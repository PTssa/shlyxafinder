-- ============================================================
-- SCRIPTERBLOX HUB | AUTO JOINER — Improved GUI
-- ============================================================

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

pcall(function()
    local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
    local clientId = RbxAnalyticsService:GetClientId()
end)

-- ======================== SETTINGS ========================
local autoJoinEnabled = false
local minMoneyThreshold = 1

-- ====================== UTILITIES =========================

local function parseMoneyValue(moneyString)
    local value = moneyString:match("%$([%d%.]+)")
    if not value then return 0 end
    local number = tonumber(value)
    if not number then return 0 end
    if moneyString:match("M") then
        return number
    elseif moneyString:match("K") then
        return number / 1000
    end
    return number
end

local function shouldJoinServer(data)
    if not autoJoinEnabled then return false end
    if not data or not data.money then return false end
    local moneyValue = parseMoneyValue(data.money)
    return moneyValue >= minMoneyThreshold
end

local function executeJoinScript(joinScript)
    if not joinScript then return end
    local success, err = pcall(function()
        loadstring(joinScript)()
    end)
    if not success then
        warn("Failed to join server:", err)
    end
end

local function tween(obj, props, duration, style, direction)
    duration = duration or 0.3
    style = style or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.Out
    local tw = TweenService:Create(obj, TweenInfo.new(duration, style, direction), props)
    tw:Play()
    return tw
end

local function createCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = parent
    return corner
end

local function createStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(130, 80, 220)
    stroke.Thickness = thickness or 1.5
    stroke.Transparency = transparency or 0.5
    stroke.Parent = parent
    return stroke
end

-- ====================== GUI BUILD =========================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScripterbloxHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = game:GetService("CoreGui")

-- ~~~ SHADOW ~~~
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(0, 380, 0, 310)
shadow.Position = UDim2.new(0.5, -190, 0.4, -140)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.Parent = screenGui

-- ~~~ MAIN FRAME ~~~
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 340, 0, 270)
mainFrame.Position = UDim2.new(0.5, -170, 0.4, -135)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 18, 35)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(100, 60, 180), 1.5, 0.4)

-- Background gradient
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 20, 48)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(22, 18, 35)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 30)),
})
bgGradient.Rotation = 135
bgGradient.Parent = mainFrame

-- ~~~ DRAGGING ~~~
local dragging = false
local dragInput, dragStart, startPos

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        local shadowOffset = shadow.Position - mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        mainFrame.Position = newPos
        shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset - 20, newPos.Y.Scale, newPos.Y.Offset - 5)
    end
end)

-- ~~~ TITLE BAR ~~~
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
createCorner(titleBar, 14)

-- Fix bottom corners of title bar
local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 14)
titleBarFix.Position = UDim2.new(0, 0, 1, -14)
titleBarFix.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
titleBarFix.BorderSizePixel = 0
titleBarFix.Parent = titleBar

-- Title gradient accent line
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, 0)
accentLine.BorderSizePixel = 0
accentLine.Parent = titleBar

local accentGradient = Instance.new("UIGradient")
accentGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 60, 200)),
})
accentGradient.Parent = accentLine

-- Logo icon
local logoIcon = Instance.new("TextLabel")
logoIcon.Size = UDim2.new(0, 28, 0, 28)
logoIcon.Position = UDim2.new(0, 12, 0.5, -14)
logoIcon.BackgroundColor3 = Color3.fromRGB(120, 70, 220)
logoIcon.Text = "S"
logoIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
logoIcon.Font = Enum.Font.GothamBold
logoIcon.TextSize = 16
logoIcon.Parent = titleBar
createCorner(logoIcon, 7)

local logoGradient = Instance.new("UIGradient")
logoGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 90, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 200)),
})
logoGradient.Rotation = 45
logoGradient.Parent = logoIcon

-- Title text
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 48, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SCRIPTERBLOX HUB"
titleLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Subtitle badge
local subtitleBadge = Instance.new("TextLabel")
subtitleBadge.Size = UDim2.new(0, 80, 0, 18)
subtitleBadge.Position = UDim2.new(0, 50, 0.5, 3)
subtitleBadge.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
subtitleBadge.BackgroundTransparency = 0.7
subtitleBadge.Text = "AUTO JOINER"
subtitleBadge.TextColor3 = Color3.fromRGB(180, 150, 240)
subtitleBadge.Font = Enum.Font.GothamBold
subtitleBadge.TextSize = 9
subtitleBadge.Parent = titleBar
createCorner(subtitleBadge, 4)

