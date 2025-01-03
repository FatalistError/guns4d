-- @within Gun.gun
-- @compact

local gun_default = Guns4d.gun
local mat4 = leef.math.mat4
--I dont remember why I made this, used it though lmao
function gun_default.multiplier_coefficient(multiplier, ratio)
    return 1+((multiplier*ratio)-ratio)
end

--- The entry method for the update of the gun
--
-- calls virtually all functions that begin with `update` once. Also updates subclass
--
-- @tparam float dt
function gun_default:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    if not self:has_entity() then self:add_entity() self:clear_animation() end
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
    --I should make this into a list
    if self.consts.HAS_SWAY then self:update_sway(dt) end
    if self.consts.HAS_RECOIL then self:update_recoil(dt) end
    if self.consts.HAS_BREATHING then self:update_breathing(dt) end
    if self.consts.HAS_WAG then self:update_wag(dt) end

    self:update_animation(dt)
    self.dir = self:get_dir(nil,nil,nil,self.consts.ANIMATIONS_OFFSET_AIM)
    self.pos = self:get_pos()+self.handler:get_pos()

    --update subclasses
    self:update_entity()
    --this should really be a list of subclasses so its more easily expansible
    for i, instance in pairs(self.subclass_instances) do
        if instance.update then instance:update(dt) end
        if not self.properties.subclasses[i] then
            instance:prepare_deletion()
            self.subclass_instances[i] = nil
        end
    end

    --finalize transforms
    self:update_transforms()
end

function gun_default:regenerate_properties()
    self._properties_unsafe = Guns4d.table.deep_copy(self.base_class.properties)
    self.properties = self._properties_unsafe
    for i, func in pairs(self.property_modifiers) do
        func(self)
    end
    self.properties = leef.class.proxy_table.new(self.properties)
    self:update_visuals()
end

--- not typically called every step, updates the gun object's visuals
function gun_default:update_visuals()
    local props = self.properties
    self.entity:set_properties({
        mesh = props.visuals.mesh,
        textures = table.copy(props.visuals.textures),
        backface_culling = props.visuals.backface_culling,
        visual_size = {x=10*props.visuals.scale,y=10*props.visuals.scale,z=10*props.visuals.scale}
    })
    for i, ent in pairs(self.attached_objects) do
        if not self.properties.visuals.attached_objects[i] then
            ent:remove()
        end
    end
    for i, attached in pairs(self.properties.visuals.attached_objects) do
        if attached.mesh then
            assert(type(attached)=="table", self.name..": `attached.objects` expects a list of tables, incorrect type given.")
            local obj
            if (not self.attached_objects[i]) or (not self.attached_objects[i]:is_valid()) then
                obj = minetest.add_entity(self.handler:get_pos(), "guns4d:gun_entity")
                self.attached_objects[i] = obj
            else
                obj = self.attached_objects[i]
            end
            obj:set_properties({
                mesh = attached.mesh,
                textures = table.copy(attached.textures or self.properties.visuals.textures),
                backface_culling = attached.backface_culling,
                visual_size = {x=attached.scale or 1,  y=attached.scale or 1,  z=attached.scale or 1}
            })
            local offset
            if attached.offset then
                offset = attached.offset
                offset = mat4.mul_vec4({}, self.b3d_model.root_orientation_rest_inverse, {offset.x, offset.y, offset.z, 0})
                offset = {x=offset[1], y=offset[2], z=offset[3]}
            end
            local rotation
            if attached.rotation then
                rotation = attached.rotation
                local rotm4 = mat4.set_rot_luanti_entity(mat4.identity(), rotation.x*math.pi/180, rotation.y*math.pi/180, rotation.z*math.pi/180)
                rotm4 = self.b3d_model.root_orientation_rest_inverse*rotm4
                rotation = {rotm4:get_rot_luanti_entity()}
                rotation = {x=rotation[1]*180/math.pi, y=rotation[2]*180/math.pi, z=rotation[3]*180/math.pi}
            else
                rotation = {(self.b3d_model.root_orientation_rest_inverse):get_rot_luanti_entity()}
                rotation = {x=rotation[1]*180/math.pi, y=rotation[2]*180/math.pi, z=rotation[3]*180/math.pi}
            end
            obj:set_attach(
                self.entity,
                self.consts.ROOT_BONE,
                offset,
                rotation
                --true
            )
        else
            minetest.log("error", "Guns4d: attached object had no mesh")
        end
    end
end


--- updates self.total_offsets which stores offsets for bones
function gun_default:update_transforms()
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
    --total_offset.gun_axial.x = 0; total_offset.gun_axial.y = 0
end

