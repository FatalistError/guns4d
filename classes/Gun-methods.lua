--@within Gun.gun

local gun_default = Guns4d.gun
--I dont remember why I made this, used it though lmao
function gun_default.multiplier_coefficient(multiplier, ratio)
    return 1+((multiplier*ratio)-ratio)
end
function gun_default:draw()
    assert(self.instance, "attempt to call object method on a class")
    local props = self.properties
    if props.visuals.animations[props.charging.draw_animation] then
        self:set_animation(props.visuals.animations[props.charging.draw_animation], props.charging.draw_time)
    end
    if props.sounds[props.charging.draw_sound] then
        local sounds = Guns4d.table.deep_copy(props.sounds[props.charging.draw_sound])
        self:play_sounds(sounds)
    end
    self.ammo_handler:chamber_round()
    self.rechamber_time = props.charging.draw_time
end

--- The entry method for the update of the gun
--
-- calls virtually all functions that begin with `update` once. Also updates subclass
--
-- @tparam float dt
function gun_default:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    if not self:has_entity() then self:add_entity(); self:clear_animation() end
    local handler = self.handler

    --player look rotation. I'm going to keep it real, I don't remember what this math does. Player handler just stores the player's rotation from MT in degrees, which is for some reason inverted

    --it's set up like this so that if the gun is fired on auto and the RPM is very fast (faster then globalstep) we know how many rounds to let off.
    if self.rechamber_time > 0 then
        self.rechamber_time = self.rechamber_time - dt
    end

    self.time_since_creation = self.time_since_creation + dt
    self.time_since_last_fire = self.time_since_last_fire + dt

    if self.burst_queue > 0 then self:update_burstfire() end
    --update some vectors
    self:update_look_offsets(dt)
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
    self:update_entity()

    if self.properties.sprite_scope then
        self.sprite_scope:update()
    end
    if self.properties.crosshair then
        self.crosshair:update()
    end
    local total_offset = self.total_offsets
    --axis rotations
    total_offset.player_axial.x = 0; total_offset.player_axial.y = 0
    total_offset.gun_axial.x = 0; total_offset.gun_axial.y = 0
    --translations
    total_offset.player_trans.x = 0; total_offset.player_trans.y = 0; total_offset.player_trans.z = 0
    total_offset.gun_trans.x = 0; total_offset.gun_trans.y = 0; total_offset.gun_trans.z = 0
    total_offset.look_trans.x = 0; total_offset.look_trans.y = 0; total_offset.look_trans.z = 0
    --this doesnt work.
    for type, _ in pairs(total_offset) do
        for i, offset in pairs(self.offsets) do
            if offset[type] and (self.consts.HAS_GUN_AXIAL_OFFSETS or type~="gun_axial") then
                total_offset[type] = total_offset[type]+offset[type]
            end
        end
    end
end

--- Update and fire the queued weapon burst
function gun_default:update_burstfire()
    if self.rechamber_time <= 0 then
        while true do
            local success = self:attempt_fire()
            if success then
                self.burst_queue = self.burst_queue - 1
            else
                if not self.ammo_handler:can_spend_round() then
                    self.burst_queue = 0
                end
                break
            end
        end
    end
end

--- cycles to the next firemode of the weapon
function gun_default:cycle_firemodes()
    --cannot get length using length operator because it's a proxy table
    local length = 0
    for i, v in ipairs(self.properties.firemodes) do
        length = length+1
    end
    self.current_firemode = ((self.current_firemode)%(length))+1

    self.meta:set_int("guns4d_firemode", self.current_firemode)
    self:update_image_and_text_meta()
    self.player:set_wielded_item(self.itemstack)
end

--- update the inventory information of the gun
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
    local firemodes = 0
    for i, v in pairs(self.properties.firemodes) do
        firemodes = firemodes+1
    end
    if firemodes > 1 and self.properties.firemode_inventory_overlays[self.properties.firemodes[self.current_firemode]] then
        image = image.."^"..self.properties.firemode_inventory_overlays[self.properties.firemodes[self.current_firemode]]
    end
    if self.handler.infinite_ammo then
        image = image.."^"..self.properties.infinite_inventory_overlay
    end
    meta:set_string("inventory_image", image)
end

