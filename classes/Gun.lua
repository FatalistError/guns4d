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
            --"burst",
            --"auto"
        },
        firemode_inventory_overlays = {
            single = "inventory_overlay_single.png",
            auto =  "inventory_overlay_auto.png",
            burst =  "inventory_overlay_burst.png",
            safe = "inventory_overlay_safe.png"
        },
        infinite_inventory_overlay = "inventory_overlay_inf_ammo.png",
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
        control_actions = { --used by control_handler
            __overfill=true, --this table will not be filled in.
            aim = Guns4d.default_controls.aim,
            auto = Guns4d.default_controls.auto,
            reload = Guns4d.default_controls.reload,
            on_use = Guns4d.default_controls.on_use,
            firemode = Guns4d.default_controls.firemode
        },
        charging = { --how the gun "cocks"
            require_draw_on_swap = true,
            bolt_charge_mode = "none", --"none"-chamber is always full, "catch"-when fired to dry bolt will not need to be charged after reload, "no_catch" bolt will always need to be charged after reload.
            default_draw_time = 1,
        },
        reload = { --used by defualt controls. Still provides usefulness elsewhere.
            __overfill=true,
            --{type="unload_mag", time=1, anim="unload_mag", interupt="to_ground", hold = true, sound = {sound = "load magazine", pitch = {min=.9, max=1.1}}},
            --{type="load", time=1, anim="load"}
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
            magazine = "magazine",
            arm_right = "right_aimpoint",
            arm_left = "left_aimpoint",
            animations = { --used by animations handler for idle, and default controls
                empty = {x=0,y=0},
                loaded = {x=1,y=1},
            },
        },
        sounds = { --this does not contain reload sound effects.
            release_bolt = {
                __overfill=true,
                sound = "ar_release_bolt",
                max_hear_distance = 5,
                pitch = {
                    min = .95,
                    max = 1.05
                },
                gain = {
                    min = .9,
                    max = 1
                }
            },
            fire = {
                {
                    __overfill=true,
                    sound = "ar_firing",
                    max_hear_distance = 40, --far min_hear_distance is also this.
                    pitch = {
                        min = .95,
                        max = 1.05
                    },
                    gain = {
                        min = .9,
                        max = 1
                    }
                },
                {
                    __overfill=true,
                    sound = "ar_firing_far",
                    min_hear_distance = 40,
                    max_hear_distance = 600,
                    pitch = {
                        min = .95,
                        max = 1.05
                    },
                    gain = {
                        min = .9,
                        max = 1
                    }
                }
            },
        },
        initial_vertical_rotation = -60,
        --inventory_image
        --inventory_image_empty
         --used by ammo_handler
        flash_offset = Vec.new(), --used by fire() (for fsx and ray start pos) [RENAME NEEDED]
        firerateRPM = 600, --used by update() and by extent fire() + default controls
        burst = 3, --default burst length
        ammo_handler = Ammo_handler
    },
    offsets = {
        recoil = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
            --move_dynamic_crosshair = false, this would make the dynamic crosshair move instead of get larger
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
    --player_rotation = Vec.new(),
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
        DEFAULT_MAX_HEAR_DISTANCE = 10,
        DEFAULT_FPS = 60,
        WAG_DECAY = 1, --divisions per second
        HAS_RECOIL = true,
        HAS_BREATHING = true,
        HAS_SWAY = true,
        HAS_WAG = true,
        HAS_GUN_AXIAL_OFFSETS = true,
        ANIMATIONS_OFFSET_AIM = false,
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
    bolt_charged = false,
    particle_spawners = {},
    current_firemode = 1,
    walking_tick = 0,
    time_since_last_fire = 0,
    time_since_creation = 0,
    rechamber_time = 0,
    burst_queue = 0,
    muzzle_flash = Guns4d.effects.muzzle_flash
}
--I dont remember why I made this, used it though lmao
function gun_default.multiplier_coefficient(multiplier, ratio)
    return 1+((multiplier*ratio)-ratio)
end
function gun_default:draw()
    assert(self.instance, "attempt to call object method on a class")
    local props = self.properties
    if props.visuals.animations.draw then
        self:set_animation(props.visuals.animations.draw, props.charging.default_draw_time)
    end
    self.ammo_handler:chamber_round()
    self.rechamber_time = props.charging.default_draw_time
