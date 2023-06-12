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
            data = {

            }
        }
    }
    ]]
}
local controls = Guns4d.control_handler
--[[-modify controls (future implementation if needed)
function controls.modify()
end]]
function controls:update(dt)
    self.player_pressed = self.player:get_player_control()
    local pressed = self.player_pressed
    local call_queue = {} --so I need to have a "call" queue so I can tell the functions the names of other active controls (busy_list)
    local busy_list = {} --list of controls that have their conditions met
    for i, control in pairs(self.controls) do
        local def = control
        local data = control.data
        local conditions_met = true
        for _, key in pairs(control.conditions) do
            if not pressed[key] then conditions_met = false break end
        end
        if not conditions_met then
            busy_list[i] = true
            data.held = false
            --detect interrupts
            if data.timer ~= def.timer then
                table.insert(call_queue, {control=def, active=false, interrupt=true, data=data})
                data.timer = def.timer
            end
        else
            data.timer = data.timer - dt
            --when time is over, if it wasnt held (or loop is active) then reset and call the function.
            if data.timer <= 0 and ((not data.held) or def.loop) then
                data.held = true
                table.insert(call_queue, {control=def, active=true, interrupt=false, data=data})
            elseif def.call_before_timer then
                table.insert(call_queue, {control=def, active=false, interrupt=false, data=data})
            end
        end
    end
    local count = 0
    for i, v in pairs(busy_list) do
        count = count + 1
    end
    if count == 0 then busy_list = nil end --so funcs can quickly deduce if they can call
    for i, tbl in pairs(call_queue) do
        tbl.control.func(tbl.active, tbl.interrupt, tbl.data, busy_list, Guns4d.players[self.player:get_player_name()].handler)
    end
end
---@diagnostic disable-next-line: duplicate-set-field
function controls.construct(def)
    if def.instance then
        assert(def.controls, "no controls provided")
        assert(def.player, "no player provided")
        def.controls = table.deep_copy(def.controls)
        for i, control in pairs(def.controls) do
            control.timer = control.timer or 0
            control.data = {
                timer = control.timer,
                held = false
            }
        end
        table.sort(def.controls, function(a,b)
            return #a.conditions > #b.conditions
        end)
    end
end
Guns4d.control_handler = Instantiatable_class:inherit(Guns4d.control_handler)