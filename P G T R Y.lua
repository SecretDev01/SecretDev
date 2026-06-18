--================================================================--
--                            VGXMOD HUB
--================================================================--

print("------------------------------------------------------------------")
print("Load ................................ Armor V3")
print("Load ................................ Vgxmod Hub")
print("------------------------------------------------------------------")

--================================================================--
-- LOAD LIBRARY (Vgxmod UI) - DO NOT CHANGE
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
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

--================================================================--
-- KILL AURA CONFIG
--================================================================--
local KillAura = {
    Enabled = false,
    MaxDistance = 30,
    AttackSpeed = 0.01,
    Debug = false,
    EnemyFolder = Workspace.Enemies
}

local KillAuraTask = nil

--================================================================--
-- GOD MODE CONFIG
--================================================================--
local GodMode = {
    Enabled = false,
    Debug = false
}

local GodModeHook = nil

--================================================================--
-- GOD MODE REMOTE (SAFE LOAD - NO ERROR)
--================================================================--
local PlrDamaged = nil

task.spawn(function()
    local success, OnServerEvents = pcall(function()
        return ReplicatedStorage:WaitForChild("OnServerEvents", 10)
    end)
    if success and OnServerEvents then
        local success2, remote = pcall(function()
            return OnServerEvents:WaitForChild("PlrDamaged", 10)
        end)
        if success2 then
            PlrDamaged = remote
        end
    end
    if not PlrDamaged then
        warn("[GOD MODE] PlrDamaged not found. God Mode disabled.")
    end
end)

--================================================================--
-- AUTO TOOL DETECTION (ANY TOOL)
--================================================================--
local function getEquippedTool()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Tool")
end

local function getAttackRemote()
    local tool = getEquippedTool()
    if tool then
        local remote = tool:FindFirstChildWhichIsA("RemoteEvent")
        if remote then return remote end
        remote = tool:FindFirstChild("DamageRemote") or 
                 tool:FindFirstChild("Fire") or 
                 tool:FindFirstChild("Swing") or
                 tool:FindFirstChild("Slash")
        if remote and remote:IsA("RemoteEvent") then return remote end
    end
    local combat = ReplicatedStorage:FindFirstChild("OnServerEvents")
    if combat then
        return combat:FindFirstChild("CombatServer")
    end
    return nil
end

--================================================================--
-- KILL AURA SYSTEM
--================================================================--
local function kaDebug(...)
    if KillAura.Debug then
        warn("[KILL AURA]", ...)
    end
end

local function getRoot()
    local char = LP.Character or LP.CharacterAdded:Wait()
    return char:FindFirstChild("HumanoidRootPart")
end

