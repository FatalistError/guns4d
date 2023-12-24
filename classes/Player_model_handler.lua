local Vec = vector
--[[offsets = {
    head = vector.new(0,6.3,0),
    arm_right = vector.new(-3.15, 5.5, 0),
    arm_right_global = vector.new(-3.15, 11.55, 0), --can be low precision
    arm_left = vector.new(3.15, 5.5, 0),
    arm_left_global = vector.new(3.15, 11.55, 0),
}]]
Guns4d.player_model_handler = {
    handlers = {}, --not for children, this stores a global list of handlers by meshname.
    offsets = {
        global = {
            --right arm (for hipfire bone)
        },
        relative = { --none of these are specifically needed... perhaps delegate this to the
            --left arm
            --right arm
            --head
        },
    },
    inv_rotation = {}, --stores inverse rotation for bone aiming
    --REMEMBER! bones must be named differently from their original model's counterparts, because minetest was written by monkeys who were supervised by clowns. (no way to unset them.)
    bone_names = {
        arm_right = "guns3d_arm_right",
        arm_left = "guns3d_arm_left",
        aim = "guns3d_aiming_bone",
        hipfire = "guns3d_hipfire_bone",
        head = "guns3d_head"
    },
    still_frame = 0, --the frame to take bone offsets from. This system has to be improved in the future (to allow better animation support)- it works for now though.
    compatible_meshes = { --list of meshes and their corresponding partner meshes for this handler.
        ["character.b3d"] = "guns3d_character.b3d"
    },
    fallback_mesh = "guns3d_character.b3d", --if no meshes are found in "compatible_meshes" it chooses this one.
    is_new_default = true --this will set the this to be the default handler.
}
local player_model = Guns4d.player_model_handler
function player_model.set_default_handler(class_or_name)
    assert(class_or_name, "class or mesh name (string) needed. Example: 'character.b3d' sets the default handler to whatever handler is used for character.b3d.")
    local handler = assert(((type(class_or_name) == "table") and class_or_name) or player_model.get_handler(class_or_name), "no handler by the name '"..tostring(class_or_name).."' found.")
    assert(not handler.instance, "cannot set instance of a handler as the default player_model_handler")
    player_model.default_handler = handler
end
function player_model.get_handler(meshname)
    local selected_handler = player_model.handlers[meshname] or player_model.main
    if selected_handler then return selected_handler end
    return player_model.default_handler
end
function player_model:add_compatible_mesh(original, replacement)
    assert(not self.instance, "attempt to call class method on an object. Cannot modify original class from an instance.")
    assert(original and replacement, "one or more parameters missing")
    self.compatible_meshes[original] = replacement
    player_model.handlers[original] = self
end
function player_model:update(dt)
    assert(dt, "delta time (dt) not provided.")
    assert(self.instance, "attempt to call object method on a class")
    local player = self.player
    local handler = self.handler
    local gun = handler.gun
    local player_axial_offset = gun.total_offset_rotation.player_axial
    local pitch = player_axial_offset.x+gun.player_rotation.x

--gun bones:
    local first, second = player:get_eye_offset()
    local eye_pos = vector.new(0, handler:get_properties().eye_height*10, 0)+first
    if handler.control_handler.ads then
        eye_pos.x = handler.horizontal_offset*10
    end
    player:set_bone_position(self.bone_names.hipfire, self.offsets.relative.arm_right, {x=-(pitch*gun.consts.HIP_PLAYER_GUN_ROT_RATIO), y=180-player_axial_offset.y, z=0})
    --player:set_bone_position(self.bone_names.reticle, eye_pos, vector.new(combined.x, 180-combined.y, 0))
    --can't use paxial dir as it needs to be relative on Y still.
    local dir = vector.rotate(gun.local_paxial_dir, {x=gun.player_rotation.x*math.pi/180,y=0,z=0})
    local rot = vector.dir_to_rotation(dir)*180/math.pi

    --irrlicht uses clockwise rotations, while everything else seemingly uses counter-clockwise. MMM yes, it's an "engine" not sphaghetti
    player:set_bone_position(self.bone_names.aim, eye_pos, {x=rot.x,y=180-rot.y,z=0})

    self:update_head(dt)
    self:update_arm_bones(dt)
end

