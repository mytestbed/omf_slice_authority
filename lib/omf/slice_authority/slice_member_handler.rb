
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_authority/resource'

module OMF::SliceAuthority

  # Handles the collection of slices on this AM.
  #
  class SliceMemberHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceAuthority::Resource::SliceMember

      # Define handlers
      opts[:slice_member_handler] = self
      @slice_handler = opts[:slice_handler] || SliceHandler.new(opts)
      @coll_handlers = {
        slice: lambda do |path, o| # This will force the showing of the SINGLE experiment
          path.insert(0, o[:context].slice.uuid.to_s)
          @slice_handler.find_handler(path, o)
        end
      }
    end

    # def on_delete(slice_uri, opts)
      # if slice = opts[:resource]
        # debug "Delete slice #{slice}"
        # res = show_deleted_resource(slice.uuid)
        # slice.destroy
      # else
        # # Delete ALL slices for experiment
        # unless (experiment = opts[:context]).is_a? GIMI::Resource::Experiment
          # raise OMF::SFA::AM::Rest::BadRequestException.new "Can only delete slices in the context of an experiment"
        # end
        # uuid_a = experiment.slices.map do |ex|
          # debug "Delete slice #{ex}"
          # uuid = ex.uuid
          # ex.destroy
          # uuid
        # end
        # res = show_deleted_resources(uuid_a)
        # experiment.reload
      # end
      # return res
    # end

    # SUPPORTING FUNCTIONS


    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      if slice = opts[:context]
        slices = slice.slice_members
      else
        slices = OMF::SliceAuthority::Resource::SliceMember.all()
      end
      show_resources(slices, :slices, opts)
    end

    # # Create a new slice within an experiment. The slice properties are
    # # contained in 'description'
    # #
    # def create_resource(description, opts)
      # if name = description[:name]
        # if (res = @resource_class.first(name: name, experiment: experiment))
          # return modify_resource(res, description, opts)
        # end
      # end
#
      # description[:experiment] = experiment
      # super
    # end

  end
end
