# Astrafy — BI Engineer Take-Home

A dbt project on BigQuery (Part 1) and a LookML semantic layer built on top of it
(Part 2). Part 3, the dashboard design challenge, is the PDF attached to the submission
email — it is a design proposal and needs no code.

```
astrafy-bi-challenge/
├── README.md
├── requirements.txt
├── data/raw/               two source .xlsx files, as received
├── scripts/                BigQuery ingestion
├── dbt/                    Part 1
└── lookml/                 Part 2
```

---

## Quickstart

Built against Python 3.14.5 on macOS arm64. Runs against any GCP project you can
authenticate to, provided the dataset names `landing`, `dbt_staging`, `dbt_intermediate`
and `dbt_marts` are free in it.

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID     # or: export GCP_PROJECT=YOUR_PROJECT_ID

.venv/bin/python scripts/load_raw_data.py     # creates landing.raw_orders, landing.raw_sales

cd dbt
../.venv/bin/dbt deps
../.venv/bin/dbt build                        # 6 models + 51 tests
../.venv/bin/dbt compile                      # renders analyses/ for Ex 1–3 and Ex 5
```

`~/.dbt/profiles.yml` is not committed and is the one thing you supply: an
`astrafy_bi_challenge` profile with `method: oauth`, `dataset: dbt`, `location: EU`, and
`project:` set to the same project as above. Region must match on both sides — everything
is created in `EU` unless `$BQ_LOCATION` says otherwise. No GCP project ID is written
anywhere in this repo; the loader reads it from the environment, dbt from
`{{ target.project }}`. The loader is idempotent and path-anchored, so it can be re-run
from any directory.

---

## Architecture

Four layers, following the layering and naming conventions in Astrafy's own published
data modeling guide (`raw_`, `stg_`, `int_`, `fct_`, `rpt_`).

```
data/raw/*.xlsx
      │  scripts/load_raw_data.py — explicit INT64 schema, no autodetect
      ▼
landing                    raw_orders (3,661)      raw_sales (28,361)
      │                    byte-faithful; column names exactly as received
      ▼
dbt_staging                stg_orders              stg_sales                (views)
      │                    rename + cast only, no business logic
      ▼
dbt_intermediate           int_orders_segmented                    (incremental table)
      │                    Ex 5 — trailing-365-day window over all history
      ▼
dbt_marts                  fct_orders (3,661)      fct_order_items (28,361)
                           rpt_orders_2026_segmented (2,573)          (tables)
      │
      ├──▶ analyses/       Ex 1, 2, 3, 5 — compile-only, all reading fct_orders
      └──▶ lookml/         Explores on fct_orders and fct_order_items
```

**Kimball, with degenerate dimensions.** `client_id` and `product_id` carry no
descriptive attribute anywhere in either source — no customer name, region or segment, no
product name or category. A dimension table would therefore be a single column already
sitting on the fact. Kimball's own term for a key carried on the fact with no attribute
table behind it is a degenerate dimension: this is a star whose spokes the source does
not contain, not a model missing its dimensions. The moment either source gains
attributes, `dim_customers` and `dim_products` slot in against keys already there.

**Two grains, because the sources have two.** `fct_order_items` is the atomic fact — the
finest grain available, which is where Kimball says to model. `fct_orders` is the header
grain and carries every attribute that is true of an order: its total, its `qty_product`,
and its `order_segmentation`.

**Staging is a pure pass-through.** Renames and casts, nothing else, reading landing
through `{{ source() }}` so the landing/dbt boundary is explicit in the lineage graph.
The three names for the customer key across the brief and the two files (`customers_id`,
`customer_id`, `client_id`) are reconciled here to the brief's term, `client_id` — and
only here.

**One intermediate model.** Ex 4's `qty_product` is one aggregation and one join, so it
goes straight to a mart. Ex 5's segmentation needs a window over full history unfiltered
by year and is consumed downstream, which is what the intermediate layer is for.

### Model reference

| Model | Layer | Materialization | Grain | Rows |
|---|---|---|---|---|
| `stg_orders` | staging | view | order | 3,661 |
| `stg_sales` | staging | view | order × product | 28,361 |
| `int_orders_segmented` | intermediate | incremental, month-partitioned, clustered `client_id` | order | 3,661 |
| `fct_orders` | marts | table, month-partitioned, clustered `client_id` | order | 3,661 |
| `fct_order_items` | marts | table, month-partitioned, clustered `order_id`, `product_id` | order × product | 28,361 |
| `rpt_orders_2026_segmented` | marts | table, month-partitioned, clustered `client_id` | order | 2,573 |

**Partitioning and clustering** target the hypothetical billions-of-rows scale. Month
rather than day: it matches Ex 2's reporting grain and stays clear of BigQuery's
4,000-partition ceiling, where daily partitioning would exhaust it in eleven years.
Clustering on `client_id` serves the customer-level filtering the semantic layer does; on
the items fact, `order_id` is the leftmost key so a point lookup on one order prunes
first.

**`int_orders_segmented` is the only incremental model.** An order's segment depends on
prior orders and never on later ones, so a computed segment is permanently correct and
history never needs reprocessing. It uses `merge` on `order_id` so a late-arriving order
updates rather than duplicates, a 365-day lookback in the source CTE to bound the scan,
and a date watermark to bound the write. Everything else is a plain table:
`fct_orders.qty_product` is mutable — a late line changes an existing order's quantity —
which is the opposite of the append-only property that justifies incremental here.

**No hardcoding.** Segmentation thresholds and the reporting year are `vars` in
`dbt_project.yml` (`segmentation_lookback_days`, `segmentation_returning_min_prior_orders`,
`segmentation_vip_min_prior_orders`, `reporting_year`), consumed by
`macros/get_order_segment.sql`. Every model reference is `ref()` or `source()`. In LookML
the equivalents are `manifest.lkml` constants — `@{gcp_project}` and `@{marts_dataset}`
interpolate into every `sql_table_name`, so no dataset name is written twice.

---

## The exercises

| Ex | Asked | Lives in | Answer |
|---|---|---|---|
| 1 | Orders in 2026 | `analyses/ex_01_orders_2026.sql` | **2,573** |
| 2 | Orders per month, 2026 | `analyses/ex_02_orders_per_month_2026.sql` | table below |
| 3 | Avg products per order per month, 2026 | `analyses/ex_03_avg_products_per_order_2026.sql` | table below |
| 4 | Order table + `qty_product`, 2025–26 | `models/marts/fct_orders.sql` | 3,661 rows |
| 5 | Order segmentation, 2026 | `models/intermediate/int_orders_segmented.sql` → `fct_orders.order_segmentation`; counts in `analyses/ex_05_order_segments_2026.sql` | 1,255 / 810 / 508 |
| 6 | 2026 orders + `order_segmentation` | `models/marts/rpt_orders_2026_segmented.sql` | 2,573 rows |

### Ex 2 and Ex 3, 2026

| Month | Orders | Avg units per order |
|---|---|---|
| Jan | 232 | 12.57 |
| Feb | 176 | 12.62 |
| Mar | 203 | 13.07 |
| Apr | 188 | 15.10 |
| May | 172 | 14.63 |
| Jun | 169 | 14.18 |
| Jul | 193 | 13.75 |
| Aug | 167 | 14.46 |
| Sep | 212 | 13.67 |
| Oct | 223 | 13.03 |
| Nov | 389 | 10.48 |
| Dec | 249 | 11.37 |
| **Total** | **2,573** | |

Twelve rows summing to 2,573 — no month is dropped by the `group by`, so no date spine is
warranted here.

### Ex 5 — segmentation, 2026

| Segment | Orders |
|---|---|
| New | 1,255 |
| Returning | 810 |
| VIP | 508 |
| **Total** | **2,573** |

Ex 5 asks for the segment of each order placed in 2026, so the answer is scoped to 2026 —
but the window that produces it is not. An order in January 2026 is segmented against the
customer's orders back to January 2025, which is why `int_orders_segmented` runs over full
history and the year filter is applied only when reporting. The total cross-checks against
Ex 1 and the Ex 6 row count, reached by three different paths.

---

## Design decisions

**Ex 1–3 and the Ex 5 counts are questions, not tables.** Four files in `analyses/`, not
models. Materialising a one-row table to hold a filtered `COUNT(*)` is precisely the
anti-pattern a semantic layer exists to remove — and it would leave a stale number in the
warehouse the moment the data changed. `dbt run` ignores `analyses/`; `dbt compile`
renders them with `ref()` and `var()` resolved into `target/compiled/`, where they run
directly. All four read `fct_orders`, one parent, so the answers cannot disagree with each
other. In Looker the same four are Order Count filtered to Order Year 2026, Order Count by
Order Month, Average Units per Order by Order Month, and Order Count by Order Segment.

**`fct_orders` carries no year filter.** Ex 4 asks for 2025 and 2026, and the extract
contains nothing else — it runs 2025-07-09 to 2026-12-31, so a year filter here would
remove no rows at all. Writing one anyway would bake a question into a fact table and
break the same table for Ex 6. The year restriction is a question asked of the table, not
a property of it, so it lives in `analyses/` and in the Ex 6 mart.

**`order_segmentation` sits on `fct_orders`, not only on the Ex 6 table.** What belongs on
a fact table is decided by its grain, not by which exercise asked. `order_segmentation` is
true of exactly one order, at order grain, and is immutable once that order exists.
`qty_product` sits there on identical grounds and would belong there even if Ex 4 had
never been written. `rpt_orders_2026_segmented` is then a projection of `fct_orders` — one
parent, no join, no logic — which is what the `rpt_` prefix declares: single-use, not
reusable. Anything reusable reads `fct_orders`, including the Ex 5 analysis.

**Year filters use a half-open date range.**
`order_date >= date(2026,1,1) and order_date < date(2027,1,1)`, in the Ex 6 mart, the four
analyses and the completeness test. Measured with `--dry_run`, BigQuery prunes
`extract(year from order_date) = 2026` identically — both estimate 20,584 bytes, the twelve
in-year partitions. The range form is kept because it is the shape BigQuery documents as
prunable, so it never depends on which functions the planner happens to invert, and because
it stays unambiguous if `order_date` ever becomes a timestamp. It is not a performance
claim.

**Both joins into `fct_orders` are left joins.** An inner join would silently drop any
order header with no lines or no segment. The left joins keep every header, return `null`
on a missing match, and `not_null` tests turn that silence into a build failure. Both pass.
The quantity aggregate is reduced to one row per `order_id` before the join, so the join is
1:1 by construction and cannot fan out — aggregate then join, never join then aggregate.

**Money is `NUMERIC`.** `net_sales` is cast to an exact decimal in both staging models.
Float sums do not compare cleanly and the reconciliation test compares two sums. Landing
stays exactly as loaded.

---

## Data notes

Four things a reviewer will find in the data. All are disclosed rather than patched.

**One sales line has no order header.** `order_id 5361303` exists in `sales` with no row in
`orders`. No model names it and no model filters it: `fct_order_items` retains it because a
fact table records what was recorded, and every order-grain model is free of it by
construction because those models start from `stg_orders`. The exclusion is a layer
contract, not a `where` clause — handling the class (a line whose header is missing), never
the row.

It is dated 2026-12-31, so counting orders at line grain would give 2,574 for 2026 against
Ex 1's 2,573. **The header table is the order register** — the brief's own words are
"Orders: 1 line per order" — so the header definition governs everywhere, including Ex 1.
Two tests report the row and both warn rather than fail (below).

**The segmentation window is bounded by the extract.** The data runs 2025-07-09 →
2026-12-31, so a full 365-day lookback only exists for orders from 2026-07-09 onward. Read
literally, Ex 5 defines a rule over a set of orders — count this customer's orders in the
365 days before this one — and applied to the data given, that count is exact. "New" is not
read as a claim that the customer had no prior relationship with the business; that is an
inference the brief does not make, and withholding a segment before July would require
inventing a fourth category the brief does not define, against an exercise that says
*calculate for each order placed in 2026*. Every 2026 order is segmented. This changes no
SQL and is repeated in the model description and the LookML dimension description.

**Segment is an attribute of the order, not of the customer.** Across full history there
are 1,747 New orders against 1,716 distinct customers — the same customer can be New more
than once, from a gap longer than 365 days, which the rule treats as a reset by design.
Reading the label as a customer count gives a wrong answer, so the LookML measure is named
"Distinct Customers (with orders)" and its description states that segment values will not
sum to the total.

**"Products per order" means units.** `qty_product` is `sum(order_qty)`, and the same
reading governs Ex 3's average — a repeated product counts once per unit. One definition
across the whole project rather than a second `product_count` column hedging the
interpretation.

Two documented approximations in Ex 5: "12 months" is 365 days, because BigQuery `range`
window frames accept only numeric offsets and the exact-calendar alternative is an O(n²)
correlated self-join that fails the billions-of-rows requirement; and same-day orders are
excluded from the prior count (`1 preceding`), because `stg_orders` holds a date and not a
timestamp, so ordering within a day would be arbitrary.

Neither source states a currency, so revenue is formatted as a plain decimal throughout
rather than inventing a symbol.

---

## Testing

`dbt build` runs 57 nodes — 6 models and 51 tests — at **PASS=55, WARN=2, ERROR=0**.

Generic tests cover the grain of every model (`unique` + `not_null` on the key,
`unique_combination_of_columns` on `stg_sales(order_id, product_id)` which has no single
key), `not_null` on every column, `relationships` from sales lines to order headers, and
`accepted_values` on the segment. Two singular tests live in `tests/`.

**Every model also carries a completeness assertion.** A model can pass every property test
while holding a fraction of its rows: during development `int_orders_segmented` built 11/11
green on 1,602 of 3,661 rows, because `unique`, `not_null`, `accepted_values` and
`relationships` all assert properties of the rows that are present and none assert that the
model is complete. `dbt_utils.equal_rowcount` against the source closes that, and on
`fct_orders` it does double duty — it catches a truncated build and a fan-out at once, since
a multiplying join would push the count above 3,661.

`assert_order_revenue_reconciles` is per-order with a `FULL OUTER JOIN`, catching three
failure classes in one test: a line without a header, a header without lines, and a matched
order whose lines do not sum to its total. It returns one row per non-reconciling order, so
the result is a magnitude rather than a boolean. `coalesce(..., 0)` on both sides is
load-bearing — on an unmatched row one side is null, `null != x` evaluates to null, and the
row would escape the predicate entirely.

**The two warnings are the same known anomaly, reported deliberately.** The staging
`relationships` test and `assert_order_revenue_reconciles` both configure
`severity: error, error_if: ">10", warn_if: ">0"`. One orphan warns; eleven break the build.
That encodes the row as known, triaged and accepted at its current magnitude, and failing
loudly if it ever becomes systemic — rather than either suppressing it or blocking on it.

Tests are written to what should be true given the grain and the business rules, not
calibrated after the fact to what is already known to pass.

---

## Part 2 — LookML

```
lookml/
├── manifest.lkml            constants gcp_project, marts_dataset
├── astrafy.model.lkml       connection, includes, datagroup
├── views/                   fct_orders, fct_order_items
└── explores/                fct_orders, fct_order_items
```

Two views and two explores, one grain each, named after their tables so the Looker field
picker and the dbt lineage graph use the same words.

**The explores do not join to each other.** Header → line is one-to-many, so joining them
would repeat each header once per line and inflate every order-grain sum. Symmetric
aggregates would technically prevent that, but one declared grain per explore is cheaper at
scale and cannot be misread. The items explore joins the header for exactly one field —
`fields: [fct_orders.order_segmentation]`, `many_to_one`, `left_outer` — which is enough to
ask "revenue by product for VIP orders" and not enough to put two Order Dates in the field
picker. `left_outer` rather than inner so order 5361303 stays in the explore with a null
segment: the semantic layer does not delete a row the fact table deliberately kept.

**`rpt_orders_2026_segmented` is not exposed.** It is a projection of `fct_orders` with
identical columns and one year of rows, so exposing it would give the layer two tables that
answer "how many orders" differently depending on which one gets picked — exactly the
hallucination the GenAI-readiness requirement asks us to design out. One right way to ask
each question is the design rule throughout: raw numeric columns (`net_sales`,
`qty_product`, `order_qty`) are hidden dimensions reachable only through measures, and no
filtered per-segment measures exist, because the segment dimension already answers those by
pivoting.

**"LookML parameters" is read as field properties** — `description:` and `label:` on every
exposed field, plus `group_label:`, `suggestions:` on the segment, `value_format_name:`,
`drill_fields:` and `hidden:`. That is what Conversational Analytics consumes. A literal
`parameter` field type was considered as a metric selector and rejected: a templated-value
field is the kind of artifact an AI mishandles, and adding one would have been a keyword
hunt rather than a design.

**Caching is tied to the pipeline.** A `datagroup` whose `sql_trigger` reads
`max(last_modified_time)` from `dbt_marts.__TABLES__` for the two exposed tables, with
`max_cache_age: "24 hours"` as a backstop, applied model-wide with `persist_with`. A dbt run
is what refreshes Looker, which is the correct dependency direction.

**Deployment note.** This is structurally ready, not deployed, and unvalidated by
construction. `connection: "astrafy_bigquery"` names a connection that exists inside a
Looker instance, which this project does not have — it must be created there and pointed at
the BigQuery project in region `EU`. Looker treats a repository root as the project root, so
a real deployment points at `lookml/` as the project root or splits it into its own repo. No
LookML validator has run over these files: every claim above is a claim about their
structure, not about a run.