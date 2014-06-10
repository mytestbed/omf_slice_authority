require 'rubygems'

require 'json'

require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'data_mapper'
require 'omf_base/lobject'
require 'omf_base/load_yaml'

require 'omf-sfa/am/am_runner'
#require 'omf-sfa/am/am_manager'
#require 'omf-sfa/am/am_scheduler'

require 'omf/slice_authority/version'
module OMF::SliceAuthority

  class Server
    # Don't use LObject as we haveb't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Base::Loggable
    extend OMF::Base::Loggable

    ETC_DIR = File.join(File.dirname(__FILE__), '/../../../etc/omf-slice-authority')

    def init_logger(options)
      OMF::Base::Loggable.init_log 'server', :searchPath => File.join(File.dirname(__FILE__), 'server')
      info "Slice Service V #{OMF::SliceAuthority.version}"
    end

    def init_data_mapper(options)
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

    def init_authorization(opts)
      return # TODO: What should happen below?

      require 'json/jwt'
      require 'omf_common'
      require 'omf_common/auth'
      require 'omf_common/auth/certificate_store'
      store = OmfCommon::Auth::CertificateStore.init(opts)
      root = OmfCommon::Auth::Certificate.create_root()

      #adam = root.create_for_user('adam')
      projectA_cert = root.create_for_resource('projectA', :project)
      msg = {cnt: "shit", iss: projectA_cert}
      p = JSON::JWT.new(msg).sign(projectA_cert.key , :RS256).to_s
      puts p
    end

    def load_test_state(options)
      require 'omf-sfa/am/am-rest/rest_handler'
      OMF::SFA::AM::Rest::RestHandler.set_service_name("OMF Slice Service")

      require  'dm-migrations'
      DataMapper.auto_migrate!

      p1 = OMF::SFA::Resource::OReference.create(name: 'projectA',
                                        resource_type: :project,
                                        href: 'http://ch.geni.net/projects/projectA')
      s1_uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, 'slice1')
      s1 = OMF::SliceAuthority::Resource::Slice.create(name: 'slice1',
                                        uuid: s1_uuid,
                                        urn: 'urn:publicid:IDN+ch.geni.net:GIMITesting+slice+slice1',
                                        expiration: Time.now + 86400,
                                        email: 'adam@acme.com',
                                        description: 'Adam\'s slice',
                                        project: p1
                                        )
      s1.aggregates << OMF::SFA::Resource::OReference.create(name: 'aggregateX',
                                        resource_type: :aggregate,
                                        href: "http://#{options[:test_omf_am] || 'localhost:8004'}/slices/#{s1.uuid}")
      s1.aggregates << OMF::SFA::Resource::OReference.create(name: 'aggregateY',
                                        resource_type: :aggregate,
                                        href: "http://BOGUS.org/slices/#{s1.uuid}")


      u1 = OMF::SliceAuthority::Resource::User.create(name: 'user1', urn: 'urn:publicid:IDN+ch.geni.net+user+maxott')

      # s1.slice_members << OMF::SliceAuthority::Resource::SliceMember.create(name: 'member1',
                                        # role: 'ADMIN')

      OMF::SliceAuthority::Resource::SliceMember.create(user: u1, slice: s1, role: 'ADMIN')

      # s2 = OMF::SliceAuthority::Resource::Slice.create(name: 'slice2',
                                        # urn: 'default_slice',
                                        # expiration: Time.now + 86400,
                                        # email: 'mary@some.edu',
                                        # description: 'Mary\'s slice')
      # s3 = OMF::SliceAuthority::Resource::Slice.create(name: 'slice3',
                                        # urn: 'default_slice',
                                        # expiration: Time.now + 86400)


      # require 'omf-sfa/resource/user'
      # u1 = OMF::SFA::Resource::User.create(:name => 'user1')
      # u2 = OMF::SFA::Resource::User.create(:name => 'user2', uuid: "a7ecac90-3d4a-498b-927f-f9bee6bb3156")

    end

    def read_config_file(o)
      unless cf = o.delete(:config_file)
        puts "ERROR: Missing config file"
        exit(-1)
      end
      unless File.readable? cf
        puts "ERROR: Can't read config file '#{cf}'"
        exit(-1)
      end
      # This is a bit a hack as the #load method is a bit too smart for this
      f = File.basename(cf)
      d = File.dirname(cf)
      config = (OMF::Base::YAML.load(f, :path => [d])[:slice_authority]) || {}

      defaults = o.delete(:defaults) || {}
      opts = config.merge(o)
      opts = defaults.merge(opts)
      opts[:config_dir] = d
      opts
    end


    def run(opts = DEF_OPTS, argv = ARGV)
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda {
        },
        :pre_parse => lambda do |p, options|
          p.on("--test-load-state", "Load an initial state for testing") do |n| options[:load_test_state] = true end
          p.separator ""
          p.separator "Slice Authority options:"
          p.on("--config FILE", "Slice Authority config file [#{options[:config_file]}]") do |n| options[:config_file] = n end
          p.separator ""
          p.separator "Datamapper options:"
          p.on("--dm-db URL", "Datamapper database [#{options[:defaults][:dm_db]}]") do |u| options[:dm_db] = u end
          p.on("--dm-log FILE", "Datamapper log file [#{options[:defaults][:dm_log]}]") do |n| options[:dm_log] = n end
          p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end
          p.separator ""
        end,
        :pre_run => lambda do |o|
          o = read_config_file(o)
          init_logger(o)
          debug "Options: #{o}"
          init_data_mapper(o)
          init_authorization(o)
          OMF::SliceAuthority.init(o)

          require 'omf-sfa/am/am-rest/rest_handler'
          OMF::SFA::AM::Rest::RestHandler.set_service_name("OMF Slice Authority")
          load_test_state(o) if o[:load_test_state]
        end
      }

      opts[:rackup] ||= File.dirname(__FILE__) + '/config.ru'

      #Thin::Logging.debug = true
      require 'omf_base/thin/runner'
      OMF::Base::Thin::Runner.new(argv, opts).run!
    end


    # def run(opts)
      # opts[:handlers] = {
        # # Should be done in a better way
        # :pre_rackup => lambda {
        # },
        # :pre_parse => lambda do |p, options|
          # p.on("--test-load-state", "Load an initial state for testing") do |n| options[:load_test_state] = true end
          # p.on("--test-omf-am URL", "Top URL for Test OMF AM") do |n| options[:test_omf_am] = n end
          # p.separator ""
          # p.separator "Datamapper options:"
          # p.on("--dm-db URL", "Datamapper database [#{options[:dm_db]}]") do |u| options[:dm_db] = u end
          # p.on("--dm-log FILE", "Datamapper log file [#{options[:dm_log]}]") do |n| options[:dm_log] = n end
          # p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end
          # p.separator ""
        # end,
        # :pre_run => lambda do |opts|
          # init_logger()
          # init_data_mapper(opts)
          # load_test_state(opts) if opts[:load_test_state]
        # end
      # }
#
#
      # #Thin::Logging.debug = true
      # require 'omf_common/thin/runner'
      # OMF::Base::Thin::Runner.new(ARGV, opts).run!
    # end
  end # class
end # module