--- attempt to fire the gun
function gun_default:attempt_fire()
    assert(self.instance, "attempt to call object method on a class")
    local props = self.properties
    --check if there could have been another round fired between steps.
    if ( (self.rechamber_time + (60/props.firerateRPM) < 0) or (self.rechamber_time <= 0) ) and (not self.ammo_handler.ammo.magazine_psuedo_empty) then
        local spent_bullet = self.ammo_handler:spend_round()
        if spent_bullet and spent_bullet ~= "empty" then
            local dir = self.dir
            local pos = self.pos

            if not Guns4d.ammo.registered_bullets[spent_bullet] then
                minetest.log("error", "unregistered bullet itemstring"..tostring(spent_bullet)..", could not fire gun (player:"..self.player:get_player_name()..")");
                return false
            end

            --begin subtasks
            local bullet_def = Guns4d.table.fill(Guns4d.ammo.registered_bullets[spent_bullet], {
                player = self.player,
                --we don't want it to be doing fuckshit and letting players shoot through walls.
                pos = pos-((self.handler.control_handler.ads and dir*props.ads.offset.z) or dir*props.hip.offset.z),
                --dir = dir, this is now collected directly by calling get_dir so pellets and spread can be handled by the bullet_ray instance.
                gun = self
            })
            Guns4d.bullet_ray:new(bullet_def)
            if props.visuals.animations.fire then
                self:set_animation(props.visuals.animations.fire, nil, false)
            end
            self:recoil()
            self:muzzle_flash()
            --[[if props.durability.shot_per_wear then
               self:damage()
            end]]
            --print(dump(self.properties.sounds.fire))
            local fire_sound = Guns4d.table.deep_copy(props.sounds.fire) --important that we copy because play_sounds modifies it.
            fire_sound.pos = self.pos
            self:play_sounds(fire_sound)

            --this should handle the firerate being faster than dt
            self.time_since_last_fire = 0
            self.rechamber_time = self.rechamber_time + (60/props.firerateRPM)
            return true
        end
    end
    return false
end
--[[function gun_default:damage()
    assert(self.instance, "attempt to call object method on a class")
    self.itemstack:set_wear(self.itemstack:get_wear()-self.properties.durability.shot_per_wear)
    self.player:set_wielded_item(self.itemstack)
end]]
local function rand_sign(b)
    b = b or .5
    local int = 1
    if math.random() > b then int=-1 end
    return int
end

--- simulate recoil by adding to the recoil velocity (called by attempt_fire)
function gun_default:recoil()
    assert(self.instance, "attempt to call object method on a class")
    local rprops = self.properties.recoil
    for axis, recoil in pairs(self.velocities.recoil) do
        for _, i in pairs({"x","y"}) do
            recoil[i] = recoil[i] + (rprops.angular_velocity[axis][i]
                *rand_sign((rprops.bias[axis][i]/2)+.5))
                *self.multiplier_coefficient(rprops.hipfire_multiplier[axis], 1-self.control_handler.ads_location)
            --set original velocity
            self.velocities.init_recoil[axis][i] = recoil[i]
        end
        local length = math.sqrt(recoil.x^2+recoil.y^2)
        if length > rprops.angular_velocity_max[axis] then
            local co = rprops.angular_velocity_max[axis]/length
            recoil.x = recoil.x*co
            recoil.y = recoil.y*co
        end
    end
end

