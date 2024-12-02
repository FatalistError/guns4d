
function table.resolve_string(object, address)
    local indexes = string.split(address)
    local current
    for i, v in pairs(indexes) do
        current = current[i]
    end
    return current
end
local function split_into_adresses(object, path, out)
    out = out or {}
    path = path or ""
    for index, val in pairs(object) do
        local this_path = path.."."..index
        if type(val) == "table" then

        end

    end
    return out
end
Modifier = leef.class.new_class:inherit({
    overwrites = {},
    construct = function(def)
        if def.instance then
            assert(type(def.apply)=="function", "no application function found for modifier")
            assert(def.name, "name is required for modifiers")
            assert(def.properties, "cannot modify a nonexisent properties table")
            local old_apply = def.apply
            def.is_active = false
            def.immutable_props = Proxy_table:get_or_create()
            function def.apply(properties)
                assert(not def.is_active, "attempt to double apply modifier '"..def.name.."'")
                def.is_active = true
                local proxy = Proxy_table:get_or_create(properties) --the proxy prevents unintended modification of the original table.
                local add_table, override_table = old_apply(proxy)
                if add_table then

                end
                if override_table then

                end
            end
            function def.stop()
            end
        end
    end,

})