
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select event_count
from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_mart`.`mart_daily_event_tone`
where event_count is null



  
  
      
    ) dbt_internal_test