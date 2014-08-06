
# Bundler is messing with that later on
GEM_PATH = ENV['_ORIGINAL_GEM_PATH'] || ENV['GEM_PATH']

# Setup bundler environment
TOP_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
ENV['BUNDLE_GEMFILE'] = File.join(TOP_DIR, 'Gemfile')
require 'bundler'
Bundler.setup()

require 'yaml'
require 'god'


desc "Starting the Slice Service as a daemon"
task :start, :config do |t, args|
  config = args[:config]
  system("/usr/bin/env JOB_CONFIG=#{config} bundle exec god -c etc/omf_slice_service.god")
  system('/usr/bin/env bundle exec god start slice_service')
end

desc "Stop the Service Daemon"
task :stop do |t, args|
  system('/usr/bin/env bundle exec god stop slice_service')
end

desc "Print the status of the Service daemon"
task :status do |t, args|
  system('/usr/bin/env bundle exec god status slice_service')
end

desc "Run the  Service in this shell"
task :run do |t, args|
  system("#{TOP_DIR}/bin/omf_slice_service start")
end



desc "Call after 'bundle install --path vendor'"
task 'post-install' => [:create_server_bin]

# task 'create_server_bin' do
#   target = 'bin/omf_slice_service'
#   unless File.readable?("#{target}.in")
#     abort "Can't find '#{target}.in' in local directory"
#   end
#   tmpl = File.read("#{target}.in")
# puts ">>>> #{tmpl}"
#   home = ENV['HOME']
#   rvm_home = ENV["rvm_bin_path"].match(/.*rvm/)[0]
#   d, ruby, gemset = (GEM_PATH || ENV['_ORIGINAL_GEM_PATH'] || ENV['GEM_PATH']).match(/.*(ruby.*)@(.*)/).to_a
# puts "HOME: #{home} rvm_home: #{rvm_home} ruby: #{ruby} gemset: #{gemset}"
#   s = tmpl.gsub('%HOME%', home).gsub('%RVM_HOME%', rvm_home).gsub('%RUBY%', ruby).gsub('%GEMSET%', gemset)
#   File.open(target, 'w') do |f|
#     f.write(s)
#   end
#   File.chmod(0755, target)
#   puts ".. Created '#{target}'."
# end

task 'create_server_bin' do
  target = 'bin/omf_slice_service'
  unless File.readable?("#{target}.in")
    abort "Can't find '#{target}.in' in local directory"
  end
  tmpl = File.read("#{target}.in")

  home = ENV['HOME']
  rvm_home = ruby = gemset = ''

  rvm_path = ENV["rvm_path"]
  if rvm_path
    rvm_home = rvm_path
    d, ruby, gemset = GEM_PATH.match(/.*(ruby.*)@(.*)/).to_a
  end

  puts [home, rvm_home, ruby, gemset].inspect
  s = tmpl.gsub('%HOME%', home).gsub('%RVM_HOME%', rvm_home).gsub('%RUBY%', ruby).gsub('%GEMSET%', gemset)
  File.open(target, 'w') do |f|
    f.write(s)
  end
  File.chmod(0755, target)
  puts ".. Created '#{target}'."
end