--- update the offsets of the player's look created by the gun
function gun_default:update_look_offsets(dt)
    assert(self.instance, "attempt to call object method on a class")
    local handler = self.handler
    local look_rotation = handler.look_rotation --remember that this is in counterclock-wise rotation. For 4dguns we use clockwise so it makes a bit more sense for recoil. So it needs to be inverted.
    local player_rot = self.player_rotation
    player_rot.y = -handler.look_rotation.y
    local rot_factor = Guns4d.config.vertical_rotation_factor*dt
    rot_factor = rot_factor
    local next_vert_aim = ((player_rot.x-look_rotation.x)/(1+rot_factor))+look_rotation.x --difference divided by a value and then added back to the original
    if math.abs(look_rotation.x-next_vert_aim) > .005 then
        player_rot.x = next_vert_aim
    else
        player_rot.x = look_rotation.x
    end

    local props = self.properties
    local hip = props.hip
    local ads = props.ads
    if not handler.control_handler.ads then
        --hipfire rotation offsets
        local pitch = self.total_offsets.player_axial.x+player_rot.x
        local gun_axial = self.offsets.look.gun_axial
        local offset = handler.look_rotation.x-player_rot.x
        gun_axial.x = Guns4d.math.clamp(offset, 0, 15*(offset/math.abs(offset)))
        gun_axial.x = gun_axial.x+(pitch*(1-hip.axis_rotation_ratio))
        self.offsets.look.player_axial.x = -pitch*(1-hip.axis_rotation_ratio)
        self.offsets.look.look_trans.x = 0
    else
        self.offsets.look.gun_axial.x = 0
        self.offsets.look.player_axial.x = 0
    end
    local location = Guns4d.math.clamp(Guns4d.math.smooth_ratio(self.control_handler.ads_location)*2, 0, 1)
    self.offsets.look.look_trans.x = ads.horizontal_offset*location
    local fwd_offset = 0
    if look_rotation.x < 0 then --minetest's pitch is inverted, checking here if it's above horizon.
        fwd_offset = math.abs(math.sin(look_rotation.x*math.pi/180))*props.ads.offset.z*location
    end
    self.offsets.look.player_trans.z = fwd_offset
    self.offsets.look.look_trans.z = fwd_offset
end
--============================================== positional info =====================================
--not going to touch any of this in this because the definitions will change in the next push from the main repo

function gun_default:get_gun_axial_dir()
    assert(self.instance, "attempt to call object method on a class")
    local rotation = self.total_offsets
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=rotation.gun_axial.x*math.pi/180, z=0}))
    dir = vector.rotate(dir, {y=rotation.gun_axial.y*math.pi/180, x=0, z=0})
    return dir
end
function gun_default:get_player_axial_dir(rltv)
    assert(self.instance, "attempt to call object method on a class")
    local handler = self.handler
    local rotation = self.total_offsets
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.player_axial.x)*math.pi/180), z=0}))
    dir = vector.rotate(dir, {y=((rotation.player_axial.y)*math.pi/180), x=0, z=0})
    if not rltv then
        if (self.properties.sprite_scope and handler.control_handler.ads) or (self.properties.crosshair and not handler.control_handler.ads) then
            --we need the head rotation in either of these cases, as that's what they're showing.
            dir = vector.rotate(dir, {x=handler.look_rotation.x*math.pi/180,y=-handler.look_rotation.y*math.pi/180,z=0})
        else
            dir = vector.rotate(dir, {x=self.player_rotation.x*math.pi/180,y=self.player_rotation.y*math.pi/180,z=0})
        end
    end
    return dir
end
--this needs to be optimized because it may be called frequently...
function gun_default:get_dir(rltv, offset_x, offset_y)
    assert(self.instance, "attempt to call object method on a class")
    local rotation = self.total_offsets
    local handler = self.handler
    --rotate x and then y.
    --used symbolab.com to precalculate the rotation matrices to save on performance since spread for pellets has to run this.
    local p = -(rotation.gun_axial.x+rotation.player_axial.x+(offset_x or 0))*math.pi/180
    local y = -(rotation.gun_axial.y+rotation.player_axial.y+(offset_y or 0))*math.pi/180
    local Cy = math.cos(y)
    local Sy = math.sin(y)
    local Cp = math.cos(p)
    local Sp = math.sin(p)
    local dir = {
        x=Sy*Cy,
        y=-Sp,
        z=Cy*Cp
    }
    if not rltv then
        p = -self.player_rotation.x*math.pi/180
        y = -self.player_rotation.y*math.pi/180
        Cy = math.cos(y)
        Sy = math.sin(y)
        Cp = math.cos(p)
        Sp = math.sin(p)
        dir = vector.new(
            (Cy*dir.x)+(Sy*Sp*dir.y)+(Sy*Cp*dir.z),
            (dir.y*Cp)-(dir.z*Sp),
            (-dir.x*Sy)+(dir.y*Sp*Cy)+(dir.z*Cy*Cp)
        )
    else
        dir = vector.new(dir)
    end
    return dir
end
--Should probably optimize this at some point.
local zero = vector.zero()

