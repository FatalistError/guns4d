local Vec = vector
local gun_default = {
    --itemstack = Itemstack
    --gun_entity = ObjRef
    name = "__guns4d:default__",
    itemstring = "",
    registered = {},
    property_modifiers = {},
    properties = {
        magnification = 1,
        hip = { --used by gun entity (attached offset)
            offset = Vec.new(),
            sway_vel_mul = 5, --these are multipliers for various attributes. Does support fractional vals (which can be useful if you want to make hipfire more random with spread.)
            sway_angle_mul = 1,
        },
        ads = { --used by player_handler, animation handler (eye bone offset from horizontal_offset), gun entity (attached offset)
            offset = Vec.new(),
            horizontal_offset = 0,
            aim_time = 1,
        },
        firemodes = {
            "single", --not limited to semi-automatic.
            "auto",
            "burst"
        },
        recoil = { --used by update_recoil()
            velocity_correction_factor = { --velocity correction factor is currently very broken.
                gun_axial = 1,
                player_axial = 1,
            },
            target_correction_factor = { --angular correction rate per second: time_since_fire*target_correction_factor
                gun_axial = 1,
                player_axial = 1,
            },
            angular_velocity_max = { --max velocity, so your gun doesnt "spin me right round baby round round"
                gun_axial = 1,
                player_axial = 1,
            },
            angular_velocity = { --the velocity added per shot. This is the real "recoil" part of the recoil
                gun_axial = {x=0, y=0},
                player_axial = {x=0, y=0},
            },
            bias = { --dictates the distribution bias for the direction angular_velocity is in. I.e. if you want recoil to always go up you set x to 1, more often to the right? y to -.5
                gun_axial = {x=1, y=0},
                player_axial = {x=1, y=0},
            },
            target_correction_max_rate = { --the cap for target_correction_fire (i.e. this is the maximum amount it will ever correct per second.)
                gun_axial = 1,
                player_axial = 1,
            },
            hipfire_multiplier = { --the mutliplier for recoil (angular_velocity) at hipfire (can be fractional)
                gun_axial = 1,
                player_axial = 1
            },
        },
        sway = { --used by update_sway()
            max_angle = {
                gun_axial = 0,
                player_axial = 0,
            },
            angular_velocity = {
                gun_axial = 0,
                player_axial = 0,
            },
            hipfire_angle_multiplier = { --the mutliplier for sway max_angle at hipfire (can be fractional)
                gun_axial = 2,
                player_axial = 2
            },
            hipfire_velocity_multiplier = { --same as above but for velocity.
                gun_axial = 2,
                player_axial = 2
            }
        },
        walking_offset = { --used by update_walking() (or something)
            gun_axial = {x=1, y=-1},
            player_axial = {x=1,y=1},
        },
        breathing_scale = .5, --the max angluler offset caused by breathing.
        controls = { --used by control_handler
            __overfill=true, --if present, this table will not be filled in.
            aim = Guns4d.default_controls.aim,
            auto = Guns4d.default_controls.auto,
            reload = Guns4d.default_controls.reload,
            on_use = Guns4d.default_controls.on_use,
            firemode = Guns4d.default_controls.firemode
        },
        reload = { --used by defualt controls. Still provides usefulness elsewhere.
            __overfill=true, --if present, this table will not be filled in.
            {type="unload", time=1, anim="unload", interupt="to_ground", hold = true},
            {type="load", time=1, anim="load"}
        },
        ammo = { --used by ammo_handler
            magazine_only = false,
            accepted_bullets = {},
            accepted_magazines = {}
        },
        visuals = {
            --mesh
            backface_culling = true,
            root = "gun",
            arm_right = "right_aimpoint",
            arm_left = "left_aimpoint",
            animations = { --used by animations handler for idle, and default controls
                empty = {x=0,y=0},
                loaded = {x=1,y=1},
            },
        },
         --used by ammo_handler
        flash_offset = Vec.new(), --used by fire() (for fsx and ray start pos) [RENAME NEEDED]
        firerateRPM = 600, --used by update() and by extent fire() + default controls
        ammo_handler = Ammo_handler
    },
    offsets = {
        recoil = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
        sway = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
        walking = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
            tick = 0,
            --velocity
        },
        breathing = {
            gun_axial = Vec.new(), --gun axial unimplemented...
            player_axial = Vec.new(),
        },
    },
    animation_rotation = vector.new(),
    spread = {

    },
    --[[total_offset_rotation = { --can't be in offsets, as they're added automatically.
        gun_axial = Vec.new(),
        player_axial = Vec.new(),
    },]]
    player_rotation = Vec.new(),
    velocities = {
        recoil = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
        sway = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
    },
    --magic number BEGONE
    consts = {
        HIP_PLAYER_GUN_ROT_RATIO = .75,
        AIM_OUT_AIM_IN_SPEED_RATIO = 2.5,
        HIPFIRE_BONE = "guns3d_hipfire_bone", --these shouldn't be here at all, these need to be model determinant.
        AIMING_BONE = "guns3d_aiming_bone",
        KEYFRAME_SAMPLE_PRECISION = .1, --[[what frequency to take precalcualted keyframe samples. The lower this is the higher the memory allocation it will need- though minimal.
        This will fuck shit up if you change it after gun construction/inheritence (interpolation between precalculated vectors will not work right)]]
        WAG_CYCLE_SPEED = 1.6,
        DEFAULT_FPS = 60,
        WAG_DECAY = 1, --divisions per second
        HAS_RECOIL = true,
        HAS_BREATHING = true,
        HAS_SWAY = true,
        HAS_WAG = true,
        HAS_GUN_AXIAL_OFFSETS = true,
        ANIMATIONS_OFFSET_AIM = false,
        INFINITE_AMMO_IN_CREATIVE = true,
        LOOP_IDLE_ANIM = false
    },
    animation_data = { --where animations data is stored.
        anim_runtime = 0,
        length = 0,
        fps = 0,
        frames = {0,0},
        current_frame = 0,
    --[[animations = {

        }
    ]]
    },
    particle_spawners = {},
    current_firemode = 1,
    walking_tick = 0,
    time_since_last_fire = 0,
    time_since_creation = 0,
    rechamber_time = 0,
    muzzle_flash = Guns4d.effects.muzzle_flash
}
--I dont remember why I made this, used it though lmao
function gun_default.multiplier_coefficient(multiplier, ratio)
    return 1+((multiplier*ratio)-ratio)
