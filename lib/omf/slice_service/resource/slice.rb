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

    # TODO: This is a hack, but until we keep track of resources
    # as individual records, this is the best we can do
    oproperty :nodes_starting_chef, Integer
    oproperty :nodes_finishing_chef, Integer

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

      cma1 = rspec.xpath('//n:*[@component_manager_id]', n: Sliver::RSPEC3_NS).map do |e|
        e['component_manager_id']
      end
      cma2 = rspec.xpath('//n:component_manager', n: Sliver::RSPEC3_NS).map {|e| e['name']}
      cms = (cma1 + cma2).to_set
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
        self.nodes_starting_chef = 0
        self.nodes_finishing_chef = 0
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
      puts "TOPO>>> #{topo.class}::#{topo}"
      rspec = nil
      if topo.is_a? Hash
        case mt = topo[:mime_type] || 'application/gjson'
        when 'application/gjson'
          Slice.transaction do |t|
            begin
              r = OMF::SFA::Util::GraphJSON.parse(topo)
            rescue OMF::SFA::Util::GraphJSONException => gex
              warn "Error parsing gjson - #{gex} - #{topo}"
              raise OMF::SFA::AM::Rest::BadRequestException.new(gex)
            end
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
      _add_service_hooks(rspec)
      rspec
    end

    def _add_service_hooks(rspec)
      #puts ">>>> ADDING SERVICES TO -- #{rspec.to_s}"
      rspec.xpath('//n:node', n: Sliver::RSPEC3_NS).each do |n|
        services =  (n.xpath 'n:services', n:  Sliver::RSPEC3_NS)[0]
        unless services
          services = Nokogiri::XML::Element.new('services', rspec)
          n.add_child(services)
        end
        unless client_id = n['client_id']
          warn "RSPEC doesn't have 'client_id' for - #{n}"
          next
        end
        url = "#{self.href}/init_scripts/#{client_id}"
        boot_s = Nokogiri::XML::Element.new("<execute command='wget -O - #{url}| /bin/bash' shell='sh'/>", rspec)
        services.add_child("<execute command='wget -O - #{url} | sudo /bin/bash' shell='sh'/>")
      end
      puts ">>>> MODIFIED RSPEC>>>> #{rspec.to_s}"
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
      r = {}
      self.slivers.each do |s|
        #puts "SLIVER RESOURCES>>>> #{s.resources}"
        r.merge! (s.resources || {})
      end
      r
    end

    def topology
      nodes = []
      edges = []
      interfaces = {}
      rs = self.resources
      rs.values.each do |r|
        next unless r['type'] == 'node'
        nodes << {
          _id: r['sliver_id'],
          _type: 'node',
          name: r['client_id'],
          status: r['status'],
          node_type: r['node_type'],
          ssh_login: r['ssh_login']
        }
        (r['interfaces'] || {}).each do |client_id, ifd|
          interfaces[client_id] = {interface: ifd, node: r}
        end
      end
      # "edges": [
      #   {
      #     "_id": "5bcbcfa4-e624-41f6-8ab5-6fd712ab6fcc",
      #   "_type": "link",
      #   "_source": "8ec2c565-c3b5-452c-be2b-d58d18fe590b",
      #   "_target": "98020d5a-2888-446c-990b-c37d8fe37f37",
      #   "head": {
      #   "name": "if0",
      #   "ip": { "address": "10.0.5.2", "type": "ipv4", "netmask": "255.255.255.0" }
      # },
      #   "tail": {
      #   "ip": { "address": "10.0.5.3", "type": "ipv4", "netmask": "255.255.255.0" }
      # }
      rs.values.each do |r|
        next unless r['type'] == 'link'

        edge = {
          _id: r['sliver_id'],
          _type: 'link'
        }
        ifs = r['interfaces'] || []
        if ifs.size == 2
          _topology_edge_from_link(edge, r, interfaces)
        end
        edges << edge
      end
      {
        graph: {
          mode: "NORMAL",
          nodes: nodes,
          edges: edges
        }
      }
    end

    def _topology_edge_from_link(edge, link, interfaces)
      #puts "LINK>>> #{link['interfaces'].values}"
      #puts "INTERFACES>>> #{interfaces}"
      head, tail = link['interfaces'].values
      if_head = interfaces[head['client_id']]
      if_tail = interfaces[tail['client_id']]
      #puts "HEAD: #{if_head}"
      #puts "TAIL: #{if_tail}"
      return unless if_head && if_tail
      edge[:_source] = if_head[:node]['sliver_id']
      edge[:head] = if_head[:interface]
      edge[:_target] = if_tail[:node]['sliver_id']
      edge[:tail] = if_tail[:interface]
    end

    alias :_slice_memberships :slice_members
    def slice_members(refresh = false)
      # there is a bug in the delete logic regarding non-functional objects
      _slice_memberships.compact
    end

    alias :_slivers :slivers
    def slivers
      slivers = self._slivers
      puts ">>>> SLIVERS >>>> #{slivers.empty?}"
      if slivers.empty? && smp = Thread.current[:slice_member]
        promise = OMF::SFA::Util::Promise.new('Obtaining sliver info')
        smp.on_success do |sm|
          OMF::SliceService::Task::SASliverInfo(sm.slice, sm).on_success do |r|
            #puts ">>>REPLY>>>>>> #{r}"
            sliver_urns = (r.values.map {|i| i["SLIVER_INFO_AGGREGATE_URN"]}).uniq
            slivers = sliver_urns.map do |cm_urn|
              authority = Authority.first(urn: cm_urn)
              sliver = Sliver.create(slice: self, slice_member: sm, authority: authority)
              self.slivers << sliver
            end
            self.save
            promise.resolve(slivers)
          end.on_error(promise).on_progress(promise)
        end.on_error(promise).on_progress(promise)
        slivers = promise
      end
      slivers
    end

    # Return a hash describing information a resource
    # would like to know to bootstrap it's own state
    #
    def resource_info(client_id)
      resources = self.resources
      resources[client_id]
    end

    # Return the postfix used to identify resources. A resource
    # prepends it's client_id to the string returned.
    #
    def slice_postfix
      p = self.urn.split '+'
      sname = p[-1]
      auth, project = p[-3].split(':')
      if project.nil?
        warn "Unexpected slice URN format '#{self.urn}' - expected something like 'urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+foo95'"
      end
      ".#{sname}.#{project}.#{auth == 'ch.geni.net' ? 'geni' : 'unknown'}"
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
