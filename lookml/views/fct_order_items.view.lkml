view: fct_order_items {
  sql_table_name: `@{gcp_project}.@{marts_dataset}.fct_order_items` ;;
  label: "Order Items"

  # ---------------------------------------------------------------------
  # Dimensions
  # ---------------------------------------------------------------------

  # No single-column key exists at line grain. The compound key is asserted
  # upstream: stg_sales carries a dbt unique_combination_of_columns test on
  # (order_id, product_id), which passes. Looker needs a declared primary key
  # to build correct aggregates across a join.
  dimension: order_item_id {
    primary_key: yes
    hidden: yes
    type: string
    sql: concat(cast(${TABLE}.order_id as string), '-',
                cast(${TABLE}.product_id as string)) ;;
  }

  dimension: order_id {
    type: number
    value_format_name: id
    label: "Order ID"
    description: "Order this line belongs to."
    sql: ${TABLE}.order_id ;;
  }

  dimension: product_id {
    type: number
    value_format_name: id
    label: "Product ID"
    group_label: "Product"
    description: "Identifier of the product on this line. Degenerate dimension —
      the source files carry no product name, category or price list, so there is
      nothing to join to."
    sql: ${TABLE}.product_id ;;
  }

  dimension: client_id {
    type: number
    value_format_name: id
    label: "Customer ID"
    description: "Customer who placed the order this line belongs to."
    sql: ${TABLE}.client_id ;;
  }

  # Kept on this view rather than taken from the joined order header: this is
  # the partitioning column of fct_order_items, so filtering it here prunes
  # partitions on the large table before the join runs.
  dimension_group: order {
    type: time
    datatype: date
    convert_tz: no
    label: "Order"
    description: "Date the order was placed."
    timeframes: [raw, date, week, month, month_name, quarter, year, day_of_week]
    sql: ${TABLE}.order_date ;;
  }

  dimension: net_sales {
    hidden: yes
    type: number
    sql: ${TABLE}.net_sales ;;
  }

  dimension: order_qty {
    hidden: yes
    type: number
    sql: ${TABLE}.order_qty ;;
  }

  # ---------------------------------------------------------------------
  # Measures
  # ---------------------------------------------------------------------

  measure: order_line_count {
    type: count
    label: "Order Line Count"
    group_label: "Volume"
    description: "Number of order lines — one per product per order."
    drill_fields: [order_item_detail*]
  }

  measure: total_net_sales {
    type: sum
    label: "Total Net Sales"
    group_label: "Revenue"
    value_format_name: decimal_2
    description: "Sum of line-level net sales. Currency is not stated in the
      source."
    sql: ${net_sales} ;;
    drill_fields: [order_item_detail*]
  }

  measure: total_units {
    type: sum
    label: "Total Units"
    group_label: "Volume"
    description: "Sum of quantities across the lines selected."
    sql: ${order_qty} ;;
  }

  measure: average_net_sales_per_unit {
    type: number
    label: "Average Net Sales per Unit"
    group_label: "Revenue"
    value_format_name: decimal_2
    description: "Total net sales divided by total units — average realised
      price per unit over the lines selected."
    sql: ${total_net_sales} / nullif(${total_units}, 0) ;;
  }

  measure: distinct_products {
    type: count_distinct
    label: "Distinct Products"
    group_label: "Product"
    description: "Number of distinct products appearing on the lines selected."
    sql: ${product_id} ;;
  }

  measure: distinct_orders {
    type: count_distinct
    label: "Distinct Orders (with lines)"
    group_label: "Volume"
    description: "Number of distinct orders represented in the lines selected.
      Use Order Count in the Orders explore for the definitive order count: the
      line data contains one order ID, dated 2026-12-31, that has no header row
      in the order register, so a count taken here can exceed the count taken
      there by one."
    sql: ${order_id} ;;
  }

  set: order_item_detail {
    fields: [order_id, order_date, product_id, client_id,
             total_net_sales, total_units]
  }
}