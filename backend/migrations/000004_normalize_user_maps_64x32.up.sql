with target_tiles as (
    select
        user_maps.user_id,
        jsonb_agg(
            coalesce(source_tiles.value::int, 0)
            order by target.index
        ) as tiles
    from user_maps
    cross join generate_series(0, 2047) as target(index)
    left join lateral (
        select value
        from jsonb_array_elements_text(user_maps.payload->'tiles') with ordinality as source(value, ordinal)
        where source.ordinal = (
            ((target.index / 64) * greatest(coalesce((user_maps.payload->>'width')::int, 64), 1))
            + (target.index % 64)
            + 1
        )
    ) as source_tiles on true
    group by user_maps.user_id
)
update user_maps
set
    payload = jsonb_set(
        jsonb_set(
            jsonb_set(payload, '{width}', '64'::jsonb),
            '{height}',
            '32'::jsonb
        ),
        '{tiles}',
        target_tiles.tiles
    ),
    updated_at = now()
from target_tiles
where user_maps.user_id = target_tiles.user_id;
