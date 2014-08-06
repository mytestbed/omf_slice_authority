
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'

module OMF::SliceService

  # Handles the collection of authorities know to this service.
  #
  class AuthorityHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::Authority
    end

  end
end
