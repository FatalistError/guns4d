local Vec = vector
local gun_default = {
    --itemstack = Itemstack
    --gun_entity = ObjRef
    name = "__guns4d:default__",
    itemstring = "",
    registered = {},
    property_modifiers = {},
    properties = {
        hip = { --used by gun entity (attached offset)
            offset = Vec.new(),
        },
        ads = { --used by player_handler, animation handler (eye bone offset from horizontal_offset), gun entity (attached offset)
            offset = Vec.new(),
            horizontal_offset = 0,
            aim_time = 1,
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
            angular_velocity = {
                gun_axial = {x=0, y=0},
                player_axial = {x=0, y=0},
            },
            angular_velocity_bias = {
                gun_axial = {x=1, y=0},
                player_axial = {x=1, y=0},
            },
            target_correction_max_rate = { --the cap for time_since_fire*target_correction_factor
                gun_axial = 1,
                player_axial = 1,
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
        },
        walking_offset = { --used by update_walking() (or something)
            gun_axial = {x=1, y=-1},
            player_axial = {x=1,y=1},
        },
        controls = { --used by control_handler
            __overfill=true, --if present, this table will not be filled in.
            aim = Guns4d.default_controls.aim,
            --fire = Guns4d.default_controls.fire,
            reload = Guns4d.default_controls.reload,
            on_use = Guns4d.default_controls.on_use
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
        animations = { --used by animations handler for idle, and default controls
            empty = {x=0,y=0},
            loaded = {x=1,y=1},
        },
         --used by ammo_handler
        flash_offset = Vec.new(), --used by fire() (for fsx and ray start pos) [RENAME NEEDED]
        firerateRPM = 600, --used by update() and by extent fire() + default controls
        ammo_handler = Ammo_handler
    },
    offsets = {
        player_rotation = Vec.new(),
        --I'll need all three of them, do some precalculation.
        total_offset_rotation = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
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
        },
        breathing = {
            gun_axial = 1,
            player_axial = 1,
        }
    },
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
        HIPFIRE_BONE = "guns3d_hipfire_bone",
        AIMING_BONE = "guns3d_aiming_bone",
        HAS_RECOIL = true,
        HAS_BREATHING = true,
        HAS_SWAY = true,
        HAS_WAG = true,
        INFINITE_AMMO_IN_CREATIVE = true,
        DEFAULT_FPS = 20,
        LOOP_IDLE_ANIM = false
    },
    animation_data = { --where animations data is stored.
        anim_runtime = 0,
        length = 0,
        fps = 0,
        animations_frames = {0,0},
        current_frame = 0,
    },
    particle_spawners = {},
    walking_tick = 0,
    time_since_last_fire = 0,
    time_since_creation = 0,
    rechamber_time = 0,
    muzzle_flash = Guns4d.muzzle_flash
}

function gun_default:attempt_fire()
    assert(self.instance, "attempt to call object method on a class")
    if self.rechamber_time <= 0 then
        local spent_bullet = self.ammo_handler:spend_round()
        if spent_bullet then
            local dir = self.dir
            local pos = self:get_pos()
            --[[print(dump(Guns4d.ammo.registered_bullets))
            print(self.ammo_handler.next_bullet)
            print(Guns4d.ammo.registered_bullets[self.ammo_handler.next_bullet])]]
            local bullet_def = table.fill(Guns4d.ammo.registered_bullets[spent_bullet], {
                player = self.player,
                pos = pos,
                dir = dir,
                gun = self
            })
            Guns4d.bullet_ray:new(bullet_def)
            self:recoil()
            self:muzzle_flash()
            self.rechamber_time = 60/self.properties.firerateRPM
        end
    end
end

function gun_default:recoil()
    assert(self.instance, "attempt to call object method on a class")
    for axis, recoil in pairs(self.velocities.recoil) do
        for _, i in pairs({"x","y"}) do
            recoil[i] = recoil[i] + (self.properties.recoil.angular_velocity[axis][i]*math.rand_sign((self.properties.recoil.angular_velocity_bias[axis][i]/2)+.5))
        end
    end
    self.time_since_last_fire = 0
end
--all of this dir shit needs to be optimized HARD
function gun_default:get_gun_axial_dir()
    assert(self.instance, "attempt to call object method on a class")
    local rotation = self.offsets.total_offset_rotation
    local dir = Vec.new(Vec.rotate({x=0, y=0, z=1}, {y=0, x=rotation.gun_axial.x*math.pi/180, z=0}))
    dir = Vec.rotate(dir, {y=rotation.gun_axial.y*math.pi/180, x=0, z=0})
    return dir
