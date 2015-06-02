require 'rethinkdb'
include RethinkDB::Shortcuts

module Kantox
  module Matcher
    module Externals
      module Broker
        def go interval, rater, claimer, matcher
          Thread.new do
            loop do
              BROKER_MX.synchronize do
                rate, claims, now = rater.call, claimer.call, DateTime.now
                LOGGER.debug "Starting match recalc. Rate is: #{rate}. Claims are: #{claims}"

                if claims
                  unless (todo = matcher.call(now, claims)).empty?
                    in_claim = r.db(Kantox::Matcher::KANTOX_DB)
                                .table(KANTOX_CLAIM_TABLE)
                                .get_all(*todo.map { |claim| claim['id'] })
                                .update(status: :matched)
                                .run(CONN)

                    todo.map! { |td| td.delete('status'); td.merge(matched: now.to_s) }
                    in_match = r.db(KANTOX_DB).table(KANTOX_MATCH_TABLE).insert(todo).run(CONN)
                    LOGGER.info "=[MATCH]==> in claims: ⥃ [#{in_claim['replaced']}]; in matches: ⥂ [#{in_match['inserted']}]"
                  end
                end
              end
              sleep interval
            end
          end
        end
        module_function :go
      end
    end
  end
end
