require 'rethinkdb'
include RethinkDB::Shortcuts

module Kantox
  module Matcher
    module Externals
      module ClaimTrigger
        def go
          Thread.new do
            begin
              r.db(Kantox::Matcher::KANTOX_DB).table(KANTOX_CLAIM_TABLE).changes.run(CONN).each do |change|
                next unless change['new_val'] # do nothing on deletion
                Thread.current[:claims] ||= []
                BROKER_MX.synchronize do
                  LOGGER.debug "=[ CLAIM ]=> #{change}"
                  case change['new_val']['status']
                  when 'created' then Thread.current[:claims] << change['new_val']
                  when 'matched' then Thread.current[:claims].reject! { |claim| claim['id'] == change['new_val']['id'] }
                  end
                end
              end
            rescue RethinkDB::RqlRuntimeError => err
              LOGGER.error "Error occurred in changefeed in #{KANTOX_CLAIM_TABLE} table within #{KANTOX_DB}"
              raise err
            end
          end
        end
        module_function :go
      end
    end
  end
end
