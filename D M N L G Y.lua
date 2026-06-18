--================================================================--
--                             VGXMOD HUB
--================================================================--



print("------------------------------------------------------------------")
print("Load ................................ Armor V5")
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
-- CORE SERVICES & VARIABLES
--================================================================--
local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local Lighting      = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP            = Players.LocalPlayer

local CheckSpeedNum = 1
local LightToggleStatus = false
local IsEscapeHunt = false
local AutoSpiritBoxToggle = false
local PlayersEspToggle = false
local ItemEspToggle = false
local EvidenceEspToggle = false
local FullBrightToggle = false
local NoclipToggle = false
local SelectedCustomSpeed = nil

local ItemEspList = {}
local EvidenceEspList = {}
local LowestTemp = 100
local LowestTempRoom = nil
local HighestEMFLevel = 1
local db = false

-- Permanent Milestones Speed Color Memory
local hasReachedYellow = false
local hasReachedGreen = false

local BillboardGui = Instance.new("BillboardGui")
local TextLabel = Instance.new("TextLabel")
local HL = Instance.new("Highlight")
BillboardGui.Enabled = false
HL.Enabled = false

-- Monospace Sono Font Config
local SonoFont = Font.new("rbxassetid://12187362578")

local OldLightingList = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	GlobalShadows = Lighting.GlobalShadows,
	FogEnd = Lighting.FogEnd
}

--================================================================--
-- UTILITY FUNCTIONS
--================================================================--
local function CheckInventory(ItemName)
	local Found = false
	local InvSlotNum = nil
	for _, obj in ipairs(LP.PlayerGui.Hotbar.Slots:GetChildren()) do
		if obj:IsA("Frame") and string.find(string.lower(obj.Name), "invslot") then
			if obj.ItemName.Text == ItemName then
				Found = true
				local str = obj.Name
				InvSlotNum = tonumber(str:match("%d+"))
			end
		end
	end
	return Found, InvSlotNum
end

local function FindItem(ItemName)
	local Found = false
	local Model = nil
	local ItemFolder = Workspace.Items
	for _, v in pairs(ItemFolder:GetChildren()) do
		if v:IsA("Model") and v:GetAttribute("ItemName") then
			if v:GetAttribute("ItemName") == ItemName then
				Found = true
				Model = v
			end
		end
	end
	return Found, Model
end

local function ActiveItem()
	local ItemModel = nil
	local Chara = LP.Character
	if Chara then
		for _, v in pairs(Chara:GetChildren()) do
			if v:IsA("Model") or tonumber(v.Name) then
				ItemModel = v
				if v:GetAttribute("Enabled") ~= true then
					local Handle = v:FindFirstChild("Handle")
					if Handle then
						ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToggleItemState"):FireServer(ItemModel)
						break
					end
				end
			end
		end
	end
	return true, ItemModel
end

local function EquipItem(SlotNum)
	ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestItemEquip"):FireServer("InvSlot" .. tostring(SlotNum))
	return true
end

local function PickupItem(Model)
	ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestItemPickup"):FireServer(Model)
	return true
end

local function DropItem(SlotNum)
	ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestItemDrop"):FireServer("InvSlot" .. tostring(SlotNum))
	return true
end

local function teleportTo(position)
	local char = LP.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(position) + Vector3.new(0, 3, 0)
	end
end

local function TpOutside()
	local success, err = pcall(function()
		local pegboard = Workspace:WaitForChild("Map"):WaitForChild("Rooms"):WaitForChild("Base Camp"):WaitForChild("Pegboard")
		local union = pegboard:FindFirstChild("Union")
		if union then
			teleportTo(union.Position)
		end
	end)
	if not success then warn("Hunt TP failed:", err) end
end

local function GhostHuntingInfo()
	game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Ghost hunting!", Text = "This action cannot be performed.", Duration = 3})
end

--================================================================--
-- GAME DETECTION LOGIC
--================================================================--
local ghostModel = Workspace:WaitForChild("Ghost", 15)
local roomsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Rooms")

local function TrackTemp()
	local Temp = 100
	local TempRoom = nil
	if roomsFolder then
		for _, room in ipairs(roomsFolder:GetChildren()) do
			if room:GetAttribute("Temperature") ~= nil then
				if room:GetAttribute("Temperature") < Temp then
					Temp = room:GetAttribute("Temperature")
					TempRoom = room
				end
			end
		end
	end
	return Temp, TempRoom
end

local function CheckHandprints()
	local found = false
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name == "Handprint1" or obj.Name == "Handprint2" or obj.Name == "Footprint" or obj.Name == "Footprint1") then
			found = true
		end
	end
	return found
end

local function CheckGhostOrb()
	local found = false
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "GhostOrb" then
			found = true
			break
		end
	end
	return found
end

