-- ============================================================
--  SCRIPTERBLOX HUB | STEAL A BRAINROT — FINDER v3.0
--  ESP • Teleport • Auto Collect • Premium GUI
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ======================== STATE ===========================
local espEnabled = false
local teleportEnabled = false
local autoCollectEnabled = false
local espObjects = {}
local guiOpen = true
local collectRange = 15
local teleportCooldown = false

-- ====================== UTILITIES =========================

local function tween(obj, props, duration, style, direction)
    duration = duration or 0.3
    style = style or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.Out
    local tw = TweenService:Create(obj, TweenInfo.new(duration, style, direction), props)
    tw:Play()
    return tw
end

local function createCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function createStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(130, 80, 220)
    s.Thickness = thickness or 1.5
    s.Transparency = transparency or 0.5
    s.Parent = parent
    return s
end

local function createPadding(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
    return p
end

-- ============== BRAINROT ITEM DETECTION ===================

local function getBrainrotFolder()
    -- scan common locations for collectible items
    for _, name in ipairs({"Brainrots", "BrainrotItems", "Items", "Collectibles", "Spawns", "BrainrotSpawns"}) do
        local folder = Workspace:FindFirstChild(name)
        if folder then return folder end
    end
    -- fallback: search deeper
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            local n = child.Name:lower()
            if n:find("brainrot") or n:find("item") or n:find("collect") or n:find("spawn") or n:find("find") then
                return child
            end
        end
    end
    return nil
end

local function isBrainrotItem(obj)
    if not obj then return false end
    local name = obj.Name:lower()
    local keywords = {"brainrot", "skibidi", "toilet", "sigma", "rizz", "gyatt", "ohio", "fanum", "tax", "mewing", "aura", "cap", "npc", "item", "collect", "find"}
    for _, kw in ipairs(keywords) do
        if name:find(kw) then return true end
    end
    -- check for ClickDetector or ProximityPrompt (collectible items)
    if obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt") then
        return true
    end
    return false
end

local function getAllBrainrots()
    local items = {}
    local folder = getBrainrotFolder()
    
    local function scan(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA("Model") or child:IsA("BasePart") or child:IsA("MeshPart")) and isBrainrotItem(child) then
                table.insert(items, child)
            end
            if child:IsA("Folder") or child:IsA("Model") then
                scan(child)
            end
        end
    end

    if folder then
        scan(folder)
    else
        scan(Workspace)
    end
    return items
end

-- ======================= ESP ==============================

local function clearESP()
    for _, data in pairs(espObjects) do
        if data.billboard then data.billboard:Destroy() end
        if data.highlight then data.highlight:Destroy() end
    end
    espObjects = {}
end

local function createESP(item)
    if espObjects[item] then return end

    local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
    if not part then return end

    -- Highlight glow
    local highlight = Instance.new("Highlight")
    highlight.Adornee = item
    highlight.FillColor = Color3.fromRGB(180, 80, 255)
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = Color3.fromRGB(255, 150, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Parent = item

    -- Billboard label
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Label"
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 160, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "🧠 " .. item.Name
    nameLabel.TextColor3 = Color3.fromRGB(220, 160, 255)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.fromRGB(40, 20, 60)
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, 0, 0.45, 0)
    distLabel.Position = UDim2.new(0, 0, 0.55, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "..."
    distLabel.TextColor3 = Color3.fromRGB(180, 255, 200)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.TextStrokeTransparency = 0.6
    distLabel.TextStrokeColor3 = Color3.fromRGB(20, 40, 20)
    distLabel.Parent = billboard

    espObjects[item] = {
        billboard = billboard,
        highlight = highlight,
        distLabel = distLabel,
        part = part,
    }
end

local function updateESP()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for item, data in pairs(espObjects) do
        if not item.Parent then
            if data.billboard then data.billboard:Destroy() end
            if data.highlight then data.highlight:Destroy() end
            espObjects[item] = nil
        else
            local dist = (data.part.Position - hrp.Position).Magnitude
            data.distLabel.Text = string.format("📏 %.0f studs", dist)
        end
    end
end

-- ==================== TELEPORT ============================

local function teleportToNearest()
    if teleportCooldown then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local items = getAllBrainrots()
    local nearest, nearestDist = nil, math.huge

    for _, item in ipairs(items) do
        local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist < nearestDist then
                nearest = part
                nearestDist = dist
            end
        end
    end

    if nearest then
        teleportCooldown = true
        hrp.CFrame = nearest.CFrame * CFrame.new(0, 3, 0)
        task.wait(0.5)
        teleportCooldown = false
        return nearest.Parent and nearest.Parent.Name or nearest.Name
    end
    return nil
end

-- =================== AUTO COLLECT =========================

local function tryCollect(item)
    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        fireproximityprompt(prompt)
        return true
    end

    local click = item:FindFirstChildWhichIsA("ClickDetector", true)
    if click then
        fireclickdetector(click)
        return true
    end

    -- try touching
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
        if part then
            local hrp = char.HumanoidRootPart
            local oldCF = hrp.CFrame
            hrp.CFrame = part.CFrame
            task.wait(0.15)
            hrp.CFrame = oldCF
            return true
        end
    end
    return false
end

-- ====================== GUI BUILD =========================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScripterbloxFinder"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = game:GetService("CoreGui")

-- ~~~ SHADOW ~~~
local shadow = Instance.new("ImageLabel")
shadow.Size = UDim2.new(0, 380, 0, 430)
shadow.Position = UDim2.new(0.5, -190, 0.35, -180)
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
mainFrame.Size = UDim2.new(0, 340, 0, 390)
mainFrame.Position = UDim2.new(0.5, -170, 0.35, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(120, 60, 220), 1.5, 0.35)

local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 18, 42)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 14, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 10, 22)),
})
bgGradient.Rotation = 150
bgGradient.Parent = mainFrame

