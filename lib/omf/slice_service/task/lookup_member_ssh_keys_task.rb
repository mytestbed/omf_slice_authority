
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'
include OMF::SliceService


module OMF::SliceService::Task

  # @param [User] user user resource for which to lookup SSH keys
  #
  def self.LookupMemberSSHKeys(user)
    LookupMemberSSHKeysTask.new.start(user)
  end

  class LookupMemberSSHKeysTask < AbstractTask

    def start(user)
      opts = {
        match: {
          KEY_MEMBER: user.urn
        },
        speaking_for: user.urn
      }
      SFA.call_ma(['lookup', 'KEY', :CERTS, opts], user).filter do |v|
        #puts "LOOKUP SSH KEYS>>>> #{v}"
        v['value'].map do |k, v|
          v['KEY_PUBLIC']
        end
      end
    end
  end
end