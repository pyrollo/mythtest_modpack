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

dofile(effects_api.path.."/api.lua")
dofile(effects_api.path.."/integration.lua")
dofile(effects_api.path.."/impact_registry.lua")
dofile(effects_api.path.."/impact_helpers.lua")
dofile(effects_api.path.."/impact_base.lua")

-- Debug function
minetest.register_chatcommand("clear_effects", {
	params = "",
	description = "Clears all effects",
	func = function(player_name, param)
			player = minetest.get_player_by_name(player_name)
			local data = effects_api.get_storage_for_subject(player)
			data.effects = {}
			data.impacts = {}
			return true, "Done."
		end,
})

minetest.register_chatcommand("dump", {
	params = "",
	description = "Dump player data",
	func = function(player_name, param)
			player = minetest.get_player_by_name(player_name)
			local data = effects_api.get_storage_for_subject(player)
			print(dump(data))
			return true, "Done."
		end,
})
