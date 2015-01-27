
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

    def start2(sliver, slice_member, promise = nil)
      slice = sliver.slice
      url = sliver.authority.aggregate_manager_2

      promise ||= OMF::SFA::Util::Promise.new('DeleteSliverTask')
      slice_member.slice_credential.on_success do |slice_credential|
        debug "Deleting a sliver at '#{url}' for slice '#{slice}'"
        #
        # struct DeleteSliver(string slice_urn,
        #                     string credentials[],
        #                     struct options)
        opts = {}
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call(url, ['DeleteSliver', slice.urn, :CERTS, opts], cred, false) \
          .on_success do |res|
            puts "DELETE SUCCEED>>> #{res}"
            promise.resolve(true)
        end.on_error do |code, ex|
          if ex.is_a? TaskTimeoutException
            debug "Retry delete again"
            promise.progress "Retrying because of timeout"
            start2(sliver, slice_member, promise)
          elsif ex.is_a? OMF::SliceService::Task::SFAException
            # 12 - {"value"=>0, "output"=>"No such slice here"
            if ex.error?(:searchfailed) #&& ex.match(/.*No such slice here/)
              debug "Looks like sliver '#{slice.urn}' is already gone."
              promise.resolve(true)
            else
              promise.reject(code, ex)
            end
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