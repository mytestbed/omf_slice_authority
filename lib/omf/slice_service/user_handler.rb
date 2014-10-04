
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
        slice_members: (opts[:slice_member_handler] ||= SliceMemberHandler.new(opts)),
        speaks_for: lambda do |path, opts|
          raise OMF::SFA::AM::Rest::RedirectException.new("/speaks_fors/#{opts[:resource].uuid}")
        end
      }
    end

    # redirect speaks_for to /speaks_for
    def after_resource_to_hash_hook(res)
      if res.key? :speaks_for
        res[:speaks_for] = absolute_path("/speaks_fors/#{res[:uuid]}")
      end
      res
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
