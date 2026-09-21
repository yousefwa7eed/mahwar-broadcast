-- Realtime fix: carry the full previous row on providers UPDATE events.
--
-- With the default replica identity ('d'), postgres_changes UPDATE events
-- include only the primary key in old_record, so a subscriber comparing old vs
-- new is_online cannot detect a true->false transition (old is_online is missing
-- and reads as false) — the provider-home toggle turned ON but never OFF.
-- 'full' makes every UPDATE event carry the complete old row, so the toggle
-- turns itself OFF reliably on the schedule's close boundary.
-- Small WAL cost, irrelevant at this traffic level.
alter table public.providers replica identity full;