--- the API for defining unique ammunition
-- @module ammo_api

Default_bullet = {
    registered = {},
    range = 100,
    force_mmRHA = 1,
    dropoff_mmRHA = 0,
    raw_blunt_damage = 0,
    raw_sharp_damage = 0,
    property_modifier = nil --(function)
}
Default_mag = {
    capacity = 1,
    craft_reload = true
}
Guns4d.ammo = {
    registered_ammo = {},
    registered_magazines = {}
}

--- registers a new round which can be used by guns
-- @tparam ItemStack itemstack
-- @tparam MetaDataRef meta (optional)
-- @compact
-- @display Guns4d.ammo.initialize_mag_data
function Guns4d.ammo.register_round(def)
    assert(def.itemstring, "no itemstring")
    assert(minetest.registered_items[def.itemstring], "no item '"..def.itemstring.."' found. Must be a registered item (check dependencies?)")
    Guns4d.ammo.registered_ammo[def.itemstring] = Guns4d.table.fill(Default_bullet, def)
end
Guns4d.ammo.register_bullet = function(def)
    minetest.log("warning", "deprecated use of Guns4d.ammo.register_bullet. Use Guns4d.register_round")
    Guns4d.ammo.register_round(def)
end

--- initializes a magazine's data
-- @tparam ItemStack itemstack
-- @tparam MetaDataRef meta (optional)
-- @compact
-- @display Guns4d.ammo.initialize_mag_data
function Guns4d.ammo.initialize_mag_data(itemstack, meta)
    meta = meta or itemstack:get_meta()
    meta:set_string("guns4d_loaded_rounds", minetest.serialize({}))
    local loaded
    local spawn = meta:get_int("guns4d_spawn_with_ammo")
    if (spawn > 0) or Guns4d.config.interpret_initial_wear_as_ammo then
        local def = Guns4d.ammo.registered_magazines[itemstack:get_name()]
        loaded = {
            [def.accepted_rounds[1]]=(spawn > 0 and spawn) or math.floor(def.capacity*(1-(itemstack:get_wear()/65535)))
        }
        meta:set_int("guns4d_spawn_with_ammo", 0)
        meta:set_string("guns4d_loaded_rounds", minetest.serialize(loaded))
        itemstack:set_wear(0)
    else
        loaded = minetest.deserialize(meta:get_string("guns4d_loaded_rounds"))
    end
    Guns4d.ammo.update_mag(nil, itemstack, meta)
    return itemstack
end

--- register a magazine so it can be filled with bullets and loaded into a gun
-- @tparam ItemStack itemstack
-- @tparam MetaDataRef meta (optional) just passes it to be used so get_meta() isn't called more then once if it's already yhere
-- @treturn itemstack
-- @compact
-- @display Guns4d.ammo.update_mag
function Guns4d.ammo.update_mag(def, itemstack, meta)
    def = def or Guns4d.ammo.registered_magazines[itemstack:get_name()]
    meta = meta or itemstack:get_meta()
    local rounds = minetest.deserialize(meta:get_string("guns4d_loaded_rounds"))
    local count = 0
    for i, v in pairs(rounds) do
        count = count + v
    end
    if count > 0 then
        meta:set_string("count_meta", tostring(count).."/"..def.capacity)
    else
        meta:set_string("count_meta",  Guns4d.config.empty_symbol.."/"..tostring(def.capacity))
    end
    return itemstack
end

--if you asked me how any of this worked, i could not tell you.

