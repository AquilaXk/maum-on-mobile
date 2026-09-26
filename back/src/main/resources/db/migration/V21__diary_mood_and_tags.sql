alter table if exists diaries
    add column if not exists mood_score integer check (mood_score is null or (mood_score >= 1 and mood_score <= 5));
alter table if exists diaries
    add column if not exists emotion_tags varchar(500);
alter table if exists diaries
    add column if not exists trigger_tags varchar(500);
create index if not exists idx_diaries_member_mood on diaries(member_id, mood_score);
