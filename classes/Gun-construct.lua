

local gun_default = Guns4d.gun
local mat4 = leef.math.mat4

--[[
*
*
*
==================================INSTANCE CONSTRUCTOR====================================
*
*
*
]]

local function initialize_tracking_meta(self)
    --create ID so we can track switches between weapons, also get some other data.
    local meta = self.itemstack:get_meta()
    self.meta = meta
    if meta:get_string("guns4d_id") == "" then
        local id = tostring(Guns4d.unique_id.generate())
        meta:set_string("guns4d_id", id)
        self.player:set_wielded_item(self.itemstack)
        self.id = id
        self.current_firemode = 1
        meta:set_int("guns4d_firemode", 1)
    else
        self.id = meta:get_string("guns4d_id")
        self.current_firemode = meta:get_int("guns4d_firemode")
    end
end
local function initialize_ammo(self)
    --initialize the ammo handler
    self.ammo_handler = self.properties.subclasses.ammo_handler:new({ --initialize ammo handler from gun and gun metadata.
        gun = self
    })
    self.subclass_instances.ammo_handler = self.ammo_handler
    --draw the gun if properties specify it
    if self.properties.require_draw_on_swap then
        self.ammo_handler.ammo.chambered_round = "empty"
    end
    minetest.after(0, function() if self.ammo_handler.ammo.total_rounds > 0 then self:draw() end end) --call this as soon as the gun is loaded in
    --update metadata
    self:update_image_and_text_meta()
    self.player:set_wielded_item(self.itemstack)
end

local function initialize_physics(self)
    --initialize rotation offsets
    self.total_offsets = {
        gun_axial = vector.new(),
        player_axial = vector.new(),
        gun_trans = vector.new(),
        player_trans = vector.new(),
        look_trans =  vector.new()
    }
    self.offsets = {}
    for offset, tbl in pairs(self.base_class.offsets) do
        self.offsets[offset] = {}
        for i, v in pairs(tbl) do
            if type(v) == "table" and v.x then
                self.offsets[offset][i] = vector.new()
            else
                self.offsets[offset][i] = v
            end
        end
    end
    --self.velocities = Guns4d.table.deep_copy(self.base_class.velocities)
    self.velocities = {}
    for i, tbl in pairs(self.base_class.velocities) do
        self.velocities[i] = {}
        self.velocities[i].gun_axial = vector.new()
        self.velocities[i].player_axial = vector.new()
    end
end

local function initialize_animation_tracking_data(self)
    self.animation_data = { --where animations data is stored.
        runtime = 0,
        length = 0,
        fps = 0,
        frames = {x=0,y=0},
        current_frame = 0,
    }
    self:clear_animation()
    self.player_rotation = vector.new(self.properties.initial_vertical_rotation,0,0)
    self.animation_rotation = vector.new()
    self.animation_translation = vector.new()
end


function gun_default:construct_instance()
    assert(self.handler, "no player handler object provided")
    --instantiate some tables for runtime data
    self.control_handler = self.handler.control_handler
    self.property_modifiers = {}
    self.attached_objects = {}
    self.subclass_instances = {}
    self.particle_spawners = {}
    self.gun_translation = vector.new()
    initialize_physics(self)

    --initialize important stuff
    self.player = self.handler.player
    self:add_entity()
    initialize_tracking_meta(self)

    --basically make the proxy table work as a temporary table for storing property changes without the need for reinstantiation
    local newindex_handler
    local proxy_set = leef.class.proxy_table.set_field_override
    function newindex_handler(p,_,k,v)
        assert(not self.PROXY_MODE_SAFE, "attempt to modify properties table when PROXY_MODE_SAFE is set to false")
        proxy_set(p,k,v)
    end
    self.properties = leef.class.proxy_table.new(self.base_class._PROPERTIES_UNSAFE, newindex_handler)
    self.PROXY_MODE_SAFE = true
    --initialize built in subclasses
    if self.properties.inventory and self.properties.inventory.part_slots then
        self.subclass_instances.part_handler = self.properties.subclasses.part_handler:new({
            gun = self
        })
        self:regenerate_properties()
    end

    --initialize special subclasses
    initialize_ammo(self)
    initialize_animation_tracking_data(self)

    --initialize any remaining subclasses
    for i, class in pairs(self.properties.subclasses) do
        if (not self.subclass_instances[i]) and (i~="part_handler") then
            self.subclass_instances[i] = class:new({
                gun = self
            })
        end
    end
    self.part_handler = self.subclass_instances.part_handler

    if self.custom_construct then self:custom_construct() end
    self:regenerate_properties()
