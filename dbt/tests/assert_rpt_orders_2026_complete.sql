with expected as (

    select count(*) as order_count
    from {{ ref('fct_orders') }}
    where extract(year from order_date) = {{ var('reporting_year') }}

),

actual as (

    select count(*) as order_count
    from {{ ref('rpt_orders_2026_segmented') }}

)

select
    expected.order_count as expected_order_count,
    actual.order_count as actual_order_count

from expected
cross join actual
where expected.order_count != actual.order_count