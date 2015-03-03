
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [URN] authority
  # @param [XML] rspec
  # @param [SliceMember] slice_member
  #
  def self.CreateSliver(sliver, rspec, slice_member)
    if url = sliver.authority.aggregate_manager_2
      CreateSliverTask.new.start2(sliver, rspec, slice_member)
    else
      raise ServiceVersionNotSupportedException.new
    end

  end

  class CreateSliverTask < AbstractTask

    def start2(sliver, rspec, slice_member)
      slice = sliver.slice
      url = sliver.authority.aggregate_manager_2
      user = slice_member.user

      promise = OMF::SFA::Util::Promise.new('CreateSliverTask')
      _speaks_for = Thread.current[:speaks_for]
      OMF::SFA::Util::Promise.all(slice_member.slice_credential, user.ssh_keys).on_success do |slice_credential, ssh_keys|
        Thread.current[:speaks_for] = _speaks_for
        debug "Creating a sliver at '#{url}' for slice '#{slice}'"
        # struct CreateSliver(string slice_urn,
        #                     string credentials[],
        #                     string rspec,
        #                     struct users[],
        #                     struct options)
        opts = {}
        users = [{urn: user.urn, keys: ssh_keys}]
        cred = slice_credential.map {|c| c["geni_value"] }
        promise.progress "Calling 'CreateSliver' on '#{sliver.authority.name}'"
        SFA.call(url, ['CreateSliver', slice.urn, :CERTS, rspec.to_s, users, opts], cred, false) \
          .on_error do |code, ex|
            #puts ">>>CRETA ERROR@ >>> #{ex.error? :refused} -- #{ex.match(/.*Must delete existing slice first/)}"
            if ex.is_a? OMF::SliceService::Task::SFAException
              if ex.error?(:refused) && ex.match(/.*Must delete existing slice first/)
                debug "Sliver '#{slice.urn}@#{url}' already exist. Need to delete first"
                promise.progress "Sliver already exists. Need to delete first."
                OMF::SliceService::Task::DeleteSliver(sliver, slice_member).on_success do |res|
                  Thread.current[:speaks_for] = _speaks_for
                  debug "Successfully deleted old sliver '#{slice.urn}@#{url}'"
                  # Try again
                  promise.progress "Try again to create sliver."
                  promise.resolve(start2(sliver, rspec, slice_member))
                end.on_error(promise).on_progress(promise)
              else
                promise.reject(code, ex)
              end
            else
              promise.reject(code, ex)
            end
          end \
          .on_success do |reply|
            debug "Successfully created sliver '#{slice.urn}@#{url}' - #{reply}"
            promise.progress "Successfully created sliver '#{slice.urn}'."
            res = { manifest: reply['value'] }
            code = reply['code']
            if (code.is_a? Hash)
              if err_url = code['protogeni_error_url']
                res[:err_url] = err_url
              end
            end

            # OMF::SliceService::Task::ListSliverResources(sliver, slice_member).on_success do |res|
            #   puts "LIST RESOURCES>>>> #{res}"
            # end.on_error do |code, ex|
            #   puts "LIST RESOURCES ERROR>>>> #{ex}"
            # end

            promise.resolve(res)
          end
      end
      promise
    end
  end
end