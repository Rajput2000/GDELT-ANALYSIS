
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select quad_class
from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_staging`.`stg_gdelt_events`
where quad_class is null



  
  
      
    ) dbt_internal_test