end

--[[
*
*
*
==================================BASE CLASS CONSTRUCTOR======================================
*
*
*
]]
local valid_ctrls = { --for validation of controls.
    up=true,
    down=true,
    left=true,
    right=true,
    jump=true,
    aux1=true,
    sneak=true,
    dig=true,
    place=true,
    LMB=true,
    RMB=true,
    zoom=true,
}

local function validate_controls(props)
    --validate controls, done before properties are filled to avoid duplication.
    if props.control_actions then
        for i, control in pairs(props.control_actions) do
            if (i~="on_use") and (i~="on_secondary_use") and (i~="__replace_old_table") then
                assert(control.conditions, "no conditions provided for control")
                for _, condition in pairs(control.conditions) do
                    if not valid_ctrls[condition] then
                        assert(false, "invalid key: '"..condition.."'")
                    end
                end
            end
        end
    end
end
local function initialize_b3d_animation_data(self, props)
    self.b3d_model = leef.b3d_reader.read_model(props.visuals.mesh)
    self.b3d_model.global_frames = {
        arm_right = {}, --the aim position of the right arm
        arm_left = {}, --the aim position of the left arm
        root_rotation = {},
        root_translation = {}
    }
    --precalculate keyframe "samples" for intepolation.
    local left = leef.b3d_nodes.get_node_by_name(self.b3d_model, self.consts.ARM_LEFT_BONE, true)
    local right = leef.b3d_nodes.get_node_by_name(self.b3d_model, self.consts.ARM_RIGHT_BONE, true)
    local main = assert(leef.b3d_nodes.get_node_by_name(self.b3d_model, self.consts.ROOT_BONE, true), "gun root-bone for "..self.itemstring.." not present in model")
    --we add 2 because we have to add 1 for the loop to make it there if it's a float val, and leef uses a system where frame 0 is 1
    for target_frame = 0, self.b3d_model.node.animation.frames+1, self.consts.KEYFRAME_SAMPLE_PRECISION do
        --we need to check that the bone exists first.
        if left then
            table.insert(self.b3d_model.global_frames.arm_left, vector.new(leef.b3d_nodes.get_node_global_position(self.b3d_model, left, nil, target_frame))*props.visuals.scale)
        else
            self.b3d_model.global_frames.arm_left = nil
        end

        if right then
            table.insert(self.b3d_model.global_frames.arm_right, vector.new(leef.b3d_nodes.get_node_global_position(self.b3d_model, right, nil, target_frame))*props.visuals.scale)
        else
            self.b3d_model.global_frames.arm_right = nil
        end

        --we compose it by the inverse because we need to get the global offset in rotation for the animation rotation offset. I really need to comment more often
        --delta rotation
        local this_transform, this_rotation = leef.b3d_nodes.get_node_global_transform(main, target_frame)
        local rest_transform, rest_rotation = leef.b3d_nodes.get_node_global_transform(main, props.visuals.animations.loaded.x)
        local quat = this_rotation*rest_rotation:inverse()
        local vec3 = vector.new(this_transform[13], this_transform[14], this_transform[15])-vector.new(rest_transform[13], rest_transform[14], rest_transform[15]) --extract translation
        --used to use euler
        table.insert(self.b3d_model.global_frames.root_rotation, quat)
        table.insert(self.b3d_model.global_frames.root_translation, vec3)
    end
    local t, _ = leef.b3d_nodes.get_node_global_transform(main, props.visuals.animations.loaded.x,1)
    self.b3d_model.root_orientation_rest = mat4.new(t)
    self.b3d_model.root_orientation_rest_inverse = mat4.invert(mat4.new(), t)

    --[[local t2 = mat4.from_quaternion(leef.math.quat.new(unpack(main.rotation)))
    self.b3d_model.root_orientation = mat4.new(t2)
    self.b3d_model.root_orientation_inverse = mat4.invert(mat4.new(), t2)]]

    local verts = {}
    self.bones = {}
    --iterate all nodes, check for meshes.
    for i, v in pairs(self.b3d_model.node_paths) do
        if v.mesh then
            --if there's a mesh present transform it's verts into global coordinate system, add add them to them to a big list.
            local transform, _ = leef.b3d_nodes.get_node_global_transform(v, props.visuals.animations.loaded.x, 1)
            for _, vert in ipairs(v.mesh.vertices) do
                vert.pos[4]=1
                table.insert(verts, transform*vert.pos)
            end
        end
    end
    local high_points = {0,0,0,0,0,0}
    for _, v in pairs(verts) do
        for i = 1,3 do
            if high_points[i+3] > v[i] then
                high_points[i+3]=v[i]
            end
            if high_points[i] < v[i] then
                high_points[i]=v[i]
            end
        end
    end
    for i=1,6 do
        high_points[i]=high_points[i]*self.properties.visuals.scale
    end
    self.model_bounding_box = high_points
    self.properties.item = {
        collisionbox = {.2, high_points[2], .2, -.2, high_points[5], -.2},
        selectionbox = {high_points[1]*3, high_points[2], high_points[3], high_points[4]*3, high_points[5], high_points[6]}
    }
