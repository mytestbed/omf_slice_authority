require 'rack/request'
require 'rack/utils'

module OMF::SliceService
  class SpeaksForRack < OMF::Base::LObject
    URN_FORMAT = /\Aurn:publicid:IDN\+ch\.geni\.net\+user\+[a-z]{1,8}\z/.freeze
    def initialize(app, options={})
      @app = app
      @opts = options
    end

    def call(env)
      path_info = ::Rack::Utils.unescape(env['PATH_INFO'])
      #puts ">> PATH_INFO: #{path_info}"
      if path_info.start_with? '/speaks_fors'
        process(env)
      else
        if error = set_speaks_for(env)
          return error
        end
        @app.call(env)
      end
    end

    # Provide the requested or default speaks_for credential as a
    # thread variable ':speaks_for'
    #
    def set_speaks_for(env)
      session = env['rack.session'][:speaks_for]
      return unless session
      return if session.empty?

      speaks_for = nil
      if urn = env['HTTP_X_SPEAKS_FOR']
        speaks_for = session[urn]
      else
        # if there is only one speaks_for registered use it
        if session.length > 1
          return [400, {'Content-Type' => 'text'}, 'Need to specify urn in X-SPEAKS-FOR header']
        end
        urn, speaks_for = session.first
      end

      # TODO: Check expiration time
      unless speaks_for[:expires] > (Time.now + 60)
        return [400, {'Content-Type' => 'text'}, 'Speaks-for credential already expired']
      end

      Thread.current[:speaks_for] = speaks_for
      nil
    end

    # Process a request for operating on speaks_for credentials
    #
    def process(env)

      req = ::Rack::Request.new(env)
      urn = req.path_info.split('/')[2]
      session = req.session[:speaks_for] ||= {}
      case req.request_method
        when 'GET'
          if urn
            if urn !~ URN_FORMAT
              [400, {"Content-Type" => "text"}, "Invalid 'urn' format"]
            elsif s = session[urn]
              [200, {'Content-Type' => 'text/xml'}, s[:cred]]
            else
              [400, {"Content-Type" => "text"}, "Unknown credential '#{urn}'"]
            end
          else
            list = session.keys.map do |urn|
              {urn: urn, url: "/speaks_fors/#{urn}"}
            end
            [200, {'Content-Type' => 'application/json'}, list.to_json]
          end

        when 'POST', 'PUT'
          if !urn
            return [400, {"Content-Type" => "text"}, "Missing 'urn'"]
          elsif urn !~ URN_FORMAT
            return [400, {"Content-Type" => "text"}, "Invalid 'urn' format"]
          end
          body = req.body
          body = body.string if body.is_a?(StringIO)
          if body.empty?
            return [400, {"Content-Type" => "text"}, "Can't find credential in body"]
          end
          begin
            doc = REXML::Document.new(body)
            expires = nil
            doc.elements.each('//credential/expires') {|e| expires = Time.parse(e.text) }
            unless expires
              return [400, {'Content-Type' => 'text'}, 'Missing "expires"']
            end
            if expires <= Time.now
              return [400, {'Content-Type' => 'text'}, 'Credential already expired']
            end
            session[urn] = {
              urn: urn,
              expires: expires,
              cred: body
            }
          rescue
            return [400, {'Content-Type' => 'text'}, "Doesn't look like a credential" ]
          end
          [200, {'Content-Type' => 'text'}, 'OK']

        when 'DELETE'
          if !urn
            return [400, {"Content-Type" => "text"}, "Missing 'urn'"]
          elsif urn !~ URN_FORMAT
            return [400, {"Content-Type" => "text"}, "Invalid 'urn' format"]
          end
          session.delete urn
          [200, {'Content-Type' => 'text'}, 'OK']
      end
    end

  end
end