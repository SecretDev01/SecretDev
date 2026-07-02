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
print("[Vgxmod Hub] Loading libraries...")

local Library, ThemeManager, SaveManager

local success, err = pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/SecretDev01/C-L-V/refs/heads/main/Custom/Library.lua"))()
    print("[Vgxmod Hub] Library loaded.")

    ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/SecretDev01/C-L-V/refs/heads/main/Custom/ThemeManager.lua"))()
    print("[Vgxmod Hub] ThemeManager loaded.")

    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/SecretDev01/C-L-V/refs/heads/main/Custom/SaveManager.lua"))()
    print("[Vgxmod Hub] SaveManager loaded.")
end)

if not success then
    warn("[Vgxmod Hub] Failed to load libraries: " .. tostring(err))
    return
end

print("[Vgxmod Hub] All libraries loaded successfully.")

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
local TweenService = game:GetService("TweenService")


local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

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
-- MAIN CONTROLS TAB
--================================================================--
local MainTab = Window:AddTab("Main", "house")
local AutoLeft = MainTab:AddLeftGroupbox("AUTOMATION", "cpu")
local PlayerLeft = MainTab:AddLeftGroupbox("PLAYER MODS", "user")
local EspBox = MainTab:AddRightGroupbox("ESP", "eye")

local EmoteBox = MainTab:AddRightGroupbox("EMOTE", "smile")

local EvidenceBox = MainTab:AddRightGroupbox("EVIDENCE", "file-plus")
local MiscBox = MainTab:AddRightGroupbox("MISCELLANEOUS")
--================================================================--
-- EVIDENCE DASHBOARD TAB
--================================================================--
local DevTab = Window:AddTab("Evidence Monitor", "thermometer")
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
-- GHOST INFO
--================================================================--
local MainTab2 = Window:AddTab("Ghost", "sword")
local EvidenceBox2 = MainTab2:AddRightGroupbox("DETECTION", "folder-plus")
local PlayerLeft2 = MainTab2:AddLeftGroupbox("REQUIRED", "file-text")

PlayerLeft2:AddLabel("Requirements needed.")
PlayerLeft2:AddLabel("Only works on Juniper Road.")
PlayerLeft2:AddLabel("Only works on Custom No Evidence.")
PlayerLeft2:AddLabel("Recommended ping: under 90 ms.")
PlayerLeft2:AddLabel("Do not use any speed modifiers.")
PlayerLeft2:AddLabel("Do not use micmicry challenge.")
PlayerLeft2:AddLabel("Red = Detection is not working.")

local PlayerLeft3 = MainTab2:AddLeftGroupbox("READ ME", "book")

PlayerLeft3:AddLabel("This detection is not 100% accurate.")
PlayerLeft3:AddLabel("Play normally and don't rely on it completely.")
PlayerLeft3:AddLabel("It only detects some ghost types.")
PlayerLeft3:AddLabel("Please read the requirements")





--================================================================--
-- AUTO TAB
--================================================================--

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
--[[
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
]]


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FireSaltShotgun = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FireSaltShotgun")

AutoLeft:AddButton({
	Text = "Shoot Ghost",
	Func = function()
		local ghost = workspace:FindFirstChild("Ghost")
		
		if ghost then
			local targetPart = ghost:FindFirstChild("Left Arm") or ghost:FindFirstChild("HumanoidRootPart")
			
			if targetPart then
				-- Gets the exact position of the ghost right when you click
				local targetPosition = targetPart.Position
				local direction = Vector3.new(-0.204, 0.975, -0.084) 

				local args = {
					[1] = targetPart,
					[2] = targetPosition, 
					[3] = direction
				}

				-- Fires exactly one time per click
				FireSaltShotgun:FireServer(unpack(args))
				print("Gay")
			else
				print("Gay")
			end
		else
			print("Gay")
		end
	end,
})


local MyDisabledButton = AutoLeft:AddButton({
	Text = "Dump & Place items near ghost",
	Func = function()
		
	end,
	DoubleClick = false,
	Tooltip = "This is a disabled button",
	DisabledTooltip = "Disable", -- Information shown when you hover over the button while it's disabled
	Disabled = true,
})










--================================================================--
-- EVIDENCE THROWING 
--================================================================--

local CONFIG = {
    GlassEnabled = true,
    ThrowEnabled = true,
    ScratchEnabled = true,
    NotifyTime = 10,
    GlassRoute = "BrokenGlass",
    ScratchRoute = "ScratchText",
    
    Counters = {
        Glass = 0,
        Throwing = 0,
        Scratch = 0
    },
    
    ActiveNotifications = {
        Glass = nil,
        Throwing = nil,
        Scratch = nil
    }
}

local THROW_IDS = {
    ["9113470969"] = "Body",
    ["9118833449"] = "Book",
    ["9113251349"] = "Cardboard",
    ["9113768979"] = "Chair",
    ["9119920406"] = "Glass Object",
    ["9117450506"] = "Heavy Object",
    ["9113720294"] = "Medium Object",
    ["9116703825"] = "Metal",
    ["9116630454"] = "Metal Can",
    ["9113564136"] = "Plush",
    ["9120885468"] = "Wood"
}

local function getAssetNumber(soundId)
    return soundId:match("%d+")
end

local function clearNotification(typeKey)
    local oldNotify = CONFIG.ActiveNotifications[typeKey]
    if oldNotify then
        if type(oldNotify) == "table" and rawget(oldNotify, "Destroy") then
            oldNotify:Destroy()
        elseif type(oldNotify) == "table" and rawget(oldNotify, "Remove") then
            oldNotify:Remove()
        end
        CONFIG.ActiveNotifications[typeKey] = nil
    end
end

-- =================================================================
-- UI ELEMENTS (Checkboxes)
-- =================================================================

EvidenceBox:AddCheckbox("GlassCheckbox", {
    Text = "Glass Detection",
    Default = CONFIG.GlassEnabled,
    Callback = function(Value)
        CONFIG.GlassEnabled = Value
        Library:Notify({
            Title = "Glass Detector",
            Description = "Detection is now " .. (Value and "Enabled" or "Disabled"),
            Time = CONFIG.NotifyTime,
        })
    end,
})

EvidenceBox:AddCheckbox("ThrowCheckbox", {
    Text = "Throwing Detection",
    Default = CONFIG.ThrowEnabled,
    Callback = function(Value)
        CONFIG.ThrowEnabled = Value
        Library:Notify({
            Title = "Throw Detector",
            Description = "Detection is now " .. (Value and "Enabled" or "Disabled"),
            Time = CONFIG.NotifyTime,
        })
    end,
})

EvidenceBox:AddCheckbox("ScratchCheckbox", {
    Text = "Scratch Detection",
    Default = CONFIG.ScratchEnabled,
    Callback = function(Value)
        CONFIG.ScratchEnabled = Value
        Library:Notify({
            Title = "Scratch Detector",
            Description = "Detection is now " .. (Value and "Enabled" or "Disabled"),
            Time = CONFIG.NotifyTime,
        })
    end,
})
EvidenceBox:AddDivider()
-- =================================================================
-- UI MONITORS (Labels added here)
-- =================================================================
-- Change "EvidenceBox" to "EvLeft" if you want them on the left side instead!
local LabelGlass = EvidenceBox:AddLabel("Total Glass: 0")
local LabelThrow = EvidenceBox:AddLabel("Total Thrown: 0")
local LabelScratch = EvidenceBox:AddLabel("Total Scratches: 0")

-- Helper function to refresh live data on your screen
local function updateLabels()
    LabelGlass:SetText("Total Glass: " .. tostring(CONFIG.Counters.Glass))
    LabelThrow:SetText("Total Thrown: " .. tostring(CONFIG.Counters.Throwing))
    LabelScratch:SetText("Total Scratches: " .. tostring(CONFIG.Counters.Scratch))
end