-- ~~~ WINDOW BUTTONS ~~~
local function createWindowBtn(text, posX, color, hoverColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 26, 0, 26)
    btn.Position = UDim2.new(1, posX, 0.5, -13)
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.8
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 180, 230)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = titleBar
    createCorner(btn, 6)

    btn.MouseEnter:Connect(function()
        tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = hoverColor}, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, {BackgroundTransparency = 0.8, BackgroundColor3 = color}, 0.2)
    end)
    return btn
end

-- Minimize button
local minimizeBtn = createWindowBtn("—", -62, Color3.fromRGB(80, 60, 140), Color3.fromRGB(100, 80, 180))
-- Close button
local closeBtn = createWindowBtn("✕", -32, Color3.fromRGB(80, 60, 140), Color3.fromRGB(200, 60, 80))

local minimized = false
local originalSize = mainFrame.Size

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(mainFrame, {Size = UDim2.new(0, 340, 0, 42)}, 0.35)
        tween(shadow, {Size = UDim2.new(0, 380, 0, 82)}, 0.35)
    else
        tween(mainFrame, {Size = originalSize}, 0.35)
        tween(shadow, {Size = UDim2.new(0, 380, 0, 310)}, 0.35)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.4, 0)}, 0.3)
    tween(shadow, {ImageTransparency = 1}, 0.3)
    task.wait(0.35)
    screenGui:Destroy()
end)

-- ~~~ CONTENT AREA ~~~
local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -24, 1, -56)
contentFrame.Position = UDim2.new(0, 12, 0, 50)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- ~~~ TOGGLE BUTTON ~~~
local toggleFrame = Instance.new("Frame")
toggleFrame.Size = UDim2.new(1, 0, 0, 42)
toggleFrame.Position = UDim2.new(0, 0, 0, 0)
toggleFrame.BackgroundColor3 = Color3.fromRGB(32, 26, 55)
toggleFrame.BorderSizePixel = 0
toggleFrame.Parent = contentFrame
createCorner(toggleFrame, 10)
createStroke(toggleFrame, Color3.fromRGB(80, 50, 150), 1, 0.6)

local toggleLabel = Instance.new("TextLabel")
toggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
toggleLabel.Position = UDim2.new(0, 14, 0, 0)
toggleLabel.BackgroundTransparency = 1
toggleLabel.Text = "⚡ Auto Join"
toggleLabel.TextColor3 = Color3.fromRGB(200, 185, 240)
toggleLabel.Font = Enum.Font.GothamBold
toggleLabel.TextSize = 14
toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
toggleLabel.Parent = toggleFrame

-- Toggle switch
local toggleSwitch = Instance.new("TextButton")
toggleSwitch.Size = UDim2.new(0, 50, 0, 24)
toggleSwitch.Position = UDim2.new(1, -64, 0.5, -12)
toggleSwitch.BackgroundColor3 = Color3.fromRGB(60, 45, 90)
toggleSwitch.Text = ""
toggleSwitch.Parent = toggleFrame
createCorner(toggleSwitch, 12)

local toggleCircle = Instance.new("Frame")
toggleCircle.Size = UDim2.new(0, 18, 0, 18)
toggleCircle.Position = UDim2.new(0, 3, 0.5, -9)
toggleCircle.BackgroundColor3 = Color3.fromRGB(150, 130, 180)
toggleCircle.Parent = toggleSwitch
createCorner(toggleCircle, 9)

local statusDot = Instance.new("TextLabel")
statusDot.Size = UDim2.new(0, 60, 0, 18)
statusDot.Position = UDim2.new(1, -130, 0.5, -9)
statusDot.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
statusDot.BackgroundTransparency = 0.6
statusDot.Text = "OFF"
statusDot.TextColor3 = Color3.fromRGB(255, 200, 200)
statusDot.Font = Enum.Font.GothamBold
statusDot.TextSize = 10
statusDot.Parent = toggleFrame
createCorner(statusDot, 4)

