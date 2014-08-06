

module OMF
  module SliceService
    module Resource
      class Slice < OMF::SFA::Resource::OResource; end
    end
  end
end

require 'omf/slice_service/resource/authority'
require 'omf/slice_service/resource/slice'
require 'omf/slice_service/resource/user'
require 'omf/slice_service/resource/slice_member'