-- =================================================================
-- DETECTION LOGIC
-- =================================================================

local brokenGlassFolder = Workspace:WaitForChild(CONFIG.GlassRoute, 5)
if brokenGlassFolder then
    brokenGlassFolder.ChildAdded:Connect(function()
        CONFIG.Counters.Glass = CONFIG.Counters.Glass + 1
        updateLabels() -- Update screen UI
        
        if CONFIG.GlassEnabled then
            clearNotification("Glass")
            CONFIG.ActiveNotifications.Glass = Library:Notify({
                Title = "Alert: Broken Glass",
                Description = ("Total Detected: %d"):format(CONFIG.Counters.Glass),
                Time = CONFIG.NotifyTime,
            })
        end
    end)
end

local scratchTextFolder = Workspace:WaitForChild(CONFIG.ScratchRoute, 5)
if scratchTextFolder then
    scratchTextFolder.ChildAdded:Connect(function()
        CONFIG.Counters.Scratch = CONFIG.Counters.Scratch + 1
        updateLabels() -- Update screen UI
        
        if CONFIG.ScratchEnabled then
            clearNotification("Scratch")
            CONFIG.ActiveNotifications.Scratch = Library:Notify({
                Title = "Alert: Scratch Detected",
                Description = ("Total Scratches: %d"):format(CONFIG.Counters.Scratch),
                Time = CONFIG.NotifyTime,
            })
        end
    end)
end

local function checkAndNotifySound(sound)
    if not sound:IsA("Sound") then return end
    
    local idNum = getAssetNumber(sound.SoundId)
    local materialName = THROW_IDS[idNum]
    
    if materialName then
        CONFIG.Counters.Throwing = CONFIG.Counters.Throwing + 1
        updateLabels() -- Update screen UI
        
        if CONFIG.ThrowEnabled then
            clearNotification("Throwing")
            CONFIG.ActiveNotifications.Throwing = Library:Notify({
                Title = "Alert: Object Thrown",
                Description = ("Type: %s\nTotal Thrown: %d"):format(materialName, CONFIG.Counters.Throwing),
                Time = CONFIG.NotifyTime,
            })
        end
    end
end

Workspace.DescendantAdded:Connect(checkAndNotifySound)
for _, descendant in ipairs(Workspace:GetDescendants()) do
    checkAndNotifySound(descendant)
end





--================================================================--
-- PLAYER TAB
--================================================================--
--[[



local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local originalHipHeight = 0

PlayerLeft:AddToggle("HipHeightToggleOption", {
    Text = "GOD MOD",
    Default = false,
    Callback = function(state)
        if LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
            
            if state then
                originalHipHeight = humanoid.HipHeight
                humanoid.HipHeight = 7
                humanoid.CameraOffset = Vector3.new(0, -7, 0)
            else
                humanoid.HipHeight = originalHipHeight
                humanoid.CameraOffset = Vector3.new(0, 0, 0)
            end
        end
    end
})

LP.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid and PlayerLeft:GetToggle("HipHeightToggleOption") then
        originalHipHeight = humanoid.HipHeight
        humanoid.HipHeight = 7
        humanoid.CameraOffset = Vector3.new(0, -7, 0)
    end
end)


]]

PlayerLeft:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">God Mod</font>',
	Default = false,
	Callback = function(Value)
		
	end,
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local StaminaToggle = true

task.spawn(function()
    while task.wait() do
        if StaminaToggle then
            local maxStamina = workspace:GetAttribute("MaxStamina") or 9999
            
            if LocalPlayer then
                LocalPlayer:SetAttribute("Stamina", maxStamina)
            end
            
            if LocalPlayer.Character then
                LocalPlayer.Character:SetAttribute("Stamina", maxStamina)
            end
        end
    end
end)

PlayerLeft:AddToggle("StaminaToggleOption", {
    Text = "Inf Stamina",
    Default = true,
    Callback = function(state)
        StaminaToggle = state
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


--================================================================--
-- ESP TAB
--================================================================--

local RunService = game:GetService("RunService")

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
						part.Transparency = 1
					end
				end
			end
		end
	end
end

EspBox:AddToggle("GhostVisibilityToggle", {
	Text = "Ghost Visibility",
	Default = true,
	Callback = function(Value)
		toggleGhostVisibility(Value)
	end,
})

toggleGhostVisibility(true)


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



--================================================================--
-- MISC TAB
--================================================================--

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




















--================================================================--
-- EMOTE 
--================================================================--
local currentTrack = nil
local selectedEmote = "float emote"

local emotes = {
    ["float emote"] = "rbxassetid://138961919210199",
    ["head pop"] = "rbxassetid://105544444013843"
}

EmoteBox:AddDropdown("EmoteDropdown", {
	Values = { "float emote", "head pop" },
	Default = 1,
	Multi = false,
	Text = "Select Emote",
	Searchable = true,
	Callback = function(Value)
		selectedEmote = Value
	end,
})

EmoteBox:AddButton({
	Text = "Play Emote",
	Func = function()
		local player = game:GetService("Players").LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")

		if currentTrack then
			currentTrack:Stop()
			currentTrack:Destroy()
			currentTrack = nil
		end

		local animId = emotes[selectedEmote]
		if animId then
			local animation = Instance.new("Animation")
			animation.AnimationId = animId
			
			currentTrack = animator:LoadAnimation(animation)
			currentTrack:Play()
		end
	end,
})

EmoteBox:AddButton({
	Text = "Stop Emote",
	Func = function()
		if currentTrack then
			currentTrack:Stop()
			currentTrack:Destroy()
			currentTrack = nil
		end
	end,
})





--================================================================--
-- GHOST DETECTION 
--================================================================--







--================================================================--
-- DETECT BANSHEE
--================================================================--

EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Bnahsee</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
})

--================================================================--
-- DETECT SPECTER 
--================================================================--
EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Specter</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
})

--================================================================--
-- DETECT SIREN
--================================================================--


-- Custom Notification Setup
local playerGui = LP:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("DeltaNotifications")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeltaNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
end

local Config = {
	Scale = 0.8,
	Duration = 10
}

local function CustomNotify(titleText, descText, duration)
	duration = duration or Config.Duration
	local scale = Config.Scale or 1.0
	
	local notifyFrame = Instance.new("Frame")
	notifyFrame.Name = "Notification"
	notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
	notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
	notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
	notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notifyFrame.BackgroundTransparency = 0.25
	notifyFrame.BorderSizePixel = 0
	notifyFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.round(8 * scale))
	corner.Parent = notifyFrame

	local blackBorder = Instance.new("UIStroke")
	blackBorder.Color = Color3.fromRGB(0, 0, 0)
	blackBorder.Thickness = math.max(1, math.round(2 * scale))
	blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blackBorder.Parent = notifyFrame

	local borderContainer = Instance.new("Frame")
	borderContainer.Size = UDim2.new(1, 0, 1, 0)
	borderContainer.BackgroundTransparency = 1
	borderContainer.BorderSizePixel = 0
	borderContainer.Parent = notifyFrame
	corner:Clone().Parent = borderContainer

	local purpleOutline = Instance.new("UIStroke")
	purpleOutline.Color = Color3.fromRGB(128, 0, 128)
	purpleOutline.Thickness = math.max(1, math.round(4 * scale))
	purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	purpleOutline.Parent = borderContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
	titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = math.round(16 * scale)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = notifyFrame

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
	descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
	descLabel.TextSize = math.round(13 * scale)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Center
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = notifyFrame

	local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 40)
	})
	tweenIn:Play()

	task.spawn(function()
		task.wait(duration)
		
		local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -150),
			BackgroundTransparency = 1
		})
		
		TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
		TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notifyFrame:Destroy()
	end)
end

local speedConnection = nil
local lastSpeed = 0
local SirenTrackerToggle = true

