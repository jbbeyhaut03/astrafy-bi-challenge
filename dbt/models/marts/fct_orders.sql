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

    select * from {{ ref('stg_orders') }}

),

order_quantities as (

    select
        order_id,
        sum(order_qty) as qty_product

    from {{ ref('stg_sales') }}
    group by all

),

final as (

    select
        orders.order_id,
        orders.client_id,
        orders.order_date,
        orders.net_sales,
        order_quantities.qty_product

    from orders
    left join order_quantities
        on orders.order_id = order_quantities.order_id

)

select * from final