end
function gun_default:get_player_axial_dir(rltv)
    assert(self.instance, "attempt to call object method on a class")
    local player = self.player
    local rotation = self.offsets.total_offset_rotation
    local dir = Vec.new(Vec.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.player_axial.x)*math.pi/180), z=0}))
    dir = Vec.rotate(dir, {y=((rotation.player_axial.y)*math.pi/180), x=0, z=0})
    if not rltv then
        dir = Vec.rotate(dir, {x=self.offsets.player_rotation.x*(math.pi/180),y=0,z=0})
    end
    --[[local hud_pos = Vec.rotate(dir, {x=0,y=self.offsets.player_rotation.y*math.pi/180,z=0})+player:get_pos()+{x=0,y=player:get_properties().eye_height,z=0}+vector.rotate(player:get_eye_offset()/10, {x=0,y=self.offsets.player_rotation.y*math.pi/180,z=0})
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
        local rotation = self.offsets.total_offset_rotation
        local dir = Vec.new(Vec.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.gun_axial.x+rotation.player_axial.x)*math.pi/180), z=0}))
        dir = Vec.rotate(dir, {y=((rotation.gun_axial.y+rotation.player_axial.y)*math.pi/180), x=0, z=0})
        --for it to be relative the the camera, rotation by player look occours post.
        if not rltv then
            dir = Vec.rotate(dir, {x=self.offsets.player_rotation.x*math.pi/180,y=self.offsets.player_rotation.y*math.pi/180,z=0})
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


function gun_default:get_pos(added_pos)
    assert(self.instance, "attempt to call object method on a class")
    added_pos = Vec.new(added_pos)
    local player = self.player
    local handler = self.handler
    local bone_location = Vec.new(handler.model_handler.offsets.arm.right)/10
    local gun_offset = Vec.new(self.properties.hip.offset)
    local player_rotation = Vec.new(self.offsets.player_rotation.x, self.offsets.player_rotation.y, 0)
    if handler.control_bools.ads then
        gun_offset = self.properties.ads.offset
        bone_location = Vec.new(0, handler:get_properties().eye_height, 0)+player:get_eye_offset()/10
    else
        --minetest is really wacky.
        bone_location.x = -bone_location.x
        player_rotation.x = self.offsets.player_rotation.x*self.consts.HIP_PLAYER_GUN_ROT_RATIO
    end
    gun_offset = gun_offset+added_pos
    --dir needs to be rotated twice seperately to avoid weirdness
    local rotation = self.offsets.total_offset_rotation
    local bone_pos = Vec.rotate(bone_location, {x=0, y=player_rotation.y*math.pi/180, z=0})
    local gun_offset = Vec.rotate(Vec.rotate(gun_offset, {x=(rotation.player_axial.x+player_rotation.x)*math.pi/180,y=0,z=0}), {x=0,y=(rotation.player_axial.y+player_rotation.y)*math.pi/180,z=0})
    --[[local hud_pos = bone_pos+gun_offset+handler:get_pos()
    if not false then
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
    end]]
    --world pos, position of bone, offset of gun from bone (with added_pos)
    return bone_pos+gun_offset+handler:get_pos(), bone_pos, gun_offset
end

function gun_default:add_entity()
    assert(self.instance, "attempt to call object method on a class")
    self.entity = minetest.add_entity(self.player:get_pos(), self.name.."_visual")
    local obj = self.entity:get_luaentity()
    obj.parent_player = self.player
    obj:on_step()
end

function gun_default:has_entity()
    assert(self.instance, "attempt to call object method on a class")
    if not self.entity then return false end
    if not self.entity:get_pos() then return false end
    return true
end

