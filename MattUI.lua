--[[
    MattUI  -  black / deep-blue UI library with an elegant glitch title ("MattXaviera")
    Same API as the script already uses (drop-in for the old catui / Rayfield adapter):

        local UILib = loadstring(game:HttpGet("<URL OF THIS FILE>"))()
        local win   = UILib:Window({ Title = "MattXaviera", Footer = "Violence District" })
        win:InfoTab({ Name = "Info", DiscordLink = "https://discord.gg/xxxx", DiscordDesc = "..." })
        local tab = win:AddTab({ Name = "Exclusive", Icon = "sparkles" })
        local sec = tab:AddSection("Auto Parry")
        sec:AddToggle({ Title = "Auto Parry", Default = false, Callback = function(v) end })
        sec:AddSlider({ Title = "Radius", Min = 4, Max = 40, Default = 10, Increment = 1, Callback = function(v) end })
        sec:AddDropdown({ Title = "Part", Options = {"Head","Torso"}, Default = "Head", Callback = function(v) end })
        sec:AddTargetSelector({ Title = "Aim", DropdownTitle = "Target", Options = {"KILLER"}, Values = {"Killer"}, Default = "Killer", Callback = function(v) end })
        sec:AddInput / AddKeybind / AddColorPicker / AddButton / AddParagraph / AddLabel / AddHStack
        sec:AddTogglePanel({ Title, PanelTitle, ButtonTitle, Default, OffsetY, Callback })
        sec:AddPresetManager({ Title, Placeholder, Default, Presets = {Name = "value"}, Callback })
        sec:AddConfig()                       -- Save / Load buttons (needs writefile / readfile)
        UILib:MakeNotify({ Title, Content, Delay })
        UILib:TogglePanel({ Title, PanelTitle, Default, OffsetY, Callback })  -- floating on-screen button
        UILib:Destroy()

    RightShift (or the round "M" button) shows / hides the menu.
]]

local Players          = game:GetService("Players")
local UIS              = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local GuiService       = game:GetService("GuiService")

local env = (getgenv and getgenv()) or _G
if env.__MattUI then pcall(function() env.__MattUI:Destroy() end) end

----------------------------------------------------------------------
-- theme
----------------------------------------------------------------------
local C = {
    bg       = Color3.fromRGB(4, 6, 12),
    bg2      = Color3.fromRGB(2, 3, 7),
    side     = Color3.fromRGB(6, 10, 21),
    card     = Color3.fromRGB(10, 16, 33),
    card2    = Color3.fromRGB(14, 23, 47),
    line     = Color3.fromRGB(22, 36, 76),
    accent   = Color3.fromRGB(34, 68, 178),
    accentHi = Color3.fromRGB(84, 128, 255),
    ghostA   = Color3.fromRGB(28, 62, 200),
    ghostB   = Color3.fromRGB(110, 165, 255),
    text     = Color3.fromRGB(216, 226, 247),
    sub      = Color3.fromRGB(116, 132, 172),
    good     = Color3.fromRGB(80, 220, 140),
}
local FONT, FONT_B = Enum.Font.GothamMedium, Enum.Font.GothamBold

local Lib = {}
local conns = {}
local gui

