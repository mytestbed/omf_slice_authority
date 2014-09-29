require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'omf/slice_service/request_context'

require 'omf/slice_service/task'

require 'time'
require 'em-synchrony'

include OMF::SliceService

module OMF::SliceService::Resource

  # This class represents a slice in the system.
  #
  class User < OMF::SFA::Resource::OResource
    SLICE_CHECK_INTERVAL = 600 # after what time should we check again for slices
    DEF_SLICE_MEMBERSHIP_ROLE = 'MEMBER'
    SSH_CHECK_INTERVAL = 600

    oproperty :created_at, DataMapper::Property::Time
    oproperty :speaks_for, String
    oproperty :authorized_until, DataMapper::Property::Time
    oproperty :email, String
    oproperty :slice_members, :slice_member, functional: false, inverse: :user
    oproperty :slices_checked_at, DataMapper::Property::Time
    oproperty :ssh_keys, String
    oproperty :ssh_keys_checked_at, DataMapper::Property::Time

    def authorized?
      self.authorized_until != nil && self.authorized_until < Time.now
    end

    def find_slice_member(slice_uri)
      if UUID.validate(slice_uri)
        key = :uuid; value = slice_uri
      elsif slice_uri.start_with?('urn')
        key = :urn; value  = slice_uri
      else
        key = :name; value = slice_uri
      end
      promise = OMF::SFA::Util::Promise.new
      slice_members.on_success do |sma|
        ssm = sma.find do |sm|
          if key == :uuid
            # UUID of slice_member, not slice
            sm.uuid.to_s == value
          else
            sm.slice.send(key) == value
          end
        end
        puts "SMEMBERS FOUND>>> #{ssm.inspect}"
        ssm ? promise.resolve(ssm) : promise.reject("Unknown slice member '#{slice_uri}' for user '#{self.urn}'")
      end.on_error(promise)
      promise
    end

    def create_slice_membership(description)
      #OMF::SliceService::Task::CreateSliceMembership(self, description)

      promise = OMF::SFA::Util::Promise.new
      debug "Creating/updating a slice membership for user '#{self.name}' - urn: #{description[:urn]}"
      role = description[:role] || DEF_SLICE_MEMBERSHIP_ROLE
      slice_name = description.delete(:slice) # needs to replaced by slice record if needed
      project_name = description[:project]
      unless role && slice_name && project_name
        raise OMF::SFA::AM::Rest::BadRequestException.new "Missing any of properties 'role', 'slice', 'project'"
      end

      begin
        p = OMF::SFA::Resource::GURN.create project_name, fail_null: true
      rescue OMF::SFA::Resource::GurnMalformedException => ex
        raise OMF::SFA::AM::Rest::BadRequestException.new "Malformed project urn - #{ex}"
      end
      domain = "#{p.domain}:#{p.short_name}"
      slice_urn = OMF::SFA::Resource::GURN.new(slice_name, :slice, domain)

      # Check if it already exists
      slice_members.on_success do |sma|
        Thread.current[:speaking_for] = self
        membership = nil
        surn = slice_urn.to_s
        membership = sma.find {|sm| sm.slice.urn == surn }
        if membership
          debug "Found existing slice membership: #{membership}"
          description.delete(:user) # should not be attempting to set user
          membership.update(description)
          membership.save
        else
          # now check if we already have a slice
          if slice = OMF::SliceService::Resource::Slice.first(urn: slice_urn)
            warn "SLICE ALREADY EXISTS - should ask for joining"
            membership = SliceMember.create(slice: slice, user: self, role: role)
          else
            Task::CreateSliceForUser(self, {urn: slice_urn, project: project_name}) \
            .on_success do |slice|
              puts ">>> SLICE CREATED(#{slice}"
              sm = SliceMember.create(name: slice_name, slice: slice, user: self, role: role)
              promise.resolve(sm)
            end.on_error(promise)
          end
        end
        promise.resolve(membership) if membership
      end
      promise
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
    def slice_members(refresh = false)
      puts "SLICE CHECKED>>>>>>>  #{self.slices_checked_at} - #{refresh}"
      promise = OMF::SFA::Util::Promise.new
      min_time = 30 # make sure we don't overload the server here
      if (Time.now - (self.slices_checked_at || 0)).to_i > (refresh ? min_time : SLICE_CHECK_INTERVAL)
        self.slices_checked_at = Time.now
        puts ">>>> NEED TO CHECK FOR SLICES"
        OMF::SliceService::Task::LookupSlicesForMember(self, ) \
        .on_error { |*msgs| promise.reject(*msgs) } \
        .on_success do |slices|
          # 'slices' is really [[slice, role], ...]
          current_sms = {}
          self._slice_members.each do |sm|
            next unless sm # skip nil values - TODO: Bug in OProperty non-functional when DELETE
            slice_uuid = sm.slice.uuid
            current_sms[slice_uuid] = sm
          end
          slices.each do |slice, role|
            slice_uuid = slice.uuid
            if sm = current_sms[slice_uuid]
              # we already know about, maybe update state?
              current_sms.delete(slice_uuid)
              sm.role = role
              sm.save
            else
              name = OMF::SFA::Resource::GURN.create(slice.urn).short_name
              sm = SliceMember.create(name: name, role: role, slice: slice, user: self)
            end
          end
          current_sms.values.each {|sm| sm.destroy} # remove slice members no longer active
          sm = _slice_members.compact
          promise.resolve(sm)
        end
      else
        sm = _slice_members.compact
        promise.resolve(sm)
      end
      promise
    end

    alias :_ssh_keys :ssh_keys
    def ssh_keys(refresh = false)
      promise = OMF::SFA::Util::Promise.new
      min_time = 30 # make sure we don't overload the server here
      if (Time.now - (self.ssh_keys_checked_at || 0)).to_i > (refresh ? min_time : SSH_CHECK_INTERVAL)
        self.ssh_keys_checked_at = Time.now
        OMF::SliceService::Task::LookupMemberSSHKeys(self) \
        .on_error { |*msgs| promise.reject(*msgs) } \
        .on_success do |keys|
          self.ssh_keys = keys.to_json
          promise.resolve(keys)
        end
      else
        keys = JSON.parse(_ssh_keys || '[]')
        promise.resolve(keys)
      end
      promise
    end

    def to_hash_long(h, objs, opts = {})
      super
      h[:urn] = self.urn || 'unknown'
      h[:authorized] = self.authorized?
      h[:ssh_keys] = ssh_keys()
    end

    def to_hash_brief(opts = {})
      h = super
      h[:urn] = self.urn || 'unknown'
      h
    end

    def initialize(opts)
      super
      debug "Creating new user - #{opts}"

      self.created_at = opts[:created_at] || Time.now
    end
  end # classs
end # module