--- register a magazine so it can be filled with bullets and loaded into a gun
-- @param def definition of the magazine
-- @compact
-- @display Guns4d.ammo.register_magazine
function Guns4d.ammo.register_magazine(def)
    def = Guns4d.table.fill(Default_mag, def)
    --deprecated
    if def.accepted_bullets then def.accepted_rounds = def.accepted_bullets; minetest.log("warning", "deprecated use of field `accepted_bullets`. This has been replaced with `accepted_rounds`") end
    assert(def.accepted_rounds, "missing property def.accepted_rounds. Need specified bullets to allow for loading")
    assert(def.itemstring, "missing item name")
    def.accepted_rounds_set = {} --this table is a "lookup" table, I didn't go to college so I have no idea
    for i, v in pairs(def.accepted_rounds) do
        --TODO: make an actual error/minetest.log
        if not Guns4d.ammo.registered_ammo[v] then minetest.log("error", "guns4D: WARNING! bullet "..v.." not registered! is this a mistake?") end --TODO replace with minetest.log
        def.accepted_rounds_set[v] = true
    end
    Guns4d.ammo.registered_magazines[def.itemstring] = def
    --register craft prediction
    local old_on_use = minetest.registered_items[def.itemstring].on_use

    --the actual item. This will be changed.
    minetest.override_item(def.itemstring, {
        on_use = function(itemstack, user, pointed_thing)
            if old_on_use then
                old_on_use(itemstack, user, pointed_thing)
            end
            local meta = itemstack:get_meta()
            local ammo = minetest.deserialize(meta:get_string("guns4d_loaded_rounds"))
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
    --loading and unloading magazines
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
            if num_mags == 1 then
                if itemstack:get_name()=="" then
                    for i, v in pairs(craft_inv:get_list("craft")) do
                        local name = v:get_name()
                        if (name == def.itemstring) and (v:get_meta():get_string("guns4d_loaded_rounds")=="") then
                            craft_inv:set_stack("craft", i, Guns4d.ammo.initialize_mag_data(v))
                        end
                        if (name~=def.itemstring) and Guns4d.ammo.registered_magazines[name] then
                            return
                        end
                        if (name~="") and (not (name == def.itemstring)) and (not def.accepted_rounds_set[name]) then
                            return
                        end
                    end
                    return def.itemstring
                end
            elseif num_mags > 1 then
                return ""
            end
        end)
        minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
            if craft_inv:contains_item("craft", def.itemstring) and craft_inv:contains_item("craftpreview", def.itemstring) then
                local craft_list = craft_inv:get_list("craft")
                --there's basically no way to cleanly avoid two iterations, annoyingly.
                --check for bullets and mags.
                local mag_stack_index
                for i, v in pairs(craft_list) do
                    local name = v:get_name()
                    if Guns4d.ammo.registered_magazines[name] then
                        if (name==def.itemstring) then
                            mag_stack_index = i
                        else
                            return
                        end
                    end
                    if (not def.accepted_rounds_set[name]) and (name ~= "") and (name~=def.itemstring) then
                        return
                    end
                end
                if not mag_stack_index then return end
                local rounds_unfilled = def.capacity
                local mag_stack = craft_inv:get_stack("craft", mag_stack_index)
                local new_ammo_table = minetest.deserialize(mag_stack:get_meta():get_string("guns4d_loaded_rounds"))
                for i, v in pairs(new_ammo_table) do
                    rounds_unfilled = rounds_unfilled - v
                end
                local new_stack = ItemStack(def.itemstring)
                --find the bullets, and fill the new_ammo_table up to any items with counts adding up to bullets_unfilled
                for i, v in pairs(craft_list) do
                    local name = v:get_name()
                    if def.accepted_rounds_set[name] then
                        local bullet_stack_count = v:get_count()
                        --check if there's not enough bullets to fill it
                        if bullet_stack_count <= rounds_unfilled then
                            --if not then remove the stack and add it
                            rounds_unfilled = rounds_unfilled - bullet_stack_count
                            new_ammo_table[name] = (new_ammo_table[name] or 0)+bullet_stack_count
                            craft_inv:set_stack("craft", i, "")
                        else
                            --if there is then add the bullets needed to it's index in the table
                            --and subtract.
                            new_ammo_table[name] = (new_ammo_table[name] or 0)+rounds_unfilled
                            v:set_count(bullet_stack_count-rounds_unfilled)
                            craft_inv:set_stack("craft", i, v)
                            rounds_unfilled = 0
                        end
                    end
                end
                mag_stack:set_count(mag_stack:get_count()-1)
                craft_inv:set_stack("craft", mag_stack_index, mag_stack)
                local meta = new_stack:get_meta()
                meta:set_string("guns4d_loaded_rounds", minetest.serialize(new_ammo_table))
                new_stack = Guns4d.ammo.update_mag(def, new_stack, meta)
                return new_stack
            end
        end)
    end
    --register the actual recipe to add ammo to a mag
end
