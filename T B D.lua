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
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

--================================================================--
-- BYPASS
--================================================================--
--[[
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
            warn(`Bypass Gay AntiCheat`)
        end
        return coroutine.yield(coroutine.running())
    end
    
    return o(...)
end))

setthreadidentity(7)
]]
--================================================================--
-- HITBOX VISUALIZER VARIABLES & CORE
--================================================================--
local hitboxVisualizerEnabled = false
local TRANSPARENCY = 0.35
local HITBOX_COLOR = Color3.fromRGB(255, 0, 0)
local LOCAL_COLOR = Color3.fromRGB(0, 255, 0)
local HITBOX_SIZE = Vector3.new(3.5, 3.5, 3.5) 
local PING_ESTIMATE = 0.0979
local MAX_HISTORY_SECONDS = 2.0
local SMOOTH_LERP = 0.9
local SHOW_LOCAL_HITBOX = true

local history = {}
local serverVisualizer = nil
local localVisualizer = nil
local hbConn = nil

local function log(msg)
	print("[HitboxViz] " .. msg)
end

local function createHitboxPart(name, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = HITBOX_SIZE
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Locked = true
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Transparency = TRANSPARENCY

	local cam = Workspace.CurrentCamera
	if cam then
		p.Parent = cam
	else
		p.Parent = Workspace
	end

	return p
end

local function cleanupHitbox()
	if hbConn then
		hbConn:Disconnect()
		hbConn = nil
	end
	if serverVisualizer then
		serverVisualizer:Destroy()
		serverVisualizer = nil
	end
	if localVisualizer then
		localVisualizer:Destroy()
		localVisualizer = nil
	end
	history = {}
end

local function findEntryAtTime(targetTime)
	for i = #history, 1, -1 do
		if history[i].t <= targetTime then
			return history[i]
		end
	end
	return nil
end

local function startVisualizer(character)
	cleanupHitbox()
	if not hitboxVisualizerEnabled then return end
	
	log("Iniciando visualizador...")

	local hrp = character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")

	if not hrp then
		log("HRP/Torso not found.")
		return
	end

	repeat task.wait() until Workspace.CurrentCamera

	serverVisualizer = createHitboxPart("Server_HitboxViz", HITBOX_COLOR)

	if SHOW_LOCAL_HITBOX then
		localVisualizer = createHitboxPart("Local_HitboxViz", LOCAL_COLOR)
		localVisualizer.Transparency = TRANSPARENCY * 0.6
	end

	local alpha = 1 - SMOOTH_LERP
	alpha = math.clamp(alpha, 0, 1)

	hbConn = RunService.Heartbeat:Connect(function()
		if not hrp or not hrp.Parent then
			cleanupHitbox()
			return
		end

		local now = os.clock()
		table.insert(history, { t = now, cframe = hrp.CFrame })

		while #history > 1 and (now - history[1].t) > MAX_HISTORY_SECONDS do
			table.remove(history, 1)
		end

		local targetTime = now - PING_ESTIMATE
		local entry = findEntryAtTime(targetTime)

		local targetCFrame = entry and entry.cframe
			or (history[1] and history[1].cframe)
			or hrp.CFrame

		if serverVisualizer and serverVisualizer.Parent then
			serverVisualizer.CFrame = serverVisualizer.CFrame:Lerp(targetCFrame, alpha)
		end

		if localVisualizer and localVisualizer.Parent then
			localVisualizer.CFrame = localVisualizer.CFrame:Lerp(hrp.CFrame, alpha)
		end
	end)

	log("Visualizer Enabled.")
end

--================================================================--
-- Auto Lock
--================================================================--
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
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
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
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
                local cam = Workspace.CurrentCamera

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
LocalPlayer.CharacterAdded:Connect(function(char)
    character = char
    humanoidRoot = character:WaitForChild("HumanoidRootPart")
    if hitboxVisualizerEnabled then
        task.wait(0.5)
        startVisualizer(char)
    end
end)

--================================================================--
-- TPWALK FIXED
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
-- SNAP ROTATION 
--================================================================--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local smoothRotateEnabled = false
local rotateSpeed = 0.5

local connection

local function setup(char)
	local hum = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")

	hum.AutoRotate = true

	if connection then
		connection:Disconnect()
		connection = nil
	end

	connection = RunService.RenderStepped:Connect(function()
		if not hum or not hrp or hum.Health <= 0 then return end

		if not smoothRotateEnabled then return end

		local moveDir = hum.MoveDirection

		if moveDir.Magnitude > 0.1 then
			local target = CFrame.lookAt(hrp.Position, hrp.Position + moveDir)
			hrp.CFrame = hrp.CFrame:Lerp(target, rotateSpeed)
		end
	end)
end

player.CharacterAdded:Connect(setup)

if player.Character then
	setup(player.Character)
end



--================================================================--
-- BLOCK ASSIST
--================================================================--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local blocksEnabled = false
local blocksFolder

local function createPart(position)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 5.5, 3)
	part.Position = Vector3.new(position.X, position.Y + 0.5, position.Z)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = blocksFolder
