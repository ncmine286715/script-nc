--[[
    NCHub Lite – Feito por NCMine
    Funcionalidades: Kill Aura, Auto Fruit, Auto Raid
    Versão otimizada para mobile (Delta)
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== CONFIGURAÇÕES ==========
local Settings = {
    KillAura = false,
    KillAuraRange = 150,
    KillAuraDelay = 0.1,
    AutoFruit = false,
    AutoRaid = false,
    RaidType = "Flame",
}

-- ========== SERVIÇOS ==========
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== FUNÇÕES AUXILIARES ==========

-- Encontra o mob mais próximo dentro do alcance
local function GetNearestMob()
    local character = LocalPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local nearest = nil
    local minDist = math.huge

    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - rootPart.Position).Magnitude
                if dist < minDist and dist <= Settings.KillAuraRange then
                    nearest = v
                    minDist = dist
                end
            end
        end
    end
    return nearest
end

-- Ataca o alvo usando a arma equipada
local function AttackTarget(target)
    if not target then return end

    local character = LocalPlayer.Character
    if not character then return end

    -- Aproxima-se do alvo
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if rootPart and targetRoot then
        rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
    end

    -- Procura a ferramenta (arma) equipada
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        -- Ativa a ferramenta (simula o clique)
        tool:Activate()
    end
end

-- Encontra a fruta mais próxima
local function GetNearestFruit()
    local character = LocalPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local nearest = nil
    local minDist = math.huge

    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Handle") then
            if v.Name:find("Fruit") then
                local fruitPart = v:FindFirstChild("Handle") or v:FindFirstChild("PrimaryPart")
                if fruitPart then
                    local dist = (fruitPart.Position - rootPart.Position).Magnitude
                    if dist < minDist and dist <= 100 then -- alcance fixo para frutas
                        nearest = v
                        minDist = dist
                    end
                end
            end
        end
    end
    return nearest
end

-- Coleta a fruta (teleporta e espera)
local function CollectFruit(fruit)
    if not fruit then return end
    local character = LocalPlayer.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local fruitPart = fruit:FindFirstChild("Handle") or fruit:FindFirstChild("PrimaryPart")
    if rootPart and fruitPart then
        -- Teleporta em cima da fruta
        rootPart.CFrame = fruitPart.CFrame * CFrame.new(0, 2, 0)
        -- Aguarda um pouco para o jogo registrar a coleta
        task.wait(0.5)
        -- Opcional: simular um movimento para garantir
        rootPart.CFrame = fruitPart.CFrame
    end
end

-- ========== LOOPS ==========

-- Kill Aura loop
local function KillAuraLoop()
    while Settings.KillAura do
        local target = GetNearestMob()
        if target then
            AttackTarget(target)
        end
        task.wait(Settings.KillAuraDelay)
    end
end

-- Auto Fruit loop
local function AutoFruitLoop()
    while Settings.AutoFruit do
        local fruit = GetNearestFruit()
        if fruit then
            CollectFruit(fruit)
        end
        task.wait(0.5)
    end
end

-- Auto Raid loop
local function AutoRaidLoop()
    while Settings.AutoRaid do
        -- Inicia a raid
        local success, err = pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("Raids", "Start", Settings.RaidType)
        end)
        if not success then
            warn("Erro ao iniciar raid: " .. tostring(err))
        end
        -- Aguarda antes de tentar novamente
        task.wait(30) -- espera 30 segundos antes de tentar outra raid
    end
end

-- ========== CONSTRUÇÃO DA UI ==========

local Window = Rayfield:CreateWindow({
    Name = "NCHub Lite",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "by NCMine",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Aba principal
local MainTab = Window:CreateTab("⚔️ Combat", 4483362458)

-- Kill Aura
MainTab:CreateToggle({
    Name = "🔪 Kill Aura",
    CurrentValue = false,
    Callback = function(value)
        Settings.KillAura = value
        if value then
            task.spawn(KillAuraLoop)
        end
    end
})

MainTab:CreateSlider({
    Name = "📏 Alcance",
    Range = {50, 250},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = 150,
    Callback = function(value)
        Settings.KillAuraRange = value
    end
})

MainTab:CreateSlider({
    Name = "⏱️ Delay (segundos)",
    Range = {0.05, 0.5},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.1,
    Callback = function(value)
        Settings.KillAuraDelay = value
    end
})

MainTab:CreateDivider()

-- Auto Fruit
MainTab:CreateToggle({
    Name = "🍎 Auto Fruit",
    CurrentValue = false,
    Callback = function(value)
        Settings.AutoFruit = value
        if value then
            task.spawn(AutoFruitLoop)
        end
    end
})

MainTab:CreateDivider()

-- Auto Raid
MainTab:CreateToggle({
    Name = "⚡ Auto Raid",
    CurrentValue = false,
    Callback = function(value)
        Settings.AutoRaid = value
        if value then
            task.spawn(AutoRaidLoop)
        end
    end
})

MainTab:CreateDropdown({
    Name = "🔥 Tipo de Raid",
    Options = {"Flame", "Ice", "Sand", "Dark", "Light", "Magma", "Water"},
    CurrentOption = "Flame",
    Callback = function(option)
        Settings.RaidType = option
    end
})

-- Notificação inicial
Rayfield:Notify({
    Title = "NCHub Lite",
    Content = "Carregado! Kill Aura e Auto Fruit funcionais.",
    Duration = 5
})

print("NCHub Lite carregado | Kill Aura, Auto Fruit, Auto Raid prontos.")
