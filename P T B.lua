--================================================================--
--                    VGXMOD HUB 
--        
--================================================================--

print("------------------------------------------------------------------")
print("Load ................................ Vgxmod Hub (Reworked)")
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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

--================================================================--
-- CONFIGURATION / STATE
--================================================================--
local currentHitboxSize = 5
local hitboxConnections = {}
local savedPositions = {}

local espConnections = {}
local tracerConnections = {}

--================================================================--
-- UTIL: Safe accessors
--================================================================--
local function safeGetPlayerGui()
    return LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
end

--================================================================--
-- HITBOX: resize / deactivate helpers (operate on CollisionPart)
--================================================================--
local function resizeCollisionPart(playerName)
    if playerName == LocalPlayer.Name then return end
    local playerModel = Workspace:FindFirstChild(playerName)
    if not playerModel then return end
    local collisionPart = playerModel:FindFirstChild("CollisionPart")
    if collisionPart and collisionPart:IsA("BasePart") then
        collisionPart.Size = Vector3.new(currentHitboxSize, currentHitboxSize, currentHitboxSize)
        collisionPart.Color = Color3.fromRGB(0, 0, 0)
        collisionPart.Transparency = 0.9
        collisionPart.CanCollide = true
    end
end

local function deactivateCollisionPart(playerName)
    if playerName == LocalPlayer.Name then return end
    local playerModel = Workspace:FindFirstChild(playerName)
    if not playerModel then return end
    local collisionPart = playerModel:FindFirstChild("CollisionPart")
    if collisionPart and collisionPart:IsA("BasePart") then
        collisionPart.Transparency = 1
        collisionPart.CanCollide = false
    end
end

-- Monitors all players each Heartbeat with a connection per player (keeps current behavior)
local function monitorPlayers()
    -- disconnect old connections if any
    for _, c in ipairs(hitboxConnections) do
        pcall(function() c:Disconnect() end)
    end
    hitboxConnections = {}

    for _, player in pairs(Players:GetPlayers()) do
        local con = RunService.Heartbeat:Connect(function()
            if Options.HitboxToggle and Options.HitboxToggle.Value then
                resizeCollisionPart(player.Name)
            else
                deactivateCollisionPart(player.Name)
            end
        end)
        table.insert(hitboxConnections, con)
    end

    local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        local con = RunService.Heartbeat:Connect(function()
            if Options.HitboxToggle and Options.HitboxToggle.Value then
                resizeCollisionPart(player.Name)
            else
                deactivateCollisionPart(player.Name)
            end
        end)
        table.insert(hitboxConnections, con)
    end)

    table.insert(hitboxConnections, playerAddedConnection)
end

--================================================================--
-- HITBOX UI (movable on-screen buttons)
--================================================================--
local function createHitboxUI()
    local guip = safeGetPlayerGui()
    if guip:FindFirstChild("HitboxGui") then
        guip.HitboxGui:Destroy()
    end

    local ui = Instance.new("ScreenGui")
    ui.Name = "HitboxGui"
    ui.ResetOnSpawn = false
    ui.Parent = guip

    local function createButton(id, text, pos, onClick)
        local btn = Instance.new("TextButton")
        btn.Name = id
        btn.Size = UDim2.new(0, 80, 0, 80)
        btn.Position = savedPositions[id] or pos
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.BackgroundColor3 = Color3.new(0, 0, 0)
        btn.BackgroundTransparency = 0.5
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBlack
        btn.TextSize = 12
        btn.TextWrapped = true
        btn.AutoButtonColor = false
        btn.Draggable = true
        btn.Parent = ui

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(1, 0)

        local border = Instance.new("UIStroke", btn)
        border.Thickness = 2
        border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- color-cycle stroke
        local hue = 0
        local rsCon
        rsCon = RunService.RenderStepped:Connect(function(dt)
            if not btn or not btn.Parent then
                if rsCon then pcall(function() rsCon:Disconnect() end) end
                return
            end
            hue = (hue + dt * 0.1) % 1
            border.Color = Color3.fromHSV(hue, 1, 1)
        end)

        btn.MouseButton1Click:Connect(onClick)
        btn:GetPropertyChangedSignal("Position"):Connect(function()
            savedPositions[id] = btn.Position
        end)
    end

createButton("Hitbox1", "Hitbox 1", UDim2.new(0.5, -60, 0.5, 0), function() currentHitboxSize = 1 end)
createButton("Hitbox8", "Hitbox 8", UDim2.new(0.5, 60, 0.5, 0), function() currentHitboxSize = 8 end)
end

