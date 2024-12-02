
--- player_model_handler
--
-- ## defining the player model when holding a gun
--
-- each player model should have a "gun holding equivelant". There are numerous reasons for this
-- first and foremost is that because Minetest is a [redacted mindless insults].
-- because of this you cannot unset bone offsets and return to normal animations.
-- Bone offsets are needed for the arms to aim at the gun there's no simple way around this fact.
-- Since every model is different custom behavior has to be defined for most.
--
-- @class player_model_handler
-- @compact

--- player_model_handler fields
-- @table fields
-- @field offsets @{fields.offsets}
Guns4d.player_model_handler = {
    handlers = {}, --not for children, this stores a global list of handlers by meshname.
    -- @table fields.offsets
    offsets = {
        -- a list of offsets relative to the whole model
        global = {
            --right arm (for hipfire bone)
        },
        -- a list of offsets relative to their parents (at rest position)
        relative = { --none of these are specifically needed...
            --left arm
            --right arm
            --head
        },
    },

    --model generation attributes
    override_bones = { --a list of bones to be read and or generated
        Arm_Right  = "guns4d_arm_right",
        Arm_Left = "guns4d_arm_left",
        Head = "guns4d_head"
    },
    new_bones = { --currently only supports empty bones. Sets at identity rotation, position 0, and parentless
        "guns4d_gun_bone",
    },
    bone_aliases = { --names of bones used by the model handler and other parts of guns4d.
        arm_right = "guns4d_arm_right", --this is a needed alias for hipfire position
        arm_left = "guns4d_arm_left",
        head = "guns4d_head",
        gun = "guns4d_gun_bone", --another needed alias
    },
    still_frame = 0, --the frame to take bone offsets from. This system has to be improved in the future (to allow better animation support)- it works for now though.
    auto_generate = true,
    scale = 1, --this is important for autogen
    output_path = minetest.get_modpath("guns4d").."/temp/",
    compatible_meshes = { --list of meshes and their corresponding partner meshes for this handler. Must have the same bones used by guns4d. The first on this list will be read and have it's bone offsets logged for use.
        --["character.b3d"] = "guns4d_character.b3d", this would tell the handler to use guns4d_character.b3d instead of generating a new one based on the override parameters.
        ["character.b3d"] = (leef.paths.media_paths["character.b3d"] and true) or nil, --it is compatible but it has no predefined model, one will be therefore generated using the override_bone_aliases parameters.
    },
    gun_bone_location = vector.new(),
    fallback_mesh = "character.b3d", --if no meshes are found in "compatible_meshes" it chooses this index in "compatible_meshes"
    is_new_default = true --this will set the this to be the default handler.
}
local player_model = Guns4d.player_model_handler
function player_model.set_default_handler(class_or_name)
    assert(class_or_name, "class or mesh name (string) needed. Example: 'character.b3d' sets the default handler to whatever handler is used for character.b3d.")
    local handler = assert(((type(class_or_name) == "class") and class_or_name) or player_model.get_handler(class_or_name), "no handler by the name '"..tostring(class_or_name).."' found.")
    assert(not handler.instance, "cannot set instance of a handler as the default player_model_handler")
    player_model.default_handler = handler
end

function player_model.get_handler(meshname)
    local selected_handler = player_model.handlers[meshname] or player_model.main
    if selected_handler then return selected_handler end
    return player_model.default_handler
end

--[[function player_model:add_compatible_mesh(original, replacement)
    assert(not self.instance, "attempt to call class method on an object. Cannot modify original class from an instance.")
    assert(original and replacement, "one or more parameters missing")
    self.compatible_meshes[original] = replacement
    player_model.handlers[original] = self
end]]

--we store the read file so it can be reused in the constructor if needed.
local model_buffer
local modpath = minetest.get_modpath("guns4d")
function player_model:custom_b3d_generation_parameters(b3d)
    --empty for now, this is for model customizations.
    return b3d
