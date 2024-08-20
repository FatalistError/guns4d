

local gun_default = Guns4d.gun

--[[
*
*
*
==================================INSTANCE CONSTRUCTOR====================================
*
*
*
]]

local function initialize_data(self)
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
    self.ammo_handler = self.properties.ammo_handler:new({ --initialize ammo handler from gun and gun metadata.
        gun = self
    })
    local ammo = self.ammo_handler.ammo
    if self.properties.require_draw_on_swap then
        ammo.next_bullet = "empty"
    end
    minetest.after(0, function() if ammo.total_bullets > 0 then self:draw() end end)
    self:update_image_and_text_meta() --has to be called manually in post as ammo_handler would not exist yet.
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

local function initialize_animation(self)
    self.animation_data = { --where animations data is stored.
        anim_runtime = 0,
        length = 0,
        fps = 0,
        frames = {0,0},
        current_frame = 0,
    }
    self.player_rotation = vector.new(self.properties.initial_vertical_rotation,0,0)
    self.animation_rotation = vector.new()
end

function gun_default:construct_instance()
    assert(self.handler, "no player handler object provided")

    --initialize important data.
    self.player = self.handler.player
    initialize_data(self)
    initialize_ammo(self)

    --unavoidable table instancing
    self.properties = Guns4d.table.fill(self.base_class.properties, self.properties)
    self.property_modifiers = {}
    self.particle_spawners = {}
    self.property_modifiers = {}

    initialize_animation(self)
    initialize_physics(self)

    if self.properties.inventory.attachment_slots then
        self.attachment_handler = self.properties.attachment_handler:new({
            gun = self
        })
    end
    if self.properties.sprite_scope then
        self.sprite_scope = self.properties.sprite_scope:new({
            gun = self
        })
    end
    if self.properties.crosshair then
        self.crosshair = self.properties.crosshair:new({
            gun = self
        })
    end
    if self.custom_construct then self:custom_construct() end
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
            if (i~="on_use") and (i~="on_secondary_use") and (i~="__overfill") then
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
    self.b3d_model = mtul.b3d_reader.read_model(props.visuals.mesh)
    self.b3d_model.global_frames = {
        arm_right = {}, --the aim position of the right arm
        arm_left = {}, --the aim position of the left arm
        rotation = {} --rotation of the gun (this is assumed as gun_axial, but that's probably fucked for holo sight alignments)
    }
    --print(table.tostring(self.b3d_model))
    --precalculate keyframe "samples" for intepolation.
    local left = mtul.b3d_nodes.get_node_by_name(self.b3d_model, self.consts.ARM_LEFT_BONE, true)
    local right = mtul.b3d_nodes.get_node_by_name(self.b3d_model, self.consts.ARM_RIGHT_BONE, true)
    local main = mtul.b3d_nodes.get_node_by_name(self.b3d_model, self.consts.ROOT_BONE, true)
    --we add 2 because we have to add 1 for the loop to make it there if it's a float val, and MTUL uses a system where frame 0 is 1
    for target_frame = 0, self.b3d_model.node.animation.frames+1, self.consts.KEYFRAME_SAMPLE_PRECISION do
        --we need to check that the bone exists first.
        if left then
            table.insert(self.b3d_model.global_frames.arm_left, vector.new(mtul.b3d_nodes.get_node_global_position(self.b3d_model, left, nil, target_frame))*props.visuals.scale)
        else
            self.b3d_model.global_frames.arm_left = nil
        end

        if right then
            table.insert(self.b3d_model.global_frames.arm_right, vector.new(mtul.b3d_nodes.get_node_global_position(self.b3d_model, right, nil, target_frame))*props.visuals.scale)
        else
            self.b3d_model.global_frames.arm_right = nil
        end

        if main then
            --ATTENTION: this is broken, roll is somehow translating to yaw. How? fuck if I know, but I will have to fix this eventually.
            --use -1 as it does not exist and thus will always go to the default resting pose
            --we compose it by the inverse because we need to get the global CHANGE in rotation for the animation rotation offset. I really need to comment more often
            local newvec = (mtul.b3d_nodes.get_node_rotation(self.b3d_model, main, nil, -1):inverse())*mtul.b3d_nodes.get_node_rotation(self.b3d_model, main, nil, target_frame)
            --used to use euler
            table.insert(self.b3d_model.global_frames.rotation, newvec)
        end
    end

    local verts = {}
    self.bones = {}
    --iterate all nodes, check for meshes.
    for i, v in pairs(self.b3d_model.node_paths) do
        if v.mesh then
            --if there's a mesh present transform it's verts into global coordinate system, add add them to them to a big list.
            local transform, _ = mtul.b3d_nodes.get_node_global_transform(v, self.properties.visuals.animations.loaded.x, "transform")
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
    self.properties.inventory_image = item_def.inventory_image
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
--========================== MAIN CLASS CONSTRUCTOR ===============================

function gun_default:construct_base_class()
    local props = self.properties

    --copy the properties
    self.properties = Guns4d.table.fill(self.parent_class.properties, props or {})
    self.consts = Guns4d.table.fill(self.parent_class.consts, self.consts or {})
    props = self.properties
    validate_controls(props)
    assert((self.properties.recoil.velocity_correction_factor.gun_axial>=1) and (self.properties.recoil.velocity_correction_factor.player_axial>=1), "velocity correction must not be less than one.")

    initialize_b3d_animation_data(self, props) --this is for animation offsets (like the spritescope uses)

    -- if it's not a template, then create an item, override some props
    if self.name ~= "__template" then
        reregister_item(self, props)
    end
    --create sets. This may need to be put in instances of modifications can change accepted ammos
    self.accepted_bullets = {}
    for _, v in pairs(self.properties.ammo.accepted_bullets) do
        self.accepted_bullets[v] = true
    end
    self.accepted_magazines = {}
    for _, v in pairs(self.properties.ammo.accepted_magazines) do
        self.accepted_magazines[v] = true
    end
    self.properties = mtul.class.proxy_table:new(self.properties)

    Guns4d.gun._registered[self.name] = self --add gun self to the registered table
end