--================================================================--
-- ESP (BOMB) helpers
--================================================================--
local function createESP(part, text)
    if not part then return end
    if part:FindFirstChild("ESP_Label") then
        part.ESP_Label:Destroy()
    end

    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_Label"
    gui.Adornee = part
    gui.Size = UDim2.new(0, 100, 0, 40)
    gui.AlwaysOnTop = true
    gui.Parent = part

    local label = Instance.new("TextLabel", gui)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 25
end

local function destroyESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        local model = Workspace:FindFirstChild(plr.Name)
        if model then
            local bomb = model:FindFirstChild("Bomb")
            local hitbox = bomb and bomb:FindFirstChild("Hitbox")
            if hitbox and hitbox:FindFirstChild("ESP_Label") then
                hitbox.ESP_Label:Destroy()
            end
        end
    end
end

local function updateESP()
    -- clear previous connections
    for _, c in ipairs(espConnections) do
        pcall(function() c:Disconnect() end)
    end
    espConnections = {}

    for _, player in pairs(Players:GetPlayers()) do
        local con = RunService.Heartbeat:Connect(function()
            if not Options.ESPNameToggle or not Options.ESPNameToggle.Value then return end
            local model = Workspace:FindFirstChild(player.Name)
            if not model then return end
            local bomb = model:FindFirstChild("Bomb")
            local hitbox = bomb and bomb:FindFirstChild("Hitbox")
            if hitbox then
                if not hitbox:FindFirstChild("ESP_Label") then
                    createESP(hitbox, "BOMB")
                else
                    local label = hitbox.ESP_Label:FindFirstChildWhichIsA("TextLabel")
                    if label then
                        local t = tick() % 5 / 5
                        label.TextColor3 = Color3.fromHSV(t, 1, 1)
                    end
                end
            end
        end)
        table.insert(espConnections, con)
    end
end

--================================================================--
-- TRACER (Beam) helpers
--================================================================--
local function createTracer(part)
    if not part then return end
    if part:FindFirstChild("ESP_Tracer") then
        part.ESP_Tracer:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "ESP_Tracer"
    folder.Parent = part

    local att0 = Instance.new("Attachment", part)
    att0.Name = "From"

    local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    if not head then return end

    local att1 = Instance.new("Attachment", head)
    att1.Name = "To"

    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Transparency = NumberSequence.new(0)
    beam.Color = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 1, 0))
    beam.Parent = folder
end

local function destroyTracer()
    for _, plr in ipairs(Players:GetPlayers()) do
        local model = Workspace:FindFirstChild(plr.Name)
        if model then
            local bomb = model:FindFirstChild("Bomb")
            local hitbox = bomb and bomb:FindFirstChild("Hitbox")
            if hitbox and hitbox:FindFirstChild("ESP_Tracer") then
                hitbox.ESP_Tracer:Destroy()
            end
        end
    end
end

local function updateTracer()
    for _, c in ipairs(tracerConnections) do
        pcall(function() c:Disconnect() end)
    end
    tracerConnections = {}

    for _, player in pairs(Players:GetPlayers()) do
        local con = RunService.Heartbeat:Connect(function()
            if not Options.ESPTracerToggle or not Options.ESPTracerToggle.Value then return end
            local model = Workspace:FindFirstChild(player.Name)
            if not model then return end
            local bomb = model:FindFirstChild("Bomb")
            local hitbox = bomb and bomb:FindFirstChild("Hitbox")
            if not hitbox then return end
            if not hitbox:FindFirstChild("ESP_Tracer") then
                createTracer(hitbox)
            else
                local beam = hitbox.ESP_Tracer:FindFirstChildWhichIsA("Beam")
                if beam then
                    local t = tick() % 5 / 5
                    beam.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(t, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV((t + 0.3) % 1, 1, 1))
                    }
                end
            end
        end)
        table.insert(tracerConnections, con)
    end
end

