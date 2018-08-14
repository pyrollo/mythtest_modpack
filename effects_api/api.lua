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

-- Living data
local active_player_effects = {}
local active_player_impacts = {}
local active_player_effets_ids = {}

--local active_world_effects = {}
--local active_world_impacts = {}
--local active_mob_effects = {}
--local active_mob_impacts = {}

-- Impact registry
------------------

-- Registry
local player_impact_types = {}

--- register_player_impact_type
-- Registers a player impact type.
-- @param name Unique name of the impact type
-- @param def Definition of the impact type
-- def = {
--	vars = { a=1, b=2, ... }       Internal variables needed by the impact (per
--                                 impact context : player / mob)
--	reset = function(impact)       Function called when impact stops
--	update = function(impact)      Function called to apply effect
--	step = function(impact, dtime) Function called every global step
--}
-- Impact passed to functions is :
-- impact = {
-- 	type = '...',         Impact type name.
--  vars = {},            Internal vars (indexed by name).
-- 	params = {},          (weak) table of per effect params and intensity.
--	changed = true/false  Indicates wether the impact has changed or not since
--                        last step.
-- }
function effects_api.register_player_impact_type(name, definition)
	if player_impact_types[name] then
		error ( 'Impact type "'..name..'" already registered.', 2)
--		minetest.log('error', '[effects_api] Impact type "'..name..'" already registered.')
	else
		local def = table.copy(definition)
		def.name = name
		player_impact_types[name] = def
	end
end

-- Main mechanism
-----------------

local function get_player_impact(player_name, impact_type_name)
	if player_impact_types[impact_type_name] == nil then
		minetest.log('error', '[effects_api] Impact type "'..impact_type_name..'" not registered.')
		return nil
	end

	-- Prepare per player/per impact table
	if active_player_impacts[player_name] == nil then
		active_player_impacts[player_name] = {}
	end

	if active_player_impacts[player_name][impact_type_name] == nil then
		active_player_impacts[player_name][impact_type_name] = {
			vars = table.copy(player_impact_types[impact_type_name].vars or {}),
			params = {},
			player_name = player_name,
			type = impact_type_name,
		}

		-- Params is a week reference table to effect
		setmetatable(
			active_player_impacts[player_name][impact_type_name].params,
			{ __mode = 'v' })
	end

	return active_player_impacts[player_name][impact_type_name]
end

-- To be called only once, when a new impact is created in memory
local function link_player_effect_impacts(effect)
	-- Create / link impacts
	if effect.impacts then
		for type_name, params in pairs(effect.impacts) do
			-- Normalise params so they are all tables
			if type(params) ~= 'table' then
				params = { params }
				effect.impacts[type_name] = params
			end
			local impact = get_player_impact(effect.player_name,
			                                 type_name)
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

-- Effect phases
----------------

-- Computes effect intensity evolution according to phases:
-- raise: Effects starts in this phase. It stops after effect.raise seconds or
--		when effect conditions are no longer fulfilled. Intensity of effect
--		grows from 0 to 1 during this phase.
-- still: Once raise phase is completed, effects enters the still phase.
--		Intensity is full and the phases lasts while conditions are
--		fulfilled.
-- fall:  When conditions are no longer fulfilled, effect enters fall phase.
--		This phase lasts effect.fall seconds (if 0, effects gets to next
--		phase instantly).
-- end:   This is the terminal phase. Effect in this phase are deleted.

local function effect_phase (effect, dtime)
	effect.phase = effect.phase or "raise"
	effect.intensity = effect.intensity or 0

	if effect.phase == "raise" then
		if (effect.raise or 0) > 0 then
			effect.intensity = effect.intensity + dtime / effect.raise
			effect.changed = true
			if effect.intensity > 1 then
				effect.phase = "still"
			end
		else
			effect.phase = "still"
		end
	end

	if effect.phase == "still" and effect.intensity ~= 1 then
		effect.intensity = 1
		effect.changed = 1
	end

	if effect.phase == "fall" then
		if (effect.fall or 0) > 0 then
			effect.intensity = effect.intensity - dtime / effect.fall
			effect.changed = true
			if effect.intensity < 0 then
				effect.phase = "end"
			end
		else
			effect.phase = "end"
		end
	end

	if effect.phase == "end" and effect.intensity ~= 0 then
		effect.intensity = 0
		effect.changed = true
	end