local function connect(signal, fn)
    local c = signal:Connect(fn)
    conns[#conns + 1] = c
    return c
end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o, col, th, tr)
    return make("UIStroke", { Color = col or C.line, Thickness = th or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function pad(o, l, t, r, b)
    return make("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0) }, o)
end
local function tween(o, t, props, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function label(parent, text, size, color, font, xa)
    return make("TextLabel", {
        BackgroundTransparency = 1, Text = text or "", TextSize = size or 13, TextColor3 = color or C.text,
        Font = font or FONT, TextXAlignment = xa or Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 1, 0),
    }, parent)
end

local function getRoot()
    local ok, r = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and r then return r end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function draggable(handle, target, onTap)
    local dragging, moved, startIn, startPos
    connect(handle.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startIn, startPos = i.Position, target.Position
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startIn
            if d.Magnitude > 6 then moved = true end
            if moved then
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
    connect(UIS.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not moved and onTap then onTap() end
        end
    end)
end

----------------------------------------------------------------------
-- glitch text
----------------------------------------------------------------------
local SYMBOLS = { "#", "$", "%", "&", "@", "?", "/", "\\", "|", "<", ">", "+", "=", "*" }
local function glitchText(parent, text, size, width, height, xalign, calm)
    local box = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, height) }, parent)
    local function layer(col, z)
        return make("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = text, TextSize = size,
            TextColor3 = col, Font = FONT_B, TextXAlignment = xalign or Enum.TextXAlignment.Left, ZIndex = z,
        }, box)
    end
    local a, b, m = layer(C.ghostA, 1), layer(C.ghostB, 2), layer(C.text, 3)
    a.TextTransparency, b.TextTransparency = 0.55, 0.65
    local rng = Random.new()
    task.spawn(function()
        while box.Parent do
            local idle, t0 = rng:NextNumber(1.6, 3.4), os.clock()
            while box.Parent and os.clock() - t0 < idle do
                local s = math.sin(os.clock() * 2.4)
                a.Position = UDim2.fromOffset(-1 - s * 0.6, 0)
                b.Position = UDim2.fromOffset(1 + s * 0.6, 0)
                task.wait(0.05)
            end
            if not box.Parent then return end
            for _ = 1, rng:NextInteger(5, 9) do
                if not box.Parent then return end
                local dx = rng:NextInteger(2, calm and 3 or 5)
                if rng:NextNumber() < 0.5 then dx = -dx end
                a.Position = UDim2.fromOffset(-dx, rng:NextInteger(-1, 1))
                b.Position = UDim2.fromOffset(dx, rng:NextInteger(-1, 1))
                a.TextTransparency, b.TextTransparency = rng:NextNumber(0.05, 0.4), rng:NextNumber(0.1, 0.5)
                m.Position = UDim2.fromOffset(rng:NextInteger(-1, 1), 0)
                if rng:NextNumber() < 0.45 then
                    local chars = {}
                    for ch in text:gmatch(".") do chars[#chars + 1] = ch end
                    chars[rng:NextInteger(1, #chars)] = SYMBOLS[rng:NextInteger(1, #SYMBOLS)]
                    m.Text = table.concat(chars)
                else
                    m.Text = text
                end
                task.wait(0.04)
            end
            m.Text, m.Position = text, UDim2.fromOffset(0, 0)
            a.TextTransparency, b.TextTransparency = 0.55, 0.65
        end
    end)
    return box
end

----------------------------------------------------------------------
-- notifications
----------------------------------------------------------------------
local notifyHolder
function Lib:MakeNotify(o)
    if not gui or not notifyHolder then return end
    local card = make("Frame", { BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y }, notifyHolder)
    corner(card, 8); stroke(card, C.line, 1)
    make("Frame", { BackgroundColor3 = C.accentHi, Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, 6, 0, 6),
        BorderSizePixel = 0 }, card)
    local inner = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 0), Position = UDim2.new(0, 18, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y }, card)
    pad(inner, 0, 8, 6, 8)
    make("UIListLayout", { Padding = UDim.new(0, 2) }, inner)
    local t = label(inner, tostring(o.Title or "MattXaviera"), 13, C.text, FONT_B)
    t.Size = UDim2.new(1, 0, 0, 16)
    local c = label(inner, tostring(o.Content or ""), 12, C.sub)
    c.Size, c.AutomaticSize, c.TextWrapped = UDim2.new(1, 0, 0, 14), Enum.AutomaticSize.Y, true
    tween(card, 0.25, { BackgroundTransparency = 0 })
    task.delay(o.Delay or 3, function()
        if card.Parent then
            tween(card, 0.3, { BackgroundTransparency = 1 })
            task.wait(0.3)
            if card.Parent then card:Destroy() end
        end
    end)
end

