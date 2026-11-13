--[[
    DXLTA Blox Fruits — Mobile Hub Panel
    Acid lime + obsidian · Nur BF: Farm · Silent Aura · Quest · Buso · ESP · Scout
    Tabs: Start · Farm · Kampf · ESP · Scout

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/bf-panel-ff0d/panel.lua"))()

    Toggle: RightShift  ·  Reopen: lime orb bottom-right
]]

print("[DXLTA] BF Panel boot…")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__DXLTA_BF_PANEL and type(ENV.__DXLTA_BF_PANEL.unload) == "function" then
    pcall(ENV.__DXLTA_BF_PANEL.unload)
end
ENV.__DXLTA_BF_PANEL = { version = "2.0" }
local HUB = ENV.__DXLTA_BF_PANEL

local okBoot, bootErr = xpcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager
local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

local COLORS = {
    bg = Color3.fromRGB(8, 10, 12),
    panel = Color3.fromRGB(14, 18, 22),
    panelAlt = Color3.fromRGB(22, 28, 34),
    border = Color3.fromRGB(40, 50, 58),
    text = Color3.fromRGB(230, 236, 240),
    muted = Color3.fromRGB(120, 132, 148),
    lime = Color3.fromRGB(180, 255, 40),
    limeDim = Color3.fromRGB(90, 140, 20),
    limeSoft = Color3.fromRGB(150, 210, 55),
    danger = Color3.fromRGB(255, 90, 90),
    enemy = Color3.fromRGB(255, 120, 80),
    npc = Color3.fromRGB(120, 200, 255),
    player = Color3.fromRGB(200, 140, 255),
    ink = Color3.fromRGB(6, 8, 6),
}

