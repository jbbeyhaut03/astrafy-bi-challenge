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

with orders as (

    select
        order_id,
        client_id,
        order_date,
        net_sales,
        qty_product

    from {{ ref('fct_orders') }}
    where extract(year from order_date) = {{ var('reporting_year') }}

),

segments as (

    select
        order_id,
        order_segmentation

    from {{ ref('int_orders_segmented') }}

)

select
    orders.order_id,
    orders.client_id,
    orders.order_date,
    orders.net_sales,
    orders.qty_product,
    segments.order_segmentation

from orders
left join segments
    on orders.order_id = segments.order_id