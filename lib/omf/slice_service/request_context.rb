
require 'weakref'
require 'uuid'
require 'omf-sfa/util/promise'

# This class provides a mechanism to deal with delayed requests which ultimately lead to an
# error.

module OMF::SliceService

  class RequestContext < OMF::Base::LObject
    @@contexts = {}

    # Each request which could lead to a RetryLaterException should be executed
    # in this context. 'opts' is expected to have a ':request_id' entry which should
    # be a UUID.
    #
    def self.exec(req, expect_promise = true, &block)
      unless id = req.env['HTTP_X_REQUEST_ID']
        id = UUID.new.generate
      end
      # unless id = opts.delete(:_request_id)
      #   if (req = opts[:req]) && req.is_a?(Rack::Request)
      #     #id = req.params['_request_id']
      #     #puts ">>>>>>>>>>>> #{req['_request_id']} - #{req.class}"
      #     id = req.params.delete('_request_id')
      #   end
      #   unless id
      #     warn "Missing 'request_id' in call - #{opts.keys.inspect}"
      #     raise
      #     id = UUID.new.generate
      #   end
      # end
      ctxt = self[id]
      puts "---- CHECKING OLD CONTEXT>>>> #{id} => #{ctxt.promise}"
      unless res = ctxt.promise
        res = block.call
        puts ">>>>RESULT(#{res.is_a?(OMF::SFA::Util::Promise) ? res.status : '?'})>>>> #{res}"
        unless res.is_a?(OMF::SFA::Util::Promise)
          if expect_promise
            raise "Expected a Promise, but got '#{res.class}' - #{res}"
          else
            res = OMF::SFA::Util::Promise.new().resolve(res)
          end
        end
        self[id].promise = res # given that we use weak reference, the above 'ctxt' may already be gone
      end
      # if ctxt.weakref_alive? && ctxt.errors?
      #   raise OMF::SFA::AM::Rest::BadRequestException.new(ctxt.error_msg)
      # end
      case res.status
      when :pending
        Thread.current[:request_context_id] = id
        raise OMF::SFA::AM::Rest::RetryLaterException.new
      when :resolved
        @@contexts.delete(id)
        puts "-----RESULT>>>> #{res.value}"
        return res.value
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new(res.error_msg)
      end
    end

    def self.id
      Thread.current[:request_context_id]
    end

    # def self.[](id)
    #   if ctxt = @@contexts[id]
    #     ctxt = WeakRef.new(self.new) unless ctxt.weakref_alive?
    #   else
    #     ctxt = WeakRef.new(self.new)
    #   end
    #   @@contexts[id] = ctxt
    # end

    def self.[](id)
      unless ctxt = @@contexts[id]
        ctxt = @@contexts[id] = self.new
      end
      ctxt.touched = Time.now
      ctxt
    end

    def self.report_error(request_id_or_opts, msg)
      id = request_id_or_opts.is_a?(Hash) ? request_id_or_opts[:request_id] : request_id_or_opts
      unless id
        warn "Reporting error but missing request ID"
        return
      end
      if msg.is_a?(Hash) && msg.key?('output')
        msg = msg['output']
      end
      self[id].report_error(msg)
    end

    attr_accessor :promise, :touched

  end
end
