local Vec = vector
Guns4d = {
    players = {},
    handler_by_ObjRef = {},
    gun_by_ObjRef = {} --used for getting the gun object by the ObjRef of the gun
}
local path = minetest.get_modpath("guns4d")
dofile(path.."/misc_helpers.lua")
dofile(path.."/visual_effects.lua")
dofile(path.."/default_controls.lua")
dofile(path.."/block_values.lua")
dofile(path.."/register_ammo.lua")
path = path .. "/classes"
dofile(path.."/Instantiatable_class.lua")
dofile(path.."/Bullet_ray.lua")
dofile(path.."/Control_handler.lua")
dofile(path.."/Ammo_handler.lua")
dofile(path.."/Sprite_scope.lua")
dofile(path.."/Dynamic_crosshair.lua")
dofile(path.."/Gun.lua")
dofile(path.."/Player_model_handler.lua")
dofile(path.."/Player_handler.lua")
dofile(path.."/Proxy_table.lua")

--load after
path = minetest.get_modpath("guns4d")

local player_handler = Guns4d.player_handler
local objref_mtable
minetest.register_on_joinplayer(function(player)
    local pname = player:get_player_name()
    Guns4d.players[pname] = {
        handler = player_handler:new({player=player})
    }
    Guns4d.handler_by_ObjRef[player] = Guns4d.players[pname].handler
    --set the FOV to a predictable value
    player:set_fov(80)
    --ObjRef overrides will be integrated into MTUL (eventually TM)
    if not objref_mtable then
        objref_mtable = getmetatable(player)
        print(dump(objref_mtable))

        local old_set_fov = objref_mtable.set_fov
        Guns4d.old_set_fov = old_set_fov
        function objref_mtable.set_fov(self, ...)
            local handler = Guns4d.handler_by_ObjRef[self]
            if handler then --check, just in case it's not a player (and thus should throw an error)
                handler.default_fov = select(1, ...)
                if handler.fov_lock then return end
            end
            old_set_fov(self, ...)
        end

        local old_get_pos = objref_mtable.get_pos
        function objref_mtable.get_pos(self)
            local gun = Guns4d.gun_by_ObjRef[self]
            if not gun then
                return old_get_pos(self)
            else
                local v, _, _ = gun:get_pos()
                return v
            end
        end

        local old_set_animation = objref_mtable.set_animation
        --put vargs there for maintainability.
        function objref_mtable.set_animation(self, frame_range, frame_speed, frame_blend, frame_loop, ...)
            local gun = Guns4d.gun_by_ObjRef[self]
            if gun then
                local data = gun.animation_data
                data.runtime = 0
                data.fps = frame_speed or 15
                data.loop = frame_loop
                if frame_loop == nil then --still have no idea what nutjob made the default true >:(
                    frame_loop = true
                end
                --so... minetest is stupid, and so it won't let me set something to the same animation twice (utterly fucking brilliant).
                --This means I literally need to flip flop between +1 frames
                frame_range = (frame_range and table.copy(frame_range)) or {x=1,y=1}
                if data.frames.x == frame_range.x and data.frames.y == frame_range.y then
                    frame_range.y = frame_range.y + 1 --oh yeah, and it only accepts whole frames... because of course.
                end
                data.frames = frame_range
                data.current_frame = data.frames.x
            end
            return old_set_animation(self, frame_range, frame_speed, frame_blend, frame_loop, ...)
        end

        local old_set_frame_speed = objref_mtable.set_animation_frame_speed
        function objref_mtable.set_animation_frame_speed(self, frame_speed, ...)
            local gun = Guns4d.gun_by_ObjRef[self]
            if gun then
                gun.animation_data.fps = frame_speed or 15
            end
            old_set_frame_speed(self, frame_speed, ...)
        end

        local old_remove = objref_mtable.remove
        function objref_mtable.remove(self)
            local gun = Guns4d.gun_by_ObjRef[self]
            if gun then
                Guns4d.gun_by_ObjRef[self] = nil
            end
            return old_remove(self)
        end
    end
end)
--we grab the ObjRef metatable from the first available source.
--because we want guns to function as real objects, we have to override the metatable get_pos() for all objects
--this is made more efficient by using a table lookup for ObjRefs we want to update properly.
--"uns4d[ObjRef] = gun" is declared on_activate() in the entity.
--[[minetest.after(0, function()

end)]]
minetest.register_on_leaveplayer(function(player)
    local pname = player:get_player_name()
    Guns4d.players[pname].handler:prepare_deletion()
    Guns4d.players[pname] = nil
    Guns4d.handler_by_ObjRef[player] = nil
end)

--ticks are rarely used, but still ideal for rare checks with minimal overhead.
TICK = 0
minetest.register_globalstep(function(dt)
    TICK = TICK + 1
    if TICK > 100000 then TICK = 0 end
    for player, obj in pairs(Guns4d.players) do
        if not obj.handler then
            --spawn the player handler. The player handler handles the gun(s),
            --the player's model, and controls
            obj.handler = player_handler:new({player=player})
        end
        obj.handler:update(dt)
    end
end)