drop index if exists users_email_unique_idx;

alter table users
  drop column if exists password_hash,
  drop column if exists email;
