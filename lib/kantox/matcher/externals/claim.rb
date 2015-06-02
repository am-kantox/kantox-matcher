require 'rethinkdb'
include RethinkDB::Shortcuts

module Kantox
  module Matcher
    module Externals
      module Claim
        CLAIM_MIN, CLAIM_MAX = 100_000, 1_000_000   # random claim range
        CLAIM_DELAY = 10 * 1                        # 10 seconds
        def go interval
          Thread.new do
            loop do
              now = Time.now.to_i
              lifetime = Random.rand(now..now+CLAIM_DELAY)
              deadline = DateTime.strptime(lifetime.to_s, "%s").to_s
              LOGGER.debug r.db(KANTOX_DB).table(KANTOX_CLAIM_TABLE).insert(
                time: now,
                currency: [:USD, :EUR].sample,
                amount: Random.rand(CLAIM_MIN..CLAIM_MAX),
                lifetime: lifetime,
                deadline: deadline,
                status: :created
              ).run(CONN)
              sleep interval
            end
          end
        end
        module_function :go
      end
    end
  end
end
