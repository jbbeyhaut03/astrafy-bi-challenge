{{
    config(
        materialized='table',
        partition_by={
            'field': 'order_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by=['client_id']
    )
}}

-- Exercise 6: one row per 2026 order, with its segment.
--
-- Both CTEs filter on a bare order_date against constants -- the shape BigQuery
-- documents as prunable. extract(year from order_date) also prunes here (both
-- forms dry-run at 20,584 bytes, exactly the 12 in-year partitions), but that
-- relies on the planner inverting the function, which is optimizer behaviour
-- rather than a documented guarantee. The range form needs no such check and
-- stays correct if order_date ever becomes a timestamp.

with orders as (

    select
        order_id,
        client_id,
        order_date,
        net_sales,
        qty_product

    from {{ ref('fct_orders') }}
    where order_date >= date({{ var('reporting_year') }}, 1, 1)
      and order_date < date({{ var('reporting_year') }} + 1, 1, 1)

),

segments as (

    -- Filtering here is only correct because int_orders_segmented.order_date
    -- and fct_orders.order_date are the same value for the same order_id --
    -- both descend from stg_orders without recomputing it. That invariant
    -- lives across two models rather than inside one, so it is held by tests
    -- rather than by construction: if it ever breaks, rows lose their segment
    -- and both not_null on order_segmentation and
    -- assert_rpt_orders_2026_complete fail.

    select
        order_id,
        order_segmentation

    from {{ ref('int_orders_segmented') }}
    where order_date >= date({{ var('reporting_year') }}, 1, 1)
      and order_date < date({{ var('reporting_year') }} + 1, 1, 1)

)

select
    orders.order_id,
    orders.client_id,
    orders.order_date,
    orders.net_sales,
    orders.qty_product,
    segments.order_segmentation

-- Left join, not inner: a missing segment must surface as null and fail the
-- not_null test, not disappear from the table.
from orders
left join segments
    on orders.order_id = segments.order_id