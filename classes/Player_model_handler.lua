local Vec = vector
--[[offsets = {
    head = vector.new(0,6.3,0),
    arm_right = vector.new(-3.15, 5.5, 0),
    arm_right_global = vector.new(-3.15, 11.55, 0), --can be low precision
    arm_left = vector.new(3.15, 5.5, 0),
    arm_left_global = vector.new(3.15, 11.55, 0),
}]]
Guns4d.player_model_handler = {
    offsets = {
        arm = {
            right = Vec.new(-3.15, 11.55, 0),
            rltv_right = Vec.new(-3.15, 5.5, 0),
            left = Vec.new(3.15, 11.55, 0),
            rltv_left = Vec.new(3.15, 5.5, 0)
        },
        head = Vec.new(0,6.3,0)
    },
    handlers = {},
    mesh = "guns3d_character.b3d"
}
local player_model = Guns4d.player_model_handler
function player_model:set_default_handler()
    assert(not self.instance, "cannot set default handler to an instance of a handler")
    player_model.default_handler = self
end
function player_model:get_handler(meshname)
    local selected_handler = player_model.handlers[meshname]
    if selected_handler then return selected_handler end
    return player_model.default_handler
end
function player_model:update()
    assert(self.instance, "attempt to call object method on a class")
    local player = self.player
    local handler = Guns4d.players[player:get_player_name()].handler
    local gun = handler.gun
    local player_axial_offset = gun.offsets.total_offset_rotation.player_axial
    local pitch = player_axial_offset.x+gun.offsets.player_rotation.x
    local combined = player_axial_offset+gun.offsets.total_offset_rotation.gun_axial+Vec.new(gun.offsets.player_rotation.x,0,0)

    local first, second = player:get_eye_offset()
    local eye_pos = vector.new(0, handler:get_properties().eye_height*10, 0)+first
    if handler.control_bools.ads then
        eye_pos.x = handler.horizontal_offset*10
    end
    player:set_bone_position("guns3d_hipfire_bone", self.offsets.arm.rltv_right, vector.new(-(pitch*gun.consts.HIP_PLAYER_GUN_ROT_RATIO), 180-player_axial_offset.y, 0))
    player:set_bone_position("guns3d_reticle_bone", eye_pos, vector.new(combined.x, 180-combined.y, 0))
    player:set_bone_position("guns3d_head", self.offsets.head, {x=pitch,z=0,y=0})

    --can't use paxial dir as it needs to be relative on Y still.
    local dir = vector.rotate(gun.local_paxial_dir, {x=gun.offsets.player_rotation.x*math.pi/180,y=0,z=0})
    local rot = vector.dir_to_rotation(dir)*180/math.pi
    player:set_bone_position("guns3d_aiming_bone", eye_pos, {x=rot.x,y=-rot.y+180,z=0})
end
function player_model:prepare_deletion()
    assert(self.instance, "attempt to call object method on a class")
    local handler = Guns4d.players[self.player:get_player_name()].handler
    local properties = handler:get_properties()
    if minetest.get_modpath("player_api") then
        player_api.set_model(self.player, self.old)
    end
    properties.mesh = self.old
    handler:set_properties(properties)
end
---@diagnostic disable-next-line: duplicate-set-field
function player_model.construct(def)
    if def.instance then
        assert(def.mesh, "model has no mesh")
        assert(def.player, "no player provided")
        local handler = Guns4d.players[def.player:get_player_name()].handler
        local properties = handler:get_properties()
        def.old = properties.mesh
        --set the model
        if minetest.get_modpath("player_api") then
            player_api.set_model(def.player, def.mesh)
        end
        properties.mesh = def.mesh
        handler:set_properties(properties)
    else
        if def.replace then
            player_model.handlers[def.replace] = def
        end
    end
end
Guns4d.player_model_handler = Instantiatable_class:inherit(player_model)
Guns4d.player_model_handler:set_default_handler()

