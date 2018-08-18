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
local meta_key = "effects_api:active_effects"

-- World subject
local world = { effects = {}, impacts = {}, type = 'world', name = 'World' }
effects_api.world = world

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

-- Impact registry
------------------

local impact_types = { player = {}, mob = {} }

--- register_impact_type
-- Registers a player impact type.
-- @param subjects Subject type or table of subjects type affected by the impact
-- @param name Unique (for a subject type) name of the impact
-- @param def Definition of the impact type
-- def = {
--	vars = { a=1, b=2, ... }       Internal variables needed by the impact (per
--                                 impact context : player / mob)
--	reset = function(impact)       Function called when impact stops
--	update = function(impact)      Function called to apply effect
--	step = function(impact, dtime) Function called every global step
--}
-- Impact passed to functions is:
-- impact = {
--  subject = player or mob ObjectRef
-- 	name = '...',         Impact type name.
--  vars = {},            Internal vars (indexed by name).
-- 	params = {},          Table of per effect params and intensity.
--	changed = true/false  Indicates wether the impact has changed or not since
--                        last step.
-- }
function effects_api.register_impact_type(subjects, name, definition)
	if type(subjects) == 'string' then subjects = { subjects } end
	if type(subjects) ~= 'table' then
		error ('[effects_api] Subjects is expected to be either a string or '..
		       'a table of subject type names)', 2)
	end

	for _, subject in ipairs(subjects) do

		if impact_types[subject] == nil then
			error ('[effects_api] Subject type "'..subject..'" unknown.', 2)
		end

		if impact_types[subject][name] then
			error ('Impact type "'..name..'" already registered for '..
				subject..'.', 2)
		end

		local def = table.copy(definition)
		def.name = name
		def.subject = subject
		impact_types[subject][name] = def
	end
end

--- get_impact_type
-- Retrieves an impact type definition
-- @param subject Subject type to be affected
-- @param name Name of the impact type
-- @returns Impact type definition table
function effects_api.get_impact_type(subject, name)
	if impact_types[subject] == nil then
		error('[effects_api] Subject type "'..subject..'" unknown.', 2)
	end

	if impact_types[subject][name] == nil then
		minetest.log('error', '[effects_api] Impact type "'..name
			..'" not registered for '..subject..'.')
	end

	return impact_types[subject][name]
end

-- Subjects
-----------

local player_data = {}

-- Return data storage for given subject:
-- For players, data is stored in the player_data table indexed by player name.
-- TODO: Free player_data entry when player is leaving
-- For mobs, data is stored in effects_api field of the LUAEntity table.
-- For world, data is stored in world local table.
local function data(subject)

	-- Player subjects
	if subject.is_player and subject:is_player() then
		local player_name = subject:get_player_name()
		player_data[player_name] = player_data[player_name] or
			{ effects={}, impacts={}, type = 'player',
			  string = 'Player "'..player_name..'"'}
		return player_data[player_name]
	end

	-- Mob subjects
	local entity = subject:get_luaentity()
	if entity and entity.type then
		if entity.effects_data then return entity.effects_data end

		entity.effects_data = { effects={}, impacts={}, type = 'mob',
			name = 'Mob "'..entity.name..'"'}

		-- For mobs, hacks the on_step to insert effects_api mechanism
		if entity.on_step then
			entity.effects_data.on_step = entity.on_step
			entity.on_step = function(entity, dtime)
				effects_api.effect_step(entity.object, dtime)
				entity.effects_data.on_step(entity, dtime)
			end
		else
			entity.on_step = function(entity, dtime)
				effects_api.effect_step(entity, dtime)
			end
		end
		return entity.effects_data
	end

	if subject == world then
		return world
	end
end

-- Effect object
----------------

local Effect = {}
Effect.__index = Effect

-- To be called only once, when a new impact is created in memory
local function link_effect_to_impacts(effect)

	local data = data(effect.subject)

	-- Create / link impacts
	if effect.impacts then
		for type_name, params in pairs(effect.impacts) do
			-- Normalise params so they are all tables
			if type(params) ~= 'table' then
				params = { params }
				effect.impacts[type_name] = params
			end

			local impact = data.impacts[type_name]

			if not impact then
				-- First effect having this impact on subject : create impact
				local impact_type = effects_api.get_impact_type(data.type,
					type_name)

				impact = {
					vars = table.copy(impact_type.vars or {}),
					params = {},
					subject = effect.subject,
					type = type_name,
				}
				data.impacts[type_name] = impact
			end

			if impact then
				-- Link effect params to impact params
				table.insert(impact.params, params)
			else
				-- Impact not existing, remove it to avoid further problems
				effect.impacts[type_name] = nil
			end
		end
	end
