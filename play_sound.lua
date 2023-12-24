--simple specification for playing a sound in relation to an action, acts as a layer of minetest.play_sound
--"gsp" guns4d-sound-spec
--first person for the gun holder, third person for everyone else. If first not present, third will be used.
--passes table directly to minetest.play_sound and adds a few additional parameters
--example:
--[[
    additional properties
    first_person = playername,
    second_person = playername
    sounds = { --weighted randoms:
        fire_fp = .5.
        fire_fp_2 = .2.
        fire_fp_3 = .3
    },
    pitch = {
        min = .6,
        max = 1
    },
    gain = 1, --format for pitch and gain is interchangable.
    min_hear_distance = 20, --this is for distant gunshots, for example. Entirely optional. Cannot be used with to_player

    to_player
        --when present it automatically plays positionless audio, as this is for first person effects.
]]
local sqrt = math.sqrt
function Guns4d.play_sounds(...)
    local args = {...}
    local out = {}
    assert(args[1], "no arguments provided")
    for i, soundspec in pairs(args) do
        assert(not (soundspec.to_player and soundspec.min_distance), "in argument '"..tostring(i).."' `min_distance` and `to_player` are incompatible parameters.")
        local sound
        local outval
        if type(soundspec.pitch) == "table" then
            local pitch = soundspec.pitch
            soundspec.pitch = pitch.min+(math.random()*(pitch.max-pitch.min))
        end
        if type(soundspec.gain) == "table" then
            local gain = soundspec.gain
            soundspec.pitch = gain.min+(math.random()*(gain.max-gain.min))
        end
        if type(soundspec.sound) == "table" then
            sound = math.weighted_randoms(soundspec.sound)
        end
        if soundspec.to_player then soundspec.pos = nil end
        if soundspec.min_hear_distance then
            local exclude_player_ref
            if soundspec.exclude_player then
                exclude_player_ref = minetest.get_player_by_name(soundspec.exclude_player)
            end
            for _, player in pairs(minetest.get_connected_players()) do
                local pos = player:get_pos()
                local dist = sqrt( sqrt(pos.x^2+pos.y^2)^2 +pos.z^2 )
                if (dist > soundspec.min_distance) and (player~=exclude_player_ref) then
                    soundspec.exclude_player = nil --not needed anyway because we can just not play it for this player.
                    soundspec.to_player = player:get_player_name()
                    outval = minetest.play_sound(sound, soundspec)
                end
            end
        else
            outval = minetest.play_sound(sound, soundspec)
        end
        out[i] = outval
    end
    return out
end
function Guns4d.stop_sounds(handle_list)
end