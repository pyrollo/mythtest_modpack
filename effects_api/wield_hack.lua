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
			if item_name and
			   minetest.registered_items[item_name] and
			   minetest.registered_items[item_name].effect then
			   	effects_api.affect_player(player_name, 
			   		minetest.registered_items[item_name].effect)
				minetest.log('info', '[effect_api] New effect affected to "'..
					player_name..'" because wielding "'..item_name..'".')
			end
			players_item_wield[player_name] = item_name
		end
	end
end
