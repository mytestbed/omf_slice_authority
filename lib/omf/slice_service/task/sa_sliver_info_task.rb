
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task



  # Return for a specific slice, the list of slivers (???) the Slice Authority
  # knows about.
  #
  # @param [Slice] slice
  # @param [SliceMember] slice_member
  #
  def self.SASliverInfo(slice, slice_member)
    SASliverInfoTask.new.start(slice, slice_member)
  end

  class SASliverInfoTask < AbstractTask

    def start(slice, slice_member)
      promise = OMF::SFA::Util::Promise.new('SASliverInfoTask')
      _speaks_for = Thread.current[:speaks_for]
      slice_member.slice_credential.on_success do |slice_credential|
        Thread.current[:speaks_for] = _speaks_for
        debug "Obtaining sliver info at SA for slice '#{slice}'"
        # struct SliverInfo(string slice_urn,
        #                    string credentials[],
        #                    struct options)
        opts = {
          match: {
            SLIVER_INFO_SLICE_URN: slice.urn
          },
          #speaking_for: user.urn
        }
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call_sa(['lookup', 'SLIVER_INFO', :CERTS, opts], slice_credential).on_success do |reply|
          #debug "Successfully queried sliver info '#{slice.urn}@#{url}' - #{reply}"
          debug "Successfully queried SA for sliver info on '#{slice.urn}'"
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