create table players (
  user_id uuid primary key references users(id) on delete cascade,
  x integer not null,
  y integer not null,
  movement jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
