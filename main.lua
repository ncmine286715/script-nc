--[[
    NCHub – Feito por NCMine
    Versão: 3.0 – Ultra Otimizado
    Blox Fruits – UI Clean & Kill Aura Segura
]]

-- ========== BIBLIOTECA E CONFIGURAÇÕES INICIAIS ==========
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Variáveis globais do hub
local NCHub = {
    Versao = "3.0",
    Criador = "NCMine",
    -- Configurações principais
    Settings = {
        -- Combat
        KillAura = false,
        KillAuraRange = 180,
        KillAuraDelay = 0.1,
        KillAuraTargets = "All", -- All, Players, Mobs
        KillAuraSafeMode = true,
        KillAuraAntiBan = true,
        
        -- Auto Farm
        AutoFarm = false,
        FarmRadius = 150,
        FarmMobType = "All",
        SelectedWeapon = "Melee",
        
        -- Auto Farm (Avançado)
        AutoCollectFruit = false,
        AutoCollectChest = false,
        AutoCollectMaterial = false,
        AutoCollectRadius = 200,
        
        -- Auto Raid
        AutoRaid = false,
        AutoRaidAll = false,
        RaidType = "Flame",
        RaidDelay = 5,
        
        -- Auto Boss
        AutoBoss = false,
        SelectedBoss = "Dragon",
        BossList = {"Dragon", "Magma", "Ice", "Darkbeard", "Dough King", "Cake Prince", "Rip Indra", "Stone"},
        
        -- Auto Stats
        AutoStats = false,
        StatsType = "Melee",
        
        -- Auto Level
        AutoLevel = false,
        AutoQuest = false,
        
        -- Auto Sea Beast
        AutoSeaBeast = false,
        
        -- Auto Elite Hunter
        AutoElite = false,
        
        -- Teleports
        TeleportHistory = {},
        
        -- Visuals
        ESP = false,
        ESPColor = Color3.fromRGB(255, 0, 0),
        ESPType = "Box",
        Chams = false,
        
        -- Misc
        SpeedHack = false,
        SpeedValue = 50,
        Fly = false,
        NoClip = false,
        InfiniteEnergy = false,
        InfiniteMoney = false,
        
        -- Funções de Brincadeira
        FakeChat = false,
        FakeMessage = "",
        SpamEffects = false,
        EffectType = "Explosion",
        AnimationSpam = false,
        AnimationID = "",
        ForceField = false,
        ChatSpam = false,
        ChatSpamMessage = "",
        ChatSpamDelay = 1,
        
        -- Anti Ban / Segurança
        AntiKick = false,
        AntiBanMode = true,
        NoReport = true,
    },
    
    -- Status dos loops
    Loops = {
        KillAura = nil,
        AutoFarm = nil,
        AutoBoss = nil,
        AutoRaid = nil,
        AutoCollect = nil,
        AutoStats = nil,
        AutoLevel = nil,
        ESP = nil,
        SpeedHack = nil,
        Fly = nil,
        SpamEffects = nil,
        ChatSpam = nil,
    },
    
    -- Variáveis de segurança
    Security = {
        LastAttack = 0,
        AttackCount = 0,
        SessionStart = os.time(),
        Whitelisted = {},
    }
}

-- ========== SERVIÇOS ==========
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

-- ========== FUNÇÕES DE SEGURANÇA ==========

-- Sistema Anti-Ban (evita comportamentos suspeitos)
local function AntiBanProtection()
    if not NCHub.Settings.KillAuraAntiBan then return end
    
    -- Limita ataques por segundo
    local currentTime = tick()
    if currentTime - NCHub.Security.LastAttack < 0.15 then
        return false
    end
    
    -- Verifica se está atacando rápido demais (mais de 8 ataques por segundo)
    NCHub.Security.AttackCount = NCHub.Security.AttackCount + 1
    if NCHub.Security.AttackCount > 8 then
        task.wait(0.5)
        NCHub.Security.AttackCount = 0
        return false
    end
    
    -- Reset a cada segundo
    task.delay(1, function()
        NCHub.Security.AttackCount = 0
    end)
    
    NCHub.Security.LastAttack = currentTime
    return true
end

-- Simula movimentação humana para evitar detecção
local function HumanLikeMovement()
    if not NCHub.Settings.KillAuraSafeMode then return end
    
    -- Pequeno delay aleatório entre ataques
    local randomDelay = math.random(80, 150) / 1000
    task.wait(randomDelay)
