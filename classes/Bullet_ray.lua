local ray = {
    history = {},
    state = "free",
    --pos = pos,
    last_node = "",
    normal = vector.new(),
    --last_dir
    --exit_direction = dir,
    --range_left = def.bullet.range,
    --force_mmRHA = def.bullet.penetration_RHA
    ITERATION_DISTANCE = .3,
    damage = 0
}

function ray:record_state()
    table.insert(self.history, {
        state = self.state

    })
end
--find (valid) edge. Slabs or other nodeboxes that are not the last hit position are not considered (to account for holes) TODO: update to account for hollow nodes
function ray:transverse_end_point()
    assert(self.instance, "attempt to call obj method on a class")
    local pointed
    local cast = minetest.raycast(self.pos+(self.dir*(self.ITERATION_DISTANCE+.01)), self.pos, false, false)
    for hit in cast do
        --we can't solidly predict all nodes, so ignore them as the distance will be solved regardless. If node name is different then
        if hit.type == "node" and (vector.equals(hit.under, self.last_pointed.under) or not minetest.registered_nodes[self.last_node_name].node_box) then
            pointed = hit
            break
        end
    end
    if pointed and vector.distance(pointed.intersection_point, self.pos) < self.ITERATION_DISTANCE then
        self.normal = pointed.intersection_normal
        self.exit_direction = vector.direction(self.dir, vector.new()) --reverse dir is exit direction (for VFX)
        return pointed.intersection_point
    end
end
function ray:cast()
    assert(self.instance, "attempt to call obj method on a class")
    local end_pos = self.pos+(self.dir*self.range)
    --if block ends early, then we set end position accordingly
    local next_penetration_val
    local edge
    local next_state = self.state
    if self.state == "transverse" then
        edge = self:transverse_end_point()
        if edge then
            end_pos = edge
            next_state = "free"
        else
            end_pos = self.pos+(self.dir*self.ITERATION_DISTANCE)
        end
    end
    local continue = true
    local cast = minetest.raycast(self.pos, end_pos, true, true)
    local pointed
    for hit in cast do
        if not continue then break end
        if vector.distance(hit.intersection_point, self.pos) > 0.0005 and vector.distance(hit.intersection_point, self.pos) < self.range then
            --if it's a node, check that it's note supposed to be ignored according to it's generated properties
            if hit.type == "node" then
                if self.state == "free" and Guns4d.node_properties[minetest.get_node(hit.under).name].behavior ~= "ignore" then
                    next_state = "transverse"
                    pointed = hit
                    break
                end
                if self.state == "transverse" then
                    --if it isn't the same name as the last node we intersected, then it's a different block with different stats for penetration
                    if minetest.get_node(hit.under).name ~= self.last_node_name then
                        pointed = hit
                    end
                    --make sure it's set to transverse if the edge has a block infront of it
                    if Guns4d.node_properties[minetest.get_node(hit.under).name].behavior == "ignore" then
                        next_state = "free"
                    else
                        next_state = "transverse"
                    end
                    break
                end
            end
            --if it's an object, make sure it's not the player object
            --note that while it may seem like this will create a infinite hit loop, it resolves itself as the intersection_point of the next ray will be close enough as to skip the pointed. See first line of iterator.
            if hit.type == "object" and hit.ref ~= self.player then
                if self.over_penetrate then
                    pointed = hit
                    break
                else
                    pointed = hit
                    continue = false
                    break
                end
            end
        end
    end
    if pointed then
        end_pos = pointed.intersection_point
        if self.state == "transverse" then
            next_penetration_val = self.force_mmRHA-(vector.distance(self.pos, end_pos)*Guns4d.node_properties[self.last_node_name].mmRHA)
        else -- transverse
            next_penetration_val = self.force_mmRHA-(vector.distance(self.pos, end_pos)*self.dropoff_mmRHA)
        end
    else
        --if there is no pointed, and it's not transverse, then the ray has ended.
        if self.state == "transverse" then
            next_penetration_val = self.force_mmRHA-(vector.distance(self.pos, end_pos)*Guns4d.node_properties[self.last_node_name].mmRHA)
        else --free
            continue = false
            next_penetration_val = self.force_mmRHA-(self.range*self.dropoff_mmRHA)
        end
    end

    --set "last" values.
    return pointed, next_penetration_val, next_state, end_pos, continue
end
function ray:iterate(initialized)
    assert(self.instance, "attempt to call obj method on a class")
    local pointed, penetration, next_state, end_pos, continue = self:cast()
    self.range = self.range-vector.distance(self.pos, end_pos)
    self.pos = end_pos
    self.force_mmRHA = penetration
---@diagnostic disable-next-line: assign-type-mismatch
    self.state = next_state
    if pointed then
        self.last_pointed = pointed
    end
    if pointed then
        if pointed.type == "node" then
            self.last_node_name = minetest.get_node(pointed.under).name
        elseif pointed.type == "object" then
            ray:hit_entity(pointed.ref)
        end
    end
    table.insert(self.history, {
        pos = self.pos,
        force_mmRHA = self.force_mmRHA,
        state = self.state,
        last_node = self.last_node_name,
        normal = self.normal,
    })
    if continue and self.range > 0 and self.force_mmRHA > 0 then
        self:iterate(true)
    end
    if not initialized then
        for i, v in pairs(self.history) do
            local hud = self.player:hud_add({
                hud_elem_type = "waypoint",
                text = "mmRHA:"..tostring(math.floor(v.force_mmRHA or 0)).." ",
                number = 255255255,
                precision = 1,
                world_pos =  v.pos,
                scale = {x=1, y=1},
                alignment = {x=0,y=0},
                offset = {x=0,y=0},
            })
            minetest.after(40, function(hud)
                self.player:hud_remove(hud)
            end, hud)
        end
    end
end
function ray.construct(def)
    if def.instance then
        assert(def.player, "no player")
        assert(def.pos, "no position")
        assert(def.dir, "no direction")
        assert(def.gun, "no Gun object")
        assert(def.range, "no range")
        assert(def.force_mmRHA, "no force")
        assert(def.dropoff_mmRHA, "no force dropoff")
        --assert(def.on_node_hit, "no node hit behavior")
        assert(def.hit_entity, "no entity hit behavior")
        def.init_force_mmRHA = def.force_mmRHA
        def.dir = vector.new(def.dir)
        def.pos = vector.new(def.pos)
        def.history = {}
        def:iterate()
    end
end
Guns4d.bullet_ray = Instantiatable_class:inherit(ray)