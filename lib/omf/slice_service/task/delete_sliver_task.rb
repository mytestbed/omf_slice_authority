
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [URN] authority
  # @param [SliceMember] slice_member
  #
  def self.DeleteSliver(authority, slice_member)
    if url = authority.aggregate_manager_2
      DeleteSliverTask.new.start2(authority, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end
  end


  class DeleteSliverTask < AbstractTask

    def start2(authority, slice_member)
      slice = slice_member.slice
      user = slice_member.user
      slice_credential_promise = slice_member.slice_credential
      url = authority.aggregate_manager_2

      promise = OMF::SFA::Util::Promise.new
      slice_credential_promise.on_success do |slice_credential|
        debug "Deleting a sliver at '#{authority}' for slice '#{slice}'"
        #
        # struct DeleteSliver(string slice_urn,
        #                     string credentials[],
        #                     struct options)
        opts = {
          speaking_for: user.urn
        }
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call(url, ['DeleteSliver', slice.urn, :CERTS, opts], user, cred, false) \
          .on_success do |res|
            puts "DELETE SUCCEED>>> #{res}"
            promise.resolve(true)
        end.on_error do |code, msg|
          puts "DELETE ERROR: #{msg} - #{msg.class}"
          promise.reject(code. msg)
        end
      end
      promise
    end
  end
end