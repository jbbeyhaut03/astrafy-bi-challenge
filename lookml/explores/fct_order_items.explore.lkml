explore: fct_order_items {
  label: "Order Items"
  description: "One row per product per order. The right explore for
    product-level questions: revenue by product, units sold, distinct products.
    Order-level totals live in the Orders explore."

  # The header is joined for exactly one field: the order's segment. Everything
  # else the header carries is either already on the line (customer, date) or
  # meaningless at line grain (the order's total units). many_to_one means each
  # line matches at most one header, so no row multiplies and no measure in this
  # explore can double-count.
  join: fct_orders {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_order_items.order_id} = ${fct_orders.order_id} ;;
    fields: [fct_orders.order_segmentation]
  }
}