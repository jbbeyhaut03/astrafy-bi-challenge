# The model file is the entry point: it names the database connection,
# pulls in the views and explores, and sets caching policy for everything
# under it.

connection: "astrafy_bigquery"

include: "/views/*.view.lkml"
include: "/explores/*.explore.lkml"

label: "Astrafy — Sales"

# Cache invalidation tied to the pipeline, not to a clock. The trigger query
# returns the last time either mart was written; Looker re-runs it on a
# schedule, and only when the returned value changes does it drop the cache.
# A dbt run is therefore what refreshes Looker, which is the correct
# dependency direction. max_cache_age is the backstop if the trigger query
# itself fails.
datagroup: dbt_marts_build {
  sql_trigger:
    select max(last_modified_time)
    from `@{gcp_project}.@{marts_dataset}.__TABLES__`
    where table_id in ('fct_orders', 'fct_order_items') ;;
  max_cache_age: "24 hours"
}

persist_with: dbt_marts_build