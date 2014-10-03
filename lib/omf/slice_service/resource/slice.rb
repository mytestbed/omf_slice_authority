require 'omf/slice_service/resource'
require 'omf/slice_service/resource/sliver'
#require 'omf-sfa/resource/oresource'
require 'omf-sfa/util/graph_json'
require 'date'
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
    oproperty :progress, String, :functional => false

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

    def set_topology(topo, slice_member = nil, promise = nil)
      # if self.slice_creation_pending
      #   raise SliceCreationPendingException.new
      # end
      promise ||= OMF::SFA::Util::Promise.new

      rspec = _extract_rspec(topo)
      # OK, we should check if this is the identical to previous
      # TODO: Should we really do that?
      # current_rspec = self.rspec
      # if (current_rspec && current_rsepc == rspec) # same
      #   return promise.resolve(current_rspec)
      # end

      # Request resources!
      unless slice_member
        if smp = Thread.current[:slice_member]
          smp.on_success {|sm| set_topology(topo, sm, promise) }
          return promise
        else
          raise OMF::SFA::AM::Rest::BadRequestException.new("Can't determine user for which to request resources")
        end
      end
      user = slice_member.user

      cms = rspec.xpath('//n:*[@component_manager_id]', n: 'http://www.geni.net/resources/rspec/3').map do |e|
        e['component_manager_id']
      end.to_set
      if cms.empty?
        raise OMF::SFA::AM::Rest::BadRequestException.new("Can't find a reference to a component manager (component_manager_id)")
      end

      if self.slice_creation_pending
        #raise OMF::SFA::AM::Rest::TemporaryUnavailableException.new
      end
      self.slice_creation_pending = true
      # first release all existing slivers
      old_slivers = self.slivers.map do |s|
        s.release!(slice_member).on_progress(promise, s.authority.urn)
      end
      OMF::SFA::Util::Promise.all(*old_slivers).on_always do |*success|
        #puts ">>>>>>>>> OLD DELETED"
        promise.progress "Old slivers cleaned up" unless old_slivers.empty?
        self.slivers.clear
        cms.each do |cm|
          sliver = Sliver.create_for_component_manager(cm, rspec, slice_member, promise)
          sliver.on_status do |state|
            _check_sliver_progress(sliver, state, promise)
          end
          self.slivers << sliver
        end
        self.save
        #promise.resolve(self.slivers.to_a)
      end
      promise.on_progress do |ts, m|
        #puts "----------------- #{ts}: #{m}"
        self.progress(m, ts)
        self.save
      end
      promise
    end

    def _extract_rspec(topo)
      if topo.is_a? Hash
        case mt = topo[:mime_type] || 'application/gjson'
        when 'application/gjson'
          Slice.transaction do |t|
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
      elsif topo.is_a? Nokogiri::XML::Document
        rspec = topo
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Topology description needs to be a hash, but is a '#{topo.class}'"
      end
      rspec
    end

    # Called whenever the state of a sliver has changed.
    # We'll check if all slivers have been provisioned
    # for the first time and then resolve 'promise'
    # with the current list of slice resources.
    #
    def _check_sliver_progress(sliver, state, promise)
      return unless promise.pending? # already resolved
      if self.slivers.all? {|s| s.provisioned? }
        self.slice_creation_pending = false
        self.save
        promise.resolve self.resources
      end
    end

    def resources
      r = self.slivers.map do |s|
        s.resources
      end.flatten
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

    def progress(msg, timestamp = nil)
      self.progresses << "#{(timestamp || Time.now).utc.iso8601}: #{msg}"
    end

    def initialize(opts)
      super
      self.created_at = Time.now
      self.slice_creation_pending = false
    end
  end # classs
end # module