Ammo_handler = Instantiatable_class:inherit({
    name = "Gun_ammo_handler",
    construct = function(def)
        assert(def.gun)
        def.itemstack = def.gun.itemstack
        def.handler = def.gun.handler
        def.inventory = def.handler.inventory
        local meta = def.gun.meta



        if gun.properties.magazine then
            local mag_meta = meta:get_string("guns4d_loaded_mag")
            if mag_meta == "" then
                meta:set_string("guns4d_loaded_mag", gun.properties.magazine.comes_with or "empty")
                meta:set_string("guns4d_loaded_bullets", minetest.serialize({}))
            else
                def.mag = mag_meta
                def.bullets = minetest.deserialize(meta:get_string("guns4d_loaded_bullets"))
            end
        else
            local bullet_meta = meta:get_string("guns4d_loaded_bullets")
            if bullet_meta == "" then
                meta:set_string("guns4d_loaded_bullets", minetest.serialize({}))
            else
                def.ammo.bullets = minetest.deserailize(bullet_meta)
            end
        end
    end
})
function Gun_ammo:load_mag()
    local inv = self.inventory
    for _, ammunition in pairs(self.gun.accepted_mags) do
        for i = 1, inv:get_size("main") do

        end
    end
    if magstack then
        ammo_table = minetest.deserialize(magstack:get_meta():get_string("ammo"))
        inv:set_stack("main", index, "")
        state = next_state
        state_changed = true
    end
end
function Gun_ammo:unload_mag()
end
function Gun_ammo:load_magless()
end
function Gun_ammo:unload_magless()
end
function Gun_ammo:load_fractional()
end
function Gun_ammo:unload_fractional()
end
function Gun_ammo:unload_chamber()
end