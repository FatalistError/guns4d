local Vec = vector
Guns4d = {
    players = {},
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
dofile(path.."/Model_reader.lua")
dofile(path.."/Bullet_ray.lua")
dofile(path.."/Control_handler.lua")
dofile(path.."/Ammo_handler.lua")
dofile(path.."/Sprite_scope.lua")
dofile(path.."/Gun.lua")
dofile(path.."/Player_model_handler.lua")
dofile(path.."/Player_handler.lua")
dofile(path.."/Proxy_table.lua")

Guns4d.Model_bone_handler:new({modelpath="model_reader_test.b3d"})

--load after
path = minetest.get_modpath("guns4d")

local player_handler = Guns4d.player_handler
local objref_mtable
minetest.register_on_joinplayer(function(player)
    local pname = player:get_player_name()
    Guns4d.players[pname] = {
        handler = player_handler:new({player=player})
    }
    player:set_fov(80)

    if not objref_mtable then
        objref_mtable = getmetatable(player)
        --putting this here is hacky as fuck.
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