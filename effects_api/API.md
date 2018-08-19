**NOT UP TO DATE AT ALL!**
Needs a total rewrite

# Introduction
This API is for managing lasting effects, not instant effects.

**Impacts**: An elementary impact on player. Different effects can result in the same impact. In that case, their parameters and intensities are properly mixed to result in a single player impact.

**Effects**: Combination of impacts, conditions and subject (player). Many effects at once can be affected to a player, with different conditions (duration, area, equipment).

Conditions are only for stopping effect. Effect_api is not continiusly scanning for conditions to be fullfiled and starting effects. Effect creation has to be triggered explicitely.

# Effects
There is no effect type registry. Effect definition dirrectly given when a new effect set on a player.

Usualy, effects are created using `affect_player` function. But some helpers are provided for item making effect on their bearers (see "Item effects" below).
## affect_player
```lua
function effects_api.affect_player(player_name, effect_definition)
```
Affects a player with an effect.

`player_name`: Name of the player to affect effect to;

`effect_definition`: Effect defintion table;

### Effect definition table
`effect_definition` table may contain following fields:

  * `impacts` Impacts effect has (pair of impact name / impact parameters);
  * `raise` Time it takes in seconds to raise to full intensity (default 0: immediate);
  * `fall` Time it takes to fall, after end to no intensity (default 0: immediate);
  * `conditions` Table of conditions. If not all conditions are fullfiled, effect stops. Possible fileds:
      * `duration` Duration in second of effect (default always);
      * `equiped_with` Effects falls if not equiped with this item anymore (armor or wielding);
      *  `location` Location definition where the effect is active (default everywhere);

`equiped_with` is used to link effect to an item/tools. It is automatically added to effect definition when effect definition is set in item definition.

`location`(WIP) is used to link effect to a node in world.

Example of effect definition:
```lua
-- Player can run fast and make high jumps for 20 seconds
effects_api.affect_player('singleplayer', {
    impacts = { jump=3, speed=10 },
    fall = 2,
    conditions = { duration = 20 }
})
```
Of course, *jump* and *speed* impacts have to be defined (they are a part of effects_base mod).

## Item effects
Easy way to create an item that makes an effect is to add an `effect` field to the item definition.

This `effect`field should contain an effect definition as described above. In such case, player is affected with this effect as soon as it gets equiped with that item. The `equiped_with` condition is automatically added to the definition so the effects stops when unequiped.

Example of jump boots:
```lua
minetest.register_tool("mymod:jump_boots", { 
    description = "Jump boots", 
    ...
    -- (standard definition)
    ...
    effect = { 
        impacts = { jump=3 },
    }
    ...
}) 
```

# Impacts registration
## register\_player\_impact\_type
```lua
function effects_api.register_player_impact_type(name, definition)
```
Registers a player impact type.
`name`: Name of the impact type;

`definition`: Definition table of the impact type;

### Impact definition table
`definition` table may contain following fields:

  * `vars`Internal variables needed by the impact (variables will instantiated for each player) (optional);
  
  * `reset` (optional) = function(impact) Function called when impact stops to reset normal player state (optional);
  
  * `update` (optional) = function(impact) Function called when impact changes to apply impact on player;
  
  * `step` (optional) = function(impact, dtime) Function called every global step (optional);

### Impact instance table

`impact`argument passed to previous function is a table representing the impact instance concerned. Table fields are :
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

`params`: the impact.params field;

`index`: index of the params field to be extracted;

## append_valints
```lua
function effects_api.append_valints(valints, extravalints) 
```
Appends a values and intensities list to another. Usefull to add extra values in further computation.

`valints`: List where extra valints will be append;

`extravalints`: Extra valints to append;

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
`valints`: Value/Intensity list;

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

`colorspec` Can be a standard color name, a 32 bit integer or a table;

## color_to_rgb_texture
```lua
function effects_api.color_to_rgb_texture(colorspec) 
```
Converts a colorspec to a "#RRGGBB" string ready to use in textures.

`colorspec` Can be a standard color name, a 32 bit integer or a table; 

## Full example of impact type creation
```lua
-- Impacts on player speed
-- Params:
-- 1: Speed multiplier [0..infinite]. Default: 1
effects_api.register_player_impact_type('speed', { 
    -- Reset function basically resets player speed to default value
    reset = function(impact)  
            local player = minetest.get_player_by_name(impact.player_name) 
            if player then
                player:set_physics_override({speed = 1.0}) 
            end
        end,
    -- Main function actually coding the impact
    update = function(impact)
        local player = minetest.get_player_by_name(impact.player_name) 
        if player then
            -- Use multiply_valints and get_valints to perform parameter and intensity mixing between all effects
            player:set_physics_override({ 
                speed = effects_api.multiply_valints(
                    effects_api.get_valints(impact.params, 1))
            }) 
        end 
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

## Main loops
### players_effects_loop
```lua
function effects_api.players_effects_loop(dtime)
```
Performs one step of players effects loop. To be called in a globalstep callback.

`dtime`: Time since last step;

### players_impacts_loop
```lua
function effects_api.players_impacts_loop(dtime)
```
Performs one step of players impacts loop. To be called in a globalstep callback.

`dtime`: Time since last step;

### players_wield_hack
```lua
effects_api.players_wield_hack(dtime)
```
This is a hack to detect wielded item change as Minetest API is missing such event. This function detects wielded item change and triggers effects accordingly.

## Persistance
### save_player_data
```lua
function effects_api.save_player_data(player)
```
Save effects player data to player storage.
`player`: Concerned player;

### load_player_data
```lua
function effects_api.load_player_data(player)
```
Loads effects player data from player storage.
`player`: Concerned player;

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

# Other
## Effect phases
Effects have a cycle of life consisting in four phases :
### raise
Effect starts in this phase.

It stops after effect.raise seconds or if effect conditions are no longer fulfilled.

Intensity of effect grows from 0 to 1 during this phase.
### still
Once raise phase is completed, effects enters the *still* phase.

Intensity is full and the phases lasts until one of the conditions stops being fulfilled.
### fall
When conditions are no longer fulfilled, effect enters fall phase.

This phase lasts effect.fall seconds (if 0, effects gets to *end* phase instantly). 
### end
This is the terminal phase.

Effect will be deleted in next step.
