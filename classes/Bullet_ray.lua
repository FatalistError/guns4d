


local ray = {


    excluded_ents = {
        ["__builtin:item"] = true,
        ["guns4d:item"] = true,
        ["guns4d:gun"] = true,
        ["guns4d:reflector_sight]"] = true
    },

    raw_blunt_damage = 0,
    blunt_penetration = nil, --if nil is half the energy of the gun
    raw_sharp_damage = 0,
    sharp_penetration = 0,
    supersonic_energy = Guns4d.config.minimum_supersonic_energy_assumption,
    pass_sound_mixing_factor = Guns4d.config.default_pass_sound_mixing_factor, --determines the ratio to use based on energy
    iteration_distance = Guns4d.config.default_penetration_iteration_distance,
    energy = 0,
    pellets = 1, --the "number of bullets"
    wall_penetration = true, --is set to false by default if pellets are greater then one.
    spread = 0, --defaults to 1 if pellets > 0 but spread not defined.
    sharp_to_blunt_conversion_factor = .5, -- 1mmRHA is converted to 1mPA of blunt force
    blunt_damage_groups = {}, --minetest.deserialize(Guns4d.config.default_blunt_groups), --these are multiplied by blunt_damage
    sharp_damage_groups = {}, --minetest.deserialize(Guns4d.config.default_sharp_groups),


    pass_sounds = {
        --[1] will be preferred if present
        supersonic = {
            sound = "bullet_crack",
            --max_hear_distance = 3,
            pitch = {
                min = 1.2,
                max = 1
            },
            gain = {
                min = -.5, --this uses distance instead of randomness
                max = 1
            }
        },
        subsonic = {
            sound = "bullet_whizz",
            --max_hear_distance = 3,
            pitch = {
                min = .7,
                max = 1.5
            },
            gain = {
                min = 0, --this uses distance instead of randomness
                max = 1
            }
        },
    },
    --whizz_sound_players = {}, needs to be instantiated anyway
    pass_sound_max_distance = 6,
    mix_supersonic_and_subsonic_sounds = Guns4d.config.mix_supersonic_and_subsonic_sounds,
    spread_deviation = 1, --deviation of the standard distribution represented. The lower the closer to the center of the spread a pellet is more likely to be.
    history = {},
    state = "free",
    last_node = "",
    bullet_hole_class = Guns4d.bullet_hole,
}

--find (valid) edge. Slabs or other nodeboxes that are not the last hit position are not considered (to account for holes) TODO: update to account for hollow nodes
function ray:find_transverse_edge()
    assert(self.instance, "attempt to call obj method on a class")
    local pointed
    local cast1 = minetest.raycast(self.pos+(self.dir*(self.iteration_distance+.001)), self.pos, false, false)
    for hit in cast1 do
        --we can't solidly predict all nodes, so ignore them as the distance will be solved regardless. If node name is different then
        if hit.type == "node" and (vector.distance(hit.intersection_point, self.pos) > 0.0001) and (vector.equals(hit.under, self.last_pointed_node.under) or not minetest.registered_nodes[self.last_node_name].node_box) then
            pointed = hit
        end
    end
    if (pointed) and (vector.distance(pointed.intersection_point, self.pos) < self.iteration_distance) then
        return pointed.intersection_point, pointed.intersection_normal
    end
end
function ray:cast()
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
            end_pos = self.pos+(self.dir*self.iteration_distance)
        end
    else
        end_pos = self.pos+(self.dir*self.range)
    end
    --do the main raycast. We don't account for mmRHA dropoff here.
    local continue = true --indicates wether to :iterate wether the Bullet_ray has ended
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
            if (hit.type == "object") and hit.ref then
                local luaent = hit.ref:get_luaentity()
                if (not self.excluded_ents[luaent.name]) and (hit.ref ~= self.player) and ((not self.last_pointed_object) or (hit.ref ~= self.last_pointed_object.ref)) then
                    print(luaent.name)
                    end_pos = hit.intersection_point
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
    end
    --set "last" values.
    return pointed_node, pointed_object, next_state, end_pos, end_normal, continue
