# Introduction
This API is for managing lasting effects, not instant effects.

**Subjects**: Subjects of effects. For now, players and mobs can be subjects of effects.

**Impacts**: An elementary impact on player. Different effects can result in the same impact. In that case, their parameters and intensities are properly mixed to result in a single player impact.

**Effects**: Combination of impacts, conditions and subject. Many effects at once can be affected to a subject, with different conditions (duration, area, equipment).

Conditions are only for stopping effect. Effect_api is not continiusly scanning for conditions to be fullfiled and starting effects. Effect creation has to be triggered explicitely. Some helpers exist to start effects on item equipment or use.

# Effects management
Active effects are represented by Effect objects. Effect objects are created by calling `Effect:new` method. Effects can also be automatically affected when using some items and blocks. In that case, they are defined in item or node definition.

## Effect phases
Effects have a cycle of life consisting in four phases :
### raise
Effect starts in this phase.  
It stops after `effect.raise` seconds or if effect conditions are no longer fulfilled.  
Intensity of effect grows from 0 to 1 during this phase.
### still
Once raise phase is completed, effects enters the *still* phase.  
Intensity is full and the phases lasts until one of the conditions stops being fulfilled.
### fall
When conditions are no longer fulfilled, effect enters fall phase.  
This phase lasts `effect.fall` seconds (if 0, effects gets to *end* phase instantly). 
### end
This is the terminal phase.  
Effect will be deleted in next step.

## Effect definition table
Effect definition table may contain following fields:  
  * `id` Identifier. If given, should be unique for a subject. If not given, an internal id is given.
  * `impacts` Impacts effect has (pair of impact name / impact parameters);
  * `raise` Time (in seconds) it takes to raise to full intensity (default 0: immediate);
  * `fall` Time (in seconds) it takes to fall, after end to no intensity (default 0: immediate);
  * `duration` Duration (in seconds) the effect lasts (default: always)
  * `distance`For effect associated to nodes, distance of action
  * `stopondeath`If true, the effect stops at player death
  
All fields are optional but an effect without impacts would do nothing.

Example of effect definition:
```lua
-- Run fast and make high jumps for 20 seconds
{
    impacts = { jump=3, speed=10 },
    fall = 2,
    duration = 20
}
```
Of course, *jump* and *speed* impacts have to be defined (they are included in base impacts).

## How to affect effects?
 
### With custom code
To affect a subject with an effect, create a new effect using `effects_api.new_effect`, giving the subject and the effect definition.
Think about adding a `duration` or `stop_on_death` clause in effect definition to avoid permanent effect (unless expected).

Example :
```lua
-- Stuck player "toto" for 5 seconds
local player = minetest.get_player_by_name("toto")
if player then
    effects_api.new_effect(player, { duration=5, impacts = { speed=0 } })
end
```

### With items
Items can have effects on players or mobs when:
  * Equiped (in hand or in armor equipment): cloth, amulets, rings;
  * Used (effect on self): potion, food;
  * Used (on someone or something): magic wand, special weapon;

#### Effect when equiped
To create an item that have an effect when equiped, add to the item definition a field named `effect_equip` containing the effect definition.

Example:
```lua
-- Jump boots
minetest.register_tool("mymod:jump_boots", { 
    description = "Jump boots", 
	inventory_image = "mymod_boots.png",
    effect_equip = { impacts = { jump=3 } },
}) 
```
To make boots wearable as boots armor, refer to **3D Armor** mod API.

#### Effect when used
To create an item that have an effect when used:
  * Put the effect definition in item definition field `effect_use` (for use on self) or `effect_use_on` (for use on players or mobs);
  * Add a call to `effects_api.on_use_tool_callback` in item `on_use`;
  * Add an end condition to avoid creating permanent effect : a `duration` clause or `stopondeath=true` clause;

Example:
```lua
-- Poison potion
minetest.register_tool("mymod:poison", { 
    description = "Poison potion", 
	inventory_image = "mymod_potion.png",
    effect_use = { impacts = { damage={ 1, 2 } }, stop_on_death=true },
}) 
```

### With nodes
Effects can be triggered by the proximity of a specific node.

To create a node with effect:
  * Add the node in `effect_trigger` group (`effect_trigger=1` in groups table);
  * Add an `effect_near` field in the node definition __with a `distance`field__;

