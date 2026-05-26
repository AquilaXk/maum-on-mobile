alter table story_comments
    add column if not exists deleted boolean not null default false;
