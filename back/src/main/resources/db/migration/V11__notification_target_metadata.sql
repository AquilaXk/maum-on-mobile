alter table notifications
    add column if not exists type varchar(40) not null default 'fallback';

alter table notifications
    add column if not exists target_type varchar(40);

alter table notifications
    add column if not exists target_id bigint;

alter table notifications
    add column if not exists route_key varchar(40) not null default 'notifications';

create index if not exists idx_notifications_receiver_route_created
    on notifications(receiver_id, route_key, created_at);
