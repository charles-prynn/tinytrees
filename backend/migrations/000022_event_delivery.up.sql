create table player_event_outbox (
  id bigserial primary key,
  event_id bigint not null references player_events(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  destination text not null,
  status text not null default 'pending',
  available_at timestamptz not null default now(),
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  unique (event_id, destination)
);

create index player_event_outbox_pending_idx
  on player_event_outbox(status, destination, available_at, id);

create table player_event_inbox (
  id bigserial primary key,
  user_id uuid not null references users(id) on delete cascade,
  event_id bigint not null references player_events(id) on delete cascade,
  status text not null default 'unread',
  delivered_at timestamptz not null default now(),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (event_id)
);

create index player_event_inbox_user_id_id_idx
  on player_event_inbox(user_id, id);

create index player_event_inbox_user_status_idx
  on player_event_inbox(user_id, status, id);