----------------------------------------------------------------------
-- floating on-screen button (toggle panel)
----------------------------------------------------------------------
local function makePanel(o, onChange)
    local state = o.Default and true or false
    local obj = {}
    local btn = make("TextButton", {
        Size = UDim2.fromOffset(150, 34), Position = UDim2.new(0, 12, 0.5, (o.OffsetY or 0) - 60),
        BackgroundColor3 = C.card, AutoButtonColor = false, Font = FONT_B, TextSize = 12, TextColor3 = C.text,
        Visible = false, BorderSizePixel = 0, ZIndex = 20,
    }, gui)
    corner(btn, 8)
    local st = stroke(btn, C.line, 1.2)
    local title = o.PanelTitle or o.Title or "TOGGLE"
    local function render()
        btn.Text = title .. ": " .. (state and "ON" or "OFF")
        st.Color = state and C.accentHi or C.line
    end
    render()
    function obj:Set(v)
        v = v and true or false
        if v == state then return end
        state = v; render()
        if onChange then onChange(state) end
    end
    function obj:Get() return state end
    function obj:Toggle() btn.Visible = not btn.Visible end
    function obj:SetVisible(v) btn.Visible = v and true or false end
    function obj:Destroy() btn:Destroy() end
    draggable(btn, btn, function() obj:Set(not state) end)
    return obj
end

----------------------------------------------------------------------
-- sections / elements
----------------------------------------------------------------------
local Section = {}
Section.__index = Section

local function keyName(k)
    if typeof(k) == "EnumItem" then return k.Name end
    return type(k) == "string" and k or "Unknown"
end

-- a card row: header (fixed height) + optional description + extra children; auto-grows
function Section:_row(o, headerH)
    self._tab._order = self._tab._order + 1
    local row = make("Frame", {
        BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, headerH or 38), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self._tab._order, ClipsDescendants = true,
    }, self._tab._page)
    corner(row, 8); stroke(row, C.line, 1, 0.3)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, row)
    local header = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerH or 38), LayoutOrder = 1 }, row)
    local title = label(header, tostring(o.Title or ""), 13, C.text)
    title.Position, title.Size = UDim2.fromOffset(12, 0), UDim2.new(0.6, -12, 1, 0)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    if o.Content and o.Content ~= "" then
        local d = label(row, tostring(o.Content), 11, C.sub)
        d.LayoutOrder, d.TextWrapped = 2, true
        d.Size, d.AutomaticSize = UDim2.new(1, 0, 0, 12), Enum.AutomaticSize.Y
        pad(d, 12, 0, 12, 8)
    end
    return row, header, title
end

function Section:_reg(title, el, get, set)
    local win = self._win
    win._reg[#win._reg + 1] = { key = self._name .. "|" .. tostring(title), get = get, set = set }
    return el
end

function Section:AddHStack() return self end
function Section:AddSection() return self end

function Section:AddLabel(o)
    o = type(o) == "table" and o or { Title = tostring(o) }
    local _, _, t = self:_row({ Title = o.Title or o.Content or "" }, 30)
    t.TextColor3 = C.sub; t.Size = UDim2.new(1, -24, 1, 0)
    local el = {}
    function el:Set(v) t.Text = tostring(v) end
    return el
end

function Section:AddParagraph(o)
    local row, header, t = self:_row({ Title = o.Title or "", Content = o.Content }, 30)
    t.Font = FONT_B; t.Size = UDim2.new(1, -24, 1, 0)
    return {}
end

function Section:AddButton(o)
    local row, header, t = self:_row({ Title = "" }, 36)
    local b = make("TextButton", {
        BackgroundColor3 = C.card2, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 5),
        Text = tostring(o.Title or "Button"), Font = FONT, TextSize = 13, TextColor3 = C.text, AutoButtonColor = false,
    }, header)
    corner(b, 6); local st = stroke(b, C.line, 1)
    t:Destroy()
    connect(b.MouseEnter, function() tween(b, 0.12, { BackgroundColor3 = C.accent }); st.Color = C.accentHi end)
    connect(b.MouseLeave, function() tween(b, 0.12, { BackgroundColor3 = C.card2 }); st.Color = C.line end)
    connect(b.MouseButton1Click, function() if o.Callback then task.spawn(o.Callback) end end)
    return {}
end

