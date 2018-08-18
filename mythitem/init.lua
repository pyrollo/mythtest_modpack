minetest.register_tool("mythitem:ring", {
    description = "Blind ring",
    inventory_image = "mythitem_ring_simple.png",
    effect_equip = {
    	raise = 2,
    	fall = 2,
    	impacts = { vision=0 },
    }
})

minetest.register_tool("mythitem:ring2", {
    description = "Invisibility ring",
    inventory_image = "mythitem_ring_thick.png",
    effect_equip = {
    	impacts = { visible=0 },
    },
})

minetest.register_tool("mythitem:ring3", {
    description = "Strange ring",
    inventory_image = "mythitem_ring_gem.png",
    effect_equip = {
    	impacts = { texture=1 },
    }
})

minetest.register_tool("mythitem:ring4", {
    description = "Ring of darkness",
    inventory_image = "mythitem_ring_spikes.png",
    effect_equip = {
    	impacts = { daylight = 0 },
    	raise = 1,
    	fall = 1,
    }
})

minetest.register_tool("mythitem:ring5", {
    description = "Bad ring",
    inventory_image = "mythitem_ring_double_spikes.png",
    effect_equip = { 
    	raise = 3,
    	impacts = { health = -0.5 }
    }
})

minetest.register_tool("mythitem:ring6", {
	description = "Thick gem ring",
	inventory_image = "mythitem_ring_thick_gem.png",
})

minetest.register_tool("mythitem:amulet1", {
	description = "Regeneration amulet",
	inventory_image = "mythitem_amulet_ankh.png",
	effect_equip = {
		raise = 2,
		fall = 2,
		impacts = { health = 1 }
	}
})

minetest.register_tool("mythitem:amulet2", {
	description = "Jump amulet",
	inventory_image = "mythitem_amulet_gem.png",
	effect_equip = {
		impacts = { jump=3 },
	}
})

minetest.register_tool("mythitem:amulet3", {
	description = "Big gem amulet",
	inventory_image = "mythitem_amulet_big_gem.png",
})

minetest.register_tool("mythitem:amulet4", {
	description = "Big amulet",
	inventory_image = "mythitem_amulet_big.png",
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
		duration = 4,
		impacts = { texture = { color = "#FF000080" } }
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




