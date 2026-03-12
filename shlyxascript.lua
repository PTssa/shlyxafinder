-- ============================================================
-- SCRIPTERBLOX HUB | STEAL A BRAINROT 
-- ESP & SERVER FINDER (HOPPER) v4.0
-- ============================================================

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- ======================== STATE ===========================
local espEnabled = false
local espObjects = {}
local guiOpen = true
local isHopping = false
local autoHopMode = nil  -- nil, "random" or "low_pop"
local autoGrabEnabled = false
local cachedItems = {} -- Optimized item list
local screenGui = nil
local HOP_FLAG_FILE = "sbx_hop_mode.txt" -- файл-флаг в папке эксекьютора

-- Проверяем, был ли прыжок с предыдущего сервера (через файл)
local function checkAutoHopFlag()
    local ok, hasFile = pcall(isfile, HOP_FLAG_FILE)
    if ok and hasFile then
        local ok2, mode = pcall(readfile, HOP_FLAG_FILE)
        if ok2 and mode and (mode == "random" or mode == "low_pop") then
            autoHopMode = mode
        end
        pcall(delfile, HOP_FLAG_FILE) -- удаляем флаг сразу, чтобы не зациклился случайно
    end
end

checkAutoHopFlag()


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

-- ============== BRAINROT ITEM DETECTION ===================

local function getBrainrotFolders()
    local folders = {}
    -- Пробуем найти папки, в которых игра обычно хранит предметы
    for _, name in ipairs({"Brainrots", "BrainrotItems", "Items", "Collectibles", "Spawns", "Level"}) do
        local folder = Workspace:FindFirstChild(name)
        if folder then table.insert(folders, folder) end
    end
    
    -- Если игра хранит предметы прямо в воркспейсе
    if #folders == 0 then
        table.insert(folders, Workspace)
    end
    
    return folders
end

local function isBrainrotItem(obj)
    if not obj then return false end
    
    -- Простая проверка: если есть ProximityPrompt или ClickDetector, и это не дверь/магазин
    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    local click = obj:FindFirstChildWhichIsA("ClickDetector", true)
    
    if not (prompt or click) then return false end
    
    local name = obj.Name:lower()
    
    -- Исключаем дефолтные вещи
    if name == "door" or name:find("door") or name:find("shop") or name:find("buy") or name:find("gamepass") then
        return false
    end
    
    -- Если внутри подсказки "Collect", "Steal", "Pick up" и т.д.
    if prompt then
        local action = prompt.ActionText:lower()
        if action:find("collect") or action:find("steal") or action:find("grab") or action:find("take") or action:find("pick") then
            return true
        end
    end

    -- Список слов-маркеров для Brainrot'ов
    local keywords = {
        "brainrot", "skibidi", "toilet", "sigma", "rizz", "gyatt", "ohio", 
        "fanum", "tax", "mewing", "aura", "npc", "gigachad", "smurf", "cat",
        "grimace", "looksmax", "sus", "amogus", "imposter", "goofy", "ahh",
        "brain", "coin", "gem", "money", "cash"
    }
    
    for _, kw in ipairs(keywords) do
        if name:find(kw) then return true end
        if prompt and prompt.ObjectText:lower():find(kw) then return true end
    end

    -- Если ничего не нашли, но это не дефолтный объект и есть промпт - на всякий случай считаем предметом
    if name ~= "block" and name ~= "part" and name ~= "meshpart" then
        return true
    end

    return false
end

local function getAllBrainrots()
    return cachedItems
end

-- Система кеширования предметов (Заменяет тяжелые сканирования)
local function refreshItemCache()
    local newItems = {}
    local scanned = {}
    
    -- Сканируем ВЕСЬ воркспейс, чтобы точно ничего не пропустить
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if not scanned[desc] and isBrainrotItem(desc) then
            table.insert(newItems, desc)
            scanned[desc] = true
        end
    end
    cachedItems = newItems
end

-- Фоновое обновление кеша
spawn(function()
    while true do
        pcall(refreshItemCache)
        task.wait(5) -- Кеш обновляется раз в 5 секунд (баланс скорости и лагов)
    end
end)

