-- The Ex 6 mart is now a projection of fct_orders, so this compares the mart's
-- row count to the reporting-year slice of its only parent. Near-tautological
-- by design — which is the point: it is the assertion that would break on a
-- wrong var, a mistyped bound, or an off-by-one on the half-open range, and
-- those are the only ways this model can now be wrong. Hard error.
--
-- Same half-open range as the model itself, deliberately: a test that filters
-- differently from the model it checks is testing two things at once.

with expected as (

    select count(*) as order_count
    from {{ ref('fct_orders') }}
    where order_date >= date({{ var('reporting_year') }}, 1, 1)
      and order_date < date({{ var('reporting_year') }} + 1, 1, 1)

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