local ray = {
    history = {},
    state = "free",
    --pos = pos,
    last_node = "",
    hole_entity = "guns4d:bullet_hole",
    normal = vector.new(),
    --last_dir
    --exit_direction = dir,
    --range_left = def.bullet.range,
    --energy = def.bullet.penetration_RHA
    ITERATION_DISTANCE = .3,
    damage = 0
}

function ray:record_state()
    table.insert(self.history, {
        state = self.state

    })
end
--find (valid) edge. Slabs or other nodeboxes that are not the last hit position are not considered (to account for holes) TODO: update to account for hollow nodes
function ray:find_transverse_edge()
    assert(self.instance, "attempt to call obj method on a class")
    local pointed
    local cast1 = minetest.raycast(self.pos+(self.dir*(self.ITERATION_DISTANCE+.001)), self.pos, false, false)
    for hit in cast1 do
        --we can't solidly predict all nodes, so ignore them as the distance will be solved regardless. If node name is different then
        if hit.type == "node" and (vector.distance(hit.intersection_point, self.pos) > 0.0001) and (vector.equals(hit.under, self.last_pointed_node.under) or not minetest.registered_nodes[self.last_node_name].node_box) then
            pointed = hit
        end
    end
    if (pointed) and (vector.distance(pointed.intersection_point, self.pos) < self.ITERATION_DISTANCE) then
        return pointed.intersection_point, pointed.intersection_normal
    end
end
function ray:_cast()
    assert(self.instance, "attempt to call obj method on a class")
    local next_state = self.state --next state of course the state of the next ray.

    local end_normal

    local end_pos
    local edge
    --detect the "edge" of the block
    if self.state == "transverse" then
        edge, end_normal = self:find_transverse_edge()
        if edge then
            end_pos = edge+(self.dir*.001) --give it a tolerance, it still needs to intersect with any node edges connected to the edge's block.
            next_state = "free"
        else
            end_pos = self.pos+(self.dir*self.ITERATION_DISTANCE)
        end
    else
        end_pos = self.pos+(self.dir*self.range)
    end
    --do the main raycast. We don't account for mmRHA dropoff here.
    local continue = true --indicates wether to :_iterate wether the Bullet_ray has ended
    local cast = minetest.raycast(self.pos, end_pos, true, true)
    local edge_length
    if edge then
        edge_length = vector.distance(edge, self.pos)
    end
    local pointed_node
    local pointed_object
    for hit in cast do
        local h_length = vector.distance(hit.intersection_point, self.pos)
        if ( (not hit.ref) and h_length > 0.0001) and h_length < self.range then
            --if it's a node, check that it's note supposed to be ignored according to it's generated properties
            if hit.type == "node" then
                if self.state == "free" and Guns4d.node_properties[minetest.get_node(hit.under).name].behavior ~= "ignore" then
                    next_state = "transverse"
                    pointed_node = hit
                    end_normal = hit.intersection_normal
                    end_pos = pointed_node.intersection_point
                    break
                end
                if self.state == "transverse" then
                    --if it isn't the same name as the last node we intersected, then it's a different block with different stats for penetration
                    pointed_node = hit
                    if minetest.get_node(hit.under).name ~= self.last_node_name then
                        end_pos = pointed_node.intersection_point
                    elseif edge then
                        if h_length-edge_length < 0.01 then
                            next_state = "transverse"
                        end
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
            if (hit.type == "object") and (hit.ref ~= self.player) and ((not self.last_pointed_object) or (hit.ref ~= self.last_pointed_object.ref)) then
                minetest.chat_send_all("ent hit, ray")
                end_pos = pointed_object.intersection_point
                if self.over_penetrate then
                    pointed_object = hit
                    break
                else
                    pointed_object = hit
                    continue = false
                    break
                end
            end
        end
    end
    --set "last" values.
    return pointed_node, pointed_object, next_state, end_pos, end_normal, continue
