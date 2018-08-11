
-- Speed
--------
-- Params :
-- 1: Speed multiplier [0..infinite]. Default: 1

effects_api.register_player_impact_type('speed', {
    reset = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({speed = 1.0}) 
            end
        end,
	update = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({
                    speed = effects_api.get_impact_mult(impact.params, 1)
                })
            end
        end,
})

-- Jump
-------
-- Params :
-- 1: Jump multiplier [0..infinite]. Default: 1

effects_api.register_player_impact_type('jump', {
    reset = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({jump = 1.0}) 
            end
        end,
	update = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({
                    jump = effects_api.get_impact_mult(impact.params, 1)
                })
            end
        end,
})

-- Gravity
----------
-- Params :
-- 1: Gravity multiplier [0..infinite]. Default: 1

effects_api.register_player_impact_type('gravity', {
    reset = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({gravity = 1.0}) 
            end
        end,
	update = function(impact) 
            local player = minetest.get_player_by_name(impact.player_name)
            if player then
                player:set_physics_override({
                    gravity = effects_api.get_impact_mult(impact.params, 1)
                })
            end
        end,
})

-- Vision
---------
-- Params :
-- 1: Vision multiplier [0..1]. 0 = Blind, 1 and above = normal. Default: 1
-- TODO: 2: Mask color (colorstring). Default "black".

effects_api.register_player_impact_type('vision', {
	vars = { hudid = nil },
    reset = function(impact)
            if impact.vars.hudid then
	    		local player = minetest.get_player_by_name(impact.player_name)
            	player:hud_remove(impact.vars.hudid)
            end
        end,
	update = function(impact)
			local player = minetest.get_player_by_name(impact.player_name)
			local vision = effects_api.get_impact_mult(impact.params, 1)
			if vision > 1 then vision = 1 end
			local text = "effect_black_pixel.png^[colorize:#000000^[opacity:"..		math.ceil(255-vision*255) --^[colorize:#000000:255^
			if impact.vars.hudid then
				player:hud_change(impact.vars.hudid, 'text', text) 
			else
				impact.vars.hudid = player:hud_add({
					hud_elem_type = "image",
					text=text,
					scale = { x=-100, y=-100},
					position = {x = 0.5, y = 0.5},
					alignment = {x = 0, y = 0}
				})
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
