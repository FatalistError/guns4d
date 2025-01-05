--- a default control system for aiming, reloading, firing, reloading, and more.

Guns4d.default_controls = {
    controls = {}
}
Guns4d.default_controls.aim = {
    conditions = {"RMB"},
    loop = false,
    timer = 0,
    func = function(self, active, interrupted, data, busy_list, gun, handler)
        if active then
            handler.control_handler.ads = not handler.control_handler.ads
        end
    end
}
Guns4d.default_controls.auto = {
    conditions = {"LMB"},
    loop = true,
    timer = 0,
    func = function(self, active, interrupted, data, busy_list, gun, handler)
        if gun.properties.firemodes[gun.current_firemode] == "auto" then
            while true do
                local success = gun:attempt_fire()
                if not success then
                    break
                end
            end
        end
    end
}
Guns4d.default_controls.jump_cancel_ads = {
    conditions = {"jump"},
    loop = false,
    timer = 0,
    func = function(self, active, interrupted, data, busy_list, gun, handler)
        if active then
            handler.control_handler.ads = false
        end
    end
}
Guns4d.default_controls.firemode = {
    conditions = {"sneak", "zoom"},
    loop = false,
    timer = 0,
    func = function(self, active, interrupted, data, busy_list, gun, handler)
        if active then
            if not (busy_list.on_use or busy_list.auto) then
                gun:cycle_firemodes()
            end
        end
    end
}

--[[Guns4d.default_controls.toggle_safety = {
    conditions = {"sneak", "zoom"},
    loop = false,
    timer = 2,
    func = function(active, interrupted, data, busy_list, gun, handler)
        local safety = "a real variable here"
        if safety and not data.timer_set then

        end
        if not (busy_list.on_use or busy_list.auto) then

        end
    end
}]]
Guns4d.default_controls.on_use = function(self, itemstack, handler, pointed_thing, busy_list)
    local gun = handler.gun
    local fmode = gun.properties.firemodes[gun.current_firemode]
    if fmode ~= "safe" and not (gun.burst_queue > 0) then
        local fired = gun:attempt_fire()
        if (fmode == "burst") then
            gun.burst_queue = gun.properties.burst-((fired and 1) or 0)
        end
    end
    --handler.control_handler.busy_list.on_use = true
end




local reload_actions = {}
function Guns4d.default_controls.register_reloading_state_type(name, def)
    assert(type(def)=="table", "improper definition type")
    assert(type(def.on_completion)=="function", "action has no completion function") --return a bool (or nil) indicating wether to progress. Nil returns the function (breaking out of the reload cycle.)
    assert(type(def.validation_check)=="function") --return bool indicating wether it is valid. If nil it is assumed to be valid
    reload_actions[name] = def
end
local reg_mstate = Guns4d.default_controls.register_reloading_state_type

reg_mstate("unload_mag", {
    on_completion = function(gun, ammo_handler, next_state) --what happens when the timer is completed.
        if next_state and next_state.action == "store" then
            ammo_handler:set_unloading(true) --if interrupted it will drop to ground, so just make it appear as if the gun is already unloaded in hotbar
        else
            ammo_handler:unload_magazine(true) --unload to ground if it's not going to be stored next state
        end
        return true --true indicates to move to the next action. If false it would replay the same state, if nil it would break out of the function and not continue until reset entirely.
    end,
    validation_check = function(gun, ammo_handler, next_state)
        if ammo_handler.ammo.loaded_mag == "empty" then
            return false --indicates that the state is not valid, this moves to the next state. If true then it is valid and it will start the reload action. Nil breaks out entirely.
        end
        return true
    end
})

reg_mstate("store", {
    on_completion = function(gun, ammo_handler, next_state)
        --[[local pause = false
        --needs to happen before so we don't detect the ammo we just unloaded
        if not ammo_handler:inventory_has_ammo() then
            pause=true
        end]]
        if gun.properties.ammo.magazine_only and (ammo_handler.ammo.loaded_mag ~= "empty") then
            ammo_handler:unload_magazine()
        else
            ammo_handler:unload_all()
        end
        --if there's no ammo make hold so you don't reload the same ammo you just unloaded.
        --[[if pause then
            return
        end
        return true]]
    end,
    validation_check = function(gun, ammo_handler, next_state)
        if gun.properties.ammo.magazine_only and (ammo_handler.ammo.loaded_mag == "empty") then
            return false
        end
        return true
    end,
    interrupt = function(gun, ammo_handler)
        if gun.properties.ammo.magazine_only and (ammo_handler.ammo.loaded_mag ~= "empty") then
            ammo_handler:unload_magazine(true) --"true" is for to_ground
        else
            ammo_handler:unload_all(true)
        end
    end
})

