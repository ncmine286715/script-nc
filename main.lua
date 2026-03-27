--[[
    NCHub – Raid Farm + Auto Mob Farm
    Feito por NCMine
    Funciona com qualquer executor (Delta mobile)
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== CONFIGURAÇÕES ==========
local Settings = {
    -- Raid
    RaidFarm = false,
    BuddhaMode = false,
    
    -- Mob Farm
    MobFarm = false,
    SelectedIsland = "Marinha",  -- nome padrão
    MobRange = 100,
    MobDelay = 0.1,
    TeleportOnStart = true,
}

-- ========== SERVIÇOS ==========
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- ========== COORDENADAS DAS ILHAS ==========
local Islands = {
    -- Primeiro Mar
    {"Marinha", Vector3.new(-790, 80, -1260)},
    {"Deserto", Vector3.new(1020, 125, 1240)},
    {"Jungla", Vector3.new(-1200, 50, 500)},
    {"Ilha do Céu", Vector3.new(-5000, 300, -2000)},
    {"Ilha do Tesouro", Vector3.new(2000, 50, 3000)},
    
    -- Segundo Mar
    {"Ilha do Cemitério", Vector3.new(-3000, 50, 4000)},
    {"Ilha da Neve", Vector3.new(-4000, 100, -1000)},
    {"Ilha do Café", Vector3.new(-2000, 50, -3000)},
    {"Ilha da Fábrica", Vector3.new(0, 50, -4000)},
    {"Ilha do Trono", Vector3.new(3000, 150, 2000)},
    
    -- Terceiro Mar
    {"Castelo", Vector3.new(5000, 200, 5000)},
    {"Ilha das Almas", Vector3.new(6000, 100, 6000)},
    {"Ilha do Dragão", Vector3.new(7000, 150, 7000)},
    {"Ilha dos Espelhos", Vector3.new(8000, 200, 8000)},
    {"Zona Neutra", Vector3.new(4000, 100, 4000)},
    
    -- Ilhas de nível
    {"Mobs Nv 1", Vector3.new(-100, 50, 0)},
    {"Mobs Nv 100", Vector3.new(500, 50, 500)},
    {"Mobs Nv 500", Vector3.new(1000, 50, 1000)},
    {"Mobs Nv 1000", Vector3.new(2000, 50, 2000)},
    {"Mobs Nv 2000", Vector3.new(3000, 100, 3000)},
}

-- ========== FUNÇÕES GERAIS ==========

-- Teleportar para coordenadas
local function TeleportTo(pos)
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(pos)
        return true
    end
    return false
end

-- Encontrar mobs próximos (opcional: ignorar boss)
local function GetNearbyMobs(range, ignoreBoss)
    local character = LocalPlayer.Character
    if not character then return {} end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return {} end

    local mobs = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            -- Ignorar o próprio jogador
            if v == character then continue end
            -- Se ignoreBoss for true, pular mobs que parecem boss
            if ignoreBoss and (v.Name:lower():find("boss") or v:FindFirstChild("Boss")) then
                continue
            end
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist <= range then
                    table.insert(mobs, v)
                end
            end
        end
    end
    return mobs
end

-- Atacar alvo (usa a ferramenta equipada)
local function AttackTarget(target)
    if not target then return end
    local character = LocalPlayer.Character
    if not character then return end

    -- Aproximar-se
    local root = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if root and targetRoot then
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
    end

    -- Encontrar ferramenta ativa
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end
end

-- ========== RAID FARM (já existente) ==========

-- Verificar se está dentro de uma raid
local function IsInRaid()
    return workspace:FindFirstChild("Raid") ~= nil
end

-- Encontrar boss da raid (para modo Buda)
local function GetRaidBoss()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") then
            if v.Name:lower():find("buddha") or v.Name:lower():find("boss") then
                return v
            end
        end
    end
    return nil
end

-- Modo Buda (ficar na cabeça do boss)
local function BuddhaModeLoop()
    while Settings.RaidFarm and Settings.BuddhaMode do
        local boss = GetRaidBoss()
        if boss then
            local character = LocalPlayer.Character
            if character then
                local root = character:FindFirstChild("HumanoidRootPart")
                local bossHead = boss:FindFirstChild("Head") or boss:FindFirstChild("HumanoidRootPart")
                if root and bossHead then
                    root.CFrame = bossHead.CFrame * CFrame.new(0, 3, 0)
                end
            end
        end
        local mobs = GetNearbyMobs(50, true)  -- ignora boss
        for _, mob in ipairs(mobs) do
            AttackTarget(mob)
            task.wait(0.1)
        end
        task.wait(0.1)
    end
end

-- Modo normal na raid
local function NormalRaidFarmLoop()
    while Settings.RaidFarm and not Settings.BuddhaMode do
        local mobs = GetNearbyMobs(50, false)
        for _, mob in ipairs(mobs) do
            AttackTarget(mob)
            task.wait(0.1)
        end
        task.wait(0.1)
    end
end

local function RaidFarmLoop()
    while Settings.RaidFarm do
        if not IsInRaid() then
            task.wait(1)
            continue
        end
        if Settings.BuddhaMode then
            BuddhaModeLoop()
        else
            NormalRaidFarmLoop()
        end
        task.wait()
    end
end

-- ========== AUTO MOB FARM (novo) ==========

-- Função principal do Auto Mob Farm
local function MobFarmLoop()
    -- Se TeleportOnStart estiver ativo, teleporta para a ilha selecionada
    if Settings.TeleportOnStart then
        local coord = nil
        for _, island in ipairs(Islands) do
            if island[1] == Settings.SelectedIsland then
                coord = island[2]
                break
            end
        end
        if coord then
            TeleportTo(coord)
            Rayfield:Notify({
                Title = "Auto Mob Farm",
                Content = "Teleportado para " .. Settings.SelectedIsland,
                Duration = 2
            })
            task.wait(2) -- aguarda estabilizar
        end
    end

    -- Loop principal
    while Settings.MobFarm do
        local mobs = GetNearbyMobs(Settings.MobRange, false)
        if #mobs > 0 then
            for _, mob in ipairs(mobs) do
                AttackTarget(mob)
                task.wait(Settings.MobDelay)
            end
        else
            -- Nenhum mob próximo, aguarda um pouco
            task.wait(0.5)
        end
    end
end

-- ========== INTERFACE ==========

local Window = Rayfield:CreateWindow({
    Name = "NCHub - Raid & Mob Farm",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "by NCMine",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Aba Raid Farm
local RaidTab = Window:CreateTab("⚔️ Raid Farm", 4483362458)

RaidTab:CreateToggle({
    Name = "🎯 Farm na Raid (ativo apenas dentro)",
    CurrentValue = false,
    Callback = function(value)
        Settings.RaidFarm = value
        if value then
            task.spawn(RaidFarmLoop)
            Rayfield:Notify({Title = "Raid Farm", Content = "Ativado! Entre na raid.", Duration = 3})
        else
            Rayfield:Notify({Title = "Raid Farm", Content = "Desativado.", Duration = 2})
        end
    end
})

RaidTab:CreateToggle({
    Name = "🪷 Modo Buda (ficar na cabeça do boss)",
    CurrentValue = false,
    Callback = function(value)
        Settings.BuddhaMode = value
        if value then
            Rayfield:Notify({Title = "Modo Buda", Content = "Ativado. Você será teleportado para a cabeça do boss.", Duration = 3})
        else
            Rayfield:Notify({Title = "Modo Buda", Content = "Desativado. Farm normal.", Duration = 2})
        end
    end
})

RaidTab:CreateButton({
    Name = "ℹ️ Instruções",
    Callback = function()
        Rayfield:Notify({
            Title = "Instruções",
            Content = "1. Entre na raid manualmente.\n2. Ative 'Farm na Raid'.\n3. Se for Buda, ative o modo especial.\n4. O script atacará automaticamente os mobs.",
            Duration = 8
        })
    end
})

-- Aba Mob Farm
local MobTab = Window:CreateTab("🏝️ Mob Farm", 4483362458)

MobTab:CreateToggle({
    Name = "🤖 Auto Mob Farm",
    CurrentValue = false,
    Callback = function(value)
        Settings.MobFarm = value
        if value then
            task.spawn(MobFarmLoop)
            Rayfield:Notify({Title = "Mob Farm", Content = "Ativado. Farmando em " .. Settings.SelectedIsland, Duration = 3})
        else
            Rayfield:Notify({Title = "Mob Farm", Content = "Desativado.", Duration = 2})
        end
    end
})

-- Dropdown para selecionar ilha
local islandNames = {}
for _, island in ipairs(Islands) do
    table.insert(islandNames, island[1])
end

MobTab:CreateDropdown({
    Name = "🏝️ Selecionar Ilha",
    Options = islandNames,
    CurrentOption = Settings.SelectedIsland,
    Callback = function(option)
        Settings.SelectedIsland = option
        Rayfield:Notify({Title = "Ilha", Content = "Ilha selecionada: " .. option, Duration = 2})
    end
})

MobTab:CreateToggle({
    Name = "🚀 Teleportar ao iniciar",
    CurrentValue = true,
    Callback = function(value)
        Settings.TeleportOnStart = value
    end
})

MobTab:CreateButton({
    Name = "📍 Teleportar agora",
    Callback = function()
        for _, island in ipairs(Islands) do
            if island[1] == Settings.SelectedIsland then
                TeleportTo(island[2])
                Rayfield:Notify({Title = "Teleport", Content = "Teleportado para " .. island[1], Duration = 2})
                break
            end
        end
    end
})

MobTab:CreateSlider({
    Name = "📏 Alcance de ataque",
    Range = {30, 200},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = Settings.MobRange,
    Callback = function(value)
        Settings.MobRange = value
    end
})

MobTab:CreateSlider({
    Name = "⏱️ Delay entre ataques",
    Range = {0.05, 0.5},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Settings.MobDelay,
    Callback = function(value)
        Settings.MobDelay = value
    end
})

-- Notificação inicial
Rayfield:Notify({
    Title = "NCHub",
    Content = "Pronto! Use as abas Raid Farm ou Mob Farm.",
    Duration = 5
})
