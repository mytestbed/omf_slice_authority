
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
require 'omf/slice_service/slice_member_handler'
require 'omf/slice_service/sliver_handler'
require 'omf/slice_service/slice_resources_handler'

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
        slice_members: (opts[:slice_member_handler] || SliceMemberHandler.new(opts)),
        slivers: (opts[:sliver_handler] || SliverHandler.new(opts)),
        resources: (opts[:slice_resources_handler] ||= SliceResourcesHandler.new(opts))
      }
    end

    def create_resource(description, opts, resource_uri = nil)
      warn "Attempt to create slice directly - #{description}"
      raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Slices can only be created in the context of /users/xxx/slice_members")
    end

    def modify_resource(resource, description, opts)
      sm = opts[:contexts][:slice_members]
      Thread.current[:slice_member] = sm
      super
    end

    # redirect speaks_for to /speaks_for
    def after_resource_to_hash_hook(res)
      res[:resources] = absolute_path("/slices/#{res[:uuid]}/resources")
      res
    end
  end
end