-- Слежение за новыми предметами в реальном времени
Workspace.DescendantAdded:Connect(function(desc)
    task.wait(0.1)
    if isBrainrotItem(desc) then
        local found = false
        for _, item in ipairs(cachedItems) do
            if item == desc then found = true break end
        end
        if not found then table.insert(cachedItems, desc) end
    end
end)

-- ===================== AUTO GRAB ==========================

local function tryGrabItem(item)
    if not item or not item.Parent then return false end
    
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Ищем ProximityPrompt или ClickDetector
    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    local clickDetector = item:FindFirstChildWhichIsA("ClickDetector", true)
    
    if prompt then
        -- Проверяем расстояние
        local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist <= prompt.MaxActivationDistance then
                pcall(function()
                    fireproximityprompt(prompt)
                end)
                return true
            end
        end
    elseif clickDetector then
        -- Для ClickDetector просто кликаем
        pcall(function()
            fireclickdetector(clickDetector)
        end)
        return true
    end
    
    return false
end

local function autoGrabLoop()
    while true do
        task.wait(0.05) -- Ещё быстрее для подбора на бегу
        if autoGrabEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                for _, item in ipairs(cachedItems) do
                    if item and item.Parent then
                        tryGrabItem(item)
                    end
                end
            end
        end
    end
end

