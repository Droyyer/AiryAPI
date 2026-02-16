A figura API meant for creation of interactive valves and air chambers for things such as pooltoys, balloons, and other airfilled objects/critters

## !WARNING!
While I deem this version of the API "functional", calling it stable and coherent would be a stretch.
It may break in unexplainable ways, lack documentation in important places, or just behave weird.
You are welcome to report all occurrences of bugs either in issues on this repository or in my discord direct messages. Ideas/suggestions are also welcome.

## Installation
1. Throw the lua file into your avatar folder
2. Require it as such:
   ```lua
   local airyapi = require("AiryAPI") -- The name of the variable doesn't really matter, it's up to you
   ```
   Or, if the file is within a subfolder:
   ```lua
   local airyapi = require("path/to/file/AiryAPI") -- The name of the variable doesn't really matter, it's up to you
   ```
   And that's it. You can utilize all the methods through this declaration

## Usage
In most cases, you'll want to set a modelpart as your primary chamber (Secondary chambers will only work independently while one of their ancestor modelparts is scaled if said ancestor is the main chamber):
```lua
-- All examples will assume that the declaration of API is "airyapi"
airyapi:setMainChamber(models.model_file.main_chamber_modelpart)
```

Next, a chamber needs an interactive valve to function, which can be created using the `newValve(modelpart: ModelPart, name?: string, animation?: Animation, deflationSpeed?: number, hitboxSize?: number)` method:
```lua
airyapi:newValve(

    models.model_file.path.to.valve.Valve, -- The main group/cube/mesh of the valve. Its pivot will also determine the center of this valve's hitbox
    "valve_name",                          -- The name of this valve used both for display and by the system. Defaults to modelpart name if not provided. Valve names should NEVER repeat
    animations.modelfile.animation_name,   -- The animation to play when this valve is opened or closed (closing reverses the animation)
    nil,                                   -- The chamber that this valve will act upon. Leave as nil to attach to main chamber
    0.000625,                              -- The speed at which air will be removed from the chamber if this valve is opened. Defaults to configuration's deflation speed (0.0005)
    3.5                                    -- The cubic hitbox (size*size*size) that another player has to hit to interact with the valve. Defaults to configuration's hitbox size (4)

)
```

Adding secondary chambers can be done through `newChamber(modelpart: ModelPart, name?: string)` method, which can also be called right in the middle of `newValve` method as the fourth argument:
```lua
airyapi:newValve(

    models.model_file.path.to.valve.SecondaryValve, 
    "secondary_valve_name",                               
    animations.model_file.animation_name,          
    airyapi:newChamber(
        models.model_file.path.to.chamber, -- The modelpart of the new chamber. All secondary chambers should at some point have the main chamber as the ancestor to scale properly when it is affected
        "chamber_name"                     -- The name of the new chamber. All the same rules as valve names: default to modelpart name, should never repeat
    ),                                  
    nil,                                  
    nil                                   

)
```

**While this is enough for functional interactive values, additional setup is advised, such as**:
Adding a deflation sound using `setDeflationSound(sound: string|Sound, volume?: number, pitch?: number, attenuation?: number, subtitle?: string)` method, otherwise there will be none:
```lua
airyapi:setDeflationSound("sound_id_or_file", 0.875, 1.1) -- All further arguments can be skipped if you don't have the need to provide them
```
Generating an action wheel page through `generateAiryPage(parentPage?: Page)` method to have easy control over aspects of the API in the game:
```lua
airyapi:generateAiryPage(mainPage) -- The generated page will be assumed as the main page of the action wheel if you don't provide one
```
<sub>Or you can code your custom interface, whatever works best for you</sub>

Generating UI/Hud elements with the `generateAirHuds(posX?: number, posY?: number, scale?: number)` method to view air values of chambers:
```lua
airyapi:generateAirHuds(-10, -10, 0.75) -- Position values are generally negative as [0;0] is the top left corner of your screen
```

The API has built-in modelpart scaling code, so if you wish to write your own based on API's values, you need to disable the scaling by setting `disableBuiltInScaling` to `true`:
```lua
airyapi.disableBuiltInScaling = true
```

There is also an experimental feature that offsets the camera based on the air left in main chamber that can be enabled by setting `disableCameraOffset` to `false`:
```
airyapi.disableCameraOffset = false
```
(The feature is slightly wonky and will likely not work as intended if the camera is affected by any other script)

### Other Useful Stuff:
`disableInteractions` - Disables all valve interactions. Can be changed through a built-in action, too

`extraValveInteractCheck` - This function will run every time a valve interaction check is ran as if it was a part of the check (The interaction is cancelled if return is not truthy)

`cameraOffsetOverride` - This function will run every time the script attempts to affect the camera offset. If returned truthy, the camera won't be offset. If returned Vector3, the camera will be offset to that vector instead

`defaultDeflationSpeed` - All new valves without own deflation speed will default to this

`defaultValveHitboxSize` - All new valves without own hitbox size will default to this

`interactionRange` - How close a player has to be to interact with the valves

`rootScale` - The API will treat the avatar to be of this scale. Use this when you affect the entire avatar's scale with `setScale`

`increaseDeflationPitch` - Whether or not opening multiple valves at once will slightly increase the pitch of the deflation sound

`airHudColor` - The color of the generated GUI elements in their default state

`airHudDeflatingColor` - The color of GUI elements when their respective chamber is losing air

`syncCooldown` - How often the script will send sync pings to synchronize values to players who loaded the avatar after values had already been changed

`setValveInteractionSound(sound?: string, volume?: number, pitch?: number)` - Changes the sound that plays when a valve is opened or closed

`setReinflationSound(sound?: string, volume?: number, pitch?: number)` - Changes the sound that plays when the user reverts all air values back to maximum
