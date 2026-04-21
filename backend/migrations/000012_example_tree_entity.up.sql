update user_entities
set name = 'Tree',
    resource_key = 'autumn_tree',
    width = 1,
    height = 1,
    state = 'idle'
where type = 'resource'
  and resource_key = 'generic_resource';