function Section:AddToggle(o)
    local state = o.Default and true or false
    local row, header = self:_row(o, 38)
    local sw = make("Frame", { BackgroundColor3 = C.card2, Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0) }, header)
    corner(sw, 10); local st = stroke(sw, C.line, 1)
    local knob = make("Frame", { BackgroundColor3 = C.sub, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3) }, sw)
    corner(knob, 7)
    local el = {}
    local function render(anim)
        local pos = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
        local col = state and C.accent or C.card2
        local kcol = state and C.text or C.sub
        if anim then
            tween(knob, 0.15, { Position = pos, BackgroundColor3 = kcol }); tween(sw, 0.15, { BackgroundColor3 = col })
        else
            knob.Position, knob.BackgroundColor3, sw.BackgroundColor3 = pos, kcol, col
        end
        st.Color = state and C.accentHi or C.line
    end
    render(false)
    function el:Set(v)
        v = v and true or false
        if v == state then return end
        state = v; render(true)
        if o.Callback then task.spawn(o.Callback, state) end
    end
    function el:Get() return state end
    local hit = make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0) }, header)
    connect(hit.MouseButton1Click, function() el:Set(not state) end)
    return self:_reg(o.Title, el, function() return state end, function(v) el:Set(v) end)
end

function Section:AddSlider(o)
    local min, max = o.Min or 0, o.Max or 100
    local inc = o.Increment or 1
    local decimals = 0
    do
        local s = tostring(inc)
        local dot = s:find("%.")
        if dot then decimals = #s - dot end
    end
    local value = math.clamp(o.Default or min, min, max)
    local row, header = self:_row(o, 34)
    local val = label(header, "", 12, C.accentHi, FONT_B, Enum.TextXAlignment.Right)
    val.Position, val.Size = UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -12, 1, 0)
    local trackHit = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 3 }, row)
    local track = make("Frame", { BackgroundColor3 = C.card2, Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 2),
        BorderSizePixel = 0 }, trackHit)
    corner(track, 3)
    local fill = make("Frame", { BackgroundColor3 = C.accent, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, track)
    corner(fill, 3)
    make("UIGradient", { Color = ColorSequence.new(C.accent, C.accentHi) }, fill)
    local el = {}
    local function fmt(v) return decimals > 0 and string.format("%." .. decimals .. "f", v) or tostring(math.floor(v + 0.5)) end
    local function render()
        local a = (max == min) and 0 or (value - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        val.Text = fmt(value)
    end
    local function setValue(v, fire)
        v = math.clamp(math.floor((v - min) / inc + 0.5) * inc + min, min, max)
        if decimals > 0 then v = tonumber(string.format("%." .. decimals .. "f", v)) end
        if v == value then return end
        value = v; render()
        if fire and o.Callback then task.spawn(o.Callback, value) end
    end
    render()
    function el:Set(v) setValue(tonumber(v) or value, true) end
    function el:Get() return value end
    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * a, true)
    end
    connect(trackHit.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; fromX(i.Position.X)
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    return self:_reg(o.Title, el, function() return value end, function(v) el:Set(v) end)
end

function Section:AddDropdown(o)
    local opts = o.Options or {}
    local value = o.Default or opts[1]
    local row, header = self:_row(o, 38)
    local cur = label(header, tostring(value or ""), 12, C.accentHi, FONT_B, Enum.TextXAlignment.Right)
    cur.Position, cur.Size = UDim2.new(0.4, 0, 0, 0), UDim2.new(0.6, -30, 1, 0)
    local arrow = label(header, "v", 11, C.sub, FONT_B, Enum.TextXAlignment.Center)
    arrow.Position, arrow.Size = UDim2.new(1, -26, 0, 0), UDim2.fromOffset(20, 38)
    local list = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = 4 }, row)
    make("UIListLayout", { Padding = UDim.new(0, 3) }, list)
    pad(list, 8, 0, 8, 0)
    local buttons, open = {}, false
    local el = {}
    local function mark()
        for name, b in pairs(buttons) do
            b.TextColor3 = (name == value) and C.accentHi or C.text
            b.BackgroundColor3 = (name == value) and C.card2 or C.card
        end
    end
    local full = #opts * 27 + 8
    local function setOpen(v)
        open = v
        tween(list, 0.18, { Size = UDim2.new(1, 0, 0, v and full or 0) })
        arrow.Text = v and "^" or "v"
    end
    function el:Set(v)
        if v == value then return end
        value = v; cur.Text = tostring(v); mark()
        if o.Callback then task.spawn(o.Callback, v) end
    end
    function el:Get() return value end
    for _, name in ipairs(opts) do
        local b = make("TextButton", { BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 24), Text = tostring(name),
            Font = FONT, TextSize = 12, TextColor3 = C.text, AutoButtonColor = false }, list)
        corner(b, 5)
        buttons[name] = b
        connect(b.MouseButton1Click, function() el:Set(name); setOpen(false) end)
    end
    mark()
    local hit = make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0) }, header)
    connect(hit.MouseButton1Click, function() setOpen(not open) end)
    return self:_reg(o.Title, el, function() return value end, function(v) el:Set(v) end)
