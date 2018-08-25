--[[
    effects_api mod for Minetest - Library to add temporary effects.
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

-- Speed
--------
-- Params :
-- 1: Speed multiplier [0..infinite]. Default: 1

effects_api.register_impact_type('player', 'speed', {
	reset = function(impact, data)
			impact.subject:set_physics_override(
				{speed = (data.defaults.speed or 1.0) })
		end,
	update = function(impact, data)
			impact.subject:set_physics_override({
				speed = (data.defaults.speed or 1.0) *
					effects_api.multiply_valints(
					effects_api.get_valints(impact.params, 1))
			})
		end,
})

-- Jump
-------
-- Params :
-- 1: Jump multiplier [0..infinite]. Default: 1

effects_api.register_impact_type('player', 'jump', {
	reset = function(impact, data)
			impact.subject:set_physics_override(
				{jump = (data.defaults.jump or 1.0)})
		end,
		update = function(impact, data)
			impact.subject:set_physics_override({
				jump = (data.defaults.jump or 1.0) *
					effects_api.multiply_valints(
					effects_api.get_valints(impact.params, 1))
			})
		end,
})

-- Gravity
----------
-- Params :
-- 1: Gravity multiplier [0..infinite]. Default: 1

effects_api.register_impact_type('player', 'gravity', {
	reset = function(impact, data)
			impact.subject:set_physics_override({
				gravity = (data.defaults.jump or 1.0)})
		end,
	update = function(impact, data)
			impact.subject:set_physics_override({
				gravity = (data.defaults.gravity or 1.0) *
					effects_api.multiply_valints(
					effects_api.get_valints(impact.params, 1))
			})
		end,
})

-- Damage
---------
-- Params :
-- 1: Health points lost (+) or gained (-) per period
-- 2: Period length in seconds
-- TODO: Use a different armor/damage group for magic ?
-- TODO: Or adapt damage to armor group
effects_api.register_impact_type({'player', 'mob'}, 'damage', {
	step = function(impact, dtime)
		for _, params in pairs(impact.params) do
			params.timer = (params.timer or 0) + dtime
			local times = math.floor(params.timer / (params[2] or 1))
			if times > 0 then
				impact.subject:punch(impact.subject, nil, {
					full_punch_interval = 1.0,
					damage_groups = {
						fleshy = times * (params[1] or 0) * params.intensity }
				})
				params.timer = params.timer - times * (params[2] or 1)
			end
		end
	end,
})

-- Daylight
-----------
-- Params :
-- 1: Daylight aimed [0..1]. 0 = Dark, 1 = Full daylight

-- Function computing default daynight ratio (there is no (yet?) any lua api
-- function to do that). More or less LUA version of C++ time_to_daynight_ratio
-- funtion from minetest/src/daynightratio.h

-- TODO: Open a feature request on minetest to expose actual daylight ratio
-- TODO: Impact should be considered as changed when default daylight changes

local function get_default_daynight_ratio()
	local t = minetest.get_timeofday() * 24000
	if t > 12000 then t = 24000 - t end
	local values = {
		{4375, 0.150}, {4875, 0.250}, {5125, 0.350}, {5375, 0.500},
		{5625, 0.675}, {5875, 0.875}, {6125, 1.0}, {6375, 1.0},
	}

	for i, v in ipairs(values) do
		if v[1] > t then
			if i == 1 then
				return v[2]
			else
				local f = (t - values[i-1][1]) / (v[1] - values[i-1][1]);
				return (f * v[2] + (1.0 - f) * values[i-1][2]);
			end
		end
	end
	return 1
end

effects_api.register_impact_type('player', 'daylight', {
	reset = function(impact)
			impact.subject:override_day_night_ratio(nil)
		end,
	update = function(impact)
			impact.subject:override_day_night_ratio(
				effects_api.superpose_valints(
					effects_api.get_valints(impact.params, 1),
					get_default_daynight_ratio()))
		end,
})

-- Texture
----------
-- Params:
-- colorize - Colorize 
-- opacity - Opacity [0..1]

effects_api.register_impact_type({'player', 'mob'}, 'texture', {
	vars = { initial_textures = nil },

	reset = function(impact)
			if impact.vars.initial_textures then
				default.player_set_textures(impact.subject, 
					impact.vars.initial_textures)
				impact.vars.initial_textures = nil
			end
			impact.subject:settexturemod("")
		end,

	update = function(impact)
			local data = effects_api.get_storage_for_subject(impact.subject)
			local modifier = ""
			local color

			for _, param in pairs(impact.params) do
				if param.colorize and param.intensity then
					color = effects_api.color_to_table(param.colorize)
					color.a = color.a * param.intensity
					modifier = modifier.."^[colorize:"..
						effects_api.color_to_rgba_texture(color)
				end
			end

			local opacity = effects_api.multiply_valints(
				effects_api.get_valints(impact.params, "opacity"))
			
			if opacity < 1 then
				-- https://github.com/minetest/minetest/pull/7148
				-- Alpha textures on entities to be released in Minetest 0.5
				-- Before 0.5, subject is either fully visible or invisible
				modifier = modifier.."^[opacity:"..(opacity * 255)
			end

			if data.type == 'mob' then
				impact.subject:settexturemod(modifier)
			end

			if data.type == 'player' then
				-- TODO:integration with 3d armor texture change
				local textures = default.player_get_animation(impact.subject).textures

				if textures then
					if not impact.vars.initial_textures then
						impact.vars.initial_textures = table.copy(textures)
					end
					for key, _ in pairs(textures) do
						textures[key] = impact.vars.initial_textures[key]
													..modifier
					end
					default.player_set_textures(impact.subject, textures)
				end

			end
		end,
	})

-- Vision (WIP)
---------
-- Params :
-- 1: Vision multiplier [0..1]. 0 = Blind, 1 and above = normal. Default: 1
-- TODO: 2: Mask color (colorstring). Default "black".

effects_api.register_impact_type('player', 'vision', {
	vars = { hudid = nil },
	reset = function(impact)
			if impact.vars.hudid then
				impact.subject:hud_remove(impact.vars.hudid)
			end
		end,
	update = function(impact)
			local vision = effects_api.multiply_valints(
				effects_api.get_valints(impact.params, 1))
			if vision > 1 then vision = 1 end
			local text = "effect_black_pixel.png^[colorize:#000000^[opacity:"..
				math.ceil(255-vision*255)
			if impact.vars.hudid then
				impact.subject:hud_change(impact.vars.hudid, 'text', text) 
			else
				impact.vars.hudid = impact.subject:hud_add({
					hud_elem_type = "image",
					text=text,
					scale = { x=-100, y=-100},
					position = {x = 0.5, y = 0.5},
					alignment = {x = 0, y = 0}
				})
			end
		end,
})