--================================================================--
-- SHIFLOCK 
--================================================================--
local function enableShiftLockMobile()
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer

    local ShiftLockScreenGui = Instance.new("ScreenGui")
    ShiftLockScreenGui.Name = "Shiftlock (CoreGui)"
    ShiftLockScreenGui.Parent = CoreGui
    ShiftLockScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ShiftLockScreenGui.ResetOnSpawn = false

    local ShiftLockButton = Instance.new("ImageButton", ShiftLockScreenGui)
    local States = {
        Off = "rbxasset://textures/ui/mouseLock_off@2x.png",
        On = "rbxasset://textures/ui/mouseLock_on@2x.png"
    }

    local MaxLength = 900000
    local EnabledOffset = CFrame.new(1.7, 0, 0)
    local DisabledOffset = CFrame.new(-1.7, 0, 0)
    local Active

    ShiftLockButton.BackgroundTransparency = 1
    ShiftLockButton.Position = UDim2.new(0.7, 0, 0.75, 0)
    ShiftLockButton.Size = UDim2.new(0.0636, 0, 0.0661, 0)
    ShiftLockButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
    ShiftLockButton.Image = States.Off

    ShiftLockButton.MouseButton1Click:Connect(function()
        if not Active then
            Active = RunService.RenderStepped:Connect(function()
                if Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character:FindFirstChild("HumanoidRootPart") then
                    Player.Character.Humanoid.AutoRotate = false
                    ShiftLockButton.Image = States.On
                    Player.Character.HumanoidRootPart.CFrame = CFrame.new(
                        Player.Character.HumanoidRootPart.Position,
                        Vector3.new(
                            workspace.CurrentCamera.CFrame.LookVector.X * MaxLength,
                            Player.Character.HumanoidRootPart.Position.Y,
                            workspace.CurrentCamera.CFrame.LookVector.Z * MaxLength
                        )
                    )
                    workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * EnabledOffset
                    workspace.CurrentCamera.Focus = CFrame.fromMatrix(
                        workspace.CurrentCamera.Focus.Position,
                        workspace.CurrentCamera.CFrame.RightVector,
                        workspace.CurrentCamera.CFrame.UpVector
                    ) * EnabledOffset
                end
            end)
        else
            if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                Player.Character.Humanoid.AutoRotate = true
            end
            ShiftLockButton.Image = States.Off
            workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * DisabledOffset
            pcall(function()
                Active:Disconnect()
            end)
            Active = nil
        end
    end)
end

--================================================================--
-- SPEED BOOST
--================================================================--







--================================================================--
-- BYPASS ADONIS ANTI CHEAT
--================================================================--

local g = getinfo or debug.getinfo
local d = true
local h = {}

local x, y

setthreadidentity(2)

for i, v in getgc(true) do
    if typeof(v) == "table" then
        local a = rawget(v, "Detected")
        local b = rawget(v, "Kill")
    
        if typeof(a) == "function" and not x then
            x = a
            
            local o; o = hookfunction(x, function(c, f, n)
                if c ~= "_" and d then
                    warn(`Adonis AntiCheat flagged\nMethod: {c}\nInfo: {f}`)
                end
                return true
            end)

            table.insert(h, x)
        end

        if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
            y = b

            local o; o = hookfunction(y, function(f)
                if d then
                    warn(`Adonis AntiCheat tried to kill (fallback): {f}`)
                end
            end)

            table.insert(h, y)
        end
    end
end

local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
    local a, f = ...

    if x and a == x then
        if d then
            warn(`Bypass Adonis AntiCheat`)
        end
        return coroutine.yield(coroutine.running())
    end
    
    return o(...)
end))

setthreadidentity(7)

--================================================================--
-- Auto Lock
--================================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRoot = character:WaitForChild("HumanoidRootPart")

local autoLockEnabled = false
local lockDistance = 50

--===== SNAPLINE (Drawing API) =====--
local snapline = Drawing.new("Line")
snapline.Thickness = 2
snapline.Color = Color3.fromRGB(128, 0, 128) -- purple 
snapline.Transparency = 1
snapline.Visible = false

--===== FIND CLOSEST PLAYER =====--
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = lockDistance
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - humanoidRoot.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

--===== MAIN LOOP =====--
RunService.RenderStepped:Connect(function()
    if humanoidRoot and humanoidRoot.Parent then
        local target = autoLockEnabled and getClosestPlayer() or nil
        
        if target and target.Character then
            local targetHead = target.Character:FindFirstChild("Head")
            local myHead = character:FindFirstChild("Head")

            if targetHead and myHead then
                --=== AUTO LOCK ===--
                local targetPos = targetHead.Position
                local direction = (Vector3.new(targetPos.X, humanoidRoot.Position.Y, targetPos.Z) - humanoidRoot.Position).Unit
                humanoidRoot.CFrame = CFrame.new(humanoidRoot.Position, humanoidRoot.Position + direction)

                --=== SNAPLINE UPDATE (HEAD → HEAD) ===--
                local cam = workspace.CurrentCamera

                local myScreen, myOnScreen = cam:WorldToViewportPoint(myHead.Position)
                local targetScreen, targetOnScreen = cam:WorldToViewportPoint(targetHead.Position)

                if myOnScreen and targetOnScreen then
                    snapline.Visible = true
                    snapline.From = Vector2.new(myScreen.X, myScreen.Y)
                    snapline.To = Vector2.new(targetScreen.X, targetScreen.Y)
                else
                    snapline.Visible = false
                end
            else
                snapline.Visible = false
            end
        else
            snapline.Visible = false
        end
    end
end)