end
function player_model:replace_b3d_bone(b3d)
end
--generates a new guns4d model bases off of the `new_bones` and `bone_overrides` parameters if one does not already exist.
function player_model:generate_b3d_model(name)
    assert(self and name, "error while generating a b3d model. Name not provided or not called as a method.")
    --generate a new model
    local filename = string.sub(name, 1, -5).."_guns4d_temp.b3d"
    local new_path = self.output_path..filename

    --buffer and modify the model
    model_buffer = leef.b3d_reader.read_model(name)
    local b3d = model_buffer
    local replaced = {}
    --add bone... forgot i made this so simple by adding node_paths
    for _, node in pairs(b3d.node_paths) do
        if self.override_bones[node.name] then
            replaced[node.name] = true
            --change the name
            node.name = self.override_bones[node.name]
            --unset rotation because it breaks shit
            local rot = node.rotation
            for i, v in pairs(node.keys) do
                v.rotation = rot
            end
            --node.rotation = {0,0,0,1}
        end
    end
    --check bones were replaced to avoid errors.
    for i, v in pairs(self.override_bones) do
        if (not replaced[i]) and i~="__overfill" then
            error("bone '"..i.."' not replaced with it's guns4d counterpart, bone was not found. Check bone name")
        end
    end
    for i, v in pairs(self.new_bones) do
        table.insert(b3d.node.children, {
            name = v,
            position = {0,0,0},
            scale = {1/self.scale,1/self.scale,1/self.scale},
            rotation = {0,0,0,1},
            children = {},
            bone = {} --empty works?
        })
    end
    --call custom generation parameters...
    b3d=self:custom_b3d_generation_parameters(b3d)
    --write temp model
    local writefile = io.open(new_path, "w+b")
    leef.b3d_writer.write_model_to_file(b3d, writefile)
    writefile:close()

    --send to player media paths
    minetest.after(0, function()
        assert(
            minetest.dynamic_add_media({filepath = new_path}, function()end),
            "failed sending media"
        )
    end)
    leef.paths.media_paths[filename] = new_path
    leef.paths.modname_by_media[filename] = "guns4d"
    return filename

end

-- main update function
function player_model:update(dt)
    --assert(dt, "delta time (dt) not provided.")
    --assert(self.instance, "attempt to call object method on a class")
    self:update_aiming(dt)
    self:update_head(dt)
    self:update_arm_bones(dt)
end

function player_model:update_aiming(dt)
    --gun bones:
    local player = self.player
    local handler = self.handler
    local gun = handler.gun
    local pprops = handler:get_properties()
    local vs = pprops.visual_size

    local player_trans = gun.total_offsets.player_trans --player translation.
    local hip_pos = self.offsets.global.arm_right

    local ip = Guns4d.math.smooth_ratio(handler.control_handler.ads_location or 0)
    local ip_inv = 1-ip
    local pos = self.gun_bone_location --reuse allocated table
    --interpolate between the eye and arm pos
    pos.x = ((hip_pos.x*10*ip_inv) + (player_trans.x*10/vs.y)) + ((gun and gun.properties.ads.horizontal_offset*10*ip/vs.y) or 0 )
    pos.y = ((hip_pos.y*10*ip_inv) + (player_trans.y*10/vs.y)) + (pprops.eye_height*10*ip/vs.y)
    pos.z = ((hip_pos.z*10*ip_inv) + (player_trans.z*10/vs.y))

    local dir = vector.rotate(gun.local_paxial_dir, {x=gun.player_rotation.x*math.pi/180,y=0,z=0})
    local rot = vector.dir_to_rotation(dir)
    player:set_bone_override(self.bone_aliases.gun,
    {
        position = {
            vec={x=pos.x, y=pos.y, z=pos.z},
            absolute = true,
            interpolation=.25
        },
        rotation = {
            vec={x=-rot.x,y=-rot.y,z=0},
            interpolation=.1,
            absolute = true
        }
    })
    pos.x = (pos.x/10)*vs.x
    pos.y = (pos.y/10)*vs.y
    pos.z = (pos.z/10)*vs.z
   -- minetest.chat_send_all(dump(pos))
end

--default arm code, compatible with MTG model.
function player_model:update_arm_bones(dt)
    local player = self.player
    local handler = self.handler
    local gun = handler.gun

    local pprops = handler:get_properties()
    local left_bone, right_bone = vector.multiply(self.offsets.global.arm_left, pprops.visual_size), vector.multiply(self.offsets.global.arm_right, pprops.visual_size)
    local left_trgt, right_trgt = gun:get_arm_aim_pos() --this gives us our offsets relative to the gun.
    --get the real position of the gun's bones relative to the player (2nd param true)
    left_trgt = gun:get_pos(left_trgt, true)
    right_trgt = gun:get_pos(right_trgt, true)
    local left_rotation = vector.dir_to_rotation(vector.direction(left_bone, left_trgt))
    local right_rotation = vector.dir_to_rotation(vector.direction(right_bone, right_trgt))
    --all of this is pure insanity. There's no logic, or rhyme or reason. Trial and error is the only way to write this garbo.
    left_rotation.x = -left_rotation.x
    right_rotation.x = -right_rotation.x
    player:set_bone_override(self.bone_aliases.arm_right, {
        rotation = {
            vec={x=math.pi/2, y=0, z=0}-right_rotation,
            absolute = true
        }
    })
    player:set_bone_override(self.bone_aliases.arm_left, {
        rotation = {
            vec={x=math.pi/2, y=0, z=0}-left_rotation,
            absolute = true
        }
    })