local function notifySiren()
    CustomNotify("SIREN DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
end

local function startSpeedTracker(humanoid)
    if speedConnection then speedConnection:Disconnect() end
    if not SirenTrackerToggle then return end
    
    lastSpeed = humanoid.WalkSpeed
    speedConnection = RunService.RenderStepped:Connect(function()
        if humanoid and humanoid.Parent then
            local currentSpeed = humanoid.WalkSpeed
            if lastSpeed > 0 and currentSpeed < lastSpeed then
                local speedLoss = lastSpeed - currentSpeed
                local percentDecrease = (speedLoss / lastSpeed) * 100
                if math.abs(percentDecrease - 20) < 1.0 then
                    notifySiren()
                    if speedConnection then
                        speedConnection:Disconnect()
                        speedConnection = nil
                        task.delay(5, function()
                            if SirenTrackerToggle and humanoid and humanoid.Parent then
                                startSpeedTracker(humanoid)
                            end
                        end)
                    end
                end
            end
            lastSpeed = currentSpeed
        end
    end)
end

EvidenceBox2:AddToggle("SirenTrackerOpt", {
    Text = "Detect Siren",
    Default = true,
    Callback = function(state)
        SirenTrackerToggle = state
        if state then
            if LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
                startSpeedTracker(LP.Character:FindFirstChildOfClass("Humanoid"))
            end
        else
            if speedConnection then
                speedConnection:Disconnect()
                speedConnection = nil
            end
        end
    end
})

LP.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        if SirenTrackerToggle then
            startSpeedTracker(humanoid)
        end
    end
end)

task.spawn(function()
    if LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
        startSpeedTracker(LP.Character:FindFirstChildOfClass("Humanoid"))
    end
end)

--================================================================--
-- DETECT ASWANG 
--================================================================--


-- Custom Notification Setup
local playerGui = LP:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("DeltaNotifications")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeltaNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
end

local Config = {
	Scale = 0.8,
	Duration = 10
}

local function CustomNotify(titleText, descText, duration)
	duration = duration or Config.Duration
	local scale = Config.Scale or 1.0
	
	local notifyFrame = Instance.new("Frame")
	notifyFrame.Name = "Notification"
	notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
	notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
	notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
	notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notifyFrame.BackgroundTransparency = 0.25
	notifyFrame.BorderSizePixel = 0
	notifyFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.round(8 * scale))
	corner.Parent = notifyFrame

	local blackBorder = Instance.new("UIStroke")
	blackBorder.Color = Color3.fromRGB(0, 0, 0)
	blackBorder.Thickness = math.max(1, math.round(2 * scale))
	blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blackBorder.Parent = notifyFrame

	local borderContainer = Instance.new("Frame")
	borderContainer.Size = UDim2.new(1, 0, 1, 0)
	borderContainer.BackgroundTransparency = 1
	borderContainer.BorderSizePixel = 0
	borderContainer.Parent = notifyFrame
	corner:Clone().Parent = borderContainer

	local purpleOutline = Instance.new("UIStroke")
	purpleOutline.Color = Color3.fromRGB(128, 0, 128)
	purpleOutline.Thickness = math.max(1, math.round(4 * scale))
	purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	purpleOutline.Parent = borderContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
	titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = math.round(16 * scale)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = notifyFrame

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
	descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
	descLabel.TextSize = math.round(13 * scale)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Center
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = notifyFrame

	local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 40)
	})
	tweenIn:Play()

	task.spawn(function()
		task.wait(duration)
		
		local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -150),
			BackgroundTransparency = 1
		})
		
		TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
		TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notifyFrame:Destroy()
	end)
end

local aswangConnection = nil
local lastGhostSpeed = 0
local AswangTrackerToggle = true

-- Shared global configuration handling (if Wendigo confirmed elsewhere)
local function isWendigoConfirmed()
    return _G.isConfirmedWendigo == true
end

local function getGhostModel()
    return workspace:FindFirstChild("Ghost")
end

local function getGhostHumanoid()
    local ghostModel = getGhostModel()
    if ghostModel then return ghostModel:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function notifyAswang()
    if isWendigoConfirmed() then return end
    CustomNotify("ASWANG DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
end

local function startAswangTracker()
    if aswangConnection then aswangConnection:Disconnect() end
    if not AswangTrackerToggle then return end
    
    local saltPiles = workspace:FindFirstChild("SaltPiles")
    local freshDisturbance = false
    local saltConnections = {}

    local function trackSalt(child)
        if child.Name == "DisturbedSaltLine" then
            freshDisturbance = true
            task.delay(0.5, function() freshDisturbance = false end)
        elseif child.Name == "SaltLine" then
            local conn = child:GetPropertyChangedSignal("Name"):Connect(function()
                if child.Name == "DisturbedSaltLine" then
                    freshDisturbance = true
                    task.delay(0.5, function() freshDisturbance = false end)
                end
            end)
            table.insert(saltConnections, conn)
        end
    end

    if saltPiles then
        for _, child in ipairs(saltPiles:GetChildren()) do trackSalt(child) end
        local mainConn = saltPiles.ChildAdded:Connect(trackSalt)
        table.insert(saltConnections, mainConn)
	end
    
    local ghostHumanoid = getGhostHumanoid()
    lastGhostSpeed = ghostHumanoid and ghostHumanoid.WalkSpeed or 0
    
    aswangConnection = RunService.RenderStepped:Connect(function()
        if isWendigoConfirmed() then return end
        
        local currentGhostHumanoid = getGhostHumanoid()
        if currentGhostHumanoid and currentGhostHumanoid.Parent then
            local currentGhostSpeed = currentGhostHumanoid.WalkSpeed
            if lastGhostSpeed > 0 and currentGhostSpeed < lastGhostSpeed then
                local speedLoss = lastGhostSpeed - currentGhostSpeed
                local percentDecrease = (speedLoss / lastGhostSpeed) * 100
                if math.abs(percentDecrease - 25) < 1.5 and freshDisturbance then
                    notifyAswang()
                    if aswangConnection then aswangConnection:Disconnect() aswangConnection = nil end
                    for _, conn in ipairs(saltConnections) do conn:Disconnect() end
                end
            end
            lastGhostSpeed = currentGhostSpeed
        end
    end)
end

EvidenceBox2:AddToggle("AswangTrackerOpt", {
    Text = "Detect Aswang",
    Default = true,
    Callback = function(state)
        AswangTrackerToggle = state
        if state then
            startAswangTracker()
        else
            if aswangConnection then aswangConnection:Disconnect() aswangConnection = nil end
        end
    end
})

task.spawn(startAswangTracker)



--================================================================--
-- DETECT DYBUKK
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local dybbukConnection = nil
    local DybbukTrackerToggle = true
    local ragdollPositions = {} 
    local ragdollCooldowns = {}

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function stopDybbuk()
        if dybbukConnection then
            dybbukConnection:Disconnect()
            dybbukConnection = nil
        end
        table.clear(ragdollPositions)
        table.clear(ragdollCooldowns)
    end

    local function startDybbuk()
        stopDybbuk()
        if not DybbukTrackerToggle then return end

        dybbukConnection = RunService.Heartbeat:Connect(function()
            if isWendigoConfirmed() or not DybbukTrackerToggle then return end

            local ragdollsFolder = workspace:FindFirstChild("Ragdolls")
            if not ragdollsFolder then return end

            for _, body in ipairs(ragdollsFolder:GetChildren()) do
                local torso = body:FindFirstChild("Torso") or body:FindFirstChild("UpperTorso") or body:FindFirstChild("HumanoidRootPart")
                if torso and torso:IsA("BasePart") then
                    
                    if not ragdollPositions[body] then
                        ragdollPositions[body] = torso.Position
                        ragdollCooldowns[body] = tick()
                    else
                        -- Wait 0.5s for physics to settle before checking distance
                        if tick() - ragdollCooldowns[body] > 0.5 then
                            local initialPos = ragdollPositions[body]
                            local currentPos = torso.Position
                            local distanceMoved = (currentPos - initialPos).Magnitude

                            -- Check for player interference
                            local isTouchingPlayer = false
                            for _, part in pairs(body:GetChildren()) do
                                if part:IsA("BasePart") then
                                    for _, p in pairs(part:GetTouchingParts()) do
                                        if p.Parent:FindFirstChild("Humanoid") then
                                            isTouchingPlayer = true
                                            break
                                        end
                                    end
                                end
                            end

                            if not isTouchingPlayer and distanceMoved >= 5 then
                                  CustomNotify("DYBUKK DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 15)
                                stopDybbuk()
                                break
                            end
                        end
                    end
                end
            end
        end)
    end

    while not EvidenceBox2 do task.wait(0.25) end
    EvidenceBox2:AddToggle("DybbukTrackerOpt", {
        Text = "Detect Dybbuk",
        Default = true,
        Callback = function(state)
            DybbukTrackerToggle = state
            if state then startDybbuk() else stopDybbuk() end
        end
    })

    startDybbuk()
end)



--================================================================--
-- DETECT DULLAHAN 
--================================================================--

-- Custom Notification Setup
local playerGui = LP:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("DeltaNotifications")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeltaNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
end

local Config = {
	Scale = 0.8,
	Duration = 15
}

local function CustomNotify(titleText, descText, duration)
	duration = duration or Config.Duration
	local scale = Config.Scale or 1.0
	
	local notifyFrame = Instance.new("Frame")
	notifyFrame.Name = "Notification"
	notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
	notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
	notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
	notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notifyFrame.BackgroundTransparency = 0.25
	notifyFrame.BorderSizePixel = 0
	notifyFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.round(8 * scale))
	corner.Parent = notifyFrame

	local blackBorder = Instance.new("UIStroke")
	blackBorder.Color = Color3.fromRGB(0, 0, 0)
	blackBorder.Thickness = math.max(1, math.round(2 * scale))
	blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blackBorder.Parent = notifyFrame

	local borderContainer = Instance.new("Frame")
	borderContainer.Size = UDim2.new(1, 0, 1, 0)
	borderContainer.BackgroundTransparency = 1
	borderContainer.BorderSizePixel = 0
	borderContainer.Parent = notifyFrame
	corner:Clone().Parent = borderContainer

	local purpleOutline = Instance.new("UIStroke")
	purpleOutline.Color = Color3.fromRGB(128, 0, 128)
	purpleOutline.Thickness = math.max(1, math.round(4 * scale))
	purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	purpleOutline.Parent = borderContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
	titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = math.round(16 * scale)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = notifyFrame

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
	descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
	descLabel.TextSize = math.round(13 * scale)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Center
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = notifyFrame

	local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 40)
	})
	tweenIn:Play()

	task.spawn(function()
		task.wait(duration)
		
		local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -150),
			BackgroundTransparency = 1
		})
		
		TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
		TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notifyFrame:Destroy()
	end)
