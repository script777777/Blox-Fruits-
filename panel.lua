--[[
    DXLTA Blox Fruits — Starter Panel
    Built from a live Explorer dump (workspace.Enemies / Characters / NPCs,
    ReplicatedStorage.Modules.Net, character Busy/Stun/Energy/HasBuso flags).

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/bf-panel-ff0d/panel.lua"))()

    Toggle: RightShift  ·  Reopen: lime orb bottom-right
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local COLORS = {
    bg = Color3.fromRGB(10, 12, 16),
    panel = Color3.fromRGB(16, 20, 26),
    panelAlt = Color3.fromRGB(22, 28, 36),
    border = Color3.fromRGB(38, 46, 56),
    text = Color3.fromRGB(220, 228, 235),
    muted = Color3.fromRGB(130, 142, 158),
    lime = Color3.fromRGB(180, 255, 40),
    limeDim = Color3.fromRGB(90, 140, 20),
    limeSoft = Color3.fromRGB(140, 200, 50),
    danger = Color3.fromRGB(255, 90, 90),
    enemy = Color3.fromRGB(255, 120, 80),
    npc = Color3.fromRGB(120, 200, 255),
    player = Color3.fromRGB(200, 140, 255),
}

local STATE = {
    enemyEsp = false,
    npcEsp = false,
    playerEsp = false,
    tweenNearest = false,
    panelVisible = true,
}

local ESP_FOLDER_NAME = "DXLTA_ESP"
local GUI_NAME = "DXLTA_BF_Panel"
local ORB_NAME = "DXLTA_BF_Orb"

local connections = {}
local enemyEspMap = {}
local npcEspMap = {}
local playerEspMap = {}
local tweenBusy = false

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function safeCall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return true, a, b, c
    end
    return false, a
end

local function safeLookAt(fromPos, toPos)
    local ok, cf = pcall(function()
        if (toPos - fromPos).Magnitude < 0.05 then
            return CFrame.new(fromPos)
        end
        return CFrame.lookAt(fromPos, toPos)
    end)
    if ok and typeof(cf) == "CFrame" then
        return cf
    end
    return CFrame.new(fromPos)
end

local function getGuiParent()
    local ok, parent = pcall(function()
        if typeof(gethui) == "function" then
            return gethui()
        end
        return CoreGui
    end)
    if ok and parent then
        return parent
    end
    if LocalPlayer then
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            return pg
        end
    end
    return CoreGui
end

local function destroyByName(parent, name)
    pcall(function()
        local existing = parent:FindFirstChild(name)
        if existing then
            existing:Destroy()
        end
    end)
end

local function getHRP(model)
    if not model then
        return nil
    end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp
    end
    local ok, part = pcall(function()
        return model.PrimaryPart
    end)
    if ok and part and part:IsA("BasePart") then
        return part
    end
    return nil
end

local function getHumanoid(model)
    if not model then
        return nil
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum
end

local function isAliveModel(model)
    local hum = getHumanoid(model)
    if not hum then
        return false
    end
    return hum.Health > 0
end

local function localRoot()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then
        return nil
    end
    return getHRP(char)
end

local function distanceTo(part)
    local root = localRoot()
    if not root or not part then
        return nil
    end
    local ok, dist = pcall(function()
        return (root.Position - part.Position).Magnitude
    end)
    if ok then
        return dist
    end
    return nil
end

local function ensureEspFolder(adornee)
    if not adornee then
        return nil
    end
    local existing = adornee:FindFirstChild(ESP_FOLDER_NAME)
    if existing then
        return existing
    end
    local folder = Instance.new("Folder")
    folder.Name = ESP_FOLDER_NAME
    folder.Parent = adornee
    return folder
end

local function clearEspOn(model)
    pcall(function()
        local folder = model and model:FindFirstChild(ESP_FOLDER_NAME)
        if folder then
            folder:Destroy()
        end
    end)
end

local function makeBillboard(adornee, text, color, yOffset)
    clearEspOn(adornee)
    local folder = ensureEspFolder(adornee)
    if not folder then
        return nil
    end

    local bb = Instance.new("BillboardGui")
    bb.Name = "Tag"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(160, 36)
    bb.StudsOffset = Vector3.new(0, yOffset or 3.2, 0)
    bb.MaxDistance = 2000
    bb.Adornee = adornee:IsA("BasePart") and adornee or getHRP(adornee)
    bb.Parent = folder

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 0.35
    label.BackgroundColor3 = COLORS.bg
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = color or COLORS.lime
    label.TextStrokeTransparency = 0.4
    label.Text = text or "?"
    label.Parent = bb

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label

    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COLORS.limeDim
    stroke.Thickness = 1
    stroke.Parent = label

    return bb, label
end

local function updateBillboardText(model, text)
    local folder = model and model:FindFirstChild(ESP_FOLDER_NAME)
    if not folder then
        return
    end
    local bb = folder:FindFirstChild("Tag")
    if not bb then
        return
    end
    local label = bb:FindFirstChild("Label")
    if label then
        label.Text = text
    end
end

-- ── Enemies / NPCs / Players helpers ────────────────────────────────────────

local function getEnemiesFolder()
    return Workspace:FindFirstChild("Enemies")
end

local function getNpcsFolder()
    return Workspace:FindFirstChild("NPCs")
end

local function getCharactersFolder()
    return Workspace:FindFirstChild("Characters")
end

local function getNetFolder()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if not modules then
        return nil
    end
    return modules:FindFirstChild("Net")
end

local function iterEnemyModels()
    local list = {}
    local folder = getEnemiesFolder()
    if not folder then
        return list
    end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") and getHRP(child) and isAliveModel(child) then
            table.insert(list, child)
        end
    end
    return list
end

local function iterNpcModels()
    local list = {}
    local folder = getNpcsFolder()
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                table.insert(list, child)
            end
        end
    end
    -- Optional templates / spawned names from RS.NPCs (match by Name in workspace)
    local templates = ReplicatedStorage:FindFirstChild("NPCs")
    if templates then
        local seen = {}
        for _, m in ipairs(list) do
            seen[m] = true
        end
        for _, tmpl in ipairs(templates:GetChildren()) do
            local name = tmpl.Name
            -- Find live instances elsewhere in workspace that match template names
            for _, desc in ipairs(Workspace:GetChildren()) do
                if desc.Name == name and desc ~= folder and (desc:IsA("Model") or desc:IsA("BasePart")) and not seen[desc] then
                    -- Prefer only under Map / Arenas / NPCs-like areas; skip Characters/Enemies
                    local parentName = desc.Parent and desc.Parent.Name or ""
                    if parentName ~= "Enemies" and parentName ~= "Characters" then
                        -- already covered if under NPCs folder
                        if desc.Parent ~= folder then
                            -- skip broad workspace root spam; only take from Map/Arenas/NPCs
                            if parentName == "Map" or parentName == "Arenas" or parentName == "NPCs" then
                                table.insert(list, desc)
                                seen[desc] = true
                            end
                        end
                    end
                end
            end
        end
    end
    return list
end

local function iterOtherPlayerChars()
    local list = {}
    local chars = getCharactersFolder()
    if chars then
        for _, child in ipairs(chars:GetChildren()) do
            if child:IsA("Model") and child.Name ~= (LocalPlayer and LocalPlayer.Name) then
                if getHRP(child) then
                    table.insert(list, child)
                end
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local already = false
            for _, m in ipairs(list) do
                if m == plr.Character or m.Name == plr.Name then
                    already = true
                    break
                end
            end
            if not already and getHRP(plr.Character) then
                table.insert(list, plr.Character)
            end
        end
    end
    return list
end

local function nearestEnemy()
    local root = localRoot()
    if not root then
        return nil, nil
    end
    local best, bestDist = nil, math.huge
    for _, enemy in ipairs(iterEnemyModels()) do
        local hrp = getHRP(enemy)
        if hrp then
            local ok, dist = pcall(function()
                return (root.Position - hrp.Position).Magnitude
            end)
            if ok and dist < bestDist then
                bestDist = dist
                best = enemy
            end
        end
    end
    return best, bestDist
end

-- ── ESP refresh ─────────────────────────────────────────────────────────────

local function refreshEnemyEsp()
    if not STATE.enemyEsp then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
        return
    end

    local alive = {}
    for _, enemy in ipairs(iterEnemyModels()) do
        alive[enemy] = true
        local hrp = getHRP(enemy)
        local dist = distanceTo(hrp)
        local distStr = dist and string.format("%.0fm", dist) or "?"
        local text = string.format("%s  ·  %s", enemy.Name, distStr)
        if not enemyEspMap[enemy] then
            makeBillboard(enemy, text, COLORS.enemy, 3.4)
            enemyEspMap[enemy] = true
        else
            updateBillboardText(enemy, text)
        end
    end
    for model in pairs(enemyEspMap) do
        if not alive[model] or not model.Parent then
            clearEspOn(model)
            enemyEspMap[model] = nil
        end
    end
end

local function refreshNpcEsp()
    if not STATE.npcEsp then
        for model in pairs(npcEspMap) do
            clearEspOn(model)
        end
        npcEspMap = {}
        return
    end

    local alive = {}
    for _, npc in ipairs(iterNpcModels()) do
        alive[npc] = true
        local part = npc:IsA("BasePart") and npc or getHRP(npc)
        local dist = distanceTo(part)
        local distStr = dist and string.format("%.0fm", dist) or "?"
        local text = string.format("%s  ·  %s", npc.Name, distStr)
        if not npcEspMap[npc] then
            makeBillboard(npc, text, COLORS.npc, 3.0)
            npcEspMap[npc] = true
        else
            updateBillboardText(npc, text)
        end
    end
    for model in pairs(npcEspMap) do
        if not alive[model] or not model.Parent then
            clearEspOn(model)
            npcEspMap[model] = nil
        end
    end
end

local function refreshPlayerEsp()
    if not STATE.playerEsp then
        for model in pairs(playerEspMap) do
            clearEspOn(model)
        end
        playerEspMap = {}
        return
    end

    local alive = {}
    for _, char in ipairs(iterOtherPlayerChars()) do
        alive[char] = true
        local hrp = getHRP(char)
        local dist = distanceTo(hrp)
        local distStr = dist and string.format("%.0fm", dist) or "?"
        local text = string.format("%s  ·  %s", char.Name, distStr)
        if not playerEspMap[char] then
            makeBillboard(char, text, COLORS.player, 3.6)
            playerEspMap[char] = true
        else
            updateBillboardText(char, text)
        end
    end
    for model in pairs(playerEspMap) do
        if not alive[model] or not model.Parent then
            clearEspOn(model)
            playerEspMap[model] = nil
        end
    end
end

local function clearAllEsp()
    for model in pairs(enemyEspMap) do
        clearEspOn(model)
    end
    for model in pairs(npcEspMap) do
        clearEspOn(model)
    end
    for model in pairs(playerEspMap) do
        clearEspOn(model)
    end
    enemyEspMap, npcEspMap, playerEspMap = {}, {}, {}
end

-- ── Status HUD data ─────────────────────────────────────────────────────────

local function readCharStatus()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then
        return {
            busy = "—",
            stun = "—",
            energy = "—",
            buso = "—",
        }
    end

    local busyVal = char:FindFirstChild("Busy")
    local stunVal = char:FindFirstChild("Stun")
    local energyVal = char:FindFirstChild("Energy")
    local hasBuso = char:FindFirstChild("HasBuso")

    local busy = "—"
    if busyVal and busyVal:IsA("BoolValue") then
        busy = busyVal.Value and "JA" or "NEIN"
    elseif busyVal then
        busy = tostring(busyVal)
    end

    local stun = "—"
    if stunVal and (stunVal:IsA("NumberValue") or stunVal:IsA("IntValue")) then
        stun = string.format("%.2f", stunVal.Value)
    elseif stunVal then
        stun = tostring(stunVal)
    end

    local energy = "—"
    if energyVal then
        if energyVal:IsA("NumberValue") or energyVal:IsA("IntValue") then
            energy = string.format("%.0f", energyVal.Value)
        elseif energyVal:IsA("ValueBase") then
            energy = tostring(energyVal.Value)
        else
            -- Energy can be a folder/number object depending on build
            local n = energyVal:FindFirstChildWhichIsA("NumberValue") or energyVal:FindFirstChildWhichIsA("IntValue")
            if n then
                energy = string.format("%.0f", n.Value)
            else
                energy = "vorhanden"
            end
        end
    end

    local buso = "—"
    if hasBuso then
        if hasBuso:IsA("BoolValue") then
            buso = hasBuso.Value and "JA" or "NEIN"
        elseif hasBuso:IsA("Folder") or hasBuso:IsA("Configuration") then
            buso = "JA (Folder)"
        else
            buso = "JA"
        end
    else
        buso = "NEIN"
    end

    return {
        busy = busy,
        stun = stun,
        energy = energy,
        buso = buso,
    }
end

-- ── Net remotes inventory ───────────────────────────────────────────────────

local function scanNetRemotes()
    local lines = {}
    local net = getNetFolder()
    if not net then
        table.insert(lines, "(Modules.Net nicht gefunden)")
        return lines, 0
    end

    local kids = {}
    local ok, children = pcall(function()
        return net:GetChildren()
    end)
    if not ok or not children then
        table.insert(lines, "(Fehler beim Lesen von Modules.Net)")
        return lines, 0
    end

    for _, child in ipairs(children) do
        table.insert(kids, child)
    end
    table.sort(kids, function(a, b)
        return a.Name < b.Name
    end)

    table.insert(lines, string.format("Modules.Net — %d Einträge", #kids))
    table.insert(lines, "--------------------------------")
    for _, child in ipairs(kids) do
        table.insert(lines, string.format("%s  [%s]", child.Name, child.ClassName))
    end

    -- Also note known sibling remotes from dump (read-only inventory)
    local dragonAim = ReplicatedStorage:FindFirstChild("DragonAim")
    if dragonAim then
        local re = dragonAim:FindFirstChild("RemoteEvent")
        if re then
            table.insert(lines, "")
            table.insert(lines, "DragonAim.RemoteEvent [gefunden]")
        end
    end

    return lines, #kids
end

-- ── Tween to nearest enemy ──────────────────────────────────────────────────

local function tweenToNearestEnemy()
    if tweenBusy then
        return false, "bereits unterwegs"
    end
    local enemy, dist = nearestEnemy()
    if not enemy then
        return false, "kein Gegner"
    end
    local target = getHRP(enemy)
    local root = localRoot()
    if not target or not root then
        return false, "kein HRP"
    end

    tweenBusy = true
    local ok, err = pcall(function()
        local from = root.Position
        local to = target.Position
        -- Stop a short distance away so we don't clip into the model
        local offset = Vector3.new(0, 0, 0)
        local delta = to - from
        if delta.Magnitude > 6 then
            offset = delta.Unit * (delta.Magnitude - 5)
            to = from + offset
        end

        local goalCF = safeLookAt(to, target.Position)
        local info = TweenInfo.new(
            math.clamp((dist or 20) / 40, 0.35, 2.2),
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        -- Step/tween CFrame safely
        local tween = TweenService:Create(root, info, { CFrame = goalCF })
        tween:Play()
        tween.Completed:Wait()
    end)
    tweenBusy = false
    if not ok then
        return false, tostring(err)
    end
    return true, enemy.Name
end

local function stepTowardNearest()
    -- Soft continuous approach while toggle is on (safe stepped CFrame)
    if not STATE.tweenNearest or tweenBusy then
        return
    end
    local enemy = nearestEnemy()
    if not enemy then
        return
    end
    local target = getHRP(enemy)
    local root = localRoot()
    if not target or not root then
        return
    end
    pcall(function()
        local from = root.Position
        local to = target.Position
        local delta = to - from
        local mag = delta.Magnitude
        if mag < 7 then
            return
        end
        local step = math.min(2.8, mag - 6)
        local nextPos = from + delta.Unit * step
        root.CFrame = safeLookAt(nextPos, to)
    end)
end

-- ── UI ──────────────────────────────────────────────────────────────────────

local guiParent = getGuiParent()
destroyByName(guiParent, GUI_NAME)
destroyByName(guiParent, ORB_NAME)

local screen = Instance.new("ScreenGui")
screen.Name = GUI_NAME
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 1000
screen.Parent = guiParent

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(360, 520)
panel.Position = UDim2.new(0, 24, 0.5, -260)
panel.BackgroundColor3 = COLORS.panel
panel.BorderSizePixel = 0
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.limeDim
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

-- Hero header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = COLORS.bg
header.BorderSizePixel = 0
header.Parent = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 14)
headerFix.Position = UDim2.new(0, 0, 1, -14)
headerFix.BackgroundColor3 = COLORS.bg
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local brand = Instance.new("TextLabel")
brand.BackgroundTransparency = 1
brand.Position = UDim2.fromOffset(16, 8)
brand.Size = UDim2.new(1, -60, 0, 32)
brand.Font = Enum.Font.GothamBlack
brand.TextSize = 26
brand.TextXAlignment = Enum.TextXAlignment.Left
brand.TextColor3 = COLORS.lime
brand.Text = "DXLTA"
brand.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 40)
subtitle.Size = UDim2.new(1, -60, 0, 20)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = COLORS.muted
subtitle.Text = "Blox Fruits · Starter Panel"
subtitle.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(30, 28)
closeBtn.Position = UDim2.new(1, -40, 0, 12)
closeBtn.BackgroundColor3 = COLORS.panelAlt
closeBtn.TextColor3 = COLORS.danger
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Text = "X"
closeBtn.AutoButtonColor = true
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeBtn

-- Content scroll
local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Size = UDim2.new(1, -20, 1, -92)
body.Position = UDim2.fromOffset(10, 82)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollBarImageColor3 = COLORS.limeDim
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

local function sectionLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = COLORS.limeSoft
    lbl.Text = text
    lbl.LayoutOrder = order
    lbl.Parent = body
    return lbl
end

local function makeToggle(name, label, order, initial, onChange)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = COLORS.panelAlt
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(12, 0)
    text.Size = UDim2.new(1, -70, 1, 0)
    text.Font = Enum.Font.Gotham
    text.TextSize = 14
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextColor3 = COLORS.text
    text.Text = label
    text.Parent = row

    local btn = Instance.new("TextButton")
    btn.Name = "Toggle"
    btn.Size = UDim2.fromOffset(52, 24)
    btn.Position = UDim2.new(1, -60, 0.5, -12)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = true
    btn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local enabled = initial and true or false

    local function paint()
        if enabled then
            btn.BackgroundColor3 = COLORS.lime
            btn.TextColor3 = COLORS.bg
            btn.Text = "AN"
        else
            btn.BackgroundColor3 = COLORS.border
            btn.TextColor3 = COLORS.muted
            btn.Text = "AUS"
        end
    end
    paint()

    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        paint()
        safeCall(onChange, enabled)
    end)

    return {
        set = function(v)
            enabled = v and true or false
            paint()
            safeCall(onChange, enabled)
        end,
        get = function()
            return enabled
        end,
    }
end

local function makeButton(name, label, order, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = color or COLORS.lime
    btn.TextColor3 = COLORS.bg
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Text = label
    btn.AutoButtonColor = true
    btn.LayoutOrder = order
    btn.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        safeCall(onClick)
    end)
    return btn
end

local function makeStatusBox(order)
    local box = Instance.new("Frame")
    box.Name = "StatusHUD"
    box.Size = UDim2.new(1, 0, 0, 88)
    box.BackgroundColor3 = COLORS.bg
    box.BorderSizePixel = 0
    box.LayoutOrder = order
    box.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.border
    stroke.Thickness = 1
    stroke.Parent = box

    local label = Instance.new("TextLabel")
    label.Name = "StatusText"
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, 6)
    label.Size = UDim2.new(1, -20, 1, -12)
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextColor3 = COLORS.text
    label.Text = "Busy: —\nStun: —\nEnergy: —\nHasBuso: —"
    label.Parent = box

    return label
end

local function makeRemotesBox(order)
    local wrap = Instance.new("Frame")
    wrap.Name = "RemotesWrap"
    wrap.Size = UDim2.new(1, 0, 0, 150)
    wrap.BackgroundColor3 = COLORS.bg
    wrap.BorderSizePixel = 0
    wrap.LayoutOrder = order
    wrap.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = wrap

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.border
    stroke.Thickness = 1
    stroke.Parent = wrap

    local countLbl = Instance.new("TextLabel")
    countLbl.Name = "Count"
    countLbl.BackgroundTransparency = 1
    countLbl.Position = UDim2.fromOffset(10, 4)
    countLbl.Size = UDim2.new(1, -20, 0, 18)
    countLbl.Font = Enum.Font.GothamBold
    countLbl.TextSize = 12
    countLbl.TextXAlignment = Enum.TextXAlignment.Left
    countLbl.TextColor3 = COLORS.limeSoft
    countLbl.Text = "Net Remotes: …"
    countLbl.Parent = wrap

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "RemoteScroll"
    scroll.Size = UDim2.new(1, -12, 1, -28)
    scroll.Position = UDim2.fromOffset(6, 24)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = COLORS.limeDim
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = wrap

    local text = Instance.new("TextLabel")
    text.Name = "RemoteText"
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, -8, 0, 0)
    text.Position = UDim2.fromOffset(4, 0)
    text.AutomaticSize = Enum.AutomaticSize.Y
    text.Font = Enum.Font.Code
    text.TextSize = 11
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.TextColor3 = COLORS.muted
    text.TextWrapped = true
    text.Text = "lade…"
    text.Parent = scroll

    return countLbl, text
