# changelog 1.3.5
* #### reworked the table proxy system to allow for better changes to properties while active

# changelog 1.3.<1-4>
* #### bug fixes?
* #### crash with magazine unloading
* #### other bugfixes
* ### fixed startup crash

# changelog 1.3.0
* #### Established Versioning system
* #### moved the following fields
  * `inventory_image_magless` -> `inventory.inventory_image_magless`
  * `inventory_image_magless` -> `inventory.inventory_image_magless`
  * `firemode_inventory_overlays` - > `inventory.firemode_inventory_overlays`
  * `ammo_handler` -> `subclasses.ammo_handler`
  * `sprite_scope` -> `subclasses.sprite_scope`
  * `crosshair` -> `subclasses.crosshair`
* #### create the following classes
  * `Part_handler`
    * completed (expansion later)
    * facilitates attachments
  * `Physics_system`
    * inactive
    * future implementation for automatic translation
  * `Reflector_sight`
    * work in progress
    * simulates a reflector sight with an entity
* #### added the following changes to the gun class
  * made `consts` and `properties` proxy tables for protection of data (and reworked the LEEF class lib for this)
  * created a system for property modification
  * added `subclasses` property to replace hardcoded subclasses with modular system
  * added `subclass_instances` field (see above). These will be automatically updated if their index is in the subclasses list.
  * added `visuals.attached_objects` property to define attached entities
  * added `attached_objects` field
  * made `get_pos` capable of accounting for animation translations