end
local function reregister_item(self, props)
    assert(self.itemstring, "no itemstring provided. Cannot create a gun without an associated itemstring.")
    local item_def = minetest.registered_items[self.itemstring]
    assert(rawget(self, "name"), "no name provided in new class")
    assert(rawget(self, "itemstring"), "no itemstring provided in new class")
    assert(props.ammo.capacity or props.ammo.magazine_only, "gun does not accept magazines, but has no set capcity! Please define ammo.capacity")
    assert(item_def, self.itemstring.." : item is not registered.")

    --override methods so control handler can do it's job
    local old_on_use = item_def.on_use
    local old_on_s_use = item_def.on_secondary_use
    local old_on_drop = item_def.on_drop
    self.properties.inventory.inventory_image = item_def.inventory_image
    --override the item to hook in controls. (on_drop needed)
    minetest.override_item(self.itemstring, {
        on_use = function(itemstack, user, pointed_thing)
            Guns4d.players[user:get_player_name()].control_handler:on_use(itemstack, pointed_thing)
            if old_on_use then
                return old_on_use(itemstack, user, pointed_thing)
            end
        end,
        on_secondary_use = function(itemstack, user, pointed_thing)
            Guns4d.players[user:get_player_name()].control_handler:on_secondary_use(itemstack, pointed_thing)
            if old_on_s_use then
                return old_on_s_use(itemstack, user, pointed_thing)
            end
        end,
        on_drop = function(itemstack, user, pos)
            local cancel_drop
            if Guns4d.players[user:get_player_name()].control_handler then
                cancel_drop = Guns4d.players[user:get_player_name()].control_handler:on_drop(itemstack)
            end
            if (not cancel_drop) and old_on_drop then
                return old_on_drop(itemstack, user, pos)
            end
        end
    })
    Guns4d.register_item(self.itemstring, {
        collisionbox = self.properties.item.collisionbox,
        selectionbox = self.properties.item.selectionbox,
        visual_size = 10*self.properties.visuals.scale,
        mesh = self.properties.visuals.mesh,
        textures = self.properties.visuals.textures,
        animation = self.properties.visuals.animations.loaded
    })
