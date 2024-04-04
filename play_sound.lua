--- implements tools for quickly playing audio.
-- @script play_sound

local sqrt = math.sqrt

--simple specification for playing a sound in relation to an action, acts as a layer of minetest.play_sound
--"gsp" guns4d-sound-spec
--first person for the gun holder, third person for everyone else. If first not present, third will be used.
--passes table directly to minetest.play_sound and adds a few additional parameters
--example:
--[[
    additional properties
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

    exclude_player
    to_player
        --when present it automatically plays positionless audio, as this is for first person effects.
]]

--- defines a sound.
-- This is passed to `minetest.sound_play` as a [ sound parameter table](https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sound-parameter-table)
-- however has the following changed or guns4d specific parameters.
-- @field min_hear_distance this is useful if you wish to play a sound which has a "far" sound, such as distant gunshots. incompatible `with to_player`
-- @field sounds a @{misc_helpers.weighted_randoms| weighted_randoms table} for randomly selecting sounds. The output will overwrite the `sound` field.
-- @field to_player 4dguns changes `to_player` so it only plays positionless audio (as it is only intended for first person audio). If set to string "from_player" and player present
-- @field player this is so to_player being set to "from_player". It's to be set to the player which fired the weapon.
-- @field delay delay the playing of the sound
-- @field has_speed_of_sound = true
-- @table guns4d_soundspec

local function handle_min_max(tbl)
    return tbl.min+(math.random()*(tbl.max-tbl.min))
end
--- allows you to play one or more sounds with more complex features, so sounds can be easily coded for guns without the need for functions.
-- WARNING: this function modifies the tables passed to it, use `Guns4d.table.shallow_copy()` for guns4d_soundspecs
-- @param sound_specs a @{guns4d_soundspec} or a list of @{guns4d_soundspec}s indexed my number. Also allows for shared fields. Example:
--      {
--          to_player = "singeplayer",
--          min_distance = 100, --soundspec_to_play1 & soundspec_to_play2 share this parameter (as well as the to_player)
--          soundspec_to_play1,
--          soundspec_to_play2
--      }
-- @return out a Guns4d sound handle (an integer)
-- @function Guns4d.play_sounds
local sound_handles = {}
local function play_sound(sound, soundspec, handle, i)
    if soundspec.delay then
        minetest.after(soundspec.delay, function()
            if sound_handles[handle] ~= false then
                sound_handles[handle][i] = minetest.sound_play(sound, soundspec, soundspec.ephemeral)
            end
        end)
    else
        sound_handles[handle][i] = minetest.sound_play(sound, soundspec)
    end
end
function Guns4d.play_sounds(soundspecs_list)
    --print(dump(soundspecs_list))
    --support a list of sounds to play
    if not soundspecs_list[1] then --turn into iteratable format.
        soundspecs_list = {soundspecs_list}
    end
    local applied = {}
    --all fields that aren't numbers will be copied over, allowing you to set fields across all sounds (i.e. pos, target player.), if already present it will remain the same.
    for field, v in pairs(soundspecs_list) do
        if type(field) ~= "number" then
            for _, spec in ipairs(soundspecs_list) do
                if not spec[field] then
                    spec[field] = v
                end
            end
            soundspecs_list[field] = nil --so it isn't iterated
        end
    end
    local handle = #sound_handles+1 --determine the sound handle before playing
    sound_handles[handle] = {}
    local handle_object = sound_handles[handle]
    for arg, soundspec in pairs(soundspecs_list) do
        if soundspec.to_player == "from_player" then soundspec.to_player = soundspec.player:get_player_name() end --setter of sound may not have access to this info, so add a method to use it.
        assert(not (soundspec.to_player and soundspec.min_distance), "in argument '"..tostring(arg).."' `min_distance` and `to_player` are incompatible parameters.")
        local sound = soundspec.sound
        local outval
        for i, v in pairs(soundspec) do
            if type(v) == "table" and v.min then
                soundspec[i]=handle_min_max(v)
            end
        end
        if type(sound) == "table" then
            sound = Guns4d.math.weighted_randoms(sound)
        end
        assert(sound, "no sound provided")
        if not mtul.paths.media_paths[(sound or "[NIL]")..".ogg"] then
            minetest.log("error", "no sound by the name `"..mtul.paths.media_paths[(sound or "[NIL]")..".ogg"].."`")
        end
        --print(dump(soundspecs_list), i)
        if soundspec.to_player then soundspec.pos = nil end
        if soundspec.min_hear_distance then
            local exclude_player_ref
            if soundspec.exclude_player then
                exclude_player_ref = minetest.get_player_by_name(soundspec.exclude_player)
            end
            --play sound for all players outside min hear distance
            for _, player in pairs(minetest.get_connected_players()) do
                soundspec.sound = nil
                local pos = player:get_pos()
                local dist = sqrt( sqrt((pos.x-soundspec.pos.x)^2+(pos.y-soundspec.pos.y)^2)^2 + (pos.z-soundspec.pos.z)^2)
                if (dist > soundspec.min_hear_distance) and (player~=exclude_player_ref) then
                    soundspec.exclude_player = nil --not needed anyway because we can just not play it for this player.
                    soundspec.to_player = player:get_player_name()
                    play_sound(sound, soundspec, handle, arg)
                end
            end
        else
            --print(dump(soundspec))
            soundspec.sound = nil
            play_sound(sound, soundspec, handle, arg)
        end
    end
    return handle
end
-- @param handle a Guns4d sound handle
-- @function Guns4d.get_sounds gets a list of currently playing Minetest sound handles from the Guns4d sound handle. Modification not reccomended.
function Guns4d.get_sounds(handle)
    return sound_handles[handle]
end
--- stops a list of sounds
-- @param handle_list a list of minetest sound handles to stop, this is the returned output of @{guns4d.play_sounds
-- @function Guns4d.stop_sounds
function Guns4d.stop_sounds(handle)
    local handle_list = (type(handle) == "table" and handle) or sound_handles[handle]
    if not handle_list then return false end
    sound_handles[handle] = false --indicate to not play any delayed noises.
    for i, v in pairs(handle_list) do
        minetest.sound_stop(v)
    end
    return true
end