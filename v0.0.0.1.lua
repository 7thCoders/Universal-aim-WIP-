-- AeGiS Ultimate Auto-Aim with Range Adjuster
-- Press [F] to enable soft aim assist
-- Press [RightShift] to toggle range adjuster

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIG --
local AimKey = Enum.KeyCode.F
local MenuKey = Enum.KeyCode.RightShift
local DefaultSettings = {
    InfluenceStrength = 0.25,
    TeamCheck = true,
    MaxDistance = 1000, -- This is what we'll adjust
    FOVSize = 60,
    HeadPriority = true,
    ShowVisuals = true,
    MenuVisible = false
}

-- STATE --
local Settings = table.clone(DefaultSettings)
local Active = false
local CurrentTarget = nil
local SuggestedLookVector = nil

-- UI SETUP --
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AeGiS_UI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Visual Indicator
local Indicator = Instance.new("Frame")
Indicator.Size = UDim2.new(0, 8, 0, 8)
Indicator.Position = UDim2.new(0.5, -4, 0.5, -4)
Indicator.BackgroundColor3 = Color3.new(1, 0, 0)
Indicator.BorderSizePixel = 0
Indicator.Visible = false
Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)
Indicator.Parent = screenGui

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 200, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 40)
StatusLabel.BackgroundTransparency = 0.7
StatusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
StatusLabel.TextColor3 = Color3.new(1, 1, 1)
StatusLabel.Font = Enum.Font.SourceSansBold
StatusLabel.TextSize = 14
StatusLabel.Text = "AeGiS: READY [F]"
StatusLabel.Parent = screenGui

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = Settings.FOVSize * 2
FOVCircle.Thickness = 2
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8
FOVCircle.Color = Color3.fromRGB(0, 170, 255)
FOVCircle.Visible = Settings.ShowVisuals
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

-- Simple Range Adjuster Menu
local MenuFrame = Instance.new("Frame")
MenuFrame.Size = UDim2.new(0, 300, 0, 80)
MenuFrame.Position = UDim2.new(0.5, -150, 0.5, -40)
MenuFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MenuFrame.BorderSizePixel = 0
MenuFrame.Visible = false
MenuFrame.ZIndex = 100
MenuFrame.Active = true
Instance.new("UICorner", MenuFrame).CornerRadius = UDim.new(0, 8)

local MenuTitle = Instance.new("TextLabel")
MenuTitle.Size = UDim2.new(1, 0, 0, 30)
MenuTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MenuTitle.TextColor3 = Color3.new(1, 1, 1)
MenuTitle.Font = Enum.Font.SourceSansBold
MenuTitle.TextSize = 18
MenuTitle.Text = "Range Adjuster (Drag)"
MenuTitle.Parent = MenuFrame

-- Make menu draggable
local dragging, dragInput, dragStart, startPos

MenuTitle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MenuFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MenuTitle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MenuFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Range Slider
local RangeSlider = Instance.new("Frame")
RangeSlider.Size = UDim2.new(0.9, 0, 0, 50)
RangeSlider.Position = UDim2.new(0.05, 0, 0, 35)
RangeSlider.BackgroundTransparency = 1
RangeSlider.ZIndex = 101
RangeSlider.Parent = MenuFrame

