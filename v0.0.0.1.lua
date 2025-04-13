-- AeGiS Ultimate Auto-Aim with Configurable Settings
-- Press [F] to enable soft aim assist
-- Press [RightShift] to toggle settings menu

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
    MaxDistance = 1000,
    FOVSize = 60, -- Degrees
    HeadPriority = true,
    ShowVisuals = true,
    MenuVisible = false
}

-- STATE --
local Settings = table.clone(DefaultSettings)
local Active = false
local CurrentTarget = nil
local SuggestedLookVector = nil
local CursorFreeGui = nil
local FakeCursor = nil

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

-- Create fake cursor
local function CreateFakeCursor()
    if FakeCursor then FakeCursor:Destroy() end
    
    FakeCursor = Instance.new("Frame")
    FakeCursor.Name = "FakeCursor"
    FakeCursor.Size = UDim2.new(0, 12, 0, 12)
    FakeCursor.AnchorPoint = Vector2.new(0.5, 0.5)
    FakeCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    FakeCursor.BackgroundTransparency = 0.5
    FakeCursor.BorderSizePixel = 0
    FakeCursor.ZIndex = 999
    
    local innerDot = Instance.new("Frame")
    innerDot.Size = UDim2.new(0, 4, 0, 4)
    innerDot.Position = UDim2.new(0.5, -2, 0.5, -2)
    innerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    innerDot.BackgroundColor3 = Color3.new(0, 0, 0)
    innerDot.BorderSizePixel = 0
    innerDot.Parent = FakeCursor
    
    Instance.new("UICorner", FakeCursor).CornerRadius = UDim.new(1, 0)
    Instance.new("UICorner", innerDot).CornerRadius = UDim.new(1, 0)
    
    FakeCursor.Parent = screenGui
    FakeCursor.Visible = false
end

-- Create cursor-free gui function
local function CreateCursorFreeGui()
    if CursorFreeGui then CursorFreeGui:Destroy() end
    
    CursorFreeGui = Instance.new("ScreenGui")
    CursorFreeGui.Name = "AeGiS_CursorFree"
    CursorFreeGui.ResetOnSpawn = false
    CursorFreeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    CursorFreeGui.DisplayOrder = 999
    CursorFreeGui.IgnoreGuiInset = true
    
    local modalButton = Instance.new("TextButton")
    modalButton.Size = UDim2.new(1, 0, 1, 0)
    modalButton.BackgroundTransparency = 1
    modalButton.Text = ""
    modalButton.Modal = true
    modalButton.Selectable = false
    modalButton.Active = true
    modalButton.Parent = CursorFreeGui
    
    -- Dark background overlay
    local background = Instance.new("Frame")
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.new(0, 0, 0)
    background.BackgroundTransparency = 0.7
    background.ZIndex = 0
    background.Parent = CursorFreeGui
    
    CursorFreeGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    CursorFreeGui.Enabled = false
end

-- Settings Menu
local MenuFrame = Instance.new("Frame")
MenuFrame.Size = UDim2.new(0, 300, 0, 350)
MenuFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MenuFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MenuFrame.BorderSizePixel = 0
MenuFrame.Visible = false
MenuFrame.ZIndex = 1000
MenuFrame.Active = true
MenuFrame.Selectable = true
Instance.new("UICorner", MenuFrame).CornerRadius = UDim.new(0, 8)

local MenuTitle = Instance.new("TextLabel")
MenuTitle.Size = UDim2.new(1, 0, 0, 30)
MenuTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MenuTitle.TextColor3 = Color3.new(1, 1, 1)
MenuTitle.Font = Enum.Font.SourceSansBold
MenuTitle.TextSize = 18
MenuTitle.Text = "AeGiS Settings (Drag)"
MenuTitle.Parent = MenuFrame

-- Make menu draggable
local dragging
local dragInput
local dragStart
local startPos

local function onMenuInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
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
end