local STATE = {
    farm = false,
    autoQuest = false,
    killAura = false,
    mobPull = false,
    autoBuso = false,
    fastFarm = false,
    kaRange = 22,
    kaRate = 6,
    bfSpeed = 160,
    enemyEsp = false,
    npcEsp = false,
    playerEsp = false,
    scoutAutoCopy = true,
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
    lastScoutCopy = "noch nie",
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
local farmTargetName = nil
local lastClick = 0
local lastQuestTry = 0
local lastBusoTry = 0
local lastAuraNear = nil
local lastFarmLogged = "idle"
local killWatch = setmetatable({}, { __mode = "k" })
local animHooks = {}
local discoveredRemotes = {}

local RING_MAX = 100
local ringLog = {}
local lastDumpText = ""
local lastDumpLines = {}
local lastAutoCopyAt = 0

local liveLabels = {}
local tabPages = {}
local tabButtons = {}
local currentTab = "Start"
local scoutStatusLbl
local scoutFilterBox
local scoutPreviewLbl
local setScoutStatus

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

-- ── Folders / remotes ───────────────────────────────────────────────────────

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

local function rememberRemote(inst)
    if not inst then
        return
    end
    local path = inst:GetFullName()
    if not discoveredRemotes[path] then
        discoveredRemotes[path] = inst.ClassName
        ringPush("remote+ " .. inst.ClassName .. " " .. inst.Name)
    end
end

local function discoverCombatRemotes()
    local found = {}
    local function walk(root, depth)
        if not root or depth > 5 then
            return
        end
        local ok, kids = pcall(function()
            return root:GetChildren()
        end)
        if not ok or not kids then
            return
        end
        for _, c in ipairs(kids) do
            local n = string.lower(c.Name)
            if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") or c:IsA("UnreliableRemoteEvent") then
                rememberRemote(c)
                if string.find(n, "combat", 1, true)
                    or string.find(n, "attack", 1, true)
                    or string.find(n, "hit", 1, true)
                    or string.find(n, "register", 1, true)
                    or string.find(n, "shoot", 1, true)
                    or string.find(n, "damage", 1, true)
                    or n == "re" then
                    table.insert(found, c)
                end
            end
            if c:IsA("Folder") or c:IsA("ModuleScript") or c.ClassName == "Folder" then
                walk(c, depth + 1)
            end
        end
    end
    pcall(walk, getNetFolder(), 0)
    pcall(walk, ReplicatedStorage:FindFirstChild("Remotes"), 0)
    return found
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
                rememberRemote(c)
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

local function statusOneLiner()
    pcall(refreshStatus)
    return string.format(
        "LV=%s farm=%s kills=%s near=%s Busy=%s Stun=%s Buso=%s remotes=%s sea=%s PlaceId=%s",
        tostring(ST.level),
        STATE.farm and "ON" or "OFF",
        tostring(ST.kills),
        tostring(ST.nearest),
        tostring(ST.busy),
        tostring(ST.stun),
        tostring(ST.buso),
        tostring(ST.remotes),
        seaLabel(),
        tostring(game.PlaceId)
    )
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
                -- skip
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
    table.insert(lines, "========== DXLTA SCOUT BUNDLE ==========")
    table.insert(lines, string.format(
        "PlaceId=%s  GameId=%s  JobId=%s",
        tostring(game.PlaceId),
        tostring(game.GameId),
        tostring(game.JobId)
    ))
    table.insert(lines, string.format("Sea=%s  Time=%s", seaLabel(), os.date("%Y-%m-%d %H:%M:%S")))
    local lv = dataVal("Level")
    table.insert(lines, string.format("Level=%s  Player=%s", tostring(lv ~= nil and lv or "?"), LocalPlayer.Name))
    table.insert(lines, "STATUS: " .. statusOneLiner())
    table.insert(lines, string.format(
        "FLAGS: farm=%s quest=%s aura=%s pull=%s buso=%s fast=%s",
        tostring(STATE.farm),
        tostring(STATE.autoQuest),
        tostring(STATE.killAura),
        tostring(STATE.mobPull),
        tostring(STATE.autoBuso),
        tostring(STATE.fastFarm)
    ))
    table.insert(lines, "FarmState=" .. tostring(ST.farm) .. "  Nearest=" .. tostring(ST.nearest))
    local data = LocalPlayer:FindFirstChild("Data")
    table.insert(lines, "LocalPlayer.Data children: " .. childSummary(data, 60))
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    table.insert(lines, "RS.Remotes children: " .. childSummary(remotes, 80))
    local net = getNetFolder()
    table.insert(lines, "Modules.Net children: " .. childSummary(net, 80))
    local disc = {}
    for path, cls in pairs(discoveredRemotes) do
        table.insert(disc, cls .. " " .. path)
    end
    table.sort(disc)
    table.insert(lines, "Discovered remotes: " .. (#disc > 0 and table.concat(disc, " | ") or "(none yet)"))
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
    table.insert(lines, "----- RING LOG (tail) -----")
    local start = math.max(1, #ringLog - 40)
    for i = start, #ringLog do
        table.insert(lines, ringLog[i])
    end
    table.insert(lines, "------------------------------------------")
    return lines
end

local function runScoutScan(filterRaw)
    local lines = buildScoutHeader()
    local truncated = { false }

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

local function buildScoutBundleLite()
    local lines = buildScoutHeader()
    table.insert(lines, "========== END BUNDLE ==========")
    return table.concat(lines, "\n")
end

local function doAutoCopyScout()
    local bundle = buildScoutBundleLite()
    if copyClip(bundle) then
        lastAutoCopyAt = os.clock()
        ST.lastScoutCopy = os.date("%H:%M:%S")
        if setScoutStatus then
            setScoutStatus("Auto-Copy @ " .. ST.lastScoutCopy, true)
        end
        if liveLabels.lastScoutCopy then
            liveLabels.lastScoutCopy.Text = ST.lastScoutCopy
        end
        return true
    end
    if setScoutStatus then
        setScoutStatus("Auto-Copy failed (no clipboard)", false)
    end
    return false
end

-- ── Tween travel (farm-only, not user Fly) ──────────────────────────────────

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
        local speed = math.clamp(tonumber(STATE.bfSpeed) or 160, 50, 300)
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

-- ── Silent combat / animation suppress ──────────────────────────────────────

local ATTACK_ANIM_HINTS = {
    "attack", "slash", "punch", "m1", "combat", "swing", "hit", "melee", "combo", "strike",
}

local function isAttackAnimTrack(track)
    if not track then
        return false
    end
    local name = ""
    local id = ""
    pcall(function()
        name = string.lower(tostring(track.Name or ""))
    end)
    pcall(function()
        local anim = track.Animation
        if anim then
            id = string.lower(tostring(anim.AnimationId or ""))
            name = name .. " " .. string.lower(tostring(anim.Name or ""))
        end
    end)
    local blob = name .. " " .. id
    for _, hint in ipairs(ATTACK_ANIM_HINTS) do
        if string.find(blob, hint, 1, true) then
            return true
        end
    end
    return false
end

local function stopAttackTracks()
    local char = localChar()
    if not char then
        return
    end
    local hum = getHumanoid(char)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = char:FindFirstChildOfClass("Animator")
    end
    local function stopOn(obj)
        if not obj then
            return
        end
        local ok, tracks = pcall(function()
            return obj:GetPlayingAnimationTracks()
        end)
        if ok and tracks then
            for _, tr in ipairs(tracks) do
                if isAttackAnimTrack(tr) then
                    pcall(function()
                        tr:Stop(0)
                    end)
                end
            end
        end
    end
    stopOn(animator)
    stopOn(hum)
end

local function clearAnimHooks()
    for _, c in ipairs(animHooks) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(animHooks)
end

local function hookAnimSuppress(char)
    clearAnimHooks()
    if not char then
        return
    end
    local hum = getHumanoid(char)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then
        pcall(function()
            animator = Instance.new("Animator")
            animator.Parent = hum
        end)
        animator = hum and hum:FindFirstChildOfClass("Animator")
    end
    local function onPlayed(track)
        if not (STATE.killAura or STATE.farm or STATE.fastFarm) then
            return
        end
        if isAttackAnimTrack(track) then
            pcall(function()
                track:Stop(0)
            end)
        end
    end
    if animator then
        local c = animator.AnimationPlayed:Connect(onPlayed)
        table.insert(animHooks, c)
        track(c)
    end
    if hum then
        local ok, c2 = pcall(function()
            return hum.AnimationPlayed:Connect(onPlayed)
        end)
        if ok and c2 then
            table.insert(animHooks, c2)
            track(c2)
        end
    end
end

local function equipMeleeTool()
    local c, h = localChar(), localHum()
    if not (c and h) then
        return nil
    end
    local held = c:FindFirstChildOfClass("Tool")
    if held then
        local tip = ""
        pcall(function()
            tip = tostring(held.ToolTip or "")
        end)
        if tip == "Melee" then
            return held
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then
        return held
    end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local tip = ""
            pcall(function()
                tip = tostring(t.ToolTip or "")
            end)
            if tip == "Melee" then
                pcall(function()
                    h:EquipTool(t)
                end)
                return t
            end
        end
    end
    -- fallback: any non-fruit tool
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local low = string.lower(t.Name)
            if not string.find(low, "fruit", 1, true) then
                pcall(function()
                    h:EquipTool(t)
                end)
                return t
            end
        end
    end
    return held
end

local function fireCombatRemotes()
    local remotes = discoverCombatRemotes()
    for _, rem in ipairs(remotes) do
        pcall(function()
            if rem:IsA("RemoteEvent") or rem:IsA("UnreliableRemoteEvent") then
                rem:FireServer()
            elseif rem:IsA("RemoteFunction") then
                rem:InvokeServer()
            end
        end)
    end
end

local function attackOnceSilent()
    local tool = equipMeleeTool()
    if tool then
        pcall(function()
            tool:Activate()
        end)
    end
    pcall(fireCombatRemotes)
    local now = os.clock()
    if now - lastClick > 0.08 then
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
    -- suppress swing visuals immediately
    stopAttackTracks()
    task.defer(stopAttackTracks)
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

-- ── Mob Pull (client-owned) ─────────────────────────────────────────────────

local function isNetOwner(part)
    if not part then
        return false
    end
    local ok, owner = pcall(function()
        if typeof(isnetworkowner) == "function" then
            return isnetworkowner(part)
        end
        return false
    end)
    return ok and owner == true
end

local function pullNearbyMobs(center, range)
    if not STATE.mobPull or not center then
        return
    end
    local myRoot = localRoot()
    if not myRoot then
        return
    end
    for _, enemy in ipairs(iterEnemyModels()) do
        local hrp = getHRP(enemy)
        if hrp and isNetOwner(hrp) then
            local d = (hrp.Position - center).Magnitude
            if d <= (range or 60) and d > 6 then
                local away = flat(myRoot.Position - hrp.Position)
                away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
                local spot = myRoot.Position + away * 5 + Vector3.new(0, 1, 0)
                pcall(function()
                    hrp.CFrame = CFrame.new(spot)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end
    end
end

-- ── Auto Buso ───────────────────────────────────────────────────────────────

local function tryAutoBuso()
    if not STATE.autoBuso then
        return
    end
    if os.clock() - lastBusoTry < 2.5 then
        return
    end
    local char = localChar()
    if not char then
        return
    end
    if char:FindFirstChild("HasBuso") then
        return
    end
    lastBusoTry = os.clock()
    local ok = invokeComm("Buso")
    if not ok then
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
            end
        end)
        ringPush("Buso key J fallback")
    end
end

-- ── Kill Aura ───────────────────────────────────────────────────────────────

local function killAuraTick()
    if not STATE.killAura and not STATE.farm then
        return
    end
    local range = math.clamp(tonumber(STATE.kaRange) or 22, 5, 60)
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
    if STATE.mobPull then
        pullNearbyMobs(tg.root.Position, range + 25)
    end
    watchKill(tg)
    attackOnceSilent()
end

-- ── Quests (Sea 1) ──────────────────────────────────────────────────────────

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
    pcall(tryAutoBuso)
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
    if STATE.mobPull then
        pullNearbyMobs(spot, 50)
    end
    local rate = math.clamp(tonumber(STATE.kaRate) or 6, 1, 14)
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
        attackOnceSilent()
        task.wait(1 / rate)
    end
end

local function applyFastFarm(on)
    STATE.fastFarm = on
    if on then
        STATE.farm = true
        STATE.autoQuest = true
        STATE.killAura = true
        STATE.autoBuso = true
        ST.farm = "FAST FARM"
        ringPush("FAST FARM ON")
        notify("DXLTA", "FAST FARM an — Farm+Quest+Aura+Buso", 3)
        hookAnimSuppress(localChar())
    else
        STATE.farm = false
        STATE.autoQuest = false
        STATE.killAura = false
        -- keep autoBuso as user left it unless it was only via fast — turn off with master
        STATE.autoBuso = false
        pin = nil
        stopTravel()
        ST.farm = "idle"
        ringPush("FAST FARM OFF")
    end
end

-- ── UI helpers ──────────────────────────────────────────────────────────────

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

-- Mobile-first: ~92% width, ~78% max height, centered
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.78, 0)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = COLORS.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.limeDim
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 18)),
})
panelGrad.Rotation = 110
panelGrad.Parent = panel

