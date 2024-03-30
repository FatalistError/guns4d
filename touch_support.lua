minetest.register_chatcommand(Guns4d.config.enable_touchscreen_command_name, {
    description = "toggle wether the user is using a mobile device so controls can be adjusted for an optimal mobile experience",
    func = function(caller, arg)
        local handler = Guns4d.players[caller]
        if handler and handler.control_handler then
            handler.control_handler:toggle_touchscreen_mode()
            minetest.chat_send_player(caller, "mobile mode "..((handler.control_handler.touchscreen and "enabled") or "disabled"))
            if handler.control_handler.touchscreen then
                minetest.chat_send_player(caller, "shift+tap to aim, shift+hold to switch fire modes, tap to fire, hold to fire full auto (when wielding a full auto weapon)")
            end
        end
    end
})

Guns4d.default_touch_controls = {}
local touch = Guns4d.default_touch_controls
local pc = Guns4d.default_controls

--aiming
touch.aim = table.copy(pc.aim)
touch.aim.conditions = {"RMB", "sneak"}

--switching firemode
touch.firemode = table.copy(pc.firemode)
touch.firemode.conditions = {"LMB", "sneak"}
touch.firemode.func = function(active, interrupted, data, busy_list, gun, handler)
    if active then
        gun:cycle_firemodes()
    end
end

--reloading
touch.reload = table.copy(pc.reload)
touch.reload.mode = "toggle"

--firing semi
touch.on_secondary_use = function(itemstack, handler, pointed_thing)
    if not handler.control_handler.player_pressed.sneak then
        pc.on_use(itemstack, handler, pointed_thing)
    end
end

--full auto
touch.auto = table.copy(pc.auto)
touch.auto.conditions = {"LMB"}
touch.auto.func = function(active, interrupted, data, busy_list, gun, handler)
    if (not handler.control_handler.player_pressed.sneak) and gun.properties.firemodes[gun.current_firemode] == "auto" then
        gun:attempt_fire()
    end
end