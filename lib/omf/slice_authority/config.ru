

REQUIRE_LOGIN = false

require 'rack/file'
class MyFile < Rack::File
  def call(env)
    c, h, b = super
    #h['Access-Control-Allow-Origin'] = '*'
    [c, h, b]
  end
end

require 'omf-sfa/resource/oresource'
OMF::SFA::Resource::OResource.href_resolver do |res, o|
  unless @http_prefix ||=
    @http_prefix = "http://#{Thread.current[:http_host]}"
  end
  case res.resource_type.to_sym
  when :slice
    "#@http_prefix/slices/#{res.uuid}"
  when :slice_member
    "#@http_prefix/slices/#{res.slice.uuid}/slice_members/#{res.uuid}"
  else
    "#@http_prefix/resources/#{res.uuid}"
  end
end

opts = OMF::Common::Thin::Runner.instance.options

require 'omf-sfa/am/am-rest/session_authenticator'
use OMF::SFA::AM::Rest::SessionAuthenticator, #:expire_after => 10,
          :login_url => (REQUIRE_LOGIN ? '/login' : nil),
          :no_session => ['^/$', '^/login', '^/logout', '^/readme', '^/assets']

map '/' do
  p = lambda do |env|
    http_prefix = "http://#{env["HTTP_HOST"]}"
    toc = {}
    [:slices].each do |s|
      toc[s] = "#{http_prefix}/#{s}"
    end
    return [200 ,{'Content-Type' => 'application/json'}, JSON.pretty_generate(toc)]
  end
  run p
end

map '/slices' do
  require 'omf/slice_authority/slice_handler'
  run opts[:slice_handler] || OMF::SliceAuthority::SliceHandler.new(opts)
end

if REQUIRE_LOGIN
  map '/login' do
    require 'omf-sfa/am/am-rest/login_handler'
    run OMF::SFA::AM::Rest::LoginHandler.new(opts[:am][:manager], opts)
  end
end

map "/readme" do
  require 'bluecloth'
  s = File::read(File.dirname(__FILE__) + '/../../../REST_API.md')
  frag = BlueCloth.new(s).to_html
  wrapper = %{
<html>
  <head>
    <title>GIME Experiment Manager API</title>
    <link href="/assets/css/default.css" media="screen" rel="stylesheet" type="text/css">
    <style type="text/css">
   circle.node {
     stroke: #fff;
     stroke-width: 1.5px;
   }

      line.link {
        stroke: #999;
        stroke-opacity: .6;
        stroke-width: 2px;

      }
</style>
  </head>
  <body>
%s
  </body>
</html>
}
  p = lambda do |env|
  puts "#{env.inspect}"

    return [200, {"Content-Type" => "text/html"}, [wrapper % frag]]
  end
  run p
end

map '/assets' do
  run MyFile.new(File.dirname(__FILE__) + '/../../../share/assets')
end

map "/" do
  handler = Proc.new do |env|
    req = ::Rack::Request.new(env)
    case req.path_info
    when '/'
      http_prefix = "http://#{env["HTTP_HOST"]}"
      toc = {}
      [:slices].each do |s|
        toc[s] = "#{http_prefix}/#{s}"
      end
      [200 ,{'Content-Type' => 'application/json'}, "#{JSON.pretty_generate(toc)}\n"]
    when '/favicon.ico'
      [301, {'Location' => '/assets/image/favicon.ico', "Content-Type" => ""}, ['Next window!']]
    else
      OMF::Common::Loggable.logger('rack').warn "Can't handle request '#{req.path_info}'"
      [401, {"Content-Type" => ""}, "Sorry!"]
    end
  end
  run handler
end