end
--update gun, the main function.
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

    if self.burst_queue > 0 then self:update_burstfire() end
    --update some vectors
    if self.consts.HAS_SWAY then self:update_sway(dt) end
    if self.consts.HAS_RECOIL then self:update_recoil(dt) end
    if self.consts.HAS_BREATHING then self:update_breathing(dt) end
    if self.consts.HAS_WAG then self:update_wag(dt) end

    self:update_animation(dt)
    self.dir = self:get_dir()
    self.local_dir = self:get_dir(true)
    self.paxial_dir = self:get_player_axial_dir()
    self.local_paxial_dir = self:get_player_axial_dir(true)
    self.pos = self:get_pos()+self.handler:get_pos()

    if self.properties.sprite_scope then
        self.sprite_scope:update()
    end
    if self.properties.crosshair then
        self.crosshair:update()
    end

    --automatically cock if uncocked.
    local ammo = self.ammo_handler.ammo
    --[[if ammo.total_bullets and (ammo.total_bullets > 0 and ammo.next_bullet == "empty") then
        self:charge()
    end]]
    --print(dump(self.ammo_handler.ammo.next_bullet))

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

function gun_default:update_burstfire()
    if self.rechamber_time <= 0 then
        local success = self:attempt_fire()
        if not success then
            self.burst_queue = 0
        else
            self.burst_queue = self.burst_queue - 1
        end
    end
