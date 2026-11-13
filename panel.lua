--[[
    DXLTA Blox Fruits — Hub Panel
    Obsidian + acid lime · BF tools from Explorer dump paths
    (workspace.Enemies / Characters / NPCs, RS.Modules.Net, Busy/Stun/Energy/HasBuso)
    Scout · Erweitern: SCAN / COPY Dump / COPY Logs / COPY Status (in-panel)

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/bf-panel-ff0d/panel.lua"))()

    Toggle: RightShift  ·  Reopen: lime orb bottom-right
]]

print("[DXLTA] BF Panel boot…")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__DXLTA_BF_PANEL and type(ENV.__DXLTA_BF_PANEL.unload) == "function" then
    pcall(ENV.__DXLTA_BF_PANEL.unload)
end
ENV.__DXLTA_BF_PANEL = { version = "1.2" }
local HUB = ENV.__DXLTA_BF_PANEL

local okBoot, bootErr = xpcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

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
    ink = Color3.fromRGB(8, 10, 8),
}

local STATE = {
    fly = false,
    flySpeed = 120,
    noclip = false,
    killAura = false,
    kaRange = 20,
    kaRate = 4,
    farm = false,
    bfSpeed = 150,
    autoQuest = false,
    enemyEsp = false,
    npcEsp = false,
    playerEsp = false,
    panelVisible = true,
}

local ST = {
    farm = "idle",
    kills = 0,
    nearest = "—",
    busy = "—",
    stun = "—",
    energy = "—",
    buso = "—",
    level = "—",
    remotes = "—",
}

local ESP_FOLDER_NAME = "DXLTA_ESP"
local GUI_NAME = "DXLTA_BF_Panel"
local ORB_NAME = "DXLTA_BF_Orb"

local connections = {}
local enemyEspMap = {}
local npcEspMap = {}
local playerEspMap = {}
local alive = true
local travelTok = 0
local pin = nil
local keysDown = {}
local flyBV, flyBG
local noclipSaved = {}
local farmTargetName = nil
local lastClick = 0
local lastQuestTry = 0
local killWatch = setmetatable({}, { __mode = "k" })

-- Scout ring log + last dump
local RING_MAX = 80
local ringLog = {}
local lastDumpText = ""
local lastDumpLines = {}
local lastFarmLogged = "idle"
local lastAuraNear = nil

local function track(conn)
    if conn then
        table.insert(connections, conn)
    end
    return conn
end

local function safeCall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return true, a, b, c
    end
    return false, a
end

local function notify(title, text, dur)
    task.spawn(function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = tostring(title),
                Text = tostring(text):sub(1, 200),
                Duration = dur or 3,
            })
        end)
    end)
end

local function safeLookAt(fromPos, toPos)
    if typeof(fromPos) ~= "Vector3" then
        return CFrame.new()
    end
    if typeof(toPos) ~= "Vector3" or (toPos - fromPos).Magnitude < 0.05 then
        return CFrame.new(fromPos)
    end
    local ok, cf = pcall(CFrame.lookAt, fromPos, toPos)
    if ok and typeof(cf) == "CFrame" then
        return cf
    end
    return CFrame.new(fromPos)
end

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function baseName(n)
    n = tostring(n or "")
    n = n:gsub("%s*%b[]", ""):gsub("%s*%b()", "")
    return trim(n)
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
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    return pg or CoreGui
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
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function isAliveModel(model)
    local hum = getHumanoid(model)
    return hum ~= nil and hum.Health > 0
end

local function localChar()
    return LocalPlayer and LocalPlayer.Character
end

local function localHum()
    local c = localChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function localRoot()
    return getHRP(localChar())
end

local function dataVal(name)
    local d = LocalPlayer:FindFirstChild("Data")
    local v = d and d:FindFirstChild(name)
    if not v then
        return nil
    end
    local ok, x = pcall(function()
        return v.Value
    end)
    return ok and x or nil
end

local function distanceTo(part)
    local root = localRoot()
    if not root or not part then
        return nil
    end
    local ok, dist = pcall(function()
        return (root.Position - part.Position).Magnitude
    end)
    return ok and dist or nil
end

local function isPlayerCharacter(model)
    if not model then
        return false
    end
    if Players:GetPlayerFromCharacter(model) then
        return true
    end
    local chars = Workspace:FindFirstChild("Characters")
    if chars and model:IsDescendantOf(chars) then
        return true
    end
    return false
end

-- ── Folders ─────────────────────────────────────────────────────────────────

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
    return modules and modules:FindFirstChild("Net")
end

local function findCommF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local f = remotes and remotes:FindFirstChild("CommF_")
    if f and (f:IsA("RemoteFunction") or f.ClassName == "RemoteFunction") then
        return f
    end
    return nil
end