--- Update and fire the queued weapon burst
function gun_default:update_burstfire()
    if self.rechamber_time <= 0 then
        local iter = 1
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
            iter = iter + 1
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
    if firemodes > 1 and self.properties.inventory.firemode_inventory_overlays[self.properties.firemodes[self.current_firemode]] then
        image = image.."^"..self.properties.inventory.firemode_inventory_overlays[self.properties.firemodes[self.current_firemode]]
    end
    if self.handler.infinite_ammo then
        image = image.."^"..self.properties.infinite_inventory_overlay
    end
    meta:set_string("inventory_image", image)
end

--- plays the draw animation and sound for the gun, delays usage.
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

            --this is gonna have to be optimized eventually because this system is complete ass.
            local fire_sound = Guns4d.table.deep_copy(props.sounds.fire) --important that we copy because play_sounds modifies it.
            fire_sound.pos = self.pos
            self:play_sounds(fire_sound)

            self.rechamber_time = self.rechamber_time + (60/props.firerateRPM)

            --acount for animation rotation in same update firing
            if (self.rechamber_time<(60/props.firerateRPM)) and props.firemodes[self.current_firemode]~="single" then
                self.animation_data.runtime = self.animation_data.runtime + (60/props.firerateRPM)
                self:update_animation_transforms()
            end
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
    self.time_since_last_fire = 0
end
function gun_default:open_inventory_menu()
    local props = self.properties
    local player = self.player
    local pname = player:get_player_name()
    local inv = minetest.get_inventory({type="player", name=pname})
    local window = minetest.get_player_window_information(pname)
    local listname = Guns4d.config.inventory_listname
    local form_dimensions = {x=20,y=15}

    local inv_height=4+((4-1)*.125)
    local hotbar_length = player:hud_get_hotbar_itemcount()
    local form = "\
    formspec_version[7]\
     size[".. form_dimensions.x ..",".. form_dimensions.y .."]"

    local hotbar_height = math.ceil(hotbar_length/8)
    form = form.."\
    scroll_container[.25,"..(form_dimensions.y)-inv_height-1.25 ..";10,5;player_inventory;vertical;.05]\
        list[current_player;"..listname..";0,0;"..hotbar_length..","..hotbar_height..";]\
        list[current_player;"..listname..";0,1.5;8,3;"..hotbar_length.."]\
    scroll_container_end[]\
    "
    if math.ceil(inv:get_size("main")/8) > 4 then
        local h = math.ceil(inv:get_size("main")/8)
        form=form.."\
        scrollbaroptions[max="..h+((h-1)*.125).."]\
        scrollbar[10.25,"..(form_dimensions.y)-inv_height-1.25 ..";.5,5;vertical;player_inventory;0]\
        "
    end
    --display gun preview
    local len = math.abs(self.model_bounding_box[3]-self.model_bounding_box[6])/props.visuals.scale
    local hei = math.abs(self.model_bounding_box[2]-self.model_bounding_box[5])/props.visuals.scale
    local offsets = {x=(-self.model_bounding_box[6]/props.visuals.scale)-(len/2), y=(self.model_bounding_box[5]/props.visuals.scale)+(hei/2)}

    local meter_scale = 15
    local image_scale = meter_scale*(props.inventory.render_size or 1)
    local gun_gui_offset = {x=0,y=-2.5}
    form = form.."container["..((form_dimensions.x-image_scale)/2)+gun_gui_offset.x.. ","..((form_dimensions.y-image_scale)/2)+gun_gui_offset.y.."]"
    if props.inventory.render_image then
        form = form.."image["
        ..(offsets.x*meter_scale) ..","
        ..(offsets.y*meter_scale) ..";"
        ..image_scale..","
        ..image_scale..";"
        ..props.inventory.render_image.."]"
    end
    if self.part_handler then
        --local attachment_inv = self.part_handler.virtual_inventory
        if props.inventory.part_slots and self.part_handler then
            for i, attachment in pairs(props.inventory.part_slots) do
                form = form.."label["..(image_scale/2)+(attachment.formspec_offset.x or 0)-.75 ..","..(image_scale/2)+(-attachment.formspec_offset.y or 0)-.2 ..";"..(attachment.description or i).."]"
                --list[<inventory location>;<list name>;<X>,<Y>;<W>,<H>;<starting item index>]
                local width = attachment.slots or 1
                width = width+((width-1)*.125)
                form = form.."list[detached:guns4d_attachment_inv_"..pname..";"..i..";"..(image_scale/2)+(attachment.formspec_offset.x or 0)-(width/2)..","..(image_scale/2)+(-attachment.formspec_offset.y or 0)..";3,5;]"
            end
        end
    end
    form = form.."container_end[]"
    minetest.show_formspec(self.handler.player:get_player_name(), "guns4d:inventory", form)
