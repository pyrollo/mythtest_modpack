minetest.register_tool("mythitem:ring", {
    description = "Blind ring",
    inventory_image = "mythitem_ring_simple.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    },
    effect = {
    	raise = 2,
    	fall = 2,
    	impacts = { vision=0 },
    }
})

minetest.register_tool("mythitem:ring2", {
    description = "Invisibility ring",
    inventory_image = "mythitem_ring_thick.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    },
    effect = {
    	raise = 0,
    	fall = 0,
    	impacts = { visible=0 },
    }

})
minetest.register_tool("mythitem:ring3", {
    description = "Gem ring",
    inventory_image = "mythitem_ring_gem.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    }
})

minetest.register_tool("mythitem:ring4", {
    description = "Ring of darkness",
    inventory_image = "mythitem_ring_spikes.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    },
    effect = {
    	impacts = { daylight = 0 },
    	raise = 1,
    	fall = 1,
    }
})

minetest.register_tool("mythitem:ring5", {
    description = "Double spiked ring",
    inventory_image = "mythitem_ring_double_spikes.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    }
})

minetest.register_tool("mythitem:ring6", {
    description = "Thick gem ring",
    inventory_image = "mythitem_ring_thick_gem.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    }
})

minetest.register_tool("mythitem:amulet1", {
    description = "Ankh amulet",
    inventory_image = "mythitem_amulet_ankh.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    }
})

minetest.register_tool("mythitem:amulet2", {
    description = "Jump amulet",
    inventory_image = "mythitem_amulet_gem.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    },
    effect = {
    	impacts = { jump=3 },
    }
})

minetest.register_tool("mythitem:amulet3", {
    description = "Big gem amulet",
    inventory_image = "mythitem_amulet_big_gem.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    }
})

minetest.register_tool("mythitem:amulet4", {
    description = "Big amulet",
    inventory_image = "mythitem_amulet_big.png",
    tool_capabilities = {
        groupcaps= {uses=70, maxlevel=1}
    }
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




