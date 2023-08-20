local player_positions = {}
minetest.register_globalstep(function(dt)

end)

Bullet_hole = Instantiatable_class:inherit({
    unrendered_exptime = 20,
    unrendered_texture = 'bullet_hole.png',
    expiration_time = 60,
    heat_effect = false,
    render_distance = 50,
    deletion_distance = 80,
    timer = 0,
    construct = function(def)
        assert(def.pos)
    end
})
function Bullet_hole:render()
    if self.old_timer then
        --acount for the time lost.
        self.timer = self.old_timer-(self.unrendered_exptime-self.timer)
    end
end
function Bullet_hole:unrender()
    self.old_timer = self.timer
    self.timer = self.unrendered_exptime
    minetest.add_particlespawner({
        pos = self.pos,
        amount = 1,
        time=0,
        exptime = self.unrendered_exptime,
        texture = {
            name = 'bullet_hole.png',
            alpha_tween = {1,0}
        }
    })
    if self.entity:get_pos() then
        self.entity:remove()
    end
end
function Bullet_hole:update()
end
function Bullet_hole:update_ent()
end
minetest.register_entity("guns4d:bullet_hole", {
    initial_properties = {
        visual = "cube",
        visual_size = {x=.15, y=.15, z=0},
        pointable = false,
        static_save = false,
        use_texture_alpha = true,
        textures = {"blank.png", "blank.png", "blank.png", "blank.png", "bullet_hole.png", "blank.png"}
    },
    on_step = function(self, dtime)
        if TICK % 50 then
            local class_inst = self.class_Inst
            if class_inst.timer < 30 then
                local properties = self.object:get_properties()
                properties.textures[5] = 'bullet_hole.png^[opacity:'..(math.floor((12.75*tostring(self.timer/30)))*20)
                self.object:set_properties(properties)
            end
        end
    end
})