local function CheckEMF()
	local Level = 0
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Folder") and obj.Name == "Indicators" then
			for _, v in pairs(obj:GetChildren()) do
				if v:IsA("BasePart") and v.Material == Enum.Material.Neon and tonumber(v.Name) > Level then
					Level = tonumber(v.Name)
				end
			end
		end
	end
	return Level
end

local function CheckWither()
	local Found = false
	if Workspace:FindFirstChild("Items") then
		for _, obj in ipairs(Workspace.Items:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name == "Petals" then
				if obj.Color == Color3.new(0,0,0) then
					Found = true
				end
			end
		end
	end
	return Found
end

local function CheckGhostWriting()
	local Found = false
	if Workspace:FindFirstChild("Items") then
		for _, obj in ipairs(Workspace.Items:GetDescendants()) do
			if obj:IsA("Decal") then
				local Model = obj:FindFirstAncestorWhichIsA("Model")
				if Model and Model:GetAttribute("ItemName") == "Spirit Book" then
					if obj.Texture ~= "" then
						Found = true
					end
				end
			end
		end
	end
	return Found
end

local function CheckSpiritBox()
	local Found = false
	if LP.PlayerGui:FindFirstChild("Subtitles") then
		local GhostText = LP.PlayerGui.Subtitles.Holder.TextLabel.Text
		if #GhostText:gsub("%s+", "") >= 3 then
			Found = true
		end
	end
	return Found
end

--================================================================--
-- ESP & SYSTEMS METHODS
--================================================================--
local AlreadyCreated = false
local function CreateGhostEsp(state)
	if not ghostModel then return end
	if not AlreadyCreated then
		AlreadyCreated = true
		BillboardGui = Instance.new("BillboardGui")
		TextLabel = Instance.new("TextLabel")
		HL = Instance.new("Highlight")

		BillboardGui.Parent = game:GetService("CoreGui")
		BillboardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		BillboardGui.Active = true
		BillboardGui.AlwaysOnTop = true
		BillboardGui.Size = UDim2.new(0, 250, 0, 70) 
		BillboardGui.LightInfluence = 0
		BillboardGui.Brightness = 1
		BillboardGui.Adornee = ghostModel
		BillboardGui.StudsOffset = Vector3.new(0, 4.5, 0)

		TextLabel.Parent = BillboardGui
		TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TextLabel.BackgroundTransparency = 1.000
		TextLabel.Size = UDim2.new(1, 0, 1, 0)
		TextLabel.FontFace = SonoFont
		TextLabel.Text = "Ghost\n[Speed: 0.0]"
		TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255) 
		TextLabel.TextSize = 18
		TextLabel.TextScaled = false
		TextLabel.TextStrokeTransparency = 0
		TextLabel.RichText = true

		HL.Parent = ghostModel
		HL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		HL.OutlineColor = Color3.fromRGB(255, 0, 0)
		HL.FillTransparency = 1
		HL.OutlineTransparency = 0
		HL.Adornee = ghostModel
	end
	BillboardGui.Enabled = state
	HL.Enabled = state
end

local function UpdatePlrEsp()
	if PlayersEspToggle then
		for _, plr in pairs(Players:GetPlayers()) do
			if plr.Character then
				local HumanoidRootPart = plr.Character:FindFirstChild("HumanoidRootPart")
				if HumanoidRootPart then
					local Esp1 = HumanoidRootPart:FindFirstChild("Ducko355PlrBil")
					local Esp2 = HumanoidRootPart:FindFirstChild("Ducko355PlrEsp")

					if plr:GetAttribute("Dead") == true then
						for _, v in pairs(plr.Character:GetDescendants()) do
							if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Transparency = 0 end
							if v.Name == "Ducko355PlrBil" then
								local Txt = v:FindFirstChild("TextLabel")
								if Txt then Txt.Text = plr.DisplayName .. "(Dead)" end
							end
						end
					end

					if not Esp1 and not Esp2 then
						local BGui = Instance.new("BillboardGui")
						local Txt = Instance.new("TextLabel")
						local HLight = Instance.new("Highlight")

						BGui.Name = "Ducko355PlrBil"
						BGui.Parent = HumanoidRootPart
						BGui.AlwaysOnTop = true
						BGui.Size = UDim2.new(0, 100, 0, 40)
						BGui.Adornee = HumanoidRootPart
						BGui.StudsOffset = Vector3.new(0, 4.5, 0)

						Txt.Parent = BGui
						Txt.BackgroundTransparency = 1
						Txt.Size = UDim2.new(1, 0, 1, 0)
						Txt.TextColor3 = Color3.fromRGB(255, 255, 255)
						Txt.FontFace = SonoFont
						Txt.TextScaled = true
						Txt.TextStrokeTransparency = 0
						Txt.Text = plr.DisplayName

						HLight.Name = "Ducko355PlrEsp"
						HLight.Parent = HumanoidRootPart
						HLight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						HLight.OutlineColor = Color3.fromRGB(255, 255, 255)
						HLight.FillTransparency = 1
						HLight.Adornee = plr.Character
					end
				end
			end
		end
	else
		for _, plr in pairs(Players:GetPlayers()) do
			if plr.Character then
				local HumanoidRootPart = plr.Character:FindFirstChild("HumanoidRootPart")
				if HumanoidRootPart then
					local Esp1 = HumanoidRootPart:FindFirstChild("Ducko355PlrBil")
					local Esp2 = HumanoidRootPart:FindFirstChild("Ducko355PlrEsp")
					if Esp1 then Esp1:Destroy() end
					if Esp2 then Esp2:Destroy() end
				end
			end
		end
	end
