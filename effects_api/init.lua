effects_api = {}
effects_api.name = minetest.get_current_modname()
effects_api.path = minetest.get_modpath(effects_api.name)

dofile(effects_api.path.."/effects_api.lua")


-- Tests


-- Speed
--------
-- Params :
-- 1: Speed multiplier [0..infinite]. Default: 1

effects_api.register_player_impact_type('speed', {
    reset = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({speed = 1.0}) 
            end
        end,
	update = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({
                    speed = effects_api.get_impact_mult(impact.params, 1)
                })
            end
        end,
})

-- Jump
-------
-- Params :
-- 1: Jump multiplier [0..infinite]. Default: 1

effects_api.register_player_impact_type('jump', {
    reset = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({jump = 1.0}) 
            end
        end,
	update = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({
                    jump = effects_api.get_impact_mult(impact.params, 1)
                })
            end
        end,
})

-- Gravity
----------
-- Params :
-- 1: Gravity multiplier [0..infinite]. Default: 1

effects_api.register_player_impact_type('gravity', {
    reset = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({gravity = 1.0}) 
            end
        end,
	update = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({
                    gravity = effects_api.get_impact_mult(impact.params, 1)
                })
            end
        end,
})

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
