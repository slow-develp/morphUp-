-- =====================================================================
-- MorpUp v19 - Auto Farm unico (pega TUDO que da XP)
-- =====================================================================
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.5)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
if not LP then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LP = Players.LocalPlayer
end
if not LP then return warn("Sem LocalPlayer") end

local pgui = LP:WaitForChild("PlayerGui", 10)
if not pgui then return warn("Sem PlayerGui") end
for _, v in ipairs(pgui:GetChildren()) do
    if v.Name == "MorpUpV19" then v:Destroy() end
end

local Events = RS:WaitForChild("Events", 10)
local AttackRequest = Events and Events:FindFirstChild("AttackRequest")
local BerryPicked   = Events and Events:FindFirstChild("BerryPicked")

local CFG = {
    walkspeed = 20,
    distAtk = 10,
}

local S = {
    autoFarm = false,
    farmKill = false,
    halloween = false,
    alvoKill = nil,
    puloCooldown = 0,
}

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- velocidade
RunService.Heartbeat:Connect(function()
    local h = getHum()
    if h and h.WalkSpeed ~= CFG.walkspeed then h.WalkSpeed = CFG.walkspeed end
end)

-- =====================================================================
-- FILTRO UNIVERSAL DE COLETAVEIS
-- =====================================================================
-- Pastas conhecidas de coletaveis no MorpUp (do scan):
--   Workspace.Berries     -> bolinhas de XP
--   Workspace.Melons      -> melancias
-- Adiciona mais pastas/nomes conforme descobrirmos.

local PASTAS_COLETAVEIS = {
    ["Berries"] = true,
    ["Melons"] = true,
    ["Melon"] = true,
    ["Fruits"] = true,
    ["Fruit"] = true,
    ["Collectibles"] = true,
    ["Pickups"] = true,
    ["Foods"] = true,
    ["Food"] = true,
}

local NOMES_COLETAVEIS = {
    "berry", "melon", "watermelon", "fruit", "apple", "orange",
    "banana", "grape", "cherry", "peach", "pear", "lemon",
    "pickup", "collectible", "orb", "ball", "sphere",
}

local function isColetavel(o)
    if not o:IsA("BasePart") then return false end

    -- ignora personagens
    local m = o:FindFirstAncestorOfClass("Model")
    if m and m:FindFirstChildOfClass("Humanoid") then return false end

    -- checa pasta pai (e avo)
    local p = o.Parent
    if p and PASTAS_COLETAVEIS[p.Name] then return true end
    local avo = p and p.Parent
    if avo and PASTAS_COLETAVEIS[avo.Name] then return true end
    local bis = avo and avo.Parent
    if bis and PASTAS_COLETAVEIS[bis.Name] then return true end

    -- fallback: nome do objeto contem palavra de coletavel
    local nome = string.lower(o.Name)
    for _, palavra in ipairs(NOMES_COLETAVEIS) do
        if string.find(nome, palavra, 1, true) then
            -- tamanho pequeno pra nao pegar decoracao
            local sz = o.Size
            local tam = (sz.X + sz.Y + sz.Z) / 3
            if tam <= 8 then return true end
        end
    end

    return false
end

-- =====================================================================
-- IR ATE E COLETAR (loop continuo com anti-preso)
-- =====================================================================
local function irEColetar(parte, timeoutMax)
    timeoutMax = timeoutMax or 4
    local t0 = tick()
    while tick() - t0 < timeoutMax do
        if not parte or not parte.Parent then return end
        local hum = getHum()
        local hrp = getHRP()
        if not hum or not hrp then return end

        local d = (hrp.Position - parte.Position).Magnitude

        if d < 4.5 then
            hum:MoveTo(hrp.Position)
            task.wait(0.05)
            local char = LP.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then
                        pcall(function()
                            firetouchinterest(p, parte, 0)
                            task.wait(0.02)
                            firetouchinterest(p, parte, 1)
                        end)
                    end
                end
            end
            if BerryPicked then
                pcall(function() BerryPicked:FireServer(parte) end)
                pcall(function() BerryPicked:FireServer(parte, parte.Position) end)
            end
            pcall(function()
                local pp = parte:FindFirstChildOfClass("ProximityPrompt")
                if pp then fireproximityprompt(pp) end
            end)
            task.wait(0.05)
            return
        end

        hum:MoveTo(parte.Position)

        if hrp.AssemblyLinearVelocity.Magnitude < 2 and tick() > S.puloCooldown then
            hum.Jump = true
            S.puloCooldown = tick() + 0.5
        end

        task.wait(0.08)
    end
    local hum = getHum()
    local hrp = getHRP()
    if hum and hrp then hum:MoveTo(hrp.Position) end
