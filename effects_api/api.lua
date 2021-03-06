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

-- Mod internal data
--------------------

-- Name of the players meta in which is saved effects data
local save_meta_key = "effects_api:active_effects"

-- Interval in seconds at which effects data is saved into players meta (only 
-- usefull in case of abdnormal server termination)
-- TODO:Move into a mod settings
local save_interval = 1

-- Interval in seconds of ABM checking for subjects being near nodes with effect
-- TODO:Move into a mod settings
local abm_interval = 1

-- Effect phases
----------------

local phase_init = 0
-- Init phase, before effect starts (and enters raise phase)

local phase_raise = 1
-- Effects starts in this phase. It stops after effect.raise seconds or when 
-- effect conditions are no longer fulfilled. Intensity of effect grows from 0
--  to 1 during this phase

local phase_still = 2
-- Once raise phase is completed, effects enters the still phase. Intensity is
-- full and the phases lasts as long as conditions are fulfilled.

local phase_fall  = 3
-- When conditions are no longer fulfilled, effect enters fall phase. This 
-- phase lasts effect.fall seconds (if 0, effects gets to next phase 
-- instantly).

local phase_end  = 4
-- This is the terminal phase. Effect in this phase are deleted.

-- Helper
---------

local function calliffunc(fct, ...)
	if type(fct) == 'function' then
		return fct(...)
	end
end

-- Subjects
-----------

local subject_data = {}
-- Automatically clean unused data by using a weak key table
setmetatable(subject_data, {__mode = "k"})

-- Return data storage for subject
local function data(subject)
	if subject_data[subject] then return subject_data[subject] end

	-- Create a data entry for new subject
	local subject_type, subject_desc

	if subject.is_player and subject:is_player() then
		subject_type = 'player'
		subject_desc = 'Player "'..subject:get_player_name()..'"'
	elseif subject.get_luaentity then
		local entity = subject:get_luaentity()
		if entity and entity.type then
			subject_type = 'mob'
			subject_desc = 'Mob "'..entity.name..'"'
		end
	end

	if subject_type then
		subject_data[subject] = {
			effects={}, impacts={},
			type = subject_type, string = subject_desc,
			defaults = {} }
	end

	return subject_data[subject]
end

-- Explose data function to API
effects_api.get_storage_for_subject = data

-- Item effects
---------------

function effects_api.set_equip_effect(subject, item_name)
	local definition = minetest.registered_items[item_name] and
		minetest.registered_items[item_name].effect_equip or nil
	if definition then
		definition.id = 'equip:'..item_name

		local effect = effects_api.get_effect_by_id(subject, definition.id)
		if effect == nil then
			effect = effects_api.new_effect(subject, definition)
			effect:set_conditions({ equiped_with = item_name })
			effect:start()
		end
		-- Restart effect in case it was in fall phase
		effect:restart()
	end
end

function effects_api.on_use_tool_callback(itemstack, user, pointed_thing)
	local def = minetest.registered_items[itemstack:get_name()]

	if def then
		if def.effect_use_on and pointed_thing.type == "object" then
		--TODO: if using Id, should restart existing item
			effects_api.new_effect(pointed_thing.ref, def.effect_use_on)
		end
		if def.effect_use then
			effects_api.new_effect(user, def.effect_use)
		end
	end
end

-- Node effects
---------------

-- ABM to detect if player gets nearby a nodes with effect (belonging to 
-- group:effect_trigger and having an effect in node definition)

minetest.register_abm({
	label = "effects_api player detection",
	nodenames="group:effect_trigger",
	interval=abm_interval,
	chance=1,
	catch_up=true,
	action = function(pos, node)
		local ndef = minetest.registered_nodes[node.name]
		local effect_def = ndef.effect_near

		if effect_def and effect_def.distance then

			for _, subject in pairs(minetest.get_objects_inside_radius(
					pos, effect_def.distance)) do

				effect_def.id = 'near:'..node.name

				local effect = effects_api.get_effect_by_id(subject, effect_def.id)

				if effect == nil then
					effect = effects_api.new_effect(subject, effect_def)
					if effect == nil then return end
					effect:set_conditions({ near_node = {
						node_name = node.name,
						radius = effect_def.distance,
						active_pos = {}
					} } )
				end

				-- Register node position as an active position
				effect.conditions.near_node
					.active_pos[minetest.hash_node_position(pos)] = true

				-- Restart effect in case it was in fall phase
				effect:restart()
			end
		end
	end,
})

-- Effect object
----------------

local Effect = {}
Effect.__index = Effect