end
function gun_default:cycle_firemodes()
    self.current_firemode = ((self.current_firemode)%(#self.properties.firemodes))+1
    self.meta:set_int("guns4d_firemode", self.current_firemode)
    self:update_image_and_text_meta()
    self.player:set_wielded_item(self.itemstack)
end
--remember to set_wielded_item to self.itemstack! otherwise these changes will not apply!
function gun_default:update_image_and_text_meta(meta)
    meta = meta or self.meta
    local ammo = self.ammo_handler.ammo
    --set the counter
    if ammo.total_bullets == 0 then
        meta:set_string("count_meta", Guns4d.config.empty_symbol)
    else
        if Guns4d.config.show_gun_inv_ammo_count then
            meta:set_string("count_meta", tostring(ammo.total_bullets))
        else
            meta:set_string("count_meta", "F")
        end
    end
    --pick the image
    local image = self.properties.inventory_image
    if (ammo.total_bullets > 0) and not ammo.magazine_psuedo_empty then
        image = self.properties.inventory_image
    elseif self.properties.inventory_image_magless and ( (ammo.loaded_mag == "empty") or (ammo.loaded_mag == "") or ammo.magazine_psuedo_empty) then
        image = self.properties.inventory_image_magless
    elseif self.properties.inventory_image_empty then
        image = self.properties.inventory_image_empty
    end
    --add the firemode overlay to the image
    if #self.properties.firemodes > 1 and self.properties.firemode_inventory_overlays[self.properties.firemodes[self.current_firemode]] then
        image = image.."^"..self.properties.firemode_inventory_overlays[self.properties.firemodes[self.current_firemode]]
    end
    if self.handler.infinite_ammo then
        image = image.."^"..self.properties.infinite_inventory_overlay
    end
    meta:set_string("inventory_image", image)
end
function gun_default:attempt_fire()
    assert(self.instance, "attempt to call object method on a class")
    if self.rechamber_time <= 0 and not self.ammo_handler.ammo.magazine_psuedo_empty then
        local spent_bullet = self.ammo_handler:spend_round()
        if spent_bullet and spent_bullet ~= "empty" then
            local dir = self.dir
            local pos = self.pos

            if not Guns4d.ammo.registered_bullets[spent_bullet] then
                minetest.log("error", "unregistered bullet itemstring"..tostring(spent_bullet)..", could not fire gun (player:"..self.player:get_player_name()..")");
                return false
            end

            local bullet_def = Guns4d.table.fill(Guns4d.ammo.registered_bullets[spent_bullet], {
                player = self.player,
                --we don't want it to be doing fuckshit and letting players shoot through walls.
                pos = pos-((self.handler.control_handler.ads and dir*self.properties.ads.offset.z) or dir*self.properties.hip.offset.z),
                dir = dir,
                gun = self
            })
            Guns4d.bullet_ray:new(bullet_def)
            if self.properties.visuals.animations.fire then
                self:set_animation(self.properties.visuals.animations.fire, nil, false)
            end
            self:recoil()
            self:muzzle_flash()

            print(dump(self.properties.sounds.fire))
            local fire_sound = Guns4d.table.deep_copy(self.properties.sounds.fire) --important that we copy because play_sounds modifies it.
            fire_sound.pos = self.pos
            Guns4d.play_sounds(fire_sound)

            self.rechamber_time = 60/self.properties.firerateRPM
            return true
        end
    end
end
local function rand_sign(b)
    b = b or .5
    local int = 1
    if math.random() > b then int=-1 end
    return int
end
function gun_default:recoil()
    assert(self.instance, "attempt to call object method on a class")
    local rprops = self.properties.recoil
    for axis, recoil in pairs(self.velocities.recoil) do
        for _, i in pairs({"x","y"}) do
            recoil[i] = recoil[i] + (rprops.angular_velocity[axis][i]
                *rand_sign((rprops.bias[axis][i]/2)+.5))
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
        if (self.properties.sprite_scope and handler.control_handler.ads) or (self.properties.crosshair and not handler.control_handler.ads) then
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
        if (self.properties.sprite_scope and handler.control_handler.ads) or (self.properties.crosshair and not handler.control_handler.ads) then
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
    if handler.control_handler.ads then
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
            local recoil_vel = Guns4d.math.clamp(self.velocities.recoil[axis][i],-self.properties.recoil.angular_velocity_max[axis],self.properties.recoil.angular_velocity_max[axis])
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
                correction_value = Guns4d.math.clamp(math.abs(correction_value), 0, self.properties.recoil.target_correction_max_rate[axis])
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
    data.current_frame = Guns4d.math.clamp(data.current_frame+(dt*data.fps), data.frames.x, data.frames.y)
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
    local current_frame = self.animation_data.current_frame+self.consts.KEYFRAME_SAMPLE_PRECISION
    local frame1 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
    current_frame = current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION
    local out
    if self.b3d_model.global_frames.rotation then
        if self.b3d_model.global_frames.rotation[frame1] then
            if (not self.b3d_model.global_frames.rotation[frame2]) or (current_frame==frame1) then
                out = vector.new(self.b3d_model.global_frames.rotation[frame1]:to_euler_angles_unpack())*180/math.pi
                --print("rawsent")
            else --to stop nan
                local ip_ratio = current_frame-frame1
                local vec1 = self.b3d_model.global_frames.rotation[frame1]
                local vec2 = self.b3d_model.global_frames.rotation[frame2]
                out = vector.new(vec1:slerp(vec2, ip_ratio):to_euler_angles_unpack())*180/math.pi
                --out = vec1+((vec1-vec2)*ip_ratio) --they're euler angles... actually I wouldnt think this works, but it's good enough for my purposes.
                --print("interpolated")
            end
        else
            out = vector.copy(self.b3d_model.global_frames.rotation[1])
        end
        --print(frame1, frame2, current_frame, dump(out))
    else
        out = vector.new()
    end
    self.animation_rotation = out
end

--relative to the gun's entity. Returns left, right vectors.
local out = {arm_left=vector.new(), arm_right=vector.new()}
function gun_default:get_arm_aim_pos()
    local current_frame = self.animation_data.current_frame+1
    local frame1 = (math.floor(current_frame)/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = (math.floor(current_frame)/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
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
    self.released = true
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
        --create ID so we can track switches between weapons, also get some other data.
        if meta:get_string("guns4d_id") == "" then
            local id = tostring(Guns4d.unique_id.generate())
            meta:set_string("guns4d_id", id)
            def.player:set_wielded_item(def.itemstack)
            def.id = id
            def.current_firemode = 1
            meta:set_int("guns4d_firemode", 1)
        else
            def.id = meta:get_string("guns4d_id")
            def.current_firemode = meta:get_int("guns4d_firemode")
        end
        def.ammo_handler = def.properties.ammo_handler:new({ --initialize ammo handler from gun and gun metadata.
            gun = def
        })
        local ammo = def.ammo_handler.ammo
        if def.properties.require_draw_on_swap then
            ammo.next_bullet = "empty"
        end
        minetest.after(0, function() if ammo.total_bullets > 0 then def:draw() end end)
        def:update_image_and_text_meta() --has to be called manually in post as ammo_handler would not exist yet.
        def.player:set_wielded_item(def.itemstack)
        --unavoidable table instancing
        def.properties = Guns4d.table.fill(def.base_class.properties, def.properties)
        def.particle_spawners = {} --Instantiatable_class only shallow copies. So tables will not change, and thus some need to be initialized.
        def.property_modifiers = {}
        def.total_offset_rotation = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        }
        def.player_rotation = Vec.new(def.properties.initial_vertical_rotation,0,0)
        --initialize all offsets
       --def.offsets = Guns4d.table.deep_copy(def.base_class.offsets)
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
        --def.velocities = Guns4d.table.deep_copy(def.base_class.velocities)
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
        if def.custom_construct then def:custom_construct() end
    elseif def.name ~= "__guns4d:default__" then
        local props = def.properties

        --validate controls, done before properties are filled to avoid duplication.
        if props.control_actions then
            for i, control in pairs(props.control_actions) do
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
        def.properties = Guns4d.table.fill(def.parent_class.properties, props or {})
        def.consts = Guns4d.table.fill(def.parent_class.consts, def.consts or {})
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
        local left = mtul.b3d_nodes.get_node_by_name(def.b3d_model, props.visuals.arm_left, true)
        local right = mtul.b3d_nodes.get_node_by_name(def.b3d_model, props.visuals.arm_right, true)
        local main = mtul.b3d_nodes.get_node_by_name(def.b3d_model, props.visuals.root, true)
        --we add 2 because we have to add 1 for the loop to make it there if it's a float val, and MTUL uses a system where frame 0 is 1
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
                --we compose it by the inverse because we need to get the global CHANGE in rotation for the animation rotation offset. I really need to comment more often
                local newvec = (mtul.b3d_nodes.get_node_rotation(def.b3d_model, main, nil, -1):inverse())*mtul.b3d_nodes.get_node_rotation(def.b3d_model, main, nil, target_frame)
                --used to use euler
                table.insert(def.b3d_model.global_frames.rotation, newvec)
            end
        end
        --[[if main then
            local quat = mtul.math.quat.new(main.keys[1].rotation)
            print(dump(main.keys[1]), vector.new(quat:to_euler_angles_unpack(quat)))
        end
        for i, v in pairs(def.b3d_model.global_frames.rotation) do
            print(i, dump(vector.new(v:to_euler_angles_unpack())*180/math.pi))
        end]]
       --print()
        -- if it's not a template, then create an item, override some props
        if def.name ~= "__template" then
            assert(def.itemstring, "no itemstring provided. Cannot create a gun without an associated itemstring.")
            local item_def = minetest.registered_items[def.itemstring]
            assert(rawget(def, "name"), "no name provided in new class")
            assert(rawget(def, "itemstring"), "no itemstring provided in new class")
            assert(not((props.ammo.capacity) and (not props.ammo.magazine_only)), "gun does not accept magazines, but has no set capcity! Please define ammo.capacity")
            assert(item_def, def.itemstring.." : item is not registered.")

            --override methods so control handler can do it's job
            local old_on_use = item_def.on_use
            local old_on_s_use = item_def.on_secondary_use
            def.properties.inventory_image = item_def.inventory_image
            --override the item to hook in controls. (on_drop needed)
            minetest.override_item(def.itemstring, {
                on_use = function(itemstack, user, pointed_thing)
                    if old_on_use then
                        old_on_use(itemstack, user, pointed_thing)
                    end
                    Guns4d.players[user:get_player_name()].control_handler:on_use(itemstack, pointed_thing)
                end,
                on_secondary_use = function(itemstack, user, pointed_thing)
                    if old_on_s_use then
                        old_on_s_use(itemstack, user, pointed_thing)
                    end
                    Guns4d.players[user:get_player_name()].control_handler:on_secondary_use(itemstack, pointed_thing)
                end
            })
        end

        --TODO this may need to be renamed and put in constructor for instances (modifications could later change ammo types.)
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
                local handler = Guns4d.players[player:get_player_name()]
                local lua_object = handler.gun
                if not lua_object then obj:remove() return end
                --this is changing the point of rotation if not aiming, this is to make it look less shit.
                local axial_modifier = Vec.new()
                if not handler.control_handler.ads then
                    local pitch = lua_object.total_offset_rotation.player_axial.x+lua_object.player_rotation.x
                    axial_modifier = Vec.new(pitch*(1-lua_object.consts.HIP_PLAYER_GUN_ROT_RATIO),0,0)
                end
                local axial_rot = lua_object.total_offset_rotation.gun_axial+axial_modifier
                --attach to the correct bone, and rotate
                local visibility = true
                if lua_object.sprite_scope and lua_object.sprite_scope.hide_gun and (not (handler.ads_location == 0)) then
                    visibility = false
                end
                if handler.control_handler.ads  then
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