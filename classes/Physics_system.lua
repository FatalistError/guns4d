
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
local rpos = vector.new()
--not going to optimize this because AHHHHHHHHHH its a lot of vector math
function physics_system:update(dt)
end
function physics_system:calculate_dv(dt, i)
    local pos =



    local field = self.forcefields[i]
    local borderR = field.border_radius
    local deadzoneR = field.deadzone_radius
    local midlineR = field.midline_radius
    local fpos = field.pos

    --rpos.x, rpos.y, rpos.z = pos.x-fpos.x,pos.y-fpos.y,pos.z-fpos.x
    rpos = pos-fpos                                     --relative pos
    local midline_intersect = rpos:normalize()*midlineR --dir*r is the intersect with midline
    local d=(midline_intersect-pos):length()            --distance from midline
    local e=  field.elastic_constant
    local f = e*d^(math.abs(e)/e)                 --force

    --local a = f/self.object_weight                      --acceleration
    return a*dt                                         --change in velocity
end
