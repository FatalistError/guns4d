local Vec = vector
local player_handler = {
    --player = playerref
    --name = playername
    --wielded_item = ItemStack
    --gun = Gun (class)
    --wield_index = Int
    --player_model_handler = player_model_handler
    --infinite_ammo = false
    look_rotation = {x=0, y=0},
    look_offset = Vec.new(),
    ads_location = 0, --interpolation scalar for gun aiming location
    default_fov = Guns4d.config.default_fov,
    fov = Guns4d.config.default_fov,
    horizontal_offset = 0,
    unreliability_update_timer = 1, --update for server unreliabilities or issues.
}
function player_handler:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    local player = self.player
    self.wielded_item = self.player:get_wielded_item()
    local held_gun = self:is_holding_gun() --get the gun class that is associated with the held gun
    if held_gun then
        --was there a gun last time? did the wield index change?
        local old_index = self.wield_index
        self.wield_index = player:get_wield_index()
        --initialize all handlers and objects
        if (not self.gun) or (self.gun.id ~= self.wielded_item:get_meta():get_string("guns4d_id")) then
            --initialize important player data
            self.itemstack = self.wielded_item
            self.inventory = player:get_inventory()
            --initialize our handlers
            if self.gun then --delete gun object if present
                self.gun:prepare_deletion()
                self.gun = nil
            end
            self.gun = held_gun:new({itemstack=self.wielded_item, handler=self}) --this will set itemstack meta, and create the gun based off of meta and other data.
            if self.player_model_handler then --if player_model_handler present, then delete
                self.player_model_handler:prepare_deletion()
                self.player_model_handler = nil
            end
            self.player_model_handler = Guns4d.player_model_handler.get_handler(self:get_properties().mesh):new({player=self.player})
            self.control_handler = Guns4d.control_handler:new({player=player, actions=self.gun.properties.control_actions, gun=self.gun})

            --this needs to be stored for when the gun is unset!
            self.horizontal_offset = self.gun.properties.ads.horizontal_offset

            --set_hud_flags
            player:hud_set_flags({wielditem = false, crosshair = false})

            --for the gun's scopes to work properly we need predictable offsets.
        end
        --update some properties.
        self.look_rotation.x, self.look_rotation.y = Guns4d.math.clamp((player:get_look_vertical() or 0)*180/math.pi, -80, 80), 360-player:get_look_horizontal()*180/math.pi
        if TICK % 10 == 0 then
            self.wininfo = minetest.get_player_window_information(self.player:get_player_name())
        end

        --update handlers
        self.gun:update(dt) --gun should be updated first so self.dir is available.
        self.control_handler:update(dt)
        self.player_model_handler:update(dt)

        --this has to be checked after control handler
        if TICK % 4 == 0 then
            self.touching_ground = self:get_is_on_ground()
            self.walking = self:get_is_walking()
        end
    elseif self.gun then
        self.control_handler = nil
        --delete gun object
        self.gun:prepare_deletion()
        self.gun = nil
        --delete model handler object (this resets the player model)
        self.player_model_handler:prepare_deletion()
        self.player_model_handler = nil
        --patch for spriteguns.
        if (not spriteguns) or (spriteguns and (not spriteguns.registered_guns[player:get_wielded_item():get_name()])) then
            player:hud_set_flags({wielditem = true, crosshair = true}) --reenable hud elements
        end
    end


    --eye offsets and ads_location
    if (self.control_handler and self.control_handler.ads) and (self.ads_location<1) then
        --if aiming, then increase ADS location
        self.ads_location = Guns4d.math.clamp(self.ads_location + (dt/self.gun.properties.ads.aim_time), 0, 1)
    elseif ((not self.control_handler) or (not self.control_handler.ads)) and self.ads_location>0 then
        local divisor = .2
        if self.gun then
            divisor = self.gun.properties.ads.aim_time/self.gun.consts.AIM_OUT_AIM_IN_SPEED_RATIO
        end
        self.ads_location = Guns4d.math.clamp(self.ads_location - (dt/divisor), 0, 1)
    end

    self.look_offset.x = self.horizontal_offset*self.ads_location
    player:set_eye_offset(self.look_offset*10)
    --some status stuff
    --stored properties and pos must be reset as they could be outdated.
    self.properties = nil
    self.pos = nil
