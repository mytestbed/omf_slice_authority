require 'spec_helper'
require_relative '../lib/omf/slice_service/speaks_for_rack'

describe OMF::SliceService::SpeaksForRack do
  let(:inner_app) { double('app', call: [200, {}, ['Body']]) }
  let(:app) { described_class.new(inner_app) }

  context "when requesting /speaks_fors" do
    context "POST" do
      context "with malformed request / invalid credentials" do
        it "should not accept request without urn" do
          post "/speaks_fors"
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("Missing 'urn'")
        end
        it "should error without asssociated xml credential" do
          post "/speaks_fors/_some_tag_", nil, format: :xml
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("Can't find credential in body")
        end
        it "should error with invalid credential and format" do
          post "/speaks_fors/_some_tag_", "{'speaks_for': 'some json'}", format: :json
        end
        it "should reject if expired credential" do
          data = File.read('spec/fixtures/expired_speaks_for_credential.xml')
          post "/speaks_fors/_some_tag_", data, format: :xml
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('Credential already expired')
        end
        it "should reject without expired field specified in credential xml" do
          data = File.read('spec/fixtures/speaks_for_credential_without_expiry.xml')
          post "/speaks_fors/_some_tag_", data, format: :xml
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('Missing "expires"')
        end
      end
      context "with valid credential" do
        before(:each) do
          data = File.read('spec/fixtures/valid_speaks_for_credential.xml')
          post "/speaks_fors/_some_tag_", data, format: :xml
        end
        it "should accept with valid credential" do
          expect(last_response.status).to eq(200)
        end
        it "should set session with valid credential" do
          expect(last_request.env['rack.session'][:speaks_for]).not_to be_empty
        end
      end
    end
    context "GET" do
      context "with malformed request / invalid credentials" do
        it "should return error if urn is not a valid session key" do
          session = create_session_by_name('_some_tag_')
          get "/speaks_fors/_tag_mismatch_", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => session } } }
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("Unknown credential '_tag_mismatch_'")
        end
      end
      context "with valid credentials" do
        it "should return credentials for specified tag" do
          session = create_session_by_name('_some_tag_')
          get "/speaks_fors/_some_tag_", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => session } } }
          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to eq('text/xml')
          expect(last_response.body).to eq(session[:cred])
        end
        it "should return a list of all credentials for the current session in json" do
          session1 = create_session_by_name('_some_tag_')
          session2 = create_session_by_name('_some_other_tag_')
          get "/speaks_fors", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => session1, '_some_other_tag_' => session2 } } }
          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to eq('application/json')
          returned_json = JSON.parse(last_response.body)
          expect(returned_json.count).to eq(2)
          expect(returned_json).to eq([{"urn"=>"_some_tag_", "url"=>"/speaks_fors/_some_tag_"}, {"urn"=>"_some_other_tag_", "url"=>"/speaks_fors/_some_other_tag_"}])
        end
      end
    end
    context "DELETE" do
      context "with malformed request / invalid credentials" do
        it "should return error if urn not provided" do
          delete "/speaks_fors"
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("Missing 'urn'")
        end
      end
      context "with valid credentials" do
        it "should delete session specified by urn tag" do
          session = create_session_by_name('_some_tag_')
          delete "/speaks_fors/_some_tag_", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => session } } }
          expect(last_request.env['rack.session'][:speaks_for]['_some_tag_']).to be nil
        end
        it "should only delete the session specified by urn tag" do
          session = create_session_by_name('_some_tag_')
          session2 = create_session_by_name('_some_other_tag_')
          delete "/speaks_fors/_some_tag_", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => session, '_some_other_tag_' => session2 } } }
          expect(last_request.env['rack.session'][:speaks_for]['_some_tag_']).to be nil
          expect(last_request.env['rack.session'][:speaks_for]['_some_other_tag_']).not_to be nil
        end
      end
    end
  end
  context "on subsequent requests with a speaks_for session" do
    before(:each) do
      @session = create_session_by_name('_some_tag_')
      @session2 = create_session_by_name('_some_other_tag_')
    end
    it "should set Thread.current[:speaks_for] with urn key session" do
      Thread.current.should_receive(:[]=).with(:speaks_for, @session)
      get "/users", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => @session } } }
      expect(last_response.status).to eq(200)
    end
    it "should return error when multiple sessions exist and X-SPEAKS-FOR is not set" do
      get "/users", {}, { 'rack.session' => { speaks_for: {'_some_tag_' => @session, '_some_other_tag_' => @session2} } }
      expect(last_response.status).to eq(400)
      expect(last_response.body).to eq('Need to specify urn in X-SPEAKS-FOR header')
    end
    it "should set Thread.current[:speaks_for] with specified urn set in X-SPEAKS-FOR header" do
      Thread.current.should_receive(:[]=).with(:speaks_for, @session2)
      get "/users", {}, { 'HTTP_X_SPEAKS_FOR' => '_some_other_tag_', 'rack.session' => { speaks_for: { '_some_tag_' => @session, '_some_other_tag_' => @session2 } } }
      expect(last_response.status).to eq(200)
    end
    it "should re-validate expired sessions" do
      @session[:expires] = Time.now - 300
      get "/users", {}, { 'rack.session' => { speaks_for: { '_some_tag_' => @session } } }
      expect(last_response.status).to eq(400)
    end
  end
end

def create_session_by_name(name)
  { urn: name,
    expires: Time.now + 300,
    cred: File.read('spec/fixtures/valid_speaks_for_credential.xml')
  }
end