--- implements tools for quickly playing audio.
-- @module play_sound

local sqrt = math.sqrt



--- Guns4d soundspec
--
-- simple specification for playing a sound in relation to an action, acts as a layer of minetest.play_sound.
-- ATTENTION: read lua_api.md for more parameters! all parameters from there are valid unless otherwise stated here, these are auxillary.
-- @table guns4d_soundspec
-- @compact
-- @field min_hear_distance `float` this is useful if you wish to play a sound which has a "far" sound, such as distant gunshots. incompatible `with to_player`
-- @field sounds `table` a @{misc_helpers.weighted_randoms| weighted_randoms table} for randomly selecting sounds. The output will overwrite the `sound` field.
-- @field to_player `objRef` 4dguns changes `to_player` so it only plays positionless audio (as it is only intended for first person audio). If set to string "from_player" and player present
-- @field player `objRef` this is so to_player being set to "from_player". It's to be set to the player which fired the weapon.
-- @field delay `float` delays the playing of the sound
-- @field attenuation_rate `float` the rate of dropoff for a sound. I figure this is a bit more intuitive then jacking the gain up super high for every sound... Set the default in config.
-- @field split_audio_by_perspective `bool` [GUN CLASS SPECIFIC] tells the gun wether to split into third and first person (positionless) audio and adjust gain.
-- @field third_person_gain_multiplier `float` [GUN CLASS SPECIFIC] replaces the constant/config value "third_person_gain_multiplier/THIRD_PERSON_GAIN_MULTIPLIER".
-- @example
--    soundspec = {
--      sounds = { --weighted randoms
--          fire_fp = .5.
--          fire_fp_2 = .2.
--          fire_fp_3 = .3
--      },
--      pitch = {
--          min = .6,
--          max = 1
--      },
--      gain = 1, --format for pitch and gain is interchangable.
--      min_hear_distance = 20, --this is for distant gunshots, for example. Entirely optional. Cannot be used with to_player
--      exclude_player
--      to_player
--        --when present it automatically plays positionless audio, as this is for first person effects.
--    }
--

local function handle_min_max(tbl)
    return tbl.min+(math.random()*(tbl.max-tbl.min))
end
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

--- allows you to play one or more sounds with more complex features, so sounds can be easily coded for guns without the need for functions.
--
-- WARNING: this function modifies the tables passed to it, use `Guns4d.table.shallow_copy()` or `table.copy` for inputted soundspecs
-- @example
--      {
--          to_player = "singeplayer",
--          min_distance = 100, --soundspec_to_play1 & soundspec_to_play2 will share this field as it is in the higher level table (as well as the above field)
--          soundspec_to_play1, --a sound parameter table
--          soundspec_to_play2
--      }
-- @tparam table soundspecs_list a list a list of @{guns4d_soundspec|soundspecs} optionally accompanied with fields to be used in all of them.
-- @treturn integer guns4d sound handle, used by stop_sounds & get_sounds
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
    --local handle_object = sound_handles[handle]
    for arg, soundspec in pairs(soundspecs_list) do
        if soundspec.to_player == "from_player" then soundspec.to_player = soundspec.player:get_player_name() end --setter of sound may not have access to this info, so add a method to use it.
        assert(not (soundspec.to_player and soundspec.min_distance), "in argument '"..tostring(arg).."' `min_distance` and `to_player` are incompatible parameters.")
        local sound = soundspec.sound
        for i, v in pairs(soundspec) do
            if type(v) == "table" and v.min then
                soundspec[i]=handle_min_max(v)
            end
        end
        if type(sound) == "table" then
            sound = Guns4d.math.weighted_randoms(sound)
        end
        assert(sound, "no sound provided")
        if not leef.paths.media_paths[(sound or "[NIL]")..".ogg"] then
            minetest.log("error", "no sound by the name `"..leef.paths.media_paths[(sound or "[NIL]")..".ogg"].."`")
        end
        local exclude_player_ref = soundspec.exclude_player
        if type(soundspec.exclude_player)=="string" then
            exclude_player_ref = minetest.get_player_by_name(soundspec.exclude_player)
        elseif soundspec.exclude_player then
            exclude_player_ref = soundspec.exclude_player
            soundspec.exclude_player = exclude_player_ref:get_player_name()
        end
        --print(dump(soundspecs_list), i)
        if soundspec.to_player then soundspec.pos = nil end
        --play sound for all players outside min hear distance
        local original_gain = soundspec.gain or 1
        local attenuation_rate = soundspec.attenuation_rate or Guns4d.config.default_audio_attenuation_rate
        local player_list = ((not soundspec.to_player) and minetest.get_connected_players()) or {minetest.get_player_by_name(soundspec.to_player)}
        for _, player in pairs(player_list) do
            soundspec.sound = nil
            local pos = player:get_pos()
            local dist = 0
            if soundspec.pos then
                dist = sqrt( sqrt((pos.x-(soundspec.pos.x))^2+(pos.y-soundspec.pos.y)^2)^2 + (pos.z-soundspec.pos.z)^2)
            end
            if ((not soundspec.max_hear_distance) or (dist <= soundspec.max_hear_distance)) and ((not soundspec.min_hear_distance) or (dist > soundspec.min_hear_distance)) and (player~=exclude_player_ref) then
                soundspec.exclude_player = nil --not needed anyway because we can just not play it for this player.
                soundspec.to_player = player:get_player_name()
                soundspec.gain = original_gain/(Guns4d.math.clamp((dist-(soundspec.min_hear_distance or 0))*attenuation_rate, 1, math.huge)^2) --so i found out the hard way that it doesn't fucking reduce volume by distance if there's a to_player. Kind of pisses me off.
                play_sound(sound, soundspec, handle, arg)
            end
        end
    end
    return handle
end

--- gets a list of currently playing Minetest sound handles from the Guns4d sound handle. Modification of table highly discouraged.
-- @tparam integer handle a sound handle as returned by play_sounds
-- @treturn table a list of sound handles as returned by minetest.sound_play()
function Guns4d.get_sounds(handle)
    return sound_handles[handle]
end
--- stops a list of sounds
-- @tparam integer|table handle a guns4d sound handle OR list of minetest sound handles to stop
-- @treturn bool returns true if successful.
function Guns4d.stop_sounds(handle)
    local handle_list = (type(handle) == "table" and handle) or sound_handles[handle]
    if not handle_list then return false end
    if type(handle) == "number" then
        sound_handles[handle] = false --indicate to not play any delayed noises.
    end
    for i, v in pairs(handle_list) do
        minetest.sound_stop(v)
    end
    return true
end