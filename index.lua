--[[
    Versão otimizada para mobile
]]
task.wait(10)

print("Carregando Rayfield UI...")

-- Carregar Rayfield (URL confiável e funcional)
local Rayfield
local success, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success or not Rayfield then
    error("❌ Falha ao carregar Rayfield. Verifique sua conexão ou executor.")
end

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
local selectedBandage = nil
local selectedChest = nil

-- Configurações
local Config = {
    stealthMode = false,
    stealthDelay = 0.5,
    chaoTransparency = 1,
    chaoSize = 200,
    theme = "Dark",
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

-- Sistema de Notificação
local function notify(title, msg)
    Rayfield:Notify({
        Title = title,
        Content = msg,
        Duration = 3,
        Image = 4483362458 -- Ícone padrão
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
                for _, nome in pairs({"Item Chest", "Item Chest2", "Item Chest3", "Item Chest4", "Item Chest5", "Item Chest6", "Chest", "ItemChest"}) do
                    if v.Name == nome then
                        table.insert(baus, v)
                        break
                    end
                end
            end
        end
    end

    print("Bandagens: " .. #bandagens .. " | Baús: " .. #baus)
    notify("✅ Itens Encontrados", string.format("Bandagens: %d | Baús: %d", #bandagens, #baus))
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
        notify("✅ Anti-AFK", "Ativado!")
    else
        notify("🔴 Anti-AFK", "Desativado")
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
                    notify("⚠️ Anti-Void", "Salvo da queda!")
                end
            end
        end)
        notify("✅ Anti-Void", "Ativado!")
    else
        notify("🔴 Anti-Void", "Desativado")
    end
end

-- ESP System
local ESPObjects = {}
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

local function toggleESP(enabled)
    clearESP()

    if enabled then
        for _, item in pairs(bandagens) do
            if item and item.Parent then
                createESP(item, Color3.fromRGB(0, 255, 0))
            end
        end

        for _, item in pairs(baus) do
            if item and item.Parent then
                createESP(item, Color3.fromRGB(255, 200, 0))
            end
        end

        notify("✅ ESP", "Ativado!")
    else
        notify("🔴 ESP", "Desativado")
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

        notify("✅ Chams", "Ativado!")
    else
        notify("🔴 Chams", "Desativado")
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
        jumpConnection = UserInputService.JumpRequest:Connect(function()
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        notify("✅ Infinite Jump", "Ativado!")
    else
        notify("🔴 Infinite Jump", "Desativado")
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

            notify("⚡ Dash", "Executado!")
        end
    end
end

-- Hotkey System
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.RightControl then
        local gui = player.PlayerGui:FindFirstChild("Rayfield")
        if gui then
            gui.Enabled = not gui.Enabled
        end
    elseif input.KeyCode == Enum.KeyCode.E then
        Config.espEnabled = not Config.espEnabled
        toggleESP(Config.espEnabled)
    elseif input.KeyCode == Enum.KeyCode.Q and Config.dashEnabled then
        performDash()
    elseif input.KeyCode == Enum.KeyCode.P then
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

-- Criar Interface com Rayfield
local Window = Rayfield:CreateWindow({
    Name = "🎯 Teleport Script v3.0",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "by Deathbringer",
    ConfigurationSaving = { Enabled = true },
    Discord = { Enabled = false }
})

-- Abas
local Tabs = {
    Bandagens = Window:CreateTab("Bandagens", 4483362458),
    Baus = Window:CreateTab("Baús", 4483362458),
    Chao = Window:CreateTab("Chão", 4483362458),
    Protecao = Window:CreateTab("Proteção", 4483362458),
    Visual = Window:CreateTab("Visual", 4483362458),
    Movimento = Window:CreateTab("Movimento", 4483362458),
    Config = Window:CreateTab("Config", 4483362458)
}

-- ABA BANDAGENS
Tabs.Bandagens:CreateButton({
    Name = "Teleportar para Mais Próxima",
    Callback = function()
        scan()
        teleProximo(bandagens, "bandagem")
    end
})

-- ABA BAÚS
Tabs.Baus:CreateButton({
    Name = "Teleportar para Mais Próximo",
    Callback = function()
        scan()
        teleProximo(baus, "baú")
    end
})

-- ABA CHÃO
Tabs.Chao:CreateToggle({
    Name = "Ativar Chão Invisível",
    CurrentValue = false,
    Callback = function(value)
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
        else
            removerChao()
            if conexao then conexao:Disconnect() end
        end
    end
})

-- ABA PROTEÇÃO
Tabs.Protecao:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Callback = function(value)
        Config.antiAFK = value
        toggleAntiAFK(value)
    end
})

Tabs.Protecao:CreateToggle({
    Name = "Anti-Void",
    CurrentValue = false,
    Callback = function(value)
        Config.antiVoid = value
        toggleAntiVoid(value)
    end
})

-- ABA VISUAL
Tabs.Visual:CreateToggle({
    Name = "ESP",
    CurrentValue = false,
    Callback = function(value)
        Config.espEnabled = value
        toggleESP(value)
    end
})

Tabs.Visual:CreateToggle({
    Name = "Chams",
    CurrentValue = false,
    Callback = function(value)
        Config.chamsEnabled = value
        toggleChams(value)
    end
})

-- ABA MOVIMENTO
Tabs.Movimento:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(value)
        Config.infiniteJump = value
        toggleInfiniteJump(value)
    end
})

Tabs.Movimento:CreateToggle({
    Name = "Dash (Q)",
    CurrentValue = false,
    Callback = function(value)
        Config.dashEnabled = value
        notify(value and "✅ Dash" or "🔴 Dash", value and "Ativado!" or "Desativado")
    end
})

-- ABA CONFIG
Tabs.Config:CreateButton({
    Name = "Atualizar Itens",
    Callback = function()
        scan()
    end
})

-- Iniciar scan automático
scan()
notify("✅ Script Carregado", "Pronto para usar!")
