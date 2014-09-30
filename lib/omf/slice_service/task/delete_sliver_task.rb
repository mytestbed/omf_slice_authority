
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [URN] authority
  # @param [SliceMember] slice_member
  #
  def self.DeleteSliver(sliver, slice_member)
    if url = sliver.authority.aggregate_manager_2
      DeleteSliverTask.new.start2(sliver, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end
  end


  class DeleteSliverTask < AbstractTask

    def start2(sliver, slice_member)
      slice = sliver.slice
      user = slice_member.user
      url = sliver.authority.aggregate_manager_2

      promise = OMF::SFA::Util::Promise.new
      slice_member.slice_credential.on_success do |slice_credential|
        debug "Deleting a sliver at '#{url}' for slice '#{slice}'"
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
        end.on_error do |code, ex|
          if ex.is_a? TaskTimeoutException
            debug "Retry delete again"
            start2(sliver, slice_member)
          else
            puts "DELETE ERROR: #{ex} - #{ex.class}"
            promise.reject(code, ex)
          end
        end
      end
      promise
    end
  end
end