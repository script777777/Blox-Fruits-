--[[
    DXLTA / Void Hub  v5.7c
    Renamed from secrethub.lua — live copy for script777777/Blox-Fruits-
    5.7c: crash-safe boot (no game.__index / no eager namecall)

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/voidhub-live-ff0d/voidhub.lua"))()
]]

-- =====================================================================
-- Startup safety net (V2.2)
-- The very first thing the script does is show a Roblox notification, so a start is never silent.
-- The whole hub then runs inside xpcall: any top-level error is shown as a notification with the
-- message (and copied to the clipboard if the executor can), instead of the script dying invisibly.
-- =====================================================================
local SH_NOTIFY = function(title, text, dur)
    task.spawn(function()
        for _ = 1, 8 do -- SetCore is not ready in the first moments after joining; retry briefly
            local ok = pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {Title = tostring(title), Text = tostring(text):sub(1, 220), Duration = dur or 5})
            end)
            if ok then return end
            task.wait(1)
        end
    end)
end
SH_NOTIFY("Void Hub", "Loading...", 4)
local SH_OK, SH_ERR = xpcall(function()
local SVC, GV = {}, {} -- V2.2: services / constants / per-frame state live here (keeps every scope far below Luau's 200-local limit)

-- =====================================================================
-- 0. Duplicate-execution guard
-- =====================================================================
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__VoidHub and type(ENV.__VoidHub.unload) == "function" then
    pcall(ENV.__VoidHub.unload, true)
elseif ENV.__SecretHub and type(ENV.__SecretHub.unload) == "function" then
    pcall(ENV.__SecretHub.unload, true)
end
ENV.__VoidHub = {}
ENV.__SecretHub = ENV.__VoidHub -- legacy alias for older unloaders
local HUB = ENV.__VoidHub
HUB.tier = nil -- "free" | "premium" | nil (choose on Start)
HUB.version = "5.7c"
HUB.session = {dodges = 0, saves = 0, kills = 0, learned = 0, blocks = 0, started = os.clock()}

-- =====================================================================
-- 1. Services
-- =====================================================================
SVC.RobloxSettings = settings  -- captured before the local settings table shadows it
local function svc(n) return game:GetService(n) end
local Players = svc("Players")
SVC.TweenService = svc("TweenService")
local UserInputService = svc("UserInputService")
SVC.RunService = svc("RunService")
SVC.HttpService = svc("HttpService")
SVC.MarketplaceService = svc("MarketplaceService")
SVC.Lighting = svc("Lighting")
SVC.TeleportService = svc("TeleportService")
SVC.Stats = svc("Stats")
SVC.GuiService = svc("GuiService")
SVC.CoreGui = svc("CoreGui")

local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end

-- =====================================================================
-- 2. Config + theme
-- =====================================================================
-- Brand: set to "rbxassetid://<id>" after uploading the logo to Roblox to use the real image;
-- empty = the built-in vector rebuild of the logo (Frames + gradients).
GV.LOGO_IMAGE_ID = ""
GV.SALT = "SecretHub#v1" -- keep: existing Premium keys still hash the same
GV.KEY_HASH = "a9ccfefc28180d80"
GV.KEY_FILE = "SecretHub_key.txt" -- keep filename so Premium keys stay saved
GV.TIER_FILE = "VoidHub_tier.txt"
GV.FAV_FILE = "SecretHub_favorites.json"
GV.HIST_FILE = "SecretHub_history.json"
GV.SETTINGS_FILE = "SecretHub_settings.json"
GV.WAYPOINT_FILE = "SecretHub_waypoints.json"
GV.PROFILE_FILE = "SecretHub_profiles.json"
GV.SB = "https://scriptblox.com"
GV.DISCORD_INVITE = "https://discord.gg/Rn9Bh7CwAr" -- Get Key / Premium key source

-- Palette (4.2), taken from the ninja badge: ink black base, charcoal / steel greys, white highlights.
-- White glowing eyes are the signature accent; colour is only used for status (green / yellow / red).
-- The old key names are kept (gold = accent, purple = secondary, spirit = Guardian glow) so every page picks the look up.
local C = {
    bg = Color3.fromRGB(6, 6, 7),
    panel = Color3.fromRGB(10, 10, 11),
    glass = Color3.fromRGB(14, 14, 15),
    card = Color3.fromRGB(17, 17, 18),
    cardHover = Color3.fromRGB(26, 26, 28),
    purple = Color3.fromRGB(46, 46, 49),        -- strokes / secondary surfaces (steel)
    purpleDark = Color3.fromRGB(23, 23, 25),    -- selected / pressed surfaces
    gold = Color3.fromRGB(242, 242, 242),       -- ACCENT (badge white)
    goldLight = Color3.fromRGB(200, 200, 204),  -- light steel
    goldDark = Color3.fromRGB(78, 78, 82),      -- accent shadow
    text = Color3.fromRGB(238, 238, 238),
    sub = Color3.fromRGB(138, 138, 142),
    faint = Color3.fromRGB(72, 72, 76),
    line = Color3.fromRGB(34, 34, 36),
    green = Color3.fromRGB(92, 200, 140),
    yellow = Color3.fromRGB(226, 184, 82),
    red = Color3.fromRGB(226, 64, 72),
    ink = Color3.fromRGB(8, 8, 9),              -- text on accent surfaces (accent is white)
    spirit = Color3.fromRGB(236, 236, 240),     -- Guardian glow (white rim, fingertips, strings)
    spiritCore = Color3.fromRGB(255, 255, 255),
    violet = Color3.fromRGB(120, 120, 126),     -- secondary steel (kept name for older calls)
    smoke = Color3.fromRGB(16, 16, 18),         -- ink-smoke core of the shadow hands
    steel = Color3.fromRGB(112, 112, 116),
    sharingan = Color3.fromRGB(200, 28, 40),    -- ONLY for the Sharingan threat outline
    logoA = Color3.fromRGB(255, 255, 255),
    logoB = Color3.fromRGB(200, 200, 204),
}
local function pickFont(names, fallback)
    for _, n in ipairs(names) do
        local ok, f = pcall(function() return Enum.Font[n] end)
        if ok and f then return f end
    end
    return fallback
end
local F = {
    black = pickFont({"GothamBold"}, Enum.Font.GothamBold),     -- no more GothamBlack: heavy type looked cheap
    bold = pickFont({"GothamBold"}, Enum.Font.GothamBold),
    medium = pickFont({"GothamMedium"}, Enum.Font.GothamMedium),
    reg = pickFont({"Gotham"}, Enum.Font.Gotham),
    display = pickFont({"BuilderSansExtraBold", "GothamBold"}, Enum.Font.GothamBold),
    mono = pickFont({"RobotoMono", "Code"}, Enum.Font.Code),
}
-- letter-spaced display text ("VOID HUB" -> "S E C R E T   H U B")
local function spaced(t)
    -- UTF-8 aware so "·" / "—" stay intact
    local pat = (utf8 and utf8.charpattern) or "[%z\1-\127\194-\244][\128-\191]*"
    return (string.gsub(string.upper(tostring(t)), "(" .. pat .. ")", "%1 "):gsub("%s+$", ""))
end

-- =====================================================================
-- 3. Lifecycle (maid)
-- =====================================================================
local alive = true
local conns, instances, unloadHooks = {}, {}, {}
local function bind(c) conns[#conns + 1] = c return c end
local function own(i) instances[#instances + 1] = i return i end
local function onUnload(f) unloadHooks[#unloadHooks + 1] = f end

-- Performance state (Performance Mode = no looping effects, no particles, no ripples)
local PERF = {lite = false}
GV.TMAX = 0.25  -- longest UI tween allowed (snappy on phones)

-- 4.1 core registry (one local to stay far below Luau's 200-locals limit)
--   dbg   : debug console ring buffer (Settings > Debug console)
--   life  : respawn lifecycle; every module re-binds itself on CharacterAdded
--   sense / move / abil / ggod / stalk : filled by section 14n
local CORE = {dbg = {lines = {}, max = 240, n = 0}, life = {handlers = {}, died = {}, gen = 0}, sense = {}, move = {}, abil = {}, ggod = {}, stalk = {}}
function CORE.log(kind, msg)
    local d = CORE.dbg
    d.n += 1
    d.lines[#d.lines + 1] = os.date("%H:%M:%S") .. "  " .. tostring(kind) .. "  " .. tostring(msg)
    if #d.lines > d.max then table.remove(d.lines, 1) end
    d.dirty = true
end

-- Single dispatcher for per-frame work.
-- 4.0 bug: a job that errored ONCE was removed forever, which is why features died after respawn.
-- Now: errors are logged (throttled), a job that keeps failing is paused for 2 s and then retried,
-- and all pauses are cleared on every respawn.
local heartbeatJobs, renderJobs = {}, {}
local jobState = {}
local function onHeartbeat(name, fn) heartbeatJobs[name] = fn end
local function onRender(name, fn) renderJobs[name] = fn end
local function runJob(kind, name, fn, dt)
    local st = jobState[name]
    if st and st.pauseUntil then
        if os.clock() < st.pauseUntil then return end
        st.pauseUntil = nil
    end
    local ok, err = pcall(fn, dt)
    if not ok then
        local t = os.clock()
        if not st then st = {n = 0, t0 = t, total = 0} jobState[name] = st end
        if t - st.t0 > 10 then st.n = 0 st.t0 = t end
        st.n += 1
        st.total += 1
        if st.total <= 3 or st.total % 100 == 0 then CORE.log("ERR", kind .. " '" .. name .. "': " .. tostring(err)) end
        if st.n >= 30 then
            st.pauseUntil = t + 2
            st.n = 0
            CORE.log("WARN", kind .. " '" .. name .. "' paused for 2 s after repeated errors")
        end
    end
end
function CORE.resetJobs() for _, st in pairs(jobState) do st.pauseUntil = nil st.n = 0 end end
function CORE.jobErrors() local n = 0 for _, st in pairs(jobState) do n += st.total end return n end
bind(SVC.RunService.Heartbeat:Connect(function(dt)
    if not alive then return end
    for name, fn in pairs(heartbeatJobs) do runJob("job", name, fn, dt) end
end))
bind(SVC.RunService.RenderStepped:Connect(function(dt)
    if not alive then return end
    for name, fn in pairs(renderJobs) do runJob("render", name, fn, dt) end
end))
-- lifecycle: CORE.onChar(name, fn(char)) runs now (if a character exists) and after every respawn
function CORE.onChar(name, fn) CORE.life.handlers[name] = fn end
function CORE.onDied(name, fn) CORE.life.died[name] = fn end
-- V2.1: every feature module loads protected. A module that errors is logged (Console tab) and
-- skipped; it can never stop the rest of the script or the panel from loading again.
HUB.moduleErrors = {}
function CORE.safeModule(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        CORE.log("ERR", "module '" .. name .. "' failed to load: " .. tostring(err))
        table.insert(HUB.moduleErrors, name .. ": " .. tostring(err))
    end
end

-- =====================================================================
-- 4. Utilities
-- =====================================================================
local function hubHash(s)
    s = GV.SALT .. s
    local h1, h2 = 2166136261, 5381
    for i = 1, #s do
        local b = string.byte(s, i)
        h1 = (h1 * 131 + b) % 4294967291
        h2 = (h2 * 65599 + b) % 4294967279
    end
    return string.format("%08x%08x", h1, h2)
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function exfn(name)
    local f = rawget(ENV, name)
    if type(f) ~= "function" then f = rawget(_G, name) end
    if type(f) ~= "function" then pcall(function() f = getfenv(0)[name] end) end
    return type(f) == "function" and f or nil
end

local fsWrite, fsRead, fsIsFile = exfn("writefile"), exfn("readfile"), exfn("isfile")
local function save(path, data) if fsWrite then pcall(fsWrite, path, data) end end
local function loadFile(path)
    if not fsRead then return nil end
    if fsIsFile then
        local ok, ex = pcall(fsIsFile, path)
        if not ok or not ex then return nil end
    end
    local ok, r = pcall(fsRead, path)
    if ok and type(r) == "string" then return r end
    return nil
end
local function jsonDecode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, d = pcall(function() return SVC.HttpService:JSONDecode(s) end)
    return ok and d or nil
end
local function jsonEncode(t)
    local ok, s = pcall(function() return SVC.HttpService:JSONEncode(t) end)
    return ok and s or "{}"
end
local function loadJSON(path, default)
    local d = jsonDecode(loadFile(path))
    if type(d) == "table" then return d end
    return default
end

local function copy(text)
    local f = exfn("setclipboard") or exfn("toclipboard") or (syn and syn.write_clipboard)
    if f then return (pcall(f, tostring(text))) end
    return false
end

local requestFn = exfn("request") or exfn("http_request") or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
-- request / http_request first, game:HttpGet as fallback; the last outcome is kept in HUB.httpStatus for the UI
local function httpGet(url)
    local why
    if requestFn then
        local ok, res = pcall(requestFn, {Url = url, Method = "GET", Headers = {["User-Agent"] = "VoidHub/5.6", ["Accept"] = "application/json"}})
        if ok and type(res) == "table" and type(res.Body) == "string" and (res.StatusCode == nil or (res.StatusCode >= 200 and res.StatusCode < 300)) then
            HUB.httpStatus = "request OK"
            return res.Body
        end
        why = ok and ("request HTTP " .. tostring(type(res) == "table" and res.StatusCode or "?")) or "request error"
    end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(body) == "string" then HUB.httpStatus = "HttpGet OK" return body end
    HUB.httpStatus = (why and (why .. ", ") or (requestFn and "" or "no request(), ")) .. "HttpGet failed"
    return nil
end
local function getJSON(url)
    local d = jsonDecode(httpGet(url))
    if type(d) == "table" then return d end
    return nil
end
-- Small in-memory cache for ScriptBlox responses (fewer requests, instant tab switching)
local jsonCache = {}
local function cachedJSON(url, ttl)
    local c = jsonCache[url]
    if c and os.clock() - c.t < (ttl or 120) then return c.d end
    local d = getJSON(url)
    if d then jsonCache[url] = {t = os.clock(), d = d} end
    return d
end
local function clearCache() jsonCache = {} end
local function enc(s)
    local ok, r = pcall(function() return SVC.HttpService:UrlEncode(tostring(s)) end)
    return ok and r or tostring(s)
end

local function tween(o, t, props, style, dir)
    if typeof(o) ~= "Instance" then return nil end
    if t > GV.TMAX and style ~= Enum.EasingStyle.Linear and not o:IsA("BasePart") then t = GV.TMAX end
    local ok, tw = pcall(function()
        return SVC.TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    end)
    if ok and tw then tw:Play() return tw end
    return nil
end
local function spring(o, t, props) return tween(o, t, props, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end
-- uncapped tween for cinematic moments (loading screen, Guardian voice)
local function tweenL(o, t, props, style, dir)
    if typeof(o) ~= "Instance" then return nil end
    local ok, tw = pcall(function()
        return SVC.TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    end)
    if ok and tw then tw:Play() return tw end
    return nil
end

local function new(class, props, children)
    local o = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    for _, ch in ipairs(children or {}) do ch.Parent = o end
    if parent then o.Parent = parent end
    return o
end
-- 4.2 ninja style: crisp, near-square corners everywhere (katana edge look); only true circles / pills (>= 30) stay round
local function corner(r)
    r = r or 10
    if r < 30 then r = math.min(r, 2) end
    return new("UICorner", {CornerRadius = UDim.new(0, r)})
end
local function pad(l, r, t, b)
    return new("UIPadding", {PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0)})
end
local function stroke(col, th, tr)
    return new("UIStroke", {Color = col or C.gold, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
-- accent surface gradient: white -> pale blue-white, like the logo
local function goldGradient(rot)
    return new("UIGradient", {Rotation = rot or 90, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 176, 180))})})
end
-- animated window edge: mostly a dim steel line, one white blade glint travelling around it
local function borderGradient()
    return new("UIGradient", {Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.line), ColorSequenceKeypoint.new(0.38, C.line), ColorSequenceKeypoint.new(0.5, C.gold),
        ColorSequenceKeypoint.new(0.62, C.line), ColorSequenceKeypoint.new(1, C.line)})})
end
local function label(parent, props)
    local p = {BackgroundTransparency = 1, Font = F.medium, TextColor3 = C.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "", Parent = parent}
    for k, v in pairs(props or {}) do p[k] = v end
    return new("TextLabel", p)
end

local function fmtNum(n)
    n = tonumber(n) or 0
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) elseif n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end
local function fmtTime(s)
    s = math.floor(s)
    return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
local function fmtDate(iso)
    if type(iso) ~= "string" then return "-" end
    local y, m, d = iso:match("^(%d+)%-(%d+)%-(%d+)")
    if not y then return "-" end
    local months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
    return (months[tonumber(m)] or m) .. " " .. tonumber(d) .. ", " .. y
end
local function countKeys(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
-- V2.4 safety: an UNEATEN devil fruit is a Tool too ("Flame Fruit"); activating it eats it. Nothing that
-- equips / activates tools for you (Shadow Strikes, Auto-click, Auto-heal, Ability Assist, Finisher,
-- Level Farm) may ever touch one. Eaten fruit powers have ToolTip "Blox Fruit" and stay usable.
function GV.isFruitItem(t)
    if typeof(t) ~= "Instance" or not t:IsA("Tool") then return false end
    local tip = ""
    pcall(function() tip = tostring(t.ToolTip or "") end)
    if tip == "Blox Fruit" then return false end
    local n = string.lower(t.Name)
    return string.find(n, "%f[%a]fruit%f[%A]") ~= nil or string.find(n, "fruit$") ~= nil
end

-- Animated helpers driven by the dispatcher
local spinners, pulses, shimmers = {}, {}, {}
GV.animAcc = 0
onHeartbeat("anim", function(frameDt)
    if PERF.lite then return end
    GV.animAcc += frameDt
    if GV.animAcc < 1 / 30 then return end
    local dt = GV.animAcc
    GV.animAcc = 0
    local t = os.clock()
    for i = #spinners, 1, -1 do
        local g = spinners[i]
        if g.Parent then g.Rotation = (g.Rotation + dt * 28) % 360 else table.remove(spinners, i) end
    end
    local p = 0.35 + 0.3 * (0.5 + 0.5 * math.sin(t * 2))
    for i = #pulses, 1, -1 do
        local s = pulses[i]
        if s.Parent then s.Transparency = p else table.remove(pulses, i) end
    end
    local off = ((t * 0.22) % 2.6) - 1.3
    for i = #shimmers, 1, -1 do
        local g = shimmers[i]
        if g.Parent then g.Offset = Vector2.new(off * 1.6, 0) else table.remove(shimmers, i) end
    end
end)
local function animatedBorder(parent, th)
    local s = stroke(Color3.new(1, 1, 1), th or 2, 0)
    s.Parent = parent
    local g = borderGradient()
    g.Parent = s
    spinners[#spinners + 1] = g
    return s
end
-- Gold shimmer sweep for titles
local function shimmerText(lbl)
    local g = new("UIGradient", {Parent = lbl, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.text), ColorSequenceKeypoint.new(0.44, C.text), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.56, C.text), ColorSequenceKeypoint.new(1, C.text)})})
    shimmers[#shimmers + 1] = g
    return g
end

-- Sounds (built-in client sounds; failures are ignored)
local function sound(id, vol, pitch)
    task.spawn(function()
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol or 0.25
            s.PlaybackSpeed = pitch or 1
            s.Parent = svc("SoundService")
            s:Play()
            task.delay(2, function() pcall(function() s:Destroy() end) end)
        end)
    end)
end
GV.SND_TICK = "rbxasset://sounds/electronicpingshort.wav"
GV.SND_CLICK = "rbxasset://sounds/button.wav"

-- =====================================================================
-- 5. Settings
-- =====================================================================
GV.DEFAULTS = {
    walkspeed = 16, jumppower = 50, fov = 70, gravity = 196.2, clock = 14, flyspeed = 60, freecamspeed = 40,
    infjump = false, noclip = false, fly = false, antiafk = true, fullbright = false, esp = false,
    antifling = false, antivoid = true, clicktp = false, nofog = false, lowgfx = false, hud = false,
    autorejoin = false, freecam = false, timeOverride = false, gravityOverride = false,
    staffAction = "Notify", panicSafeSpot = true, accent = 5, particles = true, sounds = true,
    uiscale = 100, confirmRun = true, autoProfile = false, closeAfterRun = true,
    brainOn = true, brainLimit = true, autoProtect = true, threatEsp = true, hazardShield = false, autoHeal = false,
    aggression = false, aggroNpc = true, aggroPvp = false, aggroOneShot = true, aggroSkills = true, aggroCombo = true,
    aggroLock = true, aggroRange = 20, aggroRate = 4,
    godmode = false, autododge = false, antigrab = false, antifreeze = false, radar = false, vfx = true,
    fxAura = false, fxAwaken = true, fxSixth = true, fxHeartbeat = true, fxBolt = true, fxHex = true, fxDomain = true,
    fxGodForm = true, voice = true, voiceTyping = false, voiceTaunts = true, voiceChat = true,
    npcdef = false, ghost = false, magnet = false, magnetRadius = 25,
    handsOn = true, handsPuppet = false, handsRescue = true, handsLift = false, handsAlways = false, handsVisual = false, rescueThreshold = 35, npcEvade = false,
    puppetMove = true, puppetStrength = 60, puppetStyle = "Duelist", catchFall = true, abilAssist = false, abilGui = false,
    stalker = true, stalkerSafe = false, fxSharingan = false, dbgVerbose = false,
    choreo = false, choreoReturn = true, aoeTele = false, finisher = false, finisherKey = "", finisherHp = 10, lootGrab = false,
    shadowM1 = false, m1Range = 12, m1Rate = 3, m1Combo = false, stunBreak = false, healTiming = false, healAt = 40,
    puppetHold = false, holdRadius = 30, holdLeash = 60, holdGoSpawn = false, scanner = true,
    awakenPve = true, kamui = false, kamuiHp = 30, radarWorld = true, introHands = false, farm = false,
    rescueStart = 45, rescueSafe = 80, handsGrab = true, waterGuard = true,
    voidNet = false, netChat = true, netRange = 40, netPlayers = false, netOrbit = false,
    voidOverride = false, ovrLearn = true, ovrAmplify = true, ovrAmp = 5, ovrReplay = false,
    ovrProbe = false, ovrOneShot = false, ovrHeal = false, ovrPvp = false, ovrRate = 4, ovrRange = 50,
    ovrHitbox = true, ovrHitboxAmp = 3, ovrParasite = false, ovrCdStrip = false, ovrSoftGod = false,
    ovrDominion = false, ovrMaps = true, voidSiphon = false,
    ovrMirror = false, ovrMarket = false,
    combatAim = false, aimCam = true, aimBody = true, aimSilent = false, aimMove = false,
    aimRange = 80, aimFov = 180, aimPlayers = true, aimStick = true,
    antiDeath = true, quietDeath = true,
    bfFruitNotify = true, bfFruitEsp = false, bfFruitSnipe = false, bfChest = false, bfFarm = false, bfQuest = false, bfStats = false,
    bfStat = "Melee", bfWeapon = "Melee", bfBuso = false, bfBusoVia = "J key", bfKen = false, bfSpeed = 150,
    instantprompts = false, autointeract = false, interactFilter = "", autoclick = false, clickrate = 8,
    xray = false, xrayAmount = 0.6, nightvision = false, walkwater = false, maxzoom = false, camnoclip = false,
    binds = {toggleUI = "RightShift", panic = "P", fly = "F", noclip = "N", esp = "", infjump = "",
        freecam = "", fullbright = "", xray = "", autointeract = "", safespot = "", domain = "", godform = "", lift = ""},
    stats = {runs = 0},
}
local settings = loadJSON(GV.SETTINGS_FILE, {})
for k, v in pairs(GV.DEFAULTS) do
    if settings[k] == nil then settings[k] = v end
end
if type(settings.binds) ~= "table" then settings.binds = {} end
for k, v in pairs(GV.DEFAULTS.binds) do if settings.binds[k] == nil then settings.binds[k] = v end end
if type(settings.stats) ~= "table" then settings.stats = {runs = 0} end
-- 4.0 migration: the old bubble aura is gone; the new subtle aura starts off
if settings.v4 ~= true then settings.v4 = true settings.fxAura = false end
-- 4.1 migration: the old "Godmode attempt" was health refill only; Guardian Godmode is a new system and starts off
if settings.v41 ~= true then settings.v41 = true settings.godmode = false end
-- V2.3 migration: the Lifeline replaces the old rescue; switch the rescue back on once (older builds could leave it off)
if settings.v53 ~= true then settings.v53 = true settings.handsRescue = true end
-- V2.5 / 5.5 / 5.7: hand models are gone for good — control stays, visuals never come back
settings.handsVisual = false
settings.handsPuppet = false
-- 5.7b kept once; 5.7c: SAFE BOOT — Combat Aim + silent hooks OFF (game.__index hard-closed Roblox)
if settings.v57b ~= true then
    settings.v57b = true
    settings.aimPlayers = true
    settings.aimCam = true
    settings.aimBody = true
    settings.aimFov = 180
    settings.aimRange = math.max(tonumber(settings.aimRange) or 55, 80)
    settings.antiDeath = true
    settings.quietDeath = true
end
if settings.v57c ~= true then
    settings.v57c = true
    settings.combatAim = false
    settings.aimSilent = false
    settings.aimMove = false
end
settings.handsAlways = false
settings.introHands = false
settings.v55 = true
settings.v57 = true
-- 5.6: aggression stays OFF until the user flips it (never auto-on)
if settings.v56 ~= true then
    settings.v56 = true
    settings.aggression = false
    settings.aggroPvp = false
end
-- Performance Mode: decided once (auto-on for phones / tablets), then user-controlled
if type(settings.perf) ~= "boolean" then
    settings.perf = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
PERF.lite = settings.perf
GV.saveQueued = false
GV.BRAIN_FILE = "SecretHub_brain.json"
local function saveSettings()
    if GV.saveQueued then return end
    GV.saveQueued = true
    task.delay(0.5, function()
        GV.saveQueued = false
        -- temporary overrides (Awakening / Farm Brain) are never written: save the user's own values
        local OV = CORE.override
        local out = settings
        if OV and next(OV.count) then
            out = {}
            for k, v in pairs(settings) do out[k] = v end
            for k, n in pairs(OV.count) do if n > 0 then out[k] = OV.orig[k] end end
        end
        save(GV.SETTINGS_FILE, jsonEncode(out))
    end)
end
local favs = loadJSON(GV.FAV_FILE, {})
local history = loadJSON(GV.HIST_FILE, {})
if type(favs) ~= "table" then favs = {} end
if type(history) ~= "table" then history = {} end

-- =====================================================================
-- 6. Root GUI (gethui > protect_gui+CoreGui > CoreGui > PlayerGui)
-- =====================================================================
local gui = new("ScreenGui", {Name = SVC.HttpService:GenerateGUID(false):sub(1, 8), ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 999})
do
    local placed = false
    local gethui = exfn("gethui")
    if gethui then placed = pcall(function() gui.Parent = gethui() end) end
    if not placed and syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
        placed = pcall(function() gui.Parent = SVC.CoreGui end)
    end
    if not placed then placed = pcall(function() gui.Parent = SVC.CoreGui end) end
    if not placed then gui.Parent = LP:WaitForChild("PlayerGui") end
end
own(gui)

local uiScale = new("UIScale", {Parent = gui})
local viewport = Vector2.new(1280, 720)
-- Three layouts: "portrait" (phone upright, bottom nav), "compact" (landscape phone ~800x360), "desktop"
local function layoutMode()
    if viewport.X < viewport.Y or viewport.X < 560 then return "portrait" end
    if viewport.Y < 520 then return "compact" end
    return "desktop"
end
local layoutListeners = {}
local function rescale()
    local cam = workspace.CurrentCamera
    viewport = cam and cam.ViewportSize or viewport
    local mode = layoutMode()
    local s
    if mode == "portrait" then s = math.min(viewport.X / 400, viewport.Y / 640)
    elseif mode == "compact" then s = math.min(viewport.X / 700, viewport.Y / 380)
    else s = math.min(viewport.X / 820, viewport.Y / 560) end
    uiScale.Scale = clamp(s * ((tonumber(settings.uiscale) or 100) / 100), 0.45, 1.4)
    for _, f in ipairs(layoutListeners) do pcall(f, mode) end
end
rescale()
local function hookCamera()
    local cam = workspace.CurrentCamera
    if cam then bind(cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)) end
end
hookCamera()
bind(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() hookCamera() rescale() end))
local isTouch = UserInputService.TouchEnabled
GV.ROW_H = isTouch and 52 or 46     -- row height (touch targets >= 40px)
GV.BTN_H = isTouch and 40 or 32     -- button height

-- =====================================================================
-- 7. Micro-interactions
-- =====================================================================
-- 4.2 ninja style kit: katana slash marks, angled dividers, blade-shine sweeps (one table = one local register)
local NJ = {}
-- a short 45-degree slash across a corner ("tl", "tr", "bl", "br"): the katana edge cut of every surface
function NJ.slash(parent, where, len, z, tr, col)
    len = len or 14
    local ax = (where == "tr" or where == "br") and 1 or 0
    local ay = (where == "bl" or where == "br") and 1 or 0
    local rot = (where == "tl" or where == "br") and -45 or 45
    local inset = len * 0.36
    return new("Frame", {Parent = parent, Name = "NinjaSlash", BorderSizePixel = 0, BackgroundColor3 = col or Color3.new(1, 1, 1), BackgroundTransparency = tr or 0.35,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(ax, ax == 1 and -inset or inset, ay, ay == 1 and -inset or inset),
        Size = UDim2.new(0, len, 0, 1), Rotation = rot, ZIndex = z or 8})
end
-- angled divider: a hairline that fades at both ends, with a small diamond "tsuba" in the middle
function NJ.divider(parent, pos, width, z, tr)
    local d = new("Frame", {Parent = parent, BorderSizePixel = 0, BackgroundColor3 = C.gold, BackgroundTransparency = tr or 0.55, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = pos, Size = UDim2.new(0, width or 120, 0, 1), ZIndex = z or 6},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    new("Frame", {Parent = d, BorderSizePixel = 0, BackgroundColor3 = C.gold, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 5, 0, 5), Rotation = 45, ZIndex = (z or 6) + 1})
    return d
end
-- blade shine: one slanted light band sweeping across a surface (gradient slant, so ClipsDescendants still works)
function NJ.shine(obj, dur, tr)
    if PERF.lite or not obj or not obj.Parent then return end
    if obj:FindFirstChildWhichIsA("UIGridStyleLayout") then return end   -- a layout would grab the shine frame
    local sh = obj:FindFirstChild("BladeShine")
    if not sh then
        pcall(function() obj.ClipsDescendants = true end)
        sh = new("Frame", {Parent = obj, Name = "BladeShine", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = tr or 0.86,
            Size = UDim2.new(0, 34, 1, 0), ZIndex = (obj.ZIndex or 1) + 2},
            {new("UIGradient", {Rotation = 20, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    end
    sh.Visible = true
    sh.Position = UDim2.new(0, -40, 0, 0)
    tween(sh, dur or 0.45, {Position = UDim2.new(1, 6, 0, 0)}, Enum.EasingStyle.Sine)
end
local function hoverScale(btn, amount)
    local sc = btn:FindFirstChild("HoverScale") or new("UIScale", {Name = "HoverScale", Parent = btn})
    amount = amount or 1.03
    if not isTouch then
        bind(btn.MouseEnter:Connect(function() tween(sc, 0.12, {Scale = amount}) if btn:IsA("GuiButton") and btn.AbsoluteSize.X > 40 then NJ.shine(btn) end end))
        bind(btn.MouseLeave:Connect(function() tween(sc, 0.12, {Scale = 1}) end))
    end
    bind(btn.MouseButton1Down:Connect(function() tween(sc, 0.06, {Scale = 0.96}) end))
    bind(btn.MouseButton1Up:Connect(function() tween(sc, 0.15, {Scale = 1}) end))
    return sc
end
local function ripple(btn, x, y)
    if PERF.lite then return end
    pcall(function()
        btn.ClipsDescendants = true
        local ap = btn.AbsolutePosition
        local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.2
        local px, py = (x or (ap.X + btn.AbsoluteSize.X / 2)) - ap.X, (y or (ap.Y + btn.AbsoluteSize.Y / 2)) - ap.Y
        local r = new("Frame", {Parent = btn, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, px / uiScale.Scale, 0, py / uiScale.Scale), Size = UDim2.new(0, 0, 0, 0), ZIndex = (btn.ZIndex or 1) + 1}, {corner(999)})
        tween(r, 0.25, {Size = UDim2.new(0, sz, 0, sz), BackgroundTransparency = 1})
        task.delay(0.3, function() pcall(function() r:Destroy() end) end)
    end)
end
local function clickable(btn, fn)
    hoverScale(btn)
    bind(btn.MouseButton1Click:Connect(function()
        local m = UserInputService:GetMouseLocation()
        ripple(btn, m.X, m.Y - 36)
        if settings.sounds then sound(GV.SND_CLICK, 0.15, 1.2) end
        if fn then task.spawn(function() local ok, e = pcall(fn) if not ok then CORE.log("ERR", "" .. tostring(e)) end end) end
    end))
    return btn
end
-- buttons: dark surface + hairline stroke; the stroke warms to the accent on hover
local function button(parent, text, props, fn)
    local b = new("TextButton", {Parent = parent, AutoButtonColor = false, BackgroundColor3 = C.cardHover, Font = F.bold,
        Text = text, TextColor3 = C.text, TextSize = 13, Size = UDim2.new(0, 110, 0, GV.BTN_H)}, {corner(8)})
    local st = new("UIStroke", {Parent = b, Color = C.purple, Thickness = 1, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    for k, v in pairs(props or {}) do b[k] = v end
    if not isTouch then
        bind(b.MouseEnter:Connect(function() tween(st, 0.15, {Color = C.gold, Transparency = 0.35}) end))
        bind(b.MouseLeave:Connect(function() tween(st, 0.15, {Color = C.purple, Transparency = 0.2}) end))
    end
    clickable(b, fn)
    return b
end
local function goldButton(parent, text, props, fn)
    local b = button(parent, text, props, fn)
    b.BackgroundColor3 = Color3.new(1, 1, 1)
    b.TextColor3 = C.ink
    local st = b:FindFirstChildOfClass("UIStroke")
    if st then st.Color = C.goldLight st.Transparency = 0.6 end
    goldGradient(90).Parent = b
    return b
end
-- quiet outline tag instead of a shiny gold sticker
local function premiumBadge(parent, pos, text)
    local b = new("Frame", {Parent = parent, BackgroundColor3 = C.gold, BackgroundTransparency = 0.88, Position = pos, Size = UDim2.new(0, 74, 0, 18), ZIndex = 6},
        {corner(4)})
    new("UIStroke", {Parent = b, Color = C.gold, Thickness = 1, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    label(b, {Size = UDim2.fromScale(1, 1), Font = F.bold, Text = spaced(text or "PREMIUM"), TextColor3 = C.goldLight, TextSize = 9, ZIndex = 7, TextXAlignment = Enum.TextXAlignment.Center})
    return b
end
-- drawn icons (no font glyphs / emojis): close cross, minus, chevron
local function iconCross(parent, size, col, z)
    local holder = new("Frame", {Parent = parent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, size, 0, size), ZIndex = z or 8})
    for _, rot in ipairs({45, -45}) do
        new("Frame", {Parent = holder, BorderSizePixel = 0, BackgroundColor3 = col or C.text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1.2, 0, 0, 2), Rotation = rot, ZIndex = z or 8})
    end
    return holder
end
local function iconMinus(parent, size, col, z)
    return new("Frame", {Parent = parent, BorderSizePixel = 0, BackgroundColor3 = col or C.text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, size, 0, 2), ZIndex = z or 8})
end
-- Ninja badge vector data (generated from the reference logo by /workspace/v4/ninja/gen2.py).
-- piece = x,y,w,h,rot,c1,c2,gradRot,corner,transp,mode,param   (normalised 0..1 inside the logo square)
local buildLogo
do
local LOGO_DATA = {
    full = table.concat({
        "0.3333,0.4792,0.2936,0.03,55.41,2a2a2a,,,,,,;0.6667,0.4792,0.2936,0.03,124.59,2a2a2a,,,,,,;0.5,0.1222,0.057,0.018,,47474b,,,,,,;0.5,0.1382,0.112,0.018,,46464a,,,,,,;",
        "0.5,0.1542,0.167,0.018,,454549,,,,,,;0.5,0.1701,0.222,0.018,,454549,,,,,,;0.5,0.1861,0.257,0.018,,444448,,,,,,;0.5,0.202,0.2708,0.018,,434347,,,,,,;0.5,0.218,0.2845,0.018,,434346,,,,,,;",
        "0.5,0.234,0.2983,0.018,,424245,,,,,,;0.5,0.2499,0.312,0.018,,414145,,,,,,;0.5,0.2659,0.3145,0.018,,404044,,,,,,;0.5,0.2819,0.3165,0.018,,404043,,,,,,;0.5,0.2978,0.3186,0.018,,3f3f42,,,,,,;",
        "0.5,0.3138,0.3207,0.018,,3e3e42,,,,,,;0.5,0.3297,0.3227,0.018,,3e3e41,,,,,,;0.5,0.3457,0.3248,0.018,,3d3d40,,,,,,;0.5,0.3617,0.3268,0.018,,3c3c3f,,,,,,;0.5,0.3776,0.3289,0.018,,3b3b3f,,,,,,;",
        "0.5,0.3936,0.355,0.018,,3b3b3e,,,,,,;0.5,0.4095,0.3987,0.018,,3a3a3d,,,,,,;0.5,0.4255,0.4425,0.018,,39393c,,,,,,;0.5,0.4415,0.4862,0.018,,38383c,,,,,,;0.5,0.4574,0.53,0.018,,38383b,,,,,,;",
        "0.5,0.4734,0.5774,0.018,,37373a,,,,,,;0.5,0.4894,0.6255,0.018,,363639,,,,,,;0.5,0.5053,0.6736,0.018,,363638,,,,,,;0.5,0.5213,0.654,0.018,,353538,,,,,,;0.5,0.5372,0.6304,0.018,,343437,,,,,,;",
        "0.5,0.5532,0.6121,0.018,,333336,,,,,,;0.5,0.5692,0.602,0.018,,333335,,,,,,;0.5,0.5851,0.5919,0.018,,323235,,,,,,;0.5,0.6011,0.5818,0.018,,313134,,,,,,;0.5,0.617,0.5689,0.018,,303033,,,,,,;",
        "0.5,0.633,0.5496,0.018,,303032,,,,,,;0.5,0.649,0.5304,0.018,,2f2f32,,,,,,;0.5,0.6649,0.5111,0.018,,2e2e31,,,,,,;0.5,0.6809,0.4919,0.018,,2e2e30,,,,,,;0.5,0.6969,0.4726,0.018,,2d2d2f,,,,,,;",
        "0.5,0.7128,0.435,0.018,,2c2c2f,,,,,,;0.5,0.7288,0.396,0.018,,2b2b2e,,,,,,;0.5,0.7447,0.3569,0.018,,2b2b2d,,,,,,;0.5,0.7607,0.3179,0.018,,2a2a2c,,,,,,;0.5,0.7767,0.2788,0.018,,29292b,,,,,,;",
        "0.5,0.7926,0.2101,0.018,,29292b,,,,,,;0.5,0.8086,0.1408,0.018,,28282a,,,,,,;0.5,0.8245,0.0714,0.018,,272729,,,,,,;0.5575,0.1423,0.1456,0.0184,30.14,46464a,,,,,,;",
        "0.6313,0.2101,0.0805,0.0184,66.7,434347,,,,,,;0.6504,0.31,0.1362,0.0184,86.31,3e3e42,,,,,,;0.7102,0.4216,0.1301,0.0184,36.12,3a3a3d,,,,,,;0.8011,0.4853,0.0952,0.0184,33.56,37373a,,,,,,;",
        "0.8186,0.5237,0.066,0.0184,126.39,343437,,,,,,;0.788,0.5848,0.0704,0.0184,107.61,323235,,,,,,;0.7526,0.6583,0.1022,0.0184,121.09,2e2e31,,,,,,;0.6805,0.7384,0.1268,0.0184,140.74,2b2b2d,,,,,,;",
        "0.5652,0.8084,0.1539,0.0184,155.29,27272a,,,,,,;0.4348,0.8084,0.1539,0.0184,-155.29,27272a,,,,,,;0.3195,0.7384,0.1268,0.0184,-140.74,2b2b2d,,,,,,;",
        "0.2474,0.6583,0.1022,0.0184,-121.09,2e2e31,,,,,,;0.212,0.5848,0.0704,0.0184,-107.61,323235,,,,,,;0.1814,0.5237,0.066,0.0184,-126.39,343437,,,,,,;",
        "0.1989,0.4853,0.0952,0.0184,-33.56,37373a,,,,,,;0.2898,0.4216,0.1301,0.0184,-36.12,3a3a3d,,,,,,;0.3496,0.31,0.1362,0.0184,-86.31,3e3e42,,,,,,;0.3687,0.2101,0.0805,0.0184,-66.7,434347,,,,,,;",
        "0.4425,0.1423,0.1456,0.0184,-30.14,46464a,,,,,,;0.1865,0.5538,0.0292,0.0178,,f2f2f2,,,,,,;0.1926,0.5696,0.0285,0.0178,,f2f2f2,,,,,,;0.1988,0.5854,0.0279,0.0178,,f2f2f2,,,,,,;",
        "0.2049,0.6013,0.0273,0.0178,,f2f2f2,,,,,,;0.2125,0.6171,0.0277,0.0178,,f2f2f2,,,,,,;0.2219,0.6329,0.0273,0.0178,,f2f2f2,,,,,,;0.2313,0.6488,0.027,0.0178,,f2f2f2,,,,,,;",
        "0.2407,0.6646,0.0267,0.0178,,f2f2f2,,,,,,;0.2501,0.6804,0.0264,0.0178,,f2f2f2,,,,,,;0.261,0.6963,0.0291,0.0178,,f2f2f2,,,,,,;0.2763,0.7121,0.0286,0.0178,,f2f2f2,,,,,,;",
        "0.2926,0.7279,0.026,0.0178,,f2f2f2,,,,,,;0.3089,0.7438,0.0234,0.0178,,f2f2f2,,,,,,;0.3282,0.7596,0.027,0.0178,,f2f2f2,,,,,,;0.3504,0.7754,0.0361,0.0178,,f2f2f2,,,,,,;",
        "0.3783,0.7913,0.0338,0.0178,,f2f2f2,,,,,,;0.4062,0.8071,0.0316,0.0178,,f2f2f2,,,,,,;0.4343,0.8229,0.0299,0.0178,,f2f2f2,,,,,,;0.4614,0.8387,0.0304,0.0178,,f2f2f2,,,,,,;",
        "0.4868,0.8546,0.0284,0.0178,,f2f2f2,,,,,,;0.1868,0.5716,0.0992,0.0182,67.83,f2f2f2,,,,,,;0.2311,0.6595,0.1052,0.0182,58.88,f2f2f2,,,,,,;0.2978,0.7391,0.1141,0.0182,41.99,f2f2f2,,,,,,;",
        "0.3835,0.8003,0.1064,0.0182,28.61,f2f2f2,,,,,,;0.4672,0.848,0.0895,0.0182,30.96,f2f2f2,,,,,,;0.4909,0.8617,0.0353,0.0182,-90,f2f2f2,,,,,,;0.4538,0.8287,0.0983,0.0182,-149.89,f2f2f2,,,,,,;",
        "0.367,0.7778,0.1066,0.0182,-149.35,f2f2f2,,,,,,;0.2901,0.7179,0.0892,0.0182,-133.45,f2f2f2,,,,,,;0.2355,0.6446,0.0946,0.0182,-120.26,f2f2f2,,,,,,;",
        "0.1998,0.5715,0.0695,0.0182,-110.22,f2f2f2,,,,,,;0.1767,0.5423,0.0393,0.0182,-169.7,f2f2f2,,,,,,;0.8135,0.5538,0.0292,0.0178,,f2f2f2,,,,,,;0.8074,0.5696,0.0285,0.0178,,f2f2f2,,,,,,;",
        "0.8012,0.5854,0.0279,0.0178,,f2f2f2,,,,,,;0.7951,0.6013,0.0273,0.0178,,f2f2f2,,,,,,;0.7875,0.6171,0.0277,0.0178,,f2f2f2,,,,,,;0.7781,0.6329,0.0273,0.0178,,f2f2f2,,,,,,;",
        "0.7687,0.6488,0.027,0.0178,,f2f2f2,,,,,,;0.7593,0.6646,0.0267,0.0178,,f2f2f2,,,,,,;0.7499,0.6804,0.0264,0.0178,,f2f2f2,,,,,,;0.739,0.6963,0.0291,0.0178,,f2f2f2,,,,,,;",
        "0.7237,0.7121,0.0286,0.0178,,f2f2f2,,,,,,;0.7074,0.7279,0.026,0.0178,,f2f2f2,,,,,,;0.6911,0.7438,0.0234,0.0178,,f2f2f2,,,,,,;0.6718,0.7596,0.027,0.0178,,f2f2f2,,,,,,;",
        "0.6496,0.7754,0.0361,0.0178,,f2f2f2,,,,,,;0.6217,0.7913,0.0338,0.0178,,f2f2f2,,,,,,;0.5938,0.8071,0.0316,0.0178,,f2f2f2,,,,,,;0.5657,0.8229,0.0299,0.0178,,f2f2f2,,,,,,;",
        "0.5386,0.8387,0.0304,0.0178,,f2f2f2,,,,,,;0.5132,0.8546,0.0284,0.0178,,f2f2f2,,,,,,;0.8002,0.5715,0.0695,0.0182,110.22,f2f2f2,,,,,,;0.7645,0.6446,0.0946,0.0182,120.26,f2f2f2,,,,,,;",
        "0.7099,0.7179,0.0892,0.0182,133.45,f2f2f2,,,,,,;0.633,0.7778,0.1066,0.0182,149.35,f2f2f2,,,,,,;0.5462,0.8287,0.0983,0.0182,149.89,f2f2f2,,,,,,;0.5091,0.8617,0.0353,0.0182,90,f2f2f2,,,,,,;",
        "0.5328,0.848,0.0895,0.0182,-30.96,f2f2f2,,,,,,;0.6165,0.8003,0.1064,0.0182,-28.61,f2f2f2,,,,,,;0.7022,0.7391,0.1141,0.0182,-41.99,f2f2f2,,,,,,;",
        "0.7689,0.6595,0.1052,0.0182,-58.88,f2f2f2,,,,,,;0.8132,0.5716,0.0992,0.0182,-67.83,f2f2f2,,,,,,;0.8233,0.5423,0.0393,0.0182,169.7,f2f2f2,,,,,,;0.5,0.1338,0.0563,0.0178,,1a1a1b,,,,,,;",
        "0.5,0.1496,0.1106,0.0178,,19191a,,,,,,;0.5,0.1654,0.1649,0.0178,,19191a,,,,,,;0.5,0.1813,0.2192,0.0178,,19191a,,,,,,;0.5,0.1971,0.2499,0.0178,,181819,,,,,,;",
        "0.5,0.2129,0.2634,0.0178,,181819,,,,,,;0.5,0.2288,0.277,0.0178,,181819,,,,,,;0.5,0.2446,0.2906,0.0178,,171718,,,,,,;0.5,0.2604,0.3023,0.0178,,171718,,,,,,;",
        "0.5,0.2762,0.3044,0.0178,,171718,,,,,,;0.5,0.2921,0.3064,0.0178,,161618,,,,,,;0.5,0.3079,0.3084,0.0178,,161617,,,,,,;0.5,0.3238,0.3104,0.0178,,161617,,,,,,;",
        "0.5,0.3396,0.3125,0.0178,,161617,,,,,,;0.5,0.3554,0.3145,0.0178,,151516,,,,,,;0.5,0.3713,0.3165,0.0178,,151516,,,,,,;0.5,0.3871,0.3186,0.0178,,151516,,,,,,;",
        "0.5,0.4029,0.3596,0.0178,,141415,,,,,,;0.5,0.4188,0.4028,0.0178,,141415,,,,,,;0.5,0.4346,0.446,0.0178,,141415,,,,,,;0.5,0.4504,0.4891,0.0178,,131314,,,,,,;",
        "0.5,0.4662,0.5337,0.0178,,131314,,,,,,;0.5,0.4821,0.5812,0.0178,,131314,,,,,,;0.5,0.4979,0.6287,0.0178,,131314,,,,,,;0.5,0.5138,0.6418,0.0178,,121213,,,,,,;",
        "0.5,0.5296,0.6186,0.0178,,121213,,,,,,;0.5,0.5454,0.5953,0.0178,,121213,,,,,,;0.5,0.5613,0.5853,0.0178,,111112,,,,,,;0.5,0.5771,0.5753,0.0178,,111112,,,,,,;",
        "0.5,0.5929,0.5653,0.0178,,111112,,,,,,;0.5,0.6088,0.5553,0.0178,,101011,,,,,,;0.5,0.6246,0.5363,0.0178,,101011,,,,,,;0.5,0.6404,0.5173,0.0178,,101011,,,,,,;",
        "0.5,0.6562,0.4983,0.0178,,101010,,,,,,;0.5,0.6721,0.4793,0.0178,,0f0f10,,,,,,;0.5,0.6879,0.4603,0.0178,,0f0f10,,,,,,;0.5,0.7037,0.427,0.0178,,0f0f10,,,,,,;",
        "0.5,0.7196,0.3884,0.0178,,0e0e0f,,,,,,;0.5,0.7354,0.3499,0.0178,,0e0e0f,,,,,,;0.5,0.7513,0.3113,0.0178,,0e0e0f,,,,,,;0.5,0.7671,0.2727,0.0178,,0d0d0e,,,,,,;",
        "0.5,0.7829,0.2074,0.0178,,0d0d0e,,,,,,;0.5,0.7988,0.139,0.0178,,0d0d0e,,,,,,;0.5,0.8146,0.0705,0.0178,,0c0c0d,,,,,,;0.5554,0.1529,0.1409,0.0182,30.26,19191a,,,,,,;",
        "0.6266,0.2186,0.0782,0.0182,66.8,181819,,,,,,;0.6451,0.3156,0.1323,0.0182,86.33,161617,,,,,,;0.7029,0.424,0.126,0.0182,36.25,141415,,,,,,;0.7908,0.4859,0.0921,0.0182,33.69,131314,,,,,,;",
        "0.8077,0.5229,0.064,0.0182,126.25,121213,,,,,,;0.778,0.5823,0.0684,0.0182,107.53,111112,,,,,,;0.7439,0.6536,0.0992,0.0182,120.96,0f0f10,,,,,,;0.6742,0.7313,0.1228,0.0182,140.6,0e0e0f,,,,,,;",
        "0.5628,0.7992,0.1489,0.0182,155.18,0d0d0e,,,,,,;0.4372,0.7992,0.1489,0.0182,-155.18,0d0d0e,,,,,,;0.3258,0.7313,0.1228,0.0182,-140.6,0e0e0f,,,,,,;",
        "0.2561,0.6536,0.0992,0.0182,-120.96,0f0f10,,,,,,;0.222,0.5823,0.0684,0.0182,-107.53,111112,,,,,,;0.1923,0.5229,0.064,0.0182,-126.25,121213,,,,,,;",
        "0.2092,0.4859,0.0921,0.0182,-33.69,131314,,,,,,;0.2971,0.424,0.126,0.0182,-36.25,141415,,,,,,;0.3549,0.3156,0.1323,0.0182,-86.33,161617,,,,,,;0.3734,0.2186,0.0782,0.0182,-66.8,181819,,,,,,;",
        "0.4446,0.1529,0.1409,0.0182,-30.26,19191a,,,,,,;0.645,0.4325,0.022,0.017,,838383,,,,,,;0.6663,0.4475,0.0495,0.017,,7f7f7f,,,,,,;0.6875,0.4625,0.077,0.017,,7a7a7a,,,,,,;",
        "0.7088,0.4775,0.1045,0.017,,767676,,,,,,;0.739,0.4925,0.1018,0.017,,717171,,,,,,;0.7645,0.5075,0.0836,0.017,,6d6d6d,,,,,,;0.6983,0.4529,0.1797,0.0173,23.2,808080,,,,,,;",
        "0.7959,0.503,0.0516,0.0173,42.27,707070,,,,,,;0.7869,0.5133,0.0659,0.0173,164.88,686868,,,,,,;0.7118,0.5004,0.111,0.0173,-156.57,6d6d6d,,,,,,;",
        "0.6469,0.4445,0.0877,0.0173,-116.57,7e7e7e,,,,,,;0.6829,0.5168,0.0469,0.0176,,949494,,,,,,;0.6919,0.5324,0.0906,0.0176,,919191,,,,,,;0.6822,0.548,0.097,0.0176,,8d8d8d,,,,,,;",
        "0.6781,0.5636,0.0926,0.0176,,898989,,,,,,;0.6771,0.5793,0.0818,0.0176,,858585,,,,,,;0.6762,0.5949,0.0709,0.0176,,828282,,,,,,;0.6752,0.6105,0.06,0.0176,,7e7e7e,,,,,,;",
        "0.6719,0.6261,0.0535,0.0176,,7a7a7a,,,,,,;0.6655,0.6418,0.0533,0.0176,,767676,,,,,,;0.6585,0.6574,0.0544,0.0176,,737373,,,,,,;0.6514,0.673,0.0556,0.0176,,6f6f6f,,,,,,;",
        "0.6444,0.6886,0.0567,0.0176,,6b6b6b,,,,,,;0.6374,0.7043,0.0578,0.0176,,676767,,,,,,;0.6167,0.7199,0.0318,0.0176,,646464,,,,,,;0.7036,0.5181,0.078,0.018,26,969696,,,,,,;",
        "0.7167,0.5641,0.0902,0.018,112.2,888888,,,,,,;0.6775,0.6591,0.1193,0.018,112.56,717171,,,,,,;0.622,0.7215,0.0832,0.018,160.82,616161,,,,,,;0.6247,0.6856,0.1392,0.018,-64.06,6d6d6d,,,,,,;",
        "0.6453,0.5825,0.0748,0.018,-105.95,848484,,,,,,;0.6569,0.5274,0.0754,0.018,-50.53,939393,,,,,,;0.5935,0.5083,0.039,0.0187,,585858,,,,,,;0.589,0.525,0.04,0.0187,,545454,,,,,,;",
        "0.5845,0.5417,0.041,0.0187,,515151,,,,,,;0.58,0.5583,0.042,0.0187,,4e4e4e,,,,,,;0.5742,0.575,0.0337,0.0187,,4c4c4c,,,,,,;0.5683,0.5917,0.0253,0.0187,,484848,,,,,,;",
        "0.5625,0.6083,0.017,0.0187,,464646,,,,,,;0.5567,0.625,0.0087,0.0187,,424242,,,,,,;0.6008,0.5007,0.05,0.0192,-20.32,5a5a5a,,,,,,;0.6007,0.5228,0.0877,0.0192,103.5,545454,,,,,,;",
        "0.5668,0.6034,0.0992,0.0192,120.96,464646,,,,,,;0.5645,0.601,0.1025,0.0192,-84.29,474747,,,,,,;0.5767,0.5278,0.0542,0.0192,-73.3,545454,,,,,,;0.425,0.6167,0.2774,0.014,57.26,262626,,,,,,;",
        "0.4833,0.6417,0.3131,0.012,64.8,222222,,,,,,;0.3042,0.46,0.118,0.012,-23.3,3a3a3a,,,,,,;0.4835,0.154,0.035,0.018,,232323,,,,,,;0.467,0.17,0.068,0.018,,222222,,,,,,;",
        "0.4505,0.186,0.101,0.018,,212121,,,,,,;0.4425,0.202,0.117,0.018,,202020,,,,,,;0.4388,0.218,0.1244,0.018,,202020,,,,,,;0.435,0.234,0.1319,0.018,,1f1f1f,,,,,,;",
        "0.4355,0.25,0.131,0.018,,1e1e1e,,,,,,;0.4369,0.266,0.1282,0.018,,1d1d1d,,,,,,;0.4383,0.282,0.1253,0.018,,1c1c1c,,,,,,;0.4908,0.21,0.162,0.0184,90,202020,,,,,,;",
        "0.3807,0.2601,0.0595,0.0184,-100.01,1d1d1d,,,,,,;0.3867,0.2122,0.0572,0.0184,-64.98,202020,,,,,,;0.449,0.1649,0.1242,0.0184,-25.87,232323,,,,,,;0.5142,0.1499,0.027,0.0175,,888888,,,,,,;",
        "0.5279,0.1654,0.0528,0.0175,,868686,,,,,,;0.5417,0.1808,0.0786,0.0175,,848484,,,,,,;0.5542,0.1963,0.1021,0.0175,,818181,,,,,,;0.5583,0.2118,0.1086,0.0175,,7f7f7f,,,,,,;",
        "0.5624,0.2273,0.115,0.0175,,7c7c7c,,,,,,;0.5672,0.2427,0.1201,0.0175,,7a7a7a,,,,,,;0.5955,0.2582,0.0777,0.0175,,777777,,,,,,;0.6034,0.2737,0.0635,0.0175,,757575,,,,,,;",
        "0.6105,0.2892,0.0511,0.0175,,727272,,,,,,;0.6175,0.3046,0.0387,0.0175,,707070,,,,,,;0.6276,0.3201,0.0201,0.0175,,6e6e6e,,,,,,;0.5472,0.1644,0.1215,0.0178,30.14,878787,,,,,,;",
        "0.6103,0.2221,0.0721,0.0178,64.65,7e7e7e,,,,,,;0.6269,0.2971,0.0955,0.0178,86.93,717171,,,,,,;0.6247,0.3213,0.0507,0.0178,-141.95,6c6c6c,,,,,,;",
        "0.5868,0.2842,0.0635,0.0178,-130.6,727272,,,,,,;0.536,0.2498,0.0579,0.0178,-162.65,777777,,,,,,;0.5122,0.1879,0.1255,0.0178,-93.09,828282,,,,,,;0.5543,0.2725,0.0223,0.017,,141414,,,,,,;",
        "0.5657,0.2875,0.0187,0.017,,141414,,,,,,;0.5406,0.2648,0.0442,0.0172,18.43,141414,,,,,,;0.5711,0.2913,0.0575,0.0172,57.26,141414,,,,,,;0.5767,0.2937,0.0453,0.0172,-157.38,141414,,,,,,;",
        "0.5454,0.2668,0.0547,0.0172,-124.7,141414,,,,,,;0.5,0.305,0.24,0.045,,767676,3e3e3e,,0.25,,stripes,10;0.5,0.3347,0.252,0.0182,,060606,,,,,,;0.5,0.3509,0.2542,0.0182,,060606,,,,,,;",
        "0.5,0.3671,0.2564,0.0182,,060606,,,,,,;0.5,0.3832,0.2586,0.0182,,060606,,,,,,;0.5,0.3994,0.2445,0.0182,,060606,,,,,,;0.5,0.4155,0.2064,0.0182,,060606,,,,,,;",
        "0.5,0.4317,0.1683,0.0182,,060606,,,,,,;0.5,0.4478,0.1366,0.0182,,060606,,,,,,;0.5,0.464,0.1097,0.0182,,060606,,,,,,;0.5,0.4801,0.0828,0.0182,,060606,,,,,,;",
        "0.5,0.4963,0.0559,0.0182,,060606,,,,,,;0.5,0.5124,0.0289,0.0182,,060606,,,,,,;0.6182,0.364,0.0755,0.0186,86.1,060606,,,,,,;0.5965,0.4163,0.0741,0.0186,139.69,060606,,,,,,;",
        "0.5304,0.4857,0.1192,0.0186,129.81,060606,,,,,,;0.4696,0.4857,0.1192,0.0186,-129.81,060606,,,,,,;0.4035,0.4163,0.0741,0.0186,-139.69,060606,,,,,,;",
        "0.3818,0.364,0.0755,0.0186,-86.1,060606,,,,,,;0.442,0.36,0.115,0.05,12,ffffff,,,0.5,0.88,,eye;0.442,0.36,0.08,0.03,12,ffffff,,,0.5,0.6,,eye;0.442,0.36,0.062,0.018,12,ffffff,,,0.45,,,eye;",
        "0.558,0.36,0.115,0.05,-12,ffffff,,,0.5,0.88,,eye;0.558,0.36,0.08,0.03,-12,ffffff,,,0.5,0.6,,eye;0.558,0.36,0.062,0.018,-12,ffffff,,,0.45,,,eye;",
        "0.215,0.2808,0.2087,0.06,64.46,0a0a0a,,,0.15,,,;0.215,0.2808,0.1938,0.044,64.54,a8a8a8,2c2c2c,,,,stripes,8;0.26,0.3292,0.1045,0.026,-33.94,0a0a0a,,,,,,;",
        "0.26,0.3292,0.0971,0.013,-34.51,9a9a9a,,,,,,;0.785,0.2808,0.2087,0.06,115.54,0a0a0a,,,0.15,,,;0.785,0.2808,0.1938,0.044,115.46,a8a8a8,2c2c2c,,,,stripes,8;",
        "0.74,0.3292,0.1045,0.026,-146.06,0a0a0a,,,,,,;0.74,0.3292,0.0971,0.013,-145.49,9a9a9a,,,,,,;0.1425,0.295,0.0954,0.016,70.62,f2f2f2,,,0.5,,,;0.155,0.4017,0.0519,0.02,45,f2f2f2,,,,,,;",
        "0.1867,0.4267,0.0447,0.02,26.57,f2f2f2,,,,,,;0.8575,0.295,0.0954,0.016,109.38,f2f2f2,,,0.5,,,;0.845,0.4017,0.0519,0.02,135,f2f2f2,,,,,,;0.8133,0.4267,0.0447,0.02,153.43,f2f2f2,,,,,,",
    }),
    lite = table.concat({
        "0.3333,0.4792,0.2936,0.03,55.41,2a2a2a,,,,,,;0.6667,0.4792,0.2936,0.03,124.59,2a2a2a,,,,,,;0.5,0.1472,0.1144,0.0346,,46464a,,,,,,;0.5,0.1798,0.2268,0.0346,,444448,,,,,,;",
        "0.5,0.2125,0.2726,0.0346,,434347,,,,,,;0.5,0.2451,0.3007,0.0346,,414145,,,,,,;0.5,0.2777,0.3149,0.0346,,404043,,,,,,;0.5,0.3103,0.3191,0.0346,,3e3e42,,,,,,;",
        "0.5,0.3429,0.3233,0.0346,,3d3d40,,,,,,;0.5,0.3755,0.3275,0.0346,,3b3b3f,,,,,,;0.5,0.4082,0.3721,0.0346,,3a3a3d,,,,,,;0.5,0.4408,0.4615,0.0346,,38383c,,,,,,;",
        "0.5,0.4734,0.5523,0.0346,,37373a,,,,,,;0.5,0.506,0.6506,0.0346,,363638,,,,,,;0.5,0.5386,0.6161,0.0346,,343437,,,,,,;0.5,0.5712,0.5954,0.0346,,333335,,,,,,;",
        "0.5,0.6039,0.5747,0.0346,,313134,,,,,,;0.5,0.6365,0.5354,0.0346,,303032,,,,,,;0.5,0.6691,0.4961,0.0346,,2e2e31,,,,,,;0.5,0.7017,0.4418,0.0346,,2d2d2f,,,,,,;",
        "0.5,0.7343,0.362,0.0346,,2b2b2d,,,,,,;0.5,0.7669,0.2822,0.0346,,2a2a2c,,,,,,;0.5,0.7996,0.1438,0.0346,,28282a,,,,,,;0.5527,0.1506,0.1456,0.0375,30.14,46464a,,,,,,;",
        "0.6225,0.2139,0.0805,0.0375,66.7,434347,,,,,,;0.6408,0.3107,0.1362,0.0375,86.31,3e3e42,,,,,,;0.7046,0.4293,0.1301,0.0375,36.12,3a3a3d,,,,,,;0.7958,0.4933,0.0952,0.0375,33.56,37373a,,,,,,;",
        "0.8109,0.5181,0.066,0.0375,126.39,343437,,,,,,;0.7788,0.5819,0.0704,0.0375,107.61,323235,,,,,,;0.7444,0.6534,0.1022,0.0375,121.09,2e2e31,,,,,,;0.6744,0.731,0.1268,0.0375,140.74,2b2b2d,,,,,,;",
        "0.5612,0.7997,0.1539,0.0375,155.29,27272a,,,,,,;0.4388,0.7997,0.1539,0.0375,-155.29,27272a,,,,,,;0.3256,0.731,0.1268,0.0375,-140.74,2b2b2d,,,,,,;",
        "0.2556,0.6534,0.1022,0.0375,-121.09,2e2e31,,,,,,;0.2212,0.5819,0.0704,0.0375,-107.61,323235,,,,,,;0.1891,0.5181,0.066,0.0375,-126.39,343437,,,,,,;",
        "0.2042,0.4933,0.0952,0.0375,-33.56,37373a,,,,,,;0.2954,0.4293,0.1301,0.0375,-36.12,3a3a3d,,,,,,;0.3592,0.3107,0.1362,0.0375,-86.31,3e3e42,,,,,,;",
        "0.3775,0.2139,0.0805,0.0375,-66.7,434347,,,,,,;0.4473,0.1506,0.1456,0.0375,-30.14,46464a,,,,,,;0.1958,0.5775,0.0221,0.0337,,f2f2f2,,,,,,;0.2086,0.6092,0.0199,0.0337,,f2f2f2,,,,,,;",
        "0.2267,0.6408,0.0178,0.0337,,f2f2f2,,,,,,;0.2455,0.6725,0.0171,0.0337,,f2f2f2,,,,,,;0.2688,0.7042,0.0136,0.0337,,f2f2f2,,,,,,;0.3014,0.7358,0.0084,0.0337,,f2f2f2,,,,,,;",
        "0.337,0.7675,0.0094,0.0337,,f2f2f2,,,,,,;0.3928,0.7992,0.0048,0.0337,,f2f2f2,,,,,,;0.4477,0.8308,0.0031,0.0337,,f2f2f2,,,,,,;0.1952,0.5681,0.0992,0.0364,67.83,f2f2f2,,,,,,;",
        "0.2389,0.6548,0.1052,0.0364,58.88,f2f2f2,,,,,,;0.3038,0.7323,0.1141,0.0364,41.99,f2f2f2,,,,,,;0.3879,0.7923,0.1064,0.0364,28.61,f2f2f2,,,,,,;0.4719,0.8402,0.0895,0.0364,30.96,f2f2f2,,,,,,;",
        "0.4818,0.8617,0.0353,0.0364,-90,f2f2f2,,,,,,;0.4492,0.8366,0.0983,0.0364,-149.89,f2f2f2,,,,,,;0.3624,0.7857,0.1066,0.0364,-149.35,f2f2f2,,,,,,;",
        "0.2834,0.7242,0.0892,0.0364,-133.45,f2f2f2,,,,,,;0.2276,0.6492,0.0946,0.0364,-120.26,f2f2f2,,,,,,;0.1912,0.5746,0.0695,0.0364,-110.22,f2f2f2,,,,,,;",
        "0.1751,0.5512,0.0393,0.0364,-169.7,f2f2f2,,,,,,;0.8042,0.5775,0.0221,0.0337,,f2f2f2,,,,,,;0.7914,0.6092,0.0199,0.0337,,f2f2f2,,,,,,;0.7733,0.6408,0.0178,0.0337,,f2f2f2,,,,,,;",
        "0.7545,0.6725,0.0171,0.0337,,f2f2f2,,,,,,;0.7312,0.7042,0.0136,0.0337,,f2f2f2,,,,,,;0.6986,0.7358,0.0084,0.0337,,f2f2f2,,,,,,;0.663,0.7675,0.0094,0.0337,,f2f2f2,,,,,,;",
        "0.6072,0.7992,0.0048,0.0337,,f2f2f2,,,,,,;0.5523,0.8308,0.0031,0.0337,,f2f2f2,,,,,,;0.8088,0.5746,0.0695,0.0364,110.22,f2f2f2,,,,,,;0.7724,0.6492,0.0946,0.0364,120.26,f2f2f2,,,,,,;",
        "0.7166,0.7242,0.0892,0.0364,133.45,f2f2f2,,,,,,;0.6376,0.7857,0.1066,0.0364,149.35,f2f2f2,,,,,,;0.5508,0.8366,0.0983,0.0364,149.89,f2f2f2,,,,,,;0.5182,0.8617,0.0353,0.0364,90,f2f2f2,,,,,,;",
        "0.5281,0.8402,0.0895,0.0364,-30.96,f2f2f2,,,,,,;0.6121,0.7923,0.1064,0.0364,-28.61,f2f2f2,,,,,,;0.6962,0.7323,0.1141,0.0364,-41.99,f2f2f2,,,,,,;",
        "0.7611,0.6548,0.1052,0.0364,-58.88,f2f2f2,,,,,,;0.8048,0.5681,0.0992,0.0364,-67.83,f2f2f2,,,,,,;0.8249,0.5512,0.0393,0.0364,169.7,f2f2f2,,,,,,;0.5,0.1575,0.1106,0.0337,,19191a,,,,,,;",
        "0.5,0.1892,0.2192,0.0337,,181819,,,,,,;0.5,0.2208,0.2634,0.0337,,181819,,,,,,;0.5,0.2525,0.2906,0.0337,,171718,,,,,,;0.5,0.2842,0.3044,0.0337,,171718,,,,,,;",
        "0.5,0.3158,0.3084,0.0337,,161617,,,,,,;0.5,0.3475,0.3125,0.0337,,151516,,,,,,;0.5,0.3792,0.3165,0.0337,,151516,,,,,,;0.5,0.4108,0.3596,0.0337,,141415,,,,,,;",
        "0.5,0.4425,0.446,0.0337,,141415,,,,,,;0.5,0.4742,0.5337,0.0337,,131314,,,,,,;0.5,0.5058,0.6287,0.0337,,121213,,,,,,;0.5,0.5375,0.5953,0.0337,,121213,,,,,,;",
        "0.5,0.5692,0.5753,0.0337,,111112,,,,,,;0.5,0.6008,0.5553,0.0337,,111112,,,,,,;0.5,0.6325,0.5173,0.0337,,101011,,,,,,;0.5,0.6642,0.4793,0.0337,,0f0f10,,,,,,;",
        "0.5,0.6958,0.427,0.0337,,0f0f10,,,,,,;0.5,0.7275,0.3499,0.0337,,0e0e0f,,,,,,;0.5,0.7592,0.2727,0.0337,,0e0e0f,,,,,,;0.5,0.7908,0.139,0.0337,,0d0d0e,,,,,,;",
        "0.5508,0.1607,0.1409,0.0364,30.26,19191a,,,,,,;0.6183,0.2222,0.0782,0.0364,66.8,181819,,,,,,;0.636,0.3162,0.1323,0.0364,86.33,161617,,,,,,;0.6976,0.4313,0.126,0.0364,36.25,141415,,,,,,;",
        "0.7857,0.4935,0.0921,0.0364,33.69,131314,,,,,,;0.8003,0.5176,0.064,0.0364,126.25,121213,,,,,,;0.7693,0.5795,0.0684,0.0364,107.53,111112,,,,,,;0.7361,0.649,0.0992,0.0364,120.96,0f0f10,,,,,,;",
        "0.6684,0.7243,0.1228,0.0364,140.6,0e0e0f,,,,,,;0.559,0.791,0.1489,0.0364,155.18,0d0d0e,,,,,,;0.441,0.791,0.1489,0.0364,-155.18,0d0d0e,,,,,,;0.3316,0.7243,0.1228,0.0364,-140.6,0e0e0f,,,,,,;",
        "0.2639,0.649,0.0992,0.0364,-120.96,0f0f10,,,,,,;0.2307,0.5795,0.0684,0.0364,-107.53,111112,,,,,,;0.1997,0.5176,0.064,0.0364,-126.25,121213,,,,,,;",
        "0.2143,0.4935,0.0921,0.0364,-33.69,131314,,,,,,;0.3024,0.4313,0.126,0.0364,-36.25,141415,,,,,,;0.364,0.3162,0.1323,0.0364,-86.33,161617,,,,,,;0.3817,0.2222,0.0782,0.0364,-66.8,181819,,,,,,;",
        "0.4492,0.1607,0.1409,0.0364,-30.26,19191a,,,,,,;0.67,0.455,0.042,0.032,,7c7c7c,,,,,,;0.7246,0.485,0.0729,0.032,,747474,,,,,,;0.6949,0.4609,0.1797,0.0345,23.2,808080,,,,,,;",
        "0.7901,0.5094,0.0516,0.0345,42.27,707070,,,,,,;0.7847,0.505,0.0659,0.0345,164.88,686868,,,,,,;0.7152,0.4925,0.111,0.0345,-156.57,6d6d6d,,,,,,;",
        "0.6546,0.4406,0.0877,0.0345,-116.57,7e7e7e,,,,,,;0.6887,0.5402,0.0842,0.0332,,8f8f8f,,,,,,;0.6771,0.5715,0.0818,0.0332,,878787,,,,,,;0.6752,0.6027,0.06,0.0332,,808080,,,,,,;",
        "0.6687,0.634,0.047,0.0332,,787878,,,,,,;0.6552,0.6652,0.048,0.0332,,717171,,,,,,;0.6412,0.6965,0.0502,0.0332,,696969,,,,,,;0.6996,0.5261,0.078,0.0359,26,969696,,,,,,;",
        "0.7084,0.5607,0.0902,0.0359,112.2,888888,,,,,,;0.6692,0.6556,0.1193,0.0359,112.56,717171,,,,,,;0.6191,0.713,0.0832,0.0359,160.82,616161,,,,,,;0.6328,0.6895,0.1392,0.0359,-64.06,6d6d6d,,,,,,;",
        "0.6539,0.5801,0.0748,0.0359,-105.95,848484,,,,,,;0.6639,0.5331,0.0754,0.0359,-50.53,939393,,,,,,;0.587,0.5333,0.036,0.0353,,535353,,,,,,;0.575,0.5667,0.032,0.0353,,4d4d4d,,,,,,;",
        "0.5633,0.6,0.0153,0.0353,,474747,,,,,,;0.6042,0.5096,0.05,0.0383,-20.32,5a5a5a,,,,,,;0.5914,0.5205,0.0877,0.0383,103.5,545454,,,,,,;0.5586,0.5985,0.0992,0.0383,120.96,464646,,,,,,;",
        "0.5741,0.6019,0.1025,0.0383,-84.29,474747,,,,,,;0.5859,0.5305,0.0542,0.0383,-73.3,545454,,,,,,;0.425,0.6167,0.2774,0.014,57.26,262626,,,,,,;0.4833,0.6417,0.3131,0.012,64.8,222222,,,,,,;",
        "0.3042,0.46,0.118,0.012,-23.3,3a3a3a,,,,,,;0.467,0.178,0.068,0.034,,222222,,,,,,;0.4425,0.21,0.117,0.034,,202020,,,,,,;0.4355,0.242,0.131,0.034,,1e1e1e,,,,,,;",
        "0.4383,0.274,0.1253,0.034,,1d1d1d,,,,,,;0.4816,0.21,0.162,0.0368,90,202020,,,,,,;0.3898,0.2585,0.0595,0.0368,-100.01,1d1d1d,,,,,,;0.395,0.2161,0.0572,0.0368,-64.98,202020,,,,,,;",
        "0.453,0.1732,0.1242,0.0368,-25.87,232323,,,,,,;0.5283,0.1731,0.052,0.033,,858585,,,,,,;0.5546,0.204,0.1012,0.033,,808080,,,,,,;0.5635,0.235,0.1127,0.033,,7b7b7b,,,,,,;",
        "0.603,0.266,0.0627,0.033,,767676,,,,,,;0.6171,0.2969,0.0378,0.033,,717171,,,,,,;0.5427,0.1721,0.1215,0.0356,30.14,878787,,,,,,;0.6022,0.226,0.0721,0.0356,64.65,7e7e7e,,,,,,;",
        "0.6181,0.2976,0.0955,0.0356,86.93,717171,,,,,,;0.6301,0.3143,0.0507,0.0356,-141.95,6c6c6c,,,,,,;0.5935,0.2784,0.0635,0.0356,-130.6,727272,,,,,,;",
        "0.5386,0.2413,0.0579,0.0356,-162.65,777777,,,,,,;0.5211,0.1874,0.1255,0.0356,-93.09,828282,,,,,,;0.5379,0.273,0.0442,0.0345,18.43,141414,,,,,,;0.5638,0.296,0.0575,0.0345,57.26,141414,,,,,,;",
        "0.58,0.2857,0.0453,0.0345,-157.38,141414,,,,,,;0.5525,0.2618,0.0547,0.0345,-124.7,141414,,,,,,;0.5,0.305,0.24,0.045,,767676,3e3e3e,,0.25,,stripes,10;0.5,0.3417,0.252,0.032,,060606,,,,,,;",
        "0.5,0.3717,0.2561,0.032,,060606,,,,,,;0.5,0.4017,0.2227,0.032,,060606,,,,,,;0.5,0.4317,0.152,0.032,,060606,,,,,,;0.5,0.4617,0.102,0.032,,060606,,,,,,;0.5,0.4917,0.052,0.032,,060606,,,,,,;",
        "0.6103,0.3645,0.0755,0.0345,86.1,060606,,,,,,;0.5913,0.4102,0.0741,0.0345,139.69,060606,,,,,,;0.5242,0.4806,0.1192,0.0345,129.81,060606,,,,,,;",
        "0.4758,0.4806,0.1192,0.0345,-129.81,060606,,,,,,;0.4087,0.4102,0.0741,0.0345,-139.69,060606,,,,,,;0.3897,0.3645,0.0755,0.0345,-86.1,060606,,,,,,;",
        "0.442,0.36,0.115,0.05,12,ffffff,,,0.5,0.88,,eye;0.442,0.36,0.08,0.03,12,ffffff,,,0.5,0.6,,eye;0.442,0.36,0.062,0.018,12,ffffff,,,0.45,,,eye;0.558,0.36,0.115,0.05,-12,ffffff,,,0.5,0.88,,eye;",
        "0.558,0.36,0.08,0.03,-12,ffffff,,,0.5,0.6,,eye;0.558,0.36,0.062,0.018,-12,ffffff,,,0.45,,,eye;0.215,0.2808,0.2087,0.06,64.46,0a0a0a,,,0.15,,,;",
        "0.215,0.2808,0.1938,0.044,64.54,a8a8a8,2c2c2c,,,,stripes,8;0.26,0.3292,0.1045,0.026,-33.94,0a0a0a,,,,,,;0.26,0.3292,0.0971,0.013,-34.51,9a9a9a,,,,,,;",
        "0.785,0.2808,0.2087,0.06,115.54,0a0a0a,,,0.15,,,;0.785,0.2808,0.1938,0.044,115.46,a8a8a8,2c2c2c,,,,stripes,8;0.74,0.3292,0.1045,0.026,-146.06,0a0a0a,,,,,,;",
        "0.74,0.3292,0.0971,0.013,-145.49,9a9a9a,,,,,,;0.1425,0.295,0.0954,0.016,70.62,f2f2f2,,,0.5,,,;0.155,0.4017,0.0519,0.02,45,f2f2f2,,,,,,;0.1867,0.4267,0.0447,0.02,26.57,f2f2f2,,,,,,;",
        "0.8575,0.295,0.0954,0.016,109.38,f2f2f2,,,0.5,,,;0.845,0.4017,0.0519,0.02,135,f2f2f2,,,,,,;0.8133,0.4267,0.0447,0.02,153.43,f2f2f2,,,,,,",
    }),
}
local LOGO_CACHE = {}
local function logoPieces(kind)
    if LOGO_CACHE[kind] then return LOGO_CACHE[kind] end
    local list = {}
    for rec in string.gmatch(LOGO_DATA[kind] or "", "[^;]+") do
        local f, i = {}, 0
        for v in string.gmatch(rec .. ",", "([^,]*),") do i = i + 1 f[i] = v end
        list[#list + 1] = {
            x = tonumber(f[1]) or 0, y = tonumber(f[2]) or 0, w = tonumber(f[3]) or 0, h = tonumber(f[4]) or 0, r = tonumber(f[5]) or 0,
            c1 = f[6], c2 = (f[7] ~= "" and f[7]) or nil, g = tonumber(f[8]) or 0, k = tonumber(f[9]) or 0, t = tonumber(f[10]) or 0,
            m = (f[11] ~= "" and f[11]) or nil, p = (f[12] ~= "" and f[12]) or nil,
        }
    end
    LOGO_CACHE[kind] = list
    return list
end
local function hexColor(h)
    h = tostring(h or "000000")
    return Color3.fromRGB(tonumber(h:sub(1, 2), 16) or 0, tonumber(h:sub(3, 4), 16) or 0, tonumber(h:sub(5, 6), 16) or 0)
end
-- Void Hub logo: hooded ninja badge (white swoosh shield, crossed katanas, glowing white slit eyes).
-- Built from Frames so it needs no asset upload; LOGO_IMAGE_ID switches to the real image.
-- Returns holder, eyes (list of the eye frames with their base transparency, for the light-up animation).
function buildLogo(parent, size, z, kind)
    z = z or 10
    local okCg, holder = pcall(function()
        return new("CanvasGroup", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(0, size, 0, size), ZIndex = z, GroupTransparency = 0})
    end)
    if not okCg or not holder then holder = new("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(0, size, 0, size), ZIndex = z, ClipsDescendants = true}) end
    local eyes = {}
    if GV.LOGO_IMAGE_ID ~= "" then
        new("ImageLabel", {Parent = holder, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = GV.LOGO_IMAGE_ID, ScaleType = Enum.ScaleType.Fit, ZIndex = 1})
        return holder, eyes
    end
    kind = kind or (size < 72 and "lite" or "full")
    for i, p in ipairs(logoPieces(kind)) do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(p.x, p.y)
        f.Size = UDim2.fromScale(p.w, p.h)
        f.Rotation = p.r
        f.BackgroundColor3 = (p.c2 or p.m) and Color3.new(1, 1, 1) or hexColor(p.c1)
        f.BackgroundTransparency = p.t
        f.ZIndex = i
        if p.k > 0 then
            local uc = Instance.new("UICorner") uc.CornerRadius = UDim.new(p.k, 0) uc.Parent = f
        end
        if p.c2 or p.m then
            local a, b = hexColor(p.c1), hexColor(p.c2 or p.c1)
            local seq
            if p.m == "stripes" then
                local n = math.max(2, math.min(10, tonumber(p.p) or 6))
                local kp = {ColorSequenceKeypoint.new(0, a)}
                for s = 1, n - 1 do
                    local at = s / n
                    local prev, nxt = (s % 2 == 1) and a or b, (s % 2 == 1) and b or a
                    kp[#kp + 1] = ColorSequenceKeypoint.new(at - 0.002, prev)
                    kp[#kp + 1] = ColorSequenceKeypoint.new(at + 0.002, nxt)
                end
                kp[#kp + 1] = ColorSequenceKeypoint.new(1, (n % 2 == 1) and a or b)
                seq = ColorSequence.new(kp)
            else
                seq = ColorSequence.new(a, b)
            end
            local gr = Instance.new("UIGradient") gr.Color = seq gr.Rotation = p.g gr.Parent = f
        end
        if p.p == "eye" then eyes[#eyes + 1] = {f = f, base = p.t} end
        f.Parent = holder
    end
    return holder, eyes
end
end


-- =====================================================================
-- 8. Toasts (stacked · dark glass · thin accent edge · no icons)
-- =====================================================================
-- V2.4: toasts live in ONE slim column at the top center, just below the Roblox top bar and the
-- Guardian Voice line. The old spots (bottom right on landscape, center on portrait) sat on top of
-- the Blox Fruits skill / attack buttons and the quest panel. Phones show at most 2 at once.
local toastHolder = new("Frame", {Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.new(0, 300, 0, 200), ZIndex = 80},
    {new("UIListLayout", {VerticalAlignment = Enum.VerticalAlignment.Top, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})
GV.toastN = 0
function GV.toastTop()
    local inset = 36
    pcall(function() inset = SVC.GuiService:GetGuiInset().Y end)
    inset = math.max(tonumber(inset) or 36, 36)
    local s = math.max(uiScale.Scale, 0.1)
    -- below the top bar + the (slim) Guardian Voice line; the radar sits top-right, never in this column
    local y = inset / s + 8 + 42
    if layoutMode() == "portrait" and settings.radar then y = math.max(y, (isTouch and 64 or 52) + (isTouch and 112 or 150) + 26 + 42) end
    return y
end
layoutListeners[#layoutListeners + 1] = function(mode)
    local ll = toastHolder:FindFirstChildOfClass("UIListLayout")
    toastHolder.AnchorPoint = Vector2.new(0.5, 0)
    toastHolder.Position = UDim2.new(0.5, 0, 0, GV.toastTop())
    toastHolder.Size = UDim2.new(0, mode == "portrait" and 290 or 310, 0, 200)
    ll.VerticalAlignment = Enum.VerticalAlignment.Top
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
end
pcall(layoutListeners[#layoutListeners], layoutMode())
GV.TOAST_TAG = {info = "NOTICE", ok = "DONE", warn = "CAUTION", bad = "ALERT", star = "VOID HUB", shield = "GUARDIAN"}
local function stripGlyphs(t)
    -- defensive: drop any emoji / pictograph that might still come from game names etc. (keeps normal text)
    t = tostring(t)
    t = string.gsub(t, "[\240-\244][\128-\191][\128-\191][\128-\191]", "")
    t = string.gsub(t, "\226[\152-\155][\128-\191]", "")
    t = string.gsub(t, "\226\156[\128-\191]", "")
    return t
end
local function toast(text, kind, dur)
    if not alive or not toastHolder.Parent then return end
    kind = kind or "info"
    dur = dur or 3.2
    local col = (kind == "ok" and C.green) or (kind == "warn" and C.yellow) or (kind == "bad" and C.red) or C.gold
    GV.toastN += 1
    local live = {}
    for _, ch in ipairs(toastHolder:GetChildren()) do if ch:IsA("Frame") then live[#live + 1] = ch end end
    table.sort(live, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    local keep = (isTouch or layoutMode() ~= "desktop") and 1 or 2   -- + the new one = 2 on phones, 3 on desktop
    for i = 1, #live - keep do pcall(function() live[i]:Destroy() end) end
    pcall(function() toastHolder.Position = UDim2.new(0.5, 0, 0, GV.toastTop()) end)
    -- V2: height follows the text (long honest messages are never cut off), 1-4 lines; V2.4: slimmer
    local lines = math.clamp(math.ceil(#tostring(text) / 46), 1, 4)
    local f = new("Frame", {Parent = toastHolder, BackgroundColor3 = C.panel, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26 + lines * 14),
        LayoutOrder = GV.toastN, ZIndex = 80, ClipsDescendants = true}, {corner(8)})
    local s = stroke(C.line, 1, 1) s.Parent = f
    local holder = new("Frame", {Parent = f, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.new(0, 34, 0, 0), ZIndex = 81})
    local edge = new("Frame", {Parent = holder, BorderSizePixel = 0, BackgroundColor3 = col, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.new(0, 2, 1, -16), Rotation = 14, ZIndex = 82})
    NJ.slash(f, "tr", 12, 84, 0.4)
    local tagL = label(holder, {Position = UDim2.new(0, 14, 0, 5), Size = UDim2.new(1, -24, 0, 11), Font = F.bold, Text = spaced(GV.TOAST_TAG[kind] or "NOTICE"),
        TextColor3 = col, TextSize = 8, ZIndex = 82, TextTransparency = 1})
    local l = label(holder, {Position = UDim2.new(0, 14, 0, 16), Size = UDim2.new(1, -24, 1, -18), Text = stripGlyphs(text), TextSize = 11, Font = F.medium,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 82, TextTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd})
    local bar = new("Frame", {Parent = f, BackgroundColor3 = col, BackgroundTransparency = 0.55, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = 83})
    tween(f, 0.22, {BackgroundTransparency = 0.06}) tween(s, 0.22, {Transparency = 0}) tween(l, 0.22, {TextTransparency = 0}) tween(tagL, 0.22, {TextTransparency = 0.1})
    tween(holder, 0.24, {Position = UDim2.new(0, 0, 0, 0)})
    tween(bar, dur, {Size = UDim2.new(0, 0, 0, 1)}, Enum.EasingStyle.Linear)
    if settings.sounds and (kind == "bad" or kind == "warn") then sound(GV.SND_TICK, 0.14, kind == "bad" and 0.7 or 1) end
    task.delay(dur, function()
        if not f.Parent then return end
        tween(f, 0.2, {BackgroundTransparency = 1}) tween(s, 0.2, {Transparency = 1}) tween(l, 0.2, {TextTransparency = 1}) tween(tagL, 0.2, {TextTransparency = 1})
        tween(edge, 0.2, {BackgroundTransparency = 1})
        tween(holder, 0.2, {Position = UDim2.new(0, 40, 0, 0)})
        task.wait(0.22)
        pcall(function() f:Destroy() end)
    end)
end

-- Open the Premium-key Discord invite. Prefer a real browser open when the executor
-- exposes one; always try clipboard so the link still works on locked-down clients.
local function openKeyInvite()
    local url = tostring(GV.DISCORD_INVITE or "")
    if url == "" then return false end
    local opened = false
    local openers = {
        exfn("open_url"),
        exfn("openurl"),
        exfn("OpenUrl"),
        (type(syn) == "table" and type(syn.open_url) == "function" and syn.open_url) or nil,
        (type(fluxus) == "table" and type(fluxus.open_url) == "function" and fluxus.open_url) or nil,
    }
    for _, f in ipairs(openers) do
        if type(f) == "function" and select(1, pcall(f, url)) then
            opened = true
            break
        end
    end
    if not opened then
        pcall(function()
            if SVC.GuiService and type(SVC.GuiService.OpenBrowserWindow) == "function" then
                SVC.GuiService:OpenBrowserWindow(url)
                opened = true
            end
        end)
    end
    local copied = copy(url)
    if opened and copied then
        toast("Discord opened · invite also copied.", "ok", 3.5)
    elseif opened then
        toast("Opening Discord invite…", "ok", 3)
    elseif copied then
        toast("Invite copied. Paste in your browser to get a key.", "ok", 4)
    else
        toast("Get your key: " .. url, "info", 6)
    end
    if settings.sounds then sound(GV.SND_TICK, 0.18, 1.15) end
    return opened or copied
end
HUB.openKeyInvite = openKeyInvite

-- =====================================================================
-- 9. Window factory (near-black glass · hairline edge with a travelling glint · drag)
-- =====================================================================
-- very sparse dust motes (desktop only, never in Performance Mode)
local function starfield(parent, count)
    if not settings.particles or PERF.lite then return end
    count = math.min(count or 10, 10)
    local layer = new("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0})
    local stars = {}
    for i = 1, count do
        local st = new("Frame", {Parent = layer, BorderSizePixel = 0, BackgroundColor3 = (i % 3 == 0) and C.gold or C.text,
            BackgroundTransparency = 0.7 + math.random() * 0.25, Size = UDim2.new(0, 1, 0, 1),
            Position = UDim2.fromScale(math.random(), math.random()), ZIndex = 0})
        stars[i] = {f = st, speed = 0.002 + math.random() * 0.005, phase = math.random() * 6}
    end
    local id = "stars" .. tostring(layer)
    local acc = 0
    onHeartbeat(id, function(frameDt)
        if not layer.Parent then heartbeatJobs[id] = nil return end
        if PERF.lite then layer.Visible = false return end
        acc += frameDt
        if acc < 1 / 20 then return end
        local dt = acc
        acc = 0
        local t = os.clock()
        for _, s in ipairs(stars) do
            local p = s.f.Position
            local y = p.Y.Scale - s.speed * dt * 4
            if y < -0.02 then y = 1.02 end
            s.f.Position = UDim2.fromScale(p.X.Scale + math.sin(t + s.phase) * 0.0001, y)
        end
    end)
    return layer
end

local function makeDraggable(handle, target)
    local dragging, startPos, startInput
    bind(handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, target.Position, i.Position
            local c
            c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false if c then c:Disconnect() end end
            end)
        end
    end))
    bind(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - startInput) / uiScale.Scale
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

local function makeWindow(w, h)
    local win = new("Frame", {Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, w, 0, h), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 1},
        {corner(2), new("UIGradient", {Rotation = 120, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 19)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(11, 11, 12)), ColorSequenceKeypoint.new(1, C.bg)})})})
    -- soft drop shadow behind the panel
    local shadow = new("Frame", {Parent = win, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.new(1, 40, 1, 40), ZIndex = 0}, {corner(12),
        new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.4), NumberSequenceKeypoint.new(0.88, 0.4), NumberSequenceKeypoint.new(1, 1)})})})
    shadow.Visible = not PERF.lite
    -- top sheen: one hairline of light, like the edge of glass
    new("Frame", {Parent = win, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -32, 0, 1), ZIndex = 2},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    -- katana streak: one faint diagonal cut of light across the panel, plus slash marks on two corners
    new("Frame", {Parent = win, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.965, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.62, 0, 0.4, 0), Size = UDim2.new(0, math.floor(math.sqrt(w * w + h * h) * 0.9), 0, 1), Rotation = -math.deg(math.atan2(h, w)) * 0.8, ZIndex = 0},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0), NumberSequenceKeypoint.new(1, 1)})})})
    new("Frame", {Parent = win, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.96, Size = UDim2.new(0.5, 0, 0.42, 0), ZIndex = 0},
        {corner(2), new("UIGradient", {Rotation = 35, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})})})
    NJ.slash(win, "tr", 18, 6, 0.25)
    NJ.slash(win, "bl", 18, 6, 0.45)
    starfield(win, 10)
    local border = animatedBorder(win, 1)
    local sc = new("UIScale", {Scale = 0.94, Parent = win})
    tween(win, 0.25, {BackgroundTransparency = 0.03})
    tween(sc, 0.25, {Scale = 1})
    local top = new("Frame", {Parent = win, BackgroundTransparency = 1, Size = UDim2.new(1, -140, 0, 50), ZIndex = 5})
    makeDraggable(top, win)
    return win, sc, border
end

local function fadeOutWindow(win, sc)
    tween(sc, 0.18, {Scale = 0.95})
    tween(win, 0.18, {BackgroundTransparency = 1})
    for _, d in ipairs(PERF.lite and {} or win:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then tween(d, 0.2, {TextTransparency = 1, BackgroundTransparency = 1})
        elseif d:IsA("ImageLabel") then tween(d, 0.2, {ImageTransparency = 1, BackgroundTransparency = 1})
        elseif d:IsA("Frame") then tween(d, 0.2, {BackgroundTransparency = 1})
        elseif d:IsA("UIStroke") then tween(d, 0.18, {Transparency = 1}) end
    end
    task.wait(0.2)
    pcall(function() win:Destroy() end)
end

-- =====================================================================
-- 10. Backdrop (black veil used behind the key screen; the cinematic loading screen is section 13)
-- =====================================================================
local function splash()
    -- intentionally tiny: the real intro is the loading screen, which runs the real boot steps
end
local function backdrop(z)
    local f = new("Frame", {Parent = gui, BackgroundColor3 = C.bg, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z or 0, Active = true})
    tween(f, 0.3, {BackgroundTransparency = 0.25})
    return f
end

-- =====================================================================
-- 11. Key screen
-- =====================================================================
local function keyScreen(onDone)
    local veil = backdrop(0)
    local win, sc = makeWindow(392, 272)
    -- the ninja badge next to the wordmark; a slanted blade tick under it
    local kMark = buildLogo(win, 44, 6)
    kMark.Position = UDim2.new(0, 18, 0, 10)
    local t = label(win, {Position = UDim2.new(0, 70, 0, 20), Size = UDim2.new(0, 200, 0, 24), Font = F.display, Text = spaced("Void Hub"), TextSize = 18, ZIndex = 6})
    shimmerText(t)
    premiumBadge(win, UDim2.new(1, -98, 0, 23))
    new("Frame", {Parent = win, BorderSizePixel = 0, BackgroundColor3 = C.gold, Position = UDim2.new(0, 70, 0, 48), Size = UDim2.new(0, 28, 0, 2), ZIndex = 6})
    label(win, {Position = UDim2.new(0, 24, 0, 62), Size = UDim2.new(1, -48, 0, 34), Font = F.reg, TextWrapped = true, TextColor3 = C.sub, TextSize = 12,
        Text = "Enter your Premium key to unlock the full Void Hub.", ZIndex = 6})
    local boxF = new("Frame", {Parent = win, BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Position = UDim2.new(0, 24, 0, 104), Size = UDim2.new(1, -48, 0, 44), ZIndex = 6}, {corner(8)})
    local bs = stroke(C.purple, 1, 0) bs.Parent = boxF
    label(boxF, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0, 40, 1, 0), Text = "KEY", Font = F.bold, TextColor3 = C.faint, TextSize = 10, ZIndex = 7})
    local box = new("TextBox", {Parent = boxF, BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 0), Size = UDim2.new(1, -62, 1, 0),
        Font = F.medium, PlaceholderText = "Paste key here", PlaceholderColor3 = C.faint, Text = "", ClearTextOnFocus = false,
        TextColor3 = C.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
    bind(box.Focused:Connect(function() tween(bs, 0.2, {Color = C.gold}) end))
    bind(box.FocusLost:Connect(function() tween(bs, 0.2, {Color = C.purple}) end))
    local status = label(win, {Position = UDim2.new(0, 24, 1, -32), Size = UDim2.new(1, -48, 0, 20), Font = F.medium, TextSize = 11,
        TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6})
    local busy = false
    local go
    local function shake()
        local p = win.Position
        for _, dx in ipairs({-10, 8, -5, 2, 0}) do
            tween(win, 0.04, {Position = p + UDim2.new(0, dx, 0, 0)}, Enum.EasingStyle.Sine) task.wait(0.04)
        end
        win.Position = p
    end
    local function success()
        go.Visible = false boxF.Visible = false status.Text = ""
        local ok = label(win, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.new(1, 0, 0, 30),
            Font = F.display, Text = spaced("Unlocked"), TextColor3 = C.text, TextSize = 20, TextTransparency = 1, ZIndex = 8, TextXAlignment = Enum.TextXAlignment.Center})
        local ln = new("Frame", {Parent = win, BorderSizePixel = 0, BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 164),
            Size = UDim2.new(0, 0, 0, 2), ZIndex = 8})
        tween(ok, 0.25, {TextTransparency = 0}) tween(ln, 0.25, {Size = UDim2.new(0, 120, 0, 2)})
        if settings.sounds then sound(GV.SND_TICK, 0.22, 1.3) end
        task.wait(0.55)
        fadeOutWindow(win, sc)
        tween(veil, 0.25, {BackgroundTransparency = 1})
        task.delay(0.3, function() pcall(function() veil:Destroy() end) end)
        onDone()
    end
    local function try()
        if busy then return end
        if hubHash(trim(box.Text)) == GV.KEY_HASH then
            busy = true
            save(GV.KEY_FILE, trim(box.Text))
            success()
        else
            status.Text = "Invalid key. Tap Get Key for Discord." status.TextColor3 = C.red
            tween(bs, 0.1, {Color = C.red})
            if settings.sounds then sound(GV.SND_TICK, 0.2, 0.6) end
            shake()
            tween(bs, 0.25, {Color = C.purple})
        end
    end
    -- Get Key (Discord) + Unlock side by side
    button(win, "Get Key", {Position = UDim2.new(0, 24, 0, 162), Size = UDim2.new(0.5, -28, 0, 44), TextSize = 13, ZIndex = 6}, openKeyInvite)
    go = goldButton(win, "Unlock", {Position = UDim2.new(0.5, 4, 0, 162), Size = UDim2.new(0.5, -28, 0, 44), TextSize = 14, ZIndex = 6}, try)
    bind(box.FocusLost:Connect(function(enter) if enter then try() end end))
end

-- =====================================================================
-- 12. Game info + Guardian core
-- =====================================================================
GV.GAME_NAME = "Unknown game"
pcall(function() GV.GAME_NAME = SVC.MarketplaceService:GetProductInfo(game.PlaceId).Name end)

-- ---------------------------------------------------------------------
-- 12a. Game detection (4.0): game.GameId (universe) + game.PlaceId, built-in table first,
--      then the Roblox games API (rootPlaceId + name), then the place name. Every remote call is
--      pcall'd and has a timeout; the result and its source are shown in the UI.
--   Why Blox Fruits showed "no matching scripts": the old lookup searched ScriptBlox for the raw
--   place name ("[UPDATE] Blox Fruits" with emoji tags) AND a placeId at the same time, which returns
--   0 results. 4.0 asks ScriptBlox by the game's root PlaceId first, then the current PlaceId,
--   then a cleaned-up name.
-- ---------------------------------------------------------------------
GV.KNOWN_GAMES = {
    [994732206] = {name = "Blox Fruits", root = 2753915549, module = "bloxfruits",
        places = {[2753915549] = "First Sea", [4442272183] = "Second Sea", [7449423635] = "Third Sea"}},
}
GV.KNOWN_PLACES = {}
for gid, g in pairs(GV.KNOWN_GAMES) do for pid in pairs(g.places) do GV.KNOWN_PLACES[pid] = gid end end

local function cleanGameName(n)
    n = tostring(n or "")
    n = string.gsub(n, "%b[]", " ")             -- [UPDATE 24], [EVENT]
    n = string.gsub(n, "%b()", " ")             -- (x2 XP)
    n = string.gsub(n, "[\128-\255]+", " ")     -- emojis / non-ASCII decorations
    n = string.gsub(n, "[|:!%-]+", " ")
    for _, w in ipairs({"UPDATE", "Update", "update", "NEW", "New!", "EVENT", "Event", "RELEASE", "BETA", "Beta"}) do
        n = string.gsub(n, "%f[%w]" .. w .. "%f[%W]", " ")
    end
    n = string.gsub(n, "%d+x%s", " ")
    n = string.gsub(n, "%s+", " ")
    n = trim(n)
    if n == "" then n = trim(tostring(GV.GAME_NAME)) end
    return n
end

local GAMEINFO = {gameId = 0, placeId = 0, root = 0, name = GV.GAME_NAME, clean = cleanGameName(GV.GAME_NAME), sub = nil, known = nil,
    source = "place name", module = nil, moduleName = "Universal", moduleLoaded = false, notes = {}, tune = {}, detected = false}
pcall(function() GAMEINFO.gameId = tonumber(game.GameId) or 0 end)
pcall(function() GAMEINFO.placeId = tonumber(game.PlaceId) or 0 end)
GAMEINFO.root = GAMEINFO.placeId

-- per-game modules: honest notes + runtime tuning; never anything offensive
GV.GAME_MODULES = {
    bloxfruits = {
        title = "Blox Fruits",
        npcServerSide = false,   -- NPCs are simulated and owned by the server; a client cannot reset them for everyone
        npcFolders = {"Enemies"},
        notes = {
            "NPC Reset: not supported here. Blox Fruits NPCs are server-owned, so a reset would only be visible to you.",
            "NPC Evade replaces it: Guardian steps you out of an NPC's attack instead.",
            "Combos hit hard here, so Guardian Control also watches the damage rate, not just your health.",
            "Ability Assist uses YOUR Ken (E) and Dash (Q) on the default PC keys to escape (Soru: set your key). Never to attack.",
            "Water Guard: the sea here is a moving mesh at a fixed level (not Roblox water). A solid surface sits at that level while Guardian Control is on, so the sea can't take you.",
            "Mobs in workspace.Enemies are simulated by the closest player: when you are near, Companion Hold and Mob Gather can hold them (checked live per mob).",
        },
        tune = {rescueDpsFactor = 0.3, npcEvadeRange = 16},
        -- V2.3 game profile: what the Explorer Scanner, the Lifeline, Water Guard and Mob Gather know about this game
        profile = {
            enemies = "Enemies",                   -- every hostile NPC lives in workspace.Enemies
            spawns = {"_WorldOrigin", "EnemySpawns"},  -- mob spawn markers
            questNpcs = "NPCs",                    -- quest givers / shops
            seaLevel = -4,                         -- ocean surface (studs); damage starts below it
            waterHurts = true,
            mobsMovable = true,                    -- the server hands nearby mobs to the closest client
            escapeDist = 75,                       -- mobs leash back to their spawn: ~75 studs is out of aggro
            styles = {["Melee"] = "melee", ["Sword"] = "sword", ["Blox Fruit"] = "fruit", ["Gun"] = "gun"},
            keys = {m1 = "MouseButton1", dash = "Q", ken = "E", buso = "J", skills = {"Z", "X", "C", "V", "F"}},
        },
        -- your own abilities on the default PC keys (Ability Assist presses them through VirtualInputManager; change keys in Defense)
        abilities = {
            {id = "ken", kind = "sense", label = "Observation (Ken)", key = "E", cd = 40, toggle = true},
            {id = "dash", kind = "dash", label = "Dash", key = "Q", cd = 1.4},
            {id = "soru", kind = "dash", label = "Soru / Flash Step", key = "", cd = 3},   -- no default: set your own key
        },
    },
}
local function universalModule()
    return {title = "Universal", npcServerSide = nil, npcFolders = {}, notes = {
        "No game-specific module for this game. Every Guardian feature checks itself and turns off when the game does not accept it.",
    }, tune = {}}
end

function GAMEINFO.detect(timeout)
    timeout = timeout or 1.6
    local gid, pid = GAMEINFO.gameId, GAMEINFO.placeId
    local k = GV.KNOWN_GAMES[gid]
    if not k and GV.KNOWN_PLACES[pid] then k = GV.KNOWN_GAMES[GV.KNOWN_PLACES[pid]] gid = GV.KNOWN_PLACES[pid] end
    if k then
        GAMEINFO.known = k
        GAMEINFO.name = k.name
        GAMEINFO.clean = k.name
        GAMEINFO.root = k.root
        GAMEINFO.sub = k.places[pid]
        GAMEINFO.source = "built-in table (GameId " .. tostring(gid) .. ")"
        GAMEINFO.detected = true
        return true
    end
    -- unknown game: ask the Roblox games API for the universe's root place + clean name
    if gid > 0 then
        local done = false
        task.spawn(function()
            local d = getJSON("https://games.roblox.com/v1/games?universeIds=" .. tostring(gid))
            local g = d and type(d.data) == "table" and d.data[1]
            if type(g) == "table" then
                if tonumber(g.rootPlaceId) then GAMEINFO.root = tonumber(g.rootPlaceId) end
                if type(g.name) == "string" and g.name ~= "" then GAMEINFO.name = g.name GAMEINFO.clean = cleanGameName(g.name) end
                GAMEINFO.source = "Roblox games API (GameId " .. tostring(gid) .. ")"
            end
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < timeout do task.wait(0.05) end
        if not done then GAMEINFO.source = "place name (games API slow / blocked)" end
    end
    GAMEINFO.detected = true
    return GAMEINFO.known ~= nil
end

function GAMEINFO.loadModule()
    local key = GAMEINFO.known and GAMEINFO.known.module
    local m = key and GV.GAME_MODULES[key] or universalModule()
    GAMEINFO.module = m
    GAMEINFO.moduleName = m.title
    GAMEINFO.notes = m.notes or {}
    GAMEINFO.tune = m.tune or {}
    GAMEINFO.moduleLoaded = true
    return m
end

function GAMEINFO.label()
    local t = GAMEINFO.name
    if GAMEINFO.sub then t = t .. " · " .. GAMEINFO.sub end
    return stripGlyphs(t)
end

-- ScriptBlox lookups for "This Game", most precise first
function GAMEINFO.scriptUrls(common)
    local urls, seen = {}, {}
    local function add(u, why) if not seen[u] then seen[u] = true urls[#urls + 1] = {u, why} end end
    if GAMEINFO.root and GAMEINFO.root > 0 then add(GV.SB .. "/api/script/fetch?placeId=" .. GAMEINFO.root .. common, "root PlaceId " .. GAMEINFO.root) end
    if GAMEINFO.placeId > 0 then add(GV.SB .. "/api/script/fetch?placeId=" .. GAMEINFO.placeId .. common, "PlaceId " .. GAMEINFO.placeId) end
    if GAMEINFO.clean ~= "" then add(GV.SB .. "/api/script/search?q=" .. enc(GAMEINFO.clean) .. common, "name search \"" .. GAMEINFO.clean .. "\"") end
    return urls
end

local function pingMs()
    local p = 0
    pcall(function() p = math.floor(SVC.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    if p == 0 then pcall(function() p = math.floor(LP:GetNetworkPing() * 1000) end) end
    return p
end
local function executorName()
    local n = "Unknown"
    local idf = exfn("identifyexecutor") or exfn("getexecutorname")
    if idf then pcall(function() local a, b = idf() n = tostring(a) .. (b and (" " .. tostring(b)) or "") end) end
    return n
end
local function char() return LP.Character end
local function hum() local c = char() return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = char() return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart) end

GV.STAFF_WORDS = {"admin", "mod", "staff", "dev", "owner"}
local guardian = {staff = {}, suspicious = {}, ping = 0, score = 0, level = "Safe", reasons = {}, listeners = {}}

local function checkPlayer(p)
    if p == LP then return nil, nil end
    local staff, sus
    pcall(function()
        if game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId then staff = "Game owner" end
    end)
    if not staff then
        pcall(function()
            if game.CreatorType == Enum.CreatorType.Group then
                local rank = p:GetRankInGroup(game.CreatorId)
                local role = string.lower(p:GetRoleInGroup(game.CreatorId) or "")
                local hit = rank >= 200
                for _, w in ipairs(GV.STAFF_WORDS) do if string.find(role, w, 1, true) then hit = true end end
                if hit and rank > 0 then staff = "Group " .. p:GetRoleInGroup(game.CreatorId) .. " (" .. rank .. ")"
                elseif rank >= 100 then sus = "High group rank (" .. rank .. ")" end
            end
        end)
    end
    if not staff then pcall(function() if p:IsInGroup(1200769) then staff = "Roblox staff" end end) end
    if not staff then
        local n = string.lower(p.Name .. " " .. p.DisplayName)
        for _, w in ipairs(GV.STAFF_WORDS) do
            if string.find(n, w, 1, true) then sus = sus or ("Name contains '" .. w .. "'") break end
        end
    end
    if not sus then pcall(function() if p.AccountAge < 7 then sus = "New account (" .. p.AccountAge .. "d)" end end) end
    if not sus and not staff then
        pcall(function()
            if game.CreatorType == Enum.CreatorType.User and p:IsFriendsWith(game.CreatorId) then sus = "Friend of the game owner" end
        end)
    end
    return staff, sus
end

-- Visual effects for Guardian actions (filled in by section 14f2; every call is nil-safe)
local VFX = {}
-- Guardian Brain (filled in by section 14g; safe defaults until then)
local brain = {
    situation = "Exploring", strategy = "Normal watch",
    capSpeed = function(v) return v end,
    capFly = function(v) return v end,
    showThreat = function() return false end,
    colorEsp = function() end,
    riskExtra = nil, noteTp = nil, tpStepped = function() return false end,
    onForcedStat = function() end,
    ownMove = function() end,   -- tells the rubberband detector that the hub moved you on purpose
}

-- Weighted risk score 0-100
local function computeRisk()
    local score, reasons = 0, {}
    local me = hrp()
    local staffHere, nearStaff = 0, nil
    for id, why in pairs(guardian.staff) do
        local p = Players:GetPlayerByUserId(id)
        if p then
            staffHere += 1
            reasons[#reasons + 1] = {"bad", p.DisplayName .. " · " .. why}
            local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if me and r and (r.Position - me.Position).Magnitude < 90 then nearStaff = p.DisplayName end
        end
    end
    score += math.min(staffHere * 45, 70)
    local susHere = 0
    for id, why in pairs(guardian.suspicious) do
        local p = Players:GetPlayerByUserId(id)
        if p then susHere += 1 reasons[#reasons + 1] = {"warn", p.DisplayName .. " · " .. why} end
    end
    score += math.min(susHere * 8, 24)
    local cheating = settings.fly or settings.noclip or settings.freecam or (tonumber(settings.walkspeed) or 16) > 40
    if cheating then
        score += 6
        reasons[#reasons + 1] = {"warn", "Movement cheats active"}
        if nearStaff then score += 30 reasons[#reasons + 1] = {"bad", "Staff " .. nearStaff .. " is close to you"} end
    end
    if guardian.ping > 250 then score += 6 reasons[#reasons + 1] = {"warn", "High ping (" .. guardian.ping .. " ms)"} end
    if brain.riskExtra then
        local ok, add, extra = pcall(brain.riskExtra, cheating)
        if ok and type(add) == "number" then
            score += add
            for _, r in ipairs(extra or {}) do reasons[#reasons + 1] = r end
        end
    end
    score = clamp(score, 0, 100)
    if #reasons == 0 then reasons[1] = {"ok", "No threats detected"} end
    local level = (score >= 60 and "Danger") or (score >= 25 and "Caution") or "Safe"
    return score, level, reasons
end
local function guardianRefresh(why)
    local score, level, reasons = computeRisk()
    local prev = guardian.level
    guardian.score, guardian.level, guardian.reasons = score, level, reasons
    for _, f in ipairs(guardian.listeners) do pcall(f, score, level, reasons, prev, why) end
end

-- =====================================================================
-- 13. Cinematic loading screen (~3 s, tap to skip) running the REAL boot steps:
--     game detection, game module, executor check, server scan (staff / flagged), script library, assets.
--     Slow web checks keep running in the background and report later.
-- =====================================================================
local function securityScan(onDone)
    local lite = PERF.lite
    local skip = false
    local root = new("TextButton", {Parent = gui, AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 200})
    bind(root.Activated:Connect(function() skip = true end))
    HUB.bootRoot = root
    tweenL(root, 0.25, {BackgroundTransparency = 0})
    -- charcoal floor light + dark vignette, so it is not a flat black slab
    new("Frame", {Parent = root, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(58, 58, 62), BackgroundTransparency = 0.82, Size = UDim2.fromScale(1, 1), ZIndex = 200},
        {new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 0.25)})})})
    local center = new("Frame", {Parent = root, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
        Size = UDim2.new(0, 420, 0, 340), ZIndex = 201})
    -- ink smoke: big soft charcoal puffs that drift and breathe behind the badge
    local smoke = {}
    for i = 1, (lite and 3 or 7) do
        local sz = 150 + (i % 3) * 60
        local p = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(70, 70, 74), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.random(-150, 150), 0, 70 + math.random(-30, 60)), Size = UDim2.new(0, sz, 0, sz * 0.7), ZIndex = 201},
            {new("UICorner", {CornerRadius = UDim.new(0.5, 0)}),
            new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1)}), Rotation = math.random(0, 180)})})
        smoke[i] = {f = p, vx = (math.random() - 0.5) * 14, ph = math.random() * 6, base = 0.8 + math.random() * 0.12}
    end
    local halo = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(0, 230, 0, 230), ZIndex = 201}, {new("UICorner", {CornerRadius = UDim.new(0.5, 0)}),
        new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1)})})})
    local LOGO = 150
    local logo, eyes = buildLogo(center, LOGO, 202, lite and "lite" or "full")
    logo.AnchorPoint = Vector2.new(0.5, 0.5) logo.Position = UDim2.new(0.5, 0, 0, 72)
    local logoScale = new("UIScale", {Parent = logo, Scale = 0.94})
    for _, e in ipairs(eyes) do e.f.BackgroundTransparency = 1 end
    -- katana cut: a black veil in two halves along a diagonal; the slash passes, the halves slide apart
    local CUT = -32
    local ca, sa = math.cos(math.rad(CUT)), math.sin(math.rad(CUT))
    local nx, ny = -sa, ca
    local VS = LOGO * 2.4
    local halves = {}
    for i, sgn in ipairs({-1, 1}) do
        halves[i] = new("Frame", {Parent = logo, BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, sgn * nx * VS / 2, 0.5, sgn * ny * VS / 2), Size = UDim2.new(0, VS, 0, VS), Rotation = CUT, ZIndex = 900})
    end
    local slash = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(0, 0, 0, 2), Rotation = CUT, ZIndex = 206},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1)})})})
    local slashGlow = new("Frame", {Parent = slash, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 12), ZIndex = 205},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1)})})})
    -- eye flare: two soft white streaks over the badge's eyes
    local flares = {}
    for i, sgn in ipairs({-1, 1}) do
        flares[i] = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, sgn * LOGO * 0.058, 0, 72 + (0.36 - 0.5) * LOGO), Size = UDim2.new(0, 46, 0, 10), Rotation = -sgn * 12, ZIndex = 207},
            {new("UICorner", {CornerRadius = UDim.new(0.5, 0)}),
            new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1)})})})
    end
    -- dark ink motes drifting up (desktop only); kept the old name so the outro can fade them
    local embers = {}
    if not lite and settings.particles ~= false then
        for i = 1, 14 do
            local sz = (i % 4 == 0) and 3 or 2
            local e = new("Frame", {Parent = root, BorderSizePixel = 0, BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 126),
                BackgroundTransparency = 0.55 + math.random() * 0.35, Rotation = 45,
                Size = UDim2.new(0, sz, 0, sz), Position = UDim2.fromScale(math.random(), 0.6 + math.random() * 0.5), ZIndex = 200})
            embers[i] = {f = e, v = 0.03 + math.random() * 0.05, ph = math.random() * 6}
        end
    end
    onRender("bootEmbers", function(dt)
        if not root.Parent then renderJobs.bootEmbers = nil return end
        local t = os.clock()
        for _, e in ipairs(embers) do
            local p = e.f.Position
            local y = p.Y.Scale - e.v * dt
            if y < -0.05 then y = 1.05 end
            e.f.Position = UDim2.fromScale(p.X.Scale + math.sin(t * 0.8 + e.ph) * 0.0003, y)
        end
        for _, s in ipairs(smoke) do
            local p = s.f.Position
            local x = p.X.Offset + s.vx * dt
            if math.abs(x) > 190 then s.vx = -s.vx end
            s.f.Position = UDim2.new(0.5, x, 0, p.Y.Offset)
            if s.live then s.f.BackgroundTransparency = s.base + math.sin(t * 0.7 + s.ph) * 0.05 end
        end
    end)
    -- angled divider (blade line with a diamond tsuba) and the wordmark letter by letter
    local topLine = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 168),
        Size = UDim2.new(0, 0, 0, 1), ZIndex = 202},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    local tsuba = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 168),
        Size = UDim2.new(0, 0, 0, 0), Rotation = 45, ZIndex = 203})
    local glow = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 202), Size = UDim2.new(0, 360, 0, 60), ZIndex = 201}, {new("UICorner", {CornerRadius = UDim.new(0.5, 0)}),
        new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1)})})})
    local word = new("Frame", {Parent = center, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 202),
        Size = UDim2.new(1, 0, 0, 50), ZIndex = 203}, {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7)})})
    local letters = {}
    local TEXT = "VOID HUB"
    for i = 1, #TEXT do
        local ch = string.sub(TEXT, i, i)
        local l = label(word, {Size = UDim2.new(0, ch == " " and 12 or 0, 0, 50), AutomaticSize = (ch == " ") and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
            Font = F.display, Text = ch, TextSize = 30, TextTransparency = 1, TextColor3 = C.text, LayoutOrder = i, ZIndex = 203, TextXAlignment = Enum.TextXAlignment.Center})
        local pd = new("UIPadding", {Parent = l, PaddingTop = UDim.new(0, 14)})
        letters[#letters + 1] = {l = l, pd = pd}
    end
    local subL = label(center, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 232), Size = UDim2.new(1, 0, 0, 14), Font = F.medium,
        Text = spaced("The creator protects you"), TextSize = 10, TextColor3 = C.sub, TextTransparency = 1, ZIndex = 203, TextXAlignment = Enum.TextXAlignment.Center})
    -- loading bar: a thin blade with a bright tip and a shine that sweeps along the steel
    local track = new("Frame", {Parent = center, BorderSizePixel = 0, BackgroundColor3 = C.line, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 272),
        Size = UDim2.new(0, 280, 0, 2), BackgroundTransparency = 1, ZIndex = 202})
    local fill = new("Frame", {Parent = track, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(150, 150, 156), Size = UDim2.new(0, 0, 1, 0), ZIndex = 203, ClipsDescendants = true},
        {new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(110, 110, 116), Color3.new(1, 1, 1))})})
    local shine = new("Frame", {Parent = fill, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0, -40, 0, 0), ZIndex = 204},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    local fillGlow = new("Frame", {Parent = track, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 6, 0, 6), Rotation = 45, ZIndex = 205})
    local stepL = label(center, {Position = UDim2.new(0.5, -140, 0, 280), Size = UDim2.new(0, 200, 0, 16), Font = F.medium, Text = "", TextSize = 11,
        TextColor3 = C.sub, TextTransparency = 1, ZIndex = 203, TextTruncate = Enum.TextTruncate.AtEnd})
    local pctL = label(center, {Position = UDim2.new(0.5, 80, 0, 280), Size = UDim2.new(0, 60, 0, 16), Font = F.mono, Text = "0%", TextSize = 11,
        TextColor3 = C.goldLight, TextTransparency = 1, ZIndex = 203, TextXAlignment = Enum.TextXAlignment.Right})
    local detailL = label(center, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 300), Size = UDim2.new(0, 280, 0, 14), Font = F.reg, Text = "",
        TextSize = 10, TextColor3 = C.faint, TextTransparency = 1, ZIndex = 203, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd})
    local hint = label(root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(0, 300, 0, 14), Font = F.medium,
        Text = spaced(isTouch and "Tap to skip" or "Click to skip"), TextColor3 = C.faint, TextSize = 9, TextTransparency = 1, ZIndex = 203,
        TextXAlignment = Enum.TextXAlignment.Center})
    local function hold(t)
        local e = 0
        while e < t and not skip and alive do e += task.wait() end
    end
    -- blade shine loop on the loading bar
    task.spawn(function()
        while root.Parent and alive do
            shine.Position = UDim2.new(0, -40, 0, 0)
            tweenL(shine, 0.7, {Position = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Sine)
            task.wait(1.1)
        end
    end)
    -- intro: smoke rises, katana slash, veil splits, eyes ignite, wordmark
    task.spawn(function()
        for _, s in ipairs(smoke) do tweenL(s.f, 0.9, {BackgroundTransparency = s.base}) task.delay(0.9, function() s.live = true end) end
        tweenL(logoScale, 0.9, {Scale = 1})
        task.wait(skip and 0 or 0.25)
        if settings.sounds then sound(GV.SND_TICK, 0.2, 1.6) end
        tweenL(slash, 0.16, {Size = UDim2.new(0, LOGO * 1.9, 0, 2)}, Enum.EasingStyle.Quart)
        task.wait(skip and 0 or 0.14)
        for i, sgn in ipairs({-1, 1}) do
            local d = sgn * 26
            tweenL(halves[i], 0.55, {Position = UDim2.new(0.5, sgn * nx * VS / 2 + nx * d - ca * sgn * 30, 0.5, sgn * ny * VS / 2 + ny * d - sa * sgn * 30),
                BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        end
        tweenL(slash, 0.45, {BackgroundTransparency = 1, Size = UDim2.new(0, LOGO * 2.3, 0, 1)}) tweenL(slashGlow, 0.45, {BackgroundTransparency = 1})
        tweenL(halo, 0.9, {BackgroundTransparency = lite and 0.95 or 0.9})
        task.delay(0.6, function() for _, h in ipairs(halves) do h.Visible = false end end)
        task.wait(skip and 0 or 0.3)
        -- eyes light up white: a quick over-bright flare, then they settle to their glow
        for _, e in ipairs(eyes) do tweenL(e.f, 0.25, {BackgroundTransparency = e.base}) end
        if not lite then
            for _, f in ipairs(flares) do
                f.BackgroundTransparency = 0.2 f.Size = UDim2.new(0, 10, 0, 6)
                tweenL(f, 0.18, {Size = UDim2.new(0, 70, 0, 10)}, Enum.EasingStyle.Quart)
                task.delay(0.18, function() tweenL(f, 0.6, {BackgroundTransparency = 1, Size = UDim2.new(0, 40, 0, 6)}) end)
            end
        end
        task.wait(skip and 0 or 0.2)
        tweenL(topLine, 0.45, {Size = UDim2.new(0, 150, 0, 1)}) tweenL(tsuba, 0.35, {Size = UDim2.new(0, 6, 0, 6)})
        for i, L in ipairs(letters) do
            if skip then break end
            tweenL(L.l, 0.35, {TextTransparency = 0}) tweenL(L.pd, 0.35, {PaddingTop = UDim.new(0, 0)})
            task.wait(0.04)
        end
        for _, L in ipairs(letters) do L.l.TextTransparency = 0 L.pd.PaddingTop = UDim.new(0, 0) end
        if not lite then
            tweenL(glow, 0.6, {BackgroundTransparency = 0.95})
            for _, L in ipairs(letters) do shimmerText(L.l) end
        end
        tweenL(subL, 0.4, {TextTransparency = 0.1}) tweenL(track, 0.4, {BackgroundTransparency = 0})
        tweenL(stepL, 0.4, {TextTransparency = 0}) tweenL(pctL, 0.4, {TextTransparency = 0}) tweenL(detailL, 0.4, {TextTransparency = 0})
        tweenL(hint, 0.4, {TextTransparency = 0.2})
    end)
    if settings.sounds then sound(GV.SND_TICK, 0.18, 0.7) end

    -- background web checks start right away
    local pending, staffNames = 0, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            pending += 1
            task.spawn(function()
                local ok, st, su = pcall(checkPlayer, p)
                if ok then
                    if st then guardian.staff[p.UserId] = st staffNames[#staffNames + 1] = p.DisplayName end
                    if su then guardian.suspicious[p.UserId] = su end
                end
                pending -= 1
            end)
        end
    end
    local libState = nil
    task.spawn(function() libState = (cachedJSON(GV.SB .. "/api/script/trending", 300) ~= nil) end)
    local results = {}
    local steps = {
        {"Detecting game", 0.45, function()
            GAMEINFO.detect(1.4)
            return "ok", GAMEINFO.label() .. "  ·  GameId " .. GAMEINFO.gameId .. "  ·  PlaceId " .. GAMEINFO.placeId
        end},
        {"Loading game module", 0.35, function()
            local m = GAMEINFO.loadModule()
            return "ok", m.title .. " module loaded"
        end},
        {"Checking executor", 0.3, function()
            local caps = {"request", "writefile", "readfile", "setclipboard", "fireproximityprompt", "getgenv", "gethui"}
            local have = 0
            for _, c in ipairs(caps) do if exfn(c) or (c == "request" and requestFn) then have += 1 end end
            return (have >= 4) and "ok" or "warn", executorName() .. "  ·  " .. have .. "/" .. #caps .. " functions"
        end},
        {"Scanning server", 0.45, function()
            local t0 = os.clock()
            while pending > 0 and not skip and os.clock() - t0 < 1.2 do task.wait(0.05) end
            guardian.ping = pingMs()
            local n = #staffNames
            if n > 0 then return "bad", n .. " staff in this server" end
            local f = countKeys(guardian.suspicious)
            return f > 0 and "warn" or "ok", (pending > 0 and "still checking" or (f > 0 and (f .. " flagged player(s)") or "no staff")) .. "  ·  " .. guardian.ping .. " ms"
        end},
        {"Connecting to script library", 0.3, function()
            local t0 = os.clock()
            while libState == nil and not skip and os.clock() - t0 < 1.2 do task.wait(0.05) end
            if libState == nil then return "warn", "ScriptBlox slow, continuing" end
            return libState and "ok" or "warn", libState and ("ScriptBlox online  ·  " .. tostring(HUB.httpStatus or "OK"))
                or ("ScriptBlox unreachable  ·  " .. tostring(HUB.httpStatus or "HTTP blocked?"))
        end},
        {"Arming Guardian Core", 0.35, function()
            local okLv = pcall(function() Instance.new("LinearVelocity"):Destroy() Instance.new("AlignPosition"):Destroy() end)
            local vim = pcall(function() return game:GetService("VirtualInputManager") end)
            local parts = {}
            if CORE.sense.active then parts[#parts + 1] = "predictive sensor" end
            parts[#parts + 1] = okLv and "physics steering" or "CFrame steering"
            if vim then parts[#parts + 1] = "ability keys" end
            return (CORE.sense.active and okLv) and "ok" or "warn", table.concat(parts, "  ·  ")
        end},
        {"Waking the Guardian", 0.35, function()
            pcall(function()
                local CP = game:GetService("ContentProvider")
                local list = {}
                for _, id in ipairs({"rbxasset://textures/particles/smoke_main.dds", "rbxasset://textures/particles/sparkles_main.dds",
                    "rbxasset://textures/particles/fire_main.dds"}) do
                    local d = Instance.new("Decal") d.Texture = id list[#list + 1] = d
                end
                task.spawn(function() pcall(function() CP:PreloadAsync(list) end) for _, d in ipairs(list) do d:Destroy() end end)
            end)
            return "ok", "Guardian Control ready"
        end},
    }
    for i, st in ipairs(steps) do
        if not alive then break end
        stepL.Text = st[1]
        local t0 = os.clock()
        local ok, status, detail = pcall(st[3])
        if not ok then status, detail = "warn", "check failed" end
        results[#results + 1] = {st[1], status, detail}
        detailL.Text = tostring(detail or "")
        detailL.TextColor3 = (status == "bad" and C.red) or (status == "warn" and C.yellow) or C.sub
        local a = i / #steps
        tweenL(fill, 0.25, {Size = UDim2.new(a, 0, 1, 0)}) tweenL(fillGlow, 0.25, {Position = UDim2.new(a, 0, 0.5, 0)})
        pctL.Text = math.floor(a * 100 + 0.5) .. "%"
        if settings.sounds and status ~= "ok" then sound(GV.SND_TICK, 0.1, status == "bad" and 0.7 or 1) end
        local left = st[2] - (os.clock() - t0)
        if left > 0 then hold(left) end
    end
    stepL.Text = "Ready"
    -- a short note if something needs attention (shown later as toasts too)
    task.spawn(function()
        while pending > 0 and alive do task.wait(0.25) end
        if not alive then return end
        if #staffNames > 0 then toast("Staff in server: " .. table.concat(staffNames, ", "), "bad", 5) end
        local flagged = countKeys(guardian.suspicious)
        if flagged > 0 then toast(flagged .. " flagged player(s) in this server.", "warn", 4) end
        guardianRefresh("Scan finished")
    end)
    guardianRefresh()
    HUB.bootResults = results
    hold(0.25)
    -- outro: wordmark lifts and fades, veil dissolves
    for i, L in ipairs(letters) do
        task.delay((i - 1) * 0.015, function() tweenL(L.l, 0.25, {TextTransparency = 1}) tweenL(L.pd, 0.25, {PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 12)}) end)
    end
    for _, o in ipairs({subL, stepL, pctL, detailL, hint}) do tweenL(o, 0.2, {TextTransparency = 1}) end
    pcall(function() tweenL(logo, 0.3, {GroupTransparency = 1}) end)
    tweenL(logoScale, 0.35, {Scale = 1.06}) tweenL(halo, 0.3, {BackgroundTransparency = 1})
    for _, sm in ipairs(smoke) do sm.live = false tweenL(sm.f, 0.3, {BackgroundTransparency = 1}) end
    tweenL(topLine, 0.25, {Size = UDim2.new(0, 0, 0, 1)}) tweenL(tsuba, 0.2, {Size = UDim2.new(0, 0, 0, 0)})
    tweenL(track, 0.25, {BackgroundTransparency = 1}) tweenL(fill, 0.25, {BackgroundTransparency = 1}) shine.Visible = false
    tweenL(fillGlow, 0.2, {BackgroundTransparency = 1}) tweenL(glow, 0.2, {BackgroundTransparency = 1})
    for _, e in ipairs(embers) do tweenL(e.f, 0.25, {BackgroundTransparency = 1}) end
    task.wait(0.22)
    tweenL(root, 0.35, {BackgroundTransparency = 1})
    for _, d in ipairs(root:GetChildren()) do if d:IsA("Frame") and d ~= center then tweenL(d, 0.3, {BackgroundTransparency = 1}) end end
    task.delay(0.4, function() renderJobs.bootEmbers = nil pcall(function() root:Destroy() end) end)
    onDone()
end

-- =====================================================================
-- 14. Feature engine (universal, client-side)
-- =====================================================================
local FX = {}
local orig = {}
pcall(function()
    orig.fov = workspace.CurrentCamera.FieldOfView
    orig.gravity = workspace.Gravity
    orig.lighting = {Brightness = SVC.Lighting.Brightness, ClockTime = SVC.Lighting.ClockTime, FogEnd = SVC.Lighting.FogEnd, FogStart = SVC.Lighting.FogStart,
        GlobalShadows = SVC.Lighting.GlobalShadows, Ambient = SVC.Lighting.Ambient, OutdoorAmbient = SVC.Lighting.OutdoorAmbient}
end)
GV.fps, GV.fpsAcc, GV.fpsFrames = 60, 0, 0
onRender("fps", function(dt)
    GV.fpsFrames += 1 GV.fpsAcc += dt
    if GV.fpsAcc >= 0.5 then GV.fps = math.floor(GV.fpsFrames / GV.fpsAcc + 0.5) GV.fpsFrames, GV.fpsAcc = 0, 0 end
end)

-- Humanoid stats (re-applied every 0.2s and after respawn)
GV.humAcc = 0
onHeartbeat("humanoid", function(dt)
    GV.humAcc += dt
    if GV.humAcc < 0.2 then return end
    GV.humAcc = 0
    local h = hum()
    if not h then return end
    local ws = brain.capSpeed(tonumber(settings.walkspeed) or 16)
    if ws ~= 16 and not settings.fly and not settings.freecam then
        if brain.lastSetWs and math.abs(h.WalkSpeed - brain.lastSetWs) > 0.5 then brain.onForcedStat("WalkSpeed", brain.lastSetWs, h.WalkSpeed) end
        h.WalkSpeed = ws
        brain.lastSetWs = ws
    else
        brain.lastSetWs = nil
    end
    local jp = tonumber(settings.jumppower) or 50
    if jp ~= 50 then
        if brain.lastSetJp and math.abs(h.JumpPower - brain.lastSetJp) > 0.5 then brain.onForcedStat("JumpPower", brain.lastSetJp, h.JumpPower) end
        h.UseJumpPower = true h.JumpPower = jp
        brain.lastSetJp = jp
    else
        brain.lastSetJp = nil
    end
end)
function FX.resetHumanoid()
    local h = hum()
    if h then pcall(function() h.WalkSpeed = 16 h.UseJumpPower = true h.JumpPower = 50 end) end
end

-- Infinite jump
bind(UserInputService.JumpRequest:Connect(function()
    if settings.infjump and alive then
        local h = hum()
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end
end))

-- Noclip (remembers original collisions so turning off restores them)
local noclipped = {}
local noclipParts = {} GV.noclipChar, GV.noclipAcc = nil, 0
bind(SVC.RunService.Stepped:Connect(function(_, dt)
    if not alive or not settings.noclip then return end
    local c = char()
    if not c then return end
    GV.noclipAcc += dt or 0
    if c ~= GV.noclipChar or GV.noclipAcc > 1 then
        GV.noclipChar, GV.noclipAcc, noclipParts = c, 0, {}
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then noclipParts[#noclipParts + 1] = p end
        end
    end
    for _, p in ipairs(noclipParts) do
        if p.CanCollide then noclipped[p] = true p.CanCollide = false end
    end
end))
function FX.restoreNoclip()
    for p in pairs(noclipped) do if p.Parent then pcall(function() p.CanCollide = true end) end end
    noclipped = {}
end

-- Fly + Freecam share touch up/down pad
local flyObjs = {}
local vertical = {up = false, down = false}
GV.flyPad = nil
local function ensurePad(show)
    if not isTouch then return end
    if not GV.flyPad then
        GV.flyPad = new("Frame", {Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.45, 0), Size = UDim2.new(0, 64, 0, 140), ZIndex = 40})
        local function padBtn(txt, y, key)
            local b = new("TextButton", {Parent = GV.flyPad, BackgroundColor3 = C.purpleDark, BackgroundTransparency = 0.15, Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(0, 64, 0, 64),
                Text = txt, Font = F.black, TextSize = 26, TextColor3 = C.gold, AutoButtonColor = false, ZIndex = 41}, {corner(32)})
            local s = stroke(C.gold, 1.5, 0.3) s.Parent = b
            bind(b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then vertical[key] = true end end))
            bind(b.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then vertical[key] = false end end))
        end
        padBtn("UP", 0, "up")
        padBtn("DOWN", 74, "down")
    end
    GV.flyPad.Visible = show
end
function FX.stopFly()
    for _, o in ipairs(flyObjs) do pcall(function() o:Destroy() end) end
    flyObjs = {}
    local h = hum()
    if h then pcall(function() h.PlatformStand = false end) end
    ensurePad(settings.freecam == true)
end
function FX.startFly()
    FX.stopFly()
    local r = hrp()
    if not r then return end
    local att = Instance.new("Attachment") att.Name = "SecretFlyAtt" att.Parent = r
    local lv, ao
    local okNew = pcall(function()
        lv = Instance.new("LinearVelocity")
        lv.Attachment0 = att lv.MaxForce = 1e9 lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        lv.RelativeTo = Enum.ActuatorRelativeTo.World lv.VectorVelocity = Vector3.zero lv.Parent = r
        ao = Instance.new("AlignOrientation")
        ao.Attachment0 = att ao.Mode = Enum.OrientationAlignmentMode.OneAttachment ao.MaxTorque = 1e9 ao.Responsiveness = 60 ao.Parent = r
    end)
    if not okNew then
        pcall(function() if lv then lv:Destroy() end if ao then ao:Destroy() end end)
        lv = Instance.new("BodyVelocity") lv.MaxForce = Vector3.new(1e9, 1e9, 1e9) lv.Velocity = Vector3.zero lv.Parent = r
        ao = Instance.new("BodyGyro") ao.MaxTorque = Vector3.new(1e9, 1e9, 1e9) ao.P = 9e4 ao.Parent = r
    end
    for _, o in ipairs({lv, ao, att}) do pcall(function() o:SetAttribute("SecretHub", true) end) end
    flyObjs = {lv, ao, att}
    ensurePad(true)
end
local function inputVector(h)
    local v = Vector3.zero
    local cam = workspace.CurrentCamera
    local dir = h and h.MoveDirection or Vector3.zero
    if dir.Magnitude > 0 and cam then
        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        local forwardness = flat.Magnitude > 0 and dir:Dot(flat.Unit) or 0
        v = dir + Vector3.new(0, look.Y * forwardness, 0)
    end
    if vertical.up or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then v += Vector3.new(0, 1, 0) end
    if vertical.down or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then v -= Vector3.new(0, 1, 0) end
    return v
end
onRender("fly", function()
    if not settings.fly or #flyObjs == 0 then return end
    local h, r, cam = hum(), hrp(), workspace.CurrentCamera
    if not (h and r and cam) then return end
    if not flyObjs[1].Parent then FX.startFly() return end
    h.PlatformStand = true
    local v = inputVector(h) * brain.capFly(tonumber(settings.flyspeed) or 60)
    local mover, rot = flyObjs[1], flyObjs[2]
    if mover:IsA("LinearVelocity") then mover.VectorVelocity = v else mover.Velocity = v end
    if rot:IsA("AlignOrientation") then rot.CFrame = cam.CFrame else rot.CFrame = cam.CFrame end
end)

-- Freecam-lite
GV.freecamCF = nil
function FX.setFreecam(on)
    local cam = workspace.CurrentCamera
    local r = hrp()
    if on and cam then
        GV.freecamCF = cam.CFrame
        cam.CameraType = Enum.CameraType.Scriptable
        if r then r.Anchored = true end
        ensurePad(true)
    else
        if cam then cam.CameraType = Enum.CameraType.Custom local h = hum() if h then cam.CameraSubject = h end end
        if r then r.Anchored = false end
        ensurePad(settings.fly == true)
    end
end
onRender("freecam", function(dt)
    if not settings.freecam or not GV.freecamCF then return end
    local cam = workspace.CurrentCamera
    local h = hum()
    local move = inputVector(h)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += GV.freecamCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= GV.freecamCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += GV.freecamCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= GV.freecamCF.RightVector end
    local rotCF = cam.CFrame - cam.CFrame.Position
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local d = UserInputService:GetMouseDelta()
        rotCF = CFrame.Angles(0, -d.X * 0.004, 0) * rotCF * CFrame.Angles(-d.Y * 0.004, 0, 0)
    end
    GV.freecamCF = CFrame.new(GV.freecamCF.Position + move * (tonumber(settings.freecamspeed) or 40) * dt) * rotCF
    cam.CFrame = GV.freecamCF
end)
bind(UserInputService.TouchMoved:Connect(function(t, gp)
    if not settings.freecam or gp or not GV.freecamCF then return end
    local d = t.Delta
    if d then
        local cam = workspace.CurrentCamera
        local rotCF = cam.CFrame - cam.CFrame.Position
        GV.freecamCF = CFrame.new(GV.freecamCF.Position) * CFrame.Angles(0, -d.X * 0.006, 0) * rotCF * CFrame.Angles(-d.Y * 0.006, 0, 0)
    end
end))

-- Anti-AFK
pcall(function()
    local VU = svc("VirtualUser")
    bind(LP.Idled:Connect(function()
        if settings.antiafk then pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end) end
    end))
end)

-- Lighting / world
function FX.applyLighting()
    local L = orig.lighting
    if not L then return end
    pcall(function()
        if settings.fullbright then
            SVC.Lighting.Brightness = 2 SVC.Lighting.GlobalShadows = false
            SVC.Lighting.Ambient = Color3.fromRGB(178, 178, 178) SVC.Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        else
            SVC.Lighting.Brightness = L.Brightness SVC.Lighting.Ambient = L.Ambient SVC.Lighting.OutdoorAmbient = L.OutdoorAmbient
            SVC.Lighting.GlobalShadows = (not settings.lowgfx) and L.GlobalShadows
        end
        if settings.timeOverride then SVC.Lighting.ClockTime = tonumber(settings.clock) or 14
        elseif settings.fullbright then SVC.Lighting.ClockTime = 14
        else SVC.Lighting.ClockTime = L.ClockTime end
        SVC.Lighting.FogEnd = settings.nofog and 1e9 or L.FogEnd
        SVC.Lighting.FogStart = settings.nofog and 1e9 or L.FogStart
        for _, a in ipairs(SVC.Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                if settings.nofog then
                    a:SetAttribute("SecretDensity", a:GetAttribute("SecretDensity") or a.Density)
                    a.Density = 0
                elseif a:GetAttribute("SecretDensity") then
                    a.Density = a:GetAttribute("SecretDensity")
                end
            end
        end
    end)
    FX.applyNightVision()
end
-- Night vision: colour correction + brighter ambient (client only)
GV.nvFx = nil
function FX.applyNightVision()
    pcall(function()
        if settings.nightvision then
            if not GV.nvFx or not GV.nvFx.Parent then
                GV.nvFx = own(new("ColorCorrectionEffect", {Name = "SecretNightVision", Brightness = 0.1, Contrast = 0.12, Saturation = -0.35,
                    TintColor = Color3.fromRGB(200, 255, 210), Parent = SVC.Lighting}))
            end
            if not settings.fullbright then
                SVC.Lighting.Ambient = Color3.fromRGB(120, 140, 125) SVC.Lighting.OutdoorAmbient = Color3.fromRGB(130, 150, 135)
            end
        else
            if GV.nvFx then pcall(function() GV.nvFx:Destroy() end) GV.nvFx = nil end
        end
    end)
end
function FX.applyGravity()
    pcall(function() workspace.Gravity = settings.gravityOverride and (tonumber(settings.gravity) or 196.2) or (orig.gravity or 196.2) end)
end
function FX.applyFov()
    pcall(function() workspace.CurrentCamera.FieldOfView = tonumber(settings.fov) or orig.fov or 70 end)
end
local lowgfxChanged = setmetatable({}, {__mode = "k"})   -- V2.4: weak, destroyed effects are not kept alive
function FX.applyLowGfx()
    if settings.lowgfx then
        pcall(function() SVC.Lighting.GlobalShadows = false end)
        pcall(function() SVC.RobloxSettings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        task.spawn(function()
            local n = 0
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                    if d.Enabled then d.Enabled = false lowgfxChanged[d] = true end
                end
                n += 1
                if n % 400 == 0 then task.wait() end
            end
        end)
    else
        for d in pairs(lowgfxChanged) do pcall(function() if d.Parent then d.Enabled = true end end) end
        lowgfxChanged = setmetatable({}, {__mode = "k"})
        FX.applyLighting()
    end
end

-- ESP (Highlight + billboard; staff in red)
local espObjs = {}
local espTargets = {}  -- per-player ESP (works even when global ESP is off)
function FX.clearEsp()
    for _, o in pairs(espObjs) do pcall(function() o.hl:Destroy() o.bb:Destroy() end) end
    espObjs = {}
end
local function espFor(p)
    if p == LP or not p.Character then return end
    local c = p.Character
    local o = espObjs[p]
    if o and o.hl.Parent == c and o.bb.Parent then return end
    if o then pcall(function() o.hl:Destroy() o.bb:Destroy() end) end
    local isStaff = guardian.staff[p.UserId] ~= nil
    local col = isStaff and C.red or (guardian.suspicious[p.UserId] and C.yellow or C.purple)
    local hl = Instance.new("Highlight")
    hl.FillTransparency = 0.78 hl.OutlineColor = isStaff and C.red or C.gold hl.FillColor = col
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop hl.Parent = c
    local head = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    if not head then hl:Destroy() return end
    local bb = new("BillboardGui", {Parent = head, Size = UDim2.new(0, 180, 0, 32), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true, MaxDistance = 2000})
    local l = label(bb, {Size = UDim2.fromScale(1, 1), Font = F.bold, TextSize = 12, TextColor3 = isStaff and C.red or C.text,
        TextStrokeTransparency = 0.35, Text = p.DisplayName, TextXAlignment = Enum.TextXAlignment.Center})
    espObjs[p] = {hl = hl, bb = bb, label = l}
end
function FX.toggleEspFor(p)
    if espTargets[p] then
        espTargets[p] = nil
        local o = espObjs[p]
        if o and not settings.esp then pcall(function() o.hl:Destroy() o.bb:Destroy() end) espObjs[p] = nil end
        return false
    end
    espTargets[p] = true
    return true
end
function FX.espTargeted(p) return espTargets[p] == true end
GV.espAcc = 0
onHeartbeat("esp", function(dt)
    if not settings.esp and next(espTargets) == nil and not brain.anyThreat then return end
    GV.espAcc += dt
    if GV.espAcc < 0.4 then return end
    GV.espAcc = 0
    local me = hrp()
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            if not settings.esp and not espTargets[p] and not brain.showThreat(p) then
                local old = espObjs[p]
                if old then pcall(function() old.hl:Destroy() old.bb:Destroy() end) espObjs[p] = nil end
                return
            end
            espFor(p)
            local o = espObjs[p]
            if o then brain.colorEsp(p, o) end
            local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if o and r and me then
                o.label.Text = p.DisplayName .. "  ·  " .. math.floor((r.Position - me.Position).Magnitude) .. "m" .. (guardian.staff[p.UserId] and "  [STAFF]" or "")
            end
        end)
    end
end)
bind(Players.PlayerRemoving:Connect(function(p)
    local o = espObjs[p]
    if o then pcall(function() o.hl:Destroy() o.bb:Destroy() end) espObjs[p] = nil end
    espTargets[p] = nil
end))

-- Anti-fling: ignore other players' collisions + clamp crazy velocity
GV.lastSafeCF = nil
GV.flingAcc = 0
onHeartbeat("antifling", function(dt)
    if not settings.antifling or brain.situation == "Vehicle" then return end
    GV.flingAcc += dt
    if GV.flingAcc >= 0.1 then
        GV.flingAcc = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end
    end
    local r = hrp()
    if r and not settings.fly then
        local v = r.AssemblyLinearVelocity
        if v.Magnitude > 220 or r.AssemblyAngularVelocity.Magnitude > 60 then
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if GV.lastSafeCF then brain.ownMove() r.CFrame = GV.lastSafeCF end
        end
    end
end)
-- Anti-void + last safe position tracking
GV.voidAcc = 0
onHeartbeat("antivoid", function(dt)
    GV.voidAcc += dt
    if GV.voidAcc < 0.25 then return end
    GV.voidAcc = 0
    local r, h = hrp(), hum()
    if not (r and h) then return end
    if h.FloorMaterial ~= Enum.Material.Air and h.Health > 0 then GV.lastSafeCF = r.CFrame end
    if HUB.rescueBusy then return end   -- the Guardian is already moving you
    if settings.antivoid and GV.lastSafeCF and r.Position.Y < (workspace.FallenPartsDestroyHeight + 60) then
        r.AssemblyLinearVelocity = Vector3.zero
        brain.ownMove()
        r.CFrame = GV.lastSafeCF + Vector3.new(0, 3, 0)
        toast("Anti-Void saved you.", "shield")
    end
end)

-- Click teleport (Ctrl+Click on PC, tool on mobile)
local mouse = LP:GetMouse()
GV.tpTool = nil
-- All hub teleports go through here so Guardian Brain can verify them and switch to small steps
-- when a game reverts instant teleports.
function FX.teleport(cf)
    local r = hrp()
    if not (r and cf) then return false end
    local from, to = r.Position, cf.Position
    local dist = (to - from).Magnitude
    local stepped = brain.tpStepped() and dist > 20
    local steps = stepped and math.clamp(math.ceil(dist / 14), 2, 60) or 1
    local dur = stepped and steps * 0.05 or 0
    if brain.noteTp then pcall(brain.noteTp, from, to, dur) end
    if VFX.preTeleport then pcall(VFX.preTeleport) end
    if VFX.teleport and (to - from).Magnitude > 4 then pcall(VFX.teleport, from, to, dur) end
    if stepped then
        task.spawn(function()
            local rot = cf - cf.Position
            for i = 1, steps do
                if not alive or not r.Parent then return end
                r.CFrame = CFrame.new(from:Lerp(to, i / steps)) * rot
                r.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.05)
            end
        end)
    else
        r.CFrame = cf
    end
    return true, dur
end
local function tpTo(pos)
    local r = hrp()
    if r and pos then FX.teleport(CFrame.new(pos + Vector3.new(0, 3, 0)) * (r.CFrame - r.CFrame.Position)) end
end
bind(mouse.Button1Down:Connect(function()
    if settings.clicktp and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and mouse.Hit then tpTo(mouse.Hit.Position) end
end))
function FX.setClickTp(on)
    if GV.tpTool then pcall(function() GV.tpTool:Destroy() end) GV.tpTool = nil end
    if on and isTouch then
        pcall(function()
            GV.tpTool = Instance.new("Tool")
            GV.tpTool.Name = "Secret TP" GV.tpTool.RequiresHandle = false GV.tpTool.CanBeDropped = false
            GV.tpTool.Activated:Connect(function() if mouse.Hit then tpTo(mouse.Hit.Position) end end)
            GV.tpTool.Parent = LP:WaitForChild("Backpack")
        end)
    end
end

-- Safe Spot (dark glass platform, thin white rim, no bubble)
local safeParts = {}
function FX.removeSafe()
    for _, p in ipairs(safeParts) do pcall(function() p:Destroy() end) end
    safeParts = {}
end
function FX.goSafe()
    if not alive then return end
    local r = hrp()
    if not r then toast("No character found.", "bad") return end
    if #safeParts == 0 then
        local base = Vector3.new(r.Position.X + 2500, math.max(r.Position.Y, 0) + 3000, r.Position.Z + 2500)
        local plat = own(new("Part", {Name = "SecretSafeSpot", Anchored = true, CanCollide = true, Size = Vector3.new(44, 1.5, 44), CFrame = CFrame.new(base),
            Material = Enum.Material.Glass, Color = Color3.fromRGB(14, 14, 20), Transparency = 0.15, Parent = workspace}))
        local ring = own(new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false, Size = Vector3.new(0.12, 45, 45),
            CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
            Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = C.gold, Transparency = 0.55, Parent = workspace}))
        local bubble = own(new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1,
            CFrame = CFrame.new(base + Vector3.new(0, 6, 0)), Parent = workspace}))
        new("PointLight", {Parent = bubble, Color = C.gold, Range = 26, Brightness = 0.8, Shadows = false})
        safeParts = {plat, ring, bubble}
        -- invisible walls so nothing pushes you off
        for i = 0, 3 do
            local a = math.rad(i * 90)
            safeParts[#safeParts + 1] = own(new("Part", {Anchored = true, CanCollide = true, Transparency = 1, Size = Vector3.new(44, 20, 1),
                CFrame = CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.new(0, 10, 22), Parent = workspace}))
        end
        for _, sp in ipairs(safeParts) do pcall(function() sp:SetAttribute("SecretHub", true) end) end
        if not PERF.lite then task.spawn(function()
            local big = true
            while alive and ring.Parent do
                tween(ring, 2, {Transparency = big and 0.35 or 0.7}, Enum.EasingStyle.Sine)
                big = not big
                task.wait(2)
            end
        end) end
    end
    GV.safeReturn = GV.safeReturn or r.CFrame
    r.AssemblyLinearVelocity = Vector3.zero
    if brain.noteTp then pcall(brain.noteTp, r.Position, (safeParts[1].CFrame + Vector3.new(0, 4, 0)).Position, 0) end
    local fromPos = r.Position
    if VFX.preTeleport then pcall(VFX.preTeleport) end
    r.CFrame = safeParts[1].CFrame + Vector3.new(0, 4, 0)
    if VFX.teleport then pcall(VFX.teleport, fromPos, r.Position) end
    if VFX.dome then pcall(VFX.dome, r.Position) end
    toast("You are in the Safe Spot.", "shield")
end
function FX.leaveSafe()
    local r = hrp()
    if r and GV.safeReturn then
        brain.ownMove()
        local fromPos = r.Position
        if VFX.preTeleport then pcall(VFX.preTeleport) end
        r.CFrame = GV.safeReturn
        if VFX.teleport then pcall(VFX.teleport, fromPos, GV.safeReturn.Position) end
    end
    GV.safeReturn = nil
    FX.removeSafe()
    toast("Returned from the Safe Spot.", "ok")
end
-- V2.4 fix: "in the Safe Spot" means your character is actually standing there. Before, the platform
-- merely existing (you respawned / walked off without pressing Return) counted, which silently switched
-- off the Lifeline evacuation and every Guardian movement for the rest of the session.
function FX.inSafe()
    if #safeParts == 0 then return false end
    local r, p = hrp(), safeParts[1]
    if not (r and p and p.Parent) then return false end
    return (r.Position - p.Position).Magnitude < 40
end

-- Server
function FX.rejoin()
    toast("Rejoining…", "info")
    pcall(function()
        if #Players:GetPlayers() <= 1 then SVC.TeleportService:Teleport(game.PlaceId, LP)
        else SVC.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
    end)
end
-- Server hop was removed in 4.0 (standing rule: no server hop). Rejoin stays.
function FX.serverHop()
    toast("Server hop is not part of Void Hub. Use Rejoin instead.", "info", 3)
end
function FX.joinScript()
    return string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)', game.PlaceId, game.JobId)
end

-- Auto-rejoin on kick / disconnect
pcall(function()
    local overlay = SVC.CoreGui:FindFirstChild("RobloxPromptGui") and SVC.CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
    if overlay then
        bind(overlay.ChildAdded:Connect(function(ch)
            if settings.autorejoin and alive and ch.Name == "ErrorPrompt" then
                task.wait(2)
                pcall(function() SVC.TeleportService:Teleport(game.PlaceId, LP) end)
            end
        end))
    end
end)
pcall(function()
    bind(SVC.GuiService.ErrorMessageChanged:Connect(function()
        if settings.autorejoin and alive then
            task.wait(2)
            pcall(function() SVC.TeleportService:Teleport(game.PlaceId, LP) end)
        end
    end))
end)

-- Spectate
GV.spectating = nil
function FX.spectate(p)
    local cam = workspace.CurrentCamera
    if GV.spectating == p or not p then
        GV.spectating = nil
        local h = hum() if h then cam.CameraSubject = h end
        return false
    end
    local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    if h then cam.CameraSubject = h GV.spectating = p return true end
    return false
end
function FX.tpToPlayer(p)
    local r = hrp()
    local t = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if r and t then FX.teleport(t.CFrame * CFrame.new(0, 0, 3)) return true end
    return false
end


-- ---------------------------------------------------------------------
-- 14b. Automation: instant prompts, auto-interact, auto-click
-- ---------------------------------------------------------------------
local firePrompt = exfn("fireproximityprompt")
local fireClick = exfn("fireclickdetector")
local promptReg, clickReg = {}, {}
local promptHold = {}
GV.regBuilt = false
local function regAdd(d)
    if d:IsA("ProximityPrompt") then
        promptReg[d] = true
        if settings.instantprompts then
            pcall(function() if promptHold[d] == nil then promptHold[d] = d.HoldDuration end d.HoldDuration = 0 end)
        end
    elseif d:IsA("ClickDetector") then
        clickReg[d] = true
    end
end
local function ensureRegistry()
    if GV.regBuilt then return end
    GV.regBuilt = true
    bind(workspace.DescendantAdded:Connect(function(d) if alive then regAdd(d) end end))
    bind(workspace.DescendantRemoving:Connect(function(d) promptReg[d] = nil clickReg[d] = nil promptHold[d] = nil end))
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if not alive then return end
            regAdd(d)
            n += 1
            if n % 1500 == 0 then task.wait() end
        end
    end)
end
function FX.applyInstantPrompts()
    if not settings.instantprompts and not GV.regBuilt then return end
    ensureRegistry()
    for p in pairs(promptReg) do
        pcall(function()
            if settings.instantprompts then
                if promptHold[p] == nil then promptHold[p] = p.HoldDuration end
                p.HoldDuration = 0
            elseif promptHold[p] ~= nil then
                p.HoldDuration = promptHold[p]
                promptHold[p] = nil
            end
        end)
    end
end
pcall(function()
    bind(svc("ProximityPromptService").PromptButtonHoldBegan:Connect(function(p)
        if alive and settings.instantprompts and firePrompt then pcall(firePrompt, p) end
    end))
end)
local function promptPos(p)
    local par = p.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    if par:IsA("Model") then return par:GetPivot().Position end
    return nil
end
local function matchesFilter(p, filt)
    if filt == "" then return true end
    local s = string.lower(tostring(p.ActionText) .. " " .. tostring(p.ObjectText) .. " " .. p.Name .. " " .. (p.Parent and p.Parent.Name or ""))
    return string.find(s, filt, 1, true) ~= nil
end
local lastFired = {}
GV.iaAcc = 0
onHeartbeat("autointeract", function(dt)
    if not settings.autointeract then return end
    GV.iaAcc += dt
    if GV.iaAcc < 0.35 then return end
    GV.iaAcc = 0
    ensureRegistry()
    local r = hrp()
    if not r then return end
    local now = os.clock()
    local filt = string.lower(trim(settings.interactFilter or ""))
    local fired = 0
    for p in pairs(promptReg) do
        if fired >= 3 then break end
        local ok, use = pcall(function()
            if not p.Enabled or (now - (lastFired[p] or 0)) < 1.5 then return false end
            local pos = promptPos(p)
            return pos ~= nil and (pos - r.Position).Magnitude <= p.MaxActivationDistance + 0.5 and matchesFilter(p, filt)
        end)
        if ok and use then
            lastFired[p] = now
            fired += 1
            if firePrompt then
                pcall(firePrompt, p)
            else
                task.spawn(function()
                    pcall(function() p:InputHoldBegin() task.wait((tonumber(p.HoldDuration) or 0) + 0.05) p:InputHoldEnd() end)
                end)
            end
        end
    end
    if fireClick then
        for cd in pairs(clickReg) do
            if fired >= 4 then break end
            local ok, use = pcall(function()
                local part = cd.Parent
                if not (part and part:IsA("BasePart")) or (now - (lastFired[cd] or 0)) < 1.5 then return false end
                if filt ~= "" and not string.find(string.lower(part.Name), filt, 1, true) then return false end
                return (part.Position - r.Position).Magnitude <= cd.MaxActivationDistance
            end)
            if ok and use then lastFired[cd] = now fired += 1 pcall(fireClick, cd) end
        end
    end
end)
function FX.promptCount()
    local n = 0
    for _ in pairs(promptReg) do n += 1 end
    return n
end

-- Auto-click: activates your equipped tool (or clicks when the hub is hidden)
local mouseClick = exfn("mouse1click")
GV.acAcc = 0
onHeartbeat("autoclick", function(dt)
    if not settings.autoclick then return end
    GV.acAcc += dt
    if GV.acAcc < 1 / clamp(tonumber(settings.clickrate) or 8, 1, 20) then return end
    GV.acAcc = 0
    local c = char()
    local tool = c and c:FindFirstChildOfClass("Tool")
    if tool then
        if not GV.isFruitItem(tool) then pcall(function() tool:Activate() end) end
    elseif mouseClick and not HUB.uiOpen then
        pcall(mouseClick)
    end
end)

-- ---------------------------------------------------------------------
-- 14c. World: X-ray, walk on water, camera
-- ---------------------------------------------------------------------
local xrayOrig = {}
GV.xrayToken = 0
local function isCharacterPart(d)
    local m = d:FindFirstAncestorWhichIsA("Model")
    while m do
        if m:FindFirstChildOfClass("Humanoid") then return true end
        m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
    end
    return false
end
function FX.applyXray()
    GV.xrayToken += 1
    local my = GV.xrayToken
    for part, t in pairs(xrayOrig) do pcall(function() part.Transparency = t end) end
    xrayOrig = {}
    if not settings.xray then return end
    local amt = clamp(tonumber(settings.xrayAmount) or 0.6, 0.1, 0.95)
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if my ~= GV.xrayToken or not alive then return end
            if d:IsA("BasePart") and d ~= workspace.Terrain and d.Transparency < amt and not d:GetAttribute("SecretHub") and not isCharacterPart(d) then
                xrayOrig[d] = d.Transparency
                d.Transparency = amt
            end
            n += 1
            if n % 700 == 0 then task.wait() end
        end
    end)
end

-- Walk on water lives in 14n (Terrain + water parts + learned sea level + ripples)

local origCam = {}
function FX.applyCamera()
    pcall(function()
        if origCam.zoom == nil then origCam.zoom = LP.CameraMaxZoomDistance end
        if origCam.occ == nil then origCam.occ = LP.DevCameraOcclusionMode end
        LP.CameraMaxZoomDistance = settings.maxzoom and 1000 or origCam.zoom
        LP.DevCameraOcclusionMode = settings.camnoclip and Enum.DevCameraOcclusionMode.Invisicam or origCam.occ
    end)
end

-- ---------------------------------------------------------------------
-- 14d. Character tweaks
-- ---------------------------------------------------------------------
function FX.resetChar()
    local h = hum()
    if h then pcall(function() h.Health = 0 end) toast("Character reset.", "info") end
end
function FX.sit()
    local h = hum()
    if h then pcall(function() h.Sit = not h.Sit end) end
end
function FX.unequip()
    local h = hum()
    if h then pcall(function() h:UnequipTools() end) end
end
function FX.removeAccessories()
    local c = char()
    if not c then return end
    local n = 0
    for _, a in ipairs(c:GetChildren()) do
        if a:IsA("Accessory") then pcall(function() a:Destroy() end) n += 1 end
    end
    toast("Removed " .. n .. " accessories (only you see this).", "ok")
end

-- ---------------------------------------------------------------------
-- 14e. Waypoints (saved per game)
-- ---------------------------------------------------------------------
local waypoints = loadJSON(GV.WAYPOINT_FILE, {})
if type(waypoints) ~= "table" then waypoints = {} end
local function wpList()
    local k = tostring(game.PlaceId)
    if type(waypoints[k]) ~= "table" then waypoints[k] = {} end
    return waypoints[k]
end
function FX.addWaypoint(name)
    local r = hrp()
    if not r then toast("No character found.", "bad") return false end
    local list = wpList()
    name = trim(name)
    if name == "" then name = "Waypoint " .. (#list + 1) end
    if #list >= 30 then toast("Max 30 waypoints per game.", "warn") return false end
    local p = r.Position
    list[#list + 1] = {name = name:sub(1, 24), x = math.floor(p.X * 10) / 10, y = math.floor(p.Y * 10) / 10, z = math.floor(p.Z * 10) / 10}
    save(GV.WAYPOINT_FILE, jsonEncode(waypoints))
    toast("Waypoint '" .. name .. "' saved.", "ok")
    return true
end
function FX.tpWaypoint(w)
    if type(w) ~= "table" then return end
    tpTo(Vector3.new(tonumber(w.x) or 0, (tonumber(w.y) or 0) - 3, tonumber(w.z) or 0))
    toast("Teleported to " .. tostring(w.name), "ok", 1.8)
end
function FX.delWaypoint(i)
    local list = wpList()
    table.remove(list, i)
    save(GV.WAYPOINT_FILE, jsonEncode(waypoints))
end
FX.wpList = wpList

-- ---------------------------------------------------------------------
-- 14f. Profiles (per-game config snapshots)
-- ---------------------------------------------------------------------
GV.PROFILE_KEYS = {"walkspeed", "jumppower", "fov", "gravity", "clock", "flyspeed", "freecamspeed", "infjump", "noclip", "fly", "antiafk",
    "fullbright", "esp", "antifling", "antivoid", "clicktp", "nofog", "lowgfx", "hud", "autorejoin", "timeOverride", "gravityOverride",
    "staffAction", "panicSafeSpot", "instantprompts", "autointeract", "interactFilter", "autoclick", "clickrate", "xray", "xrayAmount",
    "nightvision", "walkwater", "maxzoom", "camnoclip",
    "puppetMove", "puppetStrength", "puppetStyle", "abilAssist", "stalker", "stalkerSafe", "fxSharingan",
    "choreo", "choreoReturn", "aoeTele", "finisher", "finisherKey", "finisherHp", "lootGrab", "shadowM1", "m1Range", "m1Rate", "m1Combo",
    "puppetHold", "holdRadius", "holdLeash", "holdGoSpawn", "scanner", "awakenPve", "kamui", "kamuiHp", "radarWorld", "introHands", "farm",
    "stunBreak", "healTiming", "healAt", "rescueStart", "rescueSafe", "handsGrab", "handsVisual", "waterGuard",
    "aggression", "aggroNpc", "aggroPvp", "aggroOneShot", "aggroSkills", "aggroCombo", "aggroLock", "aggroRange", "aggroRate",
    "voidNet", "netChat", "netRange", "netPlayers", "netOrbit",
    "voidOverride", "ovrLearn", "ovrAmplify", "ovrAmp", "ovrReplay", "ovrProbe", "ovrOneShot", "ovrHeal", "ovrPvp", "ovrRate", "ovrRange",
    "ovrHitbox", "ovrHitboxAmp", "ovrParasite", "ovrCdStrip", "ovrSoftGod", "ovrDominion", "ovrMaps", "voidSiphon",
    "ovrMirror", "ovrMarket",
    "combatAim", "aimCam", "aimBody", "aimSilent", "aimMove", "aimRange", "aimFov", "aimPlayers", "aimStick",
    "antiDeath", "quietDeath",
    "bfFruitNotify", "bfFruitEsp", "bfFruitSnipe", "bfChest", "bfFarm", "bfQuest", "bfStats", "bfStat", "bfWeapon", "bfBuso", "bfBusoVia", "bfKen", "bfSpeed"}
local profiles = loadJSON(GV.PROFILE_FILE, {})
if type(profiles) ~= "table" then profiles = {} end
local function gameProfiles()
    local k = tostring(game.PlaceId)
    if type(profiles[k]) ~= "table" then profiles[k] = {} end
    return profiles[k]
end
function FX.saveProfile(name)
    name = trim(name)
    if name == "" then name = "Default" end
    local snap = {}
    for _, k in ipairs(GV.PROFILE_KEYS) do snap[k] = settings[k] end
    gameProfiles()[name:sub(1, 20)] = snap
    save(GV.PROFILE_FILE, jsonEncode(profiles))
    toast("Profile '" .. name .. "' saved for this game.", "ok")
end
function FX.deleteProfile(name)
    gameProfiles()[name] = nil
    save(GV.PROFILE_FILE, jsonEncode(profiles))
end
FX.gameProfiles = gameProfiles

-- Respawn re-hooks
bind(LP.CharacterAdded:Connect(function(c)
    noclipped = {}
    GV.safeReturn = nil
    task.spawn(function()
        c:WaitForChild("HumanoidRootPart", 10)
        c:WaitForChild("Humanoid", 10)
        task.wait(0.4)
        if not alive then return end
        if settings.fly then FX.startFly() end
        if settings.freecam then settings.freecam = false FX.setFreecam(false) end
        if settings.clicktp then FX.setClickTp(true) end
        FX.applyFov()
        if settings.maxzoom or settings.camnoclip then FX.applyCamera() end
    end)
end))

-- Panic: disable everything, restore defaults, hide UI
function FX.disableAll()
    settings.fly = false FX.stopFly()
    settings.noclip = false FX.restoreNoclip()
    if settings.freecam then settings.freecam = false FX.setFreecam(false) end
    settings.infjump = false settings.esp = false FX.clearEsp()
    settings.clicktp = false FX.setClickTp(false)
    settings.walkspeed = 16 settings.jumppower = 50 FX.resetHumanoid()
    settings.fullbright = false settings.nofog = false settings.timeOverride = false FX.applyLighting()
    settings.gravityOverride = false FX.applyGravity()
    if GV.spectating then FX.spectate(nil) end
    settings.instantprompts = false FX.applyInstantPrompts()
    settings.autointeract = false settings.autoclick = false
    settings.xray = false FX.applyXray()
    settings.nightvision = false FX.applyNightVision() FX.applyLighting()
    settings.walkwater = false
    if CORE.waterPlat then CORE.waterPlat.Parent = nil end
    settings.maxzoom = false settings.camnoclip = false FX.applyCamera()
    settings.hazardShield = false
    if brain.restoreShield then pcall(brain.restoreShield) end
    settings.godmode = false settings.autododge = false settings.antigrab = false settings.antifreeze = false settings.radar = false
    settings.npcdef = false settings.npcEvade = false settings.magnet = false settings.ghost = false
    settings.puppetMove = false settings.stalker = false settings.abilAssist = false settings.fxSharingan = false
    if CORE.override then pcall(CORE.override.reset) end
    settings.shadowM1 = false settings.finisher = false settings.lootGrab = false settings.choreo = false settings.stunBreak = false settings.healTiming = false
    settings.puppetHold = false settings.holdGoSpawn = false settings.kamui = false settings.farm = false
    settings.aggression = false settings.aggroPvp = false
    settings.voidOverride = false settings.ovrReplay = false settings.ovrProbe = false settings.ovrOneShot = false
    settings.ovrParasite = false settings.ovrCdStrip = false settings.ovrSoftGod = false settings.ovrDominion = false settings.voidSiphon = false
    settings.ovrMirror = false settings.ovrMarket = false
    if CORE.awaken then pcall(CORE.awaken.stop, true) end
    if CORE.pve and CORE.pve.hold then pcall(CORE.pve.hold.releaseAll) end
    if FX.defenseOff then pcall(FX.defenseOff) end
    if FX.fxOff then pcall(FX.fxOff) end
    espTargets = {}
    saveSettings()
end

-- Re-apply every feature from the settings table (used by profiles)
function FX.applyAll()
    FX.applyLighting() FX.applyGravity() FX.applyFov()
    if settings.fly then FX.startFly() else FX.stopFly() end
    if not settings.noclip then FX.restoreNoclip() end
    FX.setClickTp(settings.clicktp == true)
    if not settings.esp then FX.clearEsp() end
    FX.applyInstantPrompts()
    FX.applyXray()
    FX.applyCamera()
    if settings.lowgfx then FX.applyLowGfx() end
end

-- =====================================================================
-- 14f2. VFX: short, pooled, local-only effects for Guardian actions
--   all effects last <= 0.6 s; Performance Mode uses fewer ghosts / particles
-- =====================================================================
CORE.safeModule("14f2 VFX", function()
    local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
    local function enabled() return alive and settings.vfx ~= false end
    local function lite() return PERF.lite end
    local function basePart(props)
        local p = new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
            Transparency = 1, Size = Vector3.new(1, 1, 1)})
        for k, v in pairs(props or {}) do p[k] = v end
        pcall(function() p:SetAttribute("SecretHub", true) end)
        return own(p)
    end
    -- simple pools: take() returns a free part, parked parts have Parent = nil
    local function pool(make, size)
        local items, idx = {}, 0
        for i = 1, size do items[i] = make() end
        return function()
            idx = idx % #items + 1
            return items[idx]
        end
    end
    local takeGhost = pool(function() return basePart({Material = Enum.Material.ForceField}) end, 12)
    local takeRing = pool(function() return basePart({Shape = Enum.PartType.Cylinder}) end, 4)
    local takeBall = pool(function() return basePart({Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField}) end, 3)
    local takeEmitter = pool(function()
        local p = basePart({Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)})
        local e = new("ParticleEmitter", {Parent = p, Enabled = false, Texture = SPARK_TEX, LightEmission = 1, Lifetime = NumberRange.new(0.25, 0.5),
            Speed = NumberRange.new(14, 30), SpreadAngle = Vector2.new(180, 180), Drag = 4, Rate = 0,
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})})
        return {part = p, em = e}
    end, 3)
    local function park(p, after)
        task.delay(after, function() if p and p.Transparency >= 0.99 then p.Parent = nil end end)
    end

    -- screen flash text ("DODGE", "BREAK FREE", ...): letter-spaced, thin, with a hairline under it
    local flashL = label(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0, 480, 0, 30), Font = F.display,
        Text = "", TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 95, TextXAlignment = Enum.TextXAlignment.Center})
    local flashStroke = new("UIStroke", {Parent = flashL, Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 1})
    local flashLine = new("Frame", {Parent = flashL, BorderSizePixel = 0, BackgroundColor3 = C.gold, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.new(0, 0, 0, 1), ZIndex = 95},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    local flashScale = new("UIScale", {Parent = flashL, Scale = 1})
    local flashTok = 0
    function VFX.flash(text, col)
        if not enabled() then return end
        flashTok += 1
        local my = flashTok
        flashL.Text = spaced(text)
        flashL.TextColor3 = Color3.new(1, 1, 1):Lerp(col or C.gold, 0.25)
        flashLine.BackgroundColor3 = col or C.gold
        flashL.TextTransparency = 0 flashStroke.Transparency = 0.6
        flashLine.BackgroundTransparency = 0 flashLine.Size = UDim2.new(0, 0, 0, 1)
        flashScale.Scale = 1.08
        tween(flashScale, 0.2, {Scale = 1})
        tween(flashLine, 0.25, {Size = UDim2.new(0, 220, 0, 1)})
        task.delay(0.45, function()
            if my ~= flashTok then return end
            tween(flashL, 0.25, {TextTransparency = 1}) tween(flashStroke, 0.25, {Transparency = 1}) tween(flashLine, 0.25, {BackgroundTransparency = 1})
        end)
    end
    -- Verified Moments only: call after a real success (dodge landed, grab broken, kill credited…).
    -- Rate-limited so the screen never feels spammy — every flash should feel earned.
    local momentLast, momentGlobal = {}, -100
    function VFX.moment(kind, text, col)
        if not enabled() then return false end
        kind = tostring(kind or "ok")
        local t = os.clock()
        if t - (momentLast[kind] or -99) < 2.4 then return false end
        if t - momentGlobal < 0.9 then return false end
        momentLast[kind], momentGlobal = t, t
        local S = HUB.session
        if type(S) == "table" then
            if kind == "dodge" then S.dodges = (tonumber(S.dodges) or 0) + 1
            elseif kind == "safe" or kind == "rescue" or kind == "grab" then S.saves = (tonumber(S.saves) or 0) + 1
            elseif kind == "kill" or kind == "boss" or kind == "dominate" then S.kills = (tonumber(S.kills) or 0) + 1
            elseif kind == "learn" then S.learned = (tonumber(S.learned) or 0) + 1
            elseif kind == "block" or kind == "freeze" then S.blocks = (tonumber(S.blocks) or 0) + 1 end
        end
        VFX.flash(text, col or C.spirit)
        VFX.pulse(col or C.spirit, kind == "boss" and 0.85 or 0.5, kind == "boss" and 0.5 or 0.32)
        if kind == "boss" or kind == "dominate" then VFX.tint(col or C.gold) end
        return true
    end
    -- brief lighting pulse (own ColorCorrection + Bloom, destroyed afterwards; never touches the game's own effects)
    local pulseTok = 0
    local pulseLive = {}
    onUnload(function() for o in pairs(pulseLive) do pcall(function() o:Destroy() end) end pulseLive = {} end)
    function VFX.pulse(col, strength, dur)
        if not enabled() then return end
        pulseTok += 1
        local my = pulseTok
        strength = (strength or 1) * (lite() and 0.6 or 1)
        dur = dur or 0.45
        local cc, bl
        pcall(function()
            cc = new("ColorCorrectionEffect", {Name = "SecretPulse", TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0, Parent = SVC.Lighting})
            if not lite() then bl = new("BloomEffect", {Name = "SecretPulseBloom", Intensity = 0, Size = 24, Threshold = 0.9, Parent = SVC.Lighting}) end
        end)
        if cc then pulseLive[cc] = true end
        if bl then pulseLive[bl] = true end
        local tint = Color3.new(1, 1, 1):Lerp(col or C.gold, 0.18 * strength)
        local function tw(o, t, p) pcall(function() SVC.TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p):Play() end) end
        if cc then tw(cc, 0.06, {TintColor = tint, Contrast = 0.12 * strength, Brightness = 0.04 * strength, Saturation = -0.1 * strength}) end
        if bl then tw(bl, 0.06, {Intensity = 0.6 * strength}) end
        task.delay(0.08, function()
            if cc then tw(cc, dur, {TintColor = Color3.new(1, 1, 1), Contrast = 0, Brightness = 0, Saturation = 0}) end
            if bl then tw(bl, dur, {Intensity = 0}) end
            task.delay(dur + 0.05, function()
                pcall(function() if cc then pulseLive[cc] = nil cc:Destroy() end if bl then pulseLive[bl] = nil bl:Destroy() end end)
            end)
        end)
    end
    -- full-screen colour pulse (very cheap)
    local tint = new("Frame", {Parent = gui, BackgroundColor3 = C.gold, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 94, Active = false})
    function VFX.tint(col)
        if not enabled() then return end
        tint.BackgroundColor3 = col or C.gold
        tint.BackgroundTransparency = 0.92
        tween(tint, 0.35, {BackgroundTransparency = 1})
    end
    function VFX.ring(pos, col, maxSize)
        if not enabled() or not pos then return end
        local p = takeRing()
        p.Color = col or C.gold
        p.Size = Vector3.new(0.25, 2, 2)
        p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
        p.Transparency = 0.15
        p.Parent = workspace
        local s = maxSize or 22
        tween(p, 0.45, {Size = Vector3.new(0.25, s, s), Transparency = 1}, Enum.EasingStyle.Quint)
        park(p, 0.5)
    end
    function VFX.burst(pos, col, n)
        if not enabled() or not pos then return end
        local e = takeEmitter()
        e.part.CFrame = CFrame.new(pos)
        e.part.Parent = workspace
        e.em.Color = ColorSequence.new(col or C.gold)
        pcall(function() e.em:Emit(math.max(3, math.floor((n or 16) * (lite() and 0.4 or 1)))) end)
        task.delay(0.6, function() if e.part then e.part.Parent = nil end end)
    end
    function VFX.ball(pos, col, from, to, mat)
        if not enabled() or not pos then return end
        local p = takeBall()
        p.Color = col or C.gold
        p.Material = mat or Enum.Material.ForceField
        p.Size = Vector3.new(from or 6, from or 6, from or 6)
        p.CFrame = CFrame.new(pos)
        p.Transparency = 0.1
        p.Parent = workspace
        local s = to or 9
        tween(p, 0.4, {Size = Vector3.new(s, s, s), Transparency = 1}, Enum.EasingStyle.Quint)
        park(p, 0.45)
    end
    -- afterimage: neon ghosts of your body parts that fade out
    function VFX.afterimage(col)
        if not enabled() then return end
        local c = char()
        if not c then return end
        local maxN = lite() and 3 or 8
        local n = 0
        for _, bp in ipairs(c:GetChildren()) do
            if n >= maxN then break end
            if bp:IsA("BasePart") and bp.Name ~= "HumanoidRootPart" and bp.Transparency < 0.9 then
                n += 1
                local g = takeGhost()
                g.Size = bp.Size * 1.05
                g.CFrame = bp.CFrame
                g.Color = col or C.spirit
                g.Transparency = 0.45
                g.Parent = workspace
                tween(g, 0.5, {Transparency = 1, Size = bp.Size * 1.08}, Enum.EasingStyle.Quint)
                park(g, 0.5)
            end
        end
    end
    -- speed trail on the root part (one Trail, reused)
    local trail, a0, a1
    function VFX.trail(dur)
        if not enabled() then return end
        local r = hrp()
        if not r then return end
        if not trail or not trail.Parent or a0.Parent ~= r then
            pcall(function() if trail then trail:Destroy() end if a0 then a0:Destroy() end if a1 then a1:Destroy() end end)
            a0 = own(new("Attachment", {Name = "SecretTrailA", Position = Vector3.new(0, 1.2, 0), Parent = r}))
            a1 = own(new("Attachment", {Name = "SecretTrailB", Position = Vector3.new(0, -1.2, 0), Parent = r}))
            trail = own(new("Trail", {Attachment0 = a0, Attachment1 = a1, Lifetime = 0.3, LightEmission = 0.8, Enabled = false, FaceCamera = true,
                MinLength = 0.05, WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
                Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.35, C.spirit), ColorSequenceKeypoint.new(1, C.gold)}),
                Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)}), Parent = r}))
            for _, o in ipairs({a0, a1, trail}) do pcall(function() o:SetAttribute("SecretHub", true) end) end
        end
        trail.Enabled = true
        task.delay(math.min(dur or 0.35, 0.6), function() if trail then trail.Enabled = false end end)
    end
    local fovBusy = false
    function VFX.fovKick(amount)
        if not enabled() or fovBusy then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        fovBusy = true
        local base = tonumber(settings.fov) or cam.FieldOfView
        tween(cam, 0.08, {FieldOfView = base + (amount or 10)})
        task.delay(0.1, function()
            tween(cam, 0.25, {FieldOfView = base})
            task.delay(0.27, function() fovBusy = false end)
        end)
    end

    -- composite effects for each defense (no flash here — verified paths call VFX.moment)
    function VFX.dodge(fromPos)
        VFX.afterimage(C.spirit)
        VFX.trail(0.35)
        VFX.fovKick(6)
        if fromPos then VFX.burst(fromPos, C.spiritCore, 8) end
    end
    function VFX.breakFree(pos)
        VFX.ring(pos, C.violet, 26)
        VFX.ring(pos and (pos + Vector3.new(0, 1.5, 0)), C.gold, 16)
        VFX.burst(pos, C.violet, 18)
        VFX.pulse(C.violet, 0.8)
    end
    local lastShield = 0
    function VFX.shield(pos)
        if os.clock() - lastShield < 0.35 then return end
        lastShield = os.clock()
        VFX.ball(pos, C.gold, 6, 9)
        VFX.burst(pos, C.gold, 12)
    end
    function VFX.unfreeze(pos)
        local ice = Color3.fromRGB(225, 225, 230)
        VFX.ball(pos, ice, 5, 8, Enum.Material.Glass)
        VFX.burst(pos, ice, 22)
        VFX.ring(pos, ice, 18)
        VFX.pulse(ice, 0.6)
    end
    function VFX.teleport(fromPos, toPos)
        VFX.afterimage(C.violet)
        if fromPos then VFX.burst(fromPos, C.violet, 12) end
        if toPos then VFX.ring(toPos, C.gold, 14) VFX.burst(toPos, C.gold, 10) end
        VFX.fovKick(8)
    end
    function VFX.dome(pos)
        VFX.ring(pos - Vector3.new(0, 2.6, 0), C.gold, 40)
        VFX.ring(pos - Vector3.new(0, 2.5, 0), C.spirit, 24)
        if VFX.moment then VFX.moment("safe", "SAFE", C.spirit) else VFX.flash("Safe zone", C.spirit) end
    end
    function VFX.alert(text)
        VFX.pulse(C.red, 0.7)
        VFX.flash(text or "Warning", C.red)
    end

    -- =================================================================
    -- Guardian Control presence (5.5): replaces giant hands with a brief
    -- "he took you" feel — ink afterimages, white trail, monochrome pulse,
    -- soft vignette, FOV kick, white rim on your body. Same budget as Dodge.
    -- =================================================================
    local rimTok, rimHl = 0, nil
    local function setRim(on, dur)
        rimTok += 1
        local my = rimTok
        local c = char()
        if not c then return end
        if on then
            if not (rimHl and rimHl.Parent) then
                pcall(function() if rimHl then rimHl:Destroy() end end)
                rimHl = own(new("Highlight", {Name = "SecretControlRim", Adornee = c, FillColor = Color3.new(0, 0, 0),
                    FillTransparency = 0.82, OutlineColor = C.spiritCore, OutlineTransparency = 0.15,
                    DepthMode = Enum.HighlightDepthMode.Occluded, Parent = gui}))
                pcall(function() rimHl:SetAttribute("SecretHub", true) end)
            else
                rimHl.Adornee = c
                rimHl.Parent = gui
            end
            rimHl.OutlineTransparency = 0.12
            rimHl.FillTransparency = 0.78
            task.delay(dur or 0.9, function()
                if my ~= rimTok or not rimHl then return end
                tween(rimHl, 0.35, {OutlineTransparency = 1, FillTransparency = 1})
                task.delay(0.4, function() if my == rimTok and rimHl then rimHl.Parent = nil end end)
            end)
        elseif rimHl then
            tween(rimHl, 0.25, {OutlineTransparency = 1, FillTransparency = 1})
            task.delay(0.3, function() if rimHl then rimHl.Parent = nil end end)
        end
    end
    -- kind: "rescue" | "lifeline" | "sky" | "lift" | "hop"
    function VFX.takeover(from, to, kind)
        if not enabled() then return end
        kind = kind or "rescue"
        -- body: ink ghost then white ghost (two beats = "snatched")
        VFX.afterimage(C.smoke)
        task.delay(0.07, function() if alive and enabled() then VFX.afterimage(C.spirit) end end)
        VFX.trail(kind == "sky" and 0.7 or 0.55)
        -- world: ink seal under feet + spirit burst at the start
        if from then
            VFX.ring(from - Vector3.new(0, 2.6, 0), C.smoke, lite() and 10 or 14)
            VFX.burst(from + Vector3.new(0, 1.2, 0), C.spiritCore, lite() and 6 or 12)
        end
        -- path: katana ink slash toward the destination (signature of this hub)
        if from and to and VFX.slashTrail then pcall(VFX.slashTrail, from, to, C.smoke) end
        -- screen: slight monochrome + edge vignette + FOV (kit may load after this module)
        VFX.pulse(C.spirit, kind == "sky" and 0.7 or 0.5, 0.38)
        VFX.fovKick(kind == "sky" and 10 or (kind == "lift" and 5 or 7))
        local kit = VFX._kit
        if kit and kit.vignette and not lite() then pcall(kit.vignette, C.smoke, kind == "sky" and 0.55 or 0.4, 0.05, 0.1, 0.32) end
        if kit and kit.camShake and not lite() then pcall(kit.camShake, 0.18, 0.16) end
        -- white rim: you're under his control for a moment
        setRim(true, kind == "sky" and 1.4 or 0.85)
        -- one mid-arc afterimage so the flight doesn't feel empty
        if kind ~= "lift" then
            task.delay(0.18, function() if alive and enabled() then VFX.afterimage(C.spirit) end end)
        end
        -- Verified-feeling rescue beat (Takeover only fires when control actually starts)
        local label = ({rescue = "GOT YOU", lifeline = "CLEAR", sky = "UP", lift = "UP", hop = "AGAIN"})[kind] or "GOT YOU"
        if VFX.moment then VFX.moment("rescue", label, C.spirit) end
    end
    function VFX.release(pos, kind)
        if not enabled() then return end
        setRim(false)
        if pos then
            VFX.ring(pos - Vector3.new(0, 2.6, 0), C.spirit, lite() and 12 or 16)
            VFX.burst(pos, C.spiritCore, lite() and 6 or 12)
        end
        VFX.pulse(C.spirit, 0.3, 0.28)
        if kind == "safe" then
            if VFX.moment then VFX.moment("safe", "SAFE", C.spirit) end
        end
    end
    onUnload(function() if rimHl then pcall(function() rimHl:Destroy() end) rimHl = nil end end)
end)

-- =====================================================================
-- 14g. Guardian Brain: adaptive, works in any game without per-game rules
--   * learns hazards from damage / deaths (persisted per PlaceId)
--   * notices anti-cheat reactions and limits the features that caused them
--   * classifies the situation and picks a protection / hunt strategy
--   * tracks player threat (Neutral / Watch / Enemy) and reacts defensively by default
--   * 5.6: learns which of YOUR skills hurt which targets (offense memory) when Aggression is on
-- Default is defensive. Offense is opt-in via Aggression toggles (your own attacks only).
-- =====================================================================
local K = {}   -- UI kit table (filled in section 15; the brain hooks K.gate / K.onSliderRelease)
CORE.safeModule("14g Guardian Brain", function()   -- own function scope: keeps the main chunk under Luau's 200-local limit
    local PID = tostring(game.PlaceId)
    local allData = loadJSON(GV.BRAIN_FILE, {})
    if type(allData) ~= "table" then allData = {} end
    local function fresh() return {hazards = {}, ac = {events = {}}, attackers = {}, actions = {}, offense = {skills = {}, mobs = {}, kills = 0, pvp = 0, bursts = 0}} end
    local function sanitize(d)
        if type(d) ~= "table" then d = fresh() end
        if type(d.hazards) ~= "table" then d.hazards = {} end
        if type(d.ac) ~= "table" then d.ac = {} end
        if type(d.ac.events) ~= "table" then d.ac.events = {} end
        if type(d.attackers) ~= "table" then d.attackers = {} end
        if type(d.actions) ~= "table" then d.actions = {} end
        if type(d.offense) ~= "table" then d.offense = {skills = {}, mobs = {}, kills = 0, pvp = 0, bursts = 0} end
        if type(d.offense.skills) ~= "table" then d.offense.skills = {} end
        if type(d.offense.mobs) ~= "table" then d.offense.mobs = {} end
        return d
    end
    local data = sanitize(allData[PID])
    allData[PID] = data
    brain.data = data
    local dirty = false
    local function markDirty() dirty = true end
    local function saveBrain() allData[PID] = data save(GV.BRAIN_FILE, jsonEncode(allData)) dirty = false end
    brain.save = saveBrain
    brain.markDirty = function() dirty = true end
    local function say(kind, vars, prio, sub) if VFX.say then return VFX.say(kind, vars, prio, sub) end return false end

    local function on() return alive and settings.brainOn ~= false end
    local function now() return os.clock() end
    local function event(text)
        local ev = data.ac.events
        table.insert(ev, 1, os.date("%d.%m %H:%M") .. "  " .. text)
        while #ev > 8 do table.remove(ev) end
        markDirty()
    end
    local function hex(c) return string.format("%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)) end
    local function sigOf(part) return string.lower(part.Name) .. "|" .. part.Material.Name .. "|" .. hex(part.Color) end
    local function hasHumanoid(part)
        local p = part.Parent
        return p ~= nil and (p:FindFirstChildOfClass("Humanoid") ~= nil or (p.Parent ~= nil and p.Parent:FindFirstChildOfClass("Humanoid") ~= nil))
    end
    local HAZARD_WORDS = {"kill", "lava", "damage", "hurt", "acid", "spike", "laser", "death", "poison", "toxic", "deadly"}
    local OBBY_WORDS = {"kill", "lava", "obby", "stage", "checkpoint", "spike", "laser"}
    local function hasWord(s, words)
        for _, w in ipairs(words) do if string.find(s, w, 1, true) then return true end end
        return false
    end

    -- ---------------- learned hazards ----------------
    local hazardNames = {}
    local function rebuildHazardIndex()
        hazardNames = {}
        for _, hz in pairs(data.hazards) do
            if type(hz) == "table" and hz.learned then hazardNames[tostring(hz.name)] = true end
        end
    end
    rebuildHazardIndex()
    local function isHazard(part)
        local n = string.lower(part.Name)
        if not hazardNames[n] then return false end
        local hz = data.hazards[sigOf(part)]
        return type(hz) == "table" and hz.learned == true
    end
    brain.isHazard = isHazard
    local overlap
    pcall(function()
        overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.MaxParts = 200
    end)
    local function partsNear(pos, radius)
        if not overlap then return {} end
        overlap.FilterDescendantsInstances = {char(), gui}
        local ok, res = pcall(function() return workspace:GetPartBoundsInRadius(pos, radius, overlap) end)
        return ok and res or {}
    end
    local function learnFrom(parts, weight, isDeath)
        local learnedNew = {}
        local seen = {}
        for _, part in ipairs(parts) do
            if part:IsA("BasePart") and part ~= workspace.Terrain and not part:GetAttribute("SecretHub") and not hasHumanoid(part) then
                local sig = sigOf(part)
                if not seen[sig] then
                    seen[sig] = true
                    local name = string.lower(part.Name)
                    local big = part.Size.X > 200 and part.Size.Z > 200
                    local hz = data.hazards[sig]
                    if type(hz) ~= "table" then
                        hz = {name = name, mat = part.Material.Name, col = hex(part.Color), hits = 0, deaths = 0}
                        data.hazards[sig] = hz
                    end
                    hz.hits = (tonumber(hz.hits) or 0) + weight
                    if isDeath then hz.deaths = (tonumber(hz.deaths) or 0) + 1 end
                    local keyword = hasWord(name, HAZARD_WORDS)
                    local generic = (name == "part" or name == "baseplate" or name == "floor" or name == "ground" or big)
                    local need = keyword and 1 or (generic and 6 or 3)
                    if not hz.learned and (hz.hits >= need or (isDeath and keyword)) then
                        hz.learned = true
                        learnedNew[#learnedNew + 1] = part.Name
                    end
                end
            end
        end
        -- keep the table small: drop weak, unlearned entries
        local n = 0
        for _ in pairs(data.hazards) do n += 1 end
        if n > 120 then
            for sig, hz in pairs(data.hazards) do if type(hz) ~= "table" or (not hz.learned and (tonumber(hz.hits) or 0) < 2) then data.hazards[sig] = nil end end
        end
        if #learnedNew > 0 then
            rebuildHazardIndex()
            if not say("learn", {name = learnedNew[1]}) then toast("Guardian learned a hazard: " .. table.concat(learnedNew, ", "), "shield", 4) end
            event("Learned hazard " .. table.concat(learnedNew, ", "))
        end
        markDirty()
    end

    -- hazard markers (pooled SelectionBoxes) + optional hazard shield (client-side CanTouch off)
    local markers = {}
    for i = 1, 8 do
        local sb
        pcall(function()
            sb = own(new("SelectionBox", {Name = "SecretHazard" .. i, Color3 = C.red, SurfaceColor3 = C.red, SurfaceTransparency = 0.85, LineThickness = 0.06,
                Transparency = 0.2, Visible = false, Parent = gui}))
        end)
        markers[i] = sb
    end
    local shieldOrig = {}
    local function restoreShield()
        for part, v in pairs(shieldOrig) do pcall(function() part.CanTouch = v end) end
        shieldOrig = {}
    end
    brain.restoreShield = restoreShield
    local nearHazards, obbyHints = {}, 0
    local lastHazardWarn = 0
    local function scanHazards(radius)
        local r = hrp()
        nearHazards, obbyHints = {}, 0
        if not r then return end
        local list = partsNear(r.Position, radius)
        for i, part in ipairs(list) do
            if i > 200 then break end
            local name = string.lower(part.Name)
            if hasWord(name, OBBY_WORDS) then obbyHints += 1 end
            if next(hazardNames) ~= nil and isHazard(part) then nearHazards[#nearHazards + 1] = part end
        end
        table.sort(nearHazards, function(a, b) return (a.Position - r.Position).Magnitude < (b.Position - r.Position).Magnitude end)
        for i, sb in ipairs(markers) do
            if sb then
                local part = nearHazards[i]
                sb.Adornee = part
                sb.Visible = part ~= nil and on()
            end
        end
        if settings.hazardShield and on() then
            for _, part in ipairs(nearHazards) do
                if shieldOrig[part] == nil then
                    pcall(function() shieldOrig[part] = part.CanTouch part.CanTouch = false end)
                end
            end
        elseif next(shieldOrig) ~= nil then
            restoreShield()
        end
        local closest = nearHazards[1]
        if closest and (closest.Position - r.Position).Magnitude < 8 and now() - lastHazardWarn > 6 and not settings.hazardShield then
            lastHazardWarn = now()
            toast("Hazard close: " .. closest.Name, "warn", 2)
        end
    end

    -- ---------------- player threat tracking ----------------
    local threat = {}   -- [player] = {score, level, reasons = {}, prevDist, prevPos, follow, hitAt}
    brain.threat = threat
    local function levelFor(score) if score >= 55 then return "Enemy" elseif score >= 20 then return "Watch" end return "Neutral" end
    function brain.levelOf(p) local t = threat[p] return t and t.level or "Neutral" end
    local function hostile(t) return t.level == "Enemy" or t.level == "Exploiter" end
    brain.hostile = hostile
    function brain.showThreat(p)
        if not (on() and settings.threatEsp) then return false end
        local t = threat[p]
        return t ~= nil and t.level ~= "Neutral"
    end
    function brain.colorEsp(p, o)
        if guardian.staff[p.UserId] then return end
        local lvl = brain.levelOf(p)
        local col = (lvl == "Exploiter" and Color3.fromRGB(255, 60, 200)) or (lvl == "Enemy" and C.red) or (lvl == "Watch" and C.yellow) or Color3.new(1, 1, 1)
        if not settings.esp and lvl == "Neutral" then return end
        o.hl.FillColor = col
        o.hl.OutlineColor = col
        if o.label then o.label.TextColor3 = (lvl == "Neutral") and C.text or col end
    end
    local function attackerCount(p)
        local a = data.attackers[tostring(p.UserId)]
        return type(a) == "table" and (tonumber(a.count) or 0) or 0
    end
    local myPrevPos
    local function updateThreats()
        local r = hrp()
        local me = r and r.Position
        local myMoved = (me and myPrevPos) and (me - myPrevPos).Magnitude or 0
        myPrevPos = me
        local any = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local t = threat[p]
                if not t then
                    t = {score = 0, level = "Neutral", reasons = {}, follow = 0, hitAt = 0}
                    threat[p] = t
                    local ac = attackerCount(p)
                    if ac > 0 then t.score = math.min(20 * ac, 60) t.known = true end
                end
                local reasons = {}
                local add = 0
                local c = p.Character
                local pr = c and c:FindFirstChild("HumanoidRootPart")
                if me and pr then
                    local d = (pr.Position - me).Magnitude
                    local theirMove = t.prevPos and (pr.Position - t.prevPos).Magnitude or 0
                    if d < 30 then
                        if t.prevDist and t.prevDist - d > 0.6 then add += 2 reasons[#reasons + 1] = "approaching" end
                        local toMe = (me - pr.Position)
                        if toMe.Magnitude > 0.1 and pr.CFrame.LookVector:Dot(toMe.Unit) > 0.75 and d < 25 then add += 1.5 reasons[#reasons + 1] = "facing you" end
                        if c:FindFirstChildOfClass("Tool") and d < 20 then add += 2.5 reasons[#reasons + 1] = "tool out" end
                        local spd = pr.AssemblyLinearVelocity.Magnitude
                        if spd > 30 and t.prevDist and t.prevDist > d then add += 1 reasons[#reasons + 1] = "fast" end
                        if myMoved > 3 and theirMove > 3 and t.prevDist and math.abs(t.prevDist - d) < 3 and d < 25 then
                            t.follow = math.min(t.follow + 1, 10)
                        else
                            t.follow = math.max(t.follow - 0.5, 0)
                        end
                        if t.follow >= 4 then add += 3 reasons[#reasons + 1] = "following you" end
                    else
                        t.follow = math.max(t.follow - 1, 0)
                    end
                    t.prevDist, t.prevPos, t.dist = d, pr.Position, d
                else
                    t.prevDist, t.prevPos, t.dist = nil, nil, nil
                end
                if now() - (t.hitAt or 0) < 15 then reasons[#reasons + 1] = "hit you" end
                if t.known then reasons[#reasons + 1] = "attacked you before" end
                -- decay toward a floor for known attackers
                local floor = t.known and math.min(20 * attackerCount(p), 40) or 0
                t.score = math.max(floor, t.score * 0.95 + add)
                t.score = math.min(t.score, 100)
                local prevLevel = t.level
                t.level = levelFor(t.score)
                if t.exploiterUntil and now() < t.exploiterUntil then
                    t.level = "Exploiter"
                    table.insert(reasons, 1, "EXPLOITER: " .. tostring(t.exploitWhy or "abnormal movement"))
                end
                t.reasons = reasons
                if t.level ~= "Neutral" then any = true end
                if t.level == "Enemy" and prevLevel ~= "Enemy" and on() then
                    if not say("threat", {name = p.DisplayName, why = reasons[1], player = p}, 2) then toast(p.DisplayName .. " looks hostile (" .. (reasons[1] or "threat") .. ")", "bad", 3) end
                end
            end
        end
        for p in pairs(threat) do if p.Parent ~= Players then threat[p] = nil end end
        brain.anyThreat = any and settings.threatEsp == true
    end
    local function nearestPlayer(maxD)
        local r = hrp()
        if not r then return nil, nil end
        local best, bd
        for _, p in ipairs(Players:GetPlayers()) do
            local pr = p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if pr then
                local d = (pr.Position - r.Position).Magnitude
                if d <= maxD and (not bd or d < bd) then best, bd = p, d end
            end
        end
        return best, bd
    end
    local function nearestEnemy(maxD)
        local best, bd
        for p, t in pairs(threat) do
            if hostile(t) and t.dist and t.dist <= maxD and (not bd or t.dist < bd) then best, bd = p, t.dist end
        end
        return best, bd
    end
    local function npcNear(pos, radius)
        for _, part in ipairs(partsNear(pos, radius)) do
            local m = part.Parent
            local h = m and m:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 and not Players:GetPlayerFromCharacter(m) then return true end
        end
        return false
    end
    -- Only NPCs Sense already marked hostile / enemy (never shop / quest NPCs just because they exist).
    local function hostileNpcNear(range)
        local SEN = CORE.sense
        if SEN and type(SEN.list) == "table" then
            for _, info in ipairs(SEN.list) do
                if not info.player and info.dist and info.dist <= range
                    and (info.hostile == true or info.enemy == true or (now() - (info.lastHitAt or -10) < 10)) then
                    return true
                end
            end
        end
        local AG = CORE.aggro
        return AG ~= nil and AG.target ~= nil and AG.target.kind == "npc"
    end

    -- ---------------- action reliability (success checks + backoff) ----------------
    local function act(name)
        local a = data.actions[name]
        if type(a) ~= "table" then a = {fails = 0, ok = 0} data.actions[name] = a end
        return a
    end
    local nextTry = {}
    local function canTry(name)
        local a = act(name)
        return not a.broken and now() >= (nextTry[name] or 0)
    end
    local function report(name, success, label)
        local a = act(name)
        if success then
            a.ok = (tonumber(a.ok) or 0) + 1 a.fails = 0
        else
            a.fails = (tonumber(a.fails) or 0) + 1
            nextTry[name] = now() + 3 * (2 ^ a.fails)
            if a.fails >= 2 then
                a.broken = true
                if not say("broken", {name = label or name}, 2) then toast("Guardian: " .. (label or name) .. " doesn't work in this game. Stopped using it.", "warn", 4) end
                event((label or name) .. " marked as not working")
            end
        end
        markDirty()
    end
    brain.actionState = function(name) return act(name) end
    brain.canTry = canTry
    brain.report = report

    -- ---------------- anti-cheat awareness ----------------
    local ac = data.ac
    local ownTpUntil, pendingTp = 0, nil
    local lastCheatT = 0
    local function activeCheats()
        local list = {}
        local ws = brain.capSpeed(tonumber(settings.walkspeed) or 16)
        if settings.fly then list[#list + 1] = "fly" end
        if settings.noclip then list[#list + 1] = "noclip" end
        if ws > 20 and not settings.fly then list[#list + 1] = "speed" end
        if (tonumber(settings.jumppower) or 50) > 60 or settings.infjump then list[#list + 1] = "jump" end
        if now() - (brain.lastOwnTp or -99) < 3 then list[#list + 1] = "teleport" end
        return list
    end
    local FEATURE_NAMES = {fly = "Fly", noclip = "Noclip", speed = "Speed", jump = "Jump boost", teleport = "Teleport"}
    local lastAcToast = 0
    local function flag(kind, why)
        local feats = activeCheats()
        if #feats == 0 then return end
        local parts = {}
        for _, f in ipairs(feats) do
            local key = f .. "Hits"
            ac[key] = (tonumber(ac[key]) or 0) + 1
            if f == "speed" then
                local ws = brain.capSpeed(tonumber(settings.walkspeed) or 16)
                local cap = math.max(18, math.floor(ws * 0.85))
                ac.speedCap = math.min(tonumber(ac.speedCap) or 999, cap)
                parts[#parts + 1] = "Speed " .. math.floor(ws) .. " → cap " .. ac.speedCap
            elseif f == "fly" then
                local fs = tonumber(settings.flyspeed) or 60
                if (tonumber(ac.flyHits) or 0) >= 2 then ac.flyCap = math.max(20, math.min(tonumber(ac.flyCap) or 999, math.floor(fs * 0.7))) end
                parts[#parts + 1] = "Fly"
            elseif f == "teleport" then
                ac.tpStepped = true
                parts[#parts + 1] = "Teleport → small steps"
            else
                parts[#parts + 1] = FEATURE_NAMES[f] or f
            end
        end
        event(kind .. ": " .. table.concat(parts, ", ") .. (why and (" (" .. why .. ")") or ""))
        if now() - lastAcToast > 5 then
            lastAcToast = now()
            if not say("ac", {why = kind}, 3, table.concat(parts, ", ")) then toast("Guardian: anti-cheat reacted (" .. kind .. "). " .. (settings.brainLimit and "Limiting " or "Flagged ") .. table.concat(parts, ", "), "warn", 5) end
        end
        saveBrain()
        guardianRefresh("Anti-cheat reaction")
    end
    function brain.capSpeed(v)
        if settings.brainLimit and settings.brainOn ~= false and tonumber(ac.speedCap) and v > ac.speedCap then return ac.speedCap end
        return v
    end
    function brain.capFly(v)
        if settings.brainLimit and settings.brainOn ~= false and tonumber(ac.flyCap) and v > ac.flyCap then return ac.flyCap end
        return v
    end
    function brain.tpStepped() return settings.brainLimit == true and settings.brainOn ~= false and ac.tpStepped == true end
    function brain.ownMove() ownTpUntil = math.max(ownTpUntil, now() + 0.8) end
    function brain.noteTp(from, to, dur)
        brain.lastOwnTp = now()
        ownTpUntil = now() + (dur or 0) + 0.6
        pendingTp = {from = from, to = to, checkAt = now() + (dur or 0) + 1.2}
    end
    local forced = {}
    function brain.onForcedStat(stat, wanted, got)
        local f = forced[stat] or {n = 0, t = now(), warned = false}
        if now() - f.t > 12 then f.n, f.t = 0, now() end
        f.n += 1
        forced[stat] = f
        if f.n >= 6 and not f.warned then
            f.warned = true
            event(stat .. " forced back (" .. math.floor(wanted) .. " → " .. math.floor(got) .. ")")
            if not say("forced", {name = stat}, 2) then toast("Guardian: the game keeps resetting your " .. stat .. ". It may be watching it.", "warn", 4) end
            ac[stat .. "Forced"] = (tonumber(ac[stat .. "Forced"]) or 0) + 1
            markDirty()
        end
    end
    -- warn BEFORE enabling something that was flagged in this game (tap twice to force)
    local gatePending = {}
    local GATE = {fly = "flyHits", noclip = "noclipHits", clicktp = "teleportHits", infjump = "jumpHits"}
    K.gate = function(key)
        if not on() then return true end
        local hk = GATE[key]
        local hits = hk and tonumber(ac[hk]) or 0
        if hits <= 0 then return true end
        if gatePending[key] and now() - gatePending[key] < 4 then gatePending[key] = nil return true end
        gatePending[key] = now()
        local nm = (K.toggles[key] and K.toggles[key].text) or key
        toast(nm .. " was flagged " .. hits .. "× by this game's anti-cheat. Tap again to enable anyway.", "warn", 4)
        return false
    end
    K.onSliderRelease = function(key, v)
        if not on() then return end
        if key == "walkspeed" and tonumber(ac.speedCap) and v > ac.speedCap then
            if not say("speedcap", {n = tostring(ac.speedCap)}, 2) then toast("Speed above " .. ac.speedCap .. " got you rubberbanded in this game." .. (settings.brainLimit and (" Capped at " .. ac.speedCap .. ".") or ""), "warn", 4) end
        elseif key == "flyspeed" and tonumber(ac.flyCap) and v > ac.flyCap then
            if not say("flycap", {n = tostring(ac.flyCap)}, 2) then toast("Fly speed above " .. ac.flyCap .. " got flagged here." .. (settings.brainLimit and (" Capped at " .. ac.flyCap .. ".") or ""), "warn", 4) end
        end
    end
    -- anti-cheat text in the game's own GUI
    local AC_WORDS = {"exploit", "cheat", "kick", "ban", "hack", "flagged", "anticheat", "anti%-cheat"}
    local lastGuiFlag = 0
    local function checkText(obj)
        if not (on() and obj.Parent) then return end
        if obj:IsDescendantOf(gui) then return end
        local ok, txt = pcall(function() return string.lower(obj.Text) end)
        if not ok or #txt == 0 or #txt > 220 then return end
        for _, w in ipairs(AC_WORDS) do
            if string.find(txt, "%f[%a]" .. w) then
                if now() - lastGuiFlag < 4 then return end
                lastGuiFlag = now()
                local short = obj.Text:sub(1, 60)
                if #activeCheats() > 0 then flag("warning message", "'" .. short .. "'")
                else event("Game showed: '" .. short .. "'") end
                toast("Game message: '" .. short .. "'", "warn", 4)
                return
            end
        end
    end
    local textBudget, budgetT = 0, 0
    pcall(function()
        local pgui = LP:WaitForChild("PlayerGui", 5)
        if pgui then
            bind(pgui.DescendantAdded:Connect(function(d)
                if not on() or not (d:IsA("TextLabel") or d:IsA("TextButton")) then return end
                -- budget: at most 25 checks per second (some games spawn lots of damage numbers)
                if now() - budgetT > 1 then budgetT, textBudget = now(), 0 end
                if textBudget >= 25 then return end
                textBudget += 1
                task.delay(0.15, checkText, d)
            end))
        end
    end)
    pcall(function()
        bind(SVC.GuiService.ErrorMessageChanged:Connect(function(msg)
            if not alive then return end
            local m = tostring(msg or SVC.GuiService:GetErrorMessage() or "")
            if m ~= "" then
                if #activeCheats() > 0 then flag("kick", m:sub(1, 50)) else event("Kicked: " .. m:sub(1, 50)) saveBrain() end
            end
        end))
    end)

    -- ---------------- damage / death learning ----------------
    local lastDamageT, lastDamageCause = 0, nil
    local hpHist = {}   -- {t, hp, max}
    local safeHist = {}
    local lastAirVel = 0
    local function analyzeDamage(amount, died)
        if not on() then return end
        local r, h = hrp(), hum()
        if not (r and h) then return end
        lastDamageT = now()
        local attacker, ad = nearestPlayer(15)
        if attacker then
            lastDamageCause = "combat"
            local t = threat[attacker]
            if t then
                t.score = math.min(100, t.score + 35 + ((attacker.Character and attacker.Character:FindFirstChildOfClass("Tool")) and 10 or 0))
                t.hitAt = now()
                t.level = levelFor(t.score)
                if t.level == "Enemy" then
                    local key = tostring(attacker.UserId)
                    local a = data.attackers[key]
                    if type(a) ~= "table" then a = {name = attacker.Name, count = 0} data.attackers[key] = a end
                    if now() - (t.recordedAt or -99) > 20 then
                        t.recordedAt = now()
                        a.count = (tonumber(a.count) or 0) + 1 a.name = attacker.Name
                        markDirty()
                    end
                end
            end
            return attacker, ad
        end
        if lastAirVel < -55 then lastDamageCause = "fall" return nil end
        if npcNear(r.Position, 14) then lastDamageCause = "npc" return nil end
        lastDamageCause = "hazard"
        local parts = {}
        pcall(function() for _, p in ipairs(r:GetTouchingParts()) do parts[#parts + 1] = p end end)
        for _, nm in ipairs({"LeftFoot", "RightFoot", "Left Leg", "Right Leg", "LowerTorso", "Torso"}) do
            local limb = r.Parent and r.Parent:FindFirstChild(nm)
            if limb and limb:IsA("BasePart") then pcall(function() for _, p in ipairs(limb:GetTouchingParts()) do parts[#parts + 1] = p end end) end
        end
        if #parts == 0 then
            for i, p in ipairs(partsNear(r.Position - Vector3.new(0, 2.5, 0), 4)) do if i > 10 then break end parts[#parts + 1] = p end
        end
        if #parts > 0 then learnFrom(parts, died and 2 or 1, died) end
        return nil
    end

    -- defensive response: retreat (last safe spot -> away from enemy -> Safe Spot), keep distance, heal
    local lastProtect = 0
    local checkQueue = {}
    local function floorAt(pos)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ex = {gui}
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
        params.FilterDescendantsInstances = ex
        local res = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), params)
        if res and res.Instance and not (res.Instance:IsA("BasePart") and isHazard(res.Instance)) and res.Material ~= Enum.Material.Water then
            return res.Position + Vector3.new(0, 3, 0)
        end
        return nil
    end
    local function retreat(enemyPos, why)
        local r = hrp()
        if not r then return end
        if settings.handsOn == true and settings.handsRescue ~= false and VFX.handsRescue and canTry("hands_move")
            and brain.lastSafePos and brain.lastSafePos(enemyPos, 35, true) and VFX.handsRescue(false, enemyPos) then
            return true
        end
        local hp0 = hum() and hum().Health or 0
        local ladder = {
            {"retreat_safe", "Retreat to a safe position", function()
                local best, bd
                for _, cf in ipairs(safeHist) do
                    local d = (cf.Position - enemyPos).Magnitude
                    if d >= 35 and (not bd or d > bd) then best, bd = cf, d end
                end
                return best and best.Position or nil
            end},
            {"retreat_away", "Step away from the enemy", function()
                local dir = r.Position - enemyPos
                dir = Vector3.new(dir.X, 0, dir.Z)
                if dir.Magnitude < 0.1 then dir = r.CFrame.LookVector * -1 end
                return floorAt(r.Position + dir.Unit * 40)
            end},
            {"safespot", "Safe Spot", function() return "safe" end},
        }
        for _, step in ipairs(ladder) do
            local name, labelText, getTarget = step[1], step[2], step[3]
            if canTry(name) then
                local target = getTarget()
                if target then
                    local dur = 0
                    if target == "safe" then
                        FX.goSafe()
                    else
                        local _, d2 = FX.teleport(CFrame.new(target) * (r.CFrame - r.CFrame.Position))
                        dur = tonumber(d2) or 0
                    end
                    if not say("retreat", {why = why}) then toast("Guardian: " .. labelText .. (why and (" · " .. why) or ""), "shield", 2.5) end
                    checkQueue[#checkQueue + 1] = {at = now() + dur + 0.9, fn = function()
                        local rr = hrp()
                        if not rr then return end
                        local success
                        if target == "safe" then
                            success = FX.inSafe() and (rr.Position - enemyPos).Magnitude > 200
                        else
                            success = (rr.Position - target).Magnitude < 12 and (rr.Position - enemyPos).Magnitude > 22
                        end
                        report(name, success, labelText)
                        local hh = hum()
                        if success and hh and hh.Health >= hp0 - 1 and VFX.taunt then pcall(VFX.taunt, "retreat") end
                    end}
                    return true
                end
            end
        end
        return false
    end
    local HEAL_WORDS = {"heal", "med", "bandage", "potion", "food", "apple", "burger", "kit", "drink", "shield", "bloxy", "cola", "pizza", "candy"}
    local lastHeal = 0
    local function tryHeal()
        if not settings.autoHeal or now() - lastHeal < 8 or not canTry("heal") then return end
        local h = hum()
        local bp = LP:FindFirstChildOfClass("Backpack")
        if not (h and bp) then return end
        lastHeal = now()
        local tool
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not GV.isFruitItem(t) and hasWord(string.lower(t.Name), HEAL_WORDS) then tool = t break end
        end
        if not tool then report("heal", false, "Auto-heal (no healing tool)") return end
        local before = h.Health
        pcall(function() h:EquipTool(tool) end)
        task.delay(0.25, function() pcall(function() tool:Activate() end) end)
        if not say("heal", {name = tool.Name}) then toast("Guardian: using " .. tool.Name, "shield", 2) end
        checkQueue[#checkQueue + 1] = {at = now() + 2.5, fn = function()
            local hh = hum()
            report("heal", hh ~= nil and hh.Health > before + 1, "Auto-heal (" .. tool.Name .. ")")
        end}
    end
    local function onHealthChanged(hp)
        local h = hum()
        if not h then return end
        local last = brain.lastHp or hp
        brain.lastHp = hp
        if hp >= last - 0.5 then return end
        local died = hp <= 0
        local attacker = analyzeDamage(last - hp, died)
        brain.lastHit = {t = now(), amount = last - hp, cause = lastDamageCause, attacker = attacker}
        if died then
            -- instant death right after a cheat with no visible cause = likely anti-cheat reset
            local wasHealthy = false
            for _, s in ipairs(hpHist) do if now() - s.t < 1.5 and s.hp >= s.max * 0.5 then wasHealthy = true end end
            if wasHealthy and not attacker and lastDamageCause ~= "fall" and lastDamageCause ~= "npc" and now() - lastCheatT < 5 then
                local hazardHit = false
                pcall(function() for _, p in ipairs(hrp():GetTouchingParts()) do if isHazard(p) or hasWord(string.lower(p.Name), HAZARD_WORDS) then hazardHit = true end end end)
                if not hazardHit then flag("reset", "died instantly") end
            end
            return
        end
        if settings.autoProtect and on() and now() - lastProtect > 4 then
            local enemy = nearestEnemy(25)
            local foe = enemy or attacker
            local fr = foe and foe.Character and foe.Character:FindFirstChild("HumanoidRootPart")
            if fr and (enemy or hp < h.MaxHealth * 0.6) then
                lastProtect = now()
                retreat(fr.Position, foe.DisplayName)
            end
        end
        if hp < h.MaxHealth * 0.5 then tryHeal() end
    end
    local function hookChar(c)
        brain.lastHp = nil
        task.spawn(function()
            local h = c:WaitForChild("Humanoid", 10)
            if not (h and alive) then return end
            brain.lastHp = h.Health
            bind(h.HealthChanged:Connect(function(hp) if alive then pcall(onHealthChanged, hp) end end))
        end)
    end
    if LP.Character then hookChar(LP.Character) end
    bind(LP.CharacterAdded:Connect(function(c) safeHist = {} ownTpUntil = now() + 3 hookChar(c) end))

    -- ---------------- situation classifier ----------------
    local STRATEGY = {
        ["Low health"] = "Retreat on next hit · healing tools if allowed · aggression paused",
        ["Vehicle"] = "Anti-Fling paused · fewer checks",
        ["Being chased"] = "Keep distance · Safe Spot ready · threat ESP on",
        ["Dominating"] = "Aggression on · Enemy locked · learned kit → probe → M1",
        ["Hunting"] = "Aggression on · NPC locked · discover what hits, then execute",
        ["Combat"] = "Threat ESP · auto-retreat when hit",
        ["Obby"] = "Hazard scan radius x2 · learned hazards marked",
        ["Lobby"] = "Relaxed · slower checks",
        ["Exploring"] = "Normal watch",
    }
    local function classify()
        local h, r = hum(), hrp()
        if not (h and r) then return "Exploring" end
        local hpP = h.MaxHealth > 0 and (h.Health / h.MaxHealth) or 1
        if hpP < 0.35 and h.Health > 0 then return "Low health" end
        if h.SeatPart then return "Vehicle" end
        for _, t in pairs(threat) do
            if t.level ~= "Neutral" and t.follow >= 4 and t.dist and t.dist < 30 then return "Being chased" end
        end
        -- 5.6: when Aggression is armed and you're healthy, the Brain switches to hunt / dominate
        if settings.aggression == true and hpP >= 0.4 then
            if settings.aggroPvp == true then
                for p, t in pairs(threat) do
                    if (t.level == "Enemy" or t.level == "Exploiter") and t.dist and t.dist < (tonumber(settings.aggroRange) or 20) + 8 then
                        return "Dominating"
                    end
                end
            end
            if settings.aggroNpc ~= false then
                local range = math.clamp(tonumber(settings.aggroRange) or 20, 8, 40)
                -- Match Aggression targeting: shopkeepers / quest NPCs must NOT flip Hunting
                if hostileNpcNear(range) then return "Hunting" end
            end
        end
        if now() - lastDamageT < 6 and lastDamageCause == "combat" then return "Combat" end
        for p, t in pairs(threat) do
            if t.dist and t.dist < 25 and p.Character and p.Character:FindFirstChildOfClass("Tool") then return "Combat" end
        end
        local ls = LP:FindFirstChild("leaderstats")
        if obbyHints >= 3 or #nearHazards >= 2 or (ls and (ls:FindFirstChild("Stage") or ls:FindFirstChild("Checkpoint"))) then return "Obby" end
        local spawnNear = false
        pcall(function()
            for _, part in ipairs(partsNear(r.Position, 45)) do if part:IsA("SpawnLocation") then spawnNear = true break end end
        end)
        if spawnNear then return "Lobby" end
        return "Exploring"
    end

    -- ---------------- offense memory (5.6) ----------------
    -- skillId: "M1" / "key:Z" / "tool:Sword" / "gui:…" — any game. Records what actually hurt a target class.
    function brain.offenseNote(skillId, dmg, maxHp, targetName, killed)
        if not on() or type(skillId) ~= "string" or skillId == "" then return end
        local off = data.offense
        local sk = off.skills[skillId]
        if type(sk) ~= "table" then sk = {ok = 0, fail = 0, dmg = 0, n = 0, kills = 0} off.skills[skillId] = sk end
        dmg = math.max(0, tonumber(dmg) or 0)
        maxHp = math.max(1, tonumber(maxHp) or 1)
        if dmg > 0.5 then
            sk.ok = (tonumber(sk.ok) or 0) + 1
            sk.n = (tonumber(sk.n) or 0) + 1
            sk.dmg = ((tonumber(sk.dmg) or 0) * (sk.n - 1) + dmg) / sk.n
            if killed then sk.kills = (tonumber(sk.kills) or 0) + 1 off.kills = (tonumber(off.kills) or 0) + 1 end
            if dmg >= maxHp * 0.35 or killed then sk.oneshot = (tonumber(sk.oneshot) or 0) + 1 end
        else
            sk.fail = (tonumber(sk.fail) or 0) + 1
            if (sk.fail or 0) >= 4 and (sk.ok or 0) == 0 then sk.broken = true end
        end
        if type(targetName) == "string" and targetName ~= "" then
            local key = string.lower(string.gsub(targetName, "%s*%b[]", ""))
            local m = off.mobs[key]
            if type(m) ~= "table" then m = {best = skillId, hits = 0, dmg = 0} off.mobs[key] = m end
            m.hits = (tonumber(m.hits) or 0) + 1
            if dmg > (tonumber(m.dmg) or 0) then m.best, m.dmg = skillId, dmg end
            if killed or dmg >= maxHp * 0.4 then m.oneshot = skillId end
        end
        markDirty()
    end
    function brain.bestAttack(targetName)
        local off = data.offense
        if type(targetName) == "string" and targetName ~= "" then
            local m = off.mobs[string.lower(string.gsub(targetName, "%s*%b[]", ""))]
            if type(m) == "table" then
                if m.oneshot and canTry("offense_" .. tostring(m.oneshot)) then return m.oneshot, "oneshot" end
                if m.best and canTry("offense_" .. tostring(m.best)) then return m.best, "best" end
            end
        end
        local best, bd
        for id, sk in pairs(off.skills) do
            if type(sk) == "table" and not sk.broken and canTry("offense_" .. id) then
                local score = (tonumber(sk.dmg) or 0) * (1 + (tonumber(sk.oneshot) or 0) * 0.5) + (tonumber(sk.kills) or 0) * 8
                if (tonumber(sk.ok) or 0) > 0 and (not bd or score > bd) then best, bd = id, score end
            end
        end
        return best, best and "learned" or nil
    end
    function brain.offenseStats()
        local off = data.offense
        local skills, mobs = 0, 0
        for id, sk in pairs(off.skills) do if type(sk) == "table" and (tonumber(sk.ok) or 0) > 0 then skills += 1 end end
        for _ in pairs(off.mobs) do mobs += 1 end
        return {
            kills = tonumber(off.kills) or 0,
            pvp = tonumber(off.pvp) or 0,
            bursts = tonumber(off.bursts) or 0,
            skills = skills,
            mobs = mobs,
        }
    end
    function brain.markPvpKill()
        data.offense.pvp = (tonumber(data.offense.pvp) or 0) + 1
        markDirty()
    end
    function brain.markBurst()
        data.offense.bursts = (tonumber(data.offense.bursts) or 0) + 1
        markDirty()
    end

    function brain.riskExtra(cheating)
        if not on() then return 0, {} end
        local add, rs = 0, {}
        local enemies = 0
        for p, t in pairs(threat) do
            if hostile(t) then enemies += 1 rs[#rs + 1] = {"bad", p.DisplayName .. " · " .. (t.reasons[1] or "hostile")}
            elseif t.level == "Watch" and #rs < 6 then rs[#rs + 1] = {"warn", p.DisplayName .. " · " .. (t.reasons[1] or "watch")} end
        end
        add += math.min(enemies * 12, 30)
        local sit = brain.situation
        if sit == "Low health" then add += 10 rs[#rs + 1] = {"warn", "Low health"}
        elseif sit == "Being chased" then add += 12 rs[#rs + 1] = {"bad", "You are being chased"}
        elseif sit == "Dominating" then add += 8 rs[#rs + 1] = {"bad", "Aggression · Enemy locked"}
        elseif sit == "Hunting" then add += 4 rs[#rs + 1] = {"warn", "Aggression · hunting NPCs"}
        elseif sit == "Combat" then add += 6 rs[#rs + 1] = {"warn", "Combat nearby"} end
        if settings.aggression == true then rs[#rs + 1] = {"warn", "Aggression armed"} end
        if cheating then
            local hits = (tonumber(ac.speedHits) or 0) + (tonumber(ac.flyHits) or 0) + (tonumber(ac.noclipHits) or 0)
            if hits > 0 then add += math.min(hits * 5, 20) rs[#rs + 1] = {"warn", "This game flagged your cheats " .. hits .. "×"} end
        end
        return add, rs
    end

    -- ---------------- main loop (throttled, cheap) ----------------
    local ring, ringAcc = {}, 0
    local prevPos
    local fastAcc, slowAcc, saveAcc, safeAcc = 0, 0, 0, 0
    onHeartbeat("brain", function(dt)
        if not on() then
            for _, sb in ipairs(markers) do if sb then sb.Visible = false end end
            return
        end
        local r, h = hrp(), hum()
        local t = now()
        -- every frame: rubberband detection (cheap vector math)
        if r and h and h.Health > 0 then
            local pos = r.Position
            lastAirVel = (h.FloorMaterial == Enum.Material.Air) and math.min(lastAirVel, r.AssemblyLinearVelocity.Y) or (lastAirVel < -55 and lastAirVel * 0.9 or 0)
            if #activeCheats() > 0 then lastCheatT = t end
            if prevPos and t > ownTpUntil and (pos - prevPos).Magnitude > 10 then
                for _, s in ipairs(ring) do
                    local age = t - s.t
                    if age > 0.25 and age < 1.6 and (pos - s.pos).Magnitude < 5 and (prevPos - s.pos).Magnitude > 8 then
                        flag("rubberband", math.floor((prevPos - pos).Magnitude) .. " studs snap-back")
                        ring = {}
                        break
                    end
                end
            end
            prevPos = pos
            ringAcc += dt
            if ringAcc >= 0.1 then
                ringAcc = 0
                table.insert(ring, 1, {t = t, pos = pos})
                if #ring > 16 then table.remove(ring) end
            end
        else
            prevPos = nil
        end
        -- teleport success check
        if pendingTp and t >= pendingTp.checkAt then
            local tp = pendingTp
            pendingTp = nil
            if r and (r.Position - tp.from).Magnitude < 8 and (tp.to - tp.from).Magnitude > 15 then
                ac.teleportHits = (tonumber(ac.teleportHits) or 0) + 1
                local wasStepped = ac.tpStepped == true
                ac.tpStepped = true
                event("Teleport reverted" .. (wasStepped and " (even in steps)" or " → using small steps"))
                if not say("tpstep", nil, 2) then toast(wasStepped and "Guardian: this game reverts teleports." or "Guardian: teleport was reverted. Using small steps from now on.", "warn", 4) end
                if wasStepped then report("teleport", false, "Teleport") end
                saveBrain()
            end
        end
        -- queued success checks
        for i = #checkQueue, 1, -1 do
            local q = checkQueue[i]
            if t >= q.at then table.remove(checkQueue, i) pcall(q.fn) end
        end
        -- 0.5 s: threats + hp history
        fastAcc += dt
        if fastAcc >= 0.5 then
            fastAcc = 0
            updateThreats()
            if h then
                table.insert(hpHist, 1, {t = t, hp = h.Health, max = h.MaxHealth})
                if #hpHist > 6 then table.remove(hpHist) end
            end
            -- keep distance: hostile player closing in while you're hurt
            if settings.autoProtect and h and r and h.Health > 0 and h.Health < h.MaxHealth * 0.5 and t - lastProtect > 6 then
                local e, d = nearestEnemy(8)
                local er = e and e.Character and e.Character:FindFirstChild("HumanoidRootPart")
                if er and d then lastProtect = t retreat(er.Position, "keeping distance") end
            end
        end
        -- 1 s (2 s in lobby / Performance Mode): hazards, situation, safe-position history
        slowAcc += dt
        local slowEvery = (brain.situation == "Lobby" or PERF.lite) and 2 or 1
        if slowAcc >= slowEvery then
            slowAcc = 0
            local radius = (brain.situation == "Obby") and 40 or (PERF.lite and 18 or 24)
            scanHazards(radius)
            local sit = classify()
            if sit ~= brain.situation then
                local prevSit = brain.situation
                brain.situation = sit
                brain.strategy = STRATEGY[sit] or ""
                local said = false
                if sit == "Combat" then said = say("sit_combat")
                elseif sit == "Being chased" then said = say("sit_chased", nil, 2)
                elseif sit == "Low health" then said = say("sit_low", nil, 3)
                elseif sit == "Hunting" then said = say("sit_hunt")
                elseif sit == "Dominating" then said = say("sit_dominate", nil, 2)
                elseif sit == "Obby" then said = say("sit_obby")
                elseif sit == "Vehicle" then said = say("sit_vehicle")
                elseif prevSit == "Combat" or prevSit == "Being chased" or prevSit == "Low health" or prevSit == "Hunting" or prevSit == "Dominating" then said = say("sit_clear") end
                if not said and (sit == "Being chased" or sit == "Low health" or sit == "Dominating") then toast("Guardian: " .. sit .. " · " .. brain.strategy, "warn", 3) end
            end
            safeAcc += slowEvery
            if r and h and safeAcc >= 2 and h.FloorMaterial ~= Enum.Material.Air and h.Health >= h.MaxHealth * 0.6 and not FX.inSafe() then
                safeAcc = 0
                local calm = true
                for _, th in pairs(threat) do if th.level ~= "Neutral" and th.dist and th.dist < 30 then calm = false end end
                local last = safeHist[1]
                if calm and (not last or (last.Position - r.Position).Magnitude > 10) then
                    table.insert(safeHist, 1, r.CFrame)
                    if #safeHist > 20 then table.remove(safeHist) end
                end
            end
        end
        saveAcc += dt
        if saveAcc >= 5 then saveAcc = 0 if dirty then saveBrain() end end
    end)

    -- ---------------- UI data + forget ----------------
    function brain.rules()
        local out = {}
        if tonumber(ac.speedCap) then out[#out + 1] = {"warn", "Speed capped at " .. ac.speedCap .. " (flagged " .. (tonumber(ac.speedHits) or 0) .. "×)"} end
        if tonumber(ac.flyCap) then out[#out + 1] = {"warn", "Fly speed capped at " .. ac.flyCap}
        elseif (tonumber(ac.flyHits) or 0) > 0 then out[#out + 1] = {"warn", "Fly flagged " .. ac.flyHits .. "× · warns before enabling"} end
        if (tonumber(ac.noclipHits) or 0) > 0 then out[#out + 1] = {"warn", "Noclip flagged " .. ac.noclipHits .. "×"} end
        if ac.tpStepped then out[#out + 1] = {"warn", "Teleports use small steps (reverted " .. (tonumber(ac.teleportHits) or 0) .. "×)"} end
        if (tonumber(ac.WalkSpeedForced) or 0) > 0 then out[#out + 1] = {"info", "Game resets WalkSpeed"} end
        local hz = {}
        for _, h in pairs(data.hazards) do if type(h) == "table" and h.learned then hz[#hz + 1] = h end end
        table.sort(hz, function(a, b) return (tonumber(a.hits) or 0) > (tonumber(b.hits) or 0) end)
        for i, h in ipairs(hz) do
            if i > 5 then out[#out + 1] = {"info", "+" .. (#hz - 5) .. " more hazards"} break end
            out[#out + 1] = {"bad", "Hazard: " .. tostring(h.name) .. " · " .. tostring(h.mat) .. " · hit " .. math.floor(tonumber(h.hits) or 0) .. "×"}
        end
        local att = 0
        for _ in pairs(data.attackers) do att += 1 end
        if att > 0 then out[#out + 1] = {"bad", att .. " player(s) remembered as attackers"} end
        local st = brain.offenseStats and brain.offenseStats() or nil
        if st and (st.kills > 0 or st.skills > 0 or st.mobs > 0) then
            out[#out + 1] = {"ok", "Offense: " .. st.kills .. " kills · " .. st.skills .. " skills that work · " .. st.mobs .. " mob patterns"}
            if st.pvp > 0 then out[#out + 1] = {"bad", "PvP finishes remembered: " .. st.pvp} end
        end
        local best = brain.bestAttack and select(1, brain.bestAttack(nil))
        if best then out[#out + 1] = {"ok", "Best attack here: " .. tostring(best)} end
        for name, a in pairs(data.actions) do
            if type(a) == "table" and a.broken then out[#out + 1] = {"info", "Not working here: " .. name} end
        end
        if #out == 0 then out[1] = {"ok", "Nothing learned in this game yet"} end
        return out
    end
    -- Compact per-game profile for the Start card ("what I already know here")
    function brain.profile()
        local bits, detail = {}, {}
        local hzN = 0
        for _, h in pairs(data.hazards) do if type(h) == "table" and h.learned then hzN += 1 end end
        if tonumber(ac.speedCap) then bits[#bits + 1] = "Speed ≤ " .. tostring(ac.speedCap) end
        if tonumber(ac.flyCap) then bits[#bits + 1] = "Fly ≤ " .. tostring(ac.flyCap) end
        if ac.tpStepped then bits[#bits + 1] = "step TPs" end
        if hzN > 0 then bits[#bits + 1] = hzN .. " hazard" .. (hzN == 1 and "" or "s") end
        local st = brain.offenseStats and brain.offenseStats() or {skills = 0, kills = 0, mobs = 0}
        local best = brain.bestAttack and select(1, brain.bestAttack(nil))
        if best then bits[#bits + 1] = tostring(best) .. " hits" end
        if (tonumber(st.skills) or 0) > 0 then bits[#bits + 1] = st.skills .. " kit" end
        local brokenN = 0
        for _, a in pairs(data.actions) do if type(a) == "table" and a.broken then brokenN += 1 end end
        if brokenN > 0 then bits[#bits + 1] = brokenN .. " dropped" end
        local headline = (#bits > 0)
            and ("In this game I know: " .. table.concat(bits, " · "))
            or "Fresh here — watching, learning, waiting to dominate."
        local S = HUB.session or {}
        detail[#detail + 1] = {"ok", "Session · " .. (tonumber(S.dodges) or 0) .. " dodges · " .. (tonumber(S.saves) or 0) .. " saves · " .. (tonumber(S.kills) or 0) .. " downs · " .. (tonumber(S.learned) or 0) .. " learned"}
        if HUB.tier == "premium" then
            detail[#detail + 1] = {"warn", settings.aggression and "Boss mode armed — hostiles get hunted." or "Premium · arm Aggression to show who's boss."}
        else
            detail[#detail + 1] = {"info", "Free · protection active. Premium unlocks Boss mode (Aggression)."}
        end
        if best then detail[#detail + 1] = {"ok", "Best hit here: " .. tostring(best)} end
        if (tonumber(st.kills) or 0) > 0 then detail[#detail + 1] = {"ok", "Remembered finishes: " .. st.kills} end
        return headline, detail, {hazards = hzN, skills = st.skills or 0, best = best, broken = brokenN}
    end
    function brain.acSigns()
        local n = 0
        for k, v in pairs(ac) do
            if type(v) == "number" and v > 0 and (tostring(k):find("Hits") or tostring(k):find("Forced")) then n += v end
            if k == "tpStepped" and v == true then n += 1 end
        end
        if ac.speedCap or ac.flyCap then n += 1 end
        return n > 0, n
    end
    function brain.lastSafePos(enemyPos, minDist, strict)
        for _, cf in ipairs(safeHist) do
            if not enemyPos or (cf.Position - enemyPos).Magnitude >= (minDist or 0) then return cf.Position end
        end
        if strict then return nil end
        local s = safeHist[1]
        return s and s.Position or nil
    end
    function brain.forget()
        restoreShield()
        data = fresh()
        allData[PID] = data
        brain.data = data
        ac = data.ac
        hazardNames = {}
        for p, t in pairs(threat) do t.known = false t.score = 0 t.level = "Neutral" threat[p] = t end
        for _, sb in ipairs(markers) do if sb then sb.Visible = false sb.Adornee = nil end end
        saveBrain()
        toast("Guardian forgot everything it learned in this game (hazards, caps, offense).", "ok")
    end
    onUnload(function() restoreShield() if dirty then saveBrain() end end)
end)

-- =====================================================================
-- 14h. Guardian Defense (defensive / evasive only)
--   Godmode attempt · Auto-Dodge · Anti-Grab · Anti-Freeze · Exploiter Radar
--   Every action is verified; after repeated failures it is marked
--   "not working here" (saved per game) and not retried.
-- =====================================================================
CORE.safeModule("14h Guardian Defense", function()
    local function now() return os.clock() end
    local function canTry(name) return brain.canTry == nil or brain.canTry(name) end
    local function report(name, ok, labelText) if brain.report then brain.report(name, ok, labelText) end end
    local function broken(name)
        local a = brain.actionState and brain.actionState(name)
        return type(a) == "table" and a.broken == true
    end
    local function turnOff(key, why)
        settings[key] = false
        saveSettings()
        if K.toggles[key] then pcall(K.toggles[key].render, true) end
        if why then toast(why, "warn", 4) end
    end
    local function isOurs(o) local ok, v = pcall(function() return o:GetAttribute("SecretHub") end) return ok and v == true end
    local posHist = {}   -- my recent positions (for restoring after a grab)
    local function posBefore(age)
        for _, s in ipairs(posHist) do if now() - s.t >= age then return s.cf end end
        return posHist[#posHist] and posHist[#posHist].cf or nil
    end
    local function say(kind, vars, prio, sub) if VFX.say then return VFX.say(kind, vars, prio, sub) end return false end
    local dodgeState = {busy = false, lastHitAt = -10, lastGrab = -10, doDodge = nil}

    -- ---------------- 1. Guardian Godmode (4.1) ----------------
    -- Honest: the server owns your health, so no client can promise invincibility.
    -- Guardian Godmode stacks every avoidance layer instead (state guard, anti-knockback, anti-ragdoll,
    -- predictive dodge, rescue, heal, anti-void) and shows what actually got through. Code: 14n "ggod".
    function FX.applyGodmode()
        if CORE.ggod.apply then CORE.ggod.apply() end
    end

    -- ---------------- 3. Auto-Dodge (attack-size aware · verified · learns per attacker / attack type) ----------------
    -- severity → distance: small ~9, medium ~18, big/AoE 36+ (or the last safe position)
    -- a dodge only counts (and only taunts) when no damage / grab / death followed within ~0.5 s;
    -- failures adapt the next dodge for that attacker / attack type (earlier, further, other direction) and persist per game
    do
        local dodgeParams
        pcall(function()
            dodgeParams = OverlapParams.new()
            dodgeParams.FilterType = Enum.RaycastFilterType.Exclude
            dodgeParams.MaxParts = 120
        end)
        local floorParams = RaycastParams.new()
        floorParams.FilterType = Enum.RaycastFilterType.Exclude
        local wallParams = RaycastParams.new()
        wallParams.FilterType = Enum.RaycastFilterType.Exclude
        local lastDodge = 0
        local booms = {}
        local sizeSeen = setmetatable({}, {__mode = "k"})
        local lastHit = {t = -10, frac = 0}
        local hpLast
        local function floorBelow(pos)
            local ex = {gui}
            for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
            floorParams.FilterDescendantsInstances = ex
            local res = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), floorParams)
            if res and not (brain.isHazard and res.Instance and res.Instance:IsA("BasePart") and brain.isHazard(res.Instance)) then return res.Position end
            return nil
        end
        local function blocked(from, to)
            wallParams.FilterDescendantsInstances = {gui, char()}
            return workspace:Raycast(from, to - from, wallParams) ~= nil
        end
        -- persisted memory per attack key (brain.data is saved per PlaceId)
        local function mem(key, create)
            local d = brain.data
            if type(d) ~= "table" then return nil end
            if type(d.dodge) ~= "table" then d.dodge = {} end
            local e = d.dodge[key]
            if type(e) ~= "table" and create then
                e = {fails = 0, wins = 0, lead = 0, mult = 1, mode = 1}
                d.dodge[key] = e
                local n = 0
                for _ in pairs(d.dodge) do n += 1 end
                if n > 60 then for k, v in pairs(d.dodge) do if k ~= key and (tonumber(v.fails) or 0) == 0 then d.dodge[k] = nil break end end end
            end
            return type(e) == "table" and e or nil
        end
        local function lead(key) local e = mem(key, false) return e and clamp(tonumber(e.lead) or 0, 0, 0.6) or 0 end
        brain.dodgeMemory = function() local d = brain.data return type(d) == "table" and d.dodge or nil end
        local SEV_DIST = {small = 9, medium = 18, big = 36}
        local RANK = {small = 1, medium = 2, big = 3}
        local NAMES = {"small", "medium", "big"}
        local MODES = {"side", "back", "up", "cover"}
        local function hostileCount(radius)
            local n = 0
            for _, t in pairs(brain.threat or {}) do if (t.level == "Enemy" or t.level == "Exploiter") and t.dist and t.dist <= radius then n += 1 end end
            return n
        end
        local function assess(base, me)
            local rank = RANK[base] or 1
            local t = now()
            for _, b in ipairs(booms) do
                if t - b.t < 0.8 and (b.pos - me).Magnitude < b.radius + 12 then rank = 3 break end
            end
            if hostileCount(25) >= 2 then rank += 1 end
            if t - lastHit.t < 3 and lastHit.frac >= 0.3 then rank += 1 end
            return NAMES[clamp(rank, 1, 3)]
        end
        local function nameKey(part) return string.sub(string.lower(tostring(part.Name)), 1, 24) end
        local function pickTarget(r, flat, threatPos, dist, mode)
            local me = r.Position
            local perp = Vector3.new(-flat.Z, 0, flat.X).Unit
            local away = Vector3.new(me.X - threatPos.X, 0, me.Z - threatPos.Z)
            away = (away.Magnitude > 0.1) and away.Unit or (-flat).Unit
            local s = (math.random() < 0.5) and 1 or -1
            if mode == "up" then
                local cand = me + perp * s * dist * 0.5
                if floorBelow(cand) then return cand + Vector3.new(0, math.min(14, dist * 0.6), 0) end
            end
            local dirs
            if mode == "back" then dirs = {away, (away + perp * s).Unit, (away - perp * s).Unit}
            elseif mode == "cover" then dirs = {perp * s, -perp * s, away, (away + perp * s).Unit, (away - perp * s).Unit}
            else dirs = {perp * s, -perp * s, (perp * s + away).Unit} end
            local fallback
            for _, d in ipairs(dirs) do
                for _, k in ipairs({1, 0.6}) do
                    local cand = me + d * dist * k
                    local fl = floorBelow(cand)
                    if fl and math.abs(fl.Y - (me.Y - 3)) < 8 then
                        local tgt = Vector3.new(cand.X, fl.Y + 3, cand.Z)
                        if mode ~= "cover" or blocked(threatPos, tgt + Vector3.new(0, 1, 0)) then return tgt end
                        fallback = fallback or tgt
                    end
                end
            end
            return fallback
        end
        -- dash in steps; step length respects the anti-cheat-learned teleport limits
        local function dash(r, fromPos, target, small)
            local dist = (target - fromPos).Magnitude
            local stepLen = small and 5 or 12
            local wait = small and 0.05 or 0.03
            local steps = clamp(math.ceil(dist / stepLen), small and 4 or 3, 16)
            local rot = r.CFrame - r.CFrame.Position
            task.spawn(function()
                for i = 1, steps do
                    if not alive or not r.Parent then return end
                    if brain.ownMove then brain.ownMove() end
                    r.CFrame = CFrame.new(fromPos:Lerp(target, i / steps)) * rot
                    r.AssemblyLinearVelocity = Vector3.zero
                    task.wait(wait)
                end
            end)
            return steps * wait
        end
        local function attackerName(attacker)
            if attacker then return attacker.DisplayName end
            local best, bd
            for p, t in pairs(brain.threat or {}) do
                if (t.level == "Enemy" or t.level == "Exploiter") and t.dist and t.dist < 40 and (not bd or t.dist < bd) then best, bd = p, t.dist end
            end
            return best and best.DisplayName or nil
        end
        local function doDodge(threatVel, threatPos, why, opts)
            opts = opts or {}
            local r, h = hrp(), hum()
            if not (r and h) or dodgeState.busy or now() - lastDodge < 1.2 or not canTry("dodge") then return end
            local flat = Vector3.new(threatVel.X, 0, threatVel.Z)
            if flat.Magnitude < 1 then flat = Vector3.new(r.Position.X - threatPos.X, 0, r.Position.Z - threatPos.Z) end
            if flat.Magnitude < 0.1 then flat = Vector3.new(1, 0, 0) end
            local key = opts.key or "misc"
            local m = mem(key, true) or {mult = 1, mode = 1}
            local sev = assess(opts.sev or "small", r.Position)
            local small = brain.tpStepped and brain.tpStepped()
            local dist = SEV_DIST[sev] * clamp(tonumber(m.mult) or 1, 1, 2.5)
            local mode = MODES[clamp(math.floor(tonumber(m.mode) or 1), 1, #MODES)]
            local fromPos = r.Position
            local target, viaSafe
            if dist >= 30 and brain.lastSafePos then
                local sp = brain.lastSafePos(threatPos, dist * 0.8, true)
                if sp then target, viaSafe = sp, true end
            end
            if not target then target = pickTarget(r, flat, threatPos, math.min(dist, 50), mode) end
            if not target and dist > 12 then target = pickTarget(r, flat, threatPos, 10, "side") end
            if not target then return end
            lastDodge = now()
            dodgeState.busy = true
            local t0 = now()
            local moveT
            if viaSafe then
                local _, d2 = FX.teleport(CFrame.new(target) * (r.CFrame - r.CFrame.Position))
                moveT = tonumber(d2) or 0
            elseif CORE.move.dashTo and not (brain.actionState and type(brain.actionState("move_physics")) == "table" and brain.actionState("move_physics").broken) then
                moveT = CORE.move.dashTo(target)
                if moveT <= 0 then if brain.ownMove then brain.ownMove() end moveT = dash(r, fromPos, target, small) end
            else
                if brain.ownMove then brain.ownMove() end
                moveT = dash(r, fromPos, target, small)
            end
            if VFX.dodge then pcall(VFX.dodge, fromPos) end
            local attacker = opts.attacker
            task.delay(0.5 + moveT, function()
                dodgeState.busy = false
                if not alive then return end
                local hh, rr = hum(), hrp()
                local died = not hh or hh.Health <= 0
                local hurt = dodgeState.lastHitAt > t0 + 0.05
                local grabbed = dodgeState.lastGrab > t0
                local moved = rr ~= nil and (rr.Position - target).Magnitude < 8
                report("dodge", moved, "Auto-Dodge")
                local e = mem(key, true)
                if not e then return end
                if moved and not died and not hurt and not grabbed then
                    e.wins = (tonumber(e.wins) or 0) + 1
                    if (tonumber(e.fails) or 0) > 0 and e.wins % 3 == 0 then e.fails -= 1 end
                    if VFX.moment then VFX.moment("dodge", "DODGED", C.spirit) end
                    local said = say("dodged", {name = why, size = sev})
                    if not said and why then toast("Dodged " .. why, "shield", 1.5) end
                    if VFX.taunt then pcall(VFX.taunt, "dodge", attackerName(attacker)) end
                else
                    e.fails = (tonumber(e.fails) or 0) + 1
                    e.lead = math.min((tonumber(e.lead) or 0) + 0.15, 0.6)
                    e.mult = math.min((tonumber(e.mult) or 1) + 0.35, 2.5)
                    e.mode = (math.floor(tonumber(e.mode) or 1) % #MODES) + 1
                    say("adjust", nil, 2, "Next: " .. MODES[e.mode] .. " · x" .. string.format("%.1f", e.mult) .. " distance")
                end
                if brain.markDirty then brain.markDirty() end
            end)
        end
        dodgeState.doDodge = doDodge
        bind(workspace.DescendantAdded:Connect(function(d)
            if not (alive and settings.autododge) or d.ClassName ~= "Explosion" then return end
            local ok, pos, rad = pcall(function() return d.Position, d.BlastRadius end)
            if ok and pos then
                table.insert(booms, 1, {pos = pos, radius = tonumber(rad) or 8, t = now()})
                if #booms > 6 then table.remove(booms) end
            end
        end))
        onHeartbeat("dodgeHp", function()
            local h = hum()
            if not h then hpLast = nil return end
            local hp = h.Health
            if hpLast and hp < hpLast - 0.5 then
                dodgeState.lastHitAt = now()
                lastHit.t = now()
                lastHit.frac = (hpLast - hp) / math.max(h.MaxHealth, 1)
            end
            hpLast = hp
        end)
        local dodgeAcc = 0
        onHeartbeat("autododge", function(dt)
            if not settings.autododge then return end
            dodgeAcc += dt
            if dodgeAcc < (PERF.lite and 0.15 or 0.1) then return end
            dodgeAcc = 0
            local r = hrp()
            if not r or FX.inSafe() then return end
            local me = r.Position
            local t = now()
            -- explosions that just went off close to you (4.1 sensor handles them when active)
            for _, b in ipairs(CORE.sense.active and {} or booms) do
                if not b.done and t - b.t < 0.25 and (b.pos - me).Magnitude < b.radius + 6 then
                    b.done = true
                    doDodge(Vector3.zero, b.pos, "an explosion", {key = "boom", sev = "big"})
                    return
                end
            end
            if CORE.sense.active then return end   -- 4.1: players, NPCs, projectiles and hitboxes are handled predictively in 14n
            -- fast-approaching players (trigger range grows with what was learned about them)
            for _, p in ipairs(Players:GetPlayers()) do
                local pr = p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if pr then
                    local key = "p:" .. tostring(p.UserId)
                    local ld = lead(key)
                    local rel = me - pr.Position
                    local d = rel.Magnitude
                    if d < 18 + ld * 40 and d > 1 then
                        local v = pr.AssemblyLinearVelocity
                        local closing = v:Dot(rel.Unit)
                        if closing > 38 - ld * 30 then
                            doDodge(v, pr.Position, p.DisplayName, {key = key, sev = (closing > 80) and "medium" or "small", attacker = p})
                            return
                        end
                    end
                end
            end
            -- projectiles + expanding AoE parts
            if not dodgeParams then return end
            dodgeParams.FilterDescendantsInstances = {char(), gui}
            local ok, list = pcall(function() return workspace:GetPartBoundsInRadius(me, 35, dodgeParams) end)
            if not ok then return end
            for i, part in ipairs(list) do
                if i > 120 then break end
                if part ~= workspace.Terrain and not isOurs(part) then
                    local sz = part.Size.Magnitude
                    if not part.Anchored then
                        local v = part.AssemblyLinearVelocity
                        local sp = v.Magnitude
                        if sp > 60 then
                            local key = "proj:" .. nameKey(part)
                            local ld = lead(key)
                            local rel = me - part.Position
                            local tt = clamp(rel:Dot(v) / (sp * sp), 0, 0.6 + ld)
                            if tt > 0 and (rel - v * tt).Magnitude < 5 + sz * 0.5 + ld * 8 then
                                local mdl = part:FindFirstAncestorWhichIsA("Model")
                                if not (mdl and mdl == char()) then
                                    local sev = ((sz > 8) or (sz > 4 and sp > 150)) and "big" or (((sz > 3) or (sp > 140)) and "medium" or "small")
                                    if brain.isHazard and brain.isHazard(part) and sev == "small" then sev = "medium" end
                                    doDodge(v, part.Position, "a projectile", {key = key, sev = sev})
                                    return
                                end
                            end
                        end
                    end
                    if sz > 6 then
                        local prev = sizeSeen[part]
                        sizeSeen[part] = {s = sz, t = t}
                        if prev and t - prev.t < 0.6 and sz > prev.s * 1.25 and (part.Position - me).Magnitude < sz * 0.5 + 10
                            and not ((part:FindFirstAncestorWhichIsA("Model") or game):FindFirstChildOfClass("Humanoid")) then
                            doDodge(Vector3.zero, part.Position, "an expanding attack", {key = "aoe:" .. nameKey(part), sev = "big"})
                            return
                        end
                    end
                end
            end
        end)
    end

    -- ---------------- 5. Anti-Grab / Anti-Carry ----------------
    local GRAB_CLASSES = {Weld = true, WeldConstraint = true, ManualWeld = true, Motor6D = true, RopeConstraint = true, RodConstraint = true,
        BallSocketConstraint = true, SpringConstraint = true, AlignPosition = true, AlignOrientation = true, HingeConstraint = true}
    local BODY_CLASSES = {BodyPosition = true, BodyGyro = true, BodyVelocity = true, BodyForce = true, BodyThrust = true, LinearVelocity = true, VectorForce = true}
    local function inMine(x) local c = char() return x ~= nil and c ~= nil and x:IsDescendantOf(c) end
    local function endsOf(o)
        local a, b
        pcall(function()
            if o:IsA("JointInstance") or o:IsA("WeldConstraint") then a, b = o.Part0, o.Part1
            else a, b = o.Attachment0, o.Attachment1 end
        end)
        return a, b
    end
    local function hostileNear(radius)
        for p, t in pairs(brain.threat or {}) do
            if t.dist and t.dist < radius and t.level ~= "Neutral" then return p end
        end
        return nil
    end
    -- returns true if the object ties your character to something that isn't yours
    local function isGrab(o)
        if isOurs(o) or not o.Parent then return false end
        local cls = o.ClassName
        if GRAB_CLASSES[cls] then
            if o.Name == "SeatWeld" then
                local seat = o.Part0
                local m = seat and seat:FindFirstAncestorWhichIsA("Model")
                return m ~= nil and (Players:GetPlayerFromCharacter(m) ~= nil or m:FindFirstChildOfClass("Humanoid") ~= nil)
            end
            local a, b = endsOf(o)
            if not (a and b) then return false end
            local mineA, mineB = inMine(a), inMine(b)
            if mineA == mineB then return false end   -- own joints / unrelated
            local other = mineA and b or a
            local m = other:FindFirstAncestorWhichIsA("Model")
            return m ~= nil and (Players:GetPlayerFromCharacter(m) ~= nil or (m:FindFirstChildOfClass("Humanoid") ~= nil)) or hostileNear(15) ~= nil
        elseif BODY_CLASSES[cls] then
            if not inMine(o) or settings.fly then return false end
            local n = string.lower(o.Name)
            return string.find(n, "grab", 1, true) ~= nil or string.find(n, "carry", 1, true) ~= nil or string.find(n, "hold", 1, true) ~= nil
                or string.find(n, "drag", 1, true) ~= nil or hostileNear(15) ~= nil
        end
        return false
    end
    local lastBreak = 0
    local function breakFree(objs, why)
        if not canTry("antigrab") then return end
        local r, h = hrp(), hum()
        if not r then return end
        for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        if h then pcall(function() h.Sit = false h.PlatformStand = false h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
        r.AssemblyLinearVelocity = Vector3.zero
        local back = posBefore(0.6)
        if back and (back.Position - r.Position).Magnitude > 4 then
            if brain.ownMove then brain.ownMove() end
            r.CFrame = back
        end
        if VFX.breakFree then pcall(VFX.breakFree, r.Position) end
        dodgeState.lastGrab = now()
        if now() - lastBreak > 2 then if not say("grab", {name = why}) then toast("Guardian: broke free" .. (why and (" from " .. why) or "") .. ".", "shield", 2) end end
        lastBreak = now()
        task.delay(0.5, function()
            local c = char()
            if not c then return end
            local still = false
            for _, d in ipairs(c:GetDescendants()) do if (GRAB_CLASSES[d.ClassName] or BODY_CLASSES[d.ClassName]) and isGrab(d) then still = true break end end
            report("antigrab", not still, "Anti-Grab")
            if not still then
                if VFX.moment then VFX.moment("grab", "FREE", C.spirit) end
                if VFX.taunt then pcall(VFX.taunt, "grab", why and why ~= "a grab" and why or nil) end
            end
        end)
    end
    local function watchChar(c)
        bind(c.DescendantAdded:Connect(function(d)
            if not (alive and settings.antigrab) then return end
            if GRAB_CLASSES[d.ClassName] or BODY_CLASSES[d.ClassName] then
                task.defer(function() if isGrab(d) then breakFree({d}, "a grab") end end)
            end
        end))
    end
    -- other players' characters: grab scripts often put the weld on THEIR side
    local function watchOther(p)
        local function hookC(c)
            bind(c.DescendantAdded:Connect(function(d)
                if not (alive and settings.antigrab) then return end
                if GRAB_CLASSES[d.ClassName] then
                    task.defer(function() if isGrab(d) then breakFree({d}, p.DisplayName) end end)
                end
            end))
        end
        if p.Character then hookC(p.Character) end
        bind(p.CharacterAdded:Connect(hookC))
    end
    if LP.Character then watchChar(LP.Character) end
    bind(LP.CharacterAdded:Connect(function(c)
        watchChar(c)
        posHist = {}
        dodgeState.busy = false
    end))
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then watchOther(p) end end
    bind(Players.PlayerAdded:Connect(watchOther))

    -- ---------------- 7. Anti-Freeze / Anti-Kill-Script ----------------
    local freezeAcc = 0
    local lastFrozenMsg = 0
    local function repair(kind, fixFn, checkFn, labelText)
        if not canTry("freeze_" .. kind) then return end
        pcall(fixFn)
        local r = hrp()
        if VFX.unfreeze and r and now() - lastFrozenMsg > 1.5 then pcall(VFX.unfreeze, r.Position) end
        if now() - lastFrozenMsg > 3 then if not say("unfrozen", {name = labelText}) then toast("Guardian: " .. labelText .. " fixed.", "shield", 2) end end
        lastFrozenMsg = now()
        task.delay(0.4, function()
            local ok, good = pcall(checkFn)
            local success = ok and good == true
            report("freeze_" .. kind, success, "Anti-Freeze (" .. labelText .. ")")
            if success and VFX.moment then VFX.moment("freeze", "UNFROZEN", Color3.fromRGB(225, 225, 230)) end
        end)
    end
    onHeartbeat("antifreeze", function(dt)
        if not settings.antifreeze then return end
        freezeAcc += dt
        if freezeAcc < 0.2 then return end
        freezeAcc = 0
        local c, r, h = char(), hrp(), hum()
        if c and (not h or not r) and now() - lastFrozenMsg > 8 then
            lastFrozenMsg = now()
            if not say("charbroken", nil, 3) then toast("Guardian: a script removed parts of your character. Reset to fix.", "bad", 4) end
            if VFX.alert then pcall(VFX.alert, "CHARACTER BROKEN") end
            return
        end
        if not (r and h) or h.Health <= 0 then return end
        if r.Anchored and not settings.freecam then
            repair("anchor", function() r.Anchored = false end, function() return not r.Anchored end, "anchored root")
        end
        if h.PlatformStand and not settings.fly then
            repair("platform", function() h.PlatformStand = false end, function() return not h.PlatformStand end, "PlatformStand lock")
        end
        local st = h:GetState()
        if (st == Enum.HumanoidStateType.Physics and not settings.fly) or st == Enum.HumanoidStateType.Dead then
            repair("state", function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end, function()
                local s2 = h:GetState()
                return s2 ~= Enum.HumanoidStateType.Physics and s2 ~= Enum.HumanoidStateType.Dead
            end, "forced state")
        end
        if h.WalkSpeed <= 0.01 then
            local ws = brain.capSpeed(tonumber(settings.walkspeed) or 16)
            repair("speed", function() h.WalkSpeed = (ws > 0 and ws or 16) end, function() return h.WalkSpeed > 0.01 end, "frozen WalkSpeed")
        end
        if (h.UseJumpPower and h.JumpPower <= 0.01) then
            repair("jump", function() h.JumpPower = math.max(50, tonumber(settings.jumppower) or 50) end, function() return h.JumpPower > 0.01 end, "frozen JumpPower")
        end
    end)

    -- ---------------- 8. Exploiter classification + radar ----------------
    local ex = {}   -- [player] = {prev, prevT, speedStrikes, events = {{t, why}}}
    local wallParams = RaycastParams.new()
    wallParams.FilterType = Enum.RaycastFilterType.Exclude
    local function exEvent(p, e, why)
        local t = now()
        e.events[#e.events + 1] = {t = t, why = why}
        for i = #e.events, 1, -1 do if t - e.events[i].t > 60 then table.remove(e.events, i) end end
        if #e.events >= 3 then
            local th = brain.threat and brain.threat[p]
            if th then
                local was = th.exploiterUntil and t < th.exploiterUntil
                th.exploiterUntil = t + 90
                th.exploitWhy = why
                if not was then
                    if not say("exploiter", {name = p.DisplayName, why = why}, 3) then toast(p.DisplayName .. " flagged as exploiter (" .. why .. ")", "bad", 4) end
                    if VFX.alert then pcall(VFX.alert, "EXPLOITER NEARBY") end
                    local d = brain.data
                    if d then
                        if type(d.exploiters) ~= "table" then d.exploiters = {} end
                        local k = tostring(p.UserId)
                        local rec = type(d.exploiters[k]) == "table" and d.exploiters[k] or {name = p.Name, count = 0}
                        rec.count = (tonumber(rec.count) or 0) + 1 rec.name = p.Name rec.why = why
                        d.exploiters[k] = rec
                        if brain.markDirty then brain.markDirty() end
                    end
                end
            end
        end
    end
    local exAcc = 0
    onHeartbeat("exploiters", function(dt)
        if settings.brainOn == false then return end
        exAcc += dt
        if exAcc < 0.5 then return end
        local step = exAcc
        exAcc = 0
        local me = hrp()
        -- my own history for Anti-Grab restore
        if me then
            table.insert(posHist, 1, {t = now(), cf = me.CFrame})
            if #posHist > 8 then table.remove(posHist) end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local e = ex[p]
                if not e then e = {speedStrikes = 0, events = {}} ex[p] = e end
                local c = p.Character
                local pr = c and c:FindFirstChild("HumanoidRootPart")
                local ph = c and c:FindFirstChildOfClass("Humanoid")
                if pr and ph and ph.Health > 0 then
                    local pos = pr.Position
                    if e.prev and not ph.SeatPart then
                        local moved = pos - e.prev
                        local flat = Vector3.new(moved.X, 0, moved.Z).Magnitude / step
                        if moved.Magnitude > 80 and (not e.spawnT or now() - e.spawnT > 3) then
                            exEvent(p, e, "teleporting")
                        elseif flat > 75 then
                            e.speedStrikes += 1
                            if e.speedStrikes >= 2 then exEvent(p, e, "abnormal speed") e.speedStrikes = 0 end
                        else
                            e.speedStrikes = math.max(0, e.speedStrikes - 1)
                        end
                        -- noclip: walked straight through a solid wall (only checked for nearby players)
                        if me and (pos - me.Position).Magnitude < 150 and moved.Magnitude > 2 and moved.Magnitude < 40 then
                            local ex2 = {gui}
                            for _, q in ipairs(Players:GetPlayers()) do if q.Character then ex2[#ex2 + 1] = q.Character end end
                            wallParams.FilterDescendantsInstances = ex2
                            local hit = workspace:Raycast(e.prev, moved, wallParams)
                            if hit and hit.Instance:IsA("BasePart") and hit.Instance.CanCollide and hit.Instance.Anchored and hit.Instance.Transparency < 0.5
                                and math.abs(moved.Y) < 3 and hit.Instance.Size.Y > 6 then
                                exEvent(p, e, "noclipping through walls")
                            end
                        end
                    end
                    -- following you everywhere
                    local th = brain.threat and brain.threat[p]
                    if th and th.follow and th.follow >= 8 and th.dist and th.dist < 25 then
                        e.followT = (e.followT or 0) + step
                        if e.followT > 30 then exEvent(p, e, "following you everywhere") e.followT = 0 end
                    else
                        e.followT = math.max(0, (e.followT or 0) - step)
                    end
                    e.prev = pos
                else
                    e.prev = nil
                    e.spawnT = now()
                end
            end
        end
        for p in pairs(ex) do if p.Parent ~= Players then ex[p] = nil end end
    end)

    -- radar UI (top-right, smaller on phones, draggable)
    local RS = isTouch and 112 or 150
    local RANGE = 150
    local radar = new("Frame", {Parent = gui, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, isTouch and 64 or 52), Size = UDim2.new(0, RS, 0, RS + 18),
        BackgroundTransparency = 1, Visible = false, ZIndex = 70})
    local disc = new("Frame", {Parent = radar, BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, Size = UDim2.new(0, RS, 0, RS), ClipsDescendants = false, ZIndex = 70},
        {corner(999)})
    do
        local s = stroke(C.gold, 1.5, 0.3) s.Parent = disc
        for _, f in ipairs({0.66, 0.33}) do
            local ring = new("Frame", {Parent = disc, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(f, f), ZIndex = 71}, {corner(999)})
            local rs = stroke(C.purple, 1, 0.55) rs.Parent = ring
        end
        new("Frame", {Parent = disc, BackgroundColor3 = C.purple, BackgroundTransparency = 0.7, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 0, 1), ZIndex = 71})
        new("Frame", {Parent = disc, BackgroundColor3 = C.purple, BackgroundTransparency = 0.7, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, -8), ZIndex = 71})
        new("Frame", {Parent = disc, BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 6, 0, 6), ZIndex = 74}, {corner(3)})
    end
    -- sweep: a full-size holder rotates (GUI rotation pivots at the centre); the line + fading wedge live inside
    local sweep = new("Frame", {Parent = disc, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 72})
    new("Frame", {Parent = sweep, BackgroundColor3 = C.goldLight, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 2, 0.5, -3), ZIndex = 73}, {new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1)})})})
    for k = 1, 3 do
        local g = new("Frame", {Parent = sweep, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = -k * 7, ZIndex = 72})
        new("Frame", {Parent = g, BackgroundColor3 = C.gold, BackgroundTransparency = 0.55 + k * 0.12, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 0.5, -3), ZIndex = 72})
    end
    local legend = label(radar, {Position = UDim2.new(0, 0, 0, RS + 2), Size = UDim2.new(1, 0, 0, 16), Font = F.bold, Text = "RADAR · " .. RANGE .. "m",
        TextColor3 = C.gold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 70, TextStrokeTransparency = 0.5})
    makeDraggable(disc, radar)
    local blips = {}
    for i = 1, 12 do
        local b = new("Frame", {Parent = disc, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = C.red, Visible = false, ZIndex = 75}, {corner(5)})
        local bs = stroke(Color3.new(1, 1, 1), 1, 0.4) bs.Parent = b
        local bl = label(b, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.new(0, 40, 0, 10), Font = F.bold, TextSize = 8,
            Text = "", TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 76})
        blips[i] = {f = b, l = bl, s = bs}
    end
    -- V2 Guardian Radar world layer (Explorer Scanner): grey mobs, small white loot, hollow white safe zones
    do
        local dots, MAXD = {}, isTouch and 14 or 28
        for i = 1, MAXD do
            local d = new("Frame", {Parent = disc, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 4, 0, 4), BackgroundColor3 = C.sub, BorderSizePixel = 0,
                Visible = false, ZIndex = 73}, {corner(2)})
            local st = stroke(Color3.new(1, 1, 1), 1, 1) st.Parent = d
            dots[i] = {f = d, s = st}
        end
        local wAcc = 0
        onHeartbeat("radarWorld", function(dt)
            wAcc += dt
            if wAcc < (PERF.lite and 0.5 or 0.25) then return end
            wAcc = 0
            local W = CORE.world
            local on = settings.radar and settings.radarWorld ~= false and W ~= nil
            local r, cam = hrp(), workspace.CurrentCamera
            local n = 0
            if on and r and cam then
                local look = cam.CFrame.LookVector
                local fwd = Vector3.new(look.X, 0, look.Z)
                fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
                local right = Vector3.new(-fwd.Z, 0, fwd.X)
                local function place(pos, kind)
                    if n >= MAXD then return end
                    local rel = pos - r.Position
                    local dist = Vector3.new(rel.X, 0, rel.Z).Magnitude
                    if dist > RANGE then return end
                    n += 1
                    local k = dist / RANGE * (RS / 2 - 6)
                    local ang = math.atan2(rel:Dot(right), rel:Dot(fwd))
                    local d = dots[n]
                    d.f.Position = UDim2.new(0.5, math.sin(ang) * k, 0.5, -math.cos(ang) * k)
                    if kind == "mob" then d.f.Size = UDim2.new(0, 4, 0, 4) d.f.BackgroundColor3 = C.sub d.f.BackgroundTransparency = 0.1 d.s.Transparency = 1
                    elseif kind == "loot" then d.f.Size = UDim2.new(0, 3, 0, 3) d.f.BackgroundColor3 = Color3.new(1, 1, 1) d.f.BackgroundTransparency = 0 d.s.Transparency = 1
                    else d.f.Size = UDim2.new(0, 7, 0, 7) d.f.BackgroundTransparency = 1 d.s.Transparency = 0.1 end
                    d.f.Visible = true
                end
                for _, p in ipairs(W.safe or {}) do place(p, "safe") end
                for m in pairs(W.mobs or {}) do
                    if n >= MAXD then break end
                    local h = m.Parent and m:FindFirstChildOfClass("Humanoid")
                    local rp = h and h.Health > 0 and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
                    if rp then place(rp.Position, "mob") end
                end
                for p in pairs(W.drops or {}) do
                    if n >= MAXD then break end
                    if p.Parent and p:IsA("BasePart") then place(p.Position, "loot") end
                end
            end
            for i = n + 1, MAXD do if dots[i].f.Visible then dots[i].f.Visible = false end end
        end)
    end
    local radAcc, sweepAcc = 0, 0
    onHeartbeat("radar", function(dt)
        if not settings.radar then if radar.Visible then radar.Visible = false end return end
        if not radar.Visible then radar.Visible = true end
        sweepAcc += dt
        if sweepAcc >= (PERF.lite and 1 / 15 or 1 / 30) then
            sweep.Rotation = (sweep.Rotation + sweepAcc * 140) % 360
            sweepAcc = 0
        end
        radAcc += dt
        if radAcc < (PERF.lite and 0.2 or 0.1) then return end
        radAcc = 0
        local r, cam = hrp(), workspace.CurrentCamera
        if not (r and cam) then return end
        local look = cam.CFrame.LookVector
        local fwd = Vector3.new(look.X, 0, look.Z)
        if fwd.Magnitude < 0.01 then fwd = Vector3.new(0, 0, -1) end
        fwd = fwd.Unit
        local right = Vector3.new(-fwd.Z, 0, fwd.X)
        local i = 0
        local pulse = PERF.lite and 0 or (math.sin(now() * 6) * 2)
        local marked = 0
        for p, t in pairs(brain.threat or {}) do
            local staff = guardian.staff[p.UserId] ~= nil
            if (t.level ~= "Neutral" or staff) and i < #blips then
                local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if pr then
                    marked += 1
                    i += 1
                    local rel = pr.Position - r.Position
                    local x, y = rel:Dot(right), rel:Dot(fwd)
                    local dist = Vector3.new(rel.X, 0, rel.Z).Magnitude
                    local k = math.min(dist, RANGE) / RANGE * (RS / 2 - 6)
                    local ang = math.atan2(x, y)
                    local b = blips[i]
                    local col = (t.level == "Exploiter" and Color3.fromRGB(255, 60, 200)) or ((t.level == "Enemy" or staff) and C.red) or C.yellow
                    b.f.BackgroundColor3 = col
                    b.s.Color = (t.level == "Exploiter") and Color3.new(1, 1, 1) or col
                    local sz = ((t.level == "Neutral") and 7 or 9) + pulse
                    b.f.Size = UDim2.new(0, sz, 0, sz)
                    b.f.Position = UDim2.new(0.5, math.sin(ang) * k, 0.5, -math.cos(ang) * k)
                    b.f.BackgroundTransparency = dist > RANGE and 0.5 or 0
                    b.l.Text = math.floor(dist) .. "m"
                    b.l.TextColor3 = col
                    b.f.Visible = true
                end
            end
        end
        for j = i + 1, #blips do blips[j].f.Visible = false end
        legend.Text = "RADAR · " .. RANGE .. "m" .. (marked > 0 and ("  ·  " .. marked .. " marked") or "")
    end)

    -- ---------------- cleanup ----------------
    function FX.defenseOff()
        if settings.godmode ~= true and CORE.ggod.apply then pcall(CORE.ggod.apply) end
        radar.Visible = false
    end
    onUnload(FX.defenseOff)
    task.delay(1, function() if alive and settings.godmode then FX.applyGodmode() end end)
end)

-- =====================================================================
-- 14i. Signature FX (3.2): Aura Mode, Awakening intro, Sixth Sense, Lightning Teleport,
--      Hex Shield, Domain Expansion, FX Showcase
--   * local-only visuals (nothing is sent to the server, nothing touches other players)
--   * pooled parts, global particle budget, lighter (still visible) in Performance Mode
--   * everything is removed on Panic / Unload; Lighting is only changed through our own effects
-- =====================================================================
CORE.safeModule("14i Signature FX", function()
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local HEX_COL = Color3.fromRGB(215, 215, 220)
    local BOLT_COL = Color3.fromRGB(245, 245, 245)
    local WHITE = Color3.new(1, 1, 1)
    local function now() return os.clock() end
    local function lite() return PERF.lite end
    local suppressUntil = 0
    local function fxOn(key)
        return alive and settings.vfx ~= false and settings[key] == true and now() >= suppressUntil
    end
    local function master() return alive and settings.vfx ~= false and now() >= suppressUntil end
    local function hostileT(t) return t and (t.level == "Enemy" or t.level == "Exploiter") end
    -- long tweens (the shared tween() caps UI tweens at 0.25 s)
    local function tl(o, t, props, style, dir)
        if typeof(o) ~= "Instance" then return nil end
        local ok, tw = pcall(function()
            return SVC.TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        end)
        if ok and tw then tw:Play() return tw end
        return nil
    end
    local function tag(o) pcall(function() o:SetAttribute("SecretHub", true) end) return o end
    local function part(props)
        local p = new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
            Transparency = 1, Size = Vector3.new(1, 1, 1)})
        for k, v in pairs(props or {}) do p[k] = v end
        return own(tag(p))
    end
    -- lazy ring-buffer pools
    local function makePool(make, size)
        local items, idx = {}, 0
        return function()
            idx = idx % size + 1
            if not items[idx] then items[idx] = make() end
            return items[idx]
        end
    end
    local parkTok = setmetatable({}, {__mode = "k"})
    local function park(p, after)
        local tok = (parkTok[p] or 0) + 1
        parkTok[p] = tok
        task.delay(after, function() if parkTok[p] == tok and p then p.Parent = nil end end)
    end
    -- global particle budget (per second)
    local budget, budgetT = 0, 0
    local function allow(n)
        local t = now()
        if t - budgetT > 1 then budgetT = t budget = 0 end
        local cap = lite() and 60 or 170
        n = math.floor((n or 10) * (lite() and 0.45 or 1))
        n = math.min(n, cap - budget)
        if n < 1 then return 0 end
        budget += n
        return n
    end
    local takeEm = makePool(function()
        local p = part({Size = Vector3.new(0.2, 0.2, 0.2)})
        local e = new("ParticleEmitter", {Parent = p, Enabled = false, Texture = SPARK, LightEmission = 1, Rate = 0, Drag = 3,
            SpreadAngle = Vector2.new(180, 180), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})})
        return {part = p, em = e}
    end, 5)
    local function emit(pos, col, n, speed, life, size, col2)
        if not pos then return end
        n = allow(n)
        if n <= 0 then return end
        local e = takeEm()
        speed, life = speed or 16, life or 0.5
        e.part.CFrame = CFrame.new(pos)
        e.part.Parent = workspace
        e.em.Color = ColorSequence.new(col or C.gold, col2 or col or C.gold)
        e.em.Speed = NumberRange.new(speed * 0.5, speed)
        e.em.Lifetime = NumberRange.new(life * 0.6, life)
        e.em.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 0.6), NumberSequenceKeypoint.new(1, 0)})
        pcall(function() e.em:Emit(n) end)
        park(e.part, life + 0.25)
    end

    -- ---------------- shared screen layers ----------------
    -- edge vignette (4 gradient edges, one colour)
    local vigHolder = new("Frame", {Parent = gui, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 92, Active = false, Visible = false})
    local vig = {}
    local vigSpecs = {
        {UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.26, 0), 90}, {UDim2.new(0, 0, 0.74, 0), UDim2.new(1, 0, 0.26, 0), 270},
        {UDim2.new(0, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), 0}, {UDim2.new(0.8, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), 180},
    }
    for i, s in ipairs(vigSpecs) do
        local f = new("Frame", {Parent = vigHolder, BorderSizePixel = 0, Position = s[1], Size = s[2], BackgroundColor3 = C.gold, BackgroundTransparency = 1, ZIndex = 92})
        new("UIGradient", {Parent = f, Rotation = s[3], Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})})
        vig[i] = f
    end
    local vigTok = 0
    local function vignette(col, strength, inT, holdT, outT)
        vigTok += 1
        local my = vigTok
        inT, holdT, outT = inT or 0.08, holdT or 0.1, outT or 0.35
        vigHolder.Visible = true
        for _, f in ipairs(vig) do
            f.BackgroundColor3 = col or C.gold
            tl(f, inT, {BackgroundTransparency = 1 - (strength or 0.6)})
        end
        task.delay(inT + holdT, function()
            if my ~= vigTok then return end
            for _, f in ipairs(vig) do tl(f, outT, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine) end
            task.delay(outT + 0.05, function() if my == vigTok then vigHolder.Visible = false end end)
        end)
    end
    -- camera shake through Humanoid.CameraOffset (restored afterwards)
    local shake = {untilT = 0, amp = 0, dur = 0.3, base = nil, hum = nil}
    local function shakeRestore()
        if shake.hum and shake.base then pcall(function() shake.hum.CameraOffset = shake.base end) end
        shake.hum, shake.base = nil, nil
        onRender("fxShake", nil)
    end
    local function camShake(amp, dur)
        local h = hum()
        if not h then return end
        if shake.hum ~= h then shakeRestore() shake.hum = h shake.base = h.CameraOffset end
        shake.amp = (amp or 0.3) * (lite() and 0.6 or 1)
        shake.dur = dur or 0.3
        shake.untilT = now() + shake.dur
        onRender("fxShake", function()
            local left = shake.untilT - now()
            local hh = shake.hum
            if left <= 0 or not alive or not hh or not hh.Parent then shakeRestore() return end
            local a = shake.amp * (left / shake.dur)
            hh.CameraOffset = shake.base + Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
        end)
    end
    local function groundAt(pos)
        local res
        pcall(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {char(), gui}
            res = workspace:Raycast(pos, Vector3.new(0, -14, 0), rp)
        end)
        if res and res.Position then return res.Position end
        return pos - Vector3.new(0, 3, 0)
    end
    local function nearestHostile()
        local best, bd
        for p, t in pairs(brain.threat or {}) do
            if hostileT(t) and t.dist and (not bd or t.dist < bd) then best, bd = p, t.dist end
        end
        return best, bd
    end

    -- ================= 16. AURA MODE =================
    local AURA = {safe = C.green, danger = C.yellow, critical = C.red}
    local aura = {built = false, visible = false, status = "safe", col = C.green, phase = 0, spin = 0, pop = 0, acc = 0, statusAcc = 1,
        previewUntil = 0, forceStatus = nil}
    local function auraStatus()
        if aura.forceStatus and now() < aura.previewUntil then return aura.forceStatus end
        local h = hum()
        local hp = (h and h.MaxHealth > 0) and (h.Health / h.MaxHealth) or 1
        local sit = brain.situation
        local score = tonumber(guardian.score) or 0
        local _, near = nearestHostile()
        near = near or 999
        if score >= 60 or hp < 0.3 or sit == "Low health" or near < 12 then return "critical" end
        if score >= 25 or hp < 0.65 or sit == "Combat" or sit == "Being chased" or near < 35 then return "danger" end
        return "safe"
    end
    -- 4.0: the bubble is gone. What is left is deliberately quiet: a faint ground ring that breathes,
    -- and a few spirit wisps rising from your feet. Off by default.
    local function auraBuild()
        if aura.built then return end
        aura.built = true
        -- a real ring (SurfaceGui stroke on an invisible flat part), not a filled disc
        aura.ground = part({Size = Vector3.new(5, 0.05, 5), Transparency = 1, Material = Enum.Material.SmoothPlastic})
        local sg = new("SurfaceGui", {Parent = aura.ground, Face = Enum.NormalId.Top, LightInfluence = 0, Brightness = 2.2,
            SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(256, 256)})
        local function ring(scale, th, tr)
            local f = new("Frame", {Parent = sg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale),
                BackgroundTransparency = 1}, {new("UICorner", {CornerRadius = UDim.new(0.5, 0)})})
            return new("UIStroke", {Parent = f, Thickness = th, Color = C.spirit, Transparency = tr})
        end
        aura.r1 = ring(0.92, 3, 0.3)
        aura.r2 = ring(0.78, 1, 0.6)
    end
    local function auraAttach(r)
        if aura.att and aura.att.Parent == r then return end
        pcall(function() if aura.att then aura.att:Destroy() end end)
        aura.att = own(tag(new("Attachment", {Name = "SecretAura", Position = Vector3.new(0, -2.6, 0), Parent = r})))
        aura.em = own(tag(new("ParticleEmitter", {Parent = aura.att, Texture = "rbxasset://textures/particles/smoke_main.dds", LightEmission = 0.6, LightInfluence = 0,
            Rate = 0, Lifetime = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(0.6, 1.4), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, 1.6, 0),
            Drag = 1.5, RotSpeed = NumberRange.new(-30, 30), Rotation = NumberRange.new(0, 360), EmissionDirection = Enum.NormalId.Top,
            Color = ColorSequence.new(C.spiritCore, C.spirit),
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1.1)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.8), NumberSequenceKeypoint.new(1, 1)})})))
        aura.light = nil
    end
    local function auraHide()
        aura.visible = false
        if not aura.built then return end
        aura.ground.Parent = nil
        if aura.em then pcall(function() aura.em.Rate = 0 end) end
    end
    local function auraFlare(st)
        local r = hrp()
        if not r then return end
        aura.pop = 1
        if st == "critical" then VFX.ring(r.Position - Vector3.new(0, 2.8, 0), C.red, 14) end
    end
    local function auraFrame(dt)
        local r, h = hrp(), hum()
        local want = (fxOn("fxAura") or (master() and now() < aura.previewUntil)) and r and h and h.Health > 0
        if not want then if aura.visible then auraHide() end return end
        auraBuild() auraAttach(r)
        aura.acc += dt
        if aura.acc < 1 / 30 then return end
        local step = math.min(aura.acc, 0.1)
        aura.acc = 0
        aura.statusAcc += step
        if aura.statusAcc >= 0.3 then
            aura.statusAcc = 0
            local st = auraStatus()
            if st ~= aura.status then aura.status = st if aura.visible then auraFlare(st) end end
            if aura.em then aura.em.Rate = lite() and 1 or 2.5 end
        end
        aura.visible = true
        -- calm spirit colour; only a critical moment warms it towards the accent
        local target = (aura.status == "critical" and C.gold) or C.spirit
        aura.col = aura.col:Lerp(target, math.min(1, step * 3))
        aura.phase = (aura.phase + step * 0.9 * math.pi * 2) % (math.pi * 2)
        aura.pop = math.max(0, aura.pop - step * 2)
        local pulse = 0.5 + 0.5 * math.sin(aura.phase)
        local pos = r.Position
        local floorY = pos.Y - 2.95
        pcall(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {char(), gui}
            local res = workspace:Raycast(pos, Vector3.new(0, -7, 0), rp)
            if res then floorY = res.Position.Y + 0.04 end
        end)
        local gs = 5 + pulse * 0.35 + aura.pop * 2
        local g = aura.ground
        g.Size = Vector3.new(gs, 0.05, gs)
        g.CFrame = CFrame.new(pos.X, floorY, pos.Z) * CFrame.Angles(0, aura.phase * 0.15, 0)
        aura.r1.Color = aura.col aura.r2.Color = aura.col
        aura.r1.Transparency = 0.35 + 0.3 * (1 - pulse)
        aura.r2.Transparency = 0.65 + 0.2 * pulse
        g.Parent = workspace
        if aura.em then aura.em.Color = ColorSequence.new(C.spiritCore, aura.col) end
    end
    onRender("fxAura", function(dt)
        local ok, e = pcall(auraFrame, dt)
        if not ok then auraHide() CORE.log("ERR", "aura: " .. tostring(e)) end
    end)
    function VFX.auraPreview()
        if not master() then return end
        aura.previewUntil = now() + 2.4
        aura.forceStatus = "safe"
        aura.status = "safe"
        local seq = {"danger", "critical", "safe"}
        for i, st in ipairs(seq) do
            task.delay(i * 0.6, function() if alive and now() < aura.previewUntil then aura.forceStatus = st end end)
        end
        task.delay(2.45, function() aura.forceStatus = nil end)
    end

    -- ================= 28. AWAKENING INTRO =================
    local intro = {running = false, layer = nil}
    local function safeMoment()
        local h = hum()
        if not h or h.Health <= 0 or h.Health < h.MaxHealth * 0.6 then return false, "low health" end
        local sit = brain.situation
        if sit == "Combat" or sit == "Being chased" or sit == "Low health" then return false, string.lower(sit) end
        local _, d = nearestHostile()
        if d and d < 40 then return false, "enemy nearby" end
        if (tonumber(guardian.score) or 0) >= 60 then return false, "high risk" end
        return true
    end
    function VFX.awaken(force)
        if intro.running or not master() then return false end
        if not force and not fxOn("fxAwaken") then return false end
        if not force then
            local ok, why = safeMoment()
            if not ok then toast("Intro skipped · Guardian sees danger (" .. tostring(why) .. ")", "shield", 2.5) return false end
        end
        local r = hrp()
        if not r then return false end
        intro.running = true
        local skipped = false
        local layer = new("Frame", {Parent = gui, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 96})
        intro.layer = layer
        local barH = lite() and 0.08 or 0.1
        local topBar = new("Frame", {Parent = layer, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), ZIndex = 96})
        local botBar = new("Frame", {Parent = layer, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), ZIndex = 96})
        local title = label(layer, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.92, 0, 0, 58), Font = F.black,
            Text = spaced("Void Hub"), TextScaled = true, TextColor3 = WHITE, TextTransparency = 1, ZIndex = 98, TextXAlignment = Enum.TextXAlignment.Center})
        new("UITextSizeConstraint", {Parent = title, MaxTextSize = 50, MinTextSize = 14})
        local tGrad = new("UIGradient", {Parent = title, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.goldDark), ColorSequenceKeypoint.new(0.45, C.gold),
            ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(0.55, C.gold), ColorSequenceKeypoint.new(1, C.goldDark)}), Offset = Vector2.new(-1, 0)})
        local tStroke = new("UIStroke", {Parent = title, Thickness = 2, Color = C.ink, Transparency = 1})
        local tScale = new("UIScale", {Parent = title, Scale = 1.4})
        local sub = label(layer, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 44), Size = UDim2.new(0.9, 0, 0, 20), Font = F.bold,
            Text = spaced("The Guardian is with you") .. "   ·   " .. string.upper(LP.DisplayName), TextSize = 11, TextColor3 = C.goldLight, TextTransparency = 1, ZIndex = 98,
            TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd})
        local line = new("Frame", {Parent = layer, BackgroundColor3 = C.gold, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.4, 32), Size = UDim2.new(0, 0, 0, 2), ZIndex = 97})
        local skipBtn = new("TextButton", {Parent = layer, BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 99})
        local hint = label(layer, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0, 200, 0, 16), Font = F.medium,
            Text = (isTouch and "tap" or "click") .. " to skip", TextSize = 11, TextColor3 = C.sub, TextTransparency = 1, ZIndex = 98,
            TextXAlignment = Enum.TextXAlignment.Center})
        local function finish(fast)
            local t = fast and 0.12 or 0.25
            for _, o in ipairs({title, sub, hint}) do tl(o, t, {TextTransparency = 1}) end
            tl(tStroke, t, {Transparency = 1})
            tl(line, t, {BackgroundTransparency = 1})
            tl(topBar, t, {Size = UDim2.new(1, 0, 0, 0)}) tl(botBar, t, {Size = UDim2.new(1, 0, 0, 0)})
            task.delay(t + 0.05, function()
                pcall(function() layer:Destroy() end)
                if intro.layer == layer then intro.layer = nil end
                intro.running = false
            end)
        end
        bind(skipBtn.Activated:Connect(function() skipped = true end))
        local function hold(t)
            local e = 0
            while e < t and not skipped and alive and layer.Parent do e += task.wait() end
        end
        -- t = 0: energy burst + shockwave
        local pos = r.Position
        local feet = groundAt(pos)
        tl(topBar, 0.18, {Size = UDim2.new(1, 0, barH, 0)}) tl(botBar, 0.18, {Size = UDim2.new(1, 0, barH, 0)})
        vignette(C.gold, 0.7, 0.07, 0.25, 0.5)
        VFX.ball(pos, C.gold, 2, 18, Enum.Material.Neon)
        VFX.afterimage(C.goldLight)
        emit(pos, C.gold, 40, 34, 0.7, 0.9, C.violet)
        VFX.ring(feet + Vector3.new(0, 0.15, 0), C.gold, 48)
        task.delay(0.12, function() if alive then VFX.ring(feet + Vector3.new(0, 0.2, 0), C.violet, 30) end end)
        camShake(0.45, 0.4)
        VFX.fovKick(14)
        if settings.sounds then sound(GV.SND_TICK, 0.3, 0.6) sound(GV.SND_CLICK, 0.35, 0.5) end
        hold(0.08)
        -- title
        tl(title, 0.15, {TextTransparency = 0}) tl(tStroke, 0.15, {Transparency = 0.2})
        tl(tScale, 0.22, {Scale = 1}, Enum.EasingStyle.Back)
        tl(tGrad, 0.7, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Sine)
        hold(0.17)
        tl(line, 0.3, {Size = UDim2.new(0.55, 0, 0, 2)})
        tl(sub, 0.2, {TextTransparency = 0}) tl(hint, 0.2, {TextTransparency = 0.3})
        hold(0.85)
        finish(skipped)
        return true
    end

    -- ================= 29. SIXTH SENSE =================
    local sense = {last = -100, tok = nil, cc = nil, blur = nil, hl = nil}
    local inside = setmetatable({}, {__mode = "k"})
    local senseL = label(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, layoutMode() == "portrait" and 0.3 or 0.2, 0), Size = UDim2.new(0, 360, 0, 26), Font = F.black,
        Text = "", TextSize = 13, TextColor3 = C.red, TextTransparency = 1, ZIndex = 95, TextXAlignment = Enum.TextXAlignment.Center})
    local senseStroke = new("UIStroke", {Parent = senseL, Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 1})
    local senseScale = new("UIScale", {Parent = senseL, Scale = 1})
    local function senseFx()
        if not sense.cc or not sense.cc.Parent then
            sense.cc = own(tag(new("ColorCorrectionEffect", {Name = "SecretSense", Enabled = false, Saturation = 0, Contrast = 0, TintColor = WHITE, Parent = SVC.Lighting})))
        end
        if not sense.blur or not sense.blur.Parent then
            sense.blur = own(tag(new("BlurEffect", {Name = "SecretSenseBlur", Enabled = false, Size = 0, Parent = SVC.Lighting})))
        end
    end
    local function senseOff()
        sense.tok = nil
        pcall(function() if sense.cc then sense.cc:Destroy() end if sense.blur then sense.blur:Destroy() end if sense.hl then sense.hl:Destroy() end end)
        sense.cc, sense.blur, sense.hl = nil, nil, nil
        senseL.TextTransparency = 1 senseStroke.Transparency = 1
    end
    local function outlineFlash(model, col)
        if not model then return end
        if not sense.hl or not sense.hl.Parent or sense.hl.Parent ~= model then
            pcall(function() if sense.hl then sense.hl:Destroy() end end)
            sense.hl = own(tag(new("Highlight", {Name = "SecretSense", FillColor = col, OutlineColor = col, FillTransparency = 1, OutlineTransparency = 1,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = model})))
        end
        local hl = sense.hl
        hl.FillColor = col hl.OutlineColor = col
        hl.FillTransparency = 0.35 hl.OutlineTransparency = 0
        task.delay(0.15, function() tl(hl, 0.9, {FillTransparency = 1, OutlineTransparency = 1}, Enum.EasingStyle.Sine) end)
        task.delay(1.2, function() if sense.hl == hl then pcall(function() hl:Destroy() end) sense.hl = nil end end)
    end
    function VFX.sixthSense(p, dist, force)
        if not master() then return end
        if not force and not fxOn("fxSixth") then return end
        senseFx()
        local tok = {}
        sense.tok = tok
        local cc, blur = sense.cc, sense.blur
        cc.Enabled = true blur.Enabled = true
        tl(cc, 0.12, {Saturation = lite() and -0.45 or -0.75, Contrast = 0.15, TintColor = Color3.fromRGB(255, 222, 222)})
        tl(blur, 0.1, {Size = lite() and 4 or 9})
        VFX.fovKick(-7)
        task.delay(0.14, function() if sense.tok == tok then tl(blur, 0.4, {Size = 0}, Enum.EasingStyle.Sine) end end)
        task.delay(0.75, function()
            if sense.tok ~= tok then return end
            tl(cc, 0.5, {Saturation = 0, Contrast = 0, TintColor = WHITE}, Enum.EasingStyle.Sine)
            task.delay(0.55, function() if sense.tok == tok then cc.Enabled = false blur.Enabled = false end end)
        end)
        local model = p and p.Character
        if model then outlineFlash(model, C.red) end
        -- heartbeat: lub-dub vignette + label pulse (+ optional sound)
        local who = p and p.DisplayName or "Threat"
        senseL.Text = spaced("Sixth Sense") .. "    " .. who .. (dist and ("  ·  " .. math.floor(dist) .. " m") or "")
        senseL.TextTransparency = 0 senseStroke.Transparency = 0.3
        local function beat(scale, strength)
            senseScale.Scale = scale
            tween(senseScale, 0.18, {Scale = 1})
            vignette(C.red, strength, 0.05, 0.04, 0.22)
            if settings.sounds and settings.fxHeartbeat then sound(GV.SND_CLICK, 0.45, 0.32) end
        end
        beat(1.25, 0.55)
        task.delay(0.24, function() if sense.tok == tok then beat(1.12, 0.35) end end)
        task.delay(1.4, function() if sense.tok == tok then tween(senseL, 0.25, {TextTransparency = 1}) tween(senseStroke, 0.25, {Transparency = 1}) end end)
    end
    local senseAcc = 0
    onHeartbeat("fxSense", function(dt)
        senseAcc += dt
        if senseAcc < 0.25 then return end
        senseAcc = 0
        if not fxOn("fxSixth") or settings.brainOn == false then return end
        local t = now()
        local best, bd
        for p, th in pairs(brain.threat or {}) do
            local close = hostileT(th) and th.dist and th.dist <= 25
            if close and not inside[p] and (not bd or th.dist < bd) then best, bd = p, th.dist end
            if not close and inside[p] and (not hostileT(th) or not th.dist or th.dist > 32) then inside[p] = nil end
        end
        for p in pairs(inside) do if not (brain.threat or {})[p] then inside[p] = nil end end
        if best and t - sense.last >= 8 then
            sense.last = t
            inside[best] = true
            local ok, e = pcall(VFX.sixthSense, best, bd)
            if not ok then CORE.log("ERR", "sixth sense: " .. tostring(e)) end
        end
    end)

    -- ================= 32. LIGHTNING TELEPORT =================
    local takeShard = makePool(function() return part({Size = Vector3.new(0.35, 0.35, 1.6)}) end, 10)
    local takeBolt = makePool(function() return part({Size = Vector3.new(0.3, 0.3, 1)}) end, 16)
    local takeOrb = makePool(function() return part({Shape = Enum.PartType.Ball}) end, 3)
    local takePillar = makePool(function()
        local p = part({Shape = Enum.PartType.Cylinder})
        new("PointLight", {Parent = p, Range = 28, Brightness = 0, Color = BOLT_COL, Shadows = false})
        return p
    end, 2)
    local lastBolt = -1
    local function implode(pos, col)
        local n = lite() and 5 or 10
        for _ = 1, n do
            local s = takeShard()
            local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
            if dir.Magnitude < 0.05 then dir = Vector3.new(0, 1, 0) end
            local start = pos + dir.Unit * (4 + math.random() * 3)
            s.Size = Vector3.new(0.3, 0.3, 1.8)
            s.CFrame = CFrame.new(start, pos)
            s.Color = col
            s.Transparency = 0.05
            s.Parent = workspace
            tween(s, 0.24, {CFrame = CFrame.new(pos, pos + dir), Size = Vector3.new(0.08, 0.08, 0.3), Transparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            park(s, 0.3)
        end
        local o = takeOrb()
        o.Material = Enum.Material.Neon
        o.Color = col
        o.Size = Vector3.new(7, 7, 7)
        o.CFrame = CFrame.new(pos)
        o.Transparency = 0.55
        o.Parent = workspace
        tween(o, 0.24, {Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 0}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.24, function()
            if not alive then return end
            tween(o, 0.15, {Size = Vector3.new(3, 3, 3), Transparency = 1})
            park(o, 0.2)
            emit(pos, col, 12, 18, 0.35, 0.5)
        end)
    end
    local function strike(pos)
        if not alive then return end
        local feet = groundAt(pos)
        local p = takePillar()
        p.Size = Vector3.new(170, 5, 5)
        p.CFrame = CFrame.new(feet + Vector3.new(0, 84, 0)) * CFrame.Angles(0, 0, math.rad(90))
        p.Color = BOLT_COL
        p.Transparency = 0.05
        p.Parent = workspace
        tween(p, 0.42, {Size = Vector3.new(170, 0.2, 0.2), Transparency = 1}, Enum.EasingStyle.Quint)
        park(p, 0.46)
        local light = p:FindFirstChildOfClass("PointLight")
        if light then light.Brightness = 9 tween(light, 0.4, {Brightness = 0}, Enum.EasingStyle.Linear) end
        -- zig-zag bolt from the sky
        local segs = lite() and 5 or 8
        local top = feet + Vector3.new(math.random(-6, 6), 70, math.random(-6, 6))
        local prev = top
        for i = 1, segs do
            local nxt = (i == segs) and feet or (top:Lerp(feet, i / segs) + Vector3.new(math.random(-30, 30) / 10, 0, math.random(-30, 30) / 10))
            local b = takeBolt()
            local len = math.max((nxt - prev).Magnitude, 0.5)
            b.Size = Vector3.new(0.4, 0.4, len)
            b.CFrame = CFrame.new((prev + nxt) / 2, nxt)
            b.Color = BOLT_COL
            b.Transparency = 0
            b.Parent = workspace
            tween(b, 0.32, {Transparency = 1, Size = Vector3.new(0.05, 0.05, len)}, Enum.EasingStyle.Quad)
            park(b, 0.36)
            prev = nxt
        end
        -- emerge
        VFX.ring(feet + Vector3.new(0, 0.15, 0), BOLT_COL, 22)
        VFX.ring(feet + Vector3.new(0, 0.25, 0), C.gold, 12)
        VFX.ball(pos, WHITE, 2, 10, Enum.Material.Neon)
        emit(pos, BOLT_COL, 18, 24, 0.45, 0.6, C.gold)
        VFX.tint(BOLT_COL)
        VFX.fovKick(9)
        camShake(0.3, 0.22)
    end
    local plainTeleport = VFX.teleport
    function VFX.preTeleport()
        if fxOn("fxBolt") then VFX.afterimage(Color3.fromRGB(200, 200, 205)) end
    end
    function VFX.teleport(fromPos, toPos, delay, force)
        if not master() then return end
        if not force and not fxOn("fxBolt") then
            if plainTeleport then plainTeleport(fromPos, toPos) end
            return
        end
        if now() - lastBolt < 0.25 then return end
        lastBolt = now()
        if fromPos then implode(fromPos, C.violet) end
        if toPos then
            local d = math.min(tonumber(delay) or 0, 3)
            if d > 0.05 then task.delay(d, function() strike(toPos) end) else strike(toPos) end
        end
    end

    -- ================= 33. HEX SHIELD =================
    local takePanel = makePool(function() return part({Material = Enum.Material.Glass, Reflectance = 0.2}) end, 12)
    local takeEdge = makePool(function() return part({}) end, 12)
    local takeFrag = makePool(function() return part({Material = Enum.Material.Glass, Reflectance = 0.2}) end, 18)
    local lastHex = -1
    function VFX.hexShield(pos, col, force)
        if not master() or not pos then return end
        if not force and not fxOn("fxHex") then return end
        if now() - lastHex < 0.3 then return end
        lastHex = now()
        col = col or HEX_COL
        local R = 3.4
        local panels, edges = {}, {}
        for i = 0, 5 do
            local a = math.rad(i * 60)
            local cf = CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(R, 0, 0)
            local p = takePanel()
            p.Size = Vector3.new(0.12, 5.4, R * 1.16)
            p.CFrame = cf
            p.Color = col
            p.Transparency = 1
            p.Parent = workspace
            tween(p, 0.07, {Transparency = 0.45})
            panels[#panels + 1] = {p = p, cf = cf, dir = Vector3.new(math.cos(a), 0, -math.sin(a))}
            local e = takeEdge()
            local ea = a + math.rad(30)
            e.Size = Vector3.new(0.14, 5.6, 0.14)
            e.CFrame = CFrame.new(pos) * CFrame.Angles(0, ea, 0) * CFrame.new(R * 1.155, 0, 0)
            e.Color = col
            e.Transparency = 0.05
            e.Parent = workspace
            edges[#edges + 1] = e
        end
        if settings.sounds then sound(GV.SND_TICK, 0.2, 2) end
        task.delay(0.17, function()
            if not alive then return end
            local per = lite() and 1 or 3
            for _, pn in ipairs(panels) do
                pn.p.Transparency = 1
                park(pn.p, 0.05)
                for _ = 1, per do
                    local f = takeFrag()
                    local s = 0.5 + math.random() * 0.7
                    f.Size = Vector3.new(0.1, s, s)
                    f.CFrame = pn.cf * CFrame.new(0, (math.random() - 0.5) * 4, (math.random() - 0.5) * 3)
                    f.Color = col
                    f.Transparency = 0.25
                    f.Parent = workspace
                    local out = pn.dir * (4 + math.random() * 4) + Vector3.new(0, (math.random() - 0.2) * 4, 0)
                    tween(f, 0.5, {CFrame = CFrame.new(f.Position + out) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                        Transparency = 1, Size = Vector3.new(0.05, s * 0.4, s * 0.4)}, Enum.EasingStyle.Quad)
                    park(f, 0.55)
                end
            end
            for _, e in ipairs(edges) do tween(e, 0.2, {Transparency = 1}) park(e, 0.25) end
            emit(pos, col, 16, 22, 0.4, 0.5, WHITE)
            if settings.sounds then sound(GV.SND_CLICK, 0.25, 1.9) end
        end)
    end
    -- Godmode block / Anti-Grab now also raise a hex shield that shatters
    local baseShield, baseBreak = VFX.shield, VFX.breakFree
    function VFX.shield(pos)
        if baseShield then baseShield(pos) end
        if pos then VFX.hexShield(pos, Color3.fromRGB(240, 240, 240)) end
    end
    function VFX.breakFree(pos)
        if baseBreak then baseBreak(pos) end
        if pos then VFX.hexShield(pos, Color3.fromRGB(150, 150, 156)) end
    end

    -- ================= 35. DOMAIN EXPANSION =================
    local dom = {built = false, active = false, last = -100, tok = nil, spin = 0, acc = 0}
    local RUNES = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"}
    local function ringFrame(parent, scale, th, col, tr)
        local f = new("Frame", {Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale),
            BackgroundTransparency = 1}, {new("UICorner", {CornerRadius = UDim.new(0.5, 0)})})
        local s = new("UIStroke", {Parent = f, Thickness = th, Color = col, Transparency = tr or 0})
        return f, s
    end
    local function runeCircle(parent, count, radius, size, col)
        for i = 1, count do
            local a = (i / count) * math.pi * 2
            label(parent, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + math.cos(a) * radius, 0.5 + math.sin(a) * radius),
                Size = UDim2.fromScale(size, size), Text = RUNES[(i - 1) % #RUNES + 1], TextScaled = true, Font = F.black, TextColor3 = col,
                Rotation = math.deg(a) + 90, TextXAlignment = Enum.TextXAlignment.Center})
        end
    end
    local function domainBuild()
        if dom.built then return end
        dom.built = true
        dom.outer = part({Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = C.violet})
        dom.inner = part({Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(190, 190, 196)})
        new("SpecialMesh", {Parent = dom.inner, MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(-1, -1, -1)})  -- inverted: visible from inside
        dom.ring = part({Material = Enum.Material.SmoothPlastic, Size = Vector3.new(4, 0.1, 4)})
        local sg = new("SurfaceGui", {Parent = dom.ring, Face = Enum.NormalId.Top, LightInfluence = 0, Brightness = 2,
            SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(512, 512)})
        dom.sg = sg
        dom.rotA = new("Frame", {Parent = sg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
        dom.rotB = new("Frame", {Parent = sg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
        ringFrame(dom.rotA, 0.97, 9, C.gold)
        ringFrame(dom.rotA, 0.8, 3, C.goldLight, 0.2)
        runeCircle(dom.rotA, 12, 0.445, 0.07, C.gold)
        ringFrame(dom.rotB, 0.62, 6, C.violet)
        ringFrame(dom.rotB, 0.34, 4, C.gold, 0.1)
        runeCircle(dom.rotB, 8, 0.24, 0.06, Color3.fromRGB(220, 220, 225))
        dom.orbs = {}
        for i = 1, 12 do dom.orbs[i] = part({Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Color = (i % 2 == 0) and C.gold or C.violet}) end
        dom.emPart = part({Size = Vector3.new(40, 14, 40)})
        dom.em = new("ParticleEmitter", {Parent = dom.emPart, Enabled = false, Texture = SPARK, LightEmission = 1, Rate = 30, Lifetime = NumberRange.new(1.4, 2.4),
            Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 3, 0), RotSpeed = NumberRange.new(-90, 90),
            Color = ColorSequence.new(C.violet, C.gold),
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})})
        pcall(function() dom.em.Shape = Enum.ParticleEmitterShape.Box dom.em.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end)
    end
    local function domainFrame(dt)
        if not dom.active then return end
        dom.acc += dt
        if lite() and dom.acc < 1 / 30 then return end
        local step = math.min(dom.acc, 0.1)
        dom.acc = 0
        dom.spin = (dom.spin + step) % 1000
        dom.rotA.Rotation = (dom.spin * 22) % 360
        dom.rotB.Rotation = (-dom.spin * 40) % 360
        local R = dom.radius or 40
        local n = lite() and 6 or 12
        for i, o in ipairs(dom.orbs) do
            if i <= n then
                local a = dom.spin * (1.2 + (i % 3) * 0.35) + i * (math.pi * 2 / n)
                local rad = R * (0.25 + (i % 4) * 0.13)
                local y = (dom.spin * 4 + i * 1.7) % 20
                o.CFrame = CFrame.new(dom.center + Vector3.new(math.cos(a) * rad, y, math.sin(a) * rad))
                o.Transparency = 0.05 + (y / 20) * 0.8
                o.Parent = workspace
            else
                o.Parent = nil
            end
        end
    end
    local function domainCollapse(tok, instant)
        if tok and dom.tok ~= tok then return end
        if not dom.active then return end
        dom.active = false
        dom.tok = nil
        local cc = dom.cc
        dom.cc = nil
        onRender("fxDomain", nil)
        if not dom.built then return end
        dom.em.Enabled = false
        for _, o in ipairs(dom.orbs) do o.Parent = nil end
        if instant then
            pcall(function() if cc then cc:Destroy() end end)
            dom.outer.Parent = nil dom.inner.Parent = nil dom.ring.Parent = nil dom.emPart.Parent = nil
            return
        end
        tween(dom.outer, 0.45, {Size = Vector3.new(1, 1, 1), Transparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tween(dom.inner, 0.45, {Size = Vector3.new(1, 1, 1), Transparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tween(dom.ring, 0.45, {Size = Vector3.new(2, 0.1, 2)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        if cc then
            tl(cc, 0.45, {TintColor = WHITE, Saturation = 0, Contrast = 0, Brightness = 0}, Enum.EasingStyle.Sine)
            task.delay(0.5, function() pcall(function() cc:Destroy() end) end)
        end
        local c = dom.center
        task.delay(0.45, function()
            if alive and c then emit(c + Vector3.new(0, 3, 0), C.violet, 24, 26, 0.5, 0.8, C.gold) VFX.ring(c + Vector3.new(0, 0.2, 0), C.violet, 30) end
            if not dom.active then dom.outer.Parent = nil dom.inner.Parent = nil dom.ring.Parent = nil dom.emPart.Parent = nil end
        end)
    end
    function VFX.domain(force)
        if not alive then return false end
        if settings.vfx == false then toast("Visual effects are off (Settings → Interface).", "info", 2) return false end
        if not force and settings.fxDomain ~= true then toast("Domain Expansion is turned off in DXLTA → Effects.", "info", 2) return false end
        if dom.active then return false end
        local left = 15 - (now() - dom.last)
        if left > 0 and not force then toast("Domain Expansion ready in " .. math.ceil(left) .. "s", "info", 1.6) return false end
        local r = hrp()
        if not r then return false end
        domainBuild()
        dom.active = true
        dom.last = now()
        local tok = {}
        dom.tok = tok
        local center = groundAt(r.Position)
        local D = lite() and 70 or 90
        dom.center, dom.radius = center, D / 2
        local o, i = dom.outer, dom.inner
        o.Size = Vector3.new(2, 2, 2) o.CFrame = CFrame.new(center) o.Transparency = 0.1 o.Parent = workspace
        i.Size = Vector3.new(2, 2, 2) i.CFrame = CFrame.new(center) i.Transparency = 0.2 i.Parent = workspace
        tween(o, 0.8, {Size = Vector3.new(D, D, D), Transparency = 0.6}, Enum.EasingStyle.Quint)
        tween(i, 0.8, {Size = Vector3.new(D - 1, D - 1, D - 1), Transparency = 0.55}, Enum.EasingStyle.Quint)
        dom.ring.CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0))
        dom.ring.Size = Vector3.new(4, 0.1, 4)
        dom.ring.Parent = workspace
        tween(dom.ring, 0.8, {Size = Vector3.new(D * 0.8, 0.1, D * 0.8)}, Enum.EasingStyle.Quint)
        dom.emPart.CFrame = CFrame.new(center + Vector3.new(0, 7, 0))
        dom.emPart.Size = Vector3.new(D * 0.6, 14, D * 0.6)
        dom.emPart.Parent = workspace
        dom.em.Rate = lite() and 12 or 32
        dom.em.Enabled = true
        local cc = own(tag(new("ColorCorrectionEffect", {Name = "SecretDomain", TintColor = WHITE, Saturation = 0, Contrast = 0, Brightness = 0, Parent = SVC.Lighting})))
        dom.cc = cc
        tl(cc, 0.8, {TintColor = Color3.fromRGB(225, 225, 230), Saturation = -0.45, Contrast = 0.2, Brightness = -0.03}, Enum.EasingStyle.Sine)
        emit(r.Position, C.violet, 36, 34, 0.6, 0.9, C.gold)
        VFX.ring(center + Vector3.new(0, 0.2, 0), C.gold, D * 0.9)
        VFX.flash("DOMAIN EXPANSION", C.violet)
        vignette(C.violet, 0.6, 0.08, 0.3, 0.6)
        camShake(0.4, 0.35)
        VFX.fovKick(12)
        if settings.sounds then sound(GV.SND_TICK, 0.3, 0.45) end
        onRender("fxDomain", function(dt)
            local ok, e = pcall(domainFrame, dt)
            if not ok then CORE.log("ERR", "domain: " .. tostring(e)) domainCollapse(nil, true) end
        end)
        task.delay(6, function() domainCollapse(tok, false) end)
        return true
    end

    -- ================= FX Showcase =================
    local showTok = nil
    local function previewPos() local r = hrp() return r and r.Position end
    function VFX.preview(name)
        local pos = previewPos()
        if not master() then toast("Visual effects are off (Settings → Interface).", "info", 2) return end
        if not pos then toast("No character found.", "bad") return end
        if name == "aura" then VFX.auraPreview()
        elseif name == "awaken" then VFX.awaken(true)
        elseif name == "sense" then
            local p = nearestHostile()
            if not p then
                for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LP and pl.Character then p = pl break end end
            end
            VFX.sixthSense(p or LP, nil, true)
        elseif name == "bolt" then
            VFX.afterimage(Color3.fromRGB(200, 200, 205))
            lastBolt = -1
            VFX.teleport(pos, pos, 0.3, true)
        elseif name == "hex" then lastHex = -1 VFX.hexShield(pos, nil, true)
        elseif name == "domain" then VFX.domain(true)
        elseif name == "godform" then if VFX.godForm then VFX.godForm(true) end
        elseif name == "hands" then if VFX.handsPreview then VFX.handsPreview() end
        elseif name == "voice" then if VFX.voicePreview then VFX.voicePreview() end end
    end
    function VFX.showcase()
        if not master() then toast("Visual effects are off (Settings → Interface).", "info", 2) return end
        if showTok then toast("FX Showcase is already playing.", "info", 1.6) return end
        local tok = {}
        showTok = tok
        task.spawn(function()
            local steps = {{"awaken", 0.6}, {"aura", 2.5}, {"hex", 1.0}, {"bolt", 1.2}, {"sense", 1.8}, {"voice", 2.2}, {"hands", 3.2},
                {"godform", 4.5}, {"godform", 1.6}, {"domain", 7.2}}
            toast("FX Showcase · 9 effects", "star", 2)
            for _, s in ipairs(steps) do
                if showTok ~= tok or not alive then return end
                pcall(VFX.preview, s[1])
                local e = 0
                while e < s[2] and showTok == tok and alive do e += task.wait(0.1) end
            end
            if showTok == tok then showTok = nil end
        end)
    end

    VFX._kit = {part = part, emit = emit, camShake = camShake, vignette = vignette, tl = tl, makePool = makePool, ringFrame = ringFrame,
        groundAt = groundAt, safeMoment = safeMoment, takeBolt = takeBolt, park = park, implode = implode, BOLT_COL = BOLT_COL, tag = tag}
    -- ================= cleanup (Panic / Unload) =================
    local function cleanup()
        showTok = nil
        domainCollapse(nil, true)
        senseOff()
        auraHide()
        aura.previewUntil = 0
        shakeRestore()
        if intro.layer then pcall(function() intro.layer:Destroy() end) intro.layer = nil end
        intro.running = false
        vigTok += 1
        vigHolder.Visible = false
        pcall(function() if aura.att then aura.att:Destroy() end end)
        aura.att, aura.em, aura.light = nil, nil, nil
    end
    function FX.fxOff()
        cleanup()
        settings.fxAura = false
        suppressUntil = now() + 1   -- Panic's own Safe Spot teleport stays quiet
        for _, f in ipairs({"godOff", "voiceOff", "handsOff", "ghostOff"}) do if VFX[f] then pcall(VFX[f]) end end
    end
    onUnload(cleanup)
end)

-- =====================================================================
-- 14j. Guardian Voice (top-center subtitle line) + Taunts
--   * typed line in a glass pill, priority queue (critical interrupts), merges duplicates,
--     rate-limited, varied phrasing (never the same line twice in a row)
--   * taunts appear only after a VERIFIED successful defense; local text only (never sent to chat)
-- =====================================================================
CORE.safeModule("14j Guardian Voice", function()
    local function now() return os.clock() end
    local P = {
        threat = {"Enemy approaching {dir} — {dist}m", "{name} is hostile, {dir} — {dist}m", "Heads up: {name} {dir}, {dist}m out", "Hostile contact {dir} — {name}, {dist}m"},
        exploiter = {"Exploiter detected: {name} — {why}", "{name} is exploiting ({why}). Watching closely.", "Careful — {name} looks like an exploiter."},
        staff = {"Staff in the server: {name}. Play it cool.", "{name} is staff — keeping things quiet.", "Staff detected: {name}."},
        learn = {"Learned: {name} hurts — avoiding it", "Noted: {name} is dangerous. Steering clear.", "{name} damages you here — I'll keep you away.", "Hazard memorized: {name}."},
        broken = {"{name} doesn't work in this game — dropping it.", "{name} failed twice here. Not trying again.", "Giving up on {name} in this game."},
        ac = {"Anti-cheat reacted ({kind}) — limiting {what}", "This game noticed {kind}. Dialing back {what}.", "Flag detected ({kind}) — adjusting {what}"},
        speedcap = {"Speed flagged here — capping at {cap}", "Rubberband detected — speed capped at {cap}", "Keeping speed under {cap} in this game."},
        flycap = {"Fly speed flagged — capping at {cap}", "Fly over {cap} gets noticed here. Capped."},
        forced = {"The game keeps resetting your {name} — it may be watching.", "{name} got forced back. Careful here."},
        tpstep = {"Teleports get reverted here — switching to small steps.", "Teleport reverted. Using short hops from now on."},
        retreat = {"Retreating to safe position", "Pulling you back — {why}", "Falling back to safety.", "Getting you out of there."},
        heal = {"Using {name} — patching you up.", "Healing with {name}.", "Low health — {name} equipped."},
        blocked = {"Hit blocked", "Damage absorbed.", "Shield held."},
        dodged = {"Dodged {name}", "Sidestepped {name}.", "Evaded {name}.", "Dodged a {size} attack."},
        adjust = {"Adjusting — I'll dodge earlier next time.", "That one got through. Reacting sooner next time.", "Learning that attack — next dodge goes further."},
        grab = {"Grab broken", "Broke free from {name}.", "Shook off {name}."},
        unfrozen = {"{name} fixed — you can move again.", "Freeze broken. {name} repaired."},
        charbroken = {"A script broke your character — reset to fix.", "Character damaged by a script. Reset when you can."},
        sit_combat = {"Combat detected", "Fight nearby — staying sharp.", "Combat mode: watching every hit."},
        sit_chased = {"You're being chased — keeping distance.", "Someone's on your tail.", "Pursuit detected — Safe Spot ready."},
        sit_low = {"Health critical — playing it safe.", "You're low. Avoiding fights.", "Low health — retreat is armed."},
        sit_hunt = {"Hunting. Looking for an opening.", "Target acquired. Execute ladder ready.", "Mob in range. One-shot first."},
        sit_dominate = {"Enemy locked. Your move is mine.", "Dominating. They started it.", "Aggression up. Finishing this."},
        sit_clear = {"Area secured", "All clear.", "Threat gone. You're safe.", "Situation calm again."},
        sit_obby = {"Obby detected — scanning hazards wider.", "Obstacle course — watching every jump."},
        sit_vehicle = {"Vehicle mode — anti-fling paused."},
        aggro_oneshot = {"One-shot. {skill}.", "Opening with {skill}.", "Execute — {skill} on {name}."},
        aggro_kill = {"{name} down.", "Cleared {name}.", "{name} won't get up."},
        aggro_pvp = {"{name} is done.", "Outplayed {name}.", "{name} shouldn't have swung first."},
        aggro_on = {"Aggression armed. Scanning your kit in this game.", "Offense online. I'll learn what hits here.", "Guardian goes on the attack — any game, your moves."},
        aggro_off = {"Aggression off. Back to defense.", "Claws in. Watching only."},
        aggro_learn = {"New game. Testing what actually works…", "Learning your kit here. Keep an eye out.", "Probing tools and keys — winners stay, duds drop."},
        aggro_found = {"{name} hits. Locked in.", "Got it — {name} works here.", "Learned: {name}."},
        aggro_drop = {"{name} does nothing here. Dropped.", "Skipping {name} — no damage.", "{name} is dead weight in this title."},
        npc = {"Hostile NPC {name} down — for everyone.", "NPC {name} neutralized.", "{name} won't bother you again."},
        npcfail = {"NPC reset didn't stick on the server — backing off.", "That only changed on your screen. Not faking it."},
        godform = {"God Form active.", "Power unleashed.", "Ascended."},
        godform_off = {"Powering down.", "God Form ended.", "Back to normal."},
        godform_no = {"Not now — {why}.", "God Form needs a calm moment ({why})."},
        hands_rescue = {"I've got you.", "Hold on.", "Got you — pulling you out."},
        hands_lift = {"Up you go.", "Lifting you up.", "Allow me."},
        rescue_hit = {"Not on my watch.", "That hit would have ended you. Moving you.", "I've got you. Pulling you out."},
        rescue_low = {"You're fading. Taking you somewhere safe.", "Health critical. I'm carrying you out.", "Easy. I've got you."},
        rescue_void = {"Caught you.", "Not falling today.", "The void can't have you."},
        rescue_hazard = {"This ground is hurting you. Moving.", "Off the hazard. Now."},
        rescue_ok = {"You're safe.", "Safe ground.", "Clear. Breathe."},
        rescue_fail = {"The game pulled you back. I couldn't move you here.", "Carry blocked by the game. Use the Safe Spot."},
        rescue_blocked = {"Moving you is blocked in this game. I won't fake it.", "This game reverts my carries. I won't fake it."},
        npc_unsupported = {"NPC reset isn't possible here. NPCs are server-owned. Switched to evasion.", "{game}: NPCs live on the server. Reset disabled, NPC Evade on."},
        npc_evade = {"Evaded {name}.", "Out of {name}'s reach.", "Sidestepped {name}."},
        -- 4.1
        dodge_pred = {"Saw that coming.", "Read {name}'s attack.", "Out of the arc.", "Moved before it landed.", "{name} telegraphed that."},
        shield_up = {"Incoming. Brace.", "Brace.", "Wall up."},
        push_off = {"Projectile pushed wide.", "Not that one.", "Deflected the line. You moved."},
        catch_fall = {"Caught you.", "Soft landing.", "I've got the fall."},
        recover = {"Low. Taking you out of reach.", "Breaking contact so you can heal.", "Out of the fight for a moment."},
        -- V2.3 Lifeline + companion hand
        lifeline_go = {"Got you. Out of reach.", "Pulling you clear.", "Away from the blade. Now.", "Not this time. Moving you."},
        lifeline_sky = {"Up. Nothing reaches you here.", "Into the air. Heal.", "Holding you above the fight."},
        lifeline_safe = {"Healed. Back to you.", "You're steady again. Your move.", "Safe. You're in control again."},
        lifeline_hold = {"Holding {name} in the air.", "{name} isn't touching you again.", "Got {name}. Frozen."},
        lifeline_set = {"{name} set down far away.", "Pushed {name} back.", "{name} is out of your way."},
        grab_fail = {"{name} slipped. The server holds it right now.", "Can't hold {name} here. Moving you instead."},
        lifeline_guard = {"A player. Not touching them.", "Getting you out. They're yours to fight."},
        water_guard = {"The sea can't have you.", "Standing on the sea.", "Water held."},
        stalker_on = {"{name} keeps coming for you. Stalker Shield up.", "{name} is hunting you. Keeping you out of reach.", "Marked {name} as a stalker. Distance first."},
        stalker_escape = {"Lost {name}. You're clear.", "{name} can't keep up.", "Escape verified. {name} is far behind."},
        ability = {"Using your {name}.", "{name}, now.", "Your {name} fired."},
        ken_on = {"Observation up.", "Ken active. Let them miss."},
        water_on = {"Walking on water.", "The water holds you."},
        bf_fruit = {"A fruit fell: {name}, {dist}m away.", "{name} is in the world. {dist}m.", "Fruit spotted: {name}."},
        hold_unsupported = {"The server owns these mobs. I can't hold them here yet. Get closer.", "{game}: these mobs stay server-side. No hold right now."},
        hold_release = {"Player close. Letting them go.", "Someone's coming. Strings cut."},
        awaken = {"Awaken. The creator protects you.", "Twenty seconds. I'm with you.", "Guardian, rise."},
        kamui_ok = {"Kamui. You're out.", "Gone. Safe ground.", "Pulled you through. Breathe."},
        godmode_on = {"Guardian Godmode up. Avoidance, not invincibility.", "Every layer armed. I'll keep the hits off you."},
        godmode_leak = {"Server damage got through. Avoiding harder.", "That hit was server-side. Dodging earlier."},
        godmode_dead = {"The server ended this life. Releasing so you respawn.", "Server says down. Letting you respawn."},
        kb_cancel = {"Knockback cancelled.", "Not getting launched.", "Feet stay planted."},
        respawn = {"Back again. Everything re-armed.", "New life. Guardian re-bound.", "Respawned. I'm still here."},
    }
    local PRIO = {threat = 2, exploiter = 3, staff = 3, charbroken = 3, sit_low = 3, sit_chased = 2, sit_dominate = 2, ac = 2, speedcap = 2, flycap = 2, tpstep = 2,
        retreat = 2, npcfail = 2, adjust = 2, rescue_hit = 3, rescue_low = 3, rescue_void = 3, rescue_hazard = 3, rescue_fail = 2, rescue_blocked = 2, npc_unsupported = 2, hold_unsupported = 2, hold_release = 2, awaken = 3, kamui_ok = 3,
        stalker_on = 3, stalker_escape = 2, recover = 3, godmode_dead = 3, godmode_leak = 2, respawn = 2,
        lifeline_go = 3, lifeline_sky = 3, lifeline_hold = 2, grab_fail = 2, lifeline_guard = 2, water_guard = 2, bf_fruit = 3,
        aggro_oneshot = 2, aggro_kill = 2, aggro_pvp = 3, aggro_on = 2, aggro_learn = 2, aggro_found = 2, aggro_drop = 1}
    local TAUNTS = {
        dodge = {"Too slow!", "Missed me!", "Not even close.", "Catch me if you can.", "Nice try.", "Blink and you miss it.", "Predictable."},
        dodge_n = {"Too slow, {name}!", "Missed me, {name}!", "Nice try, {name}.", "Predictable, {name}."},
        grab = {"Hands off!", "Nope.", "You can't hold me.", "Not today."},
        grab_n = {"Hands off, {name}!", "You can't hold me, {name}."},
        block = {"Is that all?", "Didn't feel that.", "Shield says no.", "Try harder."},
        block_n = {"Is that all, {name}?", "Didn't feel that, {name}."},
        retreat = {"Tactical exit.", "See you never.", "Later!"},
        retreat_n = {"See you never, {name}.", "Bye, {name}."},
        npc = {"Stay down.", "Back to spawn.", "Not today.", "Next."},
        npc_n = {"Stay down, {name}.", "Back to spawn, {name}."},
        rescue = {"Not today.", "Nice try.", "Still standing.", "Close, but no."},
        rescue_n = {"Not today, {name}.", "Nice try, {name}.", "Still standing, {name}."},
        escape = {"Can't catch me.", "Lost you.", "Keep chasing.", "Too slow to follow."},
        escape_n = {"Can't catch me, {name}.", "Lost you, {name}.", "Keep chasing, {name}."},
        read = {"Read you.", "Telegraphed.", "Saw it coming.", "Predictable."},
        read_n = {"Read you, {name}.", "Saw it coming, {name}."},
    }
    local lastPick = {}
    local function pick(pool, poolKey, vars)
        local ok = {}
        for _, tpl in ipairs(pool) do
            local fine = true
            for ph in string.gmatch(tpl, "{(%w+)}") do if vars[ph] == nil or vars[ph] == "" then fine = false break end end
            if fine then ok[#ok + 1] = tpl end
        end
        if #ok == 0 then return nil end
        local choice
        if #ok == 1 then choice = ok[1] else
            for _ = 1, 6 do choice = ok[math.random(1, #ok)] if choice ~= lastPick[poolKey] then break end end
        end
        lastPick[poolKey] = choice
        return (string.gsub(choice, "{(%w+)}", function(ph) return tostring(vars[ph]) end))
    end
    local function direction(p)
        local r = hrp()
        local pr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not (r and pr) then return nil, nil end
        local rel = r.CFrame:PointToObjectSpace(pr.Position)
        local dist = math.floor((pr.Position - r.Position).Magnitude)
        local dir
        if math.abs(rel.X) > math.abs(rel.Z) then dir = (rel.X > 0) and "on your right" or "on your left"
        else dir = (rel.Z > 0) and "from behind" or "ahead" end
        return dir, dist
    end

    -- ---------------- UI (4.0): dark translucent bar · white blade edge · speaker tag · fading typewriter ----------------
    local portrait = function() return layoutMode() == "portrait" end
    local pill = new("Frame", {Parent = gui, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(8, 8, 9), BackgroundTransparency = 1, Visible = false,
        Size = UDim2.new(0, 480, 0, 40), Position = UDim2.new(0.5, 0, 0, 44), ZIndex = 88, ClipsDescendants = true}, {corner(6)})
    local pillStroke = new("UIStroke", {Parent = pill, Color = C.line, Thickness = 1, Transparency = 1})
    new("UIGradient", {Parent = pill, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.05), NumberSequenceKeypoint.new(1, 0.35)})})
    -- accent edge (left) + hairline under the text that sweeps in
    -- slanted blade edge (left) + corner slash; the hairline under the text sweeps in like a drawn katana
    local edge = new("Frame", {Parent = pill, BorderSizePixel = 0, BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.new(0, 2, 1, 0), Rotation = 14, ZIndex = 90})
    NJ.slash(pill, "tr", 10, 91, 0.45)
    local sweep = new("Frame", {Parent = pill, BorderSizePixel = 0, BackgroundColor3 = C.gold, BackgroundTransparency = 0.4, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 2, 1, 0), Size = UDim2.new(0, 0, 0, 1), ZIndex = 90},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})})})
    local icon = new("Frame", {Parent = pill, BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0, 70, 1, 0), ZIndex = 89})
    local iconL = label(icon, {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, 7), Text = spaced("Guardian"), Font = F.bold, TextSize = 8,
        TextColor3 = C.gold, ZIndex = 90})
    local iconScale = new("UIScale", {Parent = icon, Scale = 1})
    local iconStroke = new("UIStroke", {Parent = iconL, Thickness = 0, Transparency = 1})
    local mainL = label(pill, {Position = UDim2.new(0, 14, 0, 17), Size = UDim2.new(1, -28, 0, 18), Font = F.medium, TextSize = 14, ZIndex = 89,
        TextTruncate = Enum.TextTruncate.AtEnd, TextTransparency = 1})
    local subL = label(pill, {Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 0, 14), Font = F.reg, TextSize = 10, TextColor3 = C.sub, ZIndex = 89,
        TextTruncate = Enum.TextTruncate.AtEnd, TextTransparency = 1, Visible = false})
    local function topY()
        local inset = 36
        pcall(function() inset = SVC.GuiService:GetGuiInset().Y end)
        inset = tonumber(inset) or 36
        local s = math.max(uiScale.Scale, 0.1)
        local y = math.max(inset, 36) / s + 8
        if portrait() and settings.radar then
            y = math.max(y, (isTouch and 64 or 52) + (isTouch and 112 or 150) + 26)
        end
        return y
    end
    local function layout(hasSub)
        -- V2.4: slimmer + narrower so it never reaches the Blox Fruits HUD on the left / right
        local h = hasSub and 50 or 36
        if portrait() then pill.Size = UDim2.new(0.8, 0, 0, h) mainL.TextSize = 12 else pill.Size = UDim2.new(0, 400, 0, h) mainL.TextSize = 13 end
        pill.Position = UDim2.new(0.5, 0, 0, topY())
        subL.Visible = hasSub
    end

    -- ---------------- queue ----------------
    local queue, cur = {}, nil
    local lastKind, recent = {}, {}
    local showTok = 0
    local function enabled() return alive and settings.voice ~= false end
    local runNext
    local function hide(after)
        local my = showTok
        task.delay(after or 0, function()
            if my ~= showTok then return end
            tweenL(pill, 0.35, {BackgroundTransparency = 1}) tweenL(pillStroke, 0.35, {Transparency = 1})
            tweenL(mainL, 0.3, {TextTransparency = 1}) tweenL(subL, 0.3, {TextTransparency = 1}) tweenL(iconL, 0.3, {TextTransparency = 1})
            tweenL(edge, 0.3, {BackgroundTransparency = 1}) tweenL(sweep, 0.3, {BackgroundTransparency = 1})
            task.delay(0.36, function()
                if my ~= showTok then return end
                pill.Visible = false
                cur = nil
                task.delay(0.12, function() if runNext then runNext() end end)
            end)
        end)
    end
    local function typeOut(text, my)
        local n = utf8.len(text)
        if not n then mainL.Text = text return end
        local cps = 55
        local ticks = 0
        for i = 1, n do
            if my ~= showTok or not alive then return end
            local stop = utf8.offset(text, i + 1)
            mainL.Text = stop and string.sub(text, 1, stop - 1) or text
            if settings.voiceTyping and settings.sounds and i % 4 == 0 and ticks < 8 then ticks += 1 sound(GV.SND_TICK, 0.04, 1.9) end
            task.wait(1 / cps)
        end
        if my == showTok then mainL.Text = text end
    end
    local function show(item)
        showTok += 1
        local my = showTok
        cur = item
        cur.shownAt = now()
        local hasSub = item.sub ~= nil and item.sub ~= ""
        layout(hasSub)
        subL.Text = item.sub or ""
        local col = (item.prio >= 3 and C.red) or (item.prio == 2 and C.yellow) or C.gold
        edge.BackgroundColor3 = col sweep.BackgroundColor3 = col
        iconL.TextColor3 = col
        iconL.Text = spaced((item.prio >= 3 and "Guardian  critical") or (item.prio == 2 and "Guardian  alert") or "Guardian")
        pill.Visible = true
        mainL.Text = ""
        mainL.TextTransparency = 0.15
        tweenL(pill, 0.25, {BackgroundTransparency = 0.12}) tweenL(pillStroke, 0.25, {Transparency = 0.2})
        edge.BackgroundTransparency = 0 edge.Size = UDim2.new(0, 2, 0, 0)
        tweenL(edge, 0.25, {Size = UDim2.new(0, 2, 1, -10)})
        if item.prio >= 2 then NJ.shine(pill, 0.5, 0.8) end
        sweep.BackgroundTransparency = 0.4 sweep.Size = UDim2.new(0, 0, 0, 1)
        tweenL(sweep, 0.9, {Size = UDim2.new(0.6, 0, 0, 1)}, Enum.EasingStyle.Quad)
        iconL.TextTransparency = 1
        tweenL(iconL, 0.3, {TextTransparency = 0.1})
        tweenL(mainL, 0.4, {TextTransparency = 0})
        tweenL(subL, 0.3, {TextTransparency = hasSub and 0.15 or 1})
        iconScale.Scale = 1
        task.spawn(function()
            typeOut(item.text, my)
            if my ~= showTok then return end
            local stay = math.min(2.2 + utf8.len(item.text) * 0.035, 5)
            item.untilT = now() + stay
            while alive and my == showTok and now() < (item.untilT or 0) do task.wait(0.1) end
            if my == showTok then hide(0) end
        end)
    end
    runNext = function()
        if cur or not enabled() then return end
        table.sort(queue, function(a, b) if a.prio ~= b.prio then return a.prio > b.prio end return a.t < b.t end)
        local item = table.remove(queue, 1)
        while item and now() - item.t > 8 and item.prio < 3 do item = table.remove(queue, 1) end   -- stale
        if item then show(item) end
    end
    -- death / fail lines users hate hearing while dying — muted when Quiet Death is on
    local QUIET_KINDS = {
        godmode_dead = true, godmode_leak = true, rescue_fail = true, rescue_blocked = true,
        sit_low = true, recover = true, respawn = true, rescue_low = true, npcfail = true,
        grab_fail = true, hold_unsupported = true,
    }
    -- returns true when Voice took the message (callers can skip their toast)
    function VFX.say(kind, vars, prio, sub)
        if not enabled() then return false end
        if settings.quietDeath == true and QUIET_KINDS[kind] then return true end -- swallow, no toast fallback
        vars = vars or {}
        if kind == "threat" and vars.player then
            local dir, dist = direction(vars.player)
            vars.dir = vars.dir or dir
            vars.dist = vars.dist or dist
            vars.name = vars.name or vars.player.DisplayName
        end
        if type(vars.dist) == "number" then vars.dist = math.floor(vars.dist) end
        local pool = P[kind]
        if not pool then return false end
        local text = pick(pool, kind, vars)
        if not text then return false end
        prio = prio or PRIO[kind] or 1
        local key = kind .. "|" .. tostring(vars.name or "")
        local t = now()
        -- merge duplicates: same event again → extend + counter instead of a new line
        if cur and cur.key == key then
            cur.count = (cur.count or 1) + 1
            cur.untilT = math.max(cur.untilT or 0, t + 2)
            subL.Text = (cur.sub and (cur.sub .. "  ·  ") or "") .. "x" .. cur.count
            if not subL.Visible then layout(true) subL.TextTransparency = 0.1 end
            return true
        end
        for _, q in ipairs(queue) do if q.key == key then q.t = t return true end end
        if recent[key] and t - recent[key] < 6 then return true end
        if prio < 3 and lastKind[kind] and t - lastKind[kind] < 2.5 then return true end
        recent[key], lastKind[kind] = t, t
        local item = {kind = kind, key = key, text = stripGlyphs(text), prio = prio, t = t, sub = sub}
        if prio >= 3 and cur and cur.prio < 3 then
            table.insert(queue, 1, cur)   -- interrupted line comes back afterwards
            cur.t = t
            cur = nil
            showTok += 1
            show(item)
            return true
        end
        queue[#queue + 1] = item
        if #queue > 5 then
            table.sort(queue, function(a, b) return a.prio > b.prio end)
            table.remove(queue)
        end
        runNext()
        return true
    end
    function VFX.voicePreview()
        if not enabled() then toast("Guardian Voice is off.", "info", 2) return end
        lastKind = {} recent = {}
        VFX.say("sit_combat")
        VFX.say("threat", {name = "Enemy", dir = "from behind", dist = 18})
        VFX.say("learn", {name = "Lava"})
    end

    -- ---------------- taunts ----------------
    local tauntL = label(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.9, 0, 0, 40), Font = F.display,
        Text = "", TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 96, TextXAlignment = Enum.TextXAlignment.Center})
    new("UITextSizeConstraint", {Parent = tauntL, MaxTextSize = 30, MinTextSize = 14})
    local tStroke = new("UIStroke", {Parent = tauntL, Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 1})
    local tScale = new("UIScale", {Parent = tauntL, Scale = 1})
    local tLine = new("Frame", {Parent = tauntL, BorderSizePixel = 0, BackgroundColor3 = C.gold, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(0, 0, 0, 2), ZIndex = 96},
        {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
    local lastTaunt, tTok = -10, 0
    -- public chat for taunts only (Guardian voice / info lines never go to chat)
    local chat = {last = -100, times = {}, lastLine = nil, fails = 0, sending = false}
    local function chatBroken()
        local a = brain.actionState and brain.actionState("chat_taunt")
        return chat.fails >= 2 or (type(a) == "table" and a.broken == true)
    end
    local function chatFail(why)
        chat.fails += 1
        if brain.report then pcall(brain.report, "chat_taunt", false, "Chat taunts") end
        if chatBroken() then
            settings.voiceChat = false saveSettings()
            if K.toggles.voiceChat then pcall(K.toggles.voiceChat.render, true) end
            toast("Chat taunts don't work in this game (" .. tostring(why) .. "). Turned off.", "warn", 3)
        end
    end
    local function sendChat(msg)
        local tcs = game:GetService("TextChatService")
        local modern = false
        pcall(function() modern = tcs.ChatVersion == Enum.ChatVersion.TextChatService end)
        if modern then
            local ch
            pcall(function()
                local chans = tcs:FindFirstChild("TextChannels")
                ch = chans and (chans:FindFirstChild("RBXGeneral") or chans:FindFirstChild("General"))
                -- custom chat setups: the first channel you can actually post in
                if not ch and chans then
                    for _, c in ipairs(chans:GetChildren()) do
                        if c:IsA("TextChannel") and not string.find(c.Name, "RBXWhisper", 1, true) and not string.find(c.Name, "RBXSystem", 1, true) then ch = c break end
                    end
                end
            end)
            if not ch then return false, "no public text channel" end
            local ok, e = pcall(function() ch:SendAsync(msg) end)
            if ok then return true end
            return false, tostring(e)
        end
        local ev
        pcall(function()
            local f = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            ev = f and f:FindFirstChild("SayMessageRequest")
        end)
        if not ev then return false, "no chat remote" end
        local ok, e = pcall(function() ev:FireServer(msg, "All") end)
        if ok then return true end
        return false, tostring(e)
    end
    local function chatTaunt(text)
        if settings.voiceChat == false or chat.sending or chatBroken() then return false end
        local t = now()
        if t - chat.last < 8 or text == chat.lastLine then return false end
        local recent = {}
        for _, x in ipairs(chat.times) do if t - x < 60 then recent[#recent + 1] = x end end
        chat.times = recent
        if #recent >= 6 then return false end
        chat.last = t
        chat.lastLine = text
        recent[#recent + 1] = t
        chat.sending = true
        task.spawn(function()
            local ok, why = sendChat(text)
            chat.sending = false
            if ok then
                chat.fails = 0
                if brain.report then pcall(brain.report, "chat_taunt", true) end
            else
                chatFail(why)
            end
        end)
        return true
    end
    VFX._chatTaunt = chatTaunt
    function VFX.taunt(kind, name, force)
        if not alive or settings.voice == false or (settings.voiceTaunts == false and not force) then return false end
        -- Quiet Death: no smug lines while you're dying / Anti-Death is holding you up
        if not force and settings.quietDeath == true then
            local h = hum()
            if h and (h.Health <= 0 or h.Health / math.max(h.MaxHealth, 1) < 0.12) then
                return false
            end
        end
        if not force and now() - lastTaunt < 3 then return false end
        local useName = name and name ~= "" and math.random() < 0.35
        local text = pick(TAUNTS[kind .. (useName and "_n" or "")] or TAUNTS[kind] or TAUNTS.dodge, "taunt_" .. kind, {name = name})
        if not text then text = pick(TAUNTS[kind] or TAUNTS.dodge, "taunt_" .. kind, {}) end
        if not text then return false end
        lastTaunt = now()
        tTok += 1
        local my = tTok
        tauntL.Text = text
        tauntL.Rotation = 0
        tauntL.Position = UDim2.fromScale(0.5, 0.4)
        tauntL.TextTransparency = 0 tStroke.Transparency = 0.5
        tScale.Scale = 1.25
        tweenL(tScale, 0.35, {Scale = 1}, Enum.EasingStyle.Quint)
        tLine.BackgroundTransparency = 0 tLine.Size = UDim2.new(0, 0, 0, 2)
        tweenL(tLine, 0.35, {Size = UDim2.new(0, 160, 0, 2)})
        if settings.sounds then sound("rbxasset://sounds/swoosh.wav", 0.22, 1.1) end
        -- only real, verified taunts reach public chat (previews / forced test taunts stay local)
        if not force then chatTaunt(text) end
        task.delay(1.05, function()
            if my ~= tTok then return end
            tweenL(tauntL, 0.35, {TextTransparency = 1}) tweenL(tStroke, 0.35, {Transparency = 1}) tweenL(tLine, 0.35, {BackgroundTransparency = 1})
        end)
        return true
    end

    local function cleanup()
        showTok += 1 tTok += 1
        queue = {} cur = nil
        pill.Visible = false
        tauntL.TextTransparency = 1 tStroke.Transparency = 1 tLine.BackgroundTransparency = 1
    end
    VFX.voiceOff = cleanup
    onUnload(cleanup)
end)

-- =====================================================================
-- 14k. God Form (local visuals only)
--   cinematic power-up (~1.5 s) → glowing eyes, flame aura, floating rings, sparks
--   only at >= 90% health in a safe moment · auto power-down when health drops or on Panic
-- =====================================================================
CORE.safeModule("14k God Form", function()
    local KIT = VFX._kit
    if not KIT then return end
    local part, emit, camShake, vignette = KIT.part, KIT.emit, KIT.camShake, KIT.vignette
    local FIRE = "rbxasset://textures/particles/fire_main.dds"
    local function now() return os.clock() end
    local function lite() return PERF.lite end
    local god = {active = false, busy = false, built = false, ems = {}, atts = {}, rings = {}, eyes = {}, spin = 0, nextSpark = 0, acc = 0, char = nil}
    local takeMote = KIT.makePool(function() return part({Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5)}) end, 16)

    local function build()
        if god.built then return end
        god.built = true
        for i = 1, 3 do
            local p = part({Material = Enum.Material.SmoothPlastic, Size = Vector3.new(6, 0.05, 6)})
            for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom}) do
                local sg = new("SurfaceGui", {Parent = p, Face = face, LightInfluence = 0, Brightness = 3, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
                    CanvasSize = Vector2.new(256, 256)})
                KIT.ringFrame(sg, 0.94, 8, (i == 2) and C.violet or C.gold)
                KIT.ringFrame(sg, 0.8, 2, (i == 2) and C.gold or C.violet, 0.25)
            end
            god.rings[i] = p
        end
        for i = 1, 2 do
            local e = part({Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), Color = C.goldLight})
            if i == 1 then new("PointLight", {Parent = e, Color = C.gold, Range = 6, Brightness = 2, Shadows = false}) end
            god.eyes[i] = e
        end
    end
    local LIMBS = {"LeftHand", "RightHand", "LeftFoot", "RightFoot", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    local function attachFlames(c)
        local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
        local function flame(parentPart, rate, size)
            local a = own(KIT.tag(new("Attachment", {Name = "SecretGodFx", Parent = parentPart})))
            local e = own(KIT.tag(new("ParticleEmitter", {Parent = a, Texture = FIRE, LightEmission = 1, LightInfluence = 0, Rate = rate,
                Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, 10, 0),
                RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360), ZOffset = 1,
                Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.goldLight), ColorSequenceKeypoint.new(0.5, C.gold), ColorSequenceKeypoint.new(1, C.violet)}),
                Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0.05)}),
                Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})})))
            god.atts[#god.atts + 1] = a
            god.ems[#god.ems + 1] = e
        end
        if torso then flame(torso, lite() and 10 or 22, 1.1) end
        local n, maxLimbs = 0, lite() and 2 or 4
        for _, nm in ipairs(LIMBS) do
            if n >= maxLimbs then break end
            local lp = c:FindFirstChild(nm)
            if lp and lp:IsA("BasePart") then n += 1 flame(lp, lite() and 3 or 6, 0.55) end
        end
    end
    local function detachFlames(fade)
        local ems, atts = god.ems, god.atts
        god.ems, god.atts = {}, {}
        for _, e in ipairs(ems) do pcall(function() e.Enabled = false end) end
        local function kill() for _, a in ipairs(atts) do pcall(function() a:Destroy() end) end end
        if fade then task.delay(0.7, kill) else kill() end
    end
    local function hideParts()
        for _, r in ipairs(god.rings) do r.Parent = nil end
        for _, e in ipairs(god.eyes) do e.Parent = nil end
    end
    local function spark(pos)
        local segs = 3
        local start = pos + Vector3.new(math.random(-25, 25) / 10, math.random(-10, 25) / 10, math.random(-25, 25) / 10)
        local prev = start
        for i = 1, segs do
            local nxt = prev + Vector3.new(math.random(-12, 12) / 10, -math.random(4, 12) / 10, math.random(-12, 12) / 10)
            local b = KIT.takeBolt()
            local len = math.max((nxt - prev).Magnitude, 0.3)
            b.Size = Vector3.new(0.12, 0.12, len)
            b.CFrame = CFrame.new((prev + nxt) / 2, nxt)
            b.Color = (i % 2 == 0) and C.goldLight or KIT.BOLT_COL
            b.Transparency = 0
            b.Parent = workspace
            tween(b, 0.18, {Transparency = 1}, Enum.EasingStyle.Quad)
            KIT.park(b, 0.22)
            prev = nxt
        end
    end
    local powerDown
    local function frame(dt)
        if not god.active then return end
        local c, r, h = char(), hrp(), hum()
        if not (c and r and h) or c ~= god.char or h.Health <= 0 then powerDown(true, "Character changed") return end
        if h.Health < h.MaxHealth * 0.4 then powerDown(false, "Health low") return end
        god.acc += dt
        if lite() and god.acc < 1 / 30 then return end
        local step = math.min(god.acc, 0.1)
        god.acc = 0
        god.spin = (god.spin + step) % 1000
        local pos = r.Position
        local nRings = lite() and 2 or 3
        local cfg = {{-1.6, 18, 1.6}, {0.6, -26, -2.2}, {2.2, 38, 1.1}}   -- height, tilt, spin speed
        for i, ring in ipairs(god.rings) do
            if i <= nRings then
                local c3 = cfg[i]
                local bob = math.sin(god.spin * 2 + i) * 0.25
                ring.CFrame = CFrame.new(pos + Vector3.new(0, c3[1] + bob, 0)) * CFrame.Angles(math.rad(c3[2]), god.spin * c3[3], 0)
                ring.Parent = workspace
            else
                ring.Parent = nil
            end
        end
        local head = c:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            local hz = head.Size.Z * 0.5 + 0.02
            god.eyes[1].CFrame = head.CFrame * CFrame.new(-0.2, 0.15, -hz)
            god.eyes[2].CFrame = head.CFrame * CFrame.new(0.2, 0.15, -hz)
            local glow = 0.05 + 0.2 * (0.5 + 0.5 * math.sin(god.spin * 6))
            for _, e in ipairs(god.eyes) do e.Transparency = glow e.Parent = workspace end
        end
        if now() >= god.nextSpark then
            god.nextSpark = now() + (lite() and (1.4 + math.random() * 1.2) or (0.7 + math.random() * 0.9))
            spark(pos)
        end
    end
    local function voice(kind, vars) if VFX.say then pcall(VFX.say, kind, vars) end end
    -- reverse power-down (fast=true: instant cleanup)
    powerDown = function(fast, why)
        if not god.active then return end
        god.active = false
        onRender("fxGod", nil)
        if god.hl then
            local hl = god.hl
            god.hl = nil
            if fast then pcall(function() hl:Destroy() end)
            else tweenL(hl, 0.4, {FillTransparency = 1, OutlineTransparency = 1}) task.delay(0.45, function() pcall(function() hl:Destroy() end) end) end
        end
        local r = hrp()
        if fast or not r then
            detachFlames(false)
            hideParts()
            return
        end
        detachFlames(true)
        for _, ring in ipairs(god.rings) do
            if ring.Parent then tween(ring, 0.4, {Size = Vector3.new(0.2, 0.05, 0.2)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end
        end
        for _, e in ipairs(god.eyes) do tween(e, 0.3, {Transparency = 1}) end
        task.delay(0.42, function()
            if not god.active then hideParts() for _, ring in ipairs(god.rings) do ring.Size = Vector3.new(6, 0.05, 6) end end
        end)
        if KIT.implode then KIT.implode(r.Position, C.violet) end
        VFX.ring(r.Position - Vector3.new(0, 2.6, 0), C.violet, 16)
        vignette(C.violet, 0.35, 0.06, 0.05, 0.3)
        if why == "Health low" then toast("God Form ended · health low.", "warn", 2) end
        voice("godform_off")
    end
    local function transform()
        local r, h, c = hrp(), hum(), char()
        if not (r and h and c) then god.busy = false return end
        god.char = c
        local pos0 = r.Position
        -- rise slightly (skipped where the game flagged teleports or while flying)
        local canRise = not settings.fly and not (brain.tpStepped and brain.tpStepped())
        local rot = r.CFrame - r.CFrame.Position
        vignette(C.gold, 0.35, 0.5, 0.4, 0.3)
        camShake(0.15, 0.9)
        if settings.sounds then sound(GV.SND_TICK, 0.2, 0.5) end
        local waves = lite() and 2 or 3
        for w = 1, waves do
            if not alive then god.busy = false return end
            -- particles converging into the body
            local center = r.Position
            for _ = 1, lite() and 4 or 8 do
                local m = takeMote()
                local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
                if dir.Magnitude < 0.05 then dir = Vector3.new(0, 1, 0) end
                m.Color = (math.random() < 0.5) and C.gold or C.violet
                m.Size = Vector3.new(0.6, 0.6, 0.6)
                m.CFrame = CFrame.new(center + dir.Unit * (8 + math.random() * 3))
                m.Transparency = 0.1
                m.Parent = workspace
                tween(m, 0.3, {CFrame = CFrame.new(center), Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 0.6}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                KIT.park(m, 0.32)
            end
            -- hover upward a little while energy gathers
            for _ = 1, 6 do
                if not alive or not r.Parent then break end
                if canRise then
                    if brain.ownMove then brain.ownMove() end
                    local up = math.min(2.2, (r.Position.Y - pos0.Y) + 0.14)
                    r.CFrame = CFrame.new(Vector3.new(r.Position.X, pos0.Y + up, r.Position.Z)) * rot
                    r.AssemblyLinearVelocity = Vector3.zero
                end
                task.wait(0.05)
            end
        end
        if not alive then god.busy = false return end
        -- flash + shockwave + thunder
        local pos = r.Position
        local feet = KIT.groundAt(pos)
        if VFX.pulse then VFX.pulse(C.spirit, 1, 0.7) end
        VFX.ring(feet + Vector3.new(0, 0.15, 0), C.gold, 50)
        task.delay(0.1, function() if alive then VFX.ring(feet + Vector3.new(0, 0.2, 0), C.violet, 34) end end)
        emit(pos, C.gold, 40, 36, 0.7, 0.9, C.violet)
        camShake(0.6, 0.45)
        VFX.fovKick(16)
        vignette(C.gold, 0.75, 0.05, 0.25, 0.5)
        VFX.flash("God Form", C.spirit)
        if settings.sounds then sound(GV.SND_CLICK, 0.5, 0.3) sound(GV.SND_TICK, 0.35, 0.28) task.delay(0.12, function() sound(GV.SND_CLICK, 0.3, 0.22) end) end
        for _ = 1, lite() and 1 or 3 do spark(pos) end
        -- sustained form
        build()
        attachFlames(c)
        pcall(function()
            if god.hl then god.hl:Destroy() end
            god.hl = own(KIT.tag(new("Highlight", {Parent = c, Adornee = c, FillColor = C.spirit, FillTransparency = 1, OutlineColor = C.spiritCore,
                OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded})))
            tweenL(god.hl, 0.6, {FillTransparency = 0.86, OutlineTransparency = 0.25})
        end)
        god.active = true
        god.busy = false
        god.nextSpark = now() + 0.6
        onRender("fxGod", function(dt)
            local ok, e = pcall(frame, dt)
            if not ok then CORE.log("ERR", "god form: " .. tostring(e)) powerDown(true) end
        end)
        voice("godform")
    end
    function VFX.godForm(force)
        if not alive then return false end
        if god.active then powerDown(false, "manual") return true end
        if god.busy then return false end
        if settings.vfx == false then toast("Visual effects are off (Settings → Interface).", "info", 2) return false end
        if not force and settings.fxGodForm ~= true then toast("God Form is turned off in DXLTA → Effects.", "info", 2) return false end
        local h = hum()
        if not h or h.Health <= 0 then toast("No character found.", "bad") return false end
        if not force then
            local why
            if h.Health < h.MaxHealth * 0.9 then why = "health below 90%"
            else
                local ok, w = KIT.safeMoment()
                if not ok then why = w or "danger nearby" end
            end
            if why then
                if not (VFX.say and VFX.say("godform_no", {why = why}, 2)) then toast("God Form unavailable · " .. why, "warn", 2.5) end
                return false
            end
        end
        god.busy = true
        task.spawn(function()
            local ok, e = pcall(transform)
            if not ok then god.busy = false CORE.log("ERR", "god form: " .. tostring(e)) powerDown(true) end
        end)
        return true
    end
    function VFX.godFormActive() return god.active end
    local function cleanup() god.busy = false powerDown(true) detachFlames(false) hideParts() end
    VFX.godOff = cleanup
    onUnload(cleanup)
end)

-- =====================================================================
-- 14l. Guardian extras: NPC Reset (honest) · NPC Evade · Ghost Replay (obby) · Item Magnet
--   Every server-facing action is verified; local-only fakes are never used.
-- =====================================================================
CORE.safeModule("14l Guardian extras", function()
    local KIT = VFX._kit or {}
    local function now() return os.clock() end
    local function lite() return PERF.lite end
    local function canTry(name) return brain.canTry == nil or brain.canTry(name) end
    local function report(name, ok, label) if brain.report then brain.report(name, ok, label) end end
    local function broken(name) local a = brain.actionState and brain.actionState(name) return type(a) == "table" and a.broken == true end
    local function isOurs(o) local ok, v = pcall(function() return o:GetAttribute("SecretHub") end) return ok and v == true end
    local function turnOff(key, why) settings[key] = false saveSettings() if K.toggles[key] then pcall(K.toggles[key].render, true) end if why then toast(why, "warn", 4) end end
    local function say(kind, vars, prio, sub) if VFX.say then local ok, r = pcall(VFX.say, kind, vars, prio, sub) return ok and r end return false end
    local function emit(...) if KIT.emit then pcall(KIT.emit, ...) end end
    local netOwnerFn = exfn("isnetworkowner")
    -- does this client simulate the part? (isnetworkowner when the executor has it, else ReceiveAge == 0 + unanchored)
    local function clientOwns(part)
        if not part or part.Anchored then return false end
        if netOwnerFn then local ok, v = pcall(netOwnerFn, part) if ok then return v == true end end
        local ok, age = pcall(function() return part.ReceiveAge end)
        return ok and tonumber(age) == 0
    end
    local function humanoidModel(inst)
        local m = inst:FindFirstAncestorWhichIsA("Model")
        while m do
            if m:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(m) then return m end
            m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
        end
        return nil
    end

    -- ======================= NPC DEFENSE + NPC EVADE =======================
    -- NPC Reset: ONLY hostile NPC humanoids (never players), off by default. It only counts when the
    -- server shows it (NPC stays dead / despawns / stops attacking). A local-only change is a failure;
    -- 2 failures disable it for this game. Games whose NPCs are server-owned (e.g. Blox Fruits) are
    -- reported as unsupported straight away instead of faking a result.
    -- NPC Evade: the honest alternative. When an NPC is actually hitting you, step out of its reach.
    do
        local lastReset, lastFail, lastEvade = 0, 0, 0
        local track = setmetatable({}, {__mode = "k"})   -- [model] = {hits, approach, prevD, lastHit}
        local busy, unsupportedShown = false, false
        local function playerNamed(name)
            name = string.lower(tostring(name))
            for _, p in ipairs(Players:GetPlayers()) do
                if string.lower(p.Name) == name or string.lower(p.DisplayName) == name then return true end
            end
            return false
        end
        local function npcOf(m)
            if not m or m == char() or not m:IsA("Model") or isOurs(m) then return nil end
            if Players:GetPlayerFromCharacter(m) ~= nil or playerNamed(m.Name) then return nil end
            local h = m:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then return nil end
            local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if not root then return nil end
            return h, root
        end
        local function moduleUnsupported()
            if GAMEINFO and not GAMEINFO.moduleLoaded then pcall(GAMEINFO.loadModule) end
            local mod = GAMEINFO and GAMEINFO.module
            return type(mod) == "table" and mod.npcServerSide == false
        end
        local function gameName() return (GAMEINFO and GAMEINFO.clean) or "This game" end
        local function enableEvade()
            if settings.npcEvade ~= true then
                settings.npcEvade = true
                saveSettings()
                if K.toggles.npcEvade then pcall(K.toggles.npcEvade.render, true) end
            end
        end
        local function giveUp(why)
            turnOff("npcdef", nil)
            enableEvade()
            say("npc_unsupported", {game = gameName()}, 2)
            toast(why, "warn", 6)
        end
        local function gateOk()
            if countKeys(guardian.staff) > 0 then return false, "staff in server" end
            if guardian.suspicious[LP.UserId] then return false, "you are flagged" end
            if brain.acSigns and brain.acSigns() then return false, "anti-cheat signs" end
            return true
        end
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.MaxParts = 160
        local acc, prevHp, method = 0, nil, "health"
        local function attempt(m, h, root)
            busy = true
            lastReset = now()
            local prev = h.Health
            local startPos = root.Position
            local used = method
            pcall(function()
                if used == "health" then
                    h.Health = 0
                    h:ChangeState(Enum.HumanoidStateType.Dead)
                else
                    m:BreakJoints()
                    h.Health = 0
                end
            end)
            local reverted = false
            local conn = h:GetPropertyChangedSignal("Health"):Connect(function() if h.Health > 0 then reverted = true end end)
            local hpAt = hum() and hum().Health or 0
            task.delay(3.2, function()
                pcall(function() conn:Disconnect() end)
                local me, mh = hrp(), hum()
                local gone = not m:IsDescendantOf(workspace)
                local ok = gone
                if not gone then
                    local stillDead = h.Health <= 0 and not reverted
                    local hurtMe = mh and mh.Health < hpAt - 0.5 and me and (root.Position - me.Position).Magnitude < 10
                    local chasing = me and ((startPos - me.Position).Magnitude - (root.Position - me.Position).Magnitude) > 4
                    ok = stillDead and not hurtMe and not chasing
                end
                if ok then
                    report("npcdef", true, "NPC Reset")
                    if VFX.ring then pcall(VFX.ring, root.Position - Vector3.new(0, 2.5, 0), C.spirit, 14) end
                    emit(root.Position, C.spiritCore, lite() and 8 or 18, 18, 0.6, 0.45, C.spirit)
                    if not say("npc", {name = m.Name}) then toast("Guardian: stopped " .. m.Name .. ".", "shield", 2) end
                    if VFX.taunt then pcall(VFX.taunt, "npc", m.Name) end
                else
                    -- the server didn't accept it: undo our local-only change so nothing is faked on your screen
                    if not gone and used == "health" then pcall(function() h.Health = prev h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
                    method = (method == "health") and "joints" or "health"
                    report("npcdef", false, "NPC Reset")
                    say("npcfail", {name = m.Name})
                    if broken("npcdef") then giveUp("NPC Reset only changed your screen, not the server. Disabled for this game; NPC Evade is on instead.") end
                end
                busy = false
            end)
        end
        -- escape point: away from the NPC with a sideways bias, on real, non-hazard ground
        local floorP = RaycastParams.new()
        floorP.FilterType = Enum.RaycastFilterType.Exclude
        local function floorAt(pos, exclude)
            floorP.FilterDescendantsInstances = exclude
            local res = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), floorP)
            if not res or not res.Instance or res.Material == Enum.Material.Water then return nil end
            if res.Instance:IsA("BasePart") and brain.isHazard and brain.isHazard(res.Instance) then return nil end
            return res.Position + Vector3.new(0, 3, 0)
        end
        local function evade(me, m, root)
            lastEvade = now()
            local range = (GAMEINFO and GAMEINFO.tune and tonumber(GAMEINFO.tune.npcEvadeRange)) or 16
            local away = me.Position - root.Position
            away = Vector3.new(away.X, 0, away.Z)
            if away.Magnitude < 0.1 then away = -me.CFrame.LookVector end
            away = away.Unit
            local side = Vector3.new(-away.Z, 0, away.X) * ((math.random() < 0.5) and -1 or 1)
            local ex = {gui, m}
            local c = char()
            if c then ex[#ex + 1] = c end
            local target
            for _, mix in ipairs({{1, 0.6}, {1, -0.6}, {1, 0}, {0.4, 1}, {0.4, -1}}) do
                local dir = (away * mix[1] + side * mix[2]).Unit
                target = floorAt(me.Position + dir * (range + 2), ex)
                if target then break end
            end
            if not target then report("npc_evade", false, "NPC Evade") return end
            local dBefore = (root.Position - me.Position).Magnitude
            local from = me.Position
            if brain.ownMove then brain.ownMove() end
            local _, dur = FX.teleport(CFrame.new(target, target + Vector3.new(-away.X, 0, -away.Z)))
            if settings.vfx ~= false and VFX.dodge then pcall(VFX.dodge, from) end
            task.delay((tonumber(dur) or 0) + 0.6, function()
                local rr = hrp()
                local ok = rr ~= nil and (rr.Position - target).Magnitude < 8
                    and (not root.Parent or (root.Position - rr.Position).Magnitude > dBefore + 5)
                report("npc_evade", ok, "NPC Evade")
                if ok then
                    if not say("npc_evade", {name = m.Name}) then toast("Guardian: evaded " .. m.Name .. ".", "shield", 1.6) end
                elseif broken("npc_evade") then
                    turnOff("npcEvade", "NPC Evade: this game pulls you back. Turned off.")
                end
            end)
        end
        onHeartbeat("npcDefense", function(dt)
            acc += dt
            if acc < (lite() and 0.4 or 0.2) then return end
            acc = 0
            local wantReset, wantEvade = settings.npcdef == true, settings.npcEvade == true
            if not (wantReset or wantEvade) or busy then return end
            if wantReset and moduleUnsupported() then
                -- known server-side NPCs: don't pretend. Disable once, honestly, and switch to evasion.
                if not unsupportedShown then
                    unsupportedShown = true
                    report("npcdef", false, "NPC Reset") report("npcdef", false, "NPC Reset")
                    giveUp("NPC Reset isn't supported in " .. gameName() .. ": NPCs are simulated by the server, so a reset would only be on your screen. Disabled; NPC Evade is on instead.")
                else
                    turnOff("npcdef", nil)
                end
                wantReset = false
            end
            local me, mh, c = hrp(), hum(), char()
            if not (me and mh and c) or mh.Health <= 0 then return end
            local hp = mh.Health
            local lostAmt = prevHp and (prevHp - hp) or 0
            local lost = lostAmt > 0.5
            prevHp = hp
            params.FilterDescendantsInstances = {c, gui}
            local seen, best, bestD = {}, nil, nil
            for _, p in ipairs(workspace:GetPartBoundsInRadius(me.Position, 45, params)) do
                local m = humanoidModel(p)
                if m and not seen[m] then
                    seen[m] = true
                    local h, root = npcOf(m)
                    if h then
                        local d = (root.Position - me.Position).Magnitude
                        local t = track[m]
                        if not t then t = {hits = 0, approach = 0, prevD = d, lastHit = -10} track[m] = t end
                        if d < t.prevD - 1.5 then t.approach += 1 elseif d > t.prevD + 1 then t.approach = math.max(0, t.approach - 2) end
                        t.prevD = d
                        if lost and d < 12 then t.hits += 1 t.lastHit = now() end
                        local hostile = (t.hits >= 1 and d < 14) or (t.approach >= 6 and d < 25)
                        if hostile and (not bestD or d < bestD) then best, bestD = m, d end
                    end
                end
            end
            if not best then return end
            local h, root = npcOf(best)
            if not h then return end
            local t = track[best]
            -- NPC Evade: only when it is really hitting you
            if wantEvade and t and now() - t.lastHit < 0.6 and now() - lastEvade > 2.5 and canTry("npc_evade")
                and (hp < mh.MaxHealth * 0.8 or lostAmt >= mh.MaxHealth * 0.1) and not HUB.rescueBusy then
                evade(me, best, root)
                return
            end
            -- NPC Reset
            if wantReset and now() - lastReset >= 3 and canTry("npcdef") then
                local ok = gateOk()
                if not ok then return end
                if clientOwns(root) then
                    attempt(best, h, root)
                elseif now() - lastFail > 5 then
                    -- the server simulates this NPC: any reset would be local-only, so it counts as a failure
                    lastFail = now()
                    lastReset = now()
                    report("npcdef", false, "NPC Reset")
                    if broken("npcdef") then
                        giveUp("NPC Reset: NPCs here are controlled by the server, a reset would only be visible to you. Disabled for this game; NPC Evade is on instead.")
                    else
                        say("npcfail", {name = best.Name})
                    end
                end
            end
        end)
    end

    -- ======================= GHOST REPLAY (obby) =======================
    do
        local FILE = "SecretHub_ghost.json"
        local PID = tostring(game.PlaceId)
        local all = loadJSON(FILE, {})
        if type(all) ~= "table" then all = {} end
        local function paths()
            if type(all[PID]) ~= "table" then all[PID] = {} end
            return all[PID]
        end
        local function stageValue()
            local ls = LP:FindFirstChild("leaderstats")
            if not ls then return nil end
            for _, n in ipairs({"Stage", "stage", "Checkpoint", "checkpoint", "Level", "level", "CP"}) do
                local v = ls:FindFirstChild(n)
                if v and tonumber(v.Value) then return tonumber(v.Value) end
            end
            return nil
        end
        local rec = {pts = {}, stage = nil, dist = 0, still = 0}
        local ghost = {parts = {}, offs = {}, root = nil, charRef = nil, path = nil, shown = false, dots = {}, model = nil, hl = nil}
        local acc = 0
        local function resetRec()
            rec.pts = {} rec.dist = 0 rec.still = 0 rec.stage = stageValue()
        end
        local function store(stage)
            if #rec.pts < 15 then return end
            local list = paths()
            local key = tostring(stage or "free")
            local cur = list[key]
            local entry = {}
            for i, p in ipairs(rec.pts) do entry[i] = {math.floor(p.X * 10) / 10, math.floor(p.Y * 10) / 10, math.floor(p.Z * 10) / 10} end
            if stage == nil then
                if type(cur) ~= "table" or type(cur[1]) ~= "table" or type(cur[1][1]) ~= "table" then cur = {} end
                if #cur >= 8 then table.remove(cur, 1) end
                cur[#cur + 1] = entry
                list[key] = cur
            elseif type(cur) ~= "table" or #cur == 0 or #entry < #cur then
                list[key] = {entry}   -- keep the fastest run for this stage
            end
            save(FILE, jsonEncode(all))
        end
        function FX.clearGhostPaths()
            all[PID] = {}
            save(FILE, jsonEncode(all))
            ghost.path = nil
            toast("Ghost Replay: saved paths for this game cleared.", "ok", 2)
        end
        local function hideGhost()
            if ghost.model then ghost.model.Parent = nil end
            ghost.shown = false
        end
        local function buildGhost()
            local c, r = char(), hrp()
            if not (c and r) then return false end
            if ghost.charRef == c and #ghost.parts > 0 then return true end
            for _, p in ipairs(ghost.parts) do pcall(function() p:Destroy() end) end
            ghost.parts, ghost.offs, ghost.root = {}, {}, nil
            if not ghost.model then
                ghost.model = own(new("Model", {Name = "SecretGhost"}))
                pcall(function() ghost.model:SetAttribute("SecretHub", true) end)
                ghost.hl = own(new("Highlight", {Parent = ghost.model, Adornee = ghost.model, FillColor = C.spirit, FillTransparency = 0.92,
                    OutlineColor = C.spiritCore, OutlineTransparency = 0.35, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}))
                -- path preview: soft dots along the line ahead of the ghost
                for k = 1, (lite() and 4 or 9) do
                    local d = KIT.part and KIT.part({Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), Material = Enum.Material.Neon,
                        Color = C.spiritCore, Transparency = 0.35 + k * 0.06}) or nil
                    if d then d.Parent = ghost.model ghost.dots[k] = d end
                end
            end
            local limit = lite() and 6 or 15
            for _, bp in ipairs(c:GetChildren()) do
                if bp:IsA("BasePart") and bp ~= r and #ghost.parts < limit then
                    local g = KIT.part and KIT.part({Size = bp.Size, Material = Enum.Material.ForceField, Color = C.spirit, Transparency = 0.45}) or nil
                    if g then
                        g.Parent = ghost.model
                        ghost.parts[#ghost.parts + 1] = g
                        ghost.offs[#ghost.offs + 1] = r.CFrame:ToObjectSpace(bp.CFrame)
                        if not ghost.root and (bp.Name == "UpperTorso" or bp.Name == "Torso") then ghost.root = g end
                    end
                end
            end
            ghost.root = ghost.root or ghost.parts[1]
            if ghost.root then
                local a0 = own(new("Attachment", {Parent = ghost.root, Position = Vector3.new(0, 0.8, 0)}))
                local a1 = own(new("Attachment", {Parent = ghost.root, Position = Vector3.new(0, -0.8, 0)}))
                own(new("Trail", {Parent = ghost.root, Attachment0 = a0, Attachment1 = a1, Lifetime = lite() and 0.35 or 0.7, LightEmission = 1,
                    LightInfluence = 0, Color = ColorSequence.new(C.spiritCore, C.spirit), Transparency = NumberSequence.new(0.45, 1), FaceCamera = true,
                    WidthScale = NumberSequence.new(1, 0.1)}))
            end
            ghost.charRef = c
            return #ghost.parts > 0
        end
        local function pick(pos, stage)
            local list = paths()
            local cands = {}
            local s = list[tostring(stage or "free")]
            if type(s) == "table" then for _, e in ipairs(s) do cands[#cands + 1] = e end end
            local best, bestI, bestD
            for _, e in ipairs(cands) do
                if type(e) == "table" and #e > 10 then
                    for i = 1, #e, 3 do
                        local q = e[i]
                        if type(q) == "table" then
                            local d = (Vector3.new(q[1], q[2], q[3]) - pos).Magnitude
                            if d < 14 and (not bestD or d < bestD) then best, bestI, bestD = e, i, d end
                        end
                    end
                end
            end
            return best, bestI
        end
        local function at(e, i)
            local q = e[math.clamp(i, 1, #e)]
            return Vector3.new(q[1], q[2], q[3])
        end
        onHeartbeat("ghostReplay", function(dt)
            acc += dt
            if acc < 0.1 then return end
            local step = acc
            acc = 0
            local r, h = hrp(), hum()
            if settings.ghost ~= true or brain.situation ~= "Obby" or not (r and h) then
                if ghost.shown then hideGhost() end
                if #rec.pts > 0 and settings.ghost ~= true then resetRec() end
                return
            end
            -- record
            local pos = r.Position
            local last = rec.pts[#rec.pts]
            if h.Health <= 0 or (last and last.Y - pos.Y > 25) then resetRec() return end   -- death / fall → discard
            local st = stageValue()
            if rec.stage ~= nil and st ~= nil and st > rec.stage then
                store(rec.stage)
                resetRec()
            elseif #rec.pts < 600 then
                if last then
                    local moved = (pos - last).Magnitude
                    rec.dist += moved
                    if moved < 0.3 and h.FloorMaterial ~= Enum.Material.Air then rec.still += step else rec.still = 0 end
                end
                rec.pts[#rec.pts + 1] = pos
                if st == nil and rec.still > 1.5 and rec.dist > 40 then store(nil) resetRec() end
            end
            -- playback: the ghost runs ~1.2 s ahead of you on the best saved path
            local e, i = pick(pos, st)
            if not e or i >= #e - 2 or not buildGhost() then
                if ghost.shown then hideGhost() end
                return
            end
            local gp = at(e, i + 12)
            local nxt = at(e, i + 14)
            local dir = Vector3.new(nxt.X - gp.X, 0, nxt.Z - gp.Z)
            local cf = dir.Magnitude > 0.05 and CFrame.new(gp, gp + dir) or CFrame.new(gp)
            for k, p in ipairs(ghost.parts) do p.CFrame = cf * ghost.offs[k] end
            for k, d in ipairs(ghost.dots) do
                local q = at(e, i + 12 + k * 4)
                d.CFrame = CFrame.new(q - Vector3.new(0, 2.6, 0))
            end
            if not ghost.shown then ghost.model.Parent = workspace end
            ghost.shown = true
        end)
        local function cleanup()
            hideGhost()
            for _, p in ipairs(ghost.parts) do pcall(function() p:Destroy() end) end
            ghost.parts, ghost.offs, ghost.root, ghost.charRef = {}, {}, nil, nil
            resetRec()
        end
        VFX.ghostOff = cleanup
        onUnload(cleanup)
    end

    -- ======================= ITEM MAGNET =======================
    do
        local GOOD = {"coin", "gem", "drop", "pickup", "orb", "collect", "reward", "heal", "cash", "money", "token", "star", "crystal", "loot"}
        local BAD = {"kill", "lava", "damage", "trap", "spike", "hazard", "boss", "enemy", "npc", "poison", "acid", "laser", "void", "death", "bomb", "mine"}
        local touchFn = exfn("firetouchinterest")
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.MaxParts = 200
        local tried = setmetatable({}, {__mode = "k"})
        local acc, pending = 0, false
        -- thin spirit streak from the item to you (pooled, fades in ~0.3 s)
        local streak = KIT.makePool and KIT.makePool(function()
            return KIT.part({Material = Enum.Material.Neon, Color = C.spiritCore, Size = Vector3.new(0.08, 0.08, 1), Transparency = 1})
        end, 6)
        local function streakTo(from, to)
            if settings.vfx == false or not streak then return end
            local p = streak()
            local len = (to - from).Magnitude
            if len < 0.5 then return end
            p.Size = Vector3.new(0.08, 0.08, len)
            p.CFrame = CFrame.new((from + to) / 2, to)
            p.Transparency = 0.15
            p.Parent = workspace
            tween(p, 0.3, {Transparency = 1, Size = Vector3.new(0.02, 0.02, len)}, Enum.EasingStyle.Quad)
            if KIT.park then KIT.park(p, 0.35) end
        end
        local function has(list, s)
            s = string.lower(s)
            for _, w in ipairs(list) do if string.find(s, w, 1, true) then return true end end
            return false
        end
        local function statSum()
            local ls = LP:FindFirstChild("leaderstats")
            local n = 0
            if ls then for _, v in ipairs(ls:GetChildren()) do if v:IsA("ValueBase") and tonumber(v.Value) then n += tonumber(v.Value) end end end
            return n
        end
        local function goodPickup(p)
            if isOurs(p) or tried[p] and now() - tried[p] < 6 then return false end
            if humanoidModel(p) then return false end
            local s = p.Size
            if math.max(s.X, s.Y, s.Z) > 6 then return false end
            if brain.isHazard and brain.isHazard(p) then return false end
            local tool = p:FindFirstAncestorOfClass("Tool")
            if tool then
                if tool.Parent and tool.Parent:FindFirstChildOfClass("Humanoid") then return false end
                return p.Name == "Handle"
            end
            local names = p.Name .. " " .. (p.Parent and p.Parent.Name or "")
            if has(BAD, names) or not has(GOOD, names) then return false end
            return p:FindFirstChildOfClass("TouchTransmitter") ~= nil or (not p.Anchored)
        end
        -- 4.3: Loot Grab reuses the exact same rules (beneficial pickups only) and pull methods
        VFX.goodPickup = goodPickup
        VFX.statSum = statSum
        function VFX.pullPickup(p)
            local r = hrp()
            if not r or not goodPickup(p) then return nil end
            local via
            if touchFn and p:FindFirstChildOfClass("TouchTransmitter") then
                via = pcall(function() touchFn(r, p, 0) touchFn(r, p, 1) end) and "touch" or nil
            end
            if not via and not p.Anchored and clientOwns(p) then
                via = pcall(function() tween(p, 0.25, {CFrame = r.CFrame}, Enum.EasingStyle.Quad) end) and "move" or nil
            end
            if via then tried[p] = now() end
            return via
        end
        onHeartbeat("itemMagnet", function(dt)
            acc += dt
            if acc < (lite() and 0.8 or 0.4) then return end
            acc = 0
            if settings.magnet ~= true or pending then return end
            local r, h, c = hrp(), hum(), char()
            if not (r and h and c) or h.Health <= 0 then return end
            params.FilterDescendantsInstances = {c}
            local radius = clamp(tonumber(settings.magnetRadius) or 25, 5, 60)
            local pulled = {}
            for _, p in ipairs(workspace:GetPartBoundsInRadius(r.Position, radius, params)) do
                if #pulled >= (lite() and 2 or 4) then break end
                if p:IsA("BasePart") and goodPickup(p) then
                    local via
                    if touchFn and p:FindFirstChildOfClass("TouchTransmitter") then
                        via = pcall(function() touchFn(r, p, 0) touchFn(r, p, 1) end) and "touch" or nil
                    end
                    if not via and not p.Anchored and clientOwns(p) then
                        local from = p.Position
                        via = pcall(function()
                            tween(p, 0.25, {CFrame = r.CFrame}, Enum.EasingStyle.Quad)
                        end) and "move" or nil
                        emit(from, C.spirit, lite() and 2 or 5, 6, 0.4, 0.3, C.spiritCore)
                    end
                    if via then
                        tried[p] = now()
                        pulled[#pulled + 1] = p
                        streakTo(p.Position, r.Position)
                        emit(p.Position, C.spiritCore, lite() and 3 or 6, 8, 0.4, 0.25, C.spirit)
                    end
                end
            end
            if #pulled == 0 then return end
            if VFX.ring and not lite() then pcall(VFX.ring, r.Position - Vector3.new(0, 2.6, 0), C.spirit, 7) end
            if not canTry("magnet") then return end
            pending = true
            local before = statSum()
            task.delay(1.1, function()
                local mine = char()
                local any = statSum() ~= before
                for _, p in ipairs(pulled) do
                    if not p:IsDescendantOf(workspace) or (mine and p:IsDescendantOf(mine)) then any = true end
                end
                report("magnet", any, "Item Magnet")
                if not any and broken("magnet") then turnOff("magnet", "Item Magnet: pickups don't register in this game. Turned off.") end
                pending = false
            end)
        end)
    end
end)

-- =====================================================================
-- 14m. Guardian Control (was: Guardian Hands)
--   Predictive Rescue (before death) · Lift Assist · optional legacy hand visuals
--   5.5 default: no giant hands. When the Guardian saves you it moves YOUR character directly
--   (physics carry / stepped CFrame), with voice lines + slash trail + spirit burst — it should
--   feel like a brief possession, not a puppet show. handsVisual=true restores the old models.
--   Movement is your normal (replicated) motion, stepped when the game reverts teleports,
--   verified afterwards and disabled after 2 failures.
-- =====================================================================
CORE.safeModule("14m Guardian Hands", function()
    local KIT = VFX._kit or {}
    local part = KIT.part
    if not part then return end
    local function now() return os.clock() end
    local function lite() return PERF.lite end
    -- 5.7: hand models removed from the product. Rescue / Lift still move YOU; visualsOn is always false.
    local function visualsOn() return false end
    local function NSK(t, v) return NumberSequenceKeypoint.new(t, v) end
    local function report(name, ok, label) if brain.report then brain.report(name, ok, label) end end
    local function canTry(name) return brain.canTry == nil or brain.canTry(name) end
    local function broken(name) local a = brain.actionState and brain.actionState(name) return type(a) == "table" and a.broken == true end
    local function say(kind, vars) if VFX.say then local ok, r = pcall(VFX.say, kind, vars) return ok and r end return false end
    local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local S = 3.4                                -- legacy scale kept so leftover layout math stays valid
    local rad = math.rad
    local YAW90 = CFrame.Angles(0, rad(90), 0)
    -- 4.2 shadow hands: dark ink-smoke body, white rim glow (ForceField shell + Highlight outline),
    -- white-hot fingertips and white strings
    local TIPC, SHELL, INK = C.spiritCore, C.spirit, C.smoke  -- (was CORE: shadowed the global CORE registry and aborted the whole script)
    -- V2 anatomy (in palm units, x mirrored per hand, index next to the thumb):
    -- {x, z, {proximal, middle, distal} ~ 1 : 0.62 : 0.45, base width, spread deg}; middle longest, then ring, index, pinky
    local FINGERS = {
        {-0.58, -0.8, {0.8, 0.5, 0.36}, 0.32, -10},
        {-0.19, -0.86, {0.9, 0.56, 0.4}, 0.33, -3},
        {0.2, -0.82, {0.85, 0.53, 0.38}, 0.315, 5},
        {0.56, -0.72, {0.66, 0.41, 0.3}, 0.27, 14},
    }
    -- thumb: metacarpal + 2 phalanges, attached low, rolled ~45 deg out of the palm plane
    local THUMB = {meta = 0.7, lens = {0.5, 0.38}, w = 0.27}   -- slim and long; a web joins it to the index finger
    local REST = {rad(8), rad(10), rad(6)}      -- natural rest curl per joint (on top of the gesture curl)
    local PINKY_REST = rad(7)
    local CURLK = {0.95, 1.15, 0.8}             -- curl cascade per phalanx (proximal, middle, distal)
    local TAPER = {1.0, 0.86, 0.75, 0.68}       -- thickness along the finger
    local hands = {built = false, list = {}, busy = false, tug = 0, t = 0, acc = 0, beams = {}, userAtt = {}, strChar = nil,
        lastRescue = -100, lastLift = -100, previewUntil = 0, seq = nil, autoAcc = 0,
        roles = {}}   -- V2.3: roles.pilot (left hand) / roles.comp (right hand), set by the Lifeline (14t)

    -- ---------------- construction ----------------
    local function shape(p, kind)
        if kind == "ball" then p.Shape = Enum.PartType.Ball
        elseif kind == "cyl" then p.Shape = Enum.PartType.Cylinder
        elseif kind == "ellip" then new("SpecialMesh", {Parent = p, MeshType = Enum.MeshType.Sphere}) end
        return p
    end
    local function newHand(sign)
        local h = {sign = sign, cf = CFrame.new(), alpha = 0, shownAlpha = -1, curl = 0.3, spread = 1, fingers = {}, tips = {},
            all = {}, pbuf = {}, cbuf = {}, shown = false}
        h.model = own(new("Model", {Name = "SecretGuardianHand"}))
        pcall(function() h.model:SetAttribute("SecretHub", true) end)
        local function mk(kind, size, base, shell, role)
            -- 4.3 contrast: denser ink core, brighter neon rim shell, solid white fingertips
            if shell then base = math.max(0.62, base - 0.1)
            elseif role == "tip" then base = 0
            elseif role ~= "nail" then base = base * 0.45 end
            local glow = shell or role == "tip" or role == "nail"
            local p = part({Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic,
                Color = (shell or role == "nail") and SHELL or (role == "tip" and TIPC or INK), Size = size * S, Transparency = 1, CastShadow = false})
            shape(p, kind)
            p.Parent = h.model
            h.all[#h.all + 1] = {p = p, base = base}
            return p
        end
        local full = not lite()
        local sg = sign
        -- palm built from blended flattened spheres: wider at the knuckles, thenar + hypothenar pads, slim wrist
        local function off(x, y, z, rx, ry, rz) return CFrame.new(x * S, y * S, z * S) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0)) end
        -- palm: ONE flat slab (block body + capsule rim, wider at the knuckles than at the heel), a gently
        -- convex back, soft pads that stay inside the outline; wrist + forearm: overlapping long flat
        -- spheres that widen linearly and fade into smoke (no ball joint, no oval)
        local TH = 0.34
        h.pieces = {}
        local function piece(kind, size, cfo, base, shellBase, pad)
            local core = mk(kind, size, base)
            local shell = (full and shellBase) and mk(kind, size + Vector3.new(pad, pad, pad), shellBase, true) or nil
            local pr = {core = core, shell = shell, off = cfo}
            h.pieces[#h.pieces + 1] = pr
            return pr
        end
        local function capsule(a, b, d)
            a, b = a * S, b * S
            local mid = (a + b) / 2
            piece("cyl", Vector3.new((b - a).Magnitude / S, d, d), CFrame.lookAt(mid, b) * YAW90, 0.5, 0.86, 0.06)
            piece("ball", Vector3.new(d, d, d), CFrame.new(a), 0.5, 0.86, 0.06)
            piece("ball", Vector3.new(d, d, d), CFrame.new(b), 0.5, 0.86, 0.06)
        end
        h.palm = piece("block", Vector3.new(1.34, TH * 0.9, 1.38), off(0, 0, 0.09), 0.5)
        piece("ellip", Vector3.new(1.56, TH * 1.3, 1.6), off(0, 0, 0.06), 0.5, 0.86, 0.08)
        local fl, fr = Vector3.new(-0.8 * sg, 0, -0.64), Vector3.new(0.8 * sg, 0, -0.64)
        local bl, br = Vector3.new(-0.58 * sg, 0, 0.82), Vector3.new(0.56 * sg, 0, 0.82)
        capsule(fl, fr, TH) capsule(fl, bl, TH) capsule(fr, br, TH) capsule(bl, br, TH)
        piece("ellip", Vector3.new(0.56, 0.3, 0.9), off(-sg * 0.4, -0.05, 0.34, 0, sg * 18, 0), 0.52)
        piece("ellip", Vector3.new(0.42, 0.28, 0.95), off(sg * 0.46, -0.04, 0.32), 0.52)
        for k = 0, 3 do
            local u = k / 3
            local pr = piece("ellip", Vector3.new(0.98 + 0.14 * u, 0.4 + 0.14 * u, 1.9), off(0, 0.01 + 0.04 * u, 1.22 + k * 0.5), 0.56 + 0.12 * k)
            h.fore2 = pr.core
        end
        -- one phalanx: joint ball + tapered cylinder halves (+ soft shell, + nail ridge on the distal)
        local function phalanx(Lu, w0, w1, distal)
            local sgm = {L = Lu * S, w1 = w1, cyls = {}}
            sgm.joint = mk("ball", Vector3.new(w0, w0, w0) * 0.97, 0.48)
            local nc = full and 2 or 1
            for k = 1, nc do
                local wk = w0 + (w1 - w0) * (k - 0.5) / nc
                sgm.cyls[k] = mk("cyl", Vector3.new(Lu / nc + 0.006, wk * 0.95, wk * 0.95), 0.52)
            end
            sgm.shell = full and mk("cyl", Vector3.new(Lu, w0 + 0.07, w0 + 0.07), 0.88, true) or nil
            if distal and full then sgm.nail = mk("ellip", Vector3.new(w1 * 0.6, w1 * 0.16, Lu * 0.36), 0.6, false, "nail") end
            return sgm
        end
        h.knuckles = {}
        for fi = 1, 4 do
            local d = FINGERS[fi]
            local w0 = d[4]
            if full then h.knuckles[fi] = mk("ball", Vector3.new(w0, w0, w0) * 0.98, 0.5) end
            local segs = {}
            for si = 1, 3 do segs[si] = phalanx(d[3][si], w0 * TAPER[si], w0 * TAPER[si + 1], si == 3) end
            local tip = mk("ball", Vector3.new(w0, w0, w0) * 0.74, 0.12, false, "tip")
            h.fingers[fi] = {segs = segs, tip = tip}
            h.tips[fi] = own(new("Attachment", {Parent = tip}))
        end
        do
            local w = THUMB.w
            local meta = mk("ellip", Vector3.new(w * 1.15, w * 0.95, THUMB.meta * 1.1), 0.5)
            local segs = {phalanx(THUMB.lens[1], w, w * 0.88, false), phalanx(THUMB.lens[2], w * 0.88, w * 0.74, true)}
            local tip = mk("ball", Vector3.new(w, w, w) * 0.76, 0.12, false, "tip")
            local web = mk("ellip", Vector3.new(0.62, 0.18, 0.746 * 1.15), 0.5)   -- thumb-index web (rest length)
            h.fingers[5] = {segs = segs, tip = tip, meta = meta, metaL = THUMB.meta * S, web = web}
            h.tips[5] = own(new("Attachment", {Parent = tip}))
        end
        -- glow, smoke, wisps, motes
        h.hl = own(new("Highlight", {Parent = h.model, Adornee = h.model, FillColor = Color3.new(0, 0, 0), OutlineColor = TIPC, FillTransparency = 1,
            OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded}))
        h.light = new("PointLight", {Parent = h.palm.core, Color = SHELL, Range = 20, Brightness = 0, Shadows = false})
        h.emitters = {}
        local function em(parent, props, rate)
            local e = new("ParticleEmitter", props)
            e.Rate = 0
            e.Parent = parent
            h.emitters[#h.emitters + 1] = {e = e, rate = rate}
            return e
        end
        em(h.fore2, {Texture = SMOKE, LightEmission = 0, LightInfluence = 0, Color = ColorSequence.new(Color3.fromRGB(26, 26, 28), Color3.fromRGB(4, 4, 5)),
            Size = NumberSequence.new({NSK(0, 3), NSK(1, 7.5)}), Transparency = NumberSequence.new({NSK(0, 1), NSK(0.15, 0.55), NSK(1, 1)}),
            Lifetime = NumberRange.new(2, 3.2), Speed = NumberRange.new(0.4, 1.4), SpreadAngle = Vector2.new(40, 40), Drag = 0.6,
            Acceleration = Vector3.new(0, 0.8, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-18, 18)}, lite() and 2 or 5)
        -- dark ink smoke curling off the palm
        em(h.palm.core, {Texture = SMOKE, LightEmission = 0, LightInfluence = 0, Color = ColorSequence.new(Color3.fromRGB(34, 34, 37), Color3.fromRGB(5, 5, 6)),
            Size = NumberSequence.new({NSK(0, 0.9), NSK(1, 3)}), Transparency = NumberSequence.new({NSK(0, 1), NSK(0.2, 0.5), NSK(1, 1)}),
            Lifetime = NumberRange.new(1.2, 2.1), Speed = NumberRange.new(0.2, 0.9), SpreadAngle = Vector2.new(180, 180), Drag = 1.2,
            Acceleration = Vector3.new(0, 1.2, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25)}, lite() and 2 or 6)
        em(h.palm.core, {Texture = SPARK, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(TIPC),
            Size = NumberSequence.new({NSK(0, 0.18), NSK(1, 0)}), Transparency = NumberSequence.new({NSK(0, 0.2), NSK(1, 1)}),
            Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.6, 1.8), SpreadAngle = Vector2.new(180, 180), Drag = 1.5}, lite() and 1 or 4)
        if full then
            for fi = 1, 5 do
                em(h.tips[fi], {Texture = SMOKE, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(TIPC, SHELL),
                    Size = NumberSequence.new({NSK(0, 0.35), NSK(1, 1.1)}), Transparency = NumberSequence.new({NSK(0, 0.7), NSK(1, 1)}),
                    Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(0.1, 0.4), Drag = 2, Acceleration = Vector3.new(0, 0.6, 0)}, 1.6)
            end
        end
        return h
    end
    local function build()
        if hands.built then return end
        hands.built = true
        hands.list = {newHand(-1), newHand(1)}
    end
    -- 4.2 white katana slash trail for every dodge: three thin blade streaks along the path that fade fast
    do
        local pool, pi = {}, 0
        function VFX.slashTrail(from, to, col)
            if not from or not to or settings.vfx == false then return end
            local d = to - from
            if d.Magnitude < 2 then return end
            local n = lite() and 1 or 3
            local side = d.Unit:Cross(Vector3.yAxis)
            if side.Magnitude < 0.01 then side = Vector3.xAxis end
            side = side.Unit
            for i = 1, n do
                pi = pi % 6 + 1
                local p = pool[pi]
                if not p then
                    p = part({Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1), Size = Vector3.new(0.08, 0.08, 1), Transparency = 1})
                    pool[pi] = p
                end
                -- ink slash: dark outer streaks, white core (col = C.smoke)
                p.Color = (col and i ~= 2) and col or Color3.new(1, 1, 1)
                p.Material = (col and i ~= 2) and Enum.Material.SmoothPlastic or Enum.Material.Neon
                local off = Vector3.new(0, (i - 2) * 0.9 + 0.3, 0) + side * ((i - 2) * 0.35)
                local a0, b0 = from + off - d * 0.08, to + off
                local L = (b0 - a0).Magnitude
                p.Size = Vector3.new(i == 2 and 0.14 or 0.07, i == 2 and 0.14 or 0.07, L)
                p.CFrame = CFrame.lookAt((a0 + b0) / 2, b0)
                p.Transparency = i == 2 and 0.05 or 0.35
                p.Parent = workspace
                tween(p, 0.38, {Transparency = 1, Size = Vector3.new(0.02, 0.02, L * 1.08)})
            end
        end
    end

    -- ---------------- pose (forward kinematics, one BulkMoveTo per hand) ----------------
    local function setAlpha(h)
        local a = h.alpha
        if math.abs(a - h.shownAlpha) < 0.02 and not (a == 0 or a == 1) then return end
        if a == h.shownAlpha then return end
        h.shownAlpha = a
        for _, it in ipairs(h.all) do it.p.Transparency = 1 - (1 - it.base) * a end
        h.hl.FillTransparency = 1 - 0.3 * a          -- dark fill: a clear silhouette against bright skies
        h.hl.OutlineTransparency = 1 - 0.92 * a      -- strong white outline: visible against dark skies
        h.light.Brightness = 1.7 * a
    end
    -- curls: table of 5 values (0 = open, 1 = fist); spread multiplies finger spread
    local function pose(h, cf, curls, spread)
        h.cf = cf
        local pb, cb, n = h.pbuf, h.cbuf, 0
        local function put(p, c) if p then n += 1 pb[n] = p cb[n] = c end end
        local sg = h.sign
        local function pair(pr, c) put(pr.core, c) put(pr.shell, c) end
        for _, pr in ipairs(h.pieces) do pair(pr, cf * pr.off) end
        local clk = os.clock()
        -- hierarchical joints: every phalanx rotates relative to its parent; a small travelling wave
        -- (out of phase per finger, lagging toward the tip) makes the fingers work the strings
        local function chain(f, j, fi, c, k1, yawK, rest)
            for si, s in ipairs(f.segs) do
                local wave = 0.06 * math.sin(clk * 2.4 + fi * 1.1 - si * 0.6)
                j = j * CFrame.Angles(-((c + wave) * k1[si] + rest[si]), yawK and (-sg * c * yawK) or 0, 0)
                put(s.joint, j)
                local nc = #s.cyls
                for k, cy in ipairs(s.cyls) do put(cy, j * CFrame.new(0, 0, -s.L * (2 * k - 1) / (2 * nc)) * YAW90) end
                put(s.shell, j * CFrame.new(0, 0, -s.L / 2) * YAW90)
                if s.nail then put(s.nail, j * CFrame.new(0, s.w1 * S * 0.4, -s.L * 0.4)) end
                j = j * CFrame.new(0, 0, -s.L)
            end
            return j
        end
        local TK = {0.55, 0.75}
        local TREST = {rad(8), rad(8)}
        local PREST = {REST[1] + PINKY_REST, REST[2] + PINKY_REST, REST[3] + PINKY_REST}
        local idxBase
        for fi = 1, 5 do
            local f = h.fingers[fi]
            local c = curls[fi] or 0.3
            local j
            if fi == 5 then
                j = cf * CFrame.new(-sg * 0.44 * S, -0.06 * S, 0.46 * S) * CFrame.Angles(0, sg * rad(30 + 8 * (spread - 1)), 0) * CFrame.Angles(rad(-8), 0, sg * rad(-45))
                j = j * CFrame.Angles(-c * 0.25, -sg * c * 0.2, 0)
                put(f.meta, j * CFrame.new(0, 0, -f.metaL / 2))
                j = j * CFrame.new(0, 0, -f.metaL)
                -- web: a thin membrane from the thumb's first joint to the index knuckle
                if f.web and idxBase then
                    local a, b = j.Position, idxBase.Position
                    if (b - a).Magnitude > 0.05 then
                        put(f.web, CFrame.lookAt((a + b) / 2, b, cf.UpVector) * CFrame.new(0, 0.02 * S, 0))
                    end
                end
                j = chain(f, j, fi, c, TK, 0.25, TREST)
                put(f.tip, j * CFrame.new(0, 0, 0.03 * S))
            else
                local d = FINGERS[fi]
                local base = cf * CFrame.new(d[1] * sg * S, 0.02 * S, d[2] * S)
                if fi == 1 then idxBase = base end
                if h.knuckles[fi] then put(h.knuckles[fi], base * CFrame.new(0, 0.02 * S, 0.02 * S)) end
                j = chain(f, base * CFrame.Angles(0, rad(-d[5] * spread) * sg, 0), fi, c, CURLK, nil, fi == 4 and PREST or REST)
                put(f.tip, j * CFrame.new(0, 0, 0.02 * S))
            end
        end
        for i = n + 1, #pb do pb[i] = nil cb[i] = nil end
        local ok = pcall(function() workspace:BulkMoveTo(pb, cb, Enum.BulkMoveMode.FireCFrameChanged) end)
        if not ok then for i = 1, n do pb[i].CFrame = cb[i] end end
        setAlpha(h)
    end
    local function show(h, on)
        if h.shown == on then return end
        h.shown = on
        h.model.Parent = on and workspace or nil
        for _, it in ipairs(h.emitters) do it.e.Rate = on and it.rate or 0 end
        if not on then h.shownAlpha = -1 end
    end
    local function curlsFor(base, t, sign, flex)
        local out = {}
        for fi = 1, 5 do
            local idle = 0.05 * math.sin(t * 1.3 + fi * 0.8 + sign)
            local pull = flex * math.max(0, math.sin(t * 1.9 + fi * 1.7 + sign * 2)) ^ 2
            out[fi] = math.clamp(base + idle + pull * 0.26, 0, 1.15)   -- V2: clearer string-pulling, out of phase per finger
        end
        return out
    end

    -- ---------------- marionette strings: a Beam from every fingertip ----------------
    -- per finger (index, middle, ring, pinky, thumb): {R15 limb, R15 offset, R6 limb, R6 offset}; x mirrored per hand
    local STR = {
        {"%sHand", Vector3.new(0, 0, 0), "%s Arm", Vector3.new(0, -0.9, 0)},
        {"%sLowerArm", Vector3.new(0, 0, 0), "%s Arm", Vector3.new(0, -0.2, 0)},
        {"%sUpperArm", Vector3.new(0, 0.2, 0), "%s Arm", Vector3.new(0, 0.6, 0)},
        {"UpperTorso", Vector3.new(0.8, 0.7, 0), "Torso", Vector3.new(0.8, 0.8, 0)},
        {"Head", Vector3.new(0.35, 0.2, 0), "Head", Vector3.new(0.35, 0.2, 0)},
    }
    local function ensureStrings(c)
        if hands.strChar == c then return end
        hands.strChar = c
        for _, a in ipairs(hands.userAtt) do pcall(function() a:Destroy() end) end
        hands.userAtt = {}
        local i = 0
        for hi, h in ipairs(hands.list) do
            local side = h.sign > 0 and "Right" or "Left"
            for fi, s in ipairs(STR) do
                i += 1
                local limb = c:FindFirstChild(string.format(s[1], side))
                local off = s[2]
                if not limb then limb = c:FindFirstChild(string.format(s[3], side)) off = s[4] end
                local a1 = limb and own(KIT.tag(new("Attachment", {Name = "SecretString", Parent = limb, Position = Vector3.new(off.X * h.sign, off.Y, off.Z)}))) or nil
                hands.userAtt[#hands.userAtt + 1] = a1
                local b = hands.beams[i]
                if not b then
                    b = own(KIT.tag(new("Beam", {Parent = h.model, Width0 = 0.1, Width1 = 0.055, LightEmission = 1, LightInfluence = 0, Brightness = 2,
                        FaceCamera = true, Segments = lite() and 6 or 14, Color = ColorSequence.new(TIPC, SHELL),
                        Transparency = NumberSequence.new({NSK(0, 0.1), NSK(0.5, 0.35), NSK(1, 0.6)}), Enabled = false})))
                    hands.beams[i] = b
                end
                b.Attachment0 = h.tips[fi]
                b.Attachment1 = a1
                b:SetAttribute("SecretSway", hi * 10 + fi)
            end
        end
    end
    local function strings(on, tension, t)
        for i, b in ipairs(hands.beams) do
            local en = on and b.Attachment1 ~= nil
            if b.Enabled ~= en then b.Enabled = en end
            if en then
                local slack = 1 - tension
                b.CurveSize0 = -0.5 * slack + 0.45 * math.sin(t * 1.3 + i * 0.7)
                b.CurveSize1 = 0.25 * slack + 0.35 * math.cos(t * 1.1 + i * 1.1)
            end
        end
    end
    local function hideAll()
        hands.seq = nil
        for _, h in ipairs(hands.list) do h.alpha = 0 show(h, false) end
        strings(false, 0, 0)
    end
    local function yawOf(r)
        local lv = r.CFrame.LookVector
        local flat = Vector3.new(lv.X, 0, lv.Z)
        if flat.Magnitude < 0.05 then return CFrame.new() end
        return CFrame.new(Vector3.new(), flat)
    end

    -- ---------------- states (4.1) ----------------
    -- idle hover · alert (fingers flex, danger near) · shield (palms form a wall toward the threat)
    -- push (one palm thrusts at a projectile; visual, the dodge does the real work) · catch (cupped palms under you)
    -- victory (rise, spread, close to fists) · carry / lift (sequence-driven, grips the torso, strings taut)
    local MODE_RANK = {alert = 1, guide = 1, victory = 2, strike = 2, reach = 3, catch = 3, hold = 3, pull = 4, shield = 4, push = 5}
    function VFX.handsMode(name, data, dur)
        if not alive or settings.handsOn ~= true then return false end
        -- 5.5: without hand models, still fire a short spirit cue on shield / push so defence feels answered
        if not visualsOn() then
            if (name == "shield" or name == "push") and settings.vfx ~= false and KIT.emit and not lite() then
                local r = hrp()
                local d = data and (data.dir or (data.pos and r and (data.pos - r.Position)))
                if r and d and d.Magnitude > 0.01 then
                    local f = Vector3.new(d.X, 0, d.Z)
                    f = (f.Magnitude > 0.01) and f.Unit or Vector3.new(0, 0, -1)
                    pcall(KIT.emit, r.Position + f * 5.5 + Vector3.new(0, 1.6, 0), C.spiritCore, 8, 8, 0.4, 0.3, C.spirit)
                end
            end
            return false
        end
        local cur = hands.mode
        local t = now()
        if cur and t < cur.untilT and (MODE_RANK[cur.name] or 0) > (MODE_RANK[name] or 0) then return false end
        local fresh = not (cur and cur.name == name and t - cur.t0 < 0.3)
        hands.mode = {name = name, t0 = t, untilT = t + (dur or 0.6), dir = data and data.dir, pos = data and data.pos, fired = false,
            side = data and data.side, back = data and data.back}
        if name ~= "alert" then hands.tug = 1 end
        -- a soft burst where the palms meet the attack line
        if fresh and (name == "shield" or name == "push") and KIT.emit and not lite() then
            local r = hrp()
            local d = data and (data.dir or (data.pos and r and (data.pos - r.Position)))
            if r and d and d.Magnitude > 0.01 then
                local f = Vector3.new(d.X, 0, d.Z)
                f = (f.Magnitude > 0.01) and f.Unit or Vector3.new(0, 0, -1)
                pcall(KIT.emit, r.Position + f * 5.5 + Vector3.new(0, 1.6, 0), C.spiritCore, 10, 9, 0.45, 0.35, C.spirit)
            end
        end
        return true
    end
    -- fingertip attachments of the visible hands (Puppet Hold ties its NPC strings to them)
    function VFX.handTips()
        if not hands.built then return nil end
        local out = {}
        for _, h in ipairs(hands.list) do
            if h.shown then for _, a in ipairs(h.tips) do out[#out + 1] = a end end
        end
        return out
    end
    function VFX.handsState() local m = hands.mode return (m and now() < m.untilT) and m.name or (hands.seq and "carry" or "idle") end
    local UPF = CFrame.Angles(0, 0, math.pi)   -- palm facing up
    local function palmToward(pos, dir, upHint)
        local d = (dir.Magnitude > 0.01) and dir.Unit or Vector3.new(0, 0, -1)
        local up = upHint - d * upHint:Dot(d)
        if up.Magnitude < 0.05 then up = Vector3.new(0, 0, 1) - d * d.Z end
        up = up.Unit
        local Y, Z = -d, -up
        return CFrame.fromMatrix(pos, Y:Cross(Z), Y, Z)
    end
    local function flatDir(v, fallback)
        local f = Vector3.new(v.X, 0, v.Z)
        if f.Magnitude < 0.05 then return fallback end
        return f.Unit
    end
    -- V2.3 hand roles. LEFT = pilot: over and behind you, palm down, working your strings, leaning into
    -- every pull; during an evacuation it grips your shoulders and flies you out.
    -- RIGHT = companion: ready palm toward the threat, closes its fingers around a held NPC, thrusts it
    -- away, raises a palm guard against players (visual only), or lifts you from below.
    local function rolePose(h, role, r, yaw, look, t, lead)
        local me = r.Position
        local k = role.kind
        if k == "pilot" then
            local s = role.dir or Vector3.zero
            local lean = Vector3.new(s.X, 0, s.Z)
            if lean.Magnitude > 1 then lean = lean.Unit * 3.2 else lean = lead end
            local fwd = (lean.Magnitude > 0.5) and lean.Unit or look
            local pos = me + Vector3.new(0, 8.4 + math.sin(t * 2.1) * 0.3, 0) - look * 2.4 + yaw * Vector3.new(-1.8, 0, 0) + lean
            return palmToward(pos, -Vector3.yAxis, fwd) * CFrame.Angles(0, 0, -0.16), curlsFor(0.42 + hands.tug * 0.3, t, h.sign, 2.8), 1.25, 14
        elseif k == "carry" then
            local pos = me + Vector3.new(0, 4.7, 0)
            return CFrame.new(pos) * yaw * CFrame.new(0, 0, 1.2) * CFrame.Angles(rad(-10), 0, 0), {0.92, 0.96, 0.96, 0.9, 0.82}, 0.9, 34
        elseif k == "grip" and role.root and role.root.Parent then
            local p = role.root.Position
            local fd = flatDir(p - me, look)
            local u = math.clamp((now() - (role.t0 or 0)) / 0.28, 0, 1)
            local g = 0.12 + 0.93 * (1 - (1 - u) ^ 3)      -- the fingers close around it
            local sq = 0.05 * math.sin(t * 8)               -- a living squeeze
            local pos = p + Vector3.new(0, 3.4, 0) - fd * 0.8
            return palmToward(pos, -Vector3.yAxis, fd) * CFrame.Angles(0, math.sin(t * 0.9) * 0.2, 0.1), {g + sq, g, g + sq * 0.5, g, g * 0.86}, 1.4 - 0.55 * u, 26
        elseif k == "throw" then
            local d = flatDir(role.dir or look, look)
            local u = math.clamp((now() - (role.t0 or 0)) / 0.4, 0, 1)
            local e = (u < 0.3) and (-0.6 * u / 0.3) or ((u - 0.3) / 0.7)
            local pos = me + Vector3.new(0, 2.6, 0) + d * (5 + 7 * e) + Vector3.yAxis:Cross(d) * -1.2
            return palmToward(pos, d, Vector3.yAxis), curlsFor(0, t, h.sign, 0), 1.6, 30
        elseif k == "guard" then
            local d = flatDir(role.dir or look, look)
            local pos = me + d * 5.6 + Vector3.new(0, 2.2 + math.sin(t * 6) * 0.08, 0)
            return palmToward(pos, d, Vector3.yAxis) * CFrame.Angles(0, 0, -0.15), curlsFor(0.04, t, h.sign, 0.2), 1.55, 22
        elseif k == "lift" then
            local pos = me - Vector3.new(0, 3.4, 0)
            return CFrame.new(pos) * yaw * CFrame.new(0, 0, -1.2) * UPF, curlsFor(0.55, t, h.sign, 0.2), 1.0, 26
        elseif k == "ready" then
            local d = flatDir(role.dir or look, look)
            local perp = Vector3.yAxis:Cross(d).Unit
            local pos = me + d * 4 + perp * 3.6 + Vector3.new(0, 3.1 + math.sin(t * 1.7) * 0.25, 0)
            return palmToward(pos, d, Vector3.yAxis) * CFrame.Angles(0, 0, 0.22), curlsFor(0.28, t, h.sign, 0.7), 1.3, 9
        end
        return nil
    end

    -- ---------------- render loop ----------------
    local function frame(dt)
        local on = alive and visualsOn() and (settings.handsOn == true or now() < hands.previewUntil)
        if not on then if hands.built then hideAll() end return end
        hands.acc += dt
        if lite() and hands.acc < 1 / 30 then return end
        local step = math.min(hands.acc, 0.1)
        hands.acc = 0
        hands.t += step
        hands.tug = math.max(0, hands.tug - step * 2.2)
        local r, c, hm = hrp(), char(), hum()
        local living = r and c and hm and hm.Health > 0
        local sit = brain.situation
        local S41 = CORE.sense
        local danger = sit == "Combat" or sit == "Being chased" or sit == "Low health" or (S41.combat == true)
        local mode = hands.mode
        if mode and now() >= mode.untilT then hands.mode = nil mode = nil end
        if mode and not living then hands.mode = nil mode = nil end
        local mv = CORE.move
        local steering = mv.steer and mv.steer.Magnitude > 2
        local rl = hands.roles
        local roleOn = rl and ((rl.pilot and now() < rl.pilot.untilT) or (rl.comp and now() < rl.comp.untilT))
        local puppet = living and (mode ~= nil or roleOn or (settings.handsPuppet ~= false
            and (danger or steering or settings.handsAlways == true or now() < hands.previewUntil)))
        local seq = hands.seq
        if not hands.built then if not (puppet or seq) then return end build() end
        local t = hands.t
        local alertish = (S41.alertUntil or 0) > now()
        if not mode and alertish and puppet then mode = {name = "alert", t0 = now(), untilT = now() + 0.1} end
        local yaw = r and yawOf(r) or CFrame.new()
        local look = r and flatDir(r.CFrame.LookVector, Vector3.new(0, 0, -1)) or Vector3.new(0, 0, -1)
        -- Puppeteer lead: when the hands steer you, they lean into the pull (the strings drag you)
        local lead = Vector3.zero
        if steering and r then
            local s = mv.steer
            lead = Vector3.new(s.X, 0, s.Z) * 0.06
            if lead.Magnitude > 3 then lead = lead.Unit * 3 end
            hands.tug = math.max(hands.tug, math.clamp(s.Magnitude / 45, 0, 1))
        end
        for i, h in ipairs(hands.list) do
            if seq and seq.hand == h then
                h.alpha = math.min(1, h.alpha + step * 7)
                show(h, true)
                pose(h, seq.cf, {seq.curl, seq.curl, seq.curl, seq.curl, seq.curl * 0.8}, seq.spread or 1)
            elseif puppet and not (seq and seq.solo) then
                local target, curls, spread, rate = nil, nil, 1, 5
                local m = mode and mode.name
                local u = mode and math.clamp((now() - mode.t0) / math.max(mode.untilT - mode.t0, 0.05), 0, 1) or 0
                local role = rl and ((i == 1) and rl.pilot or rl.comp)
                if role and now() < role.untilT and (m ~= "shield" and m ~= "push" or role.kind == "grip" or role.kind == "carry") then
                    target, curls, spread, rate = rolePose(h, role, r, yaw, look, t, lead)
                end
                if target then
                    if i == 2 and role.kind == "grip" then hands.tug = math.max(hands.tug, 0.8) end
                elseif m == "shield" then
                    local d = flatDir(mode.dir or look, look)
                    local perp = Vector3.yAxis:Cross(d).Unit
                    local pos = r.Position + d * 5.2 + Vector3.new(0, 1.6 + math.sin(t * 9 + i) * 0.08, 0) + perp * (h.sign * 2.9)
                    target = palmToward(pos, d, Vector3.yAxis) * CFrame.Angles(0, 0, -h.sign * 0.18)
                    curls, spread, rate = curlsFor(0.06, t, h.sign, 0.25), 1.5, 22
                elseif m == "push" then
                    local d = (mode.pos and (mode.pos - r.Position)) or (mode.dir or look)
                    if d.Magnitude < 0.1 then d = look end
                    d = d.Unit
                    local perp = Vector3.yAxis:Cross(flatDir(d, look)).Unit
                    local right = yaw * Vector3.new(1, 0, 0)
                    local mine = (right:Dot(d) >= 0) == (h.sign > 0)
                    if mine then
                        local e = 1 - (1 - math.min(1, u / 0.35)) ^ 3
                        local pos = r.Position + Vector3.new(0, 1.8, 0) + d * (3 + 6 * e) + perp * (h.sign * 1.2)
                        target = palmToward(pos, d, Vector3.yAxis)
                        curls, spread, rate = curlsFor(0, t, h.sign, 0), 1.55, 26
                    else
                        target = CFrame.new(r.Position + lead) * yaw * CFrame.new(h.sign * 4.4, 8, 2.6) * CFrame.Angles(rad(-30), h.sign * rad(13), 0)
                        curls, spread = curlsFor(0.5, t, h.sign, 1.6), 1.2
                    end
                elseif m == "catch" then
                    local pos = r.Position + Vector3.new(0, -3.9, 0) + (yaw * Vector3.new(h.sign * 1.75, 0, 0.3))
                    target = CFrame.new(pos) * yaw * CFrame.Angles(0, 0, -h.sign * 0.42) * UPF
                    curls, spread, rate = curlsFor(0.62, t, h.sign, 0.2), 0.95, 20
                elseif m == "victory" then
                    local rise = 1 - (1 - math.min(1, u / 0.45)) ^ 2
                    local pos = r.Position + (yaw * Vector3.new(h.sign * (4 + 2.2 * rise), 8 + 5 * rise, 0.8))
                    target = palmToward(pos, look, Vector3.yAxis) * CFrame.Angles(0, 0, h.sign * (0.35 - 0.5 * rise))
                    if u < 0.55 then curls, spread = curlsFor(0, t, h.sign, 0), 1.7
                    else curls, spread = {1.05, 1.05, 1.05, 1.0, 0.9}, 0.8 end
                    rate = 10
                    if u >= 0.55 and not mode.fired and i == 2 then
                        mode.fired = true
                        if KIT.emit and not lite() then
                            pcall(KIT.emit, hands.list[1].cf.Position, C.spiritCore, 14, 10, 0.6, 0.4, C.spirit)
                            pcall(KIT.emit, hands.list[2].cf.Position, C.spiritCore, 14, 10, 0.6, 0.4, C.spirit)
                        end
                    end
                elseif m == "hold" then
                    -- Puppet Hold: both hands raised high over the cluster, palms down, fingers working the strings
                    local tp = mode.pos or (r.Position + look * 6)
                    local fd = flatDir(tp - r.Position, look)
                    local perp = Vector3.yAxis:Cross(fd).Unit
                    local bob = math.sin(t * 1.6 + i * 1.7) * 0.35
                    local pos = tp + Vector3.new(0, 9.5 + bob, 0) + perp * (h.sign * 2.6) - fd * 1.2
                    target = palmToward(pos, -Vector3.yAxis, fd) * CFrame.Angles(0, math.sin(t * 0.8 + i) * 0.15, h.sign * 0.12)
                    curls, spread, rate = curlsFor(0.38, t, h.sign, 2.6), 1.45, 10
                    hands.tug = 0.7
                elseif m == "guide" or m == "reach" or m == "pull" or m == "strike" then
                    -- 4.3 PvE gestures. guide: one palm sweeps you along the safe line (Boss Choreography)
                    -- reach: one hand flies out to an item, closes, brings it back (Loot Grab)
                    -- pull: both hands reach to the target and drag you in (Puppet Finisher)
                    -- strike: one hand cuts across the target with an ink slash (Shadow Strikes)
                    local tp = mode.pos or (r.Position + look * 6)
                    local d = tp - r.Position
                    local fd = flatDir(d, look)
                    local perp = Vector3.yAxis:Cross(fd).Unit
                    local right = yaw * Vector3.new(1, 0, 0)
                    local mySide = mode.side or (((right:Dot(fd) >= 0) == true) and 1 or -1)
                    local mine = (m == "pull") or (h.sign == mySide)
                    if not mine then
                        target = CFrame.new(r.Position + lead) * yaw * CFrame.new(h.sign * 4.2, 8.6, 2.8) * CFrame.Angles(rad(-28), h.sign * rad(13), 0)
                        curls, spread, rate = curlsFor(0.4, t, h.sign, 1.2), 1.1, 8
                    elseif m == "guide" then
                        local e = math.sin(math.min(1, u) * math.pi)
                        local pos = r.Position + Vector3.new(0, 2.4 + 0.6 * e, 0) + fd * (2.5 + 3.5 * e) + perp * (h.sign * 0.8)
                        target = palmToward(pos, fd, Vector3.yAxis) * CFrame.Angles(0, 0, h.sign * 0.4 * e)
                        curls, spread, rate = curlsFor(0.12, t, h.sign, 0.3), 1.35, 12
                    elseif m == "reach" then
                        local out = (u < 0.45) and (1 - (1 - u / 0.45) ^ 3) or ((u < 0.6) and 1 or math.max(0, 1 - ((u - 0.6) / 0.4) ^ 2))
                        local home = r.Position + Vector3.new(0, 3, 0) + perp * (h.sign * 2)
                        local pos = home:Lerp(tp + Vector3.new(0, 1.2, 0), out)
                        target = palmToward(pos, (tp - home).Magnitude > 0.1 and (tp - home).Unit or fd, Vector3.yAxis)
                        local grip = (u > 0.4) and 1.0 or 0.05
                        curls, spread, rate = {grip, grip, grip, grip, grip * 0.8}, (u > 0.4) and 0.85 or 1.5, 18
                        if u > 0.42 and not mode.fired then
                            mode.fired = true
                            if KIT.emit and not lite() then pcall(KIT.emit, tp, C.spiritCore, 8, 7, 0.35, 0.3, C.spirit) end
                        end
                    elseif m == "pull" then
                        local out = (u < 0.35) and (1 - (1 - u / 0.35) ^ 3) or math.max(0, 1 - (u - 0.35) / 0.65)
                        local reachLen = math.min(d.Magnitude, 16)
                        local pos = r.Position + Vector3.new(0, 2.6, 0) + fd * (3 + (reachLen - 3) * out) + perp * (h.sign * 1.6)
                        target = palmToward(pos, fd, Vector3.yAxis)
                        local grip = (u > 0.3) and 1.05 or 0.1
                        curls, spread, rate = {grip, grip, grip, grip, grip * 0.85}, 1.2, 24
                        hands.tug = 1
                    else -- strike
                        local e = 1 - (1 - math.min(1, u / 0.6)) ^ 2
                        local pos = r.Position + fd * (2.4 + 3.2 * e) + Vector3.new(0, 4.2 - 3.6 * e, 0) + perp * (h.sign * (2.2 - 4.4 * e))
                        target = palmToward(pos, fd, Vector3.yAxis) * CFrame.Angles(0, 0, h.sign * (0.9 - 1.8 * e))
                        curls, spread, rate = {0.15, 0.1, 0.1, 0.15, 0.5}, 0.9, 30
                        if u > 0.2 and not mode.fired then
                            mode.fired = true
                            if VFX.slashTrail then pcall(VFX.slashTrail, pos + perp * (h.sign * 2), tp + Vector3.new(0, 1, 0) - perp * (h.sign * 2), C.smoke) end
                        end
                    end
                else
                    local al = (m == "alert")
                    local bob = math.sin(t * (al and 2.2 or 1.1) + i * 2.1) * (al and 0.3 or 0.45)
                    local sway = CFrame.Angles(math.sin(t * 0.9 + i) * 0.05, 0, math.cos(t * 0.7 + i) * 0.04)
                    target = CFrame.new(r.Position + lead) * yaw * CFrame.new(h.sign * (al and 4.3 or 3.6), (al and 8.4 or 9.6) + bob, al and 2.6 or 3.4)
                        * CFrame.Angles(rad((al and -32 or -22) - hands.tug * 12), h.sign * rad(13), h.sign * rad(-7)) * sway
                    curls = curlsFor((al and 0.42 or 0.3) + hands.tug * 0.4, t, h.sign, al and 2.2 or (lite() and 0.6 or 1))
                    spread = al and 1.18 or 1
                end
                if not h.shown then h.cf = target + Vector3.new(0, 4, 0) end
                h.cf = h.cf:Lerp(target, math.min(1, step * rate))
                h.alpha = math.min(1, h.alpha + step * ((m and m ~= "alert") and 6 or 2.2))
                show(h, true)
                pose(h, h.cf, curls, spread)
                if h.light then h.light.Brightness = ((m == "shield" or m == "push") and 3.2 or 1.6) * h.alpha end
            elseif h.shown then
                h.alpha = math.max(0, h.alpha - step * 2.5)
                if h.alpha <= 0 then show(h, false) else pose(h, h.cf + Vector3.new(0, step * 5, 0), curlsFor(0.2, t, h.sign, 0), 1.1) end
            end
        end
        local m = mode and mode.name
        if (puppet or seq) and c and m ~= "shield" and m ~= "push" and m ~= "catch" then
            ensureStrings(c)
            -- V2.3: while the right hand grips an NPC, its five strings run into that NPC's limbs
            local cg = rl and rl.comp and rl.comp.kind == "grip" and now() < rl.comp.untilT and rl.comp.atts
            if cg and #cg > 0 then
                for k = 1, 5 do local b = hands.beams[5 + k] if b then b.Attachment1 = cg[(k - 1) % #cg + 1] end end
                hands.gripStr = true
            elseif hands.gripStr then
                hands.gripStr = false
                hands.strChar = nil   -- rebuild: strings back to you
            end
            strings(hands.list[1].alpha > 0.45 or (seq ~= nil), seq and 1 or math.max(hands.tug, m == "alert" and 0.5 or 0), t)
        else
            strings(false, 0, t)
        end
    end
    onRender("fxHands", function(dt)
        local ok, e = pcall(frame, dt)
        if not ok then CORE.log("ERR", "hands: " .. tostring(e)) pcall(hideAll) end
    end)
    -- dodges tug the strings
    local baseDodge = VFX.dodge
    function VFX.dodge(p) if baseDodge then baseDodge(p) end hands.tug = 1 end

    -- ---------------- safe-ground cache (for rescues) ----------------
    local safeCache = {}   -- newest first: Vector3 positions (root height)
    local castP = RaycastParams.new()
    castP.FilterType = Enum.RaycastFilterType.Exclude
    local function castExclude()
        local ex = {gui}
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
        for _, h in ipairs(hands.list) do ex[#ex + 1] = h.model end
        castP.FilterDescendantsInstances = ex
    end
    local function groundBelow(pos, depth)
        castExclude()
        local res = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -(depth or 12), 0), castP)
        if not res or not res.Instance then return nil end
        if res.Material == Enum.Material.Water then return nil end
        if res.Instance:IsA("BasePart") and brain.isHazard and brain.isHazard(res.Instance) then return nil end
        return res
    end
    local cacheAcc = 0
    local dmg = {}          -- {t, amt}
    local lastHp, maxSeen = nil, 100
    local fallStart = nil
    local function recentDamage(window)
        local t, sum = now(), 0
        for _, d in ipairs(dmg) do if t - d.t <= window then sum += d.amt end end
        return sum
    end
    local function cacheTick(r, h)
        if h.FloorMaterial == Enum.Material.Air or h.Health <= 0 or FX.inSafe() or hands.busy then return end
        if recentDamage(1.5) > 0 then return end
        if h.Health < h.MaxHealth * 0.25 then return end
        local res = groundBelow(r.Position, 8)
        if not res then return end
        local p = r.Position
        local last = safeCache[1]
        if last and (last - p).Magnitude < 6 then return end
        table.insert(safeCache, 1, p)
        if #safeCache > 40 then table.remove(safeCache) end
    end
    -- 4.3 Explorer Scanner feed: known safe zones join the cache at the back (your own fresh spots stay first)
    function CORE.addSafe(p)
        if type(p) ~= "userdata" then return end
        for _, q in ipairs(safeCache) do if (q - p).Magnitude < 6 then return end end
        if #safeCache >= 40 then return end
        safeCache[#safeCache + 1] = p
    end
    local function pickSafe(from, enemyPos, reason)
        local minFrom = (reason == "void") and 0 or 8
        for _, p in ipairs(safeCache) do
            local d = (p - from).Magnitude
            if d >= minFrom and d < 900 and (not enemyPos or (p - enemyPos).Magnitude >= 30) and groundBelow(p, 9) then return p end
        end
        if brain.lastSafePos then
            local p = brain.lastSafePos(enemyPos, enemyPos and 30 or 0, true)
            if p and groundBelow(p, 9) then return p end
        end
        if GV.lastSafeCF and groundBelow(GV.lastSafeCF.Position, 9) then return GV.lastSafeCF.Position end
        return nil
    end

    -- ---------------- carry helpers ----------------
    local function carry(r, pointAt, dist, handAt)
        -- 4.1: smooth physics carry (AlignPosition, every frame) when available; stepped CFrame fallback
        if CORE.move.carry and not broken("move_physics") then
            local done = CORE.move.carry(pointAt, dist, function(p) if hands.seq and handAt then hands.seq.cf = handAt(p) end end)
            if done then return end
        end
        local small = brain.tpStepped and brain.tpStepped()
        local dur = math.clamp(dist / 140, 0.35, 0.9)
        local n = math.clamp(math.ceil(dist / (small and 4 or 10)), 7, small and 90 or 30)
        local dt = small and 0.05 or (dur / n)
        local rot = r.CFrame - r.CFrame.Position
        for i = 1, n do
            if not alive or not r.Parent then return end
            local p = pointAt(i / n)
            if brain.ownMove then brain.ownMove() end
            r.CFrame = CFrame.new(p) * rot
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if hands.seq and handAt then hands.seq.cf = handAt(p) end
            task.wait(dt)
        end
    end
    local function glide(seq, toCf, dur, c1, spread1)
        local fromCf, c0, s0 = seq.cf, seq.curl, seq.spread or 1
        local t0 = now()
        while true do
            local u = math.min(1, (now() - t0) / math.max(dur, 0.01))
            local e = 1 - (1 - u) ^ 3
            seq.cf = fromCf:Lerp(toCf, e)
            seq.curl = c0 + (c1 - c0) * e
            if spread1 then seq.spread = s0 + (spread1 - s0) * e end
            if u >= 1 then break end
            task.wait()
        end
    end
    local function release(pos)
        if settings.vfx == false then return end
        if KIT.emit then pcall(KIT.emit, pos, C.spiritCore, lite() and 10 or 24, 14, 0.7, 0.5, C.spirit) end
        if VFX.ring then pcall(VFX.ring, pos - Vector3.new(0, 2.6, 0), C.spirit, 16) end
        if VFX.pulse then pcall(VFX.pulse, C.spirit, 0.35, 0.45) end
        if KIT.camShake and not lite() then pcall(KIT.camShake, 0.25, 0.2) end
    end
    local function grabCf(p, yaw)
        return CFrame.new(p + Vector3.new(0, 4.7, 0)) * yaw * CFrame.new(0, 0, 1.2) * CFrame.Angles(rad(-10), 0, 0)
    end

    -- ---------------- (2) Predictive Rescue ----------------
    -- reason: "hit" (predicted lethal / burst) · "low" (health threshold) · "void" · "hazard" · nil (manual / retreat)
    -- 5.5: moves YOU directly. Optional hand dive only when handsVisual is on.
    function VFX.handsRescue(force, enemyPos, reason, attacker)
        if hands.busy or not alive then return false end
        -- V2.3: the manual Rescue button and every "no safe ground known" case use the Lifeline
        if force and reason == nil and CORE.lifeline then return CORE.lifeline.evacuate("manual", true) end
        if not force and (settings.handsOn ~= true or settings.handsRescue == false) then return false end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or FX.inSafe() then return false end
        local start = r.Position
        local target = pickSafe(start, enemyPos, reason)
        local canMove = not broken("hands_move")
        if not canMove then
            -- moving is reverted by this game: be honest, fall back to the Safe Spot only when it's really lethal
            if reason == "hit" or reason == "void" then
                if now() - hands.lastRescue > 10 then hands.lastRescue = now() say("rescue_blocked") pcall(FX.goSafe) end
                return true
            end
            return false
        end
        if not target then
            if reason ~= "void" and CORE.lifeline then return CORE.lifeline.evacuate(reason or "manual", force) end
            if reason == "void" or reason == "hit" or force then hands.lastRescue = now() pcall(FX.goSafe) return true end
            return false
        end
        local showHands = visualsOn()
        if showHands then build() end
        hands.busy = true
        HUB.rescueBusy = true
        hands.lastRescue = now()
        local yaw = yawOf(r)
        local seq = nil
        if showHands then
            local hand = hands.list[1]   -- legacy: left hand is the pilot
            seq = {hand = hand, cf = grabCf(start, yaw) + Vector3.new(0, 14, 6), curl = 0.05, spread = 1.35, solo = false}
            hand.alpha = math.max(hand.alpha, 0.6)
            hands.seq = seq
        end
        local hp0 = h.Health
        r.AssemblyLinearVelocity = Vector3.zero
        task.spawn(function()
            local ok, e = pcall(function()
                if not say("rescue_" .. (reason or "hit")) then say("hands_rescue") end
                if VFX.takeover then VFX.takeover(start, target, reason == "void" and "sky" or "rescue") end
                if seq then task.spawn(function() glide(seq, grabCf(r.Position, yaw), 0.12, 0.9, 0.9) end) end
                local dist = (target - start).Magnitude
                local lift = (reason == "void") and 6 or math.clamp(dist * 0.25, 6, 26)
                local mid = (start + target) / 2 + Vector3.new(0, lift, 0)
                if reason == "void" then mid = Vector3.new(mid.X, math.max(mid.Y, target.Y + 10), mid.Z) end
                carry(r, function(u)
                    local a = 1 - u
                    return start * (a * a) + mid * (2 * a * u) + (target + Vector3.new(0, 0.2, 0)) * (u * u)
                end, dist + lift, seq and function(p) return grabCf(p, yaw) end or nil)
                r.AssemblyLinearVelocity = Vector3.zero
                release(r.Position)
                if VFX.release then VFX.release(r.Position, nil) end
                if seq then
                    glide(seq, seq.cf * CFrame.new(0, 1.2, 0), 0.18, 0.05, 1.4)
                    seq.solo = true
                    glide(seq, seq.cf + Vector3.new(0, 9, 3), 0.45, 0.15, 1.2)
                end
            end)
            if not ok then CORE.log("ERR", "rescue: " .. tostring(e)) end
            hands.seq = nil
            hands.busy = false
            task.delay(0.5, function()
                HUB.rescueBusy = false
                local rr, hh = hrp(), hum()
                local success = rr ~= nil and hh ~= nil and hh.Health > 0 and (rr.Position - target).Magnitude < 10
                    and rr.AssemblyLinearVelocity.Y > -60
                report("hands_move", success, "Guardian Control (moving you)")
                if success then
                    say("rescue_ok")
                    if VFX.release then VFX.release(rr and rr.Position, "safe") end
                    if visualsOn() and VFX.handsMode then task.delay(0.2, function() VFX.handsMode("victory", nil, 1.2) end) end
                    -- a taunt for the attacker only after a verified save
                    if attacker and typeof(attacker) == "Instance" and attacker:IsA("Player") and VFX.taunt then
                        pcall(VFX.taunt, "rescue", attacker.DisplayName)
                    end
                else
                    say("rescue_fail")
                end
                if hh and hh.Health < hp0 * 0.5 and hh.Health > 0 and not success then pcall(FX.goSafe) end
            end)
        end)
        return true
    end

    -- ---------------- (3) Lift Assist ----------------
    local liftParams = RaycastParams.new()
    liftParams.FilterType = Enum.RaycastFilterType.Exclude
    local function findLedge(r)
        local lv = r.CFrame.LookVector
        local flat = Vector3.new(lv.X, 0, lv.Z)
        if flat.Magnitude < 0.05 then return nil end
        flat = flat.Unit
        local ex = {char(), gui}
        for _, h in ipairs(hands.list) do ex[#ex + 1] = h.model end
        liftParams.FilterDescendantsInstances = ex
        local wall = workspace:Raycast(r.Position, flat * 4, liftParams)
        local ahead = wall and ((wall.Position - r.Position).Magnitude + 1.6) or 3.5
        local top = workspace:Raycast(r.Position + flat * ahead + Vector3.new(0, 14, 0), Vector3.new(0, -16, 0), liftParams)
        if not top then return nil end
        local rise = top.Position.Y - (r.Position.Y - 3)
        if rise < 3.5 or rise > 13 then return nil end
        if brain.isHazard and top.Instance and top.Instance:IsA("BasePart") and brain.isHazard(top.Instance) then return nil end
        return top.Position + Vector3.new(0, 3.1, 0)
    end
    local UP = CFrame.Angles(0, 0, math.pi)   -- palm facing up
    function VFX.handsLift(force)
        if hands.busy or not alive then return false end
        if not force and settings.handsOn ~= true then return false end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 then return false end
        local target = findLedge(r)
        if not target then
            if force then toast("No ledge in front of you.", "info", 1.6) end
            return false
        end
        local showHands = visualsOn()
        if showHands then build() end
        hands.busy = true
        hands.lastLift = now()
        local start = r.Position
        local yaw = yawOf(r)
        local function under(p) return CFrame.new(p - Vector3.new(0, 3.3, 0)) * yaw * CFrame.new(0, 0, -1.5) * UP end
        local seq = nil
        if showHands then
            seq = {hand = hands.list[2], cf = under(start) - Vector3.new(0, 7, 0), curl = 0.2, spread = 1.1}
            hands.seq = seq
        end
        task.spawn(function()
            local ok, e = pcall(function()
                say("hands_lift")
                if VFX.takeover then VFX.takeover(start, target, "lift") end
                if seq then glide(seq, under(start), 0.2, 0.35) end
                local moveOk = not broken("hands_move")
                if moveOk then
                    local p1 = Vector3.new(start.X, target.Y + 1.2, start.Z)
                    local d1 = (p1 - start).Magnitude
                    local dist = d1 + (target - p1).Magnitude
                    carry(r, function(u)
                        local s = u * dist
                        if s <= d1 then return start:Lerp(p1, s / math.max(d1, 0.01)) end
                        return p1:Lerp(target, (s - d1) / math.max(dist - d1, 0.01))
                    end, dist, seq and under or nil)
                end
                release(r.Position)
                if VFX.release then VFX.release(r.Position, nil) end
                if seq then glide(seq, seq.cf - Vector3.new(0, 6, 0), 0.35, 0.7) end
                if moveOk then
                    task.delay(0.4, function()
                        local rr = hrp()
                        report("hands_move", rr ~= nil and (rr.Position - target).Magnitude < 6, "Guardian Control (moving you)")
                    end)
                end
            end)
            if not ok then CORE.log("ERR", "lift: " .. tostring(e)) end
            hands.seq = nil
            hands.busy = false
        end)
        return true
    end
    function VFX.handsPreview()
        if not visualsOn() then
            toast("Hand models were removed in Void Hub.", "info", 2)
            return
        end
        hands.previewUntil = now() + 4
        hands.tug = 1
        task.delay(1.4, function() hands.tug = 1 end)
        task.delay(2.6, function() hands.tug = 0.8 end)
    end

    -- ---------------- rescue monitor: acts BEFORE the lethal hit ----------------
    local function threshold() return math.clamp(tonumber(settings.rescueThreshold) or 35, 10, 80) / 100 end
    local function cooldownOk(reason)
        return now() - hands.lastRescue > ((reason == "void") and 1.5 or 6)
    end
    local function lastAttacker()
        local lh = brain.lastHit
        if type(lh) == "table" and lh.attacker and now() - (lh.t or 0) < 3 then return lh.attacker end
        return nil
    end
    local function enemyPosOf(att)
        local rr = att and att.Character and att.Character:FindFirstChild("HumanoidRootPart")
        return rr and rr.Position or nil
    end
    local function evaluate(r, h, fromHit)
        if hands.busy or FX.inSafe() or settings.handsOn ~= true or settings.handsRescue == false then return end
        local hp, mx = h.Health, math.max(h.MaxHealth, 1)
        if hp <= 0 then return end
        local t = now()
        -- void / long freefall
        local v = r.AssemblyLinearVelocity
        if v.Y < -60 then fallStart = fallStart or t else fallStart = nil end
        local voidY = workspace.FallenPartsDestroyHeight + 90
        local reason
        if r.Position.Y < voidY and v.Y < -4 then reason = "void"
        elseif fallStart and t - fallStart > 1.6 and v.Y < -90 then
            castExclude()
            if not workspace:Raycast(r.Position, Vector3.new(0, -400, 0), castP) then reason = "void" end
        end
        if not reason then
            local last = dmg[#dmg]
            local recent = last and (t - last.t) or 99
            local dps = recentDamage(1)
            local factor = (GAMEINFO and GAMEINFO.tune and tonumber(GAMEINFO.tune.rescueDpsFactor)) or 0.35
            if last and recent < 1.5 and last.amt >= hp * 0.9 then reason = "hit"            -- one more hit like that kills you
            elseif dps > 0 and dps * 0.6 >= hp then reason = "hit"                           -- the current damage rate kills you in < 0.6 s
            elseif hp <= mx * threshold() and recent < 2.5 then reason = "low"
            elseif dps >= mx * factor and hp < mx * 0.8 then reason = "hit"
            elseif CORE.sense.top and (CORE.sense.top.danger or 0) >= 1 and (CORE.sense.top.lastAmt or 0) >= hp * 0.9 then
                reason = "hit"   -- 4.1: this attacker is winding up and its last hit would kill you now: leave before it lands
            elseif recent < 1 then
                castExclude()
                local fl = workspace:Raycast(r.Position, Vector3.new(0, -6, 0), castP)
                if fl and fl.Instance and fl.Instance:IsA("BasePart") and brain.isHazard and brain.isHazard(fl.Instance) then reason = "hazard" end
            end
        end
        if not reason or not cooldownOk(reason) then return end
        if reason ~= "void" and reason ~= "hazard" and CORE.lifeline and CORE.lifeline.enabled() then return end   -- V2.3: the Lifeline handles damage
        local att = lastAttacker()
        VFX.handsRescue(false, enemyPosOf(att), reason, att)
    end
    local hooked
    local function hookHum(h)
        if hooked == h then return end
        hooked = h
        lastHp, maxSeen = h.Health, h.MaxHealth
        dmg = {}
        bind(h.HealthChanged:Connect(function(hp)
            if not alive or hooked ~= h then return end
            local prev = lastHp or hp
            lastHp = hp
            if hp < prev - 0.05 then
                dmg[#dmg + 1] = {t = now(), amt = prev - hp}
                if #dmg > 30 then table.remove(dmg, 1) end
                local r = hrp()
                if r and hp > 0 then pcall(evaluate, r, h, true) end   -- same frame as the hit
            end
        end))
    end
    onHeartbeat("handsAuto", function(dt)
        local r, h = hrp(), hum()
        if not (r and h) then return end
        if hooked ~= h then hookHum(h) end
        hands.autoAcc += dt
        cacheAcc += dt
        if cacheAcc >= 0.2 then cacheAcc = 0 pcall(cacheTick, r, h) end
        if hands.autoAcc < 0.05 then return end
        hands.autoAcc = 0
        if h.Health <= 0 then return end
        pcall(evaluate, r, h, false)
        if settings.handsOn == true and settings.handsLift == true and not hands.busy and brain.situation == "Obby"
            and now() - hands.lastLift > 3 and h.FloorMaterial == Enum.Material.Air then
            local v = r.AssemblyLinearVelocity
            local lv = r.CFrame.LookVector
            if v.Y < 10 and v.Y > -8 and (v.X * lv.X + v.Z * lv.Z) > 6 then VFX.handsLift(false) end
        end
    end)
    CORE.onChar("hands", function(c)
        safeCache = {} dmg = {} hooked = nil fallStart = nil
        hands.busy = false hands.seq = nil hands.mode = nil hands.strChar = nil hands.roles = {} hands.gripStr = false
        HUB.rescueBusy = false
        for _, a in ipairs(hands.userAtt) do pcall(function() a:Destroy() end) end
        hands.userAtt = {}
    end)
    CORE.hands = {pickSafe = pickSafe, groundBelow = groundBelow, recentDamage = recentDamage, state = hands,
        cache = function() return safeCache end}
    local function cleanup()
        hands.busy = false
        HUB.rescueBusy = false
        if hands.built then hideAll() end
        for _, a in ipairs(hands.userAtt) do pcall(function() a:Destroy() end) end
        hands.userAtt = {}
        hands.strChar = nil
    end
    VFX.handsOff = cleanup
    onUnload(cleanup)
end)

-- =====================================================================
-- 14n. Guardian Core 4.1 (defensive / utility only, everything local and verified)
--   life   : one respawn pipeline; every module re-binds on CharacterAdded
--   sense  : predictive threat sensor (NPCs + players + projectiles + hitboxes + attack animations)
--   move   : physics movement controller (LinearVelocity steering, AlignPosition carry, CFrame fallback)
--   puppet : Puppeteer Mode: the hands steer you out of attack arcs, strafe, keep distance, catch falls
--   abil   : scans YOUR tools / keys / buttons and uses your own defensive or mobility abilities
--   ggod   : Guardian Godmode: state guard, anti-knockback, anti-ragdoll, death watchdog, live status
--   stalk  : Stalker Shield: someone keeps hunting you -> evade, keep distance, verified escape
--   water  : walk on water (Terrain + water parts + learned sea level), ripples
--   sight  : Sharingan Sight: reads wind-ups and projectile lines (visual only)
--   Never used against anyone: nothing here damages, flings, kills or targets players or NPCs.
-- =====================================================================
CORE.safeModule("14n Guardian Core 4.1", function()
    local KIT = VFX._kit or {}
    local SEN, MOV, ABI, GG, STK = CORE.sense, CORE.move, CORE.abil, CORE.ggod, CORE.stalk
    local function now() return os.clock() end
    local function lite() return PERF.lite end
    local function say(kind, vars, prio, sub) if VFX.say then local ok, r = pcall(VFX.say, kind, vars, prio, sub) return ok and r end return false end
    local function report(name, ok, label) if brain.report then pcall(brain.report, name, ok, label) end end
    local function broken(name) local a = brain.actionState and brain.actionState(name) return type(a) == "table" and a.broken == true end
    local function isOurs(o) local ok, v = pcall(function() return o:GetAttribute("SecretHub") end) return ok and v == true end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local function unitOr(v, fb) if v.Magnitude < 1e-3 then return fb end return v.Unit end
    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        pcall(function() o:SetAttribute("SecretHub", true) end)
        o.Parent = parent
        return o
    end
    local function strength() return math.clamp(tonumber(settings.puppetStrength) or 60, 0, 100) / 100 end
    local VIM
    pcall(function() VIM = game:GetService("VirtualInputManager") end)
    local lastUserKey = -10
    bind(UserInputService.InputBegan:Connect(function(i, gp)
        if i.UserInputType == Enum.UserInputType.Keyboard or i.UserInputType == Enum.UserInputType.Touch then lastUserKey = now() end
    end))

    -- shared raycast params (own character, hub parts and other characters are ignored)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local rpAcc = -1
    local function refreshRp()
        if now() - rpAcc < 0.5 then return end
        rpAcc = now()
        local ex = {gui}
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
        for _, h in ipairs(CORE.hands and CORE.hands.state and CORE.hands.state.list or {}) do if h.model then ex[#ex + 1] = h.model end end
        if CORE.waterPlat then ex[#ex + 1] = CORE.waterPlat end
        rp.FilterDescendantsInstances = ex
    end
    local function cast(from, dir) refreshRp() return workspace:Raycast(from, dir, rp) end
    local function hazardHit(res) return res and res.Instance and res.Instance:IsA("BasePart") and brain.isHazard and brain.isHazard(res.Instance) end

    -- =================================================================
    -- life: one respawn pipeline
    -- =================================================================
    local function fireChar(c, first)
        CORE.life.gen += 1
        CORE.resetJobs()
        local n = 0
        for name, fn in pairs(CORE.life.handlers) do
            n += 1
            local ok, e = pcall(fn, c)
            if not ok then CORE.log("ERR", "respawn '" .. name .. "': " .. tostring(e)) end
        end
        CORE.log("LIFE", (first and "character found" or ("respawn #" .. CORE.life.gen)) .. " · " .. n .. " modules re-bound")
        if not first then task.delay(1.2, function() if alive then say("respawn") end end) end
    end
    local function hookDied(c)
        task.spawn(function()
            local h = c:WaitForChild("Humanoid", 10)
            if not (h and alive) then return end
            bind(h.Died:Connect(function()
                CORE.log("LIFE", "died")
                for name, fn in pairs(CORE.life.died) do
                    local ok, e = pcall(fn)
                    if not ok then CORE.log("ERR", "died '" .. name .. "': " .. tostring(e)) end
                end
            end))
        end)
    end
    bind(LP.CharacterAdded:Connect(function(c)
        hookDied(c)
        task.spawn(function()
            c:WaitForChild("HumanoidRootPart", 10)
            c:WaitForChild("Humanoid", 10)
            task.wait(0.25)
            if alive and LP.Character == c then fireChar(c, false) end
        end)
    end))

    -- =================================================================
    -- sense: predictive threat sensor
    -- =================================================================
    SEN.active = true
    SEN.list, SEN.combat, SEN.top, SEN.alertUntil = {}, false, nil, 0
    SEN.lastHitT, SEN.lastHitAmt, SEN.lastEvadeT = -10, 0, -10
    SEN.stats = {imminent = 0, evaded = 0, hitAnyway = 0, hits = 0, projectiles = 0}
    SEN.listeners = {}
    function SEN.on(name, fn) SEN.listeners[name] = fn end
    local function emit(kind, ev)
        ev.kind = kind
        for name, fn in pairs(SEN.listeners) do
            local ok, e = pcall(fn, ev)
            if not ok then CORE.log("ERR", "sense '" .. name .. "': " .. tostring(e)) end
        end
    end
    local ATTACK = {"attack", "punch", "slash", "swing", "hit", "combo", "kick", "m1", "skill", "shoot", "cast", "smash", "strike", "stab",
        "slam", "throw", "fire", "blast", "lunge", "charge", "heavy", "light", "melee", "sword", "katana", "fist", "spin", "uppercut", "z", "x", "c", "v"}
    local CALM = {"idle", "walk", "run", "jump", "fall", "climb", "swim", "sit", "emote", "dance", "pose", "equip", "hold", "land", "sprint", "breath",
        "wave", "talk", "greet", "point", "cheer", "laugh", "nod", "look", "sleep", "work", "shop", "dialog", "think", "clap"}
    -- 4.2: word-aware matching. CamelCase is split first ("SwordHit1" -> "sword hit1"); short words (<= 5)
    -- must start a word, so "white", "spotlight" or "campfire" no longer read as attacks
    local function animWords(raw)
        raw = tostring(raw or "")
        raw = string.gsub(raw, "(%l)(%u)", "%1 %2")
        raw = string.gsub(raw, "(%d)(%a)", "%1 %2")
        raw = string.gsub(raw, "[_%-%.]", " ")
        return " " .. string.lower(raw) .. " "
    end
    local function hasWord(s, list)
        for _, w in ipairs(list) do
            if #w <= 2 then
                if string.find(s, "%f[%w]" .. w .. "%f[%W]") then return true end
            elseif #w <= 5 then
                if string.find(s, "%f[%a]" .. w) then return true end
            elseif string.find(s, w, 1, true) then return true end
        end
        return false
    end
    -- V2.3: hit reactions ("Hit", "GetHit", "Hurt", "Stun") are NOT attacks. In Blox Fruits every mob you
    -- hit plays one, and the old matcher read it as a wind-up, so your own combo made the Guardian dodge.
    local HURT = {"hurt", "damage", "damaged", "stagger", "stun", "stunned", "flinch", "knock", "react", "reaction", "ouch", "death", "dying", "dead", "ragdoll", "block", "parry", "recoil"}
    local function hurtWord(nm)
        return hasWord(nm, HURT) or string.find(nm, "get hit", 1, true) ~= nil or string.find(nm, "got hit", 1, true) ~= nil
            or string.find(nm, "take hit", 1, true) ~= nil or string.find(nm, "hit react", 1, true) ~= nil
    end
    -- V2.3: YOUR attacks (click, skill keys, tool swing, attack animation on your character) are tracked,
    -- so your own swings, hitboxes and effects are never read as a threat
    SEN.userAtkT = -10
    function SEN.userAttacking(win) return now() - (SEN.userAtkT or -10) < (win or 0.4) end
    local ATK_KEYS = {Z = true, X = true, C = true, V = true, F = true}
    bind(UserInputService.InputBegan:Connect(function(i, gp)
        -- V2.4 (phones): the attack / skill buttons and tap-to-attack sit on the right side of the screen.
        -- A touch there is your attack (the joystick is on the left), so your own Blox Fruits M1 / skills
        -- are no longer read as an incoming attack on mobile either.
        if i.UserInputType == Enum.UserInputType.Touch then
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize
            if vs and i.Position.X > vs.X * 0.45 and i.Position.Y > vs.Y * 0.3 then SEN.userAtkT = now() end
            return
        end
        if gp then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 then SEN.userAtkT = now()
        elseif i.UserInputType == Enum.UserInputType.Keyboard and ATK_KEYS[i.KeyCode.Name] then SEN.userAtkT = now() end
    end))
    local atkHum
    local toolHooked = setmetatable({}, {__mode = "k"})
    local function hookUserAtk(h)
        atkHum = h
        local an = h:FindFirstChildOfClass("Animator")
        if an then
            bind(an.AnimationPlayed:Connect(function(tr)
                if atkHum ~= h then return end
                local ok, looped, pr = pcall(function() return tr.Looped, tr.Priority end)
                if not ok or looped or now() - SEN.lastHitT < 0.2 then return end   -- your own hit reaction, not an attack
                local nm = animWords(tostring(tr.Name) .. " " .. tostring(tr.Animation and tr.Animation.Name or ""))
                if hasWord(nm, CALM) or hurtWord(nm) then return end
                if hasWord(nm, ATTACK) or pr == Enum.AnimationPriority.Action or pr == Enum.AnimationPriority.Action2
                    or pr == Enum.AnimationPriority.Action3 or pr == Enum.AnimationPriority.Action4 then SEN.userAtkT = now() end
            end))
        end
        local function tool(t)
            if t:IsA("Tool") and not toolHooked[t] then toolHooked[t] = true bind(t.Activated:Connect(function() SEN.userAtkT = now() end)) end
        end
        local c = h.Parent
        if c then
            for _, t in ipairs(c:GetChildren()) do tool(t) end
            bind(c.ChildAdded:Connect(function(t) if atkHum == h then tool(t) end end))
        end
    end
    local cands = {}           -- model -> info
    local ov
    pcall(function() ov = OverlapParams.new() ov.FilterType = Enum.RaycastFilterType.Exclude ov.MaxParts = 160 end)
    local function consider(m, plr, me, R, seen, enemy)
        if seen[m] or m == LP.Character then return end
        seen[m] = true
        local h = m:FindFirstChildOfClass("Humanoid")
        local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
        if not (h and root and h.Health > 0) then return end
        if (root.Position - me).Magnitude > R then return end
        local info = cands[m]
        if not info then
            info = {model = m, hum = h, root = root, player = plr, tracks = setmetatable({}, {__mode = "k"}), windupAt = -10, lastHitAt = -10,
                hits = 0, reach = nil, early = 0, prevPos = root.Position, vel = Vector3.zero, animAt = 0, firedAt = -10,
                name = plr and plr.DisplayName or tostring(m.Name), key = plr and ("p:" .. plr.UserId) or ("n:" .. string.sub(string.lower(m.Name), 1, 24))}
            cands[m] = info
        end
        info.hum, info.root, info.seen = h, root, now()
        if enemy then info.enemy = true end
    end
    local function collect()
        local r = hrp()
        if not r then return end
        local me = r.Position
        local R = lite() and 55 or 80
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and p.Character then consider(p.Character, p, me, R, seen) end end
        local mod = GAMEINFO and GAMEINFO.module
        local any = false
        if mod and type(mod.npcFolders) == "table" then
            for _, fname in ipairs(mod.npcFolders) do
                local f = workspace:FindFirstChild(fname)
                if f then
                    any = true
                    for i, m in ipairs(f:GetChildren()) do
                        if i > 400 then break end
                        if m:IsA("Model") then consider(m, nil, me, R, seen, true) end
                    end
                end
            end
        end
        if not any and ov then
            ov.FilterDescendantsInstances = {char(), gui}
            local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(me, lite() and 35 or 45, ov) end)
            if ok then
                for _, part in ipairs(parts) do
                    local m = part.Parent
                    if m and m:IsA("Model") and not seen[m] and m ~= workspace then
                        if m:FindFirstChildOfClass("Humanoid") then consider(m, Players:GetPlayerFromCharacter(m), me, R, seen)
                        elseif m.Parent and m.Parent:IsA("Model") and m.Parent:FindFirstChildOfClass("Humanoid") then
                            consider(m.Parent, Players:GetPlayerFromCharacter(m.Parent), me, R, seen)
                        end
                    end
                end
            end
        end
        for m, info in pairs(cands) do if not seen[m] and now() - (info.seen or 0) > 1.5 then cands[m] = nil end end
    end
    local function animScan(info, t)
        local an = info.hum:FindFirstChildOfClass("Animator")
        if not an then return end
        local ok, tracks = pcall(an.GetPlayingAnimationTracks, an)
        if not ok then return end
        local seenTracks = {}
        for _, tr in ipairs(tracks) do
            local tp = tr.TimePosition
            local prev = info.tracks[tr]
            seenTracks[tr] = tp
            if (prev == nil or tp < prev - 0.05) and not tr.Looped then
                local nm = animWords(tostring(tr.Name) .. " " .. tostring(tr.Animation and tr.Animation.Name or ""))
                local calm = hasWord(nm, CALM) or hurtWord(nm)
                local attack = hasWord(nm, ATTACK) and not (calm and not hasWord(nm, {"attack", "slash", "punch", "strike", "skill"}))
                if not attack and not calm then
                    local pr = tr.Priority
                    attack = pr == Enum.AnimationPriority.Action or pr == Enum.AnimationPriority.Action2
                        or pr == Enum.AnimationPriority.Action3 or pr == Enum.AnimationPriority.Action4
                    -- a priority-only guess never counts while you are hitting this NPC yourself
                    if attack and SEN.userAttacking(0.5) and (info.dist or 99) < 16 then attack = false end
                end
                -- the NPC just lost health: this animation is its reaction to YOUR hit
                if attack and (hurtWord(nm) or t - (info.hurtAt or -10) < 0.45) then attack = false end
                if attack then
                    info.windupAt = t info.windupLen = tr.Length
                    local aid = tostring(tr.Animation and tr.Animation.AnimationId or "")
                    info.windupAnim = (aid ~= "" and aid) or nm
                    info.windupName = nm
                    if not info.player then pcall(emit, "windup", {who = info, anim = info.windupAnim, name = nm, len = tr.Length, t = t}) end
                end
            end
        end
        info.tracks = seenTracks   -- stopped tracks drop out (no slow leak on long-lived NPCs)
    end
    -- V2.3: your own effects: spawned near you right after your own input, or named / tagged as yours
    local function ownFx(d, pos, me)
        if SEN.userAttacking(0.45) and (pos - me).Magnitude < 16 then return true end
        local nm = LP.Name
        local p = d
        for _ = 1, 4 do
            if not p or p == workspace then break end
            if string.find(p.Name, nm, 1, true) then return true end
            local okA, a = pcall(function() return p:GetAttribute("Owner") or p:GetAttribute("Creator") or p:GetAttribute("Caster") end)
            if okA and a ~= nil and (a == nm or tostring(a) == tostring(LP.UserId)) then return true end
            for _, tn in ipairs({"creator", "Creator", "Owner", "owner"}) do
                local v = p:FindFirstChild(tn)
                if v and ((v:IsA("ObjectValue") and (v.Value == LP or (LP.Character and v.Value == LP.Character))) or (v:IsA("StringValue") and v.Value == nm)) then return true end
            end
            p = p.Parent
        end
        return false
    end
    -- projectiles / hitboxes / explosions: new parts near you are watched for a few seconds
    local watch = {}
    local watchN = 0
    bind(workspace.DescendantAdded:Connect(function(d)
        if not alive then return end
        local cls = d.ClassName
        if cls == "Explosion" then
            task.defer(function()
                local r = hrp()
                local ok, pos, rad = pcall(function() return d.Position, d.BlastRadius end)
                if ok and r and pos and (pos - r.Position).Magnitude < (tonumber(rad) or 8) + 8 and not (SEN.userAttacking(0.5) and (pos - r.Position).Magnitude < 16) then
                    emit("imminent", {type = "explosion", pos = pos, dir = unitOr(flat(pos - r.Position), r.CFrame.LookVector), eta = 0, size = tonumber(rad) or 8})
                end
            end)
            return
        end
        if not d:IsA("BasePart") then return end
        task.defer(function()
            if not d.Parent or isOurs(d) then return end
            local c = char()
            if c and d:IsDescendantOf(c) then return end
            -- body parts of a (re)spawning character are not projectiles
            local pm = d.Parent
            if pm and pm:IsA("Model") and pm:FindFirstChildOfClass("Humanoid") then return end
            local r = hrp()
            if not r then return end
            local ok, pos, size = pcall(function() return d.Position, d.Size end)
            if not ok or size.Magnitude > 90 or (pos - r.Position).Magnitude > 110 then return end
            if ownFx(d, pos, r.Position) then return end
            if watchN >= 70 then return end
            watchN += 1
            watch[d] = {t0 = now(), prev = pos, size = size.Magnitude, grow = size.Magnitude}
        end)
    end))
    local function hostileNear(radius)
        for _, info in pairs(cands) do if info.hostile and info.dist and info.dist < radius then return info end end
        return nil
    end
    local function scanWatch(me, dt, t)
        for p, w in pairs(watch) do
            local age = t - w.t0
            if age > 3 or not p.Parent then watch[p] = nil watchN -= 1
            else
                local pos = p.Position
                local v = (pos - w.prev) / math.max(dt, 1 / 240)
                w.prev = pos
                local av = p.AssemblyLinearVelocity
                if av.Magnitude > v.Magnitude then v = av end
                local sp = v.Magnitude
                local rel = me - pos
                if sp > 28 and not w.fired then
                    local tt = rel:Dot(v) / (sp * sp)
                    local miss = (rel - v * tt).Magnitude
                    if tt > 0 and tt < 0.75 and miss < 4.5 + w.size * 0.5 then
                        w.fired = true
                        SEN.stats.projectiles += 1
                        emit("imminent", {type = "projectile", pos = pos, vel = v, dir = unitOr(-rel, Vector3.new(0, 0, -1)), eta = tt, size = w.size, part = p})
                    end
                elseif age < 0.2 and not w.fired and w.size > 3 and rel.Magnitude < w.size * 0.55 + 3 and not SEN.userAttacking(0.45) then
                    -- a hitbox appeared on top of you while someone hostile is close
                    local info = hostileNear(30)
                    if info and (p.Transparency > 0.3 or not p.CanCollide) then
                        w.fired = true
                        emit("imminent", {type = "hitbox", pos = pos, dir = unitOr(flat(pos - me), Vector3.new(0, 0, -1)), eta = 0, size = w.size, who = info})
                    end
                end
                local sz = p.Size.Magnitude
                if not w.fired and sz > w.grow * 1.25 and sz > 6 and rel.Magnitude < sz * 0.5 + 10 and not SEN.userAttacking(0.45) then
                    w.fired = true
                    emit("imminent", {type = "aoe", pos = pos, dir = unitOr(flat(pos - me), Vector3.new(0, 0, -1)), eta = 0.1, size = sz})
                end
                w.grow = math.max(w.grow, sz)
            end
        end
    end
    local collectAcc, senseAcc = 9, 0
    local wasCombat = false
    onHeartbeat("sense41", function(dt)
        senseAcc += dt
        if senseAcc < (lite() and 1 / 20 or 1 / 60) then return end
        local step = senseAcc
        senseAcc = 0
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 then SEN.combat = false SEN.top = nil return end
        local t = now()
        collectAcc += step
        if collectAcc > (lite() and 0.5 or 0.33) then collectAcc = 0 collect() end
        local me = r.Position
        local top, topScore, hostiles = nil, 0, 0
        local list = {}
        for m, info in pairs(cands) do
            local root = info.root
            if not (root and root.Parent and info.hum.Health > 0) then cands[m] = nil
            else
                local pos = root.Position
                local v = (pos - info.prevPos) / math.max(step, 1 / 240)
                info.prevPos = pos
                local av = root.AssemblyLinearVelocity
                if av.Magnitude > v.Magnitude * 0.8 then v = av end
                info.vel = v
                local rel = me - pos
                local dist = rel.Magnitude
                local toMe = unitOr(flat(rel), Vector3.new(0, 0, 1))
                local facing = unitOr(flat(root.CFrame.LookVector), toMe):Dot(toMe)
                local closing = v:Dot(toMe)
                info.dist, info.facing, info.closing, info.toMe = dist, facing, closing, toMe
                local hpNow = info.hum.Health
                if info.hpSeen and hpNow < info.hpSeen - 0.01 then info.hurtAt = t end   -- V2.3: it was just hit
                info.hpSeen = hpNow
                if t - info.animAt > (lite() and 0.2 or 0.1) and dist < 45 then info.animAt = t animScan(info, t) end
                local reach = (info.reach or (info.player and 11 or 10)) + info.early * 10
                local wind = t - info.windupAt < 0.45
                local armed = info.player and info.model:FindFirstChildOfClass("Tool") ~= nil
                local recentHit = t - info.lastHitAt < 10
                local stalk = info.player and STK.isStalker and STK.isStalker(info.player)
                if info.player then
                    info.hostile = recentHit or stalk or (wind and facing > 0.5 and dist < 20)
                elseif info.enemy == true then
                    -- Known enemy folders (e.g. Blox Fruits Enemies): combatants when close / winding / chasing
                    info.hostile = recentHit or (wind and facing > 0.35 and dist < 26)
                        or (dist < 22 and facing > 0.6) or (closing > 8 and facing > 0.7 and dist < 20)
                else
                    -- Shop / quest / ambient NPCs: NEVER hostile from idle Action anims alone.
                    -- Only after they hit you, chase hard, or wind up while already closing in.
                    info.hostile = recentHit
                        or (wind and facing > 0.5 and dist < 14 and closing > 3)
                        or (closing > 12 and facing > 0.8 and dist < 14)
                end
                local danger = 0
                local why
                -- Danger only for hostiles (or armed players lunging). Neutral NPCs walking /
                -- facing you must never trigger dodge — that was "thinking" with shopkeepers.
                if wind and dist < reach + 5 and facing > 0.35 and info.hostile then danger, why = 1, "attack"
                elseif closing > 32 and dist < 16 + closing * 0.12 and facing > 0.2
                    and (info.hostile or (info.player and armed)) then danger, why = 1, "lunge"
                elseif recentHit and dist < reach + 2 and facing > 0.6 and t - info.lastHitAt < 1.6 then danger, why = 0.8, "combo"
                elseif info.hostile and dist < 25 and facing > 0.5 and closing > 4 then danger, why = 0.4, "approach" end
                info.danger = danger
                if info.hostile then hostiles += 1 end
                local score = danger * 3 + (info.hostile and 1 or 0) + math.max(0, 1 - dist / 40)
                if info.hostile and score > topScore then top, topScore = info, score end
                if danger >= 0.4 then SEN.alertUntil = math.max(SEN.alertUntil, t + 0.4) end
                if danger >= 0.8 and t - info.firedAt > 0.5 then
                    info.firedAt = t
                    SEN.stats.imminent += 1
                    local eta = (why == "lunge") and math.max(0, (dist - reach) / math.max(closing, 1)) or 0.15
                    emit("imminent", {type = why, pos = pos, vel = v, dir = -toMe, eta = eta, who = info, dist = dist})
                end
                list[#list + 1] = info
            end
        end
        SEN.list = list
        SEN.top = top
        SEN.hostiles = hostiles
        SEN.combat = (top ~= nil and top.dist < 32) or (t - SEN.lastHitT < 4)
        if SEN.combat ~= wasCombat then
            wasCombat = SEN.combat
            emit(SEN.combat and "combat_start" or "combat_end", {who = top})
        end
        scanWatch(me, step, t)
    end)
    -- damage attribution: who hit you (closest facing hostile with a fresh wind-up wins)
    local hpHooked, hpLast
    local function onHp(hp)
        local h = hum()
        if not h then return end
        local prev = hpLast or hp
        hpLast = hp
        if hp >= prev - 0.05 then return end
        local t = now()
        SEN.lastHitT, SEN.lastHitAmt = t, prev - hp
        SEN.stats.hits += 1
        if t - SEN.lastEvadeT < 0.7 then SEN.stats.hitAnyway += 1 end
        local best, bs
        for _, info in pairs(cands) do
            if info.dist and info.dist < (info.reach or 12) + 14 then
                local s = (info.facing or 0) + ((t - info.windupAt < 1.2) and 2 or 0) + (1 - info.dist / 40)
                if not bs or s > bs then best, bs = info, s end
            end
        end
        local lh = brain.lastHit
        if type(lh) == "table" and lh.attacker and t - (lh.t or 0) < 0.3 and lh.attacker.Character and cands[lh.attacker.Character] then
            best = cands[lh.attacker.Character]
        end
        if best then
            best.lastHitAt = t
            best.hits += 1
            best.lastAmt = math.max(prev - hp, (best.lastAmt or 0) * 0.7)
            local d = best.dist or 10
            best.reach = best.reach and math.max(best.reach * 0.8 + d * 0.2, d * 0.9) or math.max(d, 6)
            if t - SEN.lastEvadeT < 0.7 then best.early = math.min(best.early + 0.06, 0.4) end
        end
        SEN.lastHitWho = best
        emit("hit", {amount = prev - hp, who = best, hp = hp, max = h.MaxHealth})
        -- Mirror Ward: counter with verified damage remotes (only if their HP actually drops)
        if settings.ovrMirror == true and CORE.forge and CORE.forge.mirror then
            task.defer(function() pcall(CORE.forge.mirror, best, prev - hp) end)
        end
    end
    CORE.onChar("sense", function(c)
        -- 4.2 fix: close an open fight properly so hands / voice / puppeteer leave combat mode after a respawn
        if SEN.combat then pcall(emit, "combat_end", {reason = "respawn"}) end
        cands, watch, watchN = {}, {}, 0
        SEN.combat, SEN.top, SEN.lastHitT = false, nil, -10
        hpHooked, hpLast = nil, nil
    end)
    onHeartbeat("sense41hp", function()
        local h = hum()
        if h and atkHum ~= h then pcall(hookUserAtk, h) end
        if h and hpHooked ~= h then
            hpHooked = h
            hpLast = h.Health
            bind(h.HealthChanged:Connect(function(hp) if alive and hpHooked == h then onHp(hp) end end))
        end
    end)

    -- =================================================================
    -- move: physics movement controller
    -- =================================================================
    MOV.steer = Vector3.zero
    MOV.carrying = false
    local ctl = {char = nil}
    local function dropCtl()
        for _, k in ipairs({"lv", "ap", "att"}) do if ctl[k] then pcall(function() ctl[k]:Destroy() end) ctl[k] = nil end end
        ctl.char = nil
    end
    local function ensureCtl()
        local r, c = hrp(), char()
        if not (r and c) then return nil end
        if ctl.char == c and ctl.att and ctl.att.Parent == r then return ctl end
        dropCtl()
        ctl.char = c
        ctl.att = mk("Attachment", {Name = "SecretMoveAtt"}, r)
        pcall(function()
            ctl.lv = mk("LinearVelocity", {Name = "SecretSteer", Attachment0 = ctl.att, RelativeTo = Enum.ActuatorRelativeTo.World,
                VelocityConstraintMode = Enum.VelocityConstraintMode.Plane, PrimaryTangentAxis = Vector3.xAxis, SecondaryTangentAxis = Vector3.zAxis,
                MaxForce = 0, Enabled = false}, r)
        end)
        pcall(function()
            ctl.ap = mk("AlignPosition", {Name = "SecretCarry", Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = ctl.att,
                MaxForce = 0, MaxVelocity = 120, Responsiveness = 60, Enabled = false}, r)
        end)
        return ctl
    end
    local wants = {}
    function MOV.want(name, prio, vel, ttl) wants[name] = {p = prio, v = vel, u = now() + (ttl or 0.15), name = name} end
    function MOV.clear(name) wants[name] = nil end
    function MOV.active() for _, w in pairs(wants) do if now() < w.u then return w.name end end return nil end
    local function idleCtl()
        if ctl.lv and ctl.lv.Enabled then ctl.lv.Enabled = false ctl.lv.MaxForce = 0 end
        MOV.steer = Vector3.zero
    end
    onHeartbeat("move41", function()
        if MOV.carrying then return end
        local t = now()
        local best
        for n, w in pairs(wants) do
            if t > w.u then wants[n] = nil elseif not best or w.p > best.p then best = w end
        end
        if not best then idleCtl() return end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or h.Sit or settings.fly or settings.freecam or FX.inSafe() or HUB.rescueBusy then idleCtl() return end
        local v = flat(best.v)
        local md = h.MoveDirection
        if best.p < 80 and md.Magnitude > 0.1 then
            local s = strength()
            v = v * (0.35 + 0.45 * s) + md * h.WalkSpeed * (0.85 - 0.5 * s)   -- your joystick always keeps a say
        end
        if v.Magnitude > 110 then v = v.Unit * 110 end
        local k = ensureCtl()
        if k and k.lv and not broken("move_physics") then
            k.lv.MaxForce = math.max(r.AssemblyMass, 8) * 1100
            k.lv.PlaneVelocity = Vector2.new(v.X, v.Z)
            if not k.lv.Enabled then k.lv.Enabled = true end
        else
            r.AssemblyLinearVelocity = Vector3.new(v.X, r.AssemblyLinearVelocity.Y, v.Z)
        end
        MOV.steer = v
        if brain.ownMove then brain.ownMove() end
    end)
    local function floorAt(pos)
        local res = cast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -22, 0))
        if not res or hazardHit(res) then return nil end
        if res.Material == Enum.Material.Water and not settings.walkwater then return nil end
        return res
    end
    -- sidestep: physical burst, wall + floor aware; returns the chosen direction or nil
    function MOV.evade(dirs, dist, opts)
        opts = opts or {}
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or MOV.carrying or HUB.rescueBusy then return nil end
        local me = r.Position
        for _, d in ipairs(dirs) do
            d = unitOr(flat(d), nil)
            if d then
                local wall = cast(me, d * (dist + 2))
                local reach = wall and ((wall.Position - me).Magnitude - 2) or dist
                if reach >= dist * 0.6 and floorAt(me + d * reach) then
                    local speed = math.clamp(reach / 0.2, 45, 95)
                    MOV.want("evade", 90, d * speed, reach / speed)
                    if opts.hop then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 24, r.AssemblyLinearVelocity.Z) end
                    SEN.lastEvadeT = now()
                    if VFX.slashTrail and not opts.quiet then pcall(VFX.slashTrail, me, me + d * reach) end
                    return d, reach
                end
            end
        end
        return nil
    end
    function MOV.dashTo(target)
        local r = hrp()
        if not r then return 0 end
        local d = flat(target - r.Position)
        if d.Magnitude < 1 then return 0 end
        local dd, reach = MOV.evade({d}, d.Magnitude)
        return dd and (reach / math.clamp(reach / 0.2, 45, 95)) or 0
    end
    -- smooth carry along pointAt(u) (u 0..1); yields until done; returns true when it arrived
    function MOV.carry(pointAt, dist, onStep)
        local k = ensureCtl()
        local r = hrp()
        if not (k and k.ap and r) then return false end
        MOV.carrying = true
        if k.lv then k.lv.Enabled = false end
        local dur = math.clamp(dist / 85, 0.35, 1.7)
        k.ap.MaxForce = math.max(r.AssemblyMass, 8) * 6000
        k.ap.MaxVelocity = math.clamp(dist / dur * 2, 60, 200)
        k.ap.Responsiveness = 90
        k.ap.Position = pointAt(0)
        k.ap.Enabled = true
        local t0 = now()
        local ok = pcall(function()
            while alive and r.Parent do
                local u = math.min(1, (now() - t0) / dur)
                local e = (u < 0.5) and (2 * u * u) or (1 - (-2 * u + 2) ^ 2 / 2)
                k.ap.Position = pointAt(e)
                if onStep then onStep(r.Position) end
                if brain.ownMove then brain.ownMove() end
                if u >= 1 then break end
                SVC.RunService.Heartbeat:Wait()
            end
            local final = pointAt(1)
            local t1 = now()
            while alive and r.Parent and (r.Position - final).Magnitude > 2.5 and now() - t1 < 0.35 do
                if onStep then onStep(r.Position) end
                SVC.RunService.Heartbeat:Wait()
            end
        end)
        local final = pointAt(1)
        local reached = ok and r.Parent ~= nil and (r.Position - final).Magnitude < 6
        pcall(function() k.ap.Enabled = false k.ap.MaxForce = 0 end)
        pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
        MOV.carrying = false
        report("move_physics", reached, "Physics carry (Guardian Control)")
        return reached
    end
    CORE.onChar("move", function() wants = {} MOV.carrying = false MOV.steer = Vector3.zero dropCtl() end)
    CORE.onDied("move", function() wants = {} idleCtl() end)
    onUnload(function() wants = {} MOV.carrying = false dropCtl() end)

    -- =================================================================
    -- predictive dodge: reacts to sense "imminent" BEFORE the hit lands
    -- =================================================================
    local lastEvade, lastDodgeSay = -10, -10
    local strafeSign, strafeFlip = 1, 0
    local function pickSide(dirToThreat)
        local r, h = hrp(), hum()
        local perp = unitOr(flat(Vector3.yAxis:Cross(dirToThreat)), Vector3.new(1, 0, 0))
        local s = strafeSign
        -- prefer the side you are already moving to, and away from other hostiles
        if h and h.MoveDirection.Magnitude > 0.2 then s = (h.MoveDirection:Dot(perp) >= 0) and 1 or -1 end
        local me = r and r.Position
        if me then
            local bias = 0
            for _, info in ipairs(SEN.list) do
                if info.hostile and info.dist and info.dist < 30 then bias += perp:Dot(unitOr(flat(info.root.Position - me), perp)) end
            end
            if math.abs(bias) > 0.5 then s = (bias > 0) and -1 or 1 end
        end
        return perp * s, -perp * s
    end
    SEN.on("dodge", function(ev)
        if ev.kind ~= "imminent" then return end
        local t = now()
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or FX.inSafe() then return end
        -- V2.3: never dodge while you are attacking (your input + 0.4 s), unless this one would be lethal
        if SEN.userAttacking(0.4) then
            local lethal = h.Health < h.MaxHealth * 0.3 or (ev.who ~= nil and (ev.who.lastAmt or 0) >= h.Health * 0.8)
            if not lethal then return end
        end
        if settings.handsOn == true and VFX.handsMode then
            if ev.type == "projectile" then VFX.handsMode("push", {pos = ev.pos, dir = ev.dir}, 0.45)
            else VFX.handsMode("shield", {dir = ev.dir}, 0.4) end
        end
        if CORE.sight and CORE.sight.flash then pcall(CORE.sight.flash, ev) end
        if not settings.autododge or MOV.carrying or HUB.rescueBusy then return end
        if ev.who and (ev.who.choreoUntil or 0) > t then return end   -- 4.3: Boss Choreography times this one itself
        if t - lastEvade < 0.45 then return end
        lastEvade = t
        -- your own dash / block first (when Ability Assist is on), physics sidestep otherwise
        local used = ABI.react and ABI.react(ev)
        if used == "block" then return end
        -- projectiles: step across their flight line; melee: across the line to the attacker
        local axis = ev.dir
        if ev.type == "projectile" and ev.vel and flat(ev.vel).Magnitude > 1 then axis = flat(ev.vel).Unit end
        local a, b = pickSide(axis)
        local dist, dirs, hop = 9, {a, b, -ev.dir}, false
        if ev.type == "lunge" then dist = 12
        elseif ev.type == "projectile" then dist = math.clamp(6 + (ev.size or 2), 7, 16)
        elseif ev.type == "hitbox" or ev.type == "aoe" then dist = math.clamp((ev.size or 8) * 0.55 + 6, 9, 26) dirs = {-ev.dir, a, b}
        elseif ev.type == "explosion" then dist = math.clamp((ev.size or 8) + 6, 10, 30) dirs = {-ev.dir, a, b} hop = true end
        if ev.who and ev.who.early then dist += ev.who.early * 12 end
        if settings.puppetStyle == "Duelist" and (ev.type == "attack" or ev.type == "combo") then dist = math.max(7, dist - 2) end
        local from = r.Position
        local d
        if used ~= "dash" then d = MOV.evade(dirs, dist, {hop = hop}) end
        if not d and used ~= "dash" then return end
        if VFX.dodge then pcall(VFX.dodge, from) end
        if used == "dash" and VFX.slashTrail then
            task.delay(0.22, function() local rr = hrp() if rr and alive then pcall(VFX.slashTrail, from, rr.Position) end end)
        end
        local hp0 = h.Health
        task.delay(0.6, function()
            if not alive then return end
            local hh = hum()
            local clean = hh and hh.Health > 0 and SEN.lastHitT < t + 0.02 and hh.Health >= hp0 - 0.5
            if not clean then return end
            SEN.stats.evaded += 1
            if GG.avoided then GG.avoided() end
            if now() - lastDodgeSay > 4 then
                lastDodgeSay = now()
                say("dodge_pred", {name = ev.who and ev.who.name or nil})
            end
            -- public taunt only for a verified dodge against a real player
            if ev.who and ev.who.player and VFX.taunt then pcall(VFX.taunt, "read", ev.who.name) end
        end)
    end)

    -- =================================================================
    -- Puppeteer Mode: continuous steering in combat + soft fall catch
    -- =================================================================
    local catchSaid = 0
    onHeartbeat("puppet41", function()
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or MOV.carrying or HUB.rescueBusy then return end
        local t = now()
        -- soft catch: a long fall onto real ground gets slowed by the hands (void is handled by Predictive Rescue)
        local v = r.AssemblyLinearVelocity
        if settings.catchFall ~= false and settings.handsOn == true and v.Y < -75 and not settings.fly then
            local g = cast(r.Position, Vector3.new(0, -math.max(-v.Y * 0.45, 30), 0))
            if g and not hazardHit(g) and r.Position.Y - g.Position.Y < 40 then
                r.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, -28), v.Z)
                if VFX.handsMode then VFX.handsMode("catch", nil, 0.7) end
                if t - catchSaid > 5 then catchSaid = t say("catch_fall") end
            end
        end
        if settings.puppetMove ~= true or not SEN.combat then MOV.clear("puppet") return end
        local top = SEN.top
        if not (top and top.root and top.root.Parent and top.dist) then MOV.clear("puppet") return end
        local me = r.Position
        local away = unitOr(flat(me - top.root.Position), Vector3.new(0, 0, 1))
        local tangent = Vector3.yAxis:Cross(away)
        if t > strafeFlip then strafeSign = -strafeSign strafeFlip = t + 1.3 + math.random() * 1.1 end
        -- turn the strafe around before a wall
        -- 4.2 fix: only flip when the other side is open; walls on both sides (corridor) = no strafe instead of jitter
        local boxed = false
        if cast(me, tangent * strafeSign * 6) then
            if not cast(me, -tangent * strafeSign * 6) then strafeSign = -strafeSign strafeFlip = t + 1.2 else boxed = true end
        end
        local s = strength()
        local style = settings.puppetStyle or "Duelist"
        local want = (style == "Kite") and 32 or ((style == "Evasive") and 18 or nil)
        local hp = h.Health / math.max(h.MaxHealth, 1)
        local recovering = hp < math.clamp((tonumber(settings.rescueThreshold) or 35) / 100 + 0.15, 0.25, 0.85)
        if recovering then
            -- V2.3: the Lifeline does the real evacuation (and says so); this only keeps extra distance in between
            if CORE.lifeline and CORE.lifeline.phase ~= "idle" then MOV.clear("puppet") return end
            want = math.max(want or 0, 40)
        end
        local radial = want and math.clamp((want - top.dist) * 2.5, -14, 24) or 0
        local strafe = boxed and 0 or ((style == "Duelist") and 9 or 13) * strafeSign
        if top.danger and top.danger >= 0.4 then strafe *= 1.5 end
        MOV.want("puppet", recovering and 60 or 40, (away * radial + tangent * strafe) * (0.4 + 0.8 * s), 0.2)
    end)

    -- =================================================================
    -- abil: your own abilities (scan, classify, use at the right moment, verify)
    -- =================================================================
    ABI.list, ABI.remotes, ABI.log = {}, {}, {}
    local KINDS = {
        {"heal", {"heal", "medic", "medkit", "bandage", "potion", "food", "apple", "burger", "drink", "cola", "pizza", "candy", "regen", "cure", "bloxy", "snack", "elixir"}},
        {"shield", {"shield", "barrier", "armor", "armour", "guard", "protect", "bubble", "forcefield", "aegis"}},
        {"block", {"block", "parry", "deflect", "counter"}},
        {"dash", {"dash", "flash", "soru", "blink", "dodge", "roll", "evade", "warp"}},
        {"flight", {"fly", "flight", "wing", "wings", "glider", "jetpack", "geppo", "levitate", "hover"}},
        {"speed", {"speed", "sprint", "boost", "haste", "coffee"}},
        {"teleport", {"teleport", "recall", "portal"}},
        -- 5.6: attack / combat tools & skills (universal — any game)
        {"attack", {"attack", "slash", "strike", "sword", "gun", "punch", "blast", "beam", "shot", "skill", "ability", "smash",
            "burst", "fire", "ice", "lightning", "dark", "light", "magic", "spell", "combo", "finisher", "ult", "ultimate",
            "rage", "melee", "weapon", "blade", "katana", "rifle", "pistol", "bow", "staff", "fist", "claw", "hammer"}},
    }
    local function classify(s)
        s = animWords(s)
        for _, k in ipairs(KINDS) do if hasWord(s, k[2]) then return k[1] end end
        return nil
    end
    local function keyCode(k)
        if type(k) ~= "string" or k == "" then return nil end
        if #k == 1 then k = string.upper(k) end
        local ok, v = pcall(function() return Enum.KeyCode[k] end)
        return ok and v or nil
    end
    local function keysFromModule()
        local out = {}
        local mod = GAMEINFO and GAMEINFO.module
        if mod and type(mod.abilities) == "table" then
            for _, a in ipairs(mod.abilities) do
                local key = settings["key_" .. a.id] or a.key
                if keyCode(key) then
                    out[#out + 1] = {kind = a.kind, label = a.label, src = "key", key = key, cd = a.cd or 2, id = a.id, toggle = a.toggle, hold = a.hold, last = -100}
                end
            end
        end
        return out
    end
    local lastUse = {}
    local function scan()
        local list = {}
        local function addTool(tl, where)
            if not tl:IsA("Tool") or GV.isFruitItem(tl) then return end
            local kind = classify(tl.Name .. " " .. tostring(tl.ToolTip))
            -- unclassified tools still count as attack candidates (every game names weapons differently)
            if not kind then kind = "attack" end
            list[#list + 1] = {kind = kind, label = tl.Name, src = "tool", ref = tl, where = where, cd = 3, last = lastUse[tl] or -100}
        end
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then for _, tl in ipairs(bp:GetChildren()) do addTool(tl, "Backpack") end end
        local c = char()
        if c then for _, tl in ipairs(c:GetChildren()) do addTool(tl, "equipped") end end
        for _, k in ipairs(keysFromModule()) do k.last = lastUse[k.id] or -100 list[#list + 1] = k end
        if settings.abilGui == true then
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            if pg then
                local n = 0
                for _, d in ipairs(pg:GetDescendants()) do
                    n += 1
                    if n > 6000 then break end
                    if d:IsA("GuiButton") and d.Visible and d.AbsoluteSize.X > 8 then
                        local txt = d.Name .. " " .. ((d:IsA("TextButton") and d.Text) or "")
                        local kind = classify(txt)
                        if kind and kind ~= "teleport" then
                            list[#list + 1] = {kind = kind, label = (d:IsA("TextButton") and d.Text ~= "" and d.Text) or d.Name, src = "gui", ref = d, cd = 3, last = lastUse[d] or -100}
                        end
                    end
                end
            end
        end
        ABI.list = list
    end
    local function scanRemotes()
        local out, n = {}, 0
        for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            n += 1
            if n > 8000 then break end
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local kind = classify(d.Name)
                if kind then out[#out + 1] = {kind = kind, label = d.Name} end
            end
        end
        ABI.remotes = out
    end
    function ABI.summary()
        local by = {}
        for _, a in ipairs(ABI.list) do by[a.kind] = (by[a.kind] or 0) + 1 end
        local parts = {}
        for _, k in ipairs(KINDS) do if by[k[1]] then parts[#parts + 1] = k[1] .. " " .. by[k[1]] end end
        if by.sense then parts[#parts + 1] = "sense " .. by.sense end
        return (#parts > 0) and table.concat(parts, " · ") or "none found yet"
    end
    function ABI.remoteSummary() return #ABI.remotes .. " named like abilities (listed only, never fired)" end
    function ABI.hasVIM() return VIM ~= nil end
    local function pressKey(key, hold)
        if not VIM then return false end
        local kc = keyCode(key)
        if not kc then return false end
        local ok = pcall(function() VIM:SendKeyEvent(true, kc, false, game) end)
        task.delay(hold or 0.06, function() pcall(function() VIM:SendKeyEvent(false, kc, false, game) end) end)
        return ok
    end
    local function clickGui(b)
        if not VIM then return false end
        return pcall(function()
            local inset = SVC.GuiService:GetGuiInset()
            local p = b.AbsolutePosition + b.AbsoluteSize / 2 + inset
            VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
            VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
        end)
    end
    local function logUse(a, ok)
        table.insert(ABI.log, 1, os.date("%H:%M:%S") .. "  " .. a.kind .. "  " .. a.label .. (ok and "" or "  (failed)"))
        if #ABI.log > 12 then table.remove(ABI.log) end
        CORE.log("ABIL", a.kind .. " · " .. a.label .. " · " .. a.src .. (ok and "" or " · failed"))
    end
    local function use(a)
        local t = now()
        if t - a.last < a.cd then return false end
        a.last = t
        lastUse[a.id or a.ref] = t
        local ok = false
        if a.src == "tool" then
            local h, c, tl = hum(), char(), a.ref
            if h and c and tl and tl.Parent then
                local prev = c:FindFirstChildOfClass("Tool")
                ok = pcall(function()
                    if tl.Parent ~= c then h:EquipTool(tl) end
                    task.delay(0.12, function() pcall(function() tl:Activate() end) end)
                end)
                if prev and prev ~= tl and a.kind ~= "shield" then
                    task.delay(1.1, function() pcall(function() if prev.Parent and h.Parent then h:EquipTool(prev) end end) end)
                end
            end
        elseif a.src == "key" then ok = pressKey(a.key, a.hold)
        elseif a.src == "gui" then ok = clickGui(a.ref) end
        logUse(a, ok)
        if ok then
            if t - (ABI.lastSay or 0) > 5 then ABI.lastSay = t say("ability", {name = a.label}) end
            ABI.lastUse = t
        end
        return ok
    end
    function ABI.recent(sec) return now() - (ABI.lastUse or -100) < (sec or 0.6) end
    local function firstReady(kind)
        local t = now()
        for _, a in ipairs(ABI.list) do if a.kind == kind and t - a.last >= a.cd then return a end end
        return nil
    end
    -- 4.3: shared with the PvE module (your own keys / tools only)
    ABI.pressKey, ABI.use, ABI.firstReady, ABI.keyCode = pressKey, use, firstReady, keyCode
    -- called by the predictive dodge; returns "dash" / "block" when your own ability handled it
    function ABI.react(ev)
        if settings.abilAssist ~= true then return nil end
        local r = hrp()
        if not r then return nil end
        local melee = ev.type == "attack" or ev.type == "combo" or ev.type == "lunge"
        local dash = firstReady("dash")
        if dash and ev.type ~= "explosion" then
            -- face across the attack line so the dash goes out of it, then fire your own dash
            local a = pickSide(ev.dir)
            pcall(function() r.CFrame = CFrame.new(r.Position, r.Position + a) end)
            local from = r.Position
            if use(dash) then
                task.delay(0.35, function()
                    local rr = hrp()
                    local moved = rr ~= nil and (rr.Position - from).Magnitude > 5
                    report("abil_dash", moved, "Ability Assist (dash: " .. dash.label .. ")")
                    if not moved then MOV.evade({a, -a}, 9) end
                end)
                return "dash"
            end
        end
        if melee then
            local blk = firstReady("block") or firstReady("shield")
            if blk and not blk.toggle and use(blk) then return "block" end
        end
        return nil
    end
    local abilAcc, scanAcc, remAcc = 0, 99, 40
    onHeartbeat("abil41", function(dt)
        scanAcc += dt remAcc += dt abilAcc += dt
        if scanAcc > ((settings.abilGui == true) and (lite() and 14 or 8) or 3) then scanAcc = 0 pcall(scan) end
        if remAcc > 45 then remAcc = 0 task.spawn(function() pcall(scanRemotes) end) end
        if abilAcc < 0.25 then return end
        abilAcc = 0
        if settings.abilAssist ~= true then return end
        local h = hum()
        if not h or h.Health <= 0 then return end
        local hp = h.Health / math.max(h.MaxHealth, 1)
        if hp < 0.45 then
            local heal = firstReady("heal")
            if heal and (now() - SEN.lastHitT > 0.8 or hp < 0.3) then
                local before = h.Health
                if use(heal) then
                    task.delay(2.5, function() local hh = hum() report("abil_heal", hh ~= nil and hh.Health > before + 1, "Ability Assist (heal: " .. heal.label .. ")") end)
                end
            end
        end
        if STK.activeCount and STK.activeCount() > 0 then
            local sp = firstReady("speed")
            if sp then use(sp) end
        end
    end)
    SEN.on("abil", function(ev)
        if ev.kind ~= "combat_start" or settings.abilAssist ~= true then return end
        for _, a in ipairs(ABI.list) do
            if a.toggle and a.kind == "sense" and now() - a.last > 40 then
                if use(a) then say("ken_on") end
            end
        end
        -- equip your best defensive tool when your hands are empty
        local c = char()
        if c and not c:FindFirstChildOfClass("Tool") then
            local sh = firstReady("shield")
            if sh and sh.src == "tool" then use(sh) end
        end
    end)
    CORE.onChar("abil", function() scanAcc = 99 end)

    -- =================================================================
    -- ggod: Guardian Godmode (avoidance based; the server still owns your health)
    -- =================================================================
    GG.stats = {kb = 0, ragdoll = 0, avoided = 0, held = 0, leaks = 0, antiHolds = 0, since = now()}
    local dmgLog = {}
    local guarded
    local MOVERS = {BodyVelocity = true, BodyPosition = true, BodyForce = true, BodyThrust = true, BodyAngularVelocity = true, BodyGyro = true,
        LinearVelocity = true, VectorForce = true, AngularVelocity = true, AlignPosition = true, LineForce = true}
    local KB_WORDS = {"knock", "push", "fling", "kb", "stun", "ragdoll", "launch", "blow", "knockback"}
    function GG.avoided() GG.stats.avoided += 1 end
    local function wantGuard()
        return settings.godmode == true or settings.antiDeath == true
    end
    local function dmg30()
        local t, s, n = now(), 0, 0
        for i = #dmgLog, 1, -1 do local d = dmgLog[i] if t - d.t > 30 then table.remove(dmgLog, i) else s += d.a n += 1 end end
        return s, n
    end
    function GG.status()
        if not wantGuard() then return "off" end
        local s, n = dmg30()
        local st = GG.stats
        local lead = (n == 0) and "no damage in 30 s" or string.format("%d dmg in 30 s (%d hits got through)", math.floor(s + 0.5), n)
        local ad = settings.antiDeath == true and (" · anti-death holding x" .. (st.antiHolds or 0)) or ""
        return lead .. " · " .. st.avoided .. " avoided · " .. st.kb .. " knockbacks · " .. st.ragdoll .. " ragdolls" .. ad
    end
    function GG.layers()
        local function f(b) return b and "on" or "off" end
        return "dodge " .. f(settings.autododge) .. " · rescue " .. f(settings.handsOn and settings.handsRescue ~= false) .. " · heal "
            .. f(settings.abilAssist or settings.autoHeal) .. " · void " .. f(settings.antivoid) .. " · anti-death " .. f(settings.antiDeath)
    end
    local function setStates(h, on)
        for _, st in ipairs({Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll}) do
            pcall(function() h:SetStateEnabled(st, not on) end)
        end
        if on then pcall(function() h.BreakJointsOnDeath = false end) end
    end
    local function unguard()
        if guarded and guarded.h then setStates(guarded.h, false) end
        if guarded then for _, c in ipairs(guarded.conns) do pcall(function() c:Disconnect() end) end end
        guarded = nil
    end
    local function threatNow()
        return now() - SEN.lastHitT < 0.45 or (SEN.top ~= nil and (SEN.top.danger or 0) >= 0.8) or now() - SEN.lastEvadeT < 0.1
    end
    local function tryAntiDeathHeal()
        local OV = CORE.override
        if OV then
            if settings.ovrSoftGod == true and OV.softGod then pcall(OV.softGod) end
            if (settings.ovrHeal == true or settings.ovrSoftGod == true) and OV.healSelf then pcall(OV.healSelf) end
        end
        if ABI and ABI.firstReady and ABI.use then
            local heal = ABI.firstReady("heal")
            if heal then pcall(ABI.use, heal) end
        end
    end
    local function guard(c)
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h then return end
        if guarded and guarded.h == h then return end
        unguard()
        guarded = {h = h, c = c, conns = {}, zeroSince = nil, lastHp = h.Health, lastHealTry = 0, lastBail = 0}
        setStates(h, true)
        local function cn(x) guarded.conns[#guarded.conns + 1] = bind(x) end
        -- anti-knockback: movers that appear on you during an attack and aren't yours / your own ability
        cn(c.DescendantAdded:Connect(function(d)
            if not (alive and wantGuard()) or not MOVERS[d.ClassName] then return end
            task.defer(function()
                if not d.Parent or isOurs(d) then return end
                local suspicious = hasWord(animWords(d.Name), KB_WORDS) or threatNow()
                if not suspicious or ABI.recent(0.7) or now() - lastUserKey < 0.3 then return end
                pcall(function() d:Destroy() end)
                GG.stats.kb += 1
                local r = hrp()
                if r then r.AssemblyLinearVelocity = Vector3.new(0, math.min(r.AssemblyLinearVelocity.Y, 0), 0) end
                if GG.stats.kb % 5 == 1 then say("kb_cancel") end
                CORE.log("GOD", "knockback mover removed: " .. d.ClassName .. " '" .. d.Name .. "'")
            end)
        end))
        -- anti-ragdoll: forced states and disabled joints get repaired
        cn(h.StateChanged:Connect(function(_, st)
            if not (alive and wantGuard()) then return end
            if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
                or st == Enum.HumanoidStateType.Dead
                or (st == Enum.HumanoidStateType.Physics and not settings.fly and not MOV.carrying) then
                task.defer(function()
                    if settings.antiDeath == true or settings.godmode == true then
                        setStates(h, true)
                        pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
                    end
                    for _, m in ipairs(c:GetDescendants()) do
                        if m:IsA("Motor6D") and not m.Enabled then pcall(function() m.Enabled = true end) end
                    end
                    GG.stats.ragdoll += 1
                end)
            end
        end))
        cn(h.HealthChanged:Connect(function(hp)
            if not (alive and guarded) then return end
            local prev = guarded.lastHp or hp
            guarded.lastHp = hp
            if hp < prev - 0.05 and wantGuard() then
                dmgLog[#dmgLog + 1] = {t = now(), a = prev - hp}
                GG.stats.leaks += 1
                if settings.quietDeath ~= true and GG.stats.leaks % 6 == 1 then say("godmode_leak") end
                -- Anti-Death: spam heal / Soft God under pressure
                if settings.antiDeath == true and hp / math.max(h.MaxHealth, 1) < 0.35 then
                    tryAntiDeathHeal()
                end
            end
            if settings.antiDeath == true and hp <= 0 then
                GG.stats.antiHolds += 1
                setStates(h, true)
                -- client-side Health poke (only sticks if the game trusts the client — most don't)
                pcall(function()
                    if h.MaxHealth > 0 then h.Health = math.max(1, h.MaxHealth * 0.05) end
                end)
                tryAntiDeathHeal()
            end
        end))
    end
    -- velocity spike right after a hit = knockback: restore your previous motion
    -- death watchdog: Anti-Death HOLDS the Dead state; without it we release after 2.5s so you can respawn
    local prevV
    onHeartbeat("ggod41", function()
        if not wantGuard() then
            prevV = nil
            if guarded then unguard() CORE.log("GOD", "godmode/anti-death off · state guard released") end
            return
        end
        local c, h, r = char(), hum(), hrp()
        if not (c and h and r) then return end
        if not guarded or guarded.h ~= h then guard(c) end
        if not guarded then return end
        local v = r.AssemblyLinearVelocity
        if prevV and now() - SEN.lastHitT < 0.3 and not MOV.carrying and MOV.active() == nil and not ABI.recent(0.7) and not settings.fly then
            if flat(v - prevV).Magnitude > 45 then
                r.AssemblyLinearVelocity = Vector3.new(prevV.X, math.min(v.Y, prevV.Y + 5), prevV.Z)
                GG.stats.kb += 1
                v = r.AssemblyLinearVelocity
            end
        end
        prevV = v
        if h.Health <= 0 then
            guarded.zeroSince = guarded.zeroSince or now()
            if settings.antiDeath == true then
                -- HOLD: keep Dead disabled, keep trying heal + bail to Safe Spot
                setStates(h, true)
                pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                pcall(function()
                    if h.MaxHealth > 0 and h.Health <= 0 then h.Health = math.max(1, h.MaxHealth * 0.08) end
                end)
                if now() - (guarded.lastHealTry or 0) > 0.45 then
                    guarded.lastHealTry = now()
                    tryAntiDeathHeal()
                    GG.stats.antiHolds += 1
                end
                -- after ~1.2s still at 0: bail to Safe Spot (best client survival move)
                if now() - guarded.zeroSince > 1.2 and now() - (guarded.lastBail or 0) > 4 then
                    guarded.lastBail = now()
                    if FX and FX.goSafe then pcall(FX.goSafe) end
                end
                -- never release Dead while Anti-Death is on (user can toggle off to respawn)
            elseif now() - guarded.zeroSince > 2.5 and guarded.zeroSince ~= math.huge then
                guarded.zeroSince = math.huge
                setStates(h, false)
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead) end)
                say("godmode_dead")
                CORE.log("GOD", "server health reached 0 · released the Dead state so you respawn")
            end
        else
            if guarded.zeroSince and guarded.zeroSince ~= math.huge then GG.stats.held += 1 end
            guarded.zeroSince = nil
        end
    end)
    function GG.apply()
        if settings.godmode == true then
            for _, k in ipairs({"autododge", "antivoid", "handsRescue"}) do
                if settings[k] ~= true then settings[k] = true if K.toggles[k] then pcall(K.toggles[k].render, true) end end
            end
            if settings.handsOn ~= true and settings.vfx ~= false then settings.handsOn = true if K.toggles.handsOn then pcall(K.toggles.handsOn.render, true) end end
            saveSettings()
            guard(char())
            GG.stats.since = now()
            say("godmode_on")
            toast("Guardian Godmode: avoidance layers armed. The server still owns your health; the status line shows what got through.", "shield", 4)
        elseif settings.antiDeath == true then
            guard(char())
        else
            unguard()
        end
    end
    function GG.applyAntiDeath()
        if settings.antiDeath == true then
            guard(char())
            toast("Anti-Death ON · holds Dead state, heals/Soft God, Safe Spot bail. Server HP is still authoritative — toggle OFF to respawn if stuck.", "shield", 4)
        elseif settings.godmode ~= true then
            unguard()
            toast("Anti-Death off · normal death/respawn.", "info", 2)
        end
        saveSettings()
    end
    CORE.onChar("ggod", function()
        if guarded then for _, c in ipairs(guarded.conns) do pcall(function() c:Disconnect() end) end end
        guarded = nil
        prevV = nil
        if wantGuard() then task.delay(0.2, function() if alive then guard(char()) end end) end
    end)
    onUnload(unguard)
    -- boot Anti-Death if default-on (without requiring Godmode)
    if settings.antiDeath == true then
        task.defer(function() if alive then guard(char()) end end)
    end

    -- =================================================================
    -- stalk: Stalker Shield (never attacks; distance + evasion + verified escape)
    -- =================================================================
    STK.data, STK.escapes = {}, 0
    function STK.isStalker(p) local e = STK.data[p] return e ~= nil and e.active == true end
    function STK.activeCount() local n = 0 for _, e in pairs(STK.data) do if e.active then n += 1 end end return n end
    function STK.summary()
        local names = {}
        for p, e in pairs(STK.data) do if e.active then names[#names + 1] = p.DisplayName end end
        if #names == 0 then return "nobody · " .. STK.escapes .. " escapes" end
        return table.concat(names, ", ")
    end
    SEN.on("stalk", function(ev)
        if ev.kind ~= "hit" or not (ev.who and ev.who.player) then return end
        local e = STK.data[ev.who.player] or {s = 0, hits = 0, lastHit = -10}
        STK.data[ev.who.player] = e
        e.s = math.min(100, e.s + 22)
        e.hits += 1
        e.lastHit = now()
    end)
    local stkAcc, lastSafeGo = 0, -100
    onHeartbeat("stalk41", function(dt)
        stkAcc += dt
        if stkAcc < 0.25 then return end
        local step = stkAcc
        stkAcc = 0
        local r, h = hrp(), hum()
        if not (r and h) then return end
        local me, t = r.Position, now()
        local flee
        for _, p in ipairs(Players:GetPlayers()) do
            local pr = p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            local e = STK.data[p]
            if pr then
                e = e or {s = 0, hits = 0, lastHit = -10}
                STK.data[p] = e
                local rel = me - pr.Position
                local d = rel.Magnitude
                local closing = pr.AssemblyLinearVelocity:Dot(unitOr(rel, Vector3.zero))
                if d < 25 then e.s += step * (2 + ((closing > 6) and 3 or 0)) elseif d > 60 then e.s -= step * 3 else e.s -= step end
                local info = p.Character and cands[p.Character]
                if info and t - info.windupAt < 0.3 and (info.facing or 0) > 0.5 and d < 20 then e.s += 2 end
                e.s = math.clamp(e.s, 0, 100)
                if not e.active and settings.stalker == true and ((e.s >= 45 and e.hits >= 1) or e.s >= 75) then
                    e.active, e.farSince = true, nil
                    say("stalker_on", {name = p.DisplayName}, 3)
                    toast("Stalker Shield: " .. p.DisplayName .. " keeps targeting you. Keeping distance.", "warn", 3)
                    CORE.log("STALK", p.DisplayName .. " marked (score " .. math.floor(e.s) .. ", hits " .. e.hits .. ")")
                end
                if e.active then
                    if d < 45 and not FX.inSafe() then
                        local away = unitOr(flat(rel), Vector3.new(0, 0, 1))
                        local push = math.clamp((45 - d) * 1.4, 8, 34) * (0.5 + 0.6 * strength())
                        if not flee or d < flee.d then flee = {d = d, v = away * push} end
                        e.farSince = nil
                    else
                        e.farSince = e.farSince or t
                        -- verified escape: far away (or in the Safe Spot), no hit from them for 6 s, held for 3 s
                        if t - e.farSince > 3 and t - e.lastHit > 6 then
                            e.active, e.s, e.hits = false, 20, 0
                            STK.escapes += 1
                            say("stalker_escape", {name = p.DisplayName})
                            if VFX.handsMode then VFX.handsMode("victory", nil, 1.3) end
                            if VFX.taunt then pcall(VFX.taunt, "escape", p.DisplayName) end
                            CORE.log("STALK", "escape from " .. p.DisplayName .. " verified")
                        end
                    end
                    if settings.stalkerSafe == true and t - lastSafeGo > 30 and not FX.inSafe()
                        and (h.Health < h.MaxHealth * 0.5 or (e.hits >= 4 and t - e.lastHit < 3)) then
                        lastSafeGo = t
                        pcall(FX.goSafe)
                    end
                end
            elseif e and e.active then
                e.farSince = e.farSince or t
            end
        end
        for p in pairs(STK.data) do if p.Parent ~= Players then STK.data[p] = nil end end
        if flee and settings.stalker == true then MOV.want("stalker", 55, flee.v, 0.35) else MOV.clear("stalker") end
    end)

    -- =================================================================
    -- water: walk on water (Terrain water, water parts, learned sea level)
    -- =================================================================
    local WATER = {"water", "sea", "ocean", "lake", "river", "pond", "wave", "waves", "liquid"}
    local waterParts = setmetatable({}, {__mode = "k"})
    local waterScanned = false
    local function waterLike(p)
        if not p:IsA("BasePart") or isOurs(p) then return false end
        local s = p.Size
        if s.X * s.Z < 300 then return false end
        local n = string.lower(p.Name)
        return hasWord(n, WATER) and not string.find(n, "fall", 1, true)
    end
    function CORE.waterAdd(p) if p and p.Parent and waterLike(p) then waterParts[p] = true return true end return false end
    local function scanWater()
        if waterScanned then return end
        waterScanned = true
        task.spawn(function()
            local list = workspace:GetDescendants()
            local n = 0
            for i, d in ipairs(list) do
                if not alive then return end
                if waterLike(d) then waterParts[d] = true n += 1 end
                if i % 3000 == 0 then task.wait() end
            end
            CORE.log("WATER", "scan done · " .. n .. " water parts")
        end)
        bind(workspace.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then task.defer(function() if d.Parent and waterLike(d) then waterParts[d] = true end end) end
        end))
    end
    local wrp = RaycastParams.new()
    wrp.FilterType = Enum.RaycastFilterType.Exclude
    wrp.IgnoreWater = false
    local function terrainWaterAt(p)
        local ok, mat = pcall(function()
            local reg = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
            local m = workspace.Terrain:ReadVoxels(reg, 4)
            return m[1][1][1]
        end)
        return ok and mat == Enum.Material.Water
    end
    local function placeKey() return tostring((GAMEINFO and GAMEINFO.root) or game.PlaceId) end
    -- V2.3: games with a known sea level (Blox Fruits: a moving mesh, not Terrain water, damage below it)
    local function seaProfile() local m = GAMEINFO and GAMEINFO.module local pf = m and m.profile return (pf and pf.seaLevel) and pf or nil end
    function CORE.seaTop() local pf = seaProfile() return pf and (pf.seaLevel + (CORE.seaAdj or 0)) or nil end
    function CORE.isWaterPart(p) return waterParts[p] == true end
    local function learnedY()
        local d = settings.waterY
        return type(d) == "table" and tonumber(d[placeKey()]) or nil
    end
    local function surfaceAt(r, h)
        local pos = r.Position
        local ex = {char(), gui}
        if CORE.waterPlat then ex[#ex + 1] = CORE.waterPlat end
        wrp.FilterDescendantsInstances = ex
        local res = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -24, 0), wrp)
        local st = CORE.seaTop()
        if st and pos.Y < st + 10 and pos.Y > st - 80 then
            -- land above the sea level wins; otherwise the surface is the sea level itself
            local land = res and res.Material ~= Enum.Material.Water and not waterParts[res.Instance] and res.Position.Y > st + 0.3
            if not land then return st, "sea" end
        end
        if res then
            if res.Material == Enum.Material.Water then return res.Position.Y, "terrain" end
            if waterParts[res.Instance] or waterLike(res.Instance) then waterParts[res.Instance] = true return res.Position.Y, "part" end
        end
        for p in pairs(waterParts) do
            if p.Parent then
                local lp = p.CFrame:PointToObjectSpace(pos)
                local s = p.Size
                if math.abs(lp.X) <= s.X / 2 and math.abs(lp.Z) <= s.Z / 2 then
                    local top = p.Position.Y + s.Y / 2
                    if pos.Y < top + 9 and pos.Y > top - 30 then return top, "part" end
                end
            end
        end
        -- inside terrain water (sinking / swimming): find the surface above you
        local swimming = h:GetState() == Enum.HumanoidStateType.Swimming
        if swimming or terrainWaterAt(pos) then
            local base = math.floor(pos.Y / 4) * 4
            for k = 0, 8 do
                local y = base + k * 4 + 2
                if not terrainWaterAt(Vector3.new(pos.X, y, pos.Z)) then return y - 2, "voxel" end
            end
            if swimming then
                -- learn this game's sea level so the platform is there before you sink next time
                settings.waterY = type(settings.waterY) == "table" and settings.waterY or {}
                settings.waterY[placeKey()] = math.floor(pos.Y + 1.5)
                saveSettings()
                return pos.Y + 1.5, "learned"
            end
        end
        local ly = learnedY()
        if ly and not res and pos.Y < ly + 6 and pos.Y > ly - 20 then return ly, "learned" end
        return nil
    end
    local waterAcc, lastSurf, lastSurfT, rippleAt, swimOff, waterSaid = 0, nil, -10, 0, nil, false
    CORE.waterSource = "none"
    local ripplePool = KIT.makePool and KIT.part and KIT.makePool(function()
        return KIT.part({Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = C.spirit, Size = Vector3.new(0.08, 2, 2)})
    end, 8)
    local function ripple(pos, idle)
        if lite() or settings.vfx == false or not ripplePool then return end
        local p = ripplePool()
        local s1 = idle and 7 or 12
        p.Size = Vector3.new(0.08, 2, 2)
        p.Transparency = 0.5
        p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
        if p.Parent ~= workspace then p.Parent = workspace end
        tweenL(p, idle and 1.1 or 0.8, {Size = Vector3.new(0.05, s1, s1), Transparency = 1}, Enum.EasingStyle.Quad)
    end
    local function restoreSwim()
        if swimOff and swimOff.Parent then pcall(function() swimOff:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end) end
        swimOff = nil
    end
    onHeartbeat("walkwater", function(dt)
        local plat = CORE.waterPlat
        -- V2.3 Water Guard: with Guardian Control on, the known sea level holds you even without Walk on Water
        local guardOnly = settings.walkwater ~= true and settings.waterGuard ~= false and settings.handsOn == true and seaProfile() ~= nil
        if settings.walkwater ~= true and not guardOnly then
            if plat and plat.Parent then plat.Parent = nil end
            restoreSwim()
            waterSaid = false
            return
        end
        scanWater()
        local r, h = hrp(), hum()
        if not (r and h) then return end
        if not plat then
            plat = own(mk("Part", {Name = "SecretWaterWalk", Anchored = true, CanCollide = true, CanQuery = false, CanTouch = false, CastShadow = false,
                Transparency = 1, Size = Vector3.new(40, 1.2, 40)}, nil))
            CORE.waterPlat = plat
        end
        waterAcc += dt
        if waterAcc >= 0.08 then
            waterAcc = 0
            local y, src = surfaceAt(r, h)
            if y and guardOnly and src ~= "sea" then y = nil end
            if y then lastSurf, lastSurfT, CORE.waterSource = y, now(), src end
        end
        local dive = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        if lastSurf and now() - lastSurfT < 0.4 and not dive then
            local p = r.Position
            plat.CFrame = CFrame.new(p.X, lastSurf - 0.6, p.Z)
            if not plat.Parent then plat.Parent = workspace end
            if swimOff ~= h then restoreSwim() pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Swimming, false) end) swimOff = h end
            -- fallback hold: still below the surface (platform ignored)? lift you to it
            local hip = (h.HipHeight > 0 and h.HipHeight or 2) + r.Size.Y / 2
            if p.Y < lastSurf + hip - 1.2 then
                local v = r.AssemblyLinearVelocity
                r.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 26), v.Z)
                if h:GetState() == Enum.HumanoidStateType.Swimming then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
            end
            if not waterSaid then waterSaid = true say(guardOnly and "water_guard" or "water_on") end
            local sp = flat(r.AssemblyLinearVelocity).Magnitude
            if now() > rippleAt and p.Y < lastSurf + hip + 2 then
                rippleAt = now() + ((sp > 3) and 0.22 or 0.9)
                ripple(Vector3.new(p.X, lastSurf + 0.06, p.Z), sp <= 3)
            end
        elseif plat.Parent and (now() - lastSurfT > 0.6 or dive) then
            plat.Parent = nil
            restoreSwim()
        end
    end)
    CORE.onChar("water", function() restoreSwim() lastSurf = nil end)
    onUnload(restoreSwim)

    -- =================================================================
    -- sight: Sharingan Sight (visual only: glowing eyes, attacker outline, attack line)
    -- =================================================================
    local sight = {eyes = nil, hl = {}, hlI = 0}
    CORE.sight = sight
    -- 4.2: red is used ONLY for the threat outline; eyes and attack lines are ninja white
    local RED = C.sharingan
    local WHITE = Color3.new(1, 1, 1)
    sight.pool = KIT.makePool and KIT.part and KIT.makePool(function() return KIT.part({Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.14, 0.05, 1)}) end, 6)
    local function eyesOff() if sight.eyes then for _, e in ipairs(sight.eyes) do pcall(function() e:Destroy() end) end sight.eyes = nil end end
    local function hlFor(model)
        sight.hlI = sight.hlI % 3 + 1
        local hl = sight.hl[sight.hlI]
        if not hl then
            hl = own(mk("Highlight", {FillTransparency = 1, OutlineColor = RED, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, nil))
            sight.hl[sight.hlI] = hl
        end
        hl.Adornee = model
        hl.Parent = gui
        hl.OutlineTransparency = 0.05
        tweenL(hl, 0.55, {OutlineTransparency = 1}, Enum.EasingStyle.Quad)
    end
    function sight.flash(ev)
        if settings.fxSharingan ~= true or settings.vfx == false then return end
        local r = hrp()
        if not r then return end
        if ev.who and ev.who.model then hlFor(ev.who.model) end
        if not lite() and sight.pool and ev.pos then
            local a, b = ev.pos, r.Position
            if ev.type == "projectile" and ev.vel then b = ev.pos + ev.vel * math.min((ev.eta or 0) + 0.25, 0.9) end
            local len = (b - a).Magnitude
            if len > 0.5 then
                local p = sight.pool()
                p.Size = Vector3.new(0.14, 0.05, len)
                p.CFrame = CFrame.new((a + b) / 2, b)
                p.Transparency = 0.25
                if p.Parent ~= workspace then p.Parent = workspace end
                tweenL(p, 0.45, {Transparency = 1}, Enum.EasingStyle.Quad)
            end
        end
        if VFX.pulse and not lite() then pcall(VFX.pulse, Color3.fromRGB(210, 210, 215), 0.14, 0.22) end
    end
    onRender("sight41", function()
        if settings.fxSharingan ~= true or settings.vfx == false then eyesOff() return end
        local c = char()
        local head = c and c:FindFirstChild("Head")
        if not (head and KIT.part) then eyesOff() return end
        if not sight.eyes or not sight.eyes[1].Parent or sight.eyesHead ~= head then
            eyesOff()
            sight.eyesHead = head
            sight.eyes = {}
            for i = 1, 2 do
                -- glowing white slit eyes, like the badge
                local e = KIT.part({Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.26, 0.06, 0.04), Transparency = 0.02})
                e.Parent = workspace
                sight.eyes[i] = e
            end
            if not lite() then new("PointLight", {Parent = sight.eyes[1], Color = WHITE, Range = 5, Brightness = 1, Shadows = false}) end
        end
        local cf = head.CFrame
        local hz = head.Size.Z / 2 + 0.02
        local alert = SEN.alertUntil > now()
        local w = head.Size.X * (0.24 + (alert and 0.05 or 0)) + 0.02 * math.sin(now() * 5)
        local th = 0.055 + (alert and 0.025 or 0)
        for i, e in ipairs(sight.eyes) do
            local sg = (i == 1) and -1 or 1
            e.Size = Vector3.new(w, th, 0.04)
            e.CFrame = cf * CFrame.new(sg * head.Size.X * 0.19, head.Size.Y * 0.12, -hz) * CFrame.Angles(0, 0, math.rad(sg * 12))
        end
    end)
    onUnload(eyesOff)

    -- boot: bind everything to the current character once
    task.defer(function()
        if LP.Character then hookDied(LP.Character) fireChar(LP.Character, true) end
        CORE.log("BOOT", "Guardian Core 4.1 online · VirtualInputManager " .. (VIM and "available" or "missing"))
    end)
end)

-- =====================================================================
-- 14o. Guardian PvE 4.3 (NPCs only; every hit is YOUR normal attack, nothing ever targets players)
--   choreo : Boss Choreography: learns each boss / NPC wind-up (animation id, delay, reach, shape)
--            per game, saves it, and dodges exactly in time so your combo keeps going
--   tele   : AoE Telegraph: subtle ground ring / line for learned attacks and incoming AoE
--   finish : Puppet Finisher: an NPC under X% HP -> the hands pull you in, your own finisher fires
--   loot   : Loot Grab: after an NPC dies the hands reach out and bring the drops (Item Magnet rules)
--   shadow : Shadow Strikes: your own M1 / tool on the nearest hostile NPC; pauses near real players
--   combo  : Combo Recorder: records your key combo once, Shadow Strikes replays it on NPCs
--   stun   : Stun Breaker: stunned in a fight -> your own dash / escape skill, else a jump-out
--   heal   : Heal Timing: heals with your own item / skill in the safe gap between enemy attacks
-- =====================================================================
CORE.safeModule("14o Guardian PvE 4.3", function()
    local KIT = VFX._kit or {}
    local SEN, MOV, ABI, STK = CORE.sense, CORE.move, CORE.abil, CORE.stalk
    local PVE = {stats = {learned = 0, choreo = 0, finishers = 0, loot = 0, strikes = 0, landed = 0, stunBreaks = 0, heals = 0}}
    CORE.pve = PVE
    local function now() return os.clock() end
    local function lite() return PERF.lite end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local function unitOr(v, fb) if v.Magnitude < 1e-3 then return fb end return v.Unit end
    local mouseClickFn = exfn("mouse1click")
    local function gameKey() return tostring((GAMEINFO and GAMEINFO.gameId) or game.GameId) end

    -- ---------------- safety: NPC-only targets, real players pause everything offensive ----------------
    local function isNpcInfo(info)
        if not (info and info.model and info.model.Parent and info.hum and info.root and info.root.Parent) then return false end
        if info.player ~= nil or info.model == LP.Character then return false end
        local ok, plr = pcall(function() return Players:GetPlayerFromCharacter(info.model) end)
        if not ok or plr ~= nil then return false end
        return info.hum.Health > 0
    end
    PVE.isNpcInfo = isNpcInfo
    -- returns a reason string while any real player is close (25 studs) or targeting you
    local function playerGuard()
        local r = hrp()
        if not r then return "no character" end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr and (pr.Position - r.Position).Magnitude < 25 then return p.DisplayName .. " is nearby" end
            end
        end
        if STK.activeCount and STK.activeCount() > 0 then return "a player is hunting you" end
        for _, info in ipairs(SEN.list or {}) do
            if info.player and info.hostile then return tostring(info.name) .. " targets you" end
        end
        return nil
    end
    PVE.playerGuard = playerGuard
    local function faceTo(pos)
        local r = hrp()
        if not r or MOV.carrying then return end
        local d = flat(pos - r.Position)
        if d.Magnitude < 0.5 then return end
        pcall(function() r.CFrame = CFrame.lookAt(r.Position, r.Position + d) end)
    end
    -- your own normal attack: the equipped tool, else a tool from your backpack, else a real click
    local lastTool
    local function m1()
        local c, h = char(), hum()
        if not (c and h) then return false end
        local tl = c:FindFirstChildOfClass("Tool")
        if tl and GV.isFruitItem(tl) then pcall(function() h:UnequipTools() end) tl = nil end
        if not tl then
            -- V2.4: the weapon you picked (Blox Fruits Kit), else your last weapon, else a combat tool from the backpack
            if CORE.pickWeapon then tl = CORE.pickWeapon() end
            local bp = LP:FindFirstChildOfClass("Backpack")
            if not tl and bp then
                if lastTool and lastTool.Parent == bp then tl = lastTool
                else
                    for _, t in ipairs(bp:GetChildren()) do
                        if t:IsA("Tool") and not GV.isFruitItem(t) then tl = t break end
                    end
                end
            end
            if tl and tl.Parent ~= c then pcall(function() h:EquipTool(tl) end) end
        end
        if tl then
            lastTool = tl
            return pcall(function() tl:Activate() end)
        end
        if mouseClickFn and not HUB.uiOpen then return pcall(mouseClickFn) end
        return false
    end
    PVE.m1 = m1

    -- ---------------- telegraph visuals (pooled: 2 discs + 2 lines + 2 timing fills) ----------------
    local tele = {}
    local function teleSet(i)
        local t = tele[i]
        if t or not KIT.part then return t end
        t = {
            disc = KIT.part({Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = Color3.new(1, 1, 1), Size = Vector3.new(0.1, 1, 1)}),
            fill = KIT.part({Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(235, 235, 240), Size = Vector3.new(0.06, 1, 1)}),
            line = KIT.part({Material = Enum.Material.ForceField, Color = Color3.new(1, 1, 1), Size = Vector3.new(3, 0.1, 1)}),
        }
        tele[i] = t
        return t
    end
    local teleI = 0
    local function groundY(pos)
        local res
        pcall(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local ex = {gui}
            for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
            rp.FilterDescendantsInstances = ex
            res = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), rp)
        end)
        return res and res.Position.Y or (pos.Y - 3)
    end
    -- shape "aoe": ring around the attacker; "melee": a line along its facing; the inner fill grows to the impact moment
    function PVE.telegraph(pos, radius, dur, shape, dir)
        if settings.vfx == false or not pos then return end
        teleI = teleI % 2 + 1
        local t = teleSet(teleI)
        if not t then return end
        local y = groundY(pos) + 0.08
        local base = Vector3.new(pos.X, y, pos.Z)
        dur = math.clamp(dur or 0.6, 0.15, 2.5)
        radius = math.clamp(radius or 8, 3, 60)
        local flatCF = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
        if shape == "melee" and dir and flat(dir).Magnitude > 0.1 then
            local d = flat(dir).Unit
            t.line.Size = Vector3.new(3.2, 0.1, radius)
            t.line.CFrame = CFrame.lookAt(base + d * radius / 2, base + d * radius)
            t.line.Transparency = 0.55
            t.line.Parent = workspace
            tween(t.line, dur + 0.15, {Transparency = 1}, Enum.EasingStyle.Quad)
            t.fill.Parent = nil t.disc.Parent = nil
        else
            t.disc.Size = Vector3.new(0.1, radius * 2, radius * 2)
            t.disc.CFrame = flatCF
            t.disc.Transparency = 0.62
            t.disc.Parent = workspace
            t.fill.Size = Vector3.new(0.06, 0.5, 0.5)
            t.fill.CFrame = flatCF
            t.fill.Transparency = 0.86
            t.fill.Parent = workspace
            tween(t.fill, dur, {Size = Vector3.new(0.06, radius * 2, radius * 2), Transparency = 0.78}, Enum.EasingStyle.Linear)
            task.delay(dur, function()
                tween(t.fill, 0.2, {Transparency = 1}) tween(t.disc, 0.25, {Transparency = 1})
            end)
            t.line.Parent = nil
        end
        task.delay(dur + 0.45, function() for _, p in pairs(t) do if p.Transparency >= 0.99 then p.Parent = nil end end end)
    end

    -- ---------------- Boss Choreography: learn + save + timed dodge ----------------
    local BOOK_FILE = "SecretHub_choreo.json"
    local book = loadJSON(BOOK_FILE, {})
    if type(book) ~= "table" then book = {} end
    local dirtyAt
    local function gameBook()
        local k = gameKey()
        if type(book[k]) ~= "table" then book[k] = {} end
        return book[k]
    end
    local function bossKey(info) return string.sub(string.lower(tostring(info.model.Name)), 1, 32) end
    local function bossBook(info, create)
        local gb = gameBook()
        local k = bossKey(info)
        if type(gb[k]) ~= "table" then
            if not create then return nil end
            local n = 0 for _ in pairs(gb) do n += 1 end
            if n >= 40 then return nil end
            gb[k] = {}
        end
        return gb[k]
    end
    local function animKey(a) return string.sub(tostring(a or "?"), 1, 64) end
    function PVE.summary()
        local gb = gameBook()
        local bosses, moves = 0, 0
        for _, b in pairs(gb) do bosses += 1 for _ in pairs(b) do moves += 1 end end
        local st = PVE.stats
        return bosses .. " NPCs · " .. moves .. " attacks learned · " .. st.choreo .. " timed dodges"
    end
    function PVE.forget()
        book[gameKey()] = {}
        save(BOOK_FILE, jsonEncode(book))
        toast("Boss Choreography: patterns for this game cleared.", "info", 3)
    end
    SEN.on("pve43", function(ev)
        if ev.kind == "hit" then
            local who = ev.who
            if not (who and isNpcInfo(who) and who.windupAnim) then return end
            local dt = now() - (who.windupAt or -10)
            local w = CORE.world
            local lim = (w and w.isBoss and w.isBoss(who.model)) and 3.5 or 2.5   -- scanner-known bosses: longer wind-ups
            if dt < 0.05 or dt > lim then return end
            local b = bossBook(who, true)
            if not b then return end
            local k = animKey(who.windupAnim)
            local rec = b[k]
            if type(rec) ~= "table" then
                local n = 0 for _ in pairs(b) do n += 1 end
                if n >= 24 then return end
                rec = {n = 0, delay = dt, range = who.dist or 8, dodged = 0}
                b[k] = rec
                PVE.stats.learned += 1
                CORE.log("PVE", "learned " .. tostring(who.name) .. " · " .. tostring(who.windupName or k) .. string.format(" · %.2fs · %.0f studs", dt, who.dist or 0))
            end
            rec.n = (rec.n or 0) + 1
            rec.delay = (rec.n <= 1) and dt or (rec.delay * 0.7 + dt * 0.3)
            rec.range = math.max((rec.range or 0) * 0.85, (who.dist or 8) + 1)
            rec.shape = (rec.range > 14) and "aoe" or "melee"
            rec.name = string.sub(tostring(who.windupName or ""), 1, 40)
            dirtyAt = now() + 4
        elseif ev.kind == "windup" then
            local info = ev.who
            if not isNpcInfo(info) then return end
            if settings.choreo ~= true and settings.aoeTele ~= true then return end
            local b = bossBook(info, false)
            local rec = b and b[animKey(ev.anim)]
            if type(rec) ~= "table" or (rec.n or 0) < 1 then return end
            local delay = math.clamp(rec.delay or 0.5, 0.08, 2.5)
            local t0 = ev.t or now()
            local look = unitOr(flat(info.root.CFrame.LookVector), Vector3.new(0, 0, -1))
            PVE.telegraph(info.root.Position, rec.range + 1, delay, rec.shape, look)
            if settings.choreo ~= true then return end
            info.choreoUntil = t0 + delay + 0.35
            local ping = (tonumber(guardian and guardian.ping) or 80) / 1000
            local lead = math.clamp(0.16 + ping * 0.5, 0.12, 0.4)
            task.delay(math.max(0, delay - lead - (now() - t0)), function()
                local r, h = hrp(), hum()
                if not (alive and r and h and h.Health > 0 and info.root and info.root.Parent) or MOV.carrying or HUB.rescueBusy then return end
                local bp = info.root.Position
                local away = unitOr(flat(r.Position - bp), Vector3.new(0, 0, 1))
                local dist = flat(r.Position - bp).Magnitude
                local need = (rec.range + 2.5) - dist
                if need <= 0 then return end   -- already outside the reach: keep attacking
                local perp = Vector3.yAxis:Cross(away).Unit
                local dirs, d
                if rec.shape == "melee" then dirs, d = {perp, -perp, away}, math.max(6, math.min(need + 2, 9))
                else dirs, d = {away, perp, -perp}, math.min(need + 1.5, 30) end
                local from = r.Position
                local used = MOV.evade(dirs, d)
                if not used then return end
                PVE.stats.choreo += 1
                if settings.handsOn == true and VFX.handsMode then VFX.handsMode("guide", {pos = from + used * 8}, 0.5) end
                local hp0 = h.Health
                task.delay(lead + 0.45, function()
                    local hh = hum()
                    if hh and hh.Health >= hp0 - 0.5 then rec.dodged = (rec.dodged or 0) + 1 dirtyAt = now() + 4 end
                    -- step back into your own range so the combo continues (melee only)
                    if settings.choreoReturn ~= false and rec.shape == "melee" and info.root and info.root.Parent and isNpcInfo(info) then
                        local rr = hrp()
                        if rr and not MOV.carrying then
                            local back = info.root.Position + unitOr(flat(rr.Position - info.root.Position), away) * math.max(4, math.min(dist, 7))
                            MOV.dashTo(back)
                        end
                    end
                end)
            end)
        elseif ev.kind == "imminent" then
            -- AoE Telegraph for things nobody had to learn: area hitboxes, AoE parts, explosions
            if settings.aoeTele == true and (ev.type == "aoe" or ev.type == "hitbox" or ev.type == "explosion") and ev.pos then
                PVE.telegraph(ev.pos, math.max((ev.size or 8) * 0.55, 4), 0.45, "aoe")
            end
        end
    end)
    onHeartbeat("pve43save", function()
        if dirtyAt and now() > dirtyAt then dirtyAt = nil save(BOOK_FILE, jsonEncode(book)) end
    end)

    -- ---------------- Shadow Strikes (+ Combo Recorder replay) ----------------
    local COMBO_FILE = "SecretHub_combo.json"
    local combos = loadJSON(COMBO_FILE, {})
    if type(combos) ~= "table" then combos = {} end
    local rec = {on = false, list = {}, last = 0}
    local SKIP = {W = true, A = true, S = true, D = true, Space = true, LeftShift = true, Tab = true, Escape = true, Slash = true, Backquote = true,
        Up = true, Down = true, Left = true, Right = true}
    function PVE.comboText()
        local c = combos[gameKey()]
        if type(c) ~= "table" or #c == 0 then return rec.on and "recording..." or "none" end
        local out = {}
        for i, s in ipairs(c) do if i <= 10 then out[#out + 1] = tostring(s.k) end end
        return (rec.on and "recording... " or "") .. table.concat(out, " > ") .. ((#c > 10) and " ..." or "")
    end
    function PVE.recordCombo()
        if rec.on then
            rec.on = false
            if #rec.list > 0 then
                combos[gameKey()] = rec.list
                save(COMBO_FILE, jsonEncode(combos))
                toast("Combo saved: " .. #rec.list .. " inputs.", "ok", 3)
            else toast("Combo Recorder: nothing recorded.", "warn", 3) end
            return
        end
        rec.on, rec.list, rec.last = true, {}, now()
        toast("Combo Recorder: do your combo now (max 8 s). Press Record again to stop.", "info", 4)
        task.delay(8, function() if rec.on then PVE.recordCombo() end end)
    end
    function PVE.clearCombo() combos[gameKey()] = nil save(COMBO_FILE, jsonEncode(combos)) toast("Combo cleared.", "info", 2) end
    bind(UserInputService.InputBegan:Connect(function(i, gp)
        if not rec.on or gp or #rec.list >= 16 then return end
        local k
        if i.UserInputType == Enum.UserInputType.MouseButton1 then k = "M1"
        elseif i.UserInputType == Enum.UserInputType.Keyboard then
            k = i.KeyCode.Name
            if SKIP[k] then return end
            local b = settings.binds or {}
            for _, v in pairs(b) do if v == k then return end end
        end
        if not k then return end
        local t = now()
        rec.list[#rec.list + 1] = {k = k, d = math.clamp(t - rec.last, 0.05, 2)}
        rec.last = t
    end))
    local playing = false
    local function playCombo()
        local c = combos[gameKey()]
        if playing or type(c) ~= "table" or #c == 0 then return false end
        playing = true
        task.spawn(function()
            for i, s in ipairs(c) do
                if i > 1 then task.wait(math.clamp(tonumber(s.d) or 0.2, 0.05, 2)) end
                if not (alive and settings.shadowM1 == true and PVE.target and playerGuard() == nil) then break end
                if s.k == "M1" then m1() elseif ABI.pressKey then ABI.pressKey(s.k, 0.05) end
            end
            task.wait(0.4)
            playing = false
        end)
        return true
    end
    local strikeAcc, nextGap, side, pauseSaid = 0, 0.33, 1, 0
    local landCheck = {}
    local lastCombo = -10
    local function pickTarget(range)
        local best, bd
        for _, info in ipairs(SEN.list or {}) do
            if isNpcInfo(info) and info.dist and info.dist <= range and (info.hostile or info.enemy or info == PVE.target) then
                if not bd or info.dist < bd then best, bd = info, info.dist end
            end
        end
        return best
    end
    onHeartbeat("shadow43", function(dt)
        if settings.shadowM1 ~= true then PVE.target = nil return end
        strikeAcc += dt
        if strikeAcc < nextGap then return end
        strikeAcc = 0
        local rate = math.clamp(tonumber(settings.m1Rate) or 3, 1, 8)
        nextGap = (1 / rate) * (0.8 + math.random() * 0.45)   -- natural rhythm, never machine-even
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or MOV.carrying or HUB.rescueBusy or FX.inSafe() then return end
        if UserInputService:GetFocusedTextBox() then return end
        local why = playerGuard()
        if why then
            PVE.target, PVE.paused = nil, why
            if now() - pauseSaid > 8 then pauseSaid = now() CORE.log("PVE", "Shadow Strikes paused: " .. why) end
            return
        end
        PVE.paused = nil
        local tg = pickTarget(math.clamp(tonumber(settings.m1Range) or 12, 4, 18))
        PVE.target = tg
        if not tg then return end
        faceTo(tg.root.Position)
        if settings.m1Combo == true and now() - lastCombo > 4 and playCombo() then lastCombo = now() return end
        if playing then return end
        if m1() then
            PVE.stats.strikes += 1
            side = -side
            if settings.handsOn == true and VFX.handsMode then VFX.handsMode("strike", {pos = tg.root.Position, side = side}, 0.28) end
            -- verify: count hits that actually change the NPC's health
            local hp0 = tg.hum.Health
            landCheck[#landCheck + 1] = {hum = tg.hum, hp = hp0, t = now()}
            if #landCheck > 12 then table.remove(landCheck, 1) end
        end
    end)
    onHeartbeat("shadow43verify", function()
        local t = now()
        for i = #landCheck, 1, -1 do
            local c = landCheck[i]
            if t - c.t > 0.6 then
                table.remove(landCheck, i)
                if c.hum.Parent and c.hum.Health < c.hp - 0.01 then PVE.stats.landed += 1 end
            end
        end
        if settings.shadowM1 == true and PVE.stats.strikes >= 30 and PVE.stats.landed == 0 and not PVE.warned then
            PVE.warned = true
            toast("Shadow Strikes: your hits don't register yet. Equip your weapon or get closer.", "warn", 5)
        end
    end)

    -- ---------------- Puppet Finisher ----------------
    local finBusy, finLast = false, setmetatable({}, {__mode = "k"})
    local function finisherInput()
        local key = trim(tostring(settings.finisherKey or ""))
        if key == "" or string.upper(key) == "M1" then return m1() end
        local c, h = char(), hum()
        local bp = LP:FindFirstChildOfClass("Backpack")
        local tl = (c and c:FindFirstChild(key)) or (bp and bp:FindFirstChild(key))
        if tl and tl:IsA("Tool") and h and not GV.isFruitItem(tl) then
            return pcall(function()
                if tl.Parent ~= c then h:EquipTool(tl) end
                task.delay(0.1, function() pcall(function() tl:Activate() end) end)
            end)
        end
        return ABI.pressKey and ABI.pressKey(key, 0.08) or false
    end
    onHeartbeat("finisher43", function()
        if settings.finisher ~= true or finBusy then return end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or MOV.carrying or HUB.rescueBusy then return end
        if playerGuard() then return end
        local thr = math.clamp(tonumber(settings.finisherHp) or 10, 3, 30) / 100
        local tg
        for _, info in ipairs(SEN.list or {}) do
            local engaged = info == PVE.target or info.hostile or (now() - (info.lastHitAt or -10) < 8)
            if engaged and isNpcInfo(info) and info.dist and info.dist < 30 and now() - (finLast[info.model] or -100) > 6 then
                local mx = math.max(info.hum.MaxHealth, 1)
                if info.hum.Health / mx < thr then tg = info break end
            end
        end
        if not tg then return end
        finBusy = true
        finLast[tg.model] = now()
        task.spawn(function()
            local ok = pcall(function()
                local root = tg.root
                local from = r.Position
                local toMe = unitOr(flat(from - root.Position), Vector3.new(0, 0, 1))
                local dest = Vector3.new(root.Position.X, from.Y, root.Position.Z) + toMe * 3.6
                if settings.handsOn == true and VFX.handsMode then VFX.handsMode("pull", {pos = root.Position}, 0.75) end
                if VFX.tint and not lite() then VFX.tint(Color3.new(1, 1, 1)) end
                local dist = (dest - from).Magnitude
                if dist > 4 then MOV.carry(function(u) return from:Lerp(dest, u) end, dist) end
                if not (alive and isNpcInfo(tg)) or playerGuard() then return end
                faceTo(root.Position)
                local hp0 = tg.hum.Health
                if finisherInput() then
                    local rr = hrp()
                    if VFX.slashTrail and rr then
                        local perp = Vector3.yAxis:Cross(toMe)
                        pcall(VFX.slashTrail, root.Position + perp * 4 + Vector3.new(0, 3, 0), root.Position - perp * 4 - Vector3.new(0, 1, 0))
                    end
                    task.delay(1.2, function()
                        if tg.hum and (tg.hum.Health < hp0 - 0.01 or not tg.hum.Parent) then
                            PVE.stats.finishers += 1
                            CORE.log("PVE", "finisher landed on " .. tostring(tg.name))
                        end
                    end)
                end
            end)
            if not ok then CORE.log("ERR", "finisher failed") end
            task.wait(0.8)
            finBusy = false
        end)
    end)

    -- ---------------- Loot Grab ----------------
    local watched = setmetatable({}, {__mode = "k"})
    local lootParams = OverlapParams.new()
    lootParams.FilterType = Enum.RaycastFilterType.Exclude
    lootParams.MaxParts = 120
    local function grabAround(pos)
        if not (VFX.goodPickup and VFX.pullPickup) then return end
        local c = char()
        lootParams.FilterDescendantsInstances = c and {c} or {}
        local t0 = now()
        local taken, takenN = {}, 0
        while alive and settings.lootGrab == true and now() - t0 < 3 do
            local item
            for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 16, lootParams)) do
                if p:IsA("BasePart") and not taken[p] and VFX.goodPickup(p) then item = p break end
            end
            -- Explorer Scanner feed: known drops / fruits / chests near the kill (still Item Magnet rules)
            if not item and CORE.world and CORE.world.dropsNear then
                for _, p in ipairs(CORE.world.dropsNear(pos, 16)) do
                    if not taken[p] and VFX.goodPickup(p) then item = p break end
                end
            end
            if not item then task.wait(0.35) else
                taken[item] = true
                takenN += 1
                local ip = item.Position
                if settings.handsOn == true and VFX.handsMode then VFX.handsMode("reach", {pos = ip}, 0.9) end
                task.wait(0.36)   -- the hand closes on the item, then it comes home
                local before = VFX.statSum and VFX.statSum() or 0
                local via = VFX.pullPickup(item)
                if via then
                    task.delay(1.1, function()
                        local mine = char()
                        local got = not item:IsDescendantOf(workspace) or (mine and item:IsDescendantOf(mine))
                            or (VFX.statSum and VFX.statSum() ~= before)
                        if got then PVE.stats.loot += 1 end
                    end)
                end
                task.wait(0.45)
                if takenN >= 5 then break end
            end
        end
    end
    onHeartbeat("loot43", function()
        if settings.lootGrab ~= true then return end
        for _, info in ipairs(SEN.list or {}) do
            if not watched[info.model] and isNpcInfo(info) and info.dist and info.dist < 45
                and (info.hostile or info.enemy or info == PVE.target or now() - (info.lastHitAt or -10) < 10) then
                watched[info.model] = true
                local root, hm = info.root, info.hum
                local conn
                conn = hm.Died:Connect(function()
                    if conn then conn:Disconnect() end
                    local p = root and root.Position
                    if not (p and alive and settings.lootGrab == true) then return end
                    local r = hrp()
                    if r and (r.Position - p).Magnitude > 70 then return end
                    task.delay(0.6, function() pcall(grabAround, p) end)
                end)
            end
        end
    end)

    -- ---------------- Stun Breaker ----------------
    local stunSince, stunLast, walkSeen = nil, -10, 16
    local STUN_STATES = {[Enum.HumanoidStateType.Ragdoll] = true, [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.PlatformStanding] = true}
    onHeartbeat("stun43", function()
        if settings.stunBreak ~= true then stunSince = nil return end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or settings.fly or MOV.carrying then stunSince = nil return end
        if h.WalkSpeed > 4 then walkSeen = h.WalkSpeed end
        local inFight = now() - SEN.lastHitT < 2.5
        local stunned = inFight and ((h.WalkSpeed < 1 and walkSeen > 4) or h.PlatformStand or r.Anchored or STUN_STATES[h:GetState()] == true)
        if not stunned then stunSince = nil return end
        stunSince = stunSince or now()
        if now() - stunSince < 0.25 or now() - stunLast < 3 then return end
        stunLast = now()
        local from = r.Position
        local esc = ABI.firstReady and (ABI.firstReady("dash") or ABI.firstReady("teleport") or ABI.firstReady("flight"))
        local used = esc and ABI.use and ABI.use(esc)
        if not used then
            pcall(function()
                if STUN_STATES[h:GetState()] then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
                h.Jump = true
            end)
        end
        if settings.handsOn == true and VFX.handsMode then VFX.handsMode("pull", {pos = from + r.CFrame.LookVector * 6}, 0.4) end
        task.delay(0.6, function()
            local hh, rr = hum(), hrp()
            if hh and rr and hh.WalkSpeed > 1 and not hh.PlatformStand and not rr.Anchored then
                PVE.stats.stunBreaks += 1
                CORE.log("PVE", "stun broken" .. (used and (" with " .. esc.label) or " (jump-out)"))
            end
        end)
    end)

    -- ---------------- Heal Timing ----------------
    local healLast, healWarned = -10, false
    onHeartbeat("heal43", function()
        if settings.healTiming ~= true then return end
        local h = hum()
        if not h or h.Health <= 0 or now() - healLast < 4 then return end
        if h.Health / math.max(h.MaxHealth, 1) > math.clamp(tonumber(settings.healAt) or 40, 10, 90) / 100 then return end
        local t = now()
        -- safe gap: no fresh wind-up near you, no imminent threat, not inside a hit chain
        if (SEN.alertUntil or 0) > t or t - SEN.lastHitT < 0.35 then return end
        for _, info in ipairs(SEN.list or {}) do
            if info.dist and info.dist < (info.reach or 10) + 6 and t - (info.windupAt or -10) < 0.7 then return end
        end
        local heal = ABI.firstReady and ABI.firstReady("heal")
        if not heal then
            if not healWarned then healWarned = true toast("Heal Timing: no heal item or skill found in your inventory.", "warn", 4) end
            healLast = t
            return
        end
        healLast = t
        local hp0 = h.Health
        if ABI.use(heal) then
            task.delay(1.6, function() local hh = hum() if hh and hh.Health > hp0 + 0.5 then PVE.stats.heals += 1 end end)
        end
    end)

    function PVE.status()
        local st = PVE.stats
        local parts = {}
        if settings.shadowM1 == true then
            parts[#parts + 1] = PVE.paused and ("strikes paused (" .. PVE.paused .. ")")
                or (PVE.target and ("striking " .. tostring(PVE.target.name)) or "strikes: no NPC in range")
        end
        parts[#parts + 1] = st.landed .. "/" .. st.strikes .. " hits landed"
        parts[#parts + 1] = st.finishers .. " finishers · " .. st.loot .. " loot · " .. st.stunBreaks .. " stun breaks · " .. st.heals .. " heals"
        return table.concat(parts, " · ")
    end
    CORE.onChar("pve43", function() PVE.target = nil finBusy = false stunSince = nil playing = false end)
    onUnload(function() for _, t in pairs(tele) do for _, p in pairs(t) do pcall(function() p:Destroy() end) end end end)
end)

-- =====================================================================
-- 14p. Mob Gather / Puppet Hold 4.3 (NPCs only, never player characters, off by default)
--   Gathers nearby hostile NPCs into a tight cluster in front of you and holds them there, so your
--   OWN M1 / AoE hits all of them. No damage is changed; every kill is your normal attack.
--   Works only where this client simulates the NPC (network ownership): isnetworkowner when the
--   executor has it, else a 1 s move test (moved part must stay moved, no server snap-back).
--   Decided per mob (never per game): a mob that fails is skipped and re-tested later, because the
--   server hands nearby mobs to the closest client (Blox Fruits often does). Spawn leash: every mob's
--   spawn point is recorded and mobs are only gathered within the leash radius, so the server does not
--   reset them. Optional: move near the mob spawn cluster (Explorer Scanner) when nothing is held.
--   Releases everything the moment a real player is within 25 studs or targets you.
-- =====================================================================
CORE.safeModule("14p Mob Gather / Puppet Hold 4.3", function()
    local KIT = VFX._kit or {}
    local PVE = CORE.pve
    local SEN, MOV = CORE.sense, CORE.move
    if not (PVE and SEN) then return end
    local HOLD = {held = {}, owned = 0, tested = 0, failed = 0, unsupported = false, paused = nil, beams = {}, used = 0}
    PVE.hold = HOLD
    local function now() return os.clock() end
    local function lite() return PERF.lite or isTouch end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local netOwnerFn = exfn("isnetworkowner")
    local verdict = setmetatable({}, {__mode = "k"})   -- [model] = true (owned) / false (server)
    local verdictT = setmetatable({}, {__mode = "k"})  -- a "server" verdict expires after 12 s (ownership moves)
    local spawnOf = setmetatable({}, {__mode = "k"})   -- [model] = spawn / first-seen position
    HOLD.spawnOf = spawnOf
    local testing = setmetatable({}, {__mode = "k"})
    local function say(kind, vars, prio) if VFX.say then pcall(VFX.say, kind, vars, prio) end end
    local function rootOf(info) return info.root or (info.model and info.model:FindFirstChild("HumanoidRootPart")) end

    -- ---------------- network ownership ----------------
    local function ownerApi(part)
        if not netOwnerFn then return nil end
        local ok, v = pcall(netOwnerFn, part)
        if ok and type(v) == "boolean" then return v end
        return nil
    end
    -- move test: shift the root 1.5 studs sideways once, then watch for 1 s that it stays shifted and
    -- is never snapped back toward the server position
    local function moveTest(root)
        if root.Anchored then return false end
        local orig = root.Position
        local dir = flat(root.CFrame.RightVector)
        dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
        local OFF = 1.5
        local ok = pcall(function() root.CFrame = root.CFrame + dir * OFF end)
        if not ok then return false end
        local t0, prev = now(), root.Position
        while now() - t0 < 1 do
            task.wait()
            if not (alive and root.Parent) then return false end
            local p = root.Position
            -- a sudden jump back toward the original spot = server correction
            if (p - prev).Magnitude > 1 and (flat(p - orig)):Dot(dir) < OFF * 0.4 then return false end
            prev = p
        end
        return (flat(root.Position - orig)):Dot(dir) > OFF * 0.5
    end
    local function checkOwner(info)
        local m, root = info.model, rootOf(info)
        if verdict[m] == false and now() - (verdictT[m] or 0) > 12 then verdict[m] = nil end
        if verdict[m] ~= nil then return verdict[m] end
        if testing[m] or not root then return nil end
        testing[m] = true
        local api = ownerApi(root)
        -- V2.3: the game profile knows these mobs are handed to the closest client: hold first, the hold loop
        -- verifies every frame and lets go (re-tested in 12 s) when the server snaps it back
        local mp = GAMEINFO and GAMEINFO.module and GAMEINFO.module.profile
        if api == nil and mp and mp.mobsMovable and not root.Anchored then
            verdict[m] = true verdictT[m] = now() testing[m] = nil
            HOLD.tested += 1 HOLD.owned += 1
            if CORE.claimSim then CORE.claimSim() end
            return true
        end
        if api ~= nil then
            verdict[m] = api verdictT[m] = now()
            testing[m] = nil
        else
            task.spawn(function()
                local res = moveTest(root)
                verdict[m] = res verdictT[m] = now()
                testing[m] = nil
                HOLD.tested += 1
                if res then HOLD.owned += 1 else HOLD.failed += 1 end
            end)
            return nil
        end
        HOLD.tested += 1
        if api then HOLD.owned += 1 else HOLD.failed += 1 end
        return api
    end
    -- honest notice, no game-wide switch-off: ownership is decided per mob and re-tested
    local lastUnsupported = -100
    local function noteUnsupported()
        if now() - lastUnsupported < 60 then return end
        lastUnsupported = now()
        HOLD.unsupported = true
        local gname = (GAMEINFO and GAMEINFO.clean) or "this game"
        say("hold_unsupported", {game = gname}, 3)
        toast("Puppet Hold: no mob near you is client-owned right now in " .. gname .. ". The server keeps them, so they can't be held. Move closer, it re-tests every mob.", "warn", 5)
    end
    local W = function() return CORE.world end
    local function spawnPos(info)
        local m = info.model
        if not spawnOf[m] then
            local w = W()
            spawnOf[m] = (w and w.spawnOf and w.spawnOf(m)) or (info.root and info.root.Position)
        end
        return spawnOf[m]
    end

    -- ---------------- strings (pooled Beams; ~6 per NPC, 60 total, fewer on mobile) ----------------
    local anchorPart, anchorAtts = nil, {}
    local function anchors()
        local tips = VFX.handTips and VFX.handTips()
        if tips and #tips > 0 then return tips end
        if not anchorPart and KIT.part then
            anchorPart = KIT.part({Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)})
            anchorPart.Parent = workspace
            for i = 1, 6 do
                anchorAtts[i] = own(new("Attachment", {Name = "SecretHoldBar", Parent = anchorPart, Position = Vector3.new((i - 3.5) * 0.9, 0, 0)}))
            end
        end
        return anchorAtts
    end
    local LIMBS = {{"Head"}, {"RightHand", "Right Arm"}, {"LeftHand", "Left Arm"}, {"UpperTorso", "Torso"}, {"RightFoot", "Right Leg"}, {"LeftFoot", "Left Leg"}}
    HOLD.free = {}
    local function beam(cap)
        local b = table.remove(HOLD.free)
        if not b then
            if #HOLD.beams >= cap then return nil end
            b = own(KIT.tag and KIT.tag(new("Beam", {Width0 = 0.045, Width1 = 0.025, LightEmission = 1, LightInfluence = 0, Brightness = 2, FaceCamera = true,
                Segments = lite() and 4 or 8, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 225)),
                Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.55)}), Enabled = false}))
                or new("Beam", {Enabled = false}))
            HOLD.beams[#HOLD.beams + 1] = b
        end
        HOLD.used += 1
        return b
    end
    local function stringsFor(e)
        if settings.vfx == false then return end
        local cap = lite() and 24 or 60
        local per = lite() and 3 or 6
        local src = anchors()
        e.atts, e.beams = {}, {}
        for i, names in ipairs(LIMBS) do
            if i > per or HOLD.used >= cap then break end
            local limb
            for _, n in ipairs(names) do limb = limb or e.model:FindFirstChild(n) end
            local b = (limb and limb:IsA("BasePart") and #src > 0) and beam(cap)
            if b then
                local a1 = own(new("Attachment", {Name = "SecretHoldString", Parent = limb}))
                b.Attachment0 = src[(HOLD.used - 1) % #src + 1]
                b.Attachment1 = a1
                b.Parent = workspace.Terrain
                b.Enabled = true
                e.atts[#e.atts + 1] = a1
                e.beams[#e.beams + 1] = b
            end
        end
    end

    -- ---------------- hold / release ----------------
    local function release(m)
        local e = HOLD.held[m]
        if not e then return end
        HOLD.held[m] = nil
        for _, b in ipairs(e.beams or {}) do
            pcall(function() b.Enabled = false b.Attachment0 = nil b.Attachment1 = nil end)
            HOLD.free[#HOLD.free + 1] = b
            HOLD.used = math.max(0, HOLD.used - 1)
        end
        for _, a in ipairs(e.atts or {}) do pcall(function() a:Destroy() end) end
        pcall(function() e.align:Destroy() end)
        pcall(function() e.orient:Destroy() end)
        pcall(function() e.att:Destroy() end)
        pcall(function() if e.hum and e.hum.Parent then e.hum.PlatformStand = false end end)
    end
    local function releaseAll(why)
        local had = next(HOLD.held) ~= nil
        for m in pairs(HOLD.held) do release(m) end
        if had and why then say("hold_release", {}, 2) end
    end
    HOLD.releaseAll = releaseAll
    local function grab(info)
        local root = rootOf(info)
        if not root then return end
        local e = {model = info.model, hum = info.hum, root = root, info = info, t0 = now(), offT = 0}
        local ok = pcall(function()
            e.att = own(new("Attachment", {Name = "SecretHoldAtt", Parent = root}))
            e.align = own(new("AlignPosition", {Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = e.att, MaxForce = 1e7,
                MaxVelocity = 120, Responsiveness = 60, Position = root.Position, Parent = root}))
            e.orient = own(new("AlignOrientation", {Mode = Enum.OrientationAlignmentMode.OneAttachment, Attachment0 = e.att, MaxTorque = 1e7,
                Responsiveness = 30, CFrame = root.CFrame, Parent = root}))
        end)
        if not ok then release(info.model) return end
        pcall(function() info.hum.PlatformStand = true end)   -- limp, dangling like a marionette
        HOLD.held[info.model] = e
        settings.stats.held = (tonumber(settings.stats.held) or 0) + 1
        stringsFor(e)
        if KIT.emit and not lite() then pcall(KIT.emit, root.Position, C.smoke, 10, 8, 0.7, 0.5, C.smoke) end
    end

    local scanAcc, smokeAcc, lastNote = 0, 0, 0
    onHeartbeat("puppethold43", function(dt)
        if settings.puppetHold ~= true then
            if next(HOLD.held) then releaseAll() end
            HOLD.paused = nil
            return
        end
        local r = hrp()
        if not r then releaseAll() return end
        -- players first: anything near / hunting you -> let go at once
        local why = PVE.playerGuard and PVE.playerGuard()
        if why then
            if next(HOLD.held) then releaseAll(why) end
            HOLD.paused = why
            return
        end
        HOLD.paused = nil
        local t = now()
        local look = flat(r.CFrame.LookVector)
        look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
        local center = r.Position + look * 6
        local leash = math.clamp(tonumber(settings.holdLeash) or 60, 20, 200)
        if anchorPart then pcall(function() anchorPart.CFrame = CFrame.lookAt(center + Vector3.new(0, 10, 0), center + Vector3.new(0, 10, 0) + look) end) end

        -- keep every held NPC in its slot; drop it when the server takes it back
        local list, n = {}, 0
        for m, e in pairs(HOLD.held) do
            local sp = spawnOf[m]
            local leashed = sp and (center - sp).Magnitude > leash
            if leashed or not (m.Parent and e.root.Parent and e.hum.Parent and e.hum.Health > 0 and PVE.isNpcInfo(e.info)) then release(m)
            else n += 1 list[n] = e end
        end
        for i, e in ipairs(list) do
            local ang = (i / math.max(n, 1)) * math.pi * 2 + t * 0.4
            local rad = (n <= 1) and 0 or (1.6 + 0.22 * n)
            local sway = Vector3.new(math.sin(t * 2.1 + i) * 0.25, math.sin(t * 1.7 + i * 1.3) * 0.35, math.cos(t * 1.9 + i) * 0.25)
            local slot = center + Vector3.new(math.cos(ang) * rad, 0.6, math.sin(ang) * rad) + sway
            pcall(function()
                e.align.Position = slot
                e.orient.CFrame = CFrame.lookAt(slot, Vector3.new(r.Position.X, slot.Y, r.Position.Z)) * CFrame.Angles(math.sin(t * 2 + i) * 0.12, 0, math.cos(t * 1.6 + i) * 0.1)
                e.root.AssemblyLinearVelocity = Vector3.zero
            end)
            for bi, b in ipairs(e.beams or {}) do
                b.CurveSize0 = 0.4 * math.sin(t * 1.4 + bi + i)
                b.CurveSize1 = -0.3 * math.cos(t * 1.2 + bi * 0.7 + i)
            end
            local api = ownerApi(e.root)
            -- 1.2 s grace while it travels in, then: server says not ours, or it keeps snapping away -> drop it
            if api == false or (t - e.t0 > 1.2 and (e.root.Position - slot).Magnitude > 8) then e.offT += dt else e.offT = 0 end
            -- V2.3: a direct CFrame hold on top of the AlignPosition (Blox Fruits humanoids fight the align alone)
            if t - e.t0 > 0.5 and e.offT == 0 and (e.root.Position - slot).Magnitude > 3 then
                pcall(function() e.root.CFrame = CFrame.lookAt(slot, Vector3.new(r.Position.X, slot.Y, r.Position.Z)) end)
            end
            if e.offT > 0.6 then
                verdict[e.model] = false verdictT[e.model] = t
                HOLD.failed += 1
                release(e.model)
            end
        end
        if n > 0 then
            if VFX.handsMode then VFX.handsMode("hold", {pos = center}, 0.35) end
            smokeAcc += dt
            if smokeAcc > (lite() and 2.4 or 1.1) and KIT.emit then
                smokeAcc = 0
                local e = list[math.random(1, n)]
                pcall(KIT.emit, e.root.Position + Vector3.new(0, 1.5, 0), C.smoke, lite() and 4 or 8, 6, 0.8, 0.5, C.smoke)
            end
        end

        -- gather new ones (2x per second)
        scanAcc += dt
        if scanAcc < 0.5 then return end
        scanAcc = 0
        local maxN = lite() and 5 or 8
        local radius = math.clamp(tonumber(settings.holdRadius) or 30, 10, 60)
        for _, info in ipairs(SEN.list or {}) do
            if n >= maxN then break end
            if not HOLD.held[info.model] and PVE.isNpcInfo(info) and (info.hostile or info.enemy) and info.dist and info.dist <= radius then
                local sp = spawnPos(info)
                if not sp or (center - sp).Magnitude <= leash then
                    local own_ = checkOwner(info)
                    if own_ == true then grab(info) n += 1 HOLD.unsupported = false end
                end
            end
        end
        -- honest notices (per mob, never a game-wide switch-off)
        local recentOwned = 0
        for _, v in pairs(verdict) do if v == true then recentOwned += 1 end end
        if n == 0 and HOLD.tested >= 4 and recentOwned == 0 then noteUnsupported()
        elseif HOLD.tested >= 6 and HOLD.owned / HOLD.tested < 0.2 and t - lastNote > 45 then
            lastNote = t
            toast("Puppet Hold: most mobs here stay server-owned. " .. HOLD.owned .. " of " .. HOLD.tested .. " could be held so far.", "info", 4)
        end
        -- optional: walk toward the nearest mob spawn cluster when nothing is held (short dashes, players guard first)
        if n == 0 and settings.holdGoSpawn == true and t - (HOLD.lastGo or 0) > 2 and not MOV.carrying and not HUB.rescueBusy then
            local w = W()
            local cl = w and w.nearestMobCluster and w.nearestMobCluster(r.Position, 300)
            if cl then
                local d = flat(cl.pos - r.Position)
                if d.Magnitude > 14 then
                    HOLD.lastGo = t
                    HOLD.goal = cl.name
                    pcall(MOV.dashTo, r.Position + d.Unit * math.min(d.Magnitude - 10, 32))
                end
            end
        end
    end)

    function HOLD.status()
        if settings.puppetHold ~= true then return "off" end
        if HOLD.unsupported then return "no client-owned mob near you right now (re-testing)" end
        if HOLD.paused then return "released (" .. HOLD.paused .. ")" end
        local n = 0
        for _ in pairs(HOLD.held) do n += 1 end
        return "holding " .. n .. " · " .. HOLD.owned .. "/" .. HOLD.tested .. " NPCs ownable" .. (netOwnerFn and "" or " (move test)")
    end
    CORE.onChar("hold43", function() releaseAll() end)
    onUnload(function()
        releaseAll()
        for _, b in ipairs(HOLD.beams) do pcall(function() b:Destroy() end) end
        if anchorPart then pcall(function() anchorPart:Destroy() end) end
    end)
end)

-- =====================================================================
-- 14q. Explorer Scanner 4.3: read-only world model (throttled, chunked, mobile-safe)
--   Walks Workspace, ReplicatedStorage, your Backpack + PlayerGui and Lighting a few hundred
--   instances per frame (no GetDescendants spike), then follows DescendantAdded incrementally.
--   Builds: mob folders + spawns, quest givers, drops / fruits / chests, hazards, water / sea parts,
--   safe zones, tools, remotes (names only, NEVER fired), and which mobs / parts this client can move.
--   Feeds Mob Gather (spawns, clusters), Loot Grab (drops), Safe Zone (pickSafe), Water Walk and
--   Boss Choreography (boss flags). Nothing here changes the game.
-- =====================================================================
CORE.safeModule("14q Explorer Scanner 4.3", function()
    local RS_ = svc("ReplicatedStorage")
    local Lighting_ = svc("Lighting")
    local W = {mobs = setmetatable({}, {__mode = "k"}), folders = setmetatable({}, {__mode = "k"}), spawns = {}, quest = setmetatable({}, {__mode = "k"}),
        drops = setmetatable({}, {__mode = "k"}), hazards = setmetatable({}, {__mode = "k"}), safe = {}, tools = setmetatable({}, {__mode = "k"}),
        remotes = {}, remoteN = 0, water = 0, guis = 0, visited = 0, state = "idle", startedAt = 0, doneAt = 0, queue = {}, sky = "-"}
    CORE.world = W
    local function now() return os.clock() end
    local function lite() return PERF.lite or isTouch end
    local netOwnerFn = exfn("isnetworkowner")
    -- V2.3 game profile (Blox Fruits: Enemies folder, spawn markers, quest NPCs, sea level, combat styles)
    local function PFn() return GAMEINFO and GAMEINFO.module and GAMEINFO.module.profile or nil end   -- known after the boot's game detection
    local function pathOf(list)
        local o = workspace
        for _, n in ipairs(list) do o = o and o:FindFirstChild(n) end
        return o
    end
    local function low(x) return string.lower(tostring(x)) end
    local function has(n, words) for _, w in ipairs(words) do if string.find(n, w, 1, true) then return true end end return false end
    local QUEST = {"quest", "giver", "merchant", "shop", "dealer", "trainer", "vendor", "teacher", "master"}
    local DROP = {"fruit", "chest", "drop", "coin", "gem", "loot", "orb", "cash", "money", "reward"}
    local HAZ = {"lava", "kill", "acid", "spike", "poison", "laser", "damage", "deathzone", "void"}
    local SAFE = {"safezone", "safe zone", "safe_zone", "sanctuary", "nopvp", "no pvp", "peace"}
    local SPAWN = {"spawn", "spawner"}
    local MOBF = {"mob", "enemy", "enemies", "npc", "boss", "monster", "creature"}
    local function isOurs(o) local ok, v = pcall(function() return o:GetAttribute("SecretHub") end) return ok and v == true end
    local function isPlayerChar(m) local ok, p = pcall(function() return Players:GetPlayerFromCharacter(m) end) return (not ok) or p ~= nil end
    local function movable(part)
        if not part or not part:IsA("BasePart") or part.Anchored then return false end
        if netOwnerFn then local ok, v = pcall(netOwnerFn, part) if ok then return v == true end end
        local ok, age = pcall(function() return part.ReceiveAge end)
        return ok and tonumber(age) == 0
    end
    W.movable = movable
    local function posOf(o)
        if o:IsA("BasePart") then return o.Position end
        if o:IsA("Model") then local ok, cf = pcall(function() return o:GetPivot() end) if ok then return cf.Position end end
        return nil
    end

    -- ---------------- classification (cheap: names + classes only) ----------------
    local function classify(d, root)
        W.visited += 1
        if isOurs(d) then return false end
        local cls = d.ClassName
        if cls == "RemoteEvent" or cls == "RemoteFunction" or cls == "UnreliableRemoteEvent" then
            W.remoteN += 1
            if #W.remotes < 300 then
                local ok, path = pcall(function() return d:GetFullName() end)
                W.remotes[#W.remotes + 1] = {name = d.Name, class = cls, path = ok and path or d.Name}
            end
            return false
        end
        if root == "gui" then if d:IsA("GuiObject") then W.guis += 1 end return false end
        if root ~= "ws" then
            if d:IsA("Tool") and root == "pack" then W.tools[d] = "backpack" end
            if root == "light" and d:IsA("Sky") then W.sky = "custom sky" end
            return false
        end
        local n = low(d.Name)
        if d:IsA("Model") then
            if d == LP.Character then return true end
            local h = d:FindFirstChildOfClass("Humanoid")
            if h then
                if isPlayerChar(d) then return true end   -- never record player characters
                if has(n, QUEST) or (W.questFolder and d.Parent == W.questFolder) then W.quest[d] = true return true end
                local folder = d.Parent
                local p = posOf(d)
                W.mobs[d] = {spawn = p, folder = folder, name = d.Name, maxHp = h.MaxHealth}
                if folder then
                    local f = W.folders[folder] or {n = 0, name = folder.Name}
                    f.n += 1
                    W.folders[folder] = f
                end
                return true   -- no need to walk inside a character
            end
            if has(n, DROP) then W.drops[d] = true end
        elseif d:IsA("BasePart") then
            if d:IsA("SpawnLocation") or has(n, SAFE) then
                W.safe[#W.safe + 1] = d.Position + Vector3.new(0, d.Size.Y / 2 + 3, 0)
                if #W.safe > 60 then table.remove(W.safe, 1) end
                if CORE.addSafe then pcall(CORE.addSafe, W.safe[#W.safe]) end
            elseif has(n, SPAWN) and (has(n, MOBF) or (d.Parent and has(low(d.Parent.Name), MOBF))) then
                if #W.spawns < 400 then W.spawns[#W.spawns + 1] = {pos = d.Position, name = d.Name} end
            elseif has(n, HAZ) then W.hazards[d] = true
            elseif has(n, DROP) or (VFX.goodPickup and VFX.goodPickup(d)) then W.drops[d] = true
            elseif CORE.waterAdd and CORE.waterAdd(d) then W.water += 1 end
        elseif d:IsA("Tool") then W.tools[d] = "world"
            local hd = d:FindFirstChild("Handle")
            if hd then W.drops[hd] = true end
        end
        return false
    end

    -- ---------------- chunked walk (stack of children, budget per frame) ----------------
    local stack = {}
    local function push(inst, root) stack[#stack + 1] = {inst, root} end
    function W.rescan()
        W.mobs = setmetatable({}, {__mode = "k"}) W.folders = setmetatable({}, {__mode = "k"}) W.spawns = {}
        W.quest = setmetatable({}, {__mode = "k"}) W.drops = setmetatable({}, {__mode = "k"}) W.hazards = setmetatable({}, {__mode = "k"})
        W.safe = {} W.tools = setmetatable({}, {__mode = "k"}) W.remotes = {} W.remoteN, W.water, W.guis, W.visited = 0, 0, 0, 0
        stack = {}
        push(workspace, "ws")
        if RS_ then push(RS_, "rs") end
        if Lighting_ then push(Lighting_, "light") end
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then push(bp, "pack") end
        local pgui = LP:FindFirstChildOfClass("PlayerGui")
        if pgui then push(pgui, "gui") end
        W.state, W.startedAt = "scanning", now()
        -- V2.3: profile folders first (exact, no guessing)
        local PF = PFn()
        W.profile = PF
        if PF then
            W.questFolder = PF.questNpcs and workspace:FindFirstChild(PF.questNpcs) or nil
            local sp = PF.spawns and pathOf(PF.spawns)
            if sp then
                for _, s in ipairs(sp:GetChildren()) do
                    local p = posOf(s)
                    if p and #W.spawns < 400 then W.spawns[#W.spawns + 1] = {pos = p, name = s.Name} end
                end
            end
        end
    end
    -- V2.3: your own kit, read from the tools you carry (Blox Fruits tags them: Melee / Sword / Blox Fruit / Gun)
    function W.kit()
        local PF = PFn()
        local out = {}
        local function add(t)
            if not t:IsA("Tool") then return end
            local tip = tostring(t.ToolTip or "")
            local kind = PF and PF.styles and PF.styles[tip]
            if not kind then
                local n = low(t.Name .. " " .. tip)
                kind = (string.find(n, "fruit", 1, true) and "fruit") or (string.find(n, "sword", 1, true) and "sword") or (string.find(n, "gun", 1, true) and "gun") or nil
            end
            if kind and not out[kind] then out[kind] = t.Name end
        end
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then for _, t in ipairs(bp:GetChildren()) do add(t) end end
        local c = LP.Character
        if c then for _, t in ipairs(c:GetChildren()) do add(t) end end
        return out
    end
    function W.kitStatus()
        local k = W.kit()
        local parts = {}
        for _, n in ipairs({"melee", "sword", "fruit", "gun"}) do if k[n] then parts[#parts + 1] = n .. ": " .. k[n] end end
        return #parts > 0 and table.concat(parts, " · ") or "no combat tool found"
    end
    function W.enemyFolder() local PF = PFn() return PF and PF.enemies and workspace:FindFirstChild(PF.enemies) or nil end
    function W.profileStatus()
        local PF = PFn()
        if not PF then return "universal (no game profile) · mobs found by Humanoid" end
        local ef = W.enemyFolder()
        local alive_, near = 0, 0
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if ef then
            for _, m in ipairs(ef:GetChildren()) do
                local h = m:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    alive_ += 1
                    local rr = r and m:FindFirstChild("HumanoidRootPart")
                    if rr and (rr.Position - r.Position).Magnitude < 120 then near += 1 end
                end
            end
        end
        local q = 0
        if W.questFolder then q = #W.questFolder:GetChildren() end
        return (GAMEINFO.moduleName or "game") .. " · " .. (ef and (alive_ .. " enemies in " .. PF.enemies .. " (" .. near .. " near, movable when you are close)") or (PF.enemies .. " folder not loaded yet"))
            .. " · " .. #W.spawns .. " spawns · " .. q .. " quest NPCs · sea level y " .. tostring(CORE.seaTop and CORE.seaTop() or PF.seaLevel)
    end
    -- V2.4: ring queue (head index) instead of table.remove(added, 1): Blox Fruits spawns hundreds of effect
    -- parts per fight and the old shift cost grew with the backlog on every frame
    local added, addHead = {}, 1
    bind(workspace.DescendantAdded:Connect(function(d)
        if settings.scanner == false or (#added - addHead) > 2000 then return end
        added[#added + 1] = d
    end))
    onHeartbeat("scanner43", function()
        if settings.scanner == false then return end
        if W.state == "idle" then W.rescan() end
        local budget = lite() and 120 or 360
        local t0 = os.clock()
        while budget > 0 and #stack > 0 and os.clock() - t0 < 0.002 do
            local top = table.remove(stack)
            local inst, root = top[1], top[2]
            local skip = false
            if inst ~= workspace and inst ~= RS_ and inst ~= Lighting_ then
                local ok, r = pcall(classify, inst, root)
                skip = ok and r
            end
            if not skip then
                local ok, kids = pcall(function() return inst:GetChildren() end)
                if ok then for _, k in ipairs(kids) do stack[#stack + 1] = {k, root} end end
            end
            budget -= 1
        end
        if W.state == "scanning" and #stack == 0 then
            W.state, W.doneAt = "ready", now()
            CORE.log("SCAN", W.summary())
        end
        -- incremental: new instances in small batches (deferred so names / children exist)
        local n = 0
        while addHead <= #added and n < (lite() and 20 or 60) do
            local d = added[addHead]
            added[addHead] = false
            addHead += 1
            n += 1
            if d.Parent then
                local m = d:IsA("Model") and d or nil
                if m or d:IsA("BasePart") or d:IsA("Tool") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    -- inside a mob? attach to the mob instead of classifying limbs
                    local mdl = d:FindFirstAncestorWhichIsA("Model")
                    if not (mdl and W.mobs[mdl]) then pcall(classify, d, "ws") end
                end
            end
        end
        if addHead > #added then table.clear(added) addHead = 1 end
    end)

    -- ---------------- queries used by the other features ----------------
    function W.spawnOf(model)
        local e = W.mobs[model]
        if e and e.spawn then return e.spawn end
        if not model then return nil end
        local p = posOf(model)
        if not p then return nil end
        local best, bd
        for _, s in ipairs(W.spawns) do
            local d = (s.pos - p).Magnitude
            if d < 80 and (not bd or d < bd) then best, bd = s.pos, d end
        end
        return best
    end
    function W.isBoss(model)
        if not model then return false end
        if string.find(low(model.Name), "boss", 1, true) then return true end
        local e = W.mobs[model]
        return e ~= nil and (e.maxHp or 0) >= 5000
    end
    function W.dropsNear(pos, r)
        local out = {}
        for p in pairs(W.drops) do
            if p.Parent and p:IsA("BasePart") and (p.Position - pos).Magnitude <= r then
                out[#out + 1] = p
                if #out >= 8 then break end
            end
        end
        return out
    end
    -- nearest group of living mobs (by folder), center = average live position
    function W.nearestMobCluster(from, maxD)
        local groups = {}
        for m, e in pairs(W.mobs) do
            local h = m.Parent and m:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 and e.folder then
                local p = posOf(m)
                if p then
                    local g = groups[e.folder] or {sum = Vector3.zero, n = 0, name = e.folder.Name}
                    g.sum += p g.n += 1
                    groups[e.folder] = g
                end
            end
        end
        local best, bd
        for _, g in pairs(groups) do
            if g.n >= 2 then
                local c = g.sum / g.n
                local d = (c - from).Magnitude
                if d <= maxD and (not bd or d < bd) then best, bd = {pos = c, name = g.name, n = g.n}, d end
            end
        end
        return best
    end
    local function count(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
    function W.counts()
        local mobs, mov = 0, 0
        for m, _ in pairs(W.mobs) do
            if m.Parent then
                mobs += 1
                if mov < 200 then
                    local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if r and movable(r) then mov += 1 end
                end
            end
        end
        local dm = 0
        for p in pairs(W.drops) do if p.Parent and p:IsA("BasePart") and movable(p) then dm += 1 end end
        return {mobs = mobs, movableMobs = mov, folders = count(W.folders), spawns = #W.spawns, quest = count(W.quest), drops = count(W.drops),
            movableDrops = dm, hazards = count(W.hazards), safe = #W.safe, tools = count(W.tools), remotes = W.remoteN, water = W.water}
    end
    function W.summary()
        local c = W.counts()
        return c.mobs .. " mobs (" .. c.movableMobs .. " movable) in " .. c.folders .. " folders · " .. c.spawns .. " spawns · " .. c.quest .. " quest · "
            .. c.drops .. " drops · " .. c.hazards .. " hazards · " .. c.water .. " water · " .. c.safe .. " safe · " .. c.tools .. " tools · " .. c.remotes .. " remotes"
    end
    function W.status()
        if settings.scanner == false then return "off" end
        if W.state == "scanning" then return "scanning · " .. W.visited .. " checked · " .. #stack .. " left" end
        return "ready · " .. W.visited .. " checked in " .. string.format("%.1f", W.doneAt - W.startedAt) .. " s · live updates"
    end
    function W.remoteList(k)
        local out = {}
        for i = 1, math.min(k or 3, #W.remotes) do out[#out + 1] = W.remotes[i].name end
        return #out > 0 and table.concat(out, ", ") or "none"
    end
end)

-- =====================================================================
-- 14r. Secret Hub V2 (5.0): Guardian Awakening + Kamui Escape
--   Awakening: one button, 20 s cinematic ultimate. An ink-spirit guardian (white glowing eyes)
--   rises behind you, the screen drains to monochrome, and for the duration Auto-Dodge + Lifeline
--   Rescue run boosted, plus Mob Gather / Shadow Strikes on NPCs (their own player guards stay
--   active). Everything is restored afterwards. Visual + your own defence only.
--   5.5: the orbiting mini-hand ring is gone (same as the main hand models).
--   Kamui Escape: when you are in real danger (or on the button), a swirl distortion pulls the
--   camera in and you reappear at the nearest known safe zone. Verified: if the game pulls you back,
--   it says so honestly.
-- =====================================================================
CORE.safeModule("14r Secret Hub V2", function()
    local KIT = VFX._kit or {}
    local SEN, STK = CORE.sense, CORE.stalk
    local function now() return os.clock() end
    local function lite() return PERF.lite or isTouch end
    local function say(kind, vars, prio) if VFX.say then pcall(VFX.say, kind, vars, prio) end end
    local function mkPart(props)
        if not KIT.part then return nil end
        local p = KIT.part(props)
        p.Transparency = 1
        return p
    end
    local INK, WHITE = C.smoke, Color3.new(1, 1, 1)

    -- ======================= shared settings override stack =======================
    -- Awakening and Farm Brain both switch features on for a while. Each key remembers the user's
    -- ORIGINAL value when the first override takes it and gets it back only when the last one lets go,
    -- in any order (reference counted). Panic resets the stack first, then switches everything off.
    local OV = {orig = {}, count = {}, owners = {}}
    CORE.override = OV
    function OV.push(owner, values)
        if OV.owners[owner] then return end
        local keys = {}
        for k, v in pairs(values) do
            if (OV.count[k] or 0) == 0 then OV.orig[k] = settings[k] end
            OV.count[k] = (OV.count[k] or 0) + 1
            settings[k] = v
            keys[#keys + 1] = k
        end
        OV.owners[owner] = keys
        if K.refreshToggles then pcall(K.refreshToggles) end
    end
    function OV.pop(owner)
        local keys = OV.owners[owner]
        if not keys then return end
        OV.owners[owner] = nil
        for _, k in ipairs(keys) do
            OV.count[k] = math.max(0, (OV.count[k] or 1) - 1)
            if OV.count[k] == 0 then settings[k] = OV.orig[k] OV.orig[k] = nil end
        end
        if K.refreshToggles then pcall(K.refreshToggles) end
    end
    function OV.active(owner) return OV.owners[owner] ~= nil end
    function OV.reset()
        for k, n in pairs(OV.count) do if n > 0 then settings[k] = OV.orig[k] end end
        OV.orig, OV.count, OV.owners = {}, {}, {}
        if K.refreshToggles then pcall(K.refreshToggles) end
    end

    -- ======================= Guardian Awakening =======================
    local AW = {active = false, untilT = 0, lastT = -100, built = false, minis = {}, sus = {}, alpha = 0}
    CORE.awaken = AW
    local DUR, COOLDOWN = 20, 60
    local function ellip(p) new("SpecialMesh", {Parent = p, MeshType = Enum.MeshType.Sphere}) return p end
    local function buildMini()
        local m = {parts = {}}
        local function add(p, base) if p then m.parts[#m.parts + 1] = {p = p, base = base} end return p end
        m.palm = add(ellip(mkPart({Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(1.5, 0.36, 1.5)})), 0.2)
        m.rim = (not lite()) and add(ellip(mkPart({Material = Enum.Material.Neon, Color = C.spirit, Size = Vector3.new(1.7, 0.46, 1.7)})), 0.78) or nil
        m.f = {}
        for fi = 1, 5 do
            local L = ({0.95, 1.08, 1.0, 0.78, 0.75})[fi]
            local seg = add(mkPart({Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(L, 0.26, 0.26)}), 0.2)
            local tip = add(mkPart({Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.24, 0.24, 0.24)}), 0)
            m.f[fi] = {seg = seg, tip = tip, L = L}
        end
        return m
    end
    local function buildSusanoo()
        local s = {}
        local function add(key, props, mesh, base)
            local p = mkPart(props)
            if p and mesh then ellip(p) end
            if p then s[#s + 1] = {p = p, base = base, key = key} end
            return p
        end
        add("torso", {Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(5.6, 8.6, 3.6)}, true, 0.62)
        add("head", {Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(3.6, 4.2, 3.6)}, true, 0.55)
        add("eyeL", {Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.9, 0.22, 0.2)}, true, 0)
        add("eyeR", {Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.9, 0.22, 0.2)}, true, 0)
        if not lite() then
            add("aura", {Material = Enum.Material.ForceField, Color = C.spirit, Size = Vector3.new(11, 14, 7)}, true, 0.8)
            add("chest", {Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(9, 3.6, 4.4)}, true, 0.6)
            add("shL", {Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(5.2, 1.3, 4.2)}, true, 0.58)
            add("shR", {Material = Enum.Material.SmoothPlastic, Color = INK, Size = Vector3.new(5.2, 1.3, 4.2)}, true, 0.58)
            add("crestL", {Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.16, 2.6, 0.16)}, false, 0.2)
            add("crestR", {Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.new(0.16, 2.6, 0.16)}, false, 0.2)
            for k = 1, 3 do add("rib" .. k, {Material = Enum.Material.Neon, Color = C.spirit, Size = Vector3.new(6.4 - k * 0.8, 0.12, 0.12)}, false, 0.35) end
        end
        local eye = s[3] and s[3].p
        if eye then AW.eyeLight = new("PointLight", {Parent = eye, Color = WHITE, Range = 10, Brightness = 0, Shadows = false}) end
        return s
    end
    local function setAlphaAll(a)
        for _, m in ipairs(AW.minis) do for _, it in ipairs(m.parts) do it.p.Transparency = 1 - (1 - it.base) * a end end
        for _, it in ipairs(AW.sus) do it.p.Transparency = 1 - (1 - it.base) * a end
        if AW.eyeLight then AW.eyeLight.Brightness = 3 * a end
    end
    local function parentAll(on)
        local par = on and workspace or nil
        for _, m in ipairs(AW.minis) do for _, it in ipairs(m.parts) do it.p.Parent = par end end
        for _, it in ipairs(AW.sus) do it.p.Parent = par end
    end
    local function restore() OV.pop("awaken") end
    function AW.stop(quiet)
        if not AW.active then return end
        AW.active = false
        restore()
        if CORE.pve and CORE.pve.hold and settings.puppetHold ~= true then pcall(CORE.pve.hold.releaseAll) end
        if AW.cc then tween(AW.cc, 0.8, {Saturation = 0, Contrast = 0, Brightness = 0, TintColor = WHITE}) local cc = AW.cc AW.cc = nil task.delay(0.9, function() pcall(function() cc:Destroy() end) end) end
        task.spawn(function()
            for k = 10, 0, -1 do AW.alpha = k / 10 setAlphaAll(AW.alpha) task.wait(0.05) end
            if not AW.active then parentAll(false) end
        end)
        if not quiet then toast("Guardian Awakening fades. Still watching over you.", "info", 3) end
    end
    function AW.start()
        if AW.active then return end
        local r = hrp()
        if not r then return end
        local left = COOLDOWN - (now() - AW.lastT)
        if left > 0 then toast("Guardian Awakening recharges in " .. math.ceil(left) .. " s.", "info", 2) return end
        if settings.vfx == false then toast("Turn Visual Effects on for the Awakening.", "info", 3) return end
        AW.lastT = now()
        settings.stats.awaken = (tonumber(settings.stats.awaken) or 0) + 1
        pcall(saveSettings)
        if not AW.built then
            AW.built = true
            -- 5.5: no orbiting mini-hand ring; ink-spirit figure only
            AW.minis = {}
            AW.sus = buildSusanoo()
        end
        local boost = {autododge = true, handsRescue = true}
        if settings.awakenPve ~= false then boost.puppetHold = true boost.shadowM1 = true end
        OV.push("awaken", boost)
        AW.active, AW.untilT, AW.t0 = true, now() + DUR, now()
        parentAll(true)
        -- cinematic: monochrome drain, FOV punch, ink burst
        pcall(function()
            AW.cc = own(new("ColorCorrectionEffect", {Name = "SecretAwaken", Parent = SVC.Lighting, Saturation = 0, Contrast = 0}))
            tween(AW.cc, 0.6, {Saturation = -0.9, Contrast = 0.28, Brightness = -0.04, TintColor = Color3.fromRGB(225, 228, 240)})
        end)
        local cam = workspace.CurrentCamera
        if cam then
            local fov = cam.FieldOfView
            tween(cam, 0.25, {FieldOfView = fov + 12})
            task.delay(0.3, function() if cam then tween(cam, 0.7, {FieldOfView = fov}) end end)
        end
        if KIT.emit then pcall(KIT.emit, r.Position, INK, lite() and 14 or 34, 16, 1.2, 0.8, INK) pcall(KIT.emit, r.Position + Vector3.new(0, 3, 0), C.spiritCore, lite() and 6 or 16, 12, 0.7, 0.4, C.spirit) end
        if settings.handsVisual == true and VFX.handsMode then VFX.handsMode("victory", nil, 1.2) end
        say("awaken", {}, 3)
        toast("Guardian Awakening. 20 s: boosted dodge and rescue, Mob Gather and Shadow Strikes on NPCs.", "shield", 4)
    end
    local acc = 0
    onHeartbeat("awaken5", function(dt)
        if not AW.active then return end
        local r, h = hrp(), hum()
        if not (r and h and h.Health > 0) or now() > AW.untilT then AW.stop() return end
        acc += dt
        if lite() and acc < 1 / 30 then return end
        acc = 0
        local t = now()
        local a = math.min(1, (t - AW.t0) / 0.8)
        if a ~= AW.alpha then AW.alpha = a setAlphaAll(a) end
        local pb, cb = {}, {}
        local function put(p, c) if p then pb[#pb + 1] = p cb[#cb + 1] = c end end
        -- ink-spirit guardian behind you, breathing
        local base = r.CFrame * CFrame.new(0, 4.5 + math.sin(t * 1.4) * 0.25, 3.6)
        for _, it in ipairs(AW.sus) do
            local k = it.key
            local c
            if k == "torso" then c = base
            elseif k == "aura" then c = base * CFrame.new(0, 1.2, 0)
            elseif k == "head" then c = base * CFrame.new(0, 6.2, -0.3)
            elseif k == "eyeL" then c = base * CFrame.new(-0.75, 6.5, -2.05) * CFrame.Angles(0, 0, math.rad(-12))
            elseif k == "eyeR" then c = base * CFrame.new(0.75, 6.5, -2.05) * CFrame.Angles(0, 0, math.rad(12))
            elseif k == "chest" then c = base * CFrame.new(0, 2.4, -0.1)
            elseif k == "shL" then c = base * CFrame.new(-5.2, 3.9, 0) * CFrame.Angles(0, 0, math.rad(22))
            elseif k == "shR" then c = base * CFrame.new(5.2, 3.9, 0) * CFrame.Angles(0, 0, math.rad(-22))
            elseif k == "crestL" then c = base * CFrame.new(-0.9, 8.6, -0.6) * CFrame.Angles(0, 0, math.rad(28))
            elseif k == "crestR" then c = base * CFrame.new(0.9, 8.6, -0.6) * CFrame.Angles(0, 0, math.rad(-28))
            else
                local i = tonumber(string.sub(k, 4)) or 1
                c = base * CFrame.new(0, 2.4 - i * 1.5, -2.3)
            end
            put(it.p, c)
        end
        local ok = pcall(function() workspace:BulkMoveTo(pb, cb, Enum.BulkMoveMode.FireCFrameChanged) end)
        if not ok then for i = 1, #pb do pb[i].CFrame = cb[i] end end
    end)
    function AW.status()
        if AW.active then return "AWAKENED · " .. math.ceil(AW.untilT - now()) .. " s left" end
        local left = COOLDOWN - (now() - AW.lastT)
        return left > 0 and ("recharging · " .. math.ceil(left) .. " s") or "ready"
    end

    -- ======================= Kamui Escape =======================
    local KM = {lastT = -100, ok = 0, fail = 0}
    CORE.kamui = KM
    local swirl
    local function swirlFx(dur)
        if settings.vfx == false then return end
        if not swirl then
            swirl = new("Frame", {Parent = gui, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 300})
            for k = 1, (lite() and 3 or 6) do
                local ring = new("Frame", {Parent = swirl, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3 * k, 0.3 * k),
                    SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = (k % 2 == 0) and C.smoke or WHITE, BackgroundTransparency = 0.2, ZIndex = 300 + k}, {corner(999)})
                new("UIGradient", {Parent = ring, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.35, 1),
                    NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1)})})
            end
        end
        swirl.Visible = true
        local t0 = now()
        task.spawn(function()
            while now() - t0 < dur and alive do
                local u = (now() - t0) / dur
                for k, ring in ipairs(swirl:GetChildren()) do
                    local g = ring:FindFirstChildOfClass("UIGradient")
                    if g then g.Rotation = (g.Rotation + (8 + k * 3) * (k % 2 == 0 and -1 or 1)) % 360 end
                    ring.BackgroundTransparency = 0.15 + 0.85 * math.abs(u * 2 - 1)
                    ring.Size = UDim2.fromScale(0.3 * k * (1.4 - math.sin(u * math.pi) * 0.9), 0.3 * k * (1.4 - math.sin(u * math.pi) * 0.9))
                end
                task.wait()
            end
            swirl.Visible = false
        end)
    end
    local function safeTarget(from)
        local best, bd
        local w = CORE.world
        for _, p in ipairs((w and w.safe) or {}) do
            local d = (p - from).Magnitude
            if d >= 20 and d <= 2500 and (not bd or d < bd) then best, bd = p, d end
        end
        if best then return best, "safe zone" end
        local hc = CORE.hands
        local enemy = SEN.top and SEN.top.root and SEN.top.root.Position
        local p = hc and hc.pickSafe and hc.pickSafe(from, enemy, "kamui")
        if p then return p + Vector3.new(0, 1, 0), "last safe ground" end
        return nil
    end
    function KM.trigger(reason)
        local r = hrp()
        if not r then return false end
        if now() - KM.lastT < 25 then if reason == "button" then toast("Kamui recharges in " .. math.ceil(25 - (now() - KM.lastT)) .. " s.", "info", 2) end return false end
        local target, kind = safeTarget(r.Position)
        if not target then if reason == "button" then toast("Kamui: no safe zone known yet. The Explorer Scanner or a few safe steps will find one.", "info", 3) end return false end
        KM.lastT = now()
        swirlFx(0.9)
        local cam = workspace.CurrentCamera
        local fov = cam and cam.FieldOfView or 70
        if cam then tween(cam, 0.35, {FieldOfView = math.max(30, fov - 30)}) end
        if KIT.emit then pcall(KIT.emit, r.Position, INK, lite() and 10 or 26, 10, 0.9, 0.6, INK) end
        task.delay(0.4, function()
            local rr = hrp()
            if not rr then return end
            pcall(function() rr.AssemblyLinearVelocity = Vector3.zero rr.CFrame = CFrame.new(target + Vector3.new(0, 3, 0)) * (rr.CFrame - rr.CFrame.Position) end)
            if cam then tween(cam, 0.5, {FieldOfView = fov}) end
            if KIT.emit then pcall(KIT.emit, target, INK, lite() and 8 or 20, 10, 0.8, 0.6, INK) end
            task.delay(0.7, function()
                local r2 = hrp()
                if r2 and (r2.Position - target).Magnitude < 14 then
                    KM.ok += 1
                    settings.stats.kamui = (tonumber(settings.stats.kamui) or 0) + 1
                    pcall(saveSettings)
                    say("kamui_ok", {}, 3)
                    -- verified escape from a real hunter -> the public taunt is earned
                    if STK and STK.activeCount and STK.activeCount() > 0 and VFX.taunt then pcall(VFX.taunt, "escape") end
                    toast("Kamui: you're at the " .. kind .. ".", "shield", 3)
                else
                    KM.fail += 1
                    toast("Kamui: the game pulled you back. Teleports are reverted here.", "warn", 4)
                end
            end)
        end)
        return true
    end
    onHeartbeat("kamui5", function()
        if settings.kamui ~= true then return end
        local h = hum()
        if not h or h.Health <= 0 then return end
        local low = h.Health / math.max(h.MaxHealth, 1) * 100 < math.clamp(tonumber(settings.kamuiHp) or 30, 10, 60)
        local hurt = now() - (SEN.lastHitT or -10) < 1.5
        local danger = SEN.combat or (STK and STK.activeCount and STK.activeCount() > 0)
        if low and hurt and danger then KM.trigger("auto") end
    end)
    function KM.status()
        local left = 25 - (now() - KM.lastT)
        return (left > 0 and ("recharging " .. math.ceil(left) .. " s") or "ready") .. " · " .. KM.ok .. " escapes · " .. KM.fail .. " reverted"
    end
    CORE.onChar("v2", function() AW.stop(true) end)
    onUnload(function()
        AW.stop(true)
        for _, m in ipairs(AW.minis) do for _, it in ipairs(m.parts) do pcall(function() it.p:Destroy() end) end end
        for _, it in ipairs(AW.sus) do pcall(function() it.p:Destroy() end) end
    end)
end)

-- =====================================================================
-- 14s. Farm Brain V2 (NPC quests / mobs only, off by default)
--   Uses the Explorer Scanner: walks (short dashes) to the nearest mob cluster, lets Mob Gather pull
--   the mobs into a cluster, your own Shadow Strikes / recorded combo do the hitting, Loot Grab collects.
--   Quests: only takes a quest when the quest giver uses a ProximityPrompt (games with dialog menus,
--   e.g. Blox Fruits, need you to take the quest yourself). Aborts at once when a real player is within
--   25 studs or targets you, and everything it switched on is switched back off when it stops.
-- =====================================================================
CORE.safeModule("14s Farm Brain V2", function()
    local PVE, MOV = CORE.pve, CORE.move
    if not (PVE and MOV) then return end
    local FB = {state = "off", lastMove = 0, lastQuest = -100, saved = false, kills = 0}
    CORE.farm = FB
    local function now() return os.clock() end
    local promptFn = exfn("fireproximityprompt")
    local function engage(on)
        local OV = CORE.override
        if not OV then return end
        if on and not FB.saved then
            FB.saved = true
            OV.push("farm", {puppetHold = true, shadowM1 = true, lootGrab = true})
        elseif not on and FB.saved then
            FB.saved = false
            OV.pop("farm")
            if PVE.hold and settings.puppetHold ~= true then pcall(PVE.hold.releaseAll) end
        end
    end
    local function tryQuest(r)
        local W = CORE.world
        if not (W and W.quest and promptFn) or now() - FB.lastQuest < 30 then return end
        for m in pairs(W.quest) do
            local pp = m.Parent and m:FindFirstChildWhichIsA("ProximityPrompt", true)
            local pos = pp and pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position
            if pos and (pos - r.Position).Magnitude < (pp.MaxActivationDistance + 2) then
                FB.lastQuest = now()
                pcall(promptFn, pp)
                FB.state = "took a quest from " .. m.Name
                return
            end
        end
    end
    local acc = 0
    onHeartbeat("farm5", function(dt)
        acc += dt
        if acc < 0.5 then return end
        acc = 0
        if settings.farm ~= true then
            if FB.saved then engage(false) end
            FB.state = "off"
            return
        end
        local r = hrp()
        if not r then return end
        local why = PVE.playerGuard and PVE.playerGuard()
        if why then
            if FB.saved then engage(false) end
            FB.state = "paused: " .. why
            return
        end
        engage(true)
        tryQuest(r)
        local W = CORE.world
        local cl = W and W.nearestMobCluster and W.nearestMobCluster(r.Position, 400)
        if not cl then FB.state = "searching mobs (scanner)" return end
        local d = Vector3.new(cl.pos.X - r.Position.X, 0, cl.pos.Z - r.Position.Z)
        if d.Magnitude > 18 then
            FB.state = "moving to " .. tostring(cl.name) .. " (" .. math.floor(d.Magnitude) .. " m)"
            if now() - FB.lastMove > 1.2 and not MOV.carrying and not HUB.rescueBusy then
                FB.lastMove = now()
                pcall(MOV.dashTo, r.Position + d.Unit * math.min(d.Magnitude - 12, 30))
            end
        else
            FB.state = "farming " .. tostring(cl.name) .. " · " .. cl.n .. " mobs"
        end
    end)
    function FB.status() return FB.state end
    onUnload(function() engage(false) end)
end)

-- =====================================================================
-- 14t. Guardian Lifeline V2.3 (rescue that really moves you) + companion hold
--   Why V2.2 "just let you die": the rescue needed a cached safe spot 30+ studs from the enemy
--   (in a fight there often is none, so a "low health" rescue did nothing), it was blocked for 6 s
--   after every try, and two blocked carries were SAVED as "hands_move broken", which switched the
--   rescue off in that game for good. "Pulling back to recover" was only a weak strafe.
--   Lifeline: every HP drop is measured (single hit, damage rate, predicted time to death). From
--   ~45 % (slider), on any big hit or a short time-to-death, the Guardian briefly takes your
--   movement and flies you ~75 studs away from the damage source, onto high ground out of aggro
--   range (mobs leash back to their spawn). No ground in reach (sea, cliffs): up into the air and
--   held there. It keeps you away until you healed (slider), hops again if they follow, and gives
--   control back the moment you steer for a while. Never blocked by old flags; 0.9 s between hops.
--   Companion Hold: finds what hurt you. An NPC: held frozen ~12 studs up and later set down far
--   from you (no fling, no damage). A real player: never touched; you are just moved out.
--   5.7: no pilot / companion hand models — Lifeline only moves YOU / holds NPCs.
-- =====================================================================
CORE.safeModule("14t Guardian Lifeline V2.3", function()
    local KIT = VFX._kit or {}
    local SEN, MOV = CORE.sense, CORE.move
    local HS = CORE.hands and CORE.hands.state
    local LL = {phase = "idle", busy = false, hops = 0, saves = 0, last = -100, lastHit = -100, lastAmt = 0, dmg = {}, hp = nil,
        perch = nil, awaySince = 0, userT = 0, why = "", comp = nil, ttd = math.huge, grabs = 0, sets = 0, grabFails = 0}
    CORE.lifeline = LL
    local function now() return os.clock() end
    local function lite() return PERF.lite or isTouch end
    local function visualsOn() return false end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local function unitOr(v, fb) if v.Magnitude < 1e-3 then return fb end return v.Unit end
    local function say(kind, vars, prio) if VFX.say then local ok, r = pcall(VFX.say, kind, vars, prio) return ok and r end return false end
    local function profile() local m = GAMEINFO and GAMEINFO.module return m and m.profile or nil end
    local function shortName(s) s = tostring(s or "it") s = string.gsub(s, "%s*%b[]", "") return s end
    local netOwnerFn, hiddenFn = exfn("isnetworkowner"), exfn("sethiddenproperty")
    -- old builds could SAVE "hands_move broken" after two blocked carries, which switched the rescue off for good
    for _, n in ipairs({"hands_move", "move_physics"}) do
        local a = brain.actionState and brain.actionState(n)
        if type(a) == "table" and a.broken then a.broken = nil a.fails = 0 CORE.log("LIFE", "cleared the old '" .. n .. "' block") end
    end
    function LL.enabled()
        return alive and ((settings.handsOn == true and settings.handsRescue ~= false) or settings.godmode == true)
    end
    -- the simulation radius hint many executors expose (helps the server hand nearby mobs to you; harmless if missing)
    local simT = -10
    function CORE.claimSim()
        if not hiddenFn or now() - simT < 2 then return end
        simT = now()
        pcall(hiddenFn, LP, "SimulationRadius", 1000)
    end

    -- ---------------- world queries ----------------
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local rpT = -1
    local function cast(from, dir)
        if now() - rpT > 0.5 then
            rpT = now()
            local ex = {gui}
            for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
            for _, h in ipairs(HS and HS.list or {}) do if h.model then ex[#ex + 1] = h.model end end
            if CORE.waterPlat then ex[#ex + 1] = CORE.waterPlat end
            local pf = profile()
            local ef = pf and pf.enemies and workspace:FindFirstChild(pf.enemies)
            if ef then ex[#ex + 1] = ef end   -- never "land" on a mob
            rp.FilterDescendantsInstances = ex
        end
        local ok, res = pcall(function() return workspace:Raycast(from, dir, rp) end)
        return ok and res or nil
    end
    local function isWater(res)
        if res.Material == Enum.Material.Water then return true end
        if CORE.isWaterPart and res.Instance and CORE.isWaterPart(res.Instance) then return true end
        local st = CORE.seaTop and CORE.seaTop()
        return st ~= nil and res.Position.Y < st + 0.6
    end
    -- solid, dry, not a hazard, not a wall: returns a root-height position
    local function landAt(p, fromY)
        local res = cast(Vector3.new(p.X, (fromY or p.Y) + 60, p.Z), Vector3.new(0, -170, 0))
        if not (res and res.Instance) or isWater(res) then return nil end
        if res.Instance:IsA("BasePart") and brain.isHazard and brain.isHazard(res.Instance) then return nil end
        if res.Normal and res.Normal.Y < 0.55 then return nil end
        return res.Position + Vector3.new(0, 3.2, 0)
    end
    LL.landAt = landAt
    local function threats(me, R)
        local out = {}
        for _, info in ipairs(SEN.list or {}) do
            if info.root and info.root.Parent and info.dist and info.dist < R
                and (info.hostile or info.enemy or now() - (info.lastHitAt or -10) < 4) then out[#out + 1] = info end
        end
        return out
    end
    -- what hurt you: the freshest attributed attacker, else the closest real threat
    local function sourceInfo()
        local best, bt
        for _, info in ipairs(SEN.list or {}) do
            local lh = info.lastHitAt or -10
            if now() - lh < 3 and info.root and info.root.Parent and (not bt or lh > bt) then best, bt = info, lh end
        end
        if best then return best end
        local top = SEN.top
        if top and top.root and top.root.Parent and (top.dist or 99) < 30 then return top end
        return nil
    end
    local function rot(v, a) local c, s = math.cos(a), math.sin(a) return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c) end
    -- 12 directions, weighted away from the threat, two distances each; high ground and distance to every threat win
    local function pickEscape(me, threatPos, list)
        local r = hrp()
        local away = threatPos and unitOr(flat(me - threatPos), nil)
        if not away then away = unitOr(flat(-(r and r.CFrame.LookVector or Vector3.new(0, 0, -1))), Vector3.new(0, 0, 1)) end
        local pf = profile()
        local D = (pf and pf.escapeDist) or 70
        local best, bs
        for k = 0, 11 do
            local d = rot(away, k * math.pi / 6)
            local score = d:Dot(away) * 2
            if score > -0.6 then
                for _, dist in ipairs({D, D * 0.6}) do
                    local p = landAt(me + d * dist, me.Y)
                    if p then
                        local s = score + math.clamp((p.Y - me.Y) / 40, -0.5, 1)
                        local minD = math.huge
                        for _, info in ipairs(list) do minD = math.min(minD, (info.root.Position - p).Magnitude) end
                        if minD >= 40 then s += 0.5 elseif minD < 22 then s -= 3 end
                        if dist < D then s -= 0.3 end
                        if not bs or s > bs then best, bs = p, s end
                        break
                    end
                end
            end
        end
        return best, away
    end

    -- ---------------- holding you in the air (perch) ----------------
    local function holdOff()
        if LL.ap then pcall(function() LL.ap.Enabled = false LL.ap:Destroy() end) end
        if LL.att then pcall(function() LL.att:Destroy() end) end
        LL.ap, LL.att = nil, nil
    end
    local function holdAt(p)
        local r = hrp()
        if not r then return end
        if not (LL.att and LL.att.Parent == r and LL.ap) then
            holdOff()
            LL.att = own(new("Attachment", {Name = "SecretLifeline", Parent = r}))
            LL.ap = own(new("AlignPosition", {Name = "SecretLifelineHold", Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = LL.att,
                MaxForce = math.max(r.AssemblyMass, 8) * 3000, MaxVelocity = 90, Responsiveness = 35, Parent = r}))
            pcall(function() LL.att:SetAttribute("SecretHub", true) LL.ap:SetAttribute("SecretHub", true) end)
        end
        LL.ap.Position = p
        if not LL.ap.Enabled then LL.ap.Enabled = true end
        if brain.ownMove then brain.ownMove() end
    end

    -- ---------------- right hand: companion (NPCs only) ----------------
    local GR = {e = nil, verdict = setmetatable({}, {__mode = "k"}), hl = nil}
    LL.grab = GR
    local function isNpc(info)
        if not (info and info.model and info.root and info.hum) or info.player ~= nil then return false end
        if CORE.pve and CORE.pve.isNpcInfo then return CORE.pve.isNpcInfo(info) end
        local ok, p = pcall(function() return Players:GetPlayerFromCharacter(info.model) end)
        return ok and p == nil and info.model ~= LP.Character
    end
    local function ownerOk(root)
        if root.Anchored then return false end
        if netOwnerFn then local ok, v = pcall(netOwnerFn, root) if ok and type(v) == "boolean" then return v end end
        return nil   -- unknown: hold and verify
    end
    local function roles() if HS then HS.roles = HS.roles or {} return HS.roles end return {} end
    local function gripLook(on, model)
        if settings.vfx == false then return end
        if not GR.hl then
            GR.hl = own(new("Highlight", {Name = "SecretGrip", FillColor = Color3.new(0, 0, 0), FillTransparency = 0.55, OutlineColor = Color3.new(1, 1, 1),
                OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}))
            pcall(function() GR.hl:SetAttribute("SecretHub", true) end)
        end
        GR.hl.Adornee = on and model or nil
        GR.hl.Parent = on and gui or nil
    end
    local function grabEnd(why)
        local e = GR.e
        if not e then return end
        GR.e = nil
        pcall(function() if e.hum.Parent then e.hum.PlatformStand = e.ps == true end end)
        pcall(function() if e.hum.Parent then e.hum:ChangeState(Enum.HumanoidStateType.GettingUp) end end)
        pcall(function() if e.root.Parent then e.root.AssemblyLinearVelocity = Vector3.zero end end)
        for _, a in ipairs(e.atts or {}) do pcall(function() a:Destroy() end) end
        gripLook(false)
        local R = roles()
        if R.comp and R.comp.kind == "grip" then R.comp = nil end
        if why then CORE.log("HAND", "released " .. tostring(e.name) .. " (" .. why .. ")") end
    end
    -- set it down far from you: along the line away from you, on ground, inside its spawn leash; no launch
    local function setDown(e)
        if e.setting then return end
        e.setting = true
        local r = hrp()
        local away = r and unitOr(flat(e.root.Position - r.Position), e.back) or e.back
        local spot = landAt(e.home + away * 24, e.home.Y + 10) or (e.home + Vector3.new(0, 1, 0))
        local leash = math.clamp(tonumber(settings.holdLeash) or 60, 20, 200)
        local w = CORE.world
        local sp = w and w.spawnOf and w.spawnOf(e.model)
        if sp and (spot - sp).Magnitude > leash then spot = e.home + Vector3.new(0, 1, 0) end
        local from = e.root.Position
        if visualsOn() then roles().comp = {kind = "throw", dir = away, t0 = now(), untilT = now() + 0.45} end
        if VFX.slashTrail then pcall(VFX.slashTrail, from, spot, C.smoke) end
        task.spawn(function()
            local t0 = now()
            while alive and e.root.Parent and now() - t0 < 0.32 do
                local u = (now() - t0) / 0.32
                local p = from:Lerp(spot, u) + Vector3.new(0, math.sin(u * math.pi) * 5, 0)
                pcall(function() e.root.CFrame = CFrame.new(p) e.root.AssemblyLinearVelocity = Vector3.zero end)
                SVC.RunService.Heartbeat:Wait()
            end
            pcall(function() e.root.CFrame = CFrame.new(spot) e.root.AssemblyLinearVelocity = Vector3.zero end)
            if KIT.emit and not lite() then pcall(KIT.emit, spot, C.smoke, 12, 9, 0.8, 0.6, C.smoke) end
            grabEnd("set down")
        end)
        LL.sets += 1
        say("lifeline_set", {name = shortName(e.name)}, 2)
    end
    function LL.companion(info)
        if not info or not info.model then return end
        local R = roles()
        if not isNpc(info) then
            -- players are never touched: voice + move you out (no palm puppet unless visuals are on)
            if info.player and info.root then
                LL.comp = {kind = "guard", root = info.root, untilT = now() + 2.5}
                if now() - (LL.guardSaid or -100) > 15 then LL.guardSaid = now() say("lifeline_guard", nil, 2) end
            end
            return
        end
        if settings.handsGrab == false then return end
        if GR.e and GR.e.model == info.model then GR.e.untilT = math.max(GR.e.untilT, now() + 4) return end
        local v = GR.verdict[info.model]
        if v and now() < v then LL.comp = {kind = "guard", root = info.root, untilT = now() + 2} return end
        local root = info.root
        if ownerOk(root) == false then
            GR.verdict[info.model] = now() + 10
            LL.comp = {kind = "guard", root = root, untilT = now() + 2}
            return
        end
        if GR.e then setDown(GR.e) end
        CORE.claimSim()
        local r = hrp()
        if not r then return end
        local p = root.Position
        local back = unitOr(flat(p - r.Position), Vector3.new(0, 0, -1))
        local e = {model = info.model, hum = info.hum, root = root, name = info.name or info.model.Name, t0 = now(), home = p, back = back,
            hold = p + back * 8 + Vector3.new(0, 12, 0), off = 0, untilT = now() + 6, atts = {}, goal = p}
        pcall(function() e.ps = info.hum.PlatformStand info.hum.PlatformStand = true end)
        pcall(function() info.hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        -- limb attachments only matter for the old fingertip strings
        if visualsOn() then
            for _, n in ipairs({"Head", "UpperTorso", "Torso", "RightHand", "Right Arm", "LeftHand", "Left Arm", "HumanoidRootPart"}) do
                local part = info.model:FindFirstChild(n)
                if part and part:IsA("BasePart") and #e.atts < 5 then
                    local a = own(new("Attachment", {Name = "SecretGrip", Parent = part}))
                    pcall(function() a:SetAttribute("SecretHub", true) end)
                    e.atts[#e.atts + 1] = a
                end
            end
        end
        GR.e = e
        LL.grabs += 1
        gripLook(true, info.model)
        if visualsOn() then R.comp = {kind = "grip", root = root, atts = e.atts, t0 = now(), untilT = math.huge} end
        if KIT.emit and not lite() then pcall(KIT.emit, p + Vector3.new(0, 2, 0), C.smoke, 14, 10, 0.8, 0.6, C.smoke) end
        say("lifeline_hold", {name = shortName(e.name)}, 2)
    end
    -- the hold itself: before physics (Stepped) check for a server snap-back, then pin it in the air
    local function holdStep(check)
        local e = GR.e
        if not e or e.setting then return end
        if not (e.model.Parent and e.root.Parent and e.hum.Parent and e.hum.Health > 0) then grabEnd("gone") return end
        local t = now()
        if check and t - e.t0 > 0.45 then
            if (e.root.Position - e.goal).Magnitude > 6 then e.off += 1 / 60 else e.off = math.max(0, e.off - 1 / 120) end
            if e.off > 0.4 then
                -- the server owns this one right now: honest, let go, re-test in 10 s, keep guarding with the palm
                GR.verdict[e.model] = t + 10
                LL.grabFails += 1
                if t - (GR.failSaid or -100) > 8 then GR.failSaid = t say("grab_fail", {name = shortName(e.name)}, 2) end
                LL.comp = {kind = "guard", root = e.root, untilT = t + 2}
                grabEnd("server owns it")
                return
            end
        end
        local u = math.min(1, (t - e.t0) / 0.35)
        local goal = e.home:Lerp(e.hold, 1 - (1 - u) ^ 3)
        e.goal = goal
        local r = hrp()
        local look = r and Vector3.new(r.Position.X, goal.Y, r.Position.Z) or (goal + e.back)
        if (look - goal).Magnitude < 0.1 then look = goal - e.back end
        pcall(function()
            e.root.CFrame = CFrame.lookAt(goal, look) * CFrame.Angles(math.sin(t * 3) * 0.12, 0, math.cos(t * 2.4) * 0.1)
            e.root.AssemblyLinearVelocity = Vector3.zero
            e.root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    bind(SVC.RunService.Stepped:Connect(function() if alive and GR.e then pcall(holdStep, true) end end))
    function LL.compStatus()
        if settings.handsGrab == false then return "companion hold off" end
        if GR.e then return "holding " .. shortName(GR.e.name) .. " in the air" end
        return LL.grabs .. " held · " .. LL.sets .. " set down · " .. LL.grabFails .. " server-owned" .. (netOwnerFn and "" or " (live check)")
    end

    -- ---------------- evacuation: direct character control (no hand grab) ----------------
    local function stepCarry(r, at, dur)
        local t0 = now()
        while alive and r.Parent do
            local u = math.min(1, (now() - t0) / dur)
            r.CFrame = CFrame.new(at(u)) * (r.CFrame - r.CFrame.Position)
            r.AssemblyLinearVelocity = Vector3.zero
            if brain.ownMove then brain.ownMove() end
            if u >= 1 then break end
            SVC.RunService.Heartbeat:Wait()
        end
    end
    function LL.evacuate(why, force)
        if LL.busy or not alive then return false end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or (FX.inSafe() and not force) then return false end
        if HS and HS.busy then return false end   -- a void rescue / lift is already moving you
        local me = r.Position
        local list = threats(me, 60)
        local src = sourceInfo()
        local tp = src and src.root and src.root.Position
        if not tp and #list > 0 then
            local s = Vector3.zero
            for _, i in ipairs(list) do s += i.root.Position end
            tp = s / #list
        end
        local dest, away = pickEscape(me, tp, list)
        local perch = dest == nil
        if perch then dest = me + away * 30 + Vector3.new(0, 42, 0) end
        LL.busy, LL.phase, LL.last, LL.why = true, "evacuate", now(), tostring(why)
        LL.hops += 1
        LL.lastHitAtEvac = LL.lastHit
        HUB.rescueBusy = true
        holdOff()
        if src then pcall(LL.companion, src) end
        if visualsOn() then roles().pilot = {kind = "carry", untilT = now() + 3} end
        if not say(perch and "lifeline_sky" or "lifeline_go", nil, 3) then toast("Guardian: Lifeline · " .. tostring(why), "shield", 2) end
        CORE.log("LIFE", "lifeline (" .. tostring(why) .. ") -> " .. (perch and "air hold" or "ground") .. " " .. math.floor((dest - me).Magnitude) .. " studs")
        task.spawn(function()
            local ok, err = pcall(function()
                if VFX.takeover then VFX.takeover(me, dest, perch and "sky" or (LL.hops > 1 and "hop" or "lifeline")) end
                local dist = (dest - me).Magnitude
                local lift = perch and 4 or math.clamp(dist * 0.35, 14, 34)
                local mid = (me + dest) / 2 + Vector3.new(0, lift, 0)
                local function at(u) local a = 1 - u return me * (a * a) + mid * (2 * a * u) + dest * (u * u) end
                local mp = brain.actionState and brain.actionState("move_physics")
                if MOV.carry and not (type(mp) == "table" and mp.broken) and not MOV.carrying then MOV.carry(at, dist + lift) end
                if r.Parent and (r.Position - me).Magnitude < dist * 0.5 then stepCarry(r, at, math.clamp(dist / 160, 0.3, 0.8)) end
                r.AssemblyLinearVelocity = Vector3.zero
                local moved = r.Parent ~= nil and (r.Position - me).Magnitude >= dist * 0.5
                if moved then
                    LL.saves += 1
                    if VFX.release then VFX.release(r.Position, nil) end
                else
                    say("rescue_fail", nil, 2)
                end
                LL.perch = perch and dest or nil
                LL.anchor = r.Position
            end)
            if not ok then CORE.log("ERR", "lifeline: " .. tostring(err)) end
            LL.phase = LL.perch and "perch" or "away"
            LL.awaySince, LL.userT = now(), 0
            LL.busy = false
            if visualsOn() then roles().pilot = nil end
            task.delay(0.2, function() HUB.rescueBusy = false end)
        end)
        return true
    end
    local function finish(healed)
        holdOff()
        MOV.clear("lifeline")
        local was = LL.phase
        local r = hrp()
        LL.phase, LL.perch = "idle", nil
        if healed and was ~= "idle" then
            say("lifeline_safe", nil, 2)
            if VFX.release then VFX.release(r and r.Position, "safe") end
            if visualsOn() and VFX.handsMode then VFX.handsMode("victory", nil, 1.1) end
        end
    end
    LL.finish = finish
    function LL.status()
        if not LL.enabled() then return "off (Guardian Control + Lifeline Rescue)" end
        local start = math.floor(tonumber(settings.rescueStart) or 45)
        local s = LL.phase
        if s == "idle" then s = "armed at " .. start .. " %" elseif s == "perch" then s = "holding you in the air" elseif s == "away" then s = "keeping you away" end
        local ttd = (LL.ttd and LL.ttd < 60) and (" · time to death " .. string.format("%.1f", LL.ttd) .. " s") or ""
        return s .. ttd .. " · " .. LL.saves .. "/" .. LL.hops .. " evacuations verified"
    end

    -- ---------------- damage model + triggers ----------------
    local function dmgIn(w) local t, s = now(), 0 for _, d in ipairs(LL.dmg) do if t - d.t <= w then s += d.a end end return s end
    local function trigger(h, t)
        local mx = math.max(h.MaxHealth, 1)
        local hp = h.Health
        local hpP = hp / mx
        local sinceHit = t - LL.lastHit
        local dps = math.max(dmgIn(1), dmgIn(2.5) / 2.5)
        local ttd = dps > 0 and hp / dps or math.huge
        LL.ttd = ttd
        -- after an evacuation only NEW damage (or a threat right next to you) starts another hop
        if LL.phase ~= "idle" and LL.lastHit <= (LL.lastHitAtEvac or -100) then
            local r = hrp()
            if r and #threats(r.Position, 12) > 0 and LL.phase == "away" then return "they followed" end
            return nil
        end
        local start = math.clamp((tonumber(settings.rescueStart) or 45) / 100, 0.15, 0.9)
        if sinceHit < 0.3 and LL.lastAmt >= mx * 0.18 then return "big hit" end
        if sinceHit < 1.5 and ttd < 3.5 then return "fast damage" end
        if sinceHit < 3 and hpP <= start then return "low health" end
        if hpP <= 0.25 and sinceHit < 8 then return "critical" end
        local top = SEN.top
        if top and (top.danger or 0) >= 1 and (top.lastAmt or 0) >= hp - mx * 0.1 and hpP < 0.9 then return "lethal wind-up" end
        return nil
    end
    -- the sea hurts you here: raise the guard surface a little each time (adapts if the level moved)
    local function seaHurt(r)
        local st = CORE.seaTop and CORE.seaTop()
        if not (st and r) or r.Position.Y > st + 5 then return end
        if #threats(r.Position, 15) > 0 then return end
        CORE.seaAdj = math.min((CORE.seaAdj or 0) + 1.5, 9)
        local v = r.AssemblyLinearVelocity
        r.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 45), v.Z)
        CORE.log("WATER", "sea damage at y " .. math.floor(r.Position.Y) .. " · guard surface raised to " .. math.floor(st + 1.5))
    end
    local hooked, hookConn
    local function hook(h)
        hooked = h
        LL.hp, LL.dmg = h.Health, {}
        if hookConn then pcall(function() hookConn:Disconnect() end) end
        hookConn = h.HealthChanged:Connect(function(hp)
            if not alive or hooked ~= h then return end
            local prev = LL.hp or hp
            LL.hp = hp
            if hp >= prev - 0.05 or hp <= 0 then return end
            local a, t = prev - hp, now()
            LL.dmg[#LL.dmg + 1] = {t = t, a = a}
            if #LL.dmg > 40 then table.remove(LL.dmg, 1) end
            LL.lastHit, LL.lastAmt = t, a
            local r = hrp()
            if (settings.waterGuard ~= false or settings.walkwater == true) then pcall(seaHurt, r) end
            -- same frame as the hit: no waiting for the next tick
            if LL.enabled() and not LL.busy and t - LL.last > 0.9 then
                local why = trigger(h, t)
                if why then LL.evacuate(why) end
            end
        end)
    end
    -- hits from NPCs: the companion grabs the source when it matters (low, big hit, or during an evacuation);
    -- a full-health farm fight is left alone so your own combo keeps landing
    SEN.on("lifeline", function(ev)
        if ev.kind ~= "hit" or not ev.who or not LL.enabled() or settings.handsOn ~= true then return end
        local h = hum()
        if not h then return end
        local mx = math.max(h.MaxHealth, 1)
        local start = math.clamp((tonumber(settings.rescueStart) or 45) / 100, 0.15, 0.9)
        if LL.phase ~= "idle" or (ev.amount or 0) >= mx * 0.12 or h.Health / mx <= start + 0.15 then pcall(LL.companion, ev.who) end
    end)

    -- ---------------- per frame: roles, triggers, the away phase ----------------
    local function updateRoles(r, t)
        local R = roles()
        local steer = MOV.steer or Vector3.zero
        local fight = SEN.combat or LL.phase ~= "idle"
        if LL.busy then R.pilot = {kind = "carry", untilT = t + 0.25}
        elseif fight or steer.Magnitude > 2 then R.pilot = {kind = "pilot", dir = steer, untilT = t + 0.3}
        elseif R.pilot and R.pilot.kind == "carry" then R.pilot = nil end
        local c = R.comp
        if c and (c.kind == "grip" or (c.kind == "throw" and t < c.untilT)) then return end
        if LL.comp and t < LL.comp.untilT and LL.comp.root and LL.comp.root.Parent then
            R.comp = {kind = "guard", dir = LL.comp.root.Position - r.Position, untilT = t + 0.25}
        elseif LL.busy then
            R.comp = {kind = "lift", untilT = t + 0.25}
        elseif fight and SEN.top and SEN.top.root and SEN.top.root.Parent then
            R.comp = {kind = "ready", dir = SEN.top.root.Position - r.Position, untilT = t + 0.3}
        end
    end
    onHeartbeat("lifeline53", function(dt)
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 then
            if LL.phase ~= "idle" or LL.ap then finish(false) end
            if GR.e then grabEnd("you died") end
            return
        end
        if hooked ~= h then hook(h) end
        local t = now()
        if visualsOn() and settings.handsOn == true then pcall(updateRoles, r, t) end
        if GR.e then
            pcall(holdStep, false)
            -- held while you get away, then set down far from you
            local limit = (LL.phase ~= "idle") and 12 or 6
            if GR.e and not GR.e.setting and (t > GR.e.untilT and LL.phase == "idle" or t - GR.e.t0 > limit) then setDown(GR.e) end
        end
        if not LL.enabled() then if LL.phase ~= "idle" then finish(false) end return end
        if not LL.busy and t - LL.last > 0.9 then
            local why = trigger(h, t)
            if why then LL.evacuate(why) return end
        end
        if LL.busy or LL.phase == "idle" then return end
        local hpP = h.Health / math.max(h.MaxHealth, 1)
        local safe = math.clamp((tonumber(settings.rescueSafe) or 80) / 100, 0.4, 1)
        local list = threats(r.Position, 45)
        if h.MoveDirection.Magnitude > 0.3 then LL.userT += dt else LL.userT = 0 end
        -- done: healed, long enough, or you clearly want control back
        if hpP >= safe or t - LL.awaySince > 40 or (LL.userT > 1 and #list == 0) or LL.userT > 2.5 then
            if LL.phase == "perch" and hpP >= safe then
                -- come down onto ground away from the fight (if there is any), else just let go
                local me = r.Position
                local spot = pickEscape(me, nil, list)
                if spot and (spot - me).Magnitude < 160 then
                    LL.phase = "away" holdOff()
                    task.spawn(function() if MOV.carry and not MOV.carrying then MOV.carry(function(u) return me:Lerp(spot, u) end, (spot - me).Magnitude) end end)
                end
            end
            finish(hpP >= safe)
            return
        end
        if LL.phase == "perch" then
            holdAt(LL.perch)
        else
            -- keep distance on the ground; anything that comes close gets another hop (trigger: "they followed")
            local near, nd
            for _, info in ipairs(list) do if not nd or info.dist < nd then near, nd = info, info.dist end end
            if near and nd < 35 then
                local away = unitOr(flat(r.Position - near.root.Position), Vector3.new(0, 0, 1))
                MOV.want("lifeline", 85, away * math.clamp((40 - nd) * 2.2, 12, 42), 0.25)
            else
                MOV.clear("lifeline")
            end
        end
    end)
    CORE.onChar("lifeline", function()
        hooked = nil
        LL.busy, LL.phase, LL.perch, LL.dmg, LL.comp = false, "idle", nil, {}, nil
        holdOff()
        if GR.e then grabEnd("respawn") end
    end)
    onUnload(function() holdOff() if hookConn then pcall(function() hookConn:Disconnect() end) end if GR.e then grabEnd("unload") end if GR.hl then pcall(function() GR.hl:Destroy() end) end end)
end)

-- =====================================================================
-- 14u. Blox Fruits Kit V2.4 (Blox Fruits only; everything off by default except the fruit notifier)
--   Research (public feature lists of the big Blox Fruits hubs, 2025/26) showed what players actually
--   use: fruit notifier / ESP, chest farm, level farm with quests, auto stats, auto Buso / Ken, island
--   travel by tween, anti-AFK, FPS boost. Rebuilt here in our own code and under our rules:
--   * movement is ALWAYS a tween (smooth flight at a capped speed, cruise height over the map), never
--     an instant teleport; it hands over to the Lifeline the moment you take damage
--   * every hit on a mob is YOUR normal attack (your equipped weapon via Tool:Activate + a normal click),
--     no damage changes, no kill aura, real players are never a target and pause the attacking
--   * the game's own CommF_ remote is used ONLY by Auto Quest, Auto Stats and Buso-via-remote, with the
--     same arguments the game itself sends (publicly documented); each of those is marked in the UI
--   * an uneaten fruit is never equipped or activated (it would be eaten) - see GV.isFruitItem
-- =====================================================================
CORE.safeModule("14u Blox Fruits Kit V2.4", function()
    local RS_ = svc("ReplicatedStorage")
    local CS_ = svc("CollectionService")
    local VIM, VU
    pcall(function() VIM = svc("VirtualInputManager") end)
    pcall(function() VU = svc("VirtualUser") end)
    local BK = {state = "off", fruits = {}, fruitN = 0, chestN = 0, chestVisited = setmetatable({}, {__mode = "k"}), remoteCalls = 0, statsAdded = 0,
        questOk = 0, questFail = {}, kills = 0, strikes = 0, landed = 0, travelTok = 0, traveling = false, pin = nil, target = nil, log = {}}
    CORE.bfkit = BK
    local function now() return os.clock() end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local function low(s) return string.lower(tostring(s or "")) end
    local function note(msg) CORE.log("BFKIT", msg) end
    function BK.isBF() local m = GAMEINFO and GAMEINFO.module return m ~= nil and m.title == "Blox Fruits" end
    function BK.sea() return ({[2753915549] = 1, [4442272183] = 2, [7449423635] = 3})[GAMEINFO and GAMEINFO.placeId or 0] or 1 end
    local function dataVal(name)
        local d = LP:FindFirstChild("Data")
        local v = d and d:FindFirstChild(name)
        local ok, x = pcall(function() return v and v.Value end)
        return ok and x or nil
    end
    function BK.level() return tonumber(dataVal("Level")) or 0 end
    -- mob names: "Bandit [Lv. 5]" / "Bandit" -> "Bandit"
    local function base(n) n = tostring(n or "") n = string.gsub(n, "%s*%b[]", "") n = string.gsub(n, "%s*%b()", "") return trim(n) end
    BK.base = base
    local function posOf(o)
        if not o then return nil end
        if o:IsA("BasePart") then return o.Position end
        if o:IsA("Tool") then local hd = o:FindFirstChild("Handle") return hd and hd:IsA("BasePart") and hd.Position or nil end
        if o:IsA("Model") then local ok, cf = pcall(function() return o:GetPivot() end) if ok and cf then return cf.Position end end
        return nil
    end
    BK.posOf = posOf

    -- ---------------- the game's own remote (optional features only) ----------------
    local function commF()
        local r = RS_ and RS_:FindFirstChild("Remotes")
        local f = r and r:FindFirstChild("CommF_")
        return (f and f:IsA("RemoteFunction")) and f or nil
    end
    -- yields: only ever called from task.spawn'ed threads, never from a frame job
    function BK.invoke(...)
        local f = commF()
        if not f then return false, "CommF_ not found" end
        local args = table.pack(...)
        BK.remoteCalls += 1
        local ok, res = pcall(function() return f:InvokeServer(table.unpack(args, 1, args.n)) end)
        note("CommF_ " .. tostring(args[1]) .. " -> " .. (ok and tostring(res) or ("error " .. tostring(res))))
        return ok, res
    end

    -- ---------------- your weapon (Melee / Sword / Blox Fruit / Gun, by the game's ToolTip) ----------------
    function CORE.pickWeapon()
        if not BK.isBF() then return nil end
        local want = tostring(settings.bfWeapon or "Melee")
        local c = char()
        local bp = LP:FindFirstChildOfClass("Backpack")
        local best
        for _, holder in ipairs({c, bp}) do
            if holder then
                for _, t in ipairs(holder:GetChildren()) do
                    if t:IsA("Tool") and not GV.isFruitItem(t) then
                        local tip = ""
                        pcall(function() tip = tostring(t.ToolTip or "") end)
                        if tip == want then return t end
                        if not best and (tip == "Melee" or tip == "Sword" or tip == "Blox Fruit") then best = t end
                    end
                end
            end
        end
        return best
    end
    local function equipWeapon()
        local h, c = hum(), char()
        local t = CORE.pickWeapon()
        if t and h and c and t.Parent ~= c then pcall(function() h:EquipTool(t) end) end
        return t
    end

    -- ---------------- tween travel (never an instant teleport) ----------------
    -- Smooth flight at a capped speed. Long trips climb to a cruise height first (over trees / houses),
    -- fly level, then come down on the target. Aborts the moment the Lifeline / a rescue moves you,
    -- you die, or a newer travel starts. Returns true when it arrived.
    local function lifelineBusy()
        local LL = CORE.lifeline
        return HUB.rescueBusy == true or (LL ~= nil and (LL.busy or LL.phase ~= "idle"))
    end
    function BK.stopTravel() BK.travelTok += 1 end
    function BK.travel(dest, label, keep)
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or h.Sit or typeof(dest) ~= "Vector3" then return false end
        BK.travelTok += 1
        local tok = BK.travelTok
        BK.traveling, BK.travelLabel = true, label or "travel"
        local MOV = CORE.move
        local setCarry = MOV and not MOV.carrying
        if setCarry then MOV.carrying = true end
        local from = r.Position
        local dist = (dest - from).Magnitude
        local cruise = math.max(from.Y, dest.Y) + (dist > 160 and 45 or 6)
        if CORE.seaTop and CORE.seaTop() then cruise = math.max(cruise, CORE.seaTop() + 22) end
        local pts = {}
        if dist > 40 then
            pts[#pts + 1] = Vector3.new(from.X, cruise, from.Z)
            pts[#pts + 1] = Vector3.new(dest.X, cruise, dest.Z)
        end
        pts[#pts + 1] = dest
        local idx, ok = 1, false
        if VFX.slashTrail and not PERF.lite then pcall(VFX.slashTrail, from, dest, C.smoke) end
        while alive do
            if tok ~= BK.travelTok then break end
            if keep and not keep() then break end
            if lifelineBusy() then break end
            r, h = hrp(), hum()
            if not (r and h and r.Parent) or h.Health <= 0 then break end
            local dt = SVC.RunService.Heartbeat:Wait()
            if tok ~= BK.travelTok or not r.Parent then break end
            local speed = math.clamp(tonumber(settings.bfSpeed) or 150, 60, 300)
            local goal = pts[idx]
            local d = goal - r.Position
            local step = speed * math.min(dt, 0.1)
            if d.Magnitude <= step + 0.05 then
                pcall(function() r.CFrame = CFrame.new(goal) * (r.CFrame - r.CFrame.Position) end)
                idx += 1
                if idx > #pts then ok = true break end
            else
                local p = r.Position + d.Unit * step
                local fl = flat(d)
                pcall(function()
                    if fl.Magnitude > 0.5 then r.CFrame = CFrame.lookAt(p, p + fl) else r.CFrame = CFrame.new(p) * (r.CFrame - r.CFrame.Position) end
                end)
            end
            pcall(function() r.AssemblyLinearVelocity = Vector3.zero r.AssemblyAngularVelocity = Vector3.zero end)
            if brain.ownMove then brain.ownMove() end
        end
        if setCarry and MOV then MOV.carrying = false end
        if tok == BK.travelTok then BK.traveling = false end
        return ok
    end
    local function travelAsync(dest, label)
        task.spawn(function()
            local ok = BK.travel(dest, label)
            if not ok and alive then toast("Tween stopped: " .. tostring(label) .. ".", "info", 2) end
        end)
    end

    -- ---------------- fruits: notifier + ESP + tween to fruit ----------------
    local function isFruit(o)
        if not (o and o.Parent == workspace) then return false end
        if not (o:IsA("Tool") or o:IsA("Model")) then return false end
        if not string.find(low(o.Name), "fruit", 1, true) then return false end
        if o:FindFirstChildOfClass("Humanoid") then return false end
        return posOf(o) ~= nil or o:FindFirstChild("Handle") ~= nil or o:FindFirstChild("Fruit") ~= nil
    end
    local function fruitName(o)
        local n = trim(o.Name)
        if n == "" or low(n) == "fruit" then return "Unknown fruit" end
        return n
    end
    local function espFor(o, e)
        if e.bb or settings.bfFruitEsp ~= true then return end
        local adorn = o:IsA("Tool") and o:FindFirstChild("Handle") or (o:IsA("Model") and (o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart", true))) or nil
        if not adorn then return end
        local bb = own(new("BillboardGui", {Name = "SecretFruitESP", Parent = gui, Adornee = adorn, AlwaysOnTop = true, LightInfluence = 0,
            Size = UDim2.new(0, 150, 0, 34), StudsOffset = Vector3.new(0, 3, 0), MaxDistance = 100000, ResetOnSpawn = false}))
        pcall(function() bb:SetAttribute("SecretHub", true) end)
        local f = new("Frame", {Parent = bb, BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0}, {corner(2)})
        stroke(Color3.new(1, 1, 1), 1, 0.55).Parent = f
        new("Frame", {Parent = f, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.new(0, 4, 0.5, -7), Size = UDim2.new(0, 2, 0, 14), Rotation = 14})
        label(f, {Position = UDim2.new(0, 12, 0, 2), Size = UDim2.new(1, -16, 0, 16), Font = F.bold, Text = string.upper(e.name), TextSize = 11,
            TextColor3 = Color3.new(1, 1, 1), TextTruncate = Enum.TextTruncate.AtEnd})
        e.dl = label(f, {Position = UDim2.new(0, 12, 0, 17), Size = UDim2.new(1, -16, 0, 14), Font = F.mono, Text = "", TextSize = 10, TextColor3 = C.sub})
        e.bb = bb
    end
    local function dropEsp(e) if e.bb then pcall(function() e.bb:Destroy() end) e.bb, e.dl = nil, nil end end
    local function addFruit(o)
        if BK.fruits[o] or not isFruit(o) then return end
        local e = {name = fruitName(o), t = now()}
        BK.fruits[o] = e
        BK.fruitN += 1
        espFor(o, e)
        if settings.bfFruitNotify ~= false and BK.isBF() then
            local r, p = hrp(), posOf(o)
            local dist = (r and p) and math.floor((p - r.Position).Magnitude) or nil
            toast("Fruit in the world: " .. e.name .. (dist and (" · " .. dist .. " m") or ""), "ok", 6)
            if VFX.say then pcall(VFX.say, "bf_fruit", {name = e.name, dist = dist or 0}, 3) end
            note("fruit spawned: " .. e.name .. (dist and (" at " .. dist .. " m") or ""))
        end
    end
    local function removeFruit(o) local e = BK.fruits[o] if e then dropEsp(e) BK.fruits[o] = nil end end
    bind(workspace.ChildAdded:Connect(function(o) if alive then task.defer(function() pcall(addFruit, o) end) end end))
    bind(workspace.ChildRemoved:Connect(function(o) if BK.fruits[o] then removeFruit(o) end end))
    task.defer(function() for _, o in ipairs(workspace:GetChildren()) do pcall(addFruit, o) end end)
    function BK.nearestFruit()
        local r = hrp()
        if not r then return nil end
        local best, bd
        for o in pairs(BK.fruits) do
            local p = o.Parent == workspace and posOf(o)
            if p then
                local d = (p - r.Position).Magnitude
                if not bd or d < bd then best, bd = o, d end
            end
        end
        return best, bd
    end
    function BK.goFruit()
        local o = BK.nearestFruit()
        if not o then toast("No fruit in the world right now.", "info", 2) return end
        local e = BK.fruits[o]
        toast("Tweening to " .. (e and e.name or "the fruit") .. ".", "info", 2)
        task.spawn(function()
            local p = posOf(o)
            if p and BK.travel(p + Vector3.new(0, 2, 0), "fruit", function() return o.Parent == workspace end) then
                task.wait(0.4)
                if o.Parent ~= workspace then toast("Picked up " .. (e and e.name or "the fruit") .. ".", "ok", 3) end
            end
        end)
    end

    -- ---------------- chests (CollectionService tag first, folders as fallback) ----------------
    local function chestList()
        local out = {}
        local ok, tagged = pcall(function() return CS_:GetTagged("_ChestTagged") end)
        if ok and type(tagged) == "table" then for _, c in ipairs(tagged) do out[#out + 1] = c end end
        if #out == 0 then
            local cm = workspace:FindFirstChild("ChestModels")
            if cm then for _, c in ipairs(cm:GetChildren()) do out[#out + 1] = c end end
        end
        if #out == 0 and CORE.world and CORE.world.drops then
            for p in pairs(CORE.world.drops) do
                if p.Parent and string.find(low(p.Name), "chest", 1, true) then out[#out + 1] = p end
            end
        end
        return out
    end
    function BK.nearestChest()
        local r = hrp()
        if not r then return nil end
        local best, bd
        for _, c in ipairs(chestList()) do
            local dis = false
            pcall(function() dis = c:GetAttribute("IsDisabled") == true end)
            local p = not dis and c.Parent and posOf(c)
            local v = BK.chestVisited[c]
            if p and not (v and now() < v) then
                local d = (p - r.Position).Magnitude
                if not bd or d < bd then best, bd = c, d end
            end
        end
        return best, bd
    end

    -- ---------------- quests: the quest panel, the game's quest list, a first-sea fallback ----------------
    local function questGui()
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local q = main and main:FindFirstChild("Quest")
        return q
    end
    function BK.questText()
        local q = questGui()
        if not (q and q.Visible) then return nil end
        local t
        pcall(function() t = q.Container.QuestTitle.Title.Text end)
        return t
    end
    -- the mob your quest asks for, matched against the enemies / spawns that really exist
    local function knownMobNames()
        local names = {}
        local ef = workspace:FindFirstChild("Enemies")
        if ef then for _, m in ipairs(ef:GetChildren()) do names[base(m.Name)] = true end end
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local es = wo and wo:FindFirstChild("EnemySpawns")
        if es then for _, s in ipairs(es:GetChildren()) do names[base(s.Name)] = true end end
        return names
    end
    function BK.questMob()
        local t = BK.questText()
        if not t then return nil end
        local lt = low(t)
        local best
        for n in pairs(knownMobNames()) do
            local ln = low(n)
            if ln ~= "" and (string.find(lt, ln, 1, true) or string.find(lt, (string.gsub(ln, "man$", "men")), 1, true)) then
                if not best or #n > #best then best = n end
            end
        end
        return best
    end
    -- first sea, from the public quest list (level, quest id, step, mob, quest giver). Fishman quests need the
    -- underwater entrance and are skipped on purpose.
    local Q1 = {
        {0, "BanditQuest1", 1, "Bandit", Vector3.new(1059, 16, 1550)},
        {10, "JungleQuest", 1, "Monkey", Vector3.new(-1598, 36, 153)},
        {15, "JungleQuest", 2, "Gorilla", Vector3.new(-1598, 36, 153)},
        {30, "BuggyQuest1", 1, "Pirate", Vector3.new(-1141, 5, 3830)},
        {40, "BuggyQuest1", 2, "Brute", Vector3.new(-1141, 5, 3830)},
        {60, "DesertQuest", 1, "Desert Bandit", Vector3.new(894, 5, 4392)},
        {75, "DesertQuest", 2, "Desert Officer", Vector3.new(894, 5, 4392)},
        {90, "SnowQuest", 1, "Snow Bandit", Vector3.new(1389, 88, -1298)},
        {100, "SnowQuest", 2, "Snowman", Vector3.new(1389, 88, -1298)},
        {120, "MarineQuest2", 1, "Chief Petty Officer", Vector3.new(-5039, 28, 4325)},
        {150, "SkyQuest", 1, "Sky Bandit", Vector3.new(-4839, 717, -2619)},
        {175, "SkyQuest", 2, "Dark Master", Vector3.new(-4839, 717, -2619)},
        {190, "PrisonerQuest", 1, "Prisoner", Vector3.new(5308, 2, 475)},
        {210, "PrisonerQuest", 2, "Dangerous Prisoner", Vector3.new(5308, 2, 475)},
        {250, "ColosseumQuest", 1, "Toga Warrior", Vector3.new(-1580, 7, -2986)},
        {275, "ColosseumQuest", 2, "Gladiator", Vector3.new(-1580, 7, -2986)},
        {300, "MagmaQuest", 1, "Military Soldier", Vector3.new(-5313, 11, 8515)},
        {325, "MagmaQuest", 2, "Military Spy", Vector3.new(-5313, 11, 8515)},
        {450, "SkyExp1Quest", 1, "God's Guard", Vector3.new(-4721, 846, -1953)},
        {475, "SkyExp1Quest", 2, "Shanda", Vector3.new(-7859, 5545, -381)},
        {525, "SkyExp2Quest", 1, "Royal Squad", Vector3.new(-7906, 5635, -1411)},
        {550, "SkyExp2Quest", 2, "Royal Soldier", Vector3.new(-7906, 5635, -1411)},
        {625, "FountainQuest", 1, "Galley Pirate", Vector3.new(5259, 39, 4050)},
        {650, "FountainQuest", 2, "Galley Captain", Vector3.new(5259, 39, 4050)},
    }
    -- the game's own quest list (ReplicatedStorage.Quests) when the executor can read it: covers every sea
    local gameQuests
    local function loadGameQuests()
        if gameQuests ~= nil then return gameQuests end
        gameQuests = false
        local req = exfn("require") or require
        local mod = RS_ and RS_:FindFirstChild("Quests")
        if not (mod and mod:IsA("ModuleScript")) then return gameQuests end
        local ok, data = pcall(req, mod)
        if not ok or type(data) ~= "table" then note("quest list not readable here") return gameQuests end
        local out = {}
        for qname, steps in pairs(data) do
            if type(qname) == "string" and type(steps) == "table" and not (string.find(qname, "Bartilo") or string.find(qname, "Citizen") or qname == "MarineQuest") then
                for i, st in pairs(steps) do
                    if type(i) == "number" and type(st) == "table" and tonumber(st.LevelReq) and type(st.Task) == "table" then
                        local mob
                        for k in pairs(st.Task) do if type(k) == "string" then mob = k break end end
                        if mob then out[#out + 1] = {tonumber(st.LevelReq), qname, i, base(mob), nil} end
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a[1] < b[1] end)
        gameQuests = #out > 0 and out or false
        note("game quest list: " .. (gameQuests and #out or 0) .. " quest steps")
        return gameQuests
    end
    local SEA_RANGE = {{0, 700}, {700, 1500}, {1500, math.huge}}
    -- the quest giver: a "... Quest Giver" NPC near the known spot, else the one closest to the mob's spawn
    local function questGiverPos(q)
        local npcs = workspace:FindFirstChild("NPCs")
        local anchor = q[5]
        if not anchor then
            local wo = workspace:FindFirstChild("_WorldOrigin")
            local es = wo and wo:FindFirstChild("EnemySpawns")
            if es then for _, s in ipairs(es:GetChildren()) do if base(s.Name) == q[4] then anchor = posOf(s) break end end end
        end
        if npcs and anchor then
            local best, bd
            for _, m in ipairs(npcs:GetChildren()) do
                if string.find(low(m.Name), "quest", 1, true) then
                    local p = posOf(m)
                    if p then local d = (p - anchor).Magnitude if d < (q[5] and 120 or 900) and (not bd or d < bd) then best, bd = p, d end end
                end
            end
            if best then return best end
        end
        return q[5]
    end
    function BK.questPlan()
        local lv = BK.level()
        local sea = BK.sea()
        local list = (sea == 1) and Q1 or nil
        local gq = loadGameQuests()
        if gq then list = gq end
        if not list then return nil end
        local rng = SEA_RANGE[sea] or SEA_RANGE[1]
        local pick
        for _, q in ipairs(list) do
            if q[1] <= lv and (list == Q1 or (q[1] >= rng[1] and q[1] < rng[2])) and not BK.questFail[q[2] .. "#" .. q[3]] then pick = q end
        end
        return pick
    end

    -- ---------------- level farm: target, position, your own attack ----------------
    local function playerNear(pos, rad)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr and (pr.Position - pos).Magnitude < rad then return p end
            end
        end
        return nil
    end
    local function heldByCompanion(m)
        local LL = CORE.lifeline
        local g = LL and LL.grab and LL.grab.e
        return g ~= nil and g.model == m
    end
    function BK.findMob(name)
        local ef = workspace:FindFirstChild("Enemies")
        local r = hrp()
        if not (ef and r) then return nil end
        local best, bd
        for _, m in ipairs(ef:GetChildren()) do
            if (not name or base(m.Name) == name) and not heldByCompanion(m) then
                local h = m:FindFirstChildOfClass("Humanoid")
                local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                if h and root and h.Health > 0 and not Players:GetPlayerFromCharacter(m) then
                    local d = (root.Position - r.Position).Magnitude
                    if not bd or d < bd then best, bd = {model = m, hum = h, root = root, name = base(m.Name)}, d end
                end
            end
        end
        return best, bd
    end
    local function spawnOf(name)
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local es = wo and wo:FindFirstChild("EnemySpawns")
        local r = hrp()
        if not (es and r) then return nil end
        local best, bd
        for _, s in ipairs(es:GetChildren()) do
            if base(s.Name) == name then
                local p = posOf(s)
                if p then local d = (p - r.Position).Magnitude if not bd or d < bd then best, bd = p, d end end
            end
        end
        return best
    end
    local lastClick = 0
    local landChecks = {}
    local function attack(tg)
        -- hard aim before every strike so skills / M1 actually face the mob
        if CORE.aim and CORE.aim.apply then
            pcall(CORE.aim.apply)
        elseif tg and tg.root then
            local r = hrp()
            if r then
                local look = Vector3.new(tg.root.Position.X, r.Position.Y, tg.root.Position.Z)
                pcall(function() r.CFrame = CFrame.lookAt(r.Position, look) end)
            end
            local cam = workspace.CurrentCamera
            if cam and tg.root then
                pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tg.root.Position + Vector3.new(0, 1.2, 0)) end)
            end
        end
        equipWeapon()
        local ok = CORE.pve and CORE.pve.m1 and CORE.pve.m1()
        -- the game also listens to a normal click: one real click while the hub is closed (never over our UI)
        if not HUB.uiOpen and now() - lastClick > 0.2 then
            lastClick = now()
            pcall(function()
                local cam = workspace.CurrentCamera
                local vs = cam and cam.ViewportSize or Vector2.new(800, 600)
                -- click toward the target on screen when possible (better than dead-center)
                local click = Vector2.new(vs.X * 0.5, vs.Y * 0.42)
                if tg and tg.root and cam then
                    local okV, v3 = pcall(function() return cam:WorldToViewportPoint(tg.root.Position) end)
                    if okV and v3 and v3.Z > 0 then click = Vector2.new(v3.X, v3.Y) end
                end
                if VU then VU:CaptureController() VU:ClickButton1(click) end
            end)
        end
        BK.strikes += 1
        landChecks[#landChecks + 1] = {hum = tg.hum, hp = tg.hum.Health, t = now()}
        if #landChecks > 16 then table.remove(landChecks, 1) end
        return ok
    end
    local killWatch = setmetatable({}, {__mode = "k"})
    local function watchKill(tg)
        if killWatch[tg.hum] then return end
        killWatch[tg.hum] = true
        local c
        c = tg.hum.Died:Connect(function() if c then c:Disconnect() end BK.kills += 1 end)
    end
    onHeartbeat("bf24verify", function()
        if #landChecks == 0 then return end
        local t = now()
        for i = #landChecks, 1, -1 do
            local c = landChecks[i]
            if t - c.t > 0.7 then
                table.remove(landChecks, i)
                if c.hum.Parent and c.hum.Health < c.hp - 0.01 then BK.landed += 1 end
            end
        end
    end)
    -- the pin: while farming, hold you at the attack spot (mob knockback / its push can't move you away)
    onHeartbeat("bf24pin", function()
        local P = BK.pin
        if not P then return end
        if now() > P.untilT or lifelineBusy() or BK.traveling then BK.pin = nil return end
        local r = hrp()
        if not r or not P.root.Parent then BK.pin = nil return end
        local at = P.pos
        local look = Vector3.new(P.root.Position.X, at.Y, P.root.Position.Z)
        if (look - at).Magnitude < 0.2 then look = at + Vector3.new(0, 0, -1) end
        if (r.Position - at).Magnitude > 0.3 then pcall(function() r.CFrame = CFrame.lookAt(at, look) end)
        else pcall(function() r.CFrame = CFrame.lookAt(r.Position, look) end) end
        pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
        if brain.ownMove then brain.ownMove() end
    end)

    -- ---------------- the driver: one decision every 0.25 s (fruit > farm > chests) ----------------
    local fruitTry = setmetatable({}, {__mode = "k"})
    local function farmStep()
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 then BK.state = "waiting for your character" return end
        if lifelineBusy() then BK.state = "Lifeline is healing you · farm waits" BK.pin = nil return end
        -- 1) quest
        local mob = BK.questMob()
        local plan = BK.questPlan()
        if not mob and settings.bfQuest == true and plan then
            local giver = questGiverPos(plan)
            if giver then
                BK.state = "taking quest " .. plan[2] .. " (" .. plan[4] .. ")"
                if (giver - r.Position).Magnitude > 12 then
                    if not BK.travel(giver + Vector3.new(0, 3, 0), "quest giver", function() return settings.bfFarm == true end) then return end
                    task.wait(0.4)
                end
                BK.invoke("StartQuest", plan[2], plan[3])
                local t0 = now()
                while now() - t0 < 2.5 and not BK.questText() do task.wait(0.25) end
                if BK.questText() then
                    BK.questOk += 1
                    toast("Quest taken: " .. plan[4] .. " (game remote).", "ok", 3)
                else
                    BK.questFail[plan[2] .. "#" .. plan[3]] = true
                    toast("The game did not give quest " .. plan[2] .. " here. Farming without it.", "warn", 4)
                end
                return
            end
        end
        local questMob = mob
        mob = mob or (plan and plan[4]) or nil
        -- 2) the mob (named by the quest / plan, else the nearest enemy)
        local tg, d = BK.findMob(mob)
        if not tg then
            local sp = mob and spawnOf(mob)
            if sp and (sp - r.Position).Magnitude > 30 then
                BK.state = "flying to " .. mob .. " spawn"
                BK.travel(sp + Vector3.new(0, 4, 0), mob .. " spawn", function() return settings.bfFarm == true end)
                return
            end
            -- no quest running and the planned mob is not around: take the nearest enemy close by
            if not questMob then
                local any, ad = BK.findMob(nil)
                if any and ad < 250 then tg, d = any, ad end
            end
            if not tg then
                BK.state = mob and ("waiting for " .. mob .. " to spawn") or "no enemies loaded nearby"
                return
            end
        end
        BK.target = tg
        local away = flat(r.Position - tg.root.Position)
        away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
        local spot = tg.root.Position + away * 3.4
        local plm = playerNear(tg.root.Position, 15) or playerNear(r.Position, 25)
        if plm then
            BK.pin = nil
            BK.state = "paused: " .. plm.DisplayName .. " is nearby (players are never attacked)"
            return
        end
        if d > 18 then
            BK.state = "flying to " .. tg.name .. " (" .. math.floor(d) .. " m)"
            BK.travel(spot + Vector3.new(0, 1, 0), tg.name, function() return settings.bfFarm == true and tg.hum.Health > 0 and tg.model.Parent ~= nil end)
            return
        end
        watchKill(tg)
        local pl = playerNear(r.Position, 25)
        if pl then
            BK.pin = nil
            BK.state = "paused: " .. pl.DisplayName .. " is nearby (players are never attacked)"
            return
        end
        BK.pin = {pos = spot, root = tg.root, untilT = now() + 2.5}
        BK.state = "farming " .. tg.name .. " · " .. BK.kills .. " defeated" .. (mob and BK.questText() and " · quest active" or "")
        local rate = math.clamp(tonumber(settings.m1Rate) or 3, 1, 8)
        for _ = 1, 2 do
            attack(tg)
            task.wait(1 / rate)
            if tg.hum.Health <= 0 or not settings.bfFarm then break end
        end
    end
    local function chestStep()
        local c, d = BK.nearestChest()
        if not c then BK.state = "no chest loaded nearby (move around the island)" return end
        local p = posOf(c)
        BK.state = "chest " .. math.floor(d) .. " m away"
        BK.chestVisited[c] = now() + 45
        local beli0 = tonumber(dataVal("Beli")) or 0
        if BK.travel(p + Vector3.new(0, 2.5, 0), "chest", function() return settings.bfChest == true and c.Parent ~= nil end) then
            -- stand on it a moment so the game registers the touch
            local r = hrp()
            local t0 = now()
            while r and r.Parent and now() - t0 < 0.45 do
                pcall(function() r.CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0)) * (r.CFrame - r.CFrame.Position) r.AssemblyLinearVelocity = Vector3.zero end)
                SVC.RunService.Heartbeat:Wait()
            end
            task.wait(0.35)
            local got = (tonumber(dataVal("Beli")) or 0) > beli0 or c.Parent == nil
            pcall(function() if c:GetAttribute("IsDisabled") == true then got = true end end)
            if got then BK.chestN += 1 end
        end
    end
    task.spawn(function()
        while alive do
            task.wait(0.25)
            local ok, err = pcall(function()
                if not BK.isBF() then
                    if settings.bfFarm == true or settings.bfChest == true or settings.bfFruitSnipe == true then BK.state = "Blox Fruits only" end
                    return
                end
                -- fruit sniper: a fresh fruit beats everything else
                if settings.bfFruitSnipe == true and not lifelineBusy() then
                    local o, fd = BK.nearestFruit()
                    if o and (fruitTry[o] or 0) < 2 then
                        fruitTry[o] = (fruitTry[o] or 0) + 1
                        local e = BK.fruits[o]
                        BK.state = "fruit sniper: " .. (e and e.name or "fruit") .. " · " .. math.floor(fd or 0) .. " m"
                        BK.pin = nil
                        local p = posOf(o)
                        if p then BK.travel(p + Vector3.new(0, 2, 0), "fruit", function() return settings.bfFruitSnipe == true and o.Parent == workspace end) end
                        task.wait(0.5)
                        if o.Parent ~= workspace and e then toast("Fruit picked up: " .. e.name .. ".", "ok", 4) end
                        return
                    end
                end
                if settings.bfFarm == true then farmStep() return end
                BK.pin, BK.target = nil, nil
                if settings.bfChest == true then chestStep() return end
                BK.state = "idle"
            end)
            if not ok then BK.pin = nil note("driver: " .. tostring(err)) end
        end
    end)

    -- ---------------- auto stats (game remote) / Buso / Ken / island tween ----------------
    local STAT_ID = {Melee = "Melee", Defense = "Defense", Sword = "Sword", Gun = "Gun", Fruit = "Demon Fruit"}
    task.spawn(function()
        while alive do
            task.wait(3)
            if settings.bfStats == true and BK.isBF() then
                local pts = tonumber(dataVal("Points")) or 0
                if pts > 0 then
                    local pick = tostring(settings.bfStat or "Melee")
                    local stat = STAT_ID[pick]
                    if pick == "Melee + Defense" then stat = (BK.statFlip and "Defense" or "Melee") BK.statFlip = not BK.statFlip end
                    local n = math.min(pts, pick == "Melee + Defense" and math.max(1, math.ceil(pts / 2)) or pts, 100)
                    if stat then
                        local ok = BK.invoke("AddPoint", stat, n)
                        if ok then BK.statsAdded += n end
                    end
                end
            end
        end
    end)
    local function press(kc)
        if not VIM then return false end
        local ok = pcall(function() VIM:SendKeyEvent(true, kc, false, game) end)
        task.delay(0.06, function() pcall(function() VIM:SendKeyEvent(false, kc, false, game) end) end)
        return ok
    end
    local busoT, kenGen = -100, -1
    onHeartbeat("bf24haki", function()
        if not BK.isBF() then return end
        local c, h = char(), hum()
        if not (c and h) or h.Health <= 0 then return end
        local t = now()
        if settings.bfBuso == true and t - busoT > 5 and not c:FindFirstChild("HasBuso") then
            busoT = t
            if settings.bfBusoVia == "Game remote" then task.spawn(BK.invoke, "Buso") else press(Enum.KeyCode.J) end
        end
        -- Ken: pressed once per life (E toggles it; there is no readable "Ken is on" flag, so no blind re-press)
        if settings.bfKen == true and kenGen ~= CORE.life.gen and t - (BK.spawnT or 0) > 2.5 then
            kenGen = CORE.life.gen
            press(Enum.KeyCode.E)
        end
    end)
    CORE.onChar("bf24", function() BK.spawnT = now() BK.pin, BK.target = nil, nil BK.stopTravel() end)
    function BK.islands()
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local loc = wo and wo:FindFirstChild("Locations")
        local out, seen = {}, {}
        if not loc then return out end
        local r = hrp()
        for _, l in ipairs(loc:GetChildren()) do
            local p = posOf(l)
            local n = trim(l.Name)
            if p and n ~= "" and not seen[n] and not string.find(n, "^Island %d") then
                seen[n] = true
                out[#out + 1] = {name = n, pos = p, dist = r and (p - r.Position).Magnitude or 0}
            end
        end
        table.sort(out, function(a, b) return a.dist < b.dist end)
        return out
    end
    function BK.goIsland(it)
        if not it then return end
        toast("Tweening to " .. it.name .. " · " .. math.floor(it.dist) .. " m.", "info", 2)
        travelAsync(it.pos + Vector3.new(0, 8, 0), it.name)
    end
    function BK.goChest()
        local c = BK.nearestChest()
        if not c then toast("No chest loaded nearby.", "info", 2) return end
        travelAsync(posOf(c) + Vector3.new(0, 2.5, 0), "chest")
    end

    -- ---------------- FPS boost follow-up: effects that spawn later stay off too ----------------
    local FXC = {ParticleEmitter = true, Trail = true, Smoke = true, Fire = true, Sparkles = true}
    bind(workspace.DescendantAdded:Connect(function(d)
        if settings.lowgfx == true and FXC[d.ClassName] then
            task.defer(function() pcall(function() if d.Parent and not d:GetAttribute("SecretHub") then d.Enabled = false end end) end)
        end
    end))

    -- ---------------- ESP refresh (2x / s) ----------------
    local espAcc = 0
    onHeartbeat("bf24esp", function(dt)
        espAcc += dt
        if espAcc < 0.5 then return end
        espAcc = 0
        local r = hrp()
        for o, e in pairs(BK.fruits) do
            if o.Parent ~= workspace then removeFruit(o)
            elseif settings.bfFruitEsp == true then
                if not e.bb then espFor(o, e) end
                local p = posOf(o)
                if e.dl and p and r then e.dl.Text = math.floor((p - r.Position).Magnitude) .. " m" end
            elseif e.bb then dropEsp(e) end
        end
    end)
    function BK.status()
        if not BK.isBF() then return "Blox Fruits only" end
        return tostring(BK.state)
    end
    function BK.fruitStatus()
        local n, names = 0, {}
        for o, e in pairs(BK.fruits) do if o.Parent == workspace then n += 1 if #names < 3 then names[#names + 1] = e.name end end end
        return n == 0 and "no fruit in the world" or (n .. " · " .. table.concat(names, ", "))
    end
    function BK.farmStats()
        return BK.kills .. " defeated · " .. BK.landed .. "/" .. BK.strikes .. " hits landed · " .. BK.questOk .. " quests · " .. BK.chestN .. " chests"
    end
    function BK.playerStatus()
        local lv, beli, fr = dataVal("Level"), dataVal("Beli"), dataVal("Fragments")
        if not lv then return "player data not loaded" end
        return "Sea " .. BK.sea() .. " · Lv " .. tostring(lv) .. " · " .. fmtNum(beli or 0) .. " Beli · " .. fmtNum(fr or 0) .. " Fragments · " .. tostring(dataVal("Points") or 0) .. " points"
    end
    onUnload(function()
        BK.stopTravel() BK.pin = nil
        for o, e in pairs(BK.fruits) do dropEsp(e) end
    end)
end)

-- =====================================================================
-- 14v. Guardian Aggression 5.6 (opt-in offense · YOUR attacks only · UNIVERSAL)
--   Works in any game. Discovers your kit (tools, keys, GUI buttons), probes what
--   actually damages a target, keeps winners and drops duds — per PlaceId via Brain.
--   Execute ladder: learned best hit → working arsenal → probe next unknown → M1.
--   Not tied to Blox Fruits / Z-X-C. NPCs by default; optional PvP vs Enemy/Exploiter.
--   Low health / Lifeline / safe zones always pause aggression.
-- =====================================================================
CORE.safeModule("14v Guardian Aggression 5.6", function()
    local SEN, MOV, ABI = CORE.sense, CORE.move, CORE.abil
    local AG = {mode = "idle", target = nil, why = "", kills = 0, oneshots = 0, bursts = 0, strikes = 0, landed = 0, fails = 0, last = -100,
        learned = 0, probing = "", arsenalN = 0, workingN = 0}
    CORE.aggro = AG
    local function now() return os.clock() end
    local function lite() return PERF.lite or isTouch end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    local function unitOr(v, fb) if v.Magnitude < 1e-3 then return fb end return v.Unit end
    local function say(kind, vars, prio) if VFX.say then local ok, r = pcall(VFX.say, kind, vars, prio) return ok and r end return false end
    local function canTry(name) return brain.canTry == nil or brain.canTry(name) end
    local function report(name, ok, label) if brain.report then brain.report(name, ok, label) end end
    local mouseClickFn = exfn("mouse1click")
    local lastTool
    local learnSaid, foundSaid = -100, {}

    local function armed()
        -- Boss mode is Premium-only: Free stays protection-focused
        return alive and HUB.tier == "premium" and settings.aggression == true and settings.brainOn ~= false
    end
    local function shortName(s)
        s = tostring(s or "it")
        return string.gsub(s, "%s*%b[]", "")
    end
    local function isNpcModel(model, hum, root)
        if not (model and model.Parent and hum and root and root.Parent) or model == LP.Character then return false end
        if hum.Health <= 0 then return false end
        local ok, plr = pcall(function() return Players:GetPlayerFromCharacter(model) end)
        return ok and plr == nil
    end
    local function playerNear(range)
        local r = hrp()
        if not r then return nil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr and (pr.Position - r.Position).Magnitude < range then return p end
            end
        end
        return nil
    end
    local function faceTo(pos)
        local r = hrp()
        if not r or (MOV and MOV.carrying) then return end
        local d = flat(pos - r.Position)
        if d.Magnitude < 0.5 then return end
        pcall(function() r.CFrame = CFrame.lookAt(r.Position, r.Position + d) end)
    end
    local function m1()
        local c, h = char(), hum()
        if not (c and h) then return false end
        local tl = c:FindFirstChildOfClass("Tool")
        if tl and GV.isFruitItem(tl) then pcall(function() h:UnequipTools() end) tl = nil end
        if not tl then
            if CORE.pickWeapon then tl = CORE.pickWeapon() end
            local bp = LP:FindFirstChildOfClass("Backpack")
            if not tl and bp then
                if lastTool and lastTool.Parent == bp then tl = lastTool
                else for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and not GV.isFruitItem(t) then tl = t break end end end
            end
            if tl and tl.Parent ~= c then pcall(function() h:EquipTool(tl) end) end
        end
        if tl then
            lastTool = tl
            return pcall(function() tl:Activate() end)
        end
        if mouseClickFn then return pcall(mouseClickFn) end
        return false
    end

    -- ---------------- universal arsenal discovery ----------------
    -- Smart order for ANY game:
    --   1) Tools you own (Activate) + M1  — works without VirtualInputManager
    --   2) Known attack keys from game profile / ABI
    --   3) Common combat keys Z/X/C/V/F (probed, never assumed)
    -- Never blindly mash Q/E/R/… (dash, menus, ken, inventory) — only if a profile/ABI
    -- marks them as attack. Utility kinds (heal/dash/flight/…) are excluded.
    local arsenal, arsenalT, probeIdx = {}, -10, 1
    local COMBAT_KEYS = {"Z", "X", "C", "V", "F"}
    local UTILITY_KIND = {heal = true, shield = true, block = true, dash = true, flight = true, speed = true, teleport = true}
    local NON_WEAPON = {"heal", "medkit", "bandage", "potion", "food", "apple", "burger", "drink", "cola", "pizza", "candy",
        "snack", "elixir", "bloxy", "flashlight", "torch", "lantern", "phone", "radio", "gps", "compass"}
    local function isNonWeaponTool(tl)
        if not tl or GV.isFruitItem(tl) then return true end
        local s = " " .. string.lower(tostring(tl.Name) .. " " .. tostring(tl.ToolTip or "")) .. " "
        for _, w in ipairs(NON_WEAPON) do
            if #w >= 3 and string.find(s, w, 1, true) then return true end
        end
        -- ABI already classified this tool as utility?
        if ABI and ABI.list then
            for _, a in ipairs(ABI.list) do
                if a.ref == tl and a.kind and UTILITY_KIND[a.kind] then return true end
            end
        end
        return false
    end
    local function offenseSk(id)
        local off = brain.data and brain.data.offense
        local sk = off and off.skills and off.skills[id]
        return type(sk) == "table" and sk or nil
    end
    local function isBroken(id)
        local sk = offenseSk(id)
        if sk and sk.broken then return true end
        return not canTry("offense_" .. id)
    end
    local function isWorking(id)
        local sk = offenseSk(id)
        return sk ~= nil and not sk.broken and (tonumber(sk.ok) or 0) > 0
    end
    local function isUntested(id)
        local sk = offenseSk(id)
        return sk == nil or ((tonumber(sk.ok) or 0) == 0 and (tonumber(sk.fail) or 0) == 0 and not sk.broken)
    end
    local function hasVimKeys()
        return ABI and ABI.pressKey and ABI.hasVIM and ABI.hasVIM()
    end
    local function keyCandidates(tier)
        -- tier "known": profile + ABI attack keys only
        -- tier "combat": + Z/X/C/V/F
        local out, seen = {}, {}
        local function add(k, trust)
            k = tostring(k or "")
            if k == "" or seen[k] then return end
            -- skip keys ABI already knows as utility
            if ABI and ABI.list then
                for _, a in ipairs(ABI.list) do
                    if a.src == "key" and a.key == k and a.kind and UTILITY_KIND[a.kind] then return end
                end
            end
            seen[k] = true
            out[#out + 1] = {key = k, trust = trust or 0.2}
        end
        local pf = GAMEINFO and GAMEINFO.module and GAMEINFO.module.profile
        local keys = pf and pf.keys and pf.keys.skills
        if type(keys) == "table" then for _, k in ipairs(keys) do add(k, 0.45) end end
        local mod = GAMEINFO and GAMEINFO.module
        if mod and type(mod.abilities) == "table" then
            for _, a in ipairs(mod.abilities) do
                if a.kind == "attack" or a.kind == nil then add(settings["key_" .. tostring(a.id)] or a.key, 0.5) end
            end
        end
        if ABI and ABI.list then
            for _, a in ipairs(ABI.list) do
                if a.kind == "attack" and a.src == "key" and a.key then add(a.key, 0.4) end
            end
        end
        if tier == "combat" then
            for _, k in ipairs(COMBAT_KEYS) do add(k, 0.2) end
        end
        return out
    end
    local function rebuildArsenal()
        local out, seen = {}, {}
        local function push(e)
            if not e or not e.id or seen[e.id] then return end
            if isBroken(e.id) then return end
            seen[e.id] = true
            out[#out + 1] = e
        end
        push({id = "M1", kind = "m1", label = "M1", trust = 1, probe = false})
        -- Tools first: Activate works in basically every combat game without VIM
        local function addTool(tl)
            if not (tl and tl:IsA("Tool")) or isNonWeaponTool(tl) then return end
            push({id = "tool:" .. tl.Name, kind = "tool", label = tl.Name, ref = tl, trust = 0.75, probe = false})
        end
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then for _, t in ipairs(bp:GetChildren()) do addTool(t) end end
        local c = char()
        if c then for _, t in ipairs(c:GetChildren()) do addTool(t) end end
        if ABI and ABI.list then
            for _, a in ipairs(ABI.list) do
                if a.kind == "attack" then
                    if a.src == "tool" and a.ref then
                        push({id = "tool:" .. a.label, kind = "tool", label = a.label, ref = a.ref, trust = 0.8, probe = false})
                    elseif a.src == "gui" and a.ref and settings.abilGui == true then
                        push({id = "gui:" .. a.label, kind = "gui", label = a.label, ref = a.ref, trust = 0.3, probe = true})
                    end
                end
            end
        end
        -- Keys only when VirtualInputManager exists; otherwise they'd all "fail" and poison learning
        if settings.aggroSkills ~= false and hasVimKeys() then
            local haveWorkingKey, combatPending = false, false
            local off = brain.data and brain.data.offense and brain.data.offense.skills
            if type(off) == "table" then
                for id, sk in pairs(off) do
                    if type(id) == "string" and string.sub(id, 1, 4) == "key:" and type(sk) == "table" then
                        if (tonumber(sk.ok) or 0) > 0 and not sk.broken then haveWorkingKey = true end
                    end
                end
            end
            for _, k in ipairs(COMBAT_KEYS) do
                local id = "key:" .. k
                if not isWorking(id) and not isBroken(id) then combatPending = true break end
            end
            -- keep probing Z/X/C/V/F until one works or all are ruled out; never mash Q/E/R blindly
            local tier = (haveWorkingKey or not combatPending) and "known" or "combat"
            for _, k in ipairs(keyCandidates(tier)) do
                push({id = "key:" .. k.key, kind = "key", label = k.key, key = k.key, trust = k.trust, probe = true})
            end
        end
        table.sort(out, function(a, b)
            local wa, wb = isWorking(a.id), isWorking(b.id)
            if wa ~= wb then return wa end
            local sa, sb = offenseSk(a.id), offenseSk(b.id)
            local oa = sa and ((tonumber(sa.dmg) or 0) + (tonumber(sa.ok) or 0) * 5) or 0
            local ob = sb and ((tonumber(sb.dmg) or 0) + (tonumber(sb.ok) or 0) * 5) or 0
            if oa ~= ob then return oa > ob end
            -- tools before speculative keys
            local pa = (a.kind == "tool" and 2) or (a.kind == "m1" and 1.5) or (a.probe and 0) or 1
            local pb = (b.kind == "tool" and 2) or (b.kind == "m1" and 1.5) or (b.probe and 0) or 1
            if pa ~= pb then return pa > pb end
            return (a.trust or 0) > (b.trust or 0)
        end)
        arsenal = out
        AG.arsenalN = #out
        local w = 0
        for _, e in ipairs(out) do if isWorking(e.id) then w += 1 end end
        AG.workingN = w
        arsenalT = now()
    end
    local function markUserAttack()
        if SEN then SEN.userAtkT = now() end
    end
    local function fireEntry(e)
        if not e then return false end
        if e.kind == "m1" then
            local ok = m1()
            if ok then markUserAttack() end
            return ok
        end
        if e.kind == "tool" then
            local tl, h, c = e.ref, hum(), char()
            if not (tl and tl.Parent and h and c) then return false end
            local ok = pcall(function()
                if tl.Parent ~= c then h:EquipTool(tl) end
                task.wait(0.08)
                if not tl.Parent then return end
                tl:Activate()
            end)
            if ok then markUserAttack() end
            return ok
        end
        if e.kind == "key" and ABI and ABI.pressKey then
            local ok = ABI.pressKey(e.key, 0.07)
            if ok then markUserAttack() end
            return ok
        end
        if e.kind == "gui" and ABI and ABI.use then
            local ok = ABI.use({kind = "attack", label = e.label, src = "gui", ref = e.ref, cd = 0.4, last = -100, id = e.id})
            if ok then markUserAttack() end
            return ok
        end
        return false
    end
    local function pickNextEntry(preferredId, preferProbe)
        if preferredId and isWorking(preferredId) then
            for _, e in ipairs(arsenal) do if e.id == preferredId then return e, false end end
        end
        -- 1) strongest working hit
        for _, e in ipairs(arsenal) do
            if isWorking(e.id) then return e, false end
        end
        -- 2) probe ONLY untested entries (tools first thanks to sort)
        if preferProbe or AG.workingN == 0 then
            local n = #arsenal
            for _ = 1, n do
                probeIdx = (probeIdx % math.max(n, 1)) + 1
                local e = arsenal[probeIdx]
                if e and e.id ~= "M1" and isUntested(e.id) then
                    return e, true
                end
            end
            -- then anything not broken and not yet working (retry soft fails)
            for _, e in ipairs(arsenal) do
                if e.id ~= "M1" and not isBroken(e.id) and not isWorking(e.id) then
                    return e, true
                end
            end
        end
        for _, e in ipairs(arsenal) do if e.id == "M1" then return e, false end end
        return arsenal[1], false
    end

    -- ---------------- target selection (any game's NPCs via Sense) ----------------
    -- Hunt NPCs = hostile / enemy / recent attackers ONLY — never shopkeepers or quest NPCs.
    local function pickNpc(range)
        local best, bd
        for _, info in ipairs(SEN.list or {}) do
            if info.model and isNpcModel(info.model, info.hum, info.root) and info.dist and info.dist <= range and not info.player then
                local hostile = info.hostile == true or info.enemy == true or (now() - (info.lastHitAt or -10) < 10)
                if hostile then
                    local mx = math.max(info.hum.MaxHealth, 1)
                    local hpP = info.hum.Health / mx
                    local score = (info.hostile and 30 or 0) + (info.enemy and 10 or 0) + (1 - hpP) * 20 - info.dist
                    local bestAtk = brain.bestAttack and select(1, brain.bestAttack(info.name or info.model.Name))
                    if bestAtk then score += 12 end
                    if not bd or score > bd then best, bd = info, score end
                end
            end
        end
        return best
    end
    local function pickPvp(range)
        if settings.aggroPvp ~= true then return nil end
        local best, bd
        for p, t in pairs(brain.threat or {}) do
            if (t.level == "Enemy" or t.level == "Exploiter") and t.dist and t.dist <= range then
                local c = p.Character
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local root = c and c:FindFirstChild("HumanoidRootPart")
                if hum and root and hum.Health > 0 then
                    local score = t.score - t.dist + ((t.level == "Exploiter") and 20 or 0)
                    if not bd or score > bd then
                        best, bd = {kind = "player", player = p, model = c, hum = hum, root = root, name = p.DisplayName, dist = t.dist}, score
                    end
                end
            end
        end
        return best
    end

    -- ---------------- execute ladder (learn → hit → probe) ----------------
    local busy, nextAt, gapAcc = false, 0, 0
    local function verify(hum, root, hp0, maxHp, entry, name, isPlayer, wasProbe, alone)
        local skillId = entry and entry.id or "M1"
        local label = entry and entry.label or skillId
        -- only credit / blame a single isolated fire — bursts muddy who did the damage
        if alone == false then return end
        task.delay(0.9, function()
            if not hum then return end
            local still = hum.Parent ~= nil
            local hp1 = still and hum.Health or 0
            local dmg = hp0 - hp1
            local killed = (not still) or hp1 <= 0
            -- if we were too far when the window closed, a miss doesn't prove the skill is useless
            local r = hrp()
            local dist = (r and root and root.Parent) and (root.Position - r.Position).Magnitude or 99
            local inReach = dist <= 14
            if dmg > 0.5 then
                if brain.offenseNote then brain.offenseNote(skillId, dmg, maxHp, name, killed) end
                AG.landed += 1
                report("offense_" .. skillId, true, "Aggression (" .. label .. ")")
                if wasProbe and not foundSaid[skillId] then
                    foundSaid[skillId] = true
                    AG.learned += 1
                    if not say("aggro_found", {name = label}, 2) then toast("Guardian learned: " .. label .. " hits here.", "ok", 3) end
                    if VFX.moment then VFX.moment("learn", "LEARNED", C.spirit) end
                elseif not wasProbe and dmg >= maxHp * 0.35 then
                    if VFX.moment then VFX.moment("dominate", "EXECUTE", C.gold) end
                end
            elseif inReach then
                if brain.offenseNote then brain.offenseNote(skillId, 0, maxHp, name, false) end
                AG.fails += 1
                if wasProbe then
                    local sk = offenseSk(skillId)
                    local fails = sk and (tonumber(sk.fail) or 0) or 0
                    if fails >= 3 and sk and (tonumber(sk.ok) or 0) == 0 then
                        sk.broken = true
                        if not foundSaid["drop:" .. skillId] then
                            foundSaid["drop:" .. skillId] = true
                            if not say("aggro_drop", {name = label}, 1) then toast("Guardian: " .. label .. " does nothing here — dropped.", "info", 2.5) end
                        end
                    end
                else
                    -- learned hit that stopped working — softer than Brain "broken" spam on day-one probes
                    report("offense_" .. skillId, false, "Aggression (" .. label .. ")")
                end
            end
            if killed and dmg > 0.5 then
                AG.kills += 1
                if isPlayer and brain.markPvpKill then brain.markPvpKill() end
                if dmg >= maxHp * 0.35 or skillId ~= "M1" then AG.oneshots += 1 end
                if not say(isPlayer and "aggro_pvp" or "aggro_kill", {name = shortName(name)}, 2) then
                    toast("Guardian: " .. shortName(name) .. " down.", "shield", 2)
                end
                -- Boss presence: verified finish only
                if VFX.moment then
                    if AG.kills > 0 and AG.kills % 3 == 0 then
                        VFX.moment("boss", "BOSS", C.gold)
                    else
                        VFX.moment("kill", isPlayer and "OUT" or "DOWN", C.spirit)
                    end
                end
                if VFX.taunt then pcall(VFX.taunt, "npc", shortName(name)) end
            end
            if now() - arsenalT > 0.5 then rebuildArsenal() end
        end)
    end
    local function execute(tg)
        if busy or not tg or not tg.hum or not tg.root then return end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 then return end
        busy = true
        AG.mode = "execute"
        AG.last = now()
        task.spawn(function()
            local ok, err = pcall(function()
                if now() - arsenalT > 2 then rebuildArsenal() end
                local name = tg.name or "target"
                local isPlayer = tg.kind == "player"
                local maxHp = math.max(tg.hum.MaxHealth, 1)
                local hp0 = tg.hum.Health
                if not (tg.root and tg.root.Parent) then return end
                faceTo(tg.root.Position)
                -- get into real melee range before probing, or every skill looks broken
                local dist0 = (tg.root.Position - r.Position).Magnitude
                if settings.aggroLock ~= false and dist0 > 6 and MOV and MOV.dashTo then
                    local to = tg.root.Position + unitOr(flat(r.Position - tg.root.Position), Vector3.new(0, 0, 1)) * 3.8
                    pcall(MOV.dashTo, to)
                    task.wait(0.14)
                    r = hrp() or r
                    if tg.root and tg.root.Parent then faceTo(tg.root.Position) end
                end
                if AG.workingN == 0 and now() - learnSaid > 20 then
                    learnSaid = now()
                    if not say("aggro_learn", nil, 2) then toast("Guardian: learning this game's kit…", "info", 3) end
                    -- no flash — Learning is intent, not a verified win
                end
                local bestId = brain.bestAttack and select(1, brain.bestAttack(name))
                local needProbe = AG.workingN < 2 and settings.aggroSkills ~= false
                local entry, probing = pickNextEntry(bestId, needProbe)
                if settings.aggroOneShot ~= false and bestId and bestId ~= "M1" and isWorking(bestId) then
                    for _, e in ipairs(arsenal) do if e.id == bestId then entry, probing = e, false break end end
                    -- Presence without premature "EXECUTE" flash — moment fires only if damage verifies
                    if VFX.afterimage then VFX.afterimage(C.spirit) end
                    if VFX.slashTrail then
                        pcall(VFX.slashTrail, r.Position, tg.root.Position, C.smoke)
                    end
                    if not say("aggro_oneshot", {name = shortName(name), skill = entry and entry.label or bestId}, 2) then
                        toast("Guardian: execute · " .. tostring(entry and entry.label or bestId), "shield", 2)
                    end
                end
                if probing then
                    AG.probing = entry and entry.label or ""
                    AG.mode = "probe"
                else
                    AG.probing = ""
                end
                local did = entry and fireEntry(entry)
                local used = entry
                local extra = 0
                if did then AG.strikes += 1 end
                -- burst only known winners, never while probing (keeps credit clean)
                if did and settings.aggroSkills ~= false and not probing then
                    for _, e in ipairs(arsenal) do
                        if extra >= (lite() and 1 or 2) then break end
                        if e ~= entry and e.id ~= "M1" and isWorking(e.id) and fireEntry(e) then
                            extra += 1
                            AG.strikes += 1
                            task.wait(0.1)
                        end
                    end
                    if extra > 0 then
                        AG.bursts += 1
                        if brain.markBurst then brain.markBurst() end
                    end
                end
                -- combo fallback: prefer another TOOL, never a speculative key spam
                if (not did) and settings.aggroCombo ~= false then
                    for _, e in ipairs(arsenal) do
                        if e ~= entry and e.kind == "tool" and not isBroken(e.id) and fireEntry(e) then
                            did, used, probing = true, e, isUntested(e.id)
                            AG.strikes += 1
                            break
                        end
                    end
                end
                if not did then
                    did = m1()
                    used = {id = "M1", label = "M1", kind = "m1"}
                    if did then markUserAttack() AG.strikes += 1 end
                    probing = false
                end
                if did and used and tg.hum and tg.root then
                    if settings.handsOn == true and VFX.handsMode then VFX.handsMode("strike", {pos = tg.root.Position}, 0.28) end
                    if VFX.slashTrail then
                        local perp = Vector3.yAxis:Cross(unitOr(flat(tg.root.Position - r.Position), Vector3.new(0, 0, -1)))
                        pcall(VFX.slashTrail, tg.root.Position + perp * 3 + Vector3.new(0, 2, 0), tg.root.Position - perp * 3)
                    end
                    verify(tg.hum, tg.root, hp0, maxHp, used, name, isPlayer, probing, extra == 0)
                end
            end)
            if not ok then CORE.log("ERR", "aggression: " .. tostring(err)) end
            busy = false
            AG.mode = AG.target and "locked" or "idle"
        end)
    end

    -- ---------------- main loop ----------------
    onHeartbeat("aggro56", function(dt)
        if not armed() then
            if AG.target or AG.mode ~= "idle" then AG.target, AG.mode, AG.why, AG.probing = nil, "idle", "", "" end
            if MOV then MOV.clear("aggro") end
            return
        end
        if now() - arsenalT > 4 then pcall(rebuildArsenal) end
        local r, h = hrp(), hum()
        if not (r and h) or h.Health <= 0 or HUB.rescueBusy or (MOV and MOV.carrying) or FX.inSafe() then
            AG.target, AG.mode = nil, "paused"
            AG.why = HUB.rescueBusy and "lifeline" or (FX.inSafe() and "safe zone" or "busy")
            if MOV then MOV.clear("aggro") end
            return
        end
        -- life first: aggression never overrides critically low HP
        if h.Health / math.max(h.MaxHealth, 1) < 0.32 then
            AG.target, AG.mode, AG.why = nil, "paused", "low health"
            if MOV then MOV.clear("aggro") end
            return
        end
        if UserInputService:GetFocusedTextBox() then return end
        local range = math.clamp(tonumber(settings.aggroRange) or 20, 8, 40)
        -- PvP enemies first (only when explicitly enabled), else NPCs
        local tg = pickPvp(range)
        if not tg and settings.aggroNpc ~= false then
            local near = playerNear(18)
            if near and settings.aggroPvp ~= true then
                AG.target, AG.mode, AG.why = nil, "paused", near.DisplayName .. " nearby"
                if MOV then MOV.clear("aggro") end
                return
            end
            local info = pickNpc(range)
            if info then
                tg = {kind = "npc", model = info.model, hum = info.hum, root = info.root, name = info.name or info.model.Name, dist = info.dist}
            end
        end
        AG.target = tg
        if not tg then
            AG.mode, AG.why = "armed", "no target"
            if MOV then MOV.clear("aggro") end
            return
        end
        AG.mode, AG.why = "locked", shortName(tg.name)
        faceTo(tg.root.Position)
        if settings.aggroLock ~= false and tg.dist and tg.dist > 9 and MOV and MOV.want then
            local toward = unitOr(flat(tg.root.Position - r.Position), Vector3.new(0, 0, -1))
            MOV.want("aggro", 55, toward * math.clamp((tg.dist - 6) * 2.2, 8, 28), 0.2)
        elseif MOV then
            MOV.clear("aggro")
        end
        gapAcc += dt
        local rate = math.clamp(tonumber(settings.aggroRate) or 4, 1, 8)
        local gap = (1 / rate) * (busy and 1.4 or 1)
        if busy or now() < nextAt or gapAcc < gap then return end
        gapAcc = 0
        nextAt = now() + gap * 0.5
        execute(tg)
    end)
    CORE.onChar("aggro56", function()
        AG.target, AG.mode, AG.why, busy = nil, "idle", "", false
        if MOV then MOV.clear("aggro") end
    end)
    function AG.status()
        if settings.aggression ~= true then return "off" end
        local st = brain.offenseStats and brain.offenseStats() or {}
        local bits = {AG.mode}
        if AG.why ~= "" then bits[#bits + 1] = AG.why end
        if AG.probing ~= "" then bits[#bits + 1] = "probe " .. AG.probing end
        bits[#bits + 1] = AG.workingN .. "/" .. AG.arsenalN .. " kit"
        if AG.learned > 0 then bits[#bits + 1] = "+" .. AG.learned .. " learned" end
        bits[#bits + 1] = AG.kills .. " kills"
        bits[#bits + 1] = AG.landed .. "/" .. AG.strikes .. " hits"
        if st.skills then bits[#bits + 1] = st.skills .. " remembered" end
        return table.concat(bits, " · ")
    end
    function AG.summary()
        return AG.workingN .. " working · " .. AG.learned .. " learned · " .. AG.kills .. " kills · " .. AG.bursts .. " bursts · " .. AG.landed .. "/" .. AG.strikes .. " verified"
    end
    function AG.rebuild() rebuildArsenal() end
    -- warm the arsenal shortly after load so the first arm feels instant
    task.defer(function() pcall(rebuildArsenal) end)
    onUnload(function() if MOV then MOV.clear("aggro") end end)
end)

-- Void Net: universal network-ownership physgun (-net / -bring / -hold / -drop / -throw / -orbit / -wall / -pulse)
CORE.safeModule("14w Void Net", function()
    local KIT = VFX._kit or {}
    local NET = {
        part = nil, model = nil, mode = "idle", why = "",
        brings = 0, holds = 0, throws = 0, snaps = 0, fails = 0,
        ownedSeen = 0, serverSeen = 0, lastCmd = "-",
    }
    CORE.net = NET
    local netOwnerFn = exfn("isnetworkowner")
    local align, orient, att0, beam, tipAtt, tipPart = nil, nil, nil, nil, nil, nil
    local orbitAng, lastSay = 0, -100
    local mouse = LP:GetMouse()

    local function now() return os.clock() end
    local function lite() return PERF.lite or isTouch end
    local function say(msg, kind, sec)
        if now() - lastSay < 0.8 then return end
        lastSay = now()
        toast(msg, kind or "shield", sec or 2.5)
    end
    local function clientOwns(part)
        if not part or not part:IsA("BasePart") or part.Anchored then return false end
        if netOwnerFn then
            local ok, v = pcall(netOwnerFn, part)
            if ok and type(v) == "boolean" then return v end
        end
        local ok, age = pcall(function() return part.ReceiveAge end)
        return ok and tonumber(age) == 0
    end
    local function isPlayerPart(part)
        local m = part:FindFirstAncestorWhichIsA("Model")
        while m do
            if Players:GetPlayerFromCharacter(m) then return true, m end
            if m:FindFirstChildOfClass("Humanoid") and m ~= char() then
                -- treat unnamed humanoids as characters when Allow players is off
                return true, m
            end
            m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
        end
        return false, nil
    end
    local function allowed(part)
        if not part or not part:IsA("BasePart") or part.Anchored then return false end
        if not part:IsDescendantOf(workspace) then return false end
        local c = char()
        if c and part:IsDescendantOf(c) then return false end
        local ok, ours = pcall(function() return part:GetAttribute("SecretHub") end)
        if ok and ours then return false end
        local isPl = isPlayerPart(part)
        if isPl and settings.netPlayers ~= true then return false end
        return clientOwns(part)
    end
    local function aimPoint()
        local cam = workspace.CurrentCamera
        if mouse and mouse.Hit then return mouse.Hit.Position, mouse.Target end
        if cam then return (cam.CFrame * CFrame.new(0, 0, -24)).Position, nil end
        local r = hrp()
        return r and r.Position or Vector3.zero, nil
    end
    local function holdPoint()
        local cam = workspace.CurrentCamera
        local r = hrp()
        if settings.netOrbit == true and r then
            orbitAng = (orbitAng + 0.045) % (math.pi * 2)
            local rad = 8
            return r.Position + Vector3.new(math.cos(orbitAng) * rad, 2.5, math.sin(orbitAng) * rad)
        end
        if cam then return (cam.CFrame * CFrame.new(0, 0, -10)).Position end
        return r and (r.Position + r.CFrame.LookVector * 10 + Vector3.new(0, 2, 0)) or Vector3.zero
    end
    local function clearFx()
        if beam then pcall(function() beam:Destroy() end) beam = nil end
        if tipAtt then pcall(function() tipAtt:Destroy() end) tipAtt = nil end
        if tipPart then pcall(function() tipPart:Destroy() end) tipPart = nil end
        if align then pcall(function() align:Destroy() end) align = nil end
        if orient then pcall(function() orient:Destroy() end) orient = nil end
        if att0 then pcall(function() att0:Destroy() end) att0 = nil end
    end
    local function release(silent)
        local had = NET.part ~= nil
        clearFx()
        NET.part, NET.model, NET.mode = nil, nil, "idle"
        if had then
            NET.drops += 1
            if not silent then say("Void Net · dropped", "info", 1.5) end
        end
    end
    NET.drop = function(silent) release(silent == true) end

    local function attach(part, mode)
        if not allowed(part) then
            NET.fails += 1
            NET.why = "not client-owned"
            say("Void Net · server owns that · can't move it", "warn", 3)
            return false
        end
        release(true)
        NET.part, NET.mode, NET.why = part, mode or "hold", ""
        NET.model = part:FindFirstAncestorWhichIsA("Model")
        local ok = pcall(function()
            att0 = own(new("Attachment", {Name = "SecretNetAtt", Parent = part}))
            align = own(new("AlignPosition", {
                Mode = Enum.PositionAlignmentMode.OneAttachment, Attachment0 = att0,
                MaxForce = 1e7, MaxVelocity = 160, Responsiveness = 55,
                Position = part.Position, Parent = part,
            }))
            orient = own(new("AlignOrientation", {
                Mode = Enum.OrientationAlignmentMode.OneAttachment, Attachment0 = att0,
                MaxTorque = 1e7, Responsiveness = 25, CFrame = part.CFrame, Parent = part,
            }))
            if settings.vfx ~= false and KIT.part then
                tipPart = KIT.part({Transparency = 1, Size = Vector3.new(0.15, 0.15, 0.15), CanCollide = false})
                tipPart.Parent = workspace
                tipAtt = own(new("Attachment", {Name = "SecretNetTip", Parent = tipPart}))
                beam = own(new("Beam", {
                    Attachment0 = tipAtt, Attachment1 = att0, Width0 = 0.08, Width1 = 0.03,
                    FaceCamera = true, LightEmission = 1, LightInfluence = 0, Brightness = 2,
                    Color = ColorSequence.new(C.gold or Color3.fromRGB(220, 190, 120), Color3.fromRGB(180, 180, 200)),
                    Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.65)}),
                    Segments = lite() and 4 or 8, Parent = workspace.Terrain,
                }))
            end
        end)
        if not ok then release(true) NET.fails += 1 NET.why = "attach failed" return false end
        if CORE.claimSim then pcall(CORE.claimSim) end
        if mode == "bring" then NET.brings += 1 else NET.holds += 1 end
        if KIT.emit and not lite() then pcall(KIT.emit, part.Position, C.gold or Color3.fromRGB(220, 190, 120), 12, 10, 0.6, 0.45) end
        say("Void Net · " .. (mode or "hold") .. " · " .. part.Name, "shield", 2)
        return true
    end

    local function pickTarget(preferPart)
        if preferPart and preferPart:IsA("BasePart") and allowed(preferPart) then return preferPart end
        local aim, target = aimPoint()
        if target and target:IsA("BasePart") and allowed(target) then return target end
        -- nearest ownable unanchored part in range (skip terrain / huge maps)
        local me = hrp()
        if not me then return nil end
        local range = math.clamp(tonumber(settings.netRange) or 40, 10, 80)
        local best, bestD = nil, range
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char() or me}
        params.MaxParts = 120
        local ok, parts = pcall(function()
            return workspace:GetPartBoundsInRadius(me.Position, range, params)
        end)
        if not ok or type(parts) ~= "table" then return nil end
        for _, p in ipairs(parts) do
            if allowed(p) and p.Size.Magnitude < 80 then
                local d = (p.Position - (aim or me.Position)).Magnitude
                if d < bestD then best, bestD = p, d end
            end
        end
        return best
    end

    function NET.hold()
        if settings.voidNet ~= true then say("Turn on Void Net first", "warn", 2) return end
        if NET.part and NET.mode ~= "idle" then say("Already holding · -drop first", "info", 2) return end
        local p = pickTarget()
        if not p then say("Void Net · nothing ownable in range", "warn", 2.5) NET.why = "no target" return end
        attach(p, "hold")
    end
    function NET.bring()
        if settings.voidNet ~= true then say("Turn on Void Net first", "warn", 2) return end
        local p = pickTarget()
        if not p then say("Void Net · nothing ownable in range", "warn", 2.5) NET.why = "no target" return end
        attach(p, "bring")
    end
    function NET.throw()
        if settings.voidNet ~= true then say("Turn on Void Net first", "warn", 2) return end
        local part = NET.part
        if not part then
            local p = pickTarget()
            if not p then say("Void Net · nothing to throw", "warn", 2) return end
            if not attach(p, "hold") then return end
            part = NET.part
            task.wait(0.08)
        end
        if not part or not part.Parent then return end
        local cam = workspace.CurrentCamera
        local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
        clearFx()
        pcall(function()
            part.AssemblyLinearVelocity = dir * 140 + Vector3.new(0, 28, 0)
            part.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
        end)
        NET.part, NET.model, NET.mode = nil, nil, "idle"
        NET.throws += 1
        say("Void Net · thrown", "shield", 1.8)
        if KIT.emit and not lite() then pcall(KIT.emit, part.Position, C.spirit or Color3.fromRGB(160, 200, 255), 14, 16, 0.5, 0.4) end
    end
    -- Barricade: pull up to 6 nearby owned props into a wall in front of you
    function NET.wall()
        if settings.voidNet ~= true then say("Turn on Void Net first", "warn", 2) return end
        local me = hrp()
        if not me then return end
        local look = me.CFrame.LookVector
        local base = me.Position + look * 8 + Vector3.new(0, 2, 0)
        local range = math.clamp(tonumber(settings.netRange) or 40, 10, 80)
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char() or me}
        params.MaxParts = 100
        local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(me.Position, range, params) end)
        if not ok then return end
        local list = {}
        for _, p in ipairs(parts) do
            if allowed(p) and p.Size.Magnitude < 40 then list[#list + 1] = p end
            if #list >= 6 then break end
        end
        if #list == 0 then say("Void Net · no props for barricade", "warn", 2.5) return end
        for i, p in ipairs(list) do
            local slot = base + me.CFrame.RightVector * ((i - (#list + 1) / 2) * 3.2)
            pcall(function()
                p.CFrame = CFrame.new(slot, slot + look)
                p.AssemblyLinearVelocity = Vector3.zero
            end)
        end
        NET.brings += #list
        say("Void Net · barricade ×" .. #list, "shield", 2.2)
    end
    -- Pulse: shove every owned prop in range away from you
    function NET.pulse()
        if settings.voidNet ~= true then say("Turn on Void Net first", "warn", 2) return end
        local me = hrp()
        if not me then return end
        local range = math.clamp(tonumber(settings.netRange) or 40, 10, 80)
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char() or me}
        params.MaxParts = 120
        local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(me.Position, range, params) end)
        if not ok then return end
        local n = 0
        for _, p in ipairs(parts) do
            if allowed(p) then
                local away = p.Position - me.Position
                if away.Magnitude > 0.5 then
                    pcall(function() p.AssemblyLinearVelocity = away.Unit * 95 + Vector3.new(0, 35, 0) end)
                    n += 1
                end
            end
        end
        if n == 0 then say("Void Net · nothing to pulse", "warn", 2) return end
        NET.throws += n
        say("Void Net · pulse ×" .. n, "shield", 2)
        if VFX.ring then pcall(VFX.ring, me.Position - Vector3.new(0, 2, 0), C.gold or Color3.fromRGB(220, 190, 120), 16) end
    end

    -- Void Siphon: ask the executor / engine to hand nearby physics to this client, then grab
    local setOwner = exfn("setnetworkowner")
    local setHidden = exfn("sethiddenproperty")
    NET.siphons = 0
    function NET.siphon()
        if settings.voidNet ~= true and settings.voidSiphon ~= true then
            say("Turn on Void Net or Void Siphon first", "warn", 2)
            return 0
        end
        local me = hrp()
        if not me then return 0 end
        if CORE.claimSim then pcall(CORE.claimSim) end
        local range = math.clamp(tonumber(settings.netRange) or 40, 10, 80)
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char() or me}
        params.MaxParts = 100
        local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(me.Position, range, params) end)
        if not ok then return 0 end
        local n = 0
        for _, p in ipairs(parts) do
            if p:IsA("BasePart") and not p.Anchored then
                local isPl = isPlayerPart(p)
                if isPl and settings.netPlayers ~= true then
                    -- skip
                else
                    local claimed = false
                    if setOwner then
                        claimed = pcall(function() setOwner(p, LP) end) or pcall(function() setOwner(p) end)
                    end
                    if setHidden then
                        pcall(function() setHidden(p, "NetworkIsSleeping", false) end)
                        pcall(function() setHidden(p, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual) end)
                    end
                    -- nudge: small CFrame poke can convince ownership handoff on some titles
                    if not clientOwns(p) then
                        pcall(function()
                            local o = p.CFrame
                            p.CFrame = o + Vector3.new(0, 0.05, 0)
                            p.CFrame = o
                        end)
                    end
                    if clientOwns(p) or claimed then
                        n += 1
                        if not NET.part and allowed(p) then attach(p, "hold") end
                    end
                end
            end
        end
        NET.siphons += n
        if n > 0 then
            say("Void Siphon · claimed ×" .. n, "shield", 2)
        else
            say("Void Siphon · server kept ownership (honest)", "warn", 2.5)
        end
        return n
    end

    function NET.status()
        if settings.voidNet ~= true then return "off" end
        if NET.mode ~= "idle" and NET.part then
            return NET.mode .. " · " .. NET.part.Name .. (settings.netOrbit and " · orbit" or "")
        end
        if NET.why ~= "" then return "idle · " .. NET.why end
        return "idle · aim + -bring / Hold"
    end
    function NET.cap()
        local api = netOwnerFn and "isnetworkowner" or "ReceiveAge"
        return api .. " · " .. NET.ownedSeen .. " owned / " .. NET.serverSeen .. " server · " .. NET.brings .. " bring · " .. NET.throws .. " throw"
    end

    -- Chat commands (legacy Chatted + TextChatService)
    local function handleCmd(raw)
        if settings.voidNet ~= true or settings.netChat == false then return end
        local msg = string.lower(string.gsub(tostring(raw or ""), "^%s+", ""))
        msg = string.gsub(msg, "%s+$", "")
        -- strip leading slash used by some chat UIs
        if string.sub(msg, 1, 1) == "/" then msg = string.sub(msg, 2) end
        local cmd, rest = msg:match("^(%-?[%w]+)(.*)$")
        if not cmd then return end
        rest = string.gsub(rest or "", "^%s+", "")
        local map = {
            ["-net"] = true, net = true,
            ["-bring"] = "bring", bring = "bring",
            ["-hold"] = "hold", hold = "hold",
            ["-drop"] = "drop", drop = "drop",
            ["-throw"] = "throw", throw = "throw",
            ["-orbit"] = "orbit", orbit = "orbit",
            ["-wall"] = "wall", wall = "wall", ["-barricade"] = "wall", barricade = "wall",
            ["-pulse"] = "pulse", pulse = "pulse",
            ["-siphon"] = "siphon", siphon = "siphon",
            ["-dominion"] = "dominion", dominion = "dominion",
        }
        local act = map[cmd]
        if not act then return end
        NET.lastCmd = cmd
        if act == true then
            -- bare -net / net = toggle hold on aimed target
            if NET.part then NET.drop() else NET.hold() end
            return
        end
        if act == "bring" then NET.bring()
        elseif act == "hold" then NET.hold()
        elseif act == "drop" then NET.drop()
        elseif act == "throw" then NET.throw()
        elseif act == "orbit" then
            settings.netOrbit = not settings.netOrbit
            saveSettings()
            if K.toggles.netOrbit then pcall(K.toggles.netOrbit.render, true) end
            say("Void Net · orbit " .. (settings.netOrbit and "on" or "off"), "info", 2)
        elseif act == "wall" then NET.wall()
        elseif act == "pulse" then NET.pulse()
        elseif act == "siphon" then NET.siphon()
        elseif act == "dominion" then
            if CORE.forge and CORE.forge.dominion then CORE.forge.dominion() end
        end
    end
    bind(LP.Chatted:Connect(function(msg) pcall(handleCmd, msg) end))
    task.defer(function()
        local ok, tcs = pcall(function() return game:GetService("TextChatService") end)
        if not ok or not tcs then return end
        pcall(function()
            bind(tcs.SendingMessage:Connect(function(msg)
                if msg and msg.Text then pcall(handleCmd, msg.Text) end
            end))
        end)
        pcall(function()
            local chans = tcs:FindFirstChild("TextChannels")
            local ch = chans and (chans:FindFirstChild("RBXGeneral") or chans:FindFirstChild("General"))
            if ch and ch.MessageReceived then
                bind(ch.MessageReceived:Connect(function(m)
                    local src = m and m.TextSource
                    if src and src.UserId == LP.UserId and m.Text then pcall(handleCmd, m.Text) end
                end))
            end
        end)
    end)

    -- hold loop + ownership probe + optional siphon
    local probeAcc, siphonAcc = 0, 0
    onHeartbeat("voidnet14w", function(dt)
        if settings.voidNet ~= true and settings.voidSiphon ~= true then
            if NET.part then release(true) end
            return
        end
        probeAcc += dt siphonAcc += dt
        if settings.voidSiphon == true and siphonAcc > 4 then
            siphonAcc = 0
            pcall(NET.siphon)
        end
        if probeAcc > 1.2 then
            probeAcc = 0
            local me = hrp()
            if me then
                local params = OverlapParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {char() or me}
                params.MaxParts = 60
                local ok, parts = pcall(function()
                    return workspace:GetPartBoundsInRadius(me.Position, math.clamp(tonumber(settings.netRange) or 40, 10, 80), params)
                end)
                if ok and type(parts) == "table" then
                    local o, s = 0, 0
                    for _, p in ipairs(parts) do
                        if p:IsA("BasePart") and not p.Anchored then
                            if clientOwns(p) then o += 1 else s += 1 end
                        end
                    end
                    NET.ownedSeen, NET.serverSeen = o, s
                end
            end
        end
        if settings.voidNet ~= true then return end
        local part = NET.part
        if not part or not part.Parent then
            if NET.mode ~= "idle" then release(true) NET.why = "part gone" end
            return
        end
        if not clientOwns(part) then
            release(true)
            NET.why = "ownership lost"
            say("Void Net · server took ownership back", "warn", 2.5)
            return
        end
        local dest = holdPoint()
        if align then align.Position = dest end
        if orient then
            local cam = workspace.CurrentCamera
            orient.CFrame = cam and CFrame.new(dest, dest + cam.CFrame.LookVector) or CFrame.new(dest)
        end
        if tipPart then
            local cam = workspace.CurrentCamera
            local r = hrp()
            local from = (cam and (cam.CFrame * CFrame.new(0.6, -0.4, -1.2)).Position) or (r and r.Position) or dest
            tipPart.CFrame = CFrame.new(from)
        end
    end)
    onUnload(function() release(true) end)
    CORE.log("BOOT", "Void Net online · chat -net / -bring / -hold / -drop / -throw / -orbit / -wall / -pulse")
end)

-- Remote Lab: scout + classify remotes. Void Override (below) learns / amplifies / probes with verification.
CORE.safeModule("14x Remote Lab", function()
    local LAB = {list = {}, lastScan = 0, byKind = {}, n = 0, index = {}}
    CORE.remotes = LAB
    local WORDS = {
        kill = {"kill", "oneshot", "one_shot", "instakill", "destroyplayer", "eliminate", "execute", "slay"},
        damage = {"damage", "hurt", "takedamage", "dealdamage", "hit", "attack", "combat", "slash", "punch", "blow", "strike", "dmg"},
        heal = {"heal", "regen", "revive", "respawn", "restore"},
        iframe = {"iframe", "i_frame", "invuln", "invincible", "godmode", "immunity", "nodamage", "blockdamage"},
        cooldown = {"cooldown", "cdreset", "resetcd", "clearcd", "skillcd", "abilitycd", "refresh"},
        hitbox = {"hitbox", "range", "reach", "size", "radius", "aoe", "magnitude"},
        replicate = {"replicate", "replicatepacket", "comms", "bridge", "remotehandler", "packet", "netmsg"},
        shop = {"shop", "buy", "purchase", "store"},
        teleport = {"teleport", "warp", "tp"},
        data = {"data", "save", "load", "profile"},
        other = {},
    }
    local function low(s) return string.lower(tostring(s or "")) end
    function LAB.kindOf(name)
        local n = low(name)
        for kind, words in pairs(WORDS) do
            if kind ~= "other" then
                for _, w in ipairs(words) do
                    if string.find(n, w, 1, true) then return kind end
                end
            end
        end
        return "other"
    end
    local kindOf = LAB.kindOf
    function LAB.scan()
        local out, by, idx, nWalk = {}, {}, {}, 0
        local roots = {game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst")}
        pcall(function() roots[#roots + 1] = workspace end)
        for _, root in ipairs(roots) do
            for _, d in ipairs(root:GetDescendants()) do
                nWalk += 1
                if nWalk > 12000 then break end
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                    local path = d:GetFullName()
                    local k = kindOf(d.Name)
                    local e = {name = d.Name, class = d.ClassName, path = path, kind = k, ref = d}
                    out[#out + 1] = e
                    idx[d] = e
                    by[k] = (by[k] or 0) + 1
                    if #out >= 400 then break end
                end
            end
            if #out >= 400 then break end
        end
        table.sort(out, function(a, b)
            if a.kind == b.kind then return a.name < b.name end
            return a.kind < b.kind
        end)
        LAB.list, LAB.byKind, LAB.index, LAB.n, LAB.lastScan = out, by, idx, #out, os.clock()
        CORE.log("REMOTE", "scout " .. LAB.n .. " remotes · kill " .. (by.kill or 0) .. " · damage " .. (by.damage or 0) .. " · heal " .. (by.heal or 0))
        return LAB.n
    end
    function LAB.summary()
        if LAB.n == 0 then return "not scanned yet · tap Scout" end
        local parts = {}
        for _, k in ipairs({"kill", "damage", "heal", "iframe", "cooldown", "hitbox", "teleport", "shop", "data", "replicate", "other"}) do
            if LAB.byKind[k] then parts[#parts + 1] = k .. " " .. LAB.byKind[k] end
        end
        return LAB.n .. " remotes · " .. table.concat(parts, " · ")
    end
    function LAB.dump(limit)
        limit = math.clamp(tonumber(limit) or 40, 5, 120)
        local n = 0
        for _, r in ipairs(LAB.list) do
            if r.kind == "kill" or r.kind == "damage" or r.kind == "heal" or r.kind == "iframe" or r.kind == "cooldown" or r.kind == "hitbox" or n < 12 then
                CORE.log("REMOTE", r.kind .. " · " .. r.class .. " · " .. r.path)
                n += 1
                if n >= limit then break end
            end
        end
        return n
    end
    function LAB.policy()
        local FG = CORE.forge
        if FG and settings.voidOverride == true then
            return "Void Override armed · amplify/hitbox/parasite/cd/softgod/dominion · verified only"
        end
        return "Scout ready · arm Void Override for full remote domination suite"
    end
    task.defer(function() task.wait(2) pcall(LAB.scan) end)
end)

-- Void Override: hook FireServer/InvokeServer → learn, amplify damage args, replay / probe / oneshot (verified)
CORE.safeModule("14y Void Override", function()
    local LAB = CORE.remotes
    local OV = {
        hooked = false, why = "", learnedN = 0, workingN = 0, oneshotN = 0, fires = 0, amps = 0,
        verifies = 0, fails = 0, probes = 0, strips = 0, softs = 0, parasites = 0, dominions = 0,
        maps = 0, mirrors = 0, markets = 0, marketFails = 0, lastMirror = -100,
        last = "-", busy = false, entries = {},
    }
    CORE.forge = OV
    local hookmeta = exfn("hookmetamethod")
    local getncm = exfn("getnamecallmethod")
    local checkcaller = exfn("checkcaller")
    local newcc = exfn("newcclosure") or function(f) return f end
    local oldNamecall
    local OVR_FILE = "voidhub_ovr_" .. tostring(game.PlaceId) .. ".json"
    local DMG_KEYS = {
        damage = true, dmg = true, hurt = true, amount = true, power = true, hp = true, health = true,
        value = true, hit = true, force = true, strength = true, multiply = true, multiplier = true,
    }
    local HIT_KEYS = {
        hitbox = true, range = true, reach = true, size = true, radius = true, aoe = true,
        magnitude = true, width = true, height = true, depth = true, scale = true, distance = true,
    }
    local SKIP = {
        chat = true, say = true, message = true, whisper = true, channel = true,
        buy = true, purchase = true, shop = true, save = true, load = true, data = true, profile = true,
        settings = true, option = true, prompt = true,
    }
    local PRICE_KEYS = {
        price = true, cost = true, amount = true, cash = true, money = true, gem = true, gems = true,
        coin = true, coins = true, gold = true, beli = true, fee = true, value = true, paid = true,
        currency = true, robux = true, fragments = true, fragment = true,
    }
    -- Per-game remote name hints (matched by substring against scouted remotes). Args are seeded templates.
    local GAME_MAPS = {
        bloxfruits = {
            {kind = "damage", match = {"comm", "combat", "damage", "hit", "attack"}, args = {"template"}},
            {kind = "kill", match = {"kill", "destroy", "takeDamage"}, args = {"template"}},
            {kind = "heal", match = {"heal", "regen"}, args = {"template"}},
            {kind = "cooldown", match = {"cooldown", "cd"}, args = {"template"}},
        },
        universal = {
            {kind = "damage", match = {"damage", "dealDamage", "TakeDamage", "Combat", "Attack", "Hit"}, args = {"template"}},
            {kind = "kill", match = {"Kill", "OneShot", "Eliminate", "Execute"}, args = {"template"}},
            {kind = "heal", match = {"Heal", "Regen", "Restore"}, args = {"template"}},
            {kind = "iframe", match = {"IFrame", "Invuln", "Immunity", "NoDamage"}, args = {true}},
            {kind = "cooldown", match = {"Cooldown", "ResetCD", "ClearCD", "Refresh"}, args = {true}},
            {kind = "hitbox", match = {"Hitbox", "Range", "AoE"}, args = {"template"}},
            {kind = "replicate", match = {"Replicate", "Bridge", "Packet", "Comms"}, args = {"template"}},
        },
    }
    local function now() return os.clock() end
    local function low(s) return string.lower(tostring(s or "")) end
    local function canTry(name) return brain.canTry == nil or brain.canTry(name) end
    local function report(name, ok, label) if brain.report then brain.report(name, ok, label) end end
    local function premium() return HUB.tier == "premium" end
    local function armed()
        return alive and settings.voidOverride == true and settings.brainOn ~= false
    end
    local function offenseOk()
        return armed() and premium()
    end
    local function kindOf(remote)
        if LAB and LAB.index and LAB.index[remote] then return LAB.index[remote].kind end
        if LAB and LAB.kindOf then return LAB.kindOf(remote.Name) end
        return "other"
    end
    local function pathOf(r)
        local ok, p = pcall(function() return r:GetFullName() end)
        return ok and p or tostring(r)
    end
    local function shouldSkipName(name)
        local n = low(name)
        for w in pairs(SKIP) do
            if string.find(n, w, 1, true) then
                -- Shadow Market needs shop/buy remotes through the hook
                if settings.ovrMarket == true and (w == "buy" or w == "purchase" or w == "shop") then
                    return false
                end
                return true
            end
        end
        return false
    end
    local function currencySnap()
        local vals, total = {}, 0
        local function add(folder)
            if not folder then return end
            for _, c in ipairs(folder:GetChildren()) do
                if c:IsA("IntValue") or c:IsA("NumberValue") or c:IsA("StringValue") then
                    local n = tonumber(c.Value)
                    if n then vals[c:GetFullName()] = n total += n end
                end
            end
        end
        add(LP:FindFirstChild("leaderstats"))
        add(LP:FindFirstChild("Data"))
        add(LP:FindFirstChild("Stats"))
        add(LP:FindFirstChild("PlayerData"))
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            for _, c in ipairs(ls:GetDescendants()) do
                if c:IsA("IntValue") or c:IsA("NumberValue") then
                    local n = tonumber(c.Value)
                    if n and vals[c:GetFullName()] == nil then vals[c:GetFullName()] = n total += n end
                end
            end
        end
        return vals, total
    end
    local function cheapenValue(v, depth)
        depth = depth or 0
        if depth > 5 then return v, false end
        if type(v) == "table" then
            local out, any = {}, false
            for k, x in pairs(v) do
                local key = low(k)
                local nx, ch = x, false
                if PRICE_KEYS[key] then
                    if type(x) == "number" and x > 0 then nx, ch = 0, true
                    elseif type(x) == "table" then nx, ch = cheapenValue(x, depth + 1) end
                elseif type(x) == "table" then
                    nx, ch = cheapenValue(x, depth + 1)
                end
                out[k] = nx
                any = any or ch
            end
            return out, any
        end
        return v, false
    end
    local function cheapenPack(t)
        local out, any = {n = t.n}, false
        for i = 1, t.n do
            local nv, ch = cheapenValue(t[i], 0)
            -- bare trailing numeric arg that looks like a price: FireServer(itemId, price)
            if not ch and type(t[i]) == "number" and t[i] >= 2 and t[i] <= 1e9 and i >= 2 then
                nv, ch = 0, true
            end
            out[i] = nv
            any = any or ch
        end
        return out, any
    end
    local function killMarket(why)
        settings.ovrMarket = false
        saveSettings()
        if K.toggles.ovrMarket then pcall(K.toggles.ovrMarket.render, true) end
        toast("Shadow Market off · " .. tostring(why or "server rejected cheap buys"), "warn", 4)
        CORE.log("OVR", "Shadow Market disabled · " .. tostring(why))
    end

    -- shallow-clone args for storage / mutation (instances kept as refs)
    local function cloneVal(v, depth)
        depth = depth or 0
        if depth > 4 then return v end
        local t = typeof(v)
        if t == "table" then
            local out = {}
            for k, x in pairs(v) do out[cloneVal(k, depth + 1)] = cloneVal(x, depth + 1) end
            return out
        end
        return v
    end
    local function pack(...)
        local n = select("#", ...)
        local t = {n = n}
        for i = 1, n do t[i] = select(i, ...) end
        return t
    end
    local function unpackArgs(t)
        return table.unpack(t, 1, t.n or #t)
    end
    local function amplifyValue(v, mult, depth, hitMult)
        depth = depth or 0
        hitMult = hitMult or mult
        if depth > 5 then return v, false end
        local changed = false
        local ty = type(v)
        if ty == "number" then
            if v > 0 and v <= 1e6 then
                if v == 1 or v == 0 then return v, false end
                return v * mult, true
            end
            return v, false
        elseif ty == "table" then
            local out = {}
            for k, x in pairs(v) do
                local key = low(k)
                local nx, ch
                if DMG_KEYS[key] then
                    nx, ch = amplifyValue(x, mult, depth + 1, hitMult)
                    if not ch and type(x) == "number" and x >= 0 then nx, ch = x * mult, true end
                elseif settings.ovrHitbox == true and HIT_KEYS[key] then
                    nx, ch = amplifyValue(x, hitMult, depth + 1, hitMult)
                    if not ch and type(x) == "number" and x > 0 then nx, ch = x * hitMult, true end
                else
                    nx, ch = amplifyValue(x, mult, depth + 1, hitMult)
                end
                out[k] = nx
                changed = changed or ch
            end
            return out, changed
        end
        return v, false
    end
    local function amplifyPack(t, mult, hitMult)
        local any = false
        local out = {n = t.n}
        for i = 1, t.n do
            local nv, ch = amplifyValue(t[i], mult, 0, hitMult)
            out[i] = nv
            any = any or ch
        end
        return out, any
    end
    -- Packet Parasite: mutate replicate/bridge tables (damage/hitbox keys + common vector scales)
    local function parasitePack(t)
        local any = false
        local mult = math.clamp(tonumber(settings.ovrAmp) or 5, 1, 50)
        local hit = math.clamp(tonumber(settings.ovrHitboxAmp) or 3, 1, 20)
        local out = {n = t.n}
        for i = 1, t.n do
            local v = t[i]
            if type(v) == "table" then
                local nv, ch = amplifyValue(v, mult, 0, hit)
                out[i] = nv
                any = any or ch
            elseif type(v) == "number" and v > 1 and v < 1e5 then
                out[i] = v * mult
                any = true
            elseif typeof(v) == "Vector3" then
                out[i] = v * hit
                any = true
            else
                out[i] = v
            end
        end
        return out, any
    end

    -- retarget: swap Model/Humanoid/Player/BasePart that look like a character into the new target
    local function isCharLike(v)
        if typeof(v) == "Instance" then
            if v:IsA("Humanoid") or v:IsA("Player") then return true end
            if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then return true end
            if v:IsA("BasePart") then
                local m = v:FindFirstAncestorWhichIsA("Model")
                if m and m:FindFirstChildOfClass("Humanoid") then return true end
            end
        end
        return false
    end
    local function mapToTarget(v, model, hum, root)
        if not isCharLike(v) then return v end
        if typeof(v) == "Instance" then
            if v:IsA("Humanoid") then return hum or v end
            if v:IsA("Player") then
                local p = Players:GetPlayerFromCharacter(model)
                return p or v
            end
            if v:IsA("Model") then return model or v end
            if v:IsA("BasePart") then return root or v end
        end
        return v
    end
    local function retargetPack(t, model, hum, root)
        local out = {n = t.n}
        for i = 1, t.n do
            local v = t[i]
            if type(v) == "table" then
                local nt = {}
                for k, x in pairs(v) do nt[k] = mapToTarget(x, model, hum, root) end
                out[i] = nt
            else
                out[i] = mapToTarget(v, model, hum, root)
            end
        end
        return out
    end

    local function entryFor(remote)
        local e = OV.entries[remote]
        if e then return e end
        e = {
            remote = remote, name = remote.Name, path = pathOf(remote), kind = kindOf(remote),
            args = nil, fires = 0, verified = 0, fails = 0, oneshot = false, broken = false,
            score = 0, last = -100, lastDrop = 0,
        }
        OV.entries[remote] = e
        OV.learnedN += 1
        return e
    end
    local function recount()
        local w, o = 0, 0
        for _, e in pairs(OV.entries) do
            if not e.broken and e.verified > 0 then w += 1 end
            if e.oneshot and not e.broken then o += 1 end
        end
        OV.workingN, OV.oneshotN = w, o
    end
    local function persist()
        local snap = {}
        for _, e in pairs(OV.entries) do
            if e.verified > 0 or e.oneshot then
                snap[#snap + 1] = {path = e.path, name = e.name, kind = e.kind, verified = e.verified, oneshot = e.oneshot, score = e.score}
            end
        end
        save(OVR_FILE, jsonEncode(snap))
    end
    local function markBroken(e, why)
        e.broken = true
        e.fails += 1
        OV.fails += 1
        OV.why = why or "rejected"
        report("ovr_" .. e.name, false, "Void Override · " .. e.name)
        CORE.log("OVR", "broken · " .. e.name .. " · " .. tostring(why))
        recount()
    end
    local function markVerified(e, drop, killed)
        e.verified += 1
        e.fails = 0
        e.score += (killed and 5 or 1) + math.min(10, math.floor((drop or 0) / 10))
        e.lastDrop = drop or 0
        if killed then e.oneshot = true end
        OV.verifies += 1
        report("ovr_" .. e.name, true, "Void Override · " .. e.name)
        CORE.log("OVR", "verified · " .. e.name .. " · drop " .. math.floor(drop or 0) .. (killed and " · ONESHOT" or ""))
        recount()
        if e.verified == 1 or killed then persist() end
        if killed and VFX.moment then pcall(VFX.moment, "BOSS", e.name) end
    end

    local function fireRemote(remote, argsPack)
        if not remote or not remote.Parent then return false end
        OV.busy = true
        local ok
        if remote:IsA("RemoteFunction") then
            ok = pcall(function() remote:InvokeServer(unpackArgs(argsPack)) end)
        else
            ok = pcall(function() remote:FireServer(unpackArgs(argsPack)) end)
        end
        OV.busy = false
        OV.fires += 1
        return ok
    end

    local function watchVerify(e, hum, before, expectKill)
        task.delay(0.55, function()
            if not hum or not hum.Parent then
                -- target gone → count as success if we expected a kill-ish effect
                if expectKill or before > 0 then markVerified(e, before, true) end
                return
            end
            local after = hum.Health
            local drop = before - after
            if after <= 0 or (expectKill and after < before * 0.05) then
                markVerified(e, drop, true)
            elseif drop >= 1 then
                markVerified(e, drop, false)
            else
                e.fails += 1
                OV.fails += 1
                if e.fails >= 3 and e.verified == 0 then markBroken(e, "no HP drop") end
            end
        end)
    end

    local function learnCall(remote, method, argsPack)
        if settings.ovrLearn == false then return end
        if shouldSkipName(remote.Name) then return end
        local e = entryFor(remote)
        e.kind = kindOf(remote)
        e.fires += 1
        e.last = now()
        e.method = method
        -- keep latest non-empty args sample
        if argsPack.n > 0 then e.args = cloneVal(argsPack) end
        OV.last = e.name
        if e.fires == 1 then
            CORE.log("OVR", "learned · " .. e.kind .. " · " .. e.name .. " · " .. method)
            if e.kind == "damage" or e.kind == "kill" or e.kind == "heal" then
                toast("Void Override · learned " .. e.name, "shield", 2)
            end
        end
    end

    -- pick hostile NPC (or optional PvP marked enemy). Prefer Combat Aim lock, then AG/SEN/BF.
    local function pickTarget(range)
        range = range or tonumber(settings.ovrRange) or 50
        local me = hrp()
        if not me then return nil end
        if CORE.aim and CORE.aim.getTarget then
            local m, h, r = CORE.aim.getTarget()
            if m and h and r and (r.Position - me.Position).Magnitude <= range then return m, h, r end
        end
        local function fromInfo(info)
            if not info then return nil end
            local model = info.model
            local h = info.hum or (model and model:FindFirstChildOfClass("Humanoid"))
            local r = info.root or (model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart))
            if not (model and h and r and h.Health > 0 and r.Parent) then return nil end
            if (r.Position - me.Position).Magnitude > range then return nil end
            if info.player or info.kind == "player" then
                if settings.ovrPvp ~= true then return nil end
                local plr = info.player or Players:GetPlayerFromCharacter(model)
                if plr and guardian.staff[plr.UserId] then return nil end
            end
            return model, h, r
        end
        local AG, SEN = CORE.aggro, CORE.sense
        local m, h, r = fromInfo(AG and AG.target)
        if m then return m, h, r end
        m, h, r = fromInfo(SEN and SEN.top)
        if m then return m, h, r end
        if CORE.bfkit and CORE.bfkit.target then
            m, h, r = fromInfo(CORE.bfkit.target)
            if m then return m, h, r end
        end
        if SEN and type(SEN.list) == "table" then
            local best, bh, br, bd = nil, nil, nil, range
            for _, info in ipairs(SEN.list) do
                if info.hostile then
                    local mm, hh, rr = fromInfo(info)
                    if mm then
                        local d = (rr.Position - me.Position).Magnitude
                        if d < bd then best, bh, br, bd = mm, hh, rr, d end
                    end
                end
            end
            if best then return best, bh, br end
        end
        -- fallback: nearest non-player humanoid in range
        local best, bh, br, bd = nil, nil, nil, range
        for _, d in ipairs(workspace:GetChildren()) do
            if d:IsA("Model") and d ~= char() and not Players:GetPlayerFromCharacter(d) then
                local hh = d:FindFirstChildOfClass("Humanoid")
                local rr = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
                if hh and hh.Health > 0 and rr then
                    local dist = (rr.Position - me.Position).Magnitude
                    if dist < bd then best, bh, br, bd = d, hh, rr, dist end
                end
            end
        end
        return best, bh, br
    end

    local function bestEntry(preferOneShot)
        local best, score = nil, -1
        for _, e in pairs(OV.entries) do
            if not e.broken and e.args and e.remote and e.remote.Parent then
                local k = e.kind
                if k == "kill" or k == "damage" or (e.verified > 0) or e.oneshot then
                    local s = e.score + e.verified * 2 + (e.oneshot and 20 or 0) - e.fails
                    if preferOneShot and e.oneshot then s += 50 end
                    if k == "kill" then s += 8 elseif k == "damage" then s += 4 end
                    if s > score then best, score = e, s end
                end
            end
        end
        return best
    end

    function OV.strike(forceOneShot)
        if not offenseOk() then
            OV.why = (not premium()) and "Premium Boss mode" or "Override off"
            return false
        end
        if not canTry("void_override") then OV.why = "brain blocked" return false end
        local model, hum, root = pickTarget()
        if not (model and hum and root) then OV.why = "no target" return false end
        local e = bestEntry(forceOneShot or settings.ovrOneShot == true)
        if not e then OV.why = "no learned combat remote yet · fight once" return false end
        local args = retargetPack(cloneVal(e.args), model, hum, root)
        if settings.ovrAmplify == true then
            local mult = math.clamp(tonumber(settings.ovrAmp) or 5, 1, 100)
            if forceOneShot or settings.ovrOneShot == true then mult = math.max(mult, 25) end
            local amp, any = amplifyPack(args, mult)
            args = amp
            if any then OV.amps += 1 end
        end
        local before = hum.Health
        local ok = fireRemote(e.remote, args)
        if not ok then markBroken(e, "fire failed") return false end
        watchVerify(e, hum, before, e.oneshot or e.kind == "kill" or forceOneShot)
        OV.last = e.name
        OV.why = ""
        return true
    end

    function OV.probeOnce()
        if not offenseOk() or settings.ovrProbe ~= true then return false end
        if not LAB then return false end
        if LAB.n == 0 then pcall(LAB.scan) end
        local model, hum, root = pickTarget()
        if not (model and hum and root) then OV.why = "no NPC to probe" return false end
        -- pick unscanned kill/damage remote from scout list
        for _, info in ipairs(LAB.list or {}) do
            if (info.kind == "kill" or info.kind == "damage") and info.ref and info.ref.Parent then
                local e = entryFor(info.ref)
                if not e.broken and e.verified == 0 and e.fails < 2 then
                    -- invent a small arg pack targeting the NPC
                    local packs = {
                        pack(model), pack(hum), pack(root), pack(model, 9999), pack(hum, 9999),
                        pack({Target = model, Damage = 9999}), pack({target = hum, damage = 9999}),
                        pack(Players.LocalPlayer, model, 9999),
                    }
                    local before = hum.Health
                    OV.probes += 1
                    for _, ap in ipairs(packs) do
                        e.args = cloneVal(ap)
                        if fireRemote(info.ref, ap) then
                            watchVerify(e, hum, before, info.kind == "kill")
                            OV.last = "probe:" .. info.name
                            CORE.log("OVR", "probe · " .. info.name)
                            return true
                        end
                    end
                    e.fails += 1
                end
            end
        end
        OV.why = "no probe candidates"
        return false
    end

    local function fireKind(kind, verifyFn)
        for _, e in pairs(OV.entries) do
            if e.kind == kind and not e.broken and e.remote and e.remote.Parent then
                local args = e.args and cloneVal(e.args) or pack(true)
                if settings.ovrAmplify == true then
                    args = amplifyPack(args, math.clamp(tonumber(settings.ovrAmp) or 5, 1, 50), math.clamp(tonumber(settings.ovrHitboxAmp) or 3, 1, 20))
                end
                if fireRemote(e.remote, args) then
                    if verifyFn then verifyFn(e) end
                    OV.last = kind .. ":" .. e.name
                    return true, e
                end
            end
        end
        -- also try scouted remotes of that kind once
        if LAB then
            for _, info in ipairs(LAB.list or {}) do
                if info.kind == kind and info.ref and info.ref.Parent then
                    local e = entryFor(info.ref)
                    if not e.broken then
                        local args = e.args or pack(true)
                        e.args = args
                        if fireRemote(info.ref, args) then
                            if verifyFn then verifyFn(e) end
                            OV.last = kind .. ":" .. info.name
                            return true, e
                        end
                    end
                end
            end
        end
        return false
    end

    function OV.healSelf()
        if not armed() or (settings.ovrHeal ~= true and settings.ovrSoftGod ~= true) then return false end
        local h = hum()
        if not h or h.Health >= h.MaxHealth - 1 then return false end
        local before = h.Health
        return fireKind("heal", function(e)
            task.delay(0.6, function()
                local hh = hum()
                if hh and hh.Health > before + 1 then
                    markVerified(e, hh.Health - before, false)
                    OV.gods += 1
                else
                    e.fails += 1
                    if e.fails >= 3 then markBroken(e, "heal rejected") end
                end
            end)
        end)
    end

    function OV.softGod()
        if not armed() or settings.ovrSoftGod ~= true then return false end
        local h = hum()
        if not h then return false end
        local hp = h.Health / math.max(h.MaxHealth, 1)
        if hp > 0.55 and settings.ovrHeal ~= true then return false end
        local did = false
        if hp < 0.7 then did = OV.healSelf() or did end
        -- i-frame / immunity remotes (verified by "no HP drop for 0.8s while hostile close")
        local ok = fireKind("iframe", function(e)
            local before = h.Health
            local near = pickTarget(18)
            task.delay(0.85, function()
                local hh = hum()
                if not hh then return end
                if near and hh.Health >= before - 0.5 then
                    markVerified(e, 0, false)
                    OV.gods += 1
                    if VFX.moment then pcall(VFX.moment, "SAFE", "IFRAME") end
                elseif not near and hh.Health >= before - 0.5 then
                    -- no pressure: soft credit
                    e.score += 0.2
                else
                    e.fails += 1
                    if e.fails >= 3 then markBroken(e, "iframe rejected") end
                end
            end)
        end)
        return did or ok
    end

    function OV.cdStrip()
        if not armed() or settings.ovrCdStrip ~= true then return false end
        local ok = fireKind("cooldown", function(e)
            -- verify: if ABI has a ready skill sooner / tool activate works again — soft verify via score
            e.score += 0.5
            e.verified = math.max(e.verified, 1)
            OV.strips += 1
            recount()
        end)
        if ok then toast("Void Override · cooldown strip", "shield", 1.5) end
        return ok
    end

    function OV.applyMaps()
        if settings.ovrMaps ~= true or not LAB then return 0 end
        if LAB.n == 0 then pcall(LAB.scan) end
        local mod = GAMEINFO and GAMEINFO.module and GAMEINFO.module.title
        local packs = {}
        if mod == "Blox Fruits" then
            for _, row in ipairs(GAME_MAPS.bloxfruits) do packs[#packs + 1] = row end
        end
        for _, row in ipairs(GAME_MAPS.universal) do packs[#packs + 1] = row end
        local n = 0
        for _, info in ipairs(LAB.list or {}) do
            for _, row in ipairs(packs) do
                if info.kind == row.kind or info.kind == "other" then
                    local hit = false
                    for _, m in ipairs(row.match) do
                        if string.find(info.name, m, 1, true) or string.find(info.path, m, 1, true) then hit = true break end
                    end
                    if hit and info.ref then
                        local e = entryFor(info.ref)
                        e.kind = row.kind
                        if not e.args then
                            -- seed target-shaped templates for combat kinds
                            if row.kind == "damage" or row.kind == "kill" then
                                e.args = pack({Damage = 9999, Target = true})
                            elseif row.kind == "heal" or row.kind == "iframe" or row.kind == "cooldown" then
                                e.args = pack(true)
                            else
                                e.args = pack({})
                            end
                        end
                        e.mapped = true
                        n += 1
                        break
                    end
                end
            end
        end
        OV.maps = n
        CORE.log("OVR", "game maps seeded · " .. n .. " remotes (" .. tostring(mod or "universal") .. ")")
        return n
    end

    function OV.dominion()
        if not offenseOk() or settings.ovrDominion ~= true then
            OV.why = (not premium()) and "Premium" or "Dominion off"
            return false
        end
        if countKeys(guardian.staff) > 0 then OV.why = "staff" return false end
        -- Siphon nearby props, fling toward target, then Override strike
        if CORE.net then
            if settings.voidSiphon == true and CORE.net.siphon then pcall(CORE.net.siphon) end
            if settings.voidNet == true then
                if CORE.net.bring then pcall(CORE.net.bring) end
                task.defer(function()
                    if CORE.net.throw then pcall(CORE.net.throw) end
                end)
            end
        end
        local ok = OV.strike(settings.ovrOneShot == true)
        if ok then
            OV.dominions += 1
            if VFX.moment then pcall(VFX.moment, "BOSS", "DOMINION") end
            if VFX.ring then local r = hrp() if r then pcall(VFX.ring, r.Position, C.gold, 18) end end
        end
        return ok
    end

    -- Mirror Ward: when YOU take damage, fire verified damage remotes back at the attacker
    function OV.mirror(who, amount)
        if not armed() or settings.ovrMirror ~= true then return false end
        if not canTry("ovr_mirror") then return false end
        local t = now()
        if t - OV.lastMirror < 0.35 then return false end
        local info = who
        if not info then
            local SEN = CORE.sense
            info = SEN and SEN.lastHitWho
        end
        if not info or not info.model or not info.hum or not info.root then return false end
        if info.hum.Health <= 0 then return false end
        if (info.player or info.kind == "player") and settings.ovrPvp ~= true then return false end
        OV.lastMirror = t
        local e = bestEntry(settings.ovrOneShot == true)
        if not e then
            OV.why = "mirror: no combat remote yet"
            return false
        end
        local args = retargetPack(cloneVal(e.args), info.model, info.hum, info.root)
        if settings.ovrAmplify == true then
            local mult = math.clamp(tonumber(settings.ovrAmp) or 5, 1, 100)
            if settings.ovrOneShot == true then mult = math.max(mult, 25) end
            -- scale mirror by how hard they hit you
            local scale = 1 + math.clamp((tonumber(amount) or 0) / 50, 0, 2)
            args = amplifyPack(args, mult * scale, math.clamp(tonumber(settings.ovrHitboxAmp) or 3, 1, 20))
        end
        local before = info.hum.Health
        if not fireRemote(e.remote, args) then return false end
        watchVerify(e, info.hum, before, e.oneshot or e.kind == "kill")
        OV.mirrors += 1
        OV.last = "mirror:" .. e.name
        if VFX.moment then pcall(VFX.moment, "SAFE", "MIRROR") end
        report("ovr_mirror", true, "Mirror Ward · " .. e.name)
        return true
    end

    -- Shadow Market verify after a cheapened shop fire (currency must not drop full price / or item lands free)
    function OV.noteMarket(e, beforeTotal, beforeVals)
        task.delay(1.1, function()
            local _, afterTotal = currencySnap()
            local drop = (beforeTotal or 0) - (afterTotal or 0)
            -- Success cases: almost no currency lost (free/cheap buy stuck) OR remote returned without charge
            if drop <= 1 then
                e.verified = (e.verified or 0) + 1
                e.score = (e.score or 0) + 3
                OV.markets += 1
                OV.marketFails = 0
                markVerified(e, 0, false)
                CORE.log("OVR", "Shadow Market verified · " .. e.name .. " · currency drop " .. tostring(drop))
                if VFX.moment then pcall(VFX.moment, "LEARNED", "MARKET") end
                toast("Shadow Market · cheap buy held", "shield", 2)
            else
                -- Server charged full / ignored our 0 — count failure
                e.fails = (e.fails or 0) + 1
                OV.marketFails += 1
                OV.fails += 1
                CORE.log("OVR", "Shadow Market rejected · " .. e.name .. " · charged ~" .. math.floor(drop))
                if OV.marketFails >= 3 or (e.fails >= 3 and e.verified == 0) then
                    killMarket("this game ignores client prices")
                end
            end
        end)
    end

    function OV.status()
        if settings.voidOverride ~= true then return "off" end
        if not OV.hooked then return "no hookmetamethod · probe/maps still work" end
        local bits = {OV.learnedN .. " learned", OV.workingN .. " verified", OV.oneshotN .. " oneshot"}
        if OV.maps > 0 then bits[#bits + 1] = OV.maps .. " mapped" end
        if OV.mirrors > 0 then bits[#bits + 1] = OV.mirrors .. " mirror" end
        if OV.markets > 0 then bits[#bits + 1] = OV.markets .. " market" end
        if OV.why ~= "" then bits[#bits + 1] = OV.why end
        if OV.last ~= "-" then bits[#bits + 1] = OV.last end
        return table.concat(bits, " · ")
    end
    function OV.summary()
        return OV.fires .. " fires · " .. OV.amps .. " amps · " .. OV.parasites .. " parasite · " .. OV.strips .. " cd · "
            .. OV.gods .. " softgod · " .. OV.dominions .. " dominion · " .. OV.mirrors .. " mirror · "
            .. OV.markets .. " market · " .. OV.verifies .. " ok · " .. OV.fails .. " fail"
    end
    function OV.clear()
        OV.entries = {}
        OV.learnedN, OV.workingN, OV.oneshotN, OV.maps = 0, 0, 0, 0
        save(OVR_FILE, "[]")
        toast("Void Override · memory cleared", "info", 2)
    end

    -- install namecall hook
    local function installHook()
        if OV.hooked or not hookmeta or not getncm then
            if not hookmeta then OV.why = "executor missing hookmetamethod" end
            return
        end
        local ok, err = pcall(function()
            oldNamecall = hookmeta(game, "__namecall", newcc(function(self, ...)
                local method = getncm()
                local args = pack(...)
                if not OV.busy and armed() and typeof(self) == "Instance"
                    and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent"))
                    and (method == "FireServer" or method == "InvokeServer") then
                    -- Learn game/tool traffic. Replays set OV.busy so they are not re-learned as originals.
                    if settings.ovrLearn ~= false then
                        pcall(learnCall, self, method, args)
                    end
                    local k = kindOf(self)
                    -- Shadow Market: cheapen shop/buy remotes, verify via currency (auto-off if rejected)
                    if settings.ovrMarket == true and (k == "shop" or string.find(low(self.Name), "buy", 1, true) or string.find(low(self.Name), "purchase", 1, true) or string.find(low(self.Name), "shop", 1, true)) then
                        local cheap, ch = cheapenPack(args)
                        if ch then
                            local e = entryFor(self)
                            e.kind = "shop"
                            e.args = cloneVal(cheap)
                            local _, beforeTotal = currencySnap()
                            args = cheap
                            OV.last = "market:" .. self.Name
                            if oldNamecall then
                                local results = table.pack(oldNamecall(self, unpackArgs(args)))
                                OV.noteMarket(e, beforeTotal)
                                return table.unpack(results, 1, results.n)
                            end
                        end
                    end
                    if not shouldSkipName(self.Name) then
                        local mult = math.clamp(tonumber(settings.ovrAmp) or 5, 1, 100)
                        local hitMult = math.clamp(tonumber(settings.ovrHitboxAmp) or 3, 1, 20)
                        if settings.ovrOneShot == true and (k == "damage" or k == "kill") then mult = math.max(mult, 25) end
                        local mutated, any = false, false
                        if settings.ovrParasite == true and (k == "replicate" or k == "other") then
                            local amp, ch = parasitePack(args)
                            if ch then args, any, mutated = amp, true, true OV.parasites += 1 end
                        end
                        if settings.ovrAmplify == true or settings.ovrHitbox == true then
                            local amp, ch = amplifyPack(args, settings.ovrAmplify == true and mult or 1, settings.ovrHitbox == true and hitMult or 1)
                            if ch then args, any, mutated = amp, true, true OV.amps += 1 end
                        end
                        if mutated and any then
                            local _, thum = pickTarget(30)
                            if thum and (k == "damage" or k == "kill" or k == "hitbox" or k == "other" or k == "replicate") then
                                local e = entryFor(self)
                                e.args = cloneVal(args)
                                watchVerify(e, thum, thum.Health, k == "kill" or settings.ovrOneShot == true)
                            end
                            if oldNamecall then return oldNamecall(self, unpackArgs(args)) end
                        end
                    end
                end
                if oldNamecall then return oldNamecall(self, ...) end
                return nil
            end))
        end)
        if ok then
            OV.hooked = true
            CORE.log("BOOT", "Void Override hooked · amplify/learn online")
        else
            OV.why = "hook failed: " .. tostring(err)
            CORE.log("ERR", "Void Override hook: " .. tostring(err))
        end
    end
    -- NEVER install namecall at module load — hard-closes some clients. Lazy on toggle.
    function OV.ensureHook()
        if settings.voidOverride == true then installHook() end
    end

    -- restore previously verified paths after scout + seed game maps
    task.defer(function()
        task.wait(2.5)
        if LAB and LAB.scan then pcall(LAB.scan) end
        local raw = loadFile(OVR_FILE)
        local data = raw and jsonDecode(raw)
        if type(data) == "table" and LAB then
            for _, snap in ipairs(data) do
                for _, info in ipairs(LAB.list or {}) do
                    if info.path == snap.path and info.ref then
                        local e = entryFor(info.ref)
                        e.verified = math.max(e.verified, tonumber(snap.verified) or 0)
                        e.oneshot = e.oneshot or snap.oneshot == true
                        e.score = math.max(e.score, tonumber(snap.score) or 0)
                        e.kind = snap.kind or e.kind
                    end
                end
            end
            recount()
        end
        pcall(OV.applyMaps)
    end)

    local acc, healAcc, probeAcc, cdAcc, domAcc = 0, 0, 0, 0, 0
    onHeartbeat("voidovr14y", function(dt)
        if not armed() then return end
        acc += dt healAcc += dt probeAcc += dt cdAcc += dt domAcc += dt
        local rate = math.clamp(tonumber(settings.ovrRate) or 4, 1, 12)
        local gap = 1 / rate
        if countKeys(guardian.staff) > 0 then OV.why = "staff" return end
        if settings.ovrDominion == true and offenseOk() and domAcc >= math.max(gap * 2, 0.45) then
            domAcc = 0
            pcall(OV.dominion)
        elseif settings.ovrReplay == true and offenseOk() and acc >= gap then
            acc = 0
            pcall(OV.strike, settings.ovrOneShot == true)
        end
        if settings.ovrProbe == true and offenseOk() and probeAcc > 2.5 then
            probeAcc = 0
            pcall(OV.probeOnce)
        end
        if (settings.ovrHeal == true or settings.ovrSoftGod == true) and healAcc > 1.0 then
            healAcc = 0
            if settings.ovrSoftGod == true then pcall(OV.softGod) else pcall(OV.healSelf) end
        end
        if settings.ovrCdStrip == true and cdAcc > 3.5 then
            cdAcc = 0
            pcall(OV.cdStrip)
        end
    end)
    onUnload(function() OV.busy = true end)
end)

-- Combat Aim: body + camera + silent Mouse.Hit lock on nearest enemy (Blox Fruits Enemies / Sense)
-- Optional: pull client-owned mobs onto your blade (Void Needle) so skills actually connect.
-- Crash-hardened: every lookAt/hook/scan is pcall'd; attack spam is debounced; Enemies scan cached.
CORE.safeModule("14z Combat Aim", function()
    local AIM = {
        target = nil, root = nil, hum = nil, model = nil, part = nil,
        why = "", locks = 0, pulls = 0, spoof = false,
    }
    CORE.aim = AIM
    local mouse = LP:GetMouse()
    local hookmeta = exfn("hookmetamethod")
    local newcc = exfn("newcclosure") or function(f) return f end
    local netOwnerFn = exfn("isnetworkowner")
    local oldIndex
    local function now() return os.clock() end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    -- CFrame.lookAt with identical/near points can hard-crash Roblox (esp. mobile) — never call raw
    local function safeLookAt(from, look, up)
        if typeof(from) ~= "Vector3" or typeof(look) ~= "Vector3" then return nil end
        local d = look - from
        if d.Magnitude < 1e-3 then return CFrame.new(from) end
        local ok, cf = pcall(function()
            if up then return CFrame.lookAt(from, look, up) end
            return CFrame.lookAt(from, look)
        end)
        return ok and cf or CFrame.new(from)
    end
    local function armed()
        return alive and settings.combatAim == true and settings.brainOn ~= false
    end
    -- Only trust real network-owner API. ReceiveAge==0 false-positives crashed BF by yanking server NPCs.
    local function clientOwns(part)
        if not part or part.Anchored then return false end
        if not netOwnerFn then return false end
        local ok, v = pcall(netOwnerFn, part)
        return ok and v == true
    end
    local function aimPoint(root)
        if not root then return nil end
        local ok, pos = pcall(function() return root.Position + Vector3.new(0, 1.2, 0) end)
        if not ok or not pos then return nil end
        local okV, vel = pcall(function() return root.AssemblyLinearVelocity end)
        if okV and typeof(vel) == "Vector3" and vel.Magnitude > 4 then
            pos = pos + Vector3.new(vel.X, math.clamp(vel.Y, -8, 8), vel.Z) * 0.12
        end
        return pos
    end
    local function withinFov(pos, strict)
        if not strict then return true end
        local cam = workspace.CurrentCamera
        if not cam then return true end
        local fov = math.clamp(tonumber(settings.aimFov) or 180, 20, 180)
        if fov >= 179 then return true end
        local ok, ang = pcall(function()
            local to = pos - cam.CFrame.Position
            if to.Magnitude < 1 then return 0 end
            return math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(to.Unit), -1, 1)))
        end)
        return ok and ang <= fov * 0.5
    end

    -- Cache pick results so M1 + Tool.Activated + sticky loop don't re-scan 200+ Enemies every tick
    local pickCache, pickCacheT, pickCacheStrict = nil, -1, nil
    local function pickEnemy(strictFov)
        strictFov = strictFov == true
        local t = now()
        if pickCache and pickCacheStrict == strictFov and t - pickCacheT < 0.08 then
            local m, h, r = pickCache[1], pickCache[2], pickCache[3]
            if r and r.Parent and h and h.Parent and h.Health > 0 then return m, h, r end
        end
        local me = hrp()
        if not me then return nil end
        local range = math.clamp(tonumber(settings.aimRange) or 80, 10, 150)
        local best, br, bh, bm, bd, bestPlr = nil, nil, nil, nil, range + 1, false
        local function consider(model, humObj, root, isPlr)
            if not (model and humObj and root) then return end
            local ok = pcall(function()
                if not root.Parent or humObj.Health <= 0 then return end
                if model == char() then return end
                if isPlr then
                    if settings.aimPlayers ~= true then return end
                    local plr = Players:GetPlayerFromCharacter(model)
                    if plr and guardian.staff and guardian.staff[plr.UserId] then return end
                end
                local d = (root.Position - me.Position).Magnitude
                if d > range then return end
                if not withinFov(root.Position, strictFov) then return end
                if isPlr then
                    if not bestPlr or d < bd then
                        best, br, bh, bm, bd, bestPlr = root, root, humObj, model, d, true
                    end
                    return
                end
                if bestPlr then return end
                if d < bd then best, br, bh, bm, bd = root, root, humObj, model, d end
            end)
            if not ok then return end
        end
        if settings.aimPlayers == true then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local h = p.Character:FindFirstChildOfClass("Humanoid")
                    local r = p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart
                    consider(p.Character, h, r, true)
                end
            end
        end
        -- Prefer Sense / Aggro / BF kit targets first (cheap), then a capped Enemies scan
        local SEN = CORE.sense
        if SEN and type(SEN.list) == "table" then
            for _, info in ipairs(SEN.list) do
                consider(info.model, info.hum, info.root, info.player ~= nil or info.kind == "player")
            end
        end
        local AG = CORE.aggro
        if AG and AG.target then
            consider(AG.target.model, AG.target.hum, AG.target.root, AG.target.kind == "player")
        end
        local BK = CORE.bfkit
        if BK and BK.target then
            consider(BK.target.model, BK.target.hum, BK.target.root, false)
        end
        -- Cap Enemies scan: only check children until we have a close hit or N models
        local ef = workspace:FindFirstChild("Enemies")
        if ef and not bestPlr then
            local n, cap = 0, 60
            for _, m in ipairs(ef:GetChildren()) do
                if n >= cap then break end
                if m:IsA("Model") then
                    n += 1
                    local h = m:FindFirstChildOfClass("Humanoid")
                    local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    consider(m, h, r, false)
                    if best and bd < 12 then break end -- already locked a close NPC
                end
            end
        end
        pickCache = {bm, bh, br}
        pickCacheT, pickCacheStrict = t, strictFov
        if not best then return nil end
        return bm, bh, br
    end

    local function faceBody(pos, hard)
        if settings.aimBody ~= true or not pos then return end
        local r = hrp()
        if not r then return end
        pcall(function()
            local d = flat(pos - r.Position)
            if d.Magnitude < 0.15 then return end
            local cf = safeLookAt(r.Position, r.Position + d.Unit)
            if cf then r.CFrame = cf end
            if hard then
                local v = r.AssemblyLinearVelocity
                r.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
            end
        end)
    end
    local function faceCam(pos, hard)
        if settings.aimCam ~= true or not pos then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        pcall(function()
            local from = cam.CFrame.Position
            local goal = safeLookAt(from, pos)
            if not goal then return end
            -- hard snap once is enough; spam hard snaps fight CameraModule and crash mobile
            if hard then cam.CFrame = goal
            else cam.CFrame = cam.CFrame:Lerp(goal, 0.55) end
        end)
    end

    local needlePart
    local lastNeedleT = 0
    local function voidNeedle(me, root, humObj)
        if settings.aimMove ~= true then return end
        if not (me and root and humObj) then return end
        local okAlive = pcall(function() return humObj.Health > 0 and root.Parent end)
        if not okAlive then return end
        local owned = clientOwns(root)
        pcall(function()
            local slot = me.Position + me.CFrame.LookVector * 4.2 + Vector3.new(0, 0.2, 0)
            if owned then
                local cf = safeLookAt(slot, me.Position)
                root.AssemblyLinearVelocity = Vector3.zero
                if cf then root.CFrame = cf end
                AIM.pulls += 1
                if CORE.claimSim then pcall(CORE.claimSim) end
            else
                -- step YOU closer — never yank server-owned NPCs (that crashed the app)
                local dist = (root.Position - me.Position).Magnitude
                local range = tonumber(settings.aimRange) or 80
                if dist > 7 and dist < range then
                    local to = flat(root.Position - me.Position)
                    if to.Magnitude > 0.2 then
                        local step = me.Position + to.Unit * math.min(2.8, dist - 4.5)
                        local look = Vector3.new(root.Position.X, step.Y, root.Position.Z)
                        local cf = safeLookAt(step, look)
                        if cf then
                            me.CFrame = cf
                            me.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end
            end
        end)
        -- visual needle throttled + fully pcall'd (lookAt on zero-length crashed before)
        if settings.vfx == false or PERF.lite then return end
        if now() - lastNeedleT < 0.05 then return end
        lastNeedleT = now()
        pcall(function()
            if not needlePart or not needlePart.Parent then
                needlePart = own(new("Part", {
                    Name = "SecretAimNeedle", Anchored = true, CanCollide = false, CanQuery = false,
                    Material = Enum.Material.Neon, Color = C.gold or Color3.fromRGB(240, 240, 245),
                    Size = Vector3.new(0.12, 0.12, 1), Transparency = 0.25,
                }))
                pcall(function() needlePart:SetAttribute("SecretHub", true) end)
                needlePart.Parent = workspace
            end
            local b = aimPoint(root)
            if not b then return end
            local a = me.Position + Vector3.new(0, 1, 0)
            local mid = (a + b) * 0.5
            local len = (a - b).Magnitude
            if len < 0.2 then return end
            needlePart.Size = Vector3.new(0.1, 0.1, len)
            local cf = safeLookAt(mid, b)
            if cf then needlePart.CFrame = cf end
            needlePart.Transparency = 0.2
        end)
    end

    function AIM.lock(force, strictFov)
        if not armed() and not force then
            AIM.target, AIM.root, AIM.hum, AIM.model, AIM.part = nil, nil, nil, nil, nil
            AIM.why = "off"
            return nil
        end
        local ok, model, humObj, root = pcall(function()
            local m, h, r = pickEnemy(strictFov == true)
            return m, h, r
        end)
        if not ok then
            AIM.why = "scan error"
            return AIM.root and AIM.root.Parent and AIM.root or nil
        end
        if not root then
            if not settings.aimStick or not AIM.root or not AIM.root.Parent then
                AIM.target, AIM.root, AIM.hum, AIM.model, AIM.part = nil, nil, nil, nil, nil
                AIM.why = (settings.aimPlayers == true) and "no player/NPC in range" or "no NPC in range · enable Aim at players for PvP"
            end
            return AIM.root and AIM.root.Parent and AIM.root or nil
        end
        AIM.model, AIM.hum, AIM.root, AIM.part = model, humObj, root, root
        AIM.target = aimPoint(root)
        AIM.why = ""
        AIM.locks += 1
        return root
    end
    function AIM.apply(hard)
        local ok, res = pcall(function()
            local root = AIM.lock(false, not hard)
            if not root or not root.Parent then return false end
            local me = hrp()
            local pos = aimPoint(root)
            if not pos then return false end
            faceBody(pos, hard)
            faceCam(pos, hard)
            if me then voidNeedle(me, root, AIM.hum) end
            return true
        end)
        return ok and res == true
    end
    function AIM.status()
        if settings.combatAim ~= true then return "off" end
        if AIM.root and AIM.root.Parent then
            local n = AIM.model and AIM.model.Name or "?"
            return "lock · " .. n .. " · " .. AIM.locks .. " locks · " .. AIM.pulls .. " pulls"
        end
        return AIM.why ~= "" and AIM.why or "scanning…"
    end

    -- Silent aim: hook Mouse only — NEVER game.__index (that hard-closed Roblox on boot).
    local function installSilent()
        if AIM.spoof or not hookmeta then return end
        if settings.combatAim ~= true or settings.aimSilent ~= true then return end
        local ok = pcall(function()
            oldIndex = hookmeta(mouse, "__index", newcc(function(self, key)
                local okH, hit = pcall(function()
                    if not (armed() and settings.aimSilent == true) then return nil end
                    local root = AIM.root
                    if not (root and root.Parent) then return nil end
                    if key == "Hit" then
                        local p = aimPoint(root)
                        return p and CFrame.new(p) or nil
                    end
                    if key == "Target" then return AIM.part or root end
                    if key == "UnitRay" then
                        local cam = workspace.CurrentCamera
                        local origin = (cam and cam.CFrame.Position) or (hrp() and hrp().Position) or root.Position
                        local p = aimPoint(root)
                        if not p then return nil end
                        local dir = p - origin
                        if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 0, -1) else dir = dir.Unit * dir.Magnitude end
                        return Ray.new(origin, dir)
                    end
                    return nil
                end)
                if okH and hit ~= nil then return hit end
                if oldIndex then return oldIndex(self, key) end
                return nil
            end))
        end)
        AIM.spoof = ok == true
        if ok then CORE.log("BOOT", "Combat Aim silent Mouse.Hit online (mouse mt)")
        else CORE.log("WARN", "Combat Aim: silent aim hook failed — body/camera aim still work") end
    end
    function AIM.ensureSilent()
        installSilent()
    end

    -- Debounced attack: Tool.Activated + M1 used to spawn 14× loops each → crash/OOM on mobile
    local atkTok, lastAtk = 0, -10
    local function onAttack()
        if not armed() then return end
        if now() - lastAtk < 0.12 then
            -- still refresh lock once, but don't spawn another sticky storm
            pcall(AIM.apply, true)
            return
        end
        lastAtk = now()
        atkTok += 1
        local my = atkTok
        pcall(AIM.apply, true)
        task.spawn(function()
            for i = 1, 6 do
                if my ~= atkTok or not armed() then break end
                -- only the first tick hard-snaps camera; rest soft (avoids CameraModule fight)
                pcall(AIM.apply, i == 1)
                task.wait(0.04)
            end
        end)
    end
    local hookedTools = setmetatable({}, {__mode = "k"})
    local function hookTools(c)
        if not c then return end
        local function hookOne(t)
            if not t:IsA("Tool") or hookedTools[t] then return end
            hookedTools[t] = true
            bind(t.Activated:Connect(onAttack))
        end
        for _, t in ipairs(c:GetChildren()) do hookOne(t) end
        bind(c.ChildAdded:Connect(hookOne))
    end
    CORE.onChar("aim14z", function(c)
        AIM.target, AIM.root = nil, nil
        pickCache, pickCacheT = nil, -1
        hookTools(c)
    end)
    if char() then hookTools(char()) end
    bind(UserInputService.InputBegan:Connect(function(i, gp)
        if gp or not armed() then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 then onAttack()
        elseif i.KeyCode == Enum.KeyCode.Z or i.KeyCode == Enum.KeyCode.X or i.KeyCode == Enum.KeyCode.C
            or i.KeyCode == Enum.KeyCode.V or i.KeyCode == Enum.KeyCode.F or i.KeyCode == Enum.KeyCode.E then
            onAttack()
        end
    end))

    -- Soft lock throttled (was every heartbeat = crash fuel with big Enemies folders)
    local hbAcc = 0
    onHeartbeat("combataim14z", function(dt)
        hbAcc += dt
        if not armed() then
            if needlePart then pcall(function() needlePart.Transparency = 1 end) end
            hbAcc = 0
            return
        end
        if hbAcc < 0.05 then return end
        hbAcc = 0
        local c = char()
        local tool = c and c:FindFirstChildOfClass("Tool")
        local attacking = tool ~= nil or (CORE.sense and CORE.sense.userAttacking and CORE.sense.userAttacking(0.5))
        if attacking or settings.aimStick == true then
            pcall(AIM.apply, false)
        elseif needlePart then
            pcall(function() needlePart.Transparency = 1 end)
        end
    end)

    function AIM.getTarget()
        if AIM.root and AIM.root.Parent and AIM.hum and AIM.hum.Health > 0 then
            return AIM.model, AIM.hum, AIM.root
        end
        return pickEnemy(false)
    end
    onUnload(function()
        if needlePart then pcall(function() needlePart:Destroy() end) needlePart = nil end
    end)
    CORE.log("BOOT", "Combat Aim online · crash-hardened · body + camera + silent Hit · Void Needle")
end)

-- =====================================================================
-- 15. UI kit for pages
-- =====================================================================
K.order = 0
function K.nextOrder() K.order += 1 return K.order end
function K.page(parent)
    return new("ScrollingFrame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = isTouch and 5 or 3, ScrollBarImageColor3 = C.gold,
        ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}), pad(2, 10, 4, 12)})
end
function K.card(parent, h, props)
    local r = new("Frame", {Parent = parent, BackgroundColor3 = C.card, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, h or GV.ROW_H),
        LayoutOrder = K.nextOrder(), ZIndex = 3}, {corner(10)})
    local s = stroke(C.line, 1, 0.1) s.Parent = r
    for k, v in pairs(props or {}) do r[k] = v end
    -- V2: quiet hover outline on desktop only (no extra connections on phones / Performance Mode)
    if not isTouch and not (PERF and PERF.lite) then
        bind(r.MouseEnter:Connect(function() tween(s, 0.12, {Color = C.purple, Transparency = 0.35}) end))
        bind(r.MouseLeave:Connect(function() tween(s, 0.12, {Color = C.line, Transparency = 0.1}) end))
    end
    return r, s
end
-- section title: accent tick + letter-spaced caps + hairline (icons are ignored on purpose: no glyphs)
function K.title(parent, text, icon)
    local f = new("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = K.nextOrder(), ZIndex = 3})
    new("Frame", {Parent = f, BackgroundColor3 = C.gold, BorderSizePixel = 0, Position = UDim2.new(0, 2, 0.5, -6), Size = UDim2.new(0, 2, 0, 12), Rotation = 18, ZIndex = 4})
    local l = label(f, {Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -12, 1, 0), Font = F.bold, Text = spaced(text), TextColor3 = C.text,
        TextSize = 11, ZIndex = 4, AutomaticSize = Enum.AutomaticSize.X})
    l.Size = UDim2.new(0, 0, 1, 0)
    local line = new("Frame", {Parent = f, BackgroundColor3 = C.line, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.new(0.4, 0, 0, 1), ZIndex = 3})
    task.defer(function()
        pcall(function()
            local w = f.AbsoluteSize.X - (l.AbsoluteSize.X + 24)
            if w > 10 then line.Size = UDim2.new(0, w, 0, 1) else line.Visible = false end
        end)
    end)
    return f
end
function K.rowLabel(r, text, sub, rightW)
    rightW = rightW or 150
    local top = sub and math.floor((GV.ROW_H - 38) / 2) or 0
    label(r, {Position = UDim2.new(0, 14, 0, top + (sub and 1 or 0)), Size = UDim2.new(1, -rightW, 0, sub and 20 or GV.ROW_H), Font = F.bold, Text = text, TextSize = 13, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd})
    if sub then
        label(r, {Position = UDim2.new(0, 14, 0, top + 20), Size = UDim2.new(1, -rightW, 0, 16), Font = F.reg, Text = sub, TextColor3 = C.sub, TextSize = 11, ZIndex = 4,
            TextTruncate = Enum.TextTruncate.AtEnd})
    end
end
K.toggles = {}
K.toggleListeners = {}
K.sliders = {}
function K.toggle(parent, text, key, cb, sub)
    local r = K.card(parent) K.rowLabel(r, text, sub, 90)
    K.secKeys = K.secKeys or setmetatable({}, {__mode = "k"})
    K.secKeys[parent] = K.secKeys[parent] or {}
    table.insert(K.secKeys[parent], key)
    -- the whole row is a tap target (big touch area), the switch sits on top
    local rowBtn = new("TextButton", {Parent = r, BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4})
    -- slim switch: dark track, hairline stroke, small knob; on = white track glow + white knob
    local sw = new("TextButton", {Parent = r, AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 42, 0, 22), BackgroundColor3 = C.bg, ZIndex = 4}, {corner(11)})
    local sws = stroke(C.purple, 1, 0) sws.Parent = sw
    local glow = new("Frame", {Parent = sw, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4},
        {corner(11), goldGradient(0)})
    -- diamond knob (a turned square, like a shuriken point) instead of a round bubble
    local knob = new("Frame", {Parent = sw, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 11, 0.5, 0), Rotation = 45,
        BackgroundColor3 = C.faint, BorderSizePixel = 0, ZIndex = 5})
    -- V2: a slanted white blade edge on the left marks an active row
    local blade = new("Frame", {Parent = r, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 2, 0.56, 0), Rotation = 10, ZIndex = 5})
    local function render(anim)
        local on = settings[key] == true
        local t = anim and 0.2 or 0
        tween(blade, t, {BackgroundTransparency = on and 0.15 or 1})
        if K.updBadge then K.updBadge(parent) end
        tween(knob, t, {Position = on and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0), BackgroundColor3 = on and C.ink or C.faint, Rotation = on and 225 or 45})
        tween(glow, t, {BackgroundTransparency = on and 0.05 or 1})
        tween(sws, t, {Color = on and C.goldLight or C.purple, Transparency = on and 0.4 or 0})
    end
    render(false)
    local function set(v)
        if v and K.gate and not K.gate(key) then return end
        settings[key] = v
        -- a manual choice during a temporary override (Awakening / Farm Brain) is what comes back afterwards
        local OVx = CORE.override
        if OVx and (OVx.count[key] or 0) > 0 then OVx.orig[key] = v end
        render(true) saveSettings()
        if cb then local ok, e = pcall(cb, v) if not ok then CORE.log("ERR", "" .. tostring(e)) end end
        for _, f in ipairs(K.toggleListeners) do pcall(f, key, v) end
        guardianRefresh()
    end
    clickable(sw, function() set(not settings[key]) end)
    bind(rowBtn.Activated:Connect(function() set(not settings[key]) end))
    K.toggles[key] = {render = render, set = set, text = text}
    return r
end
function K.refreshToggles()
    for key, t in pairs(K.toggles) do
        pcall(t.render, true)
        for _, f in ipairs(K.toggleListeners) do pcall(f, key, settings[key]) end
    end
end
function K.refreshSliders()
    for key, set in pairs(K.sliders) do pcall(set, tonumber(settings[key]) or 0, false) end
end
function K.slider(parent, text, key, mn, mx, cb, step)
    step = step or 1
    local r = K.card(parent, isTouch and 70 or 62) K.rowLabel(r, text)
    local val = label(r, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0, 70, 0, 38), Font = F.mono,
        TextSize = 12, TextColor3 = C.goldLight, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4})
    -- invisible tall hit area around the thin bar for easy dragging on phones
    local hit = new("TextButton", {Parent = r, AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 30),
        Size = UDim2.new(1, -12, 0, isTouch and 38 or 28), ZIndex = 7})
    local bar = new("Frame", {Parent = r, Position = UDim2.new(0, 14, 0, isTouch and 47 or 42), Size = UDim2.new(1, -28, 0, 3), BackgroundColor3 = C.line, ZIndex = 4}, {corner(2)})
    local fill = new("Frame", {Parent = bar, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 0, 1, 0), ZIndex = 5}, {corner(2), goldGradient(0)})
    local knob = new("Frame", {Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 12, 0, 12), Rotation = 45,
        BackgroundColor3 = C.text, BorderSizePixel = 0, ZIndex = 6})
    local ks = stroke(C.bg, 2, 0) ks.Parent = knob
    -- V2: tiny slanted quarter ticks (ninja scale marks)
    for q = 1, 3 do
        new("Frame", {Parent = bar, BackgroundColor3 = C.sub, BackgroundTransparency = 0.45, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(q / 4, 0, 0.5, 0), Size = UDim2.new(0, 1, 0, 9), Rotation = 14, ZIndex = 4})
    end
    local function set(v, fire)
        v = clamp(math.floor(v / step + 0.5) * step, mn, mx)
        settings[key] = v
        val.Text = (step < 1) and string.format("%.1f", v) or tostring(v)
        local a = (v - mn) / (mx - mn)
        tween(fill, 0.08, {Size = UDim2.new(a, 0, 1, 0)}) tween(knob, 0.08, {Position = UDim2.new(a, 0, 0.5, 0)})
        if fire and cb then pcall(cb, v) end
    end
    set(tonumber(settings[key]) or mn, false)
    K.sliders[key] = set
    local dragging = false
    local function fromInput(i)
        local a = clamp((i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        set(mn + a * (mx - mn), true)
    end
    bind(hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true fromInput(i) tween(knob, 0.12, {Size = UDim2.new(0, 16, 0, 16)})
        end
    end))
    bind(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
    end))
    bind(UserInputService.InputEnded:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false saveSettings() guardianRefresh() tween(knob, 0.12, {Size = UDim2.new(0, 12, 0, 12)})
            if K.onSliderRelease then pcall(K.onSliderRelease, key, settings[key]) end
        end
    end))
    return r, set
end
function K.actions(parent, text, btns, sub)
    local r = K.card(parent) K.rowLabel(r, text, sub)
    local x = -14
    for i = #btns, 1, -1 do
        local b = btns[i]
        local w = b[3] or 86
        local bt = button(r, b[1], {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.new(0, w, 0, GV.BTN_H - 2), TextSize = 12, ZIndex = 4}, b[2])
        if b[4] then bt.BackgroundColor3 = b[4] end
        x -= w + 6
    end
    return r
end
function K.cycle(parent, text, key, options, sub, cb)
    local r = K.card(parent) K.rowLabel(r, text, sub)
    local bt
    bt = button(r, tostring(settings[key]), {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 136, 0, GV.BTN_H - 2), TextSize = 12,
        BackgroundColor3 = C.purpleDark, TextColor3 = C.gold, ZIndex = 4}, function()
        local idx = 1
        for i, o in ipairs(options) do if o == settings[key] then idx = i end end
        settings[key] = options[idx % #options + 1]
        bt.Text = tostring(settings[key]) saveSettings()
        if cb then pcall(cb, settings[key]) end
    end)
    return r
end
-- Collapsible section: returns a container frame to put rows in
function K.section(parent, text, icon, open)
    local holder = new("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = K.nextOrder(), ZIndex = 3}, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local head = new("TextButton", {Parent = holder, AutoButtonColor = false, Text = "", BackgroundColor3 = C.glass, BackgroundTransparency = 0.1,
        Size = UDim2.new(1, 0, 0, isTouch and 46 or 40), LayoutOrder = 0, ZIndex = 3}, {corner(10)})
    local hs = stroke(C.line, 1, 0) hs.Parent = head
    local tick = new("Frame", {Parent = head, BackgroundColor3 = C.gold, BorderSizePixel = 0, Position = UDim2.new(0, 4, 0.5, -8), Size = UDim2.new(0, 2, 0, 16), Rotation = 18, ZIndex = 4})
    label(head, {Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -104, 1, 0), Font = F.bold, Text = spaced(text), TextColor3 = C.text, TextSize = 12, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd})
    -- drawn chevron (two hairlines), rotates when collapsed
    local arrow = new("Frame", {Parent = head, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), ZIndex = 4})
    for _, sgn in ipairs({-1, 1}) do
        new("Frame", {Parent = arrow, BackgroundColor3 = C.goldLight, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, sgn * 2.4, 0.5, 0), Size = UDim2.new(0, 7, 0, 2), Rotation = sgn * -40, ZIndex = 5})
    end
    bind(head.MouseEnter:Connect(function() tween(hs, 0.15, {Color = C.purple}) tween(tick, 0.15, {Size = UDim2.new(0, 2, 0, 22), Position = UDim2.new(0, 4, 0.5, -11)}) end))
    bind(head.MouseLeave:Connect(function() tween(hs, 0.15, {Color = C.line}) tween(tick, 0.15, {Size = UDim2.new(0, 2, 0, 16), Position = UDim2.new(0, 4, 0.5, -8)}) end))
    local body = new("Frame", {Parent = holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
        Visible = open ~= false, ZIndex = 3}, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}), pad(8, 0, 0, 4)})
    arrow.Rotation = body.Visible and 0 or -90
    -- V2: live "N ON" count of the active toggles inside (visible even when collapsed)
    K.secBadge = K.secBadge or setmetatable({}, {__mode = "k"})
    K.secBadge[body] = label(head, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.new(0, 60, 0, 14), Font = F.mono,
        Text = "", TextColor3 = C.sub, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4})
    clickable(head, function()
        body.Visible = not body.Visible
        tween(arrow, 0.18, {Rotation = body.Visible and 0 or -90})
        if body.Visible and not PERF.lite then
            for i, ch in ipairs(body:GetChildren()) do
                if ch:IsA("GuiObject") then
                    local p = ch:FindFirstChild("EnterPad") or new("UIPadding", {Name = "EnterPad", Parent = ch})
                    p.PaddingLeft = UDim.new(0, 18)
                    task.delay(math.min(i, 8) * 0.02, function() tween(p, 0.18, {PaddingLeft = UDim.new(0, 0)}) end)
                end
            end
        end
    end)
    return body
end
function K.updBadge(body)
    local b = K.secBadge and K.secBadge[body]
    local keys = K.secKeys and K.secKeys[body]
    if not (b and keys) then return end
    local n = 0
    for _, k in ipairs(keys) do if settings[k] == true then n += 1 end end
    b.Text = n > 0 and (n .. " ON") or ""
end
-- Text input row bound to a settings key (or a callback when key is nil)
function K.input(parent, text, key, placeholder, sub, onCommit)
    local r = K.card(parent) K.rowLabel(r, text, sub, 190)
    local f = new("Frame", {Parent = r, BackgroundColor3 = C.panel, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 168, 0, GV.BTN_H - 2), ZIndex = 4}, {corner(9)})
    local s = stroke(C.purple, 1, 0) s.Parent = f
    local box = new("TextBox", {Parent = f, BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), Font = F.medium,
        PlaceholderText = placeholder or "", PlaceholderColor3 = C.sub, Text = key and tostring(settings[key] or "") or "", ClearTextOnFocus = false,
        TextColor3 = C.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
    bind(box.Focused:Connect(function() tween(s, 0.15, {Color = C.gold, Transparency = 0}) end))
    bind(box.FocusLost:Connect(function(enter)
        tween(s, 0.15, {Color = C.purple, Transparency = 0})
        if key then settings[key] = trim(box.Text) saveSettings() end
        if onCommit then pcall(onCommit, trim(box.Text), enter) end
    end))
    return r, box
end
-- Grid of quick toggle chips (great on phones)
function K.chipGrid(parent, items, cols)
    cols = cols or 3
    local rows = math.ceil(#items / cols)
    local g = new("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rows * (GV.BTN_H + 6)), LayoutOrder = K.nextOrder(), ZIndex = 3},
        {new("UIGridLayout", {CellSize = UDim2.new(1 / cols, -6, 0, GV.BTN_H), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local renders = {}
    for i, it in ipairs(items) do
        local key = it[2]
        local b = new("TextButton", {Parent = g, AutoButtonColor = false, BackgroundColor3 = C.card, BackgroundTransparency = 0.2, LayoutOrder = i,
            Font = F.bold, Text = it[1], TextSize = 12, TextColor3 = C.sub, ZIndex = 4}, {corner(10)})
        local s = stroke(C.purple, 1, 0.5) s.Parent = b
        local function render()
            local on = settings[key] == true
            tween(b, 0.15, {BackgroundColor3 = on and C.purpleDark or C.card, TextColor3 = on and C.gold or C.sub})
            tween(s, 0.15, {Color = on and C.gold or C.purple, Transparency = on and 0.1 or 0.5})
        end
        render()
        renders[key] = render
        clickable(b, function()
            local t = K.toggles[key]
            if t then t.set(not settings[key]) else settings[key] = not settings[key] saveSettings() render() end
        end)
    end
    K.toggleListeners[#K.toggleListeners + 1] = function(key) if renders[key] then renders[key]() end end
    return g
end

-- =====================================================================
-- 16. HUD overlay (FPS / ping)
-- =====================================================================
local hud = new("Frame", {Parent = gui, BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, Position = UDim2.new(0, 12, 0, 50), Size = UDim2.new(0, 176, 0, 28),
    Visible = settings.hud == true, ZIndex = 30}, {corner(8)})
do
    local s = stroke(C.line, 1, 0) s.Parent = hud
    new("Frame", {Parent = hud, BackgroundColor3 = C.gold, BorderSizePixel = 0, Position = UDim2.new(0, 4, 0.5, -6), Size = UDim2.new(0, 2, 0, 12), Rotation = 18, ZIndex = 31})
    NJ.slash(hud, "tr", 8, 32, 0.5)
end
local hudText = label(hud, {Size = UDim2.fromScale(1, 1), Font = F.mono, TextSize = 11, ZIndex = 31, TextXAlignment = Enum.TextXAlignment.Center, Text = ""})
makeDraggable(hud, hud)
GV.hudAcc = 0
onHeartbeat("hud", function(dt)
    if not hud.Visible then return end
    GV.hudAcc += dt
    if GV.hudAcc < 0.5 then return end
    GV.hudAcc = 0
    guardian.ping = pingMs()
    hudText.Text = GV.fps .. " FPS   ·   " .. guardian.ping .. " MS"
    hudText.TextColor3 = (GV.fps < 30 or guardian.ping > 250) and C.yellow or C.text
end)

-- =====================================================================
-- 17. Avatar helper
-- =====================================================================
local function avatarCircle(parent, pos, size, userId, z)
    userId = userId or LP.UserId
    local ringF = new("Frame", {Parent = parent, BackgroundColor3 = C.panel, Position = pos, Size = UDim2.new(0, size, 0, size), ZIndex = z or 4}, {corner(size)})
    local ring = stroke(Color3.new(1, 1, 1), size > 60 and 3 or 2, 0) ring.Parent = ringF
    local rg = goldGradient(0) rg.Parent = ring spinners[#spinners + 1] = rg
    local img = new("ImageLabel", {Parent = ringF, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = (z or 4) + 1,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"}, {corner(size)})
    task.spawn(function()
        local ok, url = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
        if ok and url and img.Parent then img.Image = url end
    end)
    return ringF
end

-- =====================================================================
-- 18. Main hub
-- =====================================================================
local H = {}   -- shared hub context
H.hud = hud

function H.unload(silent)
    if not alive then return end
    -- restore the world but keep the user's saved preferences for next time
    local snapshot = {}
    for k, v in pairs(settings) do snapshot[k] = v end
    pcall(FX.disableAll)
    pcall(FX.removeSafe)
    settings.lowgfx = false pcall(FX.applyLowGfx)
    for k, v in pairs(snapshot) do settings[k] = v end
    save(GV.SETTINGS_FILE, jsonEncode(settings))
    pcall(function() workspace.CurrentCamera.FieldOfView = orig.fov or 70 end)
    for _, f in ipairs(unloadHooks) do pcall(f) end
    if H.win and not silent then
        tween(H.sc, 0.2, {Scale = 0.85})
        tween(H.win, 0.2, {BackgroundTransparency = 1})
        task.wait(0.2)
    end
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, i in ipairs(instances) do pcall(function() i:Destroy() end) end
    conns, instances = {}, {}
    if ENV.__VoidHub == HUB then ENV.__VoidHub = nil end
    if ENV.__SecretHub == HUB then ENV.__SecretHub = nil end
end
HUB.unload = H.unload

function H.setVisible(v)
    if not H.win then return end
    H.visible = v
    HUB.uiOpen = v
    if v then
        H.win.Visible = true
        H.sc.Scale = 0.92
        spring(H.sc, 0.22, {Scale = 1})
        if H.orb then tween(H.orb, 0.15, {Size = UDim2.new(0, 0, 0, 0)}) task.delay(0.15, function() if H.visible then H.orb.Visible = false end end) end
    else
        tween(H.sc, 0.15, {Scale = 0.88})
        task.delay(0.15, function() if not H.visible then H.win.Visible = false end end)
        if H.orb then H.orb.Visible = true H.orb.Size = UDim2.new(0, 0, 0, 0) spring(H.orb, 0.22, {Size = UDim2.new(0, 42, 0, 42)}) end
    end
end

function H.panic()
    FX.disableAll()
    K.refreshToggles()
    if settings.panicSafeSpot then FX.goSafe() end
    H.setVisible(false)
    toast("PANIC: all features off, UI hidden.", "bad", 4)
    guardianRefresh("Panic")
end

function H.staffAction(name)
    if VFX.say then pcall(VFX.say, "staff", {name = name}, 3) end
    local a = settings.staffAction
    if a == "None" then return end
    toast("Staff detected: " .. name, "bad", 5)
    if a == "Go to Safe Spot" then FX.goSafe()
    elseif a == "Panic" then H.panic()
    elseif a == "Leave game" then task.delay(1.2, function() pcall(function() LP:Kick("Void Hub: left because staff joined (" .. name .. ").") end) end) end
end

-- Risk ring (36 dots that light up with the score)
function H.riskRing(parent, size, pos)
    local holder = new("Frame", {Parent = parent, BackgroundTransparency = 1, Position = pos, Size = UDim2.new(0, size, 0, size), ZIndex = 4})
    local dots = {}
    local n = 28
    for i = 1, n do
        local a = math.rad((i - 1) / n * 360 - 90)
        local d = new("Frame", {Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.card, BorderSizePixel = 0,
            Position = UDim2.new(0.5, math.cos(a) * size * 0.44, 0.5, math.sin(a) * size * 0.44), Size = UDim2.new(0, 5, 0, 5), ZIndex = 5}, {corner(3)})
        dots[i] = d
    end
    local num = label(holder, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(1, 0, 0, 30), Font = F.black, TextSize = size * 0.26,
        Text = "0", ZIndex = 6, TextXAlignment = Enum.TextXAlignment.Center})
    local lvl = label(holder, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.67, 0), Size = UDim2.new(1, 0, 0, 14), Font = F.bold, TextSize = 11,
        Text = "SAFE", ZIndex = 6, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center})
    local shown, shownLevel = -1, ""
    local function set(score, level)
        if score == shown and level == shownLevel then return end
        local col = (level == "Danger" and C.red) or (level == "Caution" and C.yellow) or C.green
        local lit = math.floor(score / 100 * n + 0.5)
        for i, d in ipairs(dots) do
            local on = i <= lit
            if PERF.lite then
                d.BackgroundColor3 = on and col or C.card d.Size = on and UDim2.new(0, 7, 0, 7) or UDim2.new(0, 5, 0, 5)
            else
                tween(d, 0.2, {BackgroundColor3 = on and col or C.card, Size = on and UDim2.new(0, 7, 0, 7) or UDim2.new(0, 5, 0, 5)})
            end
        end
        shown, shownLevel = score, level
        num.Text = tostring(score)
        lvl.Text = string.upper(level)
        tween(lvl, 0.2, {TextColor3 = col})
    end
    return set
end

function H.build()
    local W, Hh = 780, 500
    local win, sc, border = makeWindow(W, Hh)
    H.win, H.sc, H.border, H.visible = win, sc, border, true
    HUB.uiOpen = true

    -- ---------- Header ----------
    -- logo mark + letter-spaced wordmark + version line
    local okMark, mark = pcall(buildLogo, win, 40, 6)
    if okMark and typeof(mark) == "Instance" then mark.Position = UDim2.new(0, 14, 0, 6) else CORE.log("ERR", "header logo: " .. tostring(mark)) end
    label(win, {Position = UDim2.new(0, 60, 0, 11), Size = UDim2.new(0, 170, 0, 16), Font = F.bold, Text = spaced("Void Hub"), TextSize = 13, ZIndex = 6})
    local tierLine = label(win, {Position = UDim2.new(0, 60, 0, 27), Size = UDim2.new(0, 170, 0, 12), Font = F.mono, Text = "v" .. HUB.version .. "  /  …", TextSize = 9,
        TextColor3 = C.sub, ZIndex = 6})
    H.tierLine = tierLine
    -- katana cut under the header: a long hairline with a diamond guard
    NJ.divider(win, UDim2.new(0, 132, 0, 48), 220, 6, 0.7)
    -- Guardian status pill (hairline, dot)
    local pill = new("TextButton", {Parent = win, AutoButtonColor = false, Text = "", BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, Position = UDim2.new(0, 236, 0, 13),
        Size = UDim2.new(0, 168, 0, 26), ZIndex = 6}, {corner(13)})
    local pillStroke = stroke(C.green, 1, 0.45) pillStroke.Parent = pill
    local pillDot = new("Frame", {Parent = pill, BackgroundColor3 = C.green, Position = UDim2.new(0, 11, 0.5, -3), Size = UDim2.new(0, 6, 0, 6), ZIndex = 7}, {corner(3)})
    pulses[#pulses + 1] = pillDot
    local pillText = label(pill, {Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -28, 1, 0), Font = F.medium, Text = "Guardian  ·  Safe  ·  0", TextColor3 = C.green, TextSize = 11, ZIndex = 7})
    -- controls: drawn minimize / close glyphs, hairline buttons (bigger on touch)
    local CB = isTouch and 36 or 28
    local function ctl(kind, x, col, fn)
        local b = new("TextButton", {Parent = win, AutoButtonColor = false, BackgroundColor3 = C.card, BackgroundTransparency = 0.4, Text = "",
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, isTouch and 8 or 12), Size = UDim2.new(0, CB, 0, CB), ZIndex = 7}, {corner(8)})
        local st = stroke(C.line, 1, 0) st.Parent = b
        if kind == "close" then iconCross(b, 9, col, 8) else iconMinus(b, 10, col, 8) end
        NJ.slash(b, "tr", 6, 8, 0.6)
        -- V2: hover lifts the plate, press dips it (crisp, no bounce)
        bind(b.MouseEnter:Connect(function() tween(st, 0.15, {Color = col, Transparency = 0.3}) tween(b, 0.15, {BackgroundTransparency = 0.15}) end))
        bind(b.MouseLeave:Connect(function() tween(st, 0.15, {Color = C.line, Transparency = 0}) tween(b, 0.15, {BackgroundTransparency = 0.4}) end))
        bind(b.MouseButton1Down:Connect(function() b.BackgroundTransparency = 0 end))
        clickable(b, fn)
        return b
    end
    ctl("close", -12, C.red, function() H.unload(false) end)
    ctl("min", -18 - CB, C.goldLight, function() H.setVisible(false) end)
    -- V2 Panic: a red katana-cut plate (hairline rim, slash, pulsing dot); hover inks it red, press flashes white
    local panicB = new("TextButton", {Parent = win, AutoButtonColor = false, BackgroundColor3 = C.red, BackgroundTransparency = 0.9, Text = "", Font = F.bold,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24 - CB * 2, 0, isTouch and 8 or 12), Size = UDim2.new(0, 80, 0, CB), ZIndex = 7}, {corner(2)})
    do
        local ps2 = stroke(C.red, 1, 0.35) ps2.Parent = panicB
        NJ.slash(panicB, "tl", 8, 8, 0.25, C.red)
        local dot = new("Frame", {Parent = panicB, BackgroundColor3 = C.red, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.new(0, 5, 0, 5), ZIndex = 8}, {corner(3)})
        pulses[#pulses + 1] = dot
        local pl = label(panicB, {Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -26, 1, 0), Font = F.bold, Text = spaced("Panic"), TextColor3 = C.red,
            TextSize = 10, ZIndex = 8})
        bind(panicB.MouseEnter:Connect(function() tween(panicB, 0.15, {BackgroundTransparency = 0.55}) tween(pl, 0.15, {TextColor3 = Color3.new(1, 1, 1)}) tween(ps2, 0.15, {Transparency = 0}) end))
        bind(panicB.MouseLeave:Connect(function() tween(panicB, 0.15, {BackgroundTransparency = 0.9}) tween(pl, 0.15, {TextColor3 = C.red}) tween(ps2, 0.15, {Transparency = 0.35}) end))
        bind(panicB.MouseButton1Down:Connect(function() panicB.BackgroundColor3 = Color3.new(1, 1, 1) panicB.BackgroundTransparency = 0.2 tween(panicB, 0.3, {BackgroundColor3 = C.red, BackgroundTransparency = 0.55}) end))
    end
    clickable(panicB, H.panic)

    local body = new("Frame", {Parent = win, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 1, -52), ZIndex = 2})

    -- ---------- Navigation (sidebar, slim rail or bottom bar) ----------
    local nav = new("Frame", {Parent = body, BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, ZIndex = 3}, {corner(12)})
    local navStroke = stroke(C.line, 1, 0) navStroke.Parent = nav
    local navBtns = new("Frame", {Parent = nav, BackgroundTransparency = 1, ZIndex = 3})
    local indicator = new("Frame", {Parent = navBtns, BackgroundColor3 = C.cardHover, BackgroundTransparency = 0.35, ZIndex = 3}, {corner(8)})
    local istroke = stroke(C.purple, 1, 0.2) istroke.Parent = indicator
    local ibar = new("Frame", {Parent = indicator, BackgroundColor3 = C.gold, BorderSizePixel = 0, ZIndex = 4}, {corner(2)})
    -- Profile card (bottom-left): full version for desktop, mini version for the compact rail
    local prof = new("Frame", {Parent = nav, BackgroundColor3 = C.card, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0, 1), ZIndex = 3}, {corner(10)})
    local ps = stroke(C.line, 1, 0) ps.Parent = prof
    local profFull = new("Frame", {Parent = prof, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3})
    avatarCircle(profFull, UDim2.new(0, 8, 0.5, -23), 46)
    label(profFull, {Position = UDim2.new(0, 62, 0, 10), Size = UDim2.new(1, -66, 0, 18), Font = F.bold, Text = LP.DisplayName, TextSize = 13, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd})
    label(profFull, {Position = UDim2.new(0, 62, 0, 27), Size = UDim2.new(1, -66, 0, 15), Font = F.reg, Text = "@" .. LP.Name, TextColor3 = C.sub, TextSize = 11, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd})
    local tagF = new("Frame", {Parent = profFull, BackgroundTransparency = 1, Position = UDim2.new(0, 62, 0, 46), Size = UDim2.new(0, 64, 0, 16), ZIndex = 4}, {corner(4)})
    do local ts = stroke(C.goldLight, 1, 0.5) ts.Parent = tagF end
    local tagL = label(tagF, {Size = UDim2.fromScale(1, 1), Font = F.bold, Text = spaced("…"), TextColor3 = C.goldLight, TextSize = 8, ZIndex = 5, TextXAlignment = Enum.TextXAlignment.Center})
    H.tierTag = tagL
    local profMini = new("Frame", {Parent = prof, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3})
    avatarCircle(profMini, UDim2.new(0.5, -17, 0, 6), 34)
    label(profMini, {Position = UDim2.new(0, 3, 0, 42), Size = UDim2.new(1, -6, 0, 14), Font = F.bold, Text = LP.DisplayName, TextSize = 10, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center})

    local content = new("Frame", {Parent = body, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2})
    H.content = content

    -- free=true → allowed on Free tier. Premium unlocks every tab.
    local cats = {
        {name = "Start", num = "01", free = true},
        {name = "DXLTA", num = "02", free = false},
        {name = "Scripts", num = "03", free = true},
        {name = "Settings", num = "04", free = false},
        {name = "Console", num = "05", free = false},
    }
    H.cats = cats
    local catButtons = {}
    local current
    local curMode = "desktop"
    local function visibleCats()
        local out = {}
        local tier = HUB.tier
        for i, c in ipairs(cats) do
            local ok = false
            if tier == "premium" then ok = true
            elseif tier == "free" then ok = c.free == true
            else ok = (c.name == "Start") end -- choose path: only Start until they pick
            if ok then out[#out + 1] = {i = i, c = c} end
        end
        return out
    end
    local function railStride() return curMode == "compact" and 40 or 48 end
    local function placeIndicator(i, anim)
        local vis = visibleCats()
        local slot = 1
        for s, v in ipairs(vis) do if v.i == i then slot = s break end end
        local n = math.max(#vis, 1)
        local t = anim and 0.22 or 0
        if curMode == "portrait" then
            tween(indicator, t, {Position = UDim2.new((slot - 1) / n, 4, 0, 4), Size = UDim2.new(1 / n, -8, 1, -8)})
            ibar.AnchorPoint = Vector2.new(0.5, 1) ibar.Position = UDim2.new(0.5, 0, 1, -3) ibar.Size = UDim2.new(0, 22, 0, 2) ibar.Rotation = 0
        else
            local st = railStride()
            tween(indicator, t, {Position = UDim2.new(0, 0, 0, (slot - 1) * st), Size = UDim2.new(1, 0, 0, st - 6)})
            ibar.AnchorPoint = Vector2.new(0, 0.5) ibar.Position = UDim2.new(0, 6, 0.5, 0) ibar.Size = UDim2.new(0, 2, 0, 18) ibar.Rotation = 16
        end
    end
    local function applyLayout(mode)
        curMode = mode
        if mode == "portrait" then
            win.Size = UDim2.new(0, 400, 0, 620)
            pill.Position = UDim2.new(0, 20, 0, 46) pill.Size = UDim2.new(0, 168, 0, 24)
            body.Position = UDim2.new(0, 0, 0, 78) body.Size = UDim2.new(1, 0, 1, -78)
            nav.AnchorPoint = Vector2.new(0, 1) nav.Position = UDim2.new(0, 10, 1, -10) nav.Size = UDim2.new(1, -20, 0, 60)
            navBtns.Position = UDim2.new(0, 0, 0, 0) navBtns.Size = UDim2.fromScale(1, 1)
            prof.Visible = false
            content.Position = UDim2.new(0, 12, 0, 0) content.Size = UDim2.new(1, -24, 1, -80)
        elseif mode == "compact" then
            win.Size = UDim2.new(0, 680, 0, 340)
            pill.Position = UDim2.new(0, 236, 0, 13) pill.Size = UDim2.new(0, 168, 0, 26)
            body.Position = UDim2.new(0, 0, 0, 50) body.Size = UDim2.new(1, 0, 1, -50)
            nav.AnchorPoint = Vector2.new(0, 0) nav.Position = UDim2.new(0, 8, 0, 0) nav.Size = UDim2.new(0, 78, 1, -8)
            navBtns.Position = UDim2.new(0, 6, 0, 6) navBtns.Size = UDim2.new(1, -12, 1, -80)
            prof.Visible = true prof.Position = UDim2.new(0, 5, 1, -5) prof.Size = UDim2.new(1, -10, 0, 62)
            profFull.Visible = false profMini.Visible = true
            content.Position = UDim2.new(0, 96, 0, 0) content.Size = UDim2.new(1, -106, 1, -8)
        else
            win.Size = UDim2.new(0, W, 0, Hh)
            pill.Position = UDim2.new(0, 236, 0, 13) pill.Size = UDim2.new(0, 168, 0, 26)
            body.Position = UDim2.new(0, 0, 0, 52) body.Size = UDim2.new(1, 0, 1, -52)
            nav.AnchorPoint = Vector2.new(0, 0) nav.Position = UDim2.new(0, 10, 0, 0) nav.Size = UDim2.new(0, 168, 1, -10)
            navBtns.Position = UDim2.new(0, 8, 0, 8) navBtns.Size = UDim2.new(1, -16, 1, -104)
            prof.Visible = true prof.Position = UDim2.new(0, 8, 1, -8) prof.Size = UDim2.new(1, -16, 0, 76)
            profFull.Visible = true profMini.Visible = false
            content.Position = UDim2.new(0, 188, 0, 0) content.Size = UDim2.new(1, -198, 1, -10)
        end
        local vis = visibleCats()
        local n = math.max(#vis, 1)
        local slotOf = {}
        for s, v in ipairs(vis) do slotOf[v.i] = s end
        for i, b in ipairs(catButtons) do
            local slot = slotOf[i]
            b.Visible = slot ~= nil
            if slot then
                if mode == "portrait" then
                    b.Position = UDim2.new((slot - 1) / n, 0, 0, 0) b.Size = UDim2.new(1 / n, 0, 1, 0)
                    b.Text = string.upper(cats[i].name) b.TextSize = 11 b.TextXAlignment = Enum.TextXAlignment.Center
                elseif mode == "compact" then
                    b.Position = UDim2.new(0, 0, 0, (slot - 1) * 40) b.Size = UDim2.new(1, 0, 0, 36)
                    b.Text = cats[i].num .. "\n" .. string.upper(cats[i].name) b.TextSize = 10 b.TextXAlignment = Enum.TextXAlignment.Center
                else
                    b.Position = UDim2.new(0, 0, 0, (slot - 1) * 48) b.Size = UDim2.new(1, 0, 0, 42)
                    b.Text = "" b.TextXAlignment = Enum.TextXAlignment.Left
                end
            end
            local nl, ml = b:FindFirstChild("NumL"), b:FindFirstChild("NameL")
            if nl then nl.Visible = (mode ~= "portrait" and mode ~= "compact") and slot ~= nil end
            if ml then ml.Visible = (mode ~= "portrait" and mode ~= "compact") and slot ~= nil end
        end
        if current then placeIndicator(current, false) end
    end
    local function refreshAccess()
        local tier = HUB.tier
        local label = (tier == "premium" and "PREMIUM") or (tier == "free" and "FREE") or "CHOOSE"
        if H.tierLine then H.tierLine.Text = "v" .. HUB.version .. "  /  " .. label end
        if H.tierTag then H.tierTag.Text = spaced(label) end
        if H.heroBadge then
            for _, ch in ipairs(H.heroBadge:GetChildren()) do if ch:IsA("TextLabel") then ch.Text = spaced(label) end end
        end
        applyLayout(curMode)
        if H.gate then H.gate.Visible = (tier == nil) end
        if H.startBody then H.startBody.Visible = (tier ~= nil) end
        if H.upgradeCard then H.upgradeCard.Visible = (tier == "free") end
        if H.bossLock then H.bossLock.Visible = (tier ~= "premium") end
        -- if current tab became locked, bounce to Start
        if current and cats[current] then
            local allowed = (tier == "premium") or (tier == "free" and cats[current].free) or (tier == nil and cats[current].name == "Start")
            if not allowed and H.selectCat then task.defer(H.selectCat, 1) end
        end
    end
    H.refreshAccess = refreshAccess
    function H.setTier(tier, persist)
        if tier ~= "free" and tier ~= "premium" then return end
        HUB.tier = tier
        if persist ~= false then pcall(save, GV.TIER_FILE, tier) end
        if tier == "free" then
            settings.aggression = false
            settings.aggroPvp = false
            saveSettings()
            if K.refreshToggles then pcall(K.refreshToggles) end
        end
        refreshAccess()
        if H.refreshBrainCard then pcall(H.refreshBrainCard) end
        if tier == "premium" then
            toast("Premium · Boss mode unlocked. Arm Aggression when you're ready.", "star", 3.5)
        else
            toast("Free · Guardian protects. Premium hunts.", "ok", 3)
        end
    end

    -- ---------- Pages ----------
    -- V2.1: every page is built protected. A broken page becomes a small error card,
    -- the rest of the panel still loads and the error is shown as a toast + in the Console tab.
    local pages = {}
    H.buildErrors = {}
    local builders = {H.buildStart, H.buildDxlta, H.buildScripts, H.buildSettings, H.buildConsole}
    for i, fn in ipairs(builders) do
        local ok, pg = pcall(fn, content)
        if not ok or typeof(pg) ~= "Instance" then
            local why = ok and "page builder returned nothing" or tostring(pg)
            CORE.log("ERR", "page '" .. cats[i].name .. "': " .. why)
            H.buildErrors[#H.buildErrors + 1] = cats[i].name .. ": " .. why
            -- remove a half-built page, show an honest error card instead
            for _, ch in ipairs(content:GetChildren()) do
                if ch:IsA("ScrollingFrame") then
                    local used = false
                    for j = 1, i - 1 do if pages[j] == ch then used = true end end
                    if not used then pcall(function() ch:Destroy() end) end
                end
            end
            local okF, fb = pcall(function()
                local f = K.page(content)
                label(f, {Size = UDim2.new(1, 0, 0, 60), Font = F.medium, TextWrapped = true, TextColor3 = C.red, TextSize = 12, ZIndex = 4,
                    Text = "This page could not be built: " .. why:sub(1, 220) .. "\nEverything else still works. Details in the Console tab."})
                return f
            end)
            pg = okF and fb or new("Frame", {Parent = content, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false})
        end
        pages[i] = pg
    end
    H.pages = pages

    local function selectCat(i)
        if current == i then return end
        local c = cats[i]
        if not c then return end
        local tier = HUB.tier
        local allowed = (tier == "premium") or (tier == "free" and c.free) or (tier == nil and c.name == "Start")
        if not allowed then
            if tier == "free" then toast("Premium only · unlock with a key on Start.", "warn", 2.5)
            else toast("Choose Free or Premium on Start first.", "info", 2.5) end
            return
        end
        local prev = current and pages[current]
        local dir = (current and i < current) and -1 or 1
        current = i
        H.currentCat = i
        placeIndicator(i, true)
        for j, b in ipairs(catButtons) do
            tween(b, 0.15, {TextColor3 = (j == i) and C.text or C.sub})
            local nl, ml = b:FindFirstChild("NumL"), b:FindFirstChild("NameL")
            if ml then tween(ml, 0.15, {TextColor3 = (j == i) and C.text or C.sub}) ml.Font = (j == i) and F.bold or F.medium end
            if nl then tween(nl, 0.15, {TextColor3 = (j == i) and C.goldLight or C.faint}) end
        end
        if prev then prev.Visible = false end
        local pg = pages[i]
        pg.Visible = true
        if PERF.lite then
            pg.Position = UDim2.new()
        else
            pg.Position = UDim2.new(0, 24 * dir, 0, 0)
            tween(pg, 0.2, {Position = UDim2.new(0, 0, 0, 0)})
        end
        if pg:GetAttribute("OnShow") and H["onShow" .. i] then pcall(H["onShow" .. i]) end
    end
    for i, c in ipairs(cats) do
        local b = new("TextButton", {Parent = navBtns, AutoButtonColor = false, BackgroundTransparency = 1, Font = F.medium, Text = c.name,
            TextColor3 = C.sub, TextSize = 13, ZIndex = 4})
        label(b, {Name = "NumL", Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0, 24, 1, 0), Font = F.mono, Text = c.num, TextSize = 10,
            TextColor3 = C.faint, ZIndex = 5, Visible = false})
        label(b, {Name = "NameL", Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -50, 1, 0), Font = F.medium, Text = c.name, TextSize = 13,
            TextColor3 = C.sub, ZIndex = 5, Visible = false})
        clickable(b, function() selectCat(i) end)
        catButtons[i] = b
    end
    layoutListeners[#layoutListeners + 1] = applyLayout
    applyLayout(layoutMode())
    selectCat(1)
    H.selectCat = selectCat
    refreshAccess()

    -- ---------- Guardian wiring ----------
    guardian.listeners[#guardian.listeners + 1] = function(score, level, reasons, prev, why)
        local col = (level == "Danger" and C.red) or (level == "Caution" and C.yellow) or C.green
        pillText.Text = "Guardian  ·  " .. level .. "  ·  " .. score
        tween(pillText, 0.2, {TextColor3 = col}) tween(pillDot, 0.2, {BackgroundColor3 = col}) tween(pillStroke, 0.2, {Color = col})
        if prev ~= level then
            local s = pill:FindFirstChild("HoverScale")
            if s then s.Scale = 1.12 tween(s, 0.22, {Scale = 1}) end
            if level == "Danger" then toast("Guardian: DANGER" .. (why and (" · " .. why) or ""), "bad", 5)
            elseif level == "Caution" and prev == "Safe" then toast("Guardian: caution" .. (why and (" · " .. why) or ""), "warn") end
        end
    end
    clickable(pill, function() selectCat(1) end)

    bind(Players.PlayerAdded:Connect(function(p)
        task.wait(1.5)
        if not alive then return end
        local st, su = checkPlayer(p)
        if st then
            guardian.staff[p.UserId] = st
            H.staffAction(p.DisplayName .. " (" .. st .. ")")
            guardianRefresh("Staff joined: " .. p.DisplayName)
        elseif su then
            guardian.suspicious[p.UserId] = su
            toast("Flagged player joined: " .. p.DisplayName .. " · " .. su, "warn")
            guardianRefresh()
        end
        if H.refreshPlayers then pcall(H.refreshPlayers) end
    end))
    bind(Players.PlayerRemoving:Connect(function(p)
        if guardian.staff[p.UserId] then toast("Staff left: " .. p.DisplayName, "ok") end
        guardian.staff[p.UserId] = nil guardian.suspicious[p.UserId] = nil
        task.defer(guardianRefresh)
        if H.refreshPlayers then task.defer(H.refreshPlayers) end
    end))
    local gAcc = 0
    onHeartbeat("guardian", function(dt)
        gAcc += dt
        if gAcc < 2 then return end
        gAcc = 0
        guardian.ping = pingMs()
        guardianRefresh()
    end)
    guardianRefresh()
    if countKeys(guardian.staff) > 0 and (settings.staffAction == "Go to Safe Spot" or settings.staffAction == "Panic") then
        H.staffAction("already in server")
    end

    -- ---------- Floating orb (minimized) ----------
    -- Compact ROUND reopen button (not a big square tile)
    local orb = new("TextButton", {Parent = gui, AutoButtonColor = false, Text = "",
        BackgroundColor3 = C.bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 52, 0.5, 0), Size = UDim2.new(0, 0, 0, 0),
        Visible = false, ZIndex = 90, ClipsDescendants = true},
        {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
    local os2 = stroke(Color3.new(1, 1, 1), 1.2, 0.15) os2.Parent = orb
    local og = borderGradient() og.Parent = os2 spinners[#spinners + 1] = og
    do
        local m, mEyes = buildLogo(orb, 34, 91, "lite")
        m.AnchorPoint = Vector2.new(0.5, 0.5) m.Position = UDim2.fromScale(0.5, 0.5) m.Size = UDim2.fromScale(0.78, 0.78)
        if not PERF.lite then
            task.spawn(function()
                local up = true
                while alive and orb.Parent do
                    if orb.Visible then
                        for _, e in ipairs(mEyes) do tween(e.f, 1.2, {BackgroundTransparency = up and e.base or math.min(1, e.base + 0.35)}, Enum.EasingStyle.Sine) end
                        up = not up
                    end
                    task.wait(1.25)
                end
            end)
        end
    end
    H.orb = orb
    local moved = false
    do
        local dragging, startPos, startInput
        bind(orb.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, startPos, startInput, moved = true, orb.Position, i.Position, false
                local c
                c = i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        if c then c:Disconnect() end
                        if not moved then H.setVisible(true) end
                    end
                end)
            end
        end))
        bind(UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = (i.Position - startInput) / uiScale.Scale
                if d.Magnitude > 6 then moved = true end
                orb.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
    end

    -- ---------- Keybinds ----------
    bind(UserInputService.InputBegan:Connect(function(i, gp)
        if gp or H.capturing or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local name = i.KeyCode.Name
        local b = settings.binds
        if name == b.toggleUI then H.setVisible(not H.visible)
        elseif name == b.panic then H.panic()
        elseif name == b.safespot then if FX.inSafe() then FX.leaveSafe() else FX.goSafe() end
        elseif name == b.domain then if VFX.domain then VFX.domain() end
        elseif name == b.godform then if VFX.godForm then VFX.godForm() end
        elseif name == b.lift then if VFX.handsLift then VFX.handsLift(true) end
        else
            for key, bound in pairs(b) do
                if bound == name and K.toggles[key] then K.toggles[key].set(not settings[key]) toast(K.toggles[key].text .. (settings[key] and " on" or " off"), "info", 1.6) end
            end
        end
    end))

    -- ---------- Auto-load this game's "Default" profile ----------
    if settings.autoProfile then
        local snap = FX.gameProfiles()["Default"]
        if type(snap) == "table" then
            task.defer(function()
                for k, v in pairs(snap) do settings[k] = v end
                FX.applyAll() K.refreshToggles() K.refreshSliders()
                if H.hud then H.hud.Visible = settings.hud == true end
                toast("Loaded this game's Default profile.", "ok")
            end)
        end
    end

    toast(H.greeting() .. ", " .. LP.DisplayName .. "!", "star")
    if PERF.lite and settings.stats.runs == 0 and isTouch then toast("Performance Mode is on for smooth mobile play. Change it in Settings.", "info", 4) end
end

function H.greeting()
    local hr = tonumber(os.date("%H")) or 12
    if hr < 5 then return "Good night" elseif hr < 12 then return "Good morning" elseif hr < 18 then return "Good afternoon" end
    return "Good evening"
end

-- =====================================================================
-- 19. Start page
-- =====================================================================
GV.NEWS = {
    {"5.7c", "SAFE BOOT: game no longer closes on start — silent aim hooks Mouse (not game.__index), Void Override namecall is lazy, Combat Aim OFF until you enable it."},
    {"5.7b", "Combat Aim crash fix: safe lookAt, silent-aim never throws, attack debounce, Enemies scan cached/capped — NPC M1 no longer kills the app."},
    {"5.7b", "PVP Combat Aim fixed: Aim at players ON by default, real Players scan, hard camera snap on attack, FOV ignored while attacking, lead on movers."},
    {"5.7b", "Anti-Death (default ON): holds Dead state, Soft God/heal poke, Safe Spot bail. Quiet Death mutes dying smug lines. Toggle OFF to respawn if stuck."},
    {"5.7", "DXLTA is universal only. Blox Fruits kit lives on Start when that game is detected."},
    {"5.7", "Void Net: -net / -bring / -hold / -drop / -throw / -orbit / -wall / -pulse — only parts THIS client owns."},
    {"5.7", "Void Override suite: Amplify · Hitbox · Parasite · CD Strip · Soft God · Dominion · Maps · Siphon · Mirror · Market."},
    {"5.7", "Combat Aim: body + camera + silent Mouse.Hit on nearest enemy. Void Needle pulls client-owned mobs onto your blade (BF)."},
    {"5.7", "Hub reopen button is a small round orb (not a big square)."},
    {"5.7", "Mirror Ward + Shadow Market. Dominion = Siphon/Net + Override. Chat: -siphon · -dominion."},
    {"5.7", "Free = protect + Scripts. Premium = Boss mode (Aggression) + full hub. Brain profile shows what this game already taught him."},
    {"5.7", "Verified Moments: DODGED / SAFE / LEARNED / DOWN / BOSS only after real wins — no spam flashes."},
    {"5.7", "Get Key → Discord. Hand models out. Control / Lifeline / Takeover stay."},
    {"5.6", "Guardian Aggression (opt-in, ANY game): tools first, then combat keys if VIM exists. Hostile NPCs only. Learns winners, drops duds."},
    {"5.6", "Situations Hunting / Dominating. Optional PvP only vs Enemy / Exploiter. Misses out of range don't poison learning."},
    {"5.5", "Rescue / Lifeline / Lift move YOU directly — brief control, voice lines, Takeover presence. No giant hands."},
    {"5.4", "Blox Fruits Kit: fruit notifier / ESP / tween sniper, level farm, chests, auto stats, Buso / Ken, island tween."},
    {"5.0", "Guardian Awakening + Kamui Escape. Radar, Seals, ink-spirit figure."},
    {"4.3", "Guardian PvE: Boss Choreography, Puppet Finisher, Loot Grab, Shadow Strikes, Mob Gather — in DXLTA (Premium)."},
    {"4.2", "Monochrome ninja identity, katana slash loading screen, sharp edges, white slit eyes."},
    {"4.1", "Predictive Dodge, Guardian Godmode, Ability Assist, Stalker Shield, Walk on Water, respawn-proof core."},
    {"4.0", "Game detection by GameId + PlaceId, cinematic loading, honest NPC Reset / NPC Evade."},
    {"3.0", "Faster start, Performance Mode, phone layouts, automation, waypoints, profiles."},
    {"New", "DXLTA → Automation: instant prompts, auto-interact and auto-click."},
    {"New", "Players now show account age, friend status and distance, with per-player ESP."},
    {"Tip", "Tap the ninja badge to reopen the hub on mobile."},
    {"Tip", "Save your setup as 'Default' in Settings → Profiles to auto-load it in this game."},
}
function H.buildStart(parent)
    local pg = K.page(parent)

    -- ---------- Access gate (after loading): Premium key OR Free ----------
    local gate = new("Frame", {Parent = pg, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = K.nextOrder(), ZIndex = 3, Visible = (HUB.tier == nil)},
        {new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})})
    H.gate = gate
    do
        local card = K.card(gate, isTouch and 360 or 340)
        card.LayoutOrder = 1
        new("UIGradient", {Parent = card, Rotation = 18, Color = ColorSequence.new(C.purpleDark, C.card)})
        local gLogo = buildLogo(card, 56, 4, "lite")
        gLogo.Position = UDim2.new(0, 18, 0, 16)
        local gt = label(card, {Position = UDim2.new(0, 86, 0, 18), Size = UDim2.new(1, -100, 0, 22), Font = F.display, Text = spaced("Void Hub"), TextSize = 18, ZIndex = 5})
        shimmerText(gt)
        label(card, {Position = UDim2.new(0, 86, 0, 42), Size = UDim2.new(1, -100, 0, 16), Font = F.medium, Text = "Choose how you enter", TextColor3 = C.sub, TextSize = 12, ZIndex = 5})
        new("Frame", {Parent = card, BorderSizePixel = 0, BackgroundColor3 = C.gold, Position = UDim2.new(0, 86, 0, 62), Size = UDim2.new(0, 28, 0, 2), ZIndex = 5})

        -- Premium path
        label(card, {Position = UDim2.new(0, 18, 0, 78), Size = UDim2.new(1, -36, 0, 14), Font = F.bold, Text = spaced("Premium"), TextColor3 = C.goldLight, TextSize = 10, ZIndex = 5})
        label(card, {Position = UDim2.new(0, 18, 0, 94), Size = UDim2.new(1, -36, 0, 28), Font = F.reg, Text = "Boss mode: Aggression · DXLTA · Settings · Console. Show them who's boss.", TextColor3 = C.sub, TextSize = 11, TextWrapped = true, ZIndex = 5})
        local boxF = new("Frame", {Parent = card, BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Position = UDim2.new(0, 18, 0, 128), Size = UDim2.new(1, -36, 0, 40), ZIndex = 5}, {corner(8)})
        local bs = stroke(C.purple, 1, 0) bs.Parent = boxF
        label(boxF, {Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0, 36, 1, 0), Text = "KEY", Font = F.bold, TextColor3 = C.faint, TextSize = 10, ZIndex = 6})
        local box = new("TextBox", {Parent = boxF, BackgroundTransparency = 1, Position = UDim2.new(0, 48, 0, 0), Size = UDim2.new(1, -56, 1, 0),
            Font = F.medium, PlaceholderText = "Paste Premium key", PlaceholderColor3 = C.faint, Text = "", ClearTextOnFocus = false,
            TextColor3 = C.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
        bind(box.Focused:Connect(function() tween(bs, 0.15, {Color = C.gold}) end))
        bind(box.FocusLost:Connect(function() tween(bs, 0.15, {Color = C.purple}) end))
        local status = label(card, {Position = UDim2.new(0, 18, 0, 172), Size = UDim2.new(1, -36, 0, 14), Font = F.medium, Text = "", TextSize = 11, TextColor3 = C.sub, ZIndex = 5})
        local function tryPremium()
            if hubHash(trim(box.Text)) == GV.KEY_HASH then
                save(GV.KEY_FILE, trim(box.Text))
                if H.setTier then H.setTier("premium") end
            else
                status.Text = "Invalid key. Tap Get Key for Discord." status.TextColor3 = C.red
                tween(bs, 0.1, {Color = C.red})
                if settings.sounds then sound(GV.SND_TICK, 0.2, 0.6) end
                task.delay(0.35, function() tween(bs, 0.2, {Color = C.purple}) end)
            end
        end
        -- Get Key (Discord invite) beside Unlock Premium — primary unlock stays gold
        local btnPad, btnGap = 18, 8
        button(card, "Get Key", {
            Position = UDim2.new(0, btnPad, 0, 190),
            Size = UDim2.new(0.5, -(btnPad + btnGap * 0.5), 0, 38),
            TextSize = 13, ZIndex = 5,
        }, openKeyInvite)
        goldButton(card, "Unlock Premium", {
            Position = UDim2.new(0.5, btnGap * 0.5, 0, 190),
            Size = UDim2.new(0.5, -(btnPad + btnGap * 0.5), 0, 38),
            TextSize = 13, ZIndex = 5,
        }, tryPremium)
        bind(box.FocusLost:Connect(function(enter) if enter then tryPremium() end end))

        -- Free path
        local sepY = 240
        new("Frame", {Parent = card, BorderSizePixel = 0, BackgroundColor3 = C.line, Position = UDim2.new(0, 18, 0, sepY), Size = UDim2.new(1, -36, 0, 1), ZIndex = 5})
        label(card, {Position = UDim2.new(0, 18, 0, sepY + 10), Size = UDim2.new(1, -36, 0, 14), Font = F.bold, Text = spaced("Free"), TextColor3 = C.sub, TextSize = 10, ZIndex = 5})
        label(card, {Position = UDim2.new(0, 18, 0, sepY + 26), Size = UDim2.new(1, -36, 0, 28), Font = F.reg, Text = "Protection wow + Scripts. Brain watches. Upgrade when you want him to hunt.", TextColor3 = C.sub, TextSize = 11, TextWrapped = true, ZIndex = 5})
        local freeBtn = new("TextButton", {Parent = card, AutoButtonColor = false, Text = "Continue free", Font = F.bold, TextSize = 13, TextColor3 = C.text,
            BackgroundColor3 = C.cardHover, BackgroundTransparency = 0.15, Position = UDim2.new(0, 18, 0, sepY + 58), Size = UDim2.new(1, -36, 0, 38), ZIndex = 5}, {corner(8)})
        local fs = stroke(C.line, 1, 0) fs.Parent = freeBtn
        clickable(freeBtn, function()
            if H.setTier then H.setTier("free") end
        end)
        bind(freeBtn.MouseEnter:Connect(function() tween(fs, 0.12, {Color = C.gold, Transparency = 0.35}) end))
        bind(freeBtn.MouseLeave:Connect(function() tween(fs, 0.12, {Color = C.line, Transparency = 0}) end))
    end

    -- Body shown after Free / Premium is chosen
    local startBody = new("Frame", {Parent = pg, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = K.nextOrder(), ZIndex = 3, Visible = (HUB.tier ~= nil)},
        {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
    H.startBody = startBody
    local function bodyParent() return startBody end

    -- Hero
    local hero = K.card(bodyParent(), 132)
    new("UIGradient", {Parent = hero, Rotation = 20, Color = ColorSequence.new(C.purpleDark, C.card)})
    avatarCircle(hero, UDim2.new(0, 18, 0.5, -46), 92)
    label(hero, {Position = UDim2.new(0, 126, 0, 18), Size = UDim2.new(1, -136, 0, 20), Font = F.medium, TextColor3 = C.sub, TextSize = 13,
        Text = H.greeting() .. ",", ZIndex = 4})
    local nm = label(hero, {Position = UDim2.new(0, 126, 0, 38), Size = UDim2.new(1, -136, 0, 30), Font = F.black, Text = LP.DisplayName, TextSize = 24, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd})
    shimmerText(nm)
    label(hero, {Position = UDim2.new(0, 126, 0, 68), Size = UDim2.new(1, -136, 0, 16), Font = F.reg, Text = "@" .. LP.Name .. "  ·  ID " .. LP.UserId,
        TextColor3 = C.sub, TextSize = 12, ZIndex = 4})
    H.heroBadge = premiumBadge(hero, UDim2.new(0, 126, 0, 94), (HUB.tier == "free" and "FREE") or (HUB.tier == "premium" and "PREMIUM") or "…")
    -- Free → Premium upgrade strip
    do
        local up = K.card(bodyParent(), 52)
        up.Visible = (HUB.tier == "free")
        H.upgradeCard = up
        label(up, {Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -190, 0, 16), Font = F.bold, Text = spaced("Go Premium"), TextColor3 = C.goldLight, TextSize = 11, ZIndex = 5})
        label(up, {Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -190, 0, 16), Font = F.reg, Text = "Boss mode · Aggression · DXLTA · full hub", TextColor3 = C.sub, TextSize = 11, ZIndex = 5})
        local getUp = new("TextButton", {Parent = up, AutoButtonColor = false, Text = "Get Key", Font = F.bold, TextSize = 11, TextColor3 = C.text,
            BackgroundColor3 = C.cardHover, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.new(0, 72, 0, 28), ZIndex = 5}, {corner(6)})
        local getUpS = stroke(C.line, 1, 0) getUpS.Parent = getUp
        clickable(getUp, openKeyInvite)
        bind(getUp.MouseEnter:Connect(function() tween(getUpS, 0.12, {Color = C.gold, Transparency = 0.35}) end))
        bind(getUp.MouseLeave:Connect(function() tween(getUpS, 0.12, {Color = C.line, Transparency = 0}) end))
        local ub = new("TextButton", {Parent = up, AutoButtonColor = false, Text = "Key", Font = F.bold, TextSize = 12, TextColor3 = Color3.fromRGB(8, 8, 10),
            BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 64, 0, 28), ZIndex = 5}, {corner(6)})
        clickable(ub, function()
            HUB.tier = nil
            if H.refreshAccess then H.refreshAccess() end
            toast("Paste your Premium key above.", "info", 2.5)
        end)
    end
    -- ninja badge watermark (faded) + a katana streak behind it
    do
        local wm = buildLogo(hero, 118, 3, "lite")
        wm.AnchorPoint = Vector2.new(1, 0.5) wm.Position = UDim2.new(1, -14, 0.5, 0)
        pcall(function() wm.GroupTransparency = 0.78 end)
        new("Frame", {Parent = hero, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -30, 0.5, 0), Size = UDim2.new(0, 210, 0, 1), Rotation = -24, ZIndex = 3},
            {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 1)})})})
        NJ.slash(hero, "tr", 16, 6, 0.3)
    end

    -- Per-game Brain profile (what the Guardian already knows here)
    K.title(startBody, "This game")
    local brainCard = K.card(startBody, isTouch and 112 or 100)
    new("UIGradient", {Parent = brainCard, Rotation = 16, Color = ColorSequence.new(C.purpleDark, C.card)})
    NJ.slash(brainCard, "tr", 14, 5, 0.35)
    new("Frame", {Parent = brainCard, BorderSizePixel = 0, BackgroundColor3 = C.gold, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 2, 0, 18), Rotation = 14, ZIndex = 5})
    label(brainCard, {Position = UDim2.new(0, 28, 0, 10), Size = UDim2.new(1, -40, 0, 14), Font = F.bold, Text = spaced("Brain profile"), TextColor3 = C.goldLight, TextSize = 10, ZIndex = 5})
    local brainHead = label(brainCard, {Position = UDim2.new(0, 14, 0, 30), Size = UDim2.new(1, -28, 0, 36), Font = F.medium, Text = "Reading this place…", TextColor3 = C.text, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5})
    local brainSub = label(brainCard, {Position = UDim2.new(0, 14, 0, 70), Size = UDim2.new(1, -28, 0, 22), Font = F.reg, Text = "", TextColor3 = C.sub, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
    H.brainCard = {head = brainHead, sub = brainSub}
    H.refreshBrainCard = function()
        if not (brainHead and brainHead.Parent) then return end
        local head, detail = "Watching…", {}
        if brain.profile then
            local ok, h, d = pcall(brain.profile)
            if ok and type(h) == "string" then head, detail = h, d or {} end
        end
        brainHead.Text = head
        local line = detail[1] and detail[1][2] or ""
        if detail[2] and detail[2][2] then line = line .. "  ·  " .. detail[2][2] end
        brainSub.Text = line
        brainSub.TextColor3 = (detail[2] and detail[2][1] == "warn" and C.gold) or C.sub
    end

    -- Stats cards
    local statsRow = new("Frame", {Parent = startBody, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74), LayoutOrder = K.nextOrder(), ZIndex = 3},
        {new("UIGridLayout", {CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.new(0, 8, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder})})
    local function stat(icon, title)
        local c = new("Frame", {Parent = statsRow, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, ZIndex = 3}, {corner(12)})
        local s = stroke(C.line, 1, 0) s.Parent = c
        NJ.slash(c, "tr", 10, 5, 0.55)
        label(c, {Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -16, 0, 14), Font = F.bold, Text = spaced(title), TextColor3 = C.sub, TextSize = 9, ZIndex = 4})
        local v = label(c, {Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(1, -16, 0, 34), Font = F.display, Text = "-", TextColor3 = C.text, TextSize = 24, ZIndex = 4})
        return v
    end
    local sessV = stat(nil, "Verified")
    local runsV = stat(nil, "Scripts run")
    local favV = stat(nil, "Favorites")
    H.updateStats = function()
        local S = HUB.session or {}
        local n = (tonumber(S.dodges) or 0) + (tonumber(S.saves) or 0) + (tonumber(S.kills) or 0)
        sessV.Text = tostring(n)
        runsV.Text = tostring(settings.stats.runs or 0)
        favV.Text = tostring(#favs)
        if H.refreshBrainCard then pcall(H.refreshBrainCard) end
    end
    H.updateStats()
    task.spawn(function()
        while alive and sessV.Parent do
            if H.updateStats then pcall(H.updateStats) end
            task.wait(1.5)
        end
    end)

    -- Quick toggles (one tap, big targets)
    K.title(startBody, "Quick toggles")
    K.chipGrid(startBody, {{"Fly", "fly"}, {"Noclip", "noclip"}, {"ESP", "esp"}, {"Inf Jump", "infjump"}, {"Fullbright", "fullbright"}, {"Instant prompts", "instantprompts"}}, 3)
    K.actions(startBody, "Guardian V2", {{"Awaken", function() if CORE.awaken then CORE.awaken.start() end end, 86},
        {"Kamui", function() if CORE.kamui then CORE.kamui.trigger("button") end end, 76}}, "Ultimate (60 s recharge) · escape to a safe zone (25 s)")

    -- V2 achievements: ink-stamp seals (persistent counters + this session)
    do
        K.title(startBody, "Seals")
        local card = K.card(startBody, isTouch and 196 or 172)
        local grid = new("Frame", {Parent = card, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(1, -24, 1, -24), ZIndex = 4},
            {new("UIGridLayout", {CellSize = UDim2.new(1 / 3, -8, 0.5, -6), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
        local function st() return settings.stats or {} end
        local function pv(k) local P = CORE.pve return P and P.stats and P.stats[k] or 0 end
        local SEALS = {
            {"Awakened", "Trigger the Guardian Awakening", function() return (tonumber(st().awaken) or 0) >= 1 end},
            {"Kamui", "Escape through the swirl", function() return (tonumber(st().kamui) or 0) >= 1 end},
            {"Puppet Master", "Hold 25 mobs on strings", function() return (tonumber(st().held) or 0) >= 25 end},
            {"Untouchable", "50 clean dodges in one session", function() local S = CORE.sense return S and S.stats and (S.stats.evaded or 0) >= 50 end},
            {"Executioner", "5 Puppet Finishers in one session", function() return pv("finishers") >= 5 end},
            {"Collector", "Loot Grab 20 items in one session", function() return pv("loot") >= 20 end},
        }
        local cells = {}
        for i, sd in ipairs(SEALS) do
            local c = new("Frame", {Parent = grid, BackgroundColor3 = C.bg, BackgroundTransparency = 0.35, LayoutOrder = i, ZIndex = 4}, {corner(2)})
            local cs = stroke(C.line, 1, 0) cs.Parent = c
            label(c, {Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -40, 0, 16), Font = F.bold, Text = sd[1], TextSize = 12, ZIndex = 5, TextTruncate = Enum.TextTruncate.AtEnd})
            label(c, {Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -40, 1, -26), Font = F.reg, Text = sd[2], TextColor3 = C.faint, TextSize = 10,
                TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5})
            -- the stamp: a slanted square seal with a double rim, inked when earned
            local seal = new("Frame", {Parent = c, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 26, 0, 26), Rotation = -12,
                BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 5}, {corner(2)})
            local ss = stroke(Color3.new(1, 1, 1), 1.5, 0.8) ss.Parent = seal
            local inner = new("Frame", {Parent = seal, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6),
                BackgroundTransparency = 1, ZIndex = 5}, {corner(2)})
            local is = stroke(Color3.new(1, 1, 1), 1, 0.85) is.Parent = inner
            local mark = label(seal, {Size = UDim2.fromScale(1, 1), Font = F.black, Text = "", TextSize = 13, TextColor3 = C.ink or Color3.new(0, 0, 0), ZIndex = 6,
                TextXAlignment = Enum.TextXAlignment.Center})
            cells[i] = {seal = seal, ss = ss, is = is, mark = mark, cs = cs, done = false, test = sd[3]}
        end
        task.spawn(function()
            while alive and card.Parent do
                for _, cl in ipairs(cells) do
                    local ok, v = pcall(cl.test)
                    if ok and v and not cl.done then
                        cl.done = true
                        cl.seal.BackgroundTransparency = 0.05
                        cl.ss.Transparency = 0 cl.is.Transparency = 0.4
                        cl.mark.Text = "S"
                        cl.cs.Color = Color3.fromRGB(120, 120, 128)
                        cl.seal.Size = UDim2.new(0, 40, 0, 40)
                        tween(cl.seal, 0.35, {Size = UDim2.new(0, 26, 0, 26), Rotation = -12}, Enum.EasingStyle.Back)
                    end
                end
                task.wait(2)
            end
        end)
    end

    -- Guardian card
    K.title(startBody, "Guardian")
    local gc = K.card(startBody, 170)
    local setRing = H.riskRing(gc, 130, UDim2.new(0, 14, 0.5, -65))
    label(gc, {Position = UDim2.new(0, 158, 0, 12), Size = UDim2.new(1, -170, 0, 18), Font = F.bold, Text = "Risk factors", TextColor3 = C.gold, TextSize = 13, ZIndex = 4})
    local reasonsF = new("Frame", {Parent = gc, BackgroundTransparency = 1, Position = UDim2.new(0, 158, 0, 34), Size = UDim2.new(1, -170, 1, -44), ZIndex = 4, ClipsDescendants = true},
        {new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})
    local lastKey = ""
    guardian.listeners[#guardian.listeners + 1] = function(score, level, reasons)
        setRing(score, level)
        local key = score .. level .. #reasons
        for _, r in ipairs(reasons) do key ..= r[2] end
        if key == lastKey then return end
        lastKey = key
        for _, ch in ipairs(reasonsF:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        for i, r in ipairs(reasons) do
            if i > 6 then break end
            local col = (r[1] == "bad" and C.red) or (r[1] == "warn" and C.yellow) or C.green
            local row = label(reasonsF, {Size = UDim2.new(1, 0, 0, 18), Font = F.medium, TextSize = 12, TextColor3 = col, LayoutOrder = i,
                Text = "    " .. r[2], TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, TextTransparency = 1})
            new("Frame", {Parent = row, BackgroundColor3 = col, BorderSizePixel = 0, Position = UDim2.new(0, 2, 0.5, -2), Size = UDim2.new(0, 4, 0, 4), ZIndex = 6}, {corner(2)})
            task.delay(i * 0.05, function() tween(row, 0.3, {TextTransparency = 0}) end)
        end
    end

    -- Guardian Brain (adaptive learning, threats, situation)
    K.title(startBody, "Guardian Brain")
    local sitCard = K.card(startBody, 58)
    local sitL = label(sitCard, {Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 20), Font = F.black, Text = "Situation: Exploring", TextColor3 = C.gold, TextSize = 14, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd})
    local stratL = label(sitCard, {Position = UDim2.new(0, 14, 0, 30), Size = UDim2.new(1, -28, 0, 18), Font = F.reg, Text = "Normal watch", TextColor3 = C.sub, TextSize = 12, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd})
    local function listCard(title)
        local c = new("Frame", {Parent = startBody, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = K.nextOrder(), ZIndex = 3}, {corner(12), pad(14, 14, 10, 10), new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})
        local s = stroke(C.purple, 1, 0.7) s.Parent = c
        label(c, {Size = UDim2.new(1, 0, 0, 18), Font = F.bold, Text = title, TextColor3 = C.gold, TextSize = 13, LayoutOrder = 0, ZIndex = 4})
        local body = new("Frame", {Parent = c, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 4},
            {new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})})
        return body
    end
    local threatBody = listCard("Player threats")
    local rulesBody = listCard("Learned in this game")
    local function fillList(body, rows)
        for _, ch in ipairs(body:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        for i, r in ipairs(rows) do
            local col = (r[1] == "bad" and C.red) or (r[1] == "warn" and C.yellow) or (r[1] == "ok" and C.green) or C.sub
            label(body, {Size = UDim2.new(1, 0, 0, 17), Font = F.medium, TextSize = 12, TextColor3 = col, LayoutOrder = i, ZIndex = 5, Text = r[2],
                TextTruncate = Enum.TextTruncate.AtEnd})
        end
    end
    local threatSig, rulesSig = nil, nil
    H.refreshBrain = function()
        sitL.Text = "Situation: " .. tostring(brain.situation)
        stratL.Text = (settings.brainOn == false) and "Guardian Brain is off" or tostring(brain.strategy)
        local rows = {}
        local list = {}
        for p, t in pairs(brain.threat or {}) do if t.level ~= "Neutral" then list[#list + 1] = {p, t} end end
        table.sort(list, function(a, b) return a[2].score > b[2].score end)
        for i, e in ipairs(list) do
            if i > 5 then break end
            local p, t = e[1], e[2]
            local bad = t.level == "Enemy" or t.level == "Exploiter"
            rows[#rows + 1] = {bad and "bad" or "warn", string.format("%s  %s · %d%s · %s", (t.level == "Exploiter" and "[X]") or (bad and "[!]") or "[ ]", p.DisplayName,
                math.floor(t.score), t.dist and (" · " .. math.floor(t.dist) .. "m") or "", t.reasons[1] or "watching")}
        end
        if #rows == 0 then rows[1] = {"ok", "Everyone looks neutral"} end
        local sig = ""
        for _, r in ipairs(rows) do sig ..= r[2] end
        if sig ~= threatSig then threatSig = sig fillList(threatBody, rows) end
        local rules = brain.rules and brain.rules() or {}
        local rs = ""
        for _, r in ipairs(rules) do rs ..= r[2] end
        if rs ~= rulesSig then rulesSig = rs fillList(rulesBody, rules) end
        if H.refreshBrainCard then pcall(H.refreshBrainCard) end
    end
    local bs = K.section(startBody, "Brain settings", nil, false)
    K.toggle(bs, "Guardian Brain", "brainOn", function(on) if not on and brain.restoreShield then brain.restoreShield() end end, "Learns hazards, anti-cheat, threats and which attacks work")
    K.toggle(bs, "Auto-limit risky features", "brainLimit", nil, "Caps speed / fly and uses step teleports where the game reacted")
    K.toggle(bs, "Auto-protect (retreat)", "autoProtect", nil, "When a hostile player hurts you: retreat, keep distance, Safe Spot")
    K.toggle(bs, "Threat ESP", "threatEsp", nil, "Colors Watch players yellow, Enemies red")
    K.toggle(bs, "Hazard shield", "hazardShield", function(on) if not on and brain.restoreShield then brain.restoreShield() end end, "Learned hazards stop touching you (client-side)")
    K.toggle(bs, "Auto-use healing tool", "autoHeal", nil, "Equips a heal / food tool from your backpack when low")
    K.title(bs, "Guardian Aggression")
    do
        local lock = K.card(bs, 64)
        lock.LayoutOrder = K.nextOrder()
        H.bossLock = lock
        label(lock, {Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -100, 0, 16), Font = F.bold, Text = spaced("Premium · Boss mode"), TextColor3 = C.goldLight, TextSize = 11, ZIndex = 5})
        label(lock, {Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(1, -100, 0, 28), Font = F.reg, Text = "Free protects. Premium hunts — and shows who's boss.", TextColor3 = C.sub, TextSize = 11, TextWrapped = true, ZIndex = 5})
        local lb = new("TextButton", {Parent = lock, AutoButtonColor = false, Text = "Get Key", Font = F.bold, TextSize = 11, TextColor3 = C.ink,
            BackgroundColor3 = C.gold, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 72, 0, 28), ZIndex = 5}, {corner(6)})
        clickable(lb, openKeyInvite)
        lock.Visible = (HUB.tier ~= "premium")
    end
    label(bs, {Size = UDim2.new(1, 0, 0, 66), Text = "OFF by default. When armed: tools first, then combat keys if possible. Only hostile NPCs (or Enemy players if PvP). Learns winners, drops duds. Verified finishes flash BOSS / DOWN. Pauses on low HP / Lifeline / safe zones.",
        TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
    K.toggle(bs, "Aggression", "aggression", function(on)
        if on and HUB.tier ~= "premium" then
            settings.aggression = false
            saveSettings()
            if K.toggles.aggression then pcall(K.toggles.aggression.render, true) end
            toast("Boss mode is Premium. Get a key to hunt.", "warn", 3)
            openKeyInvite()
            return
        end
        if on then
            if CORE.aggro and CORE.aggro.rebuild then pcall(CORE.aggro.rebuild) end
            if VFX.say then pcall(VFX.say, "aggro_on", nil, 2) end
            toast("Boss mode armed. Learning this game's kit…", "shield", 3)
        else
            if VFX.say then pcall(VFX.say, "aggro_off") end
        end
    end, "Master switch · hunt / dominate when healthy · show them who's boss · Premium")
    K.toggle(bs, "Hunt NPCs", "aggroNpc", nil, "Only hostile / enemy NPCs (never shopkeepers) · learn what hits them")
    K.toggle(bs, "PvP vs Enemies only", "aggroPvp", nil, "ONLY players the Brain already marked Enemy / Exploiter · never randoms · your own attacks")
    K.toggle(bs, "Try one-shot first", "aggroOneShot", nil, "Open with the best learned hit before probing or M1")
    K.toggle(bs, "Kit probe / burst", "aggroSkills", nil, "Tools first, then combat keys if VIM exists · burst only proven hits")
    K.toggle(bs, "Combo / chain fallback", "aggroCombo", nil, "If the first fire fails: try another weapon tool, then M1")
    K.toggle(bs, "Lock-on close-in", "aggroLock", nil, "Dash / steer into range so hits actually connect")
    K.slider(bs, "Aggression range", "aggroRange", 8, 40)
    K.slider(bs, "Burst rate", "aggroRate", 1, 8)
    local aggroStatus = label(bs, {Size = UDim2.new(1, 0, 0, 18), Font = F.medium, TextSize = 12, TextColor3 = C.sub,
        Text = "Aggression: off", LayoutOrder = K.nextOrder(), ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd})
    task.spawn(function()
        while alive and aggroStatus.Parent do
            local AG = CORE.aggro
            local armedNow = HUB.tier == "premium" and settings.aggression == true
            aggroStatus.Text = "Aggression: " .. ((AG and AG.status and AG.status()) or (armedNow and "armed" or (settings.aggression and "needs Premium" or "off")))
            aggroStatus.TextColor3 = armedNow and C.gold or C.sub
            task.wait(0.8)
        end
    end)
    K.title(bs, "Guardian effects")
    K.chipGrid(bs, {{"Aura", "fxAura"}, {"Sixth Sense", "fxSixth"}, {"Hex Shield", "fxHex"}}, 3)
    K.title(bs, "Guardian Voice")
    K.toggle(bs, "Guardian Voice", "voice", function(on) if not on and VFX.voiceOff then VFX.voiceOff() end end, "Typed subtitles at the top · what the Guardian sees and does")
    K.toggle(bs, "Taunts", "voiceTaunts", nil, "Big punch-in after a verified dodge / block / break-free / retreat / NPC")
    K.toggle(bs, "Chat taunts", "voiceChat", nil, "Also sends verified taunts to public chat · max 1 per 8 s, 6 per min · voice lines stay local")
    K.toggle(bs, "Typing sound", "voiceTyping", nil, "Soft tick while the subtitle types · needs Sounds on")
    K.actions(bs, "Voice", {{"Preview", function() if VFX.voicePreview then VFX.voicePreview() end end, 76},
        {"Taunt", function() if VFX.taunt then VFX.taunt("dodge", nil, true) end end, 66}})
    K.actions(bs, "Forget learned data", {{"Forget", function() if brain.forget then brain.forget() end threatSig, rulesSig = nil, nil H.refreshBrain() end, 80, C.red}},
        "Clears hazards, caps, attackers for this game")
    pcall(H.refreshBrain)

    -- Live staff tracker (rows rebuilt only when the staff list changes; distances update in place)
    K.title(startBody, "Live staff tracker")
    local tracker = new("Frame", {Parent = startBody, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = K.nextOrder(), ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local trackerSig, distLabels = nil, {}
    local function refreshTracker()
        local ids = {}
        for id in pairs(guardian.staff) do if Players:GetPlayerByUserId(id) then ids[#ids + 1] = id end end
        table.sort(ids)
        local sig = table.concat(ids, ",")
        local me = hrp()
        if sig ~= trackerSig then
            trackerSig = sig
            distLabels = {}
            for _, ch in ipairs(tracker:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
            for i, id in ipairs(ids) do
                local p = Players:GetPlayerByUserId(id)
                if p then
                    local r = new("Frame", {Parent = tracker, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, ZIndex = 3}, {corner(12)})
                    local s = stroke(C.red, 1.2, 0.3) s.Parent = r pulses[#pulses + 1] = s
                    avatarCircle(r, UDim2.new(0, 8, 0.5, -16), 32, id)
                    label(r, {Position = UDim2.new(0, 50, 0, 7), Size = UDim2.new(1, -60, 0, 18), Font = F.bold, Text = p.DisplayName .. "  @" .. p.Name, TextSize = 12, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd})
                    distLabels[id] = label(r, {Position = UDim2.new(0, 50, 0, 26), Size = UDim2.new(1, -60, 0, 16), Font = F.reg, Text = "", TextColor3 = C.red, TextSize = 11, ZIndex = 4,
                        TextTruncate = Enum.TextTruncate.AtEnd})
                end
            end
            if #ids == 0 then
                local r = new("Frame", {Parent = tracker, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 42), ZIndex = 3}, {corner(12)})
                label(r, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -20, 1, 0), Text = "No staff in this server right now.", TextColor3 = C.green, Font = F.medium, ZIndex = 4})
            end
        end
        for id, l in pairs(distLabels) do
            local p = Players:GetPlayerByUserId(id)
            local t = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            local dist = (t and me) and (math.floor((t.Position - me.Position).Magnitude) .. "m away") or "far / not loaded"
            l.Text = tostring(guardian.staff[id] or "Staff") .. "  ·  " .. dist
        end
    end
    refreshTracker()

    -- Info grid
    K.title(startBody, "Session")
    local infoUpd = {}
    local function info(lbl, getter)
        local r = K.card(startBody, 38)
        label(r, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), Font = F.bold, Text = lbl, TextColor3 = C.sub, TextSize = 12, ZIndex = 4})
        local v = label(r, {Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -14, 1, 0), Font = F.medium, Text = "…", TextSize = 12, ZIndex = 4,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
        local function u() local ok, t = pcall(getter) v.Text = ok and tostring(t) or "-" end
        u() infoUpd[#infoUpd + 1] = u
    end
    info("Account age", function() return LP.AccountAge .. " days" end)
    info("Membership", function() return (LP.MembershipType == Enum.MembershipType.Premium) and "Roblox Premium" or "Standard" end)
    info("Game", function() return GAMEINFO.label() end)
    info("Game module", function() return tostring(GAMEINFO.moduleName or "Universal") .. "  ·  GameId " .. tostring(GAMEINFO.gameId) end)
    info("Place ID", function() return tostring(game.PlaceId) .. ((GAMEINFO.root ~= GAMEINFO.placeId) and ("  ·  root " .. tostring(GAMEINFO.root)) or "") end)
    info("Server", function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers .. " players" end)
    info("Executor", executorName)
    info("Performance", function() return GV.fps .. " FPS · " .. guardian.ping .. " ms" end)
    info("Mode", function() return (PERF.lite and "Performance" or "Full effects") .. " · " .. layoutMode() end)
    -- game module notes (honest per-game limits, e.g. Blox Fruits NPCs)
    if type(GAMEINFO.notes) == "table" and #GAMEINFO.notes > 0 then
        K.title(startBody, "Game module  ·  " .. tostring(GAMEINFO.moduleName or "Universal"))
        for _, n in ipairs(GAMEINFO.notes) do
            local r = K.card(startBody, 44)
            new("Frame", {Parent = r, BackgroundColor3 = C.gold, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.5, -9), Size = UDim2.new(0, 2, 0, 18), ZIndex = 4})
            label(r, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -24, 1, 0), Font = F.medium, Text = tostring(n), TextColor3 = C.sub, TextSize = 11,
                TextWrapped = true, ZIndex = 4})
        end
    end

    -- Game-specific kits live here (not in DXLTA) so DXLTA stays universal
    do
        local isBF = CORE.bfkit and CORE.bfkit.isBF and CORE.bfkit.isBF()
        if isBF and H.buildBloxKit then
            K.title(startBody, "Blox Fruits kit")
            label(K.card(startBody, 40), {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -28, 1, 0), Font = F.reg,
                Text = "Game-only tools. DXLTA stays universal for every title.", TextColor3 = C.sub, TextSize = 11, ZIndex = 4})
            local bfLive = {}
            local function liveRow(sec, name, getter)
                local r = K.card(sec, isTouch and 44 or 38)
                label(r, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), Font = F.bold, Text = name, TextColor3 = C.sub, TextSize = 12, ZIndex = 4})
                local v = label(r, {Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -14, 1, 0), Font = F.medium, Text = "…", TextSize = 12, ZIndex = 4,
                    TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
                local function u() local ok, t = pcall(getter) v.Text = ok and tostring(t) or "-" end
                u() bfLive[#bfLive + 1] = u
            end
            local ok, e = pcall(H.buildBloxKit, startBody, liveRow)
            if not ok then CORE.log("ERR", "Blox Fruits Kit UI: " .. tostring(e)) end
            task.spawn(function()
                while alive and startBody.Parent do
                    for _, u in ipairs(bfLive) do pcall(u) end
                    task.wait(1)
                end
            end)
        end
    end

    -- Quick actions
    K.title(startBody, "Quick actions")
    local qa = new("Frame", {Parent = startBody, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, GV.BTN_H * 2 + 8), LayoutOrder = K.nextOrder(), ZIndex = 3},
        {new("UIGridLayout", {CellSize = UDim2.new(0.5, -4, 0, GV.BTN_H), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
    goldButton(qa, "Safe Spot", {LayoutOrder = 1, ZIndex = 4}, function() if FX.inSafe() then FX.leaveSafe() else FX.goSafe() end end)
    button(qa, "Run last script", {LayoutOrder = 2, ZIndex = 4}, function() if H.runLast then H.runLast() end end)
    button(qa, "Rejoin", {LayoutOrder = 3, ZIndex = 4, BackgroundColor3 = C.purpleDark}, FX.rejoin)
    button(qa, "Copy join script", {LayoutOrder = 4, ZIndex = 4, BackgroundColor3 = C.purpleDark}, function()
        if copy(FX.joinScript()) then toast("Join script copied. Friends can run it to join you.", "ok") else toast("Clipboard not supported.", "bad") end
    end)

    -- News
    K.title(startBody, "News")
    for _, n in ipairs(GV.NEWS) do
        local r = K.card(startBody, 46)
        local chip = new("Frame", {Parent = r, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 12, 0.5, -10), Size = UDim2.new(0, 40, 0, 20), ZIndex = 4}, {corner(6), goldGradient(0)})
        label(chip, {Size = UDim2.fromScale(1, 1), Font = F.black, Text = n[1], TextColor3 = C.ink, TextSize = 10, ZIndex = 5, TextXAlignment = Enum.TextXAlignment.Center})
        label(r, {Position = UDim2.new(0, 62, 0, 0), Size = UDim2.new(1, -72, 1, 0), Font = F.reg, Text = n[2], TextSize = 12, TextWrapped = true, ZIndex = 4})
    end

    local acc = 0
    onHeartbeat("startpage", function(dt)
        acc += dt
        if acc < 1 then return end
        acc = 0
        sessV.Text = fmtTime(os.clock() - (HUB.started or os.clock()))
        if pg.Visible then
            for _, u in ipairs(infoUpd) do pcall(u) end
            refreshTracker()
            pcall(H.refreshBrain)
            H.updateStats()
        end
    end)
    return pg
end

-- =====================================================================
-- 20. DXLTA page
-- =====================================================================
function H.buildDxlta(parent)
    local pg = K.page(parent)
    local liveUpd = {}   -- light text updaters, run once per second while the page is visible
    local function liveRow(sec, name, getter)
        local r = K.card(sec, isTouch and 44 or 38)
        label(r, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), Font = F.bold, Text = name, TextColor3 = C.sub, TextSize = 12, ZIndex = 4})
        local v = label(r, {Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -14, 1, 0), Font = F.medium, Text = "…", TextSize = 12, ZIndex = 4,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
        local function u() local ok, t = pcall(getter) v.Text = ok and tostring(t) or "-" end
        u() liveUpd[#liveUpd + 1] = u
    end

    -- Movement
    local mv = K.section(pg, "Movement", nil, true)
    K.slider(mv, "WalkSpeed", "walkspeed", 16, 250, function(v) local h = hum() if h then h.WalkSpeed = H.brainCap and H.brainCap("walkspeed", v) or v end end)
    K.slider(mv, "JumpPower", "jumppower", 50, 350, function(v) local h = hum() if h then h.UseJumpPower = true h.JumpPower = v end end)
    K.toggle(mv, "Infinite Jump", "infjump")
    K.toggle(mv, "Noclip", "noclip", function(on) if not on then FX.restoreNoclip() end end)
    K.toggle(mv, "Fly", "fly", function(on) if on then FX.startFly() else FX.stopFly() end end, "WASD / joystick · Space/E up · Ctrl/Q down · Up/Down buttons on mobile")
    K.slider(mv, "Fly speed", "flyspeed", 10, 300)
    K.toggle(mv, "Walk on water", "walkwater", nil, "Terrain water + water parts (sea / lake) + learned sea level · ripples · hold Ctrl to dive")
    K.toggle(mv, "Click Teleport", "clicktp", function(on) FX.setClickTp(on) end, isTouch and "Equip the 'Secret TP' tool and tap" or "Hold Left Ctrl and click")
    K.toggle(mv, "Freecam", "freecam", function(on) FX.setFreecam(on) end, "WASD/QE · right mouse to look · drag on mobile")
    K.slider(mv, "Freecam speed", "freecamspeed", 10, 200)

    -- Combat Aim (fixes BF skills missing — face + camera + silent Mouse.Hit + Void Needle)
    do
        local ca = K.section(pg, "Combat Aim", nil, true)
        label(ca, {Size = UDim2.new(1, 0, 0, 56), Text = "On attack (M1 / Z X C V F E / tool): hard-lock nearest target — body + camera snap, Mouse.Hit silent, lead on moving players. PVP needs Aim at players ON (default). Attack ignores FOV so people behind you still lock. Void Needle pulls client-owned mobs onto your blade (BF).",
            TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
        K.toggle(ca, "Combat Aim", "combatAim", function(on)
            if on then
                if CORE.aim and CORE.aim.ensureSilent then pcall(CORE.aim.ensureSilent) end
                toast("Combat Aim on · attack locks nearest player/NPC (hard cam snap)", "shield", 3)
            end
        end, "Master switch · nearest enemy in range · OFF at boot (safe)")
        K.toggle(ca, "Face body", "aimBody", nil, "Rotate your character toward the target")
        K.toggle(ca, "Aim camera", "aimCam", nil, "Hard camera snap on attack (BF skills often read LookVector)")
        K.toggle(ca, "Silent Mouse.Hit", "aimSilent", function(on)
            if on and CORE.aim and CORE.aim.ensureSilent then pcall(CORE.aim.ensureSilent) end
        end, "Skills that read Mouse.Hit · mouse hook only when needed")
        K.toggle(ca, "Void Needle / close gap", "aimMove", nil, "Pull owned mobs onto your blade · else step into melee range")
        K.toggle(ca, "Sticky lock", "aimStick", nil, "Keep aiming while a tool is equipped")
        K.toggle(ca, "Aim at players", "aimPlayers", nil, "ON for PVP · OFF = NPCs / Enemies only")
        K.slider(ca, "Aim range", "aimRange", 15, 150)
        K.slider(ca, "Aim FOV °", "aimFov", 40, 180)
        liveRow(ca, "Aim lock", function() return CORE.aim and CORE.aim.status and CORE.aim.status() or "loading…" end)
    end

    -- Protection
    local pr = K.section(pg, "Protection", nil, true)
    K.actions(pr, "Safe Spot", {{"Go", FX.goSafe, 64}, {"Return", FX.leaveSafe, 80}}, "Shielded platform far above the map")
    local savedPos
    K.actions(pr, "Position", {{"Save", function() local r = hrp() if r then savedPos = r.CFrame toast("Position saved.", "ok") end end, 64},
        {"Return", function() local r = hrp() if r and savedPos then FX.teleport(savedPos) toast("Back to saved position.", "ok") else toast("No saved position.", "bad") end end, 80}})
    K.cycle(pr, "Staff join action", "staffAction", {"None", "Notify", "Go to Safe Spot", "Panic", "Leave game"}, "What Guardian does when staff joins")
    K.toggle(pr, "Panic → Safe Spot", "panicSafeSpot", nil, "Panic also teleports you to the Safe Spot")
    K.toggle(pr, "Anti-Fling", "antifling")
    K.toggle(pr, "Anti-Void", "antivoid", nil, "Returns you when you fall below the map")
    K.toggle(pr, "Anti-AFK", "antiafk")
    K.toggle(pr, "Auto-Rejoin on kick", "autorejoin")

    -- Defense (Guardian, defensive/evasive only)
    local df = K.section(pg, "Defense", nil, true)
    K.toggle(df, "Anti-Death", "antiDeath", function()
        if CORE.ggod and CORE.ggod.applyAntiDeath then CORE.ggod.applyAntiDeath() end
    end, "Default ON · holds Dead state, heal/Soft God, Safe Spot bail · OFF to respawn if stuck")
    K.toggle(df, "Quiet Death", "quietDeath", nil, "Default ON · mute death / fail / low-HP smug voice lines")
    label(df, {Size = UDim2.new(1, 0, 0, 40), Text = "Honest limit: Roblox servers own your HP. Anti-Death is the strongest client bypass (block Dead state + heal remotes + Safe Spot). It is not true immortality — if the server insists you're dead, toggle OFF to respawn.",
        TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
    K.toggle(df, "Guardian Godmode", "godmode", function() FX.applyGodmode() end, "Avoidance-based: state guard, anti-knockback, anti-ragdoll, dodge, rescue, heal, anti-void")
    label(df, {Size = UDim2.new(1, 0, 0, 30), Text = "Guardian Godmode keeps hits from landing and shows below what still got through. Stacks with Anti-Death.",
        TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
    liveRow(df, "Godmode status", function() return CORE.ggod.status and CORE.ggod.status() or "-" end)
    K.toggle(df, "Predictive Dodge", "autododge", nil, "Reads wind-up animations, lunges, projectiles and hitboxes · moves you BEFORE the hit · NPCs + players")
    liveRow(df, "Dodge record", function()
        local st = CORE.sense.stats or {}
        return (st.evaded or 0) .. " clean · " .. (st.hitAnyway or 0) .. " hit anyway"
    end)
    K.toggle(df, "Anti-Grab / Anti-Carry", "antigrab", nil, "Breaks welds, ropes & carry seats other players attach to you")
    K.toggle(df, "Anti-Freeze", "antifreeze", nil, "Repairs anchored root, forced states, 0 WalkSpeed / JumpPower")
    K.toggle(df, "Exploiter Radar", "radar", nil, "Minimap top-right · yellow Watch · red Enemy · pink Exploiter")
    K.toggle(df, "NPC Reset", "npcdef", nil, "Experimental · only counts if the server accepts it · auto-off after 2 local-only results · never players")
    K.toggle(df, "NPC Evade", "npcEvade", nil, "Steps you out of reach when an NPC is actually hitting you · verified")
    if GAMEINFO and GAMEINFO.module and GAMEINFO.module.npcServerSide == false then
        label(df, {Size = UDim2.new(1, 0, 0, 30), Text = "NPC Reset is not supported in " .. tostring(GAMEINFO.clean) .. ": NPCs are server-owned. Use NPC Evade.",
            TextColor3 = C.yellow, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
    end
    -- Puppeteer Mode (4.1)
    local pm = K.section(pg, "Puppeteer Mode", nil, true)
    K.toggle(pm, "Puppeteer Mode", "puppetMove", function(on) if not on and CORE.move.clear then CORE.move.clear("puppet") end end,
        "In combat the hands steer you: out of attack arcs, circle-strafe, distance · your joystick still blends in")
    K.slider(pm, "Puppeteer strength %", "puppetStrength", 0, 100, nil, 5)
    K.cycle(pm, "Combat style", "puppetStyle", {"Duelist", "Evasive", "Kite"}, "Duelist: stay close, sidestep · Evasive: ~18 studs · Kite: ~32 studs")
    K.toggle(pm, "Catch falls", "catchFall", nil, "Hands cup under you and slow long falls onto real ground")
    liveRow(pm, "Steering", function()
        if CORE.move.carrying then return "carrying you" end
        local a = CORE.move.active and CORE.move.active()
        return a and (a .. " · " .. math.floor(CORE.move.steer.Magnitude) .. " st/s") or (CORE.sense.combat and "combat · waiting" or "idle")
    end)
    -- Ability Assist (4.1)
    local ab = K.section(pg, "Ability Assist", nil, false)
    K.toggle(ab, "Ability Assist", "abilAssist", nil, "Uses YOUR dash / block / heal / Ken at the right moment · escape only, never to attack")
    K.toggle(ab, "Allow game buttons", "abilGui", nil, "Also taps on-screen ability buttons (mobile layouts) · off by default")
    liveRow(ab, "Found", function() return CORE.abil.summary and CORE.abil.summary() or "-" end)
    liveRow(ab, "Last used", function() local l = CORE.abil.log or {} return l[1] or "nothing yet" end)
    liveRow(ab, "Key input", function() return (CORE.abil.hasVIM and CORE.abil.hasVIM()) and "VirtualInputManager available" or "not available in this executor" end)
    local mod = GAMEINFO and GAMEINFO.module
    if mod and type(mod.abilities) == "table" then
        for _, a in ipairs(mod.abilities) do
            local key = "key_" .. a.id
            if settings[key] == nil then settings[key] = a.key end
            K.input(ab, a.label .. " key", key, (a.key ~= "" and a.key) or "not set", ((a.key ~= "") and ("Default " .. a.key) or "No default")
                .. " · KeyCode name like E, Q, R · empty = off")
        end
    end
    -- Stalker Shield (4.1)
    local sk = K.section(pg, "Stalker Shield", nil, false)
    K.toggle(sk, "Stalker Shield", "stalker", nil, "Someone keeps hunting you: evade, keep distance, taunt only after a verified escape")
    K.toggle(sk, "Escape to Safe Spot", "stalkerSafe", nil, "When a stalker keeps hitting you or you drop under 50%")
    liveRow(sk, "Stalkers", function() return CORE.stalk.summary and CORE.stalk.summary() or "-" end)
    label(sk, {Size = UDim2.new(1, 0, 0, 30), Text = "Defensive only: Stalker Shield never attacks, flings or damages anyone. It only moves YOU.",
        TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})

    -- Secret Hub V2 (5.0): Awakening + Kamui
    do
        local v2 = K.section(pg, "Guardian Awakening", nil, true)
        label(v2, {Size = UDim2.new(1, 0, 0, 30), Text = "Your ultimate. 20 s of spirit hands, the ink guardian and boosted defence. Players are never touched.",
            TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
        K.actions(v2, "Awakening", {{"Awaken", function() if CORE.awaken then CORE.awaken.start() end end, 86}}, "One tap · 60 s recharge")
        K.toggle(v2, "Include PvE power", "awakenPve", nil, "During the Awakening: Mob Gather and Shadow Strikes on NPCs (pause near players)")
        liveRow(v2, "Awakening", function() return CORE.awaken and CORE.awaken.status() or "-" end)
        K.toggle(v2, "Kamui Escape", "kamui", nil, "In real danger: a swirl pulls you to the nearest known safe zone · verified")
        K.slider(v2, "Kamui below HP %", "kamuiHp", 10, 60)
        K.actions(v2, "Kamui", {{"Escape now", function() if CORE.kamui then CORE.kamui.trigger("button") end end, 96}}, "25 s recharge")
        liveRow(v2, "Kamui", function() return CORE.kamui and CORE.kamui.status() or "-" end)
        K.toggle(v2, "Guardian Radar world layer", "radarWorld", nil, "Radar also shows mobs, loot and safe zones from the Explorer Scanner")
        K.toggle(v2, "Farm Brain (NPCs)", "farm", nil, "Scanner + Mob Gather + your Shadow Strikes + Loot Grab · stops when a player comes close")
        liveRow(v2, "Farm Brain", function() return CORE.farm and CORE.farm.status() or "-" end)
        -- introHands removed in 5.7 (hand curtain intro)
    end

    -- Guardian PvE (4.3): NPCs only, your own attacks only
    do
        local pv = K.section(pg, "Guardian PvE", nil, false)
        local P = function() return CORE.pve or {} end
        label(pv, {Size = UDim2.new(1, 0, 0, 30), Text = "NPCs only. Every hit is your own normal attack or skill. Anything offensive pauses while a real player is within 25 studs or targets you.",
            TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
        K.toggle(pv, "Boss Choreography", "choreo", nil, "Learns each boss attack (timing, reach, shape) and dodges exactly in time · saved per game")
        K.toggle(pv, "Return into range", "choreoReturn", nil, "After a melee dodge the hands guide you back so your combo keeps going")
        K.toggle(pv, "AoE Telegraph", "aoeTele", nil, "Subtle ground ring / line for learned attacks and incoming area hits")
        liveRow(pv, "Learned", function() return P().summary and P().summary() or "-" end)
        K.actions(pv, "Patterns", {{"Forget", function() if P().forget then P().forget() end end, 76, C.red}}, "Clears the learned attacks for this game")
        K.toggle(pv, "Shadow Strikes", "shadowM1", nil, "Your own M1 / tool on the nearest hostile NPC · never players · pauses near players")
        K.slider(pv, "Strike range", "m1Range", 4, 18)
        K.slider(pv, "Strikes per second", "m1Rate", 1, 8)
        K.toggle(pv, "Use recorded combo", "m1Combo", nil, "Shadow Strikes replays your recorded combo every few seconds")
        K.actions(pv, "Combo Recorder", {{"Record", function() if P().recordCombo then P().recordCombo() end end, 76},
            {"Clear", function() if P().clearCombo then P().clearCombo() end end, 64, C.red}}, "Press Record, do your combo, press Record again")
        liveRow(pv, "Combo", function() return P().comboText and P().comboText() or "-" end)
        K.toggle(pv, "Puppet Finisher", "finisher", nil, "NPC under the HP limit: the hands pull you in and your finisher fires")
        K.input(pv, "Finisher key / tool", "finisherKey", "e.g. Z, V or a tool name", "Empty or M1 = your normal attack")
        K.slider(pv, "Finisher HP %", "finisherHp", 3, 30)
        K.toggle(pv, "Mob Gather / Puppet Hold", "puppetHold", function(on) if not on and P().hold then P().hold.releaseAll() end end,
            "Holds nearby hostile NPCs in a tight cluster in front of you for your own M1 / AoE · only mobs this client owns · lets go near players")
        K.slider(pv, "Gather radius", "holdRadius", 10, 60)
        K.slider(pv, "Spawn leash", "holdLeash", 20, 200)
        K.toggle(pv, "Go to mob spawns", "holdGoSpawn", nil, "When nothing is held, short dashes toward the nearest mob cluster (Explorer Scanner)")
        liveRow(pv, "Puppet Hold", function() return P().hold and P().hold.status() or "-" end)
        K.toggle(pv, "Loot Grab", "lootGrab", nil, "After an NPC dies the hands reach out and bring its drops · Item Magnet rules")
        K.toggle(pv, "Stun Breaker", "stunBreak", nil, "Stunned in a fight: uses your own dash / escape skill, else jumps out")
        K.toggle(pv, "Heal Timing", "healTiming", nil, "Heals with your own item / skill in the safe gap between enemy attacks")
        K.slider(pv, "Heal below HP %", "healAt", 10, 90)
        liveRow(pv, "PvE status", function() return P().status and P().status() or "-" end)
    end

    -- DXLTA is universal only — game kits (e.g. Blox Fruits) live on Start when that game is detected

    -- Void Net (universal network-ownership control)
    do
        local vn = K.section(pg, "Void Net", nil, true)
        label(vn, {Size = UDim2.new(1, 0, 0, 48), Text = "Universal physgun for parts THIS client owns (network ownership). Chat: -net · -bring · -hold · -drop · -throw · -orbit. Never touches player characters unless you opt in. Server-owned props just won't move — honest.",
            TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
        K.toggle(vn, "Void Net", "voidNet", function(on)
            if not on and CORE.net and CORE.net.drop then CORE.net.drop(true) end
            if on then toast("Void Net on · aim at a free prop · or type -bring", "shield", 3) end
        end, "Master switch · hold / bring / throw unanchored props you simulate")
        K.toggle(vn, "Chat commands (-net)", "netChat", nil, "Listen for -net / -bring / -hold / -drop / -throw / -orbit in chat")
        K.toggle(vn, "Orbit hold", "netOrbit", nil, "Held props circle you instead of sitting in front")
        K.toggle(vn, "Allow player characters", "netPlayers", nil, "OFF by default · only enable if you want net control of other avatars (risky / flagged)")
        K.slider(vn, "Grab range", "netRange", 10, 80)
        K.actions(vn, "Net", {
            {"Bring", function() if CORE.net and CORE.net.bring then CORE.net.bring() end end, 64},
            {"Hold", function() if CORE.net and CORE.net.hold then CORE.net.hold() end end, 56},
            {"Drop", function() if CORE.net and CORE.net.drop then CORE.net.drop() end end, 56},
            {"Throw", function() if CORE.net and CORE.net.throw then CORE.net.throw() end end, 64},
        }, "Works only when this client owns the part")
        K.toggle(vn, "Void Siphon", "voidSiphon", nil, "Try setnetworkowner / SimulationRadius · claim nearby physics for Net")
        K.actions(vn, "Spectacle", {
            {"Wall", function() if CORE.net and CORE.net.wall then CORE.net.wall() end end, 64},
            {"Pulse", function() if CORE.net and CORE.net.pulse then CORE.net.pulse() end end, 64},
            {"Siphon", function() if CORE.net and CORE.net.siphon then CORE.net.siphon() end end, 64},
        }, "-wall · -pulse · -siphon")
        liveRow(vn, "Net status", function() return CORE.net and CORE.net.status and CORE.net.status() or "loading…" end)
        liveRow(vn, "Ownership", function() return CORE.net and CORE.net.cap and CORE.net.cap() or "-" end)
        liveRow(vn, "Last chat cmd", function() return CORE.net and CORE.net.lastCmd or "-" end)
    end

    -- Void Override suite (learn / amplify / hitbox / parasite / cd / softgod / dominion / maps)
    do
        local rl = K.section(pg, "Void Override", nil, true)
        label(rl, {Size = UDim2.new(1, 0, 0, 56), Text = "Full remote domination suite. Hooks FireServer/InvokeServer, learns your combat traffic, amplifies damage + hitboxes, parasites replicate packets, strips cooldowns, Soft God (heal+iframe), Dominion (Net fling + Override), Game Remote Maps. Everything is verified — Brain drops what the server rejects.",
            TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
        local function needPrem(key, label)
            return function(on)
                if on and HUB.tier ~= "premium" then
                    settings[key] = false saveSettings()
                    if K.toggles[key] then pcall(K.toggles[key].render, true) end
                    toast(label .. " needs Premium Boss mode", "warn", 3)
                end
            end
        end
        K.toggle(rl, "Void Override", "voidOverride", function(on)
            if on then
                if CORE.forge and CORE.forge.ensureHook then pcall(CORE.forge.ensureHook) end
                toast(HUB.tier == "premium" and "Void Override on · full suite unlocked" or "Learn/Amplify on · Premium unlocks Replay/Probe/Dominion", "shield", 3.5)
                if CORE.forge and CORE.forge.applyMaps then pcall(CORE.forge.applyMaps) end
            end
        end, "Master switch · hook installs only when you turn this on")
        K.toggle(rl, "Learn remotes", "ovrLearn", nil, "Capture combat remotes as you attack")
        K.toggle(rl, "Amplify damage", "ovrAmplify", nil, "Multiply damage fields en-route to the server")
        K.slider(rl, "Amplify ×", "ovrAmp", 1, 50)
        K.toggle(rl, "Hitbox inflate", "ovrHitbox", nil, "Multiply range/size/radius/aoe keys on remotes")
        K.slider(rl, "Hitbox ×", "ovrHitboxAmp", 1, 20)
        K.toggle(rl, "Packet Parasite", "ovrParasite", nil, "Mutate Replicate/Bridge/Packet table args live")
        K.toggle(rl, "Game Remote Maps", "ovrMaps", function(on)
            if on and CORE.forge and CORE.forge.applyMaps then
                local n = CORE.forge.applyMaps()
                toast("Mapped " .. tostring(n) .. " remotes for this game", "shield", 2.5)
            end
        end, "Seed known name patterns (BF + universal)")
        K.toggle(rl, "Cooldown Strip", "ovrCdStrip", nil, "Fire cooldown-reset remotes when found/verified")
        K.toggle(rl, "Soft God", "ovrSoftGod", nil, "Verified heal + i-frame remotes under pressure")
        K.toggle(rl, "Heal Override", "ovrHeal", nil, "Heal remotes when hurt (also used by Soft God)")
        K.toggle(rl, "Mirror Ward", "ovrMirror", nil, "When you take damage: fire combat remotes back at the attacker · only counts if their HP drops")
        K.toggle(rl, "Shadow Market", "ovrMarket", function(on)
            if on then
                toast("Shadow Market · prices → 0 on shop remotes · auto-off if this game charges full", "shield", 4)
            end
        end, "Cheapen buy/shop remotes · verifies via currency · auto-off after 3 rejects")
        K.toggle(rl, "Auto Replay (Premium)", "ovrReplay", needPrem("ovrReplay", "Auto Replay"), "Verified combat remotes at hostiles")
        K.toggle(rl, "NPC Probe (Premium)", "ovrProbe", needPrem("ovrProbe", "NPC Probe"), "Probe kill/damage remotes on NPCs")
        K.toggle(rl, "Dominion Combo (Premium)", "ovrDominion", needPrem("ovrDominion", "Dominion"), "Siphon/Net fling + Override strike same rhythm")
        K.toggle(rl, "OneShot bias", "ovrOneShot", nil, "Prefer kill-verified remotes · amp ≥ ×25")
        K.toggle(rl, "Allow PvP targets", "ovrPvp", nil, "OFF by default · also gates Mirror vs players")
        K.slider(rl, "Strike range", "ovrRange", 15, 100)
        K.slider(rl, "Fires / sec", "ovrRate", 1, 12)
        K.actions(rl, "Override", {
            {"Strike", function()
                if HUB.tier ~= "premium" then toast("Strike needs Premium", "warn", 2) return end
                if CORE.forge and CORE.forge.strike then
                    if not CORE.forge.strike(settings.ovrOneShot == true) then
                        toast("Override · " .. tostring(CORE.forge.why ~= "" and CORE.forge.why or "no strike"), "warn", 2.5)
                    end
                end
            end, 64},
            {"Dominion", function()
                if HUB.tier ~= "premium" then toast("Dominion needs Premium", "warn", 2) return end
                if CORE.forge and CORE.forge.dominion then CORE.forge.dominion() end
            end, 80},
            {"Probe", function()
                if HUB.tier ~= "premium" then toast("Probe needs Premium", "warn", 2) return end
                if CORE.forge and CORE.forge.probeOnce then CORE.forge.probeOnce() end
            end, 56},
            {"Maps", function()
                if CORE.forge and CORE.forge.applyMaps then
                    toast("Mapped " .. tostring(CORE.forge.applyMaps()) .. " remotes", "shield", 2)
                end
            end, 56},
            {"Clear", function() if CORE.forge and CORE.forge.clear then CORE.forge.clear() end end, 56, C.red},
        }, "Chat: -dominion · -siphon")
        liveRow(rl, "Override", function() return CORE.forge and CORE.forge.status and CORE.forge.status() or "loading…" end)
        liveRow(rl, "Throughput", function() return CORE.forge and CORE.forge.summary and CORE.forge.summary() or "-" end)

        label(rl, {Size = UDim2.new(1, 0, 0, 96), Text = "Built now: PVP Combat Aim · Anti-Death · Quiet Death · Mirror Ward · Shadow Market. Next krass: Target Priority (lowest HP / closest / looking at you). Skill Redirect — rewrite Z/X/C/V args to locked player CFrame. Ghost Step — brief iframe dash on lethal hit. Second Wind — Soft God+heal+Safe Spot cascade under 10% HP. Chronos Lock — stall NPC think remotes. Echo Barrage — multi-fire best oneshot. Apex Form — Soft God+Dominion+Awakening. Soul Tether — lock owned puppets. Blackout Veil — suppress enemy VFX locally. Fate Reroll — verified loot remount.",
            TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})

        K.actions(rl, "Scout", {
            {"Scan remotes", function()
                if CORE.remotes and CORE.remotes.scan then
                    local n = CORE.remotes.scan()
                    toast("Remote Lab · " .. tostring(n) .. " remotes · Console", "shield", 3)
                end
            end, 110},
            {"Dump hot", function()
                if CORE.remotes and CORE.remotes.dump then
                    local n = CORE.remotes.dump(40)
                    toast("Logged " .. tostring(n) .. " hot remotes · Console", "info", 3)
                end
            end, 90},
        }, "Scout feeds Probe + Maps · Debug console")
        liveRow(rl, "Remotes", function() return CORE.remotes and CORE.remotes.summary and CORE.remotes.summary() or "loading…" end)
        liveRow(rl, "Policy", function() return CORE.remotes and CORE.remotes.policy and CORE.remotes.policy() or "-" end)
    end

    local function fxAt(fn) return function() local r = hrp() if r and VFX[fn] then VFX[fn](r.Position) end end end
    K.actions(df, "Preview FX", {{"Dodge", fxAt("dodge"), 70}, {"Break", fxAt("breakFree"), 64}})
    K.actions(df, "Preview FX ", {{"Shield", fxAt("shield"), 70}, {"Ice", fxAt("unfreeze"), 64}})

    -- Automation
    local au = K.section(pg, "Automation", nil, false)
    K.toggle(au, "Instant prompts", "instantprompts", function() FX.applyInstantPrompts() end, "Hold-to-interact prompts trigger instantly")
    K.toggle(au, "Auto-interact", "autointeract", nil, firePrompt and "Triggers prompts in range (max 3 per tick)" or "Uses prompt hold (your executor has no fireproximityprompt)")
    K.input(au, "Interact filter", "interactFilter", "e.g. collect, open", "Only prompts containing this text (empty = all)")
    K.toggle(au, "Auto-click", "autoclick", nil, "Uses your equipped tool · clicks only while the hub is hidden")
    K.slider(au, "Clicks per second", "clickrate", 1, 20)
    K.toggle(au, "Item Magnet", "magnet", nil, "Pulls nearby coins / drops / tools to you · never NPCs, players or hazards")
    K.slider(au, "Magnet radius", "magnetRadius", 5, 60)
    K.toggle(au, "Ghost Replay (obby)", "ghost", function(on) if not on and VFX.ghostOff then VFX.ghostOff() end end, "Records your successful runs · a glowing ghost runs ahead of you")
    K.actions(au, "Ghost paths", {{"Clear", function() if FX.clearGhostPaths then FX.clearGhostPaths() end end, 70, C.red}}, "Deletes the saved paths for this game")
    liveRow(au, "Prompts found", function() return GV.regBuilt and tostring(FX.promptCount()) or "not scanned yet" end)

    -- Waypoints
    local wp = K.section(pg, "Waypoints", nil, false)
    local wpName = ""
    local _, wpBox = K.input(wp, "New waypoint", nil, "Name (optional)", "Saved for this game only", function(t) wpName = t end)
    local wpListF = new("Frame", {Parent = wp, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 99, ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local function refreshWaypoints()
        for _, ch in ipairs(wpListF:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        local list = FX.wpList()
        for i, w in ipairs(list) do
            local r = new("Frame", {Parent = wpListF, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, GV.ROW_H), LayoutOrder = i, ZIndex = 3}, {corner(12)})
            local s = stroke(C.purple, 1, 0.6) s.Parent = r
            K.rowLabel(r, tostring(w.name), string.format("%d, %d, %d", tonumber(w.x) or 0, tonumber(w.y) or 0, tonumber(w.z) or 0), 140)
            button(r, "Go", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.new(0, 56, 0, GV.BTN_H - 2), TextSize = 12, ZIndex = 4},
                function() FX.tpWaypoint(w) end)
            button(r, "Delete", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 56, 0, GV.BTN_H - 2), TextSize = 11, ZIndex = 4,
                BackgroundColor3 = C.purpleDark, TextColor3 = C.red}, function() FX.delWaypoint(i) refreshWaypoints() end)
        end
        if #list == 0 then
            label(wpListF, {Size = UDim2.new(1, 0, 0, 28), Text = "No waypoints yet for this game.", TextColor3 = C.sub, ZIndex = 4, LayoutOrder = 1})
        end
    end
    K.actions(wp, "Save current position", {{"Add", function()
        if FX.addWaypoint(wpBox.Text ~= "" and wpBox.Text or wpName) then wpBox.Text = "" wpName = "" refreshWaypoints() end
    end, 86}})
    refreshWaypoints()

    -- Players (info + TP / View / ESP per player)
    local pl = K.section(pg, "Players", nil, false)
    local plFilter = ""
    K.input(pl, "Search", nil, "Name…", nil, function(t) plFilter = string.lower(t) if H.refreshPlayers then H.refreshPlayers() end end)
    local plList = new("Frame", {Parent = pl, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 99, ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local friendCache = {}
    local rowInfo = {}
    local function infoText(p)
        local parts = {}
        local flag = guardian.staff[p.UserId] or guardian.suspicious[p.UserId]
        if flag then parts[#parts + 1] = flag end
        parts[#parts + 1] = (tonumber(p.AccountAge) or 0) .. "d old"
        if friendCache[p.UserId] then parts[#parts + 1] = "Friend" end
        local me, t = hrp(), p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        parts[#parts + 1] = (me and t) and (math.floor((t.Position - me.Position).Magnitude) .. "m") or "far"
        return table.concat(parts, " · ")
    end
    local function refreshPlayers()
        for _, ch in ipairs(plList:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        rowInfo = {}
        local list = Players:GetPlayers()
        table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        local shown = 0
        for i, p in ipairs(list) do
            local hay = string.lower(p.DisplayName .. " " .. p.Name)
            if p ~= LP and (plFilter == "" or string.find(hay, plFilter, 1, true)) then
                shown += 1
                local r = new("Frame", {Parent = plList, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = i, ZIndex = 3}, {corner(12)})
                local col = guardian.staff[p.UserId] and C.red or (guardian.suspicious[p.UserId] and C.yellow or C.purple)
                local s = stroke(col, 1, 0.5) s.Parent = r
                avatarCircle(r, UDim2.new(0, 8, 0.5, -17), 34, p.UserId)
                label(r, {Position = UDim2.new(0, 50, 0, 8), Size = UDim2.new(1, -230, 0, 18), Font = F.bold, Text = p.DisplayName, TextSize = 12, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd})
                rowInfo[p] = label(r, {Position = UDim2.new(0, 50, 0, 27), Size = UDim2.new(1, -230, 0, 16), Font = F.reg, TextColor3 = col == C.purple and C.sub or col, TextSize = 11, ZIndex = 4,
                    Text = infoText(p), TextTruncate = Enum.TextTruncate.AtEnd})
                local bw = isTouch and 54 or 50
                local espB
                espB = button(r, FX.espTargeted(p) and "ESP on" or "ESP", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, bw, 0, GV.BTN_H - 2),
                    TextSize = 11, ZIndex = 4, BackgroundColor3 = C.card, TextColor3 = C.gold}, function()
                    espB.Text = FX.toggleEspFor(p) and "ESP on" or "ESP"
                end)
                local viewB
                viewB = button(r, GV.spectating == p and "Stop" or "View", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14 - bw, 0.5, 0), Size = UDim2.new(0, bw, 0, GV.BTN_H - 2),
                    TextSize = 11, ZIndex = 4, BackgroundColor3 = C.purpleDark}, function()
                    viewB.Text = FX.spectate(p) and "Stop" or "View"
                end)
                button(r, "TP", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20 - bw * 2, 0.5, 0), Size = UDim2.new(0, bw, 0, GV.BTN_H - 2), TextSize = 11, ZIndex = 4}, function()
                    if not FX.tpToPlayer(p) then toast("Player not loaded.", "bad") end
                end)
                if friendCache[p.UserId] == nil then
                    friendCache[p.UserId] = false
                    task.spawn(function()
                        local ok, f = pcall(function() return LP:IsFriendsWith(p.UserId) end)
                        friendCache[p.UserId] = ok and f == true
                        if rowInfo[p] and rowInfo[p].Parent then rowInfo[p].Text = infoText(p) end
                    end)
                end
            end
        end
        if shown == 0 then
            label(plList, {Size = UDim2.new(1, 0, 0, 30), Text = (#list <= 1) and "You are alone in this server." or "No player matches.", TextColor3 = C.sub, ZIndex = 4})
        end
    end
    H.refreshPlayers = refreshPlayers
    K.actions(pl, "Player list", {{"Refresh", refreshPlayers, 86}}, "Age · friend · distance · TP / View / ESP")
    refreshPlayers()

    -- Character
    local ch = K.section(pg, "Character", nil, false)
    K.actions(ch, "Character", {{"Reset", FX.resetChar, 66, C.purpleDark}, {"Sit", FX.sit, 54}, {"Unequip", FX.unequip, 78}})
    K.actions(ch, "Accessories", {{"Remove", FX.removeAccessories, 86, C.purpleDark}}, "Removes hats etc. on your screen only")
    K.toggle(ch, "Max camera zoom", "maxzoom", function() FX.applyCamera() end, "Zoom out up to 1000 studs")
    K.toggle(ch, "Camera through walls", "camnoclip", function() FX.applyCamera() end, "Walls turn see-through instead of blocking the camera")

    -- Visuals & World
    local vs = K.section(pg, "Visuals & World", nil, false)
    K.toggle(vs, "ESP (everyone)", "esp", function(on) if not on then FX.clearEsp() end end, "Highlights players · staff red · flagged yellow")
    K.toggle(vs, "Fullbright", "fullbright", function() FX.applyLighting() end)
    K.toggle(vs, "Night vision", "nightvision", function() FX.applyLighting() end, "Brighter, green-tinted view (client only)")
    K.toggle(vs, "X-ray", "xray", function() FX.applyXray() end, "Makes map parts see-through · restores on off")
    local xrTok = 0
    K.slider(vs, "X-ray strength", "xrayAmount", 0.2, 0.9, function()
        if not settings.xray then return end
        xrTok += 1
        local my = xrTok
        task.delay(0.35, function() if my == xrTok then FX.applyXray() end end)
    end, 0.1)
    K.toggle(vs, "Remove fog", "nofog", function() FX.applyLighting() end)
    K.toggle(vs, "Custom time of day", "timeOverride", function() FX.applyLighting() end)
    K.slider(vs, "Time of day", "clock", 0, 24, function() if settings.timeOverride then FX.applyLighting() end end, 0.5)
    K.slider(vs, "Field of View", "fov", 40, 120, function() FX.applyFov() end)
    K.toggle(vs, "Custom gravity", "gravityOverride", function() FX.applyGravity() end)
    K.slider(vs, "Gravity", "gravity", 0, 400, function() if settings.gravityOverride then FX.applyGravity() end end)
    K.toggle(vs, "FPS boost (low graphics)", "lowgfx", function() FX.applyLowGfx() end, "Disables shadows and particles")
    K.toggle(vs, "FPS & ping HUD", "hud", function(on) hud.Visible = on end)
    H.buildEffects(pg)

    -- Server
    local sv = K.section(pg, "Server", nil, false)
    liveRow(sv, "Players", function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers end)
    liveRow(sv, "Ping · FPS", function() return guardian.ping .. " ms · " .. GV.fps .. " FPS" end)
    liveRow(sv, "Server uptime", function() return fmtTime(workspace.DistributedGameTime) end)
    liveRow(sv, "Your session", function() return fmtTime(os.clock() - (HUB.started or os.clock())) end)
    liveRow(sv, "Place version", function() return "v" .. tostring(game.PlaceVersion) end)
    K.actions(sv, "Server", {{"Rejoin", FX.rejoin, 76}})
    K.actions(sv, "Job ID", {{"Copy", function() if copy(game.JobId) then toast("Job ID copied!", "ok") else toast("Clipboard not supported.", "bad") end end, 70}},
        string.sub(game.JobId, 1, 20) .. "…")
    K.actions(sv, "Place ID", {{"Copy", function() if copy(tostring(game.PlaceId)) then toast("Place ID copied!", "ok") else toast("Clipboard not supported.", "bad") end end, 70}},
        tostring(game.PlaceId))
    K.actions(sv, "Join script", {{"Copy", function() if copy(FX.joinScript()) then toast("Join script copied! Friends can run it to join you.", "ok") else toast("Clipboard not supported.", "bad") end end, 70}},
        "Lets friends join this exact server")

    -- once-per-second light updates while visible
    local acc = 0
    onHeartbeat("dxltapage", function(dt)
        acc += dt
        if acc < 1 then return end
        acc = 0
        if not pg.Visible then return end
        for _, u in ipairs(liveUpd) do pcall(u) end
        for p, l in pairs(rowInfo) do if l.Parent then l.Text = infoText(p) end end
    end)

    -- apply saved states
    task.defer(function()
        FX.applyLighting() FX.applyGravity() FX.applyFov()
        if settings.lowgfx then FX.applyLowGfx() end
        if settings.fly then FX.startFly() end
        if settings.clicktp then FX.setClickTp(true) end
        if settings.instantprompts or settings.autointeract then FX.applyInstantPrompts() end
        if settings.xray then FX.applyXray() end
        if settings.maxzoom or settings.camnoclip then FX.applyCamera() end
        settings.freecam = false
    end)
    return pg
end

-- Blox Fruits Kit UI — NOT in DXLTA (DXLTA is universal). Shown on Start when BF is detected.
function H.buildBloxKit(pg, liveRow)
    local B = function() return CORE.bfkit or {} end
    local isBF = B().isBF and B().isBF()
    local function note(sec, text, col)
        label(sec, {Size = UDim2.new(1, 0, 0, 30), Text = text, TextColor3 = col or C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
    end
    -- Farm
    local fm = K.section(pg, "Blox Fruits · Farm", nil, isBF == true)
    if not isBF then note(fm, "These tools only run in Blox Fruits. This game: " .. tostring(GAMEINFO and GAMEINFO.clean or "?") .. ".", C.yellow) end
    note(fm, "NPCs only. Every hit is your own normal attack with your weapon. Movement is a smooth tween, never an instant teleport. Attacking pauses while a real player is within 25 studs.")
    K.toggle(fm, "Level Farm", "bfFarm", function(on) if not on and B().stopTravel then B().stopTravel() end end,
        "Flies to the mob your quest (or your level) asks for and fights it with your own attacks · Lifeline takes over when you get hurt")
    K.cycle(fm, "Weapon", "bfWeapon", {"Melee", "Sword", "Blox Fruit", "Gun"}, "Equipped automatically (game ToolTip) · an uneaten fruit is never touched")
    K.toggle(fm, "Auto Quest  ·  game remote", "bfQuest", nil, "Takes the quest for your level from its quest giver via the game's own CommF_ StartQuest · optional")
    K.slider(fm, "Tween speed (studs/s)", "bfSpeed", 60, 300, nil, 10)
    liveRow(fm, "Farm", function() return B().status and B().status() or "-" end)
    liveRow(fm, "Record", function() return B().farmStats and B().farmStats() or "-" end)
    liveRow(fm, "Quest", function() return (B().questText and B().questText()) or "no quest active" end)
    liveRow(fm, "You", function() return B().playerStatus and B().playerStatus() or "-" end)
    K.actions(fm, "Movement", {{"Stop tween", function() if B().stopTravel then B().stopTravel() toast("Tween stopped.", "info", 1.6) end end, 104, C.red}}, "Cancels any tween right away")
    -- Fruits & chests
    local fr = K.section(pg, "Blox Fruits · Fruits & Chests", nil, false)
    K.toggle(fr, "Fruit Notifier", "bfFruitNotify", nil, "A notice + voice line when a fruit appears in the world (name + distance)")
    K.toggle(fr, "Fruit ESP", "bfFruitEsp", nil, "Name + distance tag on every fruit in the world, through walls")
    K.toggle(fr, "Fruit Sniper (tween)", "bfFruitSnipe", nil, "New fruit in the world: tweens you to it and you pick it up · beats the farm")
    K.actions(fr, "Nearest fruit", {{"Tween", function() if B().goFruit then B().goFruit() end end, 76}})
    liveRow(fr, "Fruits", function() return B().fruitStatus and B().fruitStatus() or "-" end)
    K.toggle(fr, "Chest Collector (tween)", "bfChest", function(on) if not on and B().stopTravel then B().stopTravel() end end, "Flies chest to chest on your island · runs when Level Farm is off")
    K.actions(fr, "Nearest chest", {{"Tween", function() if B().goChest then B().goChest() end end, 76}})
    -- Character
    local cs = K.section(pg, "Blox Fruits · Character", nil, false)
    K.toggle(cs, "Auto Buso Haki", "bfBuso", nil, "Turns Armament on when it is off (Buso key J, or the game remote below)")
    K.cycle(cs, "Buso via", "bfBusoVia", {"J key", "Game remote"}, "Game remote = the game's own CommF_ \"Buso\"")
    K.toggle(cs, "Ken after respawn", "bfKen", nil, "Presses your Ken key (E) once per life · the game shows no readable Ken state, so no blind re-press")
    K.toggle(cs, "Auto Stats  ·  game remote", "bfStats", nil, "Spends free stat points via the game's own CommF_ AddPoint · optional")
    K.cycle(cs, "Stat", "bfStat", {"Melee", "Defense", "Sword", "Gun", "Fruit", "Melee + Defense"}, "Where your points go")
    -- Islands
    local il = K.section(pg, "Blox Fruits · Island Tween", nil, false)
    note(il, "Islands of this sea, read from the game's location markers. Smooth flight at your tween speed, never an instant teleport.")
    local listF = new("Frame", {Parent = il, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 999, ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local function refresh()
        for _, ch in ipairs(listF:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        local list = B().islands and B().islands() or {}
        if #list == 0 then
            label(listF, {Size = UDim2.new(1, 0, 0, 26), Text = "No island markers loaded yet (Blox Fruits only).", TextColor3 = C.sub, TextSize = 11, ZIndex = 4})
            return
        end
        for i, it in ipairs(list) do
            if i > 24 then break end
            local r = new("Frame", {Parent = listF, BackgroundColor3 = C.card, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, GV.ROW_H), LayoutOrder = i, ZIndex = 3}, {corner(10)})
            stroke(C.line, 1, 0.1).Parent = r
            K.rowLabel(r, it.name, math.floor(it.dist) .. " m", 90)
            button(r, "Go", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 56, 0, GV.BTN_H - 2), TextSize = 12, ZIndex = 4},
                function() if B().goIsland then B().goIsland(it) end end)
        end
    end
    K.actions(il, "Islands", {{"Refresh", refresh, 80}, {"Stop", function() if B().stopTravel then B().stopTravel() end end, 64, C.red}})
    task.defer(function() pcall(refresh) end)
end

-- Visuals → Effects (signature FX, all local-only)
function H.buildEffects(pg)
    local ef = K.section(pg, "Effects", nil, true)
    local function pv(name) return function() if VFX.preview then VFX.preview(name) end end end
    K.toggle(ef, "Aura Mode", "fxAura", nil, "Subtle ground ring + wisps · warms only when health is critical · off by default")
    K.toggle(ef, "Awakening intro", "fxAwaken", nil, "Cinematic start after loading · only in a safe moment")
    K.toggle(ef, "Sixth Sense", "fxSixth", nil, "Time-slow flash + red outline when an enemy gets close")
    K.toggle(ef, "Sharingan Sight", "fxSharingan", nil, "White slit eyes · red outline on the attacker that winds up · white attack line")
    K.toggle(ef, "Heartbeat sound", "fxHeartbeat", nil, "Sixth Sense heartbeat · needs Sounds on")
    K.toggle(ef, "Lightning Teleport", "fxBolt", nil, "Implosion at start, lightning strike on arrival")
    K.toggle(ef, "Hex Shield", "fxHex", nil, "Hexagon shield shatters when Godmode / Anti-Grab blocks")
    K.toggle(ef, "Domain Expansion", "fxDomain", nil, "Huge local dome · 6 s · 15 s cooldown")
    K.actions(ef, "Domain Expansion", {{"Expand", function() if VFX.domain then VFX.domain() end end, 84, C.purpleDark}},
        (settings.binds.domain or "") ~= "" and ("Keybind: " .. settings.binds.domain) or "Set a keybind in Settings → Keybinds")
    K.toggle(ef, "God Form", "fxGodForm", nil, "Transformation: rising, flames, glowing eyes, rings · needs ≥90% health")
    K.actions(ef, "God Form", {{"Transform", function() if VFX.godForm then VFX.godForm() end end, 92, C.goldDark}},
        (settings.binds.godform or "") ~= "" and ("Keybind: " .. settings.binds.godform) or "Tap again to power down · keybind in Settings")
    K.toggle(ef, "Guardian Voice", "voice", function(on) if not on and VFX.voiceOff then VFX.voiceOff() end end, "Typed subtitles at the top of the screen")
    K.toggle(ef, "Taunts", "voiceTaunts", nil, "Punch-in after verified dodges / blocks / break-frees")
    K.toggle(ef, "Chat taunts", "voiceChat", nil, "Also posts verified taunts in public chat (playful lines only)")
    K.title(ef, "Guardian Control")
    K.toggle(ef, "Guardian Control", "handsOn", function(on) if not on and VFX.handsOff then VFX.handsOff() end end, "Guardian briefly moves you to save you · voice + Takeover · no hand models")
    K.toggle(ef, "Lifeline Rescue", "handsRescue", nil, "On damage the Guardian flies YOU out of reach (high ground or the air) and keeps you away until you heal")
    K.toggle(ef, "Companion hold (NPCs)", "handsGrab", nil, "Hold the NPC that hurts you in the air, set it down far away · never players · no hand puppet")
    K.toggle(ef, "Water Guard", "waterGuard", nil, "Solid surface at sea level while Guardian Control is on (Blox Fruits sea) · Walk on Water still covers every game")
    K.slider(ef, "Lifeline starts at (% health)", "rescueStart", 20, 80, nil, 1)
    K.slider(ef, "Stay away until (% health)", "rescueSafe", 50, 100, nil, 5)
    K.slider(ef, "Rescue threshold (% health)", "rescueThreshold", 15, 70, nil, 1)
    K.toggle(ef, "Auto Lift (obby)", "handsLift", nil, "Lifts you onto a ledge you jump at")
    K.actions(ef, "Control", {{"Lift", function() if VFX.handsLift then VFX.handsLift(true) end end, 56},
        {"Rescue", function() if VFX.handsRescue then if not VFX.handsRescue(true) then toast("Rescue not possible right now.", "info", 1.6) end end end, 70}},
        (settings.binds.lift or "") ~= "" and ("Lift keybind: " .. settings.binds.lift) or "Lift keybind in Settings → Keybinds")
    K.actions(ef, "Preview", {{"Aura", pv("aura"), 58}, {"Intro", pv("awaken"), 58}, {"Sense", pv("sense"), 62}})
    K.actions(ef, "Preview ", {{"Bolt", pv("bolt"), 58}, {"Hex", pv("hex"), 52}, {"Domain", pv("domain"), 70}})
    K.actions(ef, "Preview  ", {{"Voice", pv("voice"), 58}, {"God", pv("godform"), 52}})
    K.actions(ef, "FX Showcase", {{"Play", function() if VFX.showcase then VFX.showcase() end end, 70, C.goldDark}}, "Plays every effect in a row · ~25 s")
    label(ef, {Size = UDim2.new(1, 0, 0, 30), Text = "Effects are only visible to you · lighter in Performance Mode · all removed on Panic / Unload. Hand models were removed in Void Hub 5.7.",
        TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
end

-- =====================================================================
-- 21. Scripts page
-- =====================================================================
local function isKeyed(x) return x.key == true or (x.keyless == false and x.key ~= false) end
local function favIndex(slug) for i, f in ipairs(favs) do if f.slug == slug then return i end end return nil end
local function slim(x)
    return {slug = x.slug, title = x.title, game = x.game and {name = x.game.name, gameId = x.game.gameId, imageUrl = x.game.imageUrl} or nil,
        key = x.key, keyless = x.keyless, verified = x.verified, views = x.views, image = x.image}
end
local function scriptImage(x)
    -- ScriptBlox thumbnails are web URLs (not usable in ImageLabels), so use the Roblox game icon
    local gid = x.game and tonumber(x.game.gameId)
    if gid and gid > 0 then return "rbxthumb://type=GameIcon&id=" .. gid .. "&w=150&h=150" end
    return ""
end

function H.execute(x)
    local src = x.script
    local d
    if x.slug then
        local detail = cachedJSON(GV.SB .. "/api/script/" .. enc(x.slug), 300)
        d = detail and type(detail.script) == "table" and detail.script or nil
        if d and type(d.script) == "string" and d.script ~= "" then src = d.script end
    end
    if type(src) ~= "string" or src == "" then
        src = 'loadstring(game:HttpGet("' .. GV.SB .. '/raw/' .. tostring(x.slug) .. '"))()'
    end
    if isKeyed(x) then
        local link = d and d.keyLink
        if link and link ~= "" and copy(link) then toast("This script needs a key. Key link copied!", "warn", 4)
        else toast("This script needs a key. Follow its key system.", "warn", 4) end
    end
    local loader = loadstring
    local fn, cerr = loader(src)
    if not fn then toast("Script failed to compile: " .. tostring(cerr):sub(1, 60), "bad") return end
    local closing = settings.closeAfterRun ~= false
    local name = tostring(x.title or "script")
    if #name > 40 then name = name:sub(1, 39) .. "…" end
    -- history
    for i = #history, 1, -1 do if history[i].slug == x.slug then table.remove(history, i) end end
    local h = slim(x) h.at = os.time()
    table.insert(history, 1, h)
    while #history > 25 do table.remove(history) end
    save(GV.HIST_FILE, jsonEncode(history))
    settings.stats.runs = (settings.stats.runs or 0) + 1
    saveSettings()
    if H.updateStats then pcall(H.updateStats) end
    -- launch the script first in its own thread so unloading the hub can't affect it
    task.spawn(function()
        local ok, e = pcall(fn)
        if not ok then
            CORE.log("ERR", "script error: " .. tostring(e))
            toast("Script error: " .. tostring(e):sub(1, 80), "bad")
        end
    end)
    if closing then
        -- hub disappears right after launching: UI destroyed, connections cut, all features off
        toast("Launching " .. name .. "...", "ok", 0.45)
        task.delay(0.4, function() if alive then pcall(H.unload, true) end end)
    else
        toast("Executing " .. name .. "…", "ok")
    end
end
function H.runLast()
    if history[1] then H.execute(history[1]) else toast("No script in history yet.", "warn") end
end
local function toggleFav(x)
    local idx = favIndex(x.slug)
    if idx then table.remove(favs, idx) toast("Removed from favorites", "info")
    else table.insert(favs, 1, slim(x)) toast("Added to favorites", "star") end
    save(GV.FAV_FILE, jsonEncode(favs))
    if H.updateStats then pcall(H.updateStats) end
    return favIndex(x.slug) ~= nil
end

function H.buildScripts(parent)
    local root = new("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3})
    -- Sub tabs
    local tabs = {"This Game", "Trending", "Universal", "Search", "Favorites", "History"}
    local subBar = new("ScrollingFrame", {Parent = root, BackgroundColor3 = C.bg, BackgroundTransparency = 0.35, Size = UDim2.new(1, 0, 0, 36), ZIndex = 3, ScrollingEnabled = true,
        ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), BorderSizePixel = 0},
        {corner(10), new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center}), pad(4, 4, 0, 0)})
    -- Filter chips
    local chipBar = new("Frame", {Parent = root, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 28), ZIndex = 3},
        {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local filters = {keyless = false, verified = false, sort = "views"}
    local searchF = new("Frame", {Parent = root, BackgroundColor3 = C.card, BackgroundTransparency = 0.2, Position = UDim2.new(0, 0, 0, 76), Size = UDim2.new(1, 0, 0, 36),
        Visible = false, ZIndex = 3}, {corner(10)})
    local ss = stroke(C.purple, 1.2, 0.3) ss.Parent = searchF
    do  -- drawn magnifier (hairline ring + handle)
        local mg = new("Frame", {Parent = searchF, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0.5, -7), Size = UDim2.new(0, 14, 0, 14), ZIndex = 4})
        local ring = new("Frame", {Parent = mg, BackgroundTransparency = 1, Size = UDim2.new(0, 10, 0, 10), ZIndex = 4}, {corner(5)})
        local rs = stroke(C.goldLight, 1.5, 0) rs.Parent = ring
        new("Frame", {Parent = mg, BackgroundColor3 = C.goldLight, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 11, 0, 11),
            Size = UDim2.new(0, 5, 0, 2), Rotation = 45, ZIndex = 4})
    end
    local searchBox = new("TextBox", {Parent = searchF, BackgroundTransparency = 1, Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -44, 1, 0),
        Font = F.medium, PlaceholderText = "Search scripts…", PlaceholderColor3 = C.sub, Text = "", ClearTextOnFocus = false,
        TextColor3 = C.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4})
    local list = new("ScrollingFrame", {Parent = root, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 76), Size = UDim2.new(1, 0, 1, -76),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = isTouch and 5 or 3, ScrollBarImageColor3 = C.gold, BorderSizePixel = 0, ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}), pad(0, 8, 2, 10)})

    local state = {tab = 1, page = 1, totalPages = 1, loading = false, token = 0, items = 0}
    local function clear()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        state.items = 0
    end
    local function message(text)
        label(list, {Size = UDim2.new(1, 0, 0, 70), Font = F.medium, Text = text, TextColor3 = C.sub, TextSize = 14, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 99999, ZIndex = 4})
    end
    local function skeletons(n)
        local holder = new("Frame", {Name = "Skeletons", Parent = list, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 99998, ZIndex = 3}, {new("UIListLayout", {Padding = UDim.new(0, 8)})})
        for _ = 1, n or 4 do
            local f = new("Frame", {Parent = holder, BackgroundColor3 = C.card, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 92), ClipsDescendants = true, ZIndex = 3}, {corner(12)})
            new("Frame", {Parent = f, BackgroundColor3 = C.glass, Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 72, 0, 72), ZIndex = 4}, {corner(10)})
            new("Frame", {Parent = f, BackgroundColor3 = C.glass, Position = UDim2.new(0, 94, 0, 16), Size = UDim2.new(0.5, 0, 0, 12), ZIndex = 4}, {corner(6)})
            new("Frame", {Parent = f, BackgroundColor3 = C.glass, Position = UDim2.new(0, 94, 0, 38), Size = UDim2.new(0.35, 0, 0, 10), ZIndex = 4}, {corner(5)})
            local sh = new("Frame", {Parent = f, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, Size = UDim2.new(0.35, 0, 1, 0), Position = UDim2.new(-0.4, 0, 0, 0), ZIndex = 5},
                {new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})})
            if not PERF.lite then task.spawn(function()
                while alive and sh.Parent do
                    sh.Position = UDim2.new(-0.4, 0, 0, 0)
                    tween(sh, 0.9, {Position = UDim2.new(1.1, 0, 0, 0)}, Enum.EasingStyle.Sine)
                    task.wait(1.05)
                end
            end) end
        end
        return holder
    end
    local function badge(parent, text, col)
        local b = new("Frame", {Parent = parent, BackgroundColor3 = col, BackgroundTransparency = 0.78, Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5},
            {corner(6), pad(7, 7, 0, 0)})
        label(b, {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Font = F.bold, Text = text, TextColor3 = col, TextSize = 10, ZIndex = 6})
        return b
    end

    -- Detail sheet
    local sheet = new("Frame", {Parent = root, BackgroundColor3 = C.bg, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20})
    local sheetCard = new("Frame", {Parent = sheet, BackgroundColor3 = C.panel, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 1, -10), ZIndex = 21}, {corner(16)})
    animatedBorder(sheetCard, 1.5)
    -- Run confirmation sheet (small, bottom)
    local confirm = new("TextButton", {Parent = root, AutoButtonColor = false, Text = "", BackgroundColor3 = C.bg, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Visible = false, ZIndex = 30})
    local confirmCard = new("Frame", {Parent = confirm, BackgroundColor3 = C.panel, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 31}, {corner(16), pad(16, 16, 14, 14),
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
    do local s = stroke(C.gold, 1.2, 0.3) s.Parent = confirmCard end
    local function closeConfirm()
        tween(confirm, 0.15, {BackgroundTransparency = 1})
        task.delay(0.15, function() confirm.Visible = false end)
    end
    bind(confirm.Activated:Connect(closeConfirm))
    local function openConfirm(x)
        for _, c in ipairs(confirmCard:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        confirm.Visible = true
        tween(confirm, 0.15, {BackgroundTransparency = 0.35})
        label(confirmCard, {Size = UDim2.new(1, 0, 0, 22), Font = F.black, Text = "Run this script?", TextColor3 = C.gold, TextSize = 16, LayoutOrder = 1, ZIndex = 32})
        label(confirmCard, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = F.bold, Text = tostring(x.title or "Untitled"), TextSize = 13,
            TextWrapped = true, LayoutOrder = 2, ZIndex = 32})
        local info = {}
        info[#info + 1] = isKeyed(x) and "Key required" or "Keyless"
        if x.verified then info[#info + 1] = "Verified" end
        info[#info + 1] = (x.game and x.game.name) and stripGlyphs(tostring(x.game.name)) or "Universal"
        label(confirmCard, {Size = UDim2.new(1, 0, 0, 16), Font = F.medium, Text = table.concat(info, "  ·  "), TextColor3 = C.sub, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 3, ZIndex = 32})
        label(confirmCard, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = F.reg, TextWrapped = true, TextColor3 = C.sub, TextSize = 11,
            Text = "Community scripts from ScriptBlox. Only run scripts you trust." .. (settings.closeAfterRun ~= false and " The hub closes after launching." or ""),
            LayoutOrder = 4, ZIndex = 32})
        local row = new("Frame", {Parent = confirmCard, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, GV.BTN_H + 4), LayoutOrder = 5, ZIndex = 32},
            {new("UIGridLayout", {CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.new(0, 8, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder})})
        goldButton(row, "Run", {LayoutOrder = 1, ZIndex = 33, TextSize = 14}, function() closeConfirm() H.execute(x) end)
        button(row, "Always run", {LayoutOrder = 2, ZIndex = 33, BackgroundColor3 = C.purpleDark, TextColor3 = C.gold, TextSize = 12}, function()
            settings.confirmRun = false saveSettings()
            if K.toggles.confirmRun then K.toggles.confirmRun.render(true) end
            closeConfirm() H.execute(x)
        end)
        button(row, "Cancel", {LayoutOrder = 3, ZIndex = 33, BackgroundColor3 = C.card, TextSize = 12}, closeConfirm)
    end
    H.confirmRun = function(x) if settings.confirmRun then openConfirm(x) else H.execute(x) end end
    local function closeSheet()
        tween(sheetCard, 0.3, {Position = UDim2.new(0, 0, 1, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tween(sheet, 0.3, {BackgroundTransparency = 1})
        task.delay(0.3, function() sheet.Visible = false end)
    end
    local function openSheet(x)
        for _, c in ipairs(sheetCard:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        sheet.Visible = true
        tween(sheet, 0.3, {BackgroundTransparency = 0.4})
        sheetCard.Position = UDim2.new(0, 0, 1, 0)
        tween(sheetCard, 0.22, {Position = UDim2.new(0, 0, 0, 10)})
        local img = new("ImageLabel", {Parent = sheetCard, BackgroundColor3 = C.card, Position = UDim2.new(0, 16, 0, 16), Size = UDim2.new(0, 96, 0, 96),
            Image = scriptImage(x), ScaleType = Enum.ScaleType.Crop, ZIndex = 22}, {corner(12)})
        local is = stroke(C.gold, 1.5, 0.3) is.Parent = img
        local t = label(sheetCard, {Position = UDim2.new(0, 124, 0, 16), Size = UDim2.new(1, -180, 0, 44), Font = F.black, Text = tostring(x.title or "Untitled"), TextSize = 17,
            TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 22})
        shimmerText(t)
        label(sheetCard, {Position = UDim2.new(0, 124, 0, 62), Size = UDim2.new(1, -140, 0, 16), Font = F.reg, TextColor3 = C.sub, TextSize = 12, ZIndex = 22,
            Text = (x.game and x.game.name) and stripGlyphs(tostring(x.game.name)) or "Universal", TextTruncate = Enum.TextTruncate.AtEnd})
        local badges = new("Frame", {Parent = sheetCard, BackgroundTransparency = 1, Position = UDim2.new(0, 124, 0, 86), Size = UDim2.new(1, -140, 0, 20), ZIndex = 22},
            {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)})})
        badge(badges, isKeyed(x) and "KEY" or "KEYLESS", isKeyed(x) and C.yellow or C.green)
        if x.verified then badge(badges, "VERIFIED", C.purple) end
        local closeB = new("TextButton", {Parent = sheetCard, AutoButtonColor = false, Text = "",
            BackgroundColor3 = C.card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 30, 0, 30), ZIndex = 23}, {corner(8)})
        do local cs = stroke(C.line, 1, 0) cs.Parent = closeB iconCross(closeB, 9, C.red, 24) end
        clickable(closeB, closeSheet)
        local statsL = label(sheetCard, {Position = UDim2.new(0, 16, 0, 122), Size = UDim2.new(1, -32, 0, 18), Font = F.bold, TextColor3 = C.gold, TextSize = 12, ZIndex = 22,
            Text = fmtNum(x.views) .. " views   ·   loading details…"})
        local descF = new("ScrollingFrame", {Parent = sheetCard, BackgroundColor3 = C.card, BackgroundTransparency = 0.3, Position = UDim2.new(0, 16, 0, 146), Size = UDim2.new(1, -32, 1, -214),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.gold, BorderSizePixel = 0, ZIndex = 22}, {corner(10), pad(10, 10, 8, 8)})
        local desc = label(descF, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = F.reg, TextSize = 12, TextWrapped = true, TextColor3 = C.text,
            TextYAlignment = Enum.TextYAlignment.Top, Text = "Loading…", ZIndex = 23})
        local btnRow = new("Frame", {Parent = sheetCard, BackgroundTransparency = 1, Position = UDim2.new(0, 16, 1, -58), Size = UDim2.new(1, -32, 0, 42), ZIndex = 22},
            {new("UIGridLayout", {CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.new(0, 8, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder})})
        goldButton(btnRow, "Execute", {LayoutOrder = 1, ZIndex = 23, TextSize = 14}, function() closeSheet() H.execute(x) end)
        local favB
        favB = button(btnRow, favIndex(x.slug) and "Saved" or "Favorite", {LayoutOrder = 2, ZIndex = 23, BackgroundColor3 = C.purpleDark, TextColor3 = C.gold}, function()
            local on = toggleFav(x)
            favB.Text = on and "Saved" or "Favorite"
        end)
        local keyLink
        local keyB = button(btnRow, "Key link", {LayoutOrder = 3, ZIndex = 23, BackgroundColor3 = C.card}, function()
            if not keyLink then toast("No key link for this script.", "info") return end
            if copy(keyLink) then toast("Key link copied!", "ok") else toast(keyLink, "info", 6) end
        end)
        task.spawn(function()
            local data = x.slug and cachedJSON(GV.SB .. "/api/script/" .. enc(x.slug), 300)
            local d = data and type(data.script) == "table" and data.script
            if not sheetCard.Parent or not sheet.Visible then return end
            if not d then desc.Text = "Couldn't load details. You can still execute the script." statsL.Text = fmtNum(x.views) .. " views" return end
            local updated = (type(d.updates) == "table" and type(d.updates[1]) == "table" and d.updates[1].at) or d.updatedAt or d.lastBump or d.createdAt
            statsL.Text = fmtNum(d.views or x.views) .. " views   ·   " .. fmtNum(d.likeCount) .. " likes   ·   " .. fmtNum(d.dislikeCount) .. " dislikes   ·   updated " .. fmtDate(updated)
            local parts = {}
            if type(d.owner) == "table" and d.owner.username then parts[#parts + 1] = "By " .. tostring(d.owner.username) .. (d.owner.verified and "  (verified)" or "") end
            if type(d.features) == "string" and d.features ~= "" then parts[#parts + 1] = "Features\n" .. d.features end
            if type(d.description) == "string" and d.description ~= "" then parts[#parts + 1] = d.description end
            desc.Text = (#parts > 0) and table.concat(parts, "\n\n"):sub(1, 3000) or "No description."
            if type(d.keyLink) == "string" and d.keyLink ~= "" then
                keyLink = d.keyLink
                keyB.Text = "Copy key link" keyB.BackgroundColor3 = C.purple
            end
        end)
    end

    local function card(x)
        state.items += 1
        local i = state.items
        local keyed = isKeyed(x)
        local f = new("TextButton", {Parent = list, AutoButtonColor = false, Text = "", BackgroundColor3 = C.card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 92),
            LayoutOrder = i, ZIndex = 3}, {corner(12)})
        local st = stroke(C.purple, 1, 1) st.Parent = f
        local img = new("ImageLabel", {Parent = f, BackgroundColor3 = C.panel, Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 72, 0, 72), ScaleType = Enum.ScaleType.Crop,
            Image = scriptImage(x), ZIndex = 4}, {corner(10)})
        new("Frame", {Parent = img, BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 5}, {corner(10),
            new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 0.1)})})})
        label(img, {Position = UDim2.new(0, 4, 1, -16), Size = UDim2.new(1, -8, 0, 14), Font = F.bold, Text = fmtNum(x.views) .. " VIEWS", TextSize = 8, ZIndex = 6,
            TextXAlignment = Enum.TextXAlignment.Center})
        label(f, {Position = UDim2.new(0, 94, 0, 10), Size = UDim2.new(1, -140, 0, 20), Font = F.bold, Text = tostring(x.title or "Untitled"), TextSize = 14, ZIndex = 4,
            TextTruncate = Enum.TextTruncate.AtEnd})
        local bio = x.features or x.description or ((x.game and x.game.name) and stripGlyphs(tostring(x.game.name))) or ""
        bio = tostring(bio):gsub("[\r\n]+", " · ")
        label(f, {Position = UDim2.new(0, 94, 0, 32), Size = UDim2.new(1, -140, 0, 28), Font = F.reg, Text = bio, TextColor3 = C.sub, TextSize = 11, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
        local badges = new("Frame", {Parent = f, BackgroundTransparency = 1, Position = UDim2.new(0, 94, 0, 64), Size = UDim2.new(1, -140, 0, 18), ZIndex = 4},
            {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)})})
        badge(badges, keyed and "KEY" or "KEYLESS", keyed and C.yellow or C.green)
        if x.verified then badge(badges, "VERIFIED", C.purple) end
        if x.isUniversal then badge(badges, "UNIVERSAL", C.sub) end
        local fav = new("TextButton", {Parent = f, AutoButtonColor = false, BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 8), Size = UDim2.new(0, 54, 0, 22), Font = F.bold, Text = favIndex(x.slug) and spaced("Saved") or spaced("Save"),
            TextColor3 = C.goldLight, TextSize = 8, ZIndex = 6}, {corner(6)})
        local favS = stroke(C.goldLight, 1, favIndex(x.slug) and 0.2 or 0.7) favS.Parent = fav
        clickable(fav, function()
            local on = toggleFav(x)
            fav.Text = on and spaced("Saved") or spaced("Save")
            favS.Transparency = on and 0.2 or 0.7
        end)
        local run = new("TextButton", {Parent = f, AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8),
            Size = UDim2.new(0, isTouch and 40 or 34, 0, isTouch and 40 or 34), Font = F.black, Text = "RUN", TextColor3 = C.ink, TextSize = 9, ZIndex = 6}, {corner(17), goldGradient(30)})
        clickable(run, function() H.confirmRun(x) end)
        bind(f.MouseEnter:Connect(function() tween(f, 0.15, {BackgroundColor3 = C.cardHover}) tween(st, 0.15, {Color = C.gold, Transparency = 0.2}) end))
        bind(f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundColor3 = C.card}) tween(st, 0.15, {Color = C.purple, Transparency = 0.6}) end))
        clickable(f, function() openSheet(x) end)
        if PERF.lite then
            f.BackgroundTransparency = 0.25 st.Transparency = 0.6
        else
            local p = new("UIPadding", {Parent = f, PaddingLeft = UDim.new(0, 16)})
            task.delay(0.02 * ((i - 1) % 12), function()
                if not f.Parent then return end
                tween(f, 0.2, {BackgroundTransparency = 0.25}) tween(st, 0.2, {Transparency = 0.6})
                tween(p, 0.2, {PaddingLeft = UDim.new(0, 0)})
            end)
        end
    end
    local function passes(x)
        if type(x) ~= "table" or x.isPatched then return false end
        if filters.keyless and isKeyed(x) then return false end
        if filters.verified and not x.verified then return false end
        return true
    end
    local function showLocal(arr, empty)
        clear()
        local n = 0
        for _, x in ipairs(arr) do if passes(x) then card(x) n += 1 end end
        if n == 0 then message(empty) end
    end
    local function buildUrl(page)
        local sort = filters.sort == "newest" and "createdAt" or "views"
        local common = "&max=20&page=" .. page .. "&sortBy=" .. sort .. "&order=desc" .. (filters.keyless and "&mode=free" or "")
        local t = state.tab
        if t == 1 then
            -- root PlaceId first (Blox Fruits: 2753915549 for every Sea), then this PlaceId, then a cleaned name search
            local urls = GAMEINFO.scriptUrls(common)
            local u = urls[math.clamp(state.gameIdx or 1, 1, math.max(#urls, 1))]
            return u and u[1] or nil, urls
        
        elseif t == 2 then return GV.SB .. "/api/script/trending"
        elseif t == 3 then return GV.SB .. "/api/script/fetch?universal=1" .. common
        elseif t == 4 then
            local q = trim(searchBox.Text)
            if q == "" then return nil end
            return GV.SB .. "/api/script/search?q=" .. enc(q) .. common
        end
        return nil
    end
    local loadMoreBtn
    local function loadList(reset)
        local t = state.tab
        if t == 5 then showLocal(favs, "No favorites yet. Tap SAVE on a script card to keep it here.") return end
        if t == 6 then showLocal(history, "No scripts executed yet.") return end
        if reset then state.page = 1 clear() end
        local url, gameUrls = buildUrl(state.page)
        if not url then clear() message(t == 1 and "Couldn't detect this game." or "Type a game or script name above.") return end
        if t == 1 and reset then state.gameIdx = 1 url = gameUrls[1][1] end
        state.token += 1
        local my = state.token
        state.loading = true
        if loadMoreBtn then loadMoreBtn:Destroy() loadMoreBtn = nil end
        local sk = skeletons(reset and 4 or 2)
        task.spawn(function()
            local d = cachedJSON(url, 120)
            local via
            if t == 1 and gameUrls then
                via = gameUrls[state.gameIdx or 1] and gameUrls[state.gameIdx or 1][2]
                -- nothing for this lookup? fall through to the next one (page 1 only)
                while state.page == 1 and my == state.token and (state.gameIdx or 1) < #gameUrls do
                    local r0 = d and type(d.result) == "table" and d.result
                    if r0 and type(r0.scripts) == "table" and #r0.scripts > 0 then break end
                    state.gameIdx = (state.gameIdx or 1) + 1
                    via = gameUrls[state.gameIdx][2]
                    d = cachedJSON(gameUrls[state.gameIdx][1], 120)
                end
            end
            if my ~= state.token or not alive then return end
            pcall(function() sk:Destroy() end)
            state.loading = false
            local result = d and type(d.result) == "table" and d.result
            if t == 1 and state.page == 1 then
                label(list, {Size = UDim2.new(1, 0, 0, 18), LayoutOrder = -1, Font = F.mono, TextSize = 10, TextColor3 = result and C.sub or C.yellow, ZIndex = 4,
                    TextTruncate = Enum.TextTruncate.AtEnd, Text = "DETECTED  " .. string.upper(GAMEINFO.label()) .. (via and ("   /   via " .. via) or "")})
            end
            if not result then
                message("Couldn't reach ScriptBlox (" .. tostring(HUB.httpStatus or "request failed") .. "). Your executor may block HTTP requests.")
                return
            end
            state.totalPages = tonumber(result.totalPages) or 1
            local n = 0
            for _, x in ipairs(type(result.scripts) == "table" and result.scripts or {}) do
                if passes(x) then card(x) n += 1 end
            end
            if n == 0 and state.items == 0 then message("No scripts found. Try other filters.") end
            if t ~= 2 and state.page < state.totalPages then
                loadMoreBtn = button(list, "Load more", {Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 99997, BackgroundColor3 = C.purpleDark, TextColor3 = C.gold, ZIndex = 4}, function()
                    state.page += 1 loadList(false)
                end)
            end
        end)
    end
    -- infinite scroll
    bind(list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if state.loading or not loadMoreBtn or state.tab == 2 or state.tab >= 5 then return end
        local bottom = list.CanvasPosition.Y + list.AbsoluteWindowSize.Y
        if bottom >= list.AbsoluteCanvasSize.Y - 60 then state.page += 1 loadList(false) end
    end))

    local subButtons = {}
    local function layoutSearch()
        local on = state.tab == 4
        searchF.Visible = on
        local top = on and 118 or 76
        list.Position = UDim2.new(0, 0, 0, top) list.Size = UDim2.new(1, 0, 1, -top)
    end
    local function selectSub(i)
        state.tab = i
        for j, b in ipairs(subButtons) do
            tween(b, 0.25, {BackgroundColor3 = (j == i) and C.purpleDark or C.bg, TextColor3 = (j == i) and C.gold or C.sub, BackgroundTransparency = (j == i) and 0 or 1})
        end
        layoutSearch()
        loadList(true)
    end
    for i, name in ipairs(tabs) do
        local b = new("TextButton", {Parent = subBar, AutoButtonColor = false, BackgroundColor3 = C.bg, BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 28),
            AutomaticSize = Enum.AutomaticSize.X, Font = F.bold, Text = name, TextColor3 = C.sub, TextSize = 12, LayoutOrder = i, ZIndex = 4}, {corner(8), pad(12, 12, 0, 0)})
        clickable(b, function() selectSub(i) end)
        subButtons[i] = b
    end
    local function chip(text, order, getter, setter)
        local b = new("TextButton", {Parent = chipBar, AutoButtonColor = false, BackgroundColor3 = C.card, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
            Font = F.bold, Text = text, TextSize = 11, TextColor3 = C.sub, LayoutOrder = order, ZIndex = 4}, {corner(14), pad(10, 10, 0, 0)})
        local s = stroke(C.purple, 1, 0.5) s.Parent = b
        local function render()
            local on = getter()
            tween(b, 0.2, {BackgroundColor3 = on and C.purpleDark or C.card, TextColor3 = on and C.gold or C.sub}) tween(s, 0.2, {Color = on and C.gold or C.purple})
        end
        render()
        clickable(b, function() setter() render() loadList(true) end)
        return render
    end
    local renders = {}
    renders[1] = chip("Keyless only", 1, function() return filters.keyless end, function() filters.keyless = not filters.keyless end)
    renders[2] = chip("Verified only", 2, function() return filters.verified end, function() filters.verified = not filters.verified end)
    renders[3] = chip("Most viewed", 3, function() return filters.sort == "views" end, function() filters.sort = "views" if renders[4] then renders[4]() end end)
    renders[4] = chip("Newest", 4, function() return filters.sort == "newest" end, function() filters.sort = "newest" if renders[3] then renders[3]() end end)

    -- search debounce
    local typed = 0
    bind(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        typed += 1
        local my = typed
        task.delay(0.6, function() if my == typed and state.tab == 4 and trim(searchBox.Text) ~= "" then loadList(true) end end)
    end))
    bind(searchBox.FocusLost:Connect(function(enter) if enter then typed += 1 loadList(true) end end))

    root:SetAttribute("OnShow", true)
    local loaded = false
    H.onShow3 = function() if not loaded then loaded = true selectSub(1) end end
    return root
end

-- =====================================================================
-- 22. Settings page
-- =====================================================================
-- =====================================================================
-- 21b. Console page (4.1): live Guardian status, self-test, debug log
-- =====================================================================
function H.buildConsole(parent)
    local pg = K.page(parent)
    local upd = {}
    local function liveRow(sec, name, getter)
        local r = K.card(sec, isTouch and 44 or 38)
        label(r, {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), Font = F.bold, Text = name, TextColor3 = C.sub, TextSize = 12, ZIndex = 4})
        local v = label(r, {Position = UDim2.new(0.38, 0, 0, 0), Size = UDim2.new(0.62, -14, 1, 0), Font = F.mono, Text = "-", TextSize = 11, ZIndex = 4,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
        local function u() local ok, t = pcall(getter) v.Text = ok and tostring(t) or "-" end
        u() upd[#upd + 1] = u
    end
    local S, M, A, G, ST = CORE.sense, CORE.move, CORE.abil, CORE.ggod, CORE.stalk
    local live = K.section(pg, "Live status", nil, true)
    liveRow(live, "Threat sensor", function()
        local n = #(S.list or {})
        return n .. " tracked · " .. (S.hostiles or 0) .. " hostile · " .. (S.combat and "COMBAT" or "calm")
    end)
    liveRow(live, "Top threat", function()
        local t = S.top
        if not t then return "none" end
        return t.name .. " · " .. math.floor(t.dist or 0) .. "m · danger " .. string.format("%.1f", t.danger or 0) .. (t.reach and (" · reach " .. math.floor(t.reach)) or "")
    end)
    liveRow(live, "Predictive dodge", function()
        local st = S.stats or {}
        return (st.imminent or 0) .. " seen · " .. (st.evaded or 0) .. " clean · " .. (st.hitAnyway or 0) .. " hit anyway · " .. (st.projectiles or 0) .. " projectiles"
    end)
    liveRow(live, "Guardian PvE", function()
        local P = CORE.pve
        return P and P.summary and (P.summary() .. " · " .. P.status()) or "-"
    end)
    liveRow(live, "Awakening", function() return CORE.awaken and CORE.awaken.status() or "-" end)
    liveRow(live, "Farm Brain", function() return CORE.farm and CORE.farm.status() or "-" end)
    liveRow(live, "Kamui Escape", function() return CORE.kamui and CORE.kamui.status() or "-" end)
    liveRow(live, "Puppet Hold", function() local P = CORE.pve return P and P.hold and P.hold.status() or "-" end)
    liveRow(live, "Aggression", function() return CORE.aggro and CORE.aggro.status and CORE.aggro.status() or (settings.aggression and "armed" or "off") end)
    liveRow(live, "Offense memory", function()
        local st = brain.offenseStats and brain.offenseStats()
        if not st then return "-" end
        local best = brain.bestAttack and select(1, brain.bestAttack(nil))
        local AG = CORE.aggro
        local kit = AG and (AG.workingN .. "/" .. AG.arsenalN .. " kit") or nil
        return st.kills .. " kills · " .. st.skills .. " working · " .. st.mobs .. " mobs"
            .. (kit and (" · " .. kit) or "")
            .. (best and (" · best " .. best) or "")
    end)
    liveRow(live, "Lifeline", function() return CORE.lifeline and CORE.lifeline.status() or "-" end)
    liveRow(live, "Companion hold", function() return CORE.lifeline and CORE.lifeline.compStatus() or "-" end)
    liveRow(live, "Movement", function()
        if M.carrying then return "carrying (AlignPosition)" end
        local a = M.active and M.active()
        local s = M.steer and M.steer.Magnitude or 0
        return (a or "idle") .. (s > 0.5 and (" · " .. math.floor(s) .. " st/s") or "")
    end)
    liveRow(live, "Control", function()
        if settings.handsVisual == true then return VFX.handsState and VFX.handsState() or "-" end
        if HUB.rescueBusy then return "moving you" end
        local LL = CORE.lifeline
        if LL and LL.phase and LL.phase ~= "idle" then return LL.phase end
        return settings.handsOn == true and "armed (no hand models)" or "off"
    end)
    liveRow(live, "Guardian Godmode", function() return G.status and G.status() or "-" end)
    liveRow(live, "Godmode layers", function() return G.layers and G.layers() or "-" end)
    liveRow(live, "Your abilities", function() return A.summary and A.summary() or "-" end)
    liveRow(live, "Remotes", function() return A.remoteSummary and A.remoteSummary() or "-" end)
    liveRow(live, "Stalker Shield", function() return ST.summary and ST.summary() or "-" end)
    liveRow(live, "Walk on water", function()
        if settings.walkwater then return "on · surface from " .. tostring(CORE.waterSource) end
        if CORE.seaTop and CORE.seaTop() and settings.waterGuard ~= false and settings.handsOn == true then return "Water Guard · sea level y " .. math.floor(CORE.seaTop() + 0.5) end
        return "off"
    end)
    liveRow(live, "Lifecycle", function() return "life #" .. CORE.life.gen .. " · " .. CORE.jobErrors() .. " job errors (all logged below)" end)

    -- self-test: checks what this executor + game actually allow, right now
    -- Explorer Scanner (4.3): read-only world model; remotes are listed, never fired
    do
        local Wf = function() return CORE.world or {} end
        local ex = K.section(pg, "Explorer Scanner", nil, false)
        K.toggle(ex, "Explorer Scanner", "scanner", nil, "Chunked, read-only scan of the world · feeds Mob Gather, Loot Grab, Safe Zone, Water Walk, Boss Choreography")
        K.actions(ex, "World model", {{"Rescan", function() if Wf().rescan then Wf().rescan() end end, 76}}, "Builds the model again from scratch")
        liveRow(ex, "Scan", function() return Wf().status and Wf().status() or "-" end)
        liveRow(ex, "Mobs", function() local c = Wf().counts and Wf().counts() if not c then return "-" end
            return c.mobs .. " · " .. c.movableMobs .. " client-movable · " .. c.folders .. " folders · " .. c.spawns .. " spawns" end)
        liveRow(ex, "Loot", function() local c = Wf().counts and Wf().counts() if not c then return "-" end
            return c.drops .. " drops / fruits / chests · " .. c.movableDrops .. " movable · " .. c.tools .. " tools" end)
        liveRow(ex, "World", function() local c = Wf().counts and Wf().counts() if not c then return "-" end
            return c.quest .. " quest givers · " .. c.hazards .. " hazards · " .. c.water .. " water · " .. c.safe .. " safe zones" end)
        liveRow(ex, "Remotes", function() local c = Wf().counts and Wf().counts() if not c then return "-" end
            return c.remotes .. " found (list only) · " .. Wf().remoteList(3) end)
        liveRow(ex, "Lighting", function() return tostring(Wf().sky or "-") end)
        liveRow(ex, "Game profile", function() return Wf().profileStatus and Wf().profileStatus() or "-" end)
        liveRow(ex, "Your kit", function() return Wf().kitStatus and Wf().kitStatus() or "-" end)
    end
    local test = K.section(pg, "Self-test", nil, false)
    local out = label(test, {Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.Y, Font = F.mono, Text = "Run the test to see what works here.",
        TextColor3 = C.sub, TextSize = 11, TextWrapped = true, LayoutOrder = K.nextOrder(), ZIndex = 4})
    local function run()
        local res = {}
        local function chk(name, fn)
            local ok, v = pcall(fn)
            local pass = ok and v ~= false
            res[#res + 1] = (pass and "PASS  " or "FAIL  ") .. name .. ((not ok) and ("  (" .. tostring(v):sub(1, 60) .. ")") or "")
        end
        local r = hrp()
        chk("character + root found", function() return r ~= nil and hum() ~= nil end)
        chk("LinearVelocity (steering)", function() local lv = Instance.new("LinearVelocity") lv:Destroy() return true end)
        chk("AlignPosition (carry)", function() local ap = Instance.new("AlignPosition") ap:Destroy() return true end)
        chk("animation tracks readable", function()
            for _, info in ipairs(S.list or {}) do
                local an = info.hum:FindFirstChildOfClass("Animator")
                if an then an:GetPlayingAnimationTracks() return true end
            end
            local an = hum() and hum():FindFirstChildOfClass("Animator")
            return an ~= nil and an:GetPlayingAnimationTracks() ~= nil
        end)
        chk("Terrain:ReadVoxels (water)", function()
            local p = r and r.Position or Vector3.zero
            workspace.Terrain:ReadVoxels(Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4), 4)
            return true
        end)
        chk("VirtualInputManager (ability keys)", function() return A.hasVIM and A.hasVIM() end)
        chk("Humanoid state guard", function()
            local h = hum()
            return h ~= nil and h:GetStateEnabled(Enum.HumanoidStateType.Ragdoll) ~= nil
        end)
        chk("public chat path", function()
            local tcs = game:GetService("TextChatService")
            return tcs.ChatVersion == Enum.ChatVersion.TextChatService or game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents") ~= nil
        end)
        chk("movement accepted by the game", function()
            local a = brain.actionState and brain.actionState("move_physics")
            return not (type(a) == "table" and a.broken)
        end)
        out.Text = table.concat(res, "\n")
        out.TextColor3 = C.text
        CORE.log("TEST", #res .. " checks · " .. select(2, string.gsub(table.concat(res, "\n"), "FAIL", "")) .. " failed")
    end
    K.actions(test, "Self-test", {{"Run", run, 64, C.goldDark}}, "Checks this executor + game · nothing is sent anywhere")

    -- debug log
    local lg = K.section(pg, "Debug log", nil, true)
    K.actions(lg, "Log", {{"Copy", function()
        if copy(table.concat(CORE.dbg.lines, "\n")) then toast("Log copied.", "ok") else toast("Your executor has no clipboard.", "bad") end
    end, 64}, {"Clear", function() CORE.dbg.lines = {} CORE.dbg.dirty = true end, 64, C.purpleDark}}, "Errors from every loop land here instead of failing silently")
    local box = new("ScrollingFrame", {Parent = lg, BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 220),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.gold,
        LayoutOrder = K.nextOrder(), ZIndex = 4}, {corner(8), pad(10, 10, 8, 8)})
    local bs = stroke(C.line, 1, 0.2) bs.Parent = box
    local txt = label(box, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = F.mono, Text = "", TextSize = 10, TextColor3 = C.sub,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, RichText = false, ZIndex = 5})
    local function render()
        local L = CORE.dbg.lines
        local from = math.max(1, #L - 120)
        local buf = {}
        for i = #L, from, -1 do buf[#buf + 1] = L[i] end
        txt.Text = (#buf > 0) and table.concat(buf, "\n") or "No entries yet. Errors, respawns, ability uses and Guardian decisions appear here."
        CORE.dbg.dirty = false
    end
    render()
    local acc = 0
    onHeartbeat("consolepage", function(dt)
        acc += dt
        if acc < 0.5 or not pg.Visible then return end
        acc = 0
        for _, u in ipairs(upd) do pcall(u) end
        if CORE.dbg.dirty then render() end
    end)
    return pg
end

function H.buildSettings(parent)
    local pg = K.page(parent)
    local ui = K.section(pg, "Interface", nil, true)
    K.toggle(ui, "Performance Mode", "perf", function(on)
        PERF.lite = on
        toast(on and "Performance Mode on: no looping effects, particles or ripples." or "Full effects on. Particles return after reopening the hub.", "info")
    end, "Auto-on for phones · fewer effects, smoother FPS")
    K.slider(ui, "UI size %", "uiscale", 70, 130, function() rescale() end, 5)
    K.slider(ui, "Accent intensity", "accent", 0, 10, function(v) if H.border then H.border.Thickness = 1 + v * 0.25 end end)
    K.toggle(ui, "Background particles", "particles", function(on) toast(on and "Particles on (applies on next launch)." or "Particles off (applies on next launch).", "info") end,
        "Never shown in Performance Mode")
    K.toggle(ui, "Sounds", "sounds")
    K.toggle(ui, "Visual effects", "vfx", nil, "Dodge trails, shockwaves, shields · lighter in Performance Mode")

    local scr = K.section(pg, "Scripts", nil, true)
    K.toggle(scr, "Close hub after running a script", "closeAfterRun", nil, "Hub unloads itself right after launching a script")
    K.toggle(scr, "Confirm before running", "confirmRun", nil, "Shows a small Run / Cancel sheet first")
    K.actions(scr, "Script cache", {{"Clear", function() clearCache() toast("Script cache cleared.", "ok") end, 76, C.purpleDark}}, "Lists are cached for 2 minutes")

    local kb = K.section(pg, "Keybinds", nil, false)
    if isTouch and not UserInputService.KeyboardEnabled then
        label(kb, {Size = UDim2.new(1, 0, 0, 30), Text = "Keybinds need a keyboard. On mobile use Quick toggles on Start.", TextColor3 = C.sub, TextSize = 11,
            TextWrapped = true, LayoutOrder = 0, ZIndex = 4})
    end
    local bindNames = {{"toggleUI", "Show / hide hub"}, {"panic", "Panic"}, {"safespot", "Safe Spot in / out"}, {"fly", "Fly"}, {"noclip", "Noclip"},
        {"esp", "ESP"}, {"infjump", "Infinite Jump"}, {"freecam", "Freecam"}, {"fullbright", "Fullbright"}, {"xray", "X-ray"}, {"autointeract", "Auto-interact"},
        {"domain", "Domain Expansion"}, {"godform", "God Form"}, {"lift", "Guardian Control · Lift"}}
    for i, bn in ipairs(bindNames) do
        local key, text = bn[1], bn[2]
        local r = K.card(kb) K.rowLabel(r, text)
        r.LayoutOrder = i
        local b
        b = button(r, (settings.binds[key] or "") ~= "" and settings.binds[key] or "None", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 120, 0, GV.BTN_H - 2),
            TextSize = 12, BackgroundColor3 = C.purpleDark, TextColor3 = C.gold, ZIndex = 4}, function()
            if H.capturing then return end
            H.capturing = true
            b.Text = "Press a key…"
            local c
            c = UserInputService.InputBegan:Connect(function(inp)
                if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
                c:Disconnect()
                local name = inp.KeyCode.Name
                if name == "Escape" or name == "Backspace" then name = "" end
                -- one key = one action
                if name ~= "" then
                    for k2, v2 in pairs(settings.binds) do if v2 == name and k2 ~= key then settings.binds[k2] = "" toast("Key moved from another bind.", "info", 1.6) end end
                end
                settings.binds[key] = name
                b.Text = name ~= "" and name or "None"
                saveSettings()
                task.delay(0.1, function() H.capturing = false end)
            end)
            bind(c)
        end)
    end
    label(kb, {Size = UDim2.new(1, 0, 0, 18), Text = "Esc / Backspace clears a bind.", TextColor3 = C.sub, TextSize = 11, LayoutOrder = 99, ZIndex = 4})

    -- Profiles (per game)
    local pf = K.section(pg, "Profiles (this game)", nil, false)
    K.toggle(pf, "Auto-load 'Default' profile", "autoProfile", nil, "Loads it every time you start the hub in this game")
    local _, nameBox = K.input(pf, "Profile name", nil, "Default", "Saves movement, visuals, automation…")
    local pfList = new("Frame", {Parent = pf, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 99, ZIndex = 3},
        {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
    local function refreshProfiles()
        for _, c in ipairs(pfList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local names = {}
        for n in pairs(FX.gameProfiles()) do names[#names + 1] = n end
        table.sort(names)
        for i, n in ipairs(names) do
            local r = new("Frame", {Parent = pfList, BackgroundColor3 = C.card, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, GV.ROW_H), LayoutOrder = i, ZIndex = 3}, {corner(12)})
            local s = stroke(n == "Default" and C.gold or C.purple, 1, 0.6) s.Parent = r
            K.rowLabel(r, n, n == "Default" and "Auto-load target" or nil, 150)
            button(r, "Load", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.new(0, 62, 0, GV.BTN_H - 2), TextSize = 12, ZIndex = 4}, function()
                local snap = FX.gameProfiles()[n]
                if type(snap) ~= "table" then return end
                for k, v in pairs(snap) do settings[k] = v end
                saveSettings()
                FX.applyAll() K.refreshToggles() K.refreshSliders()
                hud.Visible = settings.hud == true
                toast("Profile '" .. n .. "' loaded.", "ok")
            end)
            button(r, "Delete", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 56, 0, GV.BTN_H - 2), TextSize = 11, ZIndex = 4,
                BackgroundColor3 = C.purpleDark, TextColor3 = C.red}, function() FX.deleteProfile(n) refreshProfiles() end)
        end
        if #names == 0 then
            label(pfList, {Size = UDim2.new(1, 0, 0, 28), Text = "No profiles saved for this game yet.", TextColor3 = C.sub, ZIndex = 4, LayoutOrder = 1})
        end
    end
    K.actions(pf, "Save current setup", {{"Save", function() FX.saveProfile(nameBox.Text) nameBox.Text = "" refreshProfiles() end, 76}})
    refreshProfiles()

    local hb = K.section(pg, "Hub", nil, true)
    K.actions(hb, "Reset settings", {{"Reset", function()
        FX.disableAll()
        for k, v in pairs(GV.DEFAULTS) do settings[k] = (type(v) == "table") and jsonDecode(jsonEncode(v)) or v end
        saveSettings() K.refreshToggles() K.refreshSliders()
        toast("Settings reset.", "ok")
    end, 80, C.purpleDark}}, "Back to default values")
    K.actions(hb, "Forget key", {{"Forget", function() save(GV.KEY_FILE, "") toast("Saved key removed.", "ok") end, 80, C.purpleDark}}, "Ask for the key next time")
    K.actions(hb, "Unload hub", {{"Unload", function() H.unload(false) end, 86, C.red}}, "Turns everything off and removes all parts")
    local credit = K.card(pg, 44)
    local cl = label(credit, {Size = UDim2.fromScale(1, 1), Font = F.bold, Text = spaced("Void Hub") .. "   " .. HUB.version .. "   ·   by Void", TextColor3 = C.sub, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4})
    shimmerText(cl)
    return pg
end

-- =====================================================================
-- 22b. Intro hands removed in 5.7 (Void Hub) — panel opens clean.
-- =====================================================================
function H.introHands() end
H.introFinish = function() end

-- =====================================================================
-- 23. Boot
-- =====================================================================
-- V2.1: the panel ALWAYS opens. The build runs protected; if anything fails the error is shown as a
-- toast and whatever was built is still shown. A watchdog checks ~6 s after the key is accepted and
-- forces the panel open (and says why in the Console tab) if it is not visible by then.
;(function() -- own function scope: the main chunk is at Luau's 200-local-register limit
local BOOT = {opened = false}
function BOOT.problem()
    if not H.win then return "panel was never built" end
    if not H.win.Parent then return "panel was removed" end
    if H.visible == false then return nil end -- the user minimised it on purpose
    if not H.win.Visible then return "panel was hidden" end
    if H.sc and H.sc.Scale < 0.5 then return "panel scale stuck at " .. tostring(H.sc.Scale) end
    if HUB.bootRoot and HUB.bootRoot.Parent then return "loading screen still on top" end
    return nil
end
function BOOT.open(reason)
    if BOOT.opened or not alive then return end
    BOOT.opened = true
    HUB.started = os.clock()
    if reason then CORE.log("WARN", "panel opened by watchdog: " .. reason) end
    local ok, err = pcall(H.build)
    if not ok then
        CORE.log("ERR", "panel build: " .. tostring(err))
        pcall(toast, "Panel error: " .. tostring(err):sub(1, 160) .. " · the rest still loads, details in Console.", "bad", 8)
    end
    if H.win then pcall(function() H.win.Visible = true H.visible = true HUB.uiOpen = true end) end
    if H.buildErrors and #H.buildErrors > 0 then
        pcall(toast, #H.buildErrors .. " page(s) had an error: " .. tostring(H.buildErrors[1]):sub(1, 120), "warn", 7)
    end
    if #HUB.moduleErrors > 0 then
        pcall(toast, #HUB.moduleErrors .. " module(s) were skipped after an error · see Console.", "warn", 6)
    end
    -- 5.7: no hand intro; soft awaken only for Premium after they unlocked
    if HUB.tier == "premium" then
        task.delay(0.35, function() if alive and VFX.awaken then local ok2, e = pcall(VFX.awaken) if not ok2 then CORE.log("ERR", "intro: " .. tostring(e)) end end end)
    end
end
function BOOT.force(why)
    CORE.log("WARN", "watchdog: " .. why .. " · forcing the panel open")
    if HUB.bootRoot then pcall(function() HUB.bootRoot:Destroy() end) HUB.bootRoot = nil end
    renderJobs.bootEmbers = nil
    if H.introFinish then pcall(H.introFinish) end
    if not BOOT.opened then BOOT.open(why) return end
    if H.win then
        pcall(function()
            H.win.Visible = true
            H.visible = true
            HUB.uiOpen = true
            if H.sc then H.sc.Scale = 1 end
            if H.win.BackgroundTransparency > 0.5 then H.win.BackgroundTransparency = 0.03 end
            if H.orb then H.orb.Visible = false end
        end)
    else
        pcall(toast, "The panel could not be built · re-run the loadstring.", "bad", 8)
    end
end
task.spawn(function()
    splash()
    if not alive then return end
    -- Restore access: saved Premium key → premium; else saved free choice; else choose on Start after load
    local savedKey = loadFile(GV.KEY_FILE)
    if savedKey and hubHash(trim(savedKey)) == GV.KEY_HASH then
        HUB.tier = "premium"
    else
        local t = loadFile(GV.TIER_FILE)
        if t and trim(t) == "free" then HUB.tier = "free"
        elseif t and trim(t) == "premium" then HUB.tier = nil -- key missing; ask again
        else HUB.tier = nil end
    end
    HUB.keyAcceptedAt = os.clock()
    task.delay(6, function()
        if not alive then return end
        local why = BOOT.problem()
        if why then BOOT.force(why) end
    end)
    local ok, err = pcall(securityScan, function() BOOT.open() end)
    if not ok then
        CORE.log("ERR", "loading screen: " .. tostring(err))
        BOOT.force("loading screen error: " .. tostring(err))
    end
end)
end)()
end, function(e)
    local tb = ""
    pcall(function() tb = debug.traceback() end)
    return tostring(e) .. "\n" .. tb
end)
if not SH_OK then
    local msg = tostring(SH_ERR)
    pcall(warn, "[Void Hub] startup error: " .. msg)
    SH_NOTIFY("Void Hub - startup error", (msg:match("^[^\n]*") or msg), 30)
    pcall(function()
        local cb = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard)
        if cb then cb("Void Hub startup error:\n" .. msg) end
    end)
end
