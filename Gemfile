source "https://rubygems.org"

def override_with_local(local_dir)
  unless local_dir.start_with? '/'
    local_dir = File.join(File.dirname(__FILE__), local_dir)
  end
  #puts "Checking for '#{local_dir}'"
  Dir.exist?(local_dir) ? {path: local_dir} : {}
end

gem 'omf_base', override_with_local('../omf_base')
gem 'omf_sfa', override_with_local('../omf_sfa')
gem 'dm-noisy-failures'

gem 'god'

gem 'thin_async'
gem "pg"
gem "em-pg-client", "~> 0.2.1", :require => ['pg/em', 'em-synchrony/pg']
gem "em-pg-sequel"
#gem 'em-xmlrpc-client', '~> 1.0.1', require: ['em-http-request']
#gem 'em-xmlrpc-client', override_with_local('../em-xmlrpc-client')
gem 'em-xmlrpc-client', git: 'https://github.com/maxott/em-xmlrpc-client.git', :branch => 'ssl'

gem 'em-http-request'
gem "uuid", "~> 2.3.5"

# Cross domain request
gem 'rack-cors', :require => 'rack/cors'

# TODO: Check if this is still needed. New macaddr gem forgot that
gem 'systemu'
