update user_entities
set name = 'Resource',
    resource_key = 'generic_resource',
    width = 1,
    height = 1,
    state = 'available'
where type = 'resource'
  and resource_key = 'autumn_tree';