end

local function createPart2(position)
	local part = Instance.new("Part")
	part.Size = Vector3.new(3, 6, 1)
	part.Position = position
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = blocksFolder
end

local function setupBlocks()
	if blocksFolder then
		blocksFolder:Destroy()
		blocksFolder = nil
	end

	blocksFolder = Instance.new("Folder")
	blocksFolder.Name = "CustomBlocks"
	blocksFolder.Parent = workspace

	if not blocksEnabled then
		return
	end

	-- Side walls
	createPart(Vector3.new(138.50, 0.6, -18.64))
	createPart(Vector3.new(138.50, 0.6, -41.24))
	createPart(Vector3.new(95.52, 0.6, -18.64))
	createPart(Vector3.new(95.52, 0.6, -41.24))

	-- Front/back walls
	createPart2(Vector3.new(128.10, 0.6, -8.50))
	createPart2(Vector3.new(105.85, 0.6, -8.50))
	createPart2(Vector3.new(105.85, 0.6, -51.50))
	createPart2(Vector3.new(128.10, 0.6, -51.50))
end


--================================================================--
-- RESIZE BIG JUMP BUTTON 
--================================================================--

local function ResizeJumpButton()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local touchGui = playerGui:WaitForChild("TouchGui")
	local touchFrame = touchGui:WaitForChild("TouchControlFrame")
	local jumpButton = touchFrame:WaitForChild("JumpButton")

	jumpButton.Size = UDim2.new(0.121, 0, 0.3, 0)
	jumpButton.Position = UDim2.new(1, -165, 1, -140)

	if not jumpButton:FindFirstChildOfClass("UICorner") then
		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(1, 0)
		uiCorner.Parent = jumpButton
	end
end