--update the gun, da meat and da potatoes
function gun_default:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    if not self:has_entity() then self:add_entity() end
    self.pos = self:get_pos()
    local handler = self.handler
    local look_rotation = {x=handler.look_rotation.x,y=handler.look_rotation.y}
    local total_rot = self.offsets.total_offset_rotation
    local player_rot = self.offsets.player_rotation
    local constant = 6

    --player look rotation. I'm going to keep it real, I don't remember what this equation does.
    if not self.sprite_scope then
        local next_vert_aim = ((player_rot.x+look_rotation.x)/(1+constant*dt))-look_rotation.x
        if math.abs(look_rotation.x-next_vert_aim) > .005 then
            player_rot.x = next_vert_aim
        else
            player_rot.x = -look_rotation.x
        end
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
    self.dir = self:get_dir()
    self.local_dir = self:get_dir(true)
    self.paxial_dir = self:get_player_axial_dir()
    self.local_paxial_dir = self:get_player_axial_dir(true)

    --sprite scope
    if self.properties.sprite_scope then
        self.sprite_scope:update()
    end

    player_rot.y = -handler.look_rotation.y
    local offsets = self.offsets
    total_rot.player_axial = offsets.recoil.player_axial + offsets.walking.player_axial + offsets.sway.player_axial + {x=offsets.breathing.player_axial,y=0,z=0}
    total_rot.gun_axial    = offsets.recoil.gun_axial    + offsets.walking.gun_axial    + offsets.sway.gun_axial
end

function gun_default:update_wag(dt)
    local handler = self.handler
    if handler.walking then
        self.walking_tick = self.walking_tick + (dt*Vec.length(self.player:get_velocity()))
    else
        self.walking_tick = 0
    end
    local walking_offset = self.offsets.walking
    for _, i in pairs({"x","y"}) do
        for axis, _ in pairs(walking_offset) do
            if handler.walking then
                local time = self.walking_tick
                local multiplier = 1
                if i == "x" then
                    multiplier = 2
                end
                walking_offset[axis][i] = math.sin((time/1.6)*math.pi*multiplier)*self.properties.walking_offset[axis][i]
            else
                local old_value = walking_offset[axis][i]
                if (math.abs(walking_offset[axis][i]) > .5 and axis=="player_axial") or (math.abs(walking_offset[axis][i]) > .6 and axis=="gun_axial")  then
                    local multiplier = (walking_offset[axis][i]/math.abs(walking_offset[axis][i]))
                    walking_offset[axis][i] = walking_offset[axis][i]-(dt*2*multiplier)
                elseif axis == "gun_axial" then
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
local animation_data = {
    anim_runtime = 0,
    length = 0,
    fps = 0,
    animations_frames = {0,0},
    current_frame = 0,
}
function gun_default:animation_update(dt)
    local ent = self.entity
    local data = self.animation_data
    local anim_range, frame_speed, frame_blend, frame_loop = ent:get_animation()
    if (not data.animation_frames) or (anim_range.x ~= data.x) or (anim_range.y ~= data.y) then
        data.runtime = 0
        data.animations_frames = false
    elseif data.animation_frames then
        data.runtime = data.runtime + dt
        data.current_frame = math.clamp(data.runtime*data.fps, data.animation_frames.x, data.animation_frames.y)
    end
end
function gun_default:set_animation(frames, length, fps, loop)
    loop = loop or false --why the fuck default is loop? I DONT FUCKIN KNOW
    assert(type(frames)=="table" and frames.x and frames.y, "frames invalid or nil in set_animation()!")
    assert(length or fps, "need either length or FPS for animation")
    assert(not (length and fps), "cannot play animation with both specified length and specified fps. Only one parameter can be used.")
    local num_frames = math.abs(frames.x-frames.y)
    local data = self.animation_data
    if length then
        fps = num_frames/length
    elseif fps then
        length = num_frames/fps
    else
        fps = self.consts.DEFAULT_FPS
        length = num_frames/self.consts.DEFAULT_FPS
    end
    data.runtime = 0
    data.length = length
    self.entity:set_animation(frames, fps, 0, loop)
end
function gun_default:clear_animation()
    local loaded = false
    for i, v in pairs(self.ammo_handler) do
        print(i,v )
    end
    if self.properties.ammo.magazine_only then
        if self.ammo_handler.ammo.loaded_mag ~= "empty" then
            loaded = true
        end
    elseif self.ammo_handler.ammo.total_bullets > 0 then
        loaded = true
    end
    if loaded then
        self.entity:set_animation({x=self.properties.animations.loaded.x, y=self.properties.animations.loaded.y}, 0, 0, self.consts.LOOP_IDLE_ANIM)
    else
        self.entity:set_animation({x=self.properties.animations.empty.x, y=self.properties.animations.empty.y}, 0, 0, self.consts.LOOP_IDLE_ANIM)
    end
    local data = self.animation_data
    data.runtime = 0
    data.length = false
    data.animations_frames = false
