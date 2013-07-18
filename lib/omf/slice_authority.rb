

module OMF
  module SliceAuthority; end
end


if __FILE__ == $0
  # Run the service
  #
  require 'omf/slice_authority/server'

  opts = {
    :app_name => 'slice_authority',
    :port => 8006,
    # :am => {
      # :manager => lambda { OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new) }
    # },
    :ssl => {
      :cert_file => File.expand_path("~/.gcf/am-cert.pem"),
      :key_file => File.expand_path("~/.gcf/am-key.pem"),
      :verify_peer => true
      #:verify_peer => false
    },
    #:log => '/tmp/am_server.log',
    :dm_db => 'sqlite:///tmp/slice_authority_test.db',
    :dm_log => '/tmp/slice_authority_test-dm.log',
    :rackup => File.dirname(__FILE__) + '/slice_authority/config.ru',

  }
  OMF::SliceAuthority::Server.new.run(opts)

end