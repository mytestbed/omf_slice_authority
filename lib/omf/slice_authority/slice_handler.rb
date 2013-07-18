
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_authority/resource'

module OMF::SliceAuthority

  # Handles the collection of slices on this AM.
  #
  class SliceHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceAuthority::Resource::Slice

      # Define handlers
      opts[:slice_handler] = self
      # @experiment_handler = opts[:experiment_handler] || ExperimentHandler.new(opts)
      # @coll_handlers = {
        # experiment: lambda do |path, o| # This will force the showing of the SINGLE experiment
          # path.insert(0, o[:context].experiment.uuid.to_s)
          # @experiment_handler.find_handler(path, o)
        # end
      # }

      # @project_handler = opts[:project_handler] || ProjectHandler.new(opts)
      # @coll_handlers = {
        # project: lambda do |path, o| # This will force the showing of the SINGLE project
          # path.insert(0, o[:context].project.uuid.to_s)
          # @project_handler.find_handler(path, o)
        # end
      # }

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
      if experiment = opts[:context]
        slices = experiment.slices
      else
        slices = OMF::SliceAuthority::Resource::Slice.all()
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