end

-- =====================================================================
-- LOOP AUTO FARM (pega tudo perto)
-- =====================================================================
local function loopAutoFarm()
    while S.autoFarm do
        local hrp = getHRP()
        if hrp then
            local alvo, menor = nil, math.huge
            for _, o in ipairs(workspace:GetDescendants()) do
                if isColetavel(o) then
                    local d = (o.Position - hrp.Position).Magnitude
                    if d < menor then menor = d; alvo = o end
                end
            end
            if alvo then
                irEColetar(alvo, 4)
                task.wait(0.05)
            else
                task.wait(0.4)
            end
        else
            task.wait(0.4)
        end
    end
end

-- =====================================================================
-- KILL GRUDADO
-- =====================================================================
local function escolherAlvo()
    local hrp = getHRP()
    if not hrp then return nil end
    local melhor, menor = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            local u = p.Character:FindFirstChildOfClass("Humanoid")
            if h and u and u.Health > 0 then
                local d = (h.Position - hrp.Position).Magnitude
                if d < menor then menor = d; melhor = p end
            end
        end
    end
    return melhor
end

local function atacar()
    if AttackRequest then
        pcall(function() AttackRequest:FireServer("Primary") end)
    end
end

local killConn = nil
local atkThread = nil

local function comecarKill()
    if killConn then killConn:Disconnect() end
    killConn = RunService.Heartbeat:Connect(function()
        if not S.farmKill then return end
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end

        local aU = S.alvoKill and S.alvoKill.Character
            and S.alvoKill.Character:FindFirstChildOfClass("Humanoid")
        if not S.alvoKill or not S.alvoKill.Character
           or not S.alvoKill.Character:FindFirstChild("HumanoidRootPart")
           or not aU or aU.Health <= 0 then
            S.alvoKill = escolherAlvo()
            return
        end

        local aH = S.alvoKill.Character:FindFirstChild("HumanoidRootPart")
        if not aH then return

        local dist = (hrp.Position - aH.Position).Magnitude
        if dist > CFG.distAtk then
            hum:MoveTo(aH.Position)
            if hrp.AssemblyLinearVelocity.Magnitude < 2 and tick() > S.puloCooldown then
                hum.Jump = true
                S.puloCooldown = tick() + 0.5
            end
        else
            hum:MoveTo(hrp.Position)
        end
    end)

    if atkThread then return end
    atkThread = task.spawn(function()
        while S.farmKill do
            local hrp = getHRP()
            local aH = S.alvoKill and S.alvoKill.Character
                and S.alvoKill.Character:FindFirstChild("HumanoidRootPart")
            if hrp and aH then
                local d = (hrp.Position - aH.Position).Magnitude
                if d <= CFG.distAtk then atacar() end
            end
            task.wait(0.1)
        end
        atkThread = nil
    end)
end

local function pararKill()
    if killConn then killConn:Disconnect(); killConn = nil end
    S.alvoKill = nil
end

-- =====================================================================
-- HALLOWEEN
-- =====================================================================
local function isEvento(o)
    if not (o:IsA("BasePart") or o:IsA("Model")) then return false end
    local n = string.lower(o.Name)
    return n:find("candy") or n:find("doce") or n:find("tomb")
        or n:find("grave") or n:find("catacomb") or n:find("puzzle")
        or n:find("pumpkin") or n:find("halloween") or n:find("sweet")