end
core.register_on_player_receive_fields(function(player, formname, fields)
    if formname=="guns4d:inventory" and fields.quit then
        local gun = Guns4d.players[player:get_player_name()].gun
        gun:regenerate_properties()
    end
end)





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
--all of this dir shit needs to be optimized HARD
--[[function gun_default:get_gun_axial_dir()
    assert(self.instance, "attempt to call object method on a class")
    local rotation = self.total_offsets
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=rotation.gun_axial.x*math.pi/180, z=0}))
    dir = vector.rotate(dir, {y=rotation.gun_axial.y*math.pi/180, x=0, z=0})
    return dir
end]]
--[[function gun_default:get_player_axial_dir(rltv)
    assert(self.instance, "attempt to call object method on a class")
    local handler = self.handler
    local rotation = self.total_offsets
    local dir = vector.new(vector.rotate({x=0, y=0, z=1}, {y=0, x=((rotation.player_axial.x)*math.pi/180), z=0}))
    dir = vector.rotate(dir, {y=((rotation.player_axial.y)*math.pi/180), x=0, z=0})
    if not rltv then
        if (self.properties.subclasses.sprite_scope and handler.control_handler.ads) or (self.properties.subclasses.crosshair and not handler.control_handler.ads) then
            --we need the head rotation in either of these cases, as that's what they're showing.
            dir = vector.rotate(dir, {x=handler.look_rotation.x*math.pi/180,y=-handler.look_rotation.y*math.pi/180,z=0})
        else
            dir = vector.rotate(dir, {x=self.player_rotation.x*math.pi/180,y=self.player_rotation.y*math.pi/180,z=0})
        end
    end
    return dir
end]]

local tmv3_rot = vector.new()
local tmv4_in = {0,0,0,1}
local tmv4_pivot_inv = {0,0,0,0}
local tmv4_offset = {0,0,0,1}
local tmv4_gun = {0,0,0,1}
local empty_vec = {x=0,y=0,z=0}
local ttransform = mat4.identity()
local out = vector.new() --reserve the memory, we still want to create new vectors each time though.
--gets the gun's position relative to the player. Relative indicates wether it's relative to the player's horizontal look
--offset is relative to the's rotation

--- get the global position of the gun. This is customized to rely on the assumption that there are 3-4 main rotations and 2-3 translations. If the behavior of the bones are changed this method may not work.
-- the point of this is to allow the user to find the gun's object origin as well as calculate where a given point should be offset given the parameters.
-- @tparam vec3 offset_pos
-- @tparam bool relative_y wether the y axis is relative to the player's look
-- @tparam bool relative_x wether the x axis is relative to the player's look
-- @tparam bool with_animation wether rotational and translational offsets from the animation are applied
-- @treturn vec3 position of gun (in global or local orientation) relative to the player's position
function gun_default:get_pos(offset, relative_y, relative_x, with_animation)
    assert(self.instance, "attempt to call object method on a class")
    --local player = self.player
    local px = (relative_x and 0) or nil
    local py = (relative_y and 0) or nil
    local ax = ((not with_animation) and 0) or nil
    local ay = ((not with_animation) and 0) or nil
    local az = ((not with_animation) and 0) or nil
    offset = offset or empty_vec

    local gun_translation = self.gun_translation --needs a refactor
    local root_transform = self.b3d_model.root_orientation_rest
    --dir needs to be rotated twice seperately to avoid weirdness
    local gun_scale = self.properties.visuals.scale
    --generate rotation values based on our output

    ttransform=self:get_rotation_transform(ttransform,nil,nil,nil,nil,nil,px,py,ax,ay,az)

    --change the pivot of `offset` to the root bone by making our vector relative to it (basically setting it to origin)
    tmv4_in[1], tmv4_in[2], tmv4_in[3] = offset.x-root_transform[13]*gun_scale, offset.y-root_transform[14]*gun_scale, offset.z-root_transform[15]*gun_scale
    tmv4_offset = ttransform.mul_vec4(tmv4_offset, ttransform, tmv4_in) --rotate by our rotation transform
    --to bring it back to global space we need to find what we offset it by in `ttransform`'s local space, so we apply the transform to it
    tmv4_in[1], tmv4_in[2], tmv4_in[3] = root_transform[13]*gun_scale, root_transform[14]*gun_scale, root_transform[15]*gun_scale
    tmv4_pivot_inv = ttransform.mul_vec4(tmv4_pivot_inv, ttransform, tmv4_in)

    --quickly add together tmv4_offset+tmv4_pivot_inv to get the global position of the offset relative to the entity
    tmv4_offset[1],tmv4_offset[2],tmv4_offset[3] = tmv4_offset[1]+tmv4_pivot_inv[1], tmv4_offset[2]+tmv4_pivot_inv[2], tmv4_offset[3]+tmv4_pivot_inv[3]

    --get the position of the gun entity in global space relative to the bone which it is attached to.
    ttransform=self:get_rotation_transform(ttransform, 0,0,0,nil,nil,px,py,ax,ay,az)
    tmv4_in[1], tmv4_in[2], tmv4_in[3] = gun_translation.x, gun_translation.y, gun_translation.z
    tmv4_gun = ttransform.mul_vec4(tmv4_gun, ttransform, tmv4_in)

    --get the position of the bone globally
    local bone_location = self.handler.player_model_handler.gun_bone_location
    if relative_y then
        out = vector.new(bone_location)
    else
        tmv3_rot.y = -self.handler.look_rotation.y*math.pi/180
        out = vector.rotate(bone_location, tmv3_rot)
    end
    --add our global translations together
    --bonepos + gunentity + gunoffset + animation offset
    local anim = (with_animation and self.animation_translation) or empty_vec
    out.x, out.y, out.z = out.x+anim.x+tmv4_gun[1]+tmv4_offset[1], out.y+anim.y+tmv4_gun[2]+tmv4_offset[2], out.z+anim.z+tmv4_gun[3]+tmv4_offset[3]
    return out
