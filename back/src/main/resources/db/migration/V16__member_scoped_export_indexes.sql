create index if not exists idx_story_posts_author_created
    on story_posts(author_id, create_date);

create index if not exists idx_story_comments_author_created
    on story_comments(author_id, create_date);