end

local function UpdateEvidenceEsp()
	for _, v in pairs(EvidenceEspList) do
		pcall(function() v:Destroy() end)
	end
	table.clear(EvidenceEspList)

	if EvidenceEspToggle then
		if Workspace:FindFirstChild("Handprints") then
			for _, obj in ipairs(Workspace.Handprints:GetDescendants()) do
				if obj:IsA("BasePart") then
					local BGui = Instance.new("BillboardGui")
					table.insert(EvidenceEspList, BGui)

					BGui.Name = "Ducko355HandprintsBil"
					BGui.Parent = game:GetService("CoreGui")
					BGui.AlwaysOnTop = true
					BGui.Size = UDim2.new(1, 0, 1, 0)
					BGui.Adornee = obj
					BGui.StudsOffset = Vector3.new(0, 1, 0)

					local ImageLabelFromSG = nil
					for _, v in pairs(obj:GetDescendants()) do
						if v:IsA("ImageLabel") then ImageLabelFromSG = v:Clone() end
					end

					if ImageLabelFromSG then
						ImageLabelFromSG.Parent = BGui
						ImageLabelFromSG.BackgroundTransparency = 1
						ImageLabelFromSG.Size = UDim2.new(1, 0, 1, 0)
					end
				end
			end
		end

		local GhostOrbPart = nil
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name == "GhostOrb" then
				GhostOrbPart = obj
				GhostOrbPart.Transparency = 0
				break
			end
		end

		if GhostOrbPart then
			local BGui = Instance.new("BillboardGui")
			local Txt = Instance.new("TextLabel")
			local HLight = Instance.new("Highlight")
			table.insert(EvidenceEspList, BGui)
			table.insert(EvidenceEspList, HLight)

			BGui.Name = "Ducko355OrbBil"
			BGui.Parent = game:GetService("CoreGui")
			BGui.AlwaysOnTop = true
			BGui.Size = UDim2.new(0, 100, 0, 40)
			BGui.Adornee = GhostOrbPart

			Txt.Parent = BGui
			Txt.BackgroundTransparency = 1
			Txt.Size = UDim2.new(1, 0, 1, 0)
			Txt.TextColor3 = Color3.fromRGB(255, 255, 255)
			Txt.FontFace = SonoFont
			Txt.TextSize = 14
			Txt.TextScaled = false
			Txt.TextStrokeTransparency = 0
			Txt.Text = "Orb"

			HLight.Name = "Ducko355OrbEsp"
			HLight.Parent = game:GetService("CoreGui")
			HLight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			HLight.Adornee = GhostOrbPart
		end
	end
end