local RangeLabel = Instance.new("TextLabel")
RangeLabel.Size = UDim2.new(1, 0, 0, 20)
RangeLabel.Text = "Range: "..Settings.MaxDistance
RangeLabel.TextColor3 = Color3.new(1, 1, 1)
RangeLabel.Font = Enum.Font.SourceSans
RangeLabel.TextSize = 14
RangeLabel.TextXAlignment = Enum.TextXAlignment.Left
RangeLabel.BackgroundTransparency = 1
RangeLabel.ZIndex = 101
RangeLabel.Parent = RangeSlider

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, 0, 0, 10)
SliderTrack.Position = UDim2.new(0, 0, 0, 25)
SliderTrack.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
SliderTrack.BorderSizePixel = 0
SliderTrack.ZIndex = 101
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)
SliderTrack.Parent = RangeSlider

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new((Settings.MaxDistance-10)/1990, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
SliderFill.BorderSizePixel = 0
SliderFill.ZIndex = 101
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
SliderFill.Parent = SliderTrack

local SliderHandle = Instance.new("TextButton")
SliderHandle.Size = UDim2.new(0, 15, 0, 15)
SliderHandle.Position = UDim2.new((Settings.MaxDistance-10)/1990, -7.5, 0.5, -7.5)
SliderHandle.BackgroundColor3 = Color3.new(1, 1, 1)
SliderHandle.Text = ""
SliderHandle.BorderSizePixel = 0
SliderHandle.ZIndex = 102
Instance.new("UICorner", SliderHandle).CornerRadius = UDim.new(1, 0)
SliderHandle.Parent = SliderTrack

local sliding = false
SliderHandle.MouseButton1Down:Connect(function()
    sliding = true
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
        local xPos = (input.Position.X - SliderTrack.AbsolutePosition.X)/SliderTrack.AbsoluteSize.X
        xPos = math.clamp(xPos, 0, 1)
        local newRange = 10 + (1990 * xPos)
        newRange = math.floor(newRange)
        
        SliderFill.Size = UDim2.new(xPos, 0, 1, 0)
        SliderHandle.Position = UDim2.new(xPos, -7.5, 0.5, -7.5)
        RangeLabel.Text = "Range: "..newRange
        Settings.MaxDistance = newRange
    end
end)

MenuFrame.Parent = screenGui

-- Toggle menu function
local function ToggleMenu()
    Settings.MenuVisible = not Settings.MenuVisible
    MenuFrame.Visible = Settings.MenuVisible
    if Settings.MenuVisible then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end

-- FIND TARGET --  
local function FindBestTarget()
    local bestTarget, bestScore = nil, -math.huge
    local cameraPos = Camera.CFrame.Position
    local cameraLook = Camera.CFrame.LookVector
    local fovAngleRad = math.rad(Settings.FOVSize / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        if not char then continue end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or not root then continue end

        local targetPos = Settings.HeadPriority and char:FindFirstChild("Head") and char.Head.Position or root.Position
        local distance = (targetPos - cameraPos).Magnitude
        if distance > Settings.MaxDistance then continue end

        local direction = (targetPos - cameraPos).Unit
        local angle = math.acos(math.clamp(cameraLook:Dot(direction), -1, 1))
        if angle > fovAngleRad then continue end

        local distanceScore = 1 / distance
        local angleScore = 1 - (angle / fovAngleRad)
        local score = distanceScore * angleScore
        
        if score > bestScore then
            bestScore = score
            bestTarget = player
        end
    end

    return bestTarget
end

-- UPDATE AIM TARGET --
local function CalculateAimSuggestion()
    if not Active then
        SuggestedLookVector = nil
        if Settings.ShowVisuals then
            Indicator.BackgroundColor3 = Color3.new(1, 0, 0)
            StatusLabel.Text = "AeGiS: READY [F]"
        end
        return
    end

    local newTarget = FindBestTarget()
    if newTarget ~= CurrentTarget then
        CurrentTarget = newTarget
    end

    if CurrentTarget and CurrentTarget.Character then
        local part = Settings.HeadPriority and CurrentTarget.Character:FindFirstChild("Head") or
                     CurrentTarget.Character:FindFirstChild("HumanoidRootPart")

        if part and CurrentTarget.Character:FindFirstChildOfClass("Humanoid") and CurrentTarget.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            SuggestedLookVector = (part.Position - Camera.CFrame.Position).Unit
            if Settings.ShowVisuals then
                Indicator.BackgroundColor3 = Color3.new(0, 1, 0)
                StatusLabel.Text = "AeGiS: LOCKED"
                Indicator.Visible = true
            end
        else
            SuggestedLookVector = nil
            if Settings.ShowVisuals then
                Indicator.BackgroundColor3 = Color3.new(1, 1, 0)
                StatusLabel.Text = "AeGiS: SEARCHING"
            end
        end
    else
        SuggestedLookVector = nil
        if Settings.ShowVisuals then
            Indicator.BackgroundColor3 = Color3.new(1, 1, 0)
            StatusLabel.Text = "AeGiS: SEARCHING"
        end
    end
end

-- GENTLY INFLUENCE CAMERA --
local function ApplyAimAssist()
    if SuggestedLookVector then
        local currentLook = Camera.CFrame.LookVector
        local newLook = currentLook:Lerp(SuggestedLookVector, Settings.InfluenceStrength)
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + newLook)
    end
end

-- INPUT LISTENERS --
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == AimKey then
        Active = true
        if Settings.ShowVisuals then
            Indicator.Visible = true
            StatusLabel.Text = "AeGiS: ACTIVE [F]"
        end
    elseif input.KeyCode == MenuKey then
        ToggleMenu()
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == AimKey then
        Active = false
        if Settings.ShowVisuals then
            Indicator.Visible = false
            StatusLabel.Text = "AeGiS: READY [F]"
        end
    end
end)

-- RENDER LOOP --
RunService.RenderStepped:Connect(function()
    CalculateAimSuggestion()
    ApplyAimAssist()
    
    -- Update FOV circle to center of screen
    if Settings.ShowVisuals then
        local viewportSize = Camera.ViewportSize
        FOVCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        FOVCircle.Radius = Settings.FOVSize * 2
    end
end)

-- Initialize mouse behavior
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

-- Cleanup on script termination
screenGui.Destroying:Connect(function()
    if FOVCircle then
        FOVCircle:Remove()
    end
    -- Restore mouse behavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end)

print("AeGiS Auto-Aim Loaded | Press [F] to toggle assist | [RightShift] for range adjuster")
