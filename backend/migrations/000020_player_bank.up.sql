create table player_bank (
  user_id uuid not null references users(id) on delete cascade,
  item_key text not null,
  quantity bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, item_key)
);
