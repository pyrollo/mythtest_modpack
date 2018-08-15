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

function set_equip_effect(player_name, item_name)
	local effect_def = minetest.registered_items[item_name] and
			minetest.registered_items[item_name].effect_equip or nil
	if effect_def then
		local effect = effects_api.get_effect_by_id(player_name,
		                                            'equip:'..item_name)
		if effect == nil then
			effect = table.copy(effect_def)
			effect.conditions = effect.conditions or {}
			effect.conditions.equiped_with = item_name
			effect.id = 'equip:'..item_name
            effect = effects_api.affect_player(player_name, effect)
			minetest.log('info', '[effect_api] New effect affected to "'
				..player_name..'" because wielding "'..item_name..'".')
		end
		-- Restart effect in case it was in fall phase
		effects_api.effect_restart(effect)
	end
end

function set_near_effect(player_name, node_name, pos)
	local effect_def = minetest.registered_nodes[node_name]
		and minetest.registered_nodes[node_name].effect_near or nil
	if effect_def then
		local effect = effects_api.get_effect_by_id(player_name,
		                                            'near:'..node_name)
		if effect == nil then
			effect = table.copy(effect_def)
			effect.conditions = effect.conditions or {}
			effect.conditions.near_node = { node_name = node_name,
				radius = effect.distance, active_pos = {} }
			effect.id = 'near:'..node_name
			effect = effects_api.affect_player(player_name, effect)
			minetest.log('info', '[effect_api] New effect affected to "'..
				player_name..'" because getting near to "'..
				node_name..'" node.')
		end

		-- Register node position as an active position
		effect.conditions.near_node
			.active_pos[minetest.hash_node_position(pos)] = true

		-- Restart effect in case it was in fall phase
		effects_api.effect_restart(effect)
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
				set_equip_effect(player_name, item_name)
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
				set_near_effect(player:get_player_name(), node.name, pos)
			end
		end
	end,
})

