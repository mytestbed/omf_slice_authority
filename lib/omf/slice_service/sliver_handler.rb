
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
require 'omf/slice_service/slice_handler'
require 'omf/slice_service/request_context'

module OMF::SliceService

  # Handles the collection of slivers belonging to a slice context.
  #
  class SliverHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::Sliver

      # Define handlers
      opts[:sliver_handler] = self
    end

    # Override finding slice member as it needs to be done in the context of the
    # slice, can't be done directly.
    #
    def find_resource(resource_uri, description = {}, opts = {})
      if UUID.validate(resource_uri)
        @resource_class.first(uuid: resource_uri)
      else
        slice = get_context_resource(:slices, opts)
        slice.find_sliver(resource_uri)
      end
    end

    def add_resource_to_context(slice_member, context)
      # Already done!
    end

    def remove_resource_from_context(slice_member, user)
      puts ">>> #{slice_member} - #{user}"
      slice.remove_sliver(slice_member)
    end

    # def on_delete_all(opts)
    #   # Resource has already been deleted
    #   #raise OMF::SFA::AM::Rest::BadRequestException.new "Already deletedI'm sorry, Dave. I'm afraid I can't do that."
    # end

    def create_resource(description, opts, resource_uri = nil)
      warn "Attempt to create sliver directly - #{description}"
      raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Slivers can only be created in the context of /slices/xxx/slivers")
    end

    # def show_resource_list(opts)
    #   # authenticator = Thread.current["authenticator"]
    #   if (context = opts[:context])
    #     m = opts[:context_name].to_sym
    #     if m == :slice_members
    #       refresh = ['', '1', 't', 'T', 'true', 'TRUE'].include?(opts[:req].params['_refresh'])
    #       resources = context.slice_members(refresh)
    #     else
    #       resources = context.send(m)
    #     end
    #   else
    #     @resource_class.all()
    #   end
    #   #end
    #   show_resources(resources, nil, opts)
    # end

    #  def _convert_obj_to_html(obj, ref_name, res, opts)
    #   if ref_name.to_s.include?('slice_credential')
    #     res << "<a href='/slice_credentials/#{opts[:context][:uuid]}'>...</a>"
    #     return
    #   end
    #   super
    # end

  end
end
