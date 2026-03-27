{{
  config(
    materialized  = 'table',
    description   = 'Daily aggregated event metrics by quad class. Powers the temporal dashboard tile: event tone and conflict intensity over the last 30 days.',
    partition_by  = {
      'field':       'event_date',
      'data_type':   'date',
      'granularity': 'day'
    },
    cluster_by    = ['quad_class_label']
  )
}}

/*
  Dashboard tile: "Global Event Tone Over Time"
  - X axis: event_date (last 30 days)
  - Y axis: avg_tone (line) + event_count (bar)
  - Series: quad_class_label (Verbal Coop / Material Coop / Verbal Conflict / Material Conflict)
*/

with base as (

    select * from {{ ref('stg_gdelt_events') }}

    where
        event_date >= date_sub(current_date(), interval 30 day)
        and event_date < current_date()

),

aggregated as (

    select
        event_date,
        quad_class,
        quad_class_label,

        -- Volume metrics
        count(*)                                            as event_count,
        sum(num_mentions)                                   as total_mentions,
        sum(num_articles)                                   as total_articles,

        -- Sentiment / stability metrics
        round(avg(avg_tone),         3)                     as avg_tone,
        round(avg(goldstein_scale),  3)                     as avg_goldstein,

        -- Importance-weighted tone (weighted by number of articles)
        round(
            sum(avg_tone * num_articles)
            / nullif(sum(num_articles), 0),
            3
        )                                                   as weighted_avg_tone,

        -- Conflict share (% of events that are verbal or material conflict)
        round(
            countif(quad_class in (3, 4)) / count(*) * 100,
            2
        )                                                   as conflict_pct

    from base
    group by 1, 2, 3

)

select * from aggregated