end

-- Turns effect off, with optional fall phase
local function effect_off(effect)
	if effect.phase == "raise" or effect.phase == "still" then
		effect.phase = "fall"
	end
end

-- Effect conditions check
--------------------------

-- player dead ?
--minetest.register_on_respawnplayer(func(ObjectRef))`

-- Item equipement : new effect at each equipment. Fall time must be shorter
-- than raise time or it may produce extra intensity by equiping/unequiping fast

-- Tells if player is equiped with item_name. Equiped means wields item or have
-- it in armor equipment slots.

local function is_player_equiped(player_name, item_name)
	local player = minetest.get_player_by_name(player_name)
	if player == nil then return false end

	-- Check wielded item
	local stack = player:get_wielded_item()
	if stack and stack:get_name() == item_name then
		return true
	end

	-- Check equiped armors
	local player_inv = player:get_inventory()
	local list = player_inv:get_list("armor") or {}
	for _, stack in pairs(list) do
		if stack:get_name() == item_name then
			return true
		end
	end
	return false -- Item not found in equipment
end

-- Tell if player is near a certain position -- not actually used
local function player_in_location(player_name, location)
	local player = minetest.get_player_by_name(player_name)

	if not location.pos or not location.radius then
		return false
	end

	local pos = player:get_pos()
	local v = vector.new(pos.x - location.pos.x,
						 pos.y - location.pos.y,
						 pos.z - location.pos.z)
	if vector.length(v) > location.radius then
		return false
	end

	return true
end

-- Check nearby nodes. 
-- This condition is not in the effect definition, it is created when needed
-- for effects associated with nodes placed on the map.
local function still_nearby_nodes(player_name, near_node)
    -- No check, near_nodes should have radius, node_name and active_pos members

	local player = minetest.get_player_by_name(player_name)
	local player_pos = player:get_pos()
    local radius2 = near_node.radius * near_node.radius

    for hash, _ in pairs(near_node.active_pos) do
        pos = minetest.get_position_from_hash(hash)
        if (pos.x - player_pos.x) * (pos.x - player_pos.x) +
           (pos.y - player_pos.y) * (pos.x - player_pos.y) +
           (pos.z - player_pos.z) * (pos.x - player_pos.z) > radius2
        then
            near_node.active_pos[hash] = nil
        else
            if minetest.get_node(pos).name ~= near_node.name then
                near_node.active_pos[hash] = nil
            end
        end
    end

    return next(near_node.active_pos, nil) ~= nil
end

-- Check if conditions on effect are all ok
local function verify_player_effect_conditions(effect)
	--	local player = minetest.get_player_by_name(effect.player_name)
	if not effect.conditions then
		return true -- no condition, always active (ex : poison)
	end

	-- Check effect duration
	if effect.conditions.duration ~= nil
		and effect.elapsed_time > effect.conditions.duration then
		return false
	end

	-- Check equipment
	if effect.conditions.equiped_with
		and not is_player_equiped(effect.player_name,
		                          effect.conditions.equiped_with) then
		return false
	end

	-- Location
	if effect.conditions.location
		and not player_in_location(effect.player_name,
		                           effect.conditions.location) then
		return false
	end

    -- Check nearby nodes
    if effect.conditions.near_node
        and not still_nearby_nodes(effect.player_name,
                                   effect.conditions.near_node) then
        return false
    end

	return true
end

-- TODO:
--- cancel_player_effects
-- Cancels all effects belonging to a group affecting a player
--function effects_api.cancel_player_effects(player_name, effect_group)

-- Main loops
-------------

function effects_api.players_effects_loop(dtime)
	local garbage = false

	-- Effects loops (players)
	for player_name, effects in pairs(active_player_effects) do

		-- Effects loops (effects)
		for index, effect in ipairs(effects) do
			effect.elapsed_time = effect.elapsed_time + dtime

			-- Compute effect phase and intensity
			effect_phase(effect, dtime)

			-- Effect conditions
			if not verify_player_effect_conditions(effect) then
				effect_off(effect)
			end

			-- Effect ends ?
			if effect.phase == 'end' then
				table.remove(effects, index)
				garbage = true
			else
				-- Intensity propagation to effects
				for impact_name, params in pairs(effect.impacts) do
					if params.intensity ~= effect.intensity then
						params.intensity = effect.intensity
						active_player_impacts[player_name][impact_name].changed = true
					end
				end
			end
		end
	end

	-- In case of ended effects, collect garbage to remove weak references
	-- in impacts.
	if garbage then
		collectgarbage()
	end
end

function effects_api.players_impacts_loop(dtime)
	local player
	-- Impacts loop (player)
	for player_name, impacts in pairs(active_player_impacts) do
		player = minetest.get_player_by_name(player_name)

		-- Impacts loop (types)
		for impact_name, impact in pairs(impacts) do
			local impact_type = player_impact_types[impact_name]

			-- Check there are still effects using this impact
			-- (can't use #impact.params because params are removed in any order)
			if next(impact.params,nil) == nil then
				if type(impact_type.reset) == 'function' then
					impact_type.reset(impact)
				end
				impacts[impact_name] = nil
			else
				if impact.changed
				  and type(impact_type.update) == 'function' then
					impact_type.update(impact)
				end

				if type(impact_type.step) == 'function' then
					impact_type.step(impact, dtime)
				end

				impact.changed = false
			end
		end
	end
end

-- Effects by ID
----------------

local function set_effect_for_id(player_name, effect_id, effect)
    if effect_id == nil then
        return true -- No id, no problem
    end

    if active_player_effects_ids[player_name] == nil then
        active_player_effects_ids[player_name] = {}
        setmetatable(active_player_effets_ids[player_name], { __mode = 'v' })
    end
    
    if active_player_effects_ids[player_name][effect_id] then
        return false
    else
        active_player_effects_ids[player_name][effect_id] = effect
        return true
    end
end

--- get_effect_by_id
-- Returns an effect with a given id
-- @param player_name Name of the player affected
-- @param effect_id Id of the effect
-- @return effect found or nil if none
function effects_api.get_effect_by_id(player_name, effect_id)
    if effect_id and active_player_effects_ids[player_name] and
        active_player_effects_ids[player_name][effect_id] 
    then
        return active_player_effects_ids[player_name][effect_id]
    else
        return nil
    end
end

-- Player effects persistance
-----------------------------

-- Effects are loaded/saved on player join/leave and every second in case of
-- server crash.

function effects_api.save_player_data(player)
	local player_name = player:get_player_name()

	if active_player_effects[player_name]
	  and #active_player_effects[player_name] then
		player:set_attribute(meta_key,
			minetest.serialize(active_player_effects[player_name]))
	else
		player:set_attribute(meta_key, "")
	end
end

function effects_api.load_player_data(player)
	local player_name = player:get_player_name()

	if active_player_effects[player_name]
	   and #active_player_effects[player_name] then
		-- TODO:Don't know what to do if player already has active effects
		minetest.log('error', '[effects_api] Trying to deserialize active effects for player "'..player_name..'" who already has active effects.')
	else
		local data = player:get_attribute(meta_key)
		if data == "" then
			active_player_effects[player_name] = nil
			active_player_effects_ids[player_name] = nil
		else
			active_player_effects[player_name] = minetest.deserialize(data)

			if active_player_effects[player_name] then
				-- Link active effects to impacts
				for index, effect in ipairs(active_player_effects[player_name]) do
                    if not set_effect_for_id(player_name, effect.id, effect) then
                        minetest.log('error', '[effects_api] Loading effects for player "'..
                        player_name..'", found duplicate ID "'..effect.id..'".')
                        -- Not quite satisfying. What to do in that case ?? Should remove duplicate ?
                    end
                    link_player_effect_impacts(effect)
				end
			end
        end
	end
--	print("Effects on player "..player_name..":")
--	print(dump(active_player_effects[player_name]))
end

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

function effects_api.forget_player(player)
	local player_name = player:get_player_name()
	if active_player_effects[player_name] then
		active_player_effects[player_name] = nil
		active_player_impacts[player_name] = nil
        active_player_effects_ids[player_name] = nil
	end
end

-- Effects management
---------------------

--- affect_player
-- Affects a player with a lasting effect
-- @param player_name Name of the player to be affected
-- @param effect_definition Definition of the effect
-- @return effect affecting the player
-- effect_definition = {
--	groups = {},  -- Permet d'agir de l'extérieur sur l'effet
--	impacts = {}, -- Impacts effect has (pair of impact name / impact parameters
--	raise = x,    -- Time it takes in seconds to raise to its full intensity
--	fall = x,     -- Time it takes to fall, after end to no intensity
--	conditions = {
--	  duration = x, -- Duration of maximum intensity in seconds (default always)
--	  location = {}, -- location definition where the effect is active (default:
--                      everywhere)
--	  equiped_with = itemstring, -- Effects falls if not equiped with this item
--                                  anymore (armor or wielding)
--	}
--  distance = x, -- In case of effect associated to a node, indicates distance of action
--	stopatdeath = true, --?
--}
--
-- impacts = { impactname = parameter, impactname2 = { param1, param2 }, ... }
--
-- location = {
--	pos = { x =, y =, z = },
--	radius = ,
--	node_name = , -- (optional) Node name if any (if node is not corresponding, effect stops)
--}


function effects_api.affect_player(player_name, effect_definition)
    -- Verify id not in use if any
    if effect_definition.id and
       effects_api.get_effect_by_id(effect_definition.id) then
		minetest.log('error', '[effects_api] Effect ID "'..effect_definition.id..
            '" already exists for player "'..player_name..'".')
        return nil
    end

	if active_player_effects[player_name] == nil then
		active_player_effects[player_name] = {}
	end

	local effect = table.copy(effect_definition)
	table.insert(active_player_effects[player_name], effect)

	-- Basic internal vars
	effect.player_name = player_name
	effect.elapsed_time = 0

    -- Register by id if any
    set_effect_for_id(player_name, effect.id, effect)

	-- Create / link impacts
	link_player_effect_impacts(effect)

    return effect
end

--- dump_effects
-- Dumps all effects affecting a player into a string
-- @param player_name Name of the player
-- @returns String describing effects
function effects_api.dump_effects(player_name)
	local str = ""
	if player_name then
		if active_player_effects[player_name] then
			for _, effect in ipairs(active_player_effects[player_name]) do
				if str ~= "" then str=str.."\n" end

				str = str .. string.format("%s:%s %d%% %.1fs ",
					player_name,
					effect.phase or "?",
					(effect.intensity or 0)*100,
					effect.elapsed_time or 0)
				if effect.impacts then
					for impact, _ in pairs(effect.impacts) do
						str=str..impact.." "
					end
				end
			end
		end
	else
		for player_name, _ in pairs(active_player_effects) do
			str=str..effects_api.dump_effects(player_name)
		end
	end
	return str
end

--function effects.affect_mob(mob?, effect_def)
--function effects.affect_world(effect_def)

-- Arret d'un effet ajouté ? Par exemple poison ? --> Groupe d'effet