end
--update the gun, da meat and da potatoes
function gun_default:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    if not self:has_entity() then self:add_entity(); self:clear_animation() end
    local handler = self.handler
    local look_rotation = handler.look_rotation --remember that this is in counterclock-wise rotation. For 4dguns we use clockwise so it makes a bit more sense for recoil. So it needs to be inverted.
    local total_rot = self.total_offset_rotation
    local player_rot = self.player_rotation
    local constant = 5 --make this a config setting

    --player look rotation. I'm going to keep it real, I don't remember what this math does. Player handler just stores the player's rotation from MT in degrees, which is for some reason inverted
    player_rot.y = -handler.look_rotation.y
    local next_vert_aim = ((player_rot.x+look_rotation.x)/(1+constant*dt))-look_rotation.x
    if math.abs(look_rotation.x-next_vert_aim) > .005 then
        player_rot.x = next_vert_aim
    else
        player_rot.x = -look_rotation.x
    end
    --timers
    if self.rechamber_time > 0 then
        self.rechamber_time = self.rechamber_time - dt
    else
        self.rechamber_time = 0
    end
    self.time_since_creation = self.time_since_creation + dt
    self.time_since_last_fire = self.time_since_last_fire + dt

    --update some vectors
    if self.consts.HAS_SWAY then self:update_sway(dt) end
    if self.consts.HAS_RECOIL then self:update_recoil(dt) end
    if self.consts.HAS_BREATHING then self:update_breathing(dt) end
    if self.consts.HAS_WAG then self:update_wag(dt) end

    --dynamic crosshair needs to be updated BEFORE wag
    if self.properties.sprite_scope then
        self.sprite_scope:update()
    end
    if self.properties.crosshair then
        self.crosshair:update()
    end

    self:update_animation(dt)
    self.dir = self:get_dir()
    self.local_dir = self:get_dir(true)
    self.paxial_dir = self:get_player_axial_dir()
    self.local_paxial_dir = self:get_player_axial_dir(true)
    self.pos = self:get_pos()+self.handler:get_pos()

    local offsets = self.offsets
    --local player_axial = offsets.recoil.player_axial + offsets.walking.player_axial + offsets.sway.player_axial + offsets.breathing.player_axial
    --local gun_axial    = offsets.recoil.gun_axial    + offsets.walking.gun_axial    + offsets.sway.gun_axial
    --apply the offsets.
    total_rot.player_axial.x = 0; total_rot.player_axial.y = 0
    total_rot.gun_axial.x = 0; total_rot.gun_axial.y = 0
    for type, _ in pairs(total_rot) do
        for i, offset in pairs(offsets) do
            if self.consts.HAS_GUN_AXIAL_OFFSETS or type~="gun_axial" then
                total_rot[type] = total_rot[type]+offset[type]
            end
        end
    end
