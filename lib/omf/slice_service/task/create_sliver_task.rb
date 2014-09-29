
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [URN] authority
  # @param [XML] rspec
  # @param [SliceMember] slice_member
  #
  def self.CreateSliver(authority, rspec, slice_member)
    if url = authority.aggregate_manager_2
      CreateSliverTask.new.start2(authority, rspec, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end

  end

  class CreateSliverTask < AbstractTask

    def start2(authority, rspec, slice_member)
      slice = slice_member.slice
      user = slice_member.user
      slice_credential_promise = slice_member.slice_credential
      url = authority.aggregate_manager_2

      promise = OMF::SFA::Util::Promise.new
      OMF::SFA::Util::Promise.all(slice_credential_promise, user.ssh_keys).on_success do |slice_credential, ssh_keys|
        debug "Creating a sliver at '#{url}' for slice '#{slice}'"
        # struct CreateSliver(string slice_urn,
        #                     string credentials[],
        #                     string rspec,
        #                     struct users[],
        #                     struct options)
        opts = {
          speaking_for: user.urn
        }
        users = [{urn: user.urn, keys: ssh_keys}]
        cred = slice_credential.map {|c| c["geni_value"] }
        SFA.call(url, ['CreateSliver', slice.urn, :CERTS, rspec.to_s, users, opts], user, cred, false) \
          .on_error do |code, msg|
            if code == ERR2CODE[:REFUSED]
              if msg.match(/.*Must delete existing slice first/)
                debug "Sliver '#{slice.urn}@#{url}' already exist. Need to delete first"
                OMF::SliceService::Task::DeleteSliver(authority, slice_member).on_success do |res|
                  debug "Successfully deleted old sliver '#{slice.urn}@#{url}'"
                  # Try again
                  promise.resolve(start2(authority, rspec, slice_member))
                end.on_error(promise)
                next
              end
            end
            promise.reject(code, msg)
          end \
          .on_success do |reply|
            debug "Successfully created sliver '#{slice.urn}@#{url}' - #{reply}"
            res = { manifest: reply['value'] }
            code = reply['code']
            if (code.is_a? Hash)
              if err_url = code['protogeni_error_url']
                res[:err_url] = err_url
              end
            end
            promise.resolve(res)
          end
      end
      promise
    end
  end
end