end
--updates the rotation of the head to match the gun.
function player_model:update_head(dt)
    local player = self.player
    local handler = self.handler
    --player:set_bone_position(self.bone_aliases.head, self.offsets.relative.head, {x=handler.look_rotation.x,z=0,y=0})
    player:set_bone_override(self.bone_aliases.head, {
        rotation = {
            vec={x=handler.look_rotation.x*math.pi/180,z=0,y=0},
            absolute = true
        }
    })
end
--should be renamed to "release" but, whatever.
function player_model:prepare_deletion()
    assert(self.instance, "attempt to call object method on a class")
    local handler = Guns4d.players[self.player:get_player_name()]
    local properties = handler:get_properties()
    --[[if minetest.get_modpath("player_api") then
        player_api.set_model(self.player, self.old)
    end]]
    local player = self.player
    player:set_bone_override(self.bone_aliases.arm_left, {})
    player:set_bone_override(self.bone_aliases.arm_right, {})
    player:set_bone_override(self.bone_aliases.head, {})
    properties.mesh = self.old
    handler:set_properties(properties)
end
--todo: add value for "still_frame" (the frame to take samples from in case 0, 0 is not still.)
---@diagnostic disable-next-line: duplicate-set-field
function player_model.construct(def)
    if def.instance then
        assert(def.player, "no player provided")
        def.handler = Guns4d.players[def.player:get_player_name()]
        --set the mesh
        local properties = def.handler:get_properties()
        def.old = properties.mesh
        properties.mesh = def.compatible_meshes[properties.mesh]
        def.gun_bone_location = vector.new()
        if not properties.mesh then
            local fallback = def.compatible_meshes[def.fallback_mesh]
            minetest.log("error", "Player model handler error: no equivelant mesh found for '"..def.old.."'. Using fallback mesh ("..fallback..")")
            properties.mesh = fallback
        end
        def.handler:set_properties(properties)
        --no further aciton required, it e
        -- character.b3d (from player_api) not present, ignore generation.
    elseif (def~=player_model) or (minetest.get_modpath("player_api")) then
        for og_mesh, replacement_mesh in pairs(def.compatible_meshes) do
            assert(type(og_mesh)=="string", "mesh index to be replaced in compatible_meshes must be a string!")
            if player_model.handlers[og_mesh] then minetest.log("warning", "Guns4d: mesh '"..og_mesh.."' overridden by a handler class, this will replace the old handler. Is this a mistake?") end
            player_model.handlers[replacement_mesh] = def
        end

        --find a valid model to read.
        if rawget(def, "auto_generate") then
            --blame mod security, this is dumb.
            assert(rawget(def, "output_path"), "a output path contained within the mod's source files is required to automatically generate models")
        end
        local read_model
        for i, v in pairs(def.compatible_meshes) do
            if type(i)=="string" then
                if (v==true) then
                    if def.auto_generate then
                        def.compatible_meshes[i] = def:generate_b3d_model(i)
                    elseif i~=def.fallback_mesh then
                        def.compatible_meshes[i] = def.compatible_meshes[def.fallback_mesh]
                    else
                        error("improperly set list of compatible_meshes in a player_model_handler inherited class. Fallback mesh "..def.fallback_mesh.." has no assigned mesh and auto_generate is off")
                    end
                end
                read_model=def.compatible_meshes[i]
            end
        end
        assert(read_model, "at least one compatible mesh required by default for autogeneration of offsets")
        local b3d_table = leef.b3d_reader.read_model(read_model, true)
        --[[all of the compatible_meshes should be identical in terms of guns4d specific bones and offsets (arms, head).
        Otherwise a new handler should be different. With new compatibilities]]
        for i, v in pairs(def.bone_aliases) do
            print(def.bone_aliases[i])
            local node = leef.b3d_nodes.get_node_by_name(b3d_table, v, true)
            assert(node, "player model handler: no node found by the name of \""..v.."\" check that it is the correct value, or that it has been correctly overriden to use that name.")
            local transform, _ = leef.b3d_nodes.get_node_global_transform(node, def.still_frame)

            def.offsets.relative[i] = vector.new(node.position[1], node.position[2], node.position[3])
            def.offsets.global[i] = vector.new(transform[13], transform[14], transform[15])/10 --4th column first 3 rows give us our global transform.
            --print(i, leef.b3d_nodes.get_node_rotation(b3d_table, node, true, def.still_frame))
        end
        def.offsets.global.hipfire = vector.new(leef.b3d_nodes.get_node_global_position(b3d_table, def.bone_aliases.arm_right, true, def.still_frame))

        if def.is_new_default then
            player_model.set_default_handler(def)
        end
    end
end
Guns4d.player_model_handler = leef.class.new_class:inherit(player_model)
Guns4d.player_model_handler:set_default_handler()

