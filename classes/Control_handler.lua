Guns4d.control_handler = {
    --[[example:
    actions_pc = {
        reload = {
            conditions = { --the list of controls (see lua_api.txt) to call
                "shift",
                "zoom"
            },
            timer = .3,
            mode = "toggle", "hybrid", "hold"
            call_before_timer = false,
            loop = false,
            func=function(active, interrupted, data, busy_controls)
        }
    }
    ]]
    ads = false,
    touchscreen = false
}
--data table:
--[[
    {
        continue = bool
        timer = float
        active_ticks = int
        current_mode = "toggle", "hold"
    }
]]
local controls = Guns4d.control_handler
--[[-modify controls (future implementation if needed)
function controls.modify()
end]]
--this function always ends up a mess. I rewrote it here 2 times,
--and in 3dguns I rewrote it at least 3 times. It's always just...
--impossible to understand. So if you see ALOT of comments, that's why.
function controls:get_actions()
    assert(self.instance, "attempt to call object method on a class")
    return (self.touchscreen and self.actions_touch) or self.actions_pc
end
function controls:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    self.player_pressed = self.player:get_player_control()
    local pressed = self.player_pressed
    local call_queue = {} --so I need to have a "call" queue so I can tell the functions the names of other active controls (busy_list)
    local busy_list = self.busy_list or {} --list of controls that have their conditions met. Has to be reset at END of update, so on_use and on_secondary_use can be marked
    if not (self.gun.rechamber_time > 0 and self.gun.ammo_handler.ammo.next_bullet == "empty") then --check if the gun is being charged.
        for i, control in pairs(self:get_actions()) do
            if not (i=="on_use") and not (i=="on_secondary_use") then
                local def = control
                local data = control.data
                local conditions_met = true
                --check no conditions are false
                for _, key in pairs(control.conditions) do
                    if not pressed[key] then conditions_met = false break end
                end
                if conditions_met then
                    if (def.mode == "toggle") or (def.mode == "hybrid") then
                        data.time_held = data.time_held + dt
                        if (not data.toggle_lock) and (data.toggled or (data.time_held > Guns4d.config.control_held_toggle_threshold)) then
                            data.toggled = not data.toggled
                            data.toggle_lock = true --so it can only be toggled once when conditions are met for a period of time
                            data.current_mode = "toggle"
                        end
                        if (data.current_mode ~= "hold") and (data.time_held > Guns4d.config.control_hybrid_toggle_threshold) and (def.mode=="hybrid") then
                            data.current_mode = "hold"
                            data.toggled = false
                        end
                    end
                else
                    if def.mode=="hyrbid" then
                        data.current_mode = "toggle"
                    end
                    data.time_held = 0
                    data.toggle_lock = false
                end
                --minetest.chat_send_all(data.current_mode)
                --minetest.chat_send_all(tostring((conditions_met and not def.toggle) or data.toggled))
                if (conditions_met and data.current_mode == "hold") or (data.toggled and data.current_mode == "toggle") then
                    busy_list[i] = true
                    data.timer = data.timer - dt
                    --when time is over, if it wasnt continue (or loop is active) then reset and call the function.
                    --continue indicates wether the function was called (as active) before last step.
                    if data.timer <= 0 and ((not data.continue) or def.loop) then
                        data.continue = true
                        table.insert(call_queue, {control=def, active=true, interrupt=false, data=data})
                        if data.current_mode == "toggle" then
                            data.toggled = false
                        end
                    elseif def.call_before_timer and not data.continue then --this is useful for functions that need to play animations for their progress.
                        table.insert(call_queue, {control=def, active=false, interrupt=false, data=data})
                    end
                else
                    data.continue = false
                    --detect interrupts, check if the timer was in progress
                    if data.timer ~= def.timer then
                        table.insert(call_queue, {control=def, active=false, interrupt=true, data=data})
                        data.timer = def.timer
                    end
                end
            end
        end
        for i, tbl in pairs(call_queue) do
            tbl.control.func(tbl.active, tbl.interrupt, tbl.data, busy_list, self.handler.gun, self.handler)
        end
        self.busy_list = {}
    elseif self.busy_list then
        self.busy_list = nil
    end
end
function controls:on_use(itemstack, pointed_thing)
    assert(self.instance, "attempt to call object method on a class")
    local actions = self:get_actions()
    if actions.on_use then
        actions.on_use(itemstack, self.handler, pointed_thing)
    end
end
function controls:on_secondary_use(itemstack, pointed_thing)
    assert(self.instance, "attempt to call object method on a class")
    local actions = self:get_actions()
    if actions.on_secondary_use then
        actions.on_secondary_use(itemstack, self.handler, pointed_thing)
    end
end
---@diagnostic disable-next-line: duplicate-set-field
function controls:toggle_touchscreen_mode(active)
    if active~=nil then self.touchscreen=active else self.touchscreen = not self.touchscreen end
    self.handler.touchscreen = self.touchscreen
    for i, action in pairs((self.touchscreen and self.actions_pc) or self.actions_touch) do
        if not (i=="on_use") and not (i=="on_secondary_use") then
            action.timer = action.timer or 0
            action.data = nil --no need to store excess data
        end
    end
    for i, action in pairs((self.touchscreen and self.actions_touch) or self.actions_pc) do
        if not (i=="on_use") and not (i=="on_secondary_use") then
            action.timer = action.timer or 0
            action.data = {
                timer = action.timer,
                continue = false,
                time_held = 0,
                current_mode = (action.mode=="hybrid" and "toggle") or action.mode or "hold"
            }
        end
    end
end
function controls.construct(def)
    if def.instance then
        assert(def.gun.properties.pc_control_actions, "no actions for pc controls provided")
        assert(def.gun.properties.touch_control_actions, "no actions for touchscreen controls provided")
        assert(def.player, "no player provided")
        --instantiate controls (as we will be adding to the table)
        def.actions_pc = Guns4d.table.deep_copy(def.gun.properties.pc_control_actions)
        def.actions_touch = Guns4d.table.deep_copy(def.gun.properties.touch_control_actions)
        def.busy_list = {}
        def.handler = Guns4d.players[def.player:get_player_name()]
        def:toggle_touchscreen_mode(def.touchscreen)

        table.sort(def.actions_pc, function(a,b)
            return #a.conditions > #b.conditions
        end)
    end
end
Guns4d.control_handler = Instantiatable_class:inherit(Guns4d.control_handler)