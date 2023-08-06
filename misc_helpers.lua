--can't be copyright claimed by myself, luckily... well actually knowing the legal system I probably could sue myself.
Unique_id = {
    generated = {},
}
function math.clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, val))
end
function Unique_id.generate()
    local genned_ids = Unique_id.generated
    local id = string.sub(tostring(math.random()), 3)
    while genned_ids[id] do
        id = string.sub(tostring(math.random()), 3)
    end
    genned_ids[id] = true
    return id
end
function math.rand_sign(b)
    b = b or .5
    local int = 1
    if math.random() > b then int=-1 end
    return int
end
--for table vectors that aren't vector objects
---@diagnostic disable-next-line: lowercase-global
function tolerance_check(a,b,tolerance)
    return math.abs(a-b) > tolerance
end
function vector.equals_tolerance(v, vb, tolerance)
    tolerance = tolerance or 0
    return (
        tolerance_check(v.x, vb.x, tolerance) and
        tolerance_check(v.y, vb.y, tolerance) and
        tolerance_check(v.z, vb.z, tolerance)
    )
end
--copy everything
function table.deep_copy(tbl, copy_metatable, indexed_tables)
    if not indexed_tables then indexed_tables = {} end
    local new_table = {}
    local metat = getmetatable(tbl)
    if metat then
        if copy_metatable then
            setmetatable(new_table, table.deep_copy(metat, true))
        else
            setmetatable(new_table, metat)
        end
    end
    for i, v in pairs(tbl) do
        if type(v) == "table" then
            if not indexed_tables[v] then
                indexed_tables[v] = true
                new_table[i] = table.deep_copy(v, copy_metatable)
            end
        else
            new_table[i] = v
        end
    end
    return new_table
end
--replace elements in tbl with elements in replacement, but preserve the rest
function table.fill(tbl, replacement, preserve_reference, indexed_tables)
    if not indexed_tables then indexed_tables = {} end --store tables to prevent circular referencing
    local new_table = tbl
    if not preserve_reference then
        new_table = table.deep_copy(tbl)
    end
    for i, v in pairs(replacement) do
        if new_table[i] then
            if type(v) == "table" and type(replacement[i]) == "table" then
                if not indexed_tables[v] then
                    indexed_tables[v] = true
                    new_table[i] = table.fill(tbl[i], replacement[i], false, indexed_tables)
                end
            elseif type(replacement[i]) == "table" then
                new_table[i] = table.deep_copy(replacement[i])
            else
                new_table[i] = replacement[i]
            end
        else
            new_table[i] = replacement[i]
        end
    end
    return new_table
end
--fill "holes" in the tables.
function table.fill_in(tbl, replacement, preserve_reference, indexed_tables)
    if not indexed_tables then indexed_tables = {} end --store tables to prevent circular referencing
    local new_table = tbl
    if not preserve_reference then
        new_table = table.deep_copy(tbl)
    end
    for i, v in pairs(replacement) do
        if new_table[i]==nil then
            if type(v)=="table" then
                new_table[i] = table.deep_copy(v)
            else
                new_table[i] = v
            end
        else
            if (type(new_table[i]) == "table") and (type(v) == "table") then
                table.fill_in(new_table[i], v, true, indexed_tables)
            end
        end
    end
    return new_table
end
--for class based OOP, ensure values containing a table in btbl are tables in a_tbl- instantiate, but do not fill.
function table.instantiate_struct(tbl, btbl, indexed_tables)
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
end
function table.shallow_copy(t)
    local new_table = {}
    for i, v in pairs(t) do
        new_table[i] = v
    end
    return new_table
end


--for the following code and functions only:
--for license see the link on the next line.
--https://github.com/3dreamengine/3DreamEngine
function Point_to_hud(pos, fov, aspect)
	local n = .1 --near
	local f = 1000 --far
    --wherever you are
    --I WILL FOLLOWWWW YOU
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
	return vector.new((x / 2)+.5, (-y / 2)+.5, z)
end