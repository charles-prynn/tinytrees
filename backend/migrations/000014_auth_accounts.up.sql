alter table users
  add column email text,
  add column password_hash text;

create unique index users_email_unique_idx
  on users (lower(email))
  where email is not null;