end

-- ========== SISTEMA KILL AURA (SEGURO) ==========

-- Encontra alvos para o Kill Aura
local function GetKillAuraTargets()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return {} end
    
    local rootPart = character.HumanoidRootPart
    local targets = {}
    local range = NCHub.Settings.KillAuraRange
    
    -- Alvos: Mobs
    if NCHub.Settings.KillAuraTargets == "All" or NCHub.Settings.KillAuraTargets == "Mobs" then
        for _, v in ipairs(workspace.Enemies:GetChildren()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                local hrp = v:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - rootPart.Position).Magnitude <= range then
                    table.insert(targets, v)
                end
            end
        end
    end
    
    -- Alvos: Players (PVP)
    if NCHub.Settings.KillAuraTargets == "All" or NCHub.Settings.KillAuraTargets == "Players" then
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                local hrp = v.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - rootPart.Position).Magnitude <= range then
                    -- Verifica se é amigo (whitelist)
                    local isWhitelisted = false
                    for _, friend in ipairs(NCHub.Security.Whitelisted) do
                        if friend == v.Name then isWhitelisted = true break end
                    end
                    if not isWhitelisted then
                        table.insert(targets, v.Character)
                    end
                end
            end
        end
    end
    
    return targets
end

-- Função para atacar o alvo (simula clique humano)
local function AttackTarget(target)
    if not target or not AntiBanProtection() then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    -- Move suavemente para o alvo
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and target:FindFirstChild("HumanoidRootPart") then
        local targetPos = target.HumanoidRootPart.Position
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos).unit
        local newPos = targetPos - direction * 4 -- Fica a 4 studs de distância
        
        -- Movimento suave
        hrp.CFrame = CFrame.new(newPos, targetPos)
    end
    
    -- Equipa a melhor arma
    local tool = nil
    local characterChildren = character:GetChildren()
    
    if NCHub.Settings.SelectedWeapon == "Melee" then
        for _, child in ipairs(characterChildren) do
            if child:IsA("Tool") and not child.Name:find("Sword") and not child.Name:find("Fruit") then
                tool = child
                break
            end
        end
    elseif NCHub.Settings.SelectedWeapon == "Sword" then
        for _, child in ipairs(characterChildren) do
            if child:IsA("Tool") and (child.Name:find("Sword") or child:FindFirstChild("Sword")) then
                tool = child
                break
            end
        end
    elseif NCHub.Settings.SelectedWeapon == "Fruit" then
        for _, child in ipairs(characterChildren) do
            if child:IsA("Tool") and (child.Name:find("Fruit") or child:FindFirstChild("Fruit")) then
                tool = child
                break
            end
        end
    end
    
    if tool then
        -- Simula clique no botão de ataque
        VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.05)
        VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
    
    -- Movimento humano
    HumanLikeMovement()
end

-- Loop principal do Kill Aura (otimizado)
local function KillAuraLoop()
    while NCHub.Settings.KillAura do
        local targets = GetKillAuraTargets()
        
        -- Ordena por distância (mais próximo primeiro)
        table.sort(targets, function(a, b)
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
            local root = char.HumanoidRootPart
            local distA = a:FindFirstChild("HumanoidRootPart") and (a.HumanoidRootPart.Position - root.Position).Magnitude or math.huge
            local distB = b:FindFirstChild("HumanoidRootPart") and (b.HumanoidRootPart.Position - root.Position).Magnitude or math.huge
            return distA < distB
        end)
        
        -- Ataca o alvo mais próximo
        if #targets > 0 then
            AttackTarget(targets[1])
        end
        
        task.wait(NCHub.Settings.KillAuraDelay)
    end
end

-- ========== FUNÇÕES AVANÇADAS DE AUTO FARM ==========

-- Encontra mobs próximos
local function GetNearestMob()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPart = character.HumanoidRootPart
    local nearest = nil
    local minDist = math.huge
    
    for _, v in ipairs(workspace.Enemies:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - rootPart.Position).Magnitude
                if dist < minDist and dist <= NCHub.Settings.FarmRadius then
                    local isBoss = v.Name:find("Boss") or v:FindFirstChild("Boss") ~= nil
                    if NCHub.Settings.FarmMobType == "All" then
                        nearest = v
                        minDist = dist
                    elseif NCHub.Settings.FarmMobType == "Boss" and isBoss then
                        nearest = v
                        minDist = dist
                    elseif NCHub.Settings.FarmMobType == "Normal" and not isBoss then
                        nearest = v
                        minDist = dist
                    end
                end
            end
        end
    end
    return nearest
