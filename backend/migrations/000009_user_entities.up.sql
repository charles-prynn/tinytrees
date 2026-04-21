create table user_entities (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  type text not null,
  resource_key text not null default '',
  x integer not null,
  y integer not null,
  width integer not null default 1,
  height integer not null default 1,
  sprite_gid integer not null default 1,
  state text not null default 'available',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index user_entities_user_id_idx on user_entities(user_id);
create index user_entities_user_position_idx on user_entities(user_id, x, y);