-- Header bar (compact — brand lives on Start tab)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = COLORS.bg
header.BorderSizePixel = 0
header.Parent = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 16)
headerFix.Position = UDim2.new(0, 0, 1, -16)
headerFix.BackgroundColor3 = COLORS.bg
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local headerBrand = Instance.new("TextLabel")
headerBrand.BackgroundTransparency = 1
headerBrand.Position = UDim2.fromOffset(14, 8)
headerBrand.Size = UDim2.new(1, -70, 0, 28)
headerBrand.Font = Enum.Font.GothamBlack
headerBrand.TextSize = 18
headerBrand.TextXAlignment = Enum.TextXAlignment.Left
headerBrand.TextColor3 = COLORS.lime
headerBrand.Text = "DXLTA"
headerBrand.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(36, 32)
closeBtn.Position = UDim2.new(1, -46, 0, 6)
closeBtn.BackgroundColor3 = COLORS.panelAlt
closeBtn.TextColor3 = COLORS.danger
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Text = "×"
closeBtn.AutoButtonColor = true
closeBtn.Parent = header
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = closeBtn
end

-- Bottom category tabs
local TAB_H = 54
local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Size = UDim2.new(1, 0, 0, TAB_H)
tabBar.Position = UDim2.new(0, 0, 1, -TAB_H)
tabBar.BackgroundColor3 = COLORS.bg
tabBar.BorderSizePixel = 0
tabBar.Parent = panel

