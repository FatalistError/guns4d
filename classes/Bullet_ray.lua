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
    mmRHA_to_Pa_energy_ratio = .5,
    ITERATION_DISTANCE = .3,
    damage = 0
}

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
        if (h_length > 0.0001) and h_length < self.range then
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
                if self.over_penetrate then
                    pointed_object = hit
                    break
                else
                    pointed_object = hit
                    continue = false
                    break
                end
                end_pos = pointed_object.intersection_point
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

        if next_state == "transverse" then
            print(vector.distance(self.pos, end_pos), vector.distance(self.pos, self.pos+(self.dir*self.range)))
            self:bullet_hole(end_pos, end_normal)
        end
    else
        --add exit holes
        if next_state == "free" then
            self:bullet_hole(end_pos, end_normal)
        end
        --calc penetration loss from traveling through the block
        local penetration_loss = distance*Guns4d.node_properties[self.last_node_name].mmRHA
        --calculate our energy loss based on the percentage of energy our penetration represents.
        self.energy = self.energy-((self.init_energy*self.energy_sharp_ratio)*(penetration_loss/self.sharp_penetration))
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
        self:hit_entity(pointed_object.ref)
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
    --[[if not initialized then
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
    end]]
end
--can be safely overridden
function ray:calculate_sharp_conversion(resistance, sharp_penetration)
    assert(self.instance, "attempt to call obj method on a class")
end
function ray:hit_entity(object)
    assert(self.instance, "attempt to call obj method on a class")

    local resistance = object:get_armor_groups() -- support for different body parts is needed here, that's for... a later date, though.
    local sharp_pen = self.sharp_penetration-(self.sharp_penetration*(self.energy/self.init_energy)*self.energy_sharp_ratio)
    sharp_pen = Guns4d.math.clamp(sharp_pen - (resistance.guns4d_mmRHA or 0), 0, 65535)
    local converted_Pa = (resistance.guns4d_mmRHA or 0) * self.mmRHA_to_Pa_energy_ratio

    local blunt_pen = converted_Pa+(self.blunt_penetration-(self.blunt_penetration*(self.energy/self.init_energy)*(1-self.energy_sharp_ratio)))
    blunt_pen = Guns4d.math.clamp(blunt_pen - (resistance.guns4d_Pa or 0), 0, 65535)
    self:apply_damage(object, sharp_pen, blunt_pen)

    --raw damage first
end
--not point in overriding this if you remove hit_entity()
--blunt & sharp ratio are the ratios of initial damage to damage at this bullet's current energy.
function ray:apply_damage(object, sharp_pen, blunt_pen)
    assert(self.instance, "attempt to call obj method on a class")
    --coefficients for damage
    local blunt_ratio = blunt_pen/self.blunt_penetration
    local sharp_ratio = sharp_pen/self.sharp_penetration

    --raw damage values
    local blunt_dmg = self.raw_blunt_damage*blunt_ratio
    local sharp_dmg = self.raw_sharp_damage*sharp_ratio

    local hp = (object:get_hp()-blunt_dmg)-sharp_dmg
    --print(blunt_dmg, sharp_dmg, blunt_ratio, sharp_ratio)
    --print(self.blunt_penetration, self.sharp_penetration)
    if hp < 0 then hp = 0 end
    object:set_hp(hp, {type="set_hp", from="guns4d"})

    --now apply damage groups.
    if self.blunt_damage_groups then
        local damage_values = {}
        for i, v in pairs(self.blunt_damage_groups) do
            damage_values[i] = v*blunt_ratio
        end
        object:punch((Guns4d.config.punch_from_player_not_gun and self.player) or self.gun.entity, 1000, {damage_groups=damage_values}, self.dir)
    end
    if self.sharp_damage_groups then
        local damage_values = {}
        for i, v in pairs(self.sharp_damage_groups) do
            damage_values[i] = v*sharp_ratio
        end
        object:punch((Guns4d.config.punch_from_player_not_gun and self.player) or self.gun.entity, 1000, {damage_groups=damage_values}, self.dir)
    end
    --punch SUCKS for this, apparently armor can only have flat rates of protection, which is sort of the worst thing i've ever heard.
    --object:punch()
end
function ray:bullet_hole(pos, normal)
    assert(self.instance, "attempt to call obj method on a class")
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

        --use this if you don't want to use the built-in system for penetrations.
        assert(not(def.ignore_penetration and not rawget(def, "hit_entity")), "bullet ray cannot ignore default penetration if hit_entity() is undefined. Use ignore_penetration for custom damage systems." )
        if not def.ignore_penetration then
            assert((not (def.blunt_penetration and def.energy)) or (def.blunt_penetration < def.energy), "blunt penetration may not be greater than energy! Blunt penetration is in Joules/Megapascals, energy is also in Joules.")

            --"raw" damages define the damage (unaffected by armor groups) for the initial penetration value of each type.
            --def.sharp_damage_groups = {} --tool capabilities
            --def.blunt_damage_groups = {}

            --guns4d mmRHA is used in traditional context.
            assert((not def.blunt_damage_groups) or not def.blunt_damage_groups["guns4d_mmRHA"], "guns4d_mmRHA damage group is not used in a traditional context. To increase penetration, increase sharp_penetration field.")
            assert((not def.blunt_damage_groups) or not def.blunt_damage_groups["guns4d_Pa"], "guns4d_Pa is not used in a traditional context. To increase blunt penetration, increase blunt_penetration field.")


            def.raw_sharp_damage = def.raw_sharp_damage or 0
            def.raw_blunt_damage = def.raw_blunt_damage or 0
            def.sharp_penetration = def.sharp_penetration or 0
            if def.sharp_penetration==0 then
                def.blunt_penetration = def.blunt_penetration or def.energy/2
            else
                def.blunt_penetration = def.blunt_penetration or def.energy
            end
            def.energy_sharp_ratio = (def.energy-def.blunt_penetration)/def.energy
        end
        def.init_energy = def.energy
        --blunt pen is in the same units (1 Joule/Area^3 = 1 Pa), so we use it to make the ratio by subtraction.

        def.dir = vector.new(def.dir)
        def.pos = vector.new(def.pos)
        def.history = {}
        def:_iterate()
    end
end
Guns4d.bullet_ray = Instantiatable_class:inherit(ray)