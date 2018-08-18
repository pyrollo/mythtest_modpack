--[[
    effects_api mod for Minetest - Library to add temporary effects on players.
    (c) Pierre-Yves Rollo

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

local abm_interval = 1 -- Test smaller intervals

local function get_players_inside_radius(pos, radius)
	local objects = minetest.get_objects_inside_radius(pos, radius)
	local players = {}
	for _,obj in ipairs(objects) do
		if obj:is_player() then
			table.insert(players, obj)
		end
	end
	return players
end

function set_equip_effect(subject, item_name)
	local definition = minetest.registered_items[item_name] and
		minetest.registered_items[item_name].effect_equip or nil
	if definition then
		definition.id = 'equip:'..item_name
		local effect = effects_api.get_effect_by_id(subject, definition.id)
		if effect == nil then
			effect = effects_api.affect(subject, definition)
			effect:set_conditions({ equiped_with = item_name })
			effect:start()
			minetest.log('info', '[effect_api] New effect affected to '..
				effects_api.get_subject_string(subject)..
				' because wielding "'..item_name..'".')
		end
		-- Restart effect in case it was in fall phase
		effect:restart()
	end
end

function set_near_effect(subject, node_name, pos)
	local definition = minetest.registered_nodes[node_name] and
		minetest.registered_nodes[node_name].effect_near or nil
	if definition then
		definition.id = 'near:'..node_name
		local effect = effects_api.get_effect_by_id(subject, definition.id)
		if effect == nil then
			effect = effects_api.affect(subject, definition)
			effect:set_conditions({ near_node = {
				node_name = node_name,
				radius = definition.distance,
				active_pos = {}
			} } )
			effect:start()
			minetest.log('info', '[effect_api] New effect affected to '..
				effects_api.get_subject_string(subject)..
				' because getting near to "'..node_name..'" node.')
		end

		-- Register node position as an active position
		effect.conditions.near_node
			.active_pos[minetest.hash_node_position(pos)] = true

		-- Restart effect in case it was in fall phase
		effect:restart()
	end
end

-- A hack to detect if player has changed wielded item and wields an item
-- with effect.

local players_item_wield = {}

function effects_api.players_wield_hack(dtime)
	local stack, player_name, item_name
	for _, player in ipairs(minetest.get_connected_players()) do
		player_name = player:get_player_name()
		stack = player:get_wielded_item() 
		item_name = nil
		
		if stack then item_name = stack:get_name() end
		
		if players_item_wield[player_name] ~= item_name then
			-- Wield item changed
			if item_name then
				set_equip_effect(player, item_name)
			end
			players_item_wield[player_name] = item_name
		end
	end
end

-- ABM to detect if player gets nearby a nodes with effect (belonging to 
-- group:effect_trigger and having an effect in node definition)

minetest.register_abm({
	label = "effects_api player detection",
	nodenames="group:effect_trigger",
	interval=abm_interval,
	chance=1,
	catch_up=true,
	action = function(pos, node)
		local distance = minetest.registered_nodes[node.name]
		   and minetest.registered_nodes[node.name].effect_near
		   and minetest.registered_nodes[node.name].effect_near.distance or nil
		if distance then
			local players = get_players_inside_radius(pos, distance)
			for _, player in pairs(players) do
				set_near_effect(player, node.name, pos)
			end
		end
	end,
})

function effects_api.on_use_tool_callback(itemstack, user, pointed_thing)
	local def = minetest.registered_items[itemstack:get_name()]

	if def then
		if def.effect_use_on and pointed_thing.type == "object" then
			effects_api.affect(pointed_thing.ref, def.effect_use_on)
		end
		if def.effect_use then
			effects_api.affect(user, def.effect_use)
		end
	end
end

--[[
-- TODO: manage lack of CMI module
if minetest.global_exists("cmi") then
	cmi.register_on_stepmob(mob_on_step_callback)
else
	minetest.log('warning', "[effects_api] CMI mod not found, won't be able to manage mob effects")
end
--]]