local tabBarTop = Instance.new("Frame")
tabBarTop.Size = UDim2.new(1, 0, 0, 12)
tabBarTop.BackgroundColor3 = COLORS.bg
tabBarTop.BorderSizePixel = 0
tabBarTop.Parent = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 6)
tabPad.PaddingRight = UDim.new(0, 6)
tabPad.PaddingBottom = UDim.new(0, 4)
tabPad.Parent = tabBar

local contentHost = Instance.new("Frame")
contentHost.Name = "Content"
contentHost.Size = UDim2.new(1, -12, 1, -(44 + TAB_H + 8))
contentHost.Position = UDim2.fromOffset(6, 48)
contentHost.BackgroundTransparency = 1
contentHost.ClipsDescendants = true
contentHost.Parent = panel

local TABS = {
    { id = "Start", label = "Start" },
    { id = "Farm", label = "Farm" },
    { id = "Kampf", label = "Kampf" },
    { id = "ESP", label = "ESP" },
    { id = "Scout", label = "Scout" },
}

local function switchTab(id)
    currentTab = id
    for name, page in pairs(tabPages) do
        local show = name == id
        page.Visible = show
        if show then
            page.CanvasPosition = Vector2.zero
            -- soft fade-in (GroupTransparency when available)
            pcall(function()
                page.GroupTransparency = 0.35
                task.spawn(function()
                    for i = 1, 6 do
                        if page.Visible then
                            pcall(function()
                                page.GroupTransparency = math.max(0, 0.35 - i * 0.06)
                            end)
                            task.wait(0.016)
                        end
                    end
                    pcall(function()
                        page.GroupTransparency = 0
                    end)
                end)
            end)
        end
    end
    for name, btn in pairs(tabButtons) do
        if name == id then
            btn.BackgroundColor3 = COLORS.lime
            btn.TextColor3 = COLORS.ink
        else
            btn.BackgroundColor3 = COLORS.panelAlt
            btn.TextColor3 = COLORS.muted
        end
    end
end

for i, meta in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. meta.id
    btn.Size = UDim2.new(0.19, 0, 0, 42)
    btn.BackgroundColor3 = COLORS.panelAlt
    btn.TextColor3 = COLORS.muted
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Text = meta.label
    btn.AutoButtonColor = true
    btn.LayoutOrder = i
    btn.Parent = tabBar
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = btn
    end
    tabButtons[meta.id] = btn
    btn.MouseButton1Click:Connect(function()
        switchTab(meta.id)
    end)

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. meta.id
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = COLORS.limeDim
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = contentHost

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 8)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)
    pad.Parent = page

    tabPages[meta.id] = page
end

local orderN = {}
local function nextOrder(tab)
    orderN[tab] = (orderN[tab] or 0) + 1
    return orderN[tab]
end

local function parentOf(tab)
    return tabPages[tab]
end

local function sectionLabel(tab, text)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = COLORS.limeSoft
    lbl.Text = text
    lbl.LayoutOrder = nextOrder(tab)
    lbl.Parent = parentOf(tab)
    return lbl
end