local function findClosestEnemy()
    local root = getRoot()
    if not root then return end

    local closest, best = nil, KillAura.MaxDistance
    for _, enemy in ipairs(KillAura.EnemyFolder:GetChildren()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        local hum = enemy:FindFirstChild("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - root.Position).Magnitude
            if dist < best then
                best = dist
                closest = enemy
            end
        end
    end
    return closest
end

local function attackEnemy(enemy)
    if not enemy then return end
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local remote = getAttackRemote()
    if not remote or not remote:IsA("RemoteEvent") then
        kaDebug("No remote found")
        return
    end

    local root = getRoot()
    local distance = (hrp.Position - root.Position).Magnitude

    local tool = getEquippedTool()
    if tool then
        local hum = enemy:FindFirstChild("Humanoid")
        if hum then
            remote:FireServer(hum)
        else
            remote:FireServer(hrp)
        end
    else
        pcall(function()
            remote:FireServer("Melee")
            remote:FireServer(hrp, "Melee", { dismantle = false, riposte = false, backstab = false })
            remote:FireServer({ enemy }, "Melee", { riposte = false, cyclone = false })
        end)
    end

    kaDebug("Attacked", enemy.Name, "@", math.floor(distance), "studs")
end

local function startKillAura()
    if KillAuraTask then return end
    KillAuraTask = task.spawn(function()
        while KillAura.Enabled do
            if not LP.Character or not getRoot() then
                task.wait()
                continue
            end
            local target = findClosestEnemy()
            if target then
                attackEnemy(target)
            end
            task.wait(KillAura.AttackSpeed)
        end
    end)
end

local function stopKillAura()
    if KillAuraTask then
        task.cancel(KillAuraTask)
        KillAuraTask = nil
    end
end

--================================================================--
-- GOD MODE SYSTEM
--================================================================--
local function gmDebug(...)
    if GodMode.Debug then
        warn("[GOD MODE]", ...)
    end
end

local function enableGodMode()
    if GodModeHook or not PlrDamaged then return end

    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if GodMode.Enabled and method == "FireServer" and self == PlrDamaged then
            gmDebug("No damage")
            return
        end
        return old(self, ...)
    end)

    setreadonly(mt, true)
    GodModeHook = true
    gmDebug("God Mode ON")
end

local function disableGodMode()
    GodMode.Enabled = false
    gmDebug("God Mode OFF")
end

LP.CharacterAdded:Connect(function(char)
    if GodMode.Enabled then
        task.wait(0.5)
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.Health = hum.MaxHealth
            gmDebug("Health restored")
        end
    end
end)

--================================================================--
-- GUI - LAYOUT
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "v2.1 | PH",
    Icon = 94858886314945,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local InfoTab     = Window:AddTab("Info", "info")
local MainTab     = Window:AddTab("Main", "house")
local SettingsTab = Window:AddTab("Settings", "cog")

--================================================================--
-- INFO TAB
--================================================================--
local InfoLeft  = InfoTab:AddLeftGroupbox("Credits")
local InfoRight = InfoTab:AddRightGroupbox("Discord")

InfoLeft:AddLabel("Made By: Pkgx1")
InfoLeft:AddLabel("PH Server Ready")
InfoLeft:AddDivider()
InfoLeft:AddLabel("Kill Aura: Any Tool")
InfoLeft:AddLabel("God Mode: Full Protection")

InfoRight:AddLabel("Discord Link")
InfoRight:AddButton({
    Text = "Copy",
    Func = function()
        setclipboard("https://discord.gg/n9gtmefsjc")
        Library:Notify({Title = "Copied!", Description = "Join Discord!", Time = 4})
    end
})

--================================================================--
-- MAIN TAB - COMBAT LEFT | PLAYER RIGHT
--================================================================--
local CombatLeft  = MainTab:AddLeftGroupbox("Combat", "zap")
local PlayerRight = MainTab:AddRightGroupbox("Player", "shield")

--================================================================--
-- COMBAT: KILL AURA (ALL TOOLS)
--================================================================--
CombatLeft:AddToggle("KillAuraToggle", {
    Text = "Kill Aura (Any Tool)",
    Default = false,
    Callback = function(state)
        KillAura.Enabled = state
        if state then
            startKillAura()
            Library:Notify({Title = "Kill Aura", Description = "ON", Time = 2})
        else
            stopKillAura()
            Library:Notify({Title = "Kill Aura", Description = "OFF", Time = 2})
        end
    end,
})

CombatLeft:AddSlider("KillAuraDistance", {
    Text = "Max Distance",
    Default = 30,
    Min = 1,
    Max = 100,
    Rounding = 1,
    Callback = function(v) KillAura.MaxDistance = v end,
})

CombatLeft:AddSlider("KillAuraSpeed", {
    Text = "Attack Speed (sec)",
    Default = 0.01,
    Min = 0.001,
    Max = 0.5,
    Rounding = 3,
    Callback = function(v) KillAura.AttackSpeed = v end,
})

CombatLeft:AddCheckbox("KillAuraDebug", {
    Text = "Enable Debug Logs",
    Default = false,
    Callback = function(v) KillAura.Debug = v end,
})

--================================================================--
-- PLAYER: GOD MODE
--================================================================--
PlayerRight:AddToggle("GodModeToggle", {
    Text = "God Mode (PATCH)",
    Default = false,
    Callback = function(state)
        GodMode.Enabled = state
        if state then
            enableGodMode()
            Library:Notify({Title = "God Mode", Description = "ON", Time = 2})
        else
            disableGodMode()
            Library:Notify({Title = "God Mode", Description = "OFF", Time = 2})
        end
    end,
})

PlayerRight:AddCheckbox("GodModeDebug", {
    Text = "Enable Debug Logs",
    Default = false,
    Callback = function(v) GodMode.Debug = v end,
})

--================================================================--
-- SETTINGS TAB
--================================================================--
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("Vgxmod")
SaveManager:SetFolder("Vgxmod")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
SaveManager:LoadAutoloadConfig()
