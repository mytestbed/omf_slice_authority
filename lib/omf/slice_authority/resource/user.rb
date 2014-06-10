require 'omf/slice_authority/resource'
require 'omf-sfa/resource/oresource'
require 'time'

module OMF::SliceAuthority::Resource

  # This class represents a slice in the system.
  #
  class User < OMF::SFA::Resource::OResource

    oproperty :created_at, DataMapper::Property::Time
    oproperty :speaks_for, String
    oproperty :authorized_until, DataMapper::Property::Time
    oproperty :email, String
    oproperty :slice_members, :slice_member, functional: false, inverse: :user

    def authorized?
      self.authorized_until != nil && self.authorized_until < Time.now
    end

    def to_hash_long(h, objs, opts = {})
      super
      h[:urn] = self.urn || 'unknown'
      h[:authorized] = self.authorized?
      h
    end

    def to_hash_brief(opts = {})
      h = super
      #h[:urn] = self.urn || 'unknown'
      h
    end

    def initialize(opts)
      super
      self.created_at = Time.now
    end
  end # classs
end # module
