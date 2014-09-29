
require 'omf/slice_service/task'
require 'omf/slice_service/task/sfa'

module OMF::SliceService::Task

  # @param [User] user user resource for which to create a slice membership
  # @param [Hash] description describing the membership
  # @option description [String] :slice name of slice
  # @option description [String] :role role in slice
  # @option description [String] :project project to create the slice in
  #
  def self.CreateSliceMembership(user, description)
    CreateSliceMembershipTask.new.start(user, description)
  end

  class CreateSliceMembershipTask < AbstractTask

    def start(user, description)
      promise = OMF::SFA::Util::Promise.new
      debug "Creating a slice membership for user '#{user.name}' - #{description}"
      role = description[:role] || DEF_SLICE_MEMBERSHIP_ROLE
      slice_name = description.delete(:slice) # needs to replaced by slice record if needed
      project_name = description[:project]
      unless role && slice_name && project_name
        raise OMF::SFA::AM::Rest::BadRequestException.new "Missing any of properties 'role', 'slice', 'project'"
      end

      begin
        p = OMF::SFA::Resource::GURN.create project_name, fail_null: true
      rescue OMF::SFA::Resource::GurnMalformedException => ex
        raise OMF::SFA::AM::Rest::BadRequestException.new "Malformed project urn - #{ex}"
      end
      domain = "#{p.domain}:#{p.short_name}"
      slice_urn = OMF::SFA::Resource::GURN.new(slice_name, :slice, domain)

      # Check if it already exists
      membership = nil
      slice_members do |sma|
        surn = slice_urn.to_s
        membership = sma.find {|sm| sm.slice.urn == surn }
        if membership
          debug "Found existing slice membership: #{membership}"
          description.delete(:user) # should not be attempting to set user
          membership.update(description)
          membership.save
        else
          # now check if we already have a slice
          if slice = OMF::SliceService::Resource::Slice.first(urn: slice_urn)
            puts "SLICE ALREADY EXISTS - should ask for joining"
            membership = SliceMember.create(slice: slice, user: user, role: role)
          else
            CreateSliceForUser(user, {urn: slice_urn, project: project_name}, false)
              .on_success do |slice|
                 puts ">>> SLICE CREATED(#{slice}"
                sm = SliceMember.create(name: slice_name, slice: slice, user: user, role: role)
                promise.resolve(dm)
              end
              .on_error do |err|
                promise.reject(description, slice['output'], err)
                #OMF::SliceService::RequestContext.report_error(description, slice['output'])
              end
          end
        end
      end
      promise.resolved(membership) if membership
      promise
      #membership || raise(OMF::SFA::AM::Rest::RetryLaterException.new)
    end
  end
end