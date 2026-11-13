--[[
    DXLTA Explorer Dump
    Structure / name dump only (ClassName + path). Does not read script source.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/script777777/Blox-Fruits-/cursor/explorer-dump-ff0d/explorer.lua"))()
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local MAX_DEPTH = 8
local MAX_LINES = 4500

local INTEREST = {
    RemoteEvent = true,
    RemoteFunction = true,
    UnreliableRemoteEvent = true,
    BindableEvent = true,
    BindableFunction = true,
    Folder = true,
    Configuration = true,
    ModuleScript = true,
    Script = true,
    LocalScript = true,
    Tool = true,
    ScreenGui = true,
    BillboardGui = true,
    SurfaceGui = true,
}

local ROOTS = {
    "Workspace",
    "ReplicatedStorage",
    "ReplicatedFirst",
    "Players",
    "Lighting",
    "StarterGui",
    "StarterPack",
    "StarterPlayer",
    "Teams",
    "SoundService",
    "Chat",
    "TextChatService",
}

local COLORS = {
    bg = Color3.fromRGB(12, 14, 18),
    panel = Color3.fromRGB(18, 22, 28),
    panelAlt = Color3.fromRGB(24, 28, 36),
    border = Color3.fromRGB(40, 48, 58),
    text = Color3.fromRGB(220, 228, 235),
    muted = Color3.fromRGB(140, 150, 165),
    lime = Color3.fromRGB(180, 255, 40),
    limeDim = Color3.fromRGB(90, 140, 20),
    danger = Color3.fromRGB(255, 90, 90),
}

local lastDump = ""
local lastLines = {}

local function safeGetService(name)
    local ok, svc = pcall(function()
        return game:GetService(name)
    end)
    if ok then
        return svc
    end
    return game:FindFirstChild(name)
end

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

local function copyToClipboard(text)
    local ok = false
    if typeof(setclipboard) == "function" then
        ok = pcall(setclipboard, text)
    end
    if not ok and typeof(toclipboard) == "function" then
        ok = pcall(toclipboard, text)
    end
    if not ok and typeof(set_clipboard) == "function" then
        ok = pcall(set_clipboard, text)
    end
    return ok
end

local function childNames(container)
    if not container then
        return "(none)"
    end
    local names = {}
    for _, c in ipairs(container:GetChildren()) do
        table.insert(names, string.format("%s [%s]", c.Name, c.ClassName))
    end
    if #names == 0 then
        return "(empty)"
    end
    return table.concat(names, ", ")
end

local function buildHeader()
    local lines = {}
    table.insert(lines, "========== DXLTA EXPLORER DUMP ==========")
    table.insert(lines, string.format("PlaceId=%s  GameId=%s  JobId=%s", tostring(game.PlaceId), tostring(game.GameId), tostring(game.JobId)))
    table.insert(lines, string.format("Time=%s", os.date("%Y-%m-%d %H:%M:%S")))

    if LocalPlayer then
        table.insert(lines, string.format("LocalPlayer=%s", LocalPlayer.Name))
        local char = LocalPlayer.Character
        table.insert(lines, string.format("Character=%s", char and getFullPath(char) or "(nil)"))
        if char then
            table.insert(lines, "  Character children: " .. childNames(char))
        end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        table.insert(lines, string.format("Backpack=%s", backpack and getFullPath(backpack) or "(nil)"))
        if backpack then
            table.insert(lines, "  Backpack children: " .. childNames(backpack))
        end
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        table.insert(lines, string.format("PlayerGui=%s", pgui and getFullPath(pgui) or "(nil)"))
        if pgui then
            table.insert(lines, "  PlayerGui children: " .. childNames(pgui))
        end
    else
        table.insert(lines, "LocalPlayer=(nil)")
    end

    table.insert(lines, "------------------------------------------")
    table.insert(lines, "Format: ClassName | game.Path.To.Instance")
    table.insert(lines, "Targets: remotes, folders, modules, scripts, tools, ScreenGuis")
    table.insert(lines, string.format("MaxDepth=%d  MaxLines=%d", MAX_DEPTH, MAX_LINES))
    table.insert(lines, "------------------------------------------")
    return lines
end

local function shouldList(inst)
    if INTEREST[inst.ClassName] then
        return true
    end
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
        return true
    end
    if inst:IsA("Folder") or inst:IsA("ModuleScript") or inst:IsA("BaseScript") then
        return true
    end
    if inst:IsA("Tool") or inst:IsA("LayerCollector") then
        return true
    end
    return false
end

local function scanRoot(root, lines, truncated)
    if truncated[1] or not root then
        return
    end

    local function walk(inst, depth)
        if truncated[1] then
            return
        end
        if depth > MAX_DEPTH then
            return
        end
        if #lines >= MAX_LINES then
            truncated[1] = true
            table.insert(lines, "... TRUNCATED (max lines reached) ...")
            return
        end

        if shouldList(inst) then
            table.insert(lines, string.format("%s | %s", inst.ClassName, getFullPath(inst)))
        end

        local children
        local ok, result = pcall(function()
            return inst:GetChildren()
        end)
        if not ok or not result then
            return
        end
        children = result

        for _, child in ipairs(children) do
            walk(child, depth + 1)
            if truncated[1] then
                return
            end
        end
    end

    table.insert(lines, "")
    table.insert(lines, string.format("### %s ###", root.Name))
    walk(root, 0)
end

local function runScan()
    local lines = buildHeader()
    local truncated = { false }

    for _, name in ipairs(ROOTS) do
        local root = safeGetService(name)
        if root then
            scanRoot(root, lines, truncated)
        else
            table.insert(lines, "")
            table.insert(lines, string.format("### %s ### (missing)", name))
        end
        if truncated[1] then
            break
        end
    end

    table.insert(lines, "")
    table.insert(lines, string.format("========== END (%d lines) ==========", #lines + 1))

    lastLines = lines
    lastDump = table.concat(lines, "\n")
    return lastDump
end

-- UI
local guiParent
local okParent, parentResult = pcall(function()
    return (gethui and gethui()) or CoreGui
end)
guiParent = (okParent and parentResult) or (LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")) or CoreGui

pcall(function()
    local existing = guiParent:FindFirstChild("DXLTA_ExplorerDump")
    if existing then
        existing:Destroy()
    end
end)

local screen = Instance.new("ScreenGui")
screen.Name = "DXLTA_ExplorerDump"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 999
screen.Parent = guiParent

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.fromOffset(520, 420)
frame.Position = UDim2.new(0.5, -260, 0.5, -210)
frame.BackgroundColor3 = COLORS.panel
frame.BorderSizePixel = 0
frame.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = COLORS.limeDim
stroke.Thickness = 1.5
stroke.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = COLORS.bg
header.BorderSizePixel = 0
header.Parent = frame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = COLORS.bg
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local brand = Instance.new("TextLabel")
brand.BackgroundTransparency = 1
brand.Position = UDim2.fromOffset(14, 0)
brand.Size = UDim2.new(1, -50, 1, 0)
brand.Font = Enum.Font.GothamBold
brand.TextSize = 18
brand.TextXAlignment = Enum.TextXAlignment.Left
brand.TextColor3 = COLORS.lime
brand.Text = "DXLTA  ·  Explorer Dump"
brand.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(32, 28)
closeBtn.Position = UDim2.new(1, -40, 0.5, -14)
closeBtn.BackgroundColor3 = COLORS.panelAlt
closeBtn.TextColor3 = COLORS.danger
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Text = "X"
closeBtn.AutoButtonColor = true
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeBtn

local filterBox = Instance.new("TextBox")
filterBox.Name = "Filter"
filterBox.PlaceholderText = "Filter (name / class / path)..."
filterBox.Text = ""
filterBox.ClearTextOnFocus = false
filterBox.Size = UDim2.new(1, -24, 0, 32)
filterBox.Position = UDim2.fromOffset(12, 54)
filterBox.BackgroundColor3 = COLORS.bg
filterBox.TextColor3 = COLORS.text
filterBox.PlaceholderColor3 = COLORS.muted
filterBox.Font = Enum.Font.Code
filterBox.TextSize = 14
filterBox.TextXAlignment = Enum.TextXAlignment.Left
filterBox.Parent = frame

local filterPad = Instance.new("UIPadding")
filterPad.PaddingLeft = UDim.new(0, 10)
filterPad.Parent = filterBox

local filterCorner = Instance.new("UICorner")
filterCorner.CornerRadius = UDim.new(0, 4)
filterCorner.Parent = filterBox

local filterStroke = Instance.new("UIStroke")
filterStroke.Color = COLORS.border
filterStroke.Thickness = 1
filterStroke.Parent = filterBox

local btnRow = Instance.new("Frame")
btnRow.BackgroundTransparency = 1
btnRow.Size = UDim2.new(1, -24, 0, 34)
btnRow.Position = UDim2.fromOffset(12, 96)
btnRow.Parent = frame

local function makeButton(name, text, xScale, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(xScale, -6, 1, 0)
    btn.BackgroundColor3 = color
    btn.TextColor3 = COLORS.bg
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = text
    btn.AutoButtonColor = true
    btn.Parent = btnRow

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn

    return btn
end

local scanBtn = makeButton("Scan", "SCAN", 1 / 3, COLORS.lime)
scanBtn.Position = UDim2.fromScale(0, 0)

local copyBtn = makeButton("Copy", "COPY", 1 / 3, Color3.fromRGB(140, 200, 50))
copyBtn.Position = UDim2.new(1 / 3, 3, 0, 0)

local clearBtn = makeButton("Clear", "CLEAR", 1 / 3, Color3.fromRGB(70, 80, 95))
clearBtn.Position = UDim2.new(2 / 3, 6, 0, 0)
clearBtn.TextColor3 = COLORS.text

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 136)
status.Size = UDim2.new(1, -24, 0, 18)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = COLORS.muted
status.Text = "Ready"
status.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Output"
scroll.Size = UDim2.new(1, -24, 1, -170)
scroll.Position = UDim2.fromOffset(12, 158)
scroll.BackgroundColor3 = COLORS.bg
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = COLORS.limeDim
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 4)
scrollCorner.Parent = scroll

local output = Instance.new("TextLabel")
output.Name = "DumpText"
output.BackgroundTransparency = 1
output.Size = UDim2.new(1, -16, 0, 0)
output.Position = UDim2.fromOffset(8, 6)
output.AutomaticSize = Enum.AutomaticSize.Y
output.Font = Enum.Font.Code
output.TextSize = 12
output.TextColor3 = COLORS.text
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = true
output.RichText = false
output.Text = ""
output.Parent = scroll

local function setStatus(msg, ok)
    status.Text = msg
    status.TextColor3 = ok == false and COLORS.danger or (ok == true and COLORS.lime or COLORS.muted)
end

local function applyFilter()
    local q = string.lower(filterBox.Text or "")
    if q == "" then
        output.Text = lastDump
        return
    end
    local filtered = {}
    for _, line in ipairs(lastLines) do
        if string.find(string.lower(line), q, 1, true) then
            table.insert(filtered, line)
        end
    end
    output.Text = table.concat(filtered, "\n")
end

local function doScan(autoCopy)
    setStatus("Scanning...", nil)
    task.wait()
    local dump = runScan()
    applyFilter()
    local copied = false
    if autoCopy then
        copied = copyToClipboard(dump)
    end
    if copied then
        setStatus(string.format("Scan done · %d lines · copied to clipboard", #lastLines), true)
    else
        setStatus(string.format("Scan done · %d lines", #lastLines), true)
    end
end

scanBtn.MouseButton1Click:Connect(function()
    doScan(true)
end)

copyBtn.MouseButton1Click:Connect(function()
    if lastDump == "" then
        setStatus("Nothing to copy — run SCAN first", false)
        return
    end
    local text = output.Text
    if text == "" then
        text = lastDump
    end
    if copyToClipboard(text) then
        setStatus("Copied to clipboard", true)
    else
        setStatus("Clipboard unavailable (setclipboard/toclipboard)", false)
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    lastDump = ""
    lastLines = {}
    filterBox.Text = ""
    output.Text = ""
    setStatus("Cleared", nil)
end)

filterBox:GetPropertyChangedSignal("Text"):Connect(function()
    if lastDump ~= "" then
        applyFilter()
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    screen:Destroy()
end)

-- Drag
do
    local dragging = false
    local dragStart, startPos

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Auto-run once on load
task.defer(function()
    doScan(true)
end)
