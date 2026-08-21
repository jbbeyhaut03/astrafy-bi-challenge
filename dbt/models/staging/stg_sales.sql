with source as (
    select * from {{ source('landing', 'raw_sales') }}
),

renamed as (
    select
        cast(order_id as int64)     as order_id,
        cast(customer_id as int64)  as client_id,
        cast(date_date as date)     as order_date,
        cast(products_id as int64)  as product_id,
        cast(net_sales as float64)  as net_sales,
        cast(qty as int64)          as order_qty
    from source
)

select * from renamed