end

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, 0, 0, 32)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextColor3 = COLORS.muted
hint.TextWrapped = true
hint.Text = "RightShift = Panel · Lime-Orb = wieder öffnen"
hint.LayoutOrder = 1
hint.Parent = body

sectionLabel("ESP", 2)

makeToggle("EnemyEsp", "Gegner ESP  (Enemies)", 3, false, function(on)
    STATE.enemyEsp = on
    if not on then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
    else
        refreshEnemyEsp()
    end
end)

makeToggle("NpcEsp", "NPC ESP  (NPCs)", 4, false, function(on)
    STATE.npcEsp = on
    if not on then
        for model in pairs(npcEspMap) do
            clearEspOn(model)
        end
        npcEspMap = {}
    else
        refreshNpcEsp()
    end
end)

makeToggle("PlayerEsp", "Spieler ESP  (Characters)", 5, false, function(on)
    STATE.playerEsp = on
    if not on then
        for model in pairs(playerEspMap) do
            clearEspOn(model)
        end
        playerEspMap = {}
    else
        refreshPlayerEsp()
    end
end)

sectionLabel("STATUS HUD", 6)
local statusLabel = makeStatusBox(7)

sectionLabel("BEWEGUNG", 8)
makeToggle("TweenToggle", "Auto zum nächsten Gegner", 9, false, function(on)
    STATE.tweenNearest = on
end)