toggleSwitch.MouseButton1Click:Connect(function()
    autoJoinEnabled = not autoJoinEnabled
    if autoJoinEnabled then
        tween(toggleCircle, {Position = UDim2.new(1, -21, 0.5, -9), BackgroundColor3 = Color3.fromRGB(140, 255, 160)}, 0.25)
        tween(toggleSwitch, {BackgroundColor3 = Color3.fromRGB(60, 160, 90)}, 0.25)
        tween(statusDot, {BackgroundColor3 = Color3.fromRGB(60, 180, 100)}, 0.2)
        statusDot.Text = "ON"
        statusDot.TextColor3 = Color3.fromRGB(180, 255, 200)
    else
        tween(toggleCircle, {Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = Color3.fromRGB(150, 130, 180)}, 0.25)
        tween(toggleSwitch, {BackgroundColor3 = Color3.fromRGB(60, 45, 90)}, 0.25)
        tween(statusDot, {BackgroundColor3 = Color3.fromRGB(200, 60, 80)}, 0.2)
        statusDot.Text = "OFF"
        statusDot.TextColor3 = Color3.fromRGB(255, 200, 200)
    end
end)

-- ~~~ MONEY THRESHOLD ~~~
local thresholdFrame = Instance.new("Frame")
thresholdFrame.Size = UDim2.new(1, 0, 0, 42)
thresholdFrame.Position = UDim2.new(0, 0, 0, 50)
thresholdFrame.BackgroundColor3 = Color3.fromRGB(32, 26, 55)
thresholdFrame.BorderSizePixel = 0
thresholdFrame.Parent = contentFrame
createCorner(thresholdFrame, 10)
createStroke(thresholdFrame, Color3.fromRGB(80, 50, 150), 1, 0.6)

local thresholdLabel = Instance.new("TextLabel")
thresholdLabel.Size = UDim2.new(0.55, 0, 1, 0)
thresholdLabel.Position = UDim2.new(0, 14, 0, 0)
thresholdLabel.BackgroundTransparency = 1
thresholdLabel.Text = "💰 Min M/s Threshold"
thresholdLabel.TextColor3 = Color3.fromRGB(200, 185, 240)
thresholdLabel.Font = Enum.Font.GothamBold
thresholdLabel.TextSize = 13
thresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
thresholdLabel.Parent = thresholdFrame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(0, 80, 0, 26)
inputBox.Position = UDim2.new(1, -94, 0.5, -13)
inputBox.BackgroundColor3 = Color3.fromRGB(45, 35, 75)
inputBox.Text = "1"
inputBox.PlaceholderText = "M/s..."
inputBox.TextColor3 = Color3.fromRGB(180, 255, 200)
inputBox.Font = Enum.Font.GothamBold
inputBox.TextSize = 14
inputBox.ClearTextOnFocus = false
inputBox.Parent = thresholdFrame
createCorner(inputBox, 7)
createStroke(inputBox, Color3.fromRGB(100, 70, 180), 1, 0.5)

local inputSuffix = Instance.new("TextLabel")
inputSuffix.Size = UDim2.new(0, 20, 1, 0)
inputSuffix.Position = UDim2.new(1, -24, 0, 0)
inputSuffix.BackgroundTransparency = 1
inputSuffix.Text = "M"
inputSuffix.TextColor3 = Color3.fromRGB(140, 120, 180)
inputSuffix.Font = Enum.Font.GothamBold
inputSuffix.TextSize = 12
inputSuffix.Parent = inputBox

inputBox.Focused:Connect(function()
    tween(inputBox, {BackgroundColor3 = Color3.fromRGB(55, 40, 90)}, 0.2)
end)

inputBox.FocusLost:Connect(function()
    tween(inputBox, {BackgroundColor3 = Color3.fromRGB(45, 35, 75)}, 0.2)
    local value = tonumber(inputBox.Text)
    if value and value > 0 then
        minMoneyThreshold = value
    else
        inputBox.Text = tostring(minMoneyThreshold)
    end
end)

-- ~~~ SEPARATOR ~~~
local separator = Instance.new("Frame")
separator.Size = UDim2.new(1, -20, 0, 1)
separator.Position = UDim2.new(0, 10, 0, 102)
separator.BackgroundColor3 = Color3.fromRGB(80, 60, 140)
separator.BackgroundTransparency = 0.6
separator.BorderSizePixel = 0
separator.Parent = contentFrame