end
--accept a chain of indices where the value from old_index overrides new_index
local function warn_deprecation(gun, field, new_field)
    minetest.log("warning", "Guns4d: `"..gun.."` deprecated use of field `"..field.."` in properties. Use `"..new_field.."` instead.")
end
local function patch_deprecated(self)
    local props = self.properties
    --1.2->1.3 (probably missing some.)
    if props.firemode_inventory_overlays then
        warn_deprecation(self.name, "firemode_inventory_overlays", "inventory.firemode_inventory_overlays")
        for i, _ in pairs(props.firemode_inventory_overlays) do
            props.inventory.firemode_inventory_overlays[i] = props.firemode_inventory_overlays[i]
        end
    end
    for _, i in pairs {"ammo_handler", "part_handler", "crosshair", "sprite_scope"} do
        if props[i] then
            warn_deprecation(self.name, i, "subclasses."..i)
            props.subclasses[i] = props[i]
        end
    end
    if props.inventory_image then
        props.inventory.inventory_image = props.inventory_image
        warn_deprecation(self.name, "inventory_image", "inventory.inventory_image")
    end
    if props.inventory_image_magless then
        props.inventory.inventory_image_magless = props.inventory_image_magless
        warn_deprecation(self.name, "inventory_image_magless", "inventory.inventory_image_magless")
    end
    if props.ammo.accepted_bullets then
        props.ammo.accepted_rounds = props.ammo.accepted_bullets
        warn_deprecation(self.name, "ammo.accepted_bullets", "ammo.accepted_rounds")
    end
    if props.flash_offset then
        props.visuals.flash_offset = props.flash_offset
        warn_deprecation(self.name, "flash_offset", "visuals.flash_offset")
    end
end
--========================== MAIN CLASS CONSTRUCTOR ===============================

function gun_default:construct_base_class()

    self._PROPERTIES_UNSAFE = Guns4d.table.fill(self.parent_class.properties, self.properties or {})
    self.properties = self._PROPERTIES_UNSAFE
    self._consts_unsafe = Guns4d.table.fill(self.parent_class.consts, self.consts or {})
    self.consts = self._consts_unsafe

    --versioning and backwards compatibility stuff
    assert(self.consts.VERSION[1]==Guns4d.version[1], "Guns4d gun `"..self.name.." has major version mismatch")
    if self.consts.VERSION[1] ~= Guns4d.version[1] then
        minetest.log("error", "Guns4d gun `"..self.name.."` major version mismatch")
    end
    if self.consts.VERSION[2] ~= Guns4d.version[2] then
        minetest.log("warning", "Guns4d gun `"..self.name.."` minor version mismatch")
    end
    patch_deprecated(self)


    local props = self.properties
    validate_controls(props)
    assert((self.properties.recoil.velocity_correction_factor.gun_axial>=1) and (self.properties.recoil.velocity_correction_factor.player_axial>=1), "velocity correction must not be less than one.")

    initialize_b3d_animation_data(self, props) --this is for animation offsets (like the spritescope uses)

    -- if it's not a template, then create an item, override some props
    if self.name ~= "__template" then
        reregister_item(self, props)
    end
    --create sets. This may need to be put in instances of modifications can change accepted ammos
    self.accepted_rounds = {}
    for _, v in pairs(self.properties.ammo.accepted_rounds) do
        self.accepted_rounds[v] = true
    end
    self.accepted_magazines = {}
    for _, v in pairs(self.properties.ammo.accepted_magazines) do
        self.accepted_magazines[v] = true
    end

    self.properties = leef.class.proxy_table.new(self.properties)
    self.consts = leef.class.proxy_table.new(self.consts)
    Guns4d.gun._registered[self.name] = self --add gun self to the registered table
end