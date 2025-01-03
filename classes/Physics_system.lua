
local physics_system = leef.class.new_class:inherit({
    objects = {}, --table of vectors,
    object_pos = vector.new(),
    center_of_mass = vector.new(),
    object_weight = 1, --weight in kg
    forcefields = {}
})

--forcefield def

--[[
{
    midline_radius = 0, --midline of attraction/repulsion
    deadzone_radius = 1,
    border_radius = 0
    pos = vec3(),
    elastic_constant = 0 --F = e * d^(|e|/e)
}
]]

--calculate delta-velocity of a given forcefield
--@tparam int index of the forcefield
--@treturn deltaV of
--not going to optimize this because AHHHHHHHHHH its a lot of vector math
function physics_system:update(dt)
    for i, v in pairs() do

    end
end
function physics_system:calculate_dv(dt, i)
    local field = self.forcefields[i]
    local borderR = field.border_radius
    local deadzoneR = field.deadzone_radius
    local midlineR = field.midline_radius
    local field_pos = field.pos
    local pos = field.target_pos

    local dir = (pos-field_pos):normalize()                  --direction of pos from field
    local midline_intersect = dir*midlineR                   --dir*r is the intersect with midline
    local dist = (midline_intersect-pos):length()-deadzoneR  --distance from midline's deadzone
    if dist < 0 then return vector.new() end
    -- if dist > 0 then we pull it to the radius
    local e = field.elastic_constant
    local ft = e*dist^(math.abs(e)/e) * vector.dot(dir, pos) --force applied to translation
    local a = ft/self.object_weight                          --acceleration
    return dir*(a*dt)
end