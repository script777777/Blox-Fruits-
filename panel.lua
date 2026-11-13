--[[
    DXLTA Blox Fruits — Hub Panel v3.0
    Sidebar + cards · FAST FARM · Stream travel · Silent Aura · Client dump

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/bf-panel-ff0d/panel.lua"))()

    − = minimize (LEFT D orb)  ·  × = unload  ·  RightShift = toggle
    Locked combat: RegisterAttack(0.5) → RegisterHit(Humanoid)
]]

print("[DXLTA] BF Panel boot… v3.0")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__DXLTA_BF_PANEL and type(ENV.__DXLTA_BF_PANEL.unload) == "function" then
    pcall(ENV.__DXLTA_BF_PANEL.unload)
end
ENV.__DXLTA_BF_PANEL = { version = "3.0" }
local HUB = ENV.__DXLTA_BF_PANEL

local okBoot, bootErr = xpcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local Stats = game:GetService("Stats")
local VirtualInputManager
local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Soft lime / charcoal — professional, not neon
local COLORS = {
    bg = Color3.fromRGB(22, 24, 28),
    panel = Color3.fromRGB(28, 30, 34),
    card = Color3.fromRGB(34, 37, 42),
    cardAlt = Color3.fromRGB(38, 42, 48),
    sidebar = Color3.fromRGB(18, 20, 24),
    ink = Color3.fromRGB(42, 46, 52),
    text = Color3.fromRGB(235, 238, 242),
    muted = Color3.fromRGB(130, 138, 148),
    lime = Color3.fromRGB(150, 210, 90),
    limeDim = Color3.fromRGB(90, 140, 55),
    limeSoft = Color3.fromRGB(170, 210, 120),
    limeOn = Color3.fromRGB(40, 56, 36),
    danger = Color3.fromRGB(220, 90, 90),
    enemy = Color3.fromRGB(230, 140, 90),
    npc = Color3.fromRGB(120, 180, 220),
    player = Color3.fromRGB(180, 150, 220),
    black = Color3.fromRGB(12, 14, 16),
    stroke = Color3.fromRGB(55, 60, 68),
}

local STATE = {
    farm = false,
    autoQuest = false,
    killAura = false,
    mobPull = false,
    autoBuso = false,
    fastFarm = false,
    kaRange = 22,
    kaRate = 8,
    bfSpeed = 240,
    enemyEsp = false,
    npcEsp = false,
    playerEsp = false,
    autoCopyAll = true,
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
    lastCopy = "—",
    fps = "—",
    ping = "—",
    session = "00:00",
}

local ESP_FOLDER_NAME = "DXLTA_ESP"
local GUI_NAME = "DXLTA_BF_Panel"
local ORB_NAME = "DXLTA_BF_Orb"
local SIDEBAR_W = 148
local MOBILE_BREAK = 700
local PIN_DIST = 8
local VERSION = "3.0"

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
local lastCancelEquip = 0
local killWatch = setmetatable({}, { __mode = "k" })
local animHooks = {}
local discoveredRemotes = {}
local noclipRestore = {}
local farmCurrentName = nil
local lastStreamAt = 0
local farmBusy = false
local lastAttackAt = 0
local sessionStart = os.clock()
local fpsAccum, fpsFrames, fpsValue = 0, 0, 0

local combatLocked = {
    attackArg = 0.5,
    hitKind = "hum",
    useRemotes = true,
}

local RING_MAX = 100
local ringLog = {}
local errorRing = {}
local lastDumpText = ""
local lastDumpLines = {}

local liveLabels = {}
local tabPages = {}
local tabButtons = {}
local currentTab = "Home"
local pageTitleLbl
local clientStatusLbl
local setClientStatus
local togglePainters = {}
local rememberRemote
local mobileMode = false
local sidebarFrame
local contentFrame
local navScroll
local brandBlock
local panelRoot

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

local function getRemotesFolder()
    return ReplicatedStorage:FindFirstChild("Remotes")
end

local function findCommF()
    local remotes = getRemotesFolder()
    local f = remotes and remotes:FindFirstChild("CommF_")
    if f and (f:IsA("RemoteFunction") or f.ClassName == "RemoteFunction") then
        return f
    end
    f = remotes and remotes:FindFirstChild("CommF")
    if f and (f:IsA("RemoteFunction") or f.ClassName == "RemoteFunction") then
        return f
    end
    return nil
end

local function findRemoteByName(folder, name)
    if not folder then
        return nil
    end
    local direct = folder:FindFirstChild(name)
    if direct then
        return direct
    end
    local ok, kids = pcall(function()
        return folder:GetChildren()
    end)
    if not ok or not kids then
        return nil
    end
    local want = string.lower(name)
    for _, c in ipairs(kids) do
        local n = string.lower(c.Name)
        if n == want or n == "re/" .. want or string.find(n, want, 1, true) then
            return c
        end
    end
    return nil
end

-- HARDCODED locked combat remotes (proven dumps)
local function getRegisterAttack()
    local net = getNetFolder()
    if net then
        local r = net:FindFirstChild("RE/RegisterAttack") or net["RE/RegisterAttack"]
        if r then
            return r
        end
    end
    return findRemoteByName(getNetFolder(), "RE/RegisterAttack")
        or findRemoteByName(getNetFolder(), "RegisterAttack")
end

local function getRegisterHit()
    local net = getNetFolder()
    if net then
        local r = net:FindFirstChild("RE/RegisterHit") or net["RE/RegisterHit"]
        if r then
            return r
        end
    end
    return findRemoteByName(getNetFolder(), "RE/RegisterHit")
        or findRemoteByName(getNetFolder(), "RegisterHit")
end

local function getCancelEquipAnim()
    return findRemoteByName(getNetFolder(), "RE/CancelEquipAnim")
        or findRemoteByName(getNetFolder(), "CancelEquipAnim")
end

local function getBestQuestNPCRemote()
    local remotes = getRemotesFolder()
    return remotes and remotes:FindFirstChild("GetBestQuestNPC")
end

local function findStreamRemote()
    local remotes = getRemotesFolder()
    local r = remotes and (remotes:FindFirstChild("RequestStreamAroundAsync") or remotes:FindFirstChild("RequestStreamAround"))
    if r then
        return r
    end
    local net = getNetFolder()
    r = findRemoteByName(net, "RequestStreamAroundAsync") or findRemoteByName(net, "RequestStreamAround")
    if r then
        return r
    end
    local roots = { ReplicatedStorage, Workspace }
    for _, root in ipairs(roots) do
        local ok, found = pcall(function()
            return root:FindFirstChild("RequestStreamAroundAsync", true)
        end)
        if ok and found then
            return found
        end
    end
    return nil
end

local function requestStreamAround(pos)
    if typeof(pos) ~= "Vector3" then
        return false
    end
    local now = os.clock()
    if now - lastStreamAt < 0.45 then
        return false
    end
    lastStreamAt = now

    local okAny = false
    pcall(function()
        if LocalPlayer and type(LocalPlayer.RequestStreamAroundAsync) == "function" then
            LocalPlayer:RequestStreamAroundAsync(pos)
            okAny = true
        end
    end)

    local rem = findStreamRemote()
    if rem then
        rememberRemote(rem)
        pcall(function()
            if rem:IsA("RemoteEvent") or rem.ClassName == "RemoteEvent" or rem.ClassName == "UnreliableRemoteEvent" then
                rem:FireServer(pos)
                rem:FireServer(CFrame.new(pos))
                okAny = true
            elseif rem:IsA("RemoteFunction") or rem.ClassName == "RemoteFunction" then
                rem:InvokeServer(pos)
                okAny = true
            end
        end)
    end
    return okAny
end

