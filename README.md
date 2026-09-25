<p align="center">

  <img src="github-static/logo.png" alt="glacierdb" width="280">

</p>

<h1 align="center">glacierdb</h1>

<p align="center">

<strong>An event-first, schema-less document database built on the openglacier engine.</strong>

</p>

<p align="center">

![Version](https://img.shields.io/badge/version-1.0.1-blue)
[![Build](https://github.com/openglacier/glacierdb/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/openglacier/core/actions/workflows/build.yml)
[![Tests](https://github.com/openglacier/glacierdb/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/openglacier/core/actions/workflows/tests.yml)
[![Clippy](https://github.com/openglacier/glacierdb/actions/workflows/clippy.yml/badge.svg?branch=main)](https://github.com/openglacier/core/actions/workflows/clippy.yml)
[![Audit](https://github.com/openglacier/glacierdb/actions/workflows/audit.yml/badge.svg?branch=main)](https://github.com/openglacier/core/actions/workflows/audit.yml)
![Architectures](https://img.shields.io/badge/release_targets-19-informational)

</p>

> **glacierdb is a database distribution built on openglacier Core.**
>
> It provides a ready-to-run database daemon and CLI with the Glacier persistent storage backend enabled by default.

glacierdb is designed to be used as a database first.

It provides:

* a schema-less document model;
* a declarative, pipeline-oriented query language;
* transactional storage;
* persistent native storage through **Glacier**;
* authentication and identity support;
* event subscriptions;
* memory governance;
* backup and restore;
* an interactive command-line client;
* an optional terminal UI.

Underneath, glacierdb uses the same database engine as openglacier.

```text
                    glacierdb
                       │
                       ▼
              ┌─────────────────┐
              │ openglacier-core│
              │                 │
              │ query engine    │
              │ storage         │
              │ transactions    │
              │ events          │
              │ authentication  │
              └────────┬────────┘
                       │
                       ▼
                Glacier storage
```

The distinction is intentional:

```text
openglacier-core
    │
    └── database engine and resource runtime

glacierdb, aka openglacier-db
    │
    └── database distribution and user-facing binaries
```

glacierdb does not fork or duplicate the database engine.

It consumes the published `openglacier-core` crate.

---

# Quick start

## Docker

```bash
docker pull openglacier/glacierdb
```

Then start glacierdb using the configuration appropriate for your deployment.

---

## From source

Clone the repository and start the daemon:

```bash
cargo run --release --bin glacierdb
```

glacierdb uses **Glacier storage by default**.

By default:

```text
address:        127.0.0.1:7878
storage:        glacier
authorization:  permissive
capabilities:   auth,database,events
```

The storage backend can still be explicitly selected.

For example, to use in-memory storage:

```bash
OGD_STORAGE=memory \
cargo run --release --bin glacierdb
```

The `OGD_*` environment variable interface is intentionally compatible with openglacier.

---

# Connect with GlacierCLI

In another terminal:

```bash
cargo run --release --bin glaciercli
```

You should get:

```text
Connected to 127.0.0.1:7878. Type help for commands.

glacierdb>
```

The CLI is intentionally thin.

It speaks the same protocol as the underlying openglacier daemon and does not introduce a separate database API.

---

# Your first documents

Insert some documents:

```text
from products
| insert {
    _id: "keyboard",
    name: "Keyboard",
    category: "hardware",
    price: 129
}
```

```text
from products
| insert {
    _id: "mouse",
    name: "Mouse",
    category: "hardware",
    price: 49
}
```

```text
from products
| insert {
    _id: "desk",
    name: "Desk",
    category: "furniture",
    price: 399
}
```

Query them:

```text
from products
| where category == "hardware"
| sort price desc
| select name, price
```

Or execute a query directly:

```bash
glaciercli \
  'from products | where price > 100 | sort price desc'
```

No schema declaration.

No SQL server.

No external database.

---

# What is glacierdb?

glacierdb is a database distribution around the openglacier database engine.

The engine itself lives in:

```text
openglacier-core
```

and provides the fundamental database primitives:

```text
query language
      │
      ▼
lexer / parser
      │
      ▼
AST
      │
      ▼
logical planning
      │
      ▼
physical planning
      │
      ▼
execution
      │
      ▼
storage abstraction
      │
      ├── Memory
      │
      └── Glacier
```

glacierdb packages those capabilities into a database-oriented runtime.

Its main binaries are:

```text
glacierdb     database daemon
glaciercli    interactive and command-line client
```

The underlying Core API remains available independently for applications that need to embed or build directly on the engine.

---

# Why glacierdb?

glacierdb is intended to make openglacier immediately recognizable as a database product without changing the underlying engine architecture.

It keeps the database engine:

* headless;
* portable;
* storage-independent;
* resource-conscious;
* query-oriented;
* independently usable as a Rust crate.

At the same time, glacierdb provides a conventional database distribution:

```text
glacierdb
    │
    ├── glacierdb
    │
    ├── glaciercli
    │
    ├── Glacier persistent storage
    │
    ├── authentication
    │
    └── events
```

---

# Query language

glacierdb uses the openglacier pipeline-oriented query language.

A query describes a sequence of transformations:

```text
from orders
| where status == "paid"
| derive net_total = total - discount
| sort net_total desc
| limit 20
```

The language is intentionally:

* schema-less;
* declarative;
* pipeline-oriented;
* not SQL;
* not MongoDB syntax;
* not a scripting language.

Common stages include:

```text
from / on
where
near
derive
join / lookup
unwind
root
group
set
insert
load
pivot
select
rename
drop
distinct
sort
skip / offset
limit
first
sample
single
count
```

For the complete query language documentation, see the openglacier Core repository.

---

# Document model

Documents are schema-less values.

A document can contain:

```text
strings
numbers
booleans
arrays
objects
null
dates / times
```

For example:

```json
{
  "_id": "user-42",
  "name": "Alice",
  "active": true,
  "tags": ["rust", "database"],
  "profile": {
    "country": "FR"
  }
}
```

There is no requirement to declare a schema before inserting documents.

---

# Glacier storage

**Glacier** is the native persistent storage backend used by glacierdb by default.

It is an append-oriented, record-backed storage engine designed around predictable resource usage and recoverable state.

Conceptually:

```text
+--------------------+--------------------+--------------------+-----+
| Superblock         | Segment frame      | Segment frame      | ... |
+--------------------+--------------------+--------------------+-----+
```

Writes append new segment data rather than modifying previously committed records in place.

Glacier also supports:

* transactional writes;
* generation/version tracking;
* crash recovery;
* checkpoints;
* primary indexes;
* projected field access;
* memory-mapped reads on supported targets;
* bounded execution integration.

The storage engine is exposed through the Core storage abstraction, allowing the query engine to remain independent of the physical backend.

---

# Persistent database

A persistent local glacierdb instance can be started with:

```bash
OGD_STORAGE=glacier \
OGD_STORAGE_PATH=./data/glacierdb.glacier \
cargo run --release --bin glacierdb
```

The same environment variables used by openglacier remain supported.

For example:

```bash
OGD_MEMORY_LIMIT=2GiB
```

can be used to configure the process memory budget.

---

# Storage backend selection

glacierdb defaults to:

```text
OGD_STORAGE=glacier
```

when the variable is not explicitly provided.

This does not remove the ability to use another supported backend.

For development or testing:

```bash
OGD_STORAGE=memory \
cargo run --release --bin glacierdb
```

The user-provided environment variable always takes precedence over the glacierdb default.

---

# Authentication

glacierdb includes the openglacier authentication and identity system.

Authorization enforcement can be enabled with:

```bash
OGD_AUTH_REQUIRED=true
```

Node identity configuration uses the same environment variables as openglacier:

```text
OGD_NODE_IDENTITY
OGD_NODE_IDENTITY_FILE
OGD_NODE_IDENTITY_PASSWORD
```

Authentication is a runtime capability and remains separate from the database storage engine itself.

---

# Events

glacierdb includes the openglacier event engine.

The `events` capability provides the event delivery layer used by long-lived clients and services.

The event system includes mechanisms for:

* subscriptions;
* heartbeat;
* event delivery;
* retry;
* deduplication;
* local subscribers;
* event outbox processing.

Events are identified by stable event IDs so that retries can be handled without treating the same event as a new event.

---

# Capabilities

glacierdb enables the following service capabilities in its standard distribution:

```text
auth
database
events
```

The capability model separates service availability from the underlying database engine.

For example:

```text
database
    │
    ├── queries
    ├── collections
    ├── storage
    └── backups

auth
    │
    ├── identities
    ├── devices
    └── authentication

events
    │
    ├── subscriptions
    └── event delivery
```

The exact operations exposed by a running daemon can be inspected through:

```text
.core.operations
```

---

# GlacierCLI

`glaciercli` is the command-line interface for glacierdb.

Start the interactive shell:

```bash
glaciercli
```

The CLI can also execute queries directly:

```bash
glaciercli \
  'from products | where price > 100 | sort price desc'
```

Raw operations can be issued using the `.` prefix:

```text
.ping
```

```text
.core.health
```

```text
.core.operations
```

JSON payloads can be supplied directly:

```text
.collections.list {"stats":true}
```

Reconnect to the daemon with:

```text
reconnect
```

or:

```text
.reconnect
```

Exit with:

```text
exit
quit
```

or:

```text
.exit
.quit
```

---

# Terminal UI

The glacierdb distribution includes the `cli-tui` feature.

The TUI is built on the same CLI and daemon protocol rather than introducing a second execution path.

Build with:

```bash
cargo build --release --features cli-tui
```

The underlying database behavior remains identical.

---

# Configuration

glacierdb preserves the `OGD_*` configuration interface used by openglacier.

Important variables include:

| Variable                     | Purpose                          |
| ---------------------------- | -------------------------------- |
| `OGD_BIND`                   | Main daemon bind address         |
| `OGD_LOCAL_BIND`             | Optional local bind address      |
| `OGD_STORAGE`                | `memory` or `glacier`            |
| `OGD_STORAGE_PATH`           | Glacier store path               |
| `OGD_MEMORY_LIMIT`           | Process memory limit             |
| `OGD_READ_TIMEOUT_MS`        | Read timeout                     |
| `OGD_WRITE_TIMEOUT_MS`       | Write timeout                    |
| `OGD_NODE_CAPABILITIES`      | Enabled service capabilities     |
| `OGD_NODE_ROLE`              | `master` or `node`               |
| `OGD_NODE_IDENTITY`          | Node identity                    |
| `OGD_NODE_IDENTITY_FILE`     | Node identity file               |
| `OGD_NODE_IDENTITY_PASSWORD` | Password for the node identity   |
| `OGD_BACKUP_PATH`            | Backup directory                 |
| `OGD_AUTH_REQUIRED`          | Enable authorization enforcement |
| `OGD_CLASSIC_AUTH_ENABLED`   | Enable classic authentication    |
| `OGD_HEARTBEAT_ENABLED`      | Enable heartbeat                 |
| `OGD_HEARTBEAT_INTERVAL_MS`  | Heartbeat interval               |
| `OGD_DEBUG_QUERY`            | Query debugging                  |
| `OGD_IMPORT_METRICS`         | Import worker metrics            |

Typical glacierdb defaults:

```text
OGD_BIND               127.0.0.1:7878
OGD_STORAGE            glacier
OGD_STORAGE_PATH       data/ogd.glacier
OGD_NODE_CAPABILITIES  auth,database,events
OGD_NODE_ROLE          master
```

Environment variables explicitly supplied by the user take precedence over glacierdb defaults.

---

# Backup and restore

glacierdb exposes database backup operations through the daemon:

```text
backup.create
backup.inspect
backup.restore
```

They can be accessed through `glaciercli` using the corresponding operation commands.

For example:

```text
.backup.create {}
```

The exact operation contracts exposed by the running version can be inspected with:

```text
.core.operations
```

---

# Memory governance

glacierdb inherits the openglacier memory governance system.

A process-wide memory limit can be configured with:

```bash
OGD_MEMORY_LIMIT=1GiB
```

The execution engine can:

* reserve memory explicitly;
* operate within bounded buffers;
* reclaim eligible cached state;
* spill intermediate execution state when necessary.

The objective is predictable resource usage rather than assuming unlimited RAM.

glacierdb is designed to remain useful on both modern servers and modest hardware.

---

# Projected execution

The Glacier storage engine supports projected field access for eligible query plans.

Conceptually:

```text
Glacier record
      │
      ▼
read required fields
      │
      ▼
query execution
      │
      ▼
identify result documents
      │
      ▼
hydrate complete documents when required
```

For queries that only require a subset of fields, this can avoid unnecessary decoding and allocation.

For example:

```text
from memories
| near embedding, [1.0, 0.0]
| sort _distance asc
| limit 5
```

can use only the fields required for candidate evaluation before loading complete result documents where necessary.

Projected execution is an optimization and does not change query semantics.

---

# Vector search

glacierdb supports vector proximity through the `near` query stage.

```text
from memories
| near embedding, [1.0, 0.0]
| sort _distance asc
| limit 5
```

The operation computes cosine distance and exposes the result through:

```text
_distance
```

Smaller values represent closer vectors.

The current implementation performs exact distance computation over candidate documents.

It is not an approximate nearest-neighbour index such as HNSW.

---

# Transactions

Database writes are transactional.

A transaction accumulates mutations and commits them as a storage generation.

Glacier tracks generation and version information so readers can resolve the visible version of a document without modifying previously committed records.

This transactional model is shared through the Core storage contracts rather than being specific to the command-line client.

---

# Protocol

glacierdb uses the openglacier operation and transport model.

Operations have canonical definitions covering information such as:

* wire name;
* operation kind;
* authorization policy;
* execution mode;
* handler domain;
* payload type.

Examples include:

```text
ping
core.health
core.operations
node.status
query.execute
collections.list
storage.stats
events.subscribe
```

The operation catalogue is discoverable from a running server:

```text
.core.operations
```

glacierdb does not introduce a separate database protocol.

This makes the glacierdb daemon compatible with the same underlying operation model as openglacier.

---

# Repository structure

The glacierdb repository is intentionally small.

Conceptually:

```text
glacierdb/
│
├── src/
│   └── bin/
│       ├── glacierdb.rs
│       └── glaciercli.rs
│
├── Cargo.toml
├── Cargo.lock
└── README.md
```

The database engine itself is not copied into this repository.

glacierdb depends on:

```text
openglacier-core
```

from crates.io.

This keeps the distribution layer separate from the engine implementation.

---

# openglacier Core

glacierdb is built on **openglacier Core**.

Core provides the reusable database engine and resource runtime:

```text
query engine
storage abstraction
Glacier storage
memory storage
transactions
memory governance
event engine
authentication
identity
operation model
protocol
```

The Core crate is published independently as:

```text
openglacier-core
```

The important architectural relationship is:

```text
                 crates.io
                    │
                    ▼
          ┌────────────────────┐
          │  openglacier-core  │
          │                    │
          │ database engine    │
          │ storage            │
          │ events             │
          │ auth               │
          └─────────┬──────────┘
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
   ┌──────────────┐    ┌──────────────┐
   │  openglacier │    │  glacierdb   │
   │              │    │              │
   │    ogd       │    │  glacierdb   │
   │   ogcli      │    │  glaciercli  │
   └──────────────┘    └──────────────┘
```

openglacier and glacierdb therefore share the same engine rather than maintaining separate database implementations.

---

# glacierdb versus openglacier

The two distributions serve different purposes.

|                       | glacierdb          | openglacier                          |
| --------------------- | ------------------ | ------------------------------------ |
| Primary positioning   | Database           | Resource / database engine ecosystem |
| Database engine       | `openglacier-core` | `openglacier-core`                   |
| Daemon                | `glacierdb`        | `ogd`                                |
| CLI                   | `glaciercli`       | `ogcli`                              |
| Default storage       | Glacier            | Memory                               |
| Authentication        | Enabled            | Enabled                              |
| Events                | Enabled            | Enabled                              |
| TUI                   | Included           | Available through Core features      |
| Environment variables | `OGD_*`            | `OGD_*`                              |
| Core engine           | Same               | Same                                 |

The difference is primarily the distribution and default runtime profile.

glacierdb does not replace openglacier Core.

It packages the same engine as a database-oriented product.

Migrating from / to glacierdb to / from core is 100% transparent. You can just switch by keeping your configuration env OGD_*.

---

# Build

Debug build:

```bash
cargo build
```

Release build:

```bash
cargo build --release
```

With the terminal UI:

```bash
cargo build --release --features cli-tui
```

---

# Tests

Run the complete test suite:

```bash
cargo test
```

The glacierdb distribution relies on the same underlying engine and protocol contracts as openglacier Core.

Core-level tests remain in the Core repository.

---

# Development

For local development against a checked-out version of `openglacier-core`, Cargo can use a local crates.io patch when coordinated development requires it.

The normal glacierdb dependency remains the published crate:

```toml
[dependencies]
og_core = {
    package = "openglacier-core",
    version = "1.0.0",
    default-features = false,
    features = ["database", "auth", "events", "cli-tui"],
}
```

The dependency is deliberately aliased as `og_core` because that is the Rust library name exposed by `openglacier-core`.

---

# Design principles

## Database first

glacierdb presents the engine as a database.

The query language, document model, transactions and storage contracts are first-class components.

---

## Same engine, different distribution

glacierdb does not fork the database implementation.

The database engine remains in `openglacier-core`.

---

## Glacier by default

glacierdb is intended for persistent database workloads.

Therefore the distribution defaults to the Glacier storage backend while retaining explicit backend selection through `OGD_STORAGE`.

---

## Compatible configuration

Existing openglacier configuration uses the `OGD_*` namespace.

glacierdb deliberately preserves that interface.

---

## Headless

The database daemon has no graphical dependency.

It can run:

* on a workstation;
* on a server;
* in a container;
* on small hardware;
* under automated tests.

---

## Resource conscious

Memory and storage behavior should remain explicit and predictable.

glacierdb does not assume unlimited CPU, memory or storage bandwidth.

---

## Small distribution layer

The glacierdb repository contains the distribution layer rather than duplicating the database engine.

This keeps the product easy to understand and the engine independently reusable.

---

# Non-goals

glacierdb is not:

* an ORM;
* a REST framework;
* a UI framework;
* an application server;
* a wrapper around PostgreSQL, SQLite or another database;
* a scripting runtime.

The database engine also intentionally does not depend on a graphical interface.

---

# Relationship to the openglacier project

glacierdb is part of the broader openglacier ecosystem.

The architecture is deliberately split between:

```text
openglacier Core
    │
    └── reusable engine and runtime

glacierdb : openglacier db
    │
    └── database distribution

openglacier
    │
    └── main initiative to a broader ecosystem and distributed architecture
```

This allows the database engine to evolve independently from the way it is distributed and presented to users.

For the broader openglacier project and architecture:

https://github.com/openglacier/openglacier

For the database engine:

https://github.com/openglacier/core

---

# License

MIT