local function FireSpiritBox()
	local args = {"Are you far away?", "Are you near?", "Where are you?", "What do you want?", "When did you cross over?", "Are you in the room with me?", "Do you want us to leave?", "When did you pass away?", "What is your goal?", "Why are you here?", "How long ago did you die?", "Is there a ghost here?"}
	ReplicatedStorage:WaitForChild("Events"):WaitForChild("AskSpiritBoxFromUI"):FireServer(args[math.random(1, #args)])
end

local DelaySBTick = tick()
local function UseSpiritBox()
	if not ghostModel then return end
	local Chara = LP.Character
	if Chara and AutoSpiritBoxToggle and ghostModel:GetAttribute("Hunting") ~= true then
		Chara:PivotTo(ghostModel:GetPivot() * CFrame.new(0, 0, 10))
	elseif Chara and AutoSpiritBoxToggle then
		TpOutside()
	end

	if tick() - DelaySBTick > 0.5 and AutoSpiritBoxToggle and ghostModel:GetAttribute("Hunting") ~= true then
		DelaySBTick = tick()
		local Found, InvSlotNum = CheckInventory("Spirit Box")
		if not Found then
			local FoundBox, Model = FindItem("Spirit Box")
			if FoundBox and Model then
				PickupItem(Model)
				task.wait(0.35)
				ActiveItem()
				task.wait(0.5)
				local FoundAgain, InvSlotNumAgain = CheckInventory("Spirit Box")
				if FoundAgain then
					EquipItem(InvSlotNumAgain)
					task.wait(0.5)
					FireSpiritBox()
				end
			end
		else
			EquipItem(InvSlotNum)
			task.wait(0.35)
			ActiveItem()
			task.wait(0.35)
			FireSpiritBox()
		end
	end
end

--================================================================--
-- NOCLIP STEPPED CONNECTION (FIXED TURN OFF)
--================================================================--
RunService.Stepped:Connect(function()
	if LP.Character then
		for _, part in ipairs(LP.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				if NoclipToggle then
					if part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end
	end
end)

--================================================================--
-- GHOET VISIBILITY 
--================================================================--

local GHOST_NAME = "Ghost"
local TARGET_FOLDER = "VisibleParts"
local ghostLoopConnection = nil

local function toggleGhostVisibility(state)
	if state then
		if ghostLoopConnection then ghostLoopConnection:Disconnect() end
		
		ghostLoopConnection = RunService.Heartbeat:Connect(function()
			local ghost = workspace:FindFirstChild(GHOST_NAME)
			if ghost then
				for _, child in ipairs(ghost:GetDescendants()) do
					if (child:IsA("Script") or child:IsA("LocalScript")) and not child.Disabled then
						child.Disabled = true
					end
				end

				local visiblePartsFolder = ghost:FindFirstChild(TARGET_FOLDER)
				if visiblePartsFolder then
					for _, part in ipairs(visiblePartsFolder:GetDescendants()) do
						if part:IsA("BasePart") and part.Transparency ~= 0 then
							part.Transparency = 0
						end
					end
				end
			end
		end)
	else
		if ghostLoopConnection then
			ghostLoopConnection:Disconnect()
			ghostLoopConnection = nil
		end
		
		local ghost = workspace:FindFirstChild(GHOST_NAME)
		if ghost then
			for _, child in ipairs(ghost:GetDescendants()) do
				if child:IsA("Script") or child:IsA("LocalScript") then
					child.Disabled = false
				end
			end
			
			local visiblePartsFolder = ghost:FindFirstChild(TARGET_FOLDER)
			if visiblePartsFolder then
				for _, part in ipairs(visiblePartsFolder:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Transparency = 0
					end
				end
			end
		end
	end
end


--================================================================--
-- GUI: CREATE WINDOW & MAIN ELEMENTS
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "DEMONOLOGY",
    Icon = 94858886314945,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

--================================================================--
-- INFO TAB
--================================================================--
local InfoTab = Window:AddTab("Info", "info")
local InfoLeft = InfoTab:AddLeftGroupbox("Credits")
local InfoRight = InfoTab:AddRightGroupbox("Links & Instructions")

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
-- EVIDENCE DASHBOARD TAB
--================================================================--
local DevTab = Window:AddTab("Evidence Monitor", "eye")
local EvLeft = DevTab:AddLeftGroupbox("EVIDENCE STATS")
local GameLeft = DevTab:AddRightGroupbox("GHOST LOGS")

local LabelHand = EvLeft:AddLabel("Handprints: No")
local LabelTemp = EvLeft:AddLabel("Temperature: 0C")
local LabelOrb = EvLeft:AddLabel("Ghost Orb: No")
local LabelSpirit = EvLeft:AddLabel("Spirit Box: No")
local LabelEmf = EvLeft:AddLabel("EMF level: 0")
local LabelWriting = EvLeft:AddLabel("Ghost Writing: No")
local LabelLaser = EvLeft:AddLabel("Laser Projector: No")
local LabelWither = EvLeft:AddLabel("Wither: No")

local LabelGhostGender = GameLeft:AddLabel("Ghost: Unknown")
local LabelGhostAge    = GameLeft:AddLabel("Age: Unknown")
local LabelGhostHunt   = GameLeft:AddLabel("Hunting: No")
local LabelRoom        = GameLeft:AddLabel("Current room: ...")
GameLeft:AddDivider()
local LabelGhostFav    = GameLeft:AddLabel("Favorite room: ...")
local LabelGhostType    = GameLeft:AddLabel("Ghost Type: ...")
local LabelDiff        = GameLeft:AddLabel("Difficulty: Unknown")
local LabelPhotos      = GameLeft:AddLabel("Photos Taken: (0/6)")

--================================================================--
-- MAIN CONTROLS TAB
--================================================================--
local MainTab = Window:AddTab("Main Controls", "house")
local AutoLeft = MainTab:AddLeftGroupbox("AUTOMATION", "cpu")
local PlayerLeft = MainTab:AddLeftGroupbox("PLAYER MODS", "user")
local EspBox = MainTab:AddRightGroupbox("ESP", "eye")
local MiscBox = MainTab:AddRightGroupbox("MISCELLANEOUS")

AutoLeft:AddToggle("EscapeHuntToggle", {
    Text = "Auto Escape Hunt",
    Default = false,
    Callback = function(state)
        IsEscapeHunt = state
		if IsEscapeHunt and ghostModel and ghostModel:GetAttribute("Hunting") then
			TpOutside()
		end
    end
})

AutoLeft:AddToggle("AutoSpiritToggle", {
    Text = "Auto Spirit Box",
    Default = false,
    Callback = function(state)
        AutoSpiritBoxToggle = state
		if not state then
			task.wait(0.2)
			TpOutside()
		end
    end
})

AutoLeft:AddButton({
	Text = "Dump & Place items near ghost",
	Func = function()
		if (ghostModel and ghostModel:GetAttribute("Hunting") == true) or db == true then
			GhostHuntingInfo()
			return
		end
		db = true
		local Chara = LP.Character
		if Chara and ghostModel then Chara:PivotTo(ghostModel:GetPivot()) end
		
		task.wait(0.1) EquipItem(1) task.wait(0.1) DropItem(1)
		task.wait(0.1) EquipItem(1) task.wait(0.1) DropItem(1)
		task.wait(0.1) EquipItem(1) task.wait(0.1) DropItem(1)
		task.wait(0.2)

		local F, M = FindItem("Cross") if F then PickupItem(M) end
		task.wait(0.35) F, M = FindItem("Cross") if F then PickupItem(M) end
		task.wait(0.35) F, M = FindItem("Flower Pot") if F then PickupItem(M) end
		task.wait(0.5)

		EquipItem(1) task.wait(0.35) ActiveItem() task.wait(0.35) DropItem(1)
		task.wait(0.35) EquipItem(1) task.wait(0.35) ActiveItem() task.wait(0.35) DropItem(1)
		task.wait(0.35) EquipItem(1) task.wait(0.35) ActiveItem() task.wait(0.35) DropItem(1)
		task.wait(0.5)

		F, M = FindItem("Laser Projector") if F then PickupItem(M) end
		task.wait(0.35) F, M = FindItem("EMF Reader") if F then PickupItem(M) end
		task.wait(0.35) F, M = FindItem("Spirit Book") if F then PickupItem(M) end
		task.wait(0.5)

		EquipItem(1) task.wait(0.6) ActiveItem() task.wait(0.5) DropItem(1)
		task.wait(0.35) EquipItem(1) task.wait(0.6) ActiveItem() task.wait(0.5) DropItem(1)
		task.wait(0.35) EquipItem(1) task.wait(0.35) ActiveItem() task.wait(0.35) DropItem(1)
		task.wait(0.35)
		
		TpOutside()
		db = false
	end
})


PlayerLeft:AddDropdown("WalkSpeedDropdown", {
    Values = { "Normal", "20", "30", "40", "50", "80", "100" },
    Default = 1,
    Multi = false,
    Text = "Custom Speed Hack",
    Callback = function(Value)
		if Value == "Normal" then
			SelectedCustomSpeed = nil
			if LP.Character and LP.Character:FindFirstChild("Humanoid") then
				LP.Character.Humanoid.WalkSpeed = 16
			end
		else
			SelectedCustomSpeed = tonumber(Value)
			if LP.Character and LP.Character:FindFirstChild("Humanoid") then
				LP.Character.Humanoid.WalkSpeed = SelectedCustomSpeed
			end
		end
    end
})

PlayerLeft:AddToggle("NoclipToggleOption", {
	Text = "Noclip",
	Default = false,
	Callback = function(state)
		NoclipToggle = state
		if not state and LP.Character then
			for _, part in ipairs(LP.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
	end
})

PlayerLeft:AddToggle("FullBrightToggleOption", {
    Text = "Full Bright",
    Default = false,
    Callback = function(state)
        FullBrightToggle = state
		if FullBrightToggle then
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
			Lighting.Brightness = 3
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 100000
		else
			Lighting.Ambient = OldLightingList.Ambient
			Lighting.OutdoorAmbient = OldLightingList.OutdoorAmbient
			Lighting.Brightness = OldLightingList.Brightness
			Lighting.GlobalShadows = OldLightingList.GlobalShadows
			Lighting.FogEnd = OldLightingList.FogEnd
		end
    end
})

PlayerLeft:AddButton({
	Text = "TP Spawn",
	Func = function()
		local map = Workspace:FindFirstChild("Map")
		local spawns = map and map:FindFirstChild("Spawns")
		local spawnLoc = spawns and spawns:FindFirstChild("SpawnLocation")
		if spawnLoc and spawnLoc:IsA("BasePart") then
			teleportTo(spawnLoc.Position)
		else
			warn("SpawnLocation path configuration is missing or broken.")
		end
	end
})

PlayerLeft:AddButton({
	Text = "TP Ghost Favorite Room",
	Func = function()
		if ghostModel then
			local favRoomName = ghostModel:GetAttribute("FavoriteRoom")
			if favRoomName and roomsFolder then
				local targetRoom = roomsFolder:FindFirstChild(tostring(favRoomName))
				if targetRoom then
					-- Targets internal center anchors or falls back cleanly to room root
					local center = targetRoom:FindFirstChild("Center") or targetRoom:FindFirstChild("RoomCenter") or targetRoom:FindFirstChildWhichIsA("BasePart")
					if center then
						teleportTo(center.Position)
					else
						teleportTo(targetRoom:GetPivot().Position)
					end
				else
					warn("Target Favorite Room object not discovered in game rooms folder.")
				end
			else
				warn("Ghost FavoriteRoom attribute is missing or empty.")
			end
		else
			warn("Ghost model instance could not be resolved.")
		end
	end
})

EspBox:AddToggle("GhostVisibilityToggle", {
	Text = "Permanent Ghost Visibility",
	Default = false,
	Callback = function(Value)
		toggleGhostVisibility(Value)
	end,
})

EspBox:AddToggle("GhostEspOpt", {
    Text = "Ghost ESP",
    Default = true, 
    Callback = function(state)
        CreateGhostEsp(state)
    end
})

EspBox:AddToggle("PlayersEspOpt", {
    Text = "Players ESP",
    Default = false,
    Callback = function(state)
        PlayersEspToggle = state
		UpdatePlrEsp()
    end
})

EspBox:AddToggle("EvidenceEspOpt", {
    Text = "Evidence ESP",
    Default = false,
    Callback = function(state)
        EvidenceEspToggle = state
		UpdateEvidenceEsp()
    end
})

EspBox:AddToggle("ItemEspOpt", {
	Text = "Item ESP",
	Default = false,
	Callback = function(state)
		ItemEspToggle = state
		if ItemEspToggle then
			for _, v in pairs(Workspace:GetDescendants()) do
				if v:IsA("Model") and v:GetAttribute("ItemName") ~= nil then
					local BGui = Instance.new("BillboardGui")
					local Txt = Instance.new("TextLabel")
					local HLight = Instance.new("Highlight")
					
					table.insert(ItemEspList, BGui)
					table.insert(ItemEspList, HLight)

					BGui.Name = "Ducko355ItemBil"
					BGui.Adornee = v
					BGui.Parent = v
					BGui.AlwaysOnTop = true
					BGui.Size = UDim2.new(0, 100, 0, 30)
					BGui.StudsOffset = Vector3.new(0, 1.5, 0)

					Txt.Parent = BGui
					Txt.BackgroundTransparency = 1
					Txt.Size = UDim2.new(1, 0, 1, 0)
					Txt.FontFace = SonoFont
					Txt.Text = v:GetAttribute("ItemName")
					Txt.TextColor3 = Color3.fromRGB(0, 255, 255)
					Txt.TextSize = 14
					Txt.TextScaled = false
					Txt.TextStrokeTransparency = 0

					HLight.Name = "Ducko355ItemEsp"
					HLight.Parent = v
					HLight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					HLight.OutlineColor = Color3.fromRGB(0, 255, 255)
					HLight.FillTransparency = 1
					HLight.Adornee = v
				end
			end
		else
			for _, v in pairs(ItemEspList) do pcall(function() v:Destroy() end) end
			table.clear(ItemEspList)
		end
	end
})

MiscBox:AddButton({
	Text = "Turn On Fuse",
	Func = function()
		ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToggleFuseBox"):FireServer()
	end
})

MiscBox:AddButton({
	Text = "Toggle All Lights",
	Func = function()
		LightToggleStatus = not LightToggleStatus
		local Rooms = Workspace:WaitForChild("Map"):WaitForChild("Rooms")
		for _, Room in pairs(Rooms:GetChildren()) do
			if Room:GetAttribute("LightsOn") ~= LightToggleStatus then
				ReplicatedStorage:WaitForChild("Events"):WaitForChild("UseLightSwitch"):FireServer(Room)
			end
		end
	end
})

MiscBox:AddDropdown("RefreshTickRate", {
    Values = { "0", "0.1", "0.2", "0.5", "1", "1.5", "2", "5", "10" },
    Default = 5,
    Multi = false,
    Text = "Monitoring Refresh Rate",
    Callback = function(Value)
        CheckSpeedNum = tonumber(Value)
    end
})

local FavRoomTab1 = Window:AddTab("Fav Room", "file-plus")
local FavRoomTab2 = FavRoomTab1:AddLeftGroupbox("Juniper Road", "cpu")

FavRoomTab2:AddDropdown("JuniperOfficeDropdown", {
	Values = { "Banshee", "Specter", "Spirit", "Umbra" },
	Default = 1,
	Multi = false,
	Text = "Office",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab2:AddDropdown("JuniperKitchenDropdown", {
	Values = { "Aswang", "The wisp", "Dybukk", "Siren" },
	Default = 1,
	Multi = false,
	Text = "Kitchen",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab2:AddDropdown("JuniperPantryDropdown", {
	Values = { "Revenant", "Leviathan", "Umbra", "Siren" },
	Default = 1,
	Multi = false,
	Text = "Pantry",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab2:AddDropdown("JuniperLivingRoomDropdown", {
	Values = { "Kares", "Vex", "Dullahan", "Aswang" },
	Default = 1,
	Multi = false,
	Text = "Living room",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab2:AddDropdown("JuniperBedroomDropdown", {
	Values = { "Demon", "Wendigo", "Wriath", "Entity" },
	Default = 1,
	Multi = false,
	Text = "Bedroom",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab2:AddDropdown("JuniperLaundryDropdown", {
	Values = { "Nightmare", "Ghoul", "Entity", "Oni", "Spirit" },
	Default = 1,
	Multi = false,
	Text = "Laundry",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab2:AddDropdown("JuniperBathroomDropdown", {
	Values = { "Shadow", "Oni", "Phantom", "Skinwalker" },
	Default = 1,
	Multi = false,
	Text = "Bathroom",
	Searchable = true,
	Callback = function(Value) end,
})

local FavRoomTab = FavRoomTab1:AddRightGroupbox("Prison", "cpu")

FavRoomTab:AddDropdown("VisitorCenterDropdown", {
	Values = { "Ghoul", "Entity" },
	Default = 1,
	Multi = false,
	Text = "VISITOR CENTER",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("InfirmaryDropdown", {
	Values = { "The wisp", "Dybukk", "Siren", "Kares" },
	Default = 1,
	Multi = false,
	Text = "INFIRMARY",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("GuardStorageDropdown", {
	Values = { "Aswang", "Dybukk", "Kares", "Dullhan" },
	Default = 1,
	Multi = false,
	Text = "GUARD QUARTER",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("BathroomDropdown", {
	Values = { "Banshee", "Umbra", "Leviathan" },
	Default = 1,
	Multi = false,
	Text = "BATHROOM",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("ShowerDropdown", {
	Values = { "Leviathan", "Revenant" },
	Default = 1,
	Multi = false,
	Text = "SHOWER",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("CafeteriaDropdown", {
	Values = { "Specter", "Skinwalker", "Banshee" },
	Default = 1,
	Multi = false,
	Text = "CAFETERIA",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("CellsDropdown", {
	Values = { "Spirit", "Specter", "Banshee" },
	Default = 1,
	Multi = false,
	Text = "CELLS",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("LoungeDropdown", {
	Values = { "Nightmare", "Ghoul" },
	Default = 1,
	Multi = false,
	Text = "LOUNGE",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("ControlRoomDropdown", {
	Values = { "Dullhan", "Aswang", "Siren", "Kares" },
	Default = 1,
	Multi = false,
	Text = "CONTROL ROOM",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("StorageRoom1Dropdown", {
	Values = { "Leviathan", "Siren" },
	Default = 1,
	Multi = false,
	Text = "STORAGE ROOM 1",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("StorageRoom2Dropdown", {
	Values = { "Vex", "Kares" },
	Default = 1,
	Multi = false,
	Text = "STORAGE ROOM 2",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("KitchenDropdown", {
	Values = { "Shadow", "Phantom", "Skinwalker" },
	Default = 1,
	Multi = false,
	Text = "KITCHEN",
	Searchable = true,
	Callback = function(Value) end,
})

FavRoomTab:AddDropdown("OfficeDropdown", {
	Values = { "Demon", "Wendigo", "Wraith" },
	Default = 1,
	Multi = false,
	Text = "OFFICE",
	Searchable = true,
	Callback = function(Value) end,
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

--================================================================--
-- ACTIVE HEARTBEAT TRACKING LOOPS
--================================================================--
Workspace.DescendantAdded:Connect(function(descendant)
	if IsEscapeHunt and descendant:IsA("Sound") and descendant.Name == "Hunt" then
		TpOutside()
	end
end)

if Workspace:FindFirstChild("Handprints") then
	Workspace.Handprints.ChildAdded:Connect(function()
		UpdateEvidenceEsp()
	end)
end

-- TRACK HUMANOID WALKSPEED DIRECTLY (NO SCRIPT DELTA CALCULATIONS / NO SPIKES)
local function GetGhostVelocity()
	if ghostModel then
		local hum = ghostModel:FindFirstChildWhichIsA("Humanoid")
		if hum then
			return hum.WalkSpeed
		end
	end
	return 0.0
end

-- FORCE LOAD & ENABLE GHOST ESP BY DEFAULT
task.spawn(function()
	task.wait(1)
	if Toggles.GhostEspOpt then
		Toggles.GhostEspOpt:SetValue(true)
	else
		CreateGhostEsp(true)
	end
end)

local OldTick = tick()
RunService.Heartbeat:Connect(function()
	UseSpiritBox()
	
	if SelectedCustomSpeed and LP.Character and LP.Character:FindFirstChild("Humanoid") then
		if LP.Character.Humanoid.WalkSpeed ~= SelectedCustomSpeed then
			LP.Character.Humanoid.WalkSpeed = SelectedCustomSpeed
		end
	end

	-- Live Frame-Perfect Text Rendering
	if ghostModel and TextLabel and TextLabel:IsA("TextLabel") and BillboardGui.Enabled then
		local rawSpeed = GetGhostVelocity()
		
		if rawSpeed >= 29.0 then
			hasReachedGreen = true
		elseif rawSpeed >= 24.0 then
			hasReachedYellow = true
		end

		-- Process Bracket Speed Memory Colors
		local speedHexColor = "rgb(255, 255, 255)" 
		if hasReachedGreen then
			speedHexColor = "rgb(0, 255, 0)"     
		elseif hasReachedYellow then
			speedHexColor = "rgb(255, 255, 0)"   
		end

		-- Process Prefix Warning Text
		local statusText = "Ghost"
		if ghostModel:GetAttribute("Hunting") == true then
			statusText = '<font color="rgb(255, 0, 0)">HUNTING</font>'
		end

		TextLabel.Text = string.format('%s\n<font color="%s">[Speed: %.1f]</font>', statusText, speedHexColor, rawSpeed)
	end

	if tick() - OldTick > CheckSpeedNum then
		OldTick = tick()
		
		if Workspace:GetAttribute("Difficulty") then
			LabelDiff:SetText("Difficulty: " .. tostring(Workspace:GetAttribute("Difficulty")))
		end
		if Workspace:GetAttribute("PhotosTaken") then
			LabelPhotos:SetText("Photos Taken: (" .. tostring(Workspace:GetAttribute("PhotosTaken")) .. "/6)")
		end
		
		UpdatePlrEsp()

		local Temp, TempRoom = TrackTemp()
		local HandprintsCheck = CheckHandprints()
		local GhostOrbCheck = CheckGhostOrb()
		local EMFLevelCheck = CheckEMF()
		local WitherCheck = CheckWither()
		local SpiritBoxCheck = CheckSpiritBox()
		local GhostWritingCheck = CheckGhostWriting()

		if ghostModel then
			local GhostHunting = ghostModel:GetAttribute("Hunting")
			local GhostFavRoom = ghostModel:GetAttribute("FavoriteRoom")
			local GhostCurrentRoom = ghostModel:GetAttribute("CurrentRoom")
			local GhostAge = ghostModel:GetAttribute("Age")
			local GhostGender = ghostModel:GetAttribute("Gender")
			local InLaser = ghostModel:GetAttribute("InLaser")

			if GhostGender then
				LabelGhostGender:SetText("Ghost: " .. tostring(GhostGender))
			else
				LabelGhostGender:SetText("Ghost: Unknown")
			end

			if GhostAge then
				LabelGhostAge:SetText("Age: " .. tostring(GhostAge))
			else
				LabelGhostAge:SetText("Age: Unknown")
			end

			if GhostHunting == true then
				LabelGhostHunt:SetText("Hunting: yes")
			else
				LabelGhostHunt:SetText("Hunting: no")
			end

			if GhostCurrentRoom then
				LabelRoom:SetText("Current room: " .. tostring(GhostCurrentRoom))
			else
				LabelRoom:SetText("Current room: ...")
			end

			if GhostFavRoom then
				LabelGhostFav:SetText("Favorite room: " .. tostring(GhostFavRoom))
			end

			if InLaser then
				LabelLaser:SetText("Laser Projector: Yes")
			end
		end

		if Temp and TempRoom then
			if Temp < LowestTemp then
				LowestTemp = Temp
				LowestTempRoom = TempRoom
				LabelTemp:SetText(string.format("Temperature: %.1f°C", LowestTemp) .. " (" .. tostring(LowestTempRoom.Name) .. ")")
			end
		end

		if HandprintsCheck then LabelHand:SetText("Handprints: Yes") end
		if GhostOrbCheck then LabelOrb:SetText("GhostOrb: Yes") end
		if SpiritBoxCheck then LabelSpirit:SetText("Spirit Box: Yes") end
		if GhostWritingCheck then LabelWriting:SetText("Ghost Writing: Yes") end
		if WitherCheck then LabelWither:SetText("Wither: Yes") end

		if EMFLevelCheck > HighestEMFLevel then
			HighestEMFLevel = EMFLevelCheck
			LabelEmf:SetText("EMF level: " .. tostring(HighestEMFLevel))
		else
			LabelEmf:SetText("EMF level: " .. tostring(HighestEMFLevel))
		end
	end
end)

task.spawn(function()
	task.wait(30)
	for _, v in pairs(Workspace:GetDescendants()) do
		if v:IsA("Model") and v.Name == "ExitDoor" then
			if v:GetAttribute("DoorClosed") ~= false then
				ReplicatedStorage:WaitForChild("Events"):WaitForChild("ClientChangeDoorState"):FireServer(v:WaitForChild("Door"))
			else
				break
			end
		end
	end
end)