end

-- Auto Farm Loop
local function AutoFarmLoop()
    while NCHub.Settings.AutoFarm do
        local target = GetNearestMob()
        if target then
            AttackTarget(target)
        end
        task.wait(0.1)
    end
end

-- Auto Coletor (frutas, baús, materiais)
local function AutoCollectLoop()
    while NCHub.Settings.AutoCollectFruit or NCHub.Settings.AutoCollectChest or NCHub.Settings.AutoCollectMaterial do
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local root = character.HumanoidRootPart
            
            for _, v in ipairs(workspace:GetDescendants()) do
                local distance = root and (v.Position - root.Position).Magnitude or math.huge
                
                if distance <= NCHub.Settings.AutoCollectRadius then
                    -- Coleta frutas
                    if NCHub.Settings.AutoCollectFruit and v:IsA("Model") and v:FindFirstChild("Handle") and v.Name:find("Fruit") then
                        root.CFrame = v.Handle.CFrame * CFrame.new(0, 0, 2)
                        task.wait(0.1)
                    end
                    
                    -- Coleta baús
                    if NCHub.Settings.AutoCollectChest and v:IsA("Model") and (v.Name:find("Chest") or v.Name:find("Barrel")) then
                        root.CFrame = v.PrimaryPart.CFrame * CFrame.new(0, 0, 2)
                        task.wait(0.1)
                    end
                    
                    -- Coleta materiais
                    if NCHub.Settings.AutoCollectMaterial and v:IsA("Part") and v.Name:find("Material") then
                        root.CFrame = v.CFrame * CFrame.new(0, 0, 2)
                        task.wait(0.1)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end

-- Auto Stats Loop
local function AutoStatsLoop()
    while NCHub.Settings.AutoStats do
        local args = { [1] = "AddPoint", [2] = NCHub.Settings.StatsType, [3] = 1 }
        local success, err = pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args))
        end)
        task.wait(0.05)
    end
end

-- Auto Level + Auto Quest
local function AutoLevelLoop()
    while NCHub.Settings.AutoLevel do
        -- Pega quest automaticamente
        if NCHub.Settings.AutoQuest then
            local args = { [1] = "StartQuest", [2] = "Bandit" } -- Ajustar conforme nível
            pcall(function()
                ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args))
            end)
        end
        
        -- Farm mobs
        local target = GetNearestMob()
        if target then
            AttackTarget(target)
        end
        
        task.wait(0.1)
    end
end

-- Auto Sea Beast
local function AutoSeaBeastLoop()
    while NCHub.Settings.AutoSeaBeast do
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA("Model") and v.Name:find("SeaBeast") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                AttackTarget(v)
                break
            end
        end
        task.wait(0.5)
    end
end

-- Auto Raid Loop
local function AutoRaidLoop()
    while NCHub.Settings.AutoRaid do
        -- Inicia raid
        local args = { [1] = "Raids", [2] = "Start", [3] = NCHub.Settings.RaidType }
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args))
        end)
        
        task.wait(NCHub.Settings.RaidDelay)
        
        -- Farm durante a raid
        local raidActive = true
        while raidActive and NCHub.Settings.AutoRaid do
            local target = GetNearestMob()
            if target then
                AttackTarget(target)
            end
            task.wait(0.1)
        end
    end
end

-- Auto Boss Loop
local function AutoBossLoop()
    while NCHub.Settings.AutoBoss do
        local boss = nil
        for _, v in ipairs(workspace.Enemies:GetChildren()) do
            if v:IsA("Model") and v.Name:lower():find(NCHub.Settings.SelectedBoss:lower()) then
                if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                    boss = v
                    break
                end
            end
        end
        
        if boss then
            AttackTarget(boss)
        else
            task.wait(5) -- Espera o boss spawnar
        end
        task.wait(0.5)
    end
end

-- ========== FUNÇÕES DE TELEPORTE ==========

