
Default_bullet = {
    registered = {},
    range = 100,
    force_mmRHA = 1,
    dropoff_mmRHA = 0,
    damage = 0,
}
Default_mag = {
    capacity = 1,
    craft_reload = true
}
Guns4d.ammo = {
    default_empty_loaded_bullets = {
    },
    registered_bullets = {

    },
    registered_magazines = {

    }
}
local max_wear = 65535
function Guns4d.ammo.register_bullet(def)
    assert(def.itemstring, "no itemstring")
    assert(minetest.registered_items[def.itemstring], "no item '"..def.itemstring.."' found. Must be a registered item (check dependencies?)")
    Guns4d.ammo.registered_bullets[def.itemstring] = table.fill(Default_bullet, def)
end
function Guns4d.ammo.initialize_mag_data(itemstack, meta)
    meta = meta or itemstack:get_meta()
    if meta:get_string("guns4d_loaded_bullets") == "" then
        meta:set_string("guns4d_loaded_bullets", minetest.serialize({}))
        itemstack:set_wear(max_wear)
    end
    return itemstack
end
function Guns4d.ammo.update_mag(def, itemstack, meta)
    meta = meta or itemstack:get_meta()
    local bullets = minetest.deserialize(meta:get_string("guns4d_loaded_bullets"))
    local count = 0
    local current_bullet = "empty"
    for i, v in pairs(bullets) do
        current_bullet = i
        count = count + v
    end
    itemstack:set_wear(max_wear-(max_wear*count/def.capacity))
    meta:set_int("guns4d_total_bullets", count)
    meta:set_string("guns4d_next_bullet", current_bullet)
    return itemstack
end

function Guns4d.ammo.register_magazine(def)
    def = table.fill(Default_mag, def)
    assert(def.accepted_bullets, "missing property def.accepted_bullets. Need specified bullets to allow for loading")
    assert(def.itemstring, "missing item name")
    def.accepted_bullets_set = {} --this table is a "lookup" table, I didn't go to college so I have no idea
    for i, v in pairs(def.accepted_bullets) do
        if not Guns4d.ammo.registered_bullets[v] then print("guns4D: WARNING! bullet "..v.." not registered! is this a mistake?") end
        def.accepted_bullets_set[v] = true
    end
    Guns4d.ammo.registered_magazines[def.itemstring] = def
    --register craft prediction
    local old_on_use = minetest.registered_items[def.itemstring].on_use
    minetest.override_item(def.itemstring, {
        on_use = function(itemstack, user, pointed_thing)
            if old_on_use then
                old_on_use(itemstack, user, pointed_thing)
            end
            local meta = itemstack:get_meta()
            local ammo = meta:get_int("guns4d_total_bullets")
            if ammo then
                minetest.chat_send_player(user:get_player_name(), "rounds in magazine:")
                for i, v in pairs(ammo) do
                    minetest.chat_send_player(user:get_player_name(), "    "..i.." : "..tostring(v))
                end
            else
                minetest.chat_send_player(user:get_player_name(), "magazine is empty")
            end
        end
    })
    if def.craft_reload then
        minetest.register_craft_predict(function(itemstack, player, old_craft_grid, craft_inv)
            --initialize all mags
            local num_mags = 0
            for i, v in pairs(craft_inv:get_list("craft")) do
                if v:get_name() == def.itemstring then
                    num_mags = num_mags + 1
                    Guns4d.ammo.initialize_mag_data(v)
                end
            end
            print(num_mags)
            if itemstack:get_name()=="" then
                for i, v in pairs(craft_inv:get_list("craft")) do
                    local name =v:get_name()
                    if name == def.itemstring then
                        craft_inv:set_stack("craft", i, Guns4d.ammo.initialize_mag_data(v))
                    end
                    if (name~=def.itemstring) and Guns4d.ammo.registered_magazines[name] then
                        return
                    end
                    if (name~="") and (not (name == def.itemstring)) and (not def.accepted_bullets_set[name]) then
                        print("name:", dump(def.accepted_bullets_set))
                        return
                    end
                end
                return def.itemstring
            end
        end)
        minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
            if craft_inv:contains_item("craft", def.itemstring) and craft_inv:contains_item("craftpreview", def.itemstring) then
                local mag_stack_index
                local craft_list = craft_inv:get_list("craft")
                --there's basically no way to cleanly avoid two iterations, annoyingly.
                for i, v in pairs(craft_list) do
                    local name = v:get_name()
                    if (name~=def.itemstring) then
                        if Guns4d.ammo.registered_magazines[name] then
                            return
                        end
                    else
                        mag_stack_index = i
                    end
                    if not def.accepted_bullets_set[name] then
                        if (name ~= "") and (name~=def.itemstring) then
                            print("return", "'"..name.."'")
                            return
                        end
                    end
                end
                local bullets_unfilled = def.capacity
                local mag_stack = craft_inv:get_stack("craft", mag_stack_index)
                local new_ammo_table = minetest.deserialize(mag_stack:get_meta():get_string("guns4d_loaded_bullets"))
                for i, v in pairs(new_ammo_table) do
                    bullets_unfilled = bullets_unfilled - v
                end
                local new_stack = ItemStack(def.itemstring)
                for i, v in pairs(craft_list) do
                    local name = v:get_name()
                    if def.accepted_bullets_set[name] then
                        local bullet_stack_count = v:get_count()
                        --check if there's not enough bullets to fill it
                        if bullet_stack_count <= bullets_unfilled then
                            --if not then remove the stack and add it
                            bullets_unfilled = bullets_unfilled - bullet_stack_count
                            new_ammo_table[name] = (new_ammo_table[name] or 0)+bullet_stack_count
                            craft_inv:set_stack("craft", i, "")
                        else
                            --if there is then add the bullets needed to it's index in the table
                            --and subtract.
                            new_ammo_table[name] = (new_ammo_table[name] or 0)+bullets_unfilled
                            v:set_count(bullet_stack_count-bullets_unfilled)
                            craft_inv:set_stack("craft", i, v)
                            bullets_unfilled = 0
                        end
                    end
                end
                mag_stack:set_count(mag_stack:get_count()-1)
                craft_inv:set_stack("craft", mag_stack_index, mag_stack)
                local meta = new_stack:get_meta()
                meta:set_string("guns4d_loaded_bullets", minetest.serialize(new_ammo_table))
                new_stack = Guns4d.ammo.update_mag(def, new_stack, meta)
                --print(new_stack:get_string())
                return new_stack
            end
        end)
    end
    --register the actual recipe to add ammo to a mag
end

