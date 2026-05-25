alter table reports
    add column if not exists action_reason clob;

alter table reports
    add column if not exists handled_by bigint;

alter table reports
    add column if not exists handled_at varchar(40);

create index if not exists idx_reports_status_created
    on reports(status, created_at);
