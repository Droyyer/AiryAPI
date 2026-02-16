--    AiryAPI v0.2.0 by: Dyrris__ / dyrris_agni
--
--    !WARNING!
--    While I deem this version of the API "functional", calling it stable and coherent would be a stretch.
--    It may break in unexplainable ways, lack documentation in important places, or just behave weird.
--    You are welcome to report all occurrences of bugs either in issues on this repository or in my discord direct messages.
--    Ideas/suggestions are also welcome.
--
--    A figura API meant for creation of interactive valves and air chambers for things such as pooltoys, balloons, and other airfilled objects/critters




local airyapi = {}

---------------- Config Stuff ----------------

airyapi.defaultDeflationSpeed = 0.0005    -- (0.0005) How fast air will escape from a valve with undefined deflationSpeed
airyapi.defaultValveHitboxSize = 4    -- (4) The cube area (size*size*size) that will be eligible for hitscans on valves with undefined hitboxes
airyapi.interactionRange = 3.5    -- (3.5) How close (In blocks) a player has to be to be to interact with valves on you
airyapi.deflationSpeedModifier = 1    -- (1) Technically not a configuration value and is changed (or intended to be) with an action during runtime, but eh. Modifies the speed of all deflation values

airyapi.disableInteractions = false    --(false) Prevents others from interacting with the valves
airyapi.disableBuiltInScaling = false    -- (false) Prevents the API from scaling the model on its own. Set this to true if you intend to run scale logic on your own (Eg. using a squish/wobble-like script)
airyapi.disableCameraOffset = true    -- (true) Prevents the API from offsetting your camera pivot depending on the air left in main chamber. True by default

airyapi.rootScale = 1    -- (1) Scale of the model that affects some of the built-in scaling features. Edit this if you're using setScale method to edit the size of your avatar

airyapi.increaseDeflationPitch = true    -- (true) Increases the pitch of the deflation sound if multiple valves are open at once. Limits at 4 valves (1.15 pitch) unless reconfigured

airyapi.airHudColor = "#00BBFF"    -- ("#00BBFF") Default color of AirHuds
airyapi.airHudDeflatingColor = "#CF1D3B"    -- ("#CF1D3B") Color of AirHuds if one of the chamber's valves is open

airyapi.syncCooldown = 200    -- (200) How often a sync ping will be made (Meant to synchronize your data to other users if they loaded you later or whatever)


airyapi.extraValveInteractCheck = nil    -- (nil) A function that is ran during a valve interaction check. The check will be cancelled if this function returns false at that point in time
airyapi.cameraOffsetOverride = nil    -- (nil) A function that cancels this script's camera offset functionality if it returns true at that point in time. If a Vector3 is returned, offsets the camera by that vector instead




---------------- Sound Stuff ----------------



airyapi.valveInteractionSound = {
    sound = "entity.item.pickup",
    volume = 1,
    pitch = 1
}

airyapi.deflationSound = nil
airyapi.deflationSoundOriginalPitch = 1    -- Exists because the actual pitch is dynamically changed

airyapi.reinflationSound = {
    sound = "entity.generic.extinguish_fire",
    volume = 0.875,
    pitch = 1.375
}


---Changes the sound that plays when a valve is interacted with (either opened or closed)
---@param sound string
---@param volume number?
---@param pitch number?
function airyapi:setValveInteractionSound(sound, volume, pitch)

    local newSound = {
        sound = sound,
        volume = volume or 1,
        pitch = pitch or 1
    }

    self.valveInteractionSound = newSound

end



---Changes the sound that plays in a loop during deflation
---@param sound string|Sound
---@param volume number?
---@param pitch number?
---@param attenuation number?
---@param subtitle string?
function airyapi:setDeflationSound(sound, volume, pitch, attenuation, subtitle)
    
    if type(sound) == "Sound" then

        sound:setLoop(true)

        self.deflationSound = sound
        return

    else

        local newSound = sounds[sound]

        newSound:setLoop(true)

        if volume then newSound:setVolume(volume) end
        if pitch then newSound:setPitch(pitch) end
        if attenuation then newSound:setAttenuation(attenuation) end
        if subtitle then newSound:setSubtitle(subtitle) end

        self.deflationSound = newSound
        self.deflationSoundOriginalPitch = pitch or 1

        return

    end

