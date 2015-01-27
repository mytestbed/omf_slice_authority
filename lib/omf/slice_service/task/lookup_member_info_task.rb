
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'
include OMF::SliceService


module OMF::SliceService::Task

  # @param [URN] user_urn user urn
  #
  def self.LookupMemberInfo(user_urn)
    LookupMemberInfoTask.new.start(user_urn)
  end

  class LookupMemberInfoTask < AbstractTask

    def start(user_urn)
      opts = {
        match: {
          MEMBER_URN: user_urn
        },
        #speaking_for: user.urn
      }
      params = ['lookup', 'MEMBER', :CERTS, opts]
      SFA.call_ma(params, nil, true, speaks_for?).filter do |v|
        #puts "LOOKUP USER>>>> #{v}"
        (v['value'] || {})[user_urn]
      end
    end
  end
end