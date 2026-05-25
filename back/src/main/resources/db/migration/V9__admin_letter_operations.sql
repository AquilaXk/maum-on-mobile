alter table letters
    add column if not exists receiver_id bigint;

create index if not exists idx_letters_receiver_created
    on letters(receiver_id, created_date);

alter table admin_audit_events
    add column if not exists target_resource_type varchar(60);

alter table admin_audit_events
    add column if not exists target_resource_id bigint;

create index if not exists idx_admin_audit_resource_created
    on admin_audit_events(target_resource_type, target_resource_id, created_at);
