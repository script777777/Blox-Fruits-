--[[
    DXLTA Blox Fruits — Mobile Hub Panel v2.3
    Premium glass · Fly-to-kill farm · Stream travel · Silent Aura · Client dump

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/bf-panel-ff0d/panel.lua"))()

    − = minimize (LEFT lime D orb)  ·  × = unload  ·  RightShift = toggle
    Locked combat: RegisterAttack(0.5) → RegisterHit(Humanoid)
]]

print("[DXLTA] BF Panel boot… v2.3")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__DXLTA_BF_PANEL and type(ENV.__DXLTA_BF_PANEL.unload) == "function" then
    pcall(ENV.__DXLTA_BF_PANEL.unload)
end
ENV.__DXLTA_BF_PANEL = { version = "2.3" }
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
    bg = Color3.fromRGB(14, 16, 18),
    panel = Color3.fromRGB(14, 16, 18),
    ink = Color3.fromRGB(24, 28, 30),
    inkDeep = Color3.fromRGB(18, 20, 22),
    text = Color3.fromRGB(232, 236, 240),
    muted = Color3.fromRGB(110, 122, 132),
    lime = Color3.fromRGB(180, 255, 40),
    limeDim = Color3.fromRGB(90, 140, 20),
    limeSoft = Color3.fromRGB(150, 210, 55),
    danger = Color3.fromRGB(255, 90, 90),
    enemy = Color3.fromRGB(255, 120, 80),
    npc = Color3.fromRGB(120, 200, 255),
    player = Color3.fromRGB(200, 140, 255),
    black = Color3.fromRGB(6, 8, 6),
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
    bfSpeed = 220,
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
    lastCopy = "noch nie",
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
local lastCancelEquip = 0
local killWatch = setmetatable({}, { __mode = "k" })
local animHooks = {}
local discoveredRemotes = {}
local noclipRestore = {}
local farmCurrentName = nil
local lastStreamAt = 0
local farmBusy = false
local lastAttackAt = 0

-- LOCKED from real user logs — do not probe other patterns
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
local statusBlockLbl
local tabPages = {}
local tabButtons = {}
local currentTab = "Start"
local clientStatusLbl
local scoutFilterBox
local scoutPreviewLbl
local setClientStatus
local togglePainters = {}
local rememberRemote

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

local function getRegisterAttack()
    return findRemoteByName(getNetFolder(), "RE/RegisterAttack")
        or findRemoteByName(getNetFolder(), "RegisterAttack")
end

local function getRegisterHit()
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
    -- deep scan common roots once
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
        return "(keine logs — farm/quest/aura starten)"
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
        return "(keine errors)"
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
                    or string.find(n, "shoot", 1, true)
                    or string.find(n, "damage", 1, true)
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
    local names = {
        "identifyexecutor", "getexecutorname", "ExecutorName",
    }
    for _, n in ipairs(names) do
        local fn = rawget(_G, n) or (type(getgenv) == "function" and rawget(getgenv(), n))
        if type(fn) == "function" then
            local ok, res = pcall(fn)
            if ok and res then
                return tostring(res)
            end
        elseif type(fn) == "string" then
            return fn
        end
    end
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

local function statusBlockText()
    local flags = (STATE.farm and "ON" or "OFF")
        .. (STATE.fastFarm and " · FAST" or "")
        .. (STATE.killAura and " · aura" or "")
        .. (STATE.autoQuest and " · quest" or "")
    return string.format(
        "LV %s · kills %s · buso %s\nnear  %s\nfarm  %s\n%s",
        tostring(ST.level),
        tostring(ST.kills),
        tostring(ST.buso),
        tostring(ST.nearest),
        tostring(ST.farm),
        flags
    )
end

-- ── Client dump / Scout scan ────────────────────────────────────────────────

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

local function parseFilterTerms(raw)
    local terms = {}
    for part in tostring(raw or ""):gmatch("[^,%s]+") do
        if part ~= "" then
            table.insert(terms, string.lower(part))
        end
    end
    return terms
end

local function lineMatchesFilter(line, terms)
    if not terms or #terms == 0 then
        return true
    end
    local low = string.lower(tostring(line))
    for _, t in ipairs(terms) do
        if string.find(low, t, 1, true) then
            return true
        end
    end
    return false
end

