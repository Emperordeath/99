print("Carregando Fluent UI Library...")

-- Apenas conserta o erro
local FluentFunc = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))
if FluentFunc then
    local Fluent = FluentFunc()
else
    warn("Fluent UI não carregou, mas o script continua...")
end

local SaveManagerFunc = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))
if SaveManagerFunc then
    local SaveManager = SaveManagerFunc()
end

local InterfaceManagerFunc = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))
if InterfaceManagerFunc then
    local InterfaceManager = InterfaceManagerFunc()
end

-- Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Variáveis
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local bandagens = {}
local baus = {}
local chaoAtivo = false
local chao = nil
local conexao = nil
local selectedBandage = nil
local selectedChest = nil

-- Configurações customizáveis
local Config = {
    stealthMode = false,
    stealthDelay = 0.5,
    chaoTransparency = 1,
    chaoSize = 200,
    theme = "Darker",
    particlesEnabled = false,
    antiAFK = false,
    antiVoid = false,
    espEnabled = false,
    espDistance = false,
    chamsEnabled = false,
    infiniteJump = false,
    dashEnabled = false,
    dashSpeed = 100
}

-- Sistema de Replay
local Replay = {
    recording = false,
    playing = false,
    route = {},
    currentIndex = 1
}

-- Sistema de Stats
local Stats = {
    startTime = os.time(),
    teleports = 0,
    itemsCollected = 0,
    distanceTraveled = 0
}

-- Sistema de Hotkeys
local Hotkeys = {
    toggleUI = Enum.KeyCode.RightControl,
    toggleESP = Enum.KeyCode.E,
    dash = Enum.KeyCode.Q,
    panic = Enum.KeyCode.P
}

-- ESP Objects
local ESPObjects = {}

-- Performance Monitor
local Performance = {
    fps = 0,
    ping = 0,
    memory = 0
}

local nomesBaus = {
    "Item Chest", "Item Chest2", "Item Chest3",
    "Item Chest4", "Item Chest5", "Item Chest6",
    "Chest", "ItemChest"
}

-- Notificação
local function notify(title, msg)
    Fluent:Notify({
        Title = title,
        Content = msg,
        Duration = 3
    })
end

-- Escanear itens
local function scan()
    bandagens = {}
    baus = {}
   
    if Workspace:FindFirstChild("Items") then
        for _, v in pairs(Workspace.Items:GetChildren()) do
            if v.Name == "Bandage" then
                table.insert(bandagens, v)
            else
                for _, nome in pairs(nomesBaus) do
                    if v.Name == nome then
                        table.insert(baus, v)
                        break
                    end
                end
            end
        end
    end
   
    print("Bandagens: " .. #bandagens .. " | Baús: " .. #baus)
end

-- Obter posição
local function getPos(item)
    return item:IsA("Model") and item:GetPivot().Position or item.Position
end

-- Calcular distância
local function getDist(item)
    if not hrp or not hrp.Parent then return math.huge end
    return (hrp.Position - getPos(item)).Magnitude
end

-- Teleportar
local function tele(item)
    if not item or not item.Parent then
        notify("❌ Erro", "Item não existe mais")
        return
    end
   
    if not hrp or not hrp.Parent then
        notify("❌ Erro", "Personagem não encontrado")
        return
    end
   
    local startPos = hrp.Position
    local pos = getPos(item)
    local targetCFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
   
    -- Modo Stealth
    if Config.stealthMode then
        local steps = 10
        local startCFrame = hrp.CFrame
        for i = 1, steps do
            hrp.CFrame = startCFrame:Lerp(targetCFrame, i / steps)
            task.wait(Config.stealthDelay / steps)
        end
    else
        hrp.CFrame = targetCFrame
    end
   
    -- Atualizar stats
    Stats.teleports = Stats.teleports + 1
    Stats.distanceTraveled = Stats.distanceTraveled + (startPos - pos).Magnitude
   
    -- Efeitos visuais
    if Config.particlesEnabled then
        local particles = Instance.new("ParticleEmitter")
        particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        particles.Color = ColorSequence.new(Color3.fromRGB(88, 101, 242))
        particles.Size = NumberSequence.new(0.5)
        particles.Lifetime = NumberRange.new(0.5, 1)
        particles.Rate = 50
        particles.Parent = hrp
        task.delay(1, function()
            particles.Enabled = false
            task.wait(1)
            particles:Destroy()
        end)
    end
   
    -- Salvar no replay
    if Replay.recording then
        table.insert(Replay.route, {pos = pos, name = item.Name})
    end
   
    notify("✅ Sucesso", "Teleportado!")
end

-- Teleportar mais próximo
local function teleProximo(lista, tipo)
    if #lista == 0 then
        notify("⚠️ Aviso", "Nenhum(a) " .. tipo .. " encontrado(a)")
        return
    end
   
    local closest = nil
    local minDist = math.huge
   
    for _, item in pairs(lista) do
        if item and item.Parent then
            local dist = getDist(item)
            if dist < minDist then
                minDist = dist
                closest = item
            end
        end
    end
   
    if closest then
        tele(closest)
    end
end

-- Criar chão
local function criarChao()
    if chao then chao:Destroy() end
   
    chao = Instance.new("Part")
    chao.Name = "ChaoInvisivel"
    chao.Size = Vector3.new(Config.chaoSize, 1, Config.chaoSize)
    chao.Anchored = true
    chao.Transparency = Config.chaoTransparency
    chao.CanCollide = true
    chao.Position = hrp.Position + Vector3.new(0, 50, 0)
    chao.Material = Enum.Material.ForceField
    chao.Color = Color3.fromRGB(88, 101, 242)
    chao.Parent = Workspace
   
    -- Teleportar jogador
    task.wait(0.1)
    hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 55, 0))
   
    notify("✅ Chão Ativo", "Você foi teleportado 50 studs acima!")