--- get the global position of the gun. This is customized to rely on the assumption that there are 3-4 main rotations and 2-3 translations. If the behavior of the bones are changed this method may not work
-- @tparam vec3 offset_pos
-- @tparam bool whether it is relative to the player entity's rotation
-- @treturn vec3 position of gun (in global or local orientation) relative to the player's position
function gun_default:get_pos(offset_pos, relative, ads, ignore_translations)
    assert(self.instance, "attempt to call object method on a class")
    local player = self.player
    local handler = self.handler
    local bone_location = handler.player_model_handler.gun_bone_location
    local gun_translation = self.gun_translation
    if offset_pos then
        gun_translation = gun_translation+offset_pos
    end
    if gun_translation==self.gun_translation then gun_translation = vector.new(gun_translation) end
    --dir needs to be rotated twice seperately to avoid weirdness
    local pos
    if not relative then
        pos = vector.rotate(bone_location, {x=0, y=-handler.look_rotation.y*math.pi/180, z=0})
        pos = pos+vector.rotate(gun_translation, vector.dir_to_rotation(self.paxial_dir))
    else
        pos = vector.rotate(gun_translation, vector.dir_to_rotation(self.local_paxial_dir)+{x=self.player_rotation.x*math.pi/180,y=0,z=0})+bone_location
    end
    --[[local hud_pos
    if relative then
        hud_pos = vector.rotate(pos, {x=0,y=player:get_look_horizontal(),z=0})+handler:get_pos()
    else
        hud_pos = pos+handler:get_pos()
    end]]
    --if minetest.get_player_by_name("fatal2") then
        --[[local hud = minetest.get_player_by_name("fatal2"):hud_add({
            hud_elem_type = "image_waypoint",
            text = "muzzle_flash2.png",
            world_pos =  hud_pos,
            scale = {x=10, y=10},
            alignment = {x=0,y=0},
            offset = {x=0,y=0},
        })
        minetest.after(0, function(hud)
            minetest.get_player_by_name("fatal2"):hud_remove(hud)
        end, hud)]]
    --end

    --world pos, position of bone, offset of gun from bone (with added_pos)
    return pos
end


--=============================================== ENTITY ======================================================

--- adds the gun entity
function gun_default:add_entity()
    assert(self.instance, "attempt to call object method on a class")
    self.entity = minetest.add_entity(self.player:get_pos(), "guns4d:gun_entity")
    local props = self.properties
    self.entity:set_properties({
        mesh = props.visuals.mesh,
        textures = props.visuals.textures,
        backface_culling = props.visuals.backface_culling,
        visual_size = {x=10*props.visuals.scale,y=10*props.visuals.scale,z=10*props.visuals.scale}
    })
    Guns4d.gun_by_ObjRef[self.entity] = self
    --obj:on_step()
    --self:update_entity()
end

local mat4 = leef.math.mat4
local tmp_mat4_rot = mat4.identity()
local ip_time = Guns4d.config.gun_axial_interpolation_time
local ip_time2 = Guns4d.config.translation_interpolation_time
--- updates the gun's entity
function gun_default:update_entity()
    local obj = self.entity
    local player = self.player
    local axial_rot = self.total_offsets.gun_axial
    local handler = self.handler
    local props = self.properties
    --attach to the correct bone, and rotate
    local visibility = true
    if self.sprite_scope and self.sprite_scope.hide_gun and (not (self.control_handler.ads_location == 0)) then
        visibility = false
    end
    --Irrlicht uses counterclockwise but we use clockwise.
    local ads = props.ads.offset
    local hip = props.hip.offset
    local offset = self.total_offsets.gun_trans
    local ip = Guns4d.math.smooth_ratio(Guns4d.math.clamp(handler.control_handler.ads_location*2,0,1))
    local ip_inv = 1-ip

    local pos = self.gun_translation --entity directly dictates the translation of the gun
    pos.x = (ads.x*ip)+(hip.x*ip_inv)+offset.x
    pos.y = (ads.y*ip)+(hip.y*ip_inv)+offset.y
    pos.z = (ads.z*ip)+(hip.z*ip_inv)+offset.z
    local scale = self.properties.visuals.scale

    --some complicated math to get client interpolation to work. It doesn't really account for the root bone having an (oriented) parent bone currently... hopefully that's not an issue.
    local b3d = self.b3d_model
    local rot = tmp_mat4_rot:set_rot_luanti_entity(axial_rot.x*math.pi/180,axial_rot.y*math.pi/180, 0)
    tmp_mat4_rot = mat4.mul(tmp_mat4_rot, {b3d.root_orientation_rest_inverse, rot, b3d.root_orientation_rest})
    local xr,yr,zr = tmp_mat4_rot:get_rot_irrlicht_bone()

    obj:set_attach(player, handler.player_model_handler.bone_aliases.gun, nil, nil, visibility)
    obj:set_bone_override(self.consts.ROOT_BONE, {
        position = {
            vec = {x=pos.x/scale, y=pos.y/scale, z=pos.z/scale},
            interpolation = ip_time2,
        },
        rotation = {
            vec = {x=-xr,y=-yr,z=-zr},
            interpolation = ip_time,
        }
    })