spawn(autoGrabLoop)

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

    local highlight = Instance.new("Highlight")
    highlight.Adornee = item
    highlight.FillColor = Color3.fromRGB(180, 80, 255)
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = Color3.fromRGB(255, 150, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Parent = item

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

-- ================= SERVER HOPPER ==========================

local function ServerHop(targetAction)
    if isHopping then return end
    isHopping = true
    
    local guiFrame = screenGui:FindFirstChild("MainFrame")
    local statusLbl = guiFrame and guiFrame:FindFirstChild("Content"):FindFirstChild("StatusPanel"):FindFirstChild("StatusText")
    
    if statusLbl then
        statusLbl.Text = "⏳ Searching for servers..."
        statusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
    end

    local apiUrl = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local success, result = pcall(function()
        return game:HttpGet(apiUrl)
    end)
    
    if not success then
        if statusLbl then statusLbl.Text = "❌ API Error. Retrying..." end
        task.wait(2)
        isHopping = false
        return
    end
    
    local data = HttpService:JSONDecode(result)
    if data and data.data then
        local servers = {}
        for _, v in pairs(data.data) do
            if type(v) == "table" and v.playing < v.maxPlayers and v.id ~= JobId then
                table.insert(servers, v)
            end
        end
        
        if #servers > 0 then
            local targetServer
            if targetAction == "low_pop" then
                -- Sort by lowest players
                table.sort(servers, function(a, b) return a.playing < b.playing end)
                targetServer = servers[1]
                if statusLbl then statusLbl.Text = "🚀 Joining Low Pop Server ("..targetServer.playing.."/"..targetServer.maxPlayers..")" end
            else
                -- Random server
                targetServer = servers[math.random(1, #servers)]
                if statusLbl then statusLbl.Text = "🚀 Joining Random Server ("..targetServer.playing.."/"..targetServer.maxPlayers..")" end
            end
            
            task.wait(0.5)
            -- Записываем флаг режима в файл (сохранится между серверами)
            pcall(function()
                writefile(HOP_FLAG_FILE, targetAction)
            end)
            TeleportService:TeleportToPlaceInstance(PlaceId, targetServer.id, LocalPlayer)
        else
            if statusLbl then statusLbl.Text = "❌ No suitable servers found!" end
            isHopping = false
        end
    end
end


-- ====================== GUI BUILD =========================

local function createGUI()
    if game:GetService("CoreGui"):FindFirstChild("ScripterbloxSAB") then
        game:GetService("CoreGui"):FindFirstChild("ScripterbloxSAB"):Destroy()
    end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ScripterbloxSAB"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 360, 0, 420) -- Увеличили размер, чтобы всё влезло
    mainFrame.Position = UDim2.new(0.5, -180, 0.5, -202)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    createCorner(mainFrame, 14)
    createStroke(mainFrame, Color3.fromRGB(130, 70, 255), 1.5, 0.3)

    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Position = UDim2.new(0, -20, 0, -15)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = mainFrame

    -- DRAGGING
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
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
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- TITLE BAR
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 45)
    titleBar.BackgroundColor3 = Color3.fromRGB(22, 16, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    createCorner(titleBar, 14)
    local fix = Instance.new("Frame")
    fix.Size = UDim2.new(1, 0, 0, 10)
    fix.Position = UDim2.new(0, 0, 1, -10)
    fix.BackgroundColor3 = Color3.fromRGB(22, 16, 38)
    fix.BorderSizePixel = 0
    fix.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -60, 1, 0)
    titleLbl.Position = UDim2.new(0, 15, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "🧠 SCRIPTERBLOX | FINDER (FINAL)"
    titleLbl.TextColor3 = Color3.fromRGB(230, 210, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    createCorner(closeBtn, 8)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() clearESP() espEnabled = false end)

    -- CONTENT
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -30, 1, -60)
    content.Position = UDim2.new(0, 15, 0, 55)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- ESP TOGGLE
    local espFrame = Instance.new("Frame")
    espFrame.Size = UDim2.new(1, 0, 0, 45)
    espFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
    espFrame.Parent = content
    createCorner(espFrame, 8)
    createStroke(espFrame, Color3.fromRGB(80, 50, 150), 1, 0.6)
    
    local espLbl = Instance.new("TextLabel")
    espLbl.Size = UDim2.new(1, -70, 1, 0)
    espLbl.Position = UDim2.new(0, 15, 0, 0)
    espLbl.BackgroundTransparency = 1
    espLbl.Text = "👁 Show All Brainrots"
    espLbl.TextColor3 = Color3.fromRGB(220, 200, 255)
    espLbl.Font = Enum.Font.GothamBold
    espLbl.TextSize = 14
    espLbl.TextXAlignment = Enum.TextXAlignment.Left
    espLbl.Parent = espFrame

    local espBtn = Instance.new("TextButton")
    espBtn.Size = UDim2.new(0, 50, 0, 26)
    espBtn.Position = UDim2.new(1, -60, 0.5, -13)
    espBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
    espBtn.Text = ""
    espBtn.Parent = espFrame
    createCorner(espBtn, 13)
    local espCirc = Instance.new("Frame")
    espCirc.Size = UDim2.new(0, 20, 0, 20)
    espCirc.Position = UDim2.new(0, 3, 0.5, -10)
    espCirc.BackgroundColor3 = Color3.fromRGB(150, 130, 180)
    espCirc.Parent = espBtn
    createCorner(espCirc, 10)

    espBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
            tween(espCirc, {Position = UDim2.new(1, -23, 0.5, -10), BackgroundColor3 = Color3.fromRGB(120, 255, 150)}, 0.25)
            tween(espBtn, {BackgroundColor3 = Color3.fromRGB(60, 160, 90)}, 0.25)
        else
            tween(espCirc, {Position = UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = Color3.fromRGB(150, 130, 180)}, 0.25)
            tween(espBtn, {BackgroundColor3 = Color3.fromRGB(50, 40, 70)}, 0.25)
            clearESP()
        end
    end)

    -- AUTO GRAB TOGGLE
    local grabFrame = Instance.new("Frame")
    grabFrame.Size = UDim2.new(1, 0, 0, 45)
    grabFrame.Position = UDim2.new(0, 0, 0, 55)
    grabFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
    grabFrame.Parent = content
    createCorner(grabFrame, 8)
    createStroke(grabFrame, Color3.fromRGB(80, 50, 150), 1, 0.6)
    
    local grabLbl = Instance.new("TextLabel")
    grabLbl.Size = UDim2.new(1, -70, 1, 0)
    grabLbl.Position = UDim2.new(0, 15, 0, 0)
    grabLbl.BackgroundTransparency = 1
    grabLbl.Text = "🤖 Auto Grab (Improved)"
    grabLbl.TextColor3 = Color3.fromRGB(220, 200, 255)
    grabLbl.Font = Enum.Font.GothamBold
    grabLbl.TextSize = 14
    grabLbl.TextXAlignment = Enum.TextXAlignment.Left
    grabLbl.Parent = grabFrame

    local grabBtn = Instance.new("TextButton")
    grabBtn.Size = UDim2.new(0, 50, 0, 26)
    grabBtn.Position = UDim2.new(1, -60, 0.5, -13)
    grabBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
    grabBtn.Text = ""
    grabBtn.Parent = grabFrame
    createCorner(grabBtn, 13)
    local grabCirc = Instance.new("Frame")
    grabCirc.Size = UDim2.new(0, 20, 0, 20)
    grabCirc.Position = UDim2.new(0, 3, 0.5, -10)
    grabCirc.BackgroundColor3 = Color3.fromRGB(150, 130, 180)
    grabCirc.Parent = grabBtn
    createCorner(grabCirc, 10)

    grabBtn.MouseButton1Click:Connect(function()
        autoGrabEnabled = not autoGrabEnabled
        if autoGrabEnabled then
            tween(grabCirc, {Position = UDim2.new(1, -23, 0.5, -10), BackgroundColor3 = Color3.fromRGB(255, 200, 100)}, 0.25)
            tween(grabBtn, {BackgroundColor3 = Color3.fromRGB(200, 140, 60)}, 0.25)
        else
            tween(grabCirc, {Position = UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = Color3.fromRGB(150, 130, 180)}, 0.25)
            tween(grabBtn, {BackgroundColor3 = Color3.fromRGB(50, 40, 70)}, 0.25)
        end
    end)

    -- HOPPER BUTTONS
    local function createHopBtn(yPos, text, icon, color, action)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 45)
        btn.Position = UDim2.new(0, 0, 0, yPos)
        btn.BackgroundColor3 = color
        btn.Text = "  " .. icon .. "  " .. text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = content
        createCorner(btn, 8)
        
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color),
            ColorSequenceKeypoint.new(1, Color3.new(color.R*0.7, color.G*0.7, color.B*0.7))
        })
        grad.Rotation = 90
        grad.Parent = btn

        btn.MouseButton1Click:Connect(function() ServerHop(action) end)
        return btn
    end

    createHopBtn(130, "Hop to Random Server", "🎲", Color3.fromRGB(140, 70, 255), "random")
    createHopBtn(190, "Hop to Low Pop. Server", "📉", Color3.fromRGB(80, 160, 255), "low_pop")

    -- STATUS PANEL
    local statusPanel = Instance.new("Frame")
    statusPanel.Name = "StatusPanel"
    statusPanel.Size = UDim2.new(1, 0, 0, 80)
    statusPanel.Position = UDim2.new(0, 0, 0, 250)
    statusPanel.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
    statusPanel.Parent = content
    createCorner(statusPanel, 8)
    createStroke(statusPanel, Color3.fromRGB(100, 60, 180), 1, 0.5)
    statusPanel.ZIndex = 2 -- Выше кнопок, на всякий случай

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "StatusText"
    statusLbl.Size = UDim2.new(1, -20, 1, 0)
    statusLbl.Position = UDim2.new(0, 10, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "📡 Ready. Server contains 0 items."
    statusLbl.TextColor3 = Color3.fromRGB(180, 200, 255)
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 14
    statusLbl.TextWrapped = true
    statusLbl.Parent = statusPanel
end

createGUI()

-- ================== MAIN LOOP =============================

spawn(function()
    while screenGui and screenGui.Parent do
        local items = getAllBrainrots()
        
        local statusText = screenGui:FindFirstChild("MainFrame")
        if statusText and not isHopping then
            local lbl = statusText:FindFirstChild("Content"):FindFirstChild("StatusPanel"):FindFirstChild("StatusText")
            if lbl then
                lbl.Text = "📡 Server active.\n\nFound " .. #items .. " brainrot items here."
                lbl.TextColor3 = Color3.fromRGB(160, 255, 180)
            end
        end

        if espEnabled then
            for _, item in ipairs(items) do
                createESP(item)
            end
            updateESP()
        end

        task.wait(1)
    end
end)

-- ============= TOGGLE GUI WITH KEY =======================
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        guiOpen = not guiOpen
        if screenGui and screenGui:FindFirstChild("MainFrame") then
            screenGui.MainFrame.Visible = guiOpen
        end
    end
end)

print("✅ Scripterblox Finder Loaded!")

-- ============= АВТО-ХОППИНГ ПОСЛЕ ТЕЛЕПОРТА ==================
if autoHopMode then
    spawn(function()
        task.wait(4) -- ждём пока игра загрузится и GUI поднимется
        print("[AUTO HOP] Resuming " .. autoHopMode .. " mode...")
        ServerHop(autoHopMode)
    end)
end
