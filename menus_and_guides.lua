local guide_players_wielditem = {}
minetest.register_tool("guns4d:guide_book", {
    description = "mysterious gun related manual",
    inventory_image = "guns4d_guide.png",
    on_use = function(itemstack, player, pointed)
        local hud_flags = player:hud_get_flags()
        guide_players_wielditem[player]=hud_flags.wielditem
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
    player:hud_set_flags({wielditem=false})
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
        if (fields.page_number and tonumber(fields.page_number)) or not fields.page_number then
            fields.page_number = fields.page_number or 1
            local num = tonumber(fields.page_number)+((fields.page_next and 1) or (fields.page_back and -1) or 0)
            Guns4d.show_guide(player,
                (pages[num] and num)   or   ((num > 1) and #pages)   or   1
            )
        end
        if fields.quit then
            player:hud_set_flags({wielditem=guide_players_wielditem[player]})
            guide_players_wielditem[player]=nil
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
--[[local allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
end]]
local allow_put = function(inv, listname, index, stack, player, gun)
    local props = gun.properties
    local atthan = gun.attachment_handler
    if props.inventory.attachment_slots[listname] and atthan:can_add(stack, listname) then
        return 1
    end
    return 0
end
--[[local allow_take = function(inv, listname, index, stack, player, gun)
end]]
local on_put = function(inv, listname, index, stack, player, gun)
    gun.attachment_handler:add_attachment(stack, listname)
end
local on_take = function(inv, listname, index, stack, player, gun)
    gun.attachment_handler:remove_attachment(stack, listname)
end
function Guns4d.show_gun_menu(gun)
    local props = gun.properties
    local player = gun.player
    local pname = player:get_player_name()
    local inv = minetest.get_inventory({type="player", name=pname})
    local window = minetest.get_player_window_information(pname)
    local listname = Guns4d.config.inventory_listname
    local form_dimensions = {x=20,y=15}

    local inv_height=4+((4-1)*.125)
    local hotbar_length = player:hud_get_hotbar_itemcount()
    local form = "\
    formspec_version[7]\
     size[".. form_dimensions.x ..",".. form_dimensions.y .."]"

    local hotbar_height = math.ceil(hotbar_length/8)
    form = form.."\
    scroll_container[.25,"..(form_dimensions.y)-inv_height-1.25 ..";10,5;player_inventory;vertical;.05]\
        list[current_player;"..listname..";0,0;"..hotbar_length..","..hotbar_height..";]\
        list[current_player;"..listname..";0,1.5;8,3;"..hotbar_length.."]\
    scroll_container_end[]\
    "
    if math.ceil(inv:get_size("main")/8) > 4 then
        local h = math.ceil(inv:get_size("main")/8)
        form=form.."\
        scrollbaroptions[max="..h+((h-1)*.125).."]\
        scrollbar[10.25,"..(form_dimensions.y)-inv_height-1.25 ..";.5,5;vertical;player_inventory;0]\
        "
    end
    --display gun preview
    local len = math.abs(gun.model_bounding_box[3]-gun.model_bounding_box[6])/props.visuals.scale
    local hei = math.abs(gun.model_bounding_box[2]-gun.model_bounding_box[5])/props.visuals.scale
    local offsets = {x=(-gun.model_bounding_box[6]/props.visuals.scale)-(len/2), y=(gun.model_bounding_box[5]/props.visuals.scale)+(hei/2)}

    local meter_scale = 15
    local image_scale = meter_scale*(props.inventory.render_size or 1)
    local gun_gui_offset = {x=0,y=-2.5}
    form = form.."container["..((form_dimensions.x-image_scale)/2)+gun_gui_offset.x.. ","..((form_dimensions.y-image_scale)/2)+gun_gui_offset.y.."]"
    if props.inventory.render_image then
        form = form.."image["
        ..(offsets.x*meter_scale) ..","
        ..(offsets.y*meter_scale) ..";"
        ..image_scale..","
        ..image_scale..";"
        ..props.inventory.render_image.."]"
    end
    local attachment_inv = minetest.create_detached_inventory("guns4d_inv_"..pname, {
        --allow_move = allow_move,
        allow_put = function(inv, putlistname, index, stack, player)
            return allow_put(inv, putlistname, index, stack, player, gun)
        end,
        on_put = function(inv, putlistname, index, stack, player)
            return on_put(inv, putlistname, index, stack, player, gun)
        end,
        on_take = function(inv, putlistname, index, stack, player)
            return on_take(inv, putlistname, index, stack, player, gun)
        end
        --allow_take = allow_take
    })
    if props.inventory.attachment_slots then
        for i, attachment in pairs(props.inventory.attachment_slots) do
            attachment_inv:set_size(i, attachment.slots or 1)
            form = form.."label["..(image_scale/2)+(attachment.formspec_offset.x or 0)-.75 ..","..(image_scale/2)+(-attachment.formspec_offset.y or 0)-.2 ..";"..(attachment.description or i).."]"
            --list[<inventory location>;<list name>;<X>,<Y>;<W>,<H>;<starting item index>]
            local width = attachment.slots or 1
            width = width+((width-1)*.125)
            form = form.."list[detached:guns4d_inv_"..pname..";"..i..";"..(image_scale/2)+(attachment.formspec_offset.x or 0)-(width/2)..","..(image_scale/2)+(-attachment.formspec_offset.y or 0)..";3,5;]"
        end
    end
    form = form.."container_end[]"
    minetest.show_formspec(gun.handler.player:get_player_name(), "guns4d:inventory", form)
end

minetest.register_chatcommand("guns4d_inv", {
    description = "Show the gun menu.",
    func = function(pname, arg)
        local gun = Guns4d.players[pname].gun
        if gun then
            Guns4d.show_gun_menu(gun)
        else
            minetest.chat_send_player(pname, "cannot show the inventory menu for a gun which is not help")
        end
    end
})