end
function player_handler:get_is_on_ground()
    assert(self.instance, "attempt to call object method on a class")
    local touching_ground = false
    local player = self.player
    local player_properties = self:get_properties()
    local ray = minetest.raycast(self:get_pos()+vector.new(0, self:get_properties().eye_height, 0), self:get_pos()-vector.new(0,.1,0), true, true)
    for pointed_thing in ray do
        if pointed_thing.type == "object" then
            if pointed_thing.ref ~= player and pointed_thing.ref:get_properties().physical == true then
                touching_ground = true
            end
        end
        if pointed_thing.type == "node" then
            touching_ground = true
        end
    end
    return touching_ground
end
function player_handler:get_is_walking()
    assert(self.instance, "attempt to call object method on a class")
    local walking = false
    local velocity = self.player:get_velocity()
    local controls
    if not self.control_handler then
        controls = self.player:get_player_control()
    else
        controls = self.control_handler.player_pressed
    end
    if (vector.length(vector.new(velocity.x, 0, velocity.z)) > .1)
        and (controls.up or controls.down or controls.left or controls.right)
        and self.touching_ground
    then
        walking = true
    end
    return walking
end
--allows the gun to set FOV without having to worry about unsetting it
function player_handler:set_fov(val, transition)
    self.fov_lock = true
    Guns4d.old_set_fov(self.player, val, nil, transition)
end
function player_handler:unset_fov(transition)
    self.fov_lock = false
    --minetest.chat_send_all(transition)
    --https://github.com/minetest/minetest/issues/14499, setting a transition time seems to fix it
    Guns4d.old_set_fov(self.player, self.default_fov, false, Guns4d.math.clamp(transition or 0, .15, math.huge))
end
--doubt I'll ever use this... but just in case I don't want to forget.
function player_handler:get_pos()
    assert(self.instance, "attempt to call object method on a class")
    if self.pos then return self.pos end
    self.pos = self.player:get_pos()
    return self.pos
end
function player_handler:set_pos(val)
    assert(self.instance, "attempt to call object method on a class")
    self.pos = vector.new(val)
    self.player:set_pos(val)
end
function player_handler:get_properties()
    assert(self.instance, "attempt to call object method on a class")
    if self.properties then return self.properties end
    self.properties = self.player:get_properties()
    return self.properties
end
function player_handler:set_properties(properties)
    assert(self.instance, "attempt to call object method on a class")
    self.player:set_properties(properties)
    self.properties = Guns4d.table.fill(self.properties, properties)
end
function player_handler:is_holding_gun()
    assert(self.instance, "attempt to call object method on a class")
    if self.wielded_item then
        for name, obj in pairs(Guns4d.gun.registered) do
            if obj.itemstring == self.wielded_item:get_name() then
                return obj
            end
        end
    end
end
function player_handler:update_wield_item(wield, meta)
    assert(self.instance, "attempt to call object method on a class")
    local stack = self.wielded_item
    if wield then
        stack = ItemStack(wield)
    end
    if meta then
        local tbl = meta
        if type(meta) ~= "table" then
            tbl = meta:to_table()
        end
        stack:from_table(tbl)
    end
    self.player:set_wielded_item(stack)
    return stack
end
function player_handler:prepare_deletion()
    assert(self.instance, "attempt to call object method on a class")
    if self.gun then
        self.gun:prepare_deletion()
        self.gun = nil
    end
end
--note that construct is NOT called as a method
function player_handler.construct(def)
    if def.instance then
        def.old_mesh = def.player:get_properties().mesh
        assert(def.player, "no player obj provided to player_handler on construction")
        --this is important, as setting a value within a table would set it for all tables otherwise
        for i, v in pairs(player_handler) do
            if (type(v) == "table") and not def[i] then
                def[i] = v
            end
        end
        def.look_rotation = Guns4d.table.deep_copy(player_handler.look_rotation)
        def.infinite_ammo = minetest.check_player_privs(def.player, Guns4d.config.infinite_ammo_priv)
    end
end
Guns4d.player_handler = Instantiatable_class:inherit(player_handler)