end

function Effect:change_intensity(intensity)
	if self.intensity ~= intensity then
		self.intensity = intensity
		self.changed = true
	end
end

function Effect:step(dtime)
	-- Internal time
	self.elapsed_time = self.elapsed_time + dtime

	-- Effect conditions
	if not self:check_conditions() then self:stop() end

	-- Phase management
	if self.phase == phase_raise then
		if (self.raise or 0) > 0 then
		self:change_intensity(self.intensity + dtime / self.raise)
			if self.intensity > 1 then self.phase = phase_still end
		else
			self.phase = phase_still
		end
	end

	if self.phase == phase_still then self:change_intensity(1) end

	if self.phase == phase_fall then
		if (self.fall or 0) > 0 then
			self:change_intensity(self.intensity - dtime / self.fall)
			if self.intensity < 0 then self.phase = phase_end end
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

-- Stops effect, with optional fall phase
function Effect:stop()
	if self.phase == phase_raise or
	   self.phase == phase_still then
		self.phase = phase_fall
	end
end

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

-- Effect conditions check
--------------------------

function Effect:set_conditions(conditions)
	self.conditions = self.conditions or {}
	for key, value in pairs(conditions) do
		self.conditions[key] = value
	end
end

-- player dead ?
--minetest.register_on_respawnplayer(func(ObjectRef))`

-- Is the subject equiped with item_name? Equiped means wields item or have it
-- in armor equipment slots.
local function is_equiped(subject, item_name)
	-- Check wielded item
	local stack = subject:get_wielded_item()
	if stack and stack:get_name() == item_name then
		return true
	end

	-- Check for equiped armors (most likely for players only)
	local list = subject:get_inventory():get_list("armor")
	if list then
		for _, stack in pairs(list) do
			if stack:get_name() == item_name then
				return true
			end
		end
	end
	return false -- Item not found in equipment
end

-- Is subject near nodes?
-- This condition is not in the effect definition, it is created when needed
-- for effects associated with nodes placed on the map.
local function is_near_nodes(subject, near_node)
	-- No check, near_nodes should have radius, node_name and active_pos members
	local subject_pos = subject:get_pos()
	local radius2 = near_node.radius * near_node.radius
	local pos
	for hash, _ in pairs(near_node.active_pos) do
		pos = minetest.get_position_from_hash(hash)

		-- TODO:ensure radius computation is the same that get_objects_in_radius
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
	if self.subject == world and (
		self.conditions.equiped_with or 
		self.conditions.near_node)
	then
		return false
	end 
	-- Check equipment
	if self.conditions.equiped_with
	   and not is_equiped(self.subject, self.conditions.equiped_with) then
		return false
	end

	-- Check nearby nodes
	if self.conditions.near_node
	   and not is_near_nodes(self.subject,self.conditions.near_node) then
		return false
	end

	-- All conditions fulfilled
	return true
end

-- TODO:
--- cancel_player_effects
-- Cancels all effects belonging to a group affecting a player
--function effects_api.cancel_player_effects(player_name, effect_group)

-- Main loop
------------

function effects_api.effect_step(subject, dtime)
	local data = data(subject)
--if data.type ~= 'player' then
--print(dump(data))
--end
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

		-- Check there are still effects using this impact
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
			if impact.changed
			   and type(impact_type.update) == 'function' then
				impact_type.update(impact)
			end

			-- Step
			if type(impact_type.step) == 'function' then
				impact_type.step(impact, dtime)
			end

			impact.changed = false
		else
			-- Ends impact
			if type(impact_type.reset) == 'function' then
				impact_type.reset(impact)
			end
			data.impacts[impact_name] = nil
		end
	end
end

-- Effects persistance
----------------------

--Probleme... le stockage.
-- Player : on join / on leave + periodiquement (players_connected) dans un attribut.
-- Vérifier en cas de crash que les attributs sont bien sauvés
-- Mob : si le serveur crash, pas moyen de gérer. Les données peuvent être sauvés pendant get_staticdata et on_activate
-- World : minetest.get_mod_storage()

-- En v5, on va pouvoir utiliser le StorageRef du joueur et des entités.

-- Effects are loaded/saved on player join/leave and every second in case of
-- server crash.

function effects_api.serialize_effects(subject)
	local data = data(subject)
	return minetest.serialize(data.effects)
end

function effects_api.deserialize_effects(subject, serialized)
	if serialized == "" then return end

	local data = data(subject)
	if data then return end -- Not a suitable subject

	if data.effects and next(data.effects, nil) then
		minetest.log('error', '[effects_api] Trying to deserialize effects for '
			..data.name..' which already has effects.')
		return
	end

	-- Deseralization
	data.effects = minetest.deserialize(serialized) or {}
	
	for index, effect in ipairs(data.effects) do
		link_effect_to_impacts(effect)
	end
end
	
function effects_api.save_player_data(player)
	player:set_attribute(meta_key, effects_api.serialize_effects(player))
end

function effects_api.load_player_data(player)
	effects_api.deserialize_effects(player, player:get_attribute(meta_key))
end

--[[
function effects_api.save_all_players_data()
	local player
	for player_name, effects in pairs(active_player_effects) do
		player = minetest.get_player_by_name(player_name)
		if player == nil then
			minetest.log('warning', '[effects_api] Player "'..player_name..
				'" has active effects but is not connected. Removing effects.')
			active_player_effects[player_name] = nil
			active_player_impacts[player_name] = nil
		else
			effects_api.save_player_data(player)
		end
	end
end
--]]

-- Effects management
---------------------

--- new
-- Creates an effect and affects it to a subject
-- @param subject Subject to be affected (player, mob or world)
-- @param effect_definition Definition of the effect
-- @return effect affecting the player
-- effect_definition = {
--	groups = {},  -- Permet d'agir de l'exterieur sur l'effet
--	impacts = {}, -- Impacts effect has (pair of impact name / impact parameters
--	raise = x,    -- Time it takes in seconds to raise to its full intensity
--	fall = x,     -- Time it takes to fall, after end to no intensity
--  duration = x, -- Duration of maximum intensity in seconds (default always)
--  distance = x, -- In case of effect associated to a node, distance of action
--	stopatdeath = true, --?
--}
--
-- impacts = { impactname = parameter, impactname2 = { param1, param2 }, ... }
--

--	conditions = { -- created programmatically
--	  duration = x, -- Duration of maximum intensity in seconds (default always)
--	  equiped_with = itemstring, -- Effects falls if not equiped with this item
--                                  anymore (armor or wielding)
-- 	  near_node = {
--	     pos = { x =, y =, z = },
--       radius = ,
--	     node_name = , -- (optional) Node name if any (if node is not corresponding, effect stops)
--},
--}

function effects_api.affect(subject, definition)

	-- Verify subject
	local data = data(subject) 
	if not data then return nil end

	-- verify ID
	if definition.id and data.effects[definition.id] then
		minetest.log('error', '[effects_api] Effect ID "'..definition.id..
			'" already exists for '..data.name..'.')
		return nil
	end

	-- Instanciation
	local effect = table.copy(definition)
	setmetatable(effect, Effect)

	effect.subject = subject
	effect.elapsed_time = 0
	effect.phase = phase_raise
	effect.intensity = 0

	-- Duration condition
	if effect.duration then
		effect:set_conditions( { duration = effect.duration } )  -- - ( effect.fall or 0 )
	end

	-- Affect to subject
	if effect.id then
		data.effects[definition.id] = effect
	else
		table.insert(data.effects, effect)
	end

	-- Link to impacts
	link_effect_to_impacts(effect)

	return effect
end

---
function effects_api.get_effect_by_id(subject, id)
	return data(subject).effects[id]
end

--- dump_effects
-- Dumps all effects affecting a player into a string
-- @param player_name Name of the player
-- @returns String describing effects
function effects_api.dump_effects(subject)
	local str = ""
	local data = data(subject)
	for _, effect in pairs(data.effects) do
		if str ~= "" then str=str.."\n" end

		str = str..string.format("%s:%d %d%% %.1fs %s",
			data.name,
			effect.phase or "",
			(effect.intensity or 0)*100,
			effect.elapsed_time or 0,
			effect.id or "")
		if effect.impacts then
			for impact, _ in pairs(effect.impacts) do
				str=str.." "..impact
			end
		end
--			str=str..minetest.serialize(effect)
	end
--  else
--		for player_name, _ in pairs(active_player_effects) do
--			str=str..effects_api.dump_effects(player_name)
--		end
--	end
	return str
end

