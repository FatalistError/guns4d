Guns4d.control_handler = {
    --[[example:
    controls = {
        reload = {
            conditions = { --the list of controls (see lua_api.txt) to call
                "shift",
                "zoom"
            },
            timer = .3,
            call_before_timer = false,
            loop = false,
            func=function(active, interrupted, data, busy_controls)
        }
    }
    ]]
}
--data table:
--[[
    {
        held = bool
        timer = float
    }
]]
local controls = Guns4d.control_handler
--[[-modify controls (future implementation if needed)
function controls.modify()
end]]
--this function always ends up a mess. I rewrote it here 2 times,
--and in 3dguns I rewrote it at least 3 times. It's always just...
--impossible to understand. So if you see ALOT of comments, that's why.
function controls:update(dt)
    assert(self.instance, "attempt to call object method on a class")
    self.player_pressed = self.player:get_player_control()
    local pressed = self.player_pressed
    local call_queue = {} --so I need to have a "call" queue so I can tell the functions the names of other active controls (busy_list)
    local busy_list = self.busy_list --list of controls that have their conditions met. Has to be reset at END of update, so on_use and on_secondary_use can be marked
    for i, control in pairs(self.controls) do
        if not (i=="on_use") and not (i=="on_secondary_use") then
            local def = control
            local data = control.data
            local conditions_met = true
            --check no conditions are false
            for _, key in pairs(control.conditions) do
                if not pressed[key] then conditions_met = false break end
            end
            if conditions_met then
                data.timer = data.timer - dt
                --when time is over, if it wasnt held (or loop is active) then reset and call the function.
                --held indicates wether the function was called (as active) before last step.
                if data.timer <= 0 and ((not data.held) or def.loop) then
                    data.held = true
                    table.insert(call_queue, {control=def, active=true, interrupt=false, data=data})
                elseif def.call_before_timer and not data.held then --this is useful for functions that need to play animations for their progress.
                    table.insert(call_queue, {control=def, active=false, interrupt=false, data=data})
                end
            else
                busy_list[i] = true
                data.held = false
                --detect interrupts, check if the timer was in progress
                if data.timer ~= def.timer then
                    table.insert(call_queue, {control=def, active=false, interrupt=true, data=data})
                    data.timer = def.timer
                end
            end
        end
    end
    --busy list is so we can tell if a function should be allowed or not
    if #busy_list == 0 then busy_list = nil end
    for i, tbl in pairs(call_queue) do
        tbl.control.func(tbl.active, tbl.interrupt, tbl.data, busy_list, self.handler)
    end
    self.busy_list = {}
end
function controls:on_use(itemstack, pointed_thing)
    assert(self.instance, "attempt to call object method on a class")
    if self.controls.on_use then
        self.controls.on_use(itemstack, self.handler, pointed_thing)
    end
end
function controls:on_secondary_use(itemstack, pointed_thing)
    assert(self.instance, "attempt to call object method on a class")
    if self.controls.on_secondary_use then
        self.controls.on_secondary_use(itemstack, self.handler, pointed_thing)
    end
end
---@diagnostic disable-next-line: duplicate-set-field
function controls.construct(def)
    if def.instance then
        assert(def.controls, "no controls provided")
        assert(def.player, "no player provided")
        def.controls = table.deep_copy(def.controls)
        def.busy_list = {}
        def.handler = Guns4d.players[def.player:get_player_name()].handler
        for i, control in pairs(def.controls) do
            if not (i=="on_use") and not (i=="on_secondary_use") then
                control.timer = control.timer or 0
                control.data = {
                    timer = control.timer,
                    held = false
                }
            end
        end
        table.sort(def.controls, function(a,b)
            return #a.conditions > #b.conditions
        end)
    end
end
Guns4d.control_handler = Instantiatable_class:inherit(Guns4d.control_handler)