Example:
```lua
-- Darkness 20 nodes around dark stone
minetest.register_node("mymod:dark_stone", {
	description = "Dark stone",
	tiles = {"default_stone.png"},
    groups = { cracky = 3, stone = 1, effect_trigger = 1 },
    effect_near = { impacts = { daylight=0 }, distance = 20 },
}) 
```

## Methods
### get\_effect\_by\_id
```lua
function effects_api.get_effect_by_id(subject, id)
```
Retrieves an effect affecting a subject by it's id. 

`subject`: Subject affected by the effect.  
`id`: Identifier of the effect to retrieve.

Returns the Effect object if found, `nil` otherwise.

## Effect object
Effect object represent a temporary (or permanent) effect on a subject (player or mob).

### Public methods
#### new
```lua
function Effect:new(subject, definition)
```
Public API :
```lua
function effects_api.new_effect(subject, definition)
```
Creates a new effect on a subject. 

`subject`: Subject to be affected by the effect.  
`definition`: Effect defintion table.

Returns an Effect object if creation succeded, `nil` otherwise.

Possible cause of failure :
  * subject is not suitable (neither a player nor a mob);
  * `definition.id` (optional) field contains a value that is already in use for the subject (check first with `effects_api.get_effect_by_id` if you are using ids);

#### start
```lua
function Effect:start()
```
Starts an effect or restart it.

If conditions are not fulfilled, it will fall in *fall* phase again during next step. So `start`/`restart` should be called only if condition are fulfilled again.

#### restart
```lua
function Effect:restart()
```
Same as `start`.

#### stop
```lua
function Effect:stop()
```
Stops an effect. Actually set it in *fall* phase, regardless of conditions.

#### change\_intensity
```lua
function Effect:change_intensity(intensity)
```
Change intensity of effect. 

`intensity`: New intensity (between 0.0 and 1.0)

Developed for internal purpose but safe to use as public method.

#### set\_conditions(conditions)
```lua
function Effect:set_conditions(conditions)
```
Sets or overrides condition(s) of an effect.
`conditions` Key / value table of conditions.

Developed for internal purpose but safe to use as public method.

### Internal use methods (unsafe)
#### step
```lua
function Effect:step(dtime)
```
Performs a step calculation of effect.
`dtime`: Time since last step.

#### check\_conditions
```lua
function Effect:check_conditions()
```
Check effects conditions are still fulfilled. Returns true or false.

# Impacts registration
## register\_player\_impact\_type
```lua
function effects_api.register_player_impact_type(subjects, name, definition)
```
Registers a player impact type.

`subjects`: Subject type or table of subject types that can be affected by that impact type  
`name`: Name of the impact type  
`definition`: Definition table of the impact type

### Impact definition table
`definition` table may contain following fields:
  * `vars`Internal variables needed by the impact (variables will instantiated for each player) (optional);
  * `reset` (optional) = function(impact) Function called when impact stops to reset normal player state (optional);
  * `update` (optional) = function(impact) Function called when impact changes to apply impact on player;
  * `step` (optional) = function(impact, dtime) Function called every global step (optional);

### Impact instance table
`impact`argument passed to `reset`, `update` and `step` functions is a table representing the impact instance concerned. Table fields are :
  * `subject` Player or mob ObjectRef affected by the impact;
  * `type` Impact type name;
  * `vars` Table of impact variables (copied from impact type definition) indexed by their name;
  * `params` Table of per effect params and intensity;
  * `changed` True if impact changed since last step;

Except variables in `vars`, nothing should be changed by the functions.

 # Impact Helpers
 
In following helpers, valint stands for a pair of value / intensity.

Each effect corresponding to an impact gives one or more parameters to the impact and an effect intensity.

The impact is responsible of computing a single values from these parameters and intensity. Effects_api provides helpers to perform common combination operations.
## get_valints
```lua
function effects_api.get_valints(params, index)
```
Returns extacts value/intensity pairs from impact params table.

Impact params table contains params given by effects definition, plus an *intensity* field reflecting the corresponding effect intensity.

`params`: the impact.params field  
`index`: index of the params field to be extracted

## append_valints
```lua
function effects_api.append_valints(valints, extravalints) 
```
Appends a values and intensities list to another. Usefull to add extra values in further computation.