end

function gun_default:cycle_firemodes()
    self.current_firemode = (self.current_firemode+1)%(#self.properties.firemodes)
    minetest.chat_send_all(self.properties.firemodes[self.current_firemode+1])
end
function gun_default:attempt_fire()
    assert(self.instance, "attempt to call object method on a class")
    if self.rechamber_time <= 0 then
        local spent_bullet = self.ammo_handler:spend_round()
        if spent_bullet and spent_bullet ~= "empty" then
            local dir = self.dir
            local pos = self.pos
            local bullet_def = table.fill(Guns4d.ammo.registered_bullets[spent_bullet], {
                player = self.player,
                pos = pos,
                dir = dir,
                gun = self
            })
            Guns4d.bullet_ray:new(bullet_def)
            if self.properties.visuals.animations.fire then
                self:set_animation(self.properties.visuals.animations.fire, nil, false)
            end
            self:recoil()
            self:muzzle_flash()
            self.rechamber_time = 60/self.properties.firerateRPM
        end
    end
end

function gun_default:recoil()
    assert(self.instance, "attempt to call object method on a class")
    local rprops = self.properties.recoil
    for axis, recoil in pairs(self.velocities.recoil) do
        for _, i in pairs({"x","y"}) do
            recoil[i] = recoil[i] + (rprops.angular_velocity[axis][i]
                *math.rand_sign((rprops.bias[axis][i]/2)+.5))
                *self.multiplier_coefficient(rprops.hipfire_multiplier[axis], 1-self.handler.ads_location)
        end
    end
    self.time_since_last_fire = 0
end
--all of this dir shit needs to be optimized HARD
function gun_default:get_gun_axial_dir()
    assert(self.instance, "attempt to call object method on a class")
    local rotation = self.total_offset_rotation
    local dir = Vec.new(Vec.rotate({x=0, y=0, z=1}, {y=0, x=rotation.gun_axial.x*math.pi/180, z=0}))
    dir = Vec.rotate(dir, {y=rotation.gun_axial.y*math.pi/180, x=0, z=0})
    return dir
end
function gun_default:get_player_axial_dir(rltv)
    assert(self.instance, "attempt to call object method on a class")
    local handler = self.handler
    local rotation = self.total_offset_rotation
    local dir = Vec.new(Vec.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.player_axial.x)*math.pi/180), z=0}))
    dir = Vec.rotate(dir, {y=((rotation.player_axial.y)*math.pi/180), x=0, z=0})
    if not rltv then
        if (self.properties.sprite_scope and handler.control_bools.ads) or (self.properties.crosshair and not handler.control_bools.ads) then
            --we need the head rotation in either of these cases, as that's what they're showing.
            dir = Vec.rotate(dir, {x=-handler.look_rotation.x*math.pi/180,y=-handler.look_rotation.y*math.pi/180,z=0})
        else
            dir = Vec.rotate(dir, {x=self.player_rotation.x*math.pi/180,y=self.player_rotation.y*math.pi/180,z=0})
        end
    end
    --[[local hud_pos = Vec.rotate(dir, {x=0,y=self.player_rotation.y*math.pi/180,z=0})+player:get_pos()+{x=0,y=player:get_properties().eye_height,z=0}+vector.rotate(player:get_eye_offset()/10, {x=0,y=self.player_rotation.y*math.pi/180,z=0})
    local hud = player:hud_add({
        hud_elem_type = "image_waypoint",
        text = "muzzle_flash2.png",
        world_pos =  hud_pos,
        scale = {x=10, y=10},
        alignment = {x=0,y=0},
        offset = {x=0,y=0},
    })
    minetest.after(0, function(hud)
        player:hud_remove(hud)
    end, hud)]]
    return dir
end
function gun_default:get_dir(rltv)
        assert(self.instance, "attempt to call object method on a class")
        local rotation = self.total_offset_rotation
        local handler = self.handler
        --rotate x and then y.
        local dir = Vec.new(Vec.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.gun_axial.x+rotation.player_axial.x)*math.pi/180), z=0}))
        dir = Vec.rotate(dir, {y=((rotation.gun_axial.y+rotation.player_axial.y)*math.pi/180), x=0, z=0})
        if not rltv then
            if (self.properties.sprite_scope and handler.control_bools.ads) or (self.properties.crosshair and not handler.control_bools.ads) then
                --we need the head rotation in either of these cases, as that's what they're showing.
                dir = Vec.rotate(dir, {x=-handler.look_rotation.x*math.pi/180,y=-handler.look_rotation.y*math.pi/180,z=0})
            else
                dir = Vec.rotate(dir, {x=self.player_rotation.x*math.pi/180,y=self.player_rotation.y*math.pi/180,z=0})
            end
        end

        --local hud_pos = dir+player:get_pos()+{x=0,y=player:get_properties().eye_height,z=0}+vector.rotate(player:get_eye_offset()/10, {x=0,y=player_rotation.y*math.pi/180,z=0})
        --[[local hud = player:hud_add({
            hud_elem_type = "image_waypoint",
            text = "muzzle_flash2.png",
            world_pos =  hud_pos,
            scale = {x=10, y=10},
            alignment = {x=0,y=0},
            offset = {x=0,y=0},
        })
        minetest.after(0, function(hud)
            player:hud_remove(hud)
        end, hud)]]
    return dir