end

local function loopHalloween()
    while S.halloween do
        local hrp = getHRP()
        if hrp then
            local alvo, menor = nil, math.huge
            for _, o in ipairs(workspace:GetDescendants()) do
                if isEvento(o) then
                    local pos = o.Position or (o.PrimaryPart and o.PrimaryPart.Position)
                    if pos then
                        local d = (pos - hrp.Position).Magnitude
                        if d < menor then menor = d; alvo = {obj = o, pos = pos} end
                    end
                end
            end
            if alvo then
                local hum = getHum()
                if hum then
                    local t0 = tick()
                    while tick() - t0 < 6 do
                        hum = getHum()
                        hrp = getHRP()
                        if not hum or not hrp then break end
                        local d = (hrp.Position - alvo.pos).Magnitude
                        if d < 5 then break end
                        hum:MoveTo(alvo.pos)
                        if hrp.AssemblyLinearVelocity.Magnitude < 2 and tick() > S.puloCooldown then
                            hum.Jump = true
                            S.puloCooldown = tick() + 0.5
                        end
                        task.wait(0.08)
                    end
                    task.wait(0.2)
                    local char = LP.Character
                    if char then
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then
                                pcall(function()
                                    firetouchinterest(p, alvo.obj, 0)
                                    task.wait(0.02)
                                    firetouchinterest(p, alvo.obj, 1)
                                end)
                            end
                        end
                    end
                    pcall(function()
                        for _, c in ipairs(alvo.obj:GetDescendants()) do
                            if c:IsA("ProximityPrompt") then fireproximityprompt(c) end
                            if c:IsA("ClickDetector") then fireclickdetector(c) end
                        end
                    end)
                    pcall(function() mouse1click() end)
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end
    end
end

-- =====================================================================
-- UI
-- =====================================================================
local C = {
    BG = Color3.fromRGB(18, 18, 24),
    PANEL = Color3.fromRGB(28, 28, 38),
    CARD = Color3.fromRGB(38, 38, 52),
    ACC = Color3.fromRGB(88, 101, 242),
    ACC2 = Color3.fromRGB(120, 130, 255),
    ON = Color3.fromRGB(80, 200, 120),
    OFF = Color3.fromRGB(55, 55, 70),
    TXT = Color3.fromRGB(240, 240, 250),
    SUB = Color3.fromRGB(150, 150, 170),
    RED = Color3.fromRGB(200, 60, 60),
    HALLOWEEN = Color3.fromRGB(255, 140, 0),
}

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = o
end
local function stroke(o, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col or C.PANEL
    s.Thickness = t or 1
    s.Transparency = 0.3
    s.Parent = o
end

local gui = Instance.new("ScreenGui")
gui.Name = "MorpUpV19"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pgui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 380)
main.Position = UDim2.new(0.5, -160, 0, 40)
main.BackgroundColor3 = C.BG
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
corner(main, 12)
stroke(main, C.ACC, 1.5)

local hd = Instance.new("Frame")
hd.Size = UDim2.new(1, 0, 0, 40)
hd.BackgroundColor3 = C.PANEL
hd.BorderSizePixel = 0
hd.Parent = main
corner(hd, 12)

local hdFix = Instance.new("Frame")
hdFix.Size = UDim2.new(1, 0, 0, 12)
hdFix.Position = UDim2.new(0, 0, 1, -12)
hdFix.BackgroundColor3 = C.PANEL
hdFix.BorderSizePixel = 0
hdFix.Parent = hd

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(0, 14, 0.5, -4)
dot.BackgroundColor3 = C.ACC
dot.BorderSizePixel = 0
dot.Parent = hd
corner(dot, 4)

local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(1, -100, 1, 0)
ttl.Position = UDim2.new(0, 30, 0, 0)
ttl.BackgroundTransparency = 1
ttl.Text = "MorpUp v19"
ttl.TextColor3 = C.TXT
ttl.TextSize = 15
ttl.Font = Enum.Font.GothamBold
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Parent = hd