-- ~~~ STATUS PANEL ~~~
local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, 0, 0, 70)
statusPanel.Position = UDim2.new(0, 0, 0, 112)
statusPanel.BackgroundColor3 = Color3.fromRGB(26, 20, 42)
statusPanel.BorderSizePixel = 0
statusPanel.Parent = contentFrame
createCorner(statusPanel, 10)
createStroke(statusPanel, Color3.fromRGB(70, 45, 130), 1, 0.6)

local statusTitle = Instance.new("TextLabel")
statusTitle.Size = UDim2.new(1, -20, 0, 20)
statusTitle.Position = UDim2.new(0, 12, 0, 6)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "📡 SERVER STATUS"
statusTitle.TextColor3 = Color3.fromRGB(140, 120, 190)
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextSize = 10
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = statusPanel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusText"
statusLabel.Size = UDim2.new(1, -24, 0, 36)
statusLabel.Position = UDim2.new(0, 12, 0, 28)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "⏳ Waiting for servers..."
statusLabel.TextColor3 = Color3.fromRGB(180, 165, 215)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Parent = statusPanel

-- Pulsing dot indicator
local pulsingDot = Instance.new("Frame")
pulsingDot.Size = UDim2.new(0, 8, 0, 8)
pulsingDot.Position = UDim2.new(1, -20, 0, 12)
pulsingDot.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
pulsingDot.Parent = statusPanel
createCorner(pulsingDot, 4)

-- Pulse animation
spawn(function()
    while screenGui.Parent do
        tween(pulsingDot, {BackgroundTransparency = 0.7}, 0.8)
        task.wait(0.85)
        tween(pulsingDot, {BackgroundTransparency = 0}, 0.8)
        task.wait(0.85)
    end
end)

-- ~~~ BOTTOM BAR ~~~
local bottomBar = Instance.new("TextLabel")
bottomBar.Size = UDim2.new(1, 0, 0, 18)
bottomBar.Position = UDim2.new(0, 0, 0, 192)
bottomBar.BackgroundTransparency = 1
bottomBar.Text = "scripterblox.com • v2.0"
bottomBar.TextColor3 = Color3.fromRGB(80, 65, 120)
bottomBar.Font = Enum.Font.Gotham
bottomBar.TextSize = 10
bottomBar.Parent = contentFrame

-- ===================== OPEN ANIMATION =====================
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
shadow.ImageTransparency = 1

task.wait(0.1)
tween(mainFrame, {Size = originalSize, Position = UDim2.new(0.5, -170, 0.4, -135)}, 0.45, Enum.EasingStyle.Back)
tween(shadow, {ImageTransparency = 0.6}, 0.5)

-- ==================== WEBSOCKET =========================
local websocket = WebSocket.connect("ws://144.172.110.44:8765/script")

websocket.OnMessage:Connect(function(message)
    local success, serverData = pcall(function()
        return HttpService:JSONDecode(message)
    end)
    
    if not success then
        warn("Failed to decode message:", message)
        return
    end
    
    if serverData.type == "snapshot" and serverData.data then
        local data = serverData.data
        
        statusLabel.Text = string.format("🖥 %s  •  %s  •  %s", 
            data.name or "Unknown",
            data.money or "$0",
            data.channel or "—"
        )
        statusLabel.TextColor3 = Color3.fromRGB(180, 165, 215)
        pulsingDot.BackgroundColor3 = Color3.fromRGB(100, 200, 140)
        
        if shouldJoinServer(data) then
            statusLabel.Text = "🚀 Joining: " .. (data.name or "Unknown") .. "..."
            statusLabel.TextColor3 = Color3.fromRGB(140, 255, 170)
            pulsingDot.BackgroundColor3 = Color3.fromRGB(100, 255, 140)
            
            task.wait(0.5)
            executeJoinScript(data.join_script)
        end
    end
end)

websocket.OnClose:Connect(function()
    statusLabel.Text = "🔴 Disconnected from server"
    statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    pulsingDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
end)

print("✅ Scripterblox Hub Auto Joiner v2.0 loaded")
