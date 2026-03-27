
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        quad_class as value_field,
        count(*) as n_records

    from `organic-phoenix-484620-p3`.`gdelt_staging_gdelt_mart`.`mart_daily_event_tone`
    group by quad_class

)

select *
from all_values
where value_field not in (
    1,2,3,4
)



  
  
      
    ) dbt_internal_test