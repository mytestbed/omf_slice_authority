
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
      opts[:slice_handler] = self
      @coll_handlers = {
        slice_members: (opts[:slice_member_handler] || SliceMemberHandler.new(opts)),
        speaks_for: lambda do |path, opts|
          raise OMF::SFA::AM::Rest::RedirectException.new("/speaks_for/#{opts[:resource].uuid}")
        end
      }
    end

    def _convert_obj_to_html(obj, ref_name, res, opts)
      if ref_name.to_s.include?('speaks_for')
        res << "<span class='value'>...</span>"
        return
      end
      super
    end

  end
end
