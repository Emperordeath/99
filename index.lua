--[[
═══════════════════════════════════════════════════════════════
    Script Teleporte Premium v4.0 - MOBILE & PC
    Com Rayfield UI Library
    Feito por Claude
═══════════════════════════════════════════════════════════════
--]]

print("Iniciando carregamento do Rayfield...")

-- Carregar Rayfield com segurança
local Rayfield
local success, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    warn("Erro ao carregar Rayfield: " .. tostring(err))
    game.StarterGui:SetCore("SendNotification", {
        Title = "❌ Erro",
        Text = "Falha ao carregar Rayfield UI",
        Duration = 5
    })
    return
end

print("Rayfield carregado com sucesso!")

-- Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

-- Variáveis
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local bandagens = {}
local baus = {}
local chaoAtivo = false
local chao = nil
local conexao = nil

local nomesBaus = {
    "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest5", "Item Chest6",
    "Chest", "ItemChest"
}

-- Configurações
local Config = {
    stealthMode = false,
    stealthDelay = 0.5,
    chaoTransparency = 1,
    chaoSize = 200,
    particlesEnabled = false
}

-- Replay
local Replay = {
    recording = false,
    playing = false,
    route = {}
}

-- EXPERIMENTAL
local Experimental = {
    antiAFK = false,
    antiVoid = false,
    espEnabled = false,
    espDistance = false,
    chamsEnabled = false,
    infiniteJump = false,
    dashEnabled = false,
    dashSpeed = 100
}

local Stats = {
    startTime = os.time(),
    sessionTime = "00:00:00"
}

local Performance = {
    fps = 0,
    ping = 0,
    memory = 0
}

local ESPObjects = {}
local chamObjects = {}
local antiAFKConnection = nil
local antiVoidConnection = nil
local jumpConnection = nil
local lastDash = 0
local lastSafePosition = nil

-- Notificação
local function notify(title, msg, duration)
    Rayfield:Notify({
        Title = title,
        Content = msg,
        Duration = duration or 3,
        Image = 4483362458
    })
end

-- Escanear
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
    
    print("Scan completo - Bandagens: " .. #bandagens .. " | Baús: " .. #baus)
end

-- Obter posição
local function getPos(item)
    return item:IsA("Model") and item:GetPivot().Position or item.Position
end

-- Distância
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
    
    local pos = getPos(item)
    local targetCFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    
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
    
    if Replay.recording then
        table.insert(Replay.route, {pos = pos, name = item.Name})
    end
    
    notify("✅ Sucesso", "Teleportado!", 2)
end

-- Teleportar próximo
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
    
    if closest then tele(closest) end
end

-- Chão
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
    
    task.wait(0.1)
    hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 55, 0))
    notify("✅ Chão Ativo", "Teleportado 50 studs acima!")
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
-- FUNÇÕES EXPERIMENTAIS
-- ═══════════════════════════════════════

-- 41. Anti-AFK
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
        notify("✅ Anti-AFK", "Proteção ativada", 2)
    end
end

-- 42. Anti-Void
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
                    notify("⚠️ Anti-Void", "Você foi salvo!", 2)
                end
            end
        end)
        notify("✅ Anti-Void", "Proteção ativada", 2)
    end
end

-- 36. ESP Boxes
local function clearESP()
    for _, obj in pairs(ESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    ESPObjects = {}
end

local function createESP(item, color)
    if not item or not item.Parent then return end
    
    local box = Instance.new("BoxHandleAdornment")
    box.Size = item:IsA("Model") and item:GetExtentsSize() or item.Size
    box.Color3 = color
    box.Transparency = 0.7
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Adornee = item
    box.Parent = item
    
    table.insert(ESPObjects, box)
end

-- 37. ESP Distance
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
            label.Text = string.format("%d m", dist)
        end
    end)
    
    table.insert(ESPObjects, billboard)
end

local function toggleESP(enabled)
    clearESP()
    
    if enabled then
        for _, item in pairs(bandagens) do
            if item and item.Parent then
                createESP(item, Color3.fromRGB(0, 255, 0))
                if Experimental.espDistance then
                    createDistanceLabel(item)
                end
            end
        end
        
        for _, item in pairs(baus) do
            if item and item.Parent then
                createESP(item, Color3.fromRGB(255, 200, 0))
                if Experimental.espDistance then
                    createDistanceLabel(item)
                end
            end
        end
        notify("✅ ESP", "ESP ativado", 2)
    end
