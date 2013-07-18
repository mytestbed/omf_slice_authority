require 'rubygems'

require 'json'

require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'data_mapper'
require 'omf_common/lobject'
require 'omf_common/load_yaml'

require 'omf-sfa/am/am_runner'
#require 'omf-sfa/am/am_manager'
#require 'omf-sfa/am/am_scheduler'

require 'omf_common/lobject'

module OMF::SliceAuthority

  class Server
    # Don't use LObject as we haveb't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Common::Loggable
    extend OMF::Common::Loggable

    def init_logger
      OMF::Common::Loggable.init_log 'server', :searchPath => File.join(File.dirname(__FILE__), 'server')

      @config = OMF::Common::YAML.load('config', :path => [File.dirname(__FILE__) + '/../../../etc/omf-slice-authority'])[:slice_authority]
    end

    def init_data_mapper(options)
      #@logger = OMF::Common::Loggable::_logger('am_server')
      #OMF::Common::Loggable.debug "options: #{options}"
      debug "options: #{options}"

      # Configure the data store
      #
      DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
      DataMapper.setup(:default, options[:dm_db])

      require 'omf-sfa/resource'
      require 'omf/slice_authority/resource'
      DataMapper::Model.raise_on_save_failure = true
      DataMapper.finalize
      DataMapper.auto_upgrade! if options[:dm_auto_upgrade]
    end


    def load_test_state(options)
      require  'dm-migrations'
      DataMapper.auto_migrate!

      p1 = OMF::SFA::Resource::OReference.create(name: 'projectA',
                                        resource_type: :project,
                                        href: 'http://ch.geni.net/projects/projectA')
      s1 = OMF::SliceAuthority::Resource::Slice.create(name: 'slice1',
                                        urn: 'urn:publicid:IDN+ch.geni.net:GIMITesting+slice+slice1',
                                        expiration: Time.now + 86400,
                                        email: 'adam@acme.com',
                                        description: 'Adam\'s slice',
                                        project: p1
                                        )
      s1.aggregates << OMF::SFA::Resource::OReference.create(name: 'aggregateX',
                                        resource_type: :aggregate,
                                        href: "http://am.orbit-lab.org/slices/#{s1.uuid}")
      s1.aggregates << OMF::SFA::Resource::OReference.create(name: 'aggregateY',
                                        resource_type: :aggregate,
                                        href: "http://am.norbit.nicta.org/slices/#{s1.uuid}")

      s1.slice_members << OMF::SliceAuthority::Resource::SliceMember.create(name: 'member1',
                                        role: 'ADMIN')

      s2 = OMF::SliceAuthority::Resource::Slice.create(name: 'slice2',
                                        urn: 'default_slice',
                                        expiration: Time.now + 86400,
                                        email: 'mary@some.edu',
                                        description: 'Mary\'s slice')
      s3 = OMF::SliceAuthority::Resource::Slice.create(name: 'slice3',
                                        urn: 'default_slice',
                                        expiration: Time.now + 86400)


      # require 'omf-sfa/resource/user'
      # u1 = OMF::SFA::Resource::User.create(:name => 'user1')
      # u2 = OMF::SFA::Resource::User.create(:name => 'user2', uuid: "a7ecac90-3d4a-498b-927f-f9bee6bb3156")

    end

    def run(opts)
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda {
        },
        :pre_parse => lambda do |p, options|
          p.on("--test-load-state", "Load an initial state for testing") do |n| options[:load_test_state] = true end
          p.separator ""
          p.separator "Datamapper options:"
          p.on("--dm-db URL", "Datamapper database [#{options[:dm_db]}]") do |u| options[:dm_db] = u end
          p.on("--dm-log FILE", "Datamapper log file [#{options[:dm_log]}]") do |n| options[:dm_log] = n end
          p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end
          p.separator ""
        end,
        :pre_run => lambda do |opts|
          init_logger()
          init_data_mapper(opts)
          load_test_state(opts) if opts[:load_test_state]
        end
      }


      #Thin::Logging.debug = true
      require 'omf_common/thin/runner'
      OMF::Common::Thin::Runner.new(ARGV, opts).run!
    end
  end # class
end # module