end
local function getDeflationPitch(openValveCount)

    openValveCount = math.min(openValveCount,4)

    return -0.0125 * openValveCount^2 + 0.1125 * openValveCount + 0.9 + airyapi.deflationSoundOriginalPitch - 1

end



---Changes the sound that plays when reinflation action is triggered
---@param sound string
---@param volume number?
---@param pitch number?
function airyapi:setReinflationSound(sound, volume, pitch)

    local newSound = {
        sound = sound,
        volume = volume or 1,
        pitch = pitch or 1
    }

    self.reinflationSound = newSound

end





---------------- Chamber Stuff ----------------

---@class chamber
---@field modelpart ModelPart
---@field name string
---@field air number
---@field valves valve[]
---@field isMain boolean    -- For the sake of avoiding modelpart comparison again

local metachamber = {}
metachamber.__index = metachamber


---Applies the scale to the modelpart this chamber is attached to
---@param self table
function metachamber.applyScale(self)

        if self.isMain then

            if not airyapi.disableBuiltInScaling then

                self.modelpart:setScale(
                    1 + (1 - self.air) * 0.075 * airyapi.rootScale,
                    self.air * airyapi.rootScale,
                    1 + (1 - self.air) * 0.075 * airyapi.rootScale
                )
            
            end
            
            if host:isHost() and not airyapi.disableCameraOffset then

                local offset = vec(0, 0, 0)
                local override = airyapi.cameraOffsetOverride and airyapi.cameraOffsetOverride()

                
                if not override then

                    offset.y = (airyapi.rootScale - 1) * player:getEyeHeight() - (1 - self.air) * airyapi.rootScale * player:getEyeHeight()

                elseif type(override) == "Vector3" then

                    offset = override

                else

                    return

                end

                renderer:setOffsetCameraPivot(offset)
                renderer:setEyeOffset(offset)

            end

        else

            if airyapi.disableBuiltInScaling then return end

            local mainAir = airyapi.mainChamber.air

            self.modelpart:setScale(
                1 + (1 - self.air) * 0.075 - (1 - mainAir) * 0.075,
                1 / mainAir * self.air,
                1 + (1 - self.air) * 0.075 - (1 - mainAir) * 0.075
            )

        end

end

---Creates a chamber that can be affected by interactive valves. 
---@param modelpart ModelPart The modelpart that will act as the chamber
---@param name string? The name of this chamber, both for the system and some displaying. Defaults to modelpart name if not provided
---@return chamber
function airyapi:newChamber(modelpart, name)

    local newChamber = {}

    newChamber.modelpart = modelpart
    newChamber.name = name or modelpart:getName()
    
    newChamber.air = 1.00
    newChamber.valves = {}
    newChamber.isMain = false

    setmetatable(newChamber, metachamber)

    return newChamber

end

airyapi.mainChamber = airyapi:newChamber(models, "Main") -- Defaults to models but it's recommended to change it to something else through setMainChamber function (NOT IN THIS FILE!!!)
airyapi.mainChamber.isMain = true -- Don't do that with any other chamber this won't go well


airyapi.secondaryChambers = {} ---@type chamber[]



---Sets a modelpart|chamber to be the primary chamber of this avatar
---@param modelpart any
function airyapi:setMainChamber(chamber)

    if self.mainChamber.modelpart and not self.disableBuiltInScaling then
        self.mainChamber.modelpart:setScale(1)
    end

    if not chamber.air then

        self.mainChamber.modelpart = chamber
        self.mainChamber.air = 1.00

    else
        self.mainChamber = chamber
    end

end



function pings.reinflateAllChambers()
    
    airyapi.mainChamber.air = 1.00
    airyapi.mainChamber:applyScale()

    for _, chamber in pairs(airyapi.secondaryChambers) do

        chamber.air = 1.00
        chamber:applyScale()

    end


    
    if not player:isLoaded() then return end

    if airyapi.reinflationSound then
        sounds:playSound(airyapi.reinflationSound.sound, player:getPos(), airyapi.reinflationSound.volume, airyapi.reinflationSound.pitch)
    end

