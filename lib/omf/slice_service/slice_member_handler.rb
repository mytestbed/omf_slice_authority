
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/slice_service/resource'
require 'omf/slice_service/user_handler'
require 'omf/slice_service/slice_handler'

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
      raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Can't modify slice memberships at this stage. Delete and create new one")
    end

    def _really_create_resource(description, opts)
      unless user = opts[:context]
        raise OMF::SFA::AM::Rest::NotAuthorizedException.new("Slice memberships can only be created in the context of /users/xxx/slice_members")
      end
      sm = user.create_slice_membership(description)
    end



    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      if (context = opts[:context])
        m = opts[:context_name].to_sym
        if m == :slice_members
          refresh = ['', '1', 't', 'T', 'true', 'TRUE'].include?(opts[:req].params['refresh'])
          resources = context.slice_members(refresh)
        else
          resources = context.send(m)
          end
      else
        resources = @resource_class.all()
      end
      show_resources(resources, nil, opts)
    end

     def _convert_obj_to_html(obj, ref_name, res, opts)
      if ref_name.to_s.include?('slice_credential')
        res << "<span class='value'>...</span>"
        return
      end
      super
    end

    # def find_handlerX(path, opts)
    #   unless path[0]
    #     opts[:resource] = nil
    #     req = opts[:req]
    #     method = req.request_method
    #     if method == 'POST'
    #       user = Thread.current[:speaking_for] = opts[:context]
    #       unless user.is_a? OMF::SliceService::Resource::User
    #         raise OMF::SFA::AM::Rest::UnsupportedMethodException.new(:find_handler)
    #       end
    #       description, format = parse_body(opts, [:json])
    #       role = description[:role] || DEF_ROLE
    #       #puts ">>>>find_handler: description: #{description}"
    #       if slice_name = description.delete(:slice)
    #         slice_descr = OMF::SFA::AM::Rest::RestHandler.parse_resource_uri(slice_name)
    #         if slice_descr[:name]
    #           # need to create urn
    #           unless project_urn = description[:project]
    #             raise OMF::SFA::AM::Rest::BadRequestException.new "Missing property 'project'"
    #           end
    #           # urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+lw-test-02
    #           # urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+slice4
    #           p = OMF::SFA::Resource::GURN.create project_urn
    #           domain = "#{p.domain}:#{p.short_name}"
    #           sn = OMF::SFA::Resource::GURN.new(slice_descr[:name], :slice, domain)
    #           debug "Using slice name '", sn.to_s, "'"
    #           slice_descr = {urn: sn.to_s}
    #         end
    #
    #         unless slice = OMF::SliceService::Resource::Slice.first(slice_descr)
    #           unless slice_descr[:urn]
    #             raise OMF::SFA::AM::Rest::BadRequestException.new "Missing slice URN"
    #           end
    #           description.merge!(slice_descr)
    #           # The next call will throw a RetryLater exception
    #           role = 'LEAD' # by creating the slice the user automatically becomes the lead
    #           user.create_slice(description) do |res, slice_or_msg|
    #             if res == :OK
    #               slice = slice_or_msg
    #               sm = @resource_class.create(user: user, slice: slice, role: role)
    #             end
    #           end
    #           # Should not get here as previous call will throw RetryLater
    #         end
    #         # OK, now we have a slice
    #         sm = slice.slice_members.find do |xm|
    #           next unless xm
    #           xm.user == user
    #         end
    #         unless sm
    #           sm = @resource_class.create user: user, slice: slice, role: role
    #         end
    #         opts[:resource] = sm
    #       end
    #       return self
    #     end
    #
    #   end
    #   super
    # end

    # def modify_resource(resource, description, opts)
    #   description.delete(:href)
    #   description.delete(:slice)
    #   description.delete(:user)
    #
    #   #puts ">>>>> MODIFY: #{resource}::#{resource.class} - #{description.keys}"
    #   resource.update(description) ? resource : nil
    # end

  end
end
