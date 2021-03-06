require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'

module OMF::SliceService::Resource

  # This class represents a slice in the system.
  #
  class SliceMember < OMF::SFA::Resource::OResource

    oproperty :status, String # 'pending', 'active', 'expired'
    oproperty :slice, :slice, inverse: :slice_members
    oproperty :user, :user, inverse: :slice_memberships
    oproperty :role, String
    oproperty :slice_credential, String

    def self.create(description)
      #puts ">>>>> NEW SLICE MEMBER - #{description}"
      description[:status] = 'unknown'
      sm = super
      sm.slice_credential() # initiate slice credential download
      sm
    end

    # def self.find_for_user(user, slice_description)
      # puts ">>>>> FIND_FOR_USER: #{user} -- #{slice_description}"
      # unless slice = Slice.first(slice_description)
        # return nil
      # end
      # puts ">>>>> FIND_FOR_USER2: #{slice}"
      # slice.slice_members.select do |sm|
        # sm.user == user
      # end
    # end

    def resource_type
      'slice_member'
    end

    def set_topology(topo)
      topo = self.slice.set_topology(topo, self)
      puts "SET_TOPO - #{topo.inspect}"
      topo
    end

    def topology=(topo)
      set_topology(topo)
    end

    def project=(project)
      # TODO: Check if same as slice's project
    end

    alias :_slice_credential :slice_credential
    def slice_credential()
      if scred = self._slice_credential
        OMF::SFA::Util::Promise.new.resolve(scred)
      else
        #OMF::SliceService::Task::GetSliceCredential(self.slice, self.user).on_success do |sc|
        OMF::SliceService::Task::GetSliceCredential(self.slice).on_success do |sc|
          #puts "SLICE_CRED>>> #{sc.inspect[0 .. 100]}"
          self.slice_credential = sc
          self.save
        end
      end
    end

    def to_hash_long(h, objs, opts = {})
      super
      href_only = opts[:level] >= opts[:max_level]
      if href_only
        h[:slice_credential] = self.href + '/slice_credential'
      end
      h[:slivers] = OMF::SliceService::Task::SASliverInfo(self.slice, self).filter do |r|
        (r.values.map {|i| i["SLIVER_INFO_AGGREGATE_URN"]}).uniq
      end
    end

    def to_hash_brief(opts = {})
      {
        slice_urn: slice.urn,
        role: self.role,
        href: self.href
      }
    end

  end # classs
end # module
