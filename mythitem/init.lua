-- 3D Armor integration
if minetest.global_exists("armor") then
	-- Allow extra stuff to be equiped also
	if armor.elements then
		table.insert(armor.elements, "neck")
		table.insert(armor.elements, "finger")
	end
end

minetest.register_tool("mythitem:ring", {
	description = "Blind ring",
	inventory_image = "mythitem_ring_simple.png",
	groups = { armor_finger = 1 },
	texture = "mythitem_transparent", 
	preview = "mythitem_ring_armor_preview",
	effect_equip = {
		raise = 2,
		fall = 2,
		impacts = { vision=0 },
	}
})

minetest.register_tool("mythitem:ring2", {
	description = "Invisibility ring",
	inventory_image = "mythitem_ring_thick.png",
	groups = { armor_finger = 1 },
	texture = "mythitem_transparent", 
	preview = "mythitem_ring_armor_preview",
})

minetest.register_tool("mythitem:ring3", {
	description = "Invisibility ring",
	inventory_image = "mythitem_ring_gem.png",
	groups = { armor_finger = 1 },
	texture = "mythitem_transparent", 
	preview = "mythitem_ring_armor_preview",
	effect_equip = {
		impacts = { texture={ opacity = 0 } },
	}
})

minetest.register_tool("mythitem:ring4", {
	description = "Ring of darkness",
	inventory_image = "mythitem_ring_spikes.png",
	groups = { armor_finger = 1 },
	texture = "mythitem_transparent", 
	preview = "mythitem_ring_armor_preview",
	effect_equip = {
		impacts = { daylight = 0 },
		raise = 1,
		fall = 1,
	}
})

minetest.register_tool("mythitem:ring5", {
	description = "Bad ring",
	inventory_image = "mythitem_ring_double_spikes.png",
	groups = { armor_finger = 1 },
	texture = "mythitem_transparent", 
	preview = "mythitem_ring_armor_preview",
	effect_equip = { 
		impacts = { damage = {1, 3} }
	}
})

minetest.register_tool("mythitem:ring6", {
	description = "Thick gem ring",
	inventory_image = "mythitem_ring_thick_gem.png",
	groups = { armor_finger = 1 },
	texture = "mythitem_transparent", 
	preview = "mythitem_ring_armor_preview",
})

minetest.register_tool("mythitem:amulet1", {
	description = "Regeneration amulet",
	inventory_image = "mythitem_amulet_ankh.png",
	groups = { armor_neck = 1 },
	texture = "mythitem_amulet_armor_texture", 
	preview = "mythitem_amulet_armor_preview",
	effect_equip = {
		impacts = { damage = {-2, 3} }
	}
})

minetest.register_tool("mythitem:amulet2", {
	description = "Jump amulet",
	inventory_image = "mythitem_amulet_gem.png",
	groups = { armor_neck = 1 },
	texture = "mythitem_amulet_armor_texture", 
	preview = "mythitem_amulet_armor_preview",
	effect_equip = {
		impacts = { jump=2 },
	}
})

minetest.register_tool("mythitem:amulet3", {
	description = "Light amulet",
	inventory_image = "mythitem_amulet_big_gem.png",
	groups = { armor_neck = 1 },
	texture = "mythitem_amulet_armor_texture", 
	preview = "mythitem_amulet_armor_preview",
	effect_equip = {
		raise = 1,
		fall = 3,
		impacts = { daylight=1 },
	}
})

minetest.register_tool("mythitem:amulet4", {
	description = "Big amulet",
	inventory_image = "mythitem_amulet_big.png",
	groups = { armor_neck = 1 },
	texture = "mythitem_amulet_armor_texture", 
	preview = "mythitem_amulet_armor_preview",
})

minetest.register_node("mythitem:darkstone", {
	description = "Dark stone of darkness",
	tiles = {"mythitem_rune_o.png"},
	groups = {cracky = 3, stone = 1, building = 1, effect_trigger = 1},
	light_source = 4,
	effect_near = {
		distance = 10,
		impacts = { daylight = 0 },
		raise = 1,
		fall = 1,
	},
	effect_equip = {
		distance = 10,
		impacts = { daylight = 0.6 },
		raise = 1,
		fall = 1,
	},
})

minetest.register_tool("mythitem:wand", {
	description = "Test wand",
	inventory_image = "default_stick.png",
	effect_use_on = {
		raise = 1,
		fall = 1,
		duration = 10,
		impacts = { texture = { colorize = "#00FF0080" } },
		id = 'use_on:mythitem:wand',
	},
	on_use = effects_api.on_use_tool_callback,
})

minetest.register_craftitem("mythitem:potion", {
	description = "Poison",
	inventory_image = "mythitem_potion.png",
	effect_use = {
		raise = 1,
		impacts = { damage = { 1, 1 } },
		stopondeath = true,
	},
	on_use = effects_api.on_use_tool_callback,
})

minetest.register_node("mythitem:runestone_o", {
	description = "Rune",
	tiles = {"mythitem_rune_o.png"},
	groups = {cracky = 3, stone = 1, building = 1, effect_trigger = 1},
})


minetest.register_chatcommand("test", {
	params = "",
	description = "test",
	func = function(player_name, param)
				for name, obj in pairs(minetest.tooldef_default) do
					print ("minetest.tooldef_default."..name..": "..type(obj))
				end
			return true, "Done."
		end,
})


minetest.register_playerevent(function(player, event)
print(event)
end)


minetest.register_on_joinplayer(function(player)
print("on join player")
--	print(dump(player:get_properties()))


end)




