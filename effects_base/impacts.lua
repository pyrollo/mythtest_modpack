
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
			print("jump data default:"..dump(data.defaults))
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

-- Visible (WIP)
----------
-- Params :
-- TODO:1: Vision multiplier [0..1]. 0 = Blind, 1 and above = normal. Default: 1

effects_api.register_impact_type('player', 'visible', {
    reset = function(impact)
			impact.subject:set_properties({is_visible = 1 })
		end,
	update = function(impact)
			local vision = effects_api.multiply_valints(
				effects_api.get_valints(impact.params, 1))
			impact.subject:set_properties({is_visible = vision >=1 })
		end,
})

-- Daylight (WIP)
-----------
-- Params :
-- 1: Daylight multiplier [0..1]. 0 = Dark, 1 = normal. Default: 1
-- TODO : [-1..0] : same but lightens.

-- Function computing default daynight ratio (there is no (yet?) any lua api
-- function to do that). More or less LUA version of C++ time_to_daynight_ratio
-- funtion from minetest/src/daynightratio.h

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

-- TODO:revoir comment calculer ca. Il faut que l'intensite indique l'influence vers le jour ou la nuit
effects_api.register_impact_type('player', 'daylight', {
	reset = function(impact)
			impact.subject:override_day_night_ratio(nil)
		end,
	update = function(impact)
			local baseratio = get_default_daynight_ratio()
			local daylight = effects_api.multiply_valints(
				effects_api.get_valints(impact.params, 1))
			impact.subject:override_day_night_ratio(daylight)
--			impact.subject:override_day_night_ratio(get_default_daynight_ratio())
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
				math.ceil(255-vision*255) --^[colorize:#000000:255^
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

-- Texture (WIP)
----------
-- Params:
-- 1-Colorize 
-- 2-Opacity [0..1]

effects_api.register_impact_type({'player', 'mob'}, 'texture', {
	vars = { initial_textures = nil },
	reset = function(impact)
			if impact.vars.initial_textures then
				impact.subject:set_properties({ 
					textures = impact.vars.initial_textures })
				impact.vars.initial_textures = nil
			end
		end,
	update = function(impact)

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

			local props = impact.subject:get_properties()
			if props.textures then
				if not impact.vars.initial_textures then
					impact.vars.initial_textures = table.copy(props.textures)
				end
				for key, _ in pairs(props.textures) do
					props.textures[key] = impact.vars.initial_textures[key]
						..modifier
--						props.textures[key] = value.."^[opacity:128" -- invisible
--						props.textures[key] = value.."^[opacity:129" -- visible
-- https://github.com/minetest/minetest/pull/7148 
-- Alpha textures on entities to be released in Minetest 0.5
				end
				impact.subject:set_properties(props)
			end
		end,
	})
	
	
--[[ Notes
    player:set_properties({object property table}) 
    
{
    hp_max = 1,
    physical = true,
    weight = 5,
    collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
    visual = "cube"/"sprite"/"upright_sprite"/"mesh"/"wielditem",
    visual_size = {x=1, y=1},
    mesh = "model",
    textures = {}, -- number of required textures depends on visual
    colors = {}, -- number of required colors depends on visual
    spritediv = {x=1, y=1},
    initial_sprite_basepos = {x=0, y=0},
    is_visible = true,
    makes_footstep_sound = false,
    automatic_rotate = false,
}    
--]]
