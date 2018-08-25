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
