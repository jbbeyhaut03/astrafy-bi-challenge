{% macro get_order_segment(prior_orders_column) %}
    case
        when {{ prior_orders_column }} >= {{ var('segmentation_vip_min_prior_orders') }}
            then 'VIP'
        when {{ prior_orders_column }} >= {{ var('segmentation_returning_min_prior_orders') }}
            then 'Returning'
        else 'New'
    end
{% endmacro %}