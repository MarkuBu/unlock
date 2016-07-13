local function get_locked_chest_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec =
		"size[8,9]" ..
		default.gui_bg ..
		default.gui_bg_img ..
		default.gui_slots ..
		"list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]" ..
		"list[current_player;main;0,4.85;8,1;]" ..
		"list[current_player;main;0,6.08;8,3;8]" ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]" ..
		default.get_hotbar_bg(0,4.85)
 return formspec
end

local function has_locked_chest_privilege(meta, player)
	local name = ""
	if player then
		if minetest.check_player_privs(player, "protection_bypass") then
			return true
		end
		name = player:get_player_name()
	end
	if name ~= meta:get_string("owner") then
		return false
	end
	return true
end

minetest.override_item("default:chest_locked", {
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index,
			to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		if not has_locked_chest_privilege(meta, player) and minetest.is_protected(pos, player:get_player_name()) then
			return 0
		end
		return count
	end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if not has_locked_chest_privilege(meta, player) and minetest.is_protected(pos, player:get_player_name()) then
			return 0
		end
		return stack:get_count()
	end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if not has_locked_chest_privilege(meta, player) and minetest.is_protected(pos, player:get_player_name()) then
			return 0
		end
		return stack:get_count()
	end,
	on_rightclick = function(pos, node, clicker)
		local meta = minetest.get_meta(pos)
		if has_locked_chest_privilege(meta, clicker) or not minetest.is_protected(pos, clicker:get_player_name()) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"default:chest_locked",
				get_locked_chest_formspec(pos)
			)
		end
	end,
})

local transform = {
	{
		{ v = "_a", param2 = 3 },
		{ v = "_a", param2 = 0 },
		{ v = "_a", param2 = 1 },
		{ v = "_a", param2 = 2 },
	},
	{
		{ v = "_b", param2 = 1 },
		{ v = "_b", param2 = 2 },
		{ v = "_b", param2 = 3 },
		{ v = "_b", param2 = 0 },
	},
	{
		{ v = "_b", param2 = 1 },
		{ v = "_b", param2 = 2 },
		{ v = "_b", param2 = 3 },
		{ v = "_b", param2 = 0 },
	},
	{
		{ v = "_a", param2 = 3 },
		{ v = "_a", param2 = 0 },
		{ v = "_a", param2 = 1 },
		{ v = "_a", param2 = 2 },
	},
}

local door_toggle = function(pos, clicker)
	local meta = minetest.get_meta(pos)
	local def = minetest.registered_nodes[minetest.get_node(pos).name]
	local name = def.door.name

	local state = meta:get_string("state")
	if state == "" then
		-- fix up lvm-placed right-hinged doors, default closed
		if minetest.get_node(pos).name:sub(-2) == "_b" then
			state = 2
		end
	else
		state = tonumber(state)
	end

	if clicker and not minetest.check_player_privs(clicker, "protection_bypass") and minetest.is_protected(pos, clicker:get_player_name()) then
		local owner = meta:get_string("doors_owner")
		if owner ~= "" then
			if clicker:get_player_name() ~= owner then
				return false
			end
		end
	end

	local old = state
	-- until Lua-5.2 we have no bitwise operators :(
	if state % 2 == 1 then
		state = state - 1
	else
		state = state + 1
	end

	local dir = minetest.get_node(pos).param2
	if state % 2 == 0 then
		minetest.sound_play(def.door.sounds[1], {pos = pos, gain = 0.3, max_hear_distance = 10})
	else
		minetest.sound_play(def.door.sounds[2], {pos = pos, gain = 0.3, max_hear_distance = 10})
	end

	minetest.swap_node(pos, {
		name = name .. transform[state + 1][dir+1].v,
		param2 = transform[state + 1][dir+1].param2
	})
	meta:set_int("state", state)

	return true
end

minetest.override_item("doors:door_steel_a", {
	can_dig = function(pos, digger)
		if minetest.is_protected(pos, digger:get_player_name()) then
			return false
		else
			return true
		end
	end,
	on_rightclick = function(pos, node, clicker)
		door_toggle(pos, clicker)
	end
})

minetest.override_item("doors:door_steel_b", {
	can_dig = function(pos, digger)
		if minetest.is_protected(pos, digger:get_player_name()) then
			return false
		else
			return true
		end
	end,
	on_rightclick = function(pos, node, clicker)
		door_toggle(pos, clicker)
	end
})

function trapdoor_toggle(pos, clicker)
	if clicker and not minetest.check_player_privs(clicker, "protection_bypass") and minetest.is_protected(pos, clicker:get_player_name()) then
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("doors_owner")
		if owner ~= "" then
			if clicker:get_player_name() ~= owner then
				return false
			end
		end
	end

	local node = minetest.get_node(pos)
	local def = minetest.registered_nodes[node.name]

	if string.sub(node.name, -5) == "_open" then
		minetest.sound_play(def.sound_close, {pos = pos, gain = 0.3, max_hear_distance = 10})
		minetest.swap_node(pos, {name = string.sub(node.name, 1, string.len(node.name) - 5), param1 = node.param1, param2 = node.param2})
	else
		minetest.sound_play(def.sound_open, {pos = pos, gain = 0.3, max_hear_distance = 10})
		minetest.swap_node(pos, {name = node.name .. "_open", param1 = node.param1, param2 = node.param2})
	end
end

minetest.override_item("doors:trapdoor_steel", {
	can_dig = function(pos, digger)
		if minetest.is_protected(pos, digger:get_player_name()) then
			return false
		else
			return true
		end
	end,
	on_rightclick = function(pos, node, clicker)
		trapdoor_toggle(pos, clicker)
	end
})

minetest.override_item("doors:trapdoor_steel_open", {
	can_dig = function(pos, digger)
		if minetest.is_protected(pos, digger:get_player_name()) then
			return false
		else
			return true
		end
	end,
	on_rightclick = function(pos, node, clicker)
		trapdoor_toggle(pos, clicker)
	end
})
