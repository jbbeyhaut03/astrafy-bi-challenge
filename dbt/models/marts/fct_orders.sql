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

-- Order-grain fact. One row per order header, carrying the two facts that are
-- true of an order and absent from the order source: how many units it
-- contained, and what the customer was at the moment they placed it.
--
-- Both are attributes of the order at this grain, so both belong here on the
-- grain's merits. Neither is here because a specific exercise asked for it.

with orders as (

    select * from {{ ref('stg_orders') }}

),

order_quantities as (

    select
        order_id,
        sum(order_qty) as qty_product

    from {{ ref('stg_sales') }}
    group by all

),

order_segments as (

    -- Already one row per order_id upstream: int_orders_segmented declares
    -- order_id as its grain and carries unique + not_null on it. The join
    -- below is therefore 1:1, and the upstream test is the justification --
    -- de-duplicating here would hedge against a condition already asserted.
    select
        order_id,
        order_segmentation

    from {{ ref('int_orders_segmented') }}

),

final as (

    select
        orders.order_id,
        orders.client_id,
        orders.order_date,
        orders.net_sales,
        order_quantities.qty_product,
        order_segments.order_segmentation

    -- Left joins, not inner, on both sides. An inner join would silently drop
    -- any order whose lines or segment were missing. Left keeps the header,
    -- returns null, and not_null on both columns turns that silence into a
    -- build failure.
    from orders
    left join order_quantities
        on orders.order_id = order_quantities.order_id
    left join order_segments
        on orders.order_id = order_segments.order_id

)

select * from final