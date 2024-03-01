
--register the infinite ammo privelage.
minetest.register_privilege(Guns4d.config.infinite_ammo_priv, {
    description = "allows player to have infinite ammo.",
    give_to_singleplayer = false,
    give_to_admin = true,
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
        handler.gun:update_image_and_text_meta()
        handler.player:set_wielded_item(handler.gun.itemstack)
    end
})