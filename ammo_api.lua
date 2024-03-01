
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
    default_empty_loaded_bullets = {},
    registered_bullets = {},
    registered_magazines = {}
}
function Guns4d.ammo.on_hit_player(bullet, force_mmRHA)
end
function Guns4d.ammo.register_bullet(def)
    assert(def.itemstring, "no itemstring")
    assert(minetest.registered_items[def.itemstring], "no item '"..def.itemstring.."' found. Must be a registered item (check dependencies?)")
    Guns4d.ammo.registered_bullets[def.itemstring] = Guns4d.table.fill(Default_bullet, def)
end
function Guns4d.ammo.initialize_mag_data(itemstack, meta)
    meta = meta or itemstack:get_meta()
    meta:set_string("guns4d_loaded_bullets", minetest.serialize({}))
    Guns4d.ammo.update_mag(nil, itemstack, meta)
    return itemstack
end
function Guns4d.ammo.update_mag(def, itemstack, meta)
    def = def or Guns4d.ammo.registered_magazines[itemstack:get_name()]
    meta = meta or itemstack:get_meta()
    local bullets = minetest.deserialize(meta:get_string("guns4d_loaded_bullets"))
    local count = 0
    for i, v in pairs(bullets) do
        count = count + v
    end
    if count > 0 then
        meta:set_string("count_meta", tostring(count).."/"..def.capacity)
    else
        meta:set_string("count_meta",  Guns4d.config.empty_symbol.."/"..tostring(def.capacity))
    end
    return itemstack
end
function Guns4d.ammo.register_magazine(def)
    def = Guns4d.table.fill(Default_mag, def)
    assert(def.accepted_bullets, "missing property def.accepted_bullets. Need specified bullets to allow for loading")
    assert(def.itemstring, "missing item name")
    def.accepted_bullets_set = {} --this table is a "lookup" table, I didn't go to college so I have no idea
    for i, v in pairs(def.accepted_bullets) do
        --TODO: make an actual error/minetest.log
        if not Guns4d.ammo.registered_bullets[v] then print("guns4D: WARNING! bullet "..v.." not registered! is this a mistake?") end
        def.accepted_bullets_set[v] = true
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
            local ammo = minetest.deserialize(meta:get_string("guns4d_loaded_bullets"))
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
    --the magazine item entity
    --print(dump(minetest.registered_entities))
    --[[local ent_def = minetest.registered_entities["__builtin:item"..def.itemstring]
    if def.model then
        ent_def.visual = "mesh"
        ent_def.mesh = def.model
        ent_def.collision_box = {
        -0.5, 0, -0.5,
         0.5, 1, 0.5
        }
        ent_def.on_step = function(self, dt, moveresult)
            if moveresult.touching_ground then
                self.object:set_rotation()
            end
        end
    end]]

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
            minetest.chat_send_all(num_mags)
            if num_mags == 1 then
                if itemstack:get_name()=="" then
                    for i, v in pairs(craft_inv:get_list("craft")) do
                        local name = v:get_name()
                        if (name == def.itemstring) and (v:get_meta():get_string("guns4d_loaded_bullets")=="") then
                            craft_inv:set_stack("craft", i, Guns4d.ammo.initialize_mag_data(v))
                        end
                        if (name~=def.itemstring) and Guns4d.ammo.registered_magazines[name] then
                            return
                        end
                        if (name~="") and (not (name == def.itemstring)) and (not def.accepted_bullets_set[name]) then
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
                         --check if there is a magazine of a different type or multiple mags, also get our mag index
                        if (name==def.itemstring) then
                            mag_stack_index = i
                        else
                            return
                        end
                    end
                    if (not def.accepted_bullets_set[name]) and (name ~= "") and (name~=def.itemstring) then
                        return
                    end
                end
                if not mag_stack_index then return end
                local bullets_unfilled = def.capacity
                local mag_stack = craft_inv:get_stack("craft", mag_stack_index)
                --print(dump(mag_stack:get_name()))
                --print(mag_stack_index)
                local new_ammo_table = minetest.deserialize(mag_stack:get_meta():get_string("guns4d_loaded_bullets"))
                for i, v in pairs(new_ammo_table) do
                    bullets_unfilled = bullets_unfilled - v
                end
                local new_stack = ItemStack(def.itemstring)
                --find the bullets, and fill the new_ammo_table up to any items with counts adding up to bullets_unfilled
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
                return new_stack
            end
        end)
    end
    --register the actual recipe to add ammo to a mag
end

