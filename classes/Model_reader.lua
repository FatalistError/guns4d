local path_seperator = "/@/"

Guns4d.Model_bone_handler = Instantiatable_class:inherit({
    construct = function(def)
        if def.instance then
            assert(def.modelpath, "no path provided")
            if mtul.media_paths[def.modelpath] then def.modelpath = mtul.media_paths[def.modelpath] end
            local stream = io.open(def.modelpath, "rb")
            def.b3d_table = mtul.b3d.read(stream)
            stream:close()
            stream = minetest.request_insecure_environment().io.open(minetest.get_modpath("guns4d").."/test.gltf", "wb")
            modlib.b3d.write_gltf(def.b3d_table, stream)
            stream:close()

            def.paths = {}
            def:process_and_reformat()
        end
    end
})
local model_bones = Guns4d.Model_bone_handler
--this creates a list of bone paths, and changes the index from an int to names.
local function retrieve_hierarchy(node, out)
    if not out then out = {node} end
    if node.parent then
        table.insert(out, 1, node.parent)
        retrieve_hierarchy(node.parent, out)
    end
    return out
end
function model_bones:solve_global_transform(node)
    assert(self.instance, "attempt to call object method on a class")
    local global_transform
    local hierarcy = retrieve_hierarchy(node)
    print("start")
    for i, v in pairs(hierarcy) do
        print(i, v.name)
    end
    print("end")
    for i, v in pairs(hierarcy) do
        local pos_vec = v.position
        local rot_vec = v.rotation
        local scl_vec = v.scale
        if v.keys[2] then
            pos_vec = v.keys[2].position
            rot_vec = v.keys[2].rotation
            scl_vec = v.keys[2].scale
        end
        --rot_vec = {rot_vec[2], rot_vec[3], rot_vec[4], rot_vec[1]}
        pos_vec = {-pos_vec[1], pos_vec[2], pos_vec[3]}
        local pos = modlib.matrix4.translation(pos_vec)
        rot_vec = {-rot_vec[1], rot_vec[2], rot_vec[3], rot_vec[4]}
        local rot = modlib.matrix4.rotation(modlib.quaternion.normalize(rot_vec))
        local scl = modlib.matrix4.scale(scl_vec)
        local local_transform = scl:compose(rot):compose(pos)

        if global_transform then
            global_transform=global_transform:multiply(local_transform)
        else
            global_transform=local_transform
        end
    end
    local pos
    if node.keys[2] then
        pos = node.position
    else
        pos = node.keys[2].position
    end
    --pos = global_transform:apply({pos[1], pos[2], pos[3], 1})
    --print(dump(global_transform))
    --return vector.new(pos[1], pos[2], pos[3])
    return vector.new(global_transform[1][4], global_transform[2][4], global_transform[3][4])
end
function model_bones:get_bone_global(bone_name)
    assert(self.instance, "attempt to call object method on a class")
    for i, v in pairs(self.paths) do
        local s, e = string.find(i, bone_name, #i-#bone_name)
        --this needs to be fixed.
        if s then
            local v1, v2 = self:solve_global_transform(v)
            return v1, v2
        end
    end
end
function model_bones:process_and_reformat(node, path)
    assert(self.instance, "attempt to call object method on a class")
    local first = false
    if not node then
        first = true
        node = self.b3d_table.node
    end
    path = path or ""
    node.mesh = nil --we wont be needing this
    for i, v in pairs(node.children) do
        if type(i) == "number" then
            local newpath
            if path ~= "" then
                newpath = path.." @ "..v.name
            else
                newpath = v.name
            end
            self.paths[newpath] = v
            v.mesh = nil
            v.parent = node
            node.children[v.name] = v
            node.children[i] = nil
            self:process_and_reformat(v, newpath)
        end
    end
    if first then
        for i, v in pairs(self.paths) do
            print(i)
            print(table.tostring(v.rotation))
            print(table.tostring(v.position))
            print(table.tostring(v.scale))
        end
    end
end
