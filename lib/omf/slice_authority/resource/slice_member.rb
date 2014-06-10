require 'omf/slice_authority/resource'
require 'omf-sfa/resource/oresource'
require 'time'

module OMF::SliceAuthority::Resource

  # This class represents a slice in the system.
  #
  class SliceMember < OMF::SFA::Resource::OResource

    oproperty :slice, :slice, inverse: :slice_members
    oproperty :user, :user, inverse: :slice_members
    oproperty :role, String

    def resource_type
      'slice_member'
    end

    # def to_hash_brief(opts = {})
      # h = super
      # #h[:urn] = self.urn || 'unknown'
      # h
    # end

  end # classs
end # module