end
--the main function.
function ray:iterate()
    assert(self.instance, "attempt to call obj method on a class")
    local pointed_node, pointed_object, next_state, end_pos, end_normal, continue = self:cast()

    local distance = vector.distance(self.pos, end_pos)
    if self.state == "free" then
        --add entry hole
        if next_state == "transverse" then
            self:bullet_hole(end_pos, end_normal)
        end
        --apply energy dropoff.
        self.energy = self.energy-(distance*self.energy_dropoff)
    else
        --add exit hole
        --edge cases exist (pun not intended) where the normal doesn't exist? not really sure how, but it happens occasionally. \_('.')_/
        if next_state == "free" and end_normal then
            self:bullet_hole(end_pos, end_normal)
        end
        --calc penetration loss from traveling through the block
        local penetration_loss = distance*Guns4d.node_properties[self.last_node_name].mmRHA
        --calculate our energy loss based on the percentage of energy our penetration represents.
        self.energy = self.energy-((self.init_def.energy*self.energy_sharp_ratio)*(penetration_loss/self.sharp_penetration))
    end

    --apply damage to objects
    if pointed_object then
        self.pos = pointed_object.intersection_point
        self.last_pointed_object = pointed_object
        self:hit_entity(pointed_object.ref)
    else
        self.pos = end_pos
    end
    --prepare for next iteration
    self.state = next_state
    self.range = self.range-distance
    if self.range <= 0.0005 or self.energy < 0 then
        continue = false
    end
    --build this history
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
        self:iterate()
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
    --calculate the amount of penetration we've lost based on how much of the energy is converted to penetration (energy_sharp_ratio)
    --dear jesus why didn't I make comments for this... ok your guess is as good as mine here, this is a cluster fuck not going to lie. But it works:tm:
    self.energy=Guns4d.math.clamp(self.energy, 0, math.huge)
    local dropoff = self.energy/self.init_def.energy

    local bullet_sharp_pen = self.sharp_penetration*dropoff
    local effective_sharp_pen = Guns4d.math.clamp(bullet_sharp_pen - (resistance.guns4d_mmRHA or 0), 0, math.huge)

    local converted_Pa = (bullet_sharp_pen-effective_sharp_pen) * self.sharp_to_blunt_conversion_factor
    local bullet_blunt_pen = converted_Pa+(self.blunt_penetration*dropoff)
    local effective_blunt_pen = Guns4d.math.clamp(bullet_blunt_pen - (resistance.guns4d_Pa or 0), 0, math.huge)
    self:apply_damage(object, effective_sharp_pen, effective_blunt_pen)
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
    --print(self.energy, "b,s dmg:", blunt_dmg, sharp_dmg, "ratio:", blunt_ratio, sharp_ratio, "input", blunt_pen, sharp_pen, "...", self.energy_sharp_ratio)

    --now apply damage groups.
    local headshot = 1
    if Guns4d.config.simple_headshot then
        local sb = object:get_properties().selectionbox
        local above_chest = (math.abs(sb[2])+math.abs(sb[5]))*Guns4d.config.simple_headshot_body_ratio
        local hit_pos = self.pos-object:get_pos()
        local lowest_point = ((sb[2] < sb[5]) and sb[2]) or sb[5]
        if (hit_pos.y-lowest_point) > above_chest then
            headshot = Guns4d.config.headshot_damage_factor
        end
    end
    local damage_values = {}
    for i, v in pairs(self.blunt_damage_groups) do
        damage_values[i] = v*blunt_ratio*headshot
    end
    for i, v in pairs(self.sharp_damage_groups) do
        damage_values[i] = (damage_values[i] or 0) + (v*sharp_ratio*headshot)
    end
    damage_values[Guns4d.config.default_damage_group] = (damage_values[Guns4d.config.default_damage_group] or 0)+((blunt_dmg+sharp_dmg)*headshot)
    object:punch((Guns4d.config.punch_from_player_not_gun and self.player) or self.gun.entity, 1000, {damage_groups=damage_values}, self.dir)
end
function ray:bullet_hole(pos, normal)
    assert(self.instance, "attempt to call obj method on a class")
    self.bullet_hole_class:new({
        pos = vector.new(pos),
        rotation = vector.dir_to_rotation(normal)
    })