local TeleportLocations = {
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
    
    -- Bosses
    {"Boss Dragão", Vector3.new(1000, 50, 1000)},
    {"Boss Magma", Vector3.new(-2000, 50, -2000)},
    {"Boss Gelo", Vector3.new(-3000, 50, -3000)},
    {"Dough King", Vector3.new(2000, 100, 2000)},
    {"Rip Indra", Vector3.new(3000, 150, 3000)},
    
    -- Ilhas Especiais
    {"Ilha dos Mobs Nível 1", Vector3.new(-100, 50, 0)},
    {"Ilha dos Mobs Nível 100", Vector3.new(500, 50, 500)},
    {"Ilha dos Mobs Nível 500", Vector3.new(1000, 50, 1000)},
    {"Ilha dos Mobs Nível 1000", Vector3.new(2000, 50, 2000)},
    {"Ilha dos Mobs Nível 2000", Vector3.new(3000, 100, 3000)},
}

-- Função de teleporte
local function TeleportTo(pos)
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(pos)
        table.insert(NCHub.Settings.TeleportHistory, {os.time(), pos})
        return true
    end
    return false
end

-- ========== FUNÇÕES VISUAIS ==========

-- ESP System
local ESPObjects = {}
local function CreateESP(character)
    if not NCHub.Settings.ESP then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Parent = character
    highlight.FillColor = NCHub.Settings.ESPColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.3
    highlight.Adornee = character
    
    ESPObjects[character] = highlight
end

local function RemoveESP(character)
    if ESPObjects[character] then
        ESPObjects[character]:Destroy()
        ESPObjects[character] = nil
    end
end

local function ESPLoop()
    while NCHub.Settings.ESP do
        -- ESP para inimigos
        for _, v in ipairs(workspace.Enemies:GetChildren()) do
            if v:IsA("Model") then
                if not ESPObjects[v] then
                    CreateESP(v)
                end
            end
        end
        
        -- ESP para players (opcional)
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                if not ESPObjects[v.Character] then
                    CreateESP(v.Character)
                end
            end
        end
        
        task.wait(0.5)
    end
    
    -- Limpa ESP quando desativado
    for char, esp in pairs(ESPObjects) do
        esp:Destroy()
    end
    table.clear(ESPObjects)
end