local function onMenuInputChanged(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end

MenuTitle.InputBegan:Connect(onMenuInputBegan)
MenuTitle.InputChanged:Connect(onMenuInputChanged)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MenuFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Sliders and Toggles
local yOffset = 40
local function CreateSlider(label, min, max, value, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0.9, 0, 0, 50)
    sliderFrame.Position = UDim2.new(0.05, 0, 0, yOffset)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.ZIndex = 1001
    sliderFrame.Parent = MenuFrame
    
    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(1, 0, 0, 20)
    labelText.Text = label .. ": " .. tostring(value)
    labelText.TextColor3 = Color3.new(1, 1, 1)
    labelText.Font = Enum.Font.SourceSans
    labelText.TextSize = 14
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.BackgroundTransparency = 1
    labelText.ZIndex = 1001
    labelText.Parent = sliderFrame
    
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 10)
    slider.Position = UDim2.new(0, 0, 0, 25)
    slider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    slider.BorderSizePixel = 0
    slider.ZIndex = 1001
    Instance.new("UICorner", slider).CornerRadius = UDim.new(1, 0)
    slider.Parent = sliderFrame
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.ZIndex = 1001
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    fill.Parent = slider
    
    local handle = Instance.new("TextButton")
    handle.Size = UDim2.new(0, 15, 0, 15)
    handle.Position = UDim2.new((value - min) / (max - min), -7.5, 0.5, -7.5)
    handle.BackgroundColor3 = Color3.new(1, 1, 1)
    handle.Text = ""
    handle.BorderSizePixel = 0
    handle.ZIndex = 1002
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)
    handle.Parent = slider
    
    local sliding = false
    
    handle.MouseButton1Down:Connect(function()
        sliding = true
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    
    local connection
    connection = UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            local xPos = (input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X
            xPos = math.clamp(xPos, 0, 1)
            local newValue = min + (max - min) * xPos
            newValue = math.floor(newValue * 100) / 100 -- Round to 2 decimal places
            
            fill.Size = UDim2.new(xPos, 0, 1, 0)
            handle.Position = UDim2.new(xPos, -7.5, 0.5, -7.5)
            labelText.Text = label .. ": " .. tostring(newValue)
            
            callback(newValue)
        end
    end)
    
    sliderFrame.Destroying:Connect(function()
        if connection then
            connection:Disconnect()
        end
    end)
    
    yOffset = yOffset + 55
    return sliderFrame
end

local function CreateToggle(label, value, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(0.9, 0, 0, 30)
    toggleFrame.Position = UDim2.new(0.05, 0, 0, yOffset)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.ZIndex = 1001
    toggleFrame.Parent = MenuFrame
    
    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(0.7, 0, 1, 0)
    labelText.Text = label
    labelText.TextColor3 = Color3.new(1, 1, 1)
    labelText.Font = Enum.Font.SourceSans
    labelText.TextSize = 14
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.BackgroundTransparency = 1
    labelText.ZIndex = 1001
    labelText.Parent = toggleFrame
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 50, 0, 25)
    toggle.Position = UDim2.new(0.7, 0, 0, 2.5)
    toggle.BackgroundColor3 = value and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    toggle.Text = ""
    toggle.BorderSizePixel = 0
    toggle.ZIndex = 1001
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    toggle.Parent = toggleFrame
    
    local toggleIndicator = Instance.new("Frame")
    toggleIndicator.Size = UDim2.new(0, 21, 0, 21)
    toggleIndicator.Position = UDim2.new(value and 0.58 or 0, -10.5, 0.5, -10.5)
    toggleIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
    toggleIndicator.BorderSizePixel = 0
    toggleIndicator.ZIndex = 1002
    Instance.new("UICorner", toggleIndicator).CornerRadius = UDim.new(1, 0)
    toggleIndicator.Parent = toggle
    
    toggle.MouseButton1Click:Connect(function()
        value = not value
        toggle.BackgroundColor3 = value and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
        toggleIndicator.Position = UDim2.new(value and 0.58 or 0, -10.5, 0.5, -10.5)
        callback(value)
    end)
    
    yOffset = yOffset + 35
    return toggleFrame
end

-- Create UI elements
CreateFakeCursor()
CreateCursorFreeGui()
MenuFrame.Parent = screenGui

-- Create settings controls
CreateSlider("Influence Strength", 0.01, 1, Settings.InfluenceStrength, function(value)
    Settings.InfluenceStrength = value
end)

CreateSlider("Max Distance", 10, 2000, Settings.MaxDistance, function(value)
    Settings.MaxDistance = value
end)

CreateSlider("FOV Size", 10, 180, Settings.FOVSize, function(value)
    Settings.FOVSize = value
    FOVCircle.Radius = value * 2
end)

CreateToggle("Team Check", Settings.TeamCheck, function(value)
    Settings.TeamCheck = value
end)

CreateToggle("Head Priority", Settings.HeadPriority, function(value)
    Settings.HeadPriority = value
end)

CreateToggle("Show Visuals", Settings.ShowVisuals, function(value)
    Settings.ShowVisuals = value
    FOVCircle.Visible = value
    Indicator.Visible = value and Active
end)

-- Toggle menu function
local function ToggleMenu()
    Settings.MenuVisible = not Settings.MenuVisible
    MenuFrame.Visible = Settings.MenuVisible
    CursorFreeGui.Enabled = Settings.MenuVisible
    
    if Settings.MenuVisible then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = false
        FakeCursor.Visible = true
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = true
        FakeCursor.Visible = false
    end
end

-- Update fake cursor position
local function UpdateFakeCursor()
    if FakeCursor and FakeCursor.Visible then
        local mousePos = UserInputService:GetMouseLocation()
        FakeCursor.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
    end
end

-- FIND TARGET --  
local function FindBestTarget()
    if not Settings.ShowVisuals then return nil end
    
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
    
    -- Update fake cursor position when menu is open
    if Settings.MenuVisible then
        UpdateFakeCursor()
    end
    
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
    if CursorFreeGui then
        CursorFreeGui:Destroy()
    end
    if FakeCursor then
        FakeCursor:Destroy()
    end
    -- Restore mouse behavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end)

print("AeGiS Auto-Aim Loaded | Press [F] to toggle assist | [RightShift] for settings")
