--================================================================--
--                             VGXMOD HUB
--================================================================--

print("------------------------------------------------------------------")
print("Load ................................ Armor V3")
print("Load ................................ Vgxmod Hub")
print("------------------------------------------------------------------")

--================================================================--
-- LOAD LIBRARY (Vgxmod UI)
--================================================================--
local repo = "https://raw.githubusercontent.com/Devilx89/P30/refs/heads/main/"

local success, err = pcall(function()
    Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    ThemeManager = loadstring(game:HttpGet(repo .. "Add-ons/ThemeManager.lua"))()
    SaveManager = loadstring(game:HttpGet(repo .. "Add-ons/SaveManager.lua"))()
end)

if not success then
    warn("Failed to load Vgxmod Hub libraries: " .. tostring(err))
    return
end

local Options = Library.Options
local Toggles = Library.Toggles



--================================================================--
-- CORE SERVICES
--================================================================--
local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote_Event = ReplicatedStorage:WaitForChild("Remote_Event")
local remote = ReplicatedStorage:WaitForChild("Remote_Event")
local TEvent = require(ReplicatedStorage.Shared.Core.TEvent)

local LootsWorld = workspace.GameSystem.Loots.World
local InteractiveItem = workspace.GameSystem.InteractiveItem




--================================================================--
-- ESP SYSTEM 
--================================================================--

local MAX_DISTANCE = 99999

local ESP = {
    Crate     = { Enabled = false, Color = Color3.fromRGB(0, 255, 255), Transparency = 0.7 },
    Cabinet   = { Enabled = false, Color = Color3.fromRGB(0, 255, 255), Transparency = 0.7 },
    OilBucket = { Enabled = false, Color = Color3.fromRGB(0, 255, 255), Transparency = 0.7 },
    Loot      = { Enabled = false, Color = Color3.fromRGB(0, 255, 0), Transparency = 0.7 },
    Monster   = { Enabled = false, Color = Color3.fromRGB(255, 0, 0), Transparency = 0.7 },
    Player    = { Enabled = false, Color = Color3.new(1,1,1), Transparency = 0.5 },
    NPC       = { Enabled = false, Color = Color3.fromRGB(255, 165, 0), Transparency = 0.7 }
}

local INTERACTIVE_FOLDER = Workspace:WaitForChild("GameSystem"):WaitForChild("InteractiveItem")
local LOOT_FOLDER        = Workspace:WaitForChild("GameSystem"):WaitForChild("Loots"):WaitForChild("World")
local MONSTER_FOLDER     = Workspace:WaitForChild("GameSystem"):WaitForChild("Monsters")
local NPC_FOLDER         = Workspace:WaitForChild("GameSystem"):WaitForChild("NPCModels")

local TrackedObjects   = {}
local TrackedLoot      = {}
local TrackedMonsters  = {}
local TrackedNPCs      = {}

local function cleanName(name)
    local prefix = name:match("^[^_%d]+")
    if prefix then
        prefix = prefix:gsub("%s+$", "")
    end
    return prefix
end

local function getObjectType(name)
    local prefix = cleanName(name)
    if not prefix then return nil end
    for objType,_ in pairs(ESP) do
        if prefix:lower() == objType:lower() then
            return objType
        end
    end
    return nil
end

local function getCleanNPCName(model)
    local name = model.Name:match("^(.-)[_%d]") or model.Name
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and name or "NPC"
end

