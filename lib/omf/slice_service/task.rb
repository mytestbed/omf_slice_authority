
module OMF
  module SliceService
    module Task
      class TaskException < Exception; end

      class ServiceVersionNotSupportedException < TaskException; end
      class TaskTimeoutException < TaskException; end
    end
  end
end

require 'omf-sfa/util/promise'

require 'omf/slice_service/task/abstract_task'
#require 'omf/slice_service/task/create_slice_member_task'
require 'omf/slice_service/task/create_slice_for_user_task'
require 'omf/slice_service/task/lookup_slices_for_member_task'
require 'omf/slice_service/task/get_slice_credential_task'

require 'omf/slice_service/task/create_sliver_task'
require 'omf/slice_service/task/delete_sliver_task'
require 'omf/slice_service/task/renew_sliver_task'
require 'omf/slice_service/task/sliver_status_task'
require 'omf/slice_service/task/list_sliver_resources_task'

require 'omf/slice_service/task/lookup_member_ssh_keys_task.rb'
