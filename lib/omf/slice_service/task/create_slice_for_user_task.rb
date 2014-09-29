
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [User] user user resource for which to create a slice
  # @param [Hash] description describing the slice to be created
  # @option description [URN/String] :urn urn of slice to create
  # @option description [String] :project project to create the slice in
  #
  def self.CreateSliceForUser(user, description)
    CreateSliceForUserTask.new.start(user, description)
  end

  class CreateSliceForUserTask < AbstractTask

    def start(user, slice_descr)
      raise unless user # intenral bug if that is being called without user
      debug "Creating a slice ''#{slice_descr}' for '#{user}'"
      unless urn_s = slice_descr[:urn]
        raise OMF::SFA::AM::Rest::BadRequestException.new "Missing slice URN"
      end
      urn = OMF::SFA::Resource::GURN.create(urn_s)
      fields = {
        SLICE_NAME: urn.short_name,
        SLICE_DESCRIPTION: slice_descr[:description] || 'None'  ,
        SLICE_EMAIL: user.email,
        SLICE_PROJECT_URN: slice_descr[:project],
      }
      fields.each {|key, value| fields.delete(key) if value.nil? }
      opts = { fields: fields, speaking_for: user.urn }
      promise = OMF::SFA::Util::Promise.new
      SFA.call_ch(['create', 'SLICE', :CERTS, opts], user) \
        .on_error {|*msgs| promise.reject(*msgs) } \
        .on_success do |res|
          unless res['code'] == 0
            warn "Error reply: #{res}"
            promise.reject("While requesting a slice: #{res['output']}")
            next
          end

          opts = {}
          value = res['value']
          # "SLICE_PROJECT_URN" "SLICE_NAME" "SLICE_EXPIRED" "SLICE_URN" "SLICE_UID" "_GENI_SLICE_OWNER" "_GENI_SLICE_EMAIL"
          # "SLICE_DESCRIPTION" "SLICE_EXPIRATION":#<XMLRPC::DateTime> "SLICE_CREATION"=>#<XMLRPC::DateTime>
          [['SLICE_NAME', :name], ['SLICE_UID', :uuid], ['SLICE_URN', :urn], ['SLICE_EXPIRED', :expiration],
           ['SLICE_CREATION', :created_at], ['_GENI_SLICE_EMAIL', :email],
          #['_GENI_SLICE_OWNER', :user_uuid], ['_GENI_PROJECT_UID', :project_uuid],
          ].each do |key, prop|
            if val = value[key]
              opts[prop] = val
            end
          end
          debug "Creating slice object: #{opts}"
          slice = OMF::SliceService::Resource::Slice.create(opts)
          promise.resolve(slice)
        end

      promise
    end
  end
end