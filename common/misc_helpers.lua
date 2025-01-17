--- misc. common tools for 4dguns
-- @script misc_helpers

Guns4d.math = {}
Guns4d.table = {}

--store this so there arent duplicates
Guns4d.unique_id = {
    generated = {},
}

--[[format of field modifiers
{
    int_field = { --the field is an integer
        add = .1 --add .1 to the field (after multiplying)
        mul = 2 --multipy before adding
    },
    int_field_2 = {
        override = 4 --sets the field to 4
        override_priority = 2 --if others set and have a higher priority, this will be it's priority
        remove = false --true if you want to remove it
    }
    table_field = {
        int_field = {. . .}
    }
}
]]
function Guns4d.apply_field_modifiers(props, mods)
    local out_props = {}
    for i, v in pairs(props) do
        if type(v)=="number" then
            local add = 0
            local mul = 1
            local override
            local remove = false
            local priority = math.huge
            for _, modifier in ipairs(mods) do
                local a = modifier[i]
                if a then
                    add = add + (a.add or 0)
                    mul = mul * (a.mul or 1)
                    if a.override and (priority > (a.priority or 10)) then
                        override = a.override
                        priority = a.priority or 10
                    end
                    remove = a.remove
                end
            end
            out_props[i] = (((override or v) or 0)*mul)+add
            if remove then
                out_props[i] = nil
            end
        elseif type(v)=="table" then
            for _, modifier in pairs(mods) do
                local a = modifier[i]
                Guns4d.apply_field_modifiers(v, a)
            end
        else
            local override
            local priority = math.huge
            local remove
            for _, modifier in ipairs(mods) do
                local a = modifier[i]
                if type(v)==type(a.override) then
                    if a.override and (priority > (a.priority or 10)) then
                        override = a.override
                        priority = a.priority or 10
                    end
                    remove = a.remove
                    if a.remove then
                        out_props[i]=nil
                    end
                elseif a then
                    minetest.log("error", "modifier name: "..(modifier._modifier_name or "???").."attempted to override a "..type(v).." with a "..type(v).." value")
                end
            end
            out_props[i] = ((override~=nil) and override) or out_props[i]
            if remove then
                out_props[i] = nil
            end
        end
    end
    return out_props
end
--[[print(dump(Guns4d.apply_field_modifiers({
    a=0,
    y=1,
    z=10,
    st="string"
}, {
    a={
        add=1,
        mul=2
    },
    z={
        mul=2,
        add=1
    },
    st={
        override=10
    }
}
)))]]

function Guns4d.unique_id.generate()
    local genned_ids = Guns4d.unique_id.generated
    local id = string.sub(tostring(math.random()), 3)
    while genned_ids[id] do
        id = string.sub(tostring(math.random()), 3)
    end
    genned_ids[id] = true
    return id
end

---math helpers.
-- in guns4d.math
--@section math