end

--broken! doesn't properly reflect values.
function gun_default:get_pos(added_pos, relative, debug)
    assert(self.instance, "attempt to call object method on a class")
    local player = self.player
    local handler = self.handler
    local bone_location
    local gun_offset
    if handler.control_bools.ads then
        gun_offset = self.properties.ads.offset
        bone_location = player:get_eye_offset() or vector.zero()
        bone_location.y = bone_location.y + handler:get_properties().eye_height
        bone_location.x = handler.horizontal_offset
    else
        --minetest is really wacky.
        gun_offset = self.properties.hip.offset
        bone_location = vector.new(handler.player_model_handler.offsets.global.hipfire)
        bone_location.x = bone_location.x / 10
        bone_location.z = bone_location.z / 10
        bone_location.y = bone_location.y / 10
    end
    if added_pos then
        gun_offset = gun_offset+added_pos
    end
    --dir needs to be rotated twice seperately to avoid weirdness
    local pos
    if not relative then
        pos = Vec.rotate(bone_location, {x=0, y=-handler.look_rotation.y*math.pi/180, z=0})
        pos = pos+Vec.rotate(gun_offset, Vec.dir_to_rotation(self.paxial_dir))
    else
        pos = Vec.rotate(gun_offset, Vec.dir_to_rotation(self.local_paxial_dir)+{x=self.player_rotation.x*math.pi/180,y=0,z=0})+bone_location
    end
    if debug then
        local hud_pos
        if relative then
            hud_pos = vector.rotate(pos, {x=0,y=player:get_look_horizontal(),z=0})+handler:get_pos()
        else
            hud_pos = pos+handler:get_pos()
        end
        local hud = player:hud_add({
            hud_elem_type = "image_waypoint",
            text = "muzzle_flash2.png",
            world_pos =  hud_pos,
            scale = {x=10, y=10},
            alignment = {x=0,y=0},
            offset = {x=0,y=0},
        })
        minetest.after(0, function(hud)
            player:hud_remove(hud)
        end, hud)
    end
    --world pos, position of bone, offset of gun from bone (with added_pos)
    return pos
end

function gun_default:add_entity()
    assert(self.instance, "attempt to call object method on a class")
    self.entity = minetest.add_entity(self.player:get_pos(), self.name.."_visual")
    local obj = self.entity:get_luaentity()
    obj.parent_player = self.player
    Guns4d.gun_by_ObjRef[self.entity] = self
    obj:on_step()
end

function gun_default:has_entity()
    assert(self.instance, "attempt to call object method on a class")
    if not self.entity then return false end
    if not self.entity:get_pos() then return false end
    return true
end
function gun_default:update_wag(dt)
    local handler = self.handler
    local wag = self.offsets.walking
    local velocity = wag.velocity
    local old_tick
    if handler.walking then
        velocity = self.player:get_velocity()
        wag.velocity = velocity
    end
    old_tick = old_tick or wag.tick
    if velocity then
        if handler.walking then
            wag.tick = wag.tick + (dt*Vec.length(velocity))
        else
            wag.tick = wag.tick + (dt*4)
        end
    end
    local walking_offset = self.offsets.walking
    if velocity and (not handler.walking) and (math.ceil(old_tick/self.consts.WAG_CYCLE_SPEED)+.5 < (math.ceil(wag.tick/self.consts.WAG_CYCLE_SPEED))+.5) and (wag.tick > old_tick) then
        wag.velocity = nil
        return
    end
    for _, i in ipairs({"x","y"}) do
        for _, axis in ipairs({"player_axial", "gun_axial"}) do
            if velocity then
                local multiplier = 1
                if i == "x" then
                    multiplier = 2
                end
                --if the result is negative we know that it's flipped, and thus can be ended.
                local inp = (wag.tick/self.consts.WAG_CYCLE_SPEED)*math.pi*multiplier
                --this is a mess, I think that 1.6 is the frequency of human steps or something
                walking_offset[axis][i] = math.sin(inp)*self.properties.walking_offset[axis][i]
            else
                local old_value = walking_offset[axis][i]
                if math.abs(walking_offset[axis][i]) > .005 then
                    local multiplier = 1/self.consts.WAG_DECAY
                    walking_offset[axis][i] = walking_offset[axis][i]-(walking_offset[axis][i]*multiplier*dt)
                else
                    walking_offset[axis][i] = 0
                end
                if math.abs(walking_offset[axis][i]) > math.abs(old_value) then
                    walking_offset[axis][i] = 0
                end
            end
        end
    end
