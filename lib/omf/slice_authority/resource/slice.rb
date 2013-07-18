require 'omf/slice_authority/resource'
require 'omf-sfa/resource/oresource'
require 'time'

module OMF::SliceAuthority::Resource

  # This class represents a slice in the system.
  #
  class Slice < OMF::SFA::Resource::OResource

    oproperty :manifest, String  # actually XML
    oproperty :expiration, DataMapper::Property::Time
    oproperty :creation, DataMapper::Property::Time
    oproperty :description, String
    oproperty :email, String
    oproperty :project, :reference, type: :project
    oproperty :aggregates, :reference, type: :project, functional: false
    oproperty :slice_members, :slice_member, functional: false, inverse: :slice

    def expired?
      self.expiration < Time.now
    end

    def to_hash_long(h, objs, opts = {})
      super
      h[:urn] = self.urn || 'unknown'
      h[:expired] = self.expired?
      href_only = opts[:level] >= opts[:max_level]
      #h[:experiment] = href_only ? self.experiment.href : self.experiment.to_hash(objs, opts)
      h
    end

    def to_hash_brief(opts = {})
      h = super
      #h[:urn] = self.urn || 'unknown'
      h
    end

    def initialize(opts)
      super
      self.creation = Time.now
    end
  end # classs
end # module