end

local ghostConnection = nil
local lastDullahanSpeed = 0
local DullahanTrackerToggle = true

local function isWendigoConfirmed()
    return _G.isConfirmedWendigo == true
end

local function getGhostModel()
    return workspace:FindFirstChild("Ghost")
end

local function getGhostHumanoid()
    local ghostModel = getGhostModel()
    if ghostModel then return ghostModel:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function notifyDullahan()
    if isWendigoConfirmed() then return end
    CustomNotify("DULLAHAN DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
end

local function startGhostTracker()
    if ghostConnection then ghostConnection:Disconnect() end
    if not DullahanTrackerToggle then return end
    
    lastDullahanSpeed = 0
    local consecutiveIncreases = 0
    
    ghostConnection = RunService.RenderStepped:Connect(function()
        if isWendigoConfirmed() then return end
        
        local ghostHumanoid = getGhostHumanoid()
        if ghostHumanoid and ghostHumanoid.Parent then
            local currentGhostSpeed = ghostHumanoid.WalkSpeed
            if lastDullahanSpeed > 0 and currentGhostSpeed > lastDullahanSpeed then
                local difference = currentGhostSpeed - lastDullahanSpeed
                if difference > 0 and difference <= 1.5 then
                    consecutiveIncreases = consecutiveIncreases + 1
                    if consecutiveIncreases >= 3 then
                        notifyDullahan()
                        consecutiveIncreases = 0
                    end
                end
            else
                consecutiveIncreases = 0
            end
            lastDullahanSpeed = currentGhostSpeed
        end
    end)
end

EvidenceBox2:AddToggle("DullahanTrackerOpt", {
    Text = "Detect Dullahan",
    Default = true,
    Callback = function(state)
        DullahanTrackerToggle = state
        if state then
            startGhostTracker()
        else
            if ghostConnection then
                ghostConnection:Disconnect()
                ghostConnection = nil
            end
        end
    end
})

task.spawn(startGhostTracker)


--================================================================--
-- DETECT ONI & PHANTOM 
--================================================================--
task.spawn(function()
    

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local oniConnection = nil
    local phantomConnection = nil
    local OniTrackerToggle = true
    local PhantomTrackerToggle = true

    local oniAnalyzing = false
    local phantomAnalyzing = false

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function getGhostModel()
        return workspace:FindFirstChild("Ghost")
    end

    local function getGhostHumanoid()
        local ghostModel = getGhostModel()
        if ghostModel then return ghostModel:FindFirstChildOfClass("Humanoid") end
        return nil
    end

    local function stopOni()
        if oniConnection then
            oniConnection:Disconnect()
            oniConnection = nil
        end
    end

    local function startOni()
        stopOni()
        if not OniTrackerToggle then return end
        
        oniConnection = RunService.RenderStepped:Connect(function()
            if isWendigoConfirmed() or oniAnalyzing then return end
            
            local ghostModel = getGhostModel()
            local ghostHumanoid = getGhostHumanoid()
            if ghostModel and ghostHumanoid and ghostHumanoid.Parent then
                local isHunting = ghostModel:GetAttribute("Hunting")
                if isHunting == true then
                    oniAnalyzing = true
                    
                    local hasDroppedSpeed = false
                    local startTime = os.clock()
                    
                    while os.clock() - startTime < 3 do
                        local model = getGhostModel()
                        local hum = getGhostHumanoid()
                        if not model or not hum or not model:GetAttribute("Hunting") then
                            oniAnalyzing = false
                            return
                        end
                        
                        -- Oni must strictly stay at high speed (27). If it drops below 25, it's not an Oni.
                        if hum.WalkSpeed < 25 then
                            hasDroppedSpeed = true
                        end
                        task.wait()
                    end
                    
                    if not hasDroppedSpeed then
                        CustomNotify("ONI DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                        stopOni()
                    end
                    oniAnalyzing = false
                end
            end
        end)
    end

    local function stopPhantom()
        if phantomConnection then
            phantomConnection:Disconnect()
            phantomConnection = nil
        end
    end

    local function startPhantom()
        stopPhantom()
        if not PhantomTrackerToggle then return end
        
        phantomConnection = RunService.RenderStepped:Connect(function()
            if isWendigoConfirmed() or phantomAnalyzing then return end
            
            local ghostModel = getGhostModel()
            local ghostHumanoid = getGhostHumanoid()
            if ghostModel and ghostHumanoid and ghostHumanoid.Parent then
                local isHunting = ghostModel:GetAttribute("Hunting")
                if isHunting == true then
                    phantomAnalyzing = true
                    
                    local sawLowSpeed = false
                    local sawHighSpeed = false
                    local startTime = os.clock()
                    
                    while os.clock() - startTime < 3 do
                        local model = getGhostModel()
                        local hum = getGhostHumanoid()
                        if not model or not hum or not model:GetAttribute("Hunting") then
                            phantomAnalyzing = false
                            return
                        end
                        
                        local currentSpeed = hum.WalkSpeed
                        if currentSpeed <= 23 then
                            sawLowSpeed = true
                        elseif currentSpeed >= 26 then
                            sawHighSpeed = true
                        end
                        task.wait()
                    end
                    
                    -- Phantom must actively change speed (it must hit both ranges within the 3 seconds)
                    if sawLowSpeed and sawHighSpeed then
                        CustomNotify("PHANTOM DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                        stopPhantom()
                    end
                    phantomAnalyzing = false
                end
            end
        end)
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("OniTrackerOpt", {
        Text = "Detect Oni",
        Default = true,
        Callback = function(state)
            OniTrackerToggle = state
            if state then
                startOni()
            else
                stopOni()
            end
        end
    })

    EvidenceBox2:AddToggle("PhantomTrackerOpt", {
        Text = "Detect Phantom",
        Default = true,
        Callback = function(state)
            PhantomTrackerToggle = state
            if state then
                startPhantom()
            else
                stopPhantom()
            end
        end
    })

    startOni()
    startPhantom()
end)


--================================================================--
-- DETECT ENTITY 
--================================================================--
--[[

-- Custom Notification Setup
local playerGui = LP:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("DeltaNotifications")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeltaNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
end

local Config = {
	Scale = 0.8,
	Duration = 15
}

local function CustomNotify(titleText, descText, duration)
	duration = duration or Config.Duration
	local scale = Config.Scale or 1.0
	
	local notifyFrame = Instance.new("Frame")
	notifyFrame.Name = "Notification"
	notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
	notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
	notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
	notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notifyFrame.BackgroundTransparency = 0.25
	notifyFrame.BorderSizePixel = 0
	notifyFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.round(8 * scale))
	corner.Parent = notifyFrame

	local blackBorder = Instance.new("UIStroke")
	blackBorder.Color = Color3.fromRGB(0, 0, 0)
	blackBorder.Thickness = math.max(1, math.round(2 * scale))
	blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blackBorder.Parent = notifyFrame

	local borderContainer = Instance.new("Frame")
	borderContainer.Size = UDim2.new(1, 0, 1, 0)
	borderContainer.BackgroundTransparency = 1
	borderContainer.BorderSizePixel = 0
	borderContainer.Parent = notifyFrame
	corner:Clone().Parent = borderContainer

	local purpleOutline = Instance.new("UIStroke")
	purpleOutline.Color = Color3.fromRGB(128, 0, 128)
	purpleOutline.Thickness = math.max(1, math.round(4 * scale))
	purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	purpleOutline.Parent = borderContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
	titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = math.round(16 * scale)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = notifyFrame

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
	descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
	descLabel.TextSize = math.round(13 * scale)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Center
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = notifyFrame

	local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 40)
	})
	tweenIn:Play()

	task.spawn(function()
		task.wait(duration)
		
		local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -150),
			BackgroundTransparency = 1
		})
		
		TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
		TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notifyFrame:Destroy()
	end)
