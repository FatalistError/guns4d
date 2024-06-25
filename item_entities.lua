
Guns4d.registered_items = {}
local old_spawn_item = core.spawn_item --didnt know if I had to use core instead of minetest or if they are the same reference, not chancing it though.
core.spawn_item = function(pos, item, ...)
    if item then --if it doesnt exist, let it handle itself...
        local stack = ItemStack(item)
        local name = stack:get_name()
        local def = Guns4d.registered_items[name]
        if def then
            local obj = minetest.add_entity(pos, "guns4d:item")
            if obj then
                obj:get_luaentity():set_item(stack:to_string())
            end
            return obj
        end
    end
    return old_spawn_item(pos, item, ...)
end

local defaults = {
    --light_source = 0,
    visual_size = 1,
    realistic = Guns4d.config.realistic_items,
    backface_culling = false,
    --animation = {x=0,y=0, speed=15, loop=true, blend=nil},
    selectionbox = {-.2,-.2,-.2,   .2,.2,.2},
    collisionbox = (Guns4d.config.realistic_items and {-.2,-.05,-.2,   .2,.15,.2}) or {-.2,-.2,-.2,   .2,.2,.2}
}

function Guns4d.register_item(itemstring, def)
    assert(minetest.registered_items[itemstring], "item: `"..tostring(itemstring).."` not registered by minetest")
    assert(type(def)=="table", "definition is not a table")
    def = Guns4d.table.fill(defaults, def)
    Guns4d.registered_items[itemstring] = def
end

local def = table.copy(minetest.registered_entities["__builtin:item"])
def.visual = "mesh"
def.visual_size = {x=1,y=1,z=1}
def.set_item = function(self, item)
    local stack = ItemStack(item or self.itemstring)


    self.itemstring = stack:to_string()
    if self.itemstring == "" then
        return
    end

    local item_def = Guns4d.registered_items[stack:get_name()]
    --[[local a = item_def.collisionbox_size
    local o = item_def.collisionbox_offset
    local b = item_def.selectionbox
    if item_def.realistic == true then
       cbox = {(-a-o.x)/20, 0-(o.y/20), (-a-o.z)/20, (a-o.x)/20, (a-o.y)/10, (a-o.z)/20} --we want the collision_box to sit above it.
       sbox = {(-b.x-o.x)/20, (-b.y/20), (-b.z-o.z)/20, (b.x-o.x)/20, (b.y/20), (b.z-o.z)/20, rotate=true}
    else
        cbox = {(-a-o.x)/20, (-a-o.y)/20, (-a-o.z)/20, (a-o.x)/20, (a-o.y)/20, (a-o.z)/20}
        sbox = {(-b.x-o.x)/20, (-b.y-o.y)/20, (-b.z-o.z)/20, (b.x-o.x)/20, (b.y-o.y)/20, (b.z-o.z)/20}
    end]]
    local cbox = item_def.collisionbox
    local sbox = item_def.selectionbox
    self.object:set_properties({
        is_visible = true,
        visual = "mesh",
        mesh = item_def.mesh,
        textures = item_def.textures,
        collisionbox = cbox,
        selectionbox = {sbox[1], sbox[2], sbox[3], sbox[4], sbox[5], sbox[6], rotate=true},
        glow = item_def and item_def.light_source and math.floor(def.light_source/2+0.5),
        backface_culling = item_def.backface_culling,
        visual_size = {x=item_def.visual_size,y=item_def.visual_size,z=item_def.visual_size},
        automatic_rotate = ((not item_def.realistic) and math.pi * 0.5 * 0.2 / 5) or nil,
        infotext = stack:get_description(),
    })
    --self._collisionbox = cbox
end
local old = def.on_step
def._respawn = function(self)
    minetest.add_item(self.object:get_pos(), self.itemstring)
end
def.on_step = function(self, dt, mr, ...)
    old(self, dt, mr, ...)
    --icky nesting.
    local item_def
    if not self._guns4d_animation_set then
        item_def = Guns4d.registered_items[ItemStack(self.itemstring):get_name()]
        if item_def then
            local anim = item_def.animation
            if anim then
                self.object:set_animation({x=anim.x, y=anim.y}, anim.speed, anim.blend, anim.loop)
            end
        else
            self:_respawn()
        end
    end
    if mr and mr.touching_ground then
        item_def = item_def or Guns4d.registered_items[ItemStack(self.itemstring):get_name()]
        if item_def and not self._4dguns_rotated then
            if item_def.realistic then
                self.object:set_properties({
                    automatic_rotate = nil
                })
                local rot = self.object:get_rotation()
                self.object:set_rotation({y=rot.y, x=rot.x, z=math.pi*.5})
                self._4dguns_rotated = true
            else
                self.object:set_properties({
                    automatic_rotate = math.pi * 0.5 * 0.2 / item_def.visual_size,
                })
                local rot = self.object:get_rotation()
                self.object:set_rotation({y=rot.y, x=0, z=0})
                self._4dguns_rotated = true
            end
        end
        if not item_def then
            self:_respawn()
        end
    else
        if self._4dguns_rotated then
            self.object:set_properties({
                automatic_rotate = 0,
            })
            self._4dguns_rotated = false
        end
    end
end
minetest.register_entity("guns4d:item", def)