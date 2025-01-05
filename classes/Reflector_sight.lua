local Reflector_sight = {
    texture = "holographic_reflection.png",
    scale = 1,
    offset = 1,
    deviation_tolerance = {
        height = .02,
        width = .02,
        deadzone = .0025
    },
}
local blank = "blank.png"
core.register_entity("guns4d:reflector_sight", {
    initial_properties = {
        textures = {
            blank,
            blank,
            blank,
            blank,
            blank,
            Reflector_sight.texture,
        },
        glow = 14,
        visual = "cube",
        visual_size = {x=.1, y=.1, z=.1},
        physical = false,
        shaded = false
    }
})
Reflector_sight.on_construct = function(self)
    self:initialize_entity()
end
local m4 = leef.math.mat4.new()
function Reflector_sight:initialize_entity()
    local obj = minetest.add_entity(self.gun.player:get_pos(), "guns4d:reflector_sight")
    obj:set_properties({
        textures = {
            blank,
            blank,
            blank,
            blank,
            blank,
            self.texture
        },
        visual_size = {x=self.scale/10, y=self.scale/10, z=self.scale/10},
        use_texture_alpha = true
    })
    self.entity = obj
    obj:set_attach(self.gun.player, self.gun.handler.player_model_handler.bone_aliases.reflector, nil, nil, true)
end
local lvec3 = leef.math.vec3
function Reflector_sight:update(dt)
    if self.entity then
        local gun = self.gun
        local player_trans = gun.total_offsets.player_trans
        self.entity:set_attach(self.gun.player, self.gun.handler.player_model_handler.bone_aliases.reflector, {x=0,y=0,z=self.offset*10}, nil, true)

       --[[ local m1 = self.gun:get_rotation_transform(m4, nil, nil, nil,   nil, nil,   nil, nil,    nil,nil,nil)
        --position and offset of our plane
        local normal = lvec3(m1[1], m1[2], m1[3])
        local offset = self.gun:get_pos({x=0,y=0,z=self.offset}, nil, nil, true)
        offset = offset - ((self.player:get_eye_offset()/10)+{x=0,y=0,z=self.player:get_properties().eye_height})
        local ray = {position=lvec3(m1[1], m1[2], m1[3])*(self.offset+1), direction = -lvec3(m1[1], m1[2], m1[3])}
        --this will obviously always intersect, but knowing where is
        local intersect, d = leef.math.intersect.ray_plane(ray, {normal=normal, position=lvec3(offset)})]]

        local offset = self.gun:get_pos({x=0,y=0,z=self.offset}, true, true, true)
        local eye_pos = vector.new()
        eye_pos.x = (player_trans.x + (gun and gun.properties.ads.horizontal_offset or 0))
        eye_pos.y = (player_trans.y + self.gun.handler:get_properties().eye_height)
        eye_pos.z = (player_trans.z)
        --offset relative to eye now
        offset = offset-eye_pos
        local deadzone = self.deviation_tolerance.deadzone
        local width = self.deviation_tolerance.width
        local height = self.deviation_tolerance.height
        local dist_x = (math.abs(offset.x)-((width-deadzone/2)))
        local dist_y = (math.abs(offset.y)-((height-deadzone/2)))

        local distance
        if (dist_x>0) and (dist_y>0) then
            --distance from closest corner
            distance = math.sqrt(dist_x^2 + dist_y^2)
        elseif (dist_x>0) then
            distance = dist_x
        elseif (dist_y>0) then
            distance = dist_y
        else
            distance = 0
        end
        self.entity:set_properties({
            textures = {
                blank,
                blank,
                blank,
                blank,
                blank,
                self.texture.."^[opacity:"..255-math.floor(255*(distance/deadzone))
            },
        })
    else
        self:initialize_entity()
    end
end
function Reflector_sight:prepare_deletion()
    if self.entity then
        self.entity:remove()
    end
end
Guns4d.Reflector_sight = leef.class.new_class:inherit(Reflector_sight)