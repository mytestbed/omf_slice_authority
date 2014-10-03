
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'


module OMF::SliceService

  # Handles the collection of slivers belonging to a slice context.
  #
  class SliceResourcesHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super

      # Define handlers
      opts[:slice_resources_handler] = self
    end

    # Override finding slice member as it needs to be done in the context of the
    # slice, can't be done directly.
    #
    def find_resource(resource_uri, description = {}, opts = {})
      puts "FIND>>>> #{opts}"
      slice = get_context_resource(:slices, opts)
    end

    def on_get(resource_uri, opts)
      debug "on_get for #{opts[:context]}"
      slice = opts[:context]
      ['application/json',  slice.resources]
    end

    def on_post(resource_uri, opts)
      raise IllegalMethodException.new("Can't modify resources, only PUT supported")
    end

    def on_put(resource_uri, opts)
      slice = opts[:context]
      description, format = parse_body(opts, [:json, :xml])
      slice_member = get_context_resource(:slice_members, opts)
      debug '>>> PUT "', slice_member.inspect, '"'
      begin
        res = slice.set_topology(description, slice_member)
      rescue Exception => ex
        puts ">>>>>>>>> #{ex}"
        raise ex
      end

      ['application/json',  res]
    end
  end
end
