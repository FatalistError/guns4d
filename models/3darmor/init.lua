
if minetest.get_modpath("3d_armor") then
    local armor3d_handler = Guns4d.player_model_handler:inherit({
        compatible_meshes = {
            ["3d_armor_character.b3d"] = "guns4d_3d_armor_character.b3d"
        }
    })
    armor3d_handler:set_default_handler()
end