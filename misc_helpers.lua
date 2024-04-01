--- misc. common tools for 4dguns
-- @script misc_helpers

Guns4d.math = {}
Guns4d.table = {}

--store this so there arent duplicates
Guns4d.unique_id = {
    generated = {},
}
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

--all of the following is disgusting and violates the namespace because I got used to love2d.
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
function Guns4d.table.deep_copy(tbl, copy_metatable, indexed_tables)
    if not indexed_tables then indexed_tables = {} end
    local new_table = {}
    local metat = getmetatable(tbl)
    if metat then
        if copy_metatable then
            setmetatable(new_table, Guns4d.table.deep_copy(metat, true))
        else
            setmetatable(new_table, metat)
        end
    end
    for i, v in pairs(tbl) do
        if type(v) == "table" then
            if not indexed_tables[v] then
                indexed_tables[v] = true
                new_table[i] = Guns4d.table.deep_copy(v, copy_metatable)
            end
        else
            new_table[i] = v
        end
    end
    return new_table
end


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
--[[function Guns4d.table.tostring_structure_only(tbl, shallow, tables, depth)
    --create a list of tables that have been tostringed in this chain
    if not table then return "nil" end
    if not tables then tables = {this_table = tbl} end
    if not depth then depth = 0 end
    depth = depth + 1
    local str = ""
    local initial_string = "\n"
    for i = 1, depth do
        initial_string = initial_string .. "    "
    end
    if depth > 20 then
        return "(TABLE): depth limited reached (20 nested tables)"
    end
    local iterations = 0
    if tbl.name then
        str = str..initial_string.."[\"name\"] = \""..tbl.name.."\","
    end
    if tbl.type then
        str = str..initial_string.."[\"type\"] = \""..tbl.type.."\","
    end
    for i, v in pairs(tbl) do
        iterations = iterations + 1
        local val_type = type(v)
        if val_type == "table" then
            local contains = table_contains(tables, v)
            --to avoid infinite loops, make sure that the table has not been tostringed yet
            if not contains then
                tables[parse_index(i).." ["..tostring(v).."]"] = v
                str = str..initial_string..parse_index(i).."("..tostring(v)..") = "..Guns4d.table.tostring_structure_only(v, shallow, tables, depth)..","
            elseif type(v) == "table" then
                str = str..initial_string..parse_index(i).." = "..tostring(v)
            else
                str = str..initial_string..parse_index(i).." = "..tostring(v).." ("..tostring(v).."),"
            end
        end
    end
    if iterations == 0 then
        return "{}"
    elseif iterations > 100 then
        return "table too long"
    end
    return "{"..str..string.sub(initial_string, 1, -5).."}"
end]]

--replace fields (and fill sub-tables) in `tbl` with elements in `replacement`. Recursively iterates all sub-tables. use property __overfill=true for subtables that don't want to be overfilled.
function Guns4d.table.fill(tbl, replacement, preserve_reference, indexed_tables)
    if not indexed_tables then indexed_tables = {} end --store tables to prevent circular referencing
    local new_table = tbl
    if not preserve_reference then
        new_table = Guns4d.table.deep_copy(tbl)
    end
    for i, v in pairs(replacement) do
        if new_table[i] then
            local replacement_type = type(v)
            if replacement_type == "table" then
                if type(new_table[i]) == "table" then
                    if not indexed_tables[v] then
                        if not new_table[i].__overfill then
                            indexed_tables[v] = true
                            new_table[i] = Guns4d.table.fill(tbl[i], replacement[i], false, indexed_tables)
                        else --if overfill is present, we don't want to preserve the old table.
                            new_table[i] = Guns4d.table.deep_copy(replacement[i])
                        end
                    end
                elseif not replacement[i].__no_copy then
                    new_table[i] = Guns4d.table.deep_copy(replacement[i])
                else
                    new_table[i] = replacement[i]
                end
                new_table[i].__overfill = nil
            else
                new_table[i] = replacement[i]
            end
        else
            new_table[i] = replacement[i]
        end
    end
    return new_table
end
--for class based OOP, ensure values containing a table in btbl are tables in a_tbl- instantiate, but do not fill.
--[[function table.instantiate_struct(tbl, btbl, indexed_tables)
    if not indexed_tables then indexed_tables = {} end --store tables to prevent circular referencing
    for i, v in pairs(btbl) do
        if type(v) == "table" and not indexed_tables[v] then
            indexed_tables[v] = true
            if not tbl[i] then
                tbl[i] = table.instantiate_struct({}, v, indexed_tables)
            elseif type(tbl[i]) == "table" then
                tbl[i] = table.instantiate_struct(tbl[i], v, indexed_tables)
            end
        end
    end
    return tbl
end]]
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
function Guns4d.rltv_point_to_hud(pos, fov, aspect)
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
function Guns4d.nearest_point_on_line(lineStart, lineEnd, pnt)
    local line = vector.subtract(lineEnd, lineStart)
    local len = vector.length(line)
    line = vector.normalize(line)

    local v = vector.subtract(pnt, lineStart)
    local d = vector.dot(v, line)
    d = Guns4d.math.clamp(d, 0, len);
    return vector.add(lineStart, vector.multiply(line, d))
end