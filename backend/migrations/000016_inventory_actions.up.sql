create table player_inventory (
  user_id uuid not null references users(id) on delete cascade,
  item_key text not null,
  quantity bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, item_key)
);

create table player_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  type text not null,
  entity_id uuid references user_entities(id) on delete set null,
  status text not null default 'active',
  started_at timestamptz not null,
  ends_at timestamptz not null,
  next_tick_at timestamptz not null,
  tick_interval_ms integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index player_actions_one_active_idx
  on player_actions(user_id)
  where status = 'active';

create index player_actions_user_status_idx on player_actions(user_id, status);
create index player_actions_due_idx on player_actions(status, next_tick_at);
