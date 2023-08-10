Sprite_scope = Instantiatable_class:inherit({
    images = {
        fore = {
            texture = "scope_fore.png",
            scale = {x=11,y=11},
            movement_multiplier = 1,
        },
        back = {
            texture = "scope_back.png",
            scale = {x=10,y=10},
            movement_multiplier = -1,
        },
        reticle = {
            texture = "gun_mrkr.png",
            scale = {x=1,y=1},
            movement_multiplier = 1,
            misalignment_opacity_threshold_angle = 3,
            misalignment_opacity_maximum_angle = 8,
        },
        --mask = "blank.png",
    },
    hide_gun = true,
    construct = function(def)
        if def.instance then
            assert(def.gun, "no gun instance provided")
            def.player = def.gun.player
            def.handler = def.gun.handler
            def.elements = {}
            local new_images = table.deep_copy(def.images)
            if def.images then
                def.images = table.fill(new_images, def.images)
            end
            def.elements.reticle = def.player:hud_add{
                hud_elem_type = "image",
                position = {x=.5,y=.5},
                scale = def.images.reticle.scale,
                text = "blank.png",
            }
            def.elements.fore = def.player:hud_add{
                hud_elem_type = "image",
                position = {x=.5,y=.5},
                scale = def.images.fore.scale,
                text = "blank.png",
            }
            def.elements.back = def.player:hud_add{
                hud_elem_type = "image",
                position = {x=.5,y=.5},
                scale = def.images.back.scale,
                text = "blank.png",
            }
        end
    end
})
function Sprite_scope:update()
    local handler = self.handler
    if handler.wininfo and self.handler.control_bools.ads then
        local dir = self.gun.local_dir
        local ratio = handler.wininfo.size.x/handler.wininfo.size.y
        local added_pos
        if handler.ads_location ~= 1 then
            dir = dir + (self.gun.properties.ads.offset+vector.new(self.gun.properties.ads.horizontal_offset,0,0))*0
        end
        local v = Point_to_hud(dir, 80, ratio)
        self.player:hud_change(self.elements.reticle, "position", {x=(v.x*self.images.reticle.movement_multiplier)+.5, y=(v.y*self.images.reticle.movement_multiplier)+.5})
        self.player:hud_change(self.elements.fore, "position", {x=(v.x*self.images.fore.movement_multiplier)+.5, y=(v.y*self.images.fore.movement_multiplier)+.5})
        self.player:hud_change(self.elements.back, "position", {x=(v.x*self.images.back.movement_multiplier)+.5, y=(v.y*self.images.back.movement_multiplier)+.5})
        --update textures
    end
    for i, v in pairs(self.elements) do
        local def = self.images[i]
        local tex = def.texture
        --"smoother is better" it's not. Apparently, this creates a new image each time. It is, however, cached. So i'd rather have
        --25 possible images, instead of 255.
        local factor = 1
        if def.misalignment_opacity_threshold_angle then
            local angle = math.sqrt(self.gun.offsets.total_offset_rotation.gun_axial.x^2+self.gun.offsets.total_offset_rotation.gun_axial.y^2)
            if def.misalignment_opacity_threshold_angle < angle then
                factor = (factor - ((angle-def.misalignment_opacity_threshold_angle)/def.misalignment_opacity_maximum_angle))
            end
        end
        self.player:hud_change(v, "text", tex.."^[opacity:"..tostring(math.ceil((25.5*handler.ads_location*factor))*10))
    end
end
function Sprite_scope:prepare_deletion()
    for i, v in pairs(self.elements) do
        self.player:hud_remove(v)
    end
end