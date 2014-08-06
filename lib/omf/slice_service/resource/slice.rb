require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'
require 'open-uri'

module OMF::SliceService::Resource

  # This class represents a slice in the system.
  #
  class Slice < OMF::SFA::Resource::OResource

    oproperty :manifest, String  # actually XML
    oproperty :expiration, DataMapper::Property::Time
    oproperty :created_at, DataMapper::Property::Time
    oproperty :description, String
    oproperty :email, String
    oproperty :project, :reference, type: :project
    oproperty :aggregates, :reference, type: :project, functional: false
    oproperty :slice_members, :slice_member, functional: false, inverse: :slice

    def self.sfa_create_for_user(user, slice_descr, throw_retry_on_pending = true, &on_done)
      raise unless user # intenral bug if that is being called without user
      debug "SFA class to create slice '#{slice_descr}' for '#{user}'"
      #Slice.create(slice_descr)
      unless urn_s = slice_descr[:urn]
        raise OMF::SFA::AM::Rest::BadRequestException.new "Missing slice URN"
      end
      urn = OMF::SFA::Resource::GURN.create(urn_s)
      fields = {
        SLICE_NAME: urn.short_name,
        SLICE_DESCRIPTION: slice_descr[:description] || 'None'  ,
        SLICE_EMAIL: user.email,
        SLICE_PROJECT_URN: slice_descr[:project],
      }
      fields.each {|key, value| fields.delete(key) if value.nil? }
      opts = { fields: fields, speaking_for: user.urn }
      OMF::SliceService::SFA.instance.call2(['create', 'SLICE', :CERTS, opts], user, throw_retry_on_pending) do |success, res|
        #success, res = client.call2('create', 'SLICE', certs, opts)
        if success && res['code'] == 0
          opts = {}
          value = res['value']
          # "SLICE_PROJECT_URN" "SLICE_NAME" "SLICE_EXPIRED" "SLICE_URN" "SLICE_UID" "_GENI_SLICE_OWNER" "_GENI_SLICE_EMAIL"
          # "SLICE_DESCRIPTION" "SLICE_EXPIRATION":#<XMLRPC::DateTime> "SLICE_CREATION"=>#<XMLRPC::DateTime>
          [['SLICE_NAME', :name], ['SLICE_UID', :uuid], ['SLICE_URN', :urn], ['SLICE_EXPIRED', :expiration],
           ['SLICE_CREATION', :created_at], ['_GENI_SLICE_EMAIL', :email],
          #['_GENI_SLICE_OWNER', :user_uuid], ['_GENI_PROJECT_UID', :project_uuid],
          ].each do |key, prop|
            if val = value[key]
              opts[prop] = val
            end
          end
          debug "Creating slice object: #{opts}"
          slice = Slice.create(opts)
          on_done.call(:OK, slice) if on_done
        else
          on_done.call(:ERROR, res) if on_done
        end
        #on_done.call(res[1]) if on_done
      end
    end

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
      #puts ">>>>> TOPOLOGY - #{topo}"

      # OK, we should check if this is the identical to previous
      if topo.is_a? Hash
        case mt = topo[:mime_type] || 'gjson'
        when 'gjson'
          OMF::SFA::AM::Rest::UnsupportedMethodException.new "Can't handle topologies in GraphJSON format yet"

        when 'xml'
          rspec = topo[:content]
          case encoding = topo[:encoding]
          when 'uri'
            rspec = URI::decode(rspec)
          else
            OMF::SFA::AM::Rest::UnsupportedMethodException.new "Unsupported content encoding '#{encoding}'."
          end

        else
          OMF::SFA::AM::Rest::UnsupportedMethodException.new "Unsupported content mime-type '#{mt}'."
        end

        puts "UUUUUSSSER>> #{Thread.current[:speaking_for]} -- #{rspec}"
        return
      end


      fields = {
        SLICE_NAME: urn.short_name,
        SLICE_DESCRIPTION: slice_descr[:description] || ''  ,
        SLICE_EMAIL: self.email,
        SLICE_PROJECT_URN: slice_descr[:project],
      }
      fields.each {|key, value| fields.delete(key) if value.nil? }
      opts = { fields: fields, speaking_for: self.urn }
      OMF::SliceService::SFA.instance.call(self.speaks_for) do |client, certs|
      end



# Allocate(string slice_urn,
         # struct credentials[],
         # geni.rspec rspec,
         # struct options)
    end

    alias :_slice_members :slice_members
    def slice_members()
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
    end
  end # classs
end # module