end

local entityConnection = nil
local EntityTrackerToggle = true

local function getGhostModel()
    return workspace:FindFirstChild("Ghost")
end

local function notifyEntity()
    CustomNotify("ENTITY DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
end

local function startEntityTracker()
    if entityConnection then entityConnection:Disconnect() end
    if not EntityTrackerToggle then return end
    
    local lastGhostPos = nil
    entityConnection = RunService.RenderStepped:Connect(function()
        local ghostModel = getGhostModel()
        if ghostModel then
            local rootPart = ghostModel:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local currentGhostPos = rootPart.Position
                if lastGhostPos then
                    local distance = (currentGhostPos - lastGhostPos).Magnitude
                    if distance > 10 then
                        notifyEntity()
                        if entityConnection then
                            entityConnection:Disconnect()
                            entityConnection = nil
                        end
                        return
                    end
                end
                lastGhostPos = currentGhostPos
            else lastGhostPos = nil end
        else lastGhostPos = nil end
    end)
end

EvidenceBox2:AddToggle("EntityTrackerOpt", {
    Text = "Detect Entity",
    Default = true,
    Callback = function(state)
        EntityTrackerToggle = state
        if state then
            startEntityTracker()
        else
            if entityConnection then
                entityConnection:Disconnect()
                entityConnection = nil
            end
        end
    end
})

task.spawn(startEntityTracker)
]]

EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Entity</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
})

--================================================================--
-- DETECT WENDIGO 
--================================================================--

-- Custom Notification Setup
local playerGui = LP:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("DeltaNotifications")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeltaNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
end

local Config = {
	Scale = 0.8,
	Duration = 15
}

local function CustomNotify(titleText, descText, duration)
	duration = duration or Config.Duration
	local scale = Config.Scale or 1.0
	
	local notifyFrame = Instance.new("Frame")
	notifyFrame.Name = "Notification"
	notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
	notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
	notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
	notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notifyFrame.BackgroundTransparency = 0.25
	notifyFrame.BorderSizePixel = 0
	notifyFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.round(8 * scale))
	corner.Parent = notifyFrame

	local blackBorder = Instance.new("UIStroke")
	blackBorder.Color = Color3.fromRGB(0, 0, 0)
	blackBorder.Thickness = math.max(1, math.round(2 * scale))
	blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blackBorder.Parent = notifyFrame

	local borderContainer = Instance.new("Frame")
	borderContainer.Size = UDim2.new(1, 0, 1, 0)
	borderContainer.BackgroundTransparency = 1
	borderContainer.BorderSizePixel = 0
	borderContainer.Parent = notifyFrame
	corner:Clone().Parent = borderContainer

	local purpleOutline = Instance.new("UIStroke")
	purpleOutline.Color = Color3.fromRGB(128, 0, 128)
	purpleOutline.Thickness = math.max(1, math.round(4 * scale))
	purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	purpleOutline.Parent = borderContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
	titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = math.round(16 * scale)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = notifyFrame

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
	descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
	descLabel.TextSize = math.round(13 * scale)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Center
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = notifyFrame

	local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 40)
	})
	tweenIn:Play()

	task.spawn(function()
		task.wait(duration)
		
		local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -150),
			BackgroundTransparency = 1
		})
		
		TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
		TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notifyFrame:Destroy()
	end)
end

local wendigoConnection = nil
local WendigoTrackerToggle = true

local function getGhostModel()
    return workspace:FindFirstChild("Ghost")
end

