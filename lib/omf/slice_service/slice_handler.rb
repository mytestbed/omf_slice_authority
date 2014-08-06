
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
require 'omf/slice_service/slice_member_handler'

module OMF::SliceService

  # Handles the collection of slices on this AM.
  #
  class SliceHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::Slice

      # Define handlers
      opts[:slice_handler] = self
      @coll_handlers = {
        slice_members: (opts[:slice_member_handler] || SliceMemberHandler.new(opts))
      }
    end

    def create_resource(description, opts, resource_uri = nil)
      warn "Attempt to create slice directly - #{description}"
      raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Slices can only be created in the context of /users/xxx/slice_members")
    end

  end
end
