local Vec = vector
local default_def = {
    --name = <string>
    --itemstring = <string>
    --textures = {<textures>}
    --mesh = <meshname> (media)
    hip = {
        offset = Vec.new(0,0,.2),
    },
    ads = {
        offset = Vec.new(0,0,.1),
        horizontal_offset = .1,
    },
    recoil = {
        velocity_correction_factor = {
            gun_axial = 2,
            player_axial = 2,
        },
        target_correction_factor = { --angular correction rate per second: time_since_fire*target_correction_factor
            gun_axial = 30,
            player_axial = 1,
        },
        target_correction_max_rate = { --the cap for time_since_fire*target_correction_factor
            gun_axial = 100,
            player_axial = 6,
        },
        angular_velocity_max = {
            gun_axial = 0,
            player_axial = 0,
        },
        angular_velocity = {
            gun_axial = {x=.1, y=.1},
            player_axial = {x=.1, y=.1},
        },
    },
    firerateRPM = 600,
    consts = {
        HIP_PLAYER_GUN_ROT_RATIO = .6
    },
    aim_time = .5
}
local valid_ctrls = {
    up=true,
    down=true,
    left=true,
    right=true,
    jump=true,
    aux1=true,
    sneak=true,
    dig=true,
    place=true,
    LMB=true,
    RMB=true,
    zoom=true,
}
function Guns4d.register_gun_default(def)
    assert(def, "no definition table provided")
    assert(def.name, "no name provided when registering gun")
    assert(def.itemstring, "no itemstring provided when registering gun")
    local new_def = {}
    new_def.consts = def.consts
    new_def.name = def.name; def.name = nil
    new_def.itemstring = def.itemstring; def.itemstring = nil
    new_def.properties = table.fill(default_def, def)
    --validate controls
    if new_def.properties.controls then
        for i, control in pairs(new_def.properties.controls) do
            if not (i=="on_use") and not (i=="on_secondary_use") then
                assert(control.conditions, "no conditions provided for control")
                for _, condition in pairs(control.conditions) do
                    if not valid_ctrls[condition] then
                        assert(false, "invalid key: '"..condition.."'")
                    end
                end
            end
        end
    end
    --gun is registered within this function
    Guns4d.gun:inherit(new_def)
end