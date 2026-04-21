update user_entities
set width = 1,
    height = 1
where type = 'resource'
  and resource_key = 'autumn_tree';