local function getGhostHumanoid()
    local ghostModel = getGhostModel()
    if ghostModel then return ghostModel:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function notifyWendigo()
    CustomNotify("WENDIGO DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
end

local function startWendigoTracker()
    if wendigoConnection then wendigoConnection:Disconnect() end
    if not WendigoTrackerToggle then return end
    
    wendigoConnection = RunService.RenderStepped:Connect(function()
        local ghostHumanoid = getGhostHumanoid()
        if ghostHumanoid and ghostHumanoid.Parent then
            if ghostHumanoid.WalkSpeed >= 28 then
                _G.isConfirmedWendigo = true -- Sync across separate scripts globally
                notifyWendigo()
                if wendigoConnection then
                    wendigoConnection:Disconnect()
                    wendigoConnection = nil
                end
            end
        end
    end)
end

EvidenceBox2:AddToggle("WendigoTrackerOpt", {
    Text = "Detect Wendigo",
    Default = true,
    Callback = function(state)
        WendigoTrackerToggle = state
        if state then
            startWendigoTracker()
        else
            if wendigoConnection then
                wendigoConnection:Disconnect()
                wendigoConnection = nil
            end
        end
    end
})

task.spawn(function()
    _G.isConfirmedWendigo = false
    startWendigoTracker()
end)

--================================================================--
-- DETECT SPIRIT 
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local function CustomNotify(titleText, descText, duration)
        local scale = 0.8
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = 2
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = 4
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -20, 0, 25)
        titleLabel.Position = UDim2.new(0, 12, 0, 8)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = 16
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -24, 1, -40)
        descLabel.Position = UDim2.new(0, 12, 0, 33)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = 13
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration or 15)
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local function checkColorIsBlue(color)
        return color.B > 0.8 and color.R < 0.5
    end

    local function isOilBlue()
        local holyOilFolder = workspace:FindFirstChild("HolyOil")
        if not holyOilFolder then return false end

        for _, desc in ipairs(holyOilFolder:GetDescendants()) do
            if desc:IsA("PointLight") then
                if checkColorIsBlue(desc.Color) then
                    return true
                end
            elseif desc:IsA("ParticleEmitter") then
                local colorSeq = desc.Color
                if colorSeq and colorSeq.Keypoints and #colorSeq.Keypoints > 0 then
                    if checkColorIsBlue(colorSeq.Keypoints[1].Value) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local spiritConnection = nil
    local SpiritTrackerToggle = true

    local function stopTracker()
        if spiritConnection then
            spiritConnection:Disconnect()
            spiritConnection = nil
        end
    end

    local function startTracker()
        stopTracker()
        if not SpiritTrackerToggle then return end

        spiritConnection = RunService.Heartbeat:Connect(function()
            if _G.isConfirmedWendigo == true then return end
            
            local ghostModel = workspace:FindFirstChild("Ghost")
            if ghostModel then
                local isHunting = ghostModel:GetAttribute("Hunting")
                if isHunting == true then
                    if isOilBlue() then
                        if _G.isConfirmedWendigo ~= true then
                            CustomNotify("SPIRIT DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                        end
                        stopTracker()
                    end
                end
            end
        end)
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("SpiritTrackerOpt", {
        Text = "Detect Spirit",
        Default = true,
        Callback = function(state)
            SpiritTrackerToggle = state
            if state then
                startTracker()
            else
                stopTracker()
            end
        end
    })

    startTracker()
end)







--================================================================--
-- DETECT THE WISP
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local wispSpawnConnection = nil
    local wispChangedConnection = nil
    local WispTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function cleanWispListener()
        if wispChangedConnection then
            wispChangedConnection:Disconnect()
            wispChangedConnection = nil
        end
    end

    local function checkWispState(ghostModel)
        if not WispTrackerToggle or isWendigoConfirmed() then return end
        
        if ghostModel and ghostModel.Parent then
            if ghostModel:GetAttribute("Burning") == true then
                CustomNotify("WISP DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                
                -- Turn off tracking once verified so it doesn't duplicate alerts
                cleanWispListener()
                if wispSpawnConnection then
                    wispSpawnConnection:Disconnect()
                    wispSpawnConnection = nil
                end
            end
        end
    end

    local function setupAttributeListener(ghostModel)
        cleanWispListener()
        if not ghostModel then return end
        
        -- Instant initial check
        checkWispState(ghostModel)
        
        -- Watch for the dynamic attribute checkmark updates (Fixes the mid-game changes!)
        wispChangedConnection = ghostModel:GetAttributeChangedSignal("Burning"):Connect(function()
            checkWispState(ghostModel)
        end)
    end

    local function stopWisp()
        cleanWispListener()
        if wispSpawnConnection then
            wispSpawnConnection:Disconnect()
            wispSpawnConnection = nil
        end
    end

    local function startWisp()
        stopWisp()
        if not WispTrackerToggle then return end
        
        -- Watch workspace for when the ghost appears
        wispSpawnConnection = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Ghost" then
                task.wait(0.1)
                setupAttributeListener(child)
            end
        end)
        
        -- Failsafe in case it's already spawned inside the match
        local existingGhost = workspace:FindFirstChild("Ghost")
        if existingGhost then
            setupAttributeListener(existingGhost)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("WispTrackerOpt", {
        Text = "Detect Wisp",
        Default = true,
        Callback = function(state)
            WispTrackerToggle = state
            if state then
                startWisp()
            else
                stopWisp()
            end
        end
    })

    startWisp()
end)

--================================================================--
-- DETECT NIGHTMARE
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local SoundService = game:GetService("SoundService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local nightmareConnection = nil
    local NightmareTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function checkSoundPlayed(sound)
        if not NightmareTrackerToggle or isWendigoConfirmed() then return end
        
        if sound.SoundId == "rbxassetid://2978605361" or sound.SoundId == "2978605361" then
            task.wait(0.1)
            
            local brokenGlassFolder = workspace:FindFirstChild("BrokenGlass")
            if brokenGlassFolder then
                local glassItems = brokenGlassFolder:GetChildren()
                if #glassItems == 0 then
                    CustomNotify("NIGHTMARE DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                    if nightmareConnection then
                        nightmareConnection:Disconnect()
                        nightmareConnection = nil
                    end
                end
            end
        end
    end

    local function stopNightmare()
        if nightmareConnection then
            nightmareConnection:Disconnect()
            nightmareConnection = nil
        end
    end

    local function startNightmare()
        stopNightmare()
        if not NightmareTrackerToggle then return end
        
        nightmareConnection = SoundService.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Sound") then
                checkSoundPlayed(descendant)
            end
        end)
        
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("Sound") then
                obj.Played:Connect(function()
                    checkSoundPlayed(obj)
                end)
            end
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("NightmareTrackerOpt", {
        Text = "Detect Nightmare",
        Default = true,
        Callback = function(state)
            NightmareTrackerToggle = state
            if state then
                startNightmare()
            else
                stopNightmare()
            end
        end
    })

    startNightmare()
end)

--================================================================--
-- DETECT UMBRA
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local umbraConnection = nil
    local UmbraTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function checkGhostModel(ghostModel)
        if not UmbraTrackerToggle or isWendigoConfirmed() then return end
        
        -- Provide a microscopic frame delay to make sure all parts/sounds inside the ghost are fully loaded
        task.wait(0.1)
        
        if ghostModel and ghostModel.Parent then
            local steps = ghostModel:FindFirstChild("GhostFootsteps")
            if not steps then
                CustomNotify("UMBRA DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                if umbraConnection then
                    umbraConnection:Disconnect()
                    umbraConnection = nil
                end
            end
        end
    end

    local function stopUmbra()
        if umbraConnection then
            umbraConnection:Disconnect()
            umbraConnection = nil
        end
    end

    local function startUmbra()
        stopUmbra()
        if not UmbraTrackerToggle then return end
        
        -- Watch for whenever the Ghost model is added to workspace
        umbraConnection = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Ghost" then
                checkGhostModel(child)
            end
        end)
        
        -- Fail-safe check in case the script runs while the ghost is already present
        local existingGhost = workspace:FindFirstChild("Ghost")
        if existingGhost then
            checkGhostModel(existingGhost)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("UmbraTrackerOpt", {
        Text = "Detect Umbra",
        Default = true,
        Callback = function(state)
            UmbraTrackerToggle = state
            if state then
                startUmbra()
            else
                stopUmbra()
            end
        end
    })

    startUmbra()
end)


--================================================================--
-- DETECT KARES
--================================================================--
EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Kares</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
})
--================================================================--
-- DETECT VEX
--================================================================--
task.spawn(function()
    
    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local vexConnection = nil
    local VexTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function checkVexAttributes(ghostModel)
        if not VexTrackerToggle or isWendigoConfirmed() then return end
        
        task.wait(0.1)
        
        if ghostModel and ghostModel.Parent then
            local isInvisLidar = ghostModel:GetAttribute("InvisibleOnLIDAR")
            if isInvisLidar == true then
                CustomNotify("VEX DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                if vexConnection then
                    vexConnection:Disconnect()
                    vexConnection = nil
                end
            end
        end
    end

    local function stopVex()
        if vexConnection then
            vexConnection:Disconnect()
            vexConnection = nil
        end
    end

    local function startVex()
        stopVex()
        if not VexTrackerToggle then return end
        
        vexConnection = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Ghost" then
                checkVexAttributes(child)
            end
        end)
        
        local existingGhost = workspace:FindFirstChild("Ghost")
        if existingGhost then
            checkVexAttributes(existingGhost)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("VexTrackerOpt", {
        Text = "Detect Vex",
        Default = true,
        Callback = function(state)
            VexTrackerToggle = state
            if state then
                startVex()
            else
                stopVex()
            end
        end
    })

    startVex()
end)