--================================================================--
-- ESP BOMB
--================================================================--
--[[
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local OBJECT_NAME = "Bomb"
local ESP_COLOR = Color3.fromRGB(255, 150, 0)
local MAX_DISTANCE = 800

local ObjectESPEnabled = false
local Tracked = {}

local function isTarget(obj)
	if not obj or not obj.Name then
		return false
	end
	return obj.Name:lower():find(OBJECT_NAME:lower())
end

local function track(model)
	if model and model:IsA("Model") and isTarget(model) then
		Tracked[model] = true
	end
end

local function clearESP(model)
	if model then
		local hl = model:FindFirstChild("OBJ_ESP_HL")
		if hl then
			hl:Destroy()
		end

		local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if root and root:FindFirstChild("OBJ_ESP_BILLBOARD") then
			root.OBJ_ESP_BILLBOARD:Destroy()
		end
	end
end

local function untrack(model)
	Tracked[model] = nil
	clearESP(model)
end

local function SetObjectESP(State)
	ObjectESPEnabled = State

	if not State then
		for model in pairs(Tracked) do
			clearESP(model)
		end
	end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	if obj:IsA("Model") then
		track(obj)
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") then
		task.wait()
		track(obj)
	end
end)

Workspace.DescendantRemoving:Connect(untrack)

RunService.Heartbeat:Connect(function()
	if not ObjectESPEnabled then
		return
	end

	local Character = LP.Character
	local HRP = Character and Character:FindFirstChild("HumanoidRootPart")

	if not HRP then
		return
	end

	local myPos = HRP.Position

	for model in pairs(Tracked) do
		if model and model.Parent then
			local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

			if root then
				local dist = (root.Position - myPos).Magnitude

				if dist <= MAX_DISTANCE then
					local hl = model:FindFirstChild("OBJ_ESP_HL") or Instance.new("Highlight")
					hl.Name = "OBJ_ESP_HL"
					hl.Parent = model
					hl.Adornee = model
					hl.FillColor = ESP_COLOR
					hl.OutlineColor = Color3.new(1, 1, 1)
					hl.FillTransparency = 0.5
					hl.OutlineTransparency = 0
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

					local bg = root:FindFirstChild("OBJ_ESP_BILLBOARD") or Instance.new("BillboardGui")
					bg.Name = "OBJ_ESP_BILLBOARD"
					bg.Parent = root
					bg.Adornee = root
					bg.Size = UDim2.new(0, 240, 0, 50)
					bg.StudsOffset = Vector3.new(0, 4, 0)
					bg.AlwaysOnTop = true
					bg.MaxDistance = MAX_DISTANCE

					local label = bg:FindFirstChild("Label") or Instance.new("TextLabel")
					label.Name = "Label"
					label.Parent = bg
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = string.format(
						"<font color='rgb(%d,%d,%d)'>%s</font>\n[%dm]",
						ESP_COLOR.R * 255,
						ESP_COLOR.G * 255,
						ESP_COLOR.B * 255,
						model.Name:gsub("^%l", string.upper),
						math.floor(dist)
					)
					label.TextColor3 = Color3.new(1, 1, 1)
					label.TextStrokeTransparency = 0
					label.TextStrokeColor3 = Color3.new(0, 0, 0)
					label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
					label.TextSize = 10
					label.RichText = true
				else
					clearESP(model)
				end
			end
		else
			untrack(model)
		end
	end
end)



]]




--================================================================--
-- TRACK FLICK 
--================================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRoot = character:WaitForChild("HumanoidRootPart")

_G.FlickFeatureEnabled = false  
_G.AutoLockEnabledGlobal = false
_G.IsRunningGlobal = false
_G.FlickAngleSetting = 60

local lockDistance = 30        
local spinDistance360 = 5      
local spinSpeed360 = 30        
local activeDuration = 1.3     

local flickAngle = 60         
local flickDelay = 0.05       
local turnSpeed = 0.25        

local timer = 0
local state = false
local currentYaw = 0
local activeTimer = 0          

local snapline = Drawing.new("Line")
snapline.Thickness = 2
snapline.Color = Color3.fromRGB(128, 0, 128) 
snapline.Transparency = 1
snapline.Visible = false
_G.SnaplineInstance = snapline

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaMiniButtonGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = false 
_G.ScreenGuiInstance = ScreenGui

local success, err = pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not success then
    ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local DragButton = Instance.new("TextButton")
DragButton.Name = "MiniToggleButton"
DragButton.Size = UDim2.new(0, 50, 0, 50)
DragButton.Position = UDim2.new(0, 20, 0.5, -25)
DragButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DragButton.BackgroundTransparency = 0.25
DragButton.Text = "CLICK"
DragButton.TextColor3 = Color3.fromRGB(128, 0, 128)
DragButton.TextSize = 14
DragButton.Font = Enum.Font.SourceSansBold
DragButton.Active = true
DragButton.ZIndex = 10
DragButton.Parent = ScreenGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = DragButton

local buttonBlackBorder = Instance.new("UIStroke")
buttonBlackBorder.Name = "BlackBorder"
buttonBlackBorder.Color = Color3.fromRGB(0, 0, 0)
buttonBlackBorder.Thickness = 2
buttonBlackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
buttonBlackBorder.Parent = DragButton

local buttonPurpleOutline = Instance.new("UIStroke")
buttonPurpleOutline.Name = "PurpleOutline"
buttonPurpleOutline.Color = Color3.fromRGB(128, 0, 128)
buttonPurpleOutline.Thickness = 4
buttonPurpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
buttonPurpleOutline.Parent = DragButton

