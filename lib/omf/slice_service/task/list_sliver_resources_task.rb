
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

require "base64"
require "zlib"

module OMF::SliceService::Task


  # @param [Sliver] sliver to query about
  # @param [User] Calling user
  #
  def self.ListSliverResources(sliver, slice_member)
    if url = sliver.authority.aggregate_manager_2
      ListSliverResourcesTask.new.start2(sliver, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end
  end

  class ListSliverResourcesTask < AbstractTask

    # We are low-level on parameters as this may be called from other tasks
    # before we have a proper Sliver object
    def start2(sliver, slice_member)
      am_url = sliver.authority.aggregate_manager_2
      slice = sliver.slice

      promise = OMF::SFA::Util::Promise.new
      slice_member.slice_credential.on_success do |slice_credential|
        debug "Obtaining resource list for sliver #{sliver} at '#{am_url}'"
        # struct ListResources(string credentials[], struct options)
        # {
        #   boolean geni_available;
        #   boolean geni_compressed;
        #   string geni_slice_urn;
        #   struct geni_rspec_version {
        #     string type;
        #     string version;
        #   };
        # }
        opts = {
          geni_rspec_version: {
            version: 3,
            type: "geni"
          },
          geni_compressed: true,
          geni_slice_urn: slice.urn,
          #speaking_for: user.urn
        }
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call(am_url, ['ListResources', :CERTS, opts], cred, false).on_success do |reply|
          debug "Successfully queried sliver resource '#{slice}@#{am_url}'"
          begin
            manifest = Zlib::Inflate.inflate(Base64.decode64(reply['value']))
            promise.resolve(manifest)
          rescue Exception => ex
            promise.reject("Can't extract manifest from returned value - #{ex}")
          end

        end.on_error do |code, msg|
          # if code == ERR2CODE[:SEARCHFAILED]
          #   promise.reject(SliverNotFoundException.new(sliver))
          #   next
          # end
          promise.reject(code, msg)
        end
      end
      promise
    end
  end
end