local function createESP(model, fillColor, fillTrans, text)
    if not model or not model.Parent then return end
    local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    local hl = model:FindFirstChild("OBJ_ESP_HL") or Instance.new("Highlight", model)
    hl.Name = "OBJ_ESP_HL"
    hl.Adornee = model
    hl.FillColor = fillColor
    hl.OutlineColor = Color3.new(1,1,1)
    hl.FillTransparency = fillTrans
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local bg = root:FindFirstChild("OBJ_ESP_BILLBOARD") or Instance.new("BillboardGui", root)
    bg.Name = "OBJ_ESP_BILLBOARD"
    bg.Adornee = root
    bg.Size = UDim2.new(0, 240, 0, 50)
    bg.StudsOffset = Vector3.new(0, 4, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = MAX_DISTANCE

    local label = bg:FindFirstChild("Label") or Instance.new("TextLabel", bg)
    label.Name = "Label"
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.RichText = true
    label.Text = text
    label.TextColor3 = Color3.new(1,1,1)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.FontFace = Font.new("rbxassetid://12187362578")
    label.TextSize = 10
end

local function removeESPVisuals(model)
    if not model then return end
    local hl = model:FindFirstChild("OBJ_ESP_HL")
    if hl then hl:Destroy() end
    local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if root then
        local bg = root:FindFirstChild("OBJ_ESP_BILLBOARD")
        if bg then bg:Destroy() end
    end
end

-- Tracking functions
local function trackInteractive(model)
    if not model or not model:IsA("Model") then return end
    local objType = getObjectType(model.Name)
    if objType then
        TrackedObjects[model] = objType
        if not ESP[objType].Enabled then removeESPVisuals(model) end
    end
end
local function untrackInteractive(model)
    TrackedObjects[model] = nil
    removeESPVisuals(model)
end

local function trackLoot(model)
    if model and model:IsA("Model") then
        TrackedLoot[model] = true
        if not ESP.Loot.Enabled then removeESPVisuals(model) end
    end
end
local function untrackLoot(model) TrackedLoot[model] = nil removeESPVisuals(model) end

local function trackMonster(model)
    if model and model:IsA("Model") then
        TrackedMonsters[model] = true
        if not ESP.Monster.Enabled then removeESPVisuals(model) end
    end
end
local function untrackMonster(model) TrackedMonsters[model] = nil removeESPVisuals(model) end

local function trackNPC(model)
    if model and model:IsA("Model") then
        TrackedNPCs[model] = true
        if not ESP.NPC.Enabled then removeESPVisuals(model) end
    end
end
local function untrackNPC(model) TrackedNPCs[model] = nil removeESPVisuals(model) end

-- Initialize tracking
for _, obj in ipairs(INTERACTIVE_FOLDER:GetChildren()) do trackInteractive(obj) end
for _, obj in ipairs(LOOT_FOLDER:GetChildren()) do trackLoot(obj) end
for _, obj in ipairs(MONSTER_FOLDER:GetChildren()) do trackMonster(obj) end
for _, obj in ipairs(NPC_FOLDER:GetChildren()) do trackNPC(obj) end

INTERACTIVE_FOLDER.ChildAdded:Connect(function(obj) task.wait() trackInteractive(obj) end)
INTERACTIVE_FOLDER.ChildRemoved:Connect(untrackInteractive)
LOOT_FOLDER.ChildAdded:Connect(trackLoot)
LOOT_FOLDER.ChildRemoved:Connect(untrackLoot)
MONSTER_FOLDER.ChildAdded:Connect(trackMonster)
MONSTER_FOLDER.ChildRemoved:Connect(untrackMonster)
NPC_FOLDER.ChildAdded:Connect(trackNPC)
NPC_FOLDER.ChildRemoved:Connect(untrackNPC)

-- Toggle ESP
local function toggleESP(name, enabled)
    ESP[name].Enabled = enabled
    Library:Notify({
        Title = name .. " ESP",
        Description = enabled and "Enabled" or "Disabled",
        Time = 4
    })

    if not enabled then
        if name == "Player" then
            for _, plr in pairs(Players:GetPlayers()) do
                removeESPVisuals(plr.Character)
            end
        elseif name == "Monster" then
            for model,_ in pairs(TrackedMonsters) do removeESPVisuals(model) end
        elseif name == "Loot" then
            for model,_ in pairs(TrackedLoot) do removeESPVisuals(model) end
        elseif name == "NPC" then
            for model,_ in pairs(TrackedNPCs) do removeESPVisuals(model) end
        else
            for model,objType in pairs(TrackedObjects) do
                if objType == name then removeESPVisuals(model) end
            end
        end
    end
end

-- Heartbeat loop
RunService.Heartbeat:Connect(function()
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    local myPos = LP.Character.HumanoidRootPart.Position

    -- Interactive Objects
    for model, objType in pairs(TrackedObjects) do
        if not ESP[objType].Enabled then removeESPVisuals(model)
        elseif model and model.Parent then
            local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if root then
                local dist = (root.Position - myPos).Magnitude
                if dist <= MAX_DISTANCE then
                    local text = string.format("<font color='rgb(%d,%d,%d)'>%s</font>\n[%dm]",
                        ESP[objType].Color.R*255, ESP[objType].Color.G*255, ESP[objType].Color.B*255,
                        objType, math.floor(dist))
                    createESP(model, ESP[objType].Color, ESP[objType].Transparency, text)
                else removeESPVisuals(model)
                end
            end
        else removeESPVisuals(model) end
    end

    -- Loot
    if ESP.Loot.Enabled then
        for model,_ in pairs(TrackedLoot) do
            if model and model.Parent then
                local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if root then
                    local dist = (root.Position - myPos).Magnitude
                    if dist <= MAX_DISTANCE then
                        local lootName, price = "Unknown", "0"
                        local lootUI = model:FindFirstChild("Folder") and model.Folder:FindFirstChild("Interactable") and model.Folder.Interactable:FindFirstChild("LootUI")
                        if lootUI and lootUI:FindFirstChild("Frame") then
                            local frame = lootUI.Frame
                            if frame:FindFirstChild("ItemName") then lootName = frame.ItemName.Text end
                            if frame:FindFirstChild("Price") then price = frame.Price.Text end
                        end
                        if lootName == "Unknown" then lootName = "Money"; price = "" end
                        local text = string.format("<font color='rgb(%d,%d,%d)'>%s\n%s</font>\n[%dm]",
                            ESP.Loot.Color.R*255, ESP.Loot.Color.G*255, ESP.Loot.Color.B*255,
                            lootName, price, math.floor(dist))
                        createESP(model, ESP.Loot.Color, ESP.Loot.Transparency, text)
                    else removeESPVisuals(model) end
                end
            else removeESPVisuals(model) end
        end
    else
        for model,_ in pairs(TrackedLoot) do removeESPVisuals(model) end
    end

    -- Monsters
    if ESP.Monster.Enabled then
        for model,_ in pairs(TrackedMonsters) do
            if model and model.Parent then
                local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if root then
                    local dist = (root.Position - myPos).Magnitude
                    if dist <= MAX_DISTANCE then
                        local text = string.format("<font color='rgb(%d,%d,%d)'>%s</font>\n[%dm]",
                            ESP.Monster.Color.R*255, ESP.Monster.Color.G*255, ESP.Monster.Color.B*255,
                            "Monster", math.floor(dist))
                        createESP(model, ESP.Monster.Color, ESP.Monster.Transparency, text)
                    else removeESPVisuals(model) end
                end
            else removeESPVisuals(model) end
        end
    else
        for model,_ in pairs(TrackedMonsters) do removeESPVisuals(model) end
    end

    -- NPCs
    if ESP.NPC.Enabled then
        for model,_ in pairs(TrackedNPCs) do
            if model and model.Parent then
                local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if root then
                    local dist = (root.Position - myPos).Magnitude
                    if dist <= MAX_DISTANCE then
                        local text = string.format("<font color='rgb(%d,%d,%d)'>%s</font>\n[%dm]",
                            ESP.NPC.Color.R*255, ESP.NPC.Color.G*255, ESP.NPC.Color.B*255,
                            getCleanNPCName(model), math.floor(dist))
                        createESP(model, ESP.NPC.Color, ESP.NPC.Transparency, text)
                    else removeESPVisuals(model) end
                end
            else removeESPVisuals(model) end
        end
    else
        for model,_ in pairs(TrackedNPCs) do removeESPVisuals(model) end
    end

    -- Players
    if ESP.Player.Enabled then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = plr.Character.HumanoidRootPart
                local dist = (hrp.Position - myPos).Magnitude
                if dist <= MAX_DISTANCE then
                    local text = string.format("<font color='rgb(255,255,255)'>%s\n[Player]</font>\n[%dm]", plr.DisplayName, math.floor(dist))
                    createESP(plr.Character, ESP.Player.Color, ESP.Player.Transparency, text)
                else removeESPVisuals(plr.Character) end
            end
        end
    else
        for _, plr in pairs(Players:GetPlayers()) do removeESPVisuals(plr.Character) end
    end
end)

--================================================================--
-- ANTI TRAP SYSTEM 
--================================================================--
local RemoveHitboxEnabled = false

local function removeMonsterHitboxes()
    for _, monster in pairs(workspace.GameSystem.Monsters:GetChildren()) do
        for _, part in pairs(monster:GetDescendants()) do
            if part:IsA("TouchTransmitter") then
                part:Destroy()
            end
        end
    end
end

workspace.GameSystem.Monsters.ChildAdded:Connect(function(monster)
    if RemoveHitboxEnabled then
        task.wait()
        for _, part in pairs(monster:GetDescendants()) do
            if part:IsA("TouchTransmitter") then
                part:Destroy()
            end
        end
    end
end)

local function toggleRemoveHitbox(value)
    RemoveHitboxEnabled = value
    if RemoveHitboxEnabled then
        removeMonsterHitboxes()
    end
    Library:Notify({
        Title = "Anti Trap Monster",
        Description = value and "Enabled" or "Disabled",
        Time = 3
    })
end

--================================================================--
-- TELEPORT ELEVATOR SYSTEM 
--================================================================--
local function teleportToElevator()
    local targetPart = workspace["电梯"].Left4.Ground
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
end
--================================================================--
-- AUTO LOOT SYSTEM 
--================================================================--

local AutoPickEnabled = false
local AutoOpenEnabled = false
local AutoGearEnabled = false
local PickLoop
local OpenConnection
local GearLoop

local BLOCKED_ITEMS = {"Flashlight","Bandage","Box","Bloxy Cola","Hourglass","Revive Syringe","Baseball Bat","Teleporter","Z-Ray Gun","Double Barrel","Random Teleporter","Stun Grenade","Bat","Baseball","Molotov","Bio-Scanner","The Trap"}
local GEAR_ONLY = {"Flashlight","Bandage","Box","Bloxy Cola","Hourglass","Revive Syringe","Baseball Bat","Teleporter","Z-Ray Gun","Double Barrel","Random Teleporter","Stun Grenade","Bat","Baseball","Molotov","Bio-Scanner","The Trap"}

local BLOCKED_SET = {}
for _,v in ipairs(BLOCKED_ITEMS) do BLOCKED_SET[v:lower()] = true end

local GEAR_SET = {}
for _,v in ipairs(GEAR_ONLY) do GEAR_SET[v:lower()] = true end

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local function getGroundPart()
    local el = workspace:FindFirstChild("电梯")
    local l4 = el and el:FindFirstChild("Left4")
    return l4 and l4:FindFirstChild("Ground")
end

local function isNearGround(instance)
    local ground = getGroundPart()
    if not ground or not instance then return false end
    
    local targetPart = nil
    if instance:IsA("BasePart") then
        targetPart = instance
    elseif instance:IsA("Model") then
        targetPart = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    else
        targetPart = instance:FindFirstChildWhichIsA("BasePart", true)
    end
    
    if not targetPart then return false end
    
    local distance = (targetPart.Position - ground.Position).Magnitude
    return distance <= 15
end

local function isPlayerOnGround()
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return isNearGround(hrp)
end

local function shouldBlockInteraction(obj)
    if isPlayerOnGround() then return true end
    if isNearGround(obj) or obj:IsDescendantOf(workspace["电梯"].Left4.Ground) then return true end
    return false
end

local function fireInteract(obj, force)
    if TEvent and TEvent.FireRemote then
        TEvent.FireRemote("Interactable", obj, force == true)
    end
end

local function isBlocked(obj)
    if shouldBlockInteraction(obj) then return true end

    local lootUI = obj:FindFirstChild("LootUI", true)
    local itemName = if lootUI then lootUI:FindFirstChild("ItemName", true) else nil
    
    if itemName and itemName.Text then
        local nameLower = itemName.Text:lower()
        if BLOCKED_SET[nameLower] then return true end
        if string.find(nameLower, "recipe") or string.find(nameLower, "key") then
            return true
        end
    end
    
    return false
end

local function isGear(obj)
    if shouldBlockInteraction(obj) then return false end

    local lootUI = obj:FindFirstChild("LootUI", true)
    local itemName = if lootUI then lootUI:FindFirstChild("ItemName", true) else nil
    
    if itemName and itemName.Text then
        local nameLower = itemName.Text:lower()
        if GEAR_SET[nameLower] then return true end
        if string.find(nameLower, "recipe") or string.find(nameLower, "key") then
            return false
        end
    end
    
    return false
end

local function toggleAutoPick(state)
    AutoPickEnabled = state
    if PickLoop then task.cancel(PickLoop) PickLoop = nil end
    
    if state then
        PickLoop = task.spawn(function()
            while AutoPickEnabled do
                if LootsWorld then
                    for _, obj in ipairs(LootsWorld:GetDescendants()) do
                        if obj:HasTag("Interactable") and obj:GetAttribute("en") and not isBlocked(obj) then
                            fireInteract(obj, true)
                        end
                    end
                end
                task.wait(0.15)
            end
        end)
    end
end

local function toggleAutoOpen(state)
    AutoOpenEnabled = state
    if OpenConnection then OpenConnection:Disconnect() OpenConnection = nil end
    
    if state and InteractiveItem then
        for _, obj in ipairs(InteractiveItem:GetDescendants()) do
            if obj:HasTag("Interactable") then 
                task.defer(fireInteract, obj, true) 
            end
        end
        OpenConnection = InteractiveItem.DescendantAdded:Connect(function(obj)
            if obj:HasTag("Interactable") then 
                task.defer(fireInteract, obj, true) 
            end
        end)
    end
end

local function toggleAutoGear(state)
    AutoGearEnabled = state
    if GearLoop then task.cancel(GearLoop) GearLoop = nil end
    
    if state then
        GearLoop = task.spawn(function()
            while AutoGearEnabled do
                if LootsWorld then
                    for _, obj in ipairs(LootsWorld:GetDescendants()) do
                        if obj:HasTag("Interactable") and obj:GetAttribute("en") and isGear(obj) then
                            fireInteract(obj, true)
                        end
                    end
                end
                task.wait(0.15)
            end
        end)
    end
end



--================================================================--
-- AUTO FARM SYSTEM 
--================================================================--
local AutoLootTPEnabled = false
local FarmLoop = nil

local BLACKLIST = {
	["Flashlight"]=true,["Bandage"]=true,["Box"]=true,["Bloxy Cola"]=true,
	["Hourglass"]=true,["Revive Syringe"]=true,["Baseball Bat"]=true,
	["Teleporter"]=true,["Z-Ray Gun"]=true,["Double Barrel"]=true,
	["Random Teleporter"]=true,["Stun Grenade"]=true,["Bat"]=true,
	["Molotov"]=true,["The Trap"]=true,["Bio-Scanner"]=true,
	["Baseball"]=true
}

local LP = game.Players.LocalPlayer
local RunService = game:GetService("RunService")

local function getGroundPart()
	local el = workspace:FindFirstChild("电梯")
	local l4 = el and el:FindFirstChild("Left4")
	return l4 and l4:FindFirstChild("Ground")
end

local function isNearGround(part)
	local ground = getGroundPart()
	if not ground or not part then return false end
	return (part.Position - ground.Position).Magnitude <= 15
end

local function teleportToElevator()
	pcall(function()
		local ground = getGroundPart()
		local char = LP.Character or LP.CharacterAdded:Wait()
		if ground and char then
			char:PivotTo(ground.CFrame + Vector3.new(0, 3, 0))
		end
	end)
end

local function getValidLoot()
	local loot = {}
	local ground = getGroundPart()
	
	for _, obj in workspace.GameSystem.Loots.World:GetChildren() do
		local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
		if part then
			if ground and (part:IsDescendantOf(ground) or isNearGround(part)) then
				continue
			end
			
			local interact = obj:FindFirstChild("Folder", true) and obj.Folder:FindFirstChild("Interactable", true)
			local itemName = interact and interact:FindFirstChild("LootUI", true) 
				and interact.LootUI:FindFirstChild("Frame", true) 
				and interact.LootUI.Frame:FindFirstChild("ItemName")
				
			if itemName and not BLACKLIST[itemName.Text] then
				local nameLower = itemName.Text:lower()
				if not string.find(nameLower, "recipe") and not string.find(nameLower, "key") then
					table.insert(loot, part)
				end
			end
		end
	end
	return loot
end

local function startFarming()
	if FarmLoop then return end
	FarmLoop = task.spawn(function()
		while AutoLootTPEnabled do
			local lootList = getValidLoot()
			if #lootList == 0 then
				task.wait(1)
				continue
			end

			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.PlatformStand = true end

			for i = 1, math.min(4, #lootList) do
				if not AutoLootTPEnabled then break end
				local target = lootList[i]
				if target and target.Parent and LP.Character then
					local hrp = LP.Character.HumanoidRootPart
					local pos = target.Position + Vector3.new(0, 8, 0)
					hrp.CFrame = CFrame.new(pos, target.Position)
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
				end
				task.wait(0.1)
			end

			if hum then hum.PlatformStand = false end
			teleportToElevator()
			task.wait(1.5)
		end
		FarmLoop = nil
	end)
end

local function toggleAutoLootTP(state)
	AutoLootTPEnabled = state

	if not state then
		if FarmLoop then task.cancel(FarmLoop) FarmLoop = nil end
		pcall(function()
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.PlatformStand = false end
		end)
		return
	end

	RunService.Heartbeat:Connect(function()
		if not AutoLootTPEnabled then return end
		if #getValidLoot() > 0 and not FarmLoop then
			startFarming()
		end
	end)
end


--================================================================--
-- SPEED WALK
--================================================================--



local WALK_SPEED = 18
local WalkSpeedEnabled = false
local speedConnection

local function setSpeed(speed)
	if LP.Character then
		local hum = LP.Character:FindFirstChild("Humanoid")
		if hum then
			hum.WalkSpeed = speed
		end
	end
end

local function startSpeedLock()
	if speedConnection then speedConnection:Disconnect() end
	speedConnection = RunService.Heartbeat:Connect(function()
		if WalkSpeedEnabled then
			setSpeed(WALK_SPEED)
		end
	end)
end

LP.CharacterAdded:Connect(function()
	task.wait(0.2)
	if WalkSpeedEnabled then
		setSpeed(WALK_SPEED)
	end
end)


--================================================================--
-- AUTO RESCUE NPC SYSTEM 
--================================================================--



local NPC_FOLDER = workspace.GameSystem.NPCModels

local AutoInteractNPC = false

local function InteractNPC(obj)
    if obj:HasTag("Interactable") and obj:GetAttribute("en") then
        TEvent.FireRemote("Interactable", obj)
    end
end

NPC_FOLDER.DescendantAdded:Connect(function(obj)
    if AutoInteractNPC then
        task.defer(function()
            InteractNPC(obj)
        end)
    end
end)

local function InteractAllNPCs()
    if not AutoInteractNPC then return end
    for _, obj in NPC_FOLDER:GetDescendants() do
        task.defer(function()
            InteractNPC(obj)
        end)
    end
end

local function toggleAutoNPC(value)
    AutoInteractNPC = value
    if value then
        InteractAllNPCs()
    end
end








--================================================================--
-- GOD MOD SYSTEM 
--================================================================--
--[[

local latestArgs = nil
local running = false
local loopThread = nil

local oldFire
oldFire = hookfunction(remote.FireServer, function(self, ...)
    latestArgs = {...}
    return oldFire(self, ...)
end)

if not latestArgs then
    latestArgs = { "\146\12\147\195\199\2\147\203\192sl\218\0\0\0\0\203@tM\181\224\0\0\0\203@z-\240\160\0\0\0\203By\173\29P\151p\0" }
end

local function toggleLoop(state)
    running = state

    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end

    if state then
        loopThread = task.spawn(function()
            while running do
                task.wait(0.25)
                if latestArgs then
                    remote:FireServer(unpack(latestArgs))
                end
            end
        end)
    end
end


]]

--================================================================--
-- INFINITY STAMINA 
--================================================================--
local rns = game:GetService("RunService")
local staminaDisabled = false
local connections = {}

local function toggleInfinityStamina(state)
    staminaDisabled = state

    if staminaDisabled then
        for _, cnx in pairs(getconnections(rns.PreRender)) do
            local src = debug.info(cnx.Function, "s")
            if src:find("Stamina") then
                cnx:Disable()
                table.insert(connections, cnx)
            end
        end
    else
        for _, cnx in pairs(connections) do
            pcall(function() cnx:Enable() end)
        end
        connections = {}
    end
end


--================================================================--
-- GUI: CREATE WINDOW
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "Deadly Delivery",
    Icon = 94858886314945,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

--================================================================--
-- INFO TAB
--================================================================--
local InfoTab = Window:AddTab("Info", "info")
local InfoLeft = InfoTab:AddLeftGroupbox("Credits")
local InfoRight = InfoTab:AddRightGroupbox("Discord")

InfoLeft:AddLabel("Made By: Pkgx1")
InfoLeft:AddLabel("Discord: https://discord.gg/n9gtmefsjc")
InfoLeft:AddDivider()
InfoLeft:AddLabel("You Can Request Script")
InfoLeft:AddLabel("On Discord!")
InfoLeft:AddDivider()

InfoLeft:AddLabel("Discord Link")
InfoLeft:AddButton({
    Text = "Copy",
    Func = function()
        setclipboard("https://discord.gg/n9gtmefsjc")
        Library:Notify({Title = "Copied!", Description = "Paste it on your browser", Time = 4})
    end,
})


InfoRight:AddLabel("MOBILE USER")
InfoRight:AddLabel("To Close The Menu")
InfoRight:AddLabel("Simply Click the Icon")
InfoRight:AddLabel()
InfoRight:AddLabel("PC USER")
InfoRight:AddLabel("To Close the Menu")
InfoRight:AddLabel("Just Press The CTRL")
InfoRight:AddLabel()
--================================================================--
-- MAIN TAB
--================================================================--
local MainTab = Window:AddTab("Main", "house")
local AutoLeft = MainTab:AddLeftGroupbox("AUTOMATION", "cpu")
local PlayerLeft = MainTab:AddLeftGroupbox("PLAYER", "user")
local TeleportRight = MainTab:AddRightGroupbox("TELEPORT", "refresh-ccw")
local ESPRight = MainTab:AddRightGroupbox("ESP", "eye")

--================================================================--
-- AUTOMATION 
--================================================================--


AutoLeft:AddToggle("AutoLootTP",{
	Text = "Auto Farm (Risky)",
	Default = false,
	Callback = toggleAutoLootTP
})

AutoLeft:AddToggle("AutoOpenItems",{
	Text = "Auto Open (Crate + More)",
	Default = false,
	Callback = toggleAutoOpen
})

AutoLeft:AddToggle("AutoPickItem",{
	Text = "Auto Loot (Item)",
	Default = false,
	Callback = toggleAutoPick
})

AutoLeft:AddToggle("AutoPickGear",{
	Text = "Auto Loot (Gear)",
	Default = false,
	Callback = toggleAutoGear
})

AutoLeft:AddToggle("AutoInteractNPC", {
    Text = "Auto Rescue (NPC)",
    Default = false,
    Callback = toggleAutoNPC
})




--================================================================--
-- PLAYER
--================================================================--

--[[
PlayerLeft:AddToggle("GodModeToggle", {
    Text = "Always (SafeZone)",
    Default = false,
    Callback = toggleLoop
})
]]

PlayerLeft:AddToggle("RemoveMonsterHitbox", {
    Text = "Anti Trap (Monster)",
    Default = false,
    Callback = toggleRemoveHitbox
})

PlayerLeft:AddToggle("InfinityStamina", {
    Text = "Infinity Stamina",
    Default = false,
    Callback = toggleInfinityStamina
})

PlayerLeft:AddToggle("WalkSpeedToggle", {
	Text = "Walk Speed",
	Default = false,
	Callback = function(Value)
		WalkSpeedEnabled = Value
		if WalkSpeedEnabled then
			startSpeedLock()
			setSpeed(WALK_SPEED)
		else
			setSpeed(18)
		end
	end,
})

PlayerLeft:AddSlider("WalkSpeedSlider", {
	Text = "Value",
	Default = 18,
	Min = 12,
	Max = 100,
	Rounding = 1,
	Callback = function(Value)
		WALK_SPEED = Value
		if WalkSpeedEnabled then
			setSpeed(WALK_SPEED)
		end
	end,
})




--================================================================--
-- TELEPORT 
--================================================================--
TeleportRight:AddButton({
    Text = "TP Elevator",
    Func = function()
        teleportToElevator()
    end,
})
--================================================================--
-- ESP
--================================================================--

ESPRight:AddToggle("Crate_ESP", {
    Text = "Crate ESP",
    Default = false,
    Callback = function(v) toggleESP("Crate", v) end
})

ESPRight:AddToggle("Cabinet_ESP", {
    Text = "Cabinet ESP",
    Default = false,
    Callback = function(v) toggleESP("Cabinet", v) end
})

ESPRight:AddToggle("OilBucket_ESP", {
    Text = "Oil Bucket ESP",
    Default = false,
    Callback = function(v) toggleESP("OilBucket", v) end
})

ESPRight:AddToggle("Loot_ESP", {
    Text = "Loot ESP",
    Default = false,
    Callback = function(v) toggleESP("Loot", v) end
})

ESPRight:AddToggle("Monster_ESP", {
    Text = "Monster ESP",
    Default = false,
    Callback = function(v) toggleESP("Monster", v) end
})

ESPRight:AddToggle("Player_ESP", {
    Text = "Player ESP",
    Default = false,
    Callback = function(v) toggleESP("Player", v) end
})

ESPRight:AddToggle("NPC_ESP", {
    Text = "NPC ESP",
    Default = false,
    Callback = function(v) toggleESP("NPC", v) end
})

--================================================================--
-- SETTINGS TAB
--================================================================--
local SettingsTab = Window:AddTab("Settings", "cog")
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("Vgxmod")
SaveManager:SetFolder("Vgxmod")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
SaveManager:LoadAutoloadConfig()
