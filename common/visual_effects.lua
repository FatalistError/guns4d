Guns4d.effects={
    bullet_holes = {}
}

--designed for use with the gun class
function Guns4d.effects.muzzle_flash(self)
    local playername = self.player:get_player_name()
    if self.particle_spawners.muzzle_smoke and self.particle_spawners.muzzle_smoke ~= -1 then
        minetest.delete_particlespawner(self.particle_spawners.muzzle_smoke, self.player:get_player_name())
    end
    local dir, offset_pos = self.dir, self:get_pos(self.properties.flash_offset)
    offset_pos=offset_pos+self.player:get_pos()
    local min = vector.rotate(vector.new(-1, -1, -.15), {x=0,y=self.player_rotation.y,z=0})
    local max = vector.rotate(vector.new(1, 1, .15), {x=0,y=self.player_rotation.y,z=0})
    minetest.add_particlespawner({
        exptime = .18,
        time = .1,
        amount = 15,
        attached = self.entity,
        pos = self.properties.flash_offset,
        radius = .04,
        glow = 3.5,
        vel = {min=min, max=max, bias=0},
        texpool = {
            { name = "smoke.png", alpha_tween = {.25, 0}, scale = 2, blend = "alpha",
            animation = {
                    type = "vertical_frames", aspect_w = 16,
                    aspect_h = 16, length = .1,
                },
            },
            { name = "smoke.png", alpha_tween = {.25, 0}, scale = .8, blend = "alpha",
                animation = {
                    type = "vertical_frames", aspect_w = 16,
                    aspect_h = 16, length = .1,
                },
            },
            { name = "smoke.png^[multiply:#dedede", alpha_tween = {.25, 0}, scale = 2,
                blend = "alpha",
                animation = {
                    type = "vertical_frames", aspect_h = 16,
                    aspect_w = 16, length = .1,
                },
            },
            { name = "smoke.png^[multiply:#b0b0b0", alpha_tween = {.2, 0}, scale = 2, blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .25,
                },
            }
      }
    })
    --muzzle smoke
    self.particle_spawners.muzzle_smoke = minetest.add_particlespawner({
        exptime = .3,
        time = 2,
        amount = 50,
        pos = self.properties.flash_offset,
        glow = 2,
        vel = {min=vector.new(-.1,.4,.2), max=vector.new(.1,.6,1), bias=0},
        attached = self.entity,
        texpool = {
            {name = "smoke.png", alpha_tween = {.12, 0}, scale = 1.4, blend = "alpha",
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .35,
                },
            },
            {name = "smoke.png^[multiply:#b0b0b0", alpha_tween = {.2, 0}, scale = 1.4, blend = "alpha",
                animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = .35,},
            }
    }
    })
end
--[[function Guns4d.effects.spawn_bullet_hole_particle(pos, size, texture)
    --modern syntax isn't accepted by add particle to my knowledge, or it's not documented.
    --so I have to use a particle spawner
    minetest.add_particlespawner({
        pos = pos,
        amount = 1,
        time=.1,
        exptime = 10,
        texture = {
            name = 'bullet_hole.png',
            alpha_tween = {1,0}
        }
    })
end
local bullet_holes = Guns4d.effects.bullet_holes
local hole_despawn_dist = 20
local time_since_last_check = 5
minetest.register_globalstep(function(dt)
    if time_since_last_check >= 5 then
        time_since_last_check = 0
        for i, v in pairs(bullet_holes) do
            local pos = v:get_pos()
            if pos then
                local nearby_players = false
                for pname, player in pairs(minetest.get_connected_players()) do
                    if vector.distance(player:get_pos(), pos) < hole_despawn_dist then
                        nearby_players = true
                    end
                end
                if not nearby_players then
                    local props = v:get_properties()
                    Guns4d.effects.spawn_bullet_hole_particle(v:get_pos(), props.visual_size.x, props.textures[5])
                    bullet_holes[i]:remove()
                    table.remove(bullet_holes, i)
                end
            else
                --if pos is nil, we know the bullet delete itself.
                table.remove(bullet_holes, i)
            end
        end
    else
        time_since_last_check = time_since_last_check + dt
    end
end)
minetest.register_entity("guns4d:bullet_hole", {
    initial_properties = {
        visual = "cube",
        visual_size = {x=.15, y=.15, z=0},
        pointable = false,
        static_save = false,
        use_texture_alpha = true,
        textures = {"blank.png",  "bullet_hole.png", "blank.png", "blank.png", "bullet_hole.png", "bullet_hole.png"}
    },
    on_step = function(self, dtime)
        if not self.block_name then
            table.insert(bullet_holes, 1, self.object)
            self.block_name = minetest.get_node(self.block_pos).name
        elseif (TICK%3==0) and (self.block_name ~= minetest.get_node(self.block_pos).name) then
            self.object:remove()
            return
        end

        if not self.timer then
            local properties = self.object:get_properties()
            self.timer = 31
            properties.textures[5] = 'bullet_hole.png'
            self.object:set_properties(properties)
        else
            self.timer = self.timer - dtime
        end
        if self.timer < 30 then
            if self.timer < 0 then
                self.object:remove()
                return
            end
            local properties = self.object:get_properties()
            properties.textures[5] = 'bullet_hole.png^[opacity:'..(math.floor((12.75*tostring(self.timer/30)))*20)
            self.object:set_properties(properties)
        end
    end
})]]