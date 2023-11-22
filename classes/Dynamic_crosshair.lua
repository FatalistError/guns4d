local Dynamic_crosshair = Instantiatable_class:inherit({
    increments = 1, --the number of pixels the reticle moves per frame.
    frames = 32, --this defines the length of the sprite sheet. But it also helps us know how wide it is (since we have increments.)
    image = "dynamic_crosshair_circular.png",
    scale = 3,
    normalize_walking = true,
    normalize_breathing = true,
    normalize_sway = true,
    old_walking_vec = vector.new(),
    construct = function(def)
        if def.instance then
            assert(def.gun, "no gun instance provided")
            def.player = def.gun.player
            def.handler = def.gun.handler
            def.width = def.frames/def.increments
            def.hud = def.player:hud_add{
                hud_elem_type = "image",
                position = {x=.5,y=.5},
                scale = {x=def.scale,y=def.scale},
                text = def.image.."^[verticalframe:"..def.frames..":0",
            }
        end
    end
})
Guns4d.dynamic_crosshair = Dynamic_crosshair
local function absolute_vector(v)
    return {x=math.abs(v.x), y=math.abs(v.y), z=math.abs(v.z)}
end
--really wish there was a better way to do this.
local function render_length(rotation, fov)
    local dir = vector.rotate({x=0,y=0,z=1}, {x=rotation.x*math.pi/180,y=0,z=0})
    vector.rotate(dir,{x=0,y=rotation.y*math.pi/180,z=0})
    local out = Point_to_hud(dir, fov, 1)
    return math.sqrt(out.x^2+out.y^2)
end
function Dynamic_crosshair:update(dt)
    assert(self.instance, "attemptr to call object method on a class")
    local handler = self.handler
    local gun = self.gun
    if handler.wininfo and not handler.control_bools.ads then
        local fov = self.player:get_fov()
        --we have to recalc the rough direction, otherwise walking will look wonky.
        local temp_vector = vector.new()

        for offset, v in pairs(gun.offsets) do
            if (offset ~= "walking" or not self.normalize_walking) and (offset ~= "breathing" or not self.normalize_breathing) and (offset ~= "sway" or not self.normalize_sway) then
                temp_vector = temp_vector + absolute_vector(v.player_axial) + absolute_vector(v.gun_axial)
            end
        end
        if gun.consts.HAS_SWAY and self.normalize_sway then
            local max_angle =
                gun.properties.sway.max_angle.gun_axial*gun.multiplier_coefficient(gun.properties.sway.hipfire_angle_multiplier.gun_axial, 1-handler.ads_location)
                + gun.properties.sway.max_angle.player_axial*gun.multiplier_coefficient(gun.properties.sway.hipfire_angle_multiplier.player_axial, 1-handler.ads_location)
            temp_vector = temp_vector + {x=max_angle, y=max_angle, z=0}
        end
        --make breathing just add to the overall rotation vector (as it could be in that circle at any time, and it looks better and is more fitting)
        if gun.consts.HAS_BREATHING and self.normalize_breathing then
            temp_vector = temp_vector + {x=gun.properties.breathing_scale, y=0, z=0}
        end
        --stop wag from looking wierd so the offset only expands and doesnt do a weird pulsing thing. Inefficient, hopefully not a terrible deal, taking the advice not to prematurely optimize.
        local walking_vec = gun.offsets.walking.gun_axial + gun.offsets.walking.player_axial
        if gun.consts.HAS_WAG and self.normalize_walking then
            if handler.walking then --"velocity" is used to track velocity of the player for after movement effects. When they are no longer needed it is expunged, also indicating to the function its over
                --only accept higher values for animation
                if render_length(walking_vec, fov) > render_length(self.old_walking_vec, fov) then
                    self.old_walking_vec = vector.copy(walking_vec)
                    temp_vector = temp_vector + absolute_vector(walking_vec)
                else
                    temp_vector = temp_vector + absolute_vector(self.old_walking_vec)
                end
            else
                --only accept lower values for animation
                if render_length(walking_vec, fov) < render_length(self.old_walking_vec, fov) then
                    self.old_walking_vec = walking_vec
                    temp_vector = temp_vector + absolute_vector(walking_vec)
                else
                    temp_vector = temp_vector + absolute_vector(self.old_walking_vec)
                end
            end
        end

        --create a new dir using our parameters.
        local dir = vector.rotate({x=0,y=0,z=1}, {x=temp_vector.x*math.pi/180, y=0, z=0})
        dir = vector.rotate(dir, {x=0, y=temp_vector.y*math.pi/180, z=0})


        --now figure out what frame will be our correct spread
        local offset = Point_to_hud(dir, fov, 1) --pretend it's a 1:1 ratio so we can do things correctly.
        local length = math.sqrt(offset.x^2+offset.y^2) --get the max length.

        local img_perc = (self.scale*2*handler.wininfo.real_hud_scaling*self.width)/handler.wininfo.size.x --the percentage that the hud element takes up
        local frame = length/img_perc --the percentage of the size the length takes up.
        frame = math.floor(self.frames*frame)
        frame = math.clamp(frame, 0, self.frames-1)
        --"^[vertical_frame:"..self.frames..":"..frame
        self.player:hud_change(self.hud, "text", self.image.."^[verticalframe:"..self.frames..":"..frame)
    else
        self.player:hud_change(self.hud, "text", "blank.png")
    end
end

function Dynamic_crosshair:prepare_deletion()
    self.player:hud_remove(self.hud)
end