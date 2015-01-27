
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [URN] authority
  # @param [String/Date] expiration_time
  # @param [SliceMember] slice_member
  #
  def self.RenewSliver(authority, expiration_time, slice_member)
    if url = authority.aggregate_manager_2
      RenewSliverTask.new.start2(authority, expiration_time, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end
  end

  class RenewSliverTask < AbstractTask

    def start2(authority, expiration_time, slice_member)
      slice = slice_member.slice
      slice_credential_promise = slice_member.slice_credential
      url = authority.aggregate_manager_2

      promise = OMF::SFA::Util::Promise.new
      OMF::SFA::Util::Promise.all(slice_credential_promise).on_success do |slice_credential|
        debug "Renewing sliver at '#{url}' for slice '#{slice}'"
        # struct RenewSliver(string slice_urn,
        #                    string credentials[],
        #                    string expiration_time,
        #                    struct options)
        opts = {}
        #users = [{urn: user.urn, keys: ssh_keys}]
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call(url, ['RenewSliver', slice.urn, :CERTS, expiration_time.to_s, opts], cred, false).on_success do |reply|
          debug "Successfully renewed sliver '#{slice.urn}@#{url}' - #{reply}"
          promise.resolve(reply['value'])
        end.on_error(promise)
      end
      promise
    end
  end
end