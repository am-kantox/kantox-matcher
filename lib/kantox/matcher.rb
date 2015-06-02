require 'webmachine'
require 'rethinkdb'

require 'kantox/matcher/version'
require 'kantox/matcher/externals'

module Kantox
  module Matcher
    RATE_CHANGE_TIMESLICE = 3.0    # secs
    CLAIM_CHANGE_TIMESLICE = 0.01  # secs
    BROKER_TIMESLICE = 5.0         # secs

    KANTOX_DB = 'test'
    KANTOX_RATE_TABLE = 'rates'
    KANTOX_CLAIM_TABLE = 'claims'
    KANTOX_MATCH_TABLE = 'matches'

    KANTOX_MATCHER_APP_IP = '127.0.0.1'
    KANTOX_MATCHER_APP_PORT = '3009'

    unless const_defined?('LOGGER')
      LOGGER = Logger.new(STDOUT)
    end

    BROKER_MX = Mutex.new

    begin
      CONN = r.connect(:host => '127.0.0.1', :port => 28015)
    rescue Exception => err
      LOGGER.error 'Cannot connect to RethinkDB at localhost:28015'
      raise err
    end


    class Env
      class << self
        def instance
          @@instance ||= Env.new
        end
        def rate
          instance.rate
        end
        def claims
          instance.claims
        end
      end

      attr_reader :threads
      def initialize
        r.db(KANTOX_DB).table_drop(KANTOX_RATE_TABLE).delete.run(CONN) rescue nil
        r.db(KANTOX_DB).table_drop(KANTOX_CLAIM_TABLE).delete.run(CONN) rescue nil
        r.db(KANTOX_DB).table_drop(KANTOX_MATCH_TABLE).delete.run(CONN) rescue nil

        r.db(KANTOX_DB).table_create(KANTOX_CLAIM_TABLE).run(CONN)
        r.db(KANTOX_DB).table(KANTOX_CLAIM_TABLE).index_create('time').run(CONN)
        r.db(KANTOX_DB).table(KANTOX_CLAIM_TABLE).index_create('status').run(CONN)
        r.db(KANTOX_DB).table(KANTOX_CLAIM_TABLE).index_create('currency').run(CONN)

        r.db(KANTOX_DB).table_create(KANTOX_RATE_TABLE).run(CONN)
        r.db(KANTOX_DB).table(KANTOX_RATE_TABLE).index_create('time').run(CONN)

        r.db(KANTOX_DB).table_create(KANTOX_MATCH_TABLE).run(CONN)
        r.db(KANTOX_DB).table(KANTOX_MATCH_TABLE).index_create('time').run(CONN)

        Thread.abort_on_exception = true

        @matcher = ->(now, claims) { claims.select { |claim| DateTime.parse(claim['deadline']) <= now } }
        @threads = {
          rate_producer: Kantox::Matcher::Externals::Rate.go(RATE_CHANGE_TIMESLICE),
          rate_listener: Kantox::Matcher::Externals::RateTrigger.go,
          claim_producer: Kantox::Matcher::Externals::Claim.go(CLAIM_CHANGE_TIMESLICE),
          claim_listener: Kantox::Matcher::Externals::ClaimTrigger.go,
          broker: Kantox::Matcher::Externals::Broker.go(
            BROKER_TIMESLICE,
            Env.instance_method(:rate).bind(self),
            Env.instance_method(:claims).bind(self),
            @matcher
          )
        }
      end

      def rate
        @threads[:rate_listener][:rate]
      end
      def claims
        @threads[:claim_listener][:claims]
      end
      private :initialize
    end

    class Howdy < Webmachine::Resource
      def allowed_methods
        ['GET']
      end

      def content_types_provided
        [['application/json', :to_json]]
      end

      def resource_exists?
        true
      end

      def to_json
        Env.instance.claims.to_json
      end
    end

    App = Webmachine::Application.new do |app|
      app.routes do
        # This can be any path as long as it ends with :*
        add ['trace', :*], Webmachine::Trace::TraceResource

        add [:howdy], Howdy
      end

      app.configure do |config|
        config.ip      = KANTOX_MATCHER_APP_IP
        config.port    = KANTOX_MATCHER_APP_PORT
        config.adapter = :Reel
      end
    end
  end
end
