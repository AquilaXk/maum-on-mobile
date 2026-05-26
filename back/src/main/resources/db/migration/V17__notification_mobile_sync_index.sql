create index if not exists idx_notifications_receiver_id_read
    on notifications(receiver_id, id, is_read);
