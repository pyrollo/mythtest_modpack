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

-- A hack to detect if player has changed wielded item and wields an item
-- with effect.

local players_item_wield = {}

local function set_conditions(effect, conditions)
	if next(conditions,nil) then
		if effect.conditions == nil then
			effect.conditions = {}
		end

		for key, value in pairs(conditions) do
			effect.conditions[key] = value
		end
	end
end

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
				set_conditions(
				   minetest.registered_items[item_name].effect,
				   { equiped_with=item_name })
			   	effects_api.affect_player(player_name, 
			   		minetest.registered_items[item_name].effect)
				minetest.log('info', '[effect_api] New effect affected to "'..
					player_name..'" because wielding "'..item_name..'".')
			end
			players_item_wield[player_name] = item_name
		end
	end
end