end

-- 39. Chams
local function clearChams()
    for _, obj in pairs(chamObjects) do
        pcall(function() obj:Destroy() end)
    end
    chamObjects = {}
end

local function toggleChams(enabled)
    clearChams()
    
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
        notify("✅ Chams", "Wallhack ativado", 2)
    end
end

-- 52. Infinite Jump
local function toggleInfiniteJump(enabled)
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    if enabled then
        jumpConnection = UserInputService.JumpRequest:Connect(function()
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        notify("✅ Infinite Jump", "Ativado", 2)
    end
end

-- 53. Dash
local function performDash()
    if os.clock() - lastDash < 1 then return end
    lastDash = os.clock()
    
    if hrp and char and char:FindFirstChild("Humanoid") then
        local direction = char.Humanoid.MoveDirection
        if direction.Magnitude > 0 then
            local velocity = Instance.new("BodyVelocity")
            velocity.Velocity = direction * Experimental.dashSpeed
            velocity.MaxForce = Vector3.new(100000, 0, 100000)
            velocity.Parent = hrp
            
            task.delay(0.2, function()
                velocity:Destroy()
            end)
        end
    end
end

-- 80. Performance Monitor
task.spawn(function()
    while true do
        task.wait(1)
        Performance.fps = math.floor(1 / RunService.Heartbeat:Wait())
        
        local pingStats = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
        Performance.ping = pingStats and math.floor(pingStats:GetValue()) or 0
        
        Performance.memory = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
        
        local sessionTime = os.time() - Stats.startTime
        local hours = math.floor(sessionTime / 3600)
        local minutes = math.floor((sessionTime % 3600) / 60)
        local seconds = sessionTime % 60
        Stats.sessionTime = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    end
end)

-- 66. Hotkeys
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E then
        Experimental.espEnabled = not Experimental.espEnabled
        toggleESP(Experimental.espEnabled)
    elseif input.KeyCode == Enum.KeyCode.Q and Experimental.dashEnabled then
        performDash()
    elseif input.KeyCode == Enum.KeyCode.P then
        -- PANIC BUTTON
        Experimental.espEnabled = false
        Experimental.chamsEnabled = false
        Experimental.antiAFK = false
        Experimental.antiVoid = false
        Experimental.dashEnabled = false
        Experimental.infiniteJump = false
        
        toggleESP(false)
        toggleChams(false)
        toggleAntiAFK(false)
        toggleAntiVoid(false)
        toggleInfiniteJump(false)
        
        if conexao then conexao:Disconnect() end
        removerChao()
        
        notify("🚨 PANIC", "Tudo desativado!", 3)
    end
end)

-- ═══════════════════════════════════════
-- CRIAR INTERFACE RAYFIELD
-- ═══════════════════════════════════════

