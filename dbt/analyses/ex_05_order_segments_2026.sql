-- Exercise 5: the segment of each order placed in 2026.
--
-- The per-order answer is a column, not a query. int_orders_segmented assigns
-- order_segmentation once, over full history, and fct_orders carries it at
-- order grain. This file is the readable form of that answer: how the 2026
-- orders distribute across the three segments.
--
-- Reads fct_orders, not rpt_orders_2026_segmented. The rpt_ prefix marks that
-- model as the Ex 6 deliverable, built for one stated use; anything that reads
-- rather than delivers reads the fact table. Same parent as Ex 1-3, so all four
-- answers are consistent by construction.
--
-- The window that produces the segment runs over all history, not over 2026 --
-- an order in January 2026 is segmented against the customer's orders back to
-- January 2025. Filtering to 2026 here selects which orders to report, never
-- which orders the segment was computed from.

select
    order_segmentation,
    count(*) as order_count

from {{ ref('fct_orders') }}

where order_date >= date({{ var('reporting_year') }}, 1, 1)
  and order_date < date({{ var('reporting_year') }} + 1, 1, 1)

group by all
order by order_count desc