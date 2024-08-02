
--can't use the default handler's automatic generation because the wielditem and the idle animations cause visual issues.
if minetest.get_modpath("3d_armor") then
    local armor3d_handler = Guns4d.player_model_handler:inherit({
        compatible_meshes = {
            ["3d_armor_character.b3d"] = "guns4d_3d_armor_character.b3d"
        },
    })
    --custom bone orientations...
    --[[function armor3d_handler:update_aiming()
        --gun bones:
        local player = self.player
        local handler = self.handler
        local gun = handler.gun
        local first, _ = player:get_eye_offset()
        local pprops = handler:get_properties()
        local eye_pos = vector.new(0, (pprops.eye_height*10)/pprops.visual_size.y, 0)+vector.divide(first, pprops.visual_size)
        if handler.control_handler.ads then
            eye_pos.x = ((handler.horizontal_offset*10)/pprops.visual_size.x) --horizontal_offset already is eye_offset on x
        end
        local player_axial_offset = gun.total_offsets.player_axial
        player:set_bone_position(self.bone_aliases.hipfire, self.offsets.relative.arm_right, {x=-player_axial_offset.x-gun.player_rotation.x, y=180-player_axial_offset.y, z=0})
        --print(self.offsets.global.arm_right)
        --player:set_bone_position(self.bone_aliases.reticle, eye_pos, vector.new(combined.x, 180-combined.y, 0))
        --can't use paxial dir as it needs to be relative on Y still.
        local dir = vector.rotate(gun.local_paxial_dir, {x=gun.player_rotation.x*math.pi/180,y=0,z=0})
        local rot = vector.dir_to_rotation(dir)*180/math.pi

        --irrlicht uses clockwise rotations, while everything else seemingly uses counter-clockwise. MMM yes, it's an "engine" not sphaghetti
        player:set_bone_position(self.bone_aliases.aim, eye_pos, {x=rot.x,y=180-rot.y,z=0})
    end]]
    armor3d_handler:set_default_handler()
end