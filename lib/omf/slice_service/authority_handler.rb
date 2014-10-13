
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'

module OMF::SliceService

  # Handles the collection of authorities know to this service.
  #
  class AuthorityHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::Authority

      opts[:authority_handler] = self
      @coll_handlers = {
        cert: lambda do |path, opts|
          auth = opts[:resource]
          OMF::SFA::AM::Rest::ContentFoundException.new(auth.cert)
        end
      }
    end

    # don't include 'cert' in normal list
    def after_resource_to_hash_hook(res_hash, res)
      if res_hash.key? :cert
        res_hash[:cert] = absolute_path("/authorities/#{res.uuid}/cert")
      end
      res_hash
    end
  end
end