local function shouldListScout(inst)
    if not inst then
        return false
    end
    local n = string.lower(inst.Name)
    local cls = inst.ClassName
    if cls == "RemoteEvent" or cls == "RemoteFunction" or cls == "UnreliableRemoteEvent" then
        return true
    end
    if string.find(n, "remote", 1, true)
        or string.find(n, "comm", 1, true)
        or string.find(n, "register", 1, true)
        or string.find(n, "attack", 1, true)
        or string.find(n, "hit", 1, true)
        or string.find(n, "net", 1, true)
        or string.find(n, "quest", 1, true)
        or string.find(n, "stream", 1, true) then
        return true
    end
    return false
end

local function dumpTree(root, lines, depth, maxDepth, maxLines)
    if not root or depth > maxDepth or #lines >= maxLines then
        return
    end
    local path = getFullPath(root)
    if shouldListScout(root) then
        table.insert(lines, string.format("%s | %s", root.ClassName, path))
    end
    local ok, kids = pcall(function()
        return root:GetChildren()
    end)
    if not ok or not kids then
        return
    end
    local pri, rest = {}, {}
    for _, c in ipairs(kids) do
        if shouldListScout(c) then
            table.insert(pri, c)
        else
            table.insert(rest, c)
        end
    end
    for _, c in ipairs(pri) do
        dumpTree(c, lines, depth + 1, maxDepth, maxLines)
    end
    for _, c in ipairs(rest) do
        if depth < 2 then
            dumpTree(c, lines, depth + 1, maxDepth, maxLines)
        end
    end
end