end

--- checks if the gun entity exists...
-- @treturn bool
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
    local props = self.properties
    local old_tick
    if handler.walking then
        velocity = self.player:get_velocity()
        wag.velocity = velocity
    end
    old_tick = old_tick or wag.tick
    if velocity then
        if handler.walking then
            wag.tick = wag.tick + (dt*vector.length(velocity))
        else
            wag.tick = wag.tick + (dt*4)
        end
    end
    local walking_offset = self.offsets.walking
    if velocity and (not handler.walking) and (math.ceil(old_tick/props.wag.cycle_speed)+.5 < (math.ceil(wag.tick/props.wag.cycle_speed))+.5) and (wag.tick > old_tick) then
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
                local inp = (wag.tick/props.wag.cycle_speed)*math.pi*multiplier
                --this is a mess, I think that 1.6 is the frequency of human steps or something
                walking_offset[axis][i] = math.sin(inp)*self.properties.wag.offset[axis][i]
            else
                local old_value = walking_offset[axis][i]
                if math.abs(walking_offset[axis][i]) > .005 then
                    local multiplier = 1/props.wag.decay_speed
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
local e = 2.7182818284590452353602874713527 --I don't know how to find it otherwise...
function gun_default:update_recoil(dt)
    for axis, _ in pairs(self.offsets.recoil) do
        for _, i in pairs({"x","y"}) do
            local recoil_vel = self.velocities.recoil[axis][i]
            local recoil = self.offsets.recoil[axis][i]
            recoil = recoil + recoil_vel
            --this is modelled off a geometric sequence where the Y incercept of the sequence is set to recoil_vel.
            local r = (10*self.properties.recoil.velocity_correction_factor[axis])^-1
            local vel_co = e^-( (self.time_since_last_fire^2)/(2*r^2) )
            recoil_vel = self.velocities.init_recoil[axis][i]*vel_co
            if math.abs(recoil_vel) < 0.0001 then
                recoil_vel = 0
            end
            self.velocities.recoil[axis][i] = recoil_vel

            --ax^2+bx+c
            --recoil_velocity_correction_rate
            --recoil_correction_rate
            local old_recoil = recoil
            local abs = math.abs(recoil)
            local sign = old_recoil/abs
            if abs > 0.001 then
                local correction_value = abs*self.time_since_last_fire*self.properties.recoil.target_correction_factor[axis]
                correction_value = Guns4d.math.clamp(correction_value, 0, self.properties.recoil.target_correction_max_rate[axis])
                abs=abs-(correction_value*dt)
                --prevent overcorrection
                if abs < 0 then
                    abs = 0
                end
            end
            if sign~=sign then
                sign = 1
            end
            self.offsets.recoil[axis][i] = abs*sign
        end
    end
    --print(self.velocities.recoil.player_axial.x, self.velocities.recoil.player_axial.y)
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
--- sets the gun's animation in the same format as ObjRef:set_animation() (future deprecation?)
-- @tparam table frames `{x=int, y=int}`
-- @tparam float|nil length length of the animation in seconds
-- @tparam int fps frames per second of the animation
-- @tparam bool loop wether to loop
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

--- clears the animation to the rest state
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
local function adjust_gain(tbl, v)
    v = tbl.third_person_gain_multiplier or v
    for i = 1, #tbl do
        adjust_gain(tbl[i], v)
    end
    if tbl.gain and (tbl.split_audio_by_perspective~=false) then
        if type(tbl.gain) == "number" then
            tbl.gain = tbl.gain*v
        else
            tbl.gain.min = tbl.gain.min*v
            tbl.gain.max = tbl.gain.max*v
        end
    end
