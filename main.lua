--[[
    NCHub v2.0 – Kill Aura + Raid Farm + Mob Farm
    Refeito por NCMine (melhorado)
    Compatível com Delta Mobile
]]

-- ========== CARREGAMENTO DA UI ==========
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== SERVIÇOS ==========
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer     = Players.LocalPlayer
local Camera          = workspace.CurrentCamera

-- ========== CONFIGURAÇÕES GLOBAIS ==========
local Settings = {
    -- Kill Aura
    KillAura         = false,
    KillAuraRange    = 30,
    KillAuraDelay    = 0.08,
    KillAuraIgnoreBoss = false,
    AutoEquipSword   = true,

    -- Raid Farm
    RaidFarm         = false,
    BuddhaMode       = false,
    RaidRange        = 60,

    -- Mob Farm
    MobFarm          = false,
    SelectedIsland   = "Marinha",
    MobRange         = 100,
    MobDelay         = 0.1,
    TeleportOnStart  = true,

    -- Utilitários
    AutoCollect      = false,
    NoclipEnabled    = false,
    ESPEnabled       = false,
}

-- ========== ILHAS (coordenadas) ==========
local Islands = {
    -- Primeiro Mar
    { "Marinha",            Vector3.new(-790,  80, -1260) },
    { "Deserto",            Vector3.new(1020, 125,  1240) },
    { "Jungla",             Vector3.new(-1200, 50,   500) },
    { "Ilha do Céu",        Vector3.new(-5000,300, -2000) },
    { "Ilha do Tesouro",    Vector3.new(2000,  50,  3000) },
    { "Ilha do Cogumelo",   Vector3.new(-800,  80,  1200) },

    -- Segundo Mar
    { "Ilha do Cemitério",  Vector3.new(-3000, 50,  4000) },
    { "Ilha da Neve",       Vector3.new(-4000,100, -1000) },
    { "Ilha do Café",       Vector3.new(-2000, 50, -3000) },
    { "Ilha da Fábrica",    Vector3.new(0,     50, -4000) },
    { "Ilha do Trono",      Vector3.new(3000, 150,  2000) },

    -- Terceiro Mar
    { "Castelo",            Vector3.new(5000, 200,  5000) },
    { "Ilha das Almas",     Vector3.new(6000, 100,  6000) },
    { "Ilha do Dragão",     Vector3.new(7000, 150,  7000) },
    { "Ilha dos Espelhos",  Vector3.new(8000, 200,  8000) },
    { "Zona Neutra",        Vector3.new(4000, 100,  4000) },
}

-- ========== UTILITÁRIOS ==========

-- Pegar personagem de forma segura
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetRoot()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Verificar se está vivo
local function IsAlive()
    local hum = GetHumanoid()
    return hum and hum.Health > 0
end

-- Teleportar de forma segura
local function TeleportTo(pos)
    local root = GetRoot()
    if root then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

-- Pegar coordenada de ilha pelo nome
local function GetIslandCoord(name)
    for _, island in ipairs(Islands) do
        if island[1] == name then
            return island[2]
        end
    end
    return nil
end

-- Equipar primeira espada no inventário
local function EquipSword()
    local character = GetCharacter()
    if not character then return end
    local backpack = LocalPlayer.Backpack
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            -- Prefere ferramentas com "sword" ou "katana" no nome
            local n = item.Name:lower()
            if n:find("sword") or n:find("katana") or n:find("blade") or n:find("sabre") then
                LocalPlayer.Character.Humanoid:EquipTool(item)
                return item
            end
        end
    end
    -- Se não achou espada específica, equipa a primeira ferramenta
    local first = backpack:FindFirstChildOfClass("Tool")
    if first then
        LocalPlayer.Character.Humanoid:EquipTool(first)
        return first
    end
end

-- Pegar ferramenta equipada
local function GetEquippedTool()
    local character = GetCharacter()
    if not character then return nil end
    return character:FindFirstChildOfClass("Tool")
end