local minB = Instance.new("TextButton")
minB.Size = UDim2.new(0, 26, 0, 26)
minB.Position = UDim2.new(1, -60, 0.5, -13)
minB.BackgroundColor3 = C.CARD
minB.Text = "-"
minB.TextColor3 = C.TXT
minB.TextSize = 16
minB.Font = Enum.Font.GothamBold
minB.BorderSizePixel = 0
minB.AutoButtonColor = false
minB.Parent = hd
corner(minB, 6)

local clsB = Instance.new("TextButton")
clsB.Size = UDim2.new(0, 26, 0, 26)
clsB.Position = UDim2.new(1, -30, 0.5, -13)
clsB.BackgroundColor3 = C.RED
clsB.Text = "X"
clsB.TextColor3 = C.TXT
clsB.TextSize = 13
clsB.Font = Enum.Font.GothamBold
clsB.BorderSizePixel = 0
clsB.AutoButtonColor = false
clsB.Parent = hd
corner(clsB, 6)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 32)
tabBar.Position = UDim2.new(0, 10, 0, 48)
tabBar.BackgroundColor3 = C.PANEL
tabBar.BorderSizePixel = 0
tabBar.Parent = main
corner(tabBar, 8)

local tabLay = Instance.new("UIListLayout")
tabLay.FillDirection = Enum.FillDirection.Horizontal
tabLay.Padding = UDim.new(0, 4)
tabLay.VerticalAlignment = Enum.VerticalAlignment.Center
tabLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLay.Parent = tabBar

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -112)
scroll.Position = UDim2.new(0, 10, 0, 88)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = C.ACC
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 4)
pad.Parent = scroll

list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 12)
end)

local abas, abasBtns = {}, {}

local function criarAba(nome, corAtiva)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 100, 0, 24)
    b.BackgroundColor3 = C.CARD
    b.Text = nome
    b.TextColor3 = C.SUB
    b.TextSize = 12
    b.Font = Enum.Font.GothamSemibold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = tabBar
    corner(b, 6)
    abasBtns[nome] = { btn = b, cor = corAtiva or C.ACC }

    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = scroll

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = f

    abas[nome] = f
    b.MouseButton1Click:Connect(function()
        for n, fr in pairs(abas) do fr.Visible = (n == nome) end
        for n, info in pairs(abasBtns) do
            info.btn.BackgroundColor3 = (n == nome) and info.cor or C.CARD
            info.btn.TextColor3 = (n == nome) and C.TXT or C.SUB
        end
    end)
    return f
end

local currentTab = nil

local function makeHeader(txt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 18)
    f.BackgroundTransparency = 1
    f.Parent = currentTab
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -6, 1, 0)
    l.Position = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = string.upper(txt)
    l.TextColor3 = C.ACC2
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
end

