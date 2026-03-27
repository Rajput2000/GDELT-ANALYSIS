
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select action_geo_country_code
from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_mart`.`mart_country_activity`
where action_geo_country_code is null



  
  
      
    ) dbt_internal_test