end
function ray:play_bullet_pass_sounds()
    --iteration done, damage applied, find players to apply bullet whizz to
    local start_pos = self.init_def.pos
    local played_for = self.whizz_sound_players
    --print(dump(self.history))
    for i = #self.history, 1, -1 do
        local v = self.history[i]
        for _, player in pairs(minetest.get_connected_players()) do
            if (player~=self.player) and not played_for[player] then
                local pos = player:get_pos()+vector.new(0,player:get_properties().eye_height,0)
                local nearest = Guns4d.math.nearest_point_on_line(start_pos, v.pos, pos)
                if vector.distance(nearest, pos) < self.pass_sound_max_distance then
                    played_for[player] = true
                    if self.pass_sounds[1] then
                        local sound = Guns4d.table.deep_copy(self.pass_sounds[1])
                        sound.pos = nearest
                        Guns4d.play_sounds(self.pass_sounds[1])
                    else
                        --interpolate to find the energy of the shot to determine supersonic or not.
                        local v1
                        if #self.history > i then v1 = v[i+1].energy else v1 = self.init_def.energy end
                        local v2 = v.energy

                        local ip_r = vector.distance(start_pos, nearest)/vector.distance(start_pos, pos)
                        local energy_at_point = v1+((v2-v1)*(1-ip_r))
                        local relative_distance = vector.distance(nearest, pos)/self.pass_sound_max_distance

                        if self.mix_supersonic_and_subsonic_sounds then
                            local f = self.pass_sound_mixing_factor
                            local sounds = {Guns4d.table.deep_copy(self.pass_sounds.supersonic), Guns4d.table.deep_copy(self.pass_sounds.subsonic)}
                            for _, sound in pairs(sounds) do
                                for _, t in pairs({"gain", "pitch"}) do
                                    if sound[t].min then
                                        sound[t] = sound[t].max+((sound[t].min-sound[t].max)*relative_distance) --mix them based on distance
                                    end
                                end
                            end
                            local x = (energy_at_point*relative_distance)/self.supersonic_energy
                            local denominator = ((x-1)+math.sqrt(f))^2
                            local mix_ratio = Guns4d.math.clamp(1-(f/denominator), 0,1) --mixes based on the energy relative to the supersonic energy. This is to simulate a "sonic boom" effect.
                            --minetest.chat_send_all(dump({f, x, denominator, mix_ratio}))
                            sounds[1].gain = sounds[1].gain*mix_ratio --supersonic
                            sounds[2].gain = sounds[2].gain*(1-mix_ratio)--subsonic
                            sounds.pos = nearest
                            sounds.to_player = player:get_player_name()
                            Guns4d.play_sounds(sounds)

                            local sound = self.pass_sounds.subsonic
                            if energy_at_point >= self.supersonic_energy then
                                sound = self.pass_sounds.supersonic
                            end
                            sound = Guns4d.table.deep_copy(sound)
                            sound.pos = nearest
                            for _, t in pairs({"gain", "pitch"}) do
                                if sound[t].min then
                                    sound[t] = sound[t].max+((sound[t].min-sound[t].max)*relative_distance)
                                end
                            end
                            Guns4d.play_sounds(sound)
                        end
                    end
                end
            end
        end
        start_pos = v.pos
    end
end
function ray:simple_cast(pos, dir)
    local cast = minetest.raycast(pos, pos+(dir*self.range), true, true)
    local pointed
    for hit in cast do
        if (hit.type == "node") and (Guns4d.node_properties[minetest.get_node(hit.under).name].behavior ~= "ignore") then
            self:bullet_hole(hit.intersection_point, hit.intersection_normal)
            pointed = hit
            break
        elseif (hit.type == "object") and (hit.ref ~= self.player) then
            self.energy = self.energy-(vector.distance(hit.intersection_point, pos)*self.energy_dropoff)
            self.pos = hit.intersection_point
            self:hit_entity(hit.ref)
            pointed = hit
            break
        end
    end
    if pointed then
        table.insert(self.history, {
            pos = pointed.intersection_point,
            energy = self.energy, --TODO, ENERGY CALCS
            state = "free",
            last_node = (pointed.under and minetest.get_node(pointed.under).name),
            normal = pointed.intersection_normal, --end normal may be nil, as it's only for hit effects.
        })
    else
        table.insert(self.history, {
            pos = pos+(dir*self.range),
            energy = self.energy, --TODO, ENERGY CALCS
            state = "free",
        })
    end
end
function ray.construct(def)
    if def.instance then
        assert((not (def.blunt_penetration and def.energy)) or (def.blunt_penetration < def.energy), "blunt penetration may not be greater than energy! Blunt penetration is in Joules/Megapascals, energy is also in Joules.")

        if def.sharp_penetration==0 then
            def.blunt_penetration = def.blunt_penetration or def.energy/2
        else
            def.blunt_penetration = def.blunt_penetration or def.energy
        end
        def.energy_sharp_ratio = (def.energy-def.blunt_penetration)/def.energy
        def.whizz_sound_players = {}
        def.init_def = {
            energy = def.energy,
            pos = def.pos,
            dir = def.dir or def.gun:get_dir(),
            range = def.range
        }
        if def.pellets > 1 then
            if rawget(def, "wall_penetration") == nil then
                def.wall_penetration = false
            end
            if rawget(def, "spread") == nil then
                def.spread = 1
            end
            if rawget(def, "iteration_distance") == nil then
                def.iteration_distance = 10
            end
        end
        --blunt pen is in the same units (1 Joule/Area^3 = 1 Pa), so we use it to make the ratio by subtraction.
        local init_def = def.init_def
        for i=1,def.pellets do
            local x, y = Guns4d.math.angular_normal_distribution(def.spread_deviation)
            --x, y = (math.random()-.5)*2, (math.random()-.5)*2
            local dir = def.gun:get_dir(false, x*def.spread, y*def.spread)
            def.energy = init_def.energy
            def.dir = dir or vector.new(init_def.dir)
            def.pos = vector.new(init_def.pos)
            def.range = init_def.range
            def.history = {}
            if def.wall_penetration then
                def:iterate()
                def:play_bullet_pass_sounds()
            else
                def:simple_cast(init_def.pos, dir or init_def.dir)
                def:play_bullet_pass_sounds()
            end
        end
    end
end
Guns4d.bullet_ray = leef.class.new_class:inherit(ray)