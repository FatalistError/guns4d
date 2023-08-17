Ammo_handler = Instantiatable_class:inherit({
    name = "Ammo_handler",
    construct = function(def)
        if def.instance then
            assert(def.gun, "no gun")
            def.handler = def.gun.handler
            def.inventory = def.handler.inventory
            local meta = def.gun.meta
            local gun = def.gun
            def.ammo = {}
            if gun.properties.ammo then
                if meta:get_string("guns4d_loaded_bullets") == "" then
                    def.ammo.loaded_mag = gun.properties.ammo.comes_with or "empty"
                    def.ammo.next_bullet = "empty"
                    def.ammo.total_bullets = 0
                    def.ammo.loaded_bullets = {}
                    def:update_meta()
                else
                    def.ammo.loaded_mag = meta:get_string("guns4d_loaded_mag")
                    def.ammo.loaded_bullets = minetest.deserialize(meta:get_string("guns4d_loaded_bullets"))
                    def.ammo.total_bullets = meta:get_int("guns4d_total_bullets")
                    def.ammo.next_bullet = meta:get_string("guns4d_next_bullet")
                end
            end
        end
    end
})
--spend the round, return false if impossible.
--updates all properties based on the ammo table, bullets string can be passed directly to avoid duplication (when needed)
function Ammo_handler:update_meta(bullets)
    assert(self.instance, "attempt to call object method on a class")
    local meta = self.gun.meta
    meta:set_string("guns4d_loaded_mag", self.ammo.loaded_mag)
    meta:set_string("guns4d_loaded_bullets", bullets or minetest.serialize(self.ammo.loaded_bullets))
    meta:set_int("guns4d_total_bullets", self.ammo.total_bullets)
    meta:set_string("guns4d_next_bullet", self.ammo.next_bullet)
    self.handler.player:set_wielded_item(self.gun.itemstack)
end
--use a round, called when the gun is shot. Returns a bool indicating success.
function Ammo_handler:spend_round()
    assert(self.instance, "attempt to call object method on a class")
    local bullet_spent = self.ammo.next_bullet
    local meta = self.gun.meta
    --subtract the bullet
    if self.ammo.total_bullets > 0 then
        self.ammo.loaded_bullets[bullet_spent] = self.ammo.loaded_bullets[bullet_spent]-1
        if self.ammo.loaded_bullets[bullet_spent] == 0 then self.ammo.loaded_bullets[bullet_spent] = nil end
        self.ammo.total_bullets = self.ammo.total_bullets - 1
        --set the new current bullet
        if next(self.ammo.loaded_bullets) then
            self.ammo.next_bullet = math.weighted_randoms(self.ammo.loaded_bullets)
            meta:set_string("guns4d_next_bullet", self.ammo.next_bullet)
        else
            self.ammo.next_bullet = "empty"
            meta:set_string("guns4d_next_bullet", "empty")
        end

        self:update_meta()
        return bullet_spent
    end
end
function Ammo_handler:load_magazine()
    assert(self.instance, "attempt to call object method on a class")
    local inv = self.inventory
    local magstack_index
    local highest_ammo = -1
    local gun = self.gun
    local gun_accepts = gun.accepted_magazines
    if self.ammo.loaded_mag ~= "empty" then
        --it's undefined, make assumptions.
        self:unload_all()
    end
    for i, v in pairs(inv:get_list("main")) do
        if gun_accepts[v:get_name()] then
            local meta = v:get_meta()
            --intiialize data if it doesn't exist so it doesnt kill itself
            if meta:get_string("guns4d_loaded_bullets") == "" then
                Guns4d.ammo.initialize_mag_data(v)
                inv:set_stack("main", i, v)
            end
            local ammo = meta:get_int("guns4d_total_bullets")
            if ammo > highest_ammo then
                highest_ammo = ammo
                local has_unaccepted = false
                print(meta:get_string("guns4d_loaded_bullets"))
                for bullet, _ in pairs(minetest.deserialize(meta:get_string("guns4d_loaded_bullets"))) do
                    if not gun.accepted_bullets[bullet] then
                        has_unaccepted = true
                        break
                    end
                end
                if not has_unaccepted then magstack_index = i end
            end
        end
    end
    if magstack_index then
        local magstack = inv:get_stack("main", magstack_index)
        local magstack_meta = magstack:get_meta()
        --get the ammo stuff
        local meta = self.gun.meta

        local bullet_string = magstack_meta:get_string("guns4d_loaded_bullets")
        self.ammo.loaded_mag = magstack:get_name()
        self.ammo.loaded_bullets = minetest.deserialize(bullet_string)
        self.ammo.total_bullets = magstack_meta:get_int("guns4d_total_bullets")
        self.ammo.next_bullet = magstack_meta:get_string("guns4d_next_bullet")
        self:update_meta()

        inv:set_stack("main", magstack_index, "")
        return
    end
