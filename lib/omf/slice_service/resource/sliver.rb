require 'omf/slice_service/resource'
require 'omf-sfa/resource/oresource'
require 'omf-sfa/util/graph_json'
require 'time'
require 'open-uri'

module OMF::SliceService::Resource
  class UnknownAuthorityException < OMF::SliceService::SliceServiceException; end
  class DiscardedSliverException < OMF::SliceService::SliceServiceException; end

  # This class represents a sliver in the system.
  #
  class Sliver < OMF::SFA::Resource::OResource
    STATUS_CHECK_INTERVAL = 60 # after what time should we check again for sliver status

    oproperty :status, String
    oproperty :status_checked_at, DataMapper::Property::Time
    oproperty :resources, Object
    oproperty :manifest, String  # actually XML
    oproperty :log_url, String # URL provided by AM to obtain more information
    oproperty :expires_at, DataMapper::Property::Time
    oproperty :created_at, DataMapper::Property::Time
    oproperty :description, String
    oproperty :rspec, String
    oproperty :slice, :reference, type: :slice
    oproperty :authority, :reference, type: :suthority

    oproperty :slice_member, :reference, type: :slice_member # TODO: Security alert - keep around for checking status

    def self.create_for_component_manager(cm_urn, rspec, slice_member)
      unless authority = Authority.first(urn: cm_urn)
        warn "Trying to create sliver on unknown authority '#{cm_urn}'"
        raise UnknownAuthorityException.new(cm_urn)
      end
      sliver = self.create(authority: authority, slice: slice_member.slice)
      sliver.slice_member = slice_member # TODO: Security alert

      Task::CreateSliver(authority, rspec, slice_member).on_success do |reply|
        #puts ">>>>>>>>>>>>>>>>>>>>SLIVER>>>> #{reply}"
        sliver.manifest = m = reply[:manifest]
        if log_url = reply[:err_url]
          sliver.log_url = log_url
        end
      end.on_error do |err_code, msg|
        puts ">>>>>>>>>>>>>>>>>>>>SLIVER ERRRO >>>> #{msg} - #{err_code}"
#        promise.reject(err_code, msg)
      end.on_always do
        sliver.save
      end
      sliver
    end

    # TODO: Should we issue a DeleteSliver task?
    def release!
      self.status == 'discarded'
      self.save
    end

    alias :_status :status
    def status(refresh = false)
      return 'discarded' if discarded?

      #puts ">>>> GETTING STATUS - #{refresh.inspect}"
      return @status_promise if @status_promise

      promise =  OMF::SFA::Util::Promise.new
      min_time = 30 # make sure we don't overload the server here
      if (Time.now - (self.status_checked_at || 0)).to_i > (refresh ? min_time : STATUS_CHECK_INTERVAL)
        @status_promise = promise # pending
        self.status_checked_at = Time.now
        puts ">>>> NEED TO CHECK FOR SLICE_STATUS"
        OMF::SliceService::Task::SliverStatus(self, self.slice_member).on_success do |res|
          puts ">>>>> SLIVER_STATUS #{res}"
          ready_count = 0
          error_count = 0
          self.resources = res['geni_resources'].map do |r|
            case status = r["geni_status"]
            when 'ready'
              ready_count += 1
            else
              error_count += 1
            end
            {
              status: status,
              urn: r["geni_urn"],
              error: r["geni_error"],
              client_id: r["geni_client_id"] || 'unknown'
            }
          end
          self.status = status = error_count == 0 ? 'ready' : 'partial'
          if expires_s = res["pg_expires"]
            self.expires = Time.parse(expires_s)
          end
          self.save
          @status_promise = nil
          promise.resolve(status)
        end.on_error do |code, ex|
          puts ">>>> STATUS FAILED: #{ex}"
          @status_promise = nil
          if ex.is_a? OMF::SliceService::Task::SliverNotFoundException
            puts ">>>> SLIVER NOT THERE: #{ex}"
            self.release!
            promise.resolve(status)
          else
            promise.reject(code, ex)
          end
        end
      else
        promise.resolve self._status
      end
      promise
    end

    def discarded?
      self._status == 'discarded'
    end

    def expired?
      self.expires_at < Time.now
    end

    def to_hash_long(h, objs, opts = {})
      raise DiscardedSliverException.new if discarded?
      super
      #
      #h[:status] = self.status(opts[:refresh] == true)
      h
    end

    def to_hash_brief(opts = {})
      raise DiscardedSliverException.new if discarded?
      h = super
      #h[:urn] = self.urn || 'unknown'
      h
    end

    def initialize(opts)
      super
      self.status = :unknown
      self.created_at = Time.now
    end
  end # classs
end # module
