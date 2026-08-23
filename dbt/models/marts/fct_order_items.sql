{{
    config(
        materialized='table',
        partition_by={
            'field': 'order_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by=['order_id', 'product_id']
    )
}}

select
    order_id,
    product_id,
    client_id,
    order_date,
    order_qty,
    net_sales

from {{ ref('stg_sales') }}