local tweenStatus = Instance.new("TextLabel")
tweenStatus.BackgroundTransparency = 1
tweenStatus.Size = UDim2.new(1, 0, 0, 16)
tweenStatus.Font = Enum.Font.Gotham
tweenStatus.TextSize = 11
tweenStatus.TextXAlignment = Enum.TextXAlignment.Left
tweenStatus.TextColor3 = COLORS.muted
tweenStatus.Text = "Tween: bereit"
tweenStatus.LayoutOrder = 10
tweenStatus.Parent = body

makeButton("TweenOnce", "JETZT zum nächsten Gegner", 11, COLORS.lime, function()
    tweenStatus.Text = "Tween: läuft…"
    tweenStatus.TextColor3 = COLORS.limeSoft
    task.spawn(function()
        local ok, msg = tweenToNearestEnemy()
        if ok then
            tweenStatus.Text = "Tween: → " .. tostring(msg)
            tweenStatus.TextColor3 = COLORS.lime
        else
            tweenStatus.Text = "Tween: " .. tostring(msg)
            tweenStatus.TextColor3 = COLORS.danger
        end
    end)
end)

sectionLabel("MODULES.NET  (nur lesen)", 12)
local remoteCount, remoteText = makeRemotesBox(13)

makeButton("RefreshNet", "Net Remotes aktualisieren", 14, COLORS.limeSoft, function()
    local lines, count = scanNetRemotes()
    remoteCount.Text = string.format("Net Remotes: %d", count)
    remoteText.Text = table.concat(lines, "\n")
end)

