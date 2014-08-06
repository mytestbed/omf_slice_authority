require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'
require 'em-synchrony'

module OMF::SliceService::Resource

  # This class represents a slice in the system.
  #
  class User < OMF::SFA::Resource::OResource
    SLICE_CHECK_INTERVAL = 300 #600 # after what time should we check again for slices
    DEF_SLICE_MEMBERSHIP_ROLE = 'MEMBER'

    oproperty :created_at, DataMapper::Property::Time
    oproperty :speaks_for, String
    oproperty :authorized_until, DataMapper::Property::Time
    oproperty :email, String
    oproperty :slice_members, :slice_member, functional: false, inverse: :user
    oproperty :slices_checked_at, DataMapper::Property::Time

    def authorized?
      self.authorized_until != nil && self.authorized_until < Time.now
    end

    def create_slice_membership(description)
      role = description[:role] || DEF_SLICE_MEMBERSHIP_ROLE
      slice_name = description[:slice]
      project_name = description[:project]
      unless role && slice_name && project_name
        raise OMF::SFA::AM::Rest::BadRequestException.new "Missing any of properties 'role', 'slice', 'project'"
      end

      p = OMF::SFA::Resource::GURN.create project_name
      domain = "#{p.domain}:#{p.short_name}"
      slice_urn = OMF::SFA::Resource::GURN.new(slice_name, :slice, domain)

      # Check if it already exists
      membership = nil
      slice_members do |sma|
        surn = slice_urn.to_s
        membership = sma.find {|sm| sm.slice.urn == surn }
        next if membership # done

        # now check if we already have a slice
        if slice = Slice.first(urn: slice_urn)
          puts "SLICE ALREADY EXISTS - should ask for joining"
          membership = SliceMember.create(slice: slice, user: self, role: role)
        else
          Slice.sfa_create_for_user self, {urn: slice_urn, project: project_name}, false do |code, slice|
            puts ">>> SLICE CREATED(#{code}): #{slice}"
            if code == :OK
              sm = SliceMember.create(slice: slice, user: self, role: role)
            end
          end
        end
      end
      membership || raise(OMF::SFA::AM::Rest::RetryLaterException.new)
    end

    def remove_slice_membership(slice_member)
      # Modify object membership, adding, removing and changing roles of members
      #    with respect to given object
      #
      # Arguments:
      #   type: type of object for whom to lookup membership (
      #       in the case of Slice Member Service, "SLICE",
      #       in the case of Project Member Service, "PROJECT")
      #   urn: URN of slice/project for which to modify membership
      #   Options:
      #       members_to_add: List of member_urn/role tuples for members to add to
      #              slice/project of form
      #                 {‘SLICE_MEMBER’ : member_urn, ‘SLICE_ROLE’ : role}
      #                    (or 'PROJECT_MEMBER/PROJECT_ROLE
      #                    for Project Member Service)
      #       members_to_remove: List of member_urn of members to
      #                remove from slice/project
      #       members_to_change: List of member_urn/role tuples for
      #                 members whose role
      #                should change as specified for given slice/project of form
      #                {‘SLICE_MEMBER’ : member_urn, ‘SLICE_ROLE’ : role}
      #                (or 'PROJECT_MEMBER/PROJECT_ROLE for Project Member Service)
      #
      # Return:
      #   None

      case slice_member.role
      when 'LEAD'
        raise OMF::SFA::AM::Rest::BadRequestException.new "Can't remove slice LEAD from slice"
      when 'MEMBER'
        raise OMF::SFA::AM::Rest::BadRequestException.new "Don't have sufficient privileges to remove oneself"
      end
      opts = {
        members_to_remove: [self.urn],
        speaking_for: self.urn # 'urn:publicid:IDN+ch.geni.net+user+maxott'
      }
      slice_urn = slice_member.slice.urn
      OMF::SliceService::SFA.instance.call2(['modify_membership', 'SLICE', slice_urn, :CERTS, opts], self) do |success, res|
        if success
          debug "Successfully removed '#{self.urn}' from slice '#{slice_urn}'"
          self._slice_members.delete(slice_member)
          slice_member.destroy
          self.save
        else
          warn "Problem removing user '#{self.urn}' from slice '#{slice_urn}' - #{res['output']}"
        end
      end
    end


    alias :_slice_members :slice_members
    def slice_members(refresh = false, &callback)
      #puts "SLICE CHECKED>>>>>>>  #{self.slices_checked_at}"
      min_time = 30 # make sure we don't overload the server here
      if (Time.now - (self.slices_checked_at || 0)).to_i > (refresh ? min_time : SLICE_CHECK_INTERVAL)
        self.slices_checked_at = Time.now
        #puts ">>>> NEED TO CHECK FOR SLICES"
        opts = {
          match: { SLICE_EXPIRED: false },
          #match: { SLICE_EXPIRED: true },
          speaking_for: self.urn # 'urn:publicid:IDN+ch.geni.net+user+maxott'
        }
        OMF::SliceService::SFA.instance.call2(['lookup_slices_for_member', self.urn, :CERTS, opts], self) do |success, res|
          if success
            current_sms = {}
            self._slice_members.each do |sm|
              next unless sm # skip nil values - TODO: Bug in OProperty non-functional when DELETE
              slice_uuid = sm.slice.uuid.to_s
              #puts "KNOWN>> #{sm.slice.urn} - #{slice_uuid}::#{slice_uuid.class}"
              current_sms[slice_uuid] = sm
            end
            res['value'].each do |smd|
              slice_uuid = smd['SLICE_UID']
              slice_urn = smd["SLICE_URN"]
              if sm = current_sms[slice_uuid]
                # we already know about, maybe update state?
                current_sms.delete(slice_uuid)
                sm.role = smd["SLICE_ROLE"]
                sm.save
              else
                #puts "MISSING>> #{slice_urn} - #{slice_uuid}::#{slice_uuid.class}"
                # a new one.
                unless slice = Slice.first(uuid: slice_uuid)
                  # new slice discovered
                  slice = Slice.create(uuid: slice_uuid, urn: slice_urn)
                end
                name = OMF::SFA::Resource::GURN.create(slice.urn).short_name
                sm = SliceMember.create(name: name, role: smd["SLICE_ROLE"], slice: slice, user: self)
              end
            end
            current_sms.values.each {|sm| sm.destroy} # remove slice members no longer active
            slice_members(false, &callback) if callback
          end
        end
        nil # need to wait
      else
        sm = _slice_members.compact
        callback.call(sm) if callback
        sm
      end
    end

    def to_hash_long(h, objs, opts = {})
      super
      h[:urn] = self.urn || 'unknown'
      h[:authorized] = self.authorized?
      h
    end

    def to_hash_brief(opts = {})
      h = super
      #h[:urn] = self.urn || 'unknown'
      h
    end

    def initialize(opts)
      super
      debug "Creating new user - #{opts}"

      self.created_at = opts[:created_at] || Time.now
    end

    # def sfa_call(&block)
      # url = "https://ch.geni.net/SA"
      # client = XMLRPC::Client.new2(url)
      # client.ssl_options = {
        # private_key_file: '/Users/max/src/omf_slice_service/etc/omf-slice-authority/certs/testing.local.key',
        # cert_chain_file: '/Users/max/src/omf_slice_service/etc/omf-slice-authority/certs/testing.local.key',
        # verify_peer: false,
#
        # # only for non-EM mode
        # ca_file: '/Users/max/src/omf_slice_service/etc/omf-slice-authority/certs/trusted_roots.crt'
      # }
      # certs = []
      # if speaks_for = self.speaks_for
        # certs << {
          # geni_type: 'geni_abac',
          # geni_version: 1,
          # geni_value: speaks_for
        # }
      # end
      # #EventMachine.synchrony.sync do
      # running = true
      # Fiber.new do
        # begin
          # block.call(client, certs)
        # rescue Exception => ex
          # warn "ERROR: #{ex}"
          # debug ex.backtrace.join("\n\t")
        # end
        # running = false
      # end.resume
      # if running
        # raise OMF::SFA::AM::Rest::RetryLaterException.new
      # end
    # end
  end # classs
end # module
