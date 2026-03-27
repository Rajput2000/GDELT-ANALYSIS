
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select event_date
from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_staging`.`stg_gdelt_events`
where event_date is null



  
  
      
    ) dbt_internal_test