local footer = Instance.new("TextLabel")
footer.BackgroundTransparency = 1
footer.Size = UDim2.new(1, 0, 0, 40)
footer.Font = Enum.Font.Gotham
footer.TextSize = 10
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.TextColor3 = COLORS.muted
footer.TextWrapped = true
footer.Text = "Pfade: workspace.Enemies / Characters / NPCs · RS.Modules.Net · Flags Busy/Stun/Energy/HasBuso"
footer.LayoutOrder = 15
footer.Parent = body

-- Reopen orb
local orb = Instance.new("ScreenGui")
orb.Name = ORB_NAME
orb.ResetOnSpawn = false
orb.IgnoreGuiInset = true
orb.DisplayOrder = 1001
orb.Enabled = false
orb.Parent = guiParent

local orbBtn = Instance.new("TextButton")
orbBtn.Name = "Orb"
orbBtn.Size = UDim2.fromOffset(48, 48)
orbBtn.Position = UDim2.new(1, -68, 1, -68)
orbBtn.BackgroundColor3 = COLORS.lime
orbBtn.TextColor3 = COLORS.bg
orbBtn.Font = Enum.Font.GothamBlack
orbBtn.TextSize = 14
orbBtn.Text = "DX"
orbBtn.AutoButtonColor = true
orbBtn.Parent = orb

