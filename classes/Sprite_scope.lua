local Sprite_scope = Instantiatable_class:inherit({
    images = {
        fore = {
            texture = "scope_fore.png",
            scale = {x=13,y=13},
            movement_multiplier = 1,
            paxial = false,
        },
        back = {
            texture = "scope_back.png",
            scale = {x=10,y=10},
            movement_multiplier = -1,
            opacity_delay = 2,
            paxial = true,
        },
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
function Sprite_scope:update()
    local handler = self.handler
    if handler.wininfo and self.handler.control_handler.ads then
        if not self.fov_set then
            self.fov_set = true
            handler:set_fov(80/self.magnification)
        end
        local dir = self.gun.local_dir
        local ratio = handler.wininfo.size.x/handler.wininfo.size.y

        if handler.ads_location ~= 1 then
            dir = dir + (self.gun.properties.ads.offset+vector.new(self.gun.properties.ads.horizontal_offset,0,0))*0
        end
        local fov = self.player:get_fov()
        local real_aim = Guns4d.rltv_point_to_hud(dir, fov, ratio)
        local anim_aim = Guns4d.rltv_point_to_hud(vector.rotate({x=0,y=0,z=1}, self.gun.animation_rotation*math.pi/180), fov, ratio)
        real_aim.x = real_aim.x+anim_aim.x; real_aim.y = real_aim.y+anim_aim.y

        --print(dump(self.gun.animation_rotation))
        local paxial_aim = Guns4d.rltv_point_to_hud(self.gun.local_paxial_dir, fov, ratio)
        --so custom scopes can do their thing without doing more calcs
        self.hud_projection_real = real_aim
        self.hud_projection_paxial = paxial_aim
        for i, v in pairs(self.elements) do
            if self.images[i].paxial then
                self.player:hud_change(v, "position", {x=(paxial_aim.x*self.images[i].movement_multiplier)+.5, y=(paxial_aim.y*self.images[i].movement_multiplier)+.5})
            else
                self.player:hud_change(v, "position", {x=(real_aim.x*self.images[i].movement_multiplier)+.5, y=(real_aim.y*self.images[i].movement_multiplier)+.5})
            end
        end
    elseif self.fov_set then
        self.fov_set = false
        handler:unset_fov()
    end
    local angle =math.sqrt(self.gun.total_offset_rotation.gun_axial.x^2+self.gun.total_offset_rotation.gun_axial.y^2)
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
        self.player:hud_change(v, "text", tex.."^[opacity:"..tostring(math.ceil((25.5*handler.ads_location))*10))
    end
end
function Sprite_scope:prepare_deletion()
    self.handler:unset_fov()
    for i, v in pairs(self.elements) do
        self.player:hud_remove(v)
    end
end