--===== CHARACTER RELOAD FIX =====--
localPlayer.CharacterAdded:Connect(function(char)
    character = char
    humanoidRoot = character:WaitForChild("HumanoidRootPart")
end)


--================================================================--
-- SPEED BOOST
--================================================================--
local tpwalkEnabled = false
local tpwalkSpeed = 0.03

local char
local hum
local hrp

local function setupCharacter(c)
	char = c
	hum = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
end

if LocalPlayer.Character then
	setupCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(c)
	task.wait(0.1)
	setupCharacter(c)
end)

RunService.Stepped:Connect(function()
	if tpwalkEnabled and char and hum and hrp then
		if hum.Health <= 0 then return end

		local moveDir = hum.MoveDirection

		if moveDir.Magnitude > 0 then
			hrp.CFrame = hrp.CFrame + (moveDir * tpwalkSpeed)
		end
	end
end)
--================================================================--
-- GUI
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "Pass The Bomb",
    Icon = 94858886314945,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

-- INFO TAB
local InfoTab = Window:AddTab("Info", "info")
local InfoLeft = InfoTab:AddLeftGroupbox("Credits", "users")
local InfoLeft2 = InfoTab:AddLeftGroupbox("Discord", "discord")
local InfoRight = InfoTab:AddRightGroupbox("Reminder", "lucide-book-a")

InfoLeft:AddLabel("Made By: Pkgx1")
InfoLeft:AddLabel("Discord: https://discord.gg/n9gtmefsjc")
InfoLeft:AddDivider()
InfoLeft:AddLabel("You Can Request Script")
InfoLeft:AddLabel("On Discord!")
InfoLeft:AddDivider()


