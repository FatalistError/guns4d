local Sprite_scope = leef.class.new_class:inherit({
    images = {
        --[[fore = {
            texture = "scope_fore.png",
            scale = {x=13,y=13},
            paxial = false,
        },
        back = {
            texture = "scope_back.png",
            scale = {x=10,y=10},
            opacity_delay = 2,
            paxial = true,
        },]]
        --[[reticle = {
            texture = "gun_mrkr.png",
            scale = {x=.5,y=.5},
            movement_multiplier = 1,
            misalignment_opacity_threshold_angle = 3,
            misalignment_opacity_maximum_angle = 8,
        },]]
        --mask = "blank.png",
    },
    fov_set = false,
    hide_gun = true,
    magnification = 4,
    construct = function(def)
        if def.instance then
            assert(def.gun, "no gun instance provided")
            def.player = def.gun.player
            def.handler = def.gun.handler
            def.elements = {}
            local new_images = Guns4d.table.deep_copy(def.images)
            if def.images then
                def.images = Guns4d.table.fill(new_images, def.images)
            end
            for i, v in pairs(def.images) do
                def.elements[i] = def.player:hud_add{
                    hud_elem_type = "image",
                    position = {x=.5,y=.5},
                    scale = v.scale,
                    text = "blank.png",
                }
            end
        end
    end,
})

Guns4d.sprite_scope = Sprite_scope
--rename to draw?
local vec3_in = vector.new()
local mat4 = leef.math.mat4
local vec4_forward = {0,0,1,0}
local vec4_dir = {0,0,0,0}
local transform = mat4.new()
function Sprite_scope:update()
    local handler = self.handler
    local gun = self.gun
    local control_handler = gun.control_handler
    if handler.wininfo and self.handler.control_handler.ads then
        if not self.fov_set then
            self.fov_set = true
            handler:set_fov(80/self.magnification)
        end
        local ratio = handler.wininfo.size.x/handler.wininfo.size.y
        local pprops = handler:get_properties()
        local hip_trans = gun.properties.ads.offset
        local player_trans = gun.total_offsets.player_trans
        for i, v in pairs(self.elements) do
            local image = self.images[i]
            local projection_pos=image.projection_pos
            local relative_pos
            if projection_pos then
                vec3_in.x = projection_pos.x/10
                vec3_in.y = projection_pos.y/10
                vec3_in.z = projection_pos.z/10
                relative_pos = gun:get_pos(vec3_in, true, true, true)

                relative_pos.x = relative_pos.x - (player_trans.x + (gun and gun.properties.ads.horizontal_offset or 0))
                relative_pos.y = relative_pos.y - hip_trans.y - (player_trans.y + pprops.eye_height)
                relative_pos.z = relative_pos.z - (player_trans.z)
            else
                local r = gun.total_offsets.gun_axial
                local a = gun.animation_rotation
                vec4_dir = mat4.mul_vec4(vec4_dir, gun:get_rotation_transform(transform,nil,nil,nil, nil,nil, 0,0), vec4_forward)
                relative_pos = vec3_in
                relative_pos.x = vec4_dir[1]
                relative_pos.y = vec4_dir[2]
                relative_pos.z = vec4_dir[3]

                --relative_pos = gun:get_dir(true)
            end

            local hud_pos = Guns4d.math.rltv_point_to_hud(relative_pos, 80/self.magnification, ratio)
            --print(i, hud_pos.x, hud_pos.y)
            self.player:hud_change(v, "position", {x=hud_pos.x+.5, y=hud_pos.y+.5})
        end
    elseif self.fov_set then
        self.fov_set = false
        handler:unset_fov()
    end
    local angle =math.sqrt(gun.total_offsets.gun_axial.x^2+gun.total_offsets.gun_axial.y^2)
    for i, v in pairs(self.elements) do
        local def = self.images[i]
        local tex = def.texture
        --"smoother is better" it's not. Apparently, this creates a new image each time. It is, however, cached. So i'd rather have
        --25 possible images, instead of 255.
        local factor = 1
        if def.misalignment_opacity_threshold_angle then
            if def.misalignment_opacity_threshold_angle < angle then
                factor = (factor - ((angle-def.misalignment_opacity_threshold_angle)/def.misalignment_opacity_maximum_angle))
            end
        end
        self.player:hud_change(v, "text", tex.."^[opacity:"..tostring(math.ceil((25.5*control_handler.ads_location))*10))
    end
end
function Sprite_scope:prepare_deletion()
    self.handler:unset_fov()
    for i, v in pairs(self.elements) do
        self.player:hud_remove(v)
    end
end