local orbCorner = Instance.new("UICorner")
orbCorner.CornerRadius = UDim.new(1, 0)
orbCorner.Parent = orbBtn

local orbStroke = Instance.new("UIStroke")
orbStroke.Color = COLORS.limeDim
orbStroke.Thickness = 2
orbStroke.Parent = orbBtn

local function setPanelVisible(vis)
    STATE.panelVisible = vis
    panel.Visible = vis
    orb.Enabled = not vis
end

closeBtn.MouseButton1Click:Connect(function()
    setPanelVisible(false)
end)

orbBtn.MouseButton1Click:Connect(function()
    setPanelVisible(true)
end)

-- Drag header
do
    local dragging = false
    local dragStart, startPos

    track(header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
        end
    end))

    track(header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- RightShift toggle
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setPanelVisible(not STATE.panelVisible)
    end
end))

-- Loops
local accum = 0
track(RunService.Heartbeat:Connect(function(dt)
    accum = accum + dt

    -- soft step toward enemy every frame when toggle on
    if STATE.tweenNearest then
        stepTowardNearest()
    end

    if accum < 0.35 then
        return
    end
    accum = 0

    safeCall(function()
        if STATE.enemyEsp then
            refreshEnemyEsp()
        end
        if STATE.npcEsp then
            refreshNpcEsp()
        end
        if STATE.playerEsp then
            refreshPlayerEsp()
        end

        local st = readCharStatus()
        statusLabel.Text = string.format(
            "Busy: %s\nStun: %s\nEnergy: %s\nHasBuso: %s",
            st.busy,
            st.stun,
            st.energy,
            st.buso
        )
    end)
end))

-- Initial remotes scan
task.defer(function()
    local lines, count = scanNetRemotes()
    remoteCount.Text = string.format("Net Remotes: %d", count)
    remoteText.Text = table.concat(lines, "\n")
end)

-- Cleanup if ScreenGui destroyed
screen.Destroying:Connect(function()
    clearAllEsp()
    for _, c in ipairs(connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    pcall(function()
        if orb and orb.Parent then
            orb:Destroy()
        end
    end)
end)

print("[DXLTA] Blox Fruits Panel geladen · RightShift zum Umschalten")
