
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
require 'omf/slice_service/user_handler'
require 'omf/slice_service/slice_handler'
require 'omf/slice_service/request_context'

module OMF::SliceService

  # Handles the collection of slices on this AM.
  #
  class SliceMemberHandler < OMF::SFA::AM::Rest::RestHandler
    DEF_ROLE = 'MEMBER'

    SLICE_CHECK_INTERVAL = 600 # after what time should we check again for slices

    def initialize(opts = {})
      super
      @resource_class = OMF::SliceService::Resource::SliceMember

      # Define handlers
      opts[:slice_member_handler] = self
      @coll_handlers = {
        slice: lambda do |path, sopts|
          slice_member = get_context_resource(:slice_members, sopts)
          path.insert(0, slice_member.slice.uuid.to_s)
          sh = (opts[:slice_handler] ||= SliceHandler.new(opts))
          sh.find_handler(path, sopts)
        end,
        user: lambda do |path, sopts|
          slice_member = get_context_resource(:slice_members, sopts)
          path.insert(0, slice_member.user.uuid.to_s)
          uh = (opts[:user_handler] ||= UserHandler.new(opts))
          uh.find_handler(path, sopts)
        end,
        slice_credential: lambda do |path, opts|
          raise OMF::SFA::AM::Rest::RedirectException.new("/slice_credentials/#{opts[:resource].uuid}")
        end
      }
    end

    # Override finding slice member as it needs to be done in the context of the
    # user, can't be done directly.
    #
    def find_resource(resource_uri, description = {}, opts = {})
      user = opts[:contexts][:users]
      user.find_slice_member(resource_uri)
    end

    def add_resource_to_context(slice_member, context)
      # Already done!
    end

    def remove_resource_from_context(slice_member, user)
      puts ">>> #{slice_member} - #{user}"
      user.remove_slice_membership(slice_member)
    end

    def on_delete_all(opts)
      # Resource has already been deleted
      #raise OMF::SFA::AM::Rest::BadRequestException.new "Already deletedI'm sorry, Dave. I'm afraid I can't do that."
    end



    def modify_resource(resource, description, opts)
      #RequestContext.exec(description) do
        topology = description.delete(:topology)
        unless topology && description.empty?
          puts "--- MODIFUY>>>>>> #{description.inspect}"
          raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Can't modify slice memberships beyond setting topology")
        end
        promise = OMF::SFA::Util::Promise.new
        resource.on_success do |sm|
          promise.resolve(sm.set_topology(topology).filter {|m| sm})
        end.on_error do |*x|
          # put on error first so it can capture any exceptions thrown
          # within the 'on_success'
          puts ">>>>>>ON ERROR #{x}"
          promise.reject(*x)
        end
        promise
      #end
      #
    end

    # def show_resource_status(resource, opts)
    #   puts "---- SHOW_RESOURCE_STATUS - #{resource}"
    #   if resource
    #     promise = OMF::SFA::Util::Promise.new
    #     promise.resolve(resource).filter do |res|
    #       puts "---SHOW STATUS>>>> #{res}"
    #       about = opts[:req].path
    #       props = res.to_hash({}, :max_level => opts[:max_level])
    #       props.delete(:type)
    #       ['application/json', { :type => res.resource_type }.merge!(props)]
    #     end
    #     promise
    #   else
    #     ['application/json', {:error => 'Unknown resource'}]
    #   end
    # end

    def _really_create_resource(description, opts)
      unless user = opts[:context]
        raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Slice memberships can only be created in the context of /users/xxx/slice_members")
      end
      Thread.current[:speaking_for] = user
      sm = user.create_slice_membership(description)
    end



    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      #resources = RequestContext.exec(opts) do
        if (context = opts[:context])
          m = opts[:context_name].to_sym
          if m == :slice_members
            refresh = ['', '1', 't', 'T', 'true', 'TRUE'].include?(opts[:req].params['_refresh'])
            resources = context.slice_members(refresh)
          else
            resources = context.send(m)
          end
        else
          @resource_class.all()
        end
      #end
      show_resources(resources, nil, opts)
    end

     def _convert_obj_to_html(obj, ref_name, res, opts)
      if ref_name.to_s.include?('slice_credential')
        res << "<a href='/slice_credentials/#{opts[:context][:uuid]}'>...</a>"
        return
      end
      super
    end

  end
end
