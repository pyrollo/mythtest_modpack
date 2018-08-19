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

-- Integration with 3D armor
if minetest.global_exists("armor") then
	print("[effects_api] Integration with 3D Armors")

	-- Item equipment. May trigger an effect
	armor:register_on_equip(function(player, index, stack)
		effects_api.set_equip_effect(player, stack:get_name())
	end)
	
-- TODO: Find a solution for player physics override in 3D Armor

-- Was not good, effects impacts were recorded also. Need to isolate thing from 3d armor
	-- Update default player physics if modifed by armor
--	armor:register_on_update(function(player)
--		data = effects_api.get_storage_for_subject(player)
--		local physics = player:get_physics_override()
--		data.defaults.gravity = physics.gravity
--		data.defaults.jump = physics.jump
--		data.defaults.speed = physics.speed
--		print(dump(data.defaults))

--		-- This supposes that affected impacts are speed, jump and gravity :
--		if data.impacts.speed   then data.impacts.speed.changed   = true end
--		if data.impacts.jump    then data.impacts.jump.changed    = true end
--		if data.impacts.gravity then data.impacts.gravity.changed = true end
-- end)

	-- Overload is_equiped function to include armor inventory
	-- TODO: Overloading process could be more elegant
	local is_equiped_old = effects_api.is_equiped
	effects_api.is_equiped = function(subject, item_name)
			if is_equiped_old(subject, item_name) then return true end

			-- Check only for players
			if subject.is_player and subject:is_player() then
				local inv = minetest.get_inventory({ type="detached", 
					name= subject:get_player_name().."_armor" })
				if inv then
					local list = inv:get_list("armor")
					if list then
						for _, stack in pairs(list) do
							if stack:get_name() == item_name then
								return true
							end
						end
					end
				end
			end
			
			return false
		end
end

