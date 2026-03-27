{{
  config(
    materialized  = 'table',
    description   = 'Country-level event activity aggregated over the last 30 days. Powers the categorical dashboard tile: top countries by event volume and avg tone.',
    cluster_by    = ['action_geo_country_code']
  )
}}

/*
  Dashboard tile: "Top Countries by Event Activity"
  - X axis: country (top N by event count)
  - Y axis: event_count (bar), avg_tone (colour scale)
  - Filter: exclude blank country codes
*/

with base as (

    select * from {{ ref('stg_gdelt_events') }}

    where
        event_date >= date_sub(current_date(), interval 30 day)
        and event_date < current_date()
        -- Only include events with a resolved country
        and action_geo_country_code is not null
        and action_geo_country_code != ''

),

by_country as (

    select
        action_geo_country_code,

        -- Best readable name: most frequent fullname for this country code
        -- (handles spelling variants — we take the mode)
        approx_top_count(action_geo_fullname, 1)[offset(0)].value
                                                            as country_name_common,

        -- Volume
        count(*)                                            as event_count,
        sum(num_mentions)                                   as total_mentions,
        sum(num_articles)                                   as total_articles,

        -- Sentiment
        round(avg(avg_tone),        3)                      as avg_tone,
        round(avg(goldstein_scale), 3)                      as avg_goldstein,

        -- Importance-weighted tone
        round(
            sum(avg_tone * num_articles)
            / nullif(sum(num_articles), 0),
            3
        )                                                   as weighted_avg_tone,

        -- Conflict breakdown
        countif(quad_class = 1)                             as verbal_coop_count,
        countif(quad_class = 2)                             as material_coop_count,
        countif(quad_class = 3)                             as verbal_conflict_count,
        countif(quad_class = 4)                             as material_conflict_count,

        round(
            countif(quad_class in (3, 4)) / count(*) * 100,
            2
        )                                                   as conflict_pct,

        -- Date range covered
        min(event_date)                                     as first_event_date,
        max(event_date)                                     as last_event_date

    from base
    group by 1

),

ranked as (

    select
        *,
        row_number() over (order by event_count desc)       as country_rank
    from by_country

)

select * from ranked
