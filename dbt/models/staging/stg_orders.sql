with source as (
    select * from {{ source('landing', 'raw_orders') }}
),

renamed as (
    select
        cast(orders_id as int64)    as order_id,
        cast(customers_id as int64) as client_id,
        cast(date_date as date)     as order_date,
        cast(net_sales as numeric)  as net_sales
    from source
)

select * from renamed