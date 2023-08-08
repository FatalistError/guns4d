
Bullet = Instantiatable_class:inherit({
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
})