local Window = Rayfield:CreateWindow({
    Name = "🎯 Teleport Script v4.0",
    LoadingTitle = "Carregando Script Premium",
    LoadingSubtitle = "by Claude - Mobile & PC",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- ═══════════════════════════════════════
-- TAB BANDAGENS
-- ═══════════════════════════════════════

local TabBandagens = Window:CreateTab("🩹 Bandagens", 4483362458)
local SectionBand = TabBandagens:CreateSection("Teleporte de Bandagens")

local LabelBand = TabBandagens:CreateLabel("Bandagens encontradas: " .. #bandagens)

TabBandagens:CreateButton({
    Name = "📍 Teleportar para Mais Próxima",
    Callback = function()
        teleProximo(bandagens, "bandagem")
    end
})

local DropdownBand = TabBandagens:CreateDropdown({
    Name = "Selecionar Bandagem Específica",
    Options = {},
    CurrentOption = "Selecione",
    Flag = "BandagemDropdown",
    Callback = function(Option)
        local index = tonumber(Option:match("#(%d+)"))
        if index and bandagens[index] then
            tele(bandagens[index])
        end
    end
})

TabBandagens:CreateButton({
    Name = "🔄 Atualizar Lista",
    Callback = function()
        scan()
        LabelBand:Set("Bandagens encontradas: " .. #bandagens)
        
        local options = {}
        for i, v in pairs(bandagens) do
            if v and v.Parent then
                local dist = math.floor(getDist(v))
                table.insert(options, string.format("Bandage #%d (%d studs)", i, dist))
            end
        end
        DropdownBand:Refresh(options)
        
        notify("✅ Atualizado", #bandagens .. " bandagens encontradas")
    end
})

-- ═══════════════════════════════════════
-- TAB BAÚS
-- ═══════════════════════════════════════

local TabBaus = Window:CreateTab("📦 Baús", 4483362458)
local SectionBau = TabBaus:CreateSection("Teleporte de Baús")

local LabelBau = TabBaus:CreateLabel("Baús encontrados: " .. #baus)

TabBaus:CreateButton({
    Name = "📍 Teleportar para Mais Próximo",
    Callback = function()
        teleProximo(baus, "baú")
    end
})

local DropdownBau = TabBaus:CreateDropdown({
    Name = "Selecionar Baú Específico",
    Options = {},
    CurrentOption = "Selecione",
    Flag = "BauDropdown",
    Callback = function(Option)
        local index = tonumber(Option:match("#(%d+)"))
        if index and baus[index] then
            tele(baus[index])
        end
    end
})

TabBaus:CreateButton({
    Name = "🔄 Atualizar Lista",
    Callback = function()
        scan()
        LabelBau:Set("Baús encontrados: " .. #baus)
        
        local options = {}
        for i, v in pairs(baus) do
            if v and v.Parent then
                local dist = math.floor(getDist(v))
                table.insert(options, string.format("%s #%d (%d studs)", v.Name, i, dist))
            end
        end
        DropdownBau:Refresh(options)
        
        notify("✅ Atualizado", #baus .. " baús encontrados")
    end
})

-- ═══════════════════════════════════════
-- TAB CHÃO
-- ═══════════════════════════════════════

local TabChao = Window:CreateTab("🟦 Chão", 4483362458)
local SectionChao = TabChao:CreateSection("Chão Invisível")

TabChao:CreateLabel("ℹ️ Chão fica 50 studs ACIMA de você")
TabChao:CreateLabel("ℹ️ TE TELEPORTA automaticamente")
TabChao:CreateLabel("ℹ️ Você FICA no chão (não cai)")

TabChao:CreateToggle({
    Name = "🟢 Ativar Chão Invisível",
    CurrentValue = false,
    Flag = "ChaoToggle",
    Callback = function(Value)
        chaoAtivo = Value
        
        if Value then
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
        else
            if conexao then conexao:Disconnect() end
            removerChao()
        end
    end
})

-- ═══════════════════════════════════════
-- TAB CUSTOMIZAÇÃO
-- ═══════════════════════════════════════

local TabCustom = Window:CreateTab("🎨 Custom", 4483362458)
local SectionCustom = TabCustom:CreateSection("Personalização Visual")

TabCustom:CreateSlider({
    Name = "🔲 Transparência do Chão (%)",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 100,
    Flag = "TransparencySlider",
    Callback = function(Value)
        Config.chaoTransparency = Value / 100
        if chao then
            chao.Transparency = Config.chaoTransparency
        end
    end
})

TabCustom:CreateSlider({
    Name = "📏 Tamanho do Chão (studs)",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = 200,
    Flag = "SizeSlider",
    Callback = function(Value)
        Config.chaoSize = Value
        if chao then
            chao.Size = Vector3.new(Value, 1, Value)
        end
    end
})

TabCustom:CreateToggle({
    Name = "✨ Efeitos de Partículas",
    CurrentValue = false,
    Flag = "ParticlesToggle",
    Callback = function(Value)
        Config.particlesEnabled = Value
    end
})

-- ═══════════════════════════════════════
-- TAB REPLAY
-- ═══════════════════════════════════════

local TabReplay = Window:CreateTab("🎬 Replay", 4483362458)
local SectionReplay = TabReplay:CreateSection("Sistema de Replay")

TabReplay:CreateLabel("1. Iniciar Gravação")
TabReplay:CreateLabel("2. Teleporte pelos locais")
TabReplay:CreateLabel("3. Parar Gravação")
TabReplay:CreateLabel("4. Reproduzir Rota")

local LabelReplay = TabReplay:CreateLabel("⚪ Nenhuma gravação")

TabReplay:CreateButton({
    Name = "🔴 Iniciar Gravação",
    Callback = function()
        Replay.recording = true
        Replay.route = {}
        LabelReplay:Set("🔴 GRAVANDO")
        notify("🔴 Gravando", "Rota sendo gravada")
    end
})

TabReplay:CreateButton({
    Name = "⏹️ Parar Gravação",
    Callback = function()
        Replay.recording = false
        LabelReplay:Set("✅ Salva - " .. #Replay.route .. " pontos")
        notify("✅ Salvo", #Replay.route .. " pontos")
    end
})

TabReplay:CreateButton({
    Name = "▶️ Reproduzir Rota",
    Callback = function()
        if #Replay.route == 0 then
            notify("⚠️ Aviso", "Nenhuma rota gravada")
            return
        end
        
        if Replay.playing then return end
        Replay.playing = true
        notify("▶️ Reproduzindo", "Iniciando...")
        
        task.spawn(function()
            for i, point in ipairs(Replay.route) do
                if not Replay.playing then break end
                hrp.CFrame = CFrame.new(point.pos + Vector3.new(0, 5, 0))
                task.wait(Config.stealthMode and Config.stealthDelay * 2 or 1)
            end
            Replay.playing = false
            notify("✅ Completo", "Replay finalizado")
        end)
    end
})

TabReplay:CreateButton({
    Name = "⏸️ Parar Reprodução",
    Callback = function()
        Replay.playing = false
        notify("⏸️ Parado", "Replay interrompido")
    end
})

TabReplay:CreateButton({
    Name = "🗑️ Limpar Rota",
    Callback = function()
        Replay.route = {}
        LabelReplay:Set("⚪ Rota limpa")
        notify("🗑️ Limpo", "Rota apagada")
    end
})

-- ═══════════════════════════════════════
-- TAB EXPERIMENTAL
-- ═══════════════════════════════════════

local TabExp = Window:CreateTab("🧪 Experimental", 4483362458)
local SectionExp = TabExp:CreateSection("⚠️ Features em Teste")

TabExp:CreateLabel("⚠️ AVISO: Recursos experimentais!")
TabExp:CreateLabel("Podem causar bugs ou detecção")
TabExp:CreateLabel("Use por sua conta e risco")

TabExp:CreateToggle({
    Name = "🔄 #41 Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAFKToggle",
    Callback = function(Value)
        Experimental.antiAFK = Value
        toggleAntiAFK(Value)
    end
})

TabExp:CreateToggle({
    Name = "🪂 #42 Anti-Void",
    CurrentValue = false,
    Flag = "AntiVoidToggle",
    Callback = function(Value)
        Experimental.antiVoid = Value
        toggleAntiVoid(Value)
    end
})

TabExp:CreateToggle({
    Name = "📦 #36 ESP Boxes",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(Value)
        Experimental.espEnabled = Value
        toggleESP(Value)
    end
})

TabExp:CreateToggle({
    Name = "📏 #37 ESP Distance",
    CurrentValue = false,
    Flag = "ESPDistToggle",
    Callback = function(Value)
        Experimental.espDistance = Value
        if Experimental.espEnabled then
            toggleESP(false)
            toggleESP(true)
        end
    end
})

TabExp:CreateToggle({
    Name = "✨ #39 Chams/Wallhack",
    CurrentValue = false,
    Flag = "ChamsToggle",
    Callback = function(Value)
        Experimental.chamsEnabled = Value
        toggleChams(Value)
    end
})

TabExp:CreateToggle({
    Name = "🦘 #52 Infinite Jump",
    CurrentValue = false,
    Flag = "InfiniteJumpToggle",
    Callback = function(Value)
        Experimental.infiniteJump = Value
        toggleInfiniteJump(Value)
    end
})

TabExp:CreateToggle({
    Name = "⚡ #53 Dash System (Q)",
    CurrentValue = false,
    Flag = "DashToggle",
    Callback = function(Value)
        Experimental.dashEnabled = Value
        if Value then
            notify("⚡ Dash ON", "Pressione Q", 2)
        end
    end
})

TabExp:CreateSlider({
    Name = "⚡ Velocidade do Dash",
    Range = {50, 300},
    Increment = 10,
    CurrentValue = 100,
    Flag = "DashSpeedSlider",
    Callback = function(Value)
        Experimental.dashSpeed = Value
    end
})

local SectionQuick = TabExp:CreateSection("⚡ #69 Quick Actions")

TabExp:CreateButton({
    Name = "📍 Quick: Bandagem Próxima",
    Callback = function()
        teleProximo(bandagens, "bandagem")
    end
})

TabExp:CreateButton({
    Name = "📦 Quick: Baú Próximo",
    Callback = function()
        teleProximo(baus, "baú")
    end
})

TabExp:CreateButton({
    Name = "👁️ Quick: Toggle ESP",
    Callback = function()
        Experimental.espEnabled = not Experimental.espEnabled
        toggleESP(Experimental.espEnabled)
    end
})

local SectionHotkeys = TabExp:CreateSection("⌨️ #66 Hotkeys")

TabExp:CreateLabel("• E - Toggle ESP")
TabExp:CreateLabel("• Q - Dash (se ativo)")
TabExp:CreateLabel("• P - PANIC BUTTON")

TabExp:CreateButton({
    Name = "🚨 TESTAR PANIC BUTTON",
    Callback = function()
        Experimental.espEnabled = false
        Experimental.chamsEnabled = false
        Experimental.antiAFK = false
        Experimental.antiVoid = false
        Experimental.dashEnabled = false
        Experimental.infiniteJump = false
        
        toggleESP(false)
        toggleChams(false)
        toggleAntiAFK(false)
        toggleAntiVoid(false)
        toggleInfiniteJump(false)
        
        if conexao then conexao:Disconnect() end
        removerChao()
        
        notify("🚨 PANIC", "Tudo desativado!", 3)
    end
})

local SectionStats = TabExp:CreateSection("📊 #47 & #80 Stats & Performance")

local LabelStats = TabExp:CreateLabel("Carregando stats...")
local LabelPerf = TabExp:CreateLabel("Carregando performance...")

-- Atualizar stats em tempo real
task.spawn(function()
    while true do
        task.wait(2)
        
        LabelStats:Set(string.format(
            "⏱️ Sessão: %s | 🩹 %d | 📦 %d",
            Stats.sessionTime,
            #bandagens,
            #baus
        ))
        
        LabelPerf:Set(string.format(
            "🖥️ FPS: %d | 📡 Ping: %d ms | 💾 %d MB",
            Performance.fps,
            Performance.ping,
            Performance.memory
        ))
    end
end)

TabExp:CreateButton({
    Name = "🔄 Atualizar ESP para Novos Itens",
    Callback = function()
        if Experimental.espEnabled then
            toggleESP(false)
            toggleESP(true)
        end
        if Experimental.chamsEnabled then
            toggleChams(false)
            toggleChams(true)
        end
        notify("✅ Atualizado", "ESP recarregado")
    end
})

-- ═══════════════════════════════════════
-- TAB CONFIGURAÇÕES
-- ═══════════════════════════════════════

local TabConfig = Window:CreateTab("⚙️ Config", 4483362458)
local SectionConfig = TabConfig:CreateSection("Configurações Gerais")

TabConfig:CreateToggle({
    Name = "🥷 Modo Stealth",
    CurrentValue = false,
    Flag = "StealthToggle",
    Callback = function(Value)
        Config.stealthMode = Value
        if Value then
            notify("🥷 Stealth ON", "Teleportes graduais", 2)
        else
            notify("🥷 Stealth OFF", "Teleportes instantâneos", 2)
        end
    end
})

TabConfig:CreateSlider({
    Name = "⏱️ Delay do Stealth (segundos)",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "StealthDelaySlider",
    Callback = function(Value)
        Config.stealthDelay = Value
    end
})

TabConfig:CreateButton({
    Name = "🔄 Atualizar Todas as Listas",
    Callback = function()
        scan()
        
        LabelBand:Set("Bandagens encontradas: " .. #bandagens)
        LabelBau:Set("Baús encontrados: " .. #baus)
        
        local bandOptions = {}
        for i, v in pairs(bandagens) do
            if v and v.Parent then
                local dist = math.floor(getDist(v))
                table.insert(bandOptions, string.format("Bandage #%d (%d studs)", i, dist))
            end
        end
        DropdownBand:Refresh(bandOptions)
        
        local bauOptions = {}
        for i, v in pairs(baus) do
            if v and v.Parent then
                local dist = math.floor(getDist(v))
                table.insert(bauOptions, string.format("%s #%d (%d studs)", v.Name, i, dist))
            end
        end
        DropdownBau:Refresh(bauOptions)
        
        notify("✅ Atualizado", "Todas as listas recarregadas!")
    end
})

TabConfig:CreateButton({
    Name = "❌ Fechar Script",
    Callback = function()
        if conexao then conexao:Disconnect() end
        if antiAFKConnection then antiAFKConnection:Disconnect() end
        if antiVoidConnection then antiVoidConnection:Disconnect() end
        if jumpConnection then jumpConnection:Disconnect() end
        
        removerChao()
        clearESP()
        clearChams()
        
        notify("👋 Até logo", "Script fechado", 3)
        task.wait(1)
        Rayfield:Destroy()
    end
})

local SectionInfo = TabConfig:CreateSection("📝 Informações")

TabConfig:CreateLabel("Script de Teleporte v4.0")
TabConfig:CreateLabel("Feito por Claude")
TabConfig:CreateLabel("Mobile & PC Friendly")
TabConfig:CreateLabel("")
TabConfig:CreateLabel("✨ Features Principais:")
TabConfig:CreateLabel("• Teleporte de Bandagens e Baús")
TabConfig:CreateLabel("• Chão Invisível (50 studs acima)")
TabConfig:CreateLabel("• Modo Stealth")
TabConfig:CreateLabel("• Sistema de Replay")
TabConfig:CreateLabel("• Customização Visual")
TabConfig:CreateLabel("")
TabConfig:CreateLabel("🧪 Features Experimentais:")
TabConfig:CreateLabel("#41 Anti-AFK | #42 Anti-Void")
TabConfig:CreateLabel("#36 ESP Boxes | #37 ESP Distance")
TabConfig:CreateLabel("#39 Chams/Wallhack")
TabConfig:CreateLabel("#47 Session Stats")
TabConfig:CreateLabel("#52 Infinite Jump | #53 Dash")
TabConfig:CreateLabel("#66 Hotkeys | #69 Quick Actions")
TabConfig:CreateLabel("#80 Performance Monitor")

-- ═══════════════════════════════════════
-- INICIALIZAÇÃO
-- ═══════════════════════════════════════

scan()

-- Atualizar dropdowns iniciais
local bandOptions = {}
for i, v in pairs(bandagens) do
    if v and v.Parent then
        local dist = math.floor(getDist(v))
        table.insert(bandOptions, string.format("Bandage #%d (%d studs)", i, dist))
    end
end
if #bandOptions > 0 then
    DropdownBand:Refresh(bandOptions)
end

local bauOptions = {}
for i, v in pairs(baus) do
    if v and v.Parent then
        local dist = math.floor(getDist(v))
        table.insert(bauOptions, string.format("%s #%d (%d studs)", v.Name, i, dist))
    end
end
if #bauOptions > 0 then
    DropdownBau:Refresh(bauOptions)
end

LabelBand:Set("Bandagens encontradas: " .. #bandagens)
LabelBau:Set("Baús encontrados: " .. #baus)

notify("✅ Script Carregado", "v4.0 pronto para usar!", 5)

print("═══════════════════════════════════════")
print("Script v4.0 Carregado com Rayfield!")
print("Bandagens: " .. #bandagens)
print("Baús: " .. #baus)
print("")
print("🧪 Features Experimentais Disponíveis:")
print("#41 Anti-AFK | #42 Anti-Void")
print("#36 ESP Boxes | #37 ESP Distance")
print("#39 Chams/Wallhack")
print("#47 Session Stats | #52 Infinite Jump")
print("#53 Dash System | #66 Hotkeys")
print("#69 Quick Actions | #80 Performance")
print("")
print("⌨️ Hotkeys:")
print("E - Toggle ESP")
print("Q - Dash (se ativo)")
print("P - PANIC BUTTON (desativa tudo)")
print("")
print("⚠️ Use recursos experimentais com cuidado!")
print("═══════════════════════════════════════")