-- Ativar ferramenta (simula clique)
local function ActivateTool()
    local tool = GetEquippedTool()
    if not tool then
        if Settings.AutoEquipSword then
            tool = EquipSword()
        end
    end
    if tool and tool.Activated then
        tool:Activate()
    elseif tool then
        -- Fallback: dispara evento manualmente
        local remote = tool:FindFirstChildOfClass("RemoteEvent")
        if remote then
            remote:FireServer()
        end
    end
end

-- ========== DETECÇÃO DE MOBS ==========

local function IsMob(model)
    if not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    -- Não é o próprio jogador
    if model == GetCharacter() then return false end
    -- Não é outro jogador
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return false end
    end
    return true
end

local function IsBoss(model)
    local n = model.Name:lower()
    return n:find("boss") or n:find("raid") or n:find("buddha") or model:FindFirstChild("Boss") ~= nil
end

local function GetNearbyMobs(range, ignoreBoss)
    local root = GetRoot()
    if not root then return {} end

    local mobs = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if IsMob(v) then
            if ignoreBoss and IsBoss(v) then continue end
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist <= range then
                    table.insert(mobs, { model = v, distance = dist })
                end
            end
        end
    end

    -- Ordenar por distância (mais próximos primeiro)
    table.sort(mobs, function(a, b) return a.distance < b.distance end)
    return mobs
end

-- Atacar alvo: teleporta perto e ativa ferramenta
local function AttackMob(mob)
    if not mob or not mob:FindFirstChild("HumanoidRootPart") then return end
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local root = GetRoot()
    if root then
        -- Vai até perto do mob sem atravessar ele
        root.CFrame = mob.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3.5)
    end

    ActivateTool()
end

-- ========== KILL AURA ==========

local KillAuraConnection = nil

local function StartKillAura()
    if KillAuraConnection then KillAuraConnection:Disconnect() end

    KillAuraConnection = RunService.Heartbeat:Connect(function()
        if not Settings.KillAura then
            KillAuraConnection:Disconnect()
            return
        end
        if not IsAlive() then return end

        local mobs = GetNearbyMobs(Settings.KillAuraRange, false)
        for _, entry in ipairs(mobs) do
            AttackMob(entry.model)
            task.wait(Settings.KillAuraDelay)
        end
    end)
end

-- ========== RAID FARM ==========

local function IsInRaid()
    return workspace:FindFirstChild("Raid") ~= nil
        or workspace:FindFirstChild("RaidFolder") ~= nil
end

local function GetRaidBoss()
    for _, v in ipairs(workspace:GetDescendants()) do
        if IsMob(v) and IsBoss(v) then
            return v
        end
    end
    return nil
end

local function RaidFarmLoop()
    while Settings.RaidFarm do
        if not IsAlive() then task.wait(2) continue end

        if not IsInRaid() then
            -- Aguarda entrar na raid
            task.wait(1)
            continue
        end

        if Settings.BuddhaMode then
            -- Modo Buda: ficar em cima do boss
            local boss = GetRaidBoss()
            if boss then
                local root = GetRoot()
                local bossHead = boss:FindFirstChild("Head") or boss:FindFirstChild("HumanoidRootPart")
                if root and bossHead then
                    root.CFrame = bossHead.CFrame * CFrame.new(0, 5, 0)
                end
            end
            -- Atacar mobs normais ao redor
            local mobs = GetNearbyMobs(Settings.RaidRange, true)
            for _, entry in ipairs(mobs) do
                AttackMob(entry.model)
                task.wait(0.1)
            end
        else
            -- Modo normal: atacar tudo
            local mobs = GetNearbyMobs(Settings.RaidRange, false)
            for _, entry in ipairs(mobs) do
                AttackMob(entry.model)
                task.wait(0.1)
            end
        end

        task.wait(0.05)
    end
end

-- ========== MOB FARM ==========

