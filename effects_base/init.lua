effects_base = {}
effects_base.name = minetest.get_current_modname()
effects_base.path = minetest.get_modpath(effects_base.name)

dofile(effects_base.path.."/impacts.lua")

local dur=10

minetest.register_chatcommand("fly", {
	params = "",
	description = "Fly for 20 seconds",
	func = function(player_name, param)
			effects_api.affect_player(player_name, {
				raise = 2,
				fall = 2,
				impacts = { gravity=0 },
				conditions = {
					duration = dur,
				},
			})
			return true, "Done."
	end,
})

minetest.register_chatcommand("run", {
	params = "",
	description = "Run for 20 seconds",
	func = function(player_name, param)
			effects_api.affect_player(player_name, {
				raise = 2,
				fall = 2,
				impacts = { speed=3 },
				conditions = {
					duration = dur,
				},
			})
			return true, "Done."
	end,
})

minetest.register_chatcommand("test", {
	params = "",
	description = "Blind zone",
	func = function(player_name, param)
			effects_api.affect_player(player_name, {
				raise = 1,
				fall = 2,
				impacts = { vision=1/2 },
				conditions = {
					location = {
						pos = minetest.get_player_by_name(player_name):get_pos(),
						radius = 10,
					},
				},
			})
			return true, "Done."
	end,
})
