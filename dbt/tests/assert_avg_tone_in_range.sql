-- Test: avg_tone must be between -100 and +100
-- Fails if any rows fall outside that range

select *
from {{ model }}
where avg_tone < -100
   or avg_tone > 100