local function MobFarmLoop()
    -- Teleporta para a ilha se configurado
    if Settings.TeleportOnStart then
        local coord = GetIslandCoord(Settings.SelectedIsland)
        if coord then
            TeleportTo(coord)
            Rayfield:Notify({
                Title = "🏝️ Mob Farm",
                Content = "Teleportado para: " .. Settings.SelectedIsland,
                Duration = 3,
                Image = 4483362458
            })
            task.wait(2)
        end
    end

    while Settings.MobFarm do
        if not IsAlive() then
            -- Aguarda respawn
            task.wait(3)
            if Settings.TeleportOnStart then
                local coord = GetIslandCoord(Settings.SelectedIsland)
                if coord then TeleportTo(coord) end
                task.wait(2)
            end
            continue
        end

        local mobs = GetNearbyMobs(Settings.MobRange, false)
        if #mobs > 0 then
            for _, entry in ipairs(mobs) do
                if not Settings.MobFarm then break end
                AttackMob(entry.model)
                task.wait(Settings.MobDelay)
            end
        else
            task.wait(0.5)
        end
    end
end

-- ========== ESP (highlight mobs) ==========

local ESPHighlights = {}

local function ClearESP()
    for _, h in ipairs(ESPHighlights) do
        if h and h.Parent then h:Destroy() end
    end
    ESPHighlights = {}
end

local function UpdateESP()
    ClearESP()
    if not Settings.ESPEnabled then return end

    for _, v in ipairs(workspace:GetDescendants()) do
        if IsMob(v) then
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 50, 50)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.Parent = v
            table.insert(ESPHighlights, highlight)
        end
    end
end

local ESPLoop = nil
local function StartESP()
    if ESPLoop then ESPLoop:Disconnect() end
    ESPLoop = RunService.Heartbeat:Connect(function()
        if not Settings.ESPEnabled then
            ClearESP()
            if ESPLoop then ESPLoop:Disconnect() end
            return
        end
        UpdateESP()
    end)
end

-- ========== NOCLIP ==========

local NoclipConnection = nil

local function StartNoclip()
    if NoclipConnection then NoclipConnection:Disconnect() end
    NoclipConnection = RunService.Stepped:Connect(function()
        if not Settings.NoclipEnabled then
            NoclipConnection:Disconnect()
            return
        end
        local character = GetCharacter()
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

-- ========== AUTO COLETAR (frutas/drops) ==========

local function AutoCollectLoop()
    while Settings.AutoCollect do
        local root = GetRoot()
        if root then
            for _, v in ipairs(workspace:GetDescendants()) do
                -- Tenta coletar objetos próximos (frutas, drops)
                local isFruit = v.Name:lower():find("fruit") or v.Name:lower():find("devil")
                if v:IsA("BasePart") and isFruit then
                    local dist = (v.Position - root.Position).Magnitude
                    if dist < 200 then
                        TeleportTo(v.Position)
                        task.wait(0.3)
                        -- Tenta interagir via ProximityPrompt
                        local prompt = v:FindFirstChildOfClass("ProximityPrompt")
                            or v.Parent and v.Parent:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then
                            fireproximityprompt(prompt)
                        end
                        task.wait(0.2)
                    end
                end
            end
        end
        task.wait(2)
    end
end

-- ========== INTERFACE RAYFIELD ==========

local Window = Rayfield:CreateWindow({
    Name = "NCHub v2.0",
    LoadingTitle = "NCHub – Blox Fruits",
    LoadingSubtitle = "by NCMine  |  v2.0",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NCHub",
        FileName = "Config"
    },
    KeySystem = false
})

-- ===== ABA: KILL AURA =====
local AuraTab = Window:CreateTab("⚡ Kill Aura", 4483362458)

AuraTab:CreateSection("Configuração")

AuraTab:CreateToggle({
    Name = "⚡ Kill Aura",
    CurrentValue = false,
    Flag = "KillAura",
    Callback = function(v)
        Settings.KillAura = v
        if v then
            StartKillAura()
            Rayfield:Notify({ Title = "Kill Aura", Content = "Ativado! Atacando mobs próximos.", Duration = 3 })
        else
            Rayfield:Notify({ Title = "Kill Aura", Content = "Desativado.", Duration = 2 })
        end
    end
})

AuraTab:CreateToggle({
    Name = "🗡️ Auto Equipar Espada",
    CurrentValue = true,
    Flag = "AutoEquipSword",
    Callback = function(v)
        Settings.AutoEquipSword = v
    end
})

AuraTab:CreateSlider({
    Name = "📏 Alcance da Kill Aura",
    Range = {10, 150},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = Settings.KillAuraRange,
    Flag = "KillAuraRange",
    Callback = function(v)
        Settings.KillAuraRange = v
    end
})

