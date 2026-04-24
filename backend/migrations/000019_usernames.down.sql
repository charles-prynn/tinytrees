drop index if exists users_username_unique_idx;

alter table users
  drop column if exists username;
