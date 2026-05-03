create table player_events (
  id bigserial primary key,
  user_id uuid not null references users(id) on delete cascade,
  aggregate_type text not null,
  aggregate_id uuid,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index player_events_user_id_id_idx on player_events(user_id, id);
create index player_events_user_event_type_idx on player_events(user_id, event_type, id);
create index player_actions_ends_at_idx on player_actions(status, ends_at);
