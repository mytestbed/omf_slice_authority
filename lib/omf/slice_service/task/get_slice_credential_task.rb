
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'
include OMF::SliceService


module OMF::SliceService::Task

  # @param [User] user user resource for which to lookup slice memberships
  #
  def self.GetSliceCredential(slice, user)
    GetSliceCredentialTask.new.start(slice, user)
  end

  class GetSliceCredentialTask < AbstractTask

    def start(slice, user)
      opts = {
        speaking_for: user.urn
      }
      SFA.call_ch(['get_credentials', slice.urn, :CERTS, opts], user).filter do |v|
        v['value']
      end
    end
  end
end