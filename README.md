# Kantox::Matcher

Example of Reactor pattern implementation on pure `Threads` and `Mutices`.

`RethinkDB` as a backend: prerequisite.

## Installation

Make sure you have RethinkDB server installed and running.

Download `kantox-matcher`, run `bundle` and execute `bin/serve` script.

## Usage

    DEBUG=true MATCHER_DAEMON=true bin/serve

The `DEBUG` option turns debugging output on (too many garbage, line is spitted
out once per transaction.) Setting `MATCHER_DAEMON` env var to `true` results in
no webserver startup.

To view current matches:

    http://localhost:3009/howdy

To examine rethink database:

    http://127.0.0.1:8080/#dataexplorer

## Matching algorithm

Legend: is a subject of rework; currently matches expires only.

Reality: to be written from scratch, but it is clearly encapsulated and
already supports different matchers.
