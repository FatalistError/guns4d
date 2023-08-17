Guns4d.node_properties = {}
--{["default:gravel"] = {rha=2, random_deviation=1, behavior="normal"}, . . . }
--behavior types:
--normal, bullets hit and penetrate
--breaks, bullets break it but still applies RHA/randomness values (etc)
--ignore, bullets pass through

--unimplemented

--liquid, bullets hit and penetrate, but effects are different
--damage, bullets hit and penetrate, but replace with "replace = _"

--mmRHA of wood .05 (mostly arbitrary)
--{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1}

--this is really the best way I could think of to do this
--in a perfect world you could perfectly balance each node, but a aproximation will have to do
--luckily its still an option, if you are literally out of your fucking mind.
minetest.register_on_mods_loaded(function()
    for i, v in pairs(minetest.registered_nodes) do
        local groups = v.groups
        local RHA = 1
        local random_deviation = 1
        local behavior_type = "normal"
        if groups.wood then
            RHA = RHA*.1
            random_deviation = random_deviation/groups.wood
        end
        if groups.oddly_breakable_by_hand then
            RHA = RHA / groups.oddly_breakable_by_hand
        end
        if groups.choppy then
            RHA = RHA*.5
        end
        if groups.flora or groups.grass then
            RHA = 0
            random_deviation = 0
            behavior_type = "ignore"
        end
        if groups.leaves then
            RHA = .0001
            random_deviation = .005
        end
        if groups.stone then
            RHA = 1/groups.stone
            random_deviation = .5
        end
        if groups.cracky then
            RHA = RHA*(.5/groups.cracky)
            random_deviation = random_deviation*(.5/groups.cracky)
        end
        if groups.crumbly then
            RHA = RHA/groups.crumbly
        end
        if groups.soil then
            RHA = RHA*(groups.soil*2)
        end
        if groups.sand then
            RHA = RHA*(groups.sand*2)
        end
        if groups.liquid then
            --behavior type here
            RHA = .5
            random_deviation = .1
        end
        Guns4d.node_properties[i] = {mmRHA=RHA*1000, random_deviation=random_deviation, behavior=behavior_type}
    end
end)
function Guns4d.override_node_propertoes(node, table)
    --TODO: check if node is valid
    assert(type(table.mmRHA)=="number", "no mmRHA value provided in override")
    assert(type(table.behavior)=="string", "no behavior type provided in override")
    assert(type(table.behavior)=="number", "no random_deviation value provided in override")
    Guns4d.node_properties[node] = table
end