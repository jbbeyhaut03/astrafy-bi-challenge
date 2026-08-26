view: fct_orders {
  sql_table_name: `@{gcp_project}.@{marts_dataset}.fct_orders` ;;
  label: "Orders"

  # ---------------------------------------------------------------------
  # Dimensions
  # ---------------------------------------------------------------------

  dimension: order_id {
    primary_key: yes
    type: number
    value_format_name: id
    label: "Order ID"
    description: "Unique identifier of the order, carried from the source system.
      One row per order ID in this view — asserted by unique and not_null tests
      in dbt. There is no order dimension table: the ID is a degenerate
      dimension, a key with no descriptive attributes behind it."
    sql: ${TABLE}.order_id ;;
  }

  dimension: client_id {
    type: number
    value_format_name: id
    label: "Customer ID"
    group_label: "Customer"
    description: "Identifier of the customer who placed the order. Degenerate
      dimension — the source files carry no customer name, region or segment
      attribute, so there is nothing to join to."
    sql: ${TABLE}.client_id ;;
  }

  dimension_group: order {
    type: time
    datatype: date
    convert_tz: no
    label: "Order"
    description: "Date the order was placed. The extract runs 2025-07-09 to
      2026-12-31."
    timeframes: [raw, date, week, month, month_name, quarter, year, day_of_week]
    sql: ${TABLE}.order_date ;;
  }

  dimension: order_segmentation {
    type: string
    label: "Order Segment"
    group_label: "Customer"
    suggestions: ["New", "Returning", "VIP"]
    description: "Segment of this order, based on how many orders the same
      customer placed in the 365 days before it: New = none, Returning = 1 to 3,
      VIP = 4 or more. This describes the order, not the customer — the same
      customer can place a New order more than once if their previous order falls
      outside the 365-day window. Orders early in the extract sit on a shorter
      lookback than 365 days, because the data starts 2025-07-09."
    sql: ${TABLE}.order_segmentation ;;
  }

  # Raw numeric columns are hidden. They are inputs to measures, and exposing
  # them as dimensions invites grouping revenue by revenue — the single most
  # common way a natural-language query returns a technically valid, useless
  # answer.

  dimension: net_sales {
    hidden: yes
    type: number
    sql: ${TABLE}.net_sales ;;
  }

  dimension: qty_product {
    hidden: yes
    type: number
    sql: ${TABLE}.qty_product ;;
  }

  # ---------------------------------------------------------------------
  # Measures
  # ---------------------------------------------------------------------

  measure: order_count {
    type: count
    label: "Order Count"
    group_label: "Volume"
    description: "Number of orders. The order register is the header table, so
      this is the definitive order count at every level of aggregation."
    drill_fields: [order_detail*]
  }

  measure: total_net_sales {
    type: sum
    label: "Total Net Sales"
    group_label: "Revenue"
    value_format_name: decimal_2
    description: "Sum of order net sales. The source files do not state a
      currency, so values are reported as-is."
    sql: ${net_sales} ;;
    drill_fields: [order_detail*]
  }

  measure: average_order_value {
    type: number
    label: "Average Order Value"
    group_label: "Revenue"
    value_format_name: decimal_2
    description: "Total net sales divided by order count, recomputed at whatever
      level the query aggregates to."
    sql: ${total_net_sales} / nullif(${order_count}, 0) ;;
  }

  measure: total_units {
    type: sum
    label: "Total Units"
    group_label: "Volume"
    description: "Sum of product units across the orders selected. A product
      ordered three times counts as three."
    sql: ${qty_product} ;;
  }

  measure: average_units_per_order {
    type: number
    label: "Average Units per Order"
    group_label: "Volume"
    value_format_name: decimal_2
    description: "Total units divided by order count — average basket size in
      units."
    sql: ${total_units} / nullif(${order_count}, 0) ;;
  }

  measure: distinct_customers {
    type: count_distinct
    label: "Distinct Customers (with orders)"
    group_label: "Customer"
    description: "Number of distinct customers who placed at least one of the
      orders selected. Combined with Order Segment it counts customers with at
      least one order in that segment during the period — not customers who
      'are' that segment. A customer can appear under two or three segments, so
      segment values do not sum to the unfiltered total: the full extract holds
      1,716 distinct customers against 1,747 orders labelled New."
    sql: ${client_id} ;;
  }

  measure: orders_per_customer {
    type: number
    label: "Orders per Customer"
    group_label: "Customer"
    value_format_name: decimal_2
    description: "Order count divided by distinct customers — purchase frequency
      over the period selected."
    sql: ${order_count} / nullif(${distinct_customers}, 0) ;;
  }

  measure: net_sales_per_customer {
    type: number
    label: "Net Sales per Customer"
    group_label: "Customer"
    value_format_name: decimal_2
    description: "Total net sales divided by distinct customers over the period
      selected. Not lifetime value unless the query is unfiltered by date."
    sql: ${total_net_sales} / nullif(${distinct_customers}, 0) ;;
  }

  set: order_detail {
    fields: [order_id, order_date, client_id, order_segmentation,
             total_net_sales, total_units]
  }
}