local Vec = vector
Guns4d = {
    players = {},
    handler_by_ObjRef = {},
    gun_by_ObjRef = {} --used for getting the gun object by the ObjRef of the gun
}
--default config values, config will be added soon:tm:
Guns4d.config = {
    show_mag_inv_ammo_bar = true,
    show_mag_inv_ammo_count = true,
    show_gun_inv_ammo_count = true,
    control_hybrid_toggle_threshold = .3,
    control_held_toggle_threshold = 0,
    empty_symbol = "E",
    default_damage_group = "fleshy",
    infinite_ammo_priv = "guns4d_infinite_ammo",
    interpret_initial_wear_as_ammo = false,
    punch_from_player_not_gun = true,
    vertical_rotation_factor = 10,
    simple_headshot = true, --holdover feature before a more complex system is implemented
    simple_headshot_body_ratio = .75, --percentage of hitbox height that is body.
    default_fov = 80,
    headshot_damage_factor = 1.75,
    enable_touchscreen_command_name = "guns4d_enable_touchmode",
    minimum_supersonic_energy_assumption = 900, --used to determine the energy of a "supersonic" bullet for bullet whizzing sound effects
    default_audio_attenuation_rate = .8, --changes the dropoff rate of sound. Acts as a multiplier for the distance used to calculate inverse square law. Most guns (from the gun packs) set their own, so this is mainly for reloads.
    mix_supersonic_and_subsonic_sounds = true,
    default_pass_sound_mixing_factor = 10,
    third_person_gain_multiplier = 1/3,
    default_penetration_iteration_distance = .25,
    maximum_bullet_holes = 20,
    inventory_listname = "main",
    aim_out_multiplier = 1.5,
    --enable_assert = false,
    realistic_items = false
    --`["official_content.replace_ads_with_bloom"] = false,
    --`["official_content.uses_magazines"] = true
}
local modpath = minetest.get_modpath("guns4d")

local conf = Settings(modpath.."/guns4d_settings.conf"):to_table() or {}
local mt_conf = minetest.settings:to_table() --allow use of MT config for servers that regularly update 4dguns through it's development
for i, v in pairs(Guns4d.config) do
    --Guns4d.config[i] = conf[i] or minetest.settings["guns4d."..i] or Guns4d.config[i]
    --cant use or because it'd evaluate to false if the setting is alse
    if mt_conf["guns4d."..i] ~= nil then
        Guns4d.config[i] = mt_conf["guns4d."..i]
    elseif conf[i] ~= nil then
        Guns4d.config[i] = conf[i]
    end
end

minetest.rmdir(modpath.."/temp", true)
minetest.mkdir(modpath.."/temp")

dofile(modpath.."/misc_helpers.lua")
dofile(modpath.."/item_entities.lua")
dofile(modpath.."/play_sound.lua")
dofile(modpath.."/visual_effects.lua")
dofile(modpath.."/default_controls.lua")
dofile(modpath.."/touch_support.lua")
dofile(modpath.."/block_values.lua")
dofile(modpath.."/ammo_api.lua")
dofile(modpath.."/menus_and_guides.lua")
local path = modpath .. "/classes"
dofile(path.."/Bullet_hole.lua")
dofile(path.."/Bullet_ray.lua")
dofile(path.."/Control_handler.lua")
dofile(path.."/Ammo_handler.lua")
dofile(path.."/Attachment_handler.lua")
dofile(path.."/Sprite_scope.lua")
dofile(path.."/Dynamic_crosshair.lua")
dofile(path.."/Gun.lua") --> loads /classes/gun_construct.lua
dofile(path.."/Player_model_handler.lua")
dofile(path.."/Player_handler.lua")

--model compatibility
path = modpath .. "/models"
dofile(path.."/3darmor/init.lua")

--infinite ammo
minetest.register_privilege(Guns4d.config.infinite_ammo_priv, {
    description = "allows player to have infinite ammo.",
    give_to_singleplayer = false,
    on_grant = function(name, granter_name)
        local handler = Guns4d.players[name]
        handler.infinite_ammo = true
        minetest.chat_send_player(name, "infinite ammo enabled by "..(granter_name or "unknown"))
        if handler.gun then
            handler.gun:update_image_and_text_meta()
        end
    end,
    on_revoke = function(name, revoker_name)
        local handler = Guns4d.players[name]
        handler.infinite_ammo = false
        minetest.chat_send_player(name, "infinite ammo disabled by "..(revoker_name or "unknown"))
        if handler.gun then
            handler.gun:update_image_and_text_meta()
        end
    end,
})
minetest.register_chatcommand("ammoinf", {
    parameters = "player",
    description = "quick toggle infinite ammo",
    privs = {privs=true},
    func = function(caller, arg)
        local trgt
        local args = string.split(arg, " ")
        local set_arg
        if #args > 1 then
            trgt = args[1]
            set_arg = args[2]
        else
            set_arg = args[1]
            trgt = caller
        end
        local handler = Guns4d.players[trgt]
        local set_to
        if set_arg then
            if set_arg == "true" then
                set_to = true
            elseif set_arg ~= "false" then --if it's false we leave it as nil
                minetest.chat_send_player(caller, "cannot toggle ammoinf, invalid value:"..set_arg)
                return
            end
        else
            set_to = not handler.infinite_ammo --if it's false set it to nil, otherwise set it to true.
            if set_to == false then set_to = nil end
        end
        local privs = minetest.get_player_privs(trgt)
        privs[Guns4d.config.infinite_ammo_priv] = set_to
        minetest.set_player_privs(trgt, privs)
        minetest.chat_send_player(caller, "infinite ammo "..((set_to and "granted to") or "revoked from") .." user '"..trgt.."'")
        handler.infinite_ammo = set_to or false
        if handler.gun then
            handler.gun:update_image_and_text_meta()
            handler.player:set_wielded_item(handler.gun.itemstack)
        end
    end
})