--this is seperate as different models may use different coordinate systems for this. I tried to make it automatic, but irrlicht is a load of trash.
function player_model:update_arm_bones(dt)
    local player = self.player
    local handler = self.handler
    local gun = handler.gun

    local left_bone, right_bone = self.offsets.global.arm_left, self.offsets.global.arm_right
    local left_trgt, right_trgt = gun:get_arm_aim_pos() --this gives us our offsets relative to the gun.
    --get the real position of the gun's bones relative to the player (2nd param true)
    left_trgt = gun:get_pos(left_trgt, true)
    right_trgt = gun:get_pos(right_trgt, true)
    local left_rotation = vector.dir_to_rotation(vector.direction(left_bone, left_trgt))*180/math.pi
    local right_rotation = vector.dir_to_rotation(vector.direction(right_bone, right_trgt))*180/math.pi
    --all of this is pure insanity. There's no logic, or rhyme or reason. Trial and error is the only way to write this garbo.
    left_rotation.x = -left_rotation.x
    right_rotation.x = -right_rotation.x
    player:set_bone_position(self.bone_names.arm_left, self.offsets.relative.arm_left, {x=90, y=0, z=0}-left_rotation)
    player:set_bone_position(self.bone_names.arm_right, self.offsets.relative.arm_right, {x=90, y=0, z=0}-right_rotation)
end
function player_model:update_head(dt)
    local player = self.player
    local handler = self.handler
    local gun = handler.gun
    local player_axial_offset = gun.total_offset_rotation.player_axial
    local pitch = player_axial_offset.x+gun.player_rotation.x
    player:set_bone_position(self.bone_names.head, self.offsets.relative.head, {x=pitch,z=0,y=0})
end
--should be renamed to "release" but, whatever.
function player_model:prepare_deletion()
    assert(self.instance, "attempt to call object method on a class")
    local handler = Guns4d.players[self.player:get_player_name()]
    local properties = handler:get_properties()
    if minetest.get_modpath("player_api") then
        player_api.set_model(self.player, self.old)
    end
    properties.mesh = self.old
    handler:set_properties(properties)
end
--todo: add value for "still_frame" (the frame to take samples from in case 0, 0 is not still.)
---@diagnostic disable-next-line: duplicate-set-field
function player_model.construct(def)
    if def.instance then
        assert(def.player, "no player provided")
        def.handler = Guns4d.players[def.player:get_player_name()]
        local properties = def.handler:get_properties()
        def.old = properties.mesh
        --set the mesh

        properties.mesh = def.compatible_meshes[properties.mesh] or def.fallback_mesh
        def.handler:set_properties(properties)
    else
        for og_mesh, replacement_mesh in pairs(def.compatible_meshes) do
            assert(type(og_mesh)=="string", "mesh to be replaced (index) must be a string!")
            if player_model.handlers[og_mesh] then minetest.log("warning", "Guns4d: mesh '"..og_mesh.."' overridden by a handler class, this will replace the old handler. Is this a mistake?") end
            player_model.handlers[replacement_mesh] = def
        end
        if def.is_new_default then
            player_model.set_default_handler(def)
        end
        local i, v = next(def.compatible_meshes)
        local b3d_table = mtul.b3d_reader.read_model(v, true)
        --[[all of the compatible_meshes should be identical in terms of guns4d specific bones and offsets (arms, head).
        Otherwise a new handler should be different. With new compatibilities]]
        ---@diagnostic disable-next-line: redefined-local
        for i, v in pairs({"arm_right", "arm_left", "head"}) do
            --print(def.bone_names[v])
            local node = mtul.b3d_nodes.get_node_by_name(b3d_table, def.bone_names[v], true)

            local transform, rotation = mtul.b3d_nodes.get_node_global_transform(node, def.still_frame)

            def.offsets.relative[v] = vector.new(node.position[1], node.position[2], node.position[3])
            def.offsets.global[v] = vector.new(transform[13], transform[14], transform[15])/10 --4th column first 3 rows give us our global transform.
            --print(i, mtul.b3d_nodes.get_node_rotation(b3d_table, node, true, def.still_frame))
            def.inv_rotation[v] = rotation:conjugate() --(note this overrides original matrix made in get_node_global_transform)
        end
        def.offsets.global.hipfire = vector.new(mtul.b3d_nodes.get_node_global_position(b3d_table, def.bone_names.arm_right, true, def.still_frame))

        if def.is_new_default then
            player_model.set_default_handler(def)
        end
    end
end
Guns4d.player_model_handler = Instantiatable_class:inherit(player_model)
Guns4d.player_model_handler:set_default_handler()

