

module OMF
  module SliceAuthority
    module Resource
      class Slice < OMF::SFA::Resource::OResource; end
    end
  end
end

require 'omf/slice_authority/resource/slice'
require 'omf/slice_authority/resource/user'
require 'omf/slice_authority/resource/slice_member'