--player handling
local player_handler = Guns4d.player_handler
local objref_mtable
minetest.register_on_joinplayer(function(player)
    local pname = player:get_player_name()
    Guns4d.players[pname] = player_handler:new({player=player}) --player handler does just what it sounds like- see classes/Player_handler
    Guns4d.handler_by_ObjRef[player] = Guns4d.players[pname]
    --set the FOV to a predictable value
    player:set_fov(Guns4d.config.default_fov)
    --ObjRef overrides will be integrated into MTUL (eventually TM)
    if not objref_mtable then
        objref_mtable = getmetatable(player)

        local old_set_fov = objref_mtable.set_fov
        Guns4d.old_set_fov = old_set_fov
        function objref_mtable.set_fov(self, ...)
            local handler = Guns4d.handler_by_ObjRef[self]
            local fov = select(1, ...)
            if handler then --check, just in case it's not a player (and thus should throw an error)
                if fov == 0 then
                    fov = Guns4d.config.default_fov
                elseif select(2, ...) == true then
                    fov = Guns4d.config.default_fov*fov
                end
                handler.default_fov = fov
                if handler.fov_lock then return end
            end
            local args = {...}
            args[1] = fov --basically permenantly set the player's fov to 80, making multipliers and resets return there.
            old_set_fov(self, unpack(args))
        end

        local old_get_pos = objref_mtable.get_pos
        function objref_mtable.get_pos(self, ...)
            local gun = Guns4d.gun_by_ObjRef[self]
            local mt_pos = old_get_pos(self, ...)
            if mt_pos then --mods (including this) will frequently use this as a check if an ent is still around.
                if (not gun) or gun.released then
                    return mt_pos
                else
                    local v, _, _ = gun:get_pos()
                    return v
                end
            end
        end
        function objref_mtable._guns4d_old_get_pos(self, ...)
            return old_get_pos(self, ...)
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
                    frame_loop = false
                end
                --so... minetest is stupid, and so it won't let me set something to the same animation twice (utterly fucking brilliant).
                --This means I literally need to flip flop between +1 frames
                frame_range = table.copy(frame_range)
                --minetest.chat_send_all(dump(frame_range))
                if (data.frames.x == frame_range.x and data.frames.y == frame_range.y) and not (frame_range.x==frame_range.y) then
                     --oh yeah, and it only accepts whole frames... because of course.
                    frame_range.x = frame_range.x+1
                    --minetest.chat_send_all("+1")
                end
                --frame_blend = 25
                --minetest.chat_send_all(dump(frame_range))
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



        --[[minetest.after(1, function(playername)
            minetest.get_player_by_name(playername):hud_add({
                hud_elem_type = "compass",
                text = "gun_mrkr.png",
                scale = {x=1, y=1},
                alignment = {x=0,y=0},
                position = {x=.5,y=.5},
                size = {x=200, y=200},
                offset = {x=-.5,y=.5},
                direction = 0
            })
        end, player:get_player_name())]]
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
    Guns4d.players[pname]:prepare_deletion()
    Guns4d.players[pname] = nil
    Guns4d.handler_by_ObjRef[player] = nil
end)

--ticks are rarely used, but still ideal for rare checks with minimal overhead.
TICK = 0
minetest.register_globalstep(function(dt)
    TICK = TICK + 1
    if TICK > 100000 then TICK = 0 end
    for player, handler in pairs(Guns4d.players) do
        if not handler then
            --spawn the player handler. The player handler handles the gun(s),
            --the player's model, and controls
            handler = player_handler:new({player=player})
        end
        handler:update(dt)
            --[[minetest.get_player_by_name(player):hud_add({
                hud_elem_type = "compass",
                text = "gay.png",
                scale = {x=10, y=10},
                alignment = {x=0,y=0},
                offset = {x=-.5,y=-.5},
                direction = 0
            })]]
    end
end)