--- new
-- Creates an effect and affects it to a subject
-- @param subject Subject to be affected (player, mob or world)
-- @param effect_definition Definition of the effect
-- @return effect affecting the player
--
-- effect_definition = {
--	groups = {},  -- Permet d'agir de l'exterieur sur l'effet
--	impacts = {}, -- Impacts effect has (pair of impact name / impact parameters
--	raise = x,    -- Time it takes in seconds to raise to its full intensity
--	fall = x,     -- Time it takes to fall, after end to no intensity
--  duration = x, -- Duration of maximum intensity in seconds (default always)
--  distance = x, -- In case of effect associated to a node, distance of action
--	stopondeath = true, --?
--}
-- impacts = { impactname = parameter, impactname2 = { param1, param2 }, ... }

function Effect:new(subject, definition)
	-- Verify subject
	local data = data(subject)
	if data == nil then return nil end

	-- Check for existing ID
	if definition.id and data.effects[definition.id] then
		minetest.log('error', '[effects_api] Effect ID "'..definition.id..
			'" already exists for '..data.string..'.')
		return nil
	end

	-- Instanciation
	self = table.copy(definition)
	setmetatable(self, Effect)

	-- Default values
	self.elapsed_time = self.elapsed_time or 0
	self.intensity = self.intensity or 0
	self.phase = self.phase or phase_raise
	self.subject = subject

	-- Duration condition
	if self.duration then
		self:set_conditions( { duration = self.duration } )  -- - ( effect.fall or 0 )
	end

	-- Affect to subject
	if self.id then
		data.effects[self.id] = self
	else
		table.insert(data.effects, self)
	end

	-- Create impacts
	local impacts = self.impacts
	self.impacts = {}

	if impacts then
		for type_name, params in pairs(impacts) do
			self:add_impact(type_name, params)
		end
	end

	return self
end

-- Explose new method to API
function effects_api.new_effect(...)
	return Effect:new(...)
end

-- TODO: Clip value to 0-1
function Effect:change_intensity(intensity)
	if self.intensity ~= intensity then
		self.intensity = intensity
		self.changed = true
	end
end

--- add_impact
-- Add a new impact to effect
-- @param type_name Impact type name
-- @param params Parameters of the impact

function Effect:add_impact(type_name, params)
	local data = data(self.subject)
	local impact_type = effects_api.get_impact_type(data.type, type_name)

	-- Impact type unknown or not for this type of subject
	if not impact_type then	return end

	-- Add impact to effect
	if type(params) == 'table' then
		self.impacts[type_name] = table.copy(params)
	else
		self.impacts[type_name] = { params }
	end

	-- Link effect to subject impact
	local impact = data.impacts[type_name]
	if not impact then
		-- First effect having this impact on subject : create impact
		impact = {
			vars = table.copy(impact_type.vars or {}),
			params = {},
			subject = self.subject,
			type = type_name,
		}
		data.impacts[type_name] = impact
	end

	-- Link effect params to impact params
	impact.changed = true
	table.insert(impact.params, self.impacts[type_name])
end

--- remove_impact
-- Remove impact from effect
-- @param type_name Impact type name
function Effect:remove_impact(type_name)
	if not self.impacts[type_name] then return end

	local data = data(self.subject)

	-- Mark subject impact as ended for this effect
	self.impacts[type_name].ended = true
	data.impacts[type_name].changed = true

	-- Detach impact params from effect
	self.impacts[type_name] = nil
end

--- stop
-- Stops effect, with optional fall phase
function Effect:stop()
	if self.phase == phase_raise or
	   self.phase == phase_still then
		self.phase = phase_fall
	end
end

--- start
-- Starts or restarts effect if it's in fall or end phase
function Effect:start()
	if self.phase == phase_init or
	   self.phase == phase_fall or
	   self.phase == phase_end then
		self.phase = phase_raise
	end
end

-- Restart is the same
Effect.restart = Effect.start

-- Effect step
--------------

--- step
-- Performs a step of calculation for the effect
-- @param dtime Time elapsed since last step

-- TODO: For a while after reconnecting, it seems that step runs and conditions
-- are not in place for effect conservation.
function Effect:step(dtime)
	-- Internal time
	self.elapsed_time = self.elapsed_time + dtime

	-- Effect conditions
	if (self.phase == phase_init or self.phase == phase_raise
	   or self.phase == phase_still) and not self:check_conditions() then
		self:stop()
	end

	-- End effects that have no impact
	if not next(self.impacts, nil) then
		self.phase = phase_end
	end

	-- Phase management
	if self.phase == phase_raise then
		if (self.raise or 0) > 0 then
		self:change_intensity(self.intensity + dtime / self.raise)
			if self.intensity >= 1 then self.phase = phase_still end
		else
			self.phase = phase_still
		end
	end

	if self.phase == phase_still then self:change_intensity(1) end

	if self.phase == phase_fall then
		if (self.fall or 0) > 0 then
			self:change_intensity(self.intensity - dtime / self.fall)
			if self.intensity <= 0 then self.phase = phase_end end
		else
			self.phase = phase_end
		end
	end

	if self.phase == phase_end then self:change_intensity(0) end

	-- Propagate to impacts (intensity and end)
	for impact_name, impact in pairs(self.impacts) do
		if impact.intensity ~= self.intensity then
			impact.intensity = self.intensity
			data(self.subject).impacts[impact_name].changed = true
		end
		if self.phase == phase_end then
			impact.ended = true
		end
	end
end

-- Effect conditions check
--------------------------

--- set_conditions
-- Add or replace conditions on the effect.
-- @param conditions A table of key/values describing the conditions
function Effect:set_conditions(conditions)
	self.conditions = self.conditions or {}
	for key, value in pairs(conditions) do
		self.conditions[key] = value
	end
end

-- Is the subject equiped with item_name?
function effects_api.is_equiped(subject, item_name)
	-- Check wielded item
	local stack = subject:get_wielded_item()
	if stack and stack:get_name() == item_name then
		return true
	end
	return false -- Item not found in equipment
end

-- Is subject near nodes?
-- This condition is not in the effect definition, it is created when needed
-- for effects associated with nodes placed on the map.
function effects_api.is_near_nodes(subject, near_node)
	-- No check, near_nodes should have radius, node_name and active_pos members
	local subject_pos = subject:get_pos()
	local radius2 = near_node.radius * near_node.radius
	local pos
	for hash, _ in pairs(near_node.active_pos) do
		pos = minetest.get_position_from_hash(hash)

		if (pos.x - subject_pos.x) * (pos.x - subject_pos.x) +
		   (pos.y - subject_pos.y) * (pos.y - subject_pos.y) +
		   (pos.z - subject_pos.z) * (pos.z - subject_pos.z) > radius2
		then
			near_node.active_pos[hash] = nil
		else
			if minetest.get_node(pos).name ~= near_node.node_name then
				near_node.active_pos[hash] = nil
			end
		end
	end

	return next(near_node.active_pos, nil) ~= nil
end

-- Check if conditions on effect are all ok
function Effect:check_conditions()
	if not self.conditions then
		return true -- no condition, always active (ex : poison)
	end

	-- Check effect duration
	if self.conditions.duration ~= nil
	   and self.elapsed_time > self.conditions.duration then
		return false
	end

	-- Next conditions are never true for World subject
--	if self.subject == world and (
--		self.conditions.equiped_with or
--		self.conditions.near_node)
--	then
--		return false
--	end

	-- Check equipment
	if self.conditions.equiped_with and
	   not effects_api.is_equiped(self.subject,self.conditions.equiped_with)
	then
		return false
	end

	-- Check nearby nodes
	if self.conditions.near_node and
	   not effects_api.is_near_nodes(self.subject, self.conditions.near_node)
	then
		return false
	end

	-- All conditions fulfilled
	return true
end

-- On die player : stop effects that are marked stopondeath = true
minetest.register_on_dieplayer(function(player)
	local data = data(player)
	if data then
		for index, effect in pairs(data.effects) do
			if effect.stopondeath then
				effect:stop()
			end
		end
	end
end)

-- TODO:
--- cancel_player_effects
-- Cancels all effects belonging to a group affecting a player
--function effects_api.cancel_player_effects(player_name, effect_group)

-- Main globalstep loop
-----------------------

minetest.register_globalstep(function(dtime)
		-- Loop over all known subjects
		for subject, data in pairs(subject_data) do

			-- Check subject existence
			if subject:get_properties() == nil then
				subject_data[subject] = nil
			else
				-- Wield item change check
				-- TODO: work only if subject is known, what about mobs ?
				local stack = subject:get_wielded_item()
				local item_name = stack and stack:get_name() or nil

				if data.wielded_item ~= item_name then
					data.wielded_item = item_name
					if item_name then
						effects_api.set_equip_effect(subject, item_name)
					end
				end

				-- Effects
				for index, effect in pairs(data.effects) do
					-- Compute effect elapsed_time, phase and intensity
					effect:step(dtime)

					-- Effect ends ?
					if effect.phase == phase_end then
						-- Delete effect
						data.effects[index] = nil
					end
				end

				-- Impacts
				for impact_name, impact in pairs(data.impacts) do
					local impact_type = effects_api.get_impact_type(
						data.type, impact_name)

					-- Check if there are still effects using this impact
					local remains = false
					for key, params in pairs(impact.params) do
						if params.ended then
							impact.params[key] = nil
						else
							remains = true
						end
					end

					if remains then
						-- Update impact if changed (effect intensity changed)
						if impact.changed then
							calliffunc(impact_type.update, impact, data)
						end

						-- Step
						calliffunc(impact_type.step, impact, dtime, data)
						impact.changed = false
					else
						-- Ends impact
						calliffunc(impact_type.reset, impact, data)
						data.impacts[impact_name] = nil
					end
				end
			end
		end
	end)

-- Effects persistance
----------------------

-- How effect data are stored:
-- Player: Serialized in a player attribute (In V5, it will be possible to use
--         StorageRef for players and entities)
-- Mob: (:TODO:)
-- World: minetest.get_mod_storage() (:TODO:)

-- Periodically, players and world effect are saved in case of server crash

-- TODO:Check that attributes are saved in case of server crash
-- TODO:Manage entity persistance with get_staticdata and on_activate

-- serialize_effects
function serialize_effects(subject)
	local data = data(subject)
	if not data then return end -- Not a suitable subject

	local effects = table.copy(data.effects)

	-- remove subject references from data to be serialized (not serializable)
	for _, effect in pairs(effects) do effect.subject = nil	end

	return minetest.serialize(effects)
end

-- deserialize_effects
function deserialize_effects(subject, serialized)
	if serialized == "" then return end

	local data = data(subject)
	if not data then return end -- Not a suitable subject

	if data.effects and next(data.effects, nil) then
		minetest.log('error', '[effects_api] Trying to deserialize effects for '
			..data.string..' which already has effects.')
		return
	end

	-- Deseralization
	local effects = minetest.deserialize(serialized) or {}

	for _, fields in pairs(effects) do
		local effect = Effect:new(subject, fields)
		effect.break_time = true
	end
end


local function periodic_save()
	for _,player in ipairs(minetest.get_connected_players()) do
		player:set_attribute(save_meta_key, serialize_effects(player))
	end
	minetest.after(save_interval, periodic_save)
end
minetest.after(save_interval, periodic_save)

minetest.register_on_joinplayer(function(player)
--	deserialize_effects(player, player:get_attribute(save_meta_key))
end)

minetest.register_on_leaveplayer(function(player)
	player:set_attribute(save_meta_key, serialize_effects(player))
end)

minetest.register_on_shutdown(function()
	for _,player in ipairs(minetest.get_connected_players()) do
		player:set_attribute(save_meta_key, serialize_effects(player))
	end
end)

-- Effects management
---------------------

--- get_effect_by_id
-- Retrieves an effect by its ID for a given subject
-- @param subject Concerned subject (player, mob, world)
-- @param id Id of the effect researched
-- @returns The Effect object or nil if not found
function effects_api.get_effect_by_id(subject, id)
	return data(subject).effects[id]
end

-- Hacks
--------

-- Awful hack for integration with other mods dealing with player physics

local physic_impacts =
	{ jump = 'jump', gravity = 'gravity', speed = 'speed' }

local function set_physics_override(player, table)
	-- Separate physics managed by impacts from those still managed by
	-- core api set_physics_override
	local impacts = {}
	local physics = {}
	for physic, impact in pairs(physic_impacts) do
		if table[physic] then
			impacts[impact] = table[physic]
		else
			physics[physic] = table[physic]
		end
	end

	-- If impact managed physics, update or create specific effect
	if next(impacts, nil) then
		local effect = effects_api.get_effect_by_id(player, 'core:physics')
			or Effect:new(player, {	id = 'core:physics' })

		for impact, value in pairs(impacts) do
			if value == 1 then
				effect:remove_impact(impact)
			else
				effect:add_impact(impact, { value })
			end
		end
	end

	-- If core api managed physics, call core api
	if next(physics, nil) then
		effects_api.set_physics_override(player, physics)
	end

end

minetest.register_on_joinplayer(function(player)
	if effects_api.set_physics_override == nil then
		print('[effect_api] Hacking Player:set_physics_override')
		local meta = getmetatable(player)
		effects_api.set_physics_override = meta.set_physics_override
		meta.set_physics_override = set_physics_override
	end

	-- Create effect if there are already physic changes
	local physics = player:get_physics_override()
	set_physics_override(player, physics)
end)