local function ringPush(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
    table.insert(ringLog, line)
    while #ringLog > RING_MAX do
        table.remove(ringLog, 1)
    end
end

local function errorPush(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
    table.insert(errorRing, line)
    while #errorRing > RING_MAX do
        table.remove(errorRing, 1)
    end
    ringPush("ERR " .. tostring(msg):sub(1, 90))
end

local function ringText(limit)
    if #ringLog == 0 then
        return "(no logs — start farm/quest/aura)"
    end
    if limit and #ringLog > limit then
        local slice = {}
        for i = #ringLog - limit + 1, #ringLog do
            table.insert(slice, ringLog[i])
        end
        return table.concat(slice, "\n")
    end
    return table.concat(ringLog, "\n")
end

local function errorText()
    if #errorRing == 0 then
        return "(no errors)"
    end
    return table.concat(errorRing, "\n")
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
        errorPush("CommF_ " .. label .. " → " .. brief)
    end
    return ok, res
end

rememberRemote = function(inst)
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
                    or string.find(n, "stream", 1, true)
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

-- ── Status / metrics ────────────────────────────────────────────────────────

local function formatSession(sec)
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec % 60
    if m >= 60 then
        local h = math.floor(m / 60)
        m = m % 60
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

local function readPing()
    local ping = nil
    pcall(function()
        if LocalPlayer and type(LocalPlayer.GetNetworkPing) == "function" then
            ping = LocalPlayer:GetNetworkPing()
        end
    end)
    if type(ping) == "number" then
        -- GetNetworkPing returns seconds
        if ping < 5 then
            return string.format("%dms", math.floor(ping * 1000 + 0.5))
        end
        return string.format("%dms", math.floor(ping + 0.5))
    end
    pcall(function()
        local net = Stats:FindFirstChild("Network")
        local serverStats = net and net:FindFirstChild("ServerStatsItem")
        local item = serverStats and (serverStats:FindFirstChild("Data Ping") or serverStats:FindFirstChild("Ping"))
        if item and item.GetValueString then
            ping = item:GetValueString()
        end
    end)
    if type(ping) == "string" and ping ~= "" then
        return ping
    end
    return "—"
end

local function readMem()
    local mb = nil
    pcall(function()
        if Stats and type(Stats.GetTotalMemoryUsageMb) == "function" then
            mb = Stats:GetTotalMemoryUsageMb()
        end
    end)
    if type(mb) == "number" then
        return string.format("%.0f MB", mb)
    end
    return "—"
end

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
            ST.busy = busyVal.Value and "YES" or "NO"
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
        else
            ST.energy = "—"
        end
        ST.buso = char:FindFirstChild("HasBuso") and "YES" or "NO"
    end)
    pcall(function()
        ST.remotes = tostring(countNetRemotes())
    end)
    ST.ping = readPing()
    ST.fps = tostring(math.floor(fpsValue + 0.5))
    ST.session = formatSession(os.clock() - sessionStart)
    if not STATE.farm and not STATE.killAura then
        local tg, d = findNearestEnemy(nil, nil)
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

local function detectExecutor()
    if type(identifyexecutor) == "function" then
        local ok, res = pcall(identifyexecutor)
        if ok and res then
            return tostring(res)
        end
    end
    if type(getexecutorname) == "function" then
        local ok, res = pcall(getexecutorname)
        if ok and res then
            return tostring(res)
        end
    end
    return "unknown"
end

local function statusOneLiner()
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

-- ── Client dump ─────────────────────────────────────────────────────────────

local function getFullPath(inst)
    if not inst then
        return "?"
    end
    local parts = {}
    local cur = inst
    local guard = 0
    while cur and cur ~= game and guard < 40 do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
        guard += 1
    end
    return "game." .. table.concat(parts, ".")
end

local function childSummary(parent, limit)
    limit = limit or 40
    if not parent then
        return "(nil)"
    end
    local ok, kids = pcall(function()
        return parent:GetChildren()
    end)
    if not ok or not kids then
        return "(err)"
    end
    local names = {}
    for i, c in ipairs(kids) do
        if i > limit then
            table.insert(names, "…+" .. tostring(#kids - limit))
            break
        end
        table.insert(names, string.format("%s[%s]", c.Name, c.ClassName))
    end
    return #names > 0 and table.concat(names, ", ") or "(empty)"
end

local function buildClientDump()
    local lines = {}
    table.insert(lines, "========== DXLTA CLIENT DUMP v" .. VERSION .. " ==========")
    table.insert(lines, string.format(
        "PlaceId=%s  GameId=%s  JobId=%s  Sea=%s",
        tostring(game.PlaceId),
        tostring(game.GameId),
        tostring(game.JobId),
        seaLabel()
    ))
    table.insert(lines, string.format("Player=%s  Time=%s", LocalPlayer.Name, os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, string.format(
        "Level=%s  Race=%s  DevilFruit=%s",
        tostring(dataVal("Level") or "?"),
        tostring(dataVal("Race") or "?"),
        tostring(dataVal("DevilFruit") or dataVal("Fruit") or "?")
    ))
    table.insert(lines, "Executor=" .. detectExecutor())
    table.insert(lines, "STATUS: " .. statusOneLiner())
    table.insert(lines, string.format(
        "FLAGS: farm=%s quest=%s aura=%s pull=%s buso=%s fast=%s autoCopy=%s",
        tostring(STATE.farm),
        tostring(STATE.autoQuest),
        tostring(STATE.killAura),
        tostring(STATE.mobPull),
        tostring(STATE.autoBuso),
        tostring(STATE.fastFarm),
        tostring(STATE.autoCopyAll)
    ))
    table.insert(lines, "FarmState=" .. tostring(ST.farm) .. "  Nearest=" .. tostring(ST.nearest) .. "  Kills=" .. tostring(ST.kills))
    table.insert(lines, string.format(
        "LOCKED COMBAT: RegisterAttack(%.1f) → RegisterHit(Humanoid)  useRemotes=%s",
        combatLocked.attackArg,
        tostring(combatLocked.useRemotes)
    ))
    table.insert(lines, string.format("FPS=%s  Ping=%s  Mem=%s  Session=%s", ST.fps, ST.ping, readMem(), ST.session))

    local char = localChar()
    table.insert(lines, "Character children: " .. childSummary(char, 80))
    table.insert(lines, string.format("HasBuso=%s  Busy=%s  Stun=%s  Energy=%s", tostring(ST.buso), tostring(ST.busy), tostring(ST.stun), tostring(ST.energy)))
    local eq = char and char:FindFirstChildOfClass("Tool")
    table.insert(lines, "Equipped=" .. (eq and (eq.Name .. " tip=" .. tostring(eq.ToolTip)) or "(none)"))

    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        local tools = {}
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                table.insert(tools, string.format("%s(tip=%s)", t.Name, tostring(t.ToolTip)))
            end
        end
        table.insert(lines, "Backpack tools: " .. (#tools > 0 and table.concat(tools, ", ") or "(none)"))
    end

    local ra = getRegisterAttack()
    local rh = getRegisterHit()
    table.insert(lines, string.format(
        "Combat remotes: RegisterAttack=%s  RegisterHit=%s  CommF_=%s  GetBestQuestNPC=%s  Stream=%s",
        ra and ra:GetFullName() or "MISSING",
        rh and rh:GetFullName() or "MISSING",
        findCommF() and "yes" or "MISSING",
        getBestQuestNPCRemote() and "yes" or "MISSING",
        findStreamRemote() and "yes" or "Player:RequestStreamAroundAsync"
    ))
    table.insert(lines, "Modules.Net: " .. childSummary(getNetFolder(), 80))
    table.insert(lines, "============================================")
    return table.concat(lines, "\n")
end

local function buildCombatRemotesTrim()
    local lines = {}
    table.insert(lines, "----- COMBAT REMOTES -----")
    local ra = getRegisterAttack()
    local rh = getRegisterHit()
    table.insert(lines, "RegisterAttack=" .. (ra and ra:GetFullName() or "MISSING"))
    table.insert(lines, "RegisterHit=" .. (rh and rh:GetFullName() or "MISSING"))
    table.insert(lines, "LOCKED: FireServer(0.5) → FireServer(hum)")
    return table.concat(lines, "\n")
end

local function buildRemotesSummary()
    local lines = {}
    table.insert(lines, "----- REMOTES SUMMARY -----")
    local ra = getRegisterAttack()
    local rh = getRegisterHit()
    table.insert(lines, "RegisterAttack=" .. (ra and ra:GetFullName() or "MISSING"))
    table.insert(lines, "RegisterHit=" .. (rh and rh:GetFullName() or "MISSING"))
    table.insert(lines, "LOCKED: FireServer(0.5) → FireServer(hum)")
    table.insert(lines, "Modules.Net: " .. childSummary(getNetFolder(), 60))
    return table.concat(lines, "\n")
end

local function buildAllBundle()
    return table.concat({
        buildClientDump(),
        "",
        "----- ERRORS -----",
        errorText(),
        "",
        "----- LOGS -----",
        ringText(),
        "",
        buildRemotesSummary(),
    }, "\n")
end

local function buildAutoCopyBundle()
    return table.concat({
        "========== DXLTA AUTO v" .. VERSION .. " ==========",
        statusOneLiner(),
        "FarmState=" .. tostring(ST.farm) .. "  Nearest=" .. tostring(ST.nearest) .. "  Kills=" .. tostring(ST.kills),
        string.format(
            "FLAGS farm=%s quest=%s aura=%s buso=%s fast=%s",
            tostring(STATE.farm),
            tostring(STATE.autoQuest),
            tostring(STATE.killAura),
            tostring(STATE.autoBuso),
            tostring(STATE.fastFarm)
        ),
        "",
        buildCombatRemotesTrim(),
        "",
        "----- ERRORS -----",
        errorText(),
        "",
        "----- LOGS (last 40) -----",
        ringText(40),
    }, "\n")
end

local function doAutoCopyAll()
    local bundle = buildAutoCopyBundle()
    if copyClip(bundle) then
        ST.lastCopy = os.date("%H:%M:%S")
        if setClientStatus then
            setClientStatus("Auto-Copy @ " .. ST.lastCopy, true)
        end
        if liveLabels.lastCopy then
            liveLabels.lastCopy.Text = ST.lastCopy
        end
        return true
    end
    if setClientStatus then
        setClientStatus("Auto-Copy failed (no clipboard)", false)
    end
    return false
end

-- ── Travel / noclip ─────────────────────────────────────────────────────────

local function setTravelNoclip(on)
    local char = localChar()
    if not char then
        return
    end
    if on then
        table.clear(noclipRestore)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                noclipRestore[part] = part.CanCollide
                pcall(function()
                    part.CanCollide = false
                end)
            end
        end
    else
        for part, was in pairs(noclipRestore) do
            if part and part.Parent then
                pcall(function()
                    part.CanCollide = was
                end)
            end
        end
        table.clear(noclipRestore)
    end
end

local function stopTravel()
    travelTok += 1
    setTravelNoclip(false)
end

local function enemyAttackSpot(tg)
    if not tg or not tg.root then
        return nil
    end
    local look = tg.root.CFrame.LookVector
    local fl = flat(look)
    if fl.Magnitude < 0.1 then
        fl = Vector3.new(0, 0, 1)
    else
        fl = fl.Unit
    end
    return tg.root.Position - fl * 5 + Vector3.new(0, 5, 0)
end

local function travelTo(destOrFn, label, keep)
    local r, h = localRoot(), localHum()
    local function resolveDest()
        if type(destOrFn) == "function" then
            local ok, v = pcall(destOrFn)
            if ok and typeof(v) == "Vector3" then
                return v
            end
            return nil
        end
        return typeof(destOrFn) == "Vector3" and destOrFn or nil
    end
    local dest = resolveDest()
    if not (r and h) or h.Health <= 0 or not dest then
        return false
    end
    travelTok += 1
    local tok = travelTok
    ST.farm = "travel → " .. tostring(label or "goal")
    ringPush("travel start → " .. tostring(label or "goal"))
    setTravelNoclip(true)
    local stuckAt = r.Position
    local stuckSince = os.clock()
    local lastStreamPos = Vector3.zero
    local okArrived = false
    while alive and tok == travelTok do
        local broke = false
        local okLoop, errLoop = pcall(function()
            if keep and not keep() then
                broke = true
                return
            end
            r, h = localRoot(), localHum()
            if not (r and h and r.Parent) or h.Health <= 0 then
                broke = true
                return
            end
            dest = resolveDest() or dest
            local dt = RunService.Heartbeat:Wait()
            if tok ~= travelTok or not r.Parent then
                broke = true
                return
            end
            dest = resolveDest() or dest
            local speed = math.clamp(tonumber(STATE.bfSpeed) or 240, 120, 320)
            local d = dest - r.Position
            local dist = d.Magnitude

            if dist > PIN_DIST then
                if (dest - lastStreamPos).Magnitude > 8 or os.clock() - lastStreamAt >= 0.5 then
                    requestStreamAround(dest)
                    lastStreamPos = dest
                end
            end

            if dist <= PIN_DIST then
                okArrived = true
                broke = true
                return
            end

            -- stuck 2s → chunk hop
            if (r.Position - stuckAt).Magnitude < 2.5 then
                if os.clock() - stuckSince > 2 then
                    local hopDist = math.min(80, math.max(8, dist - 8))
                    local hop = r.Position + d.Unit * hopDist
                    pcall(function()
                        setTravelNoclip(true)
                        r.CFrame = safeLookAt(hop, dest)
                        r.AssemblyLinearVelocity = Vector3.zero
                        r.AssemblyAngularVelocity = Vector3.zero
                    end)
                    requestStreamAround(dest)
                    ringPush(string.format("chunk-hop %.0fm → %s", hopDist, tostring(label)))
                    stuckAt = hop
                    stuckSince = os.clock()
                end
            else
                stuckAt = r.Position
                stuckSince = os.clock()
            end

            local step = speed * math.min(dt, 0.12)
            if dist <= step + 0.05 then
                pcall(function()
                    r.CFrame = safeLookAt(dest, dest + flat(d.Magnitude > 0.1 and d or Vector3.new(0, 0, 1)))
                    r.AssemblyLinearVelocity = Vector3.zero
                end)
                okArrived = true
                broke = true
                return
            else
                local p = r.Position + d.Unit * step
                local fl = flat(d)
                pcall(function()
                    if fl.Magnitude > 0.5 then
                        r.CFrame = safeLookAt(p, p + fl)
                    else
                        r.CFrame = CFrame.new(p) * (r.CFrame - r.CFrame.Position)
                    end
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end)
        if not okLoop then
            errorPush("travel: " .. tostring(errLoop):sub(1, 100))
            break
        end
        if broke then
            break
        end
    end
    if tok == travelTok then
        setTravelNoclip(false)
    end
    if okArrived then
        ringPush("arrive → " .. tostring(label or "goal"))
    end
    return okArrived
end

-- ── Silent combat ───────────────────────────────────────────────────────────

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

    local function isGodhuman(t)
        if not t or not t:IsA("Tool") then
            return false
        end
        local tip = ""
        pcall(function()
            tip = tostring(t.ToolTip or "")
        end)
        if tip == "Melee" then
            return true
        end
        if string.lower(t.Name) == "godhuman" then
            return true
        end
        return false
    end

    local held = c:FindFirstChildOfClass("Tool")
    if held and isGodhuman(held) then
        return held
    end

    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local pick = nil
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if isGodhuman(t) then
                pick = t
                break
            end
        end
        if not pick then
            for _, t in ipairs(c:GetChildren()) do
                if isGodhuman(t) then
                    pick = t
                    break
                end
            end
        end
    end

    if pick then
        pcall(function()
            h:EquipTool(pick)
        end)
        if os.clock() - lastCancelEquip > 1.2 then
            lastCancelEquip = os.clock()
            local cancel = getCancelEquipAnim()
            if cancel then
                pcall(function()
                    cancel:FireServer()
                end)
            end
        end
        return pick
    end

    if bp then
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
    end
    return held
end

local function fireRegisterAttack()
    local rem = getRegisterAttack()
    if not rem then
        return false
    end
    rememberRemote(rem)
    local ok, err = pcall(function()
        rem:FireServer(0.5)
    end)
    if not ok then
        errorPush("RegisterAttack(0.5): " .. tostring(err):sub(1, 80))
        return false
    end
    return true
end

local function readEnemyHp(tg)
    if not tg or not tg.hum then
        return nil
    end
    local ok, hp = pcall(function()
        return tg.hum.Health
    end)
    return ok and hp or nil
end

local function fireRegisterHit(tg)
    local rem = getRegisterHit()
    if not rem or not tg or not tg.hum then
        return false
    end
    rememberRemote(rem)
    local beforeHp = readEnemyHp(tg)
    local hum = tg.hum
    local ok, err = pcall(function()
        rem:FireServer(hum)
    end)
    if not ok then
        errorPush("RegisterHit(hum): " .. tostring(err):sub(1, 80))
        return false
    end
    ringPush("hit " .. tostring(tg.name or "enemy"))
    if beforeHp then
        task.delay(0.15, function()
            local after = readEnemyHp(tg)
            if after and after < beforeHp - 0.5 then
                ringPush(string.format(
                    "hit −%.0f (%.0f→%.0f)",
                    beforeHp - after,
                    beforeHp,
                    after
                ))
            end
        end)
    end
    return true
end

local function attackFallbackActivate(tool)
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

local function attackOnceSilent(optionalTarget)
    local tool = equipMeleeTool()
    local tg = optionalTarget
    if not tg then
        local range = math.clamp(tonumber(STATE.kaRange) or 22, 5, 60)
        local filter = STATE.farm and farmTargetName or nil
        tg = select(1, findNearestEnemy(range, filter))
        if not tg and STATE.farm then
            tg = select(1, findNearestEnemy(range, nil))
        end
    end

    local usedRemote = false
    if combatLocked.useRemotes and tg then
        local hasAtk = getRegisterAttack() ~= nil
        local hasHit = getRegisterHit() ~= nil
        if not hasAtk and not hasHit then
            combatLocked.useRemotes = false
            ringPush("Register* remotes MISSING · fallback Tool:Activate")
        else
            local atk = hasAtk and fireRegisterAttack() or false
            local hit = hasHit and fireRegisterHit(tg) or false
            usedRemote = atk or hit
        end
    end

    if not usedRemote then
        attackFallbackActivate(tool)
    end

    stopAttackTracks()
    task.defer(stopAttackTracks)
end

local function watchKill(tg)
    if not tg or not tg.hum or killWatch[tg.hum] then
        return
    end
    killWatch[tg.hum] = true
    local name = tg.name
    local c
    c = tg.hum.Died:Connect(function()
        if c then
            c:Disconnect()
        end
        ST.kills += 1
        ringPush("kill " .. tostring(name))
        pin = nil
        farmCurrentName = nil
    end)
    track(c)
end

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

local function tryAutoBuso()
    if not STATE.autoBuso then
        return
    end
    local char = localChar()
    if not char then
        return
    end
    if char:FindFirstChild("HasBuso") then
        ST.buso = "YES"
        return
    end
    if os.clock() - lastBusoTry < 2.5 then
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
    attackOnceSilent(tg)
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

local function tryGetBestQuestNPC()
    local rf = getBestQuestNPCRemote()
    if not rf then
        return nil
    end
    rememberRemote(rf)
    local ok, res = pcall(function()
        return rf:InvokeServer()
    end)
    if not ok then
        errorPush("GetBestQuestNPC ERR " .. tostring(res):sub(1, 48))
        return nil
    end
    local brief = tostring(res)
    if #brief > 72 then
        brief = brief:sub(1, 69) .. "…"
    end
    ringPush("GetBestQuestNPC → " .. brief)
    return res
end

local function tryAutoQuest()
    if not STATE.autoQuest then
        return
    end
    if os.clock() - lastQuestTry < 4 then
        return
    end
    lastQuestTry = os.clock()

    local best = tryGetBestQuestNPC()
    if best ~= nil then
        if typeof(best) == "Instance" then
            local root = getHRP(best) or (best:IsA("BasePart") and best)
            if root then
                local r = localRoot()
                local dist = r and (r.Position - root.Position).Magnitude or 999
                if dist > 14 then
                    travelTo(root.Position + Vector3.new(0, 3, 0), "best quest NPC", function()
                        return STATE.autoQuest == true
                    end)
                end
                firePromptsNear(best:IsA("Model") and best or best.Parent)
                ST.farm = "bestNPC @ " .. best.Name
            end
        elseif type(best) == "string" and best ~= "" then
            invokeComm("StartQuest", best, 1)
        elseif type(best) == "table" then
            local qName = best[1] or best.Name or best.Quest or best.quest
            local qId = best[2] or best.Id or best.id or 1
            if qName then
                invokeComm("StartQuest", tostring(qName), tonumber(qId) or 1)
            end
        end
    end

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
        ringPush("quest CommF_ soft-fail · continue farm")
    else
        ringPush("quest: no Sea1 plan · sea=" .. seaLabel() .. " · farm nearest")
        farmTargetName = nil
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
        ringPush("quest: no giver · continue nearest farm")
    end
end

-- ── Auto Farm ───────────────────────────────────────────────────────────────

local function farmStep()
    if farmBusy then
        return
    end
    farmBusy = true
    local okOuter, errOuter = pcall(function()
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

        local tg, d = findNearestEnemy(nil, nil)
        if farmTargetName then
            local filtered, fd = findNearestEnemy(nil, farmTargetName)
            if filtered then
                tg, d = filtered, fd
            end
        end

        if not tg then
            ST.farm = "waiting for Enemies"
            ST.nearest = "—"
            pin = nil
            farmCurrentName = nil
            local root = localRoot()
            if root then
                requestStreamAround(root.Position)
            end
            return
        end

        ST.nearest = string.format("%s · %dm", tg.name, math.floor(d or 0))
        local spot = enemyAttackSpot(tg)
        if not spot then
            return
        end

        if d > PIN_DIST then
            pin = nil
            ST.farm = string.format("travel → %s %.0fm", tg.name, d or 0)
            if farmCurrentName ~= tg.name then
                farmCurrentName = tg.name
                ringPush(string.format("travel → %s @%dm", tg.name, math.floor(d or 0)))
            end
            travelTo(function()
                return enemyAttackSpot(tg)
            end, string.format("%s %.0fm", tg.name, d or 0), function()
                if not STATE.farm then
                    return false
                end
                if not tg.hum or tg.hum.Health <= 0 or not tg.model.Parent then
                    return false
                end
                local hh = localHum()
                if not hh or hh.Health <= 0 then
                    return false
                end
                return true
            end)
            r = localRoot()
            if r and tg.hum and tg.hum.Health > 0 then
                spot = enemyAttackSpot(tg) or spot
                local nd = (r.Position - tg.root.Position).Magnitude
                if nd > PIN_DIST then
                    pcall(function()
                        setTravelNoclip(true)
                        r.CFrame = safeLookAt(spot, tg.root.Position)
                        r.AssemblyLinearVelocity = Vector3.zero
                        setTravelNoclip(false)
                    end)
                    ringPush(string.format("hard-set → %s @%.0fm", tg.name, nd))
                end
            end
            return
        end

        watchKill(tg)
        farmCurrentName = tg.name
        spot = enemyAttackSpot(tg) or spot
        pin = { pos = spot, root = tg.root, untilT = os.clock() + 2.5 }
        ST.farm = "kill " .. tg.name

        if STATE.mobPull then
            pullNearbyMobs(spot, 50)
        end

        local look = Vector3.new(tg.root.Position.X, spot.Y, tg.root.Position.Z)
        pcall(function()
            local rr = localRoot()
            if rr then
                rr.CFrame = safeLookAt(spot, look)
                rr.AssemblyLinearVelocity = Vector3.zero
                rr.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        local rate = math.clamp(tonumber(STATE.kaRate) or 8, 1, 14)
        local interval = 1 / rate
        local deadline = os.clock() + 1.0
        while STATE.farm and alive and os.clock() < deadline do
            if not tg.hum or tg.hum.Health <= 0 or not tg.model.Parent then
                break
            end
            local hh = localHum()
            if not hh or hh.Health <= 0 then
                break
            end
            spot = enemyAttackSpot(tg) or spot
            pin = { pos = spot, root = tg.root, untilT = os.clock() + 2.5 }
            look = Vector3.new(tg.root.Position.X, spot.Y, tg.root.Position.Z)
            pcall(function()
                local rr = localRoot()
                if rr then
                    rr.CFrame = safeLookAt(spot, look)
                    rr.AssemblyLinearVelocity = Vector3.zero
                end
            end)
            if STATE.mobPull then
                pullNearbyMobs(spot, 50)
            end
            if os.clock() - lastAttackAt >= interval then
                lastAttackAt = os.clock()
                local okHit, errHit = pcall(attackOnceSilent, tg)
                if not okHit then
                    errorPush("hit: " .. tostring(errHit):sub(1, 80))
                end
            end
            task.wait(0.05)
        end
    end)
    farmBusy = false
    if not okOuter then
        errorPush("farm: " .. tostring(errOuter):sub(1, 100))
        ST.farm = "err"
    end
end

local function applyFastFarm(on)
    STATE.fastFarm = on
    if on then
        STATE.farm = true
        STATE.autoQuest = true
        STATE.killAura = true
        local char = localChar()
        if not (char and char:FindFirstChild("HasBuso")) then
            STATE.autoBuso = true
        else
            STATE.autoBuso = false
            ST.buso = "YES"
        end
        ST.farm = "FAST FARM"
        ringPush("FAST FARM ON")
        notify("DXLTA", "FAST FARM — farm + quest + aura + buso", 3)
        hookAnimSuppress(localChar())
    else
        STATE.farm = false
        STATE.autoQuest = false
        STATE.killAura = false
        STATE.autoBuso = false
        pin = nil
        stopTravel()
        ST.farm = "idle"
        ringPush("FAST FARM OFF")
    end
end

local function refreshToggleUIs()
    for _, paint in pairs(togglePainters) do
        pcall(paint)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — left sidebar + cards, branded DXLTA
-- ═══════════════════════════════════════════════════════════════════════════

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

panelRoot = Instance.new("Frame")
panelRoot.Name = "Panel"
panelRoot.AnchorPoint = Vector2.new(0.5, 0.5)
panelRoot.Size = UDim2.fromOffset(720, 460)
panelRoot.Position = UDim2.fromScale(0.5, 0.5)
panelRoot.BackgroundColor3 = COLORS.bg
panelRoot.BorderSizePixel = 0
panelRoot.ClipsDescendants = true
panelRoot.Parent = screen

do
    local lim = Instance.new("UISizeConstraint")
    lim.MaxSize = Vector2.new(820, 560)
    lim.MinSize = Vector2.new(320, 380)
    lim.Parent = panelRoot
end

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panelRoot

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.stroke
panelStroke.Thickness = 1
panelStroke.Transparency = 0.25
panelStroke.Parent = panelRoot

-- LEFT SIDEBAR
sidebarFrame = Instance.new("Frame")
sidebarFrame.Name = "Sidebar"
sidebarFrame.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
sidebarFrame.BackgroundColor3 = COLORS.sidebar
sidebarFrame.BorderSizePixel = 0
sidebarFrame.Parent = panelRoot

brandBlock = Instance.new("Frame")
brandBlock.Name = "Brand"
brandBlock.Size = UDim2.new(1, 0, 0, 64)
brandBlock.BackgroundTransparency = 1
brandBlock.Parent = sidebarFrame

local brandTitle = Instance.new("TextLabel")
brandTitle.BackgroundTransparency = 1
brandTitle.Position = UDim2.fromOffset(14, 14)
brandTitle.Size = UDim2.new(1, -20, 0, 22)
brandTitle.Font = Enum.Font.GothamBlack
brandTitle.TextSize = 18
brandTitle.TextXAlignment = Enum.TextXAlignment.Left
brandTitle.TextColor3 = COLORS.lime
brandTitle.Text = "DXLTA"
brandTitle.Parent = brandBlock

local brandSub = Instance.new("TextLabel")
brandSub.BackgroundTransparency = 1
brandSub.Position = UDim2.fromOffset(14, 36)
brandSub.Size = UDim2.new(1, -20, 0, 16)
brandSub.Font = Enum.Font.Gotham
brandSub.TextSize = 11
brandSub.TextXAlignment = Enum.TextXAlignment.Left
brandSub.TextColor3 = COLORS.muted
brandSub.Text = "Blox Fruits"
brandSub.Parent = brandBlock

navScroll = Instance.new("ScrollingFrame")
navScroll.Name = "Nav"
navScroll.Size = UDim2.new(1, 0, 1, -72)
navScroll.Position = UDim2.fromOffset(0, 64)
navScroll.BackgroundTransparency = 1
navScroll.BorderSizePixel = 0
navScroll.ScrollBarThickness = 2
navScroll.ScrollBarImageColor3 = COLORS.limeDim
navScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
navScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
navScroll.Parent = sidebarFrame

local navLay = Instance.new("UIListLayout")
navLay.Padding = UDim.new(0, 4)
navLay.SortOrder = Enum.SortOrder.LayoutOrder
navLay.Parent = navScroll

local navPad = Instance.new("UIPadding")
navPad.PaddingLeft = UDim.new(0, 10)
navPad.PaddingRight = UDim.new(0, 10)
navPad.PaddingTop = UDim.new(0, 4)
navPad.PaddingBottom = UDim.new(0, 10)
navPad.Parent = navScroll

-- MAIN CONTENT
contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
contentFrame.Position = UDim2.fromOffset(SIDEBAR_W, 0)
contentFrame.BackgroundColor3 = COLORS.panel
contentFrame.BorderSizePixel = 0
contentFrame.ClipsDescendants = true
contentFrame.Parent = panelRoot

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 48)
topBar.BackgroundTransparency = 1
topBar.Parent = contentFrame

pageTitleLbl = Instance.new("TextLabel")
pageTitleLbl.BackgroundTransparency = 1
pageTitleLbl.Position = UDim2.fromOffset(18, 0)
pageTitleLbl.Size = UDim2.new(1, -100, 1, 0)
pageTitleLbl.Font = Enum.Font.GothamBold
pageTitleLbl.TextSize = 16
pageTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
pageTitleLbl.TextColor3 = COLORS.text
pageTitleLbl.Text = "Home"
pageTitleLbl.Parent = topBar

local headerBtns = Instance.new("Frame")
headerBtns.Size = UDim2.fromOffset(70, 28)
headerBtns.Position = UDim2.new(1, -84, 0.5, -14)
headerBtns.BackgroundTransparency = 1
headerBtns.Parent = topBar

local headerBtnLay = Instance.new("UIListLayout")
headerBtnLay.FillDirection = Enum.FillDirection.Horizontal
headerBtnLay.HorizontalAlignment = Enum.HorizontalAlignment.Right
headerBtnLay.VerticalAlignment = Enum.VerticalAlignment.Center
headerBtnLay.Padding = UDim.new(0, 6)
headerBtnLay.Parent = headerBtns

local function makeHeaderBtn(text, color, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(28, 28)
    btn.BackgroundColor3 = COLORS.ink
    btn.TextColor3 = color
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.Text = text
    btn.AutoButtonColor = true
    btn.LayoutOrder = order
    btn.Parent = headerBtns
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = btn
    return btn
end

local minBtn = makeHeaderBtn("−", COLORS.muted, 1)
local closeBtn = makeHeaderBtn("×", COLORS.danger, 2)

local pagesHost = Instance.new("Frame")
pagesHost.Name = "Pages"
pagesHost.Size = UDim2.new(1, 0, 1, -48)
pagesHost.Position = UDim2.fromOffset(0, 48)
pagesHost.BackgroundTransparency = 1
pagesHost.ClipsDescendants = true
pagesHost.Parent = contentFrame

local TABS = {
    { id = "Home", label = "Home", icon = "⌂" },
    { id = "Farm", label = "Farm", icon = "⚔" },
    { id = "Combat", label = "Combat", icon = "◎" },
    { id = "ESP", label = "ESP", icon = "◉" },
    { id = "Client", label = "Client", icon = "⎘" },
    { id = "Teleport", label = "Teleport", icon = "⇢" },
}

local function paintNav()
    for name, btn in pairs(tabButtons) do
        local active = name == currentTab
        if mobileMode then
            btn.Size = UDim2.fromOffset(0, 36)
            btn.AutomaticSize = Enum.AutomaticSize.X
            btn.Text = btn:GetAttribute("Short") or btn:GetAttribute("Label") or name
        else
            btn.Size = UDim2.new(1, 0, 0, 34)
            btn.AutomaticSize = Enum.AutomaticSize.None
            btn.Text = "  " .. (btn:GetAttribute("Label") or name)
        end
        if active then
            btn.BackgroundColor3 = COLORS.lime
            btn.BackgroundTransparency = 0
            btn.TextColor3 = COLORS.black
        else
            btn.BackgroundColor3 = COLORS.ink
            btn.BackgroundTransparency = mobileMode and 0.35 or 1
            btn.TextColor3 = COLORS.muted
        end
    end
end

local function switchTab(id)
    currentTab = id
    for name, page in pairs(tabPages) do
        page.Visible = name == id
        if name == id then
            page.CanvasPosition = Vector2.zero
        end
    end
    if pageTitleLbl then
        pageTitleLbl.Text = id
    end
    paintNav()
end

for i, meta in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name = "Nav_" .. meta.id
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = COLORS.ink
    btn.BackgroundTransparency = 1
    btn.TextColor3 = COLORS.muted
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = "  " .. meta.label
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    btn:SetAttribute("Label", meta.label)
    btn:SetAttribute("Short", meta.label)
    btn:SetAttribute("Icon", meta.icon)
    btn.Parent = navScroll
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = btn
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = btn
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
    page.Parent = pagesHost

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 10)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
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

local function makeCard(tab, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height or 72)
    card.BackgroundColor3 = COLORS.card
    card.BorderSizePixel = 0
    card.LayoutOrder = nextOrder(tab)
    card.Parent = parentOf(tab)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = card
    local s = Instance.new("UIStroke")
    s.Color = COLORS.stroke
    s.Thickness = 1
    s.Transparency = 0.55
    s.Parent = card
    return card
end

local function sectionLabel(tab, text)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = COLORS.limeSoft
    lbl.Text = string.upper(text)
    lbl.LayoutOrder = nextOrder(tab)
    lbl.Parent = parentOf(tab)
    return lbl
end

local function makeToggle(tab, title, key, onChange, opts)
    opts = opts or {}
    local h = opts.giant and 64 or 52
    local row = makeCard(tab, h)
    if opts.giant then
        row.BackgroundColor3 = COLORS.limeOn
        local stroke = row:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = COLORS.lime
            stroke.Transparency = 0.4
        end
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.fromOffset(14, opts.sub and 10 or 0)
    titleLbl.Size = UDim2.new(1, -78, opts.sub and 0 or 1, opts.sub and 18 or 0)
    if not opts.sub then
        titleLbl.Size = UDim2.new(1, -78, 1, 0)
        titleLbl.Position = UDim2.fromOffset(14, 0)
    end
    titleLbl.Font = opts.giant and Enum.Font.GothamBlack or Enum.Font.GothamMedium
    titleLbl.TextSize = opts.giant and 15 or 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextColor3 = COLORS.text
    titleLbl.Text = title
    titleLbl.Parent = row

    if opts.sub then
        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1
        sub.Position = UDim2.fromOffset(14, 30)
        sub.Size = UDim2.new(1, -78, 0, 14)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextColor3 = COLORS.muted
        sub.Text = opts.sub
        sub.Parent = row
    end

    local pill = Instance.new("TextButton")
    pill.Name = "Pill"
    pill.Size = UDim2.fromOffset(46, 26)
    pill.Position = UDim2.new(1, -58, 0.5, -13)
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.Parent = row
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = pill
    end

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.fromOffset(20, 20)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.Parent = pill
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = knob
    end

    local function paint()
        if STATE[key] then
            pill.BackgroundColor3 = COLORS.lime
            knob.BackgroundColor3 = COLORS.black
            knob.Position = UDim2.fromOffset(23, 3)
        else
            pill.BackgroundColor3 = Color3.fromRGB(58, 62, 70)
            knob.BackgroundColor3 = COLORS.muted
            knob.Position = UDim2.fromOffset(3, 3)
        end
    end
    paint()
    togglePainters[key] = paint

    local function toggle()
        STATE[key] = not STATE[key]
        paint()
        if onChange then
            safeCall(onChange, STATE[key])
        end
    end

    pill.MouseButton1Click:Connect(toggle)
    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.new(1, -68, 1, 0)
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
    local row = makeCard(tab, 58)
    local lab = Instance.new("TextLabel")
    lab.BackgroundTransparency = 1
    lab.Position = UDim2.fromOffset(14, 8)
    lab.Size = UDim2.new(1, -28, 0, 16)
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.TextColor3 = COLORS.text
    lab.Text = label .. ": " .. tostring(STATE[key])
    lab.Parent = row

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(14, 34)
    bar.Size = UDim2.new(1, -28, 0, 8)
    bar.BackgroundColor3 = Color3.fromRGB(50, 54, 60)
    bar.BorderSizePixel = 0
    bar.Parent = row
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = bar
    end

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((STATE[key] - minV) / math.max(maxV - minV, 1), 0, 1, 0)
    fill.BackgroundColor3 = COLORS.lime
    fill.BorderSizePixel = 0
    fill.Parent = bar
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
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

local function makeButton(tab, label, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = color or COLORS.lime
    btn.TextColor3 = COLORS.black
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
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
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, h or 28)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextColor3 = COLORS.muted
    lbl.TextWrapped = true
    lbl.Text = text
    lbl.LayoutOrder = nextOrder(tab)
    lbl.Parent = parentOf(tab)
    return lbl
end

local function makeStatCard(tab, title, key, height)
    local card = makeCard(tab, height or 70)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(14, 10)
    t.Size = UDim2.new(1, -28, 0, 14)
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = COLORS.muted
    t.Text = title
    t.Parent = card

    local v = Instance.new("TextLabel")
    v.BackgroundTransparency = 1
    v.Position = UDim2.fromOffset(14, 28)
    v.Size = UDim2.new(1, -28, 0, 28)
    v.Font = Enum.Font.GothamBold
    v.TextSize = 18
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextColor3 = COLORS.text
    v.Text = "—"
    v.Parent = card
    liveLabels[key] = v
    return card, v
end

local farmToggleUI, questToggleUI, auraToggleUI, busoToggleUI, fastToggleUI, pullToggleUI

-- ═══ HOME ═══════════════════════════════════════════════════════════════════

local welcome = makeCard("Home", 78)
do
    local hi = Instance.new("TextLabel")
    hi.BackgroundTransparency = 1
    hi.Position = UDim2.fromOffset(16, 14)
    hi.Size = UDim2.new(1, -32, 0, 18)
    hi.Font = Enum.Font.Gotham
    hi.TextSize = 12
    hi.TextXAlignment = Enum.TextXAlignment.Left
    hi.TextColor3 = COLORS.muted
    hi.Text = "Welcome"
    hi.Parent = welcome

    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.fromOffset(16, 34)
    nameLbl.Size = UDim2.new(1, -32, 0, 28)
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = 20
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextColor3 = COLORS.text
    nameLbl.Text = tostring(LocalPlayer.DisplayName or LocalPlayer.Name)
    nameLbl.Parent = welcome
    liveLabels.welcome = nameLbl
end

local metricsRow = Instance.new("Frame")
metricsRow.Size = UDim2.new(1, 0, 0, 70)
metricsRow.BackgroundTransparency = 1
metricsRow.LayoutOrder = nextOrder("Home")
metricsRow.Parent = parentOf("Home")

local metricsLay = Instance.new("UIListLayout")
metricsLay.FillDirection = Enum.FillDirection.Horizontal
metricsLay.Padding = UDim.new(0, 10)
metricsLay.Parent = metricsRow

local function miniMetric(parent, title, key, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0.5, -5, 1, 0)
    card.BackgroundColor3 = COLORS.card
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = card
    local s = Instance.new("UIStroke")
    s.Color = COLORS.stroke
    s.Thickness = 1
    s.Transparency = 0.55
    s.Parent = card
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(12, 10)
    t.Size = UDim2.new(1, -20, 0, 14)
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = COLORS.muted
    t.Text = title
    t.Parent = card
    local v = Instance.new("TextLabel")
    v.BackgroundTransparency = 1
    v.Position = UDim2.fromOffset(12, 30)
    v.Size = UDim2.new(1, -20, 0, 26)
    v.Font = Enum.Font.GothamBold
    v.TextSize = 16
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextColor3 = COLORS.text
    v.Text = "—"
    v.Parent = card
    liveLabels[key] = v
    return v
end

miniMetric(metricsRow, "FPS / Ping", "fpsPing", 1)
miniMetric(metricsRow, "Session", "session", 2)

fastToggleUI = makeToggle("Home", "FAST FARM", "fastFarm", function(on)
    applyFastFarm(on)
    refreshToggleUIs()
end, { giant = true, sub = "farm · quest · aura · buso" })

local homeState = makeCard("Home", 72)
do
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(14, 10)
    t.Size = UDim2.new(1, -28, 0, 14)
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = COLORS.muted
    t.Text = "Live farm state"
    t.Parent = homeState
    local v = Instance.new("TextLabel")
    v.BackgroundTransparency = 1
    v.Position = UDim2.fromOffset(14, 28)
    v.Size = UDim2.new(1, -28, 0, 32)
    v.Font = Enum.Font.Code
    v.TextSize = 12
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextYAlignment = Enum.TextYAlignment.Top
    v.TextColor3 = COLORS.limeSoft
    v.TextWrapped = true
    v.Text = "idle"
    v.Parent = homeState
    liveLabels.homeState = v
end

local footer = makeCard("Home", 78)
do
    local ids = Instance.new("TextLabel")
    ids.BackgroundTransparency = 1
    ids.Position = UDim2.fromOffset(14, 10)
    ids.Size = UDim2.new(1, -28, 0, 28)
    ids.Font = Enum.Font.Code
    ids.TextSize = 11
    ids.TextXAlignment = Enum.TextXAlignment.Left
    ids.TextYAlignment = Enum.TextYAlignment.Top
    ids.TextColor3 = COLORS.muted
    ids.TextWrapped = true
    ids.Text = string.format("JobId %s\nPlaceId %s · %s", tostring(game.JobId), tostring(game.PlaceId), seaLabel())
    ids.Parent = footer
    liveLabels.ids = ids

    local tip = Instance.new("TextLabel")
    tip.BackgroundTransparency = 1
    tip.Position = UDim2.fromOffset(14, 44)
    tip.Size = UDim2.new(1, -28, 0, 24)
    tip.Font = Enum.Font.Gotham
    tip.TextSize = 11
    tip.TextXAlignment = Enum.TextXAlignment.Left
    tip.TextColor3 = COLORS.limeSoft
    tip.TextWrapped = true
    tip.Text = "Workflow: FAST FARM 30s → Client COPY All → paste in chat"
    tip.Parent = footer
end

-- ═══ FARM ═══════════════════════════════════════════════════════════════════

sectionLabel("Farm", "Core")
farmToggleUI = makeToggle("Farm", "Auto Farm", "farm", function(on)
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
end, { sub = "nearest Enemies · speed 240 · hit hum" })

questToggleUI = makeToggle("Farm", "Auto Quest", "autoQuest", function(on)
    ringPush(on and "auto quest ON" or "auto quest OFF")
end, { sub = "CommF_ StartQuest · soft fail OK" })

busoToggleUI = makeToggle("Farm", "Auto Buso", "autoBuso", function(on)
    ringPush(on and "auto buso ON" or "auto buso OFF")
    if on then
        tryAutoBuso()
    end
end, { sub = "skip if HasBuso" })

pullToggleUI = makeToggle("Farm", "Mob Pull", "mobPull", function(on)
    ringPush(on and "mob pull ON" or "mob pull OFF")
end, { sub = "net-owner pull nearby" })

makeSlider("Farm", "Tween speed", "bfSpeed", 120, 320)

local farmLive = makeCard("Farm", 86)
do
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(14, 10)
    t.Size = UDim2.new(1, -28, 0, 14)
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = COLORS.muted
    t.Text = "Live farm"
    t.Parent = farmLive
    local v = Instance.new("TextLabel")
    v.BackgroundTransparency = 1
    v.Position = UDim2.fromOffset(14, 28)
    v.Size = UDim2.new(1, -28, 0, 46)
    v.Font = Enum.Font.Code
    v.TextSize = 12
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextYAlignment = Enum.TextYAlignment.Top
    v.TextColor3 = COLORS.limeSoft
    v.TextWrapped = true
    v.Text = "idle"
    v.Parent = farmLive
    liveLabels.farmLive = v
end

makeTip("Farm", "Travel → pin @ 8 studs · Godhuman each cycle · RegisterAttack(0.5)+Hit(hum) · stream while far · chunk hop if stuck 2s", 40)

-- ═══ COMBAT ═════════════════════════════════════════════════════════════════

sectionLabel("Combat", "Silent Aura")
auraToggleUI = makeToggle("Combat", "Silent Aura", "killAura", function(on)
    lastAuraNear = nil
    ringPush(on and "silent aura ON" or "silent aura OFF")
    if on then
        hookAnimSuppress(localChar())
    end
    if not on and STATE.fastFarm then
        STATE.fastFarm = false
        if fastToggleUI then fastToggleUI.paint() end
    end
end, { sub = "LOCKED RegisterAttack(0.5) → RegisterHit(hum)" })

makeSlider("Combat", "Aura range", "kaRange", 5, 60)
makeSlider("Combat", "Attack rate", "kaRate", 1, 14)
makeTip("Combat", "Locked remotes only · Godhuman equip · attack anims suppressed", 28)

-- ═══ ESP ════════════════════════════════════════════════════════════════════

sectionLabel("ESP", "Overlays")
makeToggle("ESP", "Enemy ESP", "enemyEsp", function(on)
    if not on then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
    else
        refreshEnemyEsp()
    end
end, { sub = "workspace.Enemies" })

makeToggle("ESP", "NPC ESP", "npcEsp", function(on)
    if not on then
        for model in pairs(npcEspMap) do
            clearEspOn(model)
        end
        npcEspMap = {}
    else
        refreshNpcEsp()
    end
end, { sub = "workspace.NPCs (optional)" })

makeToggle("ESP", "Player ESP", "playerEsp", function(on)
    if not on then
        for model in pairs(playerEspMap) do
            clearEspOn(model)
        end
        playerEspMap = {}
    else
        refreshPlayerEsp()
    end
end, { sub = "other players (optional)" })

-- ═══ CLIENT ═════════════════════════════════════════════════════════════════

sectionLabel("Client", "Clipboard")
makeToggle("Client", "Auto-Copy All (3s)", "autoCopyAll", function(on)
    ringPush(on and "auto-copy All ON" or "auto-copy All OFF")
    if on then
        doAutoCopyAll()
    end
end, { sub = "ON by default · remotes + last 40 logs" })

clientStatusLbl = Instance.new("TextLabel")
clientStatusLbl.BackgroundTransparency = 1
clientStatusLbl.Size = UDim2.new(1, 0, 0, 16)
clientStatusLbl.Font = Enum.Font.Gotham
clientStatusLbl.TextSize = 11
clientStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
clientStatusLbl.TextColor3 = COLORS.muted
clientStatusLbl.Text = "Client ready · Auto-Copy ON"
clientStatusLbl.LayoutOrder = nextOrder("Client")
clientStatusLbl.Parent = parentOf("Client")

setClientStatus = function(msg, ok)
    clientStatusLbl.Text = tostring(msg)
    if ok == true then
        clientStatusLbl.TextColor3 = COLORS.lime
    elseif ok == false then
        clientStatusLbl.TextColor3 = COLORS.danger
    else
        clientStatusLbl.TextColor3 = COLORS.muted
    end
end

makeButton("Client", "COPY All", COLORS.lime, function()
    if copyClip(buildAllBundle()) then
        ST.lastCopy = os.date("%H:%M:%S")
        setClientStatus("All copied @ " .. ST.lastCopy, true)
        notify("DXLTA", "All bundle copied — paste in chat", 3)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeButton("Client", "COPY Client", COLORS.limeSoft, function()
    if copyClip(buildClientDump()) then
        ST.lastCopy = os.date("%H:%M:%S")
        setClientStatus("Client copied @ " .. ST.lastCopy, true)
        notify("DXLTA", "Client dump copied", 2)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeButton("Client", "COPY Errors", Color3.fromRGB(200, 100, 80), function()
    if copyClip(errorText()) then
        setClientStatus("Errors copied (" .. tostring(#errorRing) .. ")", true)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeButton("Client", "COPY Logs", Color3.fromRGB(120, 170, 80), function()
    if copyClip(ringText()) then
        setClientStatus("Logs copied (" .. tostring(#ringLog) .. ")", true)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeTip("Client", "Farm 30s ON then paste — Workflow: FAST FARM 30s → COPY All → paste in chat", 36)

local lastCopyCard = makeCard("Client", 52)
do
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(14, 8)
    t.Size = UDim2.new(1, -28, 0, 14)
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = COLORS.muted
    t.Text = "Last copy"
    t.Parent = lastCopyCard
    local v = Instance.new("TextLabel")
    v.BackgroundTransparency = 1
    v.Position = UDim2.fromOffset(14, 24)
    v.Size = UDim2.new(1, -28, 0, 20)
    v.Font = Enum.Font.GothamBold
    v.TextSize = 14
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextColor3 = COLORS.text
    v.Text = "—"
    v.Parent = lastCopyCard
    liveLabels.lastCopy = v
end

-- ═══ TELEPORT (stub) ════════════════════════════════════════════════════════

sectionLabel("Teleport", "Soon")
local tpCard = makeCard("Teleport", 90)
do
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(16, 18)
    t.Size = UDim2.new(1, -32, 0, 54)
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Top
    t.TextColor3 = COLORS.muted
    t.TextWrapped = true
    t.Text = "Teleport destinations coming next.\nUse Farm travel for now — it streams + hops to nearest enemies."
    t.Parent = tpCard
end

switchTab("Home")

-- Responsive: AbsoluteSize.X < 700 → top chip rail
local function applyLayout(width)
    local wantMobile = width < MOBILE_BREAK
    if wantMobile == mobileMode and width > 0 then
        -- still refresh sizes
    end
    mobileMode = wantMobile
    if mobileMode then
        sidebarFrame.Size = UDim2.new(1, 0, 0, 56)
        sidebarFrame.Position = UDim2.fromOffset(0, 0)
        brandBlock.Visible = false
        navScroll.Size = UDim2.new(1, 0, 1, 0)
        navScroll.Position = UDim2.fromOffset(0, 0)
        navLay.FillDirection = Enum.FillDirection.Horizontal
        navLay.Padding = UDim.new(0, 6)
        navPad.PaddingLeft = UDim.new(0, 8)
        navPad.PaddingRight = UDim.new(0, 8)
        navPad.PaddingTop = UDim.new(0, 10)
        navPad.PaddingBottom = UDim.new(0, 10)
        navScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
        navScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        navScroll.ScrollingDirection = Enum.ScrollingDirection.X
        contentFrame.Size = UDim2.new(1, 0, 1, -56)
        contentFrame.Position = UDim2.fromOffset(0, 56)
        panelRoot.Size = UDim2.new(0.94, 0, 0.72, 0)
    else
        sidebarFrame.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
        sidebarFrame.Position = UDim2.fromOffset(0, 0)
        brandBlock.Visible = true
        navScroll.Size = UDim2.new(1, 0, 1, -72)
        navScroll.Position = UDim2.fromOffset(0, 64)
        navLay.FillDirection = Enum.FillDirection.Vertical
        navLay.Padding = UDim.new(0, 4)
        navPad.PaddingLeft = UDim.new(0, 10)
        navPad.PaddingRight = UDim.new(0, 10)
        navPad.PaddingTop = UDim.new(0, 4)
        navPad.PaddingBottom = UDim.new(0, 10)
        navScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        navScroll.ScrollingDirection = Enum.ScrollingDirection.Y
        contentFrame.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
        contentFrame.Position = UDim2.fromOffset(SIDEBAR_W, 0)
        panelRoot.Size = UDim2.fromOffset(720, 460)
    end
    paintNav()
end

track(panelRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    applyLayout(panelRoot.AbsoluteSize.X)
end))
task.defer(function()
    applyLayout(panelRoot.AbsoluteSize.X)
end)

-- open tween
panelRoot.Size = UDim2.fromOffset(690, 440)
pcall(function()
    TweenService:Create(panelRoot, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(720, 460),
    }):Play()
end)

-- ── LEFT reopen orb ─────────────────────────────────────────────────────────

local orb = Instance.new("ScreenGui")
orb.Name = ORB_NAME
orb.ResetOnSpawn = false
orb.IgnoreGuiInset = true
orb.DisplayOrder = 1001
orb.Enabled = false
orb.Parent = guiParent

local ORB_SIZE = 48
local orbBtn = Instance.new("TextButton")
orbBtn.Name = "Orb"
orbBtn.Size = UDim2.fromOffset(ORB_SIZE, ORB_SIZE)
orbBtn.Position = UDim2.new(0, 14, 0.42, 0)
orbBtn.BackgroundColor3 = COLORS.lime
orbBtn.TextColor3 = COLORS.black
orbBtn.Font = Enum.Font.GothamBlack
orbBtn.TextSize = 22
orbBtn.Text = "D"
orbBtn.AutoButtonColor = true
orbBtn.Parent = orb
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = orbBtn
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(0, 0, 0)
    s.Thickness = 2
    s.Transparency = 0.35
    s.Parent = orbBtn
end

local function setPanelVisible(vis)
    STATE.panelVisible = vis
    panelRoot.Visible = vis
    orb.Enabled = not vis
    if vis then
        applyLayout(panelRoot.AbsoluteSize.X > 0 and panelRoot.AbsoluteSize.X or 720)
    end
end

minBtn.MouseButton1Click:Connect(function()
    setPanelVisible(false)
    ringPush("panel minimized · left D orb")
end)

closeBtn.MouseButton1Click:Connect(function()
    ringPush("panel unload via ×")
    pcall(function()
        HUB.unload()
    end)
end)

do
    local dragging = false
    local moved = false
    local dragStart
    local originAbs
    local DRAG_THRESH = 8
    local function clampOrb(x, y)
        local cam = Workspace.CurrentCamera
        local vs = cam and cam.ViewportSize or Vector2.new(800, 600)
        return math.clamp(x, 4, math.max(4, vs.X - ORB_SIZE - 4)),
            math.clamp(y, 4, math.max(4, vs.Y - ORB_SIZE - 4))
    end
    track(orbBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            originAbs = orbBtn.AbsolutePosition
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging or not orb.Enabled then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > DRAG_THRESH or math.abs(delta.Y) > DRAG_THRESH then
                moved = true
            end
            if moved and originAbs then
                local nx, ny = clampOrb(originAbs.X + delta.X, originAbs.Y + delta.Y)
                orbBtn.Position = UDim2.fromOffset(nx, ny)
            end
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved and orb.Enabled then
                setPanelVisible(true)
            end
            dragging = false
            moved = false
        end
    end))
end

do
    local dragging = false
    local dragStart, startPos
    track(topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panelRoot.Position
        end
    end))
    track(topBar.InputEnded:Connect(function(input)
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
            panelRoot.Position = UDim2.new(
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
        if panelRoot.Parent then
            setPanelVisible(not STATE.panelVisible)
        end
    end
end))

track(RunService.Heartbeat:Connect(function(dt)
    if not alive then
        return
    end
    fpsFrames += 1
    fpsAccum += dt
    if fpsAccum >= 0.5 then
        fpsValue = fpsFrames / fpsAccum
        fpsFrames = 0
        fpsAccum = 0
    end
    pcall(function()
        if pin then
            if os.clock() > pin.untilT or not pin.root or not pin.root.Parent then
                pin = nil
            else
                local r = localRoot()
                if r then
                    local at = pin.pos
                    if pin.root then
                        local lookV = pin.root.CFrame.LookVector
                        local fl = flat(lookV)
                        if fl.Magnitude < 0.1 then
                            fl = Vector3.new(0, 0, 1)
                        else
                            fl = fl.Unit
                        end
                        at = pin.root.Position - fl * 5 + Vector3.new(0, 5, 0)
                        pin.pos = at
                    end
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

task.spawn(function()
    while alive do
        task.wait(0.12)
        if STATE.killAura and not STATE.farm then
            local ok, err = pcall(killAuraTick)
            if not ok then
                errorPush("aura: " .. tostring(err):sub(1, 80))
            end
        end
    end
end)

task.spawn(function()
    while alive do
        task.wait(0.1)
        if STATE.farm or STATE.fastFarm then
            local ok, err = pcall(farmStep)
            if not ok then
                ST.farm = "err"
                errorPush("farm: " .. tostring(err):sub(1, 100))
                warn("[DXLTA] farm: " .. tostring(err))
            end
        elseif STATE.autoBuso then
            pcall(tryAutoBuso)
        end
    end
end)

task.spawn(function()
    while alive do
        task.wait(3)
        pcall(function()
            refreshStatus()
            discoverCombatRemotes()
            if STATE.autoCopyAll then
                doAutoCopyAll()
            end
        end)
    end
end)

local accum = 0
track(RunService.Heartbeat:Connect(function(dt)
    accum += dt
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
        refreshStatus()
        if ST.farm ~= lastFarmLogged then
            lastFarmLogged = ST.farm
            ringPush("farm: " .. tostring(ST.farm))
        end
        if liveLabels.fpsPing then
            liveLabels.fpsPing.Text = string.format("%s fps · %s", ST.fps, ST.ping)
        end
        if liveLabels.session then
            liveLabels.session.Text = ST.session
        end
        if liveLabels.homeState then
            liveLabels.homeState.Text = string.format(
                "%s\nnear %s · kills %s · buso %s",
                tostring(ST.farm),
                tostring(ST.nearest),
                tostring(ST.kills),
                tostring(ST.buso)
            )
        end
        if liveLabels.farmLive then
            liveLabels.farmLive.Text = string.format(
                "state  %s\nnear   %s\nkills  %s · remotes %s",
                tostring(ST.farm),
                tostring(ST.nearest),
                tostring(ST.kills),
                tostring(ST.remotes)
            )
        end
        if liveLabels.lastCopy then
            liveLabels.lastCopy.Text = tostring(ST.lastCopy)
        end
        if liveLabels.ids then
            liveLabels.ids.Text = string.format(
                "JobId %s\nPlaceId %s · %s · mem %s",
                tostring(game.JobId),
                tostring(game.PlaceId),
                seaLabel(),
                readMem()
            )
        end
    end)
end))

track(LocalPlayer.CharacterAdded:Connect(function(char)
    pin = nil
    table.clear(noclipRestore)
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
    ringPush("LOCKED RegisterAttack(0.5) → RegisterHit(hum)")
    ringPush("v" .. VERSION .. " sidebar · travel 240 · pin 8 · Godhuman")
    if STATE.autoCopyAll then
        doAutoCopyAll()
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

notify("DXLTA", "BF Panel v3.0 · sidebar + locked Hit(hum)", 4)
print("[DXLTA] BF Panel ready — panel.lua v3.0")
print("[DXLTA] UI: left sidebar + cards · Home/Farm/Combat/ESP/Client/Teleport")
print("[DXLTA] Locked: Modules.Net RE/RegisterAttack:FireServer(0.5) → RE/RegisterHit:FireServer(hum)")
print("[DXLTA] Minimize → left D orb")

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
