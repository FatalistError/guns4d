
local Vec = vector

--- class fields
--
-- (this class found in `Guns4d.gun`)
-- the following fields (placed anywhere) are used to perform special actions:
-- @example
--      __no_copy                       --the replacing (table) will not be copied, and the field containing it will be a reference to the orginal table found in replacement
--      __replace_old_table = true      --the replacing table declares that the old table should be replaced with the new one
--      __replace_only = true           --the original table declares that it should be replaced with the new one
--

--- @class gun
--
-- the following is documentation of gun fields. Methods are currently not present in this list.
--
-- @display gun
-- @see defining_guns
-- @compact
-- @field properties @{lvl1_fields.properties|properties} which define the vast majority of gun attributes and may change accross instances
-- @field consts @{lvl1_fields.consts|constants} which define gun attributes and should not be changed in an instance of the gun
-- @field offsets runtime storage of @{lvl1_fields.offsets|offsets} generated by recoil sway wag or any other element.
local gun_default = {
    --- `string` the name of the gun. Set to __template for guns which have no instances and serve as a template. It is safe to set name to the same as @{gun.itemstring}
    name = "__guns4d:default__",
    --- `string` the itemstring of the gun- i.e. `"guns4d_pack_1:m4"`. Set to `""` for `__template` guns.
    itemstring = "",
    --- `ItemStack` the gun itemstack. Remember to player:set_wielded_item(self.itemstack) when making meta or itemstack changes.
    itemstack = nil,
    --- `ObjRef` the operator of the weapon. This may at some point be deprecated when I start to implement AI/mob usage
    player = nil,
    --- `MetaDataRef` itemstack meta
    meta = nil,
    --- `string` the ID of the gun used for tracking of it's inventory
    id = nil,
    --- `ObjRef` the gun entity
    gun_entity = nil,
    --- list of registered guns. Don't modify this it will break the entire mod (it shouldnt even be here i dont know why it is but im not going to fix it today lmao)
    _registered = {},
    --- `bool` is the bolt charged
    bolt_charged = false,
    --- `table` list of particle spawner handles (generated by firing)
    particle_spawners = nil, --table
    --- `int` the active index of the firemode from @{lvl1_fields.properties.firemodes|firemodes}
    current_firemode = 1,
    --- `float` walking time used to generate the figure 8 for wag
    walking_tick = 0,
    --- `float`
    time_since_last_fire = 0,
    --- `float`
    time_since_creation = 0,
    --- `float` time left for the chamber to cycle (for firerates)
    rechamber_time = 0,
    --- `int` number of rounds left that need to be fired after a burst fire
    burst_queue = 0,
    --- `vec3` translation of the gun relative to the "gun" bone or the player axial rotation.
    gun_translation = nil, --vector.new()
    --- `table` indexed list of functions which are called when the gun's properties need to be built. This is used for things like attachments, etc.
    property_modifiers = nil, --table
    --- `table` a list of ObjRefs that are attached to the gun as a result of attached_objects
    attached_objects = nil, --table
    --- `table` list of subclass instances (i.e. Sprite_scope)
    subclass_instances = nil, --table

    --- properties
    --
    -- the table containing every attribute of the gun.
    -- @table lvl1_fields.properties
    -- @field hip `table` @{gun.properties.hip|hipfire properties}
    -- @field ads `table` @{gun.properties.ads|aiming ("aiming down sights") properties}
    -- @field firemodes `table` @{gun.properties.firemodes|list of firemodes}
    -- @field recoil `table` @{gun.properties.recoil|defines the guns recoil}
    -- @field sway `table` @{gun.properties.sway|defines the guns idle sway}
    -- @field wag `table` @{gun.properties.wag|defines the movement of the gun while walking}
    -- @field charging `table` @{gun.properties.charging|defines how rounds are chambered into the gun}
    -- @field ammo `table` @{gun.properties.ammo|defines what ammo the gun uses}
    -- @field visuals `table` @{gun.properties.visuals|defines visual attributes of the gun}
    -- @field sounds `table` @{gun.properties.sounds|defines sounds to be used by functions of the gun}
    -- @field inventory `table` @{gun.properties.inventory|inventory related attributes}
    -- @compact
    properties = {
        --- `float` starting vertical rotation of the gun
        initial_vertical_rotation = -60,
        --- `float`=.5 max angular deviation (vertical) from breathing
        breathing_scale = .5,
        --- `int`=600 The number of rounds (cartidges) this gun can throw per minute. Used by update(), attempt_fire() and default controls
        firerateRPM = 600,
        --- `table` a table containing the `collisionbox` and `selection` of the item in the same format as recieved by minetest entities. On construction of the gun's base class this will be set to model_bounding_box. Probably needs to be a const.
        item = {},
        --- an ordered list of reloading states used by @{default_controls}.
        --
        -- the default reload states for a magazine operated weapon, copied from the m4.
        -- @example
        --      {action="charge", time=.5, anim="charge", sounds={sound="ar_charge", delay = .2}},
        --      {action="unload_mag", time=.25, anim="unload", sounds = {sound="ar_mag_unload"}},
        --      {action="store", time=.5, anim="store", sounds = {sound="ar_mag_store"}},
        --      {action="load", time=.5, anim="load", sounds = {sound="ar_mag_load", delay = .25}},
        --      {action="charge", time=.5, anim="charge", sounds={sound="ar_charge", delay = .2}}
        reload = {},
        --- `table` (optional) a table `{x1,y1,z1, x2,y2,z2}` specifying the bounding box of the model. The first 3 (x1,y1,z1) are the lower of their counterparts. This is autogenerated from the model when not present, reccomended that you leave nil.
        model_bounding_box = nil,
        --- `string` overlay on the item to use when infinite ammo is on
        infinite_inventory_overlay = "inventory_overlay_inf_ammo.png",
        --- `int`=3 how many rounds in burst using when firemode is at "burst"
        burst = 3,
        --- `table` containing a list of actions for PC users passed to @{Control_handler}. `__replace_only = true` in this table, meaning if the table exists in the new definition, it will be replaced.
        pc_control_actions = { --used by control_handler
            __replace_only = true,
            aim = Guns4d.default_controls.aim,
            auto = Guns4d.default_controls.auto,
            reload = Guns4d.default_controls.reload,
            on_use = Guns4d.default_controls.on_use,
            firemode = Guns4d.default_controls.firemode,
            jump_cancel_ads = Guns4d.default_controls.jump_cancel_ads
        },
        --- `table` containing a list of actions for touch screen users passed to @{Control_handler}. `__replace_only = true` in this table, meaning if the table exists in the new definition, it will be replaced.
        touch_control_actions = {
            __replace_only = true,
            aim = Guns4d.default_touch_controls.aim,
            auto = Guns4d.default_touch_controls.auto,
            reload = Guns4d.default_touch_controls.reload,
            on_secondary_use = Guns4d.default_touch_controls.on_secondary_use,
            firemode = Guns4d.default_touch_controls.firemode,
            jump_cancel_ads = Guns4d.default_touch_controls.jump_cancel_ads
        },
        --- properties.inventory
        --
        -- @table gun.properties.inventory
        -- @see lvl1_fields.properties|properties
        -- @compact
        inventory = {
            --- the size in meters to render the gun in it's inventory opened with /guns4d_inv
            render_size = 2, --length (in meters) which is visible accross the z/forward axis at y/up=0, x=0. For orthographic this will be the scale of the orthographic camera. Default 2
            --- the image of the gun in it's inventory opened with /guns4d_inv
            render_image = "m4_ortho.png", --expects an image of the right side of the gun, where the gun is facing the right. Default "m4_ortho.png"
            --- table of firemodes and their overlays in the player's inventory when the gun is on that firemode
            firemode_inventory_overlays = { --#4
                --singlefire default: "inventory_overlay_single.png"
                single = "inventory_overlay_single.png",
                --automatic default: "inventory_overlay_auto.png"
                auto =  "inventory_overlay_auto.png",
                --burstfire default: "inventory_overlay_burst.png"
                burst =  "inventory_overlay_burst.png",
                --safe default: "inventory_overlay_safe.png" (unimplemented firemode)
                safe = "inventory_overlay_safe.png"
            },
            --- `string` (optional) inventory image for when the gun has no magazine
            inventory_image_magless = nil,
            --- `string` inventory image for when the gun is loaded. This is added automatically during construction as the item's wield image.
            inventory_image = nil,
            --[[part_slots = {
                underbarrel = {
                    formspec_inventory_location = {x=0, y=1}
                    slots = 2,
                    rail = "picatinny" --only attachments fit for this type will be usable.
                    allowed = {
                        "group:guns4d_underbarrel"
                    },
                    bone = "" --the bone both to attach to and to display at on the menu.
                }
            },]]
        },
        --- properties.subclasses
        --
        -- @table gun.properties.subclsses
        -- @see lvl1_fields.properties|properties
        -- @compact
        subclasses = {
            --- `Ammo_handler` the class (based on) ammo_handler to create an instance of and use. Default is `Guns4d.ammo_handler`
            ammo_handler = Guns4d.ammo_handler,
            --- `part_handler` Part_handler class to use. Default is `Guns4d.part_handler`
            part_handler = Guns4d.part_handler,
            --- `Sprite_scope` sprite scope class to use. Nil by default, inherit Sprite_scope for class (**documentation needed, reccomended contact for help if working with it**)
            sprite_scope = nil,
            --- `Dynamic_crosshair` crosshair class to use. Nil by default, set to `Guns4d.Dynamic_crosshair` for a generic circular expanding reticle.
            crosshair = nil,
        },
        --- properties.ads
        --
        -- @table gun.properties.ads
        -- @see lvl1_fields.properties|properties
        -- @compact
        ads = { --#2
            --- `vector` the offset of the gun relative to the eye's position at hip.
            offset = Vec.new(),
            --- `float` the horizontal offset of the eye when aiming
            horizontal_offset = .1,
            --- the time it takes to go into full aim
            aim_time = 1,
        },
        --- properties.hip
        --
        -- @table gun.properties.hip
        -- @see lvl1_fields.properties|properties
        -- @compact
        hip = {--#1
            --- `vector` the offset of the gun (relative to the right arm's default position) at hip.
            offset = Vec.new(),
            --- the ratio that the look rotation is expressed through player_axial (rotated around the viewport) rotation as opposed to gun_axial (rotating the entity).
            axis_rotation_ratio = .75,
            --- sway speed multiplier while at hip
            sway_vel_mul = 5,
            --- sway angle multiplier while at hip
            sway_angle_mul = 1,
        },
        --- properties.firemodes
        --
        -- list containing the firemodes of the gun. Default only contains "single". Strings allowed by default:
        -- @table gun.properties.firemodes
        -- @see lvl1_fields.properties|properties
        -- @compact
        -- @field "single"
        -- @field "burst"
        -- @field "auto"
        firemodes = { --#3
            "single", --not limited to semi-automatic.
        },
        --- properties.recoil
        --
        -- **IMPORTANT**: expects fields to be tables containing a "gun_axial" and "player_axial" field.
        -- @see lvl1_fields.properties|properties
        -- @example
        --      property = {
        --          gun_axial = type
        --          player_axial = type
        --      }
        --      --using a vector...
        --      property = {
        --          gun_axial={x=float, y=float},
        --          player_axial={x=float, y=float}
        --      }`
        -- @table gun.properties.recoil
        -- @compact
        recoil = { --#5 used by update_recoil()
            --- `float` TL:DR higher decreases recoil at expense of smoothness. 1/value is the deviation of a normalized bell curve, where x is the time since firing.
            -- this means that increasing it decreases the time it takes for the angular velocity to fully "decay".
            velocity_correction_factor = { --velocity correction factor is currently very broken.
                gun_axial = 1,
                player_axial = 1,
            },
            --- `float` Correction of recoil offset per second is calculated as such: `target_correction_factor[axis]*time_since_fire*recoil[axis]`
            target_correction_factor = { --angular correction rate per second: time_since_fire*target_correction_factor
                gun_axial = 1,
                player_axial = 1,
            },
            --- `float` The maximum rate per second of recoil offset as determined with @{target_correction_factor}
            target_correction_max_rate = { --the cap for target_correction_fire (i.e. this is the maximum amount it will ever correct per second.)
                gun_axial = math.huge,
                player_axial = math.huge,
            },
            --- `float` caps the recoil velocity that can stack up from shots.
            angular_velocity_max = { --max velocity, so your gun doesnt "spin me right round baby round round"
                gun_axial = 5,
                player_axial = 5,
            },
            --- `vector` {x=`float`, y=`float`}, defines the initial angular velocity produced by firing the gun
            angular_velocity = { --the velocity added per shot. This is the real "recoil" part of the recoil
                gun_axial = {x=0, y=0},
                player_axial = {x=0, y=0},
            },
            --- `vector` {x=`float`, y=`float`}, ranges -1 to 1. Defines the probability of the recoil being positive or negative for any given axis.
            bias = { --dictates the distribution bias for the direction angular_velocity is in. I.e. if you want recoil to always go up you set x to 1, more often to the right? y to -.5
                gun_axial = {x=1, y=0},
                player_axial = {x=1, y=0},
            },
            --- `float` angular velocity multiplier when firing from the hip
            hipfire_multiplier = { --the mutliplier for recoil (angular_velocity) at hipfire (can be fractional)
                gun_axial = 1,
                player_axial = 1
            },
        },
        --[[spread = {

        },]]
        --- properties.sway
        --
        -- **IMPORTANT**: expects fields to be tables containing a "gun_axial" and "player_axial" field. In the same format as @{gun.properties.recoil}
        -- @table gun.properties.sway
        -- @see lvl1_fields.properties|properties
        -- @compact
        sway = { --#6
            --- `float` maximum angle of the sway
            max_angle = {
                gun_axial = 0,
                player_axial = 0,
            },
            --- `float` angular velocity the sway
            angular_velocity = {
                gun_axial = 0,
                player_axial = 0,
            },
            --- `float` maximum angle multiplier while the gun is at the hip
            hipfire_angle_multiplier = { --the mutliplier for sway max_angle at hipfire (can be fractional)
                gun_axial = 2,
                player_axial = 2
            },
            --- `float` velocity multiplier while the gun is at the hip
            hipfire_velocity_multiplier = { --same as above but for velocity.
                gun_axial = 2,
                player_axial = 2
            }
        },
        --- properties.wag
        --
        -- @table gun.properties.wag
        -- @see lvl1_fields.properties|properties
        -- @compact
        wag = {
            --- `float`=1.6 the cycle speed multiplier
            cycle_speed = 1.6,
            --- `float`=1 decay factor when walking has stopped and offset remains.
            decay_speed = 1,
            --- `table` containing angular deviation while walking in the same format as @{gun.properties.recoil|an offset vector}. Acts as a multiplier on the figure-8 generated while walking.
            offset = { --used by update_walking() (or something)
                gun_axial = {x=1, y=-1},
                player_axial = {x=1,y=1},
            },
        },
        --- properties.charging
        --
        -- @table gun.properties.charging
        -- @see lvl1_fields.properties|properties
        -- @compact
        charging = { --#7
            --- `bool` defines wether the draw animation is played on swap (when loaded). Default true.
            require_draw_on_swap = true,
            --- `string` "none" bolt will never need to be charged after reload, "catch" when fired to empty bolt will not need to be charged after reload, "no_catch" bolt will always need to be charged after reload.
            bolt_charge_mode = "none", --"none"-chamber is always full, "catch"-when fired to dry bolt will not need to be charged after reload, "no_catch" bolt will always need to be charged after reload. Default "none"
            --- `float` the time it takes to swap to the gun
            draw_time = 1,
            --- `string` name of the animation to play from @{gun.properties.visuals.animations|visuals.animations}. Default "draw"
            draw_animation = "draw",
            --- `string` name of the sound to play from @{gun.properties.sounds|sounds}. Default "draw"
            draw_sound = "draw"
            --sound = soundspec
        },
        --- properties.ammo
        --
        -- @table gun.properties.ammo
        -- @see lvl1_fields.properties|properties
        -- @compact
        ammo = { --#8
            --- `bool` wether the gun only uses a magazine or accepts raw ammunition too.
            magazine_only = false,
            --capacity = 0, --this is only needed if magazine_only = false
            --- `table` a list of accepted bullet itemstrings
            accepted_rounds = {},
            --- `table` a list of accepted magazine itemstrings
            accepted_magazines = {},
            --- `string` the mag the gun starts with. Set to "empty" for no mag, otherwise it defaults to accepted_magazines[1] (if present)
            initial_mag = nil
        },
        --- properties.visuals
        --
        -- @table gun.properties.visuals
        -- @see lvl1_fields.properties|properties
        -- @compact
        visuals = {
            --- `vector` the offset of the muzzle from the very front of the model. Probably should be a negative Y value on most guns. Used to position the object that particle spawners attach to
            flash_offset = Vec.new(),
            --- name of mesh to display. Currently only supports b3d
            mesh = nil,
            --- list of textures to use.
            textures = {},
            --- scale multiplier. Default 1
            scale = 1,
            --- objects that are attached to the gun. This is especially useful for attachments. By default has an invisible object `guns4d_muzzle_smoke` for the particlespawner to attach to.
            -- if `mesh` is not present it will be drawn as a sprite
            --
            -- @example
            --      my_object = {
            --          mesh = "obj.obg",
            --          textures = {"blank.png"},
            --          visual_size = {x=1,y=1,z=1},
            --          offset = {x=0,y=0,z=0},
            --          backface_culling = false,
            --          glow = 0
            --      }
            attached_objects = {
                guns4d_muzzle_smoke = {
                    scale = .01
                }
            },
            --- toggles backface culling. Default true
            backface_culling = false,
            --- a table of animations. Indexes define the name of the animation to be refrenced by other functions of the gun.
            -- should be in the format `{x=integer,y=integer}`
            -- @example
            --      animations = {
            --          empty = {x=0,y=0}
            --          loaded = {x=1,y=1}
            --          fire = {x=10,y=20}
            --          draw = {x=24,y=30} --DEFAULT of charging.draw_animation.
            --      }
            --
            -- There are other animations which are variable which are not listed here, these are usually defined by properties such as:
            -- @{reload}, @{gun.properties.charging.draw_animation|draw_animation}
            animations = { --used by animations handler for idle, and default controls
                empty = {x=0,y=0},
                loaded = {x=1,y=1},
                fire = {x=0,y=0},
            },
        },
        --- properties.sounds
        --
        -- other fields are defined by other properties such as @{gun.properties.charging.draw_sound|properties.charging.draw_sound} and @{lvl1_fields.properties.reload|properties.reload}
        -- @table gun.properties.sounds
        -- @see lvl1_fields.properties|properties
        -- @see guns4d_soundspec|soundspec
        -- @compact
        sounds = { --this does not contain reload sound effects.
            --- sound player when firing the weapon
            fire = {
                {
                    __replace_old_table=true,
                    sound = "ar_firing",
                    max_hear_distance = 40, --far min_hear_distance is also this.
                    pitch = {
                        min = .95,
                        max = 1.05
                    },
                    gain = {
                        min = .9,
                        max = 1
                    }
                },
                {
                    __replace_old_table=true,
                    sound = "ar_firing_far",
                    min_hear_distance = 40,
                    max_hear_distance = 600,
                    pitch = {
                        min = .95,
                        max = 1.05
                    },
                    gain = {
                        min = .9,
                        max = 1
                    }
                }
            },
        },
    },
    --- `vector` containing the rotation offset from the current frame, this will be factored into the gun's direction if @{consts.ANIMATIONS_OFFSET_AIM}=true
    animation_rotation = vector.new(),
    --- `vector` containing the translational/positional offset from the current frame
    animation_translation = vector.new(),
    --- all offsets from @{offsets|gun.offset} of a type added together gun in the same format as a @{offsets|an offset} (that is, five vectors, `gun_axial`, `player_axial`, etc.). Note that if
    -- offsets are changed after update, this will not be updated automatically until the next update. update_rotations() must be called to do so.
    total_offsets = {
        gun_axial = vector.new(),       --rotation of the gun entity (around entity's own axis)
        player_axial = vector.new(),    --rotation around the eye (the player's axis)
        gun_trans = vector.new(),       --translation of the gun relative to attached bone's rotation
        player_trans = vector.new(),    --translation of the gun relative to the player's eye
        look_trans =  vector.new()      --translation/offset of the player's eye
    },
    --- velocities in the format of @{offsets|offsets}, but only containing angular (`gun_axial` and `player_axial`) offsets.
    velocities = {
        recoil = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
        init_recoil = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
        sway = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
    },
    --- offsets
    --
    -- a list of tables each containing offset vectors These are required for automatic initialization of offsets.
    -- note rotations are in degrees, and translations are in meters.
    -- @example
    --      recoil = {
    --          gun_axial = {x=0, y=0}, --rotation of the gun around it's origin.
    --          player_axial = {x=0, y=0}, --rotation of the gun around the bone it's attached to
    --          --translations of gun
    --          player_trans = {x=0, y=0, z=0}, --translation of the bone the gun is attached to
    --          eye_trans = {x=0, y=0, z=0}, --trnaslation of the player's look
    --          gun_tran = {x=0, y=0, z=0}s  --translation of the gun relative to the bone it's attachted to.
    --      }
    -- @table lvl1_fields.offsets
    -- @compact
    offsets = {
        ---
        recoil = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
            --move_dynamic_crosshair = false, this would make the dynamic crosshair move instead of get larger
        },
        ---
        sway = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
        },
        ---
        walking = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
            tick = 0,
            --velocity
        },
        ---
        breathing = {
            gun_axial = Vec.new(), --gun axial unimplemented...
            player_axial = Vec.new(),
        },
        ---
        look = {
            gun_axial = Vec.new(),
            player_axial = Vec.new(),
            look_trans = Vec.new(),
            player_trans = Vec.new(),
            gun_trans = Vec.new()
        },
    },
    --- consts
    --
    -- These are variables that are constant across the class and should usually not ever be changed by instnaces
    -- @table lvl1_fields.consts
    -- @compact
    consts = {
        --- frequency of keyframe samples for animation offsets and
        KEYFRAME_SAMPLE_PRECISION = .1,
        --- default max hear distance when not specified
        DEFAULT_MAX_HEAR_DISTANCE = 10,
        --- `fps`=60 animation fps i.e. during firing when no length is specified
        DEFAULT_FPS = 60,
        --- `bool`
        HAS_RECOIL = true,
        --- `bool`
        HAS_BREATHING = true,
        --- `bool`
        HAS_SWAY = true,
        --- `bool`
        HAS_WAG = true,
        --- `bool` wether the gun rotates on it's own axis instead of the player's view (i.e. ironsight misalignments)
        HAS_GUN_AXIAL_OFFSETS = true,
        --- wether animations create an offset
        ANIMATIONS_OFFSET_AIM = true,
        --- whether the idle animation changes or not
        LOOP_IDLE_ANIM = false,
        --- general gain multiplier for third persons when hearing sounds
        THIRD_PERSON_GAIN_MULTIPLIER = Guns4d.config.third_person_gain_multiplier,
        --- the root bone of the gun (for animation offsets)
        ROOT_BONE = "gun",
        --- `string`="magazine",the bone of the magazine in the gun (for dropping mags)
        MAG_BONE = "magazine",
        --- `string`="right_aimpoint", the bone which the right arm aims at to
        ARM_RIGHT_BONE = "right_aimpoint",
        --- `string`="left_aimpoint", the bone which the left arm aims at to
        ARM_LEFT_BONE = "left_aimpoint",
        --- `table` version of 4dguns this gun is made for. If left empty it will be assumed it is before 1.3.
        VERSION = {1, 2, 0}
    },
}
gun_default._PROPERTIES_UNSAFE = gun_default.properties
gun_default.properties = leef.class.proxy_table.new(gun_default.properties)
gun_default._consts_unsafe = gun_default.consts
gun_default.consts = leef.class.proxy_table.new(gun_default.consts)

minetest.register_entity("guns4d:gun_entity", {
    initial_properties = {
        visual = "mesh",
        mesh = "",
        textures = {},
        glow = 0,
        pointable = false,
        static_save = false,
        visual_size = {x=10,y=10,z=10},
        backface_culling = false
    },
    on_step = function(self)
        if not self.object:get_attach() then self.object:remove() end
    end
})

Guns4d.gun = gun_default
dofile(minetest.get_modpath("guns4d").."/classes/Gun-methods.lua")
dofile(minetest.get_modpath("guns4d").."/classes/Gun-construct.lua")

gun_default.construct = function(def)
    if def.instance then
        gun_default.construct_instance(def)
    elseif def.name ~= "__guns4d:default__" then
        gun_default.construct_base_class(def)
    end
end
Guns4d.gun = leef.class.new_class:inherit(gun_default)