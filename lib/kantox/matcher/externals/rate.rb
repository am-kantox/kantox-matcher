require 'rethinkdb'
include RethinkDB::Shortcuts

module Kantox
  module Matcher
    module Externals
      module Rate
        MIN_RATE = 1.0
        MAX_RATE = 2.0
        RATE_STEP = 0.07
        def go interval
          Thread.new do
            Thread.current[:rate] = MIN_RATE
            Thread.current[:step] = :+

            loop do
              Thread.current[:step] = case Thread.current[:rate]
                                      when (-Float::INFINITY..MIN_RATE) then :+
                                      when (MAX_RATE..Float::INFINITY) then :-
                                      else Thread.current[:step]
                                      end
              Thread.current[:rate] = Thread.current[:rate].public_send Thread.current[:step], RATE_STEP
              LOGGER.debug r.db(KANTOX_DB).table(KANTOX_RATE_TABLE).insert(rate: Thread.current[:rate], time: Time.now.to_i).run(CONN)
              sleep interval
            end
          end
        end
        module_function :go
      end
    end
  end
end