end

function pings.reinflateChamber(chamberName)
    
    local chamber = chamberName == airyapi.mainChamber.name and airyapi.mainChamber or airyapi.secondaryChambers[chamberName]

    chamber.air = 1.00
    chamber:applyScale()



    if not player:isLoaded() then return end

    if airyapi.reinflationSound then
        sounds:playSound(airyapi.reinflationSound.sound, player:getPos(), airyapi.reinflationSound.volume, airyapi.reinflationSound.pitch)
    end

end


---------------- Valve Stuff ----------------

airyapi.valves = {} ---@type valve[]
---@class valve
---@field modelpart ModelPart
---@field name string
---@field animation Animation
---@field deflationSpeed number
---@field chamber chamber
---@field hitboxSize number
---@field isOpen boolean
---@field isLocked boolean
---@field isOnMainChamber boolean    -- Idfk how heavy modelpart to modelpart comparison is so this exists, fun!


local metavalve = {}
metavalve.__index = metavalve



---Adds a new interactive valve to the avatar
---@param modelpart ModelPart The primary modelpart of the valve
---@param name string? How the valve will be referred to by the system and in UI in some cases. Defaults to modelpart's name if not given
---@param animation Animation? The animation that plays (and is held on last frame) when the valve is opened. Reverses when the valve is closed. Optional, but recommended
---@param deflationSpeed number? The speed at which air will escape from this valve when opened. Defaults to 0.0005 (Or whatever you've changed default deflation speed if you did)
---@param hitboxSize number? The cube area (size*size*size) that will be eligible for hitscans from other users. Defaults to 4 (Or whatever you've configured the default to)
---@param chamber chamber? The modelpart that will act as the air container this valve is connected to. Otherwise the container is the model (or an assigned main modelpart)
---@return valve
function airyapi:newValve(modelpart, name, animation, chamber, deflationSpeed, hitboxSize)

    local modelpartName = modelpart:getName()

    local newValve = {

        modelpart = modelpart,

        -- Kinda important
        name = name or modelpartName,
        animation = animation or nil,

        -- Not so much (Have defaults)
        chamber = chamber or self.mainChamber,
        deflationSpeed = deflationSpeed or self.defaultDeflationSpeed,
        hitboxSize = hitboxSize or self.defaultValveHitboxSize,

        -- Field initiation
        isOpen = false,
        isLocked = false,
        isOnMainChamber = chamber and false or true
        
    }

    if animation then
        animation:setPriority(100):setSpeed(-1):setPlaying(true)
    end

    if chamber then
        self.secondaryChambers[chamber.name] = newValve.chamber
    end


    setmetatable(newValve, metavalve)

    newValve.chamber.valves[#newValve.chamber.valves+1] = newValve
    self.valves[newValve.name] = newValve

    return newValve    -- Not sure why this would be needed, but just in case

end


---Can actually be changed to whatever you want (outside of the API file, of course)! Tampering with this function is challenging, so I'd recommend just looking inside of the API to copy it first
function metavalve:decreaseAir()

    local chamber = self.chamber
    local totalDeflationSpeed = self.deflationSpeed * airyapi.deflationSpeedModifier

    chamber.air = math.clamp(chamber.air - (totalDeflationSpeed * 0.5 * math.max(chamber.air, 0.5)^2 + totalDeflationSpeed * 0.5), 0.05, 1)

    

    chamber:applyScale()

    if airyapi.disableBuiltInScaling then return end    -- Main chamber still receives the applyScale check to offset the camera if needed

    if self.isOnMainChamber and airyapi.secondaryChambers then

        for _, secondaryChamber in pairs(airyapi.secondaryChambers) do
            secondaryChamber:applyScale()
        end

    end

end



---Opens or closes a valve
---@param valveName string The name of the valve (Pinging over the entire thing wouldn't be wise)
---@param state boolean Open (true) or Close (false) the valve

function pings.ToggleValve(valveName, state)

    local valve = airyapi.valves[valveName]

    valve.isOpen = state


    if not player:isLoaded() then return end

    if valve.animation then
        valve.animation:setSpeed(state and 1 or -1)
    end

    if airyapi.valveInteractionSound then
        sounds:playSound(airyapi.valveInteractionSound.sound, player:getPos(), airyapi.valveInteractionSound.volume, airyapi.valveInteractionSound.pitch)
    end

end



function pings.modifyDeflationSpeed(deflationSpeedModifier_)
    airyapi.deflationSpeedModifier = deflationSpeedModifier_
end



---Checks whether a player is eligible to interact with valves on the user at the given moment
---@param otherPlayer Player
---@return boolean
local function canOpenValve(otherPlayer)
    return

        otherPlayer:isLoaded()

        and otherPlayer:getUUID() ~= player:getUUID()

        and (otherPlayer:getPos() - player:getPos()):length() < airyapi.interactionRange
        
        and otherPlayer:getHeldItem().id == "minecraft:air"

        and otherPlayer:getSwingTime() == 1

        and (not airyapi.extraValveInteractCheck or airyapi.extraValveInteractCheck())

end


---Returns aabb hitboxes of all existing/eligible valves
---@return Vec3[][]
---@return table<number, string>
local function getValveAabbs()
    
    local valveAabbs = {} ---@type Vec3[][]
    local valveIndexToKey = {} ---@type table<number, string>


    local index = 1
    for _, valve in pairs(airyapi.valves) do
        

        valveIndexToKey[index] = valve.name

        local valvePos = valve.modelpart:partToWorldMatrix():apply()
        local valveHitboxCorner = valve.hitboxSize/32    -- Halving and dividing into pixels at the same time

        valveAabbs[index] = {
            valvePos - valveHitboxCorner,
            valvePos + valveHitboxCorner
        }
        
        index = index + 1
        
    end

    return valveAabbs, valveIndexToKey

end





---------------- Action Wheel Stuff ----------------

airyapi.airyPage = nil ---@type Page Intentionally left as empty as to not generate an unneeded page if not requested

airyapi.valveActions = {} ---@type Action[]

airyapi.miscActions = {} ---@type Action[]

local chamberIndexToKey = {} ---@type table<number, string>
local selectedChamberIndex = 1

local valveIndexToKey = {} ---@type table<number, string>
local selectedValveIndex = 1

local newDeflationSpeedModifier = airyapi.deflationSpeedModifier


---Creates a page for the AiryAPI
---@param parentPage Page? The page that AiryPage will be parented to. AiryPage is automatically set as the active page and not given an open/exit page actions if not provided a parent
---@return Page|nil
local function createAiryPage(parentPage)
    
    airyapi.airyPage = action_wheel:newPage("AiryPage")

    if parentPage then
        
        parentPage:newAction()
            :setTitle("AiryAPI")
            :setItem("minecraft:light_blue_stained_glass")
            :setColor(vectors.hexToRGB("#174f78"))
            :setHoverColor(vectors.hexToRGB("#479fde"))
            :onLeftClick(function()
                action_wheel:setPage(airyapi.airyPage)
            end)


        airyapi.airyPage:newAction()
            :setTitle("Exit")
            :setItem("minecraft:barrier")
            :setColor(vectors.hexToRGB("#330606"))
            :setHoverColor(vectors.hexToRGB("#DD3636"))
            
            :onLeftClick(function()
                action_wheel:setPage(parentPage)
            end)

    else

        action_wheel:setPage(airyapi.airyPage)

    end

end



local function toggleValveAction(valveName, state)
    
    local action = airyapi.valveActions[valveName]

    if not action then return end

    action
        :setTitle(state and "Close " .. valveName .. " Valve" or "Open " .. valveName .. " Valve")
        :setItem(state and "minecraft:ender_chest" or "minecraft:chest")
        :setColor(state and vectors.hexToRGB("#5c1b24") or vectors.hexToRGB("#1b4a2c"))
        :setHoverColor(state and vectors.hexToRGB("#c74646") or vectors.hexToRGB("#53c94d"))

end

---Creates an action for a valve if not already present
---@param valve valve The valve that will be controlled by this action
---@return Action|nil
local function newValveAction(valve)

    if airyapi.valveActions[valve.name] then return end

    local newValveAction = airyapi.airyPage:newAction()
        :setTitle("Open " .. valve.name .. " Valve")
        :setItem("minecraft:chest")
        :setColor(vectors.hexToRGB("#1b4a2c"))
        :setHoverColor(vectors.hexToRGB("#53c94d"))

    function newValveAction.leftClick()
        
        pings.ToggleValve(valve.name, not valve.isOpen)
        toggleValveAction(valve.name, not valve.isOpen)

    end



    airyapi.valveActions[valve.name] = newValveAction

    return newValveAction

end



local function createMiscActions()

    if not chamberIndexToKey[1] then
        chamberIndexToKey[1] = airyapi.mainChamber.name
    end
    
    for _, chamber in pairs(airyapi.secondaryChambers) do

        local isPresent = false
        for _, chamberName_ in pairs(chamberIndexToKey) do
            if chamber.name == chamberName_ then
                isPresent = true
                break
            end
        end

        if not isPresent then
            chamberIndexToKey[#chamberIndexToKey+1] = chamber.name
        end

    end



    for _, valve in pairs(airyapi.valves) do

        local isPresent = false
        for _, valveName_ in pairs(valveIndexToKey) do
            if valve == valveName_ then
                isPresent = true
                break
            end
        end

        if not isPresent then
            valveIndexToKey[#valveIndexToKey+1] = valve.name
        end

    end


    

    if not airyapi.miscActions["AllChambers"] then

        local reinflateAllAction = airyapi.airyPage:newAction()
            :setTitle("Reinflate All Chambers")
            :setItem("minecraft:ender_eye")
            :setColor(vectors.hexToRGB("#293B77"))
            :setHoverColor(vectors.hexToRGB("#6A82CF"))

            :onLeftClick(pings.reinflateAllChambers)

        airyapi.miscActions["AllChambers"] = reinflateAllAction

    end

    if not airyapi.miscActions["SpecificChamber"] then

        local reinflateAction
        reinflateAction = airyapi.airyPage:newAction()
            :setTitle("Reinflate ".. chamberIndexToKey[selectedChamberIndex] .." Chamber")
            :setItem("minecraft:ender_pearl")
            :setColor(vectors.hexToRGB("#472977"))
            :setHoverColor(vectors.hexToRGB("#806ACF"))

            :onScroll(function (dir)
                
                selectedChamberIndex = (selectedChamberIndex + dir - 1) % #chamberIndexToKey + 1
                reinflateAction:setTitle("Reinflate ".. chamberIndexToKey[selectedChamberIndex] .." Chamber")

            end)

            :onLeftClick(function ()
                pings.reinflateChamber(chamberIndexToKey[selectedChamberIndex])
            end)

        airyapi.miscActions["SpecificChamber"] = reinflateAction

    end




    if not airyapi.miscActions["DisableInteractions"] then

        local disableInteractionsAction
        disableInteractionsAction = airyapi.airyPage:newAction()
            :setTitle(not airyapi.disableInteractions and "Disable Interactions" or "Enable Interactions")
            :setItem(not airyapi.disableInteractions and "minecraft:lantern" or "minecraft:soul_lantern")
            :setColor(vectors.hexToRGB("#68194E"))
            :setHoverColor(vectors.hexToRGB("#DF61A0"))

            :onLeftClick(function ()

                airyapi.disableInteractions = not airyapi.disableInteractions

                disableInteractionsAction:setTitle(not airyapi.disableInteractions and "Disable Interactions" or "Enable Interactions")
                disableInteractionsAction:setItem(not airyapi.disableInteractions and "minecraft:lantern" or "minecraft:soul_lantern")

            end)

        airyapi.miscActions["DisableInteractions"] = disableInteractionsAction

    end


    if not airyapi.miscActions["LockValve"] then
        
        local lockValveAction
        lockValveAction = airyapi.airyPage:newAction()
            :setTitle("Lock ".. valveIndexToKey[selectedValveIndex] .." Valve")
            :setItem("minecraft:tripwire_hook")
            :setColor(vectors.hexToRGB("#555258"))
            :setHoverColor(vectors.hexToRGB("#AEACAF"))

            :onScroll(function (dir)
                
                selectedValveIndex = (selectedValveIndex + dir - 1) % #valveIndexToKey + 1

                local valve = airyapi.valves[valveIndexToKey[selectedChamberIndex]]

                lockValveAction:setTitle((not valve.isLocked and "Lock " or "Unlock ").. valveIndexToKey[selectedValveIndex] .." Valve")
                lockValveAction:setItem(not valve.isLocked and "minecraft:tripwire_hook" or "minecraft:redstone_torch")

            end)

            :onLeftClick(function ()
                
                local valve = airyapi.valves[valveIndexToKey[selectedValveIndex]]

                valve.isLocked = not valve.isLocked


                lockValveAction:setTitle((not valve.isLocked and "Lock " or "Unlock ").. valveIndexToKey[selectedValveIndex] .." Valve")
                lockValveAction:setItem(not valve.isLocked and "minecraft:tripwire_hook" or "minecraft:redstone_torch")

            end)

        airyapi.miscActions["LockValve"] = lockValveAction

    end


    

    if not airyapi.miscActions["ModifyDeflationSpeed"] then

        local modifyDeflationSpeedAction
        modifyDeflationSpeedAction = airyapi.airyPage:newAction()
            :setTitle("Deflation Speed Modifier: " .. airyapi.deflationSpeedModifier)
            :setItem("minecraft:glowstone_dust")
            :setColor(vectors.hexToRGB("#774829"))
            :setHoverColor(vectors.hexToRGB("#E7B64A"))

            :onScroll(function (dir)

                newDeflationSpeedModifier = math.clamp(newDeflationSpeedModifier + dir * 0.1, 0.2, 10)
                modifyDeflationSpeedAction:setTitle("Deflation Speed Modifier: " .. newDeflationSpeedModifier .. " (Click to Update)")

            end)

            :onLeftClick(function ()

                pings.modifyDeflationSpeed(newDeflationSpeedModifier)
                modifyDeflationSpeedAction:setTitle("Deflation Speed Modifier: " .. newDeflationSpeedModifier)

            end)

        airyapi.miscActions["ModifyDeflationSpeed"] = modifyDeflationSpeedAction

    end

end



---Generates an action page that allows the user to control valve states, modify some values and revert air values back to their original state
---@param parentPage Page? The page that AiryPage will be parented to. AiryPage is automatically set as the active page and not given an open/exit page actions if not provided a parent. Can be ran again to generate actions for valves added after the first invocation
function airyapi:generateAiryPage(parentPage)

    if not host:isHost() then return end

    createAiryPage(parentPage)

    for _, valve in pairs(self.valves) do
        newValveAction(valve)
    end

    createMiscActions()

end





---------------- Hud Stuff ----------------

---@class airhud
---@field hud TextTask
---@field chamber chamber

local metaairhud = {}
metaairhud.__index = metaairhud

function metaairhud:updateHud()

    local valves = self.chamber.valves
    local isDeflating
    if #valves < 2 then
        isDeflating = valves[1].isOpen
    else
        for _, valve in pairs(valves) do
            if valve.isOpen then
                isDeflating = true
                break
            end
        end
    end

    self.hud:setText(
        '{"text":"'
        .. self.chamber.name .. ' Air: '.. math.round(self.chamber.air * 1000) / 10 ..
        '%","color":"'
        .. (isDeflating and airyapi.airHudDeflatingColor or airyapi.airHudColor) ..
        '"}'
    ):setOutlineColor(vectors.hexToRGB(isDeflating and airyapi.airHudDeflatingColor or airyapi.airHudColor) / 5)

end


airyapi.AirHudGroup = nil ---@type ModelPart
airyapi.AirHuds = {} ---@type TextTask[]


local currentHudOffsetX = 0
local currentHudOffsetY = 0

local function createAirHudGroup()

    if not host:isHost() then return end

    airyapi.AirHudGroup = models:newPart("AirHud", "Hud")

end

---
---@param chamber chamber
---@param posX number?
---@param posY number?
---@param scale number?
local function newAirHud(chamber, posX, posY, scale)
    
    if not host:isHost() then return end
    if airyapi.AirHuds[chamber.name] then return end

    local airHud = {}

    airHud.hud = airyapi.AirHudGroup:newText("AirHud"..chamber.name)
        :setText('{"text":"' .. chamber.name .. ' Air: '.. math.round(chamber.air * 1000) / 10 ..'%","color":"'.. airyapi.airHudColor ..'"}')
        :setPos(vec((posX or 0) + currentHudOffsetX, (posY or 0) + currentHudOffsetY, 0))
        :setScale(scale or 1)
        :setOutline(true)
        :setOutlineColor(vectors.hexToRGB(airyapi.airHudColor) / 5)
        :setLight(15)

    airHud.chamber = chamber

    setmetatable(airHud, metaairhud)
    airyapi.AirHuds[chamber.name] = airHud

    currentHudOffsetY = currentHudOffsetY - 12 * scale

end


---Creates GUI/Hud elements to visualize air values of all chambers
---@param posX number X position of the list on the screen
---@param posY number Y position of the list on the screen
---@param scale number The scale of the list
function airyapi:generateAirHuds(posX, posY, scale)

    createAirHudGroup()

    if not self.AirHuds[self.mainChamber.name] then
        newAirHud(self.mainChamber, posX, posY, scale)
    end

    for _, chamber in pairs(self.secondaryChambers) do
        
        if not self.AirHuds[chamber.name] then
            newAirHud(chamber, posX, posY, scale)
        end

    end

end



local function updateHuds()
    
    if not host:isHost() then return end

    for _, airHud in pairs(airyapi.AirHuds) do
        airHud:updateHud()
    end

end





---------------- Evil Sync Stuff ----------------

---Sends a synchronization ping that fixes air and valve states to users who loaded the avatar after the values had been changed
local function sendSyncPing()
    
    local dict = {}

    for key, valve in pairs(airyapi.valves) do

        dict[key] = {}

        dict[key][1] = valve.chamber.air
        dict[key][2] = valve.isOpen

    end

    pings.syncValves(dict)
    pings.modifyDeflationSpeed(airyapi.deflationSpeedModifier)

end

function pings.syncValves(dict)

    for key, table in pairs(dict) do

        local valve = airyapi.valves[key]

        valve.chamber.air = table[1]
        valve.isOpen = table[2]

    end

end





---------------- Evil Event Stuff ----------------

local function runValveInteraction()

    if airyapi.disableInteractions then return end

    for _, otherPlayer in pairs(world.getPlayers()) do    -- Totally won't be a problem on big servers! (To be fair players too far away are excluded from most calculations)

        if canOpenValve(otherPlayer) then

            local valveAabbs, valveIndexToKey = getValveAabbs()

            local eyePos = otherPlayer:getPos() + vec(0, otherPlayer:getEyeHeight(), 0)
            local endPos = eyePos + (otherPlayer:getLookDir() * airyapi.interactionRange)

            local _, _, _, valveHit = raycast:aabb(eyePos, endPos, valveAabbs)

            if valveHit then

                local valveName = valveIndexToKey[valveHit]
                local valve = airyapi.valves[valveName]

                if valve.isLocked then return end

                pings.ToggleValve(valveName, not valve.isOpen)
                toggleValveAction(valveName, not valve.isOpen)

            end

        end

    end

end





local function runDeflation()

    local openValveCount = 0

    for key, valve in pairs(airyapi.valves) do
        
        if valve.isOpen and valve.chamber.air > 0.05 then
            openValveCount = openValveCount + 1

            valve:decreaseAir()

        end
    end



    local deflationSound = airyapi.deflationSound

    if not deflationSound then return end
    if openValveCount > 0 then
        
        deflationSound:setPos(player:getPos())
        if airyapi.increaseDeflationPitch then deflationSound:setPitch(getDeflationPitch(openValveCount)) end

        if not deflationSound:isPlaying() then deflationSound:play() end

    else
        if deflationSound:isPlaying() then deflationSound:stop() end
    end
    
end




function events.tick()

    runDeflation()
    updateHuds()

    if host:isHost() then

        runValveInteraction()    -- The check can be ran by host exclusively to decrease stress on the systems of other players

        if airyapi.syncCooldown ~= -1 and world.getTime() % airyapi.syncCooldown == 0 then
            sendSyncPing()
        end

    end

end



return airyapi
