local player_positions = {}
minetest.register_globalstep(function(dt)
    for i, v in pairs(player_positions) do
        player_positions[i] = nil
    end
    for i, player_handler in pairs(Guns4d.players) do
        table.insert(player_positions, player_handler.player:get_pos())
    end
    local count = 0
    for i = #Guns4d.bullet_hole.instances+1, 1, -1 do --start at the last so the bullet_holes added sooner are expired.
        local obj = Guns4d.bullet_hole.instances[i]
        if obj then --obj can be a false value.
            if (count > Guns4d.config.maximum_bullet_holes) and (obj.exp_time > 2.5) then
                obj.exp_time = 2.5
            end
            count = count + 1
            local closest_dist
            for _, pos in pairs(player_positions) do
                local dist = vector.distance(obj.pos, pos)
                if (not closest_dist) or (dist < closest_dist) then
                    closest_dist = dist
                end
            end

            if closest_dist > obj.deletion_distance then
                obj:delete()
                return
            end
            if (closest_dist > obj.render_distance) and obj.rendered then
                obj:unrender()
            elseif (closest_dist < obj.render_distance*.85) and not obj.rendered then
                obj:render()
            end
            obj:update(dt)
        end
    end
end)
Guns4d.bullet_hole = Instantiatable_class:inherit({
    texture = 'bullet_hole.png',
    exp_time = 30, --how much time a rendered bullet hole takes to expire
    unrendered_exptime = 10, --how much time an unrendered bullet hole takes to expire
    deletion_distance = 100,
    --heat_effect = false,
    instances = {},
    size = .15,
    render_distance = 25,
    particle_spawner_id = nil,
    hole_entity = "guns4d:bullet_hole",
    rendered = true,
})
local Bullet_hole = Guns4d.bullet_hole
---@diagnostic disable-next-line: duplicate-set-field
function Bullet_hole.construct(def)
    if def.instance then
        assert(def.pos)
        assert(def.rotation)
        --[[for i, v in pairs(def.pos) do
           if math.abs(v-Guns4d.math.round(v)) > (.5-(def.size/2)) then
                def.pos[i] = Guns4d.math.round(v)+((math.abs(v-Guns4d.math.round(v))/(v-Guns4d.math.round(v)))*(.5-(def.size/2)))
           end
        end]]
        Bullet_hole.instances[(#Bullet_hole.instances)+1]=def
        def.id = #Bullet_hole.instances
        def.unrendered_expire_speed = def.exp_time/def.unrendered_exptime
        def:render()
    end
end
function Bullet_hole:render()
    assert(self.instance)
    self.rendered = true

    local normal = vector.rotate(vector.new(0,0,1), self.rotation)
    local ent = minetest.add_entity(self.pos+(normal*(.001+math.random()/1000)), self.hole_entity)
    ent:set_rotation(vector.dir_to_rotation(normal))
    ent:set_properties({visual_size={x=self.size, y=self.size, z=0}})
    self.entity = ent
    local lua_ent = ent:get_luaentity()
    lua_ent.lua_instance = self

    if self.particle_spawner_id then
        minetest.delete_particlespawner(self.particle_spawner_id)
    end
end
function Bullet_hole:unrender()
    assert(self.instance)
    self.rendered = false

    local normal = vector.rotate(vector.new(0,0,1), self.rotation)
    local time_left = self.exp_time/self.unrendered_expire_speed
    local number_of_particles = 2
    minetest.add_particle({
        size = self.size*10,
        texture = self.texture,
        expiration_time = 2*time_left/math.ceil(number_of_particles*time_left),
        pos = self.pos+(normal*.05)
    })
    self.particle_spawner_id = minetest.add_particlespawner({
        pos = self.pos+(normal*.05),
        amount = math.ceil(number_of_particles*time_left)*5, --multiply so it doesn't flash in and out of existence...
        time=time_left,
        exptime = time_left/math.ceil(number_of_particles*time_left),
        texture = {
            name = self.texture,
            scale = self.size*10
        }
    })
    if self.entity:get_pos() then
        self.entity:remove()
    end
end
function Bullet_hole:delete()
    assert(self.instance)
    Bullet_hole.instances[self.id] = false
    if self.entity:get_pos() then
        self.entity:remove()
    end
    if self.particle_spawner_id then
        minetest.delete_particlespawner(self.particle_spawner_id)
    end
end
function Bullet_hole:update(dt)
    assert(self.instance)
    if self.rendered then
        self.exp_time = self.exp_time-dt
    else
        self.exp_time = self.exp_time-(dt*self.unrendered_expire_speed)
    end
    if self.exp_time <= 0 then
        self:delete()
    end
end
minetest.register_entity("guns4d:bullet_hole", {
    initial_properties = {
        visual = "cube",
        visual_size = {x=.1, y=.1, z=0},
        pointable = false,
        static_save = false,
        use_texture_alpha = true,
        textures = {"blank.png", "blank.png", "blank.png", "blank.png", "bullet_hole.png", "blank.png"}
    },
    on_step = function(self, dt)
        if TICK % 50 then
            local lua_instance = self.lua_instance
            if lua_instance.exp_time <= 0 then
                self.object:remove()
                return
            end
            if lua_instance.exp_time < 2.5 then
                local properties = self.object:get_properties()
                properties.textures[5] = lua_instance.texture..'^[opacity:'..(math.floor((12.75*tostring(lua_instance.exp_time/2.5)))*20)
                self.object:set_properties(properties)
            end
        end
    end
})