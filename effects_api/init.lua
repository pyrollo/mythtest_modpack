effects_api = {}
effects_api.name = minetest.get_current_modname()
effects_api.path = minetest.get_modpath(effects_api.name)

-- Interval in seconds at which effects data is saved into players meta (only 
-- usefull in case of abdnormal server termination)
-- TODO:Move into a mod settings
local save_interval = 1 

dofile(effects_api.path.."/effects_api.lua")
dofile(effects_api.path.."/wield_hack.lua")

-- Main loop
minetest.register_globalstep(function(dtime)
	effects_api.players_wield_hack(dtime)
    effects_api.players_effects_loop(dtime)
    effects_api.players_impacts_loop(dtime)
end)

-- Effects persistance
minetest.register_on_joinplayer(effects_api.load_player_data)

minetest.register_on_leaveplayer(function(player) 
	effects_api.save_player_data(player)
	effects_api.forget_player(player)
end)

local function periodic_save()
	--	print(effects_api.dump_effects())
    effects_api.save_all_players_data()
    minetest.after(save_interval, periodic_save)
end

minetest.after(save_interval, periodic_save)

