require 'omf/slice_service/resource'
require 'omf/slice_service/resource/sliver'
#require 'omf-sfa/resource/oresource'
require 'omf-sfa/util/graph_json'
require 'time'
require 'open-uri'

module OMF::SliceService::Resource
  class SliceCreationPendingException < OMF::SliceService::SliceServiceException; end

  # This class represents a slice in the system.
  #
  class Slice < OMF::SFA::Resource::OResource

    oproperty :manifest, String  # actually XML
    oproperty :expiration, DataMapper::Property::Time
    oproperty :created_at, DataMapper::Property::Time
    oproperty :description, String
    oproperty :rspec, String
    oproperty :email, String
    oproperty :project, :reference, type: :project
    #oproperty :aggregates, :reference, type: :project, functional: false
    oproperty :slivers, :reference, type: :sliver, functional: false
    oproperty :slice_members, :slice_member, functional: false, inverse: :slice
    oproperty :slice_creation_pending, :boolean


    def expired?
      self.expiration < Time.now
    end

    def register_sliver_info(user, sliver_urn)
      fields = {
        SLIVER_INFO_SLICE_URN: self.urn,
        SLIVER_INFO_AGGREGATE_URN: "urn:publicid:IDN+emulab.net+authority+cm",
        SLIVER_INFO_EXPIRATION: "2014-08-12T17:11:00+10:00",
        SLIVER_INFO_CREATOR_URN: user.urn,
        SLIVER_INFO_URN: sliver_urn #"urn:publicid:IDN+emulab.net+sliver+198546"
      }
      opts = { fields: fields, speaking_for: user.urn }
      OMF::SliceService::SFA.instance.call2(['create', 'SLICE_INFO', :CERTS, opts], user) do |success, res|
        puts "SLICE_INFO #{success} - #{res}"
      end
    end

    def topology=(topo)
      set_topology(topo)
    end

    def set_topology(topo, slice_member = nil)
      # if self.slice_creation_pending
      #   raise SliceCreationPendingException.new
      # end
      promise = OMF::SFA::Util::Promise.new
      puts ">>>>> TOPOLOGY(#{topo.class}) - #{topo.to_s[0 .. 80]}"

      # OK, we should check if this is the identical to previous
      rspec = nil
      if topo.is_a? Hash

        case mt = topo[:mime_type] || 'application/gjson'
        when 'application/gjson'
          User.transaction do |t|
            r = OMF::SFA::Util::GraphJSON.parse(topo[:content])
            rspec = OComponent.to_rspec(r.values, :request)
            puts "RES>>>> #{rspec}"
            t.rollback
          end

        when 'text/xml'
          rspec_s = topo[:content]
          case encoding = topo[:encoding]
          when 'uri'
            rspec_s = URI::decode(rspec_s)
          else
            raise OMF::SFA::AM::Rest::BadRequestException.new "Unsupported content encoding '#{encoding}'."
          end
          rspec = Nokogiri::XML(rspec_s)
        else
          raise OMF::SFA::AM::Rest::BadRequestException.new "Unsupported content mime-type '#{mt}'."
        end

      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Topology description needs to be a hash"
      end
      current_rspec = self.rspec
      if (current_rspec && current_rsepc == rspec) # same
        return promise.resolve(current_rspec)
      end

      # Request resources!
      unless slice_member
        raise OMF::SFA::AM::Rest::BadRequestException.new("Can't determine user for which to request resources")
      end
      user = slice_member.user


      cms = rspec.xpath('//n:*[@component_manager_id]', n: 'http://www.geni.net/resources/rspec/3').map do |e|
        e['component_manager_id']
      end.to_set
      if cms.empty?
        raise OMF::SFA::AM::Rest::BadRequestException.new("Can't find a reference to a component manager (component_manager_id)")
      end

      self.slice_creation_pending = true
      # first release all existing slivers
      self.slivers.each {|s| s.release! }
      self.slivers.clear

      puts ">>> CMS: #{cms.inspect}"
      cms.each do |cm|
        puts ">>> CM: #{cm}"
        self.slivers << Sliver.create_for_component_manager(cm, rspec, slice_member)
      end
      promise.resolve(self.slivers.to_a)
      promise
    end

    alias :_slice_members :slice_members
    def slice_members(refresh = false)
      # there is a bug in the delete logic regarding non-functional objects
      _slice_members.compact
    end

    def to_hash_long(h, objs, opts = {})
      super
      h[:urn] = self.urn || 'unknown'
      h[:expired] = self.expired? if self.expiration
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
      self.created_at = Time.now
      self.slice_creation_pending = false
    end
  end # classs
end # module