local function ringPush(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
    table.insert(ringLog, line)
    while #ringLog > RING_MAX do
        table.remove(ringLog, 1)
    end
end

local function ringText()
    if #ringLog == 0 then
        return "(keine logs — farm/quest/aura starten)"
    end
    return table.concat(ringLog, "\n")
end

local function copyClip(text)
    text = tostring(text or "")
    local ok = false
    if type(setclipboard) == "function" then
        ok = pcall(setclipboard, text)
    end
    if not ok and type(toclipboard) == "function" then
        ok = pcall(toclipboard, text)
    end
    if not ok and type(set_clipboard) == "function" then
        ok = pcall(set_clipboard, text)
    end
    return ok
end

local function invokeComm(...)
    local f = findCommF()
    if not f then
        ringPush("CommF_ missing")
        return false, "CommF_ missing"
    end
    local args = table.pack(...)
    local label = tostring(args[1] or "?")
    for i = 2, math.min(args.n, 4) do
        label = label .. "," .. tostring(args[i])
    end
    local ok, res = pcall(function()
        return f:InvokeServer(table.unpack(args, 1, args.n))
    end)
    local brief = tostring(res)
    if #brief > 64 then
        brief = brief:sub(1, 61) .. "…"
    end
    if ok then
        ringPush("CommF_ " .. label .. " → " .. brief)
    else
        ringPush("CommF_ ERR " .. label .. " → " .. brief)
    end
    return ok, res
end

local function countNetRemotes()
    local n = 0
    local net = getNetFolder()
    if not net then
        return 0
    end
    local function walk(inst, depth)
        if depth > 6 then
            return
        end
        for _, c in ipairs(inst:GetChildren()) do
            if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") or c:IsA("UnreliableRemoteEvent") then
                n += 1
            end
            walk(c, depth + 1)
        end
    end
    pcall(walk, net, 0)
    return n
end

local function iterEnemyModels()
    local list = {}
    local folder = getEnemiesFolder()
    if not folder then
        return list
    end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") and not isPlayerCharacter(child) and getHRP(child) and isAliveModel(child) then
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
    return list
end

local function iterOtherPlayerChars()
    local list = {}
    local chars = getCharactersFolder()
    if chars then
        for _, child in ipairs(chars:GetChildren()) do
            if child:IsA("Model") and child.Name ~= LocalPlayer.Name and getHRP(child) then
                table.insert(list, child)
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and getHRP(plr.Character) then
            local already = false
            for _, m in ipairs(list) do
                if m == plr.Character or m.Name == plr.Name then
                    already = true
                    break
                end
            end
            if not already then
                table.insert(list, plr.Character)
            end
        end
    end
    return list
end

local function findNearestEnemy(maxRange, nameFilter)
    local root = localRoot()
    if not root then
        return nil, nil
    end
    local best, bd
    for _, enemy in ipairs(iterEnemyModels()) do
        if not nameFilter or baseName(enemy.Name) == nameFilter then
            local hrp = getHRP(enemy)
            local hum = getHumanoid(enemy)
            if hrp and hum and hum.Health > 0 then
                local d = (root.Position - hrp.Position).Magnitude
                if (not maxRange or d <= maxRange) and (not bd or d < bd) then
                    best, bd = { model = enemy, hum = hum, root = hrp, name = baseName(enemy.Name) }, d
                end
            end
        end
    end
    return best, bd
end

-- ── ESP ─────────────────────────────────────────────────────────────────────

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
    local bb = folder and folder:FindFirstChild("Tag")
    local label = bb and bb:FindFirstChild("Label")
    if label then
        label.Text = text
    end
end

local function refreshEnemyEsp()
    if not STATE.enemyEsp then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
        return
    end
    local aliveMap = {}
    for _, enemy in ipairs(iterEnemyModels()) do
        aliveMap[enemy] = true
        local hrp = getHRP(enemy)
        local dist = distanceTo(hrp)
        local text = string.format("%s  ·  %s", enemy.Name, dist and string.format("%.0fm", dist) or "?")
        if not enemyEspMap[enemy] then
            makeBillboard(enemy, text, COLORS.enemy, 3.4)
            enemyEspMap[enemy] = true
        else
            updateBillboardText(enemy, text)
        end
    end
    for model in pairs(enemyEspMap) do
        if not aliveMap[model] or not model.Parent then
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
    local aliveMap = {}
    for _, npc in ipairs(iterNpcModels()) do
        aliveMap[npc] = true
        local part = npc:IsA("BasePart") and npc or getHRP(npc)
        local dist = distanceTo(part)
        local text = string.format("%s  ·  %s", npc.Name, dist and string.format("%.0fm", dist) or "?")
        if not npcEspMap[npc] then
            makeBillboard(npc, text, COLORS.npc, 3.0)
            npcEspMap[npc] = true
        else
            updateBillboardText(npc, text)
        end
    end
    for model in pairs(npcEspMap) do
        if not aliveMap[model] or not model.Parent then
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
    local aliveMap = {}
    for _, char in ipairs(iterOtherPlayerChars()) do
        aliveMap[char] = true
        local hrp = getHRP(char)
        local dist = distanceTo(hrp)
        local text = string.format("%s  ·  %s", char.Name, dist and string.format("%.0fm", dist) or "?")
        if not playerEspMap[char] then
            makeBillboard(char, text, COLORS.player, 3.6)
            playerEspMap[char] = true
        else
            updateBillboardText(char, text)
        end
    end
    for model in pairs(playerEspMap) do
        if not aliveMap[model] or not model.Parent then
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

-- ── Status ──────────────────────────────────────────────────────────────────

local function refreshStatus()
    pcall(function()
        local lv = dataVal("Level")
        ST.level = lv ~= nil and tostring(lv) or "—"
    end)
    pcall(function()
        local char = localChar()
        if not char then
            ST.busy, ST.stun, ST.energy, ST.buso = "—", "—", "—", "—"
            return
        end
        local busyVal = char:FindFirstChild("Busy")
        if busyVal and busyVal:IsA("BoolValue") then
            ST.busy = busyVal.Value and "JA" or "NEIN"
        elseif busyVal then
            ST.busy = tostring(busyVal.Value ~= nil and busyVal.Value or busyVal)
        else
            ST.busy = "—"
        end
        local stunVal = char:FindFirstChild("Stun")
        if stunVal and (stunVal:IsA("NumberValue") or stunVal:IsA("IntValue")) then
            ST.stun = string.format("%.2f", stunVal.Value)
        else
            ST.stun = "—"
        end
        local energyVal = char:FindFirstChild("Energy")
        if energyVal and (energyVal:IsA("NumberValue") or energyVal:IsA("IntValue")) then
            ST.energy = string.format("%.0f", energyVal.Value)
        elseif energyVal then
            local n = energyVal:FindFirstChildWhichIsA("NumberValue") or energyVal:FindFirstChildWhichIsA("IntValue")
            ST.energy = n and string.format("%.0f", n.Value) or "vorhanden"
        else
            ST.energy = "—"
        end
        local hasBuso = char:FindFirstChild("HasBuso")
        ST.buso = hasBuso and "JA" or "NEIN"
    end)
    pcall(function()
        ST.remotes = tostring(countNetRemotes())
    end)
    if not STATE.farm and not STATE.killAura then
        local tg, d = findNearestEnemy(250, nil)
        ST.nearest = tg and string.format("%s · %dm", tg.name, math.floor(d or 0)) or "—"
    end
end

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
    return lines, #kids
end

-- ── Scout / Explorer dump ───────────────────────────────────────────────────

local SCOUT_MAX_LINES = 3000
local SCOUT_MAX_DEPTH = 7

local SCOUT_INTEREST = {
    RemoteEvent = true,
    RemoteFunction = true,
    UnreliableRemoteEvent = true,
    BindableEvent = true,
    BindableFunction = true,
    Folder = true,
    ModuleScript = true,
    Script = true,
    LocalScript = true,
    Tool = true,
    Configuration = true,
}

local function getFullPath(inst)
    if not inst then
        return "nil"
    end
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return "game." .. table.concat(parts, ".")
end

local function seaLabel()
    local pid = game.PlaceId
    if pid == 2753915549 then
        return "First Sea"
    elseif pid == 4442272183 then
        return "Second Sea"
    elseif pid == 7449423635 then
        return "Third Sea"
    end
    return "unknown"
end

local function childSummary(container, limit)
    if not container then
        return "(none)"
    end
    limit = limit or 80
    local names = {}
    local ok, kids = pcall(function()
        return container:GetChildren()
    end)
    if not ok or not kids then
        return "(error)"
    end
    for i, c in ipairs(kids) do
        if i > limit then
            table.insert(names, "…+" .. tostring(#kids - limit))
            break
        end
        table.insert(names, string.format("%s[%s]", c.Name, c.ClassName))
    end
    if #names == 0 then
        return "(empty)"
    end
    return table.concat(names, ", ")
end

local function isPriorityName(name)
    local n = string.lower(tostring(name or ""))
    if n == "remotes" or n == "net" or n == "comm" or n == "modules" then
        return true
    end
    if string.find(n, "remote", 1, true) or string.find(n, "comm", 1, true) then
        return true
    end
    return false
end

local function shouldListScout(inst)
    if SCOUT_INTEREST[inst.ClassName] then
        return true
    end
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
        return true
    end
    if isPriorityName(inst.Name) then
        return true
    end
    return false
end

local function isFxSpamPath(pathLower, inst)
    if string.find(pathLower, "%.fx%.", 1, true) or string.find(pathLower, "%.effects%.", 1, true) then
        if inst.ClassName == "Configuration" or string.find(string.lower(inst.Name), "config", 1, true) then
            return true
        end
    end
    local n = string.lower(inst.Name)
    if n == "fx" or n == "effects" or n == "vfx" then
        return true
    end
    return false
end

local function parseFilterTerms(raw)
    local terms = {}
    raw = string.lower(tostring(raw or ""))
    for part in string.gmatch(raw, "[^,;]+") do
        part = trim(part)
        if part ~= "" then
            table.insert(terms, part)
        end
    end
    return terms
end

local function lineMatchesFilter(line, terms)
    if not terms or #terms == 0 then
        return true
    end
    local low = string.lower(line)
    for _, t in ipairs(terms) do
        if string.find(low, t, 1, true) then
            return true
        end
    end
    return false
end

local function scoutWalk(root, lines, truncated, depthCap, skipChildNames)
    if truncated[1] or not root then
        return
    end
    skipChildNames = skipChildNames or {}
    local function walk(inst, depth, underFx)
        if truncated[1] then
            return
        end
        if depth > depthCap then
            return
        end
        if #lines >= SCOUT_MAX_LINES then
            truncated[1] = true
            table.insert(lines, "... TRUNCATED (max ~3000 lines) ...")
            return
        end
        local path = getFullPath(inst)
        local pathLow = string.lower(path)
        local fxHere = underFx or isFxSpamPath(pathLow, inst)
        local list = shouldListScout(inst)
        if list and not (fxHere and inst.ClassName == "Configuration") then
            table.insert(lines, string.format("%s | %s", inst.ClassName, path))
        elseif list and fxHere then
            if isPriorityName(inst.Name) or inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                table.insert(lines, string.format("%s | %s", inst.ClassName, path))
            end
        end
        if fxHere and not isPriorityName(inst.Name) and not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")) then
            if inst.ClassName == "Configuration" or depth > 1 then
                return
            end
        end
        local ok, kids = pcall(function()
            return inst:GetChildren()
        end)
        if not ok or not kids then
            return
        end
        local pri, rest = {}, {}
        for _, c in ipairs(kids) do
            if depth == 0 and skipChildNames[c.Name] then
                -- already dumped in priority pass
            elseif isPriorityName(c.Name) or c:IsA("RemoteEvent") or c:IsA("RemoteFunction") or c:IsA("UnreliableRemoteEvent") then
                table.insert(pri, c)
            else
                table.insert(rest, c)
            end
        end
        for _, c in ipairs(pri) do
            walk(c, depth + 1, fxHere)
            if truncated[1] then
                return
            end
        end
        for _, c in ipairs(rest) do
            walk(c, depth + 1, fxHere)
            if truncated[1] then
                return
            end
        end
    end
    walk(root, 0, false)
end

local function buildScoutHeader()
    local lines = {}
    table.insert(lines, "========== DXLTA SCOUT DUMP ==========")
    table.insert(lines, string.format(
        "PlaceId=%s  GameId=%s  JobId=%s",
        tostring(game.PlaceId),
        tostring(game.GameId),
        tostring(game.JobId)
    ))
    table.insert(lines, string.format("Sea=%s  Time=%s", seaLabel(), os.date("%Y-%m-%d %H:%M:%S")))
    local lv = dataVal("Level")
    table.insert(lines, string.format("Level=%s  Player=%s", tostring(lv ~= nil and lv or "?"), LocalPlayer.Name))
    local data = LocalPlayer:FindFirstChild("Data")
    table.insert(lines, "LocalPlayer.Data children: " .. childSummary(data, 60))
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    table.insert(lines, "RS.Remotes children: " .. childSummary(remotes, 80))
    local net = getNetFolder()
    table.insert(lines, "Modules.Net children: " .. childSummary(net, 80))
    local enemies = getEnemiesFolder()
    local sample = {}
    if enemies then
        local ok, kids = pcall(function()
            return enemies:GetChildren()
        end)
        if ok and kids then
            for i, m in ipairs(kids) do
                if i > 25 then
                    table.insert(sample, "…+" .. tostring(#kids - 25))
                    break
                end
                table.insert(sample, m.Name)
            end
        end
    end
    table.insert(lines, "workspace.Enemies sample: " .. (#sample > 0 and table.concat(sample, ", ") or "(none)"))
    table.insert(lines, "------------------------------------------")
    table.insert(lines, "Format: ClassName | game.Path  ·  remotes/net/comm first · skip deep FX.Configuration")
    table.insert(lines, string.format("MaxDepth=%d  MaxLines=%d", SCOUT_MAX_DEPTH, SCOUT_MAX_LINES))
    table.insert(lines, "------------------------------------------")
    return lines
end

local function runScoutScan(filterRaw)
    local lines = buildScoutHeader()
    local truncated = { false }

    -- Priority roots first
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        table.insert(lines, "")
        table.insert(lines, "### ReplicatedStorage.Remotes ###")
        scoutWalk(remotes, lines, truncated, SCOUT_MAX_DEPTH)
    end
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules and not truncated[1] then
        table.insert(lines, "")
        table.insert(lines, "### ReplicatedStorage.Modules ###")
        scoutWalk(modules, lines, truncated, SCOUT_MAX_DEPTH)
    end
    local enemies = getEnemiesFolder()
    if enemies and not truncated[1] then
        table.insert(lines, "")
        table.insert(lines, "### workspace.Enemies (shallow) ###")
        for _, m in ipairs(enemies:GetChildren()) do
            if #lines >= SCOUT_MAX_LINES then
                truncated[1] = true
                break
            end
            table.insert(lines, string.format("%s | %s", m.ClassName, getFullPath(m)))
        end
    end

    if not truncated[1] then
        table.insert(lines, "")
        table.insert(lines, "### Workspace ###")
        scoutWalk(Workspace, lines, truncated, SCOUT_MAX_DEPTH, { Enemies = true })
    end
    if not truncated[1] then
        table.insert(lines, "")
        table.insert(lines, "### ReplicatedStorage (rest) ###")
        scoutWalk(ReplicatedStorage, lines, truncated, SCOUT_MAX_DEPTH, { Remotes = true, Modules = true })
    end
    local extra = {
        "ReplicatedFirst",
        "Players",
        "Lighting",
        "StarterGui",
        "StarterPack",
    }
    for _, name in ipairs(extra) do
        if truncated[1] then
            break
        end
        local ok, root = pcall(function()
            return game:GetService(name)
        end)
        if ok and root then
            table.insert(lines, "")
            table.insert(lines, string.format("### %s ###", name))
            scoutWalk(root, lines, truncated, SCOUT_MAX_DEPTH)
        end
    end

    table.insert(lines, "")
    table.insert(lines, string.format("========== END (%d lines) ==========", #lines + 1))

    lastDumpLines = lines
    lastDumpText = table.concat(lines, "\n")

    local terms = parseFilterTerms(filterRaw)
    if #terms == 0 then
        return lastDumpText, lines, #lines
    end
    local filtered = {}
    for _, line in ipairs(lines) do
        if lineMatchesFilter(line, terms) then
            table.insert(filtered, line)
        end
    end
    return table.concat(filtered, "\n"), filtered, #lines
end

local function statusOneLiner()
    pcall(refreshStatus)
    local farmOn = STATE.farm and "ON" or "OFF"
    return string.format(
        "LV=%s farm=%s kills=%s near=%s Busy=%s Stun=%s Buso=%s remotes=%s sea=%s",
        tostring(ST.level),
        farmOn,
        tostring(ST.kills),
        tostring(ST.nearest),
        tostring(ST.busy),
        tostring(ST.stun),
        tostring(ST.buso),
        tostring(ST.remotes),
        seaLabel()
    )
end

-- ── Noclip / Fly ────────────────────────────────────────────────────────────

local function applyNoclip(on)
    local c = localChar()
    if not c then
        return
    end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            if on then
                if noclipSaved[part] == nil then
                    noclipSaved[part] = part.CanCollide
                end
                part.CanCollide = false
            elseif noclipSaved[part] ~= nil then
                part.CanCollide = noclipSaved[part]
                noclipSaved[part] = nil
            end
        end
    end
end

local function wantNoclip()
    return STATE.noclip == true and (STATE.fly == true or STATE.farm == true or pin ~= nil)
end

local function stopFlyBody()
    if flyBV then
        pcall(function()
            flyBV:Destroy()
        end)
        flyBV = nil
    end
    if flyBG then
        pcall(function()
            flyBG:Destroy()
        end)
        flyBG = nil
    end
end

local function ensureFlyBody()
    local r = localRoot()
    if not r then
        return
    end
    if not flyBV or flyBV.Parent ~= r then
        stopFlyBody()
        local bv = Instance.new("BodyVelocity")
        bv.Name = "DXLTA_FlyBV"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = r
        flyBV = bv
        local bg = Instance.new("BodyGyro")
        bg.Name = "DXLTA_FlyBG"
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 3000
        bg.CFrame = r.CFrame
        bg.Parent = r
        flyBG = bg
    end
end

local function flyDir()
    local cam = Workspace.CurrentCamera
    if not cam then
        return Vector3.zero
    end
    local cf = cam.CFrame
    local move = Vector3.zero
    if keysDown[Enum.KeyCode.W] then
        move += cf.LookVector
    end
    if keysDown[Enum.KeyCode.S] then
        move -= cf.LookVector
    end
    if keysDown[Enum.KeyCode.A] then
        move -= cf.RightVector
    end
    if keysDown[Enum.KeyCode.D] then
        move += cf.RightVector
    end
    if keysDown[Enum.KeyCode.Space] or keysDown[Enum.KeyCode.E] then
        move += Vector3.new(0, 1, 0)
    end
    if keysDown[Enum.KeyCode.LeftControl] or keysDown[Enum.KeyCode.Q] then
        move -= Vector3.new(0, 1, 0)
    end
    if move.Magnitude < 0.05 then
        return Vector3.zero
    end
    return move.Unit
end

-- ── Tween travel ────────────────────────────────────────────────────────────

local function stopTravel()
    travelTok += 1
end

local function travelTo(dest, label, keep)
    local r, h = localRoot(), localHum()
    if not (r and h) or h.Health <= 0 or typeof(dest) ~= "Vector3" then
        return false
    end
    travelTok += 1
    local tok = travelTok
    ST.farm = "tween: " .. tostring(label or "travel")
    local from = r.Position
    local dist = (dest - from).Magnitude
    local cruise = math.max(from.Y, dest.Y) + (dist > 160 and 45 or 6)
    local pts = {}
    if dist > 40 then
        pts[#pts + 1] = Vector3.new(from.X, cruise, from.Z)
        pts[#pts + 1] = Vector3.new(dest.X, cruise, dest.Z)
    end
    pts[#pts + 1] = dest
    local idx, okArrived = 1, false
    while alive and tok == travelTok do
        if keep and not keep() then
            break
        end
        r, h = localRoot(), localHum()
        if not (r and h and r.Parent) or h.Health <= 0 then
            break
        end
        local dt = RunService.Heartbeat:Wait()
        if tok ~= travelTok or not r.Parent then
            break
        end
        local speed = math.clamp(tonumber(STATE.bfSpeed) or 150, 50, 300)
        local goal = pts[idx]
        local d = goal - r.Position
        local step = speed * math.min(dt, 0.1)
        if d.Magnitude <= step + 0.05 then
            pcall(function()
                r.CFrame = CFrame.new(goal) * (r.CFrame - r.CFrame.Position)
            end)
            idx += 1
            if idx > #pts then
                okArrived = true
                break
            end
        else
            local p = r.Position + d.Unit * step
            local fl = flat(d)
            pcall(function()
                if fl.Magnitude > 0.5 then
                    r.CFrame = safeLookAt(p, p + fl)
                else
                    r.CFrame = CFrame.new(p) * (r.CFrame - r.CFrame.Position)
                end
            end)
        end
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    return okArrived
end

-- ── Combat ──────────────────────────────────────────────────────────────────

local function equipAnyTool()
    local c, h = localChar(), localHum()
    if not (c and h) then
        return nil
    end
    local held = c:FindFirstChildOfClass("Tool")
    if held then
        return held
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then
        return nil
    end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local tip = ""
            pcall(function()
                tip = tostring(t.ToolTip or "")
            end)
            local low = string.lower(t.Name)
            if tip == "Melee" or tip == "Sword" or not string.find(low, "fruit", 1, true) then
                pcall(function()
                    h:EquipTool(t)
                end)
                return t
            end
        end
    end
    return nil
end

local function attackOnce()
    local tool = equipAnyTool()
    if tool then
        pcall(function()
            tool:Activate()
        end)
    end
    local now = os.clock()
    if now - lastClick > 0.12 then
        lastClick = now
        pcall(function()
            if VirtualUser then
                local cam = Workspace.CurrentCamera
                local vs = cam and cam.ViewportSize or Vector2.new(800, 600)
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(vs.X * 0.5, vs.Y * 0.42))
            end
        end)
    end
end

local function watchKill(tg)
    if not tg or not tg.hum or killWatch[tg.hum] then
        return
    end
    killWatch[tg.hum] = true
    local c
    c = tg.hum.Died:Connect(function()
        if c then
            c:Disconnect()
        end
        ST.kills += 1
    end)
    track(c)
end

local function killAuraTick()
    if not STATE.killAura and not STATE.farm then
        return
    end
    local range = math.clamp(tonumber(STATE.kaRange) or 20, 5, 50)
    local filter = STATE.farm and farmTargetName or nil
    local tg, d = findNearestEnemy(range, filter)
    if not tg and STATE.farm then
        tg, d = findNearestEnemy(range, nil)
    end
    if not tg then
        return
    end
    ST.nearest = string.format("%s · %dm", tg.name, math.floor(d or 0))
    if STATE.killAura and tg.name ~= lastAuraNear then
        lastAuraNear = tg.name
        ringPush("aura → " .. tg.name .. " @" .. math.floor(d or 0) .. "m")
    end
    local r = localRoot()
    if r then
        local look = Vector3.new(tg.root.Position.X, r.Position.Y, tg.root.Position.Z)
        pcall(function()
            r.CFrame = safeLookAt(r.Position, look)
        end)
    end
    watchKill(tg)
    attackOnce()
end

-- ── Quests ──────────────────────────────────────────────────────────────────

local Q1 = {
    { 0, "BanditQuest1", 1, "Bandit" },
    { 10, "JungleQuest", 1, "Monkey" },
    { 15, "JungleQuest", 2, "Gorilla" },
    { 30, "BuggyQuest1", 1, "Pirate" },
    { 40, "BuggyQuest1", 2, "Brute" },
    { 60, "DesertQuest", 1, "Desert Bandit" },
    { 75, "DesertQuest", 2, "Desert Officer" },
    { 90, "SnowQuest", 1, "Snow Bandit" },
    { 100, "SnowQuest", 2, "Snowman" },
    { 120, "MarineQuest2", 1, "Chief Petty Officer" },
    { 150, "SkyQuest", 1, "Sky Bandit" },
    { 175, "SkyQuest", 2, "Dark Master" },
}

local QUEST_GIVER_NAMES = {
    "Area 1 Quest Giver",
    "Area 2 Quest Giver",
    "Marine Quest Giver",
    "Graveyard Quest Giver",
    "Ice Quest Giver",
    "Fire Quest Giver",
    "Frost Quest Giver",
    "Forgotten Quest Giver",
    "Snow Quest Giver",
    "Rear Crew Quest Giver",
    "Front Crew Quest Giver",
}

local function questPlan()
    local lv = tonumber(dataVal("Level")) or 0
    local pick
    for _, q in ipairs(Q1) do
        if q[1] <= lv then
            pick = q
        end
    end
    return pick
end

local function findQuestGiver()
    local npcs = getNpcsFolder()
    if not npcs then
        return nil
    end
    local r = localRoot()
    local best, bd
    for _, m in ipairs(npcs:GetChildren()) do
        local nm = m.Name
        local hit = string.find(string.lower(nm), "quest", 1, true) ~= nil
        if not hit then
            for _, gn in ipairs(QUEST_GIVER_NAMES) do
                if nm == gn then
                    hit = true
                    break
                end
            end
        end
        if hit then
            local root = getHRP(m)
            local p = root and root.Position
            if p and r then
                local d = (p - r.Position).Magnitude
                if not bd or d < bd then
                    best, bd = m, d
                end
            elseif not best then
                best = m
            end
        end
    end
    return best, bd
end

local function firePromptsNear(model)
    if not model then
        return false
    end
    local fired = false
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function()
                if fireproximityprompt then
                    fireproximityprompt(d)
                    fired = true
                end
            end)
            pcall(function()
                d:InputHoldBegin()
                task.wait(0.05)
                d:InputHoldEnd()
                fired = true
            end)
        end
    end
    return fired
end

local function tryAutoQuest()
    if not STATE.autoQuest then
        return
    end
    if os.clock() - lastQuestTry < 4 then
        return
    end
    lastQuestTry = os.clock()
    local plan = questPlan()
    if plan then
        ringPush("quest try " .. tostring(plan[2]) .. " #" .. tostring(plan[3]) .. " → " .. tostring(plan[4]))
        local ok = invokeComm("StartQuest", plan[2], plan[3])
        if ok then
            farmTargetName = plan[4]
            ST.farm = "quest: " .. plan[2]
            notify("DXLTA", "StartQuest " .. plan[2] .. " #" .. tostring(plan[3]), 2)
            return
        end
        ringPush("quest CommF_ failed · fallback prompt")
    else
        ringPush("quest: no plan for level")
    end
    local giver, dist = findQuestGiver()
    if giver then
        local root = getHRP(giver)
        if root and dist and dist > 14 then
            travelTo(root.Position + Vector3.new(0, 3, 0), "quest giver", function()
                return STATE.autoQuest == true
            end)
        end
        firePromptsNear(giver)
        ST.farm = "prompt @ " .. giver.Name
        ringPush("quest prompt @ " .. giver.Name)
    else
        ringPush("quest: no giver found")
    end
end

-- ── Auto Farm ───────────────────────────────────────────────────────────────

local function farmStep()
    local r, h = localRoot(), localHum()
    if not (r and h) then
        ST.farm = "waiting for character"
        return
    end
    if h.Health <= 0 then
        ST.farm = "dead · abort"
        pin = nil
        stopTravel()
        return
    end
    if STATE.autoQuest then
        pcall(tryAutoQuest)
    end
    local nameFilter = farmTargetName
    if not nameFilter then
        local plan = questPlan()
        if plan then
            nameFilter = plan[4]
        end
    end
    local tg, d = findNearestEnemy(nil, nameFilter)
    if not tg then
        tg, d = findNearestEnemy(nil, nil)
    end
    if not tg then
        ST.farm = "no enemies"
        ST.nearest = "—"
        pin = nil
        return
    end
    ST.nearest = string.format("%s · %dm", tg.name, math.floor(d or 0))
    local away = flat(r.Position - tg.root.Position)
    away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
    local spot = tg.root.Position + away * 4
    if d > 10 then
        pin = nil
        ST.farm = "travel → " .. tg.name
        travelTo(spot + Vector3.new(0, 1, 0), tg.name, function()
            return STATE.farm == true and tg.hum.Health > 0 and tg.model.Parent ~= nil and (localHum() and localHum().Health > 0)
        end)
        return
    end
    watchKill(tg)
    pin = { pos = spot, root = tg.root, untilT = os.clock() + 2.5 }
    ST.farm = "farming " .. tg.name
    local rate = math.clamp(tonumber(STATE.kaRate) or 4, 1, 12)
    for _ = 1, 2 do
        if not STATE.farm or tg.hum.Health <= 0 then
            break
        end
        local hh = localHum()
        if not hh or hh.Health <= 0 then
            break
        end
        local look = Vector3.new(tg.root.Position.X, spot.Y, tg.root.Position.Z)
        pcall(function()
            local rr = localRoot()
            if rr then
                rr.CFrame = safeLookAt(spot, look)
            end
        end)
        attackOnce()
        task.wait(1 / rate)
    end
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
panel.Size = UDim2.fromOffset(370, 580)
panel.Position = UDim2.new(0, 24, 0.5, -290)
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
brand.TextSize = 28
brand.TextXAlignment = Enum.TextXAlignment.Left
brand.TextColor3 = COLORS.lime
brand.Text = "DXLTA"
brand.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 40)
subtitle.Size = UDim2.new(1, -60, 0, 20)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = COLORS.muted
subtitle.Text = "Blox Fruits Hub · RightShift"
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

local orderN = 0
local function nextOrder()
    orderN += 1
    return orderN
end

local liveLabels = {}

local function sectionLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = COLORS.limeSoft
    lbl.Text = text
    lbl.LayoutOrder = nextOrder()
    lbl.Parent = body
    return lbl
end

local function makeToggle(label, key, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = COLORS.panelAlt
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(12, 0)
    text.Size = UDim2.new(1, -70, 1, 0)
    text.Font = Enum.Font.Gotham
    text.TextSize = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextColor3 = COLORS.text
    text.Text = label
    text.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(52, 24)
    btn.Position = UDim2.new(1, -60, 0.5, -12)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = true
    btn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local function paint()
        if STATE[key] then
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
        STATE[key] = not STATE[key]
        paint()
        if onChange then
            safeCall(onChange, STATE[key])
        end
    end)
end

local function makeSlider(label, key, minV, maxV)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = COLORS.panelAlt
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row

    local lab = Instance.new("TextLabel")
    lab.BackgroundTransparency = 1
    lab.Position = UDim2.fromOffset(12, 4)
    lab.Size = UDim2.new(1, -24, 0, 16)
    lab.Font = Enum.Font.Gotham
    lab.TextSize = 12
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.TextColor3 = COLORS.text
    lab.Text = label .. ": " .. tostring(STATE[key])
    lab.Parent = row

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(12, 26)
    bar.Size = UDim2.new(1, -24, 0, 10)
    bar.BackgroundColor3 = COLORS.border
    bar.BorderSizePixel = 0
    bar.Parent = row

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 5)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((STATE[key] - minV) / math.max(maxV - minV, 1), 0, 1, 0)
    fill.BackgroundColor3 = COLORS.lime
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 5)
    fillCorner.Parent = fill

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local val = math.floor(minV + rel * (maxV - minV) + 0.5)
        STATE[key] = val
        fill.Size = UDim2.new(rel, 0, 1, 0)
        lab.Text = label .. ": " .. tostring(val)
    end

    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function makeLive(title, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.LayoutOrder = nextOrder()
    row.Parent = body

    local left = Instance.new("TextLabel")
    left.BackgroundTransparency = 1
    left.Size = UDim2.new(0.36, 0, 1, 0)
    left.Font = Enum.Font.Gotham
    left.TextSize = 11
    left.TextXAlignment = Enum.TextXAlignment.Left
    left.TextColor3 = COLORS.muted
    left.Text = title
    left.Parent = row

    local val = Instance.new("TextLabel")
    val.BackgroundTransparency = 1
    val.Position = UDim2.new(0.36, 0, 0, 0)
    val.Size = UDim2.new(0.64, 0, 1, 0)
    val.Font = Enum.Font.Code
    val.TextSize = 11
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.TextColor3 = COLORS.lime
    val.TextTruncate = Enum.TextTruncate.AtEnd
    val.Text = "—"
    val.Parent = row
    liveLabels[key] = val
end

local function makeButton(label, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = color or COLORS.lime
    btn.TextColor3 = COLORS.bg
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Text = label
    btn.AutoButtonColor = true
    btn.LayoutOrder = nextOrder()
    btn.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        safeCall(onClick)
    end)
    return btn
end

local function makeRemotesBox()
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 130)
    wrap.BackgroundColor3 = COLORS.bg
    wrap.BorderSizePixel = 0
    wrap.LayoutOrder = nextOrder()
    wrap.Parent = body

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = wrap

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.border
    stroke.Thickness = 1
    stroke.Parent = wrap

    local countLbl = Instance.new("TextLabel")
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

-- Build sections
local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, 0, 0, 28)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextColor3 = COLORS.muted
hint.TextWrapped = true
hint.Text = "RightShift = Panel · Lime-Orb = wieder öffnen"
hint.LayoutOrder = nextOrder()
hint.Parent = body

sectionLabel("MOVEMENT")
makeToggle("Fly (WASD · Space/Ctrl · E/Q)", "fly", function(on)
    if not on then
        stopFlyBody()
        local h = localHum()
        if h then
            h.PlatformStand = false
        end
    end
end)
makeSlider("Fly speed", "flySpeed", 50, 300)
makeToggle("Noclip (mit Fly / Farm)", "noclip", function(on)
    if not on then
        applyNoclip(false)
    end
end)
makeSlider("Tween / Farm speed", "bfSpeed", 50, 300)

sectionLabel("COMBAT / FARM")
makeToggle("Kill Aura", "killAura", function(on)
    lastAuraNear = nil
    ringPush(on and "kill aura ON" or "kill aura OFF")
end)
makeSlider("Aura range", "kaRange", 5, 50)
makeSlider("Attack rate", "kaRate", 1, 12)
makeToggle("Auto Level / Farm", "farm", function(on)
    if not on then
        pin = nil
        stopTravel()
        ST.farm = "idle"
        ringPush("farm OFF")
    else
        ST.farm = "starting"
        ringPush("farm ON")
    end
end)
makeToggle("Auto Quest (CommF_ / Prompt)", "autoQuest", function(on)
    ringPush(on and "auto quest ON" or "auto quest OFF")
end)

sectionLabel("ESP")
makeToggle("Gegner ESP (Enemies)", "enemyEsp", function(on)
    if not on then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
    else
        refreshEnemyEsp()
    end
end)
makeToggle("NPC ESP", "npcEsp", function(on)
    if not on then
        for model in pairs(npcEspMap) do
            clearEspOn(model)
        end
        npcEspMap = {}
    else
        refreshNpcEsp()
    end
end)
makeToggle("Spieler ESP", "playerEsp", function(on)
    if not on then
        for model in pairs(playerEspMap) do
            clearEspOn(model)
        end
        playerEspMap = {}
    else
        refreshPlayerEsp()
    end
end)

sectionLabel("STATUS (live)")
makeLive("Farm", "farm")
makeLive("Kills", "kills")
makeLive("Nearest", "nearest")
makeLive("Busy", "busy")
makeLive("Stun", "stun")
makeLive("Energy", "energy")
makeLive("HasBuso", "buso")
makeLive("Level", "level")
makeLive("Net remotes", "remotes")

sectionLabel("MODULES.NET (lesen)")
local remoteCount, remoteText = makeRemotesBox()
makeButton("Net Remotes aktualisieren", COLORS.limeSoft, function()
    local lines, count = scanNetRemotes()
    remoteCount.Text = string.format("Net Remotes: %d", count)
    remoteText.Text = table.concat(lines, "\n")
end)

sectionLabel("SCOUT · ERWEITERN")
local scoutHint = Instance.new("TextLabel")
scoutHint.BackgroundColor3 = COLORS.bg
scoutHint.Size = UDim2.new(1, 0, 0, 40)
scoutHint.Font = Enum.Font.Gotham
scoutHint.TextSize = 11
scoutHint.TextXAlignment = Enum.TextXAlignment.Left
scoutHint.TextYAlignment = Enum.TextYAlignment.Top
scoutHint.TextColor3 = COLORS.limeSoft
scoutHint.TextWrapped = true
scoutHint.Text = "  Scan → Copy → Dump hier im Chat einfügen → wir erweitern den Script"
scoutHint.LayoutOrder = nextOrder()
scoutHint.Parent = body
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = scoutHint
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 8)
    p.PaddingLeft = UDim.new(0, 4)
    p.PaddingRight = UDim.new(0, 4)
    p.Parent = scoutHint
end

local scoutFilter = Instance.new("TextBox")
scoutFilter.Name = "ScoutFilter"
scoutFilter.PlaceholderText = "Remote, CommF, Modules.Net, Enemies"
scoutFilter.Text = ""
scoutFilter.ClearTextOnFocus = false
scoutFilter.Size = UDim2.new(1, 0, 0, 32)
scoutFilter.BackgroundColor3 = COLORS.bg
scoutFilter.TextColor3 = COLORS.text
scoutFilter.PlaceholderColor3 = COLORS.muted
scoutFilter.Font = Enum.Font.Code
scoutFilter.TextSize = 12
scoutFilter.TextXAlignment = Enum.TextXAlignment.Left
scoutFilter.LayoutOrder = nextOrder()
scoutFilter.Parent = body
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = scoutFilter
    local s = Instance.new("UIStroke")
    s.Color = COLORS.border
    s.Thickness = 1
    s.Parent = scoutFilter
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = scoutFilter
end

local scoutStatus = Instance.new("TextLabel")
scoutStatus.BackgroundTransparency = 1
scoutStatus.Size = UDim2.new(1, 0, 0, 16)
scoutStatus.Font = Enum.Font.Gotham
scoutStatus.TextSize = 11
scoutStatus.TextXAlignment = Enum.TextXAlignment.Left
scoutStatus.TextColor3 = COLORS.muted
scoutStatus.Text = "Scout bereit"
scoutStatus.LayoutOrder = nextOrder()
scoutStatus.Parent = body

local function setScoutStatus(msg, ok)
    scoutStatus.Text = tostring(msg)
    if ok == true then
        scoutStatus.TextColor3 = COLORS.lime
    elseif ok == false then
        scoutStatus.TextColor3 = COLORS.danger
    else
        scoutStatus.TextColor3 = COLORS.muted
    end
end

local scoutPreviewWrap = Instance.new("Frame")
scoutPreviewWrap.Size = UDim2.new(1, 0, 0, 120)
scoutPreviewWrap.BackgroundColor3 = COLORS.bg
scoutPreviewWrap.BorderSizePixel = 0
scoutPreviewWrap.LayoutOrder = nextOrder()
scoutPreviewWrap.Parent = body
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = scoutPreviewWrap
    local s = Instance.new("UIStroke")
    s.Color = COLORS.border
    s.Thickness = 1
    s.Parent = scoutPreviewWrap
end

local scoutScroll = Instance.new("ScrollingFrame")
scoutScroll.Size = UDim2.new(1, -10, 1, -8)
scoutScroll.Position = UDim2.fromOffset(5, 4)
scoutScroll.BackgroundTransparency = 1
scoutScroll.BorderSizePixel = 0
scoutScroll.ScrollBarThickness = 4
scoutScroll.ScrollBarImageColor3 = COLORS.limeDim
scoutScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scoutScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scoutScroll.Parent = scoutPreviewWrap

local scoutPreview = Instance.new("TextLabel")
scoutPreview.BackgroundTransparency = 1
scoutPreview.Size = UDim2.new(1, -6, 0, 0)
scoutPreview.Position = UDim2.fromOffset(2, 0)
scoutPreview.AutomaticSize = Enum.AutomaticSize.Y
scoutPreview.Font = Enum.Font.Code
scoutPreview.TextSize = 10
scoutPreview.TextXAlignment = Enum.TextXAlignment.Left
scoutPreview.TextYAlignment = Enum.TextYAlignment.Top
scoutPreview.TextColor3 = COLORS.muted
scoutPreview.TextWrapped = true
scoutPreview.Text = "(noch kein dump — SCAN Explorer)"
scoutPreview.Parent = scoutScroll

local function setScoutPreview(text)
    local t = tostring(text or "")
    -- UI truncated; full text kept in lastDumpText for COPY
    if #t > 3500 then
        scoutPreview.Text = t:sub(1, 3500) .. "\n… (UI truncated — COPY Dump = full)"
    else
        scoutPreview.Text = t ~= "" and t or "(leer)"
    end
end

local function filteredDumpView()
    local terms = parseFilterTerms(scoutFilter.Text)
    if lastDumpText == "" then
        return ""
    end
    if #terms == 0 then
        return lastDumpText
    end
    local filtered = {}
    for _, line in ipairs(lastDumpLines) do
        if lineMatchesFilter(line, terms) then
            table.insert(filtered, line)
        end
    end
    return table.concat(filtered, "\n")
end

makeButton("SCAN Explorer", COLORS.lime, function()
    setScoutStatus("Scanning…", nil)
    task.wait()
    local view, filteredLines, total = runScoutScan(scoutFilter.Text)
    setScoutPreview(view)
    setScoutStatus(string.format("Scan · %d Zeilen · Ansicht %d", total, #filteredLines), true)
    ringPush("scout scan " .. tostring(total) .. " lines")
end)

makeButton("COPY Dump", COLORS.limeSoft, function()
    if lastDumpText == "" then
        setScoutStatus("Nichts zu kopieren — erst SCAN", false)
        return
    end
    local text = filteredDumpView()
    if text == "" then
        text = lastDumpText
    end
    if copyClip(text) then
        setScoutStatus("kopiert — hier an den Agent schicken", true)
        notify("DXLTA", "kopiert — hier an den Agent schicken", 3)
    else
        setScoutStatus("Clipboard unavailable", false)
    end
end)

makeButton("COPY Logs", Color3.fromRGB(120, 180, 70), function()
    local text = ringText()
    if copyClip(text) then
        setScoutStatus("Logs kopiert (" .. tostring(#ringLog) .. " Zeilen)", true)
        notify("DXLTA", "kopiert — hier an den Agent schicken", 3)
    else
        setScoutStatus("Clipboard unavailable", false)
    end
end)

makeButton("COPY Status", Color3.fromRGB(90, 140, 60), function()
    local line = statusOneLiner()
    if copyClip(line) then
        setScoutStatus("Status: " .. line, true)
        notify("DXLTA", "kopiert — hier an den Agent schicken", 2)
    else
        setScoutStatus("Clipboard unavailable", false)
    end
end)

scoutFilter:GetPropertyChangedSignal("Text"):Connect(function()
    if lastDumpText ~= "" then
        setScoutPreview(filteredDumpView())
    end
end)

local footer = Instance.new("TextLabel")
footer.BackgroundTransparency = 1
footer.Size = UDim2.new(1, 0, 0, 36)
footer.Font = Enum.Font.Gotham
footer.TextSize = 10
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.TextColor3 = COLORS.muted
footer.TextWrapped = true
footer.Text = "Pfade: workspace.Enemies / Characters / NPCs · RS.Remotes.CommF_ · Flags Busy/Stun/Energy/HasBuso · Scout in-panel"
footer.LayoutOrder = nextOrder()
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

-- Drag
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

track(UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        keysDown[input.KeyCode] = true
    end
    if gp then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setPanelVisible(not STATE.panelVisible)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        keysDown[input.KeyCode] = nil
    end
end))

-- Heartbeat: fly / noclip / pin
track(RunService.Heartbeat:Connect(function()
    if not alive then
        return
    end
    pcall(function()
        if wantNoclip() then
            applyNoclip(true)
        end
        if STATE.fly then
            ensureFlyBody()
            local r = localRoot()
            if r and flyBV then
                local dir = flyDir()
                local spd = math.clamp(tonumber(STATE.flySpeed) or 120, 50, 300)
                flyBV.Velocity = dir * spd
                if flyBG then
                    local cam = Workspace.CurrentCamera
                    if cam then
                        flyBG.CFrame = cam.CFrame
                    end
                end
                local h = localHum()
                if h then
                    h.PlatformStand = true
                end
            end
        else
            if flyBV then
                stopFlyBody()
                local h = localHum()
                if h and h.PlatformStand then
                    h.PlatformStand = false
                end
            end
        end
        if pin then
            if os.clock() > pin.untilT or not pin.root or not pin.root.Parent then
                pin = nil
            else
                local r = localRoot()
                if r then
                    local at = pin.pos
                    local look = Vector3.new(pin.root.Position.X, at.Y, pin.root.Position.Z)
                    pcall(function()
                        r.CFrame = safeLookAt(at, look)
                        r.AssemblyLinearVelocity = Vector3.zero
                    end)
                end
            end
        end
    end)
end))

-- Kill aura rate loop
task.spawn(function()
    while alive do
        local rate = math.clamp(tonumber(STATE.kaRate) or 4, 1, 12)
        task.wait(1 / rate)
        pcall(killAuraTick)
    end
end)

-- Farm loop 0.25s
task.spawn(function()
    while alive do
        task.wait(0.25)
        if STATE.farm then
            local ok, err = pcall(farmStep)
            if not ok then
                ST.farm = "err"
                ringPush("farm ERR " .. tostring(err):sub(1, 80))
                warn("[DXLTA] farm: " .. tostring(err))
            end
        end
    end
end)

-- Status + ESP
local accum = 0
track(RunService.Heartbeat:Connect(function(dt)
    accum += dt
    if accum < 0.4 then
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
        refreshStatus()
        if ST.farm ~= lastFarmLogged then
            lastFarmLogged = ST.farm
            ringPush("farm: " .. tostring(ST.farm))
        end
        if liveLabels.farm then
            liveLabels.farm.Text = tostring(ST.farm)
        end
        if liveLabels.kills then
            liveLabels.kills.Text = tostring(ST.kills)
        end
        if liveLabels.nearest then
            liveLabels.nearest.Text = tostring(ST.nearest)
        end
        if liveLabels.busy then
            liveLabels.busy.Text = tostring(ST.busy)
        end
        if liveLabels.stun then
            liveLabels.stun.Text = tostring(ST.stun)
        end
        if liveLabels.energy then
            liveLabels.energy.Text = tostring(ST.energy)
        end
        if liveLabels.buso then
            liveLabels.buso.Text = tostring(ST.buso)
        end
        if liveLabels.level then
            liveLabels.level.Text = tostring(ST.level)
        end
        if liveLabels.remotes then
            liveLabels.remotes.Text = tostring(ST.remotes)
        end
    end)
end))

track(LocalPlayer.CharacterAdded:Connect(function()
    noclipSaved = {}
    stopFlyBody()
    pin = nil
    task.wait(0.5)
    if wantNoclip() then
        applyNoclip(true)
    end
end))

task.defer(function()
    local lines, count = scanNetRemotes()
    remoteCount.Text = string.format("Net Remotes: %d", count)
    remoteText.Text = table.concat(lines, "\n")
end)

function HUB.unload()
    alive = false
    stopTravel()
    pin = nil
    stopFlyBody()
    applyNoclip(false)
    clearAllEsp()
    for _, c in ipairs(connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(connections)
    pcall(function()
        if screen then
            screen:Destroy()
        end
    end)
    pcall(function()
        if orb then
            orb:Destroy()
        end
    end)
    ENV.__DXLTA_BF_PANEL = nil
end

screen.Destroying:Connect(function()
    pcall(HUB.unload)
end)

notify("DXLTA", "BF Panel ready · RightShift to toggle", 4)
print("[DXLTA] BF Panel ready — panel.lua loaded")

end, debug.traceback)

if not okBoot then
    warn("[DXLTA] BF Panel boot error: " .. tostring(bootErr))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "DXLTA boot error",
            Text = tostring(bootErr):sub(1, 180),
            Duration = 8,
        })
    end)
end