end
function gun_default:update_recoil(dt)
    for axis, _ in pairs(self.offsets.recoil) do
        for _, i in pairs({"x","y"}) do
            local recoil = self.offsets.recoil[axis][i]
            local recoil_vel = math.clamp(self.velocities.recoil[axis][i],-self.properties.recoil.angular_velocity_max[axis],self.properties.recoil.angular_velocity_max[axis])
            local old_recoil_vel = recoil_vel
            recoil = recoil + recoil_vel
            if math.abs(recoil_vel) > 0.01 then
                --look, I know this doesn't really make sense, but this is the best I can do atm. I've looked for better and mroe intuitive methods, I cannot find them.
                --8-(8*(1-(8/100))
                --recoil_vel = recoil_vel-((recoil_vel-(recoil_vel/(1+self.properties.recoil.velocity_correction_factor[axis])))*dt*10)
                recoil_vel = recoil_vel * (recoil_vel/(recoil_vel/(self.properties.recoil.velocity_correction_factor[axis]*2))*dt)
            else
                recoil_vel = 0
            end
            if math.abs(recoil_vel)>math.abs(old_recoil_vel) then
                recoil_vel = 0
            end
            --ax^2+bx+c
            --recoil_velocity_correction_rate
            --recoil_correction_rate
            local old_recoil = recoil
            if math.abs(recoil) > 0.001 then
                local correction_multiplier = self.time_since_last_fire*self.properties.recoil.target_correction_factor[axis]
                local correction_value = recoil*correction_multiplier
                correction_value = math.clamp(math.abs(correction_value), 0, self.properties.recoil.target_correction_max_rate[axis])
                recoil=recoil-(correction_value*dt*(math.abs(recoil)/recoil))
                --prevent overcorrection
                if math.abs(recoil) > math.abs(old_recoil) then
                    recoil = 0
                end
            end
            self.velocities.recoil[axis][i] = recoil_vel
            self.offsets.recoil[axis][i] = recoil
        end
    end
end
function gun_default:update_animation(dt)
    local ent = self.entity
    local data = self.animation_data
    data.runtime = data.runtime + dt
    data.current_frame = math.clamp(data.current_frame+(dt*data.fps), data.frames.x, data.frames.y)
    if data.loop and (data.current_frame > data.frames.y) then
        data.current_frame = data.frames.x
    end
    --track rotations and applies to aim.
    if self.consts.ANIMATIONS_OFFSET_AIM then self:update_animation_rotation() end
end
--IMPORTANT!!! this does not directly modify the animation_data table anymore, it's all hooked through ObjRef:set_animation() (init.lua) so if animation is set elsewhere it doesnt break.
--this may be deprecated in the future- as it is no longer really needed now that I hook ObjRef functions.
function gun_default:set_animation(frames, length, fps, loop)
    loop = loop or false --why the fuck default is true? I DONT FUCKIN KNOW (this undoes this)
    assert(type(frames)=="table" and frames.x and frames.y, "frames invalid or nil in set_animation()!")
    assert(not (length and fps), "cannot play animation with both specified length and specified fps. Only one parameter can be used.")
    local num_frames = math.abs(frames.x-frames.y)
    if length then
        fps = num_frames/length
    elseif not fps then
        fps = self.consts.DEFAULT_FPS
    end
    self.entity:set_animation(frames, fps, 0, loop) --see init.lua for modified ObjRef stuff.
end
function gun_default:clear_animation()
    local loaded = false
    if self.properties.ammo.magazine_only then
        if self.ammo_handler.ammo.loaded_mag ~= "empty" then
            loaded = true
        end
    elseif self.ammo_handler.ammo.total_bullets > 0 then
        loaded = true
    end
    if loaded then
        self.entity:set_animation({x=self.properties.visuals.animations.loaded.x, y=self.properties.visuals.animations.loaded.y}, 0, 0, self.consts.LOOP_IDLE_ANIM)
    else
        self.entity:set_animation({x=self.properties.visuals.animations.empty.x, y=self.properties.visuals.animations.empty.y}, 0, 0, self.consts.LOOP_IDLE_ANIM)
    end
end
function gun_default:update_breathing(dt)
    local breathing_info = {pause=1.4, rate=4.2}
    --we want X to be between 0 and 4.2. Since math.pi is a positive crest, we want X to be above it before it reaches our-
    --"length" (aka rate-pause), thus it will pi/length or pi/(rate-pause) will represent out slope of our control.
    local x = (self.time_since_creation%breathing_info.rate)*math.pi/(breathing_info.rate-breathing_info.pause)
    local scale = self.properties.breathing_scale
    --now if it's above math.pi we know it's in the pause half of the cycle. For smoothness, we cut the sine off early and decay the value non-linearly.
    --not sure why 8/9 is a constant here... I assume it's if it's 8/9 of the way through the cycle. Not going to worry about it.
    if x > math.pi*(8/9) then
        self.offsets.breathing.player_axial.x=self.offsets.breathing.player_axial.x-(self.offsets.breathing.player_axial.x*2*dt)
    else
        self.offsets.breathing.player_axial.x = scale*(math.sin(x))
    end
end

function gun_default:update_sway(dt)
    assert(self.instance, "attempt to call object method from a base class")
    local sprops = self.properties.sway
    for axis, sway in pairs(self.offsets.sway) do
        local sway_vel = self.velocities.sway[axis]
        local ran
        ran = Vec.apply(Vec.new(), function(i,v)
            if i ~= "x" then
                return (math.random()-.5)*2
            end
        end)
        ran.z = 0
        local vel_mul = self.multiplier_coefficient(sprops.hipfire_velocity_multiplier[axis], 1-self.handler.ads_location)
        sway_vel = Vec.normalize(sway_vel+(ran*dt))*sprops.angular_velocity[axis]*vel_mul
        sway=sway+(sway_vel*dt)
        local len_mul = self.multiplier_coefficient(sprops.hipfire_angle_multiplier[axis], 1-self.handler.ads_location)
        if Vec.length(sway) > sprops.max_angle[axis]*len_mul then
            sway=Vec.normalize(sway)*sprops.max_angle[axis]*len_mul
            sway_vel = Vec.new()
        end
        self.offsets.sway[axis] = sway
        self.velocities.sway[axis] = sway_vel
    end
end

function gun_default:update_animation_rotation()
    local current_frame = self.animation_data.current_frame
    local frame1 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
    current_frame = current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION
    local out
    if self.b3d_model.global_frames.rotation then
        if self.b3d_model.global_frames.rotation[frame1] then
            if (not self.b3d_model.global_frames.rotation[frame2]) or (current_frame==frame1) then
                out = vector.copy(self.b3d_model.global_frames.rotation[frame1])
            else --to stop nan
                local ip_ratio = current_frame-frame1
                local vec1 = self.b3d_model.global_frames.rotation[frame1]
                local vec2 = self.b3d_model.global_frames.rotation[frame2]
                out = vec1+((vec1-vec2)*ip_ratio)
            end
        else
            out = vector.copy(self.b3d_model.global_frames.rotation[1])
        end
    else
        out = vector.new()
    end
    self.animation_rotation = out
end

--relative to the gun's entity. Returns left, right vectors.
local out = {arm_left=vector.new(), arm_right=vector.new()}
function gun_default:get_arm_aim_pos()
    local current_frame = self.animation_data.current_frame
    local frame1 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
    current_frame = current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION

    for i, v in pairs(out) do
        if self.b3d_model.global_frames[i] then
            if self.b3d_model.global_frames[i][frame1] then
                if (not self.b3d_model.global_frames[i][frame2]) or (current_frame==frame1) then
                    out[i] = vector.copy(self.b3d_model.global_frames[i][frame1])
                else --to stop nan
                    local ip_ratio = current_frame-frame1
                    local vec1 = self.b3d_model.global_frames[i][frame1]
                    local vec2 = self.b3d_model.global_frames[i][frame2]
                    out[i] = vec1+((vec1-vec2)*ip_ratio)
                end
            else
                out[i]=vector.copy(self.b3d_model.global_frames[i][1])
            end
        else
            out[i] = vector.new()
        end
    end
    return out.arm_left, out.arm_right
    --return vector.copy(self.b3d_model.global_frames.arm_left[1]), vector.copy(self.b3d_model.global_frames.arm_right[1])
end

function gun_default:prepare_deletion()
    assert(self.instance, "attempt to call object method on a class")
    if self:has_entity() then self.entity:remove() end
    if self.sprite_scope then self.sprite_scope:prepare_deletion() end
    if self.crosshair then self.crosshair:prepare_deletion() end
end
local valid_ctrls = { --for validation of controls.
    up=true,
    down=true,
    left=true,
    right=true,
    jump=true,
    aux1=true,
    sneak=true,
    dig=true,
    place=true,
    LMB=true,
    RMB=true,
    zoom=true,
}
gun_default.construct = function(def)
    if def.instance then
        --make some quick checks.
        assert(def.handler, "no player handler object provided")

        --initialize some variables
        def.player = def.handler.player
        local meta = def.itemstack:get_meta()
        def.meta = meta
        local out = {}



        --create ID so we can track switches between weapons
        if meta:get_string("guns4d_id") == "" then
            local id = tostring(Unique_id.generate())
            meta:set_string("guns4d_id", id)
            def.player:set_wielded_item(def.itemstack)
            def.id = id
        else
            def.id = meta:get_string("guns4d_id")
        end

        --unavoidable table instancing
        def.properties = table.fill(def.base_class.properties, def.properties)
        def.particle_spawners = {} --Instantiatable_class only shallow copies. So tables will not change, and thus some need to be initialized.
        def.property_modifiers = {}
        def.total_offset_rotation = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        }
        def.player_rotation = Vec.new()
        --initialize all offsets
       --def.offsets = table.deep_copy(def.base_class.offsets)
        def.offsets = {}
        for offset, tbl in pairs(def.base_class.offsets) do
            def.offsets[offset] = {}
            for i, v in pairs(tbl) do
                if type(v) == "table" and v.x then
                    def.offsets[offset][i] = vector.new()
                else
                    def.offsets[offset][i] = v
                end
            end
        end
        def.animation_rotation = vector.new()
        --def.velocities = table.deep_copy(def.base_class.velocities)
        def.velocities = {}
        for i, tbl in pairs(def.base_class.velocities) do
            def.velocities[i] = {}
            def.velocities[i].gun_axial = Vec.new()
            def.velocities[i].player_axial = Vec.new()
        end
        --properties have been assigned, create necessary objects TODO: completely change this system for defining them.
        if def.properties.sprite_scope then
            def.sprite_scope = def.properties.sprite_scope:new({
                gun = def
            })
        end
        if def.properties.crosshair then
            def.crosshair = def.properties.crosshair:new({
                gun = def
            })
        end
        if def.properties.entity_scope then
            if not def.entity_scope then

            end
        end
        def.ammo_handler = def.properties.ammo_handler:new({
            gun = def
        })
    elseif def.name ~= "__guns4d:default__" then
        local props = def.properties

        --validate controls, done before properties are filled to avoid duplication.
        if props.controls then
            for i, control in pairs(props.controls) do
                if not (i=="on_use") and not (i=="on_secondary_use") then
                    assert(control.conditions, "no conditions provided for control")
                    for _, condition in pairs(control.conditions) do
                        if not valid_ctrls[condition] then
                            assert(false, "invalid key: '"..condition.."'")
                        end
                    end
                end
            end
        end

        --fill in the properties.
        def.properties = table.fill(def.parent_class.properties, props or {})
        def.consts = table.fill(def.parent_class.consts, def.consts or {})
        props = def.properties --have to reinitialize this as the reference is replaced.

        --print(table.tostring(props))
        def.b3d_model = mtul.b3d_reader.read_model(props.visuals.mesh, true)
        def.b3d_model.global_frames = {
            arm_right = {}, --the aim position of the right arm
            arm_left = {}, --the aim position of the left arm
            rotation = {} --rotation of the gun (this is assumed as gun_axial, but that's probably fucked for holo sight alignments)
        }
        --print(table.tostring(def.b3d_model))
        --precalculate keyframe "samples" for intepolation.
        --mildly infuriating that lua just stops short by one (so I have to add one extra) I *think* I get why though.
        local left = mtul.b3d_nodes.get_node_by_name(def.b3d_model, props.visuals.arm_left, true)
        local right = mtul.b3d_nodes.get_node_by_name(def.b3d_model, props.visuals.arm_right, true)
        local main = mtul.b3d_nodes.get_node_by_name(def.b3d_model, props.visuals.root, true)
        for target_frame = 0, def.b3d_model.node.animation.frames+1, def.consts.KEYFRAME_SAMPLE_PRECISION do
            --we need to check that the bone exists first.
            if left then
                table.insert(def.b3d_model.global_frames.arm_left, vector.new(mtul.b3d_nodes.get_node_global_position(def.b3d_model, left, nil, target_frame))/10)
            else
                def.b3d_model.global_frames.arm_left = nil
            end

            if right then
                table.insert(def.b3d_model.global_frames.arm_right, vector.new(mtul.b3d_nodes.get_node_global_position(def.b3d_model, right, nil, target_frame))/10)
            else
                def.b3d_model.global_frames.arm_right = nil
            end

            if main then
                --use -1 as it does not exist and thus will always go to the default resting pose
                local newvec = (mtul.b3d_nodes.get_node_rotation(def.b3d_model, main, nil, -1):inverse())*mtul.b3d_nodes.get_node_rotation(def.b3d_model, main, nil, target_frame)
                newvec = vector.new(newvec:to_euler_angles_unpack())*180/math.pi
                --newvec.z = 0
                table.insert(def.b3d_model.global_frames.rotation, newvec)
                print(target_frame)
                print(dump(vector.new(mtul.b3d_nodes.get_node_rotation(def.b3d_model, main, nil, -1):to_euler_angles_unpack())*180/math.pi))
            end
        end
        -- if it's not a template, then create an item, override some props
        if def.name ~= "__template" then
            assert(rawget(def, "name"), "no name provided in new class")
            assert(rawget(def, "itemstring"), "no itemstring provided in new class")
            assert(not((props.ammo.capacity) and (not props.ammo.magazine_only)), "gun does not accept magazines, but has no set capcity! Please define ammo.capacity")
            assert(minetest.registered_items[def.itemstring], def.itemstring.." : item is not registered, check dependencies.")

            --override methods so control handler can do it's job
            local old_on_use = minetest.registered_items[def.itemstring].on_use
            local old_on_s_use = minetest.registered_items[def.itemstring].on_secondary_use
            --override the item to hook in controls. (on_drop needed)
            minetest.override_item(def.itemstring, {
                on_use = function(itemstack, user, pointed_thing)
                    if old_on_use then
                        old_on_use(itemstack, user, pointed_thing)
                    end
                    Guns4d.players[user:get_player_name()].handler.control_handler:on_use(itemstack, pointed_thing)
                end,
                on_secondary_use = function(itemstack, user, pointed_thing)
                    if old_on_s_use then
                        old_on_s_use(itemstack, user, pointed_thing)
                    end
                    Guns4d.players[user:get_player_name()].handler.control_handler:on_secondary_use(itemstack, pointed_thing)
                end
            })
        end

        def.accepted_bullets = {}
        for _, v in pairs(def.properties.ammo.accepted_bullets) do
            def.accepted_bullets[v] = true
        end
        def.accepted_magazines = {}
        for _, v in pairs(def.properties.ammo.accepted_magazines) do
            def.accepted_magazines[v] = true
        end
        --add gun def to the registered table
        Guns4d.gun.registered[def.name] = def

        --register the visual entity
        minetest.register_entity(def.name.."_visual", {
            initial_properties = {
                visual = "mesh",
                mesh = props.visuals.mesh,
                textures = props.textures,
                glow = 0,
                pointable = false,
                static_save = false,
                backface_culling = props.visuals.backface_culling
            },
            on_step = function(self, dtime)
                local obj = self.object
                if not self.parent_player then obj:remove() return end
                local player = self.parent_player
                local handler = Guns4d.players[player:get_player_name()].handler
                local lua_object = handler.gun
                if not lua_object then obj:remove() return end
                --this is changing the point of rotation if not aiming, this is to make it look less shit.
                local axial_modifier = Vec.new()
                if not handler.control_bools.ads then
                    local pitch = lua_object.total_offset_rotation.player_axial.x+lua_object.player_rotation.x
                    axial_modifier = Vec.new(pitch*(1-lua_object.consts.HIP_PLAYER_GUN_ROT_RATIO),0,0)
                end
                local axial_rot = lua_object.total_offset_rotation.gun_axial+axial_modifier
                --attach to the correct bone, and rotate
                local visibility = true
                if lua_object.sprite_scope and lua_object.sprite_scope.hide_gun and (not (handler.ads_location == 0)) then
                    visibility = false
                end
                if handler.control_bools.ads  then
                    local normal_pos = (props.ads.offset)*10
                    obj:set_attach(player, lua_object.consts.AIMING_BONE, normal_pos, -axial_rot, visibility)
                else
                    local normal_pos = Vec.new(props.hip.offset)*10
                    -- Vec.multiply({x=normal_pos.x, y=normal_pos.z, z=-normal_pos.y}, 10)
                    obj:set_attach(player, lua_object.consts.HIPFIRE_BONE, normal_pos, -axial_rot, visibility)
                end
            end,
        })
    end
end
Guns4d.gun = Instantiatable_class:inherit(gun_default)