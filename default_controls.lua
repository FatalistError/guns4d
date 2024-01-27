Guns4d.default_controls = {
    controls = {}
}
Guns4d.default_controls.aim = {
    conditions = {"RMB"},
    loop = false,
    timer = 0,
    func = function(active, interrupted, data, busy_list, gun, handler)
        if active then
            handler.control_handler.ads = not handler.control_handler.ads
        end
    end
}
Guns4d.default_controls.auto = {
    conditions = {"LMB"},
    loop = true,
    timer = 0,
    func = function(active, interrupted, data, busy_list, gun, handler)
        if gun.properties.firemodes[gun.current_firemode] == "auto" then
            gun:attempt_fire()
        end
    end
}
Guns4d.default_controls.firemode = {
    conditions = {"sneak", "zoom"},
    loop = false,
    timer = .5,
    func = function(active, interrupted, data, busy_list, gun, handler)
        if not (busy_list.on_use or busy_list.auto) then
            gun:cycle_firemodes()
        end
    end
}
Guns4d.default_controls.on_use = function(itemstack, handler, pointed_thing)
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
Guns4d.default_controls.reload = {
    conditions = {"zoom"},
    loop = false,
    timer = 0, --1 so we have a call to initialize the timer.
    --remember that the data table allows us to store arbitrary data
    func = function(active, interrupted, data, busy_list, gun, handler)
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

            elseif type(this_state.type) == "function" then
                this_state.type(true, handler, gun)

            elseif this_state.type == "unload_mag" then

                next_state_index = next_state_index + 1
                if next_state and next_state.type == "store" then
                    ammo_handler:set_unloading(true) --if interrupted it will drop to ground, so just make it appear as if the gun is already unloaded.
                else
                    ammo_handler:unload_magazine(true) --unload to ground
                end

            elseif this_state.type == "store" then

                local pause = false
                --needs to happen before so we don't detect the ammo we just unloaded
                if next_state and (next_state.type=="load_fractional" or next_state.type=="load") and (not ammo_handler:inventory_has_ammo()) then
                    pause=true
                end
                if props.ammo.magazine_only and (ammo_handler.ammo.loaded_mag ~= "empty") then
                    ammo_handler:unload_magazine()
                else
                    ammo_handler:unload_all()
                end
                --if there's no ammo make hold so you don't reload the same ammo you just unloaded.
                if pause then
                    return
                end
                next_state_index = next_state_index + 1

            --for these two we don't want to continue unless we're done unloading.
            elseif this_state.type == "load" then

                if props.ammo.magazine_only then
                    ammo_handler:load_magazine()
                else
                    ammo_handler:load_flat()
                end

                if not (next_state or (next_state.type ~= "charge")) then
                    --chamber the round automatically.
                    ammo_handler:close_bolt()
                end
                next_state_index = next_state_index + 1

            elseif this_state.type == "charge" then

                next_state_index = next_state_index + 1
                ammo_handler:close_bolt()
                --if not

            elseif this_state.type == "unload_fractional" then
                ammo_handler:unload_fractional()
                if ammo_handler.ammo.total_bullets == 0 then
                    next_state_index = next_state_index + 1
                end

            elseif this_state.type == "load_fractional" then
                ammo_handler:load_fractional()
                if ammo_handler.ammo.total_bullets == props.ammo.capacity then
                    next_state_index = next_state_index + 1
                end

            end

            --typically i'd return, that's not an option.

            --handle the animations.
            local next_state = props.reload[next_state_index]

            --check that the next states are actually valid, if not, skip them
            local valid_state = false
            while not valid_state do
                next_state = props.reload[next_state_index]
                if next_state then
                    --determine wether the next_state is valid (can actually be completed)
                    local invalid_state = false
                    if next_state.type == "store" then

                        if props.ammo.magazine_only and (ammo_handler.ammo.loaded_mag == "empty") then
                            invalid_state = true
                        end
                        --need to check for inventory room, because otherwise we just want to drop it to the ground.
                        --[[
                        if ... then
                            if props.ammo.magazine_only and (ammo_handler.ammo.loaded_mag ~= "empty") then
                                ammo_handler:unload_magazine(true)
                            else
                                ammo_handler:unload_all(true)
                            end
                        end
                        ]]

                    --[[elseif next_state.type == "unload_fractional" then --UNIMPLEMENTED

                        if not ammo_handler.ammo.total_bullets > 0 then
                            invalid_state = true
                        end]]
                    elseif next_state.type == "unload_mag" then

                        if ammo_handler.ammo.loaded_mag == "empty" then
                            invalid_state = true
                        end

                    elseif next_state.type == "load" then
                        --check we have ammo
                        if props.ammo.magazine_only then
                            if not ammo_handler:can_load_magazine() then
                                invalid_state = true
                            end
                        else

                            if not ammo_handler:can_load_flat() then
                                invalid_state = true
                            end
                        end
                    end
                    if not invalid_state then
                        valid_state=true
                    else
                        next_state_index = next_state_index + 1
                        next_state = props.reload[next_state_index]
                    end
                else
                    --if the next state doesn't exist, we've reached the end (the gun is reloaded) and we should restart. "held" so it doesn't continue unless the user lets go of the input button.
                    data.state = 0
                    data.timer = 0.5
                    data.held = true
                    return
                end
            end
            --I don't think this is needed given the above.
           --[[ if next_state == nil then
                data.state = 0
                data.timer = 0
                data.held = true
                return
            else]]
            data.state = next_state_index
            data.timer = next_state.time
            data.held = false
            local anim = next_state.anim
            if type(next_state.anim) == "string" then
                anim = props.visuals.animations[next_state.anim]
            end
            if anim then
                if anim.x and anim.y then
                    gun:set_animation(anim, next_state.time)
                else
                    minetest.log("error", "improperly set gun reload animation, reload state `"..next_state.type.."`, gun `"..gun.itemstring.."`")
                end
            end
            if next_state.sounds then
                local sounds = Guns4d.table.deep_copy(props.reload[next_state_index].sounds)
                sounds.pos = gun.pos
                sounds.max_hear_distance = sounds.max_hear_distance or gun.consts.DEFAULT_MAX_HEAR_DISTANCE
                data.played_sounds = Guns4d.play_sounds(sounds)
            end
            print(dump(next_state_index))
            --end
        elseif interrupted then
            local this_state = props.reload[data.state]
            if this_state and (this_state.type == "store") then
                --if the player was about to store the mag, eject it.
                if props.ammo.magazine_only and (ammo_handler.ammo.loaded_mag ~= "empty") then
                    ammo_handler:unload_magazine(true) --"true" is for to_ground
                else
                    ammo_handler:unload_all(true)
                end
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