local function buildClientDump()
    local lines = {}
    table.insert(lines, "========== DXLTA CLIENT DUMP v2.3 ==========")
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

    local data = LocalPlayer:FindFirstChild("Data")
    table.insert(lines, "Data children: " .. childSummary(data, 80))
    local stats = data and (data:FindFirstChild("Stats") or data:FindFirstChild("Stat") or data:FindFirstChild("stats"))
    if stats then
        table.insert(lines, "Stats folder: " .. childSummary(stats, 60))
        local ok, kids = pcall(function() return stats:GetChildren() end)
        if ok and kids then
            for _, s in ipairs(kids) do
                local okv, val = pcall(function() return s.Value end)
                if okv then
                    table.insert(lines, string.format("  Stat.%s = %s", s.Name, tostring(val)))
                end
            end
        end
    end

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
    else
        table.insert(lines, "Backpack tools: (no backpack)")
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
    table.insert(lines, "RS.Remotes: " .. childSummary(getRemotesFolder(), 80))

    local disc = {}
    for path, cls in pairs(discoveredRemotes) do
        table.insert(disc, cls .. " " .. path)
    end
    table.sort(disc)
    table.insert(lines, "Discovered remotes: " .. (#disc > 0 and table.concat(disc, " | ") or "(none yet)"))

    local sample = {}
    local folder = getEnemiesFolder()
    if folder then
        local kids = folder:GetChildren()
        for i, m in ipairs(kids) do
            if i > 25 then
                table.insert(sample, "…+" .. tostring(#kids - 25))
                break
            end
            table.insert(sample, m.Name)
        end
    end
    table.insert(lines, "workspace.Enemies sample: " .. (#sample > 0 and table.concat(sample, ", ") or "(none)"))
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
    local stream = findStreamRemote()
    table.insert(lines, "RequestStreamAroundAsync=" .. (stream and stream:GetFullName() or "Player method / missing"))
    local combatHints = { "register", "attack", "hit", "combat", "damage", "buso", "stream", "quest", "comm" }
    local disc = {}
    for path, cls in pairs(discoveredRemotes) do
        local low = string.lower(path)
        for _, hint in ipairs(combatHints) do
            if string.find(low, hint, 1, true) then
                table.insert(disc, cls .. " " .. path)
                break
            end
        end
    end
    table.sort(disc)
    for i, d in ipairs(disc) do
        if i > 24 then
            table.insert(lines, "…+" .. tostring(#disc - 24))
            break
        end
        table.insert(lines, d)
    end
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
    local disc = {}
    for path, cls in pairs(discoveredRemotes) do
        table.insert(disc, cls .. " " .. path)
    end
    table.sort(disc)
    for _, d in ipairs(disc) do
        table.insert(lines, d)
    end
    return table.concat(lines, "\n")
end

local function buildAllBundle()
    local parts = {
        buildClientDump(),
        "",
        "----- ERRORS -----",
        errorText(),
        "",
        "----- LOGS -----",
        ringText(),
        "",
        buildRemotesSummary(),
    }
    return table.concat(parts, "\n")
end

-- Mobile-friendly auto-copy: combat remotes + last 40 logs (pasteable)
local function buildAutoCopyBundle()
    local parts = {
        "========== DXLTA AUTO v2.3 ==========",
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
    }
    return table.concat(parts, "\n")
end

local function runScoutScan(filterRaw)
    local lines = {}
    table.insert(lines, "========== DXLTA SCAN ==========")
    table.insert(lines, statusOneLiner())
    local remotes = getRemotesFolder()
    if remotes then
        table.insert(lines, "")
        table.insert(lines, "### ReplicatedStorage.Remotes ###")
        dumpTree(remotes, lines, 0, 4, 1200)
    end
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        table.insert(lines, "")
        table.insert(lines, "### ReplicatedStorage.Modules ###")
        dumpTree(modules, lines, 0, 4, 1800)
    end
    local enemies = getEnemiesFolder()
    if enemies then
        table.insert(lines, "")
        table.insert(lines, "### workspace.Enemies (shallow) ###")
        for _, m in ipairs(enemies:GetChildren()) do
            if #lines > 2800 then
                break
            end
            table.insert(lines, string.format("%s | %s", m.ClassName, getFullPath(m)))
        end
    end
    table.insert(lines, "")
    table.insert(lines, string.format("========== END (%d lines) ==========", #lines + 1))
    if #lines > 3000 then
        table.insert(lines, "... TRUNCATED ...")
    end
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

-- ── Noclip during travel ────────────────────────────────────────────────────

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
    -- goal = enemy.Pos - flatLook*5 + (0,5,0)
    return tg.root.Position - fl * 5 + Vector3.new(0, 5, 0)
end

-- destOrFn: Vector3 or function() -> Vector3 (live behind-enemy spot)
-- Long-range: 220 studs/s HRP tween + stream + chunk teleport on stall
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
    ST.farm = "flug → " .. tostring(label or "travel")
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
            local speed = math.clamp(tonumber(STATE.bfSpeed) or 220, 180, 280)
            local d = dest - r.Position
            local dist = d.Magnitude

            -- stream while traveling far so enemies load in
            if dist > 10 then
                if (dest - lastStreamPos).Magnitude > 8 or os.clock() - lastStreamAt >= 0.5 then
                    requestStreamAround(dest)
                    lastStreamPos = dest
                end
            end

            if dist <= 10 then
                okArrived = true
                broke = true
                return
            end

            -- no progress 2.5s → chunk teleport min(80, dist-8)
            if (r.Position - stuckAt).Magnitude < 2.5 then
                if os.clock() - stuckSince > 2.5 then
                    local hopDist = math.min(80, math.max(8, dist - 8))
                    local hop = r.Position + d.Unit * hopDist
                    pcall(function()
                        setTravelNoclip(true)
                        r.CFrame = safeLookAt(hop, dest)
                        r.AssemblyLinearVelocity = Vector3.zero
                        r.AssemblyAngularVelocity = Vector3.zero
                    end)
                    requestStreamAround(dest)
                    ringPush(string.format("chunk-tp %.0fm → %s", hopDist, tostring(label)))
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

-- ALWAYS equip Godhuman (ToolTip==Melee or Name==Godhuman) every attack cycle
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

    -- last resort: any non-fruit tool
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

-- LOCKED: RegisterAttack(0.5)
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

-- LOCKED: RegisterHit(Humanoid)
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
    if beforeHp then
        task.delay(0.15, function()
            local after = readEnemyHp(tg)
            if after and after < beforeHp - 0.5 then
                ringPush(string.format(
                    "hit hum −%.0f (%.0f→%.0f)",
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
        -- clear pin so next target is picked immediately
        pin = nil
        farmCurrentName = nil
    end)
    track(c)
end

-- ── Mob Pull ────────────────────────────────────────────────────────────────

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

-- ── Auto Buso — skip if HasBuso folder exists ───────────────────────────────

local function tryAutoBuso()
    if not STATE.autoBuso then
        return
    end
    local char = localChar()
    if not char then
        return
    end
    if char:FindFirstChild("HasBuso") then
        ST.buso = "JA"
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
    attackOnceSilent(tg)
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
        ringPush("quest CommF_ failed · fallback prompt")
    else
        -- PlaceId unknown / high level → always farm nearest workspace.Enemies
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

-- ── Auto Farm — fly to enemy and kill ───────────────────────────────────────

local function farmStep()
    if farmBusy then
        return
    end
    farmBusy = true
    local okOuter, errOuter = pcall(function()
        local r, h = localRoot(), localHum()
        if not (r and h) then
            ST.farm = "warte auf Character"
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

        -- Always farm nearest workspace.Enemies (Health>0)
        local tg, d = findNearestEnemy(nil, nil)
        if farmTargetName then
            local filtered, fd = findNearestEnemy(nil, farmTargetName)
            if filtered then
                tg, d = filtered, fd
            end
        end

        if not tg then
            ST.farm = "warte auf Enemies"
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

        if d > 10 then
            pin = nil
            ST.farm = string.format("flug → %s %.0fm", tg.name, d or 0)
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
            -- after travel: if still far, hard set closer once
            r = localRoot()
            if r and tg.hum and tg.hum.Health > 0 then
                spot = enemyAttackSpot(tg) or spot
                local nd = (r.Position - tg.root.Position).Magnitude
                if nd > 10 then
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

        -- Within ≤10 studs: pin behind, equip Godhuman, attack ~8/s
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
        -- buso only if not already HasBuso
        local char = localChar()
        if not (char and char:FindFirstChild("HasBuso")) then
            STATE.autoBuso = true
        else
            STATE.autoBuso = false
            ST.buso = "JA"
        end
        ST.farm = "FAST FARM"
        ringPush("FAST FARM ON")
        notify("DXLTA", "FAST FARM — flug + kill", 3)
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
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.55)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screen

do
    local lim = Instance.new("UISizeConstraint")
    lim.MaxSize = Vector2.new(420, 520)
    lim.MinSize = Vector2.new(280, 360)
    lim.Parent = panel
end

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.lime
panelStroke.Thickness = 1
panelStroke.Transparency = 0.55
panelStroke.Parent = panel

-- subtle glass gradient
local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 22, 24)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 16)),
})
panelGrad.Rotation = 110
panelGrad.Parent = panel

-- Header bar 40px
local HEADER_H = 40
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundColor3 = COLORS.inkDeep
header.BorderSizePixel = 0
header.Parent = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 16)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 14)
headerFix.Position = UDim2.new(0, 0, 1, -14)
headerFix.BackgroundColor3 = COLORS.inkDeep
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local headerBrand = Instance.new("TextLabel")
headerBrand.BackgroundTransparency = 1
headerBrand.Position = UDim2.fromOffset(14, 0)
headerBrand.Size = UDim2.new(1, -90, 1, 0)
headerBrand.Font = Enum.Font.GothamBlack
headerBrand.TextSize = 15
headerBrand.TextXAlignment = Enum.TextXAlignment.Left
headerBrand.TextColor3 = COLORS.lime
headerBrand.Text = "DXLTA"
headerBrand.Parent = header

local headerBtns = Instance.new("Frame")
headerBtns.Name = "HeaderBtns"
headerBtns.AnchorPoint = Vector2.new(1, 0.5)
headerBtns.Position = UDim2.new(1, -10, 0.5, 0)
headerBtns.Size = UDim2.fromOffset(60, 26)
headerBtns.BackgroundTransparency = 1
headerBtns.Parent = header

local headerBtnLay = Instance.new("UIListLayout")
headerBtnLay.FillDirection = Enum.FillDirection.Horizontal
headerBtnLay.HorizontalAlignment = Enum.HorizontalAlignment.Right
headerBtnLay.VerticalAlignment = Enum.VerticalAlignment.Center
headerBtnLay.Padding = UDim.new(0, 6)
headerBtnLay.SortOrder = Enum.SortOrder.LayoutOrder
headerBtnLay.Parent = headerBtns

local function makeHeaderBtn(text, color, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(26, 26)
    btn.BackgroundColor3 = COLORS.ink
    btn.TextColor3 = color
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = text
    btn.AutoButtonColor = true
    btn.LayoutOrder = order
    btn.Parent = headerBtns
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = btn
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(40, 48, 50)
    s.Thickness = 1
    s.Transparency = 0.4
    s.Parent = btn
    return btn
end

local minBtn = makeHeaderBtn("−", COLORS.muted, 1)
local closeBtn = makeHeaderBtn("×", COLORS.danger, 2)

-- Bottom tab bar 46px · 5 equal tabs
local TAB_H = 46
local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Size = UDim2.new(1, 0, 0, TAB_H)
tabBar.Position = UDim2.new(0, 0, 1, -TAB_H)
tabBar.BackgroundColor3 = COLORS.inkDeep
tabBar.BorderSizePixel = 0
tabBar.Parent = panel

local tabBarTop = Instance.new("Frame")
tabBarTop.Size = UDim2.new(1, 0, 0, 12)
tabBarTop.BackgroundColor3 = COLORS.inkDeep
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
tabPad.PaddingLeft = UDim.new(0, 8)
tabPad.PaddingRight = UDim.new(0, 8)
tabPad.PaddingBottom = UDim.new(0, 6)
tabPad.Parent = tabBar

local contentHost = Instance.new("Frame")
contentHost.Name = "Content"
contentHost.Size = UDim2.new(1, 0, 1, -(HEADER_H + TAB_H))
contentHost.Position = UDim2.fromOffset(0, HEADER_H)
contentHost.BackgroundTransparency = 1
contentHost.ClipsDescendants = true
contentHost.Parent = panel

local TABS = {
    { id = "Start", label = "Start" },
    { id = "Farm", label = "Farm" },
    { id = "Kampf", label = "Kampf" },
    { id = "ESP", label = "ESP" },
    { id = "Client", label = "Client" },
}

local function switchTab(id)
    currentTab = id
    for name, page in pairs(tabPages) do
        page.Visible = name == id
        if name == id then
            page.CanvasPosition = Vector2.zero
        end
    end
    for name, btn in pairs(tabButtons) do
        if name == id then
            btn.BackgroundColor3 = COLORS.lime
            btn.TextColor3 = COLORS.black
            btn.BackgroundTransparency = 0
        else
            btn.BackgroundColor3 = COLORS.ink
            btn.TextColor3 = COLORS.muted
            btn.BackgroundTransparency = 1
        end
    end
end

local tabCount = #TABS
for i, meta in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. meta.id
    btn.Size = UDim2.new(1 / tabCount, -5, 0, 32)
    btn.BackgroundColor3 = COLORS.ink
    btn.BackgroundTransparency = 1
    btn.TextColor3 = COLORS.muted
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
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
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
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

-- Toggle row: 50px · ink · corner 12 · title 14 · subtitle 11 · pill 48×28
local function makeToggle(tab, title, key, onChange, opts)
    opts = opts or {}
    local h = opts.giant and 56 or 50
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, h)
    row.BackgroundColor3 = opts.giant and Color3.fromRGB(28, 36, 22) or COLORS.ink
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder(tab)
    row.Parent = parentOf(tab)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = row

    if opts.giant then
        local stroke = Instance.new("UIStroke")
        stroke.Color = COLORS.lime
        stroke.Thickness = 1
        stroke.Transparency = 0.55
        stroke.Parent = row
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.fromOffset(14, opts.sub and 8 or 0)
    titleLbl.Size = UDim2.new(1, -78, opts.sub and 0 or 1, opts.sub and 18 or 0)
    if not opts.sub then
        titleLbl.Size = UDim2.new(1, -78, 1, 0)
        titleLbl.Position = UDim2.fromOffset(14, 0)
    end
    titleLbl.Font = opts.giant and Enum.Font.GothamBlack or Enum.Font.GothamMedium
    titleLbl.TextSize = opts.giant and 15 or 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextColor3 = COLORS.text
    titleLbl.Text = title
    titleLbl.Parent = row

    if opts.sub then
        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1
        sub.Position = UDim2.fromOffset(14, 28)
        sub.Size = UDim2.new(1, -78, 0, 14)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextColor3 = COLORS.muted
        sub.Text = opts.sub
        sub.Parent = row
    end

    -- pill switch 48×28
    local pill = Instance.new("TextButton")
    pill.Name = "Pill"
    pill.Size = UDim2.fromOffset(48, 28)
    pill.Position = UDim2.new(1, -60, 0.5, -14)
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
    knob.Size = UDim2.fromOffset(22, 22)
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
            if opts.giant then
                row.BackgroundColor3 = Color3.fromRGB(36, 48, 22)
            end
        else
            pill.BackgroundColor3 = Color3.fromRGB(48, 54, 56)
            knob.BackgroundColor3 = COLORS.muted
            knob.Position = UDim2.fromOffset(3, 3)
            if opts.giant then
                row.BackgroundColor3 = Color3.fromRGB(28, 36, 22)
            end
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
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = COLORS.ink
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder(tab)
    row.Parent = parentOf(tab)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = row

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
    bar.Position = UDim2.fromOffset(14, 30)
    bar.Size = UDim2.new(1, -28, 0, 10)
    bar.BackgroundColor3 = Color3.fromRGB(40, 46, 48)
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
    btn.Size = UDim2.new(1, 0, 0, 42)
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
        c.CornerRadius = UDim.new(0, 12)
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

local farmToggleUI, questToggleUI, auraToggleUI, busoToggleUI, fastToggleUI, pullToggleUI

-- ═══ START ══════════════════════════════════════════════════════════════════

local hero = Instance.new("TextLabel")
hero.BackgroundTransparency = 1
hero.Size = UDim2.new(1, 0, 0, 32)
hero.Font = Enum.Font.GothamBlack
hero.TextSize = 28
hero.TextXAlignment = Enum.TextXAlignment.Left
hero.TextColor3 = COLORS.lime
hero.Text = "DXLTA"
hero.LayoutOrder = nextOrder("Start")
hero.Parent = parentOf("Start")

local heroSub = Instance.new("TextLabel")
heroSub.BackgroundTransparency = 1
heroSub.Size = UDim2.new(1, 0, 0, 16)
heroSub.Font = Enum.Font.Gotham
heroSub.TextSize = 12
heroSub.TextXAlignment = Enum.TextXAlignment.Left
heroSub.TextColor3 = COLORS.muted
heroSub.Text = "Mobile farm hub · fly · silent hit"
heroSub.LayoutOrder = nextOrder("Start")
heroSub.Parent = parentOf("Start")

fastToggleUI = makeToggle("Start", "FAST FARM", "fastFarm", function(on)
    applyFastFarm(on)
    refreshToggleUIs()
end, { giant = true, sub = "farm · quest · aura · buso" })

-- compact status block — 4 mono lines, no empty void
local statusCard = Instance.new("Frame")
statusCard.Size = UDim2.new(1, 0, 0, 78)
statusCard.BackgroundColor3 = COLORS.ink
statusCard.BorderSizePixel = 0
statusCard.LayoutOrder = nextOrder("Start")
statusCard.Parent = parentOf("Start")
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = statusCard
end

statusBlockLbl = Instance.new("TextLabel")
statusBlockLbl.BackgroundTransparency = 1
statusBlockLbl.Position = UDim2.fromOffset(12, 10)
statusBlockLbl.Size = UDim2.new(1, -24, 1, -16)
statusBlockLbl.Font = Enum.Font.Code
statusBlockLbl.TextSize = 11
statusBlockLbl.TextXAlignment = Enum.TextXAlignment.Left
statusBlockLbl.TextYAlignment = Enum.TextYAlignment.Top
statusBlockLbl.TextColor3 = COLORS.limeSoft
statusBlockLbl.TextWrapped = true
statusBlockLbl.Text = statusBlockText()
statusBlockLbl.Parent = statusCard

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
end, { sub = "nearest Enemies · fly 220 · hit hum" })

questToggleUI = makeToggle("Farm", "Auto Quest", "autoQuest", function(on)
    ringPush(on and "auto quest ON" or "auto quest OFF")
end, { sub = "StartQuest / giver prompt" })

busoToggleUI = makeToggle("Farm", "Auto Buso", "autoBuso", function(on)
    ringPush(on and "auto buso ON" or "auto buso OFF")
    if on then
        tryAutoBuso()
    end
end, { sub = "skip if HasBuso" })

pullToggleUI = makeToggle("Farm", "Mob Pull", "mobPull", function(on)
    ringPush(on and "mob pull ON" or "mob pull OFF")
end, { sub = "net-owner pull nearby" })

makeSlider("Farm", "Fly speed", "bfSpeed", 180, 280)
makeTip("Farm", "flug → pin ≤10m · EquipTool Godhuman · RegisterAttack(0.5)+Hit(hum) · stream far", 36)

-- ═══ KAMPF ══════════════════════════════════════════════════════════════════

sectionLabel("Kampf", "Silent Aura")
auraToggleUI = makeToggle("Kampf", "Kill Aura", "killAura", function(on)
    lastAuraNear = nil
    ringPush(on and "kill aura ON" or "kill aura OFF")
    if on then
        hookAnimSuppress(localChar())
    end
    if not on and STATE.fastFarm then
        STATE.fastFarm = false
        if fastToggleUI then fastToggleUI.paint() end
    end
end, { sub = "Melee → Attack(0.5) → Hit(hum)" })

makeSlider("Kampf", "Aura range", "kaRange", 5, 60)
makeSlider("Kampf", "Attack rate", "kaRate", 1, 14)
makeTip("Kampf", "Locked remotes only · Activate fallback · anims stopped", 28)

-- ═══ ESP ════════════════════════════════════════════════════════════════════

sectionLabel("ESP", "Overlays")
makeToggle("ESP", "Gegner ESP", "enemyEsp", function(on)
    if not on then
        for model in pairs(enemyEspMap) do
            clearEspOn(model)
        end
        enemyEspMap = {}
    else
        refreshEnemyEsp()
    end
end, { sub = "workspace.Enemies tags" })

makeToggle("ESP", "NPC ESP", "npcEsp", function(on)
    if not on then
        for model in pairs(npcEspMap) do
            clearEspOn(model)
        end
        npcEspMap = {}
    else
        refreshNpcEsp()
    end
end, { sub = "workspace.NPCs" })

makeToggle("ESP", "Spieler ESP", "playerEsp", function(on)
    if not on then
        for model in pairs(playerEspMap) do
            clearEspOn(model)
        end
        playerEspMap = {}
    else
        refreshPlayerEsp()
    end
end, { sub = "other players" })

-- ═══ CLIENT ═════════════════════════════════════════════════════════════════

sectionLabel("Client", "Clipboard")
makeToggle("Client", "Auto-Copy All (3s)", "autoCopyAll", function(on)
    ringPush(on and "auto-copy All ON" or "auto-copy All OFF")
    if on then
        doAutoCopyAll()
    end
end, { sub = "combat remotes + last 40 logs" })

clientStatusLbl = Instance.new("TextLabel")
clientStatusLbl.BackgroundTransparency = 1
clientStatusLbl.Size = UDim2.new(1, 0, 0, 16)
clientStatusLbl.Font = Enum.Font.Gotham
clientStatusLbl.TextSize = 11
clientStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
clientStatusLbl.TextColor3 = COLORS.muted
clientStatusLbl.Text = "Client bereit · Auto-Copy AN"
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

makeButton("Client", "COPY Client", COLORS.lime, function()
    if copyClip(buildClientDump()) then
        ST.lastCopy = os.date("%H:%M:%S")
        setClientStatus("Client kopiert @ " .. ST.lastCopy, true)
        notify("DXLTA", "Client dump kopiert", 2)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeButton("Client", "COPY Errors", Color3.fromRGB(200, 90, 70), function()
    if copyClip(errorText()) then
        setClientStatus("Errors kopiert (" .. tostring(#errorRing) .. ")", true)
        notify("DXLTA", "Errors kopiert", 2)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeButton("Client", "COPY Logs", Color3.fromRGB(120, 180, 70), function()
    if copyClip(ringText()) then
        setClientStatus("Logs kopiert (" .. tostring(#ringLog) .. ")", true)
        notify("DXLTA", "Logs kopiert", 2)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

makeButton("Client", "COPY All", COLORS.limeSoft, function()
    if copyClip(buildAllBundle()) then
        ST.lastCopy = os.date("%H:%M:%S")
        setClientStatus("All kopiert @ " .. ST.lastCopy, true)
        notify("DXLTA", "All bundle kopiert — pasten", 3)
    else
        setClientStatus("Clipboard unavailable", false)
    end
end)

sectionLabel("Client", "Scan")
scoutFilterBox = Instance.new("TextBox")
scoutFilterBox.Name = "ScanFilter"
scoutFilterBox.PlaceholderText = "Filter: Remote, CommF, Net…"
scoutFilterBox.Text = ""
scoutFilterBox.ClearTextOnFocus = false
scoutFilterBox.Size = UDim2.new(1, 0, 0, 36)
scoutFilterBox.BackgroundColor3 = COLORS.ink
scoutFilterBox.TextColor3 = COLORS.text
scoutFilterBox.PlaceholderColor3 = COLORS.muted
scoutFilterBox.Font = Enum.Font.Code
scoutFilterBox.TextSize = 12
scoutFilterBox.TextXAlignment = Enum.TextXAlignment.Left
scoutFilterBox.LayoutOrder = nextOrder("Client")
scoutFilterBox.Parent = parentOf("Client")
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = scoutFilterBox
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(40, 48, 50)
    s.Thickness = 1
    s.Transparency = 0.35
    s.Parent = scoutFilterBox
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = scoutFilterBox
end

local scoutPreviewWrap = Instance.new("Frame")
scoutPreviewWrap.Size = UDim2.new(1, 0, 0, 100)
scoutPreviewWrap.BackgroundColor3 = COLORS.ink
scoutPreviewWrap.BorderSizePixel = 0
scoutPreviewWrap.LayoutOrder = nextOrder("Client")
scoutPreviewWrap.Parent = parentOf("Client")
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = scoutPreviewWrap
end

local scoutScroll = Instance.new("ScrollingFrame")
scoutScroll.Size = UDim2.new(1, -8, 1, -6)
scoutScroll.Position = UDim2.fromOffset(4, 3)
scoutScroll.BackgroundTransparency = 1
scoutScroll.BorderSizePixel = 0
scoutScroll.ScrollBarThickness = 3
scoutScroll.ScrollBarImageColor3 = COLORS.limeDim
scoutScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scoutScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scoutScroll.Parent = scoutPreviewWrap

scoutPreviewLbl = Instance.new("TextLabel")
scoutPreviewLbl.BackgroundTransparency = 1
scoutPreviewLbl.Size = UDim2.new(1, -4, 0, 0)
scoutPreviewLbl.AutomaticSize = Enum.AutomaticSize.Y
scoutPreviewLbl.Font = Enum.Font.Code
scoutPreviewLbl.TextSize = 10
scoutPreviewLbl.TextXAlignment = Enum.TextXAlignment.Left
scoutPreviewLbl.TextYAlignment = Enum.TextYAlignment.Top
scoutPreviewLbl.TextColor3 = COLORS.muted
scoutPreviewLbl.TextWrapped = true
scoutPreviewLbl.Text = "(SCAN für Remotes)"
scoutPreviewLbl.Parent = scoutScroll

local function setScoutPreview(text)
    local t = tostring(text or "")
    if #t > 2800 then
        scoutPreviewLbl.Text = t:sub(1, 2800) .. "\n… truncated"
    else
        scoutPreviewLbl.Text = t ~= "" and t or "(leer)"
    end
end

makeButton("Client", "SCAN", Color3.fromRGB(90, 140, 60), function()
    setClientStatus("Scanning…", nil)
    task.wait()
    local view, filteredLines, total = runScoutScan(scoutFilterBox.Text)
    setScoutPreview(view)
    setClientStatus(string.format("Scan · %d Zeilen · Ansicht %d", total, #filteredLines), true)
    ringPush("scan " .. tostring(total) .. " lines")
end)

switchTab("Start")

-- Smooth open scale 0.96 → 1
panel.Size = UDim2.fromScale(0.9 * 0.96, 0.55 * 0.96)
pcall(function()
    TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(0.9, 0.55),
    }):Play()
end)

-- ── LEFT reopen orb 48px @ (0,14,0.42,0) ─────────────────────────────────────

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
    panel.Visible = vis
    orb.Enabled = not vis
    if vis then
        panel.Size = UDim2.fromScale(0.9 * 0.96, 0.55 * 0.96)
        pcall(function()
            TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.fromScale(0.9, 0.55),
            }):Play()
        end)
    end
end

minBtn.MouseButton1Click:Connect(function()
    setPanelVisible(false)
    ringPush("panel minimized · left orb")
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
        if panel.Parent then
            setPanelVisible(not STATE.panelVisible)
        end
    end
end))

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

-- Silent aura ~0.12s when killAura (farm has its own tick loop)
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

-- Farm / fastFarm driver ~0.1s
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

-- Auto-Copy trimmed bundle every 3s
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
        if statusBlockLbl then
            statusBlockLbl.Text = statusBlockText()
        end
        if liveLabels.lastCopy then
            liveLabels.lastCopy.Text = tostring(ST.lastCopy)
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
    ringPush("v2.3 travel 220 · stream · Godhuman equip")
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

notify("DXLTA", "BF Panel v2.3 · left D orb · locked Hit(hum)", 4)
print("[DXLTA] BF Panel ready — panel.lua v2.3")
print("[DXLTA] Locked: Modules.Net RE/RegisterAttack:FireServer(0.5) → RE/RegisterHit:FireServer(hum)")
print("[DXLTA] Minimize → left lime D orb @ UDim2.new(0,14,0.42,0)")

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
