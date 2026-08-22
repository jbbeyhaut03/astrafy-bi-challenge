{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns',
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
        net_sales
    from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    where order_date >= date_sub(
        (select max(order_date) from {{ this }}),
        interval {{ var('segmentation_lookback_days') }} day
    )
    {% endif %}

),

orders_with_prior_count as (

    select
        order_id,
        client_id,
        order_date,
        net_sales,
        count(*) over (
            partition by client_id
            order by unix_date(order_date)
            range between {{ var('segmentation_lookback_days') }} preceding
                      and 1 preceding
        ) as prior_orders_12m
    from orders

)

select
    order_id,
    client_id,
    order_date,
    net_sales,
    prior_orders_12m,
    {{ get_order_segment('prior_orders_12m') }} as order_segmentation
from orders_with_prior_count

{% if is_incremental() %}
where order_date > (select max(order_date) from {{ this }})
{% endif %}