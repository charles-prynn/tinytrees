create table player_skills (
  user_id uuid not null references users(id) on delete cascade,
  skill_key text not null,
  xp bigint not null default 0,
  level integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_key)
);

update user_entities
set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
  'skill_key', 'woodcutting',
  'xp_per_reward', 25,
  'required_level', 1
)
where type = 'resource'
  and resource_key = 'autumn_tree';
