--will have to merge with ammo_handler eventually for coherency.
local attachment_handler = mtul.class.new_class:inherit({})
Guns4d.attachment_handler = attachment_handler
function attachment_handler:construct()
    assert(self.gun, "no gun object provided")
    local meta = self.gun.meta

    if self.instance then
        self.modifier = {}
        self.gun.property_modifiers = self.modifier
        self.handler = self.gun.handler
        if meta:get_string("guns4d_attachments") == "" then
            self.attachments = {}
            for i, v in pairs(self.gun.properties.inventory.attachment_slots) do
                self.attachments[i] = {}
                if type(v.default)=="string" then
                    self:add_attachment(v.default)
                end
            end
            meta:set_string("guns4d_attachments", minetest.serialize(self.attachments))
        else
            self.attachments = minetest.deserialize(meta:get_string("guns4d_attachments"))
            --self:update_meta()
        end
    end
end
Guns4d.registered_attachments = {}
function attachment_handler.register_attachment(def)
    assert(def.itemstring, "itemstring field required")
    --assert(def.modifier)
    Guns4d.registered_attachments[def.itemstring] = def
end
function attachment_handler:rebuild_modifiers()
    --rebuild the modifier
    local new_mods = self.modifier
    local index = 1
    --replace indices with modifiers
    for _, v in pairs(self.attachments) do
        for name, _ in pairs(v) do
            if Guns4d.registered_attachments[name].modifier then
                new_mods[index]=Guns4d.registered_attachments[name].modifier
                index = index + 1
            end
        end
    end
    --remove any remaining modifiers
    if index < #new_mods then
        for i=index, #new_mods do
            new_mods[i]=nil
        end
    end
    self.gun.property_modifiers["attachment_handler"] = self.modifier
end
--returns bool indicating success.
function attachment_handler:add_attachment(itemstack, slot)
    assert(self.instance)
    itemstack = ItemStack(itemstack)
    local stackname = itemstack:get_name()
    if self:can_add(itemstack, slot) then
        self.attachments[slot][stackname] = itemstack
        self:rebuild_modifiers()
        return true
    else
        return false
    end
end
function attachment_handler:can_add(itemstack, slot)
    assert(self.instance)
    local name = itemstack:get_name()
    local props = self.gun.properties
    print(slot, dump(self.attachments))
    if Guns4d.registered_attachments[name] and (not self.attachments[slot][name]) and (props.inventory.attachment_slots[slot].allowed) then
        --check if it's allowed, group check required
        for i, v in pairs(props.inventory.attachment_slots[slot].allowed) do
            print(v, name)
            if v==name then
                return true
            end
        end
    else
        return false
    end
end
--returns bool indicating success.
function attachment_handler:remove_attachment(itemstack, slot)
    assert(self.instance)
    local stackname = itemstack:get_name()
    if (self.attachments[slot][stackname]) then
        self.attachments[slot][stackname] = nil
        self:rebuild_modifiers()
    else
        return false
    end
end