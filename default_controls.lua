Guns4d.default_controls = {
    controls = {}
}
Guns4d.default_controls.aim = {
    conditions = {"RMB"},
    loop = false,
    timer = 0,
    func = function(active, interrupted, data, busy_list, handler)
        if active then
            handler.control_bools.ads = not handler.control_bools.ads
        end
    end
}
Guns4d.default_controls.fire = {
    conditions = {"LMB"},
    loop = true,
    timer = 0,
    func = function(active, interrupted, data, busy_list, handler)
        if not handler.control_handler.busy_list.on_use then
            handler.gun:attempt_fire()
        end
    end
}
Guns4d.default_controls.reload = {
    conditions = {"zoom"},
    loop = false,
    timer = 0, --1 so we have a call to initialize the timer.
    func = function(active, interrupted, data, busy_list, handler)
        local gun = handler.gun
        local ammo_handler = gun.ammo_handler
        local props = gun.properties
        if active then
            if not data.state then
                data.state = 0
            end
            local this_state = props.reload[data.state]
            local next_state_index = data.state

            if next_state_index == 0 then

                next_state_index = next_state_index + 1

            elseif type(this_state.type) == "function" then

                this_state.type(true, handler, gun)

            elseif this_state.type == "unload" then
                local pause = false
                local next = props.reload[next_state_index+1]
                if (next.type=="load_fractional" or next.type=="load") and (not ammo_handler:inventory_has_ammo()) then
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
                next_state_index = next_state_index +1

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
                local state_changed = false
                next_state = props.reload[next_state_index]
                if next_state then
                    local state_changed = false

                    if next_state.type == "unload" then

                        if props.ammo.magazine_only and (ammo_handler.ammo.loaded_mag == "empty") then
                            state_changed = true
                        end

                    elseif next_state.type == "unload_fractional" then

                        if not ammo_handler.ammo.total_bullets > 0 then
                            state_changed = true
                        end

                    elseif next_state.type == "load" then
                        if props.ammo.magazine_only then
                            if not ammo_handler:can_load_magazine() then
                                state_changed = true
                            end
                        else

                            if not ammo_handler:can_load_flat() then
                                state_changed = true
                            end
                        end
                    end
                    if not state_changed then
                        valid_state=true
                    else
                        next_state_index = next_state_index + 1
                        next_state = props.reload[next_state_index]
                    end
                else
                    data.state = 0
                    data.timer = 0.5
                    data.held = true
                    return
                end
            end
            --check if we're at cycle end
            if next_state == nil then
                data.state = 0
                data.timer = 0
                data.held = true
                return
            else
                data.state = next_state_index
                data.timer = next_state.time
                data.held = false
                local anim = next_state.anim
                if type(next_state.anim) == "string" then
                    anim = props.animations[next_state.anim]
                end
                gun:set_animation(anim, next_state.time)
            end
        elseif interrupted then
            local this_state = props.reload[data.state]
            if this_state and (this_state.type == "unload") and (this_state.interupt == "to_ground") then
                --true indicates to_ground (meaning they will be removed)
                if props.ammo.magazine_only and (ammo_handler.ammo.loaded_mag ~= "empty") then
                    ammo_handler:unload_magazine(true)
                else
                    ammo_handler:unload_all(true)
                end
            end
            gun:clear_animation()
            data.state = 0
        end
    end
}
Guns4d.default_controls.on_use = function(itemstack, handler, pointed_thing)
    handler.gun:attempt_fire()
    handler.control_handler.busy_list.on_use = true
end