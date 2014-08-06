
require 'omf_base'
require 'singleton'
require "em-xmlrpc-client"
require 'omf-sfa/am/am-rest/rest_handler'


module OMF::SliceService

  class MissingSpeaksForCredential < OMF::SFA::AM::Rest::RackException
     def initialize(user)
       super 400, "Missing speaks-for credential for user '#{user.name}'"
     end
  end

  class SFA < OMF::Base::LObject
    include Singleton

    attr_reader :clearinghouse_urn

    def self.init(opts)
      unless sfa = opts[:sfa]
        fatal "Missing 'sfa' section in config file"
        exit(-1)
      end

      # Update list of authorities
      unless authority_list = sfa[:authority_list]
        fatal "Missing 'authority_list' in 'sfa'"
        exit(-1)
      end
      EM.next_tick do
        OMF::SliceService::Resource::Authority.parse_from_url authority_list
      end

      unless @@clearing_house_url = sfa[:clearing_house]
        fatal "Missing 'clearing_house' in 'sfa'"
        exit(-1)
      end
      EM.next_tick do
        instance.check_clearinghouse_version
      end

      unless x509 = sfa[:x509]
        fatal "Missing 'x509' in 'sfa'"
        exit(-1)
      end
      unless (cert = x509[:cert]) && (key = x509[:key]) && (ca = x509[:ca])
        fatal "Missing 'key' or 'cert' in 'x509'"
        exit(-1)
      end
      cert = File.join(opts[:config_dir], cert) unless cert.start_with? '/'
      key = File.join(opts[:config_dir], key) unless key.start_with? '/'
      ca = File.join(opts[:config_dir], ca) unless ca.start_with? '/'
      @@ssl_options = {
        private_key_file: key,
        cert_chain_file: cert,
        ca_file: ca, #'/Users/max/.gcf/trusted_roots/GPO.crt'
        verify_peer: false,
      }
      #puts "#{@@ssl_options} -- #{x509}"
    end

    def lookup_slices_for_member(user, opts = {match: {SLICE_EXPIRED: false}}, &callback)
      #run(@@clearing_house_url, 'lookup_slices_for_member', user, [], opts, &callback)
      call(nil, false) do |client, certs|
        res = client.call2('lookup_slices_for_member', user, certs, opts)
        callback.call(res) if callback
      end
    end

    def call2(params, user = nil, throw_retry_on_pending = true, &block)
      url = @@clearing_house_url  ##"https://ch.geni.net/SA"
      client = XMLRPC::Client.new2(url)
      client.ssl_options = @@ssl_options
      certs = []
      if user
        unless speaks_for = user.speaks_for
          debug "Can't call CH because of missing speaks-for - #{params}"
          raise MissingSpeaksForCredential.new(user)
        end
        certs << {
          geni_type: 'geni_abac',
          geni_version: 1,
          geni_value: speaks_for
        }
      end
      running = true
      Fiber.new do
        begin
          debug "Calling CH - #{params}"
          pa = params.map {|p| p == :CERTS ? certs : p }
          success, res = client.call2(*pa)
          if success && res['code'] != 0
            success = false
            warn "SFA call returned error - #{res} - call: #{params.join(' ')}"
          end
          block.call(success, res)
        rescue Exception => ex
          warn "ERROR: #{ex}"
          debug ex.backtrace.join("\n\t")
        end
        running = false
      end.resume
      if throw_retry_on_pending && running
        raise OMF::SFA::AM::Rest::RetryLaterException.new
      end
    end

    # def call(speaks_for = nil, throw_retry_on_pending = true, &block)
    #   url = @@clearing_house_url  ##"https://ch.geni.net/SA"
    #   client = XMLRPC::Client.new2(url)
    #   client.ssl_options = @@ssl_options
    #   certs = []
    #   if speaks_for
    #     certs << {
    #       geni_type: 'geni_abac',
    #       geni_version: 1,
    #       geni_value: speaks_for
    #     }
    #   end
    #   running = true
    #   Fiber.new do
    #     begin
    #       block.call(client, certs)
    #     rescue Exception => ex
    #       warn "ERROR: #{ex}"
    #       debug ex.backtrace.join("\n\t")
    #     end
    #     running = false
    #   end.resume
    #   if throw_retry_on_pending && running
    #     raise OMF::SFA::AM::Rest::RetryLaterException.new
    #   end
    # end

    def check_clearinghouse_version
      info "Checking Clearinghouse API version at '#{@@clearing_house_url}'"
      call2 ['get_version'], nil, false do |sucess, res|
        next unless sucess

        res['value'].each do |k, v|
          case k.strip
          when 'VERSION'
            @api_version = v.to_i
          when 'SERVICES'
            @suported_services = v
          when 'ROLES'
            @suported_roles = v
          when 'URN'
            @clearinghouse_urn = OMF::SFA::Resource::GURN.create(v)
          else
            debug "Ignoring field '#{k}' in 'get_version' - #{v}"
          end
        end
      end
    end

    private

    def run(url, method, *args)
      Fiber.new do
        begin
          client = get_client(url)
          res = client.call(method, *args)
          yield :ok, res
        rescue Exception => ex
          puts "------- #{args}"
          puts ex.backtrace.join("\n")
          puts "-------"
          yield :error, ex
        end
      end.resume
    end

    def get_client(url)
      client = XMLRPC::Client.new2(url)
      client.ssl_options = @@ssl_options
      puts ">> CLIENT: #{url} -- #{@@ssl_options}"
      client
    end


  end
end