end
--the main function.
function ray:_iterate(initialized)
    assert(self.instance, "attempt to call obj method on a class")
    local pointed_node, pointed_object, next_state, end_pos, end_normal, continue = self:_cast()

    local distance = vector.distance(self.pos, end_pos)
    if self.state == "free" then
        self.energy = self.energy-(distance*self.energy_dropoff)
        if distance ~= self.pos+(self.dir*self.range) then
            self:bullet_hole(end_pos, end_normal)
        end
    else
        if self.history[#self.history].state == "free" then
            self:bullet_hole(self.pos, self.history[#self.history-1].normal)
        end
        if next_state == "free" then
            self:bullet_hole(end_pos, end_normal)
        end
        local penetration_loss = distance*Guns4d.node_properties[self.last_node_name].mmRHA
        --calculate our energy loss based on the percentage of energy our penetration represents.
        self.energy = self.energy-((self.init_energy*self.energy_sharp_ratio)*(penetration_loss/self.init_penetration))
    end
    if self.state ~= self.next_state then

    end
    --set values for next iteration.
    self.range = self.range-distance
    if self.range <= 0.0005 or self.energy < 0 then
        continue = false
    end
---@diagnostic disable-next-line: assign-type-mismatch
    self.state = next_state
    if pointed_object then
        self.pos = pointed_object.intersection_point
        self.last_pointed_object = pointed_object
        ray:hit_entity(pointed_object.ref)
    else
        self.pos = end_pos
    end
    if pointed_node then
        self.last_node_name = minetest.get_node(pointed_node.under).name
        self.last_pointed_node = pointed_node
    end
    table.insert(self.history, {
        pos = self.pos,
        energy = self.energy,
        state = self.state,
        last_node = self.last_node_name,
        normal = end_normal, --end normal may be nil, as it's only for hit effects.
    })
    if continue and self.range > 0 and self.energy > 0 then
        self:_iterate(true)
    end
    if not initialized then
        for i, v in pairs(self.history) do
            local hud = self.player:hud_add({
                hud_elem_type = "waypoint",
                text = "   "..self.history[i].energy,
                number = 255255255,
                precision = 1,
                world_pos =  v.pos,
                scale = {x=1, y=1},
                alignment = {x=0,y=0},
                offset = {x=0,y=0},
            })
            minetest.after(15, function(hud)
                self.player:hud_remove(hud)
            end, hud)
        end
    end
end
function ray:calculate_sharp_conversion(bullet, armor, groups)
end
function ray:calculate_sharp_damage(bullet, armor, groups)
end
function ray:calculate_blunt_damage(bullet, armor, groups)
end
function ray:apply_damage(object, blunt_pen, sharp_pen, blunt_dmg, sharp_dmg)
    minetest.chat_send_all("ent hit")
    object:punch()
end
function ray:bullet_hole(pos, normal)
    local nearby_players = false
    for pname, player in pairs(minetest.get_connected_players()) do
        if vector.distance(player:get_pos(), pos) < 50 then
            nearby_players = true; break
        end
    end
    --if it's close enough to any players, then add it
    if nearby_players then
        --this entity will keep track of itself.
        local ent = minetest.add_entity(pos+(normal*(.0001+math.random()/1000)), self.hole_entity)
        ent:set_rotation(vector.dir_to_rotation(normal))
        local lua_ent = ent:get_luaentity()
        lua_ent.block_pos = pos
    else
        Guns4d.effects.spawn_bullet_hole_particle(pos, self.hole_scale, '(bullet_hole_1.png^(bullet_hole_2.png^[opacity:129))')
    end
end
function ray.construct(def)
    if def.instance then
        assert(def.player, "no player")
        assert(def.pos, "no position")
        assert(def.dir, "no direction")

        assert(def.gun, "no Gun object")
        assert(def.range, "no range")
        assert(def.energy, "no energy")
        assert(def.energy_dropoff, "no energy dropoff")
        assert(def.blunt_damage, "no blunt damage")

        def.sharp_damage = def.sharp_damage or 0
        def.sharp_penetration = def.sharp_penetration or 0
        if def.sharp_penetration==0 then
            def.blunt_penetration = def.blunt_penetration or def.energy/2
        else
            def.blunt_penetration = def.blunt_penetration or def.energy
        end

        def.init_energy = def.energy
        def.init_penetration = def.sharp_penetration
        def.init_blunt = def.blunt_penetration
        --blunt pen is in the same units (1 Joule/Area^3 = 1 MPa), so we use it to make the ratio by subtraction.
        def.energy_sharp_ratio = (def.energy-def.blunt_penetration)/def.energy

        def.dir = vector.new(def.dir)
        def.pos = vector.new(def.pos)
        def.history = {}
        def:_iterate()
    end
end
Guns4d.bullet_ray = Instantiatable_class:inherit(ray)