-- ~~~ DRAGGING ~~~
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
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
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(26, 18, 44)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
createCorner(titleBar, 14)

local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 14)
titleBarFix.Position = UDim2.new(0, 0, 1, -14)
titleBarFix.BackgroundColor3 = Color3.fromRGB(26, 18, 44)
titleBarFix.BorderSizePixel = 0
titleBarFix.Parent = titleBar

-- Accent line
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, 0)
accentLine.BorderSizePixel = 0
accentLine.Parent = titleBar
local accentGrad = Instance.new("UIGradient")
accentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 80, 255)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 60, 200)),
})
accentGrad.Parent = accentLine

-- Logo
local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0, 32, 0, 32)
logo.Position = UDim2.new(0, 12, 0.5, -16)
logo.BackgroundColor3 = Color3.fromRGB(140, 60, 240)
logo.Text = "🧠"
logo.TextSize = 16
logo.Font = Enum.Font.GothamBold
logo.Parent = titleBar
createCorner(logo, 8)
local logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 40, 220)),
})
logoGrad.Rotation = 45
logoGrad.Parent = logo

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -110, 0.5, 0)
titleLabel.Position = UDim2.new(0, 52, 0, 2)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SCRIPTERBLOX HUB"
titleLabel.TextColor3 = Color3.fromRGB(230, 210, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local subBadge = Instance.new("TextLabel")
subBadge.Size = UDim2.new(0, 115, 0, 16)
subBadge.Position = UDim2.new(0, 52, 0.5, 2)
subBadge.BackgroundColor3 = Color3.fromRGB(120, 50, 200)
subBadge.BackgroundTransparency = 0.7
subBadge.Text = "BRAINROT FINDER"
subBadge.TextColor3 = Color3.fromRGB(200, 160, 255)
subBadge.Font = Enum.Font.GothamBold
subBadge.TextSize = 9
subBadge.Parent = titleBar
createCorner(subBadge, 4)

-- Window buttons
local function winBtn(text, px, baseColor, hoverColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 28, 0, 28)
    btn.Position = UDim2.new(1, px, 0.5, -14)
    btn.BackgroundColor3 = baseColor
    btn.BackgroundTransparency = 0.8
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 180, 240)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = titleBar
    createCorner(btn, 7)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = hoverColor}, 0.2) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundTransparency = 0.8, BackgroundColor3 = baseColor}, 0.2) end)
    return btn
