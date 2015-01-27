
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'
include OMF::SliceService


module OMF::SliceService::Task

  # @param [User] user user resource for which to lookup slice memberships
  #
  def self.GetSliceCredential(slice)
    GetSliceCredentialTask.new.start(slice)
  end

  class GetSliceCredentialTask < AbstractTask

    def start(slice)
      opts = {}
      SFA.call_ch(['get_credentials', slice.urn, :CERTS, opts]).filter do |v|
        v['value']
      end
    end
  end
end