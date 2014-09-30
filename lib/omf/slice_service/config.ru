
require 'active_support/inflector'

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
ActiveSupport::Inflector.inflections.irregular('slice', 'slices')
OMF::SFA::Resource::OResource.href_resolver do |res, o|
  rtype = res.resource_type.to_sym
  unless [:slice, :sliver, :user, :slice_member, :authority].include?(rtype)
    rtype = :resource
  end
  case rtype
  when :slice_members
    "http://#{Thread.current[:http_host]}/users/#{res.user.uuid}/slice_members/#{res.uuid}"
  else
    "http://#{Thread.current[:http_host]}/#{rtype.to_s.pluralize}/#{res.uuid}"
  end
end

opts = OMF::Base::Thin::Runner.instance.options

require 'rack/cors'
use Rack::Cors, debug: true do
  allow do
    origins '*'
    resource '*', :headers => :any, :methods => [:get, :post, :options]
  end
end

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
  require 'omf/slice_service/slice_handler'
  run opts[:slice_handler] || OMF::SliceService::SliceHandler.new(opts)
end

map '/slivers' do
  require 'omf/slice_service/sliver_handler'
  run opts[:sliver_handler] || OMF::SliceService::SliverHandler.new(opts)
end

map '/users' do
  require 'omf/slice_service/user_handler'
  run opts[:user_handler] || OMF::SliceService::UserHandler.new(opts)
end

map '/slice_members' do
  require 'omf/slice_service/slice_member_handler'
  run opts[:slice_member_handler] || OMF::SliceService::SliceMemberHandler.new(opts)
end

map '/authorities' do
  require 'omf/slice_service/authority_handler'
  run opts[:authority_handler] || OMF::SliceService::AuthorityHandler.new(opts)
end

map '/promises' do
  require 'omf-sfa/am/am-rest/promise_handler'
  run OMF::SFA::AM::Rest::PromiseHandler.new(opts)
end

map '/manifests' do
  p = lambda do |env|
    req = ::Rack::Request.new(env)
    obj_id = req.path_info.split('/')[-1]
    q = OMF::SFA::AM::Rest::RestHandler.parse_resource_uri(obj_id)
    sliver = OMF::SliceService::Resource::Sliver.first(q)
    unless sliver
      return [401, {"Content-Type" => ""}, "Unknown resource '#{obj_id}'"]
    end
    case req.request_method
    when 'GET'
      if manifest = sliver.manifest
        [200, {'Content-Type' => 'text/xml'}, manifest]
      else
        [204, {}, '']
      end
    else
      [400, {}, '']
    end
  end
  run p
end

map '/speaks_fors' do
  p = lambda do |env|
    req = ::Rack::Request.new(env)
    obj_id = req.path_info.split('/')[-1]
    #puts "OBJ_ID: #{obj_id}"
    q = OMF::SFA::AM::Rest::RestHandler.parse_resource_uri(obj_id)
    #puts "QQQQ: #{q}"
    user = OMF::SliceService::Resource::User.first(q)
    #puts "USER: #{user}"
    unless user
      return [401, {"Content-Type" => ""}, "Unknown resource '#{obj_id}'"]
    end
    case req.request_method
    when 'GET'
      if speaks_for = user.speaks_for.to_s
        #speaks_for = speaks_for.string if speaks_for.is_a?(StringIO)
        [200, {'Content-Type' => 'text/xml'}, speaks_for]
      else
        [204, {}, '']
      end
    when 'POST', 'PUT'
      body = req.body
      body = body.string if body.is_a?(StringIO)
      if body.empty?
        [400, {"Content-Type" => "text"}, "Can't find credential in body"]
      else
        user.speaks_for = body
        user.save
        [200, {'Content-Type' => 'text'}, 'OK']
      end
    when 'DELETE'
      user.speaks_for = nil
      user.save
      [200, {'Content-Type' => 'text'}, 'OK']
    end
  end
  run p
end

map '/slice_credentials' do
  p = lambda do |env|
    req = ::Rack::Request.new(env)
    obj_id = req.path_info.split('/')[-1]
    q = OMF::SFA::AM::Rest::RestHandler.parse_resource_uri(obj_id)
    sm = OMF::SliceService::Resource::SliceMember.first(q)
    unless sm
      return [401, {"Content-Type" => ""}, "Unknown resource '#{obj_id}'"]
    end
    case req.request_method
    when 'GET'
      if cred = sm.slice_credential.to_s
        [200, {'Content-Type' => 'text'}, cred]
      else
        [204, {}, '']
      end
    end
  end
  run p
end

if REQUIRE_LOGIN
  map '/login' do
    require 'omf-sfa/am/am-rest/login_handler'
    run OMF::SFA::AM::Rest::LoginHandler.new(opts[:am][:manager], opts)
  end
end

map "/readme" do
  require 'bluecloth'
  p = lambda do |env|
    s = File::read(File.dirname(__FILE__) + '/../../../README.md')
    frag = BlueCloth.new(s).to_html
    page = {
      service: '<h2><a href="/?_format=html">ROOT</a>/<a href="/readme">Readme</a></h2>',
      content: frag.gsub('http://localhost:8002', "http://#{env["HTTP_HOST"]}")
    }
    [200 ,{'Content-Type' => 'text/html'}, OMF::SFA::AM::Rest::RestHandler.render_html(page)]
  end
  run p
end

map '/assets' do
  run MyFile.new(File.dirname(__FILE__) + '/../../../share/assets')
end

map '/version' do
  l = lambda do |env|
    reply = {
      service: 'SliceService',
      version: OMF::SliceService.version
    }
    [200 ,{'Content-Type' => 'application/json'}, JSON.pretty_generate(reply) + "\n"]
  end
  run l
end

map "/" do
  handler = Proc.new do |env|
    req = ::Rack::Request.new(env)
    case req.path_info
    when '/'
      http_prefix = "http://#{env["HTTP_HOST"]}"
      toc = ['README', :slices, :users, :authorities].map do |s|
        "<li><a href='#{http_prefix}/#{s.to_s.downcase}?_format=html&_level=0'>#{s}</a></li>"
      end
      page = {
        service: 'Slice Service',
        content: "<ul>#{toc.join("\n")}</ul>"
      }
      [200 ,{'Content-Type' => 'text/html'}, OMF::SFA::AM::Rest::RestHandler.render_html(page)]
    when '/favicon.ico'
      [301, {'Location' => '/assets/image/favicon.ico', "Content-Type" => ""}, ['Next window!']]
    else
      OMF::Base::Loggable.logger('rack').warn "Can't handle request '#{req.path_info}'"
      [401, {"Content-Type" => ""}, "Sorry!"]
    end
  end
  run handler
end


