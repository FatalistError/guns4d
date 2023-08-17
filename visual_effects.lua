--designed for use with the gun class
function Guns4d.muzzle_flash(self)
    local playername = self.player:get_player_name()
    if self.particle_spawners.muzzle_smoke and self.particle_spawners.muzzle_smoke ~= -1 then
        minetest.delete_particlespawner(self.particle_spawners.muzzle_smoke, self.player:get_player_name())
    end
    local dir, offset_pos = self.dir, self:get_pos(self.properties.flash_offset)
    offset_pos=offset_pos+self.player:get_pos()
    local min = vector.rotate(vector.new(-1, -1, -.15), {x=0,y=self.offsets.player_rotation.y,z=0})
    local max = vector.rotate(vector.new(1, 1, .15), {x=0,y=self.offsets.player_rotation.y,z=0})
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
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = .35,
                },
            }
    }
    })
end