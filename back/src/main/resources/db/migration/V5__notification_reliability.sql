alter table notifications
    add column if not exists read_at varchar(40);

create table if not exists notification_device_tokens (
    member_id bigint not null,
    token varchar(512) not null,
    platform varchar(20) not null,
    enabled boolean not null,
    updated_at varchar(40) not null,
    primary key (member_id, token),
    constraint fk_notification_device_token_member
        foreign key (member_id) references auth_members(id)
        on delete cascade
);

create index if not exists idx_notification_device_tokens_member_enabled
    on notification_device_tokens(member_id, enabled, updated_at);