-- Chams (cores vibrantes)
local function ChamsLoop()
    while NCHub.Settings.Chams do
        for _, v in ipairs(workspace.Enemies:GetChildren()) do
            if v:IsA("Model") then
                for _, part in ipairs(v:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Material = Enum.Material.Neon
                        part.Color = Color3.fromRGB(255, 0, 0)
                    end
                end
            end
        end
        task.wait(1)
    end
end

-- Speed Hack (seguro)
local function SpeedHackLoop()
    local originalSpeed = 16
    while NCHub.Settings.SpeedHack do
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.WalkSpeed = originalSpeed + NCHub.Settings.SpeedValue
        end
        task.wait(0.5)
    end
    
    -- Reset speed
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.WalkSpeed = originalSpeed
    end
end

-- Fly System
local FlyEnabled = false
local function FlyLoop()
    while NCHub.Settings.Fly do
        local character = LocalPlayer.Character
        if not character then break end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            humanoid.PlatformStand = true
            
            local moveDirection = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection + Vector3.new(-1, 0, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + Vector3.new(1, 0, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection + Vector3.new(0, -1, 0) end
            
            if moveDirection.Magnitude > 0 then
                moveDirection = moveDirection.unit
                rootPart.Velocity = moveDirection * 50
            else
                rootPart.Velocity = Vector3.new(0, 0, 0)
            end
        end
        
        task.wait()
    end
    
    -- Reset
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.PlatformStand = false
    end
end

-- No Clip
local function NoClipLoop()
    while NCHub.Settings.NoClip do
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        task.wait(1)
    end
    
    -- Reset
    local character = LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ========== FUNÇÕES DE BRINCADEIRA ==========

-- Efeitos Visuais
local function CreateEffect(effectType)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local pos = character.HumanoidRootPart.Position
    
    if effectType == "Explosion" then
        local explosion = Instance.new("Explosion")
        explosion.Position = pos
        explosion.BlastRadius = 10
        explosion.Parent = workspace
    elseif effectType == "Fire" then
        local fire = Instance.new("Fire")
        fire.Parent = character.HumanoidRootPart
        fire.Size = 5
        task.delay(2, function() fire:Destroy() end)
    elseif effectType == "Sparkles" then
        local sparkles = Instance.new("Sparkles")
        sparkles.Parent = character.HumanoidRootPart
        task.delay(2, function() sparkles:Destroy() end)
    elseif effectType == "Smoke" then
        local smoke = Instance.new("Smoke")
        smoke.Parent = character.HumanoidRootPart
        smoke.Color = Color3.fromRGB(0, 0, 0)
        task.delay(2, function() smoke:Destroy() end)
    elseif effectType == "Trail" then
        local trail = Instance.new("Trail")
        trail.Parent = character.HumanoidRootPart
        trail.Lifetime = 1
        trail.Width = 1
        task.delay(2, function() trail:Destroy() end)
    end
end

-- Spam de Efeitos
local function SpamEffectsLoop()
    while NCHub.Settings.SpamEffects do
        CreateEffect(NCHub.Settings.EffectType)
        task.wait(0.3)
    end
end

-- Chat Spam
local function ChatSpamLoop()
    while NCHub.Settings.ChatSpam do
        game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(NCHub.Settings.ChatSpamMessage, "All")
        task.wait(NCHub.Settings.ChatSpamDelay)
    end
end

-- Animação Spam
local function AnimationSpamLoop()
    while NCHub.Settings.AnimationSpam do
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") and NCHub.Settings.AnimationID ~= "" then
            local anim = Instance.new("Animation")
            anim.AnimationId = NCHub.Settings.AnimationID
            local track = character.Humanoid:LoadAnimation(anim)
            track:Play()
            task.wait(2)
            track:Stop()
        end
        task.wait(1)
    end
end

-- Force Field
local function ForceFieldLoop()
    while NCHub.Settings.ForceField do
        local character = LocalPlayer.Character
        if character then
            local forceField = character:FindFirstChild("ForceField")
            if not forceField then
                local newForceField = Instance.new("ForceField")
                newForceField.Parent = character
                task.delay(5, function()
                    if newForceField and newForceField.Parent then
                        newForceField:Destroy()
                    end
                end)
            end
        end
        task.wait(5)
    end
end

-- ========== CONSTRUÇÃO DA UI CLEAN ==========

local Window = Rayfield:CreateWindow({
    Name = "NCHub v" .. NCHub.Versao .. " | by " .. NCHub.Criador,
    LoadingTitle = "Carregando NCHub...",
    LoadingSubtitle = "Sistema Ultra Otimizado",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Abas Principais
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)
local FarmTab = Window:CreateTab("🌾 Farm", 4483362458)
local RaidBossTab = Window:CreateTab("👑 Raid & Boss", 4483362458)
local TeleportsTab = Window:CreateTab("📍 Teleports", 4483362458)
local VisualsTab = Window:CreateTab("🎨 Visuals", 4483362458)
local MovementTab = Window:CreateTab("🏃 Movement", 4483362458)
local FunTab = Window:CreateTab("🎉 Fun", 4483362458)
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)

-- ========== ABA COMBAT (KILL AURA) ==========
CombatTab:CreateToggle({
    Name = "🔪 Kill Aura (Anti-Ban)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.KillAura = value
        if value then
            task.spawn(KillAuraLoop)
        end
    end
})

CombatTab:CreateSlider({
    Name = "📏 Alcance do Kill Aura",
    Range = {50, 300},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = 180,
    Callback = function(value)
        NCHub.Settings.KillAuraRange = value
    end
})

CombatTab:CreateSlider({
    Name = "⏱️ Delay entre Ataques (segundos)",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.1,
    Callback = function(value)
        NCHub.Settings.KillAuraDelay = value
    end
})

CombatTab:CreateDropdown({
    Name = "🎯 Alvos do Kill Aura",
    Options = {"All", "Mobs", "Players"},
    CurrentOption = "All",
    Callback = function(option)
        NCHub.Settings.KillAuraTargets = option
    end
})

CombatTab:CreateToggle({
    Name = "🛡️ Modo Seguro (Anti-Ban)",
    CurrentValue = true,
    Callback = function(value)
        NCHub.Settings.KillAuraSafeMode = value
    end
})

CombatTab:CreateToggle({
    Name = "🔒 Proteção Anti-Ban Avançada",
    CurrentValue = true,
    Callback = function(value)
        NCHub.Settings.KillAuraAntiBan = value
    end
})

CombatTab:CreateDropdown({
    Name = "⚔️ Arma Principal",
    Options = {"Melee", "Sword", "Fruit"},
    CurrentOption = "Melee",
    Callback = function(option)
        NCHub.Settings.SelectedWeapon = option
    end
})

-- Whitelist (evitar atacar amigos)
CombatTab:CreateInput({
    Name = "👥 Adicionar à Whitelist (Nome)",
    PlaceholderText = "Digite o nome do amigo",
    CurrentValue = "",
    Callback = function(text)
        if text ~= "" then
            table.insert(NCHub.Security.Whitelisted, text)
            Rayfield:Notify({
                Title = "Whitelist",
                Content = text .. " adicionado à lista de amigos",
                Duration = 3
            })
        end
    end
})

-- ========== ABA FARM ==========
FarmTab:CreateToggle({
    Name = "🌾 Auto Farm (Mobs)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoFarm = value
        if value then
            task.spawn(AutoFarmLoop)
        end
    end
})

FarmTab:CreateSlider({
    Name = "📏 Raio de Farm",
    Range = {50, 500},
    Increment = 10,
    Suffix = "studs",
    CurrentValue = 150,
    Callback = function(value)
        NCHub.Settings.FarmRadius = value
    end
})

FarmTab:CreateDropdown({
    Name = "👾 Tipo de Inimigo",
    Options = {"All", "Normal", "Boss"},
    CurrentOption = "All",
    Callback = function(option)
        NCHub.Settings.FarmMobType = option
    end
})

FarmTab:CreateDivider()

FarmTab:CreateToggle({
    Name = "🍎 Auto Coletar Frutas",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoCollectFruit = value
        if NCHub.Settings.AutoCollectFruit or NCHub.Settings.AutoCollectChest or NCHub.Settings.AutoCollectMaterial then
            if not NCHub.Loops.AutoCollect then
                NCHub.Loops.AutoCollect = task.spawn(AutoCollectLoop)
            end
        end
    end
})

FarmTab:CreateToggle({
    Name = "📦 Auto Coletar Baús",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoCollectChest = value
        if NCHub.Settings.AutoCollectFruit or NCHub.Settings.AutoCollectChest or NCHub.Settings.AutoCollectMaterial then
            if not NCHub.Loops.AutoCollect then
                NCHub.Loops.AutoCollect = task.spawn(AutoCollectLoop)
            end
        end
    end
})

FarmTab:CreateToggle({
    Name = "💎 Auto Coletar Materiais",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoCollectMaterial = value
        if NCHub.Settings.AutoCollectFruit or NCHub.Settings.AutoCollectChest or NCHub.Settings.AutoCollectMaterial then
            if not NCHub.Loops.AutoCollect then
                NCHub.Loops.AutoCollect = task.spawn(AutoCollectLoop)
            end
        end
    end
})

FarmTab:CreateSlider({
    Name = "📏 Raio de Coleta",
    Range = {50, 500},
    Increment = 10,
    Suffix = "studs",
    CurrentValue = 200,
    Callback = function(value)
        NCHub.Settings.AutoCollectRadius = value
    end
})

FarmTab:CreateDivider()

FarmTab:CreateToggle({
    Name = "📈 Auto Level (Farm + Quest)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoLevel = value
        if value then
            task.spawn(AutoLevelLoop)
        end
    end
})

FarmTab:CreateToggle({
    Name = "📋 Auto Pegar Quest",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoQuest = value
    end
})

FarmTab:CreateToggle({
    Name = "🌊 Auto Sea Beast",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoSeaBeast = value
        if value then
            task.spawn(AutoSeaBeastLoop)
        end
    end
})

-- ========== ABA RAID & BOSS ==========
RaidBossTab:CreateToggle({
    Name = "⚡ Auto Raid",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoRaid = value
        if value then
            task.spawn(AutoRaidLoop)
        end
    end
})

RaidBossTab:CreateDropdown({
    Name = "🔥 Tipo de Raid",
    Options = {"Flame", "Ice", "Sand", "Dark", "Light", "Magma", "Water"},
    CurrentOption = "Flame",
    Callback = function(option)
        NCHub.Settings.RaidType = option
    end
})

RaidBossTab:CreateSlider({
    Name = "⏱️ Delay entre Raids",
    Range = {1, 30},
    Increment = 1,
    Suffix = "s",
    CurrentValue = 5,
    Callback = function(value)
        NCHub.Settings.RaidDelay = value
    end
})

RaidBossTab:CreateDivider()

RaidBossTab:CreateToggle({
    Name = "👑 Auto Boss",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AutoBoss = value
        if value then
            task.spawn(AutoBossLoop)
        end
    end
})

RaidBossTab:CreateDropdown({
    Name = "🐉 Selecionar Boss",
    Options = NCHub.Settings.BossList,
    CurrentOption = "Dragon",
    Callback = function(option)
        NCHub.Settings.SelectedBoss = option
    end
})

RaidBossTab:CreateButton({
    Name = "📍 Teleportar para Boss",
    Callback = function()
        for _, v in ipairs(workspace.Enemies:GetChildren()) do
            if v:IsA("Model") and v.Name:lower():find(NCHub.Settings.SelectedBoss:lower()) then
                if v:FindFirstChild("HumanoidRootPart") then
                    TeleportTo(v.HumanoidRootPart.Position)
                    break
                end
            end
        end
    end
})

-- ========== ABA TELEPORTS ==========
-- Criar seção de teleports (scrollable)
for _, loc in ipairs(TeleportLocations) do
    TeleportsTab:CreateButton({
        Name = "📍 " .. loc[1],
        Callback = function()
            TeleportTo(loc[2])
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Teleportado para " .. loc[1],
                Duration = 2
            })
        end
    })
end

-- Histórico de teleports
TeleportsTab:CreateButton({
    Name = "📜 Histórico de Teleports",
    Callback = function()
        local historyText = "Últimos teleports:\n"
        for i = #NCHub.Settings.TeleportHistory, math.max(1, #NCHub.Settings.TeleportHistory - 5), -1 do
            local entry = NCHub.Settings.TeleportHistory[i]
            if entry then
                historyText = historyText .. os.date("%H:%M:%S", entry[1]) .. " - " .. tostring(entry[2]) .. "\n"
            end
        end
        Rayfield:Notify({
            Title = "Histórico",
            Content = historyText,
            Duration = 5
        })
    end
})

-- ========== ABA VISUAIS ==========
VisualsTab:CreateToggle({
    Name = "👁️ ESP (Ver Inimigos)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.ESP = value
        if value then
            task.spawn(ESPLoop)
        end
    end
})

VisualsTab:CreateColorPicker({
    Name = "🎨 Cor do ESP",
    CurrentValue = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        NCHub.Settings.ESPColor = color
    end
})

VisualsTab:CreateToggle({
    Name = "✨ Chams (Cores Vibrantes)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.Chams = value
        if value then
            task.spawn(ChamsLoop)
        end
    end
})

VisualsTab:CreateButton({
    Name = "🌙 Modo Noturno",
    Callback = function()
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.Brightness = 0
        Lighting.ClockTime = 0
        Rayfield:Notify({Title = "Visuals", Content = "Modo noturno ativado", Duration = 2})
    end
})

VisualsTab:CreateButton({
    Name = "☀️ Modo Dia",
    Callback = function()
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
        Rayfield:Notify({Title = "Visuals", Content = "Modo dia ativado", Duration = 2})
    end
})

-- ========== ABA MOVEMENT ==========
MovementTab:CreateToggle({
    Name = "💨 Speed Hack",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.SpeedHack = value
        if value then
            task.spawn(SpeedHackLoop)
        end
    end
})

MovementTab:CreateSlider({
    Name = "⚡ Velocidade Extra",
    Range = {0, 100},
    Increment = 5,
    Suffix = "speed",
    CurrentValue = 50,
    Callback = function(value)
        NCHub.Settings.SpeedValue = value
    end
})

MovementTab:CreateToggle({
    Name = "🕊️ Fly (Voar)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.Fly = value
        if value then
            task.spawn(FlyLoop)
        end
    end
})

MovementTab:CreateToggle({
    Name = "🔓 No Clip (Atravessar Paredes)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.NoClip = value
        if value then
            task.spawn(NoClipLoop)
        end
    end
})

MovementTab:CreateButton({
    Name = "⬆️ Teleportar para o Céu",
    Callback = function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local pos = character.HumanoidRootPart.Position
            TeleportTo(Vector3.new(pos.X, pos.Y + 100, pos.Z))
        end
    end
})

MovementTab:CreateButton({
    Name = "⬇️ Teleportar para o Chão",
    Callback = function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local pos = character.HumanoidRootPart.Position
            TeleportTo(Vector3.new(pos.X, 50, pos.Z))
        end
    end
})

-- ========== ABA DIVERSÃO ==========
FunTab:CreateToggle({
    Name = "✨ Spam de Efeitos",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.SpamEffects = value
        if value then
            task.spawn(SpamEffectsLoop)
        end
    end
})

FunTab:CreateDropdown({
    Name = "🎆 Tipo de Efeito",
    Options = {"Explosion", "Fire", "Sparkles", "Smoke", "Trail"},
    CurrentOption = "Explosion",
    Callback = function(option)
        NCHub.Settings.EffectType = option
    end
})

FunTab:CreateDivider()

FunTab:CreateToggle({
    Name = "💬 Chat Spam",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.ChatSpam = value
        if value then
            task.spawn(ChatSpamLoop)
        end
    end
})

FunTab:CreateInput({
    Name = "📝 Mensagem do Spam",
    PlaceholderText = "Digite a mensagem",
    CurrentValue = "",
    Callback = function(text)
        NCHub.Settings.ChatSpamMessage = text
    end
})

FunTab:CreateSlider({
    Name = "⏱️ Delay do Spam",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 1,
    Callback = function(value)
        NCHub.Settings.ChatSpamDelay = value
    end
})

FunTab:CreateDivider()

FunTab:CreateToggle({
    Name = "💃 Spam de Animação",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AnimationSpam = value
        if value then
            task.spawn(AnimationSpamLoop)
        end
    end
})

FunTab:CreateInput({
    Name = "🎬 ID da Animação",
    PlaceholderText = "rbxassetid://...",
    CurrentValue = "",
    Callback = function(text)
        NCHub.Settings.AnimationID = text
    end
})

FunTab:CreateDivider()

FunTab:CreateToggle({
    Name = "🛡️ Force Field (Campo de Força)",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.ForceField = value
        if value then
            task.spawn(ForceFieldLoop)
        end
    end
})

FunTab:CreateButton({
    Name = "💥 Explosão Instantânea",
    Callback = function()
        CreateEffect("Explosion")
    end
})

FunTab:CreateButton({
    Name = "🔥 Fogo no Personagem",
    Callback = function()
        CreateEffect("Fire")
    end
})

-- ========== ABA CONFIGURAÇÕES ==========
SettingsTab:CreateToggle({
    Name = "🛡️ Anti-Kick",
    CurrentValue = false,
    Callback = function(value)
        NCHub.Settings.AntiKick = value
        if value then
            game:GetService("Players").LocalPlayer.Kick = function() end
        end
    end
})

SettingsTab:CreateToggle({
    Name = "🚫 Modo Anti-Ban Total",
    CurrentValue = true,
    Callback = function(value)
        NCHub.Settings.AntiBanMode = value
    end
})

SettingsTab:CreateButton({
    Name = "🔄 Reconectar ao Servidor",
    Callback = function()
        TeleportService:Teleport(game.PlaceId)
    end
})

SettingsTab:CreateButton({
    Name = "❌ Sair do Jogo",
    Callback = function()
        game:Shutdown()
    end
})

SettingsTab:CreateButton({
    Name = "📊 Status do Hub",
    Callback = function()
        local status = "=== NCHub Status ===\n"
        status = status .. "Versão: " .. NCHub.Versao .. "\n"
        status = status .. "Criador: " .. NCHub.Criador .. "\n"
        status = status .. "Sessão Ativa: " .. os.date("%H:%M:%S", NCHub.Security.SessionStart) .. "\n"
        status = status .. "Kill Aura: " .. tostring(NCHub.Settings.KillAura) .. "\n"
        status = status .. "Auto Farm: " .. tostring(NCHub.Settings.AutoFarm) .. "\n"
        status = status .. "Proteção Anti-Ban: " .. tostring(NCHub.Settings.AntiBanMode) .. "\n"
        
        Rayfield:Notify({
            Title = "Status",
            Content = status,
            Duration = 8
        })
    end
})

-- Notificação de inicialização
Rayfield:Notify({
    Title = "NCHub v" .. NCHub.Versao,
    Content = "Carregado com sucesso! Modo Anti-Ban ativo.",
    Duration = 5
})

print("=========================================")
print("NCHub v" .. NCHub.Versao .. " - Feito por " .. NCHub.Criador)
print("Kill Aura Seguro | Anti-Ban Ativado")
print("=========================================")
