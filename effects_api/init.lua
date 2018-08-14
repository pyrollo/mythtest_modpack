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

effects_api = {}
effects_api.name = minetest.get_current_modname()
effects_api.path = minetest.get_modpath(effects_api.name)

-- Interval in seconds at which effects data is saved into players meta (only 
-- usefull in case of abdnormal server termination)
-- TODO:Move into a mod settings
local save_interval = 1 

dofile(effects_api.path.."/api.lua")
dofile(effects_api.path.."/hacks.lua")
dofile(effects_api.path.."/impact_helpers.lua")

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

