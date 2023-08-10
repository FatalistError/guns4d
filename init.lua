local Vec = vector
Guns4d = {
    players = {}
}
local path = minetest.get_modpath("guns4d")
dofile(path.."/misc_helpers.lua")
dofile(path.."/visual_effects.lua")
dofile(path.."/gun_api.lua")
dofile(path.."/block_values.lua")
path = path .. "/classes"
dofile(path.."/Instantiatable_class.lua")
dofile(path.."/Bullet_ray.lua")
dofile(path.."/Control_handler.lua")
dofile(path.."/Sprite_scope.lua")
dofile(path.."/Gun.lua")
dofile(path.."/Player_model_handler.lua")
dofile(path.."/Player_handler.lua")
dofile(path.."/Proxy_table.lua")

--load after
path = minetest.get_modpath("guns4d")

local player_handler = Guns4d.player_handler

minetest.register_on_joinplayer(function(player)
    local pname = player:get_player_name()
    Guns4d.players[pname] = {
        handler = player_handler:new({player=player})
    }
    player:set_fov(80)
end)

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