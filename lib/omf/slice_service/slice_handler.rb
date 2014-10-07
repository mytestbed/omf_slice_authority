
require 'erb'
require 'ostruct'

require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
require 'omf/slice_service/slice_member_handler'
require 'omf/slice_service/sliver_handler'
require 'omf/slice_service/slice_resources_handler'

module OMF::SliceService

  # Handles the collection of slices on this AM.
  #
  class SliceHandler < OMF::SFA::AM::Rest::RestHandler
    INIT_FILE_TEMPLATE = File.absolute_path(File.dirname(__FILE__) + '/../../../etc/omf-slice-service/node_init_file.erb.sh')

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::Slice

      # Define handlers
      opts[:slice_handler] = self
      @coll_handlers = {
        slice_members: (opts[:slice_member_handler] || SliceMemberHandler.new(opts)),
        slivers: (opts[:sliver_handler] || SliverHandler.new(opts)),
        resources: (opts[:slice_resources_handler] ||= SliceResourcesHandler.new(opts)),
        topology: lambda do |path, opts|
          slice = opts[:resource]
          graph  = JSON.pretty_generate(slice.topology)
          OMF::SFA::AM::Rest::ContentFoundException.new(graph, :json)
        end,
        init_scripts: lambda do |path, opts|
          script = find_initscript(path, opts)
          OMF::SFA::AM::Rest::ContentFoundException.new(script)
        end
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

    def find_initscript(path, opts)
      slice = opts[:resource]
      node = path[0]
      if slice.nil? || node.nil?
        raise OMF::SFA::AM::Rest::UnknownResourceException.new("Can't find node name")
      end
      resources = slice.resources
      unless resources.key? node
        raise OMF::SFA::AM::Rest::UnknownResourceException.new("Don't know anything about '#{node}''")
      end
      state = OpenStruct.new(node_name: node, slice: slice, resources: resources)
      template = File.read INIT_FILE_TEMPLATE
      ERB.new(template).result(state.instance_eval { binding })
    end
  end
end
