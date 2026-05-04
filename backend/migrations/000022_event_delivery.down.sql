drop index if exists player_event_inbox_user_status_idx;
drop index if exists player_event_inbox_user_id_id_idx;
drop table if exists player_event_inbox;

drop index if exists player_event_outbox_pending_idx;
drop table if exists player_event_outbox;
