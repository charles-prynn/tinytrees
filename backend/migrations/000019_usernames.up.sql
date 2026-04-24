alter table users
  add column username text;

create unique index users_username_unique_idx
  on users (lower(username))
  where username is not null;
