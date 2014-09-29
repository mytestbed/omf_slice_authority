
require 'omf_base'
require 'singleton'
require "em-xmlrpc-client"
require 'omf-sfa/am/am-rest/rest_handler'


module OMF::SliceService::Task

  class MissingSpeaksForCredential < OMF::SFA::AM::Rest::RackException
     def initialize(user)
       super 400, "Missing speaks-for credential for user '#{user.name}'"
     end
  end

  # http://groups.geni.net/geni/wiki/GAPI_AM_API_V2_DETAILS#Elementsincode
  ERR_CODES = [
    'SUCCESS', # Success
    'BADARGS', # Bad Arguments: malformed arguments
    'ERROR', # Error (other)
    'FORBIDDEN', # Operation Forbidden: eg supplied credentials do not provide sufficient privileges (on given slice)
    'BADVERSION', # Bad Version (eg of RSpec)
    'SERVERERROR', # Server Error
    'TOOBIG', # Too Big (eg request RSpec)
    'REFUSED', # Operation Refused
    'TIMEDOUT', # Operation Timed Out
    'DBERROR', # Database Error
    'RPCERROR', # RPC Error
    'UNAVAILABLE', # Unavailable (eg server in lockdown)
    'SEARCHFAILED', # Search Failed (eg for slice)
    'UNSUPPORTED', # Operation Unsupported
    'BUSY', # Busy (resource, slice); try again later
    'EXPIRED', # Expired (eg slice)
    'INPROGRESS', # In Progress
    'ALREADYEXISTS', # Already Exists (eg the slice}
    'VLAN_UNAVAILABLE', # VLAN tag(s) requested not available (likely stitching failure)
    'INSUFFICIENT_BANDWIDTH'
  ]

  ERR2CODE = {
    SUCCESS: 0,
    BADARGS: 1,
    ERROR: 2,
    FORBIDDEN: 3,
    BADVERSION: 4,
    SERVERERROR: 5,
    TOOBIG: 6,
    REFUSED: 7,
    TIMEDOUT: 8,
    DBERROR: 9,
    RPCERROR: 10,
    UNAVAILABLE: 11,
    SEARCHFAILED: 12,
    UNSUPPORTED: 13,
    BUSY: 14,
    EXPIRED: 15,
    INPROGRESS: 16,
    ALREADYEXISTS: 17,
    VLAN_UNAVAILABLE: 24,
    INSUFFICIENT_BANDWIDTH: 25
  }

  class SFA < OMF::Base::LObject
    include Singleton

    def self.call_ch(params, user = nil, credentials = nil, v3_credentials = true)
      self.call(@@clearing_house_url, params, user, credentials, v3_credentials)
    end

    def self.call_ma(params, user = nil, credentials = nil, v3_credentials = true)
      self.call(@@member_authority_url, params, user, credentials, v3_credentials)
    end

    def self.call(authority, params, user = nil, credentials = nil, v3_credentials = true)
      self.instance.call(authority, params, user, credentials, v3_credentials)
    end


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
      unless @@member_authority_url = sfa[:member_authority]
        fatal "Missing 'member_authority' in 'sfa'"
        exit(-1)
      end

      EM.next_tick do
        check_clearinghouse_version
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

    def self.check_clearinghouse_version
      info "Checking Clearinghouse API version at '#{@@clearing_house_url}'"
      call_ch(['get_version']).on_success do |res|
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

    # def call_ch(params, user = nil)
    #   call(@@clearing_house_url, params, user)
    # end
    #
    # def call_ma(params, user = nil)
    #   call(@@member_authority_url, params, user)
    # end

    def call(url, params, user = nil, credentials = nil, v3_credentials = true)
      promise = OMF::SFA::Util::Promise.new
      client = XMLRPC::Client.new2(url, nil, 300)
      client.ssl_options = @@ssl_options
      certs = credentials || []
      unless certs.is_a? Array
        certs = [certs]
      end
      if user
        unless speaks_for = user.speaks_for
          debug "Can't call CH because of missing speaks-for - #{params}"
          raise MissingSpeaksForCredential.new(user)
        end
        if v3_credentials
          certs << {
            geni_type: 'geni_abac',
            geni_version: 1,
            geni_value: speaks_for
          }
        else
          certs << speaks_for
        end
      end
      done = false
      Fiber.new do
        while !done
          begin
            start = Time.now
            debug "Calling #{url} (#{promise.name}) - #{params}"
            pa = params.map {|p| p == :CERTS ? certs : p }
            #debug "Calling2 CH - #{pa}"
            success, res = client.call2(*pa)
            debug "Authority reply(#{success}) - #{res.inspect[0 .. 120]}"
            code = nil
            if res.is_a? Hash
              code = res['code']
              if code.is_a? Hash
                code = code['geni_code']
              end
            end
            if !success || code != 0
              warn "SFA call returned error - #{res} - call: #{params.join(' ')}"
              promise.reject(code, "[SFA] Error: #{res['output']}")
            else
              promise.resolve(res)
            end
            done = true
          rescue Exception => ex
            # TODO: On timeout and busy, retry again
            warn "ERROR(#{ex.class}): #{ex} - #{Time.now - start}"
            debug ex.backtrace.join("\n\t")
            promise.reject(-99, "[XMLRPC] ERROR #{ex}")
            done = true
          end
        end
      end.resume
      promise
    end

    private

    # def run(url, method, *args)
    #   Fiber.new do
    #     begin
    #       client = get_client(url)
    #       res = client.call(method, *args)
    #       yield :ok, res
    #     rescue Exception => ex
    #       puts "------- #{args}"
    #       puts ex.backtrace.join("\n")
    #       puts "-------"
    #       yield :error, ex
    #     end
    #   end.resume
    # end
    #
    # def get_client(url)
    #   client = XMLRPC::Client.new2(url, nil, 300) # extend time out
    #   client.ssl_options = @@ssl_options
    #   puts ">> CLIENT: #{url} -- #{@@ssl_options}"
    #   client
    # end


  end
end