local function makeToggle(tab, label, key, onChange, opts)
    opts = opts or {}
    local h = opts.giant and 64 or 48
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, h)
    row.BackgroundColor3 = opts.giant and Color3.fromRGB(28, 40, 22) or COLORS.panelAlt
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder(tab)
    row.Parent = parentOf(tab)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    if opts.giant then
        local stroke = Instance.new("UIStroke")
        stroke.Color = COLORS.limeDim
        stroke.Thickness = 1.5
        stroke.Parent = row
    end

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(14, 0)
    text.Size = UDim2.new(1, -90, 1, 0)
    text.Font = opts.giant and Enum.Font.GothamBlack or Enum.Font.GothamMedium
    text.TextSize = opts.giant and 18 or 14
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextColor3 = COLORS.text
    text.Text = label
    text.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(opts.giant and 72 or 58, opts.giant and 36 or 30)
    btn.Position = UDim2.new(1, opts.giant and -84 or -70, 0.5, opts.giant and -18 or -15)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = opts.giant and 14 or 13
    btn.AutoButtonColor = true
    btn.Parent = row
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = btn
    end

    local function paint()
        if STATE[key] then
            btn.BackgroundColor3 = COLORS.lime
            btn.TextColor3 = COLORS.ink
            btn.Text = "AN"
            if opts.giant then
                row.BackgroundColor3 = Color3.fromRGB(36, 55, 22)
            end
        else
            btn.BackgroundColor3 = COLORS.border
            btn.TextColor3 = COLORS.muted
            btn.Text = "AUS"
            if opts.giant then
                row.BackgroundColor3 = Color3.fromRGB(28, 40, 22)
            end
        end
    end
    paint()

    local function toggle()
        STATE[key] = not STATE[key]
        paint()
        if onChange then
            safeCall(onChange, STATE[key])
        end
    end

    btn.MouseButton1Click:Connect(toggle)
    -- whole row touchable
    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.new(1, -90, 1, 0)
    hit.Text = ""
    hit.ZIndex = 2
    hit.Parent = row
    hit.MouseButton1Click:Connect(toggle)

    return {
        paint = paint,
        set = function(v)
            STATE[key] = v and true or false
            paint()
        end,
    }
end

local function makeSlider(tab, label, key, minV, maxV)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = COLORS.panelAlt
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder(tab)
    row.Parent = parentOf(tab)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local lab = Instance.new("TextLabel")
    lab.BackgroundTransparency = 1
    lab.Position = UDim2.fromOffset(14, 6)
    lab.Size = UDim2.new(1, -28, 0, 18)
    lab.Font = Enum.Font.Gotham
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.TextColor3 = COLORS.text
    lab.Text = label .. ": " .. tostring(STATE[key])
    lab.Parent = row

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(14, 32)
    bar.Size = UDim2.new(1, -28, 0, 14)
    bar.BackgroundColor3 = COLORS.border
    bar.BorderSizePixel = 0
    bar.Parent = row
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 7)
        c.Parent = bar
    end

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((STATE[key] - minV) / math.max(maxV - minV, 1), 0, 1, 0)
    fill.BackgroundColor3 = COLORS.lime
    fill.BorderSizePixel = 0
    fill.Parent = bar
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 7)
        c.Parent = fill
    end

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

