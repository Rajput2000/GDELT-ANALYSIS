
    
    

with dbt_test__target as (

  select global_event_id as unique_field
  from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_staging`.`stg_gdelt_events`
  where global_event_id is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