end

function Section:AddTargetSelector(o)
    local opts, vals = o.Options or {}, o.Values or o.Options or {}
    local toValue, toDisplay = {}, {}
    for i, name in ipairs(opts) do toValue[name] = vals[i] or name; toDisplay[vals[i] or name] = name end
    local dd = self:AddDropdown({
        Title = (o.Title or "Target") .. (o.DropdownTitle and (" - " .. o.DropdownTitle) or ""),
        Options = opts, Default = toDisplay[o.Default] or opts[1],
        Callback = function(name) if o.Callback then o.Callback(toValue[name] or name) end end,
    })
    return dd
end

function Section:AddInput(o)
    local value = tostring(o.Default or "")
    local row, header = self:_row(o, 38)
    local box = make("TextBox", {
        BackgroundColor3 = C.card2, Size = UDim2.new(0.4, 0, 0, 24), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0), Text = value, PlaceholderText = o.Placeholder or "", Font = FONT, TextSize = 12,
        TextColor3 = C.text, PlaceholderColor3 = C.sub, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
    }, header)
    corner(box, 6); stroke(box, C.line, 1)
    local el = {}
    function el:Set(v) value = tostring(v); box.Text = value; if o.Callback then task.spawn(o.Callback, value) end end
    function el:Get() return value end
    connect(box.FocusLost, function()
        value = box.Text
        if o.Callback then task.spawn(o.Callback, value) end
    end)
    return self:_reg(o.Title, el, function() return value end, function(v) el:Set(v) end)
end

function Section:AddKeybind(o)
    local key = keyName(o.Default)
    local row, header = self:_row(o, 38)
    local btn = make("TextButton", { BackgroundColor3 = C.card2, Size = UDim2.fromOffset(96, 24), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0), Font = FONT_B, TextSize = 12, TextColor3 = C.accentHi, AutoButtonColor = false,
        Text = "" }, header)
    corner(btn, 6); stroke(btn, C.line, 1)
    local listening = false
    local function render() btn.Text = listening and "..." or (key == "Unknown" and "None" or key) end
    render()
    local el = {}
    function el:Get() return key end
    function el:Set(k) key = keyName(k); render() end
    connect(btn.MouseButton1Click, function() listening = true; render() end)
    connect(UIS.InputBegan, function(i, gp)
        if listening then
            if i.UserInputType == Enum.UserInputType.Keyboard then
                key = (i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace) and "Unknown" or i.KeyCode.Name
                listening = false; render()
            end
        elseif not gp and key ~= "Unknown" and i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode.Name == key then
            if o.Callback then task.spawn(o.Callback) end
        end
    end)
    return self:_reg(o.Title, el, function() return key end, function(v) el:Set(v) end)
end