end

local minimizeBtn = winBtn("—", -66, Color3.fromRGB(80, 60, 140), Color3.fromRGB(100, 80, 200))
local closeBtn = winBtn("✕", -34, Color3.fromRGB(80, 60, 140), Color3.fromRGB(220, 50, 70))

local minimized = false
local fullSize = mainFrame.Size

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(mainFrame, {Size = UDim2.new(0, 340, 0, 46)}, 0.35)
        tween(shadow, {Size = UDim2.new(0, 380, 0, 86)}, 0.35)
    else
        tween(mainFrame, {Size = fullSize}, 0.35)
        tween(shadow, {Size = UDim2.new(0, 380, 0, 430)}, 0.35)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    clearESP()
    espEnabled = false
    autoCollectEnabled = false
    tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.4, 0)}, 0.3)
    tween(shadow, {ImageTransparency = 1}, 0.3)
    task.wait(0.35)
    screenGui:Destroy()
end)

-- ~~~ CONTENT ~~~
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -24, 1, -60)
content.Position = UDim2.new(0, 12, 0, 54)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- ====== TOGGLE ROW BUILDER ======
local function createToggleRow(parent, yPos, icon, label, defaultState, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(28, 22, 48)
    row.BorderSizePixel = 0
    row.Parent = parent
    createCorner(row, 10)
    createStroke(row, Color3.fromRGB(80, 50, 150), 1, 0.6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = icon .. "  " .. label
    lbl.TextColor3 = Color3.fromRGB(200, 185, 240)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    -- Toggle switch
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 50, 0, 24)
    sw.Position = UDim2.new(1, -64, 0.5, -12)
    sw.BackgroundColor3 = Color3.fromRGB(50, 38, 80)
    sw.Text = ""
    sw.Parent = row
    createCorner(sw, 12)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = Color3.fromRGB(140, 120, 180)
    circle.Parent = sw
    createCorner(circle, 9)

    local state = defaultState or false

    local function updateVisual()
        if state then
            tween(circle, {Position = UDim2.new(1, -21, 0.5, -9), BackgroundColor3 = Color3.fromRGB(140, 255, 160)}, 0.25)
            tween(sw, {BackgroundColor3 = Color3.fromRGB(50, 170, 90)}, 0.25)
            tween(row, {BackgroundColor3 = Color3.fromRGB(30, 38, 50)}, 0.2)
        else
            tween(circle, {Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = Color3.fromRGB(140, 120, 180)}, 0.25)
            tween(sw, {BackgroundColor3 = Color3.fromRGB(50, 38, 80)}, 0.25)
            tween(row, {BackgroundColor3 = Color3.fromRGB(28, 22, 48)}, 0.2)
        end
    end

    sw.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        onToggle(state)
    end)

    return row, sw, state
end

-- ====== TOGGLES ======

-- 1. ESP Toggle
createToggleRow(content, 0, "👁", "ESP Highlight", false, function(on)
    espEnabled = on
    if not on then clearESP() end
end)

-- 2. Auto Collect Toggle
createToggleRow(content, 52, "🧲", "Auto Collect", false, function(on)
    autoCollectEnabled = on
end)

-- 3. Separator
local sep1 = Instance.new("Frame")
sep1.Size = UDim2.new(1, -20, 0, 1)
sep1.Position = UDim2.new(0, 10, 0, 108)
sep1.BackgroundColor3 = Color3.fromRGB(90, 60, 160)
sep1.BackgroundTransparency = 0.6
sep1.BorderSizePixel = 0
sep1.Parent = content

