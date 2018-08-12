effects_base = {}
effects_base.name = minetest.get_current_modname()
effects_base.path = minetest.get_modpath(effects_base.name)

dofile(effects_base.path.."/impacts.lua")