end

local roll = mat4.identity() --roll offset (future implementation )
local lrot = mat4.identity() --local rotation offset
local grot = mat4.identity() --global rotation offset
local prot = mat4.identity() --global player rotation
local trad = math.pi/180
function gun_default:get_rotation_transform(out, lx,ly,lz,gx,gy,px,py,ax,ay,az)
    --local pitch, global pitch etc.
    local rotations = self.total_offsets
    local arotation = self.animation_rotation
    local protation = self.player_rotation
    --eventually we want to INTERNALLY use radians, for now we have to do this though.
    lz = lz or 0 --roll is currently unused.
    ax, ay, az = ax or -arotation.x*trad, ay or -arotation.y*trad, az or -arotation.z*trad
    lx, ly = lx or -rotations.gun_axial.x*trad, ly or -rotations.gun_axial.y*trad
    gx, gy = gx or -rotations.player_axial.x*trad, gy or -rotations.player_axial.y*trad
    px, py = px or -protation.x*trad, py or -protation.y*trad

    --this doesnt account for the actual rotation of the player
    --reset roll matrix
    roll[1] = 1
    roll[2] = 0
    roll[5] = 0
    roll[6] = 1
    roll = mat4.rotate_Z(roll, lz+az)
        --we use bone rotation because it uses the XYZ order. Overall order is "PGLA", player (ZXY)<-global_offset (XYZ)<-local_offset (XYZ)<-roll (Z)\
    out = mat4.multiply(out, {prot:set_rot_luanti_entity(px, py, 0), grot:set_rot_irrlicht_bone(gx, gy, 0), lrot:set_rot_irrlicht_bone(lx+ax, ly+ay, 0), roll})
    return out
end
local forward = {0,0,1,0}
local tmv4_out = {0,0,0,0}
-- get the direction for firing
function gun_default:get_dir(rltv, offx, offy, suppress_anim)
    local rotations = self.total_offsets
    local anim_x = (suppress_anim and 0) or nil
    local anim_y = (suppress_anim and 0) or nil
    local anim_z = (suppress_anim and 0) or nil
    if rltv then
        ttransform = self:get_rotation_transform(ttransform, (-rotations.gun_axial.x-(offx or 0) )*trad, (-rotations.gun_axial.y-(offy or 0))*trad, nil,   nil, nil,   0, 0,      anim_x,anim_y,anim_z)
    else
        local player_aim
        if (self.properties.subclasses.sprite_scope and self.handler.control_handler.ads) or (self.properties.subclasses.crosshair and not self.handler.control_handler.ads)  then
            player_aim=self.player:get_look_vertical()
        end
        ttransform = self:get_rotation_transform(ttransform, (-rotations.gun_axial.x-(offx or 0))*trad, (-rotations.gun_axial.y-(offy or 0))*trad, nil,   nil, nil,   player_aim, nil,   anim_x,anim_y,anim_z)
    end
    local tmv4 = ttransform.mul_vec4(tmv4_out, ttransform, forward)
    local pos = vector.new(tmv4[1], tmv4[2], tmv4[3])

    return pos
