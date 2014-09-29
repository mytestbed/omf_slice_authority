require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'
require 'open-uri'
require 'em-http'

module OMF::SliceService::Resource
  class UnknownAuthorityException < OMF::SliceService::SliceServiceException; end

  # This class represents a specific authority in the system.
  #
  class Authority < OMF::SFA::Resource::OResource

    AUTHORITY_TYPES = [
      'slice_authority_1',
      'aggregate_manager_1', 'aggregate_manager_2', 'aggregate_manager_3',
      'planetlab_registry_1',
      'scs_1',
      'geni_ch_ma_2',
      'geni_ch_sa_2',
      'occi_1'
    ]

    # <authority xmlns="http://jfed.iminds.be/authority">
      # <urn>urn:publicid:IDN+wall1.ilabt.iminds.be+authority+cm</urn>
      # <hrn>iMinds Virtual Wall 1</hrn>
      # <urls>
        # <serverurl>
          # <servertype role="Slice Authority" version="1"/>
          # <url>https://www.wall1.ilabt.iminds.be/protogeni/xmlrpc/sa</url>
        # </serverurl>
        # <serverurl>
          # <servertype role="Aggregate Manager" version="3"/>
          # <url>https://www.wall1.ilabt.iminds.be:12369/protogeni/xmlrpc/am/3.0</url>
        # </serverurl>
      # </urls>
      # <proxies/>
      # <type>emulab</type>
      # <reconnectEachTime>false</reconnectEachTime>
      # <pemSslTrustCert>....</pemSslTrustCert>
    # </authority>

    oproperty :auth_type, String
    oproperty :reconnect_each_time, :bool # don't know what that means
    oproperty :cert, String, :length => 1000 # actually PEM
    AUTHORITY_TYPES.each do |at|
      oproperty at, String
    end

    def self.parse_from_url(url)
      info "Fetching authority list from '#{url}'"
      http = EventMachine::HttpRequest.new(url).get
      http.errback do
        warn "Something went wrong with calling '#{url}' - #{http.error}"
      end
      http.callback do
        #p http.response_header
        unless http.response_header['CONTENT_TYPE'] == 'application/xml'
          warn "Document '#{url}' is not of type xml - #{http.response_header['CONTENT_TYPE']}"
          break
        end
        doc = REXML::Document.new http.response
        doc.elements.each("*/authority") do |el|
          urn = (e = el.elements['urn']) ? e.text : nil
          next if self.first(urn: urn)

          opts = {urn: urn, reconnect_each_time: true}
          [['hrn', :name], ['type', :auth_type], ['reconnectEachTime', :reconnect_each_time], ['pemSslTrustCert', :cert]].each do |e|
            if e.is_a? Array
              el_name, key = e
            else
              el_name = e
              key = e.to_sym
            end
            if e = el.elements[el_name]
              case key
              when :reconnect_each_time
                value = (e.text == 'true')
              else
                value = e.text
              end
              opts[key] = value
            end
          end

          # hrn = (e = el.elements['hrn']) ? e.text : nil
          # type = (e = el.elements['type']) ? e.text : nil
          # reconnect_each_time = (e = el.elements['reconnectEachTime']) ? e.text == 'true' : true
          # cert = (e = el.elements['pemSslTrustCert']) ? e.text : nil
          el.elements.each('urls/serverurl') do |sel|
            if e = sel.elements['servertype']
               role = (e.attributes['role'] || 'Unknown').downcase
               version = e.attributes['version'] || 1
               name = "#{role.gsub(' ', '_')}_#{version}"
               url = (e = sel.elements['url']) ? e.text : nil
               if AUTHORITY_TYPES.include?(name)
                 opts[name.to_sym] = url
               else
                 warn "Ignoring service '#{name}' for authority '#{urn}'"
               end
            end
          end
          info "Discovered new authority: '#{opts[:name] || 'Unknown'}' - #{urn}"
          self.create(opts)
        end
      end
    end

    def self.parse_from_xml(doc)
    end

    # def to_hash_long(h, objs, opts = {})
      # super
      # h[:urn] = self.urn || 'unknown'
      # href_only = opts[:level] >= opts[:max_level]
      # h
    # end

    def to_hash_brief(opts = {})
      h = super
      h[:role] = self.role
      h
    end

    def initialize(opts)
      super
    end
  end # classs
end # module