end
function Ammo_handler:inventory_has_ammo()
    local inv = self.inventory
    local gun = self.gun
    for i, v in pairs(inv:get_list("main")) do
        if gun.accepted_magazines[v:get_name()] and (v:get_meta():get_int("guns4d_total_bullets")>0) then
            return true
        end
        if (not gun.properties.magazine_only) and gun.accepted_bullets[v:get_name()] then
            return true
        end
    end
    return false
end
function Ammo_handler:can_load_magazine()
    local inv = self.inventory
    local gun = self.gun
    local gun_accepts = gun.accepted_magazines
    for i, v in pairs(inv:get_list("main")) do
        if gun_accepts[v:get_name()] then
            return true
        end
    end
    return false
end

function Ammo_handler:unload_magazine(to_ground)
    assert(self.instance, "attempt to call object method on a class")
    if self.ammo.loaded_mag ~= "empty" then
        minetest.chat_send_all("not empty")
        local inv = self.handler.inventory
        local magstack = ItemStack(self.ammo.loaded_mag)
        local magmeta = magstack:get_meta()
        local gunmeta = self.gun.meta
        --set the mag's meta before updating ours and adding the item.
        magmeta:set_string("guns4d_loaded_bullets", gunmeta:get_string("guns4d_loaded_bullets"))
        magmeta:set_string("guns4d_total_bullets", gunmeta:get_string("guns4d_total_bullets"))
        magmeta:set_string("guns4d_next_bullet", gunmeta:get_string("guns4d_next_bullet"))
        magstack = Guns4d.ammo.update_mag(nil, magstack, magmeta)
        --throw it on the ground if to_ground is true
        local remaining
        if to_ground then
            remaining = magstack
        else
            remaining = inv:add_item("main", magstack)
        end
        --eject leftover or full stack
        if remaining:get_count() > 0 then
            local object = minetest.add_item(self.gun.pos, remaining)
            object:add_velocity(vector.rotate({x=.6,y=-.3,z=.4}, {x=0,y=-self.handler.look_rotation.y*math.pi/180,z=0}))
        end
        self.ammo.loaded_mag = "empty"
        self.ammo.next_bullet = "empty"
        self.ammo.total_bullets = 0
        self.ammo.loaded_bullets = {}
        self:update_meta()
    end
end
--this is used for unloading flat, or unloading as a "clip" aka a feed only magazine, you'd use this for something like an m1 garand. God that ping.
function Ammo_handler:unload_all(to_ground)
    assert(self.instance, "attempt to call object method on a class")
    local inv = self.handler.inventory
    for i, v in pairs(self.ammo.loaded_bullets) do
        local leftover
        --if to_ground is true throw it to the ground
        if to_ground then
            leftover = ItemStack("main", i.." "..tostring(v))
        else
            leftover = inv:add_item("main", i.." "..tostring(v))
        end
        if leftover:get_count() > 0 then --I don't know itemstacks well enough to know if I need this (for leftover stack of add_item)
            local object = minetest.add_item(self.gun.pos, leftover)
            object:add_velocity(vector.rotate({x=.6,y=-.3,z=.4}, {x=0,y=-self.handler.look_rotation.y*math.pi/180,z=0}))
        end
    end
    if self.ammo.loaded_mag ~= "empty" then
        local stack
        if to_ground or Guns4d.ammo.registered_magazines[self.ammo.loaded_mag].hot_eject then
            stack = ItemStack(self.ammo.loaded_mag)
        else
            stack = inv:add_item("main", self.ammo.loaded_mag)
        end
        if stack:get_count() > 0 then
            local object = minetest.add_item(self.gun.pos, stack)
            object:add_velocity(vector.rotate({x=1,y=2,z=.4}, {x=0,y=-self.handler.look_rotation.y*math.pi/180,z=0}))
        end
    end
    self.ammo.loaded_mag = "empty"
    self.ammo.next_bullet = "empty"
    self.ammo.total_bullets = 0
    self.ammo.loaded_bullets = {}
    self:update_meta()
end
function Ammo_handler:load_magless()
    assert(self.instance, "attempt to call object method on a class")
end
function Ammo_handler:unload_magless()
    assert(self.instance, "attempt to call object method on a class")
end
function Ammo_handler:load_fractional()
    assert(self.instance, "attempt to call object method on a class")
end
function Ammo_handler:unload_fractional()
    assert(self.instance, "attempt to call object method on a class")
end
function Ammo_handler:unload_chamber()
    assert(self.instance, "attempt to call object method on a class")
end