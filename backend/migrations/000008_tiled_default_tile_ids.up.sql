update user_maps
set
    payload = jsonb_set(
        payload,
        '{tiles}',
        (
            select jsonb_agg(
                case
                    when tile.value::int <= 0 then 1
                    else tile.value::int
                end
                order by tile.ordinal
            )
            from jsonb_array_elements_text(payload->'tiles') with ordinality as tile(value, ordinal)
        )
    ),
    updated_at = now()
where payload ? 'tiles';
