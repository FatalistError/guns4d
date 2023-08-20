Instantiatable_class = {
    instance = false,
    __no_copy = true
}
function Instantiatable_class:inherit(def)
    --construction chain for inheritance
    --if not def then def = {} else def = table.shallow_copy(def) end
    def.parent_class = self
    def.instance = false
    def.__no_copy = true
    def._construct_low = def.construct
    --this effectively creates a construction chain by overwriting .construct
    function def.construct(parameters)
        --rawget because in a instance it may only be present in a hierarchy but not the table itself
        if rawget(def, "_construct_low") then
            def._construct_low(parameters)
        end
        if self.construct then
            self.construct(parameters)
        end
    end
    def.construct(def)
    --iterate through table properties
    setmetatable(def, {__index = self})
    return def
end
function Instantiatable_class:new(def)
    --if not def then def = {} else def = table.shallow_copy(def) end
    def.base_class = self
    def.instance = true
    def.__no_copy = true
    function def:inherit(def)
        assert(false, "cannot inherit instantiated object")
    end
    setmetatable(def, {__index = self})
    --call the construct chain for inherited objects, also important this is called after meta changes
    self.construct(def)
    return def
end