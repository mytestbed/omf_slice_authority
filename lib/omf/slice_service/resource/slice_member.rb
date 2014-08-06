require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'

module OMF::SliceService::Resource

  # This class represents a slice in the system.
  #
  class SliceMember < OMF::SFA::Resource::OResource

    oproperty :status, String # 'pending', 'active', 'expired'
    oproperty :slice, :slice, inverse: :slice_members
    oproperty :user, :user, inverse: :slice_members
    oproperty :role, String
    oproperty :slice_credential, String

    def self.create(description)
      puts ">>>>> NEW SLICE MEMBER - #{description}"
      description[:status] = 'unknown'
      sm = super
      sm.slice_credential(false)
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

    def topology=(topo)
      self.slice.topology = topo
    end

    def project=(project)
      # TODO: Check if same as slice's project
    end

    alias :_slice_credential :slice_credential
    def slice_credential(throw_retry_on_pending = true, &on_done)
      unless scred = self._slice_credential
        user = self.user
        opts = {
          speaking_for: user.urn
        }
        # get_credentials(slice_urn, credentials, options)
        OMF::SliceService::SFA.instance.call2(['get_credentials', self.slice.urn, :CERTS, opts], user, throw_retry_on_pending) do |success, res|
          #puts "GET_CREDS: #{success} - #{res}"
          if success
            self.slice_credential = sc = res['value']
            self.save
            on_done.call(sc) if on_done
          end
        end
      end
      scred
    end


    def to_hash_brief(opts = {})
      h = super
      h[:status] = self.status || 'unknown'
      h[:role] = self.role
      if slice = self.slice
        h[:slice_urn] = slice.urn
      end
      if user = self.user
        h[:user_urn] = user.urn
      end
      h
    end

  end # classs
end # module
