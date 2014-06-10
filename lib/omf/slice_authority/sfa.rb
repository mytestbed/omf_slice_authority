
require 'omf_base'
require 'singleton'
require "em-xmlrpc-client"


module OMF::SliceAuthority
  class SFA < OMF::Base::LObject
    include Singleton

    def self.init(opts)
      unless sfa = opts[:sfa]
        fatal "Missing 'sfa' section in config file"
        exit(-1)
      end
      unless @@clearing_house = sfa[:clearing_house]
        fatal "Missing 'clearing_house' in 'sfa'"
        exit(-1)
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
      run(@@clearing_house, 'lookup_slices_for_member', user, [], opts, &callback)
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
