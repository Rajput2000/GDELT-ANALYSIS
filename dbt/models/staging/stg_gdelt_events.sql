{{
  config(
    materialized = 'view',
    description  = 'Cleaned and typed GDELT events. Casts integer dates to DATE, renames columns to snake_case, and filters out rows missing critical fields.'
  )
}}

with raw as (

    select * from {{ source('gdelt_raw', 'events') }}

),

cleaned as (

    select
        -- ── Identifiers ──────────────────────────────────────────
        GlobalEventID                                           as global_event_id,

        -- ── Dates — cast from YYYYMMDD integer to DATE ──────────
        parse_date('%Y%m%d', cast(Day as string))               as event_date,
        parse_date('%Y%m%d', cast(DATEADDED as string))         as date_added,
        Year                                                    as event_year,
        MonthYear                                               as event_month_year,

        -- ── Actor 1 ───────────────────────────────────────────
        Actor1Code                                              as actor1_code,
        Actor1Name                                              as actor1_name,
        Actor1CountryCode                                       as actor1_country_code,
        Actor1Type1Code                                         as actor1_type1_code,
        Actor1KnownGroupCode                                    as actor1_known_group_code,

        -- ── Actor 2 ───────────────────────────────────────────
        Actor2Code                                              as actor2_code,
        Actor2Name                                              as actor2_name,
        Actor2CountryCode                                       as actor2_country_code,
        Actor2Type1Code                                         as actor2_type1_code,
        Actor2KnownGroupCode                                    as actor2_known_group_code,

        -- ── Event action ──────────────────────────────────────
        IsRootEvent                                             as is_root_event,
        EventCode                                               as event_code,
        EventBaseCode                                           as event_base_code,
        EventRootCode                                           as event_root_code,

        -- QuadClass labels for readability
        QuadClass                                               as quad_class,
        case QuadClass
            when 1 then 'Verbal Cooperation'
            when 2 then 'Material Cooperation'
            when 3 then 'Verbal Conflict'
            when 4 then 'Material Conflict'
            else        'Unknown'
        end                                                     as quad_class_label,

        -- ── Scores ────────────────────────────────────────────
        GoldsteinScale                                          as goldstein_scale,
        AvgTone                                                 as avg_tone,
        NumMentions                                             as num_mentions,
        NumSources                                              as num_sources,
        NumArticles                                             as num_articles,

        -- ── Action geography (best field for mapping events) ──
        ActionGeo_Type                                          as action_geo_type,
        ActionGeo_Fullname                                      as action_geo_fullname,
        ActionGeo_CountryCode                                   as action_geo_country_code,
        ActionGeo_ADM1Code                                      as action_geo_adm1_code,
        ActionGeo_Lat                                           as action_geo_lat,
        ActionGeo_Long                                          as action_geo_long,
        ActionGeo_FeatureID                                     as action_geo_feature_id,

        -- ── Actor 1 geography ─────────────────────────────────
        Actor1Geo_CountryCode                                   as actor1_geo_country_code,
        Actor1Geo_Fullname                                      as actor1_geo_fullname,
        Actor1Geo_Lat                                           as actor1_geo_lat,
        Actor1Geo_Long                                          as actor1_geo_long,

        -- ── Actor 2 geography ─────────────────────────────────
        Actor2Geo_CountryCode                                   as actor2_geo_country_code,
        Actor2Geo_Fullname                                      as actor2_geo_fullname,
        Actor2Geo_Lat                                           as actor2_geo_lat,
        Actor2Geo_Long                                          as actor2_geo_long,

        -- ── Source ────────────────────────────────────────────
        SOURCEURL                                               as source_url

    from raw

    where
        -- Drop rows with no usable date
        Day is not null
        -- Drop rows with invalid date format (sanity check)
        and cast(Day as string) like '20%'

)

select * from cleaned
