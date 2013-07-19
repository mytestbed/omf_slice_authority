
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_authority/resource'
require 'omf/slice_authority/slice_member_handler'

module OMF::SliceAuthority

  # Handles the collection of slices on this AM.
  #
  class SliceHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceAuthority::Resource::Slice

      # Define handlers
      opts[:slice_handler] = self
      @coll_handlers = {
        slice_members: (opts[:slice_member_handler] || SliceMemberHandler.new(opts))
      }
    end


    # SUPPORTING FUNCTIONS


    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      slices = OMF::SliceAuthority::Resource::Slice.all()
      show_resources(slices, :slices, opts)
    end

  end
end