AuraTab:CreateSlider({
    Name = "⏱️ Delay entre ataques",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Settings.KillAuraDelay,
    Flag = "KillAuraDelay",
    Callback = function(v)
        Settings.KillAuraDelay = v
    end
})

AuraTab:CreateButton({
    Name = "🗡️ Equipar melhor espada agora",
    Callback = function()
        local tool = EquipSword()
        if tool then
            Rayfield:Notify({ Title = "Equip", Content = "Equipado: " .. tool.Name, Duration = 2 })
        else
            Rayfield:Notify({ Title = "Equip", Content = "Nenhuma ferramenta encontrada no inventário.", Duration = 3 })
        end
    end
})

-- ===== ABA: RAID FARM =====
local RaidTab = Window:CreateTab("⚔️ Raid Farm", 4483362458)

RaidTab:CreateSection("Configuração")

RaidTab:CreateToggle({
    Name = "⚔️ Farm na Raid",
    CurrentValue = false,
    Flag = "RaidFarm",
    Callback = function(v)
        Settings.RaidFarm = v
        if v then
            task.spawn(RaidFarmLoop)
            Rayfield:Notify({ Title = "Raid Farm", Content = "Ativado! Entre em uma Raid.", Duration = 3 })
        else
            Rayfield:Notify({ Title = "Raid Farm", Content = "Desativado.", Duration = 2 })
        end
    end
})

RaidTab:CreateToggle({
    Name = "🪷 Modo Buda (voar na cabeça do boss)",
    CurrentValue = false,
    Flag = "BuddhaMode",
    Callback = function(v)
        Settings.BuddhaMode = v
        Rayfield:Notify({
            Title = "Modo Buda",
            Content = v and "Ativado. Ficará em cima do boss!" or "Desativado.",
            Duration = 2
        })
    end
})

RaidTab:CreateSlider({
    Name = "📏 Alcance na Raid",
    Range = {30, 150},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = Settings.RaidRange,
    Flag = "RaidRange",
    Callback = function(v)
        Settings.RaidRange = v
    end
})

RaidTab:CreateSection("Informações")

RaidTab:CreateButton({
    Name = "ℹ️ Como usar",
    Callback = function()
        Rayfield:Notify({
            Title = "Instruções – Raid Farm",
            Content = "1. Ative o toggle Raid Farm.\n2. Entre em uma Raid manualmente.\n3. O script detecta automaticamente e começa a atacar.\n4. Para modo Buda, ative antes de entrar.",
            Duration = 8
        })
    end
})

-- ===== ABA: MOB FARM =====
local MobTab = Window:CreateTab("🏝️ Mob Farm", 4483362458)

MobTab:CreateSection("Ilha")

local islandNames = {}
for _, island in ipairs(Islands) do
    table.insert(islandNames, island[1])
end

MobTab:CreateDropdown({
    Name = "🏝️ Selecionar Ilha",
    Options = islandNames,
    CurrentOption = Settings.SelectedIsland,
    Flag = "SelectedIsland",
    Callback = function(option)
        Settings.SelectedIsland = option
        Rayfield:Notify({ Title = "Ilha", Content = "Selecionada: " .. option, Duration = 2 })
    end
})

MobTab:CreateButton({
    Name = "📍 Teleportar agora",
    Callback = function()
        local coord = GetIslandCoord(Settings.SelectedIsland)
        if coord then
            TeleportTo(coord)
            Rayfield:Notify({ Title = "Teleport", Content = "Indo para: " .. Settings.SelectedIsland, Duration = 2 })
        end
    end
})

MobTab:CreateSection("Configuração do Farm")

MobTab:CreateToggle({
    Name = "🤖 Auto Mob Farm",
    CurrentValue = false,
    Flag = "MobFarm",
    Callback = function(v)
        Settings.MobFarm = v
        if v then
            task.spawn(MobFarmLoop)
            Rayfield:Notify({ Title = "Mob Farm", Content = "Farmando em: " .. Settings.SelectedIsland, Duration = 3 })
        else
            Rayfield:Notify({ Title = "Mob Farm", Content = "Desativado.", Duration = 2 })
        end
    end
})