`valints`: List where extra valints will be append  
`extravalints`: Extra valints to append

## multiply_valints
```lua
function effects_api.multiply_valints(valints)
```
Returns the result of a multiplication of values with intensities

`valints`: Value/Intensity list;

## sum_valints
```lua
function effects_api.sum_valints(valints)
```
Returns the result of a sum of values with intensities

`valints`: Value/Intensity list

## mix_color_valints
```lua
function effects_api.mix_color_valints(valints) 
```
Mix colors with intensity. Returns {r,g,b,a} table representing the resulting color.

`valints` List of colorstrings (value=) and intensities 

## color_to_table
```lua
function effects_api.color_to_table(colorspec) 
```
Converts a colorspec to a {r,g,b,a} table. Returns the conversion result.

`colorspec` Can be a standard color name, a 32 bit integer or a table

## color_to_rgb_texture
```lua
function effects_api.color_to_rgb_texture(colorspec) 
```
Converts a colorspec to a "#RRGGBB" string ready to use in textures.

`colorspec` Can be a standard color name, a 32 bit integer or a table

## Full example of impact type creation
```lua
-- Impacts on player speed
-- Params:
-- 1: Speed multiplier [0..infinite]. Default: 1
effects_api.register_player_impact_type('speed', {
    -- Reset function basically resets subject speed to default value
    reset = function(impact)
            impact.player:set_physics_override({speed = 1.0})
        end,
    -- Main function actually coding the impact
    update = function(impact)
        -- Use multiply_valints and get_valints to perform parameter and intensity mixing between all effects
        impact.player:set_physics_override({speed =
            speed = effects_api.multiply_valints(
                effects_api.get_valints(impact.params, 1))
        })
    end,
})
```

# More internal stuff
 ## Debug
### dump_effects
```lua
function effects_api.dump_effects(player_name)
```
Returns a string containing a dump of all effects affecting *player_name* player. For debug purpose.

## Main loop
### step
```lua
function effects_api.step(dtime)
```
Performs one step on all active effects. To be called in a globalstep callback.

`dtime`: Time since last step

### players_wield_hack
```lua
effects_api.players_wield_hack(dtime)
```
This is a hack to detect wielded item change as Minetest API is missing such event. This function detects wielded item change and triggers effects accordingly.

### on_dieplayer
```lua
effects_api.on_dieplayer(player)
```
Stops effects marked with `stop_on_deaht=true` for a player. To be called in a register_on_dieplayer.

`player`: Player who died

## Ohter stuff
### get_storage_for_subject
```lua
effects_api.get_storage_for_subject(subject)
```
Retrieves or create the effects_api storage for a subject.

`subject`: Subject

Returns storage associated with the subject or `nil` if subject not suitable.

### is_equiped
```lua
effects_api.is_equiped(subject, item_name)
```
Equipment condition check. Can be overriden to extend equipment to other than wielded item (done in 3D Armor integration).

`subject`: Subject to check equipment for  
`item_name`: Name of the item that should equip the subject

Returns true or false whether subject equiped with item or not.

### is_near_nodes
```lua
effects_api.is_near_nodes(subject, near_node)
```
Location condition check. Can be overriden to extend or change location condition.

`subject`: Subject to check location for  
`near_node`: table defining location

## Persistance
### serialize_effects
```lua
effects_api.serialize_effects(subject)
```
Serialize all effects_api data for given subject.

`subject`: Subject to serialize data from

Returns a serialized string containing subject data.

### deserialize_effects
```lua
effects_api.deserialize_effects(subject, serialized)
```
Deserialize data for a subject. The subject should have no effects_api data associated with yet or deserialization will not be performed.

`subject`: Subject to deserialize data to  
`serialized`: Serialized data

### save_player_data
```lua
function effects_api.save_player_data(player)
```
Save effects player data to player storage.

`player`: Concerned player

### load_player_data
```lua
function effects_api.load_player_data(player)
```
Loads effects player data from player storage.

`player`: Concerned player

### save_all_players_data
```lua
function effects_api.save_all_players_data()
```
Saves all players data into player storage.

### forget_player
```lua
function effects_api.forget_player(player)
```
Unload player data from memory.


