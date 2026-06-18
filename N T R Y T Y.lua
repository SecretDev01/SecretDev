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
local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local LP            = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--================================================================--
-- AUTOMATION & PLAYER LOOPS
--================================================================--
local MobMagnetConnection
local config = { Distance = -7, Height = 0.7 }

-- Infinite Stats Loop Execution
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local criminals = Workspace:FindFirstChild("Criminals")
            local p = criminals and criminals:FindFirstChild(LP.Name)
            if not p then return end

            -- Infinite Ammo & Equipment
            if Toggles.UnliAmmo and Toggles.UnliAmmo.Value then
                if p:FindFirstChild("PrimaryAmmo") then p.PrimaryAmmo.Value = 9999 end
                if p:FindFirstChild("PrimaryAmmoMax") then p.PrimaryAmmoMax.Value = 9999 end
                if p:FindFirstChild("SecondaryAmmo") then p.SecondaryAmmo.Value = 9999 end
                if p:FindFirstChild("SecondaryAmmoMax") then p.SecondaryAmmoMax.Value = 9999 end
                if p:FindFirstChild("GadgetAmmo") then p.GadgetAmmo.Value = 9999 end
                if p:FindFirstChild("GadgetAmmoMax") then
                    local g = p.GadgetAmmoMax
                    if g:FindFirstChild("Capacity") then g.Capacity.Value = 9999 end
                    if g:FindFirstChild("MagCapacity") then g.MagCapacity.Value = 9999 end
                    if g:FindFirstChild("Pickup") then g.Pickup.Value = 9999 end
                    if g:FindFirstChild("PickupRand") then g.PickupRand.Value = 9999 end
                end
                if p:FindFirstChild("Throwables") then p.Throwables.Value = 9999 end
            end

            -- Infinite Health & Armor
            if Toggles.UnliHealth and Toggles.UnliHealth.Value then
                if p:FindFirstChild("Health") then
                    p.Health.Value = 9999
                    if p.Health:FindFirstChild("Total") then p.Health.Total.Value = 9999 end
                    if p.Health:FindFirstChild("BleedoutHP") then p.Health.BleedoutHP.Value = 9999 end
                end
                if p:FindFirstChild("Messiah") then p.Messiah.Value = 9999 end
            end

            if Toggles.UnliArmor and Toggles.UnliArmor.Value then
                if p:FindFirstChild("Armor") then
                    p.Armor.Value = 9999
                    if p.Armor:FindFirstChild("Total") then p.Armor.Total.Value = 9999 end
                end
            end

            -- Infinite Stamina
            if Toggles.UnliStamina and Toggles.UnliStamina.Value then
                if p:FindFirstChild("Stamina") then p.Stamina.Value = 9999 end
                if p:FindFirstChild("MaxStamina") then p.MaxStamina.Value = 9999 end
            end

            -- Miscellaneous Utilities
            if Toggles.UnliUtilities and Toggles.UnliUtilities.Value then
                if p:FindFirstChild("CableTies") then p.CableTies.Value = 9999 end
                if p:FindFirstChild("BodyBags") then p.BodyBags.Value = 9999 end
                if p:FindFirstChild("Crit") then p.Crit.Value = 9999 end
            end
        end)
    end
end)

-- Standalone Mob Magnet function
local function toggleMobMagnet(state)
    if MobMagnetConnection then
        MobMagnetConnection:Disconnect()
        MobMagnetConnection = nil
    end

    if state then
        local policeFolder = Workspace:FindFirstChild("Police")
        if policeFolder then
            MobMagnetConnection = RunService.Heartbeat:Connect(function()
                local character = LP.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                
                if rootPart then
                    local targetCFrame = rootPart.CFrame * CFrame.new(0, config.Height, config.Distance)
                    
                    for _, mob in pairs(policeFolder:GetChildren()) do
                        local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Head") or mob.PrimaryPart
                        
                        if mobRoot and mobRoot:IsA("BasePart") then
                            mobRoot.CFrame = targetCFrame
                            mobRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            mobRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end)
        end
    end
end

--================================================================--
-- ESP CONFIGURATION & UTILITIES
--================================================================--
local MAX_DISTANCE = 2000               
local FONT_ASSET   = "rbxassetid://12187362578" 

