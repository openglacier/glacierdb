<p align="center">

  <img src="github-static/logo.png" alt="glacierdb" width="280">

</p>

<h1 align="center">glacierdb</h1>

<p align="center">

<strong>An event-first, schema-less document database built on the openglacier engine.</strong>

</p>

<p align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue)
[![Build](https://github.com/openglacier/glacierdb/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/openglacier/glacierdb/actions/workflows/build.yml)
[![Tests](https://github.com/openglacier/glacierdb/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/openglacier/glacierdb/actions/workflows/tests.yml)
[![Clippy](https://github.com/openglacier/glacierdb/actions/workflows/clippy.yml/badge.svg?branch=main)](https://github.com/openglacier/glacierdb/actions/workflows/clippy.yml)
[![Audit](https://github.com/openglacier/glacierdb/actions/workflows/audit.yml/badge.svg?branch=main)](https://github.com/openglacier/glacierdb/actions/workflows/audit.yml)
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

glacierdb uses a declarative, pipeline-oriented query language.

This section is a summary. The complete guide and reference, with one entry per stage and per function, views, caches, modeling patterns, the grammar and an index, is the book *The OpenGlacier Modeling Language* (`og-books/manifest/the_ogml_language`).

A query names a source, then describes a sequence of transformations separated by `|`:

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

Each stage has one responsibility.

Execution order is explicit. Execution strategy is not: the planner decides how a pipeline actually runs.

This section is the complete reference:

* [A short tour](#a-short-tour)
* [Query structure](#query-structure)
* [Lexical structure](#lexical-structure)
* [Values and types](#values-and-types)
* [Expressions](#expressions)
* [Functions](#functions)
* [Parameters, variables and `explain`](#parameters-variables-and-explain)
* [Stage reference](#stage-reference)
* [Past states and history](#past-states-and-history)
* [Views](#views)
* [Composition rules](#composition-rules)
* [System collections](#system-collections)
* [Results and statistics](#results-and-statistics)
* [Errors](#errors)
* [Known limitations](#known-limitations)
* [Grammar summary](#grammar-summary)

The examples use three collections:

```text
users     { name, age, city, active, tags: [...], profile: { country, score } }
orders    { order_id, user, product, qty, price, status, month, region }
products  { code, label, category, embedding: [x, y, z] }
```

| users | age | city   | active | tags       | profile.country | profile.score |
| ----- | --- | ------ | ------ | ---------- | --------------- | ------------- |
| Alice | 31  | Paris  | true   | admin, dev | FR              | 9.5           |
| Bob   | 17  | Lyon   | false  | dev        | FR              | 7             |
| Carol | 45  | Berlin | true   | *(empty)*  | DE              | 8.25          |
| Dan   | 28  | Paris  | true   | ops        | FR              | 6             |

| orders | user  | product | qty | price | status    | month   | region |
| ------ | ----- | ------- | --- | ----- | --------- | ------- | ------ |
| 1      | Alice | P1      | 2   | 10.0  | paid      | 2026-01 | EU     |
| 2      | Alice | P2      | 1   | 99.5  | paid      | 2026-02 | EU     |
| 3      | Bob   | P1      | 5   | 10.0  | pending   | 2026-01 | EU     |
| 4      | Carol | P3      | 1   | 250.0 | paid      | 2026-02 | US     |
| 5      | Dan   | P2      | 3   | 99.5  | cancelled | 2026-01 | US     |
| 6      | Carol | P1      | 4   | 10.0  | paid      | 2026-01 | US     |

| products | label   | category | embedding       |
| -------- | ------- | -------- | --------------- |
| P1       | Pen     | office   | [1.0, 0.0, 0.0] |
| P2       | Printer | office   | [0.9, 0.1, 0.0] |
| P3       | Phone   | mobile   | [0.0, 1.0, 0.0] |

To keep outputs short, the `_id` field of each result document is omitted.

In the examples, a line starting with `--` shows a result or a remark. It is not part of the query: the language has no comments.

---

## A short tour

Filter, compute, rank. This is a Top-N over a computed value:

```text
on orders
| where status != "cancelled"
| select user, product, price * qty as total
| sort total desc
| limit 3
```

```json
{"product":"P3","total":250.0,"user":"Carol"}
{"product":"P2","total":99.5,"user":"Alice"}
{"product":"P1","total":50.0,"user":"Bob"}
```

Revenue per region, with a derived value feeding a grouped sum:

```text
on orders
| where status == "paid"
| derive revenue = price * qty
| group region, revenue as revenue
| sort revenue desc
```

```json
{"region":"US","revenue":290.0}
{"region":"EU","revenue":119.5}
```

Several measures at once, with the compound `group`:

```text
on orders | group | by region | sum qty as units | avg price as mean | count as rows | end
```

Expressions are one language everywhere. Arithmetic, membership and functions work in filters, projections and updates alike:

```text
on orders
| where price * qty > 50 and status in ["paid", "pending"]
| select order_id, round(price * qty, 1) as total, if(qty > 2, "bulk", "unit") as kind
```

Vector similarity search, by cosine distance:

```text
on products
| near embedding, [0.1, 0.9, 0.0]
| sort _distance
| limit 2
| select code, label, _distance
```

Correlated joins. Each user receives their own large orders:

```text
on users as u
| where age > 30
| lookup orders as o
    | where o.user == u.name and o.price * o.qty > 20
    | select order_id, price
    | into big_orders
| end
```

Running values over ordered rows:

```text
on orders
| window
    | partition by region
    | order by order_id
    | cumsum qty as running_units
    | row_number as rank
| end
```

Transactional writes. `set` acts on exactly the documents that reach it, even after a sort and a limit:

```text
on users | sort name | limit 1 | set top = true
on orders | where status == "cancelled" | delete
on users | where active | into archive
```

Engine introspection is queryable like any other collection:

```text
on _memory | where scope == "global" | select profile, current_bytes, pressure_state
```

---

## Query structure

```text
[explain] [let ... |] <source> ( "|" <stage> )*
```

### Source

```text
on   <collection> [as of <date|generation> | history] [as <alias>]
from <collection> [as of <date|generation> | history] [as <alias>]
on values [ {...}, ... ]
on view <name> [version <n>] [as <alias>]
```

* `on` and `from` are synonyms.
* The collection name may be dotted: `on shop.orders`.
* Collections are created implicitly by the first write. Reading a collection that does not exist returns nothing.
* A query may consist of the source alone: `on users` returns every document.
* The alias names the source. At the top level, `u.age` and `age` are the same field (`on users as u | where u.age > 30`). In `lookup` and `union` sub-pipelines, the alias names the outer document.
* `on values [...]` reads literal rows, objects with bare or quoted keys. It works wherever a collection is read, including `lookup` and `union`. The rows can never be written.
* `as of` and `history` are described in [Past states and history](#past-states-and-history), `on view` in [Views](#views).

```text
on values [{code: "FR", rate: 0.2}, {code: "DE", rate: 0.19}] | where rate > 0.19
-- {"code":"FR","rate":0.2}
```

### Simple stages

```text
| <stage-name> <arguments>
```

Everything up to the next top-level `|` is the argument text of the stage. Parentheses, brackets and braces must balance. A `|` inside `(...)`, `[...]`, `{...}` or a string does not end the stage.

### Compound stages and `end`

Some stages open a **sub-pipeline**, a sequence of stages closed by `| end`:

| Stages            | Rule                                                                      |
| ----------------- | ------------------------------------------------------------------------- |
| `union`, `pivot`, `window` | Always compound                                                  |
| `lookup` / `join` | Compound, except the one-line form whose header contains `into`           |
| `load`, `group`   | Compound when written without arguments; compact one-line form otherwise  |
| every other stage | Always simple                                                             |

```text
on users
| lookup orders
    | where status == "paid"
    | into paid
| end
| where active
```

* A missing `| end` is an error.
* An `end` without an open sub-pipeline is an error.
* Sub-pipelines can nest.

---

## Lexical structure

### Whitespace

Spaces, tabs and newlines are interchangeable. A query can sit on one line or span many, and indentation is cosmetic.

There are **no comments** in the language.

### The pipe

`|` separates stages and is the only statement separator. `||` is always the boolean "or", never two stage boundaries.

### Identifiers

* An identifier starts with a letter (any Unicode alphabetic character) or `_`, and continues with letters, digits or `_`.
* Identifiers are case-sensitive.
* Unicode identifiers work everywhere: `on données | where prénom == "Élodie"`.
* **Field paths** use dots: `profile.country`, `a.b.c`. Each segment is an identifier.
* A key containing a space or a hyphen can be stored (`insert {"display name": "Zed"}`) but cannot be written as a path. Read it with `get(field, "display name")`.
* A `?` after a path segment makes the path optional: `nick?`, `profile?.country`.

### Keywords

These words are reserved:

```text
on  from  as  where  set  lookup  join  union  load  pivot
into  with  chunk  replace  update  merge  end
and  or  not  true  false  null
```

Other stage names (`select`, `sort`, `group`, `limit`, ...) are ordinary identifiers recognised in stage position.

Inside expressions, `in` is also reserved. `between` is recognised only after an operand, so it remains usable as a field name. Function names are not reserved: `round(x)` is a call and `round` alone is a field.

### Literals

| Literal | Examples                                        | Notes                                                                                   |
| ------- | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| Null    | `null`                                          |                                                                                         |
| Boolean | `true`, `false`                                 |                                                                                         |
| Integer | `0`, `42`, `18446744073709551615`               | Signed 64-bit when it fits, otherwise unsigned 64-bit                                   |
| Float   | `9.5`, `.75`, `1e3`, `1.5e-10`                  | Finite IEEE-754 doubles. `1` and `1.0` compare equal                                    |
| String  | `"Paris"`, `"a\"b"`, `"line\nbreak"`            | Double quotes only. JSON escapes: `\" \\ \/ \b \f \n \r \t` and `\uXXXX`. No raw newline |
| Array   | `[1, 2]`, `["a", qty * 2, lower(name)]`         | Elements are any expressions                                                            |
| Object  | `{"a": 1}`, `{name: "Alice", tags: ["x"]}`      | Quoted keys anywhere in an expression; `insert` and `on values` also accept bare keys    |

A leading `+` or `-` directly applied to a numeric literal is part of the literal: `-5` and `+2.5` are constants. Between two operands they are binary operators. Applied to a field (`-qty`), `-` is a negation.

### Operators and punctuation

| Token                                    | Meaning                                              |
| ---------------------------------------- | ---------------------------------------------------- |
| `==` `!=` `<` `<=` `>` `>=`              | Comparisons                                          |
| `and`, `or`, `not`                       | Boolean operators                                    |
| `&&`, `\|\|`, `!`                        | Symbolic synonyms of `and`, `or`, `not`              |
| `+` `-` `*` `/` `%`                      | Arithmetic                                           |
| `in`, `not in`                           | Membership in an array (literal or field)            |
| `between ... and ...`, `not between ... and ...` | Inclusive range test                         |
| `?`                                      | Optional field path                                  |
| `name(...)`                              | Function call                                        |
| `( )`                                    | Grouping                                             |
| `[ ]`                                    | Array constructor                                    |
| `{ } : ,`                                | Objects, argument lists                              |
| `.`                                      | Field-path and collection-path separator             |
| `=`                                      | Assignment in `set`, `derive` and `let` (never comparison) |
| `$name`                                  | Parameter or variable                                |

---

## Values and types

### The value model

Documents are schema-less. Every field holds one of:

| Kind    | Description                                                                    |
| ------- | ------------------------------------------------------------------------------ |
| `null`  | Explicit null                                                                  |
| boolean | `true` / `false`                                                               |
| number  | Signed integer (i64), unsigned integer (u64) or finite float (f64)             |
| string  | UTF-8 text                                                                     |
| array   | Ordered values of any kind, including mixed kinds                              |
| object  | Nested document                                                                |

There is no date type. A timestamp is a number of milliseconds since the Unix epoch, or an ISO-8601 string, and the [date functions](#dates) read both.

### `_id`

Every stored document has an `_id`, a **UUID v7**.

* `insert` and `load` generate it when absent.
* `load` accepts an explicit `_id` (a 32-hex-digit UUID, with or without dashes). This gives idempotent imports and upserts.
* `where _id == "<uuid>"` runs as a **primary-key lookup** instead of a scan.
* `select` always keeps `_id`.

### Comparison rules

* Integers and floats compare numerically: `age == 31.0` matches `age: 31`.
* Strings compare lexicographically: `name >= "B" and name < "D"`.
* **No cross-kind coercion.** `age == "31"` is an error, not `false`. Membership is the exception: `x in [...]` never fails on kinds, it just does not match.
* Field-to-field comparisons are allowed: `where age >= profile.score`.

### Missing fields are strict

A field referenced in a predicate or an expression **must exist** on every document that reaches it. Otherwise the query fails:

```text
expression evaluation failed: field path "nickname" is missing
```

This is deliberate: a typo in a field name surfaces as an error instead of silently returning nothing.

Missing is not `null`, and the language gives explicit tools for optional fields:

* `exists(nickname)` is `true` or `false` and never fails.
* `coalesce(nickname, name)` returns its first present, non-null argument.
* `and`, `or`, `if` and `case` evaluate lazily, so `exists(x) and x > 3` is safe.
* A `?` after a path segment reads a missing field as `null`: `nick?`, `profile?.country`. `==` and `!=` accept `null` on either side.

```text
on users | select name, coalesce(nick, name) as display, exists(nick) as has_nick
on users | where profile?.level == "gold" | select name, nick? as nick
```

Exceptions:

* `near` discards documents that lack the vector field.
* Projection stages (`select field`, `drop`, `rename`) tolerate missing fields.

---

## Expressions

There is a single expression language. Anything that works in `where` works in `select ... as`, `derive`, `set`, `sort` and inside sub-pipelines, with the same results and the same errors.

### Forms

| Form            | Example                                                                  |
| --------------- | ------------------------------------------------------------------------ |
| Literal         | `42`, `"paid"`, `true`, `null`                                           |
| Field path      | `age`, `profile.country`                                                 |
| Optional path   | `nick?`, `profile?.country`                                              |
| Unary           | `not active`, `!active`, `-qty`, `+qty`                                  |
| Binary          | `age >= 18`, `price * qty`                                               |
| Group           | `(city == "Paris" or city == "Lyon")`                                    |
| Membership      | `status in ["paid", "pending"]`, `"dev" in tags`, `region not in ["US"]` |
| Range           | `age between 18 and 30`, `price not between 10 and 20`                   |
| Array           | `[qty, qty * 2, "x"]`                                                    |
| Function call   | `round(price * qty, 2)`, `coalesce(nick, name)`                          |
| Object          | `{"a": 1}`, `merge(meta, {"v": 2})`                                      |
| Parameter       | `$min`, `$cities`                                                        |

Every form nests inside every other: `upper(concat(name, "@", lower(city)))`, `max([a, b, c]) in allowed`.

A bare boolean field or literal is a valid predicate: `where active`, `where true`.

### Precedence

From lowest to highest. Binary operators are left-associative.

| Level      | Operators                                              |
| ---------- | ------------------------------------------------------ |
| 1          | `or`, `\|\|`                                           |
| 2          | `and`, `&&`                                            |
| 3 (prefix) | `not`, `!`                                             |
| 4          | `==` `!=`                                              |
| 5          | `<` `<=` `>` `>=` `in` `not in` `between ... and ...`  |
| 6          | `+` `-`                                                |
| 7          | `*` `/` `%`                                            |
| 8 (prefix) | unary `-`, unary `+`                                   |

`not` binds looser than comparisons: `not city == "Berlin"` means `not (city == "Berlin")`, and `not active and age > 18` means `(not active) and age > 18`.

### Semantics

| Construct            | Semantics                                                                                             |
| -------------------- | ----------------------------------------------------------------------------------------------------- |
| Comparisons          | Numbers compare across integer and float; strings lexicographically; any other cross-kind comparison is an error |
| `and` / `or` / `not` | Operands must be booleans. `and` and `or` short-circuit                                               |
| `in` / `not in`      | The right side must be an array. Incompatible kinds simply do not match                               |
| `+` `-` `*` `%`      | Integers stay integers while the result fits in 64 bits. Anything involving a float gives a float     |
| `/`                  | Always a float: `7 / 2` is `3.5`                                                                      |
| Division by zero     | Error. Use `div(a, b, fallback)` for a safe division                                                  |
| Unary `-`            | Integer negation when possible, otherwise float                                                       |
| Text                 | No `+` on strings: use `concat(...)`                                                                  |

```text
on orders | where price * qty > 50 and status != "cancelled" | select order_id, round(price * qty, 1) as total
-- {"order_id":2,"total":99.5}
-- {"order_id":4,"total":250.0}

on users | where abs(age - 30) <= 2 and not (name in ["Bob"]) | select name, age
-- {"age":31,"name":"Alice"}
-- {"age":28,"name":"Dan"}
```

---

## Functions

Functions are called by name with parenthesised arguments, and any expression can be an argument.

Unknown names and wrong argument counts are rejected when the query is planned, before any storage access.

There is no general `null` propagation: numeric, text and date functions refuse `null` (`` `upper` expects a string, found Null ``). `coalesce`, `exists`, `optional`, `nullif`, `concat`, `to_int`, `to_float`, `to_string`, `type`, `merge` and the aggregates `sum`, `avg`, `median`, `percentile`, `stddev` accept it. Guard optional values with `coalesce(x?, default)`.

### Numeric

| Function                                      | Result                                                                                         | Example                              |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------ |
| `abs(x)`                                      | Absolute value, integer kept                                                                   | `abs(-3)` → `3`                      |
| `sqrt(x)`                                     | Square root (float); a negative input is an error                                              | `sqrt(16)` → `4.0`                   |
| `pow(x, y)`                                   | Power; integer when exact                                                                      | `pow(3, 2)` → `9`                    |
| `round(x [, digits [, mode]])`                | Rounds half away from zero (`"half_up"`, the default) or to even (`"half_even"`). Integer without `digits`, float with `digits` (0 to 15) | `round(13.333, 2)` → `13.33`, `round(0.125, 2, "half_even")` → `0.12` |
| `trunc(x [, digits])`                         | Rounds toward zero, same rules as `round`                                                      | `trunc(-2.7)` → `-2`                 |
| `floor(x)`, `ceil(x)`                         | Rounded down / up, as an integer                                                               | `floor(12.5)` → `12`                 |
| `sign(x)`                                     | `-1`, `0` or `1`                                                                               | `sign(-3)` → `-1`                    |
| `ln(x)`, `log10(x)`, `log(x, base)`, `exp(x)` | Logarithms (positive input) and exponential, as floats                                         | `log(8, 2)` → `3.0`                  |
| `min(a, b, ...)`, `max(a, b, ...)`            | Smallest / largest argument; with one array argument, over its elements; values must be comparable (a `null` item is an error) | `max(age, 30)`, `max(scores)`        |
| `sum(a, b, ...)`, `avg(a, b, ...)`            | Sum (integer while every term is) / mean; with one array argument, over its elements; `null` items are skipped | `sum(scores)`, `avg([])` → `null` |
| `median(a, b, ...)`, `percentile(array, fraction)`, `stddev(a, b, ...)` | Middle value, value at a fraction (0 to 1, linear between the two closest values), sample standard deviation; with one array argument, over its elements; `null` items are skipped; `null` when there are no values (fewer than two for `stddev`) | `median([3, 1, 2])` → `2.0`, `percentile(scores, 0.9)` |
| `div(a, b [, fallback])`                      | Safe division: `fallback` when `b` is 0 (`null` without fallback), else `a / b`                | `div(price, qty - 1, 0)`             |

### Logic, missing values and conversions

| Function                                | Result                                                                                         | Example                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `if(cond, then, else)`                  | Only the chosen branch is evaluated                                                            | `if(age >= 18, "adult", "minor")`              |
| `case(c1, v1, c2, v2, ..., [default])`  | Value of the first true condition, else `default` (or `null`); lazy                            | `case(qty > 5, "bulk", qty > 1, "few", "one")` |
| `coalesce(a, b, ...)`                   | First argument that is present and not `null`                                                  | `coalesce(nick, name)`                         |
| `exists(x)`                             | Whether `x` is present; never fails                                                            | `exists(nickname)`                             |
| `optional(x)`                           | `x`, or `null` when missing; what `x?` means                                                   | `optional(nick)`                               |
| `nullif(a, b)`                          | `null` when `a == b`, else `a`                                                                 | `nullif(status, "")`                           |
| `between(x, low, high)`                 | `low <= x <= high`; what `x between low and high` means                                        | `between(age, 18, 30)`                         |
| `bucket(x, [b0, b1, ...] [, default])`  | Lower bound of the range `[b(i), b(i+1))` holding `x`, else `default` (or `null`); the last bound closes the last range | `bucket(31, [0, 18, 65])` → `18`, `bucket(70, [0, 18, 65], "old")` → `"old"` |
| `to_int(x)`                             | Integer from a number (truncated), a numeric string or a boolean; `null` stays `null`          | `to_int("42")` → `42`                          |
| `to_float(x)`                           | Float from a number, a numeric string or a boolean                                             | `to_float("2.5")` → `2.5`                      |
| `to_string(x)`                          | Text; numbers, booleans, arrays and objects are written as JSON                                | `to_string(3)` → `"3"`                         |
| `to_bool(x)`                            | From a boolean, a number (non-zero), or `true/false/1/0/yes/no`                                | `to_bool("yes")` → `true`                      |
| `type(x)`                               | `"null"`, `"bool"`, `"number"`, `"string"`, `"array"` or `"object"`                            | `type(profile)` → `"object"`                   |

### Text

Positions count characters, not bytes. A negative start counts from the end.

| Function                                                  | Result                                                                                       | Example                                        |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `len(x)`                                                  | Characters of a string, items of an array, keys of an object                                 | `len(tags)` → `2`                              |
| `lower(s)`, `upper(s)`, `trim(s)`, `ltrim(s)`, `rtrim(s)` | Text transforms                                                                              | `upper(trim(name))`                            |
| `concat(a, b, ...)`                                       | Joins text (numbers and booleans are written as text, `null` is skipped); when every argument is an array, concatenates the arrays | `concat(name, "@", city)`, `concat(tags, ["new"])` |
| `substr(s, start [, length])`                             | Substring                                                                                    | `substr("Paris", 0, 3)` → `"Par"`              |
| `split(s, separator)`                                     | Array of parts; an empty separator splits characters                                         | `split("a,b", ",")` → `["a","b"]`              |
| `replace(s, from, to)`                                    | Replaces every occurrence                                                                    | `replace(city, " ", "-")`                      |
| `index_of(x, y)`                                          | Position of `y` in a string or an array, `-1` when absent                                    | `index_of(tags, "dev")` → `1`                  |
| `pad_left(s, width [, fill])`, `pad_right(...)`           | Pads to `width` characters with `fill` (one character, a space by default)                   | `pad_left("3", 3, "0")` → `"003"`              |
| `contains(x, y)`                                          | Substring test on strings, element test on arrays                                            | `contains(name, "li")`, `contains(tags, "dev")` |
| `starts_with(s, p)`, `ends_with(s, p)`                    | Prefix / suffix test                                                                         | `starts_with(city, "Pa")`                      |

### Arrays

| Function                                 | Result                                                                  | Example                           |
| ---------------------------------------- | ----------------------------------------------------------------------- | --------------------------------- |
| `at(array, i)`                           | Item `i` (negative from the end), `null` when out of range              | `at(tags, -1)` → `"dev"`          |
| `slice(array, start [, length])`         | Sub-array                                                               | `slice(tags, 1)`                  |
| `reverse(x)`                             | Reversed array or string                                                | `reverse(tags)`                   |
| `sort_array(array [, "asc"\|"desc"])`    | Sorted copy; items must be comparable                                   | `sort_array(scores, "desc")`      |
| `unique(array)`                          | Distinct items, first occurrence kept                                   | `unique([1, 1, 2])` → `[1,2]`     |
| `flatten(array)`                         | Flattens one level                                                      | `flatten([[1], 2])` → `[1,2]`     |
| `range(start, end [, step])`             | Integers from `start` up to (excluding) `end`; at most 1,000,000 items  | `range(0, 6, 2)` → `[0,2,4]`      |

### Objects

| Function                    | Result                                                           | Example                                   |
| --------------------------- | ---------------------------------------------------------------- | ----------------------------------------- |
| `keys(o)`, `values(o)`      | Keys / values of an object                                       | `keys(profile)` → `["country","score"]`   |
| `get(o, key [, default])`   | Value under any key, including keys that are not identifiers     | `get(meta, "display name", "")`           |
| `has(o, key)`               | Whether the key is present                                       | `has(profile, "score")`                   |
| `merge(o1, o2, ...)`        | Shallow merge, later objects win; `null` arguments are skipped   | `merge(profile, {"level": 2})`            |

### Dates

A timestamp is a number of milliseconds since the Unix epoch, or an ISO-8601 string (`2026-03-09`, `2026-03`, `2026-03-09T10:00:00Z`, `2026-03-09 10:00:00+02:00`).

Every computation is in UTC.

Units are `year`, `quarter`, `month`, `week` (weeks start on Monday), `day`, `hour`, `minute`, `second`, `millisecond`, singular or plural.

| Function                                             | Result                                                                                                  | Example                                                    |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `now()`                                              | Current time, epoch milliseconds                                                                        |                                                            |
| `parse_date(t)`                                      | Epoch milliseconds                                                                                      | `parse_date("1970-01-02")` → `86400000`                    |
| `date_trunc(t, unit)`                                | Start of the unit, epoch milliseconds                                                                   | `date_trunc(at, "month")`                                  |
| `date_add(t, n, unit)`                               | Epoch milliseconds; adding months clamps the day                                                        | `date_add("2026-01-31", 1, "month")` → 2026-02-28          |
| `date_diff(start, end, unit)`                        | Unit boundaries crossed from `start` to `end`                                                           | `date_diff("2025-12-31", "2026-01-01", "year")` → `1`      |
| `date_part(t, part)`                                 | `year`, `quarter`, `month`, `week` (ISO), `day`, `day_of_week` (1 = Monday), `day_of_year`, `hour`, `minute`, `second`, `millisecond` | `date_part(at, "day_of_week")` |
| `date_format(t [, pattern])`                         | Text; ISO-8601 by default. Directives `%Y %m %d %H %M %S %L` (ms) `%j %u %V %F %T %%`                    | `date_format(at, "%Y-%m")` → `"2026-03"`                   |
| `fiscal_year(t, closing)`                            | Fiscal year holding `t`, named after the year it closes in. `closing` is the closing month (1 to 12; 12 is the calendar year), or a timestamp on the first day of the opening month | `fiscal_year("2026-07-01", 6)` → `2027` |
| `fiscal_month(t, closing)`                           | Month within the fiscal year, 1 to 12                                                                   | `fiscal_month("2026-07-01", 6)` → `1`                      |
| `fiscal_start(t, closing)`, `fiscal_end(t, closing)` | First and last day of the fiscal year, epoch milliseconds                                               | `fiscal_end("2026-07-01", 6)` → 2027-06-30                 |
| `month_end(t)`                                       | Last day of the month, epoch milliseconds                                                               | `month_end("2024-02-10")` → 2024-02-29                     |
| `days_in(t, unit)`                                   | Number of days of the unit holding `t`                                                                  | `days_in("2024-02-10", "month")` → `29`                   |

---

## Parameters, variables and `explain`

### Parameters (`$name`)

A query can reference named parameters. Their values travel next to the query in the `query.execute` request:

```json
{"query": "on users | where age >= $min and city in $cities | limit $n",
 "params": {"min": 18, "cities": ["Paris", "Lyon"], "n": 10}}
```

With `glaciercli`:

```bash
glaciercli --param min=18 --param 'cities=["Paris","Lyon"]' --param n=10 \
  'on users | where age >= $min and city in $cities | limit $n'
```

* Each `$name` outside a string literal is replaced by the literal of its value before the query is authorized, planned or run. Strings are quoted and escaped, so a value never changes the structure of the query.
* Any JSON value works: numbers, strings, booleans, `null`, arrays (for `in`), objects (for `insert`). A parameter can appear wherever its literal could: `limit $n`, `near embedding, $vector`.
* An unbound `$name` fails the request. Unused parameters are ignored.
* With `glaciercli`, the value is parsed as JSON when it can be, otherwise taken as a string.

### Variables (`let`)

A query can start with one or more `let` headers that name values reused by its stages:

```text
let <$name> = <expression>, <$name> = <expression>, ...
| [let ... |]
on <collection> | ...
```

```text
let $threshold = 50, $label = upper("big")
| on orders
| where price * qty > $threshold
| derive margin = price * qty - $threshold, kind = $label
| select order_id, margin, kind
```

```json
{"kind":"BIG","margin":49.5,"order_id":2}
{"kind":"BIG","margin":200.0,"order_id":4}
{"kind":"BIG","margin":248.5,"order_id":5}
```

* Each expression is evaluated **once per query**, before planning, then used wherever `$name` appears. `let $now = now()` therefore gives every row the same instant.
* An expression may use any function, request parameters and variables declared before it. It cannot read document fields: `let $x = qty` is rejected.
* A name is bound once. Redeclaring a variable, or declaring a name also passed as a parameter, is an error.
* `let $name ?= <expression>` gives a default: it binds the name only when it is not bound already.
* A value written as a query in parentheses is the array of its rows, read once before the query is planned. The inner query must not write and returns at most 1,000 rows:

```text
let $best = (on users | sort profile.score desc | limit 1)
| let $name = get(at($best, 0), "name")
| on orders
| where user == $name
| select order_id, user
-- {"order_id":1,"user":"Alice"}
-- {"order_id":2,"user":"Alice"}
```

### `explain`

Prefixing a query with `explain` plans it without running it, and returns one document describing the plan:

```text
explain on orders | where qty > 1 | sort price * qty desc | limit 3
```

| Field       | Meaning                                                                                   |
| ----------- | ----------------------------------------------------------------------------------------- |
| `access`    | `collection_scan` or `primary_key_lookup`                                                 |
| `executor`  | `streaming`, `governed_blocking`, `transactional` (writes), or `rejected` when the shape has no bounded executor |
| `mode`      | Memory contract of the plan                                                               |
| `operators` | Physical operators in order, with shorthand forms expanded                                |
| `read_only` | Whether the query writes                                                                  |

Variables and parameters are bound first, so `explain let $n = 2 | on orders | limit $n` shows `limit 2`.

---

## Stage reference

| Role                      | Stages                                                             |
| ------------------------- | ------------------------------------------------------------------ |
| Filtering and projection  | `where`, `select` / `project`, `derive`, `rename`, `drop`, `root`  |
| Vector search             | `near`                                                             |
| Ordering and paging       | `sort`, `limit`, `skip` / `offset`, `first`, `single`, `sample`    |
| Arrays                    | `unwind`                                                           |
| Deduplication and counting | `distinct`, `count`                                               |
| Aggregation               | `group`, `bucket`, `pivot`                                         |
| Ordered rows              | `window`, `fill`                                                   |
| Combining collections     | `lookup` / `join`, `union`                                         |
| Writes                    | `insert`, `set`, `delete`, `into` / `out`, `load`                  |

A running daemon lists every stage with its forms, arguments and placement:

```text
.query.stages
```

### `where`

```text
where <predicate>
```

Keeps the documents for which the predicate is `true`. Several `where` stages may be chained.

```text
on users | where age >= 18 and city == "Paris" | select name, age
-- {"age":31,"name":"Alice"}
-- {"age":28,"name":"Dan"}

on users | where (city == "Paris" or city == "Lyon") and age < 30 | select name
on users | where profile.score >= 8 | select name, profile.score
on users | where age >= 18 | where active | select name
```

### `select`

```text
select <item>, <item>, ...
item := <field.path> | <expression> as <field.path>
```

`project` is an alias.

Keeps only the listed fields, plus `_id`. Nested sources are rebuilt nested: `select profile.score` returns `{"profile":{"score":...}}`. An alias can be a nested path. A computed item needs `as`.

```text
on orders | select order_id, price * qty as total, product as sku | limit 2
-- {"order_id":1,"sku":"P1","total":20.0}
-- {"order_id":2,"sku":"P2","total":99.5}

on users | select name, profile.country as geo.country | limit 1
-- {"geo":{"country":"FR"},"name":"Alice"}
```

Items are evaluated left to right, and a later item can use an alias introduced earlier: `select price * qty as total, total > 50 as big`.

### `derive`

```text
derive <field.path> = <expression>, <field.path> = <expression>, ...
```

Adds or overwrites fields while keeping the rest of the document. Target paths may be nested. Assignments are applied **left to right**, and each one sees the fields computed before it:

```text
on orders
| derive total = price * qty, big = total > 100, label = if(big, "big", "small")
| select order_id, total, label
| limit 2
-- {"label":"small","order_id":1,"total":20.0}
-- {"label":"small","order_id":2,"total":99.5}
```

`derive` does not modify stored data.

### `rename`

```text
rename <source.path> as <target.path>
```

Moves one field. Source and target must differ.

```text
on users | rename name as full_name | select full_name, age | limit 1
-- {"age":31,"full_name":"Alice"}
```

### `drop`

```text
drop <field.path>, <field.path>, ...
```

Removes fields from the output. It does not modify stored data.

```text
on users | drop tags, profile | limit 1
-- {"active":true,"age":31,"city":"Paris","name":"Alice"}
```

### `root`

```text
root <field.path>
```

Replaces each document with the object stored at the path.

```text
on users | where name == "Alice" | root profile
-- {"country":"FR","score":9.5}
```

### `near`

```text
near <vector.field>, [<number>, <number>, ...]
```

Computes the **cosine distance** between the query vector and the vector field of each document, and writes it to `_distance` (0 means same direction).

* Documents without the field are discarded.
* A dimension mismatch is an error.
* `near` does not reorder documents. Pair it with `sort _distance` and `limit k` for k-nearest-neighbours, or with `where _distance < t` for a radius search.

```text
on products | near embedding, [0.0, 1.0, 0.0] | sort _distance | limit 2
on products | near embedding, [0.0, 1.0, 0.0] | where _distance < 0.5 | select code, _distance
-- {"_distance":0.0,"code":"P3"}
on products | where category == "office" | near embedding, [0.0, 1.0, 0.0] | select code, _distance
```

### `sort`

```text
sort <key> [asc|desc], ...
key := <field.path> | <expression>
```

Stable ordering on one or more keys. A key can be any expression: `sort price * qty desc`, `sort len(name), name`.

* The default direction is `asc`.
* Missing fields and `null` sort before every other value in ascending order, and after them in descending order.
* Followed by `limit N`, `sort` runs as a bounded **Top-N** that keeps only N rows in memory.
* A large sort spills sorted runs to disk instead of growing in memory.

```text
on orders | sort price desc | limit 2
on orders | sort price * qty desc | limit 3
on users  | select name, city | sort city, name desc
```

### `limit`, `skip`

```text
limit <non-negative integer>
skip  <non-negative integer>
```

`offset` is an alias of `skip`.

```text
on orders | sort order_id | skip 2 | limit 2 | select order_id
-- {"order_id":3}
-- {"order_id":4}
```

### `first`, `single`

```text
first  [<field.path>]
single [<field.path>]
```

`first` returns the first document that reaches it. `single` returns the only document that reaches it, and fails when there are zero or several. With a path, both also project that field.

```text
on orders | select order_id, price | sort price desc | first
-- {"order_id":4,"price":250.0}

on users | where name == "Alice" | single | select name, age
-- {"age":31,"name":"Alice"}

on users | where city == "Paris" | single
-- error: single expected exactly 1 row(s), found more
```

`first` stops the scan as soon as one row has passed, and `sort ... | first` runs as a bounded Top-1.

### `sample`

```text
sample <n>
```

Returns `n` documents chosen uniformly at random, or all of them when there are fewer. Memory is bounded by `n` whatever the input size.

```text
on orders | where status == "paid" | sample 2
```

### `unwind`

```text
unwind <field.path> [with index <field.path>] [keep empty]
```

Emits one row per item of the array at the path, with the item in place of the array, in order.

* A row whose field is missing or not an array passes through unchanged.
* A row whose array is empty is dropped, unless `keep empty` is given: the field is then `null`.
* `with index <field>` stores the 0-based position of each item.

```text
on users | unwind tags with index position | select name, tags, position
-- {"name":"Alice","position":0,"tags":"admin"}
-- {"name":"Alice","position":1,"tags":"dev"}
-- {"name":"Bob","position":0,"tags":"dev"}
-- {"name":"Dan","position":0,"tags":"ops"}

on users | unwind tags keep empty | where tags == null | select name
-- {"name":"Carol"}
```

### `distinct`

```text
distinct                      -- whole-document equality
distinct <field.path>, ...    -- keeps the first document per distinct key
```

```text
on orders | select status | distinct
-- {"status":"paid"}
-- {"status":"pending"}
-- {"status":"cancelled"}

on orders | distinct region, status
```

### `count`

```text
count
count as <alias>
```

Terminal. It returns a single document holding the number of input documents.

```text
on orders | where price > 20 | count as expensive_orders
-- {"expensive_orders":3}
```

### `group`

**Compact form:**

```text
group <key> [as <alias>]                                -- group + count
group <key> [as <alias>], ..., <measure> [as <alias>]   -- group + sum(measure)
```

* **One item:** group by that key and emit `count`.
* **Two or more items:** every item except the last is a grouping key, and the **last item is summed**.
* Every key and the measure can be renamed with `as`. Keys may be nested paths.

```text
on orders | group status
-- {"count":4,"status":"paid"}
-- {"count":1,"status":"pending"}
-- {"count":1,"status":"cancelled"}

on orders | group region, qty
-- {"qty":8,"region":"EU"}
-- {"qty":8,"region":"US"}

on orders | group region as zone, month, qty as units | sort units desc

on orders | group product | sort count desc | limit 2
-- {"count":3,"product":"P1"}
-- {"count":2,"product":"P2"}
```

**Compound form**, for several measures:

```text
group
| by <key> [as <alias>], ...
| sum|avg|min|max|first|last|list|median|stddev <value> [where <predicate>] [as <alias>]
| percentile <value> <fraction> [where <predicate>] [as <alias>]
| first|last <value> by <order> [where <predicate>] [as <alias>]
| count [<value>] [where <predicate>] [as <alias>]
| ...
| end
```

`by` is required and appears exactly once. Measures appear zero or more times, in any order. With no measure, the group emits `count`.

| Measure                                            | Result                                                                                             | Default alias                     |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------------------- |
| `sum <field>`                                      | Sum of the numeric values (integer while exact)                                                    | `<field>`                         |
| `avg <field>`                                      | Mean of the numeric values, `null` when there are none                                             | `avg_<field>`                     |
| `min <field>`, `max <field>`                       | Smallest / largest non-null value                                                                  | `min_<field>`, `max_<field>`      |
| `first <field>`, `last <field>`                    | Value on the first / last row of the group, in input order                                         | `first_<field>`, `last_<field>`   |
| `first <value> by <order>`, `last <value> by <order>` | Value on the row of smallest / largest `<order>`, whatever the input order                      | `first_<field>`, `last_<field>`   |
| `count`                                            | Number of rows                                                                                     | `count`                           |
| `count <field>`                                    | Number of rows where the field is present and not `null`                                           | `count_<field>`                   |
| `list <field>`                                     | Array of the values neither missing nor null, in input order                                       | `list_<field>`                    |
| `median <value>`, `percentile <value> <fraction>`, `stddev <value>` | The functions of the same name over the group's numbers | `median_<field>`, `percentile_<field>`, `stddev_<field>` |

* A measured value, and a `by <order>`, may be any expression. An expression needs `as <alias>`.
* `where <predicate>` measures only the rows the predicate keeps. `count where <predicate>` counts the kept rows.
* Grouping keys are field paths. To group by a computed value, `derive` it first.
* A sum stays an integer while every term is an integer and the total fits in 64 bits. Non-numeric values are ignored by sums.
* Groups are emitted in group-key order. A large `group` spills to disk instead of growing in memory.

```text
on orders | group | by region | avg price as mean | max qty | count as rows | end
-- {"max_qty":5,"mean":39.833333333333336,"region":"EU","rows":3}
-- {"max_qty":4,"mean":119.83333333333333,"region":"US","rows":3}

on orders
| group
    | by region
    | sum price * qty as revenue
    | sum qty where status == "paid" as paid_units
    | count where status == "cancelled" as cancelled
    | last product by order_id as last_product
    | list user as customers
| end
-- {"cancelled":0,"customers":["Alice","Alice","Bob"],"last_product":"P1","paid_units":3,"region":"EU","revenue":169.5}
-- {"cancelled":1,"customers":["Carol","Dan","Carol"],"last_product":"P1","paid_units":5,"region":"US","revenue":588.5}
```

### `bucket`

```text
bucket <expression> by [<b0>, <b1>, ...] [default <value>] [as <alias>]
```

Counts rows per range `[b(i), b(i+1))`. Each row falls in the bucket named by its lower bound. Rows outside every range go to `default`, or to `null` without it. The alias defaults to `bucket`. Boundaries must be strictly ascending.

```text
on users | bucket age by [0, 18, 40] default "40+" as band
-- {"band":0,"count":1}
-- {"band":18,"count":2}
-- {"band":"40+","count":1}
```

`bucket` is shorthand for `derive <alias> = bucket(<expression>, [...], <default>) | group <alias>`.

### `pivot`

```text
pivot
| rows    <field>, ...
| columns <field>, ...
| values  <field> [as <alias>] | <expression> as <alias>, ...
| aggregate sum|count|avg|min|max|first|last
| end
```

Emits one row per row key, with one cell per column value. Each directive appears exactly once.

* `values` takes one or more measures, written like `select` items. With one measure, each cell is named after its column. With several, cells are named `<column>.<name>`.
* A cell with no row is absent: read it with `?`.
* Stages may follow `pivot`.
* The aggregate cells must fit the query memory budget: `pivot` does not spill.

```text
on orders | pivot | rows region | columns month | values qty | aggregate sum | end
-- {"2026-01":7,"2026-02":1,"region":"EU"}
-- {"2026-01":7,"2026-02":1,"region":"US"}

on orders | pivot | rows region | columns month | values qty, price * qty as rev | aggregate sum | end
-- {"2026-01.qty":7,"2026-01.rev":70.0,"2026-02.qty":1,"2026-02.rev":99.5,"region":"EU"}
-- {"2026-01.qty":7,"2026-01.rev":338.5,"2026-02.qty":1,"2026-02.rev":250.0,"region":"US"}
```

### `window`

```text
window
| partition by <field>, ...
| order by <field> [asc|desc], ...
| lag|lead <field> [<rows>] [as <alias>]
| cumsum|first|last <field> [as <alias>]
| row_number [as <alias>]
| ...
| end
```

Adds to every row values computed over its **partition**, taken in `order by` order.

* `order by` is required and appears once. `partition by` is optional: without it, the whole input is one partition. At least one function is required.
* Rows come out sorted by partition, then order, and keep all their fields.
* Functions run in order, so one may read a field an earlier one added.

| Function                        | Value on each row                                                             | Default alias                     |
| ------------------------------- | ----------------------------------------------------------------------------- | --------------------------------- |
| `lag <field> [<rows>]`          | The field `<rows>` rows earlier in the partition (default 1); `null` before the first | `lag_<field>`             |
| `lead <field> [<rows>]`         | The field `<rows>` rows later; `null` after the last                          | `lead_<field>`                    |
| `cumsum <field>`                | Running sum up to this row; `null` before the first number                    | `cumsum_<field>`                  |
| `first <field>`, `last <field>` | The field on the first / last row of the partition                            | `first_<field>`, `last_<field>`   |
| `row_number`                    | 1, 2, 3... within the partition                                               | `row_number`                      |

```text
on orders
| window
    | partition by region
    | order by order_id
    | lag qty as previous
    | cumsum qty as running
    | row_number as n
| end
| select region, order_id, qty, previous, running, n
```

```json
{"n":1,"order_id":1,"previous":null,"qty":2,"region":"EU","running":2}
{"n":2,"order_id":2,"previous":2,"qty":1,"region":"EU","running":3}
{"n":3,"order_id":3,"previous":1,"qty":5,"region":"EU","running":8}
{"n":1,"order_id":4,"previous":null,"qty":1,"region":"US","running":1}
{"n":2,"order_id":5,"previous":1,"qty":3,"region":"US","running":4}
{"n":3,"order_id":6,"previous":3,"qty":4,"region":"US","running":8}
```

`window` works at the top level of a pipeline. The sort it performs spills to disk when needed, and each partition must fit the query memory budget.

### `fill`

```text
fill <field> from <start> to <end> step <step> [by <field>, ...] [with <field> = <value>, ...]
```

Adds, in each partition, a row for every value of the grid `start`, `start + step`, ... up to `end` that no row of the partition holds in `<field>`.

* The partition is the rows whose `by` fields compare equal, or the whole input without `by`.
* A new row holds the `by` fields of the partition, the grid value and the `with` values. Every other field is missing.
* Rows already there pass unchanged. Rows come out sorted by the `by` fields, then `<field>`.
* The grid steps by a positive number (`from 0 to 100 step 10`), or by a date unit for date bounds (`step "month"`), written as `start` is: `"2026-01"` gives `"2026-02"`, `"2026-03"`...
* A grid holds at most 100,000 values. Bounds may be parameters.

```text
on orders
| group | by region, month | sum qty as units | end
| fill month from "2026-01" to "2026-03" step "month" by region with units = 0
```

```json
{"month":"2026-01","region":"EU","units":7}
{"month":"2026-02","region":"EU","units":1}
{"month":"2026-03","region":"EU","units":0}
{"month":"2026-01","region":"US","units":7}
{"month":"2026-02","region":"US","units":1}
{"month":"2026-03","region":"US","units":0}
```

`fill` pairs naturally with `window`: fill the missing months, then read `lag <field> 12` for the same month of the previous year.

### `lookup`

```text
lookup <collection> [as <alias>]
| <read-only stages>
| into <field>
| end
```

`join` is an alias.

For each input document, `lookup` runs the sub-pipeline over `<collection>` and stores the resulting documents as an **array** in `<field>`.

* `into <field>` is mandatory and appears exactly once.
* **Field scope.** Inside the sub-pipeline, `<lookup alias>.field` reads the joined document, `<outer alias>.field` reads the document being enriched, and unqualified fields read the joined document.
* Any expression can mix both documents: comparisons, arithmetic, `in`, functions.
* The sub-pipeline may hold `where`, `select`, `derive`, `skip`, `limit`, `first`, `unwind`, and blocking stages (`sort`, `group`, `distinct`), which run on the rows joined to each outer row.
* Lookups can nest, and stages may follow the `end`.

```text
on users as u
| lookup orders as o
    | where o.user == u.name
    | select order_id, status
    | into orders
| end
| select name, orders
```

```json
{"name":"Alice","orders":[{"order_id":1,"status":"paid"},{"order_id":2,"status":"paid"}]}
{"name":"Bob","orders":[{"order_id":3,"status":"pending"}]}
{"name":"Carol","orders":[{"order_id":4,"status":"paid"},{"order_id":6,"status":"paid"}]}
{"name":"Dan","orders":[{"order_id":5,"status":"cancelled"}]}
```

Attach only the most expensive order of each user:

```text
on users as u
| lookup orders as o
    | where o.user == u.name
    | sort price desc
    | first
    | select order_id, price
    | into top_order
| end
```

**One-line equality form.** When the join is a single equality, the sub-pipeline can be omitted:

```text
lookup <collection> [as <alias>] on <joined field> == <outer field> into <field>
```

```text
on orders | lookup products on code == product into product
on users as u | lookup orders as o on o.user == u.name into orders
```

The left side reads the joined collection and the right side the document being enriched. Rows where either field is missing do not match.

**Execution.** When the first `where` of the sub-pipeline begins with `joined == outer`, or with `starts_with(outer, joined)`, the joined collection is indexed once on the joined field instead of being scanned for each outer row. Several leading equalities make one composite key. The prefix form gives longest-prefix matching:

```text
on orders as o
| lookup values [{prefix: "P", family: "other"}, {prefix: "P1", family: "pens"}] as r
    | where starts_with(o.product, r.prefix)
    | derive length = len(prefix) | sort length desc | first
    | select family
    | into family
| end
| select order_id, product, family
| limit 3
-- {"family":[{"family":"pens"}],"order_id":1,"product":"P1"}
-- {"family":[{"family":"other"}],"order_id":2,"product":"P2"}
-- {"family":[{"family":"pens"}],"order_id":3,"product":"P1"}
```

`lookup values [...] as v` joins literal rows, and `lookup view <name> as v` joins a view.

### `union`

```text
union
| on <collection> [as <alias>]
| <read-only stages>
| end
```

Emits the main stream, then the documents of the sub-pipeline. The first sub-stage must be `on <collection>`.

```text
on users | select name | union | on products | select label | end
```

A branch takes any read pipeline (`sort`, `group`, `lookup`, another `union`), and any stage may follow the `end`:

```text
on orders
| where region == "EU"
| group | by month | sum qty as units | end
| union
    | on orders
    | where region == "US"
    | group | by month | sum qty as units | end
| end
| group | by month | sum units as units | end
-- {"month":"2026-01","units":14}
-- {"month":"2026-02","units":2}
```

### Writes

Every write runs in **one transaction**: all mutations commit, or none do.

Write stages are **terminal**: nothing can follow them.

The response contains the mutation counters (`inserted`, `replaced`, `deleted`). `insert` of one document and `set` also return the written documents.

### `insert`

```text
insert { <key>: <value>, ... }
insert [ { <key>: <value>, ... }, ... ]
```

Inserts one document, or every object of an array in one transaction. Keys may be unquoted identifiers or JSON strings. `insert` must be the only stage of its pipeline.

With an array, a row carrying the `_id` of an existing document is merged into it.

```text
on users | insert {name: "Frank", age: 52, tags: ["new"], profile: {country: "IT"}, active: true}
on users | insert [{name: "Gus", age: 20}, {name: "Hal", age: 33}]
```

### `set`

```text
set <field.path> = <expression>, ...
```

Updates every document that reaches it. Target paths can be nested and are created when missing.

Every value is computed from the document **as it was before the `set`**, so `set a = b, b = a` swaps two fields.

```text
on users | where name == "Bob" | set active = true, profile.level = "gold", age = 18
on users | where name == "Bob" | set age = age + 1, nickname = lower(name)
on users | sort name | limit 1 | set top = true
```

`sort`, `skip` and `limit` can precede `set`.

### `delete`

```text
delete
```

Deletes every document that reaches it. It takes no arguments.

```text
on orders | where status == "cancelled" | delete
on staging | delete
```

### `into`

```text
into <collection>
```

`out` is an alias.

Inserts every row that reaches it into another collection, in one transaction, and returns no rows. Each stored row gets a fresh `_id`. The source collection is never modified.

The target must differ from the source and cannot be a system collection.

```text
on users | where active | into archive
on orders | group | by region | sum qty as units | end | into region_totals
```

### `load`

Bulk import and upsert.

```text
load
| with replace | update | merge
| chunk [ {...}, {...}, ... ]
| chunk [ ... ]
| end
```

* `with` sets the mode and is required exactly once. At least one `chunk` is required.
* Each chunk is a JSON array of objects.
* `load` must be the first stage.
* Rows without an `_id` get a fresh one. Rows with an `_id` are matched against existing documents:

| Mode      | `_id` exists                            | `_id` absent from the collection | Row without `_id` |
| --------- | --------------------------------------- | -------------------------------- | ----------------- |
| `replace` | whole document replaced                 | inserted                         | inserted          |
| `merge`   | incoming fields merged over stored ones | inserted                         | inserted          |
| `update`  | incoming fields merged over stored ones | **error**, nothing committed     | **error**         |

The whole load is atomic. An invalid `_id`, a duplicate `_id` in one request or an `update` miss rolls back every chunk.

```text
on tmp | load | with merge | chunk [{"_id":"01900000-0000-7000-8000-0000000000a1","a":1,"b":1}] | end
on tmp | load | with merge | chunk [{"_id":"01900000-0000-7000-8000-0000000000a1","b":2,"c":3}] | end
on tmp
-- {"_id":"01900000-0000-7000-8000-0000000000a1","a":1,"b":2,"c":3}

on tmp | load | with merge | chunk [{"n":1},{"n":2}] | chunk [{"n":3}] | end
```

---

## Past states and history

A source can be read at a past point, or as the list of its stored versions.

History must be kept by the store:

```bash
OGD_HISTORY=on
```

Without it, `as of` and `history` fail with `this store does not keep history`.

```text
on orders as of "2026-09-01T12:00:00Z" | where status == "paid" | count
on orders as of 1842 | sort price desc | limit 10
on orders history | where _op == "delete"
on orders as of "2026-09-01" | into orders_restored
```

* `as of <string>` reads the store as it was at that time (ISO 8601; a date alone means midnight UTC). `as of <number>` reads it at that commit generation. Every collection of the query is read at that point, `lookup` and `union` collections included.
* `history` returns one row per stored write of the collection, in commit order. Each row holds the document of the version plus the fields below.
* Both are read-only. A stage that writes is rejected, except a terminal `into`, which copies the rows into another collection: a restore.
* A generation after the current one is an error. A date after the last commit reads the current state.

| Field               | Meaning                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| `_id`               | Identifier of the history row: distinct and ordered                                                  |
| `_doc_id`           | Identifier of the document                                                                           |
| `_version`          | Version of the document written, or deleted for a `delete` row                                       |
| `_op`               | `insert`, `replace`, `delete` (the row holds the document as it was deleted), or `baseline` (present when history recording started) |
| `_generation`       | Commit generation                                                                                    |
| `_at`               | Commit time (ISO 8601), `null` when not recorded                                                     |
| `_by`, `_by_device` | Identity and device that made the commit, `null` when unknown                                        |

---

## Views

A view is a named read query, kept in the `_views` collection with one document per version.

What a view brings:

* **Reuse.** A query is written once, named, and read like a collection by any other query.
* **Parameters.** The same view serves different readers: each one binds its own `$name` values.
* **Composition.** Views read other views, and can be filtered, joined, grouped or united like any source.
* **No hidden cost.** A view is expanded before planning, so a query over a view is optimized as if it had been written in full.
* **Versions.** Every definition is kept. A previous version can be read or restored.
* **Kept results.** A materialized view computes its rows once and serves them until its sources change.

Like `explain`, `define view` is a statement, not a stage:

```text
define view sales.by_region
| description "Units and revenue per region"
| exec
  | on orders
  | where status == $status
  | group | by region | sum qty as units | sum price * qty as revenue | end
  | end
| end
```

* `exec` is the last clause. The body runs from `exec` to the two final `end`.
* The parameters of a view are the `$name` its body reads without declaring them with `let`. They are bound by the reading query.
* The body is checked when the view is defined, and refused when it writes.
* Each `define` writes a new version and supersedes the previous one. History is never rewritten.
* `define view <name> | description "..." | end` changes the description. `define view <name> | version <n> | end` restores version `n` as a new version. `undefine view <name>` deletes the active version.
* `explain define view ...` checks without writing.

A view is read as a source, in the main pipeline, in a `union` branch, or as the joined side of a `lookup`:

```text
let $status = "paid" | on view sales.by_region | sort revenue desc
-- {"region":"US","revenue":290.0,"units":5}
-- {"region":"EU","revenue":119.5,"units":3}

let $status = "paid" | on view sales.by_region version 1 | where region == "EU"

on _views | where name == "sales.by_region" | select version, state, parameters
```

* The query of the view replaces the source before planning, so the stages that follow are optimized with it: a filter written after a view reaches its source.
* A view can read other views, 8 deep at most. A cycle is refused when the view is defined.

**Materialized views.** `| materialized |` before `exec` keeps the rows of the view. The first read computes them, and later reads use the kept rows until a collection the view reads changes, or a view it reads (at any depth) is redefined, restored or undefined. A materialized view takes no parameter: its body binds what it needs with `let`, and filters written after `on view` apply to the kept rows.

* The rows are kept per scope (Place and App instance) in cache collections listed by `on _cache`. A write in one Place leaves the rows of the other Places alone.
* When a view is redefined, `glacierdb` computes again, in the background, the materialized views that read it, in every scope they were already kept for: the next reader finds them ready.
* The rows of an earlier version of a view are dropped once the new ones are in.
* Separately, the rows of repeated read requests are kept in memory for a minute (the result cache, bounded by the memory profile, `OGD_RESULT_CACHE=off` to disable).

```text
define view sales.totals
| materialized
| exec
  | on orders | group | by region | sum qty as units | end
  | end
| end
```

---

## Composition rules

### Planner rules

| Rule                                                                                 |
| ------------------------------------------------------------------------------------ |
| Nothing may follow a terminal stage: `set`, `delete`, `insert`, `load`, `into`, `count` |
| `insert` must be the only stage                                                      |
| `load` must be the first stage                                                       |
| Unknown stage names are rejected                                                     |
| Stage arguments are validated before any storage access                              |

**Filters move towards the source.** The planner splits `where a and b` and moves each filter before the stages that leave alone the fields it reads and the set of rows: `derive`, `select`, `rename`, `drop`, `sort`, and `group` or `pivot` when the filter reads only their keys. Results and errors are unchanged. `explain` shows the resulting plan.

### Bounded execution

glacierdb never falls back to "load everything into memory". A read query runs in one of two shapes:

1. **Pure streaming.** Any mix of `where`, `select`, `derive`, `rename`, `drop`, `root`, `near`, `unwind`, `skip`, `limit`, `first`, `single`, optionally followed by `count`. Documents flow one by one, and a row bound (`limit`, `first`) stops the scan early.
2. **Streaming prefix, then blocking stages.** The blocking stages are `sort`, `distinct`, `group`, `pivot`, `window`, `fill`, `sample`, `lookup` and `union`. Any number of them may follow one another, each followed by row-local stages.

In the second shape:

* a `skip` / `limit` (or `first`) after a blocking stage bounds that stage: `sort k | skip 10 | limit 5` runs as a bounded Top-15;
* `sort` and `group` spill sorted runs to disk when their state outgrows the memory they can get;
* every blocking stage reserves memory as its state grows, and all of them together stay within the query budget.

A shape with no bounded executor is rejected before execution.

---

## System collections

Collections whose name starts with `_` are reserved.

They can be queried with the full language. The first four below are **virtual**: they are computed on read from live engine state.

| Collection            | Content                                                                                           |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| `_memory`             | One `global` row (profile, limits, current and peak bytes, pressure state, spill counters) and one row per memory class |
| `_query_memory`       | Query admission budget and one row per running operation                                          |
| `_memory_events`      | Recent memory reservations and releases                                                           |
| `_index_observations` | Per-query-shape execution statistics: fingerprint, access path, executions, scanned, returned, elapsed |
| `_views`              | Views and their versions                                                                          |
| `_cache`              | Kept rows of materialized views                                                                   |

```text
on _memory | where scope == "global" | select profile, current_bytes, pressure_state
on _index_observations | sort executions desc | limit 10
```

Other system collections (`_identities`, `_devices`, `_permissions`, ...) are managed by the daemon and protected by authorization.

---

## Results and statistics

A query returns a stream of documents followed by execution statistics:

```json
{"documents":[...],
 "statistics":{"committed":false,"deleted":0,"filtered":1,"inserted":0,
               "replaced":0,"returned":3,"scanned":4,
               "strategies":["collection_scan"],"streamed":true,
               "timings_us":{"parse":29,"plan":116,"execute":436,"materialize_response":55}}}
```

| Field                                             | Meaning                                                                       |
| ------------------------------------------------- | ----------------------------------------------------------------------------- |
| `scanned` / `filtered` / `returned`               | Documents read, rejected by predicates, emitted                               |
| `inserted` / `replaced` / `deleted` / `committed` | Write counters, and whether a transaction was committed                       |
| `strategies`                                      | Physical strategies used: `collection_scan`, `primary_key_lookup`, ...        |
| `streamed`                                        | `true` when rows were streamed to the client as they were produced            |
| `timings_us`                                      | Per-phase timings in microseconds. Plans are cached, so a repeated query skips planning |

With `glaciercli`, `-q` prints only the documents and `--compact` prints the response as compact JSON.

---

## Errors

Errors come from four layers, and each message carries a byte span or a stage location.

| Layer     | When                                   | Example                                                                     |
| --------- | -------------------------------------- | --------------------------------------------------------------------------- |
| Lexer     | Unknown character, bad string or number | ``lex error: unexpected character `@` at 9..10``                           |
| Parser    | Pipeline structure                     | `parse error: expected stage name, found operator at 11..12`                |
| Planner   | Stage arguments, expressions, ordering | `unknown stage "frobnicate"`, ``unknown function `nope` ``                  |
| Execution | Data-dependent                         | `field path "nickname" is missing`, `single expected exactly 1 row(s), found 0` |

Planning errors are raised before any storage access. Write errors roll back the whole transaction.

---

## Known limitations

| Area             | Limitation                                                                     | Workaround                                           |
| ---------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------- |
| Missing fields   | A missing field fails the query, except in `exists`, `coalesce` and optional paths | `x?`, `exists(x) and ...`, `coalesce(x, default)` |
| `group` keys     | Field paths only                                                               | `derive` the computed key first                      |
| `sort`           | The values of a key other than `null` must all be numbers, all texts or all booleans | `to_string(...)` or `to_float(...)` in a `derive` first |
| `pivot`          | Aggregate cells must fit the query memory budget (no spill)                    | Filter or `select` before it                         |
| `window`         | Top level only; each partition must fit the query memory budget; keys are field paths | Partition more finely; `derive` computed keys first |
| `fill`           | Top level only; `<field>` and `by` are field paths; at most 100,000 grid values | `derive` computed fields first                      |
| Dates            | No native type; date functions read epoch milliseconds or ISO-8601 strings, in UTC | `date_*` functions                               |
| Vector search    | Exact distance computation, no approximate index                               | Filter candidates with `where` before `near`         |
| Not in the language | Recursive queries, user-defined functions, full-text search, geospatial operators |                                                 |

---

## Grammar summary

The pipeline layer is below. Each stage then interprets its argument text with the grammar given in the [stage reference](#stage-reference).

```ebnf
request      = [ "explain" ] , { let-header } , query ;
let-header   = "let" , variable , ( "=" | "?=" ) , expression , { "," , variable , ( "=" | "?=" ) , expression } , "|" ;
variable     = "$" , identifier ;
query        = source , { "|" , stage } ;
source       = ( "on" | "from" ) , collection , [ temporal ] , [ "as" , identifier ] ;
temporal     = "as" , "of" , ( string | number ) | "history" ;
collection   = identifier , { "." , identifier } ;

stage        = simple-stage | compound-stage ;
simple-stage = stage-name , arguments ;
compound-stage
             = ( "lookup" | "join" ) , arguments , sub-pipeline   (* unless the header contains `into` *)
             | ( "union" | "pivot" | "window" ) , sub-pipeline
             | ( "load" | "group" ) , sub-pipeline ;               (* header-less form only *)
sub-pipeline = { "|" , stage } , "|" , "end" ;
arguments    = { token } ;                        (* up to the next top-level "|", brackets balanced *)

expression   = or-expr ;
or-expr      = and-expr , { ( "or" | "||" ) , and-expr } ;
and-expr     = not-expr , { ( "and" | "&&" ) , not-expr } ;
not-expr     = ( "not" | "!" ) , eq-expr | eq-expr ;
eq-expr      = rel-expr , { ( "==" | "!=" ) , rel-expr } ;
rel-expr     = add-expr , { ( "<" | "<=" | ">" | ">=" | "in" | "not" , "in" ) , add-expr
                          | [ "not" ] , "between" , add-expr , ( "and" | "&&" ) , add-expr } ;
add-expr     = mul-expr , { ( "+" | "-" ) , mul-expr } ;
mul-expr     = unary , { ( "*" | "/" | "%" ) , unary } ;
unary        = ( "-" | "+" ) , unary | primary ;
primary      = literal | variable | call | field-path | array | object | "(" , expression , ")" ;
object       = "{" , [ member , { "," , member } ] , "}" ;
member       = string , ":" , expression ;
call         = identifier , "(" , [ expression , { "," , expression } ] , ")" ;
array        = "[" , [ expression , { "," , expression } ] , "]" ;
field-path   = identifier , [ "?" ] , { "." , identifier , [ "?" ] } ;
literal      = "null" | "true" | "false" | number | string ;

identifier   = ( letter | "_" ) , { letter | digit | "_" } ;   (* Unicode letters *)
number       = digit , { digit } , [ "." , digit , { digit } ] , [ ( "e" | "E" ) , [ "+" | "-" ] , digit , { digit } ]
             | "." , digit , { digit } ;
string       = '"' , { char | escape } , '"' ;
escape       = "\" , ( '"' | "\" | "/" | "b" | "f" | "n" | "r" | "t" | "u" , 4 * hex ) ;
```

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
```

Dates and times are stored as epoch milliseconds or ISO-8601 strings, and handled by the date functions of the query language.

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
