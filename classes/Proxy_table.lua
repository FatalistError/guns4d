--

Proxy_table = {
    registered_proxies = {},
    proxy_children = {}
}
--this creates proxy tables in a structure of tables
--this is great if you want to prevent the change of a table
--but still want it to be viewable, such as with constants
function Proxy_table:new(og_table, parent)
    local new = {}
    self.registered_proxies[og_table] = new
    if parent then
        self.proxy_children[parent][og_table] = true
    else
        self.proxy_children[og_table] = {}
        parent = og_table
    end
    --set the proxy's metatable
    setmetatable(new, {
        __index = function(t, key)
            if type(og_table[key]) == "table" then
                return Proxy_table:get_or_create(og_table[key], parent)
            else
                return og_table[key]
            end
        end,
        __newindex = function(table, key)
            assert(false, "attempt to edit immutable table, cannot edit a proxy")
        end,
    })
    --[[overwrite og_table meta to destroy the proxy aswell (but I realized it wont be GCed unless it's removed altogether, so this is pointless)
    local mtable = getmetatable(og_table)
    local old_gc = mtable.__gc
    mtable.__gc = function(t)
        self.registered_proxies[t] = nil
        self.proxy_children[t] = nil
        old_gc(t)
    end
    setmetatable(og_table, mtable)]]
    --premake proxy tables
    for i, v in pairs(og_table) do
        if type(v) == "table" then
            Proxy_table:get_or_create(v, parent)
        end
    end
    return new
end
function Proxy_table:get_or_create(og_table, parent)
    return self.registered_proxies[og_table] or Proxy_table:new(og_table, parent)
end
function Proxy_table:destroy_proxy(parent)
    self.registered_proxies[parent] = nil
    if self.proxy_children[parent] then
        for i, v in pairs(self.proxy_children[parent]) do
            Proxy_table:destroy_proxy(i)
        end
    end
    self.proxy_children[parent] = nil
end