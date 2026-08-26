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
-- Now a straight projection of fct_orders. The segment is an attribute of the
-- order and lives on the order fact; this model exists because the exercise
-- asks for the filtered table itself as a deliverable, not because it is where
-- any logic happens. Hence rpt_ rather than fct_ or mart_.
--
-- The filter is a bare order_date against constants -- the shape BigQuery
-- documents as prunable. extract(year from order_date) also prunes here (both
-- forms dry-run at 20,584 bytes, exactly the 12 in-year partitions), but that
-- relies on the planner inverting the function, which is optimizer behaviour
-- rather than a documented guarantee. The range form needs no such check and
-- stays correct if order_date ever becomes a timestamp. Half-open on the upper
-- bound so it never has to know how long December is.

select
    order_id,
    client_id,
    order_date,
    net_sales,
    qty_product,
    order_segmentation

from {{ ref('fct_orders') }}
where order_date >= date({{ var('reporting_year') }}, 1, 1)
  and order_date < date({{ var('reporting_year') }} + 1, 1, 1)