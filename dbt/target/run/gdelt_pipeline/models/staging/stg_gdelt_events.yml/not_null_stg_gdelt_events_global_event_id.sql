
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select global_event_id
from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_staging`.`stg_gdelt_events`
where global_event_id is null



  
  
      
    ) dbt_internal_test