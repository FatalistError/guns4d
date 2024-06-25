--- The system for defining classes in 4dguns. Please note the capital "I", Ldoc converts it to a lowercase in all of this file
-- @class Instantiatable_class

Instantiatable_class = {
    instance = false,
    __no_copy = true
}
--- Instantiatable_class
-- @table god_work please
-- @field instance defines wether the object is an instance
-- @field base_class only present for instances: the class from which this instance originates
-- @field parent_class the class from which this class was inherited from

--- creates a new base class. Calls all constructors in the chain with def.instance=true
-- @param def the table containing a new definition (where the class calling the method is the parent). The content of the definition will override the fields for it's children.
-- @return def a new base class
-- @function Instantiatable_class:inherit()
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
        if self.construct then
            self.construct(parameters)
        end
        if rawget(def, "_construct_low") then
            def._construct_low(parameters)
        end
    end
    --iterate through table properties
    setmetatable(def, {__index = self})
    def.construct(def) --moved this to call after the setmetatable, it doesnt seem to break anything, and how it should be? I dont know when I changed it... hopefully not totally broken.
    return def
end
--- construct
-- every parent constructor is called in order of inheritance, this is used to make changes to the child table. In self you will find base_class defining what class it is from, and the bool instance indicating (shocking) wether it is an instance.
-- @function construct where self is the definition (after all higher parent calls) of the table. This is the working object, no returns necessary to change it's fields/methods.


--- creates an instance of the base class. Calls all constructors in the chain with def.instance=true
-- @return def a new instance of the class.
-- @function Instantiatable_class:new(def)
function Instantiatable_class:new(def)
    --if not def then def = {} else def = table.shallow_copy(def) end
    def.base_class = self
    def.instance = true
    def.__no_copy = true
    function def:inherit()
        assert(false, "cannot inherit instantiated object")
    end
    setmetatable(def, {__index = self})
    --call the construct chain for inherited objects, also important this is called after meta changes
    self.construct(def)
    return def
end