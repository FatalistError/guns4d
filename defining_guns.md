
# The basic structure

The appearance and handling of guns by default are defined by two table fields: their @{lvl1_fields.consts|consts} and their @{lvl1_fields.properties|properties}.
@{lvl1_fields.properties|properties} define nearly everything, from how a gun handles to how it looks, what model it uses, etc.
while @{lvl1_fields.consts|consts} define attributes that should never change, like bones within the gun, framerates,

wether the gun is allowed to have certain attributes at all. The other fields of the class define tracking variables or other important things for the internal workings.
There are essentially only 3 fields you must define to register a gun: @{gun.itemstring|itemstring}, @{gun.name|name}, and @{lvl1_fields.properties|properties}.
To hold the gun, the item defined in itemstring must actually exist, it will not automatically register. To have a functional gun however, more will need to be changed in terms of properties.
it's reccomended that you take a look at existing mods (like guns4d_pack_1) for guidance

Guns4d uses a class system for most moving parts- including the gun. New guns therefore are created with the :inherit(def) method,
where def is the definition of your new gun- or rather the changed parts of it. So to make a new gun you can run Guns4d.gun:inherit()
or you can do the same thing with a seperate class of weapons. Set name to "__template" for template classes of guns.

for properties: for tables where you wish to delete the parent class's fields altogether (since inheritence prevents this) you can set the field "__replace_old_table=true"
additionally

# Ammunition

Ammunition is currently self-defined. Ammo has its own attributes seperate from the gun. This will eventually be changed to where the ammunition can both have an effect on the gun
and the gun can have an effect on the ammunition.

# Subclasses

subclasses are classes which are defined in `properties.subclasses` (where they will be instantiated on construction of the instance).
The resulting instance will then be put (under the same name/index) into the gun instance's `subclass_instances` table which will then be iterated. If the subclass has an `update` field it will be called as a function. If the properties change and the subclass no longer exists, it will be destroyed. This is so that things like scopes or other subclasses can be removed automatically if they no longer are present.

## adding a subclass to a gun after construction

you should accomplish this using a `property_modifier`. To do so, simply add a function `function(gun)` to `property_modifier` (preferably under a name like `modname:modifier`).
The function should add a your class to `properties