create index if not exists idx_letters_status_receiver_created
    on letters(status, receiver_id, created_date);

create index if not exists idx_diaries_private_created
    on diaries(is_private, create_date);

create index if not exists idx_story_posts_category_created
    on story_posts(category, create_date);

create index if not exists idx_story_posts_views_created
    on story_posts(view_count, create_date);

create index if not exists idx_auth_members_status_random_receive
    on auth_members(status, random_receive_allowed);