end
function gun_default:update_breathing(dt)
    local breathing_info = {pause=1.4, rate=4.2}
    --we want X to be between 0 and 4.2. Since math.pi is a positive crest, we want X to be above it before it reaches our-
    --"length" (aka rate-pause), thus it will pi/length or pi/(rate-pause) will represent out slope of our control.
    local x = (self.time_since_creation%breathing_info.rate)*math.pi/(breathing_info.rate-breathing_info.pause)
    local scale = 1
    --now if it's above math.pi we know it's in the pause half of the cycle. For smoothness, we cut the sine off early and decay the value linearly.
    if x > math.pi*(8/9) then
        self.offsets.breathing.player_axial=self.offsets.breathing.player_axial-(self.offsets.breathing.player_axial*2*dt)
    else
        self.offsets.breathing.player_axial = scale*(math.sin(x))
    end
end

function gun_default:update_sway(dt)
    for axis, sway in pairs(self.offsets.sway) do
        local sway_vel = self.velocities.sway[axis]
        local ran
        ran = Vec.apply(Vec.new(), function(i,v)
            if i ~= "x" then
                return (math.random()-.5)*2
            end
        end)
        ran.z = 0
        sway_vel = Vec.normalize(sway_vel+(ran*dt))*self.properties.sway.angular_velocity[axis]
        sway=sway+(sway_vel*dt)
        if Vec.length(sway) > self.properties.sway.max_angle[axis] then
            sway=Vec.normalize(sway)*self.properties.sway.max_angle[axis]
            sway_vel = Vec.new()
        end
        self.offsets.sway[axis] = sway
        self.velocities.sway[axis] = sway_vel
    end
end

function gun_default:prepare_deletion()
    assert(self.instance, "attempt to call object method on a class")
    if self:has_entity() then self.entity:remove() end
    if self.sprite_scope then self.sprite_scope:prepare_deletion() end
end
--construction for the base gun class
local valid_ctrls = {
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

        --initialize all offsets
       --def.offsets = table.deep_copy(def.base_class.offsets)
        def.offsets = {}
        for i, tbl in pairs(def.base_class.offsets) do
            if (tbl.gun_axial and tbl.player_axial) then
                local ty = type(tbl.gun_axial)
                if (ty=="table") and tbl.gun_axial.x and tbl.gun_axial.y and tbl.gun_axial.z then
                    def.offsets[i] = {}
                    def.offsets[i].gun_axial = Vec.new()
                    def.offsets[i].player_axial = Vec.new()
                else
                    def.offsets[i] = {}
                    def.offsets[i] = table.deep_copy(def.offsets[i])
                end
            elseif tbl.x and tbl.y and tbl.z then
                def.offsets[i] = Vec.new()
            end
        end

        --def.velocities = table.deep_copy(def.base_class.velocities)
        def.velocities = {}
        for i, tbl in pairs(def.base_class.velocities) do
            def.velocities[i] = {}
            if tbl.gun_axial and tbl.player_axial then
                def.velocities[i].gun_axial = Vec.new()
                def.velocities[i].player_axial = Vec.new()
            end
        end
        --properties have been assigned, create necessary objects
        if def.properties.sprite_scope then
            if not def.sprite_scope then
                def.sprite_scope = def.properties.sprite_scope:new({
                    gun = def
                })
            end
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
        print(table.tostring(def.properties))
        def.consts = table.fill(def.parent_class.consts, def.consts or {})
        props = def.properties --have to reinitialize this as the reference is replaced.

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
                mesh = props.mesh,
                textures = props.textures,
                glow = 0,
                pointable = false,
                static_save = false,
            },
            on_step = function(self, dtime)
                local name = string.gsub(self.name, "_visual", "")
                local obj = self.object
                if not self.parent_player then obj:remove() return end
                local player = self.parent_player
                local handler = Guns4d.players[player:get_player_name()].handler
                local lua_object = handler.gun
                if not lua_object then obj:remove() return end
                --this is changing the point of rotation if not aiming, this is to make it look less shit.
                local axial_modifier = Vec.new()
                if not handler.control_bools.ads then
                    local pitch = lua_object.offsets.total_offset_rotation.player_axial.x+lua_object.offsets.player_rotation.x
                    axial_modifier = Vec.new(pitch*(1-lua_object.consts.HIP_PLAYER_GUN_ROT_RATIO),0,0)
                end
                local axial_rot = lua_object.offsets.total_offset_rotation.gun_axial+axial_modifier
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
            end
        })
    end
end
Guns4d.gun = Instantiatable_class:inherit(gun_default)