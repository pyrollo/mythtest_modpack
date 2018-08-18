
-- Speed
--------
-- Params :
-- 1: Speed multiplier [0..infinite]. Default: 1

effects_api.register_impact_type('player', 'speed', {
	reset = function(impact) 
			impact.subject:set_physics_override({speed = 1.0}) 
		end,
	update = function(impact) 
			impact.subject:set_physics_override({
				speed = effects_api.multiply_valints(
					effects_api.get_valints(impact.params, 1))
			})
		end,
})

-- Jump
-------
-- Params :
-- 1: Jump multiplier [0..infinite]. Default: 1

effects_api.register_impact_type('player', 'jump', {
	reset = function(impact) 
			impact.subject:set_physics_override({jump = 1.0}) 
		end,
		update = function(impact) 
			impact.subject:set_physics_override({
				jump = effects_api.multiply_valints(
					effects_api.get_valints(impact.params, 1))
			})
		end,
})

-- Gravity
----------
-- Params :
-- 1: Gravity multiplier [0..infinite]. Default: 1

effects_api.register_impact_type('player', 'gravity', {
	reset = function(impact) 
			impact.subject:set_physics_override({gravity = 1.0}) 
		end,
	update = function(impact) 
			impact.subject:set_physics_override({
				gravity = effects_api.multiply_valints(
					effects_api.get_valints(impact.params, 1))
			})
		end,
})

-- Health
---------
-- Params :
-- 1: Health points per seconds gain or loss

-- TODO:
-- 1: Health points gained (+) or lost (-) per period
-- 2: Period in seconds

local function change_hp(player, delta, reason)
	local hp = player:get_hp()
	if delta + hp  > (core.PLAYER_MAX_HP_DEFAULT or 20) then
		delta = (core.PLAYER_MAX_HP_DEFAULT or 20) - hp
	end
	if delta + hp < 0 then
		delta = hp
	end
	hp = delta + hp 
	player:set_hp(hp, reason)
	return delta
end

effects_api.register_impact_type('player', 'health', {
	vars = { timer = 0 },
	step = function(impact, dtime)
		impact.vars.timer = impact.vars.timer + dtime
		if impact.vars.timer > 1 then
			local health = effects_api.sum_valints(
				effects_api.get_valints(impact.params, 1))
			local times = math.floor(impact.vars.timer)

			change_hp(impact.subject, times*health, 'magic')

			impact.vars.timer =	impact.vars.timer - times
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
			if not impact.vars.initial_textures then
				local props = impact.subject:get_properties()
				if props.textures then
					impact.vars.initial_textures = table.copy(props.textures)
					for key, value in pairs(props.textures) do
						props.textures[key] = value.."^[colorize:#80000040"
--						props.textures[key] = value.."^[opacity:128" -- invisible
--						props.textures[key] = value.."^[opacity:129" -- visible
-- https://github.com/minetest/minetest/pull/7148 
-- Alpha textures on entities to be released in Minetest 0.5
					end
					impact.subject:set_properties(props)
				end
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