local FOLDERS = {
	Police = {Instance = Workspace:FindFirstChild("Police"),    Color = Color3.fromRGB(0, 0, 255),   Name = "Police", ToggleKey = "EspPolice"},
	Criminals = {Instance = Workspace:FindFirstChild("Criminals"), Color = Color3.fromRGB(255, 255, 255), Name = "Criminal", ToggleKey = "EspCriminal"},
	Citizens = {Instance = Workspace:FindFirstChild("Citizens"),  Color = Color3.fromRGB(0, 255, 0),   Name = "Citizen", ToggleKey = "EspCivilian"}
}

local trackedEntities = {}
local EspConnection

local function addHighlight(char, col)
	if not char then return end
	local hl = char:FindFirstChild("FOLDER_ESP_HL") or Instance.new("Highlight", char)
	hl.Name = "FOLDER_ESP_HL"
	hl.Adornee = char
	hl.FillColor = col
	hl.OutlineColor = Color3.new(255, 255, 255)
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function addBillboard(char, text, col)
	if not char then return end
	local head = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
	if not head then return end

	local bg = head:FindFirstChild("FOLDER_ESP_BILLBOARD") or Instance.new("BillboardGui", head)
	bg.Name = "FOLDER_ESP_BILLBOARD"
	bg.Adornee = head
	bg.Size = UDim2.new(0, 250, 0, 60)
	bg.StudsOffset = Vector3.new(0, 3.5, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = MAX_DISTANCE
	bg.LightInfluence = 0

	local label = bg:FindFirstChild("Label") or Instance.new("TextLabel", bg)
	label.Name = "Label"
	label.Size = UDim2.new(1,0,1,0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1,1,1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0,0,0)
	
	label.FontFace = Font.new(FONT_ASSET, Enum.FontWeight.Bold)
	label.TextSize = 13
	label.RichText = true
end

local function removeESP(char)
	if not char then return end
	if char:FindFirstChild("FOLDER_ESP_HL") then char.FOLDER_ESP_HL:Destroy() end
	if char:FindFirstChild("Head") and char.Head:FindFirstChild("FOLDER_ESP_BILLBOARD") then
		char.Head.FOLDER_ESP_BILLBOARD:Destroy()
	elseif char:FindFirstChildWhichIsA("BasePart") and char:FindFirstChildWhichIsA("BasePart"):FindFirstChild("FOLDER_ESP_BILLBOARD") then
		char:FindFirstChildWhichIsA("BasePart").FOLDER_ESP_BILLBOARD:Destroy()
	end
end

local function startEspLoop()
    if EspConnection then return end
    
    EspConnection = RunService.Heartbeat:Connect(function()
        if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
        local myPos = LP.Character.HumanoidRootPart.Position

        local currentFrameEntities = {}

        for folderKey, folderData in pairs(FOLDERS) do
            local toggle = Toggles[folderData.ToggleKey]
            if toggle and toggle.Value then
                local folder = folderData.Instance
                if folder then
                    for _, entity in ipairs(folder:GetChildren()) do
                        if entity:IsA("Model") and entity ~= LP.Character then
                            local hrp = entity:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                currentFrameEntities[entity] = true
                                
                                local dist = math.floor((hrp.Position - myPos).Magnitude)
                                
                                local entityName = entity.Name
                                local plr = Players:GetPlayerFromCharacter(entity)
                                if plr then
                                    entityName = plr.DisplayName
                                end

                                local text = string.format(
                                    "%s\n<font color='rgb(200,200,200)'>[%dm]</font> <font color='rgb(%d,%d,%d)'>[%s]</font>",
                                    entityName, dist, folderData.Color.R * 255, folderData.Color.G * 255, folderData.Color.B * 255, folderData.Name
                                )

                                addHighlight(entity, folderData.Color)
                                addBillboard(entity, text, folderData.Color)
                            end
                        end
                    end
                end
            end
        end

        for oldEntity, _ in pairs(trackedEntities) do
            if not currentFrameEntities[oldEntity] then
                removeESP(oldEntity)
            end
        end
        trackedEntities = currentFrameEntities
    end)
end

local function updateEspState()
    local policeOn = Toggles.EspPolice and Toggles.EspPolice.Value
    local criminalOn = Toggles.EspCriminal and Toggles.EspCriminal.Value
    local civilianOn = Toggles.EspCivilian and Toggles.EspCivilian.Value

    if policeOn or criminalOn or civilianOn then
        startEspLoop()
    else
        if EspConnection then
            EspConnection:Disconnect()
            EspConnection = nil
        end
        for oldEntity, _ in pairs(trackedEntities) do
            removeESP(oldEntity)
        end
        trackedEntities = {}
    end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

getgenv().TeleportConnection = getgenv().TeleportConnection or nil
getgenv().CharacterAddedConnection = getgenv().CharacterAddedConnection or nil

local function checkAndTeleport(character)
    local isDowned = character:GetAttribute("Downed")
    
    if isDowned then
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        local criminalsFolder = workspace:FindFirstChild("Criminals")
        
        if myRoot and criminalsFolder then
            local closestTeammate = nil
            local shortestDistance = math.huge
            
            for _, teammate in ipairs(criminalsFolder:GetChildren()) do
                if teammate:IsA("Model") and teammate ~= character and not teammate:GetAttribute("Downed") then
                    local teamRoot = teammate:FindFirstChild("HumanoidRootPart")
                    local teamHumanoid = teammate:FindFirstChild("Humanoid")
                    
                    if teamRoot and teamHumanoid and teamHumanoid.Health > 0 then
                        local distance = (myRoot.Position - teamRoot.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestTeammate = teamRoot
                        end
                    end
                end
            end
            
            if closestTeammate then
                myRoot.CFrame = closestTeammate.CFrame + Vector3.new(0, 2, 0)
            end
        end
    end
end

local function setupCharacter(character)
    if not character then return end
    
    if getgenv().TeleportConnection then
        getgenv().TeleportConnection:Disconnect()
    end
    
    getgenv().TeleportConnection = character:GetAttributeChangedSignal("Downed"):Connect(function()
        checkAndTeleport(character)
    end)
end



--================================================================--
-- GUI: CREATE WINDOW
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "Notoriety",
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
local EspLeft = MainTab:AddRightGroupbox("ESP", "eye")
--[[
local TpLeft = MainTab:AddRightGroupbox("TELEPORT", "teleport") 
]]

--================================================================--
-- TOGGLES INTERFACE
--================================================================--
AutoLeft:AddToggle("MobMagnetToggle", {
    Text = "Auto Bring Mobs",
    Default = false,
    Callback = function(state)
        toggleMobMagnet(state)
    end
})

AutoLeft:AddToggle("MobMagnetToggle", {
    Text = "Auto Tp (down)",
    Default = false,
    Callback = function(state)
        if state then
            if LocalPlayer.Character then
                setupCharacter(LocalPlayer.Character)
            end
            
            if getgenv().CharacterAddedConnection then
                getgenv().CharacterAddedConnection:Disconnect()
            end
            getgenv().CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(setupCharacter)
        else
            if getgenv().TeleportConnection then
                getgenv().TeleportConnection:Disconnect()
                getgenv().TeleportConnection = nil
            end
            if getgenv().CharacterAddedConnection then
                getgenv().CharacterAddedConnection:Disconnect()
                getgenv().CharacterAddedConnection = nil
            end
        end
    end
})

-- PLAYER STATS
PlayerLeft:AddToggle("UnliHealth", { Text = "Infinite Health", Default = false })
PlayerLeft:AddToggle("UnliArmor", { Text = "Infinite Armor", Default = false })
PlayerLeft:AddToggle("UnliAmmo", { Text = "Infinite Ammo & Throwables", Default = false })
PlayerLeft:AddToggle("UnliStamina", { Text = "Infinite Stamina", Default = false })
PlayerLeft:AddToggle("UnliUtilities", { Text = "Infinite Ties/Bags/Crits", Default = false })

-- ESP TOGGLES
EspLeft:AddToggle("EspPolice", {
    Text = "Esp police",
    Default = false,
    Callback = function()
        updateEspState()
    end
})

EspLeft:AddToggle("EspCivilian", {
    Text = "Esp civilian",
    Default = false,
    Callback = function()
        updateEspState()
    end
})

EspLeft:AddToggle("EspCriminal", {
    Text = "Esp criminal",
    Default = false,
    Callback = function()
        updateEspState()
    end
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
