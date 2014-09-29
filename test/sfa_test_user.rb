
require 'pp'
require "eventmachine"
require "em-xmlrpc-client"
XMLRPC::Config.send(:remove_const, :ENABLE_NIL_PARSER)
XMLRPC::Config.const_set(:ENABLE_NIL_PARSER, true)


def get_client(url)
  client = XMLRPC::Client.new2(url)
  client.ssl_options = {
      private_key_file: '/Users/max/.gcf/max-geni.key.cert',
      cert_chain_file: '/Users/max/.gcf/max-geni.key.cert',
      verify_peer: false,

      # only for non-EM mode
      ca_file: '/Users/max/.gcf/trusted_roots/GPO.crt' #CATedCACertsX.pem'
  }
  # client.ssl_options = {
  #   private_key_file: '/Users/max/src/omf_slice_service/etc/omf-slice-service/certs/testing.local.key',
  #   cert_chain_file: '/Users/max/src/omf_slice_service/etc/omf-slice-service/certs/testing.local.key',
  #   verify_peer: false,
  #
  #   # only for non-EM mode
  #   ca_file: '/Users/max/src/omf_slice_service/etc/omf-slice-service/certs/trusted_roots.crt' #CATedCACertsX.pem'
  # }

  client
end

def run
  client = get_client("https://ch.geni.net:8444/CH")
  #opts = {'filter' => ['SERVICE_URN', 'SERVICE_URL']}
  opts = {filter: ['SERVICE_URN', 'SERVICE_URL']}
  #pp client.call("lookup_slice_authorities", opts)
  #pp client.call("lookup_aggregates", opts)

  client2 = get_client("https://ch.geni.net/SA")
  opts = {match: {SLICE_EXPIRED: false}}
  opts = {match: {SLICE_EXPIRED: true}}
  pp client2.call('lookup_slices_for_member', 'urn:publicid:IDN+ch.geni.net+user+maxott', [], opts)
end

def run2
  opts = {speaks_for: 'urn:publicid:IDN+ch.geni.net+user+maxott'}
  slice = "urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+foo99"
  certs = [{
             geni_type: 'geni_abac',
             geni_version: 1,
             geni_value: File.read(File.join(File.dirname(__FILE__), 'maxott_speaks_for3.xml'))
           }, {
             geni_type: 'geni_sfa',
             geni_version: 3,
             geni_value: File.read(File.join(File.dirname(__FILE__), 'maxott_slice_cred_foo99.xml'))
           }]
  rspec = '<?xml version=\"1.0\"?>\n<rspec xmlns=\"http://www.geni.net/resources/rspec/3\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:ol=\"http://nitlab.inf.uth.gr/schema/sfa/rspec/1\" xmlns:omf=\"http://schema.mytestbed.net/sfa/rspec/1\" xmlns:exo_sliver=\"http://groups.geni.net/exogeni/attachment/wiki/RspecExtensions/sliver-info/1\" xmlns:exo_slice=\"http://groups.geni.net/exogeni/attachment/wiki/RspecExtensions/slice-info/1\" type=\"request\" generated=\"2014-08-20T20:06:37+10:00\">\n  <node id=\"8ec2c565-c3b5-452c-be2b-d58d18fe590b\" uuid=\"8ec2c565-c3b5-452c-be2b-d58d18fe590b\" client_id=\"r70243959251620\" exclusive=\"true\">\n    <services/>\n    <sliver_type uuid=\"4ff695fe-42f5-4253-ab91-a43f285bc815\" name=\"tiny\">\n      <disk_image id=\"dda04cc3-fddf-4d3b-a0a3-f4491a829aa4\" uuid=\"dda04cc3-fddf-4d3b-a0a3-f4491a829aa4\" name=\"gimi.iso\"/>\n    </sliver_type>\n  </node>\n</rspec>\n'
  #client = get_client("https://www.emulab.net:12369/protogeni/xmlrpc/am/3.0")
  #pp client.call("Allocate", slice, certs, rspec, [], opts)
  client = get_client("https://rci-hn.exogeni.net:11443/orca/xmlrpc")
  pp client.call("CreateSliver", slice, certs, rspec, [], opts)
end


def run3
  client = get_client("https://www.emulab.net:12369/protogeni/xmlrpc/am/3.0")
  pp client.call("GetVersion")
  #client = get_client("https://ch.geni.net:8444/CH")
  #pp client.call("get_version")
end

def run_em
  EM.run do
    Fiber.new do
      run3
    end.resume
    #puts ">>>>>>> DONE"
  end
end

run_em
#run3

