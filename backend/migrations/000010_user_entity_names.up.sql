alter table user_entities
  add column name text not null default 'Entity';

update user_entities
set name = 'Resource'
where type = 'resource'
  and (name = '' or name = 'Entity');