--================================================================--
-- DETECT WRIATH
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local wraithConnections = {}
    local saltPilesConnection = nil
    local WraithTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function monitorSaltLine(saltLine)
        if not saltLine:IsA("Model") then return end
        
        local tracker = saltLine:WaitForChild("GhostTracker", 5)
        if tracker and tracker:IsA("BasePart") then
            local connection
            connection = tracker.Touched:Connect(function(hit)
                if not WraithTrackerToggle or isWendigoConfirmed() then return end
                
                local ghostModel = workspace:FindFirstChild("Ghost")
                if ghostModel and hit:IsDescendantOf(ghostModel) then
                    -- Microscopic delay to allow the game engine to complete its state updates
                    task.wait(0.15)
                    
                    -- If the ghost touched it, but it's STILL named SaltLine, it's a Wraith
                    if saltLine and saltLine.Parent and saltLine.Name == "SaltLine" then
                        CustomNotify("WRAITH DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                        
                        -- Disconnect this specific touch line so it doesn't spam notifications
                        if connection then
                            connection:Disconnect()
                            wraithConnections[saltLine] = nil
                        end
                    end
                end
            end)
            wraithConnections[saltLine] = connection
        end
    end

    local function stopWraith()
        if saltPilesConnection then
            saltPilesConnection:Disconnect()
            saltPilesConnection = nil
        end
        for saltLine, connection in pairs(wraithConnections) do
            if connection then connection:Disconnect() end
        end
        table.clear(wraithConnections)
    end

    local function startWraith()
        stopWraith()
        if not WraithTrackerToggle then return end
        
        local saltPiles = workspace:FindFirstChild("SaltPiles")
        if saltPiles then
            -- Scan existing salt lines placed in the match
            for _, child in ipairs(saltPiles:GetChildren()) do
                if child.Name == "SaltLine" then
                    monitorSaltLine(child)
                end
            end
            
            -- Keep monitoring if players drop new salt lines mid-game
            saltPilesConnection = saltPiles.ChildAdded:Connect(function(child)
                task.wait(0.1) -- Allow model structure to instantiate inside folder
                if child.Name == "SaltLine" then
                    monitorSaltLine(child)
                end
            end)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("WraithTrackerOpt", {
        Text = "Detect Wraith",
        Default = true,
        Callback = function(state)
            WraithTrackerToggle = state
            if state then
                startWraith()
            else
                stopWraith()
            end
        end
    })

    startWraith()
end)

--================================================================--
-- DETECT SKINWALKER 
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local skinwalkerConnection = nil
    local SkinwalkerTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function checkOrbPresence(child)
        if not SkinwalkerTrackerToggle or isWendigoConfirmed() then return end
        
        if child and child.Name == "GhostOrb" then
            CustomNotify("SKINWALKER DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
            if skinwalkerConnection then
                skinwalkerConnection:Disconnect()
                skinwalkerConnection = nil
            end
        end
    end

    local function stopSkinwalker()
        if skinwalkerConnection then
            skinwalkerConnection:Disconnect()
            skinwalkerConnection = nil
        end
    end

    local function startSkinwalker()
        stopSkinwalker()
        if not SkinwalkerTrackerToggle then return end
        
        -- Watch for whenever the GhostOrb model/part drops into workspace
        skinwalkerConnection = workspace.ChildAdded:Connect(function(child)
            checkOrbPresence(child)
        end)
        
        -- Instant check in case it's already there
        local existingOrb = workspace:FindFirstChild("GhostOrb")
        if existingOrb then
            checkOrbPresence(existingOrb)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("SkinwalkerTrackerOpt", {
        Text = "Detect Skinwalker",
        Default = true,
        Callback = function(state)
            SkinwalkerTrackerToggle = state
            if state then
                startSkinwalker()
            else
                stopSkinwalker()
            end
        end
    })

    startSkinwalker()
end)

--================================================================--
-- DETECT VASPER
--================================================================--
EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Vasper</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
})
--================================================================--
-- DETECT RAVAGER
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local ravagerConnection = nil
    local RavagerTrackerToggle = true
    
    local throwWindow = 0.15 
    local uniqueSoundIdsThisFrame = {}
    local trackingActive = false

    -- Valid Ravager interaction sound targets matching your list
    local targetSounds = {
        ["9113470969"] = true, -- body
        ["9118833449"] = true, -- book
        ["9113251349"] = true, -- cardboard
        ["9113768979"] = true, -- chair
        ["9119920406"] = true, -- glass
        ["9117450506"] = true, -- heavy
        ["9113720294"] = true, -- medium
        ["9116703825"] = true, -- metal
        ["9116630454"] = true, -- metalcan
        ["9113564136"] = true, -- plush
        ["9120885468"] = true  -- wood
    }

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function stopRavager()
        if ravagerConnection then
            ravagerConnection:Disconnect()
            ravagerConnection = nil
        end
    end

    local function checkSoundInstance(sound)
        if not RavagerTrackerToggle or isWendigoConfirmed() then return end
        
        local assetId = sound.SoundId:match("%d+")
        if assetId and targetSounds[assetId] then
            uniqueSoundIdsThisFrame[assetId] = true
            
            if not trackingActive then
                trackingActive = true
                task.delay(throwWindow, function()
                    local distinctCount = 0
                    for _ in pairs(uniqueSoundIdsThisFrame) do
                        distinctCount = distinctCount + 1
                    end

                    -- Exactly 3 unique sound types played inside the frame window = Ravager multi-throw event!
                    -- Filters out full-house ghost events because those trigger massive/chaotic audio overlap profiles.
                    if distinctCount == 3 then
                        CustomNotify("RAVAGER DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 15)
                        stopRavager()
                    end
                    
                    table.clear(uniqueSoundIdsThisFrame)
                    trackingActive = false
                end)
            end
        end
    end

    local function startRavager()
        stopRavager()
        if not RavagerTrackerToggle then return end

        local interactables = workspace:WaitForChild("Interactables", 5)
        if interactables then
            ravagerConnection = interactables.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("Sound") then
                    -- If sound is already playing or immediately plays on spawn
                    if descendant.IsPlaying then
                        checkSoundInstance(descendant)
                    else
                        descendant:GetPropertyChangedSignal("IsPlaying"):Connect(function()
                            if descendant.IsPlaying then
                                checkSoundInstance(descendant)
                            end
                        end)
                    end
                end
            end)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("RavagerTrackerOpt", {
        Text = "Detect Ravager",
        Default = true,
        Callback = function(state)
            RavagerTrackerToggle = state
            if state then
                startRavager()
            else
                stopRavager()
            end
        end
    })

    startRavager()
end)

