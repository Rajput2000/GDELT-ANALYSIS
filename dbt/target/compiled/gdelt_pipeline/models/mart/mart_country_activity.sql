

with base as (

    select * from `organic-phoenix-484620-p3`.`gdelt_staging`.`stg_gdelt_events`

    where
        event_date >= date_sub(current_date(), interval 30 day)
        and event_date < current_date()
        and action_geo_country_code is not null
        and action_geo_country_code != ''

),

by_country as (

    select
        action_geo_country_code,

        approx_top_count(action_geo_fullname, 1)[offset(0)].value
                                                            as country_name_common,

        count(*)                                            as event_count,
        sum(num_mentions)                                   as total_mentions,
        sum(num_articles)                                   as total_articles,
        round(avg(avg_tone),        3)                      as avg_tone,
        round(avg(goldstein_scale), 3)                      as avg_goldstein,
        round(
            sum(avg_tone * num_articles)
            / nullif(sum(num_articles), 0),
            3
        )                                                   as weighted_avg_tone,
        countif(quad_class = 1)                             as verbal_coop_count,
        countif(quad_class = 2)                             as material_coop_count,
        countif(quad_class = 3)                             as verbal_conflict_count,
        countif(quad_class = 4)                             as material_conflict_count,
        round(
            countif(quad_class in (3, 4)) / count(*) * 100,
            2
        )                                                   as conflict_pct,
        min(event_date)                                     as first_event_date,
        max(event_date)                                     as last_event_date

    from base
    group by 1

),

-- ─────────────────────────────────────────────────────────
-- FIPS10-4 → ISO 3166-1 alpha-2 crosswalk
-- Looker Studio Geo charts require ISO codes or country names
-- Most common GDELT country codes mapped here
-- ─────────────────────────────────────────────────────────
fips_to_iso as (

    select fips, iso from unnest([
        struct('US' as fips, 'US' as iso),
        struct('UK', 'GB'),
        struct('FR', 'FR'),
        struct('GM', 'DE'),
        struct('RS', 'RU'),
        struct('CH', 'CN'),
        struct('IN', 'IN'),
        struct('BR', 'BR'),
        struct('MX', 'MX'),
        struct('IT', 'IT'),
        struct('SP', 'ES'),
        struct('PO', 'PT'),
        struct('JA', 'JP'),
        struct('KS', 'KR'),
        struct('AU', 'AU'),
        struct('CA', 'CA'),
        struct('IS', 'IL'),
        struct('EG', 'EG'),
        struct('SA', 'SA'),
        struct('IR', 'IR'),
        struct('IZ', 'IQ'),
        struct('SY', 'SY'),
        struct('TU', 'TR'),
        struct('PK', 'PK'),
        struct('AF', 'AF'),
        struct('NI', 'NG'),
        struct('SF', 'ZA'),
        struct('KE', 'KE'),
        struct('ET', 'ET'),
        struct('SU', 'SD'),
        struct('LY', 'LY'),
        struct('MO', 'MA'),
        struct('AG', 'DZ'),
        struct('GH', 'GH'),
        struct('IV', 'CI'),
        struct('SE', 'SN'),
        struct('UG', 'UG'),
        struct('TZ', 'TZ'),
        struct('AO', 'AO'),
        struct('ZI', 'ZW'),
        struct('ZA', 'ZM'),
        struct('MZ', 'MZ'),
        struct('BC', 'BW'),
        struct('WA', 'NA'),
        struct('UP', 'UA'),
        struct('PL', 'PL'),
        struct('HU', 'HU'),
        struct('RO', 'RO'),
        struct('BK', 'BA'),
        struct('HR', 'HR'),
        struct('SI', 'SI'),
        struct('GR', 'GR'),
        struct('BU', 'BG'),
        struct('EZ', 'CZ'),
        struct('LO', 'SK'),
        struct('EN', 'EE'),
        struct('LG', 'LV'),
        struct('LH', 'LT'),
        struct('FI', 'FI'),
        struct('SW', 'SE'),
        struct('NO', 'NO'),
        struct('DA', 'DK'),
        struct('NL', 'NL'),
        struct('BE', 'BE'),
        struct('SZ', 'CH'),
        struct('AU', 'AT'),
        struct('VE', 'VE'),
        struct('CO', 'CO'),
        struct('AR', 'AR'),
        struct('CI', 'CL'),
        struct('PE', 'PE'),
        struct('EC', 'EC'),
        struct('BO', 'BO'),
        struct('UY', 'UY'),
        struct('CU', 'CU'),
        struct('DR', 'DO'),
        struct('HA', 'HT'),
        struct('JM', 'JM'),
        struct('TD', 'TH'),
        struct('VM', 'VN'),
        struct('MY', 'MY'),
        struct('ID', 'ID'),
        struct('RP', 'PH'),
        struct('SN', 'SG'),
        struct('NZ', 'NZ'),
        struct('BD', 'BD'),
        struct('CE', 'LK'),
        struct('NP', 'NP'),
        struct('BM', 'MM'),
        struct('CB', 'KH'),
        struct('LA', 'LA'),
        struct('KZ', 'KZ'),
        struct('UZ', 'UZ'),
        struct('AJ', 'AZ'),
        struct('GG', 'GE'),
        struct('AM', 'AM'),
        struct('MO', 'MN'),
        struct('JO', 'JO'),
        struct('LE', 'LB'),
        struct('PA', 'PS'),
        struct('KU', 'KW'),
        struct('BA', 'BH'),
        struct('QA', 'QA'),
        struct('TC', 'AE'),
        struct('YM', 'YE'),
        struct('OM', 'OM')
    ]) as t

),

ranked as (

    select
        b.*,
        coalesce(f.iso, b.action_geo_country_code)          as iso_country_code,
        row_number() over (order by event_count desc)       as country_rank
    from by_country b
    left join fips_to_iso f on b.action_geo_country_code = f.fips

)

select * from ranked