local Reflector_sight = {
    texture = "holographic_reflection.png",
    scale = 1,
    offset = 1,
    deviation_tolerance = {
        min = .01,
        max = .05,
        depth = .1
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
function Reflector_sight:update(dt)
    if self.entity then
        self.entity:set_attach(self.gun.player, self.gun.handler.player_model_handler.bone_aliases.reflector, {x=0,y=0,z=self.offset*10}, nil, true)

        local v1 = leef.math.mat4.mul_vec4({}, self.gun:get_rotation_transform(m4, nil, nil, nil,   nil, nil,   nil, nil,    nil,nil,nil), {0,0,self.offset,0})
        local v2 = leef.math.mat4.mul_vec4({}, self.gun:get_rotation_transform(m4, 0, 0, 0,         nil, nil,   nil, nil,  0,0,0), {0,0,self.offset,0})
        --[[local dist = vector.distance({x=v1[1], y=v1[2], z=v1[3]}, {x=v2[1], y=v2[2], z=v2[3]})
        minetest.chat_send_all(dist)
        self.entity:set_properties({
            textures = {
                blank,
                blank,
                blank,
                blank,
                blank,
                self.texture .. "^[opacity:"..255-math.ceil(255*((dist-self.deviation_tolerance.min)/self.deviation_tolerance.max))
            },
        })]]
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