-- Exercise 1: How many orders were placed in 2026?
--
-- Reads fct_orders, which is one row per order (unique + not_null tests on
-- order_id enforce that grain), so count(*) is the order count. No distinct
-- needed: de-duplicating here would hedge against a condition the model is
-- already tested for.
--
-- Header grain governs. Line-grain counting would return one more, because
-- one sales line has no order header and is dated 2026-12-31. See README.

select
    count(*) as order_count

from {{ ref('fct_orders') }}

where order_date >= date({{ var('reporting_year') }}, 1, 1)
  and order_date < date({{ var('reporting_year') }} + 1, 1, 1)