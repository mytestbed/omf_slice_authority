
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  class SliverNotFoundException < TaskException
    attr_reader :sliver

    def initialize(sliver)
      @sliver = sliver
  end
end

  # @param [URN] authority
  # @param [SliceMember] slice_member
  #
  def self.SliverStatus(sliver, slice_member)
    if url = sliver.authority.aggregate_manager_2
      SliverStatusTask.new.start2(sliver, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end
  end

  class SliverStatusTask < AbstractTask

    def start2(sliver, slice_member)
      slice = slice_member.slice
      user = slice_member.user
      slice_credential_promise = slice_member.slice_credential
      url = sliver.authority.aggregate_manager_2

      promise = OMF::SFA::Util::Promise.new
      #OMF::SFA::Util::Promise.all(slice_credential_promise).on_success do |slice_credential|
      slice_member.slice_credential.on_success do |slice_credential|
        debug "Obtaining sliver status at '#{url}' for slice '#{slice}'"
        # struct SliverStatus(string slice_urn,
        #                    string credentials[],
        #                    struct options)
        opts = {
          speaking_for: user.urn
        }
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call(url, ['SliverStatus', slice.urn, :CERTS, opts], user, cred, false).on_success do |reply|
          debug "Successfully queried sliver status '#{slice.urn}@#{url}' - #{reply}"
          promise.resolve(reply['value'])
        end.on_error do |code, msg|
          if code == ERR2CODE[:SEARCHFAILED]
            promise.reject(SliverNotFoundException.new(sliver))
            next
          end
          promise.reject(code, msg)
        end
      end
      promise
    end
  end
end