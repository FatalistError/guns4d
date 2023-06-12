function guns3d.ray(player, pos, dir, def, bullet_info)
    --"transverse" just means in a node
    --"free" means in open air
    local playername = player:get_player_name()
    local is_first_iter = false
    local constant = .7
    local normal
    ----------------------------------------------------------initialize------------------------------------------------------------------
    if not bullet_info then
        is_first_iter = true
        bullet_info = {
            history = {},
            state = "free",
            last_pos = pos,
            last_node = "",
            last_normal = vector.new(),
            end_direction = dir,
            range_left = def.bullet.range,
            penetrating_force = def.bullet.penetration_RHA
            --last_pointed
        }
    end
    table.insert(bullet_info.history, {start_pos=pos, state=bullet_info.state, normal=bullet_info.last_normal, end_direction = bullet_info.end_direction})
    --set ray end
    local pos2 = pos+(dir*bullet_info.range_left)
    local block_ends_early = false
    --if was last in a block, check where the "transverse" state should end.
    --------------------------------------------------prepare for raycast --------------------------------------------------------------
    if bullet_info.state == "transverse" then
        local pointed
        local ray = minetest.raycast(pos+(dir*(constant+.01)), pos, false, false)
        for p in ray do
            if p.type == "node" and (table.compare(p.under, bullet_info.last_pointed.under) or not minetest.registered_nodes[minetest.get_node(bullet_info.last_pointed.under).name].node_box) then
                pointed = p
                break
            end
        end
        --maybe remove check for pointed
        if pointed and vector.distance(pointed.intersection_point, pos) < constant then
            pos2 = pointed.intersection_point
            block_ends_early = true
            normal = pointed.intersection_normal
            bullet_info.end_direction = vector.direction(dir, vector.new())
        else
            pos2 = pos+(dir*constant)
        end
    end
    -----------------------------------------------------------raycast--------------------------------------------------------------
    local ray = minetest.raycast(pos, pos2, true, true)
    local pointed
    local next_ray_pos = pos2
    for p in ray do
        if vector.distance(p.intersection_point, bullet_info.last_pos) > 0.0005 and vector.distance(p.intersection_point, bullet_info.last_pos) < bullet_info.range_left then
            local distance = vector.distance(pos, p.intersection_point)
            --if it's a node, check that it's note supposed to be ignored according to it's generated properties
            if p.type == "node" and guns3d.node_properties[minetest.get_node(p.under).name].behavior ~= "ignore" then
                local next_penetration_val = bullet_info.penetrating_force-(distance*guns3d.node_properties[minetest.get_node(p.under).name].rha*1000)
                if bullet_info.state ~= "transverse" then
                    pointed = p
                    --print(dump(p))
                    bullet_info.state = "transverse"
                    next_ray_pos = p.intersection_point
                else
                    pointed = p
                    if minetest.get_node(p.under).name ~= bullet_info.last_node and next_penetration_val > 0 and guns3d.node_properties[minetest.get_node(p.under).name].behavior ~= "ignore"  then
                        next_ray_pos = p.intersection_point
                    end
                end
                break
            end
            --if it's an object, make sure it's not the player object
            --note that while it may seem like this will create a infinite hit loop, it resolves itself as the intersection_point of the next ray will be close enough as to skip the pointed. See first line of iterator.
            if p.type == "object" and p.ref ~= player then
                --apply force dropoff
                local next_penetration_val = bullet_info.penetrating_force-def.bullet.penetration_dropoff_RHA*distance
                if bullet_info.state == "transverse" then
                    next_penetration_val = bullet_info.penetrating_force-(distance*guns3d.node_properties[minetest.get_node(bullet_info.last_pointed.under).name].rha*1000)
                end
                --insure there's still penetrating force left to actually damage the player
                if bullet_info.penetrating_force > 0 then
                    if (bullet_info.state == "transverse" and next_penetration_val > 0) or (bullet_info.state == "free" and bullet_info.penetrating_force-def.bullet.penetration_dropoff_RHA*distance > 0) then
                        local penetration_val = next_penetration_val
                        if bullet_info.state == "free" then
                            bullet_info.penetrating_force = next_penetration_val
                            penetration_val = bullet_info.penetrating_force
                        end
                        local damage = math.floor((def.bullet.damage*(next_penetration_val/def.bullet.penetration_RHA))+1)
                        p.ref:punch(player, nil, {damage_groups = {fleshy = damage}}, dir)
                        if p.ref:is_player() then
                            --TODO: finish
                        end
                    end
                end
            end
        end
    end
    ---------------------prepare for recursion---------------------------------------------------------------------------------
    local penetration_loss = def.bullet.penetration_dropoff_RHA
    local distance = vector.distance(pos, next_ray_pos)
    local new_dir = dir
    local node_properties
    if pointed then
        node_properties = guns3d.node_properties[minetest.get_node(pointed.under).name]
    end
    if pointed and (not normal) then
        normal = pointed.intersection_normal
    else
        normal = vector.new()
    end
    if not bullet_info.end_direction then
        bullet_info.end_direction = new_dir
    end
    --we know if the first raycast didn't find it ended early, or if there wasn't a hit, that it isn't in a block
    if block_ends_early or not pointed then
        bullet_info.state = "free"
    end
    --calculate penetration loss, and simulate loss of accuracy
    if bullet_info.history[#bullet_info.history].state == "transverse" and pointed then
        local rotation = vector.apply(vector.new(), function(a)
            a=a+(((math.random()-.5)*2)*node_properties.random_deviation*def.bullet.penetration_deviation*distance)
            return a
        end)
        new_dir = vector.rotate(new_dir, rotation*math.pi/180)
        penetration_loss = node_properties.rha*1000
    end
    --set the current bullet info.
    bullet_info.penetrating_force=bullet_info.penetrating_force-(penetration_loss*distance)
    bullet_info.range_left = bullet_info.range_left-distance
    bullet_info.last_pointed = pointed
    bullet_info.last_normal = normal
    bullet_info.last_pos = pos

    --set the last node
    if pointed then
        bullet_info.last_node = minetest.get_node(pointed.under).name
    end
    --recurse.
    if bullet_info.range_left > 0.001 and bullet_info.penetrating_force > 0 then
        guns3d.ray(player, next_ray_pos, new_dir, def, bullet_info)
    end
    -------------------------- visual -------------------------------------------------------------------------------------
    if is_first_iter then
        for i, val in pairs(bullet_info.history) do
            if not table.compare(val.normal, vector.new()) then
                guns3d.handle_node_hit_fx(val.normal, val.end_direction, val.start_pos)
            end
        end
    end
end
local raycast = {
    history = {},
    state = "free",
    last_pos = pos,
    last_node = "",
    last_normal = vector.new(),
    end_direction = dir,
    range_left = def.bullet.range,
    penetrating_force = def.bullet.penetration_RHA
}