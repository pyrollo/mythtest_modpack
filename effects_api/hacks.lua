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

-- A hack to detect if player has changed wielded item and wields an item
-- with effect.

local players_item_wield = {}

function effects_api.players_wield_hack(dtime)
	local stack, player_name, item_name
	for _, player in ipairs(minetest.get_connected_players()) do
		player_name = player:get_player_name()
		stack = player:get_wielded_item() 
		item_name = nil
		
		if stack then
			item_name = stack:get_name()
		end
		
		if players_item_wield[player_name] ~= item_name then
			if item_name and minetest.registered_items[item_name] and
			   minetest.registered_items[item_name].effect then
                local effect = minetest.registered_items[item_name].effect
                effect.conditions.equiped_with=item_name
			   	effects_api.affect_player(player_name, effect)
				minetest.log('info', '[effect_api] New effect affected to "'
                    ..player_name..'" because wielding "'..item_name..'".')
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
        local def = minetest.registered_nodes(node.name)
        if def and def.effect and def.effect.distance then 
            local players = get_players_inside_radius(pos, def.effect.radius)
            local effect
            
            for _, player in pairs(players) do
                local effect = 
                    effects_apî.get_effect_by_id(player:get_player_name(),
                    'near:'..node_name)

                if effect == nil then
                    effect = table.copy(def.effect)
                    effect.conditions.near_node={ node_name = node.name, 
                        radius = effect.distance, active_pos = {} }
                    effect.id = 'near:'..node_name

                    affect_player(player:get_player_name(), effect)

                    minetest.log('info', 
                        '[effect_api] New effect affected to "'
                        ..player_name..'" because getting near to  "'
                        ..node_name..'" node.')
                end
                effect.conditions.near_node
                    .active_pos[minetest.hash_node_position(pos)] = true
            end
        end
    end,
})


