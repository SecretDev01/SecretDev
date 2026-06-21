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
-- ESP 
--================================================================--

local ESP_ENABLED = false

task.spawn(function()
    while true do
        if ESP_ENABLED then
            pcall(function()
                for _, desc in ipairs(workspace:GetDescendants()) do
                    if desc:IsA("Model") and desc:FindFirstChild("HumanoidRootPart") and desc:FindFirstChild("Head") then
                        -- Check against LocalPlayer.Character name to fix potential undefined variables
                        local myCharName = LP.Character and LP.Character.Name or ""
                        if desc.HumanoidRootPart.CollisionGroup == "Player" and desc.Name ~= myCharName then
                            local playerObject = Players:GetPlayerFromCharacter(desc)
                            local isSheriff = playerObject and playerObject.Team and playerObject.Team.Name == "Sheriffs"
                            
                            -- Changed the false fallback color from green to orange
                            local espColor = isSheriff and Color3.new(0, 0, 1) or Color3.new(1, 0.6, 0)
                            local roleText = isSheriff and " [SHERIFF]" or " [CRIMINAL]"
                            
                            -- 1. Sphere Marker Adornment
                            local existingESP = desc:FindFirstChild("ESP")
                            if existingESP then
                                existingESP.Color3 = espColor
                            else
                                local circle = Instance.new("SphereHandleAdornment")
                                circle.Name = "ESP"
                                circle.Adornee = desc.Head
                                circle.CFrame = CFrame.new(0, 1.5, 0)
                                circle.AlwaysOnTop = true
                                circle.Radius = 0.6
                                circle.ZIndex = 0
                                circle.Transparency = 0.3
                                circle.Color3 = espColor
                                circle.Parent = desc
                            end

                            -- 2. ESP TEXT (BillboardGui)
                            local existingText = desc:FindFirstChild("ESP_Text")
                            if existingText then
                                if existingText:FindFirstChild("Label") then
                                    existingText.Label.TextColor3 = espColor
                                    existingText.Label.Text = desc.Name .. roleText
                                end
                            else
                                local billboard = Instance.new("BillboardGui")
                                billboard.Name = "ESP_Text"
                                billboard.Adornee = desc.Head
                                billboard.Size = UDim2.new(0, 200, 0, 50)
                                billboard.StudsOffset = Vector3.new(0, 3, 0) -- Higher up above the sphere marker
                                billboard.AlwaysOnTop = true
                                billboard.Parent = desc

                                local label = Instance.new("TextLabel")
                                label.Name = "Label"
                                label.Size = UDim2.new(1, 0, 1, 0)
                                label.BackgroundTransparency = 1
                                label.Text = desc.Name .. roleText
                                label.TextColor3 = espColor
                                label.TextSize = 14
                                label.Font = Enum.Font.SourceSansBold
                                label.TextStrokeTransparency = 0 -- Gives text a clean black outline
                                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                                label.Parent = billboard
                            end
                        end
                    end
                end
            end)
            task.wait(0.5) -- Decreased loop wait slightly for better text updates
        else
            -- Cleanup everything when toggle is OFF
            for _, desc in ipairs(workspace:GetDescendants()) do
                if (desc.Name == "ESP" and desc:IsA("SphereHandleAdornment")) or (desc.Name == "ESP_Text" and desc:IsA("BillboardGui")) then
                    desc:Destroy()
                end
            end
            task.wait(0.5)
        end
    end
end)

--================================================================--
-- NO CLIP
--================================================================--
local NoclipToggle = false

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
-- GUI: CREATE WINDOW
--================================================================--
local Window = Library:CreateWindow({
    Title = "Vgxmod Hub",
    Footer = "Mines",
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

local EspLeft = MainTab:AddRightGroupbox("ESP", "eye")
local PlayerLeft = MainTab:AddLeftGroupbox("PLAYER", "user")
local ChestLeft = MainTab:AddLeftGroupbox("Chest", "anchor")

--================================================================--
-- ESP SYSTEM INTEGRATION
--================================================================--

EspLeft:AddToggle("ESPToggle", {
    Text = "Criminal/Sherif ESP",
    Default = false,
    Callback = function(state)
        ESP_ENABLED = state
    end
})


--================================================================--
-- AUTOMATION 
--================================================================--
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

ChestLeft:AddButton({
    Text = "Collect Normal Chest",
    Func = function()
        pcall(function()
            if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart
                local target = Workspace:FindFirstChild("Lobby")
                    and Workspace.Lobby:FindFirstChild("Obby")
                    and Workspace.Lobby.Obby:FindFirstChild("ObbyEndPart")
                
                if target then
                    firetouchinterest(hrp, target, 0)
                    task.wait()
                    firetouchinterest(hrp, target, 1)
                end
            end
        end)
    end,
})

ChestLeft:AddButton({
    Text = "Collect Hard Chest",
    Func = function()
        pcall(function()
            if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart
                local target = Workspace:FindFirstChild("Lobby")
                    and Workspace.Lobby:FindFirstChild("Obby")
                    and Workspace.Lobby.Obby:FindFirstChild("HardObbyEndPart")
                
                if target then
                    firetouchinterest(hrp, target, 0)
                    task.wait()
                    firetouchinterest(hrp, target, 1)
                end
            end
        end)
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
