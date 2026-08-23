{{
    config(
        severity='error',
        error_if='>10',
        warn_if='>0'
    )
}}

-- FULL OUTER JOIN and COALESCE are load-bearing: an inner join would
-- drop the unmatched rows this test exists to catch, and a null on
-- either side would escape the inequality predicate.

with header_revenue as (

    select
        order_id,
        net_sales as header_net_sales

    from {{ ref('fct_orders') }}

),

line_revenue as (

    select
        order_id,
        sum(net_sales) as line_net_sales

    from {{ ref('fct_order_items') }}
    group by order_id

)

select
    coalesce(header_revenue.order_id, line_revenue.order_id) as order_id,
    header_revenue.header_net_sales,
    line_revenue.line_net_sales,
    coalesce(line_revenue.line_net_sales, 0)
        - coalesce(header_revenue.header_net_sales, 0) as net_sales_difference

from header_revenue
full outer join line_revenue
    on header_revenue.order_id = line_revenue.order_id

where coalesce(line_revenue.line_net_sales, 0)
    != coalesce(header_revenue.header_net_sales, 0)