

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
    self.total_offset_rotation = {
        gun_axial = vector.new(),
        player_axial = vector.new(),
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
    self.particle_spawners = {} --Instantiatable_class only shallow copies. So tables will not change, and thus some need to be initialized.
    self.property_modifiers = {}

    initialize_animation(self)
    initialize_physics(self)

    --properties have been assigned, create necessary objects TODO: completely change this system for selfining them.
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
    self.b3d_model = mtul.b3d_reader.read_model(props.visuals.mesh, true)
    self.b3d_model.global_frames = {
        arm_right = {}, --the aim position of the right arm
        arm_left = {}, --the aim position of the left arm
        rotation = {} --rotation of the gun (this is assumed as gun_axial, but that's probably fucked for holo sight alignments)
    }
    --print(table.tostring(self.b3d_model))
    --precalculate keyframe "samples" for intepolation.
    local left = mtul.b3d_nodes.get_node_by_name(self.b3d_model, props.visuals.arm_left, true)
    local right = mtul.b3d_nodes.get_node_by_name(self.b3d_model, props.visuals.arm_right, true)
    local main = mtul.b3d_nodes.get_node_by_name(self.b3d_model, props.visuals.root, true)
    --we add 2 because we have to add 1 for the loop to make it there if it's a float val, and MTUL uses a system where frame 0 is 1
    for target_frame = 0, self.b3d_model.node.animation.frames+1, self.consts.KEYFRAME_SAMPLE_PRECISION do
        --we need to check that the bone exists first.
        if left then
            table.insert(self.b3d_model.global_frames.arm_left, vector.new(mtul.b3d_nodes.get_node_global_position(self.b3d_model, left, nil, target_frame))/10)
        else
            self.b3d_model.global_frames.arm_left = nil
        end

        if right then
            table.insert(self.b3d_model.global_frames.arm_right, vector.new(mtul.b3d_nodes.get_node_global_position(self.b3d_model, right, nil, target_frame))/10)
        else
            self.b3d_model.global_frames.arm_right = nil
        end

        if main then
            --use -1 as it does not exist and thus will always go to the default resting pose
            --we compose it by the inverse because we need to get the global CHANGE in rotation for the animation rotation offset. I really need to comment more often
            local newvec = (mtul.b3d_nodes.get_node_rotation(self.b3d_model, main, nil, -1):inverse())*mtul.b3d_nodes.get_node_rotation(self.b3d_model, main, nil, target_frame)
            --used to use euler
            table.insert(self.b3d_model.global_frames.rotation, newvec)
        end
    end

    --[[if main then
        local quat = mtul.math.quat.new(main.keys[1].rotation)
        print(dump(main.keys[1]), vector.new(quat:to_euler_angles_unpack(quat)))
    end
    for i, v in pairs(self.b3d_model.global_frames.rotation) do
        print(i, dump(vector.new(v:to_euler_angles_unpack())*180/math.pi))
    end]]
    --print()
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
            local cancel_drop = Guns4d.players[user:get_player_name()].control_handler:on_drop(itemstack)
            if (not cancel_drop) and old_on_drop then
                return old_on_drop(itemstack, user, pos)
            end
        end
    })
    Guns4d.register_item(self.itemstring, {
        collisionbox = self.properties.item.collisionbox,
        selectionbox = self.properties.item.selectionbox,
        mesh = self.properties.visuals.mesh,
        textures = self.properties.visuals.textures,
        animation = self.properties.visuals.animations.loaded
    })
end
local function register_visual_entity(def, props)
    minetest.register_entity(def.name.."_visual", {
        initial_properties = {
            visual = "mesh",
            mesh = props.visuals.mesh,
            textures = props.visuals.textures,
            glow = 0,
            pointable = false,
            static_save = false,
            backface_culling = props.visuals.backface_culling
        },
        on_step = function(self)
            if not self.object:get_attach() then self.object:remove() end
        end
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

    Guns4d.gun.registered[self.name] = self --add gun self to the registered table
    register_visual_entity(self, props)  --register the visual entity
end