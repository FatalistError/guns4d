--- adds 3d items for guns and magazines
-- @script item_entities.lua

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

--- table defining the new 3d entity for a dropped item
-- @field light_source int, equivelant to minetest itemdef version
-- @field size int, the size of the collision box
-- @field mesh string, the mesh to use for the item
-- @field textures table, a list of textures (see minetest entity documentation)
-- @field collisionbox_size, the size of collisionbox in tenths of meters.
-- @field selectionbox vector, xyz scale of the selectionbox
-- @field offset vector, xyz offset of the visual object from the collision and selectionbox. (so that magazines's origin can match their bone.)
-- @table guns4d_itemdef

local defaults = {
    --light_source = 0,
    collisionbox_size = 2,
    visual_size = 1,
    offset = {x=0,y=0,z=0}
}
--- replaces the item entity of the provided item with a 3d entity based on the definition
-- @param itemstring
-- @param def, a @{guns4d_itemdef}
-- @function Guns4d.register_item()
function Guns4d.register_item(itemstring, def)
    assert(minetest.registered_items[itemstring], "item: `"..tostring(itemstring).."` not registered by minetest")
    assert(type(def)=="table", "definition is not a table")
    def = Guns4d.table.fill(defaults, def)
    if not def.selectionbox then
        def.selectionbox = vector.new(def.collisionbox_size, def.collisionbox_size, def.collisionbox_size)
    end
    def.offset = vector.new(def.offset)
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
    local cbox
    local sbox
    local a = item_def.collisionbox_size
    local b = item_def.selectionbox
    if item_def.realistic == true then
       cbox = {-a/20, 0, -a/20, a/20, (a*2)/20, a/20} --we want the collision_box to sit above it.
       sbox = {-b.x/20, 0, -b.z/20, b.x/20, b.y/10, b.z/20, rotate=true}
    else
        cbox = {-a/20, -a/20, -a/20, a/20, a/20, a/20}
        sbox = {-b.x/20, -b.y/20, -b.z/20, b.x/20, b.y/20, b.z/20}
    end
    self.object:set_properties({
        is_visible = true,
        visual = "mesh",
        mesh = item_def.mesh,
        textures = item_def.textures,
        collisionbox = cbox,
        selectionbox = sbox,
        glow = item_def and item_def.light_source and math.floor(def.light_source/2+0.5),
        visual_size = {x=item_def.visual_size,y=item_def.visual_size,z=item_def.visual_size},
        automatic_rotate = (not item_def.realistic) and math.pi * 0.5 * 0.2 / a,
        infotext = stack:get_description(),
    })
    self._collisionbox = cbox
end
local old = def.on_step
print(dump(def))
def.on_step = function(self, dt, mr, ...)
    old(self, dt, mr, ...)
    --icky nesting.
    if mr and mr.touching_ground then
        local item_def = Guns4d.registered_items[ItemStack(self.itemstring):get_name()]
        if item_def and not self._rotated then
            if item_def.realistic then
                self.object:set_properties({
                    automatic_rotate = (not item_def.realistic) and math.pi * 0.5 * 0.2 / item_def.visual_size,
                })
                local rot = self.object:get_rotation()
                self.object:set_rotation({y=rot.y, x=rot.x+(math.pi/2), z=0})
                self._rotated = true
            else
                self.object:set_properties({
                    automatic_rotate = (not item_def.realistic) and math.pi * 0.5 * 0.2 / item_def.visual_size,
                })
                local rot = self.object:get_rotation()
                self.object:set_rotation({y=rot.y, x=0, z=0})
                self._rotated = true
            end
        end
    else
        if self._rotated then
            self.object:set_properties({
                automatic_rotate = 0,
            })
            self._rotated = false
        end
    end
end
minetest.register_entity("guns4d:item", def)