-- 4. Teleport Button
local tpBtn = Instance.new("TextButton")
tpBtn.Size = UDim2.new(1, 0, 0, 42)
tpBtn.Position = UDim2.new(0, 0, 0, 118)
tpBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
tpBtn.Text = "⚡  Teleport to Nearest"
tpBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
tpBtn.Font = Enum.Font.GothamBold
tpBtn.TextSize = 14
tpBtn.Parent = content
createCorner(tpBtn, 10)
createStroke(tpBtn, Color3.fromRGB(140, 80, 255), 1, 0.4)

local tpGrad = Instance.new("UIGradient")
tpGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 60, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 40, 180)),
})
tpGrad.Rotation = 90
tpGrad.Parent = tpBtn

tpBtn.MouseEnter:Connect(function()
    tween(tpBtn, {BackgroundColor3 = Color3.fromRGB(130, 70, 240)}, 0.2)
end)
tpBtn.MouseLeave:Connect(function()
    tween(tpBtn, {BackgroundColor3 = Color3.fromRGB(100, 50, 200)}, 0.2)
end)

-- 5. Teleport All Button
local tpAllBtn = Instance.new("TextButton")
tpAllBtn.Size = UDim2.new(1, 0, 0, 42)
tpAllBtn.Position = UDim2.new(0, 0, 0, 168)
tpAllBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 120)
tpAllBtn.Text = "🚀  Teleport to ALL (chain)"
tpAllBtn.TextColor3 = Color3.fromRGB(255, 230, 245)
tpAllBtn.Font = Enum.Font.GothamBold
tpAllBtn.TextSize = 14
tpAllBtn.Parent = content
createCorner(tpAllBtn, 10)
createStroke(tpAllBtn, Color3.fromRGB(220, 80, 160), 1, 0.4)

local tpAllGrad = Instance.new("UIGradient")
tpAllGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 60, 140)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 40, 100)),
})
tpAllGrad.Rotation = 90
tpAllGrad.Parent = tpAllBtn

tpAllBtn.MouseEnter:Connect(function()
    tween(tpAllBtn, {BackgroundColor3 = Color3.fromRGB(210, 70, 140)}, 0.2)
end)
tpAllBtn.MouseLeave:Connect(function()
    tween(tpAllBtn, {BackgroundColor3 = Color3.fromRGB(180, 50, 120)}, 0.2)
end)

-- Separator 2
local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(1, -20, 0, 1)
sep2.Position = UDim2.new(0, 10, 0, 220)
sep2.BackgroundColor3 = Color3.fromRGB(90, 60, 160)
sep2.BackgroundTransparency = 0.6
sep2.BorderSizePixel = 0
sep2.Parent = content

-- ~~~ STATUS PANEL ~~~
local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, 0, 0, 80)
statusPanel.Position = UDim2.new(0, 0, 0, 230)
statusPanel.BackgroundColor3 = Color3.fromRGB(22, 16, 38)
statusPanel.BorderSizePixel = 0
statusPanel.Parent = content
createCorner(statusPanel, 10)
createStroke(statusPanel, Color3.fromRGB(70, 45, 130), 1, 0.6)

local statusTitle = Instance.new("TextLabel")
statusTitle.Size = UDim2.new(1, -20, 0, 18)
statusTitle.Position = UDim2.new(0, 12, 0, 6)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "📊 STATUS"
statusTitle.TextColor3 = Color3.fromRGB(130, 110, 180)
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextSize = 10
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = statusPanel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 22)
statusLabel.Position = UDim2.new(0, 12, 0, 26)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "⏳ Scanning workspace..."
statusLabel.TextColor3 = Color3.fromRGB(180, 165, 215)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Parent = statusPanel

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -24, 0, 20)
countLabel.Position = UDim2.new(0, 12, 0, 50)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Found: 0 items"
countLabel.TextColor3 = Color3.fromRGB(140, 255, 180)
countLabel.Font = Enum.Font.GothamBold
countLabel.TextSize = 13
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = statusPanel

