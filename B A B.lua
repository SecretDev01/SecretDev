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
-- AUTO FARM SYSTEM 
--================================================================--
local stages = {
    Vector3.new(-44.9613, 56.8942, 1124.1836),
    Vector3.new(-39.5883, 98.1583, 1883.2020),
    Vector3.new(-34.8094, 104.3719, 2561.3865),
    Vector3.new(-37.5433, 124.8919, 3464.9512),
    Vector3.new(-35.1518, 111.0665, 4219.6265),
    Vector3.new(-21.2759, 98.0882, 4928.8818),
    Vector3.new(-38.4606, 82.4065, 5784.1480),
    Vector3.new(-37.1649, 91.0599, 6477.4680),
    Vector3.new(-54.7392, 97.8948, 7289.2622),
    Vector3.new(-48.1038, 93.1693, 7983.5054)
}

local finishPos = Vector3.new(-55.29559326171875, -360.4061584472656, 9488.623046875)
local teleportEnabled = false

local function createPlatform(character, pos)
    local humanoid = character:WaitForChild("Humanoid")
    local platform = Instance.new("Part")
    platform.Size = Vector3.new(6,1,6)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    platform.Parent = Workspace
    local platformY = pos.Y - (humanoid.HipHeight + 2.5)
    platform.CFrame = CFrame.new(pos.X, platformY, pos.Z)
    return platform
end

local function tpStages(character)
    local hrp = character:WaitForChild("HumanoidRootPart")
    local previousPlatform
    for _, pos in ipairs(stages) do
        if not teleportEnabled then break end
        if previousPlatform then previousPlatform:Destroy() end
        previousPlatform = createPlatform(character, pos)
        hrp.CFrame = CFrame.new(pos)
        wait(2)
    end
    if teleportEnabled then
        if previousPlatform then previousPlatform:Destroy() end
        local finalPlat = createPlatform(character, finishPos)
        hrp.CFrame = CFrame.new(finishPos)
        wait(2)
        finalPlat:Destroy()
    end
end

local function startTeleport()
    spawn(function()
        if LP.Character then
            tpStages(LP.Character)
        end
    end)
end

LP.CharacterAdded:Connect(function(char)
    wait(1)
    if teleportEnabled then
        startTeleport()
    end
end)
--================================================================--
-- AUTO BUY 
--================================================================--

local chestEnabled = false
local chestType = "Common Chest"
local chestAmount = 1
local chestLoop

local function invokeChest(typeName, amount)
    local Event = workspace:WaitForChild("ItemBoughtFromShop")
    pcall(function()
        local Result = Event:InvokeServer(typeName, amount)
        local ExpectedResult = table.unpack({true})
        return Result == ExpectedResult
    end)
end

local function startAutoChest()
    if chestLoop then return end
    chestLoop = spawn(function()
        while chestEnabled do
            if chestType and chestAmount then
                invokeChest(chestType, chestAmount)
            end
            wait(1)
        end
        chestLoop = nil
    end)
end

local function toggleAutoChest(state)
    chestEnabled = state
    if chestEnabled then
        startAutoChest()
    end
end

local function setChestType(Value)
    chestType = Value
end

local function setChestAmount(Value)
    local max = 15
    local amount = tonumber(Value)
    if amount then
        if amount > max then amount = max end
        if amount < 1 then amount = 1 end
        chestAmount = amount
        Library:Notify({ Title = "Chest Amount", Description = "Set to " .. tostring(amount), Time = 2 })
    end
end
--================================================================--
-- GUI: CREATE WINDOW
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "Build A Boat",
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
local AutoRight = MainTab:AddRightGroupbox("SHOP", "shopping-cart")
--================================================================--
-- AUTOMATION 
--================================================================--
AutoLeft:AddToggle("StageTpToggle", {
    Text = "Auto Farm",
    Default = false,
    Callback = function(state)
        teleportEnabled = state
        if teleportEnabled then
            startTeleport()
        end
    end
})

--================================================================--
-- SHOP
--================================================================--


AutoRight:AddToggle("AutoChestToggle", {
    Text = "Auto Open Chest",
    Default = false,
    Callback = toggleAutoChest
})

AutoRight:AddDropdown("ChestTypeDropdown", {
    Values = { "Common Chest", "Uncommon Chest", "Rare Chest", "Epic Chest", "Legendary Chest" },
    Default = 1,
    Multi = false,
    Text = "Chest Type",
    Searchable = false,
    Callback = setChestType
})

AutoRight:AddInput("ChestAmountInput", {
    Default = "1",
    Numeric = true,
    ClearTextOnFocus = true,
    Text = "Amount",
    Placeholder = "Enter number of chests",
    Callback = setChestAmount
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