end

--=============================================== ENTITY ======================================================

--- adds the gun entity
function gun_default:add_entity()
    assert(self.instance, "attempt to call object method on a class")
    self.entity = minetest.add_entity(self.player:get_pos(), "guns4d:gun_entity")
    local props = self.properties
    Guns4d.gun_by_ObjRef[self.entity] = self
    self:update_visuals()
end
local tmp_mat4_rot = mat4.identity()
local ip_time = Guns4d.config.gun_axial_interpolation_time
local ip_time2 = Guns4d.config.translation_interpolation_time

--- updates the gun's entity
function gun_default:update_entity()
    local obj = self.entity
    local player = self.player
    local handler = self.handler
    local props = self.properties
    --attach to the correct bone, and rotate
    local visibility = true
    if self.subclass_instances.sprite_scope and self.subclass_instances.sprite_scope.hide_gun and (not (self.control_handler.ads_location == 0)) then
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
    local rot = self:get_rotation_transform(tmp_mat4_rot, nil,nil,nil, 0,0, 0,0, 0,0,0)
    tmp_mat4_rot = mat4.mul(tmp_mat4_rot, {b3d.root_orientation_rest_inverse, rot, b3d.root_orientation_rest})
    local xr,yr,zr = tmp_mat4_rot:get_rot_irrlicht_bone()

    obj:set_attach(player, handler.player_model_handler.bone_aliases.gun, nil, nil, visibility)
    obj:set_bone_override(self.consts.ROOT_BONE, {
        position = {
            vec = {x=pos.x/scale, y=pos.y/scale, z=pos.z/scale},
            interpolation = ip_time2,
        },
        rotation = {
            vec = {x=xr,y=yr,z=zr},
            interpolation = ip_time,
        }
    })
end

--- checks if the gun entity exists...
-- @treturn bool
function gun_default:has_entity()
    assert(self.instance, "attempt to call object method on a class")
    if not self.entity then return false end
    if not self.entity:is_valid() then return false end
    return true
end

--- updates the gun's wag offset for walking
-- @tparam float dt
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

--- updates the gun's recoil simulation
-- @tparam float dt
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
end

--- updates the gun's animation data
-- @tparam dt
function gun_default:update_animation(dt)
    --local ent = self.entity
    local data = self.animation_data
    data.runtime = data.runtime + dt
    data.current_frame = Guns4d.math.clamp(data.current_frame+(dt*data.fps), data.frames.x, data.frames.y)
    if data.loop and (data.current_frame > data.frames.y) then
        data.current_frame = data.frames.x
    end
    self:update_animation_transforms()
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
function gun_default:update_animation_transforms()
    local current_frame = self.animation_data.current_frame+self.consts.KEYFRAME_SAMPLE_PRECISION
    local frame1 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)
    local frame2 = math.floor(current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION)+1
    current_frame = current_frame/self.consts.KEYFRAME_SAMPLE_PRECISION
    local rotations = self.b3d_model.global_frames.root_rotation
    local positions = self.b3d_model.global_frames.root_translation
    local euler_rot
    local trans
    if not rotations[frame1] then --note that we are inverting the rotations, this is because b3d turns the wrong way or something? It might be an issue with LEEF idk.
        euler_rot = vector.new(rotations[1]:get_euler_irrlicht_bone())*-1
    else
        local ip_ratio = (frame2 and (current_frame-frame1)/(frame2-frame1)) or 1
        local vec1 = rotations[frame1]
        local vec2 = rotations[frame2] or rotations[frame1]
        euler_rot = vector.new(vec1:slerp(vec2, ip_ratio):get_euler_irrlicht_bone())*-180/math.pi
    end

    if not positions[frame1] then --note that we are inverting the rotations, this is because b3d turns the wrong way or something? It might be an issue with LEEF idk.
        trans = positions[1]*-1
    else
        local ip_ratio = (frame2 and (current_frame-frame1)/(frame2-frame1)) or 1
        local vec1 = positions[frame1]
        local vec2 = positions[frame2] or positions[frame1]
        trans = (vec1*(1-ip_ratio))+(vec2*ip_ratio)
    end
    self.animation_rotation = euler_rot
    self.animation_translation = trans
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
                    local ip_ratio = (current_frame-frame1)/(frame2-frame1)
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

--- ready the gun to be deleted
function gun_default:prepare_deletion()
    self.released = true
    assert(self.instance, "attempt to call object method on a class")
    if self:has_entity() then self.entity:remove() end

    for i, instance in pairs(self.subclass_instances) do
        if instance.prepare_deletion then instance:prepare_deletion() end
    end
end
