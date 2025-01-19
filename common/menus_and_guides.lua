local guide_players_wielditem = {}
minetest.register_tool("guns4d:guide_book", {
    description = "mysterious gun related manual",
    inventory_image = "guns4d_guide.png",
    on_use = function(itemstack, player, pointed)
        Guns4d.show_guide(player,1)
    end,
    on_place = function(itemstack, player, pointed_thing)
        if pointed_thing and (pointed_thing.type == "node") then
            local pname = player:get_player_name()
            local node = minetest.get_node(pointed_thing.under).name
            local props = Guns4d.node_properties[node]
            if props.behavior~="ignore" then
                minetest.chat_send_player(pname,  math.ceil(props.mmRHA).."mm of \"Rolled Homogenous Armor\" per meter")
                minetest.chat_send_player(pname,  (math.ceil(props.random_deviation*100)/100).."° of deviation per meter")
            else
                minetest.chat_send_player(pname,  "bullets pass through this block like air")
            end
        end
    end
})
local pages = {
    --first page, diagram of m4 and controls
    "\
    size[7.5,10.5]\
    image[0,0;7.5,10.5;guns4d_guide_cover.png]\
    ",
    "\
    size[15,10.5]\
    image[0,0;15,10.5;m4_diagram_text_en.png]\
    image[0,0;15,10.5;m4_diagram_overlay.png]\
    ",
    "\
    size[15,10.5]\
    image[0,0;15,10.5;guns4d_guide_page_2.png]\
    "
    --
}
function Guns4d.show_guide(player, page)
    if not guide_players_wielditem[player] then
        local hud_flags = player:hud_get_flags()
        guide_players_wielditem[player]=hud_flags.wielditem
        player:hud_set_flags({wielditem=false})
    end
    local form = pages[page]
    form = "\
    formspec_version[6]\
    "..form
    if page==1 then
        form=form.."\
        button[5.5,9.5;.7,.5;page_next;next]"
    else
        form=form.."\
        image[0,0;15,10.5;page_crinkles.png]\
        button[13.75,9.75;.7,.5;page_next;next]\
        button[.6,9.75;.7,.5;page_back;back]\
        field[5.6,9.8;.7,.5;page_number;page;"..page.."]\
        field_close_on_enter[page_number;false]\
        label[6.25,10.05; /"..#pages.."]"
    end
    --button[<X>,<Y>;<W>,<H>;page_turn;<label>]\
    --field[<X>,<Y>;<W>,<H>;<name>;<label>;<default>]

    minetest.show_formspec(player:get_player_name(), "guns4d:guide", form)
end
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "guns4d:guide" then
        if fields.quit then
            player:hud_set_flags({wielditem=guide_players_wielditem[player]})
            guide_players_wielditem[player]=nil
        elseif (fields.page_number and tonumber(fields.page_number)) or not fields.page_number then
            fields.page_number = fields.page_number or 1
            local num = tonumber(fields.page_number)+((fields.page_next and 1) or (fields.page_back and -1) or 0)
            Guns4d.show_guide(player,
                (pages[num] and num)   or   ((num > 1) and #pages)   or   1
            )
        end
    end
end)
minetest.register_chatcommand("guns4d_guide", {
    description = "open the Guns4d guide book",
    func = function(pname, arg)
        local player = minetest.get_player_by_name(pname)
        local flags = player:hud_get_flags()
        guide_players_wielditem[player]=flags.wielditem
        Guns4d.show_guide(player,1)
    end
})
local function lstdmn(h,w)
    return {x=w+((w-1)*.125), y=h+((h-1)*.125)}
end

minetest.register_chatcommand("guns4d_inv", {
    description = "Show the gun menu.",
    func = function(pname, arg)
        local gun = Guns4d.players[pname].gun
        if gun then
            gun:open_inventory_menu()
        else
            minetest.chat_send_player(pname, "cannot show the inventory menu for a gun which is not help")
        end
    end
})


