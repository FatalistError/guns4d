# Property modifiers

property modifiers are used to define changes to the gun's properties (though dually they have the ability to make runtime changes to other gun fields).
In the context ogthe gun class, a property modifier is any function found in the `property_modifiers` table.

You can safely make direct changes to the property table that will be cleared (and regenerated if still present) when `gun:regenerate_properties()` is called
for example:
```
    function my_property_modfier(props)
        props.visuals.mesh = "mesh.b3d"
    end
```
in this example the mesh of the gun will be set to `mesh.b3d` but if the property_modifier is removed (as it would be if you removed an attachment for example) it
would be reset to the base class's mesh.