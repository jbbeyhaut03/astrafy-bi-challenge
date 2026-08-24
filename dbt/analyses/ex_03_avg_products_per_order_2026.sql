-- Exercise 3: Average number of products per order, per month of 2026.
--
-- "Number of products" is units, not distinct products: qty_product on
-- fct_orders is sum(order_qty), so a product ordered three times counts three.
-- One reading across the whole project, declared in the README.
--
-- fct_orders is already one row per order, so avg(qty_product) and
-- sum(qty_product) / count(*) are the same number. avg states the intent.

select
    date_trunc(order_date, month) as order_month,
    avg(qty_product) as avg_products_per_order

from {{ ref('fct_orders') }}

where order_date >= date({{ var('reporting_year') }}, 1, 1)
  and order_date < date({{ var('reporting_year') }} + 1, 1, 1)

group by all
order by order_month