reg_mstate("load", {
    on_completion = function(gun, ammo_handler, next_state)
        if gun.properties.ammo.magazine_only then
            ammo_handler:load_magazine()
        else
            ammo_handler:load_flat()
        end

        if (not next_state) or (next_state.action ~= "charge") then
            --chamber the round automatically.
            ammo_handler:chamber_round()
        end
        return true
    end,
    validation_check = function(gun, ammo_handler, next_state)
        if gun.properties.ammo.magazine_only then
            if not ammo_handler:can_load_magazine() then
                return false
            end
        else
            if not ammo_handler:can_load_flat() then
                return false
            end
        end
        return true
    end
})
reg_mstate("load_cartridge_once", {
    on_completion = function(gun, ammo_handler, next_state)
        ammo_handler:load_single_cartridge() --load one time, always continue
        return true
    end,
    validation_check = function(gun, ammo_handler, next_state)
        if (ammo_handler.ammo.total_bullets<gun.properties.ammo.capacity) and ammo_handler:inventory_has_ammo(true) then
            return true
        else
            return false
        end
    end
})
reg_mstate("load_cartridge", {
    on_completion = function(gun, ammo_handler, next_state)
        return not ammo_handler:load_single_cartridge() --it returns wether the cartidge could be loaded
    end,
    validation_check = function(gun, ammo_handler, next_state)
        if (ammo_handler.ammo.total_bullets<gun.properties.ammo.capacity) and ammo_handler:inventory_has_ammo(true) then
            return true
        else
            return false
        end
    end
})
reg_mstate("charge", {
    on_completion = function(gun, ammo_handler)
        ammo_handler:chamber_round()
        return
    end,
    validation_check = function(gun, ammo_handler, next_state)
        if (ammo_handler.ammo.next_bullet ~= "empty") or (ammo_handler.ammo.total_bullets == 0) then
            return false
        else
            return true
        end
    end
})
Guns4d.default_controls.reload = {
    conditions = {"zoom"},
    loop = false,
    mode = "hybrid",
    timer = 0, --1 so we have a call to initialize the timer. This will also mean that data.toggled and data.continue will need to be set manually
    --remember that the data table allows us to store arbitrary data
    func = function(self, active, interrupted, data, busy_list, gun, handler)
        local ammo_handler = gun.ammo_handler
        local props = gun.properties
        if active and not busy_list.firemode then
            if not data.state then
                data.state = 0
            end
            local this_state = props.reload[data.state]
            local next_state_index = data.state
            local next_state = props.reload[next_state_index+1]

            --this elseif chain has gotten egregiously long, so I'll have to create a system for registering these reload states eventually- both for the sake of organization aswell as a modular API.
            if next_state_index == 0 then
                --nothing to do, let animations get set down the line.
                next_state_index = next_state_index + 1
            end

            if this_state then
                assert(reload_actions[this_state.action], "no reload action by the name: "..tostring(this_state.action))
                local result = reload_actions[this_state.action].on_completion(gun, ammo_handler, next_state)
                if result==true then
                    next_state_index = next_state_index + 1
                elseif result == false then
                    --do something?
                elseif result == nil then
                    return
                else
                    error("invalid on_completion return for reload state: "..this_state.action)
                end
            end

            --check that the next states are actually valid, if not, skip them
            local valid_state = false
            while not valid_state do
                next_state = props.reload[next_state_index]
                if next_state then
                    --determine wether the next_state is valid (can actually be completed)
                    assert(reload_actions[next_state.action], "no reload action by the name: "..tostring(next_state.action))
                    local result = reload_actions[next_state.action].validation_check(gun, ammo_handler, next_state)
                    if result==true then
                        valid_state=true
                    elseif result==false then
                        next_state_index = next_state_index + 1
                        next_state = props.reload[next_state_index]
                    elseif result==nil then
                        return
                    else
                        error("invalid validation_check return for reload state: "..this_state.action)
                    end
                else
                    --if the next state doesn't exist, we've reached the end (the gun is reloaded) and we should restart. "continue" so it doesn't continue unless the user lets go of the input button.
                    data.state = 0
                    --data.timer = 0.5
                    data.continue = true
                    return
                end
            end
            --I don't think this is needed given the above.
           --[[ if next_state == nil then
                data.state = 0
                data.timer = 0
                data.continue = true
                return
            else]]
            data.state = next_state_index
            data.timer = next_state.time
            data.continue = false
            if data.current_mode == "toggle" then --this control uses hybrid and therefor may be on either mode.
                data.toggled = true
            end

            local anim = next_state.anim
            if type(next_state.anim) == "string" then
                anim = props.visuals.animations[next_state.anim]
                if not anim then
                    minetest.log("error", "improperly set gun reload animation, animation not found `"..next_state.anim.."`, gun `"..gun.itemstring.."`")
                end
            end
            if anim then
                if anim.x and anim.y then
                    gun:set_animation(anim, next_state.time)
                else
                    minetest.log("error", "improperly set gun reload animation, reload state `"..next_state.action.."`, gun `"..gun.itemstring.."`")
                end
            end
            if next_state.sounds then
                local sounds
                if type(next_state.sounds) == "table" then
                    sounds = Guns4d.table.deep_copy(props.reload[next_state_index].sounds)
                elseif type(next_state.sounds) == "string" then
                    assert(props.sounds[next_state.sounds], "no sound by the name of "..next_state.sounds)
                    sounds = Guns4d.table.deep_copy(props.sounds[next_state.sounds])
                end
                sounds.pos = gun.pos
                data.played_sounds = {gun:play_sounds(sounds)}
            end
            --print(dump(next_state_index))
            --end
        elseif interrupted then
            local this_state = props.reload[data.state]
            if this_state and reload_actions[this_state.action].interrupt then
                reload_actions[this_state.action].interrupt(gun, ammo_handler)
            end
            if data.played_sounds then
                Guns4d.stop_sounds(data.played_sounds)
                data.played_sounds = nil
            end
            gun:clear_animation()
            data.state = 0
        end
    end
}