InfoLeft2:AddLabel("Discord Link")
InfoLeft2:AddButton({
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

----------------------------------------------------------------
-- MAIN TAB (4 GROUPBOX CLEAN ORGANIZATION)
----------------------------------------------------------------
local MainTab = Window:AddTab("Main", "house")

local HitboxBox     = MainTab:AddLeftGroupbox("Hitbox", "scan")
local EspBox        = MainTab:AddRightGroupbox("Esp","eye")
local MovementBox        = MainTab:AddRightGroupbox("Movement","cloud-lightning")
local MiscBox       = MainTab:AddLeftGroupbox("Misc", "settings")
local ProtectBox    = MainTab:AddRightGroupbox("Protection","shield")
local PlayerRight = MainTab:AddRightGroupbox("Animation Control", "contact")
----------------------------------------------------------------
-- HITBOX SECTION
----------------------------------------------------------------
HitboxBox:AddToggle("HitboxToggle", {
    Text = "Enable Hitbox",
    Default = false,
    Callback = function(Value)
        if Value then
            Options.HitboxToggle = { Value = true }
            monitorPlayers()
            Library:Notify({ Title = "Hitbox", Description = "Enabled", Time = 2 })
        else
            Options.HitboxToggle = { Value = false }
            for _, c in ipairs(hitboxConnections) do pcall(function() c:Disconnect() end) end
            hitboxConnections = {}

            for _, pl in pairs(Players:GetPlayers()) do
                deactivateCollisionPart(pl.Name)
            end

            Library:Notify({ Title = "Hitbox", Description = "Disabled", Time = 2 })
        end
    end,
})

HitboxBox:AddInput("HitboxSizeInput", {
    Default = "",
    Numeric = true,
    ClearTextOnFocus = true,
    Text = "Hitbox Size",
    Placeholder = "Enter size (max 15)",
    Callback = function(Value)
        local max = 15
        local size = tonumber(Value)

        if size then
            if size > max then size = max end
            if size < 0 then size = 0 end

            currentHitboxSize = size

            for _, pl in pairs(Players:GetPlayers()) do
                if pl.Name ~= LocalPlayer.Name then
                    local pm = Workspace:FindFirstChild(pl.Name)
                    if pm then
                        local c = pm:FindFirstChild("CollisionPart")
                        if c and c:IsA("BasePart") then
                            c.Size = Vector3.new(size, size, size)
                        end
                    end
                end
            end

            Library:Notify({ Title = "Hitbox Size", Description = "Set to " .. tostring(size), Time = 2 })
        end
    end,
})

HitboxBox:AddToggle("ShowHitboxButtons", {
    Text = "Show Hitbox Buttons",
    Default = false,
    Callback = function(Value)
        if Value then
            createHitboxUI()
            LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                createHitboxUI()
            end)
            Library:Notify({ Title = "Hitbox UI", Description = "Shown", Time = 2 })
        else
            local gui = safeGetPlayerGui():FindFirstChild("HitboxGui")
            if gui then gui:Destroy() end
            Library:Notify({ Title = "Hitbox UI", Description = "Hidden", Time = 2 })
        end
    end,
})

HitboxBox:AddToggle("AutoLockToggle", {
    Text = "Auto Lock",
    Default = false,
    Callback = function(state)
        autoLockEnabled = state
    end
})

HitboxBox:AddInput("AutoLockDistanceInput", {
    Default = tostring(lockDistance),
    Numeric = true,
    ClearTextOnFocus = true,
    Text = "Lock Distance",
    Placeholder = "Enter max distance",
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            lockDistance = num
            Library:Notify({Title = "Auto Lock", Description = "Lock distance set to "..num, Time = 2})
        end
    end
})

----------------------------------------------------------------
-- PROTECTION SECTION (Adonis Bypass)
----------------------------------------------------------------
ProtectBox:AddToggle("AdonisBypassToggle", {
    Text = "Bypass (AntiCheat)",
    Default = true,
    Callback = function(Value)
        d = Value
        if Value then
            Library:Notify({ Title = "Adonis Bypass", Description = "Enabled", Time = 2 })
        else
            Library:Notify({ Title = "Adonis Bypass", Description = "Disabled", Time = 2 })
        end
    end,
})


----------------------------------------------------------------
-- ESP SECTION
----------------------------------------------------------------
EspBox:AddToggle("ESPNameToggle", {
    Text = "ESP Bomb",
    Default = false,
    Callback = function(Value)
        if Value then
            Options.ESPNameToggle = { Value = true }
            updateESP()
            Library:Notify({ Title = "ESP Bomb", Description = "Enabled", Time = 2 })
        else
            Options.ESPNameToggle = { Value = false }
            for _, c in ipairs(espConnections) do pcall(function() c:Disconnect() end) end
            espConnections = {}
            destroyESP()
            Library:Notify({ Title = "ESP Bomb", Description = "Disabled", Time = 2 })
        end
    end,
})

EspBox:AddToggle("ESPTracerToggle", {
    Text = "Tracer Bomb",
    Default = false,
    Callback = function(Value)
        if Value then
            Options.ESPTracerToggle = { Value = true }
            updateTracer()
            Library:Notify({ Title = "ESP Tracer", Description = "Enabled", Time = 2 })
        else
            Options.ESPTracerToggle = { Value = false }
            for _, c in ipairs(tracerConnections) do pcall(function() c:Disconnect() end) end
            tracerConnections = {}
            destroyTracer()
            Library:Notify({ Title = "ESP Tracer", Description = "Disabled", Time = 2 })
        end
    end,
})






MovementBox:AddToggle("TPWalkToggle", {
	Text = "Speed Boost",
	Default = false,
	Callback = function(state)
		tpwalkEnabled = state
	end
})

MovementBox:AddSlider("TPWalkSpeedSlider", {
	Text = "Speed Boost Level",
	Default = 3,
	Min = 1,
	Max = 3,
	Rounding = 0,
	Callback = function(value)
		if value == 1 then
			tpwalkSpeed = 0.01
		elseif value == 2 then
			tpwalkSpeed = 0.02
		elseif value == 3 then
			tpwalkSpeed = 0.03
		end
	end
})

----------------------------------------------------------------
-- MISC SECTION
----------------------------------------------------------------
MiscBox:AddButton({
    Text = "Max View",
    Func = function()
        LocalPlayer.CameraMaxZoomDistance = 500
        LocalPlayer.CameraMinZoomDistance = 0.5
        Library:Notify({ Title = "Camera", Description = "Max view set", Time = 2 })
    end,
})

MiscBox:AddButton({
    Text = "Remove Explosion",
    Func = function()
        local debris = Workspace:FindFirstChild("DebrisFolder")
        if debris then debris:Destroy() end
        Library:Notify({ Title = "Debris", Description = "Removed", Time = 2 })
    end,
})

MiscBox:AddButton({
    Text = "Shiftlock Mobile",
    Func = function()
        enableShiftLockMobile()
        Library:Notify({ Title = "Shiftlock", Description = "Enabled (mobile UI)", Time = 2 })
    end,
})

----------------------------------------------------------------
-- PLAYER TAB
----------------------------------------------------------------

PlayerRight:AddButton({
    Text = "Animation",
    Func = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/BeemTZy/Motiona/refs/heads/main/source.lua"))()
    end,
})

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
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