end

local function removerChao()
    if chao then
        chao:Destroy()
        chao = nil
        notify("🔴 Desativado", "Chão removido")
    end
end

-- Atualizar personagem
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = char:WaitForChild("HumanoidRootPart")
   
    if chaoAtivo then
        task.wait(0.5)
        criarChao()
        if conexao then conexao:Disconnect() end
        conexao = RunService.Heartbeat:Connect(function()
            if chao and hrp then
                local chaoY = chao.Position.Y
                chao.Position = Vector3.new(hrp.Position.X, chaoY, hrp.Position.Z)
               
                if hrp.Position.Y < chaoY then
                    hrp.CFrame = CFrame.new(hrp.Position.X, chaoY + 5, hrp.Position.Z)
                end
            end
        end)
    end
end)

-- ═══════════════════════════════════════
-- SISTEMAS AVANÇADOS
-- ═══════════════════════════════════════

-- Anti-AFK
local antiAFKConnection
local function toggleAntiAFK(enabled)
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
   
    if enabled then
        antiAFKConnection = RunService.Heartbeat:Connect(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        notify("✅ Anti-AFK", "Sistema ativado!")
    else
        notify("🔴 Anti-AFK", "Sistema desativado")
    end
end

-- Anti-Void
local antiVoidConnection
local lastSafePosition = nil
local function toggleAntiVoid(enabled)
    if antiVoidConnection then
        antiVoidConnection:Disconnect()
        antiVoidConnection = nil
    end
   
    if enabled then
        antiVoidConnection = RunService.Heartbeat:Connect(function()
            if hrp and hrp.Parent then
                if hrp.Position.Y > -100 then
                    lastSafePosition = hrp.Position
                elseif hrp.Position.Y < -100 and lastSafePosition then
                    hrp.CFrame = CFrame.new(lastSafePosition + Vector3.new(0, 10, 0))
                    notify("⚠️ Anti-Void", "Você foi salvo da queda!")
                end
            end
        end)
        notify("✅ Anti-Void", "Proteção ativada!")
    else
        notify("🔴 Anti-Void", "Proteção desativada")
    end
end

-- ESP System
local function clearESP()
    for _, obj in pairs(ESPObjects) do
        if obj and obj.Parent then
            obj:Destroy()
        end
    end
    ESPObjects = {}
end

local function createESP(item, color)
    if not item or not item.Parent then return end
   
    local box = Instance.new("BoxHandleAdornment")
    box.Size = item:IsA("Model") and item:GetExtentsSize() or item.Size
    box.Color3 = color or Color3.fromRGB(0, 255, 0)
    box.Transparency = 0.7
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Adornee = item
    box.Parent = item
   
    table.insert(ESPObjects, box)
    return box
end

local function createDistanceLabel(item)
    if not item or not item.Parent then return end
   
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 1000
    billboard.Adornee = item
    billboard.Parent = item
   
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard
   
    RunService.Heartbeat:Connect(function()
        if item and item.Parent and hrp and hrp.Parent then
            local dist = math.floor(getDist(item))
            label.Text = string.format("%d studs", dist)
        end
    end)
   
    table.insert(ESPObjects, billboard)
    return billboard
end

local function toggleESP(enabled)
    clearESP()
   
    if enabled then
        for _, item in pairs(bandagens) do
            if item and item.Parent then
                createESP(item, Color3.fromRGB(0, 255, 0))
                if Config.espDistance then
                    createDistanceLabel(item)
                end
            end
        end
       
        for _, item in pairs(baus) do
            if item and item.Parent then
                createESP(item, Color3.fromRGB(255, 200, 0))
                if Config.espDistance then
                    createDistanceLabel(item)
                end
            end
        end
       
        notify("✅ ESP", "ESP ativado!")
    else
        notify("🔴 ESP", "ESP desativado")
    end
end

-- Chams (Highlight)
local chamObjects = {}
local function toggleChams(enabled)
    for _, obj in pairs(chamObjects) do
        if obj and obj.Parent then
            obj:Destroy()
        end
    end
    chamObjects = {}
   
    if enabled then
        for _, item in pairs(bandagens) do
            if item and item.Parent then
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(0, 255, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.Parent = item
                table.insert(chamObjects, highlight)
            end
        end
       
        for _, item in pairs(baus) do
            if item and item.Parent then
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(255, 200, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.Parent = item
                table.insert(chamObjects, highlight)
            end
        end
       
        notify("✅ Chams", "Wallhack ativado!")
    else
        notify("🔴 Chams", "Wallhack desativado")
    end
end

-- Infinite Jump
local jumpConnection
local function toggleInfiniteJump(enabled)
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
   
    if enabled then
        local UserInputService = game:GetService("UserInputService")
        jumpConnection = UserInputService.JumpRequest:Connect(function()
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        notify("✅ Infinite Jump", "Pulo infinito ativado!")
    else
        notify("🔴 Infinite Jump", "Pulo infinito desativado")
    end
end

-- Dash System
local lastDash = 0
local function performDash()
    if os.clock() - lastDash < 1 then return end
    lastDash = os.clock()
   
    if hrp and char and char:FindFirstChild("Humanoid") then
        local direction = char.Humanoid.MoveDirection
        if direction.Magnitude > 0 then
            local velocity = Instance.new("BodyVelocity")
            velocity.Velocity = direction * Config.dashSpeed
            velocity.MaxForce = Vector3.new(100000, 0, 100000)
            velocity.Parent = hrp
           
            task.delay(0.2, function()
                velocity:Destroy()
            end)
           
            notify("⚡ Dash", "Dash executado!")
        end
    end
end

-- Performance Monitor
local function updatePerformance()
    RunService.Heartbeat:Connect(function()
        Performance.fps = math.floor(1 / RunService.Heartbeat:Wait())
        Performance.ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        Performance.memory = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
    end)
end

-- Hotkey System
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
   
    if input.KeyCode == Hotkeys.toggleUI then
        -- Toggle UI visibility
        local gui = player.PlayerGui:FindFirstChild("Fluent")
        if gui then
            gui.Enabled = not gui.Enabled
        end
    elseif input.KeyCode == Hotkeys.toggleESP then
        Config.espEnabled = not Config.espEnabled
        toggleESP(Config.espEnabled)
    elseif input.KeyCode == Hotkeys.dash and Config.dashEnabled then
        performDash()
    elseif input.KeyCode == Hotkeys.panic then
        -- Panic: desativa tudo
        Config.espEnabled = false
        Config.chamsEnabled = false
        Config.antiAFK = false
        Config.antiVoid = false
        Config.dashEnabled = false
        Config.infiniteJump = false
       
        toggleESP(false)
        toggleChams(false)
        toggleAntiAFK(false)
        toggleAntiVoid(false)
        toggleInfiniteJump(false)
       
        if conexao then conexao:Disconnect() end
        removerChao()
       
        notify("🚨 PANIC", "Tudo desativado!")
    end
end)

-- Iniciar performance monitor
updatePerformance()

-- ═══════════════════════════════════════
-- CRIAR INTERFACE
-- ═══════════════════════════════════════

local Window = Fluent:CreateWindow({
    Title = "🎯 Teleport Script " .. "v3.0",
    SubTitle = "by Deathbringer",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Garantir que a janela esteja visível
task.wait(0.1)  -- pequeno delay para garantir PlayerGui carregado
if Window.Main then
    Window.Main.Enabled = true
end

local Tabs = {
    Bandagens = Window:AddTab({ Title = "🩹 Bandagens", Icon = "" }),
    Baus = Window:AddTab({ Title = "📦 Baús", Icon = "" }),
    Chao = Window:AddTab({ Title = "🟦 Chão", Icon = "" }),
    Protecao = Window:AddTab({ Title = "🛡️ Proteção", Icon = "" }),
    Visual = Window:AddTab({ Title = "👁️ Visual", Icon = "" }),
    Movimento = Window:AddTab({ Title = "⚡ Movimento", Icon = "" }),
    Stats = Window:AddTab({ Title = "📊 Stats", Icon = "" }),
    Hotkeys = Window:AddTab({ Title = "⌨️ Hotkeys", Icon = "" }),
    QuickActions = Window:AddTab({ Title = "⚡ Quick", Icon = "" }),
    Customizacao = Window:AddTab({ Title = "🎨 Custom", Icon = "" }),
    Replay = Window:AddTab({ Title = "🎬 Replay", Icon = "" }),
    Settings = Window:AddTab({ Title = "⚙️ Config", Icon = "" })
}

-- ═══════════════════════════════════════
-- ABA BANDAGENS
-- ═══════════════════════════════════════

local BandagemSection = Tabs.Bandagens:AddSection("Teleporte de Bandagens")

local BandagemParagraph = Tabs.Bandagens:AddParagraph({
    Title = "📊 Status",
    Content = "Carregando..."
})

Tabs.Bandagens:AddButton({
    Title = "📍 Teleportar para Mais Próxima",
    Description = "Teleporta para a bandagem mais próxima de você",
    Callback = function()
        teleProximo(bandagens, "bandagem")
    end
})

local BandagemDropdown = Tabs.Bandagens:AddDropdown("BandagemDropdown", {
    Title = "Selecionar Bandagem",
    Description = "Escolha uma bandagem específica",
    Values = {},
    Multi = false,
    Default = nil,
})

BandagemDropdown:OnChanged(function(Value)
    selectedBandage = Value
end)

Tabs.Bandagens:AddButton({
    Title = "✅ Teleportar para Selecionada",
    Description = "Teleporta para a bandagem escolhida no menu",
    Callback = function()
        if selectedBandage then
            local index = tonumber(selectedBandage:match("#(%d+)"))
            if index and bandagens[index] then
                tele(bandagens[index])
            end
        else
            notify("⚠️ Aviso", "Selecione uma bandagem primeiro")
        end
    end
})

-- ═══════════════════════════════════════
-- ABA BAÚS
-- ═══════════════════════════════════════

local BauSection = Tabs.Baus:AddSection("Teleporte de Baús")

local BauParagraph = Tabs.Baus:AddParagraph({
    Title = "📊 Status",
    Content = "Carregando..."
})

Tabs.Baus:AddButton({
    Title = "📍 Teleportar para Mais Próximo",
    Description = "Teleporta para o baú mais próximo de você",
    Callback = function()
        teleProximo(baus, "baú")
    end
})

local BauDropdown = Tabs.Baus:AddDropdown("BauDropdown", {
    Title = "Selecionar Baú",
    Description = "Escolha um baú específico",
    Values = {},
    Multi = false,
    Default = nil,
})

BauDropdown:OnChanged(function(Value)
    selectedChest = Value
end)

Tabs.Baus:AddButton({
    Title = "✅ Teleportar para Selecionado",
    Description = "Teleporta para o baú escolhido no menu",
    Callback = function()
        if selectedChest then
            local index = tonumber(selectedChest:match("#(%d+)"))
            if index and baus[index] then
                tele(baus[index])
            end
        else
            notify("⚠️ Aviso", "Selecione um baú primeiro")
        end
    end
})

-- ═══════════════════════════════════════
-- ABA CHÃO
-- ═══════════════════════════════════════

local ChaoSection = Tabs.Chao:AddSection("Chão Invisível")

Tabs.Chao:AddParagraph({
    Title = "ℹ️ Informações",
    Content = "• Chão fica 50 studs ACIMA de você\n• TE TELEPORTA automaticamente\n• Você FICA no chão (não cai)\n• Chão te segue horizontalmente"
})

local ChaoToggle = Tabs.Chao:AddToggle("ChaoToggle", {
    Title = "🟢 Ativar Chão Invisível",
    Description = "Liga/Desliga o chão invisível",
    Default = false
})

ChaoToggle:OnChanged(function(value)
    chaoAtivo = value
   
    if value then
        criarChao()
        if conexao then conexao:Disconnect() end
        conexao = RunService.Heartbeat:Connect(function()
            if chao and hrp then
                local chaoY = chao.Position.Y
                chao.Position = Vector3.new(hrp.Position.X, chaoY, hrp.Position.Z)
               
                if hrp.Position.Y < chaoY then
                    hrp.CFrame = CFrame.new(hrp.Position.X, chaoY + 5, hrp.Position.Z)
                end
            end
        end)
      