function Section:AddColorPicker(o)
    local color = o.Default or Color3.new(1, 1, 1)
    local h, s, v = Color3.toHSV(color)
    local row, header = self:_row(o, 38)
    local sw = make("TextButton", { BackgroundColor3 = color, Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0), Text = "", AutoButtonColor = false }, header)
    corner(sw, 6); stroke(sw, C.line, 1)
    local panel = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = 4 }, row)
    local open = false
    local el = {}
    local function apply(fire)
        color = Color3.fromHSV(h, s, v)
        sw.BackgroundColor3 = color
        if fire and o.Callback then task.spawn(o.Callback, color) end
    end
    local bars = {}
    local function bar(y, grad, get, set)
        local hit = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, y) }, panel)
        local tr = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 5),
            BorderSizePixel = 0 }, hit)
        corner(tr, 4)
        local g = make("UIGradient", {}, tr)
        local knob = make("Frame", { BackgroundColor3 = C.text, Size = UDim2.fromOffset(6, 16), Position = UDim2.new(0, 0, 0, -4),
            AnchorPoint = Vector2.new(0.5, 0), BorderSizePixel = 0 }, tr)
        corner(knob, 3)
        local b = { g = g, knob = knob, grad = grad, get = get }
        bars[#bars + 1] = b
        local dragging = false
        local function fromX(x)
            set(math.clamp((x - tr.AbsolutePosition.X) / math.max(1, tr.AbsoluteSize.X), 0, 1))
        end
        connect(hit.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true; fromX(i.Position.X)
            end
        end)
        connect(UIS.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
        end)
        connect(UIS.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end
    local function refresh()
        for _, b in ipairs(bars) do
            b.g.Color = b.grad()
            b.knob.Position = UDim2.new(b.get(), 0, 0, -4)
        end
    end
    bar(6, function()
        local k = {}
        for i = 0, 6 do k[#k + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 >= 1 and 0.999 or i / 6, 1, 1)) end
        return ColorSequence.new(k)
    end, function() return h end, function(a) h = a; apply(true); refresh() end)
    bar(28, function() return ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v)) end,
        function() return s end, function(a) s = a; apply(true); refresh() end)
    bar(50, function() return ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1)) end,
        function() return v end, function(a) v = a; apply(true); refresh() end)
    refresh()
    connect(sw.MouseButton1Click, function()
        open = not open
        tween(panel, 0.18, { Size = UDim2.new(1, 0, 0, open and 76 or 0) })
    end)
    function el:Set(c) color = c; h, s, v = Color3.toHSV(c); apply(true); refresh() end
    function el:Get() return color end
    return self:_reg(o.Title, el,
        function() return { color.R, color.G, color.B } end,
        function(t) if type(t) == "table" then el:Set(Color3.new(t[1], t[2], t[3])) end end)
end

function Section:AddTogglePanel(o)
    local toggle
    local syncing = false
    local panel = makePanel(o, function(val)
        if toggle and not syncing then syncing = true; pcall(function() toggle:Set(val) end); syncing = false end
    end)
    toggle = self:AddToggle({
        Title = o.Title or "Toggle", Default = o.Default,
        Callback = function(val)
            syncing = true; panel:Set(val); syncing = false
            if o.Callback then o.Callback(val) end
        end,
    })
    self:AddButton({ Title = o.ButtonTitle or ("Show / hide " .. (o.PanelTitle or "on-screen") .. " button"),
        Callback = function() panel:Toggle() end })
    return toggle
end

