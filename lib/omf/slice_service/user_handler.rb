
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
#require 'omf/slice_service/slice_member_handler'

module OMF::SliceService

  # Handles the collection of slices on this AM.
  #
  class UserHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::User

      # Define handlers
      opts[:user_handler] = self
      @coll_handlers = {
        slice_memberships: (opts[:slice_member_handler] ||= SliceMemberHandler.new(opts)),
        ssh_keys: lambda do |path, opts|
          user = opts[:resource]
          OMF::SFA::AM::Rest::ContentFoundException.new(user.ssh_keys)
        end,
        speaks_for: lambda do |path, opts|
          raise OMF::SFA::AM::Rest::RedirectException.new("/speaks_fors/#{opts[:resource].uuid}")
        end
      }
    end

    # Allow sub class to override actual finding of resource - may create it on the fly
    def _find_resource(descr)
      debug "Finding User - #{descr}"
      unless user = @resource_class.first(descr)
        # If descr is a 'urn', let's look it up
        if user_urn = descr[:urn]
          user = @resource_class.create_from_urn(user_urn)
        end
      end
      user
    end

    # redirect speaks_for to /speaks_for
    def after_resource_to_hash_hook(res_hash, res)
      if res_hash.key? :speaks_for
        res_hash[:speaks_for] = absolute_path("/speaks_fors/#{res.uuid}")
      end
      res_hash
    end


    def on_new_resource(resource)
      # Add the user urn to current speaks_for (no idea if this is the right place for this)
      Thread.current[:speaks_for][:urn] = resource.urn
      super
    end
    # def _dispatch(method, target, resource_uri, opts)
    #   puts ">>>> DISPATC"
    #   RequestContext.exec(opts) do
    #     super
    #   end
    # end

    # def dispatch(req)
    #   puts ">>>> DISPATC"
    #   RequestContext.exec(req) do
    #     super
    #   end
    #
    # end

    def _convert_obj_to_html(obj, ref_name, res, opts)
      if ref_name.to_s.include?('speaks_for')
        #puts ">>> #{opts[:context].inspect}"
        res << "<a href='/speaks_fors/#{opts[:context][:uuid]}'>...</a>"
        return
      end
      super
    end

  end
end