end

--- plays a list of sounds for the gun's user and thirdpersons
-- @tparam soundspec_list sound parameters following the format of @{Guns4d.play_sounds}
-- @treturn integer thirdperson sound's guns4d sound handle
-- @treturn integer firstperson sound's guns4d sound handle
function gun_default:play_sounds(sound)
    local thpson_sound = Guns4d.table.deep_copy(sound)
    local fsprsn_sound = Guns4d.table.deep_copy(sound)

    thpson_sound.pos = self.pos
    thpson_sound.player = self.player
    thpson_sound.exclude_player = self.player
    adjust_gain(thpson_sound, self.consts.THIRD_PERSON_GAIN_MULTIPLIER)

    fsprsn_sound.player = self.player
    fsprsn_sound.to_player = "from_player"

    return Guns4d.play_sounds(thpson_sound), Guns4d.play_sounds(fsprsn_sound)
end
function gun_default:update_breathing(dt)
    assert(self.instance)
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
        ran = vector.apply(vector.new(), function(i,v)
            if i ~= "x" then
                return (math.random()-.5)*2
            end
        end)
        ran.z = 0
        local vel_mul = self.multiplier_coefficient(sprops.hipfire_velocity_multiplier[axis], 1-self.control_handler.ads_location)
        sway_vel = vector.normalize(sway_vel+(ran*dt))*sprops.angular_velocity[axis]*vel_mul
        sway=sway+(sway_vel*dt)
        local len_mul = self.multiplier_coefficient(sprops.hipfire_angle_multiplier[axis], 1-self.control_handler.ads_location)
        if vector.length(sway) > sprops.max_angle[axis]*len_mul then
            sway=vector.normalize(sway)*sprops.max_angle[axis]*len_mul
            sway_vel = vector.new()
        end
        self.offsets.sway[axis] = sway
        self.velocities.sway[axis] = sway_vel
    end
end


--should merge these functions eventually...
function gun_default:update_animation_rotation()
    local current_frame = self.animation_data.current_frame+self.consts.KEYFRAME_SAMPLE_PRECISION
    local frame1 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
    current_frame = current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION
    local out
    if self.b3d_model.global_frames.rotation then
        if self.b3d_model.global_frames.rotation[frame1] then
            if (not self.b3d_model.global_frames.rotation[frame2]) or (current_frame==frame1) then
                out = vector.new(self.b3d_model.global_frames.rotation[frame1]:get_euler_irrlicht_bone())*180/math.pi
                --print("rawsent")
            else --to stop nan
                local ip_ratio = (current_frame-frame1)/(frame2-frame1)
                local vec1 = self.b3d_model.global_frames.rotation[frame1]
                local vec2 = self.b3d_model.global_frames.rotation[frame2]
                out = vector.new(vec1:slerp(vec2, ip_ratio):get_euler_irrlicht_bone())*180/math.pi
            end
        else
            out = vector.copy(self.b3d_model.global_frames.rotation[1])
        end
        --print(frame1, frame2, current_frame, dump(out))
    else
        out = vector.new()
    end
    --we use a different rotation system
    self.animation_rotation = -out
end

--relative to the gun's entity. Returns left, right vectors.
local out = {arm_left=vector.new(), arm_right=vector.new()}
function gun_default:get_arm_aim_pos()
    local current_frame = self.animation_data.current_frame+1
    local frame1 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
    current_frame = current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION

    for i, v in pairs(out) do
        if self.b3d_model.global_frames[i] then
            if self.b3d_model.global_frames[i][frame1] then
                if (not self.b3d_model.global_frames[i][frame2]) or (current_frame==frame1) then
                    out[i] = vector.copy(self.b3d_model.global_frames[i][frame1])
                else --to stop nan
                    local ip_ratio = (current_frame-frame1)/(frame2-frame1)
                    local vec1 = self.b3d_model.global_frames[i][frame1]
                    local vec2 = self.b3d_model.global_frames[i][frame2]
                    --print(current_frame, frame1, frame2, ip_ratio)
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