local function makeToggle(txt, init, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = C.CARD
    b.Text = ""
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = currentTab
    corner(b, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -70, 1, 0)
    l.Position = UDim2.new(0, 14, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = C.TXT
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = b

    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, 44, 0, 22)
    ind.Position = UDim2.new(1, -56, 0.5, -11)
    ind.BackgroundColor3 = init and C.ON or C.OFF
    ind.BorderSizePixel = 0
    ind.Parent = b
    corner(ind, 11)

    local kn = Instance.new("Frame")
    kn.Size = UDim2.new(0, 16, 0, 16)
    kn.Position = init and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    kn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    kn.BorderSizePixel = 0
    kn.Parent = ind
    corner(kn, 8)

    local st = init
    b.MouseButton1Click:Connect(function()
        st = not st
        ind.BackgroundColor3 = st and C.ON or C.OFF
        kn.Position = st and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        cb(st)
    end)
end

local function makeTextbox(txt, init, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.BackgroundColor3 = C.CARD
    f.BorderSizePixel = 0
    f.Parent = currentTab
    corner(f, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 140, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = C.SUB
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -160, 0, 26)
    tb.Position = UDim2.new(1, -148, 0.5, -13)
    tb.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    tb.Text = tostring(init or "")
    tb.TextColor3 = C.TXT
    tb.TextSize = 13
    tb.Font = Enum.Font.Gotham
    tb.ClearTextOnFocus = false
    tb.PlaceholderText = "..."
    tb.PlaceholderColor3 = C.SUB
    tb.BorderSizePixel = 0
    tb.Parent = f
    corner(tb, 5)

    tb.FocusLost:Connect(function() cb(tb.Text) end)
end

local function makeButton(txt, cb, cor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = cor or C.CARD
    b.Text = txt
    b.TextColor3 = C.TXT
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = currentTab
    corner(b, 6)
    b.MouseButton1Click:Connect(cb)
end

-- ABA FARM
currentTab = criarAba("Farm")
makeHeader("Configuracao")
makeTextbox("Velocidade", 20, function(v)
    local n = tonumber(v)
    if n and n >= 1 and n <= 100 then CFG.walkspeed = n end
end)
makeHeader("Auto Farm")
makeToggle("Auto Farm (pega tudo)", false, function(v)
    S.autoFarm = v
    if v then task.spawn(loopAutoFarm) end
end)
makeHeader("Auto Kill")
makeToggle("Farm Kill", false, function(v)
    S.farmKill = v
    if v then
        S.alvoKill = escolherAlvo()
        comecarKill()
    else
        pararKill()
    end
end)
makeTextbox("Distancia Ataque", 10, function(v)
    local n = tonumber(v)
    if n and n >= 3 and n <= 25 then CFG.distAtk = n end
end)

-- ABA HALLOWEEN
currentTab = criarAba("Halloween", C.HALLOWEEN)
makeHeader("Evento")
makeToggle("Auto Evento", false, function(v)
    S.halloween = v
    if v then task.spawn(loopHalloween) end
end)
makeHeader("Scan")
makeButton("Escanear Evento (console)", function()
    print("=== SCAN EVENTO ===")
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Model") then
            local n = string.lower(v.Name)
            if n:find("candy") or n:find("doce") or n:find("tomb")
               or n:find("grave") or n:find("catacomb") or n:find("puzzle")
               or n:find("pumpkin") or n:find("halloween") then
                print(v:GetFullName(), "|", v.ClassName)
            end
        end
    end
    print("=== FIM ===")
end)
makeButton("Escanear Coletaveis (console)", function()
    print("=== SCAN COLETAVEIS ===")
    local pastas = {}
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Folder") or v:IsA("Model") then
            local temPart = false
            for _, c in ipairs(v:GetChildren()) do
                if c:IsA("BasePart") then temPart = true break end
            end
            if temPart then
                print("[PASTA] " .. v.Name .. " (" .. v.ClassName .. ")")
            end
        end
    end
    print("=== FIM ===")
end)

abasBtns["Farm"].btn.BackgroundColor3 = C.ACC
abasBtns["Farm"].btn.TextColor3 = C.TXT
abas["Farm"].Visible = true

local floatB = Instance.new("TextButton")
floatB.Size = UDim2.new(0, 50, 0, 50)
floatB.Position = UDim2.new(0, 15, 0.35, 0)
floatB.BackgroundColor3 = C.ACC
floatB.Text = "MF"
floatB.TextColor3 = C.TXT
floatB.TextSize = 15
floatB.Font = Enum.Font.GothamBold
floatB.BorderSizePixel = 0
floatB.AutoButtonColor = false
floatB.Visible = false
floatB.Parent = gui
corner(floatB, 25)
stroke(floatB, C.ACC2, 1.5)

minB.MouseButton1Click:Connect(function() main.Visible = false; floatB.Visible = true end)
floatB.MouseButton1Click:Connect(function() main.Visible = true; floatB.Visible = false end)
clsB.MouseButton1Click:Connect(function() gui:Destroy() end)

print("[MorpUp v19] carregado")
print(">>> Farm: 1 toggle so, pega tudo")
print(">>> Se achar coletavel novo, use 'Escanear Coletaveis' e me manda")
