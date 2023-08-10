
Default_bullet = {
    registered = {},
    range = 100,
    force_mmRHA = 1,
    dropoff_mmRHA = 0,
    damage = 0,
    itemstring = "",
    construct = function(def)
        assert(not def.instance, "attempt to create instance of a template")
        assert(rawget(def, "itemstring"), "no string provided to new bullet template")
        assert(minetest.registered_items[def.itemstring], "bullet item is not registered. Check dependencies?")

    end
}
Guns4d.ammo = {
    registered_bullets = {

    },
    registered_magazines = {

    }
}
function Guns4d.ammo.register_bullet(def)
    assert(def.itemstring)
    assert(minetest.registered_items[def.itemstring], "no item '"..def.itemstring.."' found. Must be a registered item (check dependencies?)")
    Guns4d.ammo.registered_bullets[def.itemstring] = table.fill(Default_bullet, def)
end
function Guns4d.ammo.register_magazine(def)
    assert(def.accepted_bullets, "missing property def.accepted_bullets. Need specified bullets to allow for loading")
    for i, v in pairs(def.accepted_bullets) do
        if not Guns4d.ammo.registered_bullets[v] then print("WARNING! bullet "..v.." not registered! is this a mistake?") end
    end
    --register craft prediction
    minetest.register_craft_predict(function(itemstack, player, old_craft_grid, craft_inv)
        if craft_inv:contains_item("craft", def.itemstring) and itemstack:get_name()=="" then
            --potentially give predicted ammo gauge here
            return def.itemstring
        end
    end)
    minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
        if craft_inv:contains_item("craft", def.itemstring) and craft_inv:contains_item("craftpreview", def.itemstring) then
        end
    end)
    --register the actual recipe to add ammo to a mag
end