function Guns4d.math.clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, val))
end
--- picks a random index, with odds based on it's value. Returns the index of the selected.
-- @param tbl a table containing weights, example
--      {
--          ["sound"] = 999, --999 in 1000 chance this is chosen
--          ["rare_sound"] = 1 --1 in 1000 chance this is chosen
--      }
-- @function weighted_randoms
function Guns4d.math.weighted_randoms(tbl)
    local total_weight = 0
    local new_tbl = {}
    for i, v in pairs(tbl) do
        total_weight=total_weight+v
        table.insert(new_tbl, {i, v})
    end
    local ran = math.random()*total_weight
    --[[the point of the new table is so we can have them
    sorted in order of weight, so we can check if the random
    fufills the lower values first.]]
    table.sort(new_tbl, function(a, b) return a[2] > b[2] end)
    local scaled_weight = 0 --[[so this is added to the weight so it's chances are proportional
    to it's actual weight as opposed to being wether the lower values are picked- if you have
    weight 19 and 20, 20 would have a 1/20th chance of being picked if we didn't do this]]
    for i, v in pairs(new_tbl) do
        if (v[2]+scaled_weight) > ran then
            return v[1]
        end
        scaled_weight = scaled_weight + v[2]
    end
end
function Guns4d.math.smooth_ratio(r)
    return ((math.sin((r-.5)*math.pi))+1)/2
end
--[[
--for table vectors that aren't vector objects
local function tolerance_check(a,b,tolerance)
    return math.abs(a-b) > tolerance
end
function Guns4d.math.vectors_in_tolerance(v, vb, tolerance)
    tolerance = tolerance or 0
    return (
        tolerance_check(v.x, vb.x, tolerance) and
        tolerance_check(v.y, vb.y, tolerance) and
        tolerance_check(v.z, vb.z, tolerance)
    )
end
]]

---table helpers.
-- in guns4d.table
--@section table

--copy everything
--[[function Guns4d.table.deep_copy(tbl, copy_metatable, indexed_tables)
    local new_table = {}
    if not indexed_tables then indexed_tables = {[tbl]=new_table} end
    for i, v in pairs(tbl) do
        if type(v) == "table" then
            if not indexed_tables[v] then
                new_table[i] = Guns4d.table.deep_copy(v, copy_metatable, indexed_tables)
                indexed_tables[v] = new_table[i]
            else
                new_table[i] = indexed_tables[v]
            end
        else
            new_table[i] = v
        end
    end
    if copy_metatable then setmetatable(new_table, getmetatable(tbl)) end
    return new_table
end]]


function Guns4d.table.deep_copy(in_value, copy_metatable, copied_list)
    if not copied_list then copied_list = {} end
    if copied_list[in_value] then return copied_list[in_value] end
    if type(in_value)~="table" then return in_value end
    local out = {}
    copied_list[in_value] = out
    for i, v in pairs(in_value) do
        out[i] = Guns4d.table.deep_copy(v, copy_metatable, copied_list)
    end
    if copy_metatable then
        setmetatable(out, getmetatable(in_value))
    end
    return out
end
--[[local test = {}
test.gay = {
    gay = {
        behind_me = {hell=1, test=test},
        h = 1,
        dead = "ten"
    }
}
]]


function Guns4d.table.contains(tbl, value)
    for i, v in pairs(tbl) do
        if v == value then
            return i
        end
    end
    return false
end
local function parse_index(i)
    if type(i) == "string" then
       return "[\""..i.."\"]"
    else
        return "["..tostring(i).."]"
    end
end
--dump() sucks.
local table_contains = Guns4d.table.contains
function Guns4d.table.tostring(tbl, shallow, list_length_lim, depth_limit, tables, depth)
    --create a list of tables that have been tostringed in this chain
    if not table then return "nil" end
    if not tables then tables = {this_table = tbl} end
    if not depth then depth = 0 end
    depth = depth + 1
    local str = "{"
    local initial_string = "\n"
    for i = 1, depth do
        initial_string = initial_string .. "    "
    end
    if depth > (depth_limit or math.huge) then
        return "(TABLE): depth limited reached"
    end
    local iterations = 0
    for i, v in pairs(tbl) do
        iterations = iterations + 1
        local val_type = type(v)
        if val_type == "string" then
            str = str..initial_string..parse_index(i).." = \""..v.."\","
        elseif val_type == "table" and (not shallow) then
            local contains = table_contains(tables, v)
            --to avoid infinite loops, make sure that the table has not been tostringed yet
            if not contains then
                tables[i] = v
                str = str..initial_string..parse_index(i).." = "..Guns4d.table.tostring(v, shallow, list_length_lim, depth_limit, tables, depth)..","
            else
                str = str..initial_string..parse_index(i).." = "..tostring(v).." (index: '"..tostring(contains).."'),"
            end
        else
            str = str..initial_string..parse_index(i).." = "..tostring(v)..","
        end
    end
    if iterations >  (list_length_lim or math.huge) then
        return "(TABLE): too long, 100+ indices"
    end
    return str..string.sub(initial_string, 1, -5).."}"
end


--these need to be documented flags:
--__replace_old_table = true      --the replacing table declares that the old table should be replaced with the new one (if present)
--__replace_only = true           --the original table declares that it should be replaced with the new one (if present)
--[field] = "__redact_field"      --the field will be nil even if it existed in the old table

--replace fields (and fill sub-tables) in `tbl` with elements in `replacement`. Recursively iterates all sub-tables. use property __replace_old_table=true for subtables that don't want to be overfilled.

local redact_field = "__redact_field"
function Guns4d.table.fill(to_fill, replacement, copy_metatable, traversed)
    if replacement == redact_field then return nil end
    if type(replacement)~="table" then return replacement end
    if (not to_fill) or (replacement.__replace_old_table) or (to_fill.__replace_only) then return Guns4d.table.deep_copy(replacement, copy_metatable, traversed) end
    if not traversed then traversed = {} end
    if traversed[replacement] then return traversed[replacement] end
    local out = {}
    traversed[replacement] = out
    for i, value in pairs(replacement) do
        out[i] = Guns4d.table.fill(to_fill[i], value, copy_metatable, traversed)
        if type(out[i])=="table" then out[i].__replace_old_table = nil end
    end
    for i, v in pairs(to_fill) do
        if (not out[i]) and (not replacement[i]~=redact_field) then
            out[i] = Guns4d.table.deep_copy(to_fill[i], copy_metatable, traversed)
        end
    end

    if copy_metatable then
        setmetatable(out, getmetatable(to_fill))
    end
    return out
end

--[[local test = {}
test.gay = {
        behind_me = {
            hell=1,
            circular_reference=test,
            redacted_field = "not redacted"
        },
        h = 1,
        dead = "ten",
        unchanged_variable = "unchanged_variable",
        table_to_replace = {
            __replace_only = true,
            nil_var = false
        },
        table_to_replace2 ={
            nil_var = false
        }
    }
local test2 = {}
test2.gay = {
    behind_me = {
        hell=1,
        circular_reference=test2,
        original_table=test,
        redacted_field = "__redact_field"
    },
    h = 2,
    dead = "twelve",
    no_russian = true,
    nobody = {},
    table_to_replace = {
        death = 1
    },
    table_to_replace2 = {
        __replace_old_table = true
    }
}
]]

function Guns4d.table.shallow_copy(t)
    local new_table = {}
    for i, v in pairs(t) do
        new_table[i] = v
    end
    return new_table
end

---other helpers
--@section other

--for the following function only:
--for license see the link on the next line (direct permission was granted).
--https://github.com/3dreamengine/3DreamEngine
function Guns4d.math.rltv_point_to_hud(pos, fov, aspect)
	local n = .1 --near
	local f = 1000 --far
	local scale = math.tan(fov * math.pi / 360)
	local r = scale * n * aspect
	local t = scale * n
	--optimized matrix multiplication by removing constants
	--looks like a mess, but its only the opengl projection multiplied by the camera
	local a1 = n / r
	--local a6 = n / t * m
    local a6 = n / t
	local fn1 = 1 / (f - n)
	local a11 = -(f + n) * fn1
    local x = (pos.x/pos.z)*a1
    local y = (pos.y/pos.z)*a6
    local z = (pos.z/pos.z)*a11
	return {x=x / 2,y=-y / 2} --output needs to be offset by +.5 on both for HUD elements, but this cannot be integrated.
end

--Code: Elkien3 (CC BY-SA 3.0)
--https://github.com/Elkien3/spriteguns/blob/1c632fe12c35c840d6c0b8307c76d4dfa44d1bd7/init.lua#L76
function Guns4d.math.nearest_point_on_line(lineStart, lineEnd, pnt)
    local line = vector.subtract(lineEnd, lineStart)
    local len = vector.length(line)
    line = vector.normalize(line)

    local v = vector.subtract(pnt, lineStart)
    local d = vector.dot(v, line)
    d = Guns4d.math.clamp(d, 0, len);
    return vector.add(lineStart, vector.multiply(line, d))
end

--[[function Guns4d.math.rand_box_muller(deviation)
    local tau = math.pi*2
    --our first value cant be 0
    math.randomseed(math.random())
    local r1 = 0
    while r1 == 0 do r1=math.random() end
    local r2=math.random()

    local a = deviation * math.sqrt(-2.0*math.log(r1))
    return a * math.cos(tau * r1), a * math.sin(tau * r2);
end]]
local e = 2.7182818284590452353602874713527 --I don't know how to find it otherwise...
--deviation just changes the distribution, range is the maximum spread
function Guns4d.math.angular_normal_distribution(deviation)
    local x=math.random()
    --positive only normal distribution
    local a = 1/(deviation*math.sqrt(2*math.pi))
    local exp = -.5*(x/deviation)^2
    local exp_x_1 = (-.5*(1/deviation)^2) --exp value where x=1
    local y=( (a*e^exp) - (a*e^exp_x_1) )/( a - (a*e^exp_x_1) ) --subtraction is to bring the value of x=1 to 0 on the curve and the division is to keep it normalized to an output of one
    local theta = math.random()*math.pi*2
    return y*math.cos(theta), y*math.sin(theta)
end
function Guns4d.math.round(n)
    return (n-math.floor(n)<.5 and math.floor(n)) or math.ceil(n)
end