local function makeLive(tab, title, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.LayoutOrder = nextOrder(tab)
    row.Parent = parentOf(tab)

    local left = Instance.new("TextLabel")
    left.BackgroundTransparency = 1
    left.Size = UDim2.new(0.4, 0, 1, 0)
    left.Font = Enum.Font.Gotham
    left.TextSize = 12
    left.TextXAlignment = Enum.TextXAlignment.Left
    left.TextColor3 = COLORS.muted
    left.Text = title
    left.Parent = row

    local val = Instance.new("TextLabel")
    val.BackgroundTransparency = 1
    val.Position = UDim2.new(0.4, 0, 0, 0)
    val.Size = UDim2.new(0.6, 0, 1, 0)
    val.Font = Enum.Font.Code
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.TextColor3 = COLORS.lime
    val.TextTruncate = Enum.TextTruncate.AtEnd
    val.Text = "—"
    val.Parent = row
    liveLabels[key] = val
end

local function makeButton(tab, label, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.BackgroundColor3 = color or COLORS.lime
    btn.TextColor3 = COLORS.ink
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = label
    btn.AutoButtonColor = true
    btn.LayoutOrder = nextOrder(tab)
    btn.Parent = parentOf(tab)
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = btn
    end
    btn.MouseButton1Click:Connect(function()
        safeCall(onClick)
    end)
    return btn
end

local function makeTip(tab, text, h)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundColor3 = COLORS.bg
    lbl.Size = UDim2.new(1, 0, 0, h or 44)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextColor3 = COLORS.muted
    lbl.TextWrapped = true
    lbl.Text = "  " .. text
    lbl.LayoutOrder = nextOrder(tab)
    lbl.Parent = parentOf(tab)
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = lbl
    end
    return lbl
end

-- Keep refs to sync paints when Fast Farm flips slaves
local farmToggleUI, questToggleUI, auraToggleUI, busoToggleUI, fastToggleUI

-- ═══ START TAB ══════════════════════════════════════════════════════════════

do
    local hero = Instance.new("TextLabel")
    hero.BackgroundTransparency = 1
    hero.Size = UDim2.new(1, 0, 0, 52)
    hero.Font = Enum.Font.GothamBlack
    hero.TextSize = 42
    hero.TextXAlignment = Enum.TextXAlignment.Left
    hero.TextColor3 = COLORS.lime
    hero.Text = "DXLTA"
    hero.LayoutOrder = nextOrder("Start")
    hero.Parent = parentOf("Start")

    local tagline = Instance.new("TextLabel")
    tagline.BackgroundTransparency = 1
    tagline.Size = UDim2.new(1, 0, 0, 22)
    tagline.Font = Enum.Font.Gotham
    tagline.TextSize = 14
    tagline.TextXAlignment = Enum.TextXAlignment.Left
    tagline.TextColor3 = COLORS.text
    tagline.Text = "Nur Blox Fruits · ein Toggle farmt"
    tagline.LayoutOrder = nextOrder("Start")
    tagline.Parent = parentOf("Start")

    fastToggleUI = makeToggle("Start", "FAST FARM", "fastFarm", function(on)
        applyFastFarm(on)
        if farmToggleUI then farmToggleUI.paint() end
        if questToggleUI then questToggleUI.paint() end
        if auraToggleUI then auraToggleUI.paint() end
        if busoToggleUI then busoToggleUI.paint() end
    end, { giant = true })

    makeTip("Start", "Spiel 1–2 Min → Clipboard hier pasten (Auto-Scout kopiert alle 3s).", 48)

    sectionLabel("Start", "LIVE STATUS")
    makeLive("Start", "Level", "level")
    makeLive("Start", "Kills", "kills")
    makeLive("Start", "State", "farm")
    makeLive("Start", "Nearest", "nearest")
    makeLive("Start", "Last Scout Copy", "lastScoutCopy")
    makeLive("Start", "Busy / Stun", "busy")
    makeLive("Start", "HasBuso", "buso")

    makeTip("Start", "RightShift = Panel · Lime-Orb unten rechts = wieder öffnen", 40)
end

-- ═══ FARM TAB ═══════════════════════════════════════════════════════════════

farmToggleUI = makeToggle("Farm", "Auto Farm / Auto Level", "farm", function(on)
    if not on then
        pin = nil
        stopTravel()
        ST.farm = "idle"
        ringPush("farm OFF")
        if STATE.fastFarm then
            STATE.fastFarm = false
            if fastToggleUI then fastToggleUI.paint() end
        end
    else
        ST.farm = "starting"
        ringPush("farm ON")
        hookAnimSuppress(localChar())
    end
end)

questToggleUI = makeToggle("Farm", "Auto Quest (CommF_ / Prompt)", "autoQuest", function(on)
    ringPush(on and "auto quest ON" or "auto quest OFF")
end)

busoToggleUI = makeToggle("Farm", "Auto Buso (J / CommF_)", "autoBuso", function(on)
    ringPush(on and "auto buso ON" or "auto buso OFF")
    if on then
        tryAutoBuso()
    end
end)

makeToggle("Farm", "Mob Pull (network owner)", "mobPull", function(on)
    ringPush(on and "mob pull ON" or "mob pull OFF")
end)

makeSlider("Farm", "Tween / Farm speed", "bfSpeed", 50, 300)
makeTip("Farm", "Tween nur intern zum Mob — kein freies Fly.", 36)

-- ═══ KAMPF TAB ══════════════════════════════════════════════════════════════

auraToggleUI = makeToggle("Kampf", "Kill Aura (Silent M1)", "killAura", function(on)
    lastAuraNear = nil
    ringPush(on and "kill aura ON" or "kill aura OFF")
    if on then
        hookAnimSuppress(localChar())
    end
    if not on and STATE.fastFarm then
        STATE.fastFarm = false
        if fastToggleUI then fastToggleUI.paint() end
    end
end)

makeSlider("Kampf", "Aura range", "kaRange", 5, 60)
makeSlider("Kampf", "Attack rate", "kaRate", 1, 14)
makeTip("Kampf", "Melee equip · face target · Activate · Attack-Anims gestoppt. Steht still-ish am Farm-Pin.", 56)

-- ═══ ESP TAB ════════════════════════════════════════════════════════════════

makeToggle("ESP", "Gegner ESP (Enemies)", "enemyEsp", function(on)
    if not on then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
    else
        refreshEnemyEsp()
    end
end)

makeToggle("ESP", "NPC ESP (optional)", "npcEsp", function(on)
    if not on then
        for model in pairs(npcEspMap) do
            clearEspOn(model)
        end
        npcEspMap = {}
    else
        refreshNpcEsp()
    end
end)

makeToggle("ESP", "Spieler ESP (optional)", "playerEsp", function(on)
    if not on then
        for model in pairs(playerEspMap) do
            clearEspOn(model)
        end
        playerEspMap = {}
    else
        refreshPlayerEsp()
    end
end)

-- ═══ SCOUT TAB ══════════════════════════════════════════════════════════════

makeToggle("Scout", "Auto-Copy Scout (3s)", "scoutAutoCopy", function(on)
    ringPush(on and "scout auto-copy ON" or "scout auto-copy OFF")
    if on then
        doAutoCopyScout()
    end
end)

makeTip("Scout", "Alle 3s: Farm-State, nearest, CommF_, Remotes, Busy/Stun, Level, PlaceId → Clipboard.", 52)

scoutFilterBox = Instance.new("TextBox")
scoutFilterBox.Name = "ScoutFilter"
scoutFilterBox.PlaceholderText = "Filter: Remote, CommF, Modules.Net…"
scoutFilterBox.Text = ""
scoutFilterBox.ClearTextOnFocus = false
scoutFilterBox.Size = UDim2.new(1, 0, 0, 40)
scoutFilterBox.BackgroundColor3 = COLORS.bg
scoutFilterBox.TextColor3 = COLORS.text
scoutFilterBox.PlaceholderColor3 = COLORS.muted
scoutFilterBox.Font = Enum.Font.Code
scoutFilterBox.TextSize = 13
scoutFilterBox.TextXAlignment = Enum.TextXAlignment.Left
scoutFilterBox.LayoutOrder = nextOrder("Scout")
scoutFilterBox.Parent = parentOf("Scout")
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = scoutFilterBox
    local s = Instance.new("UIStroke")
    s.Color = COLORS.border
    s.Thickness = 1
    s.Parent = scoutFilterBox
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = scoutFilterBox
end

scoutStatusLbl = Instance.new("TextLabel")
scoutStatusLbl.BackgroundTransparency = 1
scoutStatusLbl.Size = UDim2.new(1, 0, 0, 18)
scoutStatusLbl.Font = Enum.Font.Gotham
scoutStatusLbl.TextSize = 12
scoutStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
scoutStatusLbl.TextColor3 = COLORS.muted
scoutStatusLbl.Text = "Scout bereit · Auto-Copy AN"
scoutStatusLbl.LayoutOrder = nextOrder("Scout")
scoutStatusLbl.Parent = parentOf("Scout")

setScoutStatus = function(msg, ok)
    scoutStatusLbl.Text = tostring(msg)
    if ok == true then
        scoutStatusLbl.TextColor3 = COLORS.lime
    elseif ok == false then
        scoutStatusLbl.TextColor3 = COLORS.danger
    else
        scoutStatusLbl.TextColor3 = COLORS.muted
    end
end

local scoutPreviewWrap = Instance.new("Frame")
scoutPreviewWrap.Size = UDim2.new(1, 0, 0, 140)
scoutPreviewWrap.BackgroundColor3 = COLORS.bg
scoutPreviewWrap.BorderSizePixel = 0
scoutPreviewWrap.LayoutOrder = nextOrder("Scout")
scoutPreviewWrap.Parent = parentOf("Scout")
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
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
scoutScroll.ScrollBarThickness = 3
scoutScroll.ScrollBarImageColor3 = COLORS.limeDim
scoutScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scoutScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scoutScroll.Parent = scoutPreviewWrap

scoutPreviewLbl = Instance.new("TextLabel")
scoutPreviewLbl.BackgroundTransparency = 1
scoutPreviewLbl.Size = UDim2.new(1, -6, 0, 0)
scoutPreviewLbl.Position = UDim2.fromOffset(2, 0)
scoutPreviewLbl.AutomaticSize = Enum.AutomaticSize.Y
scoutPreviewLbl.Font = Enum.Font.Code
scoutPreviewLbl.TextSize = 10
scoutPreviewLbl.TextXAlignment = Enum.TextXAlignment.Left
scoutPreviewLbl.TextYAlignment = Enum.TextYAlignment.Top
scoutPreviewLbl.TextColor3 = COLORS.muted
scoutPreviewLbl.TextWrapped = true
scoutPreviewLbl.Text = "(noch kein dump — SCAN Explorer)"
scoutPreviewLbl.Parent = scoutScroll

local function setScoutPreview(text)
    local t = tostring(text or "")
    if #t > 3500 then
        scoutPreviewLbl.Text = t:sub(1, 3500) .. "\n… (UI truncated — COPY Dump = full)"
    else
        scoutPreviewLbl.Text = t ~= "" and t or "(leer)"
    end
end

local function filteredDumpView()
    local terms = parseFilterTerms(scoutFilterBox.Text)
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

makeButton("Scout", "SCAN Explorer", COLORS.lime, function()
    setScoutStatus("Scanning…", nil)
    task.wait()
    local view, filteredLines, total = runScoutScan(scoutFilterBox.Text)
    setScoutPreview(view)
    setScoutStatus(string.format("Scan · %d Zeilen · Ansicht %d", total, #filteredLines), true)
    ringPush("scout scan " .. tostring(total) .. " lines")
end)

makeButton("Scout", "COPY Dump", COLORS.limeSoft, function()
    if lastDumpText == "" then
        setScoutStatus("Nichts zu kopieren — erst SCAN", false)
        return
    end
    local text = filteredDumpView()
    if text == "" then
        text = lastDumpText
    end
    if copyClip(text) then
        ST.lastScoutCopy = os.date("%H:%M:%S")
        setScoutStatus("Dump kopiert @ " .. ST.lastScoutCopy, true)
        notify("DXLTA", "Dump kopiert — hier pasten", 3)
    else
        setScoutStatus("Clipboard unavailable", false)
    end
end)

makeButton("Scout", "COPY Logs", Color3.fromRGB(120, 180, 70), function()
    if copyClip(ringText()) then
        setScoutStatus("Logs kopiert (" .. tostring(#ringLog) .. ")", true)
        notify("DXLTA", "Logs kopiert", 2)
    else
        setScoutStatus("Clipboard unavailable", false)
    end
end)

makeButton("Scout", "COPY Status", Color3.fromRGB(90, 140, 60), function()
    local line = statusOneLiner()
    if copyClip(line) then
        setScoutStatus("Status: " .. line, true)
        notify("DXLTA", "Status kopiert", 2)
    else
        setScoutStatus("Clipboard unavailable", false)
    end
end)

scoutFilterBox:GetPropertyChangedSignal("Text"):Connect(function()
    if lastDumpText ~= "" then
        setScoutPreview(filteredDumpView())
    end
end)

switchTab("Start")

-- ── Reopen orb ──────────────────────────────────────────────────────────────

local orb = Instance.new("ScreenGui")
orb.Name = ORB_NAME
orb.ResetOnSpawn = false
orb.IgnoreGuiInset = true
orb.DisplayOrder = 1001
orb.Enabled = false
orb.Parent = guiParent

local orbBtn = Instance.new("TextButton")
orbBtn.Name = "Orb"
orbBtn.Size = UDim2.fromOffset(52, 52)
orbBtn.Position = UDim2.new(1, -72, 1, -72)
orbBtn.BackgroundColor3 = COLORS.lime
orbBtn.TextColor3 = COLORS.ink
orbBtn.Font = Enum.Font.GothamBlack
orbBtn.TextSize = 15
orbBtn.Text = "DX"
orbBtn.AutoButtonColor = true
orbBtn.Parent = orb
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = orbBtn
    local s = Instance.new("UIStroke")
    s.Color = COLORS.limeDim
    s.Thickness = 2
    s.Parent = orbBtn
end

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

-- Drag panel by header
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
    if gp then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setPanelVisible(not STATE.panelVisible)
    end
end))

-- Heartbeat: farm pin hold
track(RunService.Heartbeat:Connect(function()
    if not alive then
        return
    end
    pcall(function()
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
        if STATE.killAura or STATE.farm then
            stopAttackTracks()
        end
    end)
end))

-- Silent aura rate loop
task.spawn(function()
    while alive do
        local rate = math.clamp(tonumber(STATE.kaRate) or 6, 1, 14)
        task.wait(1 / rate)
        pcall(killAuraTick)
    end
end)

-- Farm loop
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
        elseif STATE.autoBuso then
            pcall(tryAutoBuso)
        end
    end
end)

-- Scout auto-copy every 3s + background logger
task.spawn(function()
    while alive do
        task.wait(3)
        pcall(function()
            refreshStatus()
            local tg = findNearestEnemy(400, nil)
            if tg then
                -- keep nearest fresh in ring occasionally
            end
            discoverCombatRemotes()
            if STATE.scoutAutoCopy then
                doAutoCopyScout()
            end
        end)
    end
end)

-- Status + ESP refresh
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
            liveLabels.busy.Text = tostring(ST.busy) .. " / " .. tostring(ST.stun)
        end
        if liveLabels.buso then
            liveLabels.buso.Text = tostring(ST.buso)
        end
        if liveLabels.level then
            liveLabels.level.Text = tostring(ST.level)
        end
        if liveLabels.lastScoutCopy then
            liveLabels.lastScoutCopy.Text = tostring(ST.lastScoutCopy)
        end
    end)
end))

track(LocalPlayer.CharacterAdded:Connect(function(char)
    pin = nil
    task.wait(0.4)
    hookAnimSuppress(char)
    if STATE.autoBuso then
        tryAutoBuso()
    end
end))

if LocalPlayer.Character then
    hookAnimSuppress(LocalPlayer.Character)
end

task.defer(function()
    pcall(discoverCombatRemotes)
    pcall(countNetRemotes)
    if STATE.scoutAutoCopy then
        doAutoCopyScout()
    end
end)

function HUB.unload()
    alive = false
    stopTravel()
    pin = nil
    clearAnimHooks()
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

notify("DXLTA", "BF Panel v2 · RightShift · FAST FARM", 4)
print("[DXLTA] BF Panel ready — panel.lua v2 mobile loaded")

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
