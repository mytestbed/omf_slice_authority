
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_authority/resource'
require 'omf/slice_authority/user_handler'
require 'omf/slice_authority/slice_handler'

module OMF::SliceAuthority

  # Handles the collection of slices on this AM.
  #
  class SliceMemberHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceAuthority::Resource::SliceMember

      # Define handlers
      opts[:slice_member_handler] = self
    end

  end
end