local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    TweenService:Create(DragButton, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end

DragButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = DragButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

DragButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

DragButton.MouseButton1Click:Connect(function()
    if _G.FlickFeatureEnabled and not _G.IsRunningGlobal then
        _G.IsRunningGlobal = true
        _G.AutoLockEnabledGlobal = true
        activeTimer = 0 
        
        DragButton.Text = "RUN"
        TweenService:Create(DragButton, TweenInfo.new(0.1), {BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(128, 0, 128), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        buttonPurpleOutline.Color = Color3.fromRGB(255, 255, 255)
    end
end)

local function getClosestPlayer(maxDistance)
    local closestPlayer = nil
    local shortestDistance = maxDistance or lockDistance
    
    if not humanoidRoot then return nil end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local targetPos = player.Character.HumanoidRootPart.Position
                local distance = (targetPos - humanoidRoot.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

RunService.Heartbeat:Connect(function(dt)
    if not _G.FlickFeatureEnabled then 
        snapline.Visible = false
        return 
    end
    
    if not humanoidRoot or not humanoidRoot.Parent then return end
    
    if _G.AutoLockEnabledGlobal then
        activeTimer += dt
        if activeTimer >= activeDuration then
            _G.AutoLockEnabledGlobal = false
            _G.IsRunningGlobal = false 
            activeTimer = 0
            
            DragButton.Text = "CLICK"
            TweenService:Create(DragButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(0, 0, 0), TextColor3 = Color3.fromRGB(128, 0, 128)}):Play()
            buttonPurpleOutline.Color = Color3.fromRGB(128, 0, 128)
        end
    end

    local chosenAngle = _G.FlickAngleSetting or 60

    if chosenAngle == 360 then
        if _G.AutoLockEnabledGlobal then
            local target = getClosestPlayer(spinDistance360)
            
            if target and target.Character then
                currentYaw = currentYaw + math.rad(spinSpeed360)
                humanoidRoot.CFrame = CFrame.new(humanoidRoot.Position) * CFrame.Angles(0, currentYaw, 0)
                
                local targetHead = target.Character:FindFirstChild("Head")
                local myHead = character:FindFirstChild("Head")
                if targetHead and myHead then
                    local cam = workspace.CurrentCamera
                    local myScreen, myOnScreen = cam:WorldToViewportPoint(myHead.Position)
                    local targetScreen, targetOnScreen = cam:WorldToViewportPoint(targetHead.Position)
                    if myOnScreen and targetOnScreen then
                        snapline.Visible = true
                        snapline.From = Vector2.new(myScreen.X, myScreen.Y)
                        snapline.To = Vector2.new(targetScreen.X, targetScreen.Y)
                        return
                    end
                end
            end
        end
        snapline.Visible = false
        return
    end

    local target = _G.AutoLockEnabledGlobal and getClosestPlayer(lockDistance) or nil
    
    if target and target.Character then
        local targetHead = target.Character:FindFirstChild("Head")
        local myHead = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if targetHead and myHead and (humanoid and humanoid.Health > 0) then
            local targetPos = targetHead.Position
            local direction = (Vector3.new(targetPos.X, humanoidRoot.Position.Y, targetPos.Z) - humanoidRoot.Position).Unit
            local baseYaw = math.atan2(-direction.X, -direction.Z)

            timer += dt
            if timer >= flickDelay then
                timer = 0
                state = not state
            end

            local targetYaw = baseYaw
            if state then
                targetYaw = baseYaw + math.rad(chosenAngle)
            else
                targetYaw = baseYaw - math.rad(chosenAngle)
            end

            local diff = (targetYaw - currentYaw)
            diff = math.atan2(math.sin(diff), math.cos(diff))
            currentYaw = currentYaw + diff * (turnSpeed * (dt * 60))

            humanoidRoot.CFrame = CFrame.new(humanoidRoot.Position) * CFrame.Angles(0, currentYaw, 0)

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
end)

localPlayer.CharacterAdded:Connect(function(char)
    character = char
    humanoidRoot = char:WaitForChild("HumanoidRootPart")
end)



-- ============================================================
-- FLICK JUMP
-- ============================================================








getgenv().FlickConfig = {
	ButtonScale = 1.0,
	FlickDirection = "Left", 
	ReturnDelay = 0.1
}
getgenv().FlickFeatureEnabled = false 

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local isFlicking = false
local screenGui
local toggleButton

local baseBlackBorder = Instance.new("UIStroke")
baseBlackBorder.Name = "BlackBorder"
baseBlackBorder.Color = Color3.fromRGB(0, 0, 0)
baseBlackBorder.Thickness = 2
baseBlackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local basePurpleOutline = Instance.new("UIStroke")
basePurpleOutline.Name = "PurpleOutline"
basePurpleOutline.Color = Color3.fromRGB(128, 0, 128)
basePurpleOutline.Thickness = 4
basePurpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function TriggerFlick()
	if not getgenv().FlickFeatureEnabled or isFlicking then return end
	isFlicking = true

	local Character = LocalPlayer.Character
	if Character then
		local humanoid = Character:FindFirstChildOfClass("Humanoid")
		local rootPart = Character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and rootPart then
			humanoid:ChangeState(Enum.HumanoidStateType.Landed)
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, humanoid.JumpPower, rootPart.AssemblyLinearVelocity.Z)
		end
	end

	local originalCFrame = Camera.CFrame
	local angleRad = math.rad(65)
	if getgenv().FlickConfig.FlickDirection == "Right" then angleRad = -angleRad end

	Camera.CFrame = CFrame.new(Camera.CFrame.Position)
		* CFrame.Angles(0, angleRad, 0)
		* (Camera.CFrame - Camera.CFrame.Position)

	task.wait(getgenv().FlickConfig.ReturnDelay)
	Camera.CFrame = originalCFrame
	isFlicking = false
end

local function CreateUI()
	if PlayerGui:FindFirstChild("DeltaMiniButtonGui") then 
		PlayerGui.DeltaMiniButtonGui:Destroy() 
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeltaMiniButtonGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = getgenv().FlickFeatureEnabled 
	screenGui.Parent = PlayerGui

	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "MiniToggleButton"
	toggleButton.Size = UDim2.new(0, 50, 0, 50)
	toggleButton.Position = UDim2.new(0, 20, 0.5, -25)
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0) 
	toggleButton.BackgroundTransparency = 0.25
	toggleButton.Text = "Δ"
	toggleButton.TextColor3 = Color3.fromRGB(128, 0, 128)
	toggleButton.TextSize = 24
	toggleButton.Font = Enum.Font.SourceSansBold
	toggleButton.Active = true
	toggleButton.AutoButtonColor = false
	toggleButton.Parent = screenGui

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = toggleButton

	local buttonBlackBorder = baseBlackBorder:Clone()
	buttonBlackBorder.Parent = toggleButton

	local buttonPurpleOutline = basePurpleOutline:Clone()
	buttonPurpleOutline.Parent = toggleButton

	toggleButton.MouseButton1Click:Connect(TriggerFlick)

	local dragging = false
	local dragInput, dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(toggleButton, tweenInfo, {Position = targetPos}):Play()
	end

	toggleButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = toggleButton.Position
			
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	toggleButton.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
end

CreateUI()

RunService.RenderStepped:Connect(function()
	if not PlayerGui:FindFirstChild("DeltaMiniButtonGui") or (screenGui and screenGui.Parent ~= PlayerGui) then
		CreateUI()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F then TriggerFlick() end
end)





--================================================================--
-- GUI INITIALIZATION
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "Time Bomb Duel",
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
-- MAIN TAB
----------------------------------------------------------------
local MainTab = Window:AddTab("Main", "house")
local AutoLeft     = MainTab:AddLeftGroupbox("Aim Lock", "lock")
--[[ local EspRight  = MainTab:AddRightGroupbox("Esp", "eye")
local BypassRight    = MainTab:AddRightGroupbox("Protection","shield")  ]]
local HitboxRight  = MainTab:AddRightGroupbox("Assist", "file-plus")
local MovementLeft = MainTab:AddLeftGroupbox("Movement", "user")

-- AIM LOCK CONFIG
AutoLeft:AddToggle("AutoLockToggle", {
    Text = "Auto Lock",
    Default = false,
    Callback = function(state)
        autoLockEnabled = state
    end
})

AutoLeft:AddInput("AutoLockDistanceInput", {
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

-- ============================================================
-- UI LIBRARY ELEMENTS (Toggle & Dropdown)
-- ============================================================

AutoLeft:AddToggle("FlickFeatureToggle", {
	Text = "Flick Jump",
	Default = false,
	Callback = function(Value)
		getgenv().FlickFeatureEnabled = Value
		
		local Players = game:GetService("Players")
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		local flickGui = playerGui and playerGui:FindFirstChild("DeltaMiniButtonGui")
		
		if flickGui then
			flickGui.Enabled = Value
			
			local miniButton = flickGui:FindFirstChild("MiniToggleButton", true)
			if miniButton then
				miniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				miniButton.BackgroundTransparency = 0.25
			end
		end
	end,
})




AutoLeft:AddToggle("SpinBotToggle", {
	Text = "Flick",
	Default = false,
	Callback = function(Value)
		_G.FlickFeatureEnabled = Value
		if _G.ScreenGuiInstance then
			_G.ScreenGuiInstance.Enabled = Value
		end
		if not Value then
			_G.AutoLockEnabledGlobal = false
			_G.IsRunningGlobal = false
			if _G.SnaplineInstance then
				_G.SnaplineInstance.Visible = false
			end
		end
	end,
})

AutoLeft:AddDropdown("FlickAngleDropdown", {
	Values = { "360", "60", "90" },
	Default = "60",
	Multi = false,
	Text = "Flick Angle Type",
	Searchable = false,
	Callback = function(Value)
		_G.FlickAngleSetting = tonumber(Value) or 60
	end,
})




----------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------

MovementLeft:AddToggle("TPWalkToggle", {
	Text = "Speed Boost",
	Default = false,
	Callback = function(state)
		tpwalkEnabled = state
	end
})

MovementLeft:AddSlider("TPWalkSpeedSlider", {
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

MovementLeft:AddToggle("SmoothRotateToggle", {
	Text = "Snap Rotate",
	Default = false,
	Callback = function(state)
		smoothRotateEnabled = state
	end
})

MovementLeft:AddSlider("SmoothRotateSpeed", {
	Text = "Rotate Speed",
	Default = 5,
	Min = 1,
	Max = 10,
	Rounding = 1,
	Callback = function(value)
		rotateSpeed = value / 10
	end
})



----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
--[[

EspRight:AddToggle("ObjectESP", {
	Text = "Bomb ESP",
	Default = false,
	Callback = function(Value)
		SetObjectESP(Value)
	end,
})
----------------------------------------------------------------
-- BYPASS PROTECTION 
----------------------------------------------------------------
--[[
BypassRight:AddToggle("AdonisBypassToggle", {
    Text = "Bypass (AntiCheat)",
    Default = true,
    Callback = function(Value)
        d = Value
        if Value then
            Library:Notify({ Title = "Bypass", Description = "Enabled", Time = 2 })
        else
            Library:Notify({ Title = "Bypass", Description = "Disabled", Time = 2 })
        end
    end,
})
]]
----------------------------------------------------------------
-- HITBOX VISUALIZER 
----------------------------------------------------------------
HitboxRight:AddButton({
	Text = "Resize Jump Button",
	Func = function()
		ResizeJumpButton()
	end
})


HitboxRight:AddToggle("HitboxVisualizerToggle", {
    Text = "Enable Hitbox Visualizer",
    Default = false,
    Callback = function(state)
        hitboxVisualizerEnabled = state
        if state then
            if LocalPlayer.Character then
                startVisualizer(LocalPlayer.Character)
            end
            Library:Notify({ Title = "Hitbox Visualizer", Description = "Circle View Enabled", Time = 2 })
        else
            cleanupHitbox()
            Library:Notify({ Title = "Hitbox Visualizer", Description = "Disabled", Time = 2 })
        end
    end,
})


HitboxRight:AddLabel("Helpful Brick (Map)")


HitboxRight:AddToggle("BlocksToggle", {
	Text = "Brick assist (Double Decker)",
	Default = false,
	Callback = function(state)
		blocksEnabled = state
		setupBlocks()
	end
})


--================================================================--
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