MobTab:CreateToggle({
    Name = "🚀 Teleportar ao iniciar",
    CurrentValue = true,
    Flag = "TeleportOnStart",
    Callback = function(v)
        Settings.TeleportOnStart = v
    end
})

MobTab:CreateSlider({
    Name = "📏 Alcance de detecção",
    Range = {30, 250},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = Settings.MobRange,
    Flag = "MobRange",
    Callback = function(v)
        Settings.MobRange = v
    end
})

MobTab:CreateSlider({
    Name = "⏱️ Delay entre ataques",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Settings.MobDelay,
    Flag = "MobDelay",
    Callback = function(v)
        Settings.MobDelay = v
    end
})

-- ===== ABA: UTILITÁRIOS =====
local UtilTab = Window:CreateTab("🔧 Utilidades", 4483362458)

UtilTab:CreateSection("Visual")

UtilTab:CreateToggle({
    Name = "👁️ ESP – Highlight Mobs",
    CurrentValue = false,
    Flag = "ESPEnabled",
    Callback = function(v)
        Settings.ESPEnabled = v
        if v then StartESP() end
        Rayfield:Notify({ Title = "ESP", Content = v and "Mobs destacados em vermelho." or "ESP desativado.", Duration = 2 })
    end
})

UtilTab:CreateSection("Movimento")

UtilTab:CreateToggle({
    Name = "👻 Noclip",
    CurrentValue = false,
    Flag = "NoclipEnabled",
    Callback = function(v)
        Settings.NoclipEnabled = v
        if v then StartNoclip() end
        Rayfield:Notify({ Title = "Noclip", Content = v and "Ativado. Atravessa paredes." or "Desativado.", Duration = 2 })
    end
})

UtilTab:CreateSection("Coleta")

UtilTab:CreateToggle({
    Name = "🍎 Auto Coletar Frutas",
    CurrentValue = false,
    Flag = "AutoCollect",
    Callback = function(v)
        Settings.AutoCollect = v
        if v then task.spawn(AutoCollectLoop) end
        Rayfield:Notify({ Title = "Auto Collect", Content = v and "Coletando frutas automaticamente!" or "Desativado.", Duration = 2 })
    end
})

UtilTab:CreateButton({
    Name = "💀 Auto Morrer (respawn rápido)",
    Callback = function()
        local hum = GetHumanoid()
        if hum then
            hum.Health = 0
            Rayfield:Notify({ Title = "Respawn", Content = "Morrendo para respawnar...", Duration = 2 })
        end
    end
})

UtilTab:CreateButton({
    Name = "🏃 Teleportar para Spawn",
    Callback = function()
        TeleportTo(Vector3.new(0, 50, 0))
        Rayfield:Notify({ Title = "Teleport", Content = "Indo para o spawn.", Duration = 2 })
    end
})

-- ===== ABA: INFO =====
local InfoTab = Window:CreateTab("📋 Info", 4483362458)

InfoTab:CreateSection("NCHub v2.0")

InfoTab:CreateLabel("Criado por NCMine")
InfoTab:CreateLabel("Kill Aura | Raid Farm | Mob Farm | ESP | Noclip")
InfoTab:CreateLabel("Use com responsabilidade.")

InfoTab:CreateSection("Status")

InfoTab:CreateButton({
    Name = "📊 Ver status atual",
    Callback = function()
        local status = string.format(
            "Kill Aura: %s\nRaid Farm: %s\nMob Farm: %s\nESP: %s\nNoclip: %s",
            Settings.KillAura and "✅" or "❌",
            Settings.RaidFarm and "✅" or "❌",
            Settings.MobFarm and "✅" or "❌",
            Settings.ESPEnabled and "✅" or "❌",
            Settings.NoclipEnabled and "✅" or "❌"
        )
        Rayfield:Notify({ Title = "Status", Content = status, Duration = 6 })
    end
})

-- ========== NOTIFICAÇÃO INICIAL ==========
task.wait(1)
Rayfield:Notify({
    Title = "✅ NCHub v2.0 Carregado!",
    Content = "Kill Aura, Raid Farm, Mob Farm e mais prontos!",
    Duration = 5,
    Image = 4483362458
})