-- Pulsing indicator
local pulse = Instance.new("Frame")
pulse.Size = UDim2.new(0, 8, 0, 8)
pulse.Position = UDim2.new(1, -20, 0, 11)
pulse.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
pulse.Parent = statusPanel
createCorner(pulse, 4)

spawn(function()
    while screenGui.Parent do
        tween(pulse, {BackgroundTransparency = 0.7}, 0.8)
        task.wait(0.85)
        tween(pulse, {BackgroundTransparency = 0}, 0.8)
        task.wait(0.85)
    end
end)

-- Bottom text
local bottomText = Instance.new("TextLabel")
bottomText.Size = UDim2.new(1, 0, 0, 14)
bottomText.Position = UDim2.new(0, 0, 0, 318)
bottomText.BackgroundTransparency = 1
bottomText.Text = "scripterblox hub • brainrot finder v3.0"
bottomText.TextColor3 = Color3.fromRGB(70, 55, 110)
bottomText.Font = Enum.Font.Gotham
bottomText.TextSize = 9
bottomText.Parent = content

-- =================== OPEN ANIMATION ======================
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
shadow.ImageTransparency = 1

task.wait(0.1)
tween(mainFrame, {Size = fullSize, Position = UDim2.new(0.5, -170, 0.35, -175)}, 0.5, Enum.EasingStyle.Back)
tween(shadow, {ImageTransparency = 0.6}, 0.5)

-- ================== BUTTON LOGIC ==========================

tpBtn.MouseButton1Click:Connect(function()
    statusLabel.Text = "⚡ Teleporting..."
    statusLabel.TextColor3 = Color3.fromRGB(200, 180, 255)
    local name = teleportToNearest()
    if name then
        statusLabel.Text = "✅ Teleported to: " .. name
        statusLabel.TextColor3 = Color3.fromRGB(140, 255, 180)
    else
        statusLabel.Text = "❌ No brainrots found!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
end)

tpAllBtn.MouseButton1Click:Connect(function()
    local items = getAllBrainrots()
    if #items == 0 then
        statusLabel.Text = "❌ No brainrots found!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end

    statusLabel.TextColor3 = Color3.fromRGB(255, 180, 220)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for i, item in ipairs(items) do
        local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
        if part and part.Parent then
            statusLabel.Text = string.format("🚀 %d/%d → %s", i, #items, item.Name)
            hrp.CFrame = part.CFrame * CFrame.new(0, 3, 0)
            tryCollect(item)
            task.wait(0.6)
        end
    end

    statusLabel.Text = "✅ Teleported to all " .. #items .. " items!"
    statusLabel.TextColor3 = Color3.fromRGB(140, 255, 180)
end)

-- ================== MAIN LOOP =============================

spawn(function()
    while screenGui.Parent do
        local items = getAllBrainrots()
        countLabel.Text = "Found: " .. #items .. " items"

        if espEnabled then
            for _, item in ipairs(items) do
                createESP(item)
            end
            updateESP()
        end

        if autoCollectEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                for _, item in ipairs(items) do
                    local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                    if part then
                        local dist = (part.Position - hrp.Position).Magnitude
                        if dist <= collectRange then
                            tryCollect(item)
                        end
                    end
                end
            end
        end

        task.wait(0.5)
    end
end)

-- ============= TOGGLE GUI WITH KEY =======================
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        guiOpen = not guiOpen
        mainFrame.Visible = guiOpen
        shadow.Visible = guiOpen
    end
end)

print("✅ Scripterblox Hub — Brainrot Finder v3.0 loaded!")
print("🔑 Press RIGHT SHIFT to toggle GUI")
