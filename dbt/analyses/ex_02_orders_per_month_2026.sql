-- Exercise 2: How many orders per month in 2026?
--
-- date_trunc keeps the month as a DATE rather than an integer, so it sorts
-- chronologically on its own and maps directly onto a Looker dimension_group
-- in Part 2. extract(month from ...) would return 1-12, which sorts correctly
-- only inside a single year.

select
    date_trunc(order_date, month) as order_month,
    count(*) as order_count

from {{ ref('fct_orders') }}

where order_date >= date({{ var('reporting_year') }}, 1, 1)
  and order_date < date({{ var('reporting_year') }} + 1, 1, 1)

group by all
order by order_month