--================================================================--
-- DETECT DEMON
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local demonConnection = nil
    local DemonTrackerToggle = true
    local spinTimers = {} -- Tracks how long each cross has been spinning continuously

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function stopDemon()
        if demonConnection then
            demonConnection:Disconnect()
            demonConnection = nil
        end
        table.clear(spinTimers)
    end

    local function startDemon()
        stopDemon()
        if not DemonTrackerToggle then return end

        local itemsFolder = workspace:WaitForChild("Items", 5)
        if itemsFolder then
            demonConnection = RunService.Heartbeat:Connect(function(deltaTime)
                if isWendigoConfirmed() or not DemonTrackerToggle then return end

                for _, item in ipairs(itemsFolder:GetChildren()) do
                    if item.Name == "Cross" or item:GetAttribute("ItemName") == "Cross" then
                        local crossPart = item:FindFirstChild("Cross") or item:FindFirstChild("Handle")
                        
                        if crossPart and crossPart:IsA("BasePart") then
                            local angularVel = crossPart.AssemblyAngularVelocity.Magnitude
                            local linearVelY = math.abs(crossPart.AssemblyLinearVelocity.Y)

                            -- Criteria: It must be spinning fast AND it shouldn't be falling downwards (Y velocity near 0 = floating)
                            if angularVel > 5 and linearVelY < 1.5 then
                                spinTimers[item] = (spinTimers[item] or 0) + deltaTime
                                
                                -- Must hold the float-spin state continuously for 0.4 seconds to confirm Demon
                                if spinTimers[item] >= 0.4 then
                                    CustomNotify("DEMON DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 15)
                                    stopDemon()
                                    break
                                end
                            else
                                spinTimers[item] = 0 -- Reset if it hits the ground or stops spinning
                            end
                        end
                    end
                end
            end)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("DemonTrackerOpt", {
        Text = "Detect Demon",
        Default = true,
        Callback = function(state)
            DemonTrackerToggle = state
            if state then
                startDemon()
            else
                stopDemon()
            end
        end
    })

    startDemon()
end)


--================================================================--
-- DETECT LEVIATHAN 
--================================================================--
EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Leviathan</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
})
--================================================================--
-- DETECT REVENANT 
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local revenantConnection = nil
    local RevenantTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function stopRevenant()
        if revenantConnection then
            revenantConnection:Disconnect()
            revenantConnection = nil
        end
    end

    local function startRevenant()
        stopRevenant()
        if not RevenantTrackerToggle then return end

        local ragdollsFolder = workspace:WaitForChild("Ragdolls", 5)
        if ragdollsFolder then
            revenantConnection = ragdollsFolder.ChildAdded:Connect(function(child)
                if isWendigoConfirmed() or not RevenantTrackerToggle then return end

                local ghost = workspace:FindFirstChild("Ghost")
                if ghost and ghost:GetAttribute("Hunting") == true then
                    -- Player just died during an active hunt! Wait a brief moment to check if hunt stops
                    task.wait(0.6)
                    
                    local activeGhost = workspace:FindFirstChild("Ghost")
                    if activeGhost and activeGhost:GetAttribute("Hunting") == false then
                        -- The hunt immediately ended right after a single kill occurred
                        CustomNotify("REVENANT DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 15)
                        stopRevenant()
                    end
                end
            end)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("RevenantTrackerOpt", {
        Text = "Detect Revenant",
        Default = true,
        Callback = function(state)
            RevenantTrackerToggle = state
            if state then
                startRevenant()
            else
                stopRevenant()
            end
        end
    })

    startRevenant()
end)

--================================================================--
-- DETECT GHOUL 
--================================================================--
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local playerGui = LP:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("DeltaNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DeltaNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end

    local Config = {
        Scale = 0.8,
        Duration = 15
    }

    local function CustomNotify(titleText, descText, duration)
        duration = duration or Config.Duration
        local scale = Config.Scale or 1.0
        
        local notifyFrame = Instance.new("Frame")
        notifyFrame.Name = "Notification"
        notifyFrame.Size = UDim2.new(0, math.round(300 * scale), 0, math.round(95 * scale))
        notifyFrame.Position = UDim2.new(0.5, 0, 0, -150) 
        notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notifyFrame.BackgroundTransparency = 0.25
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, math.round(8 * scale))
        corner.Parent = notifyFrame

        local blackBorder = Instance.new("UIStroke")
        blackBorder.Color = Color3.fromRGB(0, 0, 0)
        blackBorder.Thickness = math.max(1, math.round(2 * scale))
        blackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        blackBorder.Parent = notifyFrame

        local borderContainer = Instance.new("Frame")
        borderContainer.Size = UDim2.new(1, 0, 1, 0)
        borderContainer.BackgroundTransparency = 1
        borderContainer.BorderSizePixel = 0
        borderContainer.Parent = notifyFrame
        corner:Clone().Parent = borderContainer

        local purpleOutline = Instance.new("UIStroke")
        purpleOutline.Color = Color3.fromRGB(128, 0, 128)
        purpleOutline.Thickness = math.max(1, math.round(4 * scale))
        purpleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        purpleOutline.Parent = borderContainer

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, math.round(-20 * scale), 0, math.round(25 * scale))
        titleLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(8 * scale))
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = math.round(16 * scale)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = notifyFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, math.round(-24 * scale), 1, math.round(-40 * scale))
        descLabel.Position = UDim2.new(0, math.round(12 * scale), 0, math.round(33 * scale))
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
        descLabel.TextSize = math.round(13 * scale)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Center
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.Parent = notifyFrame

        local tweenIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 40)
        })
        tweenIn:Play()

        task.spawn(function()
            task.wait(duration)
            
            local tweenOut = TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -150),
                BackgroundTransparency = 1
            })
            
            TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(descLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            TweenService:Create(purpleOutline, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(blackBorder, TweenInfo.new(0.2), {Transparency = 1}):Play()
            
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notifyFrame:Destroy()
        end)
    end

    local ghoulSpawnConnection = nil
    local ghoulChangedConnection = nil
    local GhoulTrackerToggle = true

    local function isWendigoConfirmed()
        return _G.isConfirmedWendigo == true
    end

    local function cleanGhoulListener()
        if ghoulChangedConnection then
            ghoulChangedConnection:Disconnect()
            ghoulChangedConnection = nil
        end
    end

    local function checkGhoulState(ghostModel)
        if not GhoulTrackerToggle or isWendigoConfirmed() then return end
        
        if ghostModel and ghostModel.Parent then
            if ghostModel:GetAttribute("CantDisableElectronics") == true then
                CustomNotify("GHOUL DETECTED!", "Made By: Vgxmod Hub\nDiscord: https://discord.gg/n9gtmefsjc", 10)
                
                cleanGhoulListener()
                if ghoulSpawnConnection then
                    ghoulSpawnConnection:Disconnect()
                    ghoulSpawnConnection = nil
                end
            end
        end
    end

    local function setupAttributeListener(ghostModel)
        cleanGhoulListener()
        if not ghostModel then return end
        
        checkGhoulState(ghostModel)
        
        ghoulChangedConnection = ghostModel:GetAttributeChangedSignal("CantDisableElectronics"):Connect(function()
            checkGhoulState(ghostModel)
        end)
    end

    local function stopGhoul()
        cleanGhoulListener()
        if ghoulSpawnConnection then
            ghoulSpawnConnection:Disconnect()
            ghoulSpawnConnection = nil
        end
    end

    local function startGhoul()
        stopGhoul()
        if not GhoulTrackerToggle then return end
        
        ghoulSpawnConnection = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Ghost" then
                task.wait(0.1)
                setupAttributeListener(child)
            end
        end)
        
        local existingGhost = workspace:FindFirstChild("Ghost")
        if existingGhost then
            setupAttributeListener(existingGhost)
        end
    end

    while not EvidenceBox2 do
        task.wait(0.25)
    end

    EvidenceBox2:AddToggle("GhoulTrackerOpt", {
        Text = "Detect Ghoul",
        Default = true,
        Callback = function(state)
            GhoulTrackerToggle = state
            if state then
                startGhoul()
            else
                stopGhoul()
            end
        end
    })

    startGhoul()
end)

--================================================================--
-- DETECT SHADOW
--================================================================--
EvidenceBox2:AddToggle("InfoToggle", {
	Text = '<font color="rgb(255, 0, 0)">Detect Shadow</font>',
	Default = false,
	Callback = function(Value)
		print("Info Toggle changed:", Value)
		espSettings.Windows.Enabled = Value 
	end,
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
		
		if rawSpeed >= 27.0 then
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
