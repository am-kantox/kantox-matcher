require 'rethinkdb'
include RethinkDB::Shortcuts

module Kantox
  module Matcher
    module Externals
      module RateTrigger
        def go
          Thread.new do
            begin
              r.db(Kantox::Matcher::KANTOX_DB).table(KANTOX_RATE_TABLE).changes.run(CONN).each do |change|
                next unless change['new_val'] # skip initialization artefacts / deal with updates/unserts only
                BROKER_MX.synchronize do
                  LOGGER.debug "=[ RATE ]=> #{change}"
                  Thread.current[:rate] = change['new_val']['rate']
                end
              end
            rescue RethinkDB::RqlRuntimeError => err
              LOGGER.error "Error occurred in changefeed in #{KANTOX_RATE_TABLE} table within #{KANTOX_DB}"
              raise err
            end
          end
        end
        module_function :go
      end
    end
  end
end
