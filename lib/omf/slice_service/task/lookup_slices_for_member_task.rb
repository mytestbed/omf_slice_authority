
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'
require 'omf/slice_service/resource/slice'
include OMF::SliceService


module OMF::SliceService::Task

  # @param [User] user user resource for which to lookup slice memberships
  #
  def self.LookupSlicesForMember(user)
    LookupSlicesForMemberTask.new.start(user)
  end

  class LookupSlicesForMemberTask < AbstractTask

    def start(user)
      #promise = OMF::SFA::Util::Promise.new

      opts = {
        match: { SLICE_EXPIRED: false },
        #match: { SLICE_EXPIRED: true },
        #speaking_for: user.urn # 'urn:publicid:IDN+ch.geni.net+user+maxott'
      }
      promise = OMF::SFA::Util::Promise.new('LookupSlicesForMemberTask')
      SFA.call_ch(['lookup_slices_for_member', user.urn, :CERTS, opts]) \
      .on_error {|*msgs| promise.reject(*msgs) } \
      .on_success do |res|
        slices = res['value'].map do |sd|
          opts = {}
          # "SLICE_PROJECT_URN" "SLICE_NAME" "SLICE_EXPIRED" "SLICE_URN" "SLICE_UID" "_GENI_SLICE_OWNER" "_GENI_SLICE_EMAIL"
          # "SLICE_DESCRIPTION" "SLICE_EXPIRATION":#<XMLRPC::DateTime> "SLICE_CREATION"=>#<XMLRPC::DateTime>
          [['SLICE_NAME', :name], ['SLICE_UID', :uuid], ['SLICE_URN', :urn], ['SLICE_EXPIRED', :expiration],
           ['SLICE_CREATION', :created_at], ['_GENI_SLICE_EMAIL', :email],
          #['_GENI_SLICE_OWNER', :user_uuid], ['_GENI_PROJECT_UID', :project_uuid],
          ].each do |key, prop|
            if val = sd[key]
              opts[prop] = val
            end
          end
          unless slice = Resource::Slice.first(uuid: opts[:uuid])
            debug "Creating slice object: #{opts}"
            slice = Resource::Slice.create(opts)
          end
          [slice, sd["SLICE_ROLE"]]
        end
        promise.resolve(slices)
      end
      promise
    end
  end
end