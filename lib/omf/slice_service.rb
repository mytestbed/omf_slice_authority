
module OMF
  module SliceService
    DEF_OPTS = {
      :app_name => 'slice_service',
      :port => 8006,
      :config_file => File.absolute_path(File.join(File.dirname(__FILE__), '../../etc/omf-slice-service/config.yaml')),
      #:log => '/tmp/am_server.log',
      :defaults => {
        :dm_db => 'sqlite:///tmp/slice_service_test.db',
        :dm_log => '/tmp/slice_service_test-dm.log',
      },
      :rackup => File.dirname(__FILE__) + '/slice_service/config.ru'
    }

    DEF_SSL_OPTS = {
      ssl: {
        cert_file: File.expand_path("~/.gcf/am-cert.pem"),
        key_file: File.expand_path("~/.gcf/am-key.pem"),
        #:verify_peer => true,
        verify_peer: false
      }
    }

    def self.init(opts)
      require 'omf/slice_service/sfa'
      SFA.init(opts)

      # SFA.instance.call() do |client, certs|
        # success, res = client.call2('lookupAM', {})
        # puts ">>>>>>>>>> #{success}--#{res}"
      # end



      # SFA.instance.lookup_slices_for_member('urn:publicid:IDN+ch.geni.net+user+maxott') do |status, reply|
        # puts ">>>>>>>>>> #{status}::#{reply}--#{reply.class}"
      # end
      # EM.next_tick { @@scheduler.start }
    end
  end
end