function Section:AddPresetManager(o)
    local names = {}
    for k in pairs(o.Presets or {}) do names[#names + 1] = k end
    table.sort(names)
    local input = self:AddInput({ Title = o.Title, Default = o.Default, Placeholder = o.Placeholder, Callback = o.Callback })
    if #names > 0 then
        self:AddDropdown({ Title = "Preset", Options = names, Default = names[1], Callback = function(name)
            local val = o.Presets[name]
            if val then input:Set(val) end
        end })
    end
    return input
end

function Section:AddConfig()
    local win = self._win
    local file = "MattXaviera/config.json"
    local HttpService = game:GetService("HttpService")
    self:AddButton({ Title = "Save Config", Callback = function()
        local data = {}
        for _, r in ipairs(win._reg) do local ok, v = pcall(r.get); if ok then data[r.key] = v end end
        local ok = pcall(function()
            if makefolder and isfolder and not isfolder("MattXaviera") then makefolder("MattXaviera") end
            writefile(file, HttpService:JSONEncode(data))
        end)
        Lib:MakeNotify({ Title = "Config", Content = ok and "Settings saved." or "Save failed (no file access).", Delay = 2 })
    end })
    self:AddButton({ Title = "Load Config", Callback = function()
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
        if not ok or type(data) ~= "table" then
            Lib:MakeNotify({ Title = "Config", Content = "No saved config found.", Delay = 2 }); return
        end
        for _, r in ipairs(win._reg) do
            if data[r.key] ~= nil then pcall(r.set, data[r.key]) end
        end
        Lib:MakeNotify({ Title = "Config", Content = "Settings loaded.", Delay = 2 })
    end })
end

----------------------------------------------------------------------
-- tab / window
----------------------------------------------------------------------
local function newSection(tab, title)
    tab._order = tab._order + 1
    local s = setmetatable({ _tab = tab, _win = tab._win, _name = title or "sec" }, Section)
    if title and title ~= "" then
        local h = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = tab._order }, tab._page)
        local t = label(h, string.upper(title), 11, C.accentHi, FONT_B)
        t.Position, t.Size = UDim2.fromOffset(4, 0), UDim2.new(1, -4, 0, 20)
        make("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 1), Position = UDim2.fromOffset(4, 22) }, h)
    end
    return s
end

local Tab = {}
Tab.__index = function(t, k)
    local m = rawget(Tab, k)
    if m then return m end
    if Section[k] then
        return function(self, ...)
            self._default = self._default or setmetatable({ _tab = self, _win = self._win, _name = self._title }, Section)
            return Section[k](self._default, ...)
        end
    end
end
function Tab:AddSection(title) return newSection(self, title) end

local Window = {}
Window.__index = Window

function Window:AddTab(o)
    local win = self
    local name = o.Name or "Tab"
    local btn = make("TextButton", { BackgroundColor3 = C.side, Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false,
        LayoutOrder = #win._tabs + 1 }, win._tabList)
    corner(btn, 6)
    local bar = make("Frame", { BackgroundColor3 = C.accentHi, Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 2, 0.5, -8),
        BorderSizePixel = 0, Visible = false }, btn)
    corner(bar, 2)
    local t = label(btn, name, 13, C.sub)
    t.Position, t.Size = UDim2.fromOffset(16, 0), UDim2.new(1, -20, 1, 0)
    local page = make("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false }, win._content)
    make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    pad(page, 10, 8, 12, 12)
    local tab = setmetatable({ _page = page, _order = 0, _win = win, _title = name, _btn = btn }, Tab)
    win._tabs[#win._tabs + 1] = tab
    local function select()
        for _, tb in ipairs(win._tabs) do
            tb._page.Visible = (tb == tab)
            tb._btn.BackgroundColor3 = (tb == tab) and C.card or C.side
            tb._btn:FindFirstChildOfClass("TextLabel").TextColor3 = (tb == tab) and C.text or C.sub
            tb._btn:FindFirstChildOfClass("Frame").Visible = (tb == tab)
        end
    end
    connect(btn.MouseButton1Click, select)
    if #win._tabs == 1 then select() end
    return tab
end

function Window:InfoTab(o)
    local tab = self:AddTab({ Name = o.Name or "Info" })
    local s = tab:AddSection(o.SectionTitle or "Information")
    s:AddParagraph({ Title = "MattXaviera " .. tostring(o.Version or ""), Content = o.DiscordDesc or "" })
    if o.DiscordLink then
        s:AddButton({ Title = "Copy Discord Link", Callback = function()
            pcall(function() setclipboard(o.DiscordLink) end)
            Lib:MakeNotify({ Title = "Discord", Content = "Link copied: " .. o.DiscordLink, Delay = 3 })
        end })
    end
    return tab
end

function Lib:Window(o)
    if gui then gui:Destroy() end
    gui = make("ScreenGui", { Name = "MattUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    gui.Parent = getRoot()

    local W, H = 580, 380
    local main = make("Frame", { Name = "Main", BackgroundColor3 = C.bg, Size = UDim2.fromOffset(W, H),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), ClipsDescendants = true, Visible = false }, gui)
    corner(main, 12); stroke(main, C.line, 1.2)
    make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(8, 14, 32), C.bg2), Rotation = 90 }, main)
    local scale = make("UIScale", {}, main)
    local function fit()
        local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
        scale.Scale = math.clamp(math.min(vp.X / (W + 40), vp.Y / (H + 40)), 0.5, 1)
    end
    fit()

    -- title bar
    local bar = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44) }, main)
    glitchText(bar, "MattXaviera", 20, 170, 44, Enum.TextXAlignment.Left).Position = UDim2.fromOffset(18, 0)
    local foot = label(bar, tostring(o.Footer or ""), 11, C.sub)
    foot.Position, foot.Size = UDim2.fromOffset(186, 4), UDim2.new(1, -300, 1, 0)
    make("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0) }, bar)
    local function tbtn(txt, x)
        local b = make("TextButton", { BackgroundColor3 = C.card, Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, x, 0.5, -12),
            Text = txt, Font = FONT_B, TextSize = 14, TextColor3 = C.text, AutoButtonColor = false }, bar)
        corner(b, 6)
        connect(b.MouseEnter, function() tween(b, 0.1, { BackgroundColor3 = C.accent }) end)
        connect(b.MouseLeave, function() tween(b, 0.1, { BackgroundColor3 = C.card }) end)
        return b
    end
    local minBtn, closeBtn = tbtn("-", -72), tbtn("x", -38)
    draggable(bar, main)

    -- side + content
    local side = make("Frame", { BackgroundColor3 = C.side, BorderSizePixel = 0, Size = UDim2.new(0, 140, 1, -45), Position = UDim2.fromOffset(0, 45) }, main)
    local tabList = make("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
    make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
    pad(tabList, 8, 10, 8, 8)
    make("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0) }, side)
    local content = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -141, 1, -45), Position = UDim2.fromOffset(141, 45),
        ClipsDescendants = true }, main)

    -- notifications holder
    notifyHolder = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(260, 400), AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -14) }, gui)
    make("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder }, notifyHolder)

    -- round "M" button (restore)
    local bubble = make("TextButton", { BackgroundColor3 = C.card, Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 14, 0, 70),
        Text = "M", Font = FONT_B, TextSize = 18, TextColor3 = C.text, AutoButtonColor = false, Visible = false, ZIndex = 30 }, gui)
    corner(bubble, 21); stroke(bubble, C.accentHi, 1.5)

    local function setOpen(v)
        main.Visible = v
        bubble.Visible = not v
        if v then fit() end
    end
    connect(minBtn.MouseButton1Click, function() setOpen(false) end)
    connect(bubble.MouseButton1Click, function() end) -- handled by draggable tap
    draggable(bubble, bubble, function() setOpen(true) end)
    connect(closeBtn.MouseButton1Click, function() Lib:Destroy() end)
    connect(UIS.InputBegan, function(i, gp)
        if not gp and i.KeyCode == Enum.KeyCode.RightShift then setOpen(not main.Visible) end
    end)
    if workspace.CurrentCamera then
        connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit)
    end

    -- intro splash with glitch title, then reveal the window
    local splash = make("CanvasGroup", { BackgroundColor3 = C.bg2, Size = UDim2.new(1, 0, 1, 0), ZIndex = 100 }, gui)
    make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(7, 13, 30), C.bg2), Rotation = 90 }, splash)
    local g = glitchText(splash, "MattXaviera", 46, 360, 70, Enum.TextXAlignment.Center)
    g.AnchorPoint, g.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, -8)
    local sub = label(splash, string.upper(tostring(o.Footer or "")), 12, C.sub, FONT, Enum.TextXAlignment.Center)
    sub.AnchorPoint, sub.Position, sub.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 38), UDim2.fromOffset(360, 16)
    task.delay(1.7, function()
        if not splash.Parent then return end
        main.Visible = true
        tween(splash, 0.5, { GroupTransparency = 1 })
        task.wait(0.55)
        if splash.Parent then splash:Destroy() end
    end)

    local win = setmetatable({ _tabs = {}, _tabList = tabList, _content = content, _reg = {}, _gui = gui }, Window)
    return win
end

function Lib:TogglePanel(o)
    return makePanel(o, function(v) if o.Callback then o.Callback(v) end end)
end

function Lib:Destroy()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    if gui then pcall(function() gui:Destroy() end) end
    gui, notifyHolder = nil, nil
    env.__MattUI = nil
end

env.__MattUI = Lib
return Lib
