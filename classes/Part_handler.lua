
local Part_handler = leef.class.new_class:inherit({})
Guns4d.part_handler = Part_handler
function Part_handler:construct()
    assert(self.gun, "no gun object provided")
    if self.instance then
        local gun = self.gun
        local meta = gun.meta
        self.player = gun.player

        --just a function to warn that there is a cheater...
        local warn_cheater = function(p)
            core.log("warning", "player: `"..p:get_player_name().."` attempted to access another player's (`"..self.player:get_player_name().."`) gun attachment inventory. This is not possible without cheating!")
        end

        --currently there is no support for multiple attachments of the same type in a given slot
        self.invstring = "guns4d_attachment_inv_"..gun.player:get_player_name()
        core.remove_detached_inventory(self.invstring)
        local inv = core.create_detached_inventory(self.invstring, {
            --allow_move = allow_move,
            allow_put = function(_, listname, index, stack, player)
                if player == self.player then
                    local props = gun.properties
                    if props.inventory.part_slots[listname] and self:can_add(stack, listname) then
                        return 1
                    end
                    return 0
                else
                    warn_cheater(player)
                    return 0
                end
            end,
            on_put = function(_, listname, index, stack, _)
                self:add_attachment(stack, listname, index)
            end,

            allow_take = function(inv, listname, index, stack, player)
                if (player == self.player) then
                    if self.parts[listname][index] then
                        return 1
                    else
                        return 0
                    end
                else
                    warn_cheater(player)
                    return 0
                end
            end,
            on_take = function(_, listname, index, _, _)
                self:remove_attachment(index, listname)
            end,

            allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                if player == self.player then
                    if self.parts[from_list][from_index] and self:can_add(inv:get_stack(from_list, from_index), to_list) then --can be removed
                        return 1
                    else
                        return 0
                    end
                else
                    warn_cheater(player)
                    return 0
                end
            end,
            on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                self:remove_attachment(from_index, from_list)
                self:add_attachment(inv:get_stack(to_list, to_index), to_list, to_index)
            end
            --allow_take = allow_take
        })
        self.virtual_inventory = inv
        self.handler = self.gun.handler
        gun.property_modifiers["part_handler"] = function(props)
            for _, slot in pairs(self.parts) do
                for _, stack in pairs(slot) do
                    local mod_def = Guns4d.registered_attachments[stack:get_name()]
                    if mod_def and mod_def.mod then
                        mod_def.mod(props)
                    end
                end
            end
        end
        --initialize attachments
        if self.gun.properties.inventory.part_slots then
            if meta:get_string("guns4d_attachments") == "" then
                self.parts = {}
                for i, partdef in pairs(self.gun.properties.inventory.part_slots) do
                    --set the size of the virtual inventory slot
                    inv:set_size(i, partdef.slots or 1)
                    self.parts[i] = {}
                    if type(partdef.default)=="string" then
                        self:add_attachment(partdef.default)
                    end
                end
                meta:set_string("guns4d_attachments", core.serialize(self.parts))
            else
                self.parts = core.deserialize(meta:get_string("guns4d_attachments"))
                for slotname, slot in pairs(self.parts) do
                    --set the size of the virtual inventory slot
                    inv:set_size(slotname, self.gun.properties.inventory.part_slots[slotname].slots or 1)
                    for i, stack in pairs(slot) do
                        slot[i] = ItemStack(stack)
                        if type(i) == "number" then
                            inv:set_stack(slotname, i, slot[i])
                        else
                            slot[i] = nil
                        end
                    end
                end
            end
        end
    end
end

--[[
    --basically. Done like this to allow for quick lookups of stacks
    attachments = {
        part_slot = { --part slot as defined in properties.inventory.part_slots
            ["item_name"] = ItemStack("item_name . . .")
        }
    }
]]


Guns4d.registered_attachments = {}
function Part_handler.register_attachment(def)
    assert(def.itemstring, "itemstring field required")
    --assert(def.modifier)
    Guns4d.registered_attachments[def.itemstring] = def
end

function Part_handler:update_parts()
    local meta = self.gun.meta
    local new_meta = table.copy(self.parts)
    for _, slot in pairs(new_meta) do
        for stackname, stack in pairs(slot) do
            slot[stackname] = stack:to_string()
        end
    end
    --print(dump(new_meta))
    meta:set_string("guns4d_attachments", core.serialize(new_meta))
    self.handler.player:set_wielded_item(self.gun.itemstack)
end

--returns bool indicating success. Attempts to add the attachment.
function Part_handler:add_attachment(itemstack, slotname, index)
    assert(self.instance)
    itemstack = ItemStack(itemstack)
    if self:can_add(itemstack, slotname) then
        self.parts[slotname][index]=itemstack
        self:update_parts()
        return true
    else
        return false
    end
end
--check if it has a part
function Part_handler:has_part(slotname, itemname)
    for i, v in pairs(self.parts[slotname]) do
        if v and (v:get_name()==itemname) then
            return true
        end
    end
    return false
end
--check if it can be added. WARNING: after a change is made, the gun's regenerate_properties must be called
function Part_handler:can_add(itemstack, slotname)
    assert(self.instance)
    local itemname = itemstack:get_name()
    local props = self.gun.properties
    --if props.inventory.part_slots[slotname][index] then return false end
    --print(slot, dump(self.parts))
    if
        (not self:has_part(slotname, itemname)) and (props.inventory.part_slots[slotname].allowed)
    then
        --check if it's allowed, group check required
        for i, v in pairs(props.inventory.part_slots[slotname].allowed) do
            --print(v, name)
            if v==itemname then
                return true
            end
        end
    else
        return false
    end
end
--returns bool indicating success.
function Part_handler:remove_attachment(index, slot)
    assert(self.instance)
    if self.parts[slot][index] then
        self.parts[slot][index] = nil
        self:update_parts()
        return true
    else
        return false
    end
end

function Part_handler:prepare_deletion()
    --print("prepare_deletion", debug.getinfo(2).short_src, debug.getinfo(2).linedefined)
    core.remove_detached_inventory(self.invstring)
end