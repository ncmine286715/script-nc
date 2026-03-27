--[[
    NCHub v3.0 – Blox Fruits
    Feito por NCMine
    Compatível com Delta Mobile
    
    CORREÇÕES v3:
    - Kill Aura não pega mais NPCs de missão
    - Personagem fica corretamente ao lado do mob (não mais embaixo)
    - Dano funcionando via RemoteEvent (método correto do Blox Fruits)
    - Auto Farm com detecção e loop corrigidos
]]

-- ========== CARREGAMENTO ==========
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== SERVIÇOS ==========
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local workspace        = game:GetService("Workspace")

-- ========== CONFIGURAÇÕES ==========
local Settings = {
    KillAura         = false,
    KillAuraRange    = 25,
    KillAuraDelay    = 0.15,

    RaidFarm         = false,
    BuddhaMode       = false,
    RaidRange        = 60,

    MobFarm          = false,
    SelectedIsland   = "Marinha",
    MobRange         = 80,
    MobDelay         = 0.15,
    TeleportOnStart  = true,

    ESPEnabled       = false,
    NoclipEnabled    = false,
    AutoCollect      = false,
}

-- ========== NOMES DE NPCS QUE NÃO DEVEM SER ATACADOS ==========
-- Quest givers, vendedores, mestres, etc.
local BLACKLIST_NAMES = {
    -- Quest givers / missão
    "Military", "Bartilo", "Monkey", "Yoshi", "Rob", "Caveman",
    "Wysper", "Thunder", "Cyborg", "Sea", "Burning", "Beautiful",
    "Mysterious", "Hungry", "Sick", "Yakuza", "Bandit", "Monkey",
    -- Vendedores e mestres
    "Sword Dealer", "Blox Fruit Dealer", "Blox Fruit Gacha",
    "Master", "Trainer", "Greybeard", "Arowe", "Rayleigh",
    "Shanks", "Don Swan", "Fajita", "Wysper", "Thunder God",
    "Mihawk", "Shank", "Bucky", "Longma", "Monstro",
    -- Genéricos de NPC de interação
    "NPC", "Crew", "Shopkeeper", "Dealer", "Elder",
    "Gacha", "Factory", "Prisoner",
}

-- Nomes PERMITIDOS para atacar (mobs reais do Blox Fruits)
-- O script vai checar se o mob tem "Humanoid" E não está na blacklist
local function IsBlacklisted(name)
    local lower = name:lower()
    for _, bl in ipairs(BLACKLIST_NAMES) do
        if lower:find(bl:lower()) then
            return true
        end
    end
    return false
end

-- ========== ILHAS ==========
local Islands = {
    { "Marinha",           Vector3.new(-790,  80, -1260) },
    { "Deserto",           Vector3.new(1020, 125,  1240) },
    { "Jungla",            Vector3.new(-1200, 50,   500) },
    { "Ilha do Céu",       Vector3.new(-5000, 300, -2000) },
    { "Ilha do Tesouro",   Vector3.new(2000,  50,  3000) },
    { "Ilha do Cogumelo",  Vector3.new(-800,  80,  1200) },
    { "Ilha do Cemitério", Vector3.new(-3000, 50,  4000) },
    { "Ilha da Neve",      Vector3.new(-4000, 100, -1000) },
    { "Ilha do Café",      Vector3.new(-2000, 50, -3000) },
    { "Ilha da Fábrica",   Vector3.new(0,     50, -4000) },
    { "Ilha do Trono",     Vector3.new(3000,  150, 2000) },
    { "Castelo",           Vector3.new(5000,  200, 5000) },
    { "Ilha das Almas",    Vector3.new(6000,  100, 6000) },
    { "Ilha do Dragão",    Vector3.new(7000,  150, 7000) },
    { "Zona Neutra",       Vector3.new(4000,  100, 4000) },
}

-- ========== UTILITÁRIOS ==========

local function GetChar()    return LocalPlayer.Character end
local function GetRoot()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function IsAlive()
    local h = GetHum()
    return h and h.Health > 0
end

local function TeleportTo(pos)
    local root = GetRoot()
    if root then
        -- +5 no Y para não entrar no chão
        root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        return true
    end
    return false
end

local function GetIslandCoord(name)
    for _, i in ipairs(Islands) do
        if i[1] == name then return i[2] end
    end
end

-- ========== DETECÇÃO DE MOBS (CORRIGIDA) ==========

local function IsEnemy(model)
    -- Deve ser um Model
    if not model:IsA("Model") then return false end
    -- Deve ter Humanoid com vida
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    -- Não pode ser o próprio jogador
    if model == GetChar() then return false end
    -- Não pode ser outro jogador
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return false end
    end
    -- Não pode estar na blacklist (NPCs de missão, vendedores, etc.)
    if IsBlacklisted(model.Name) then return false end
    -- Deve ter HumanoidRootPart para poder ser localizado
    if not model:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

local function IsBoss(model)
    local n = model.Name:lower()
    return n:find("boss") or n:find("buddha") or n:find("raid")
end

-- Retorna lista de inimigos próximos, ordenados por distância
local function GetEnemiesInRange(range, ignoreBoss)
    local root = GetRoot()
    if not root then return {} end

    local list = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if IsEnemy(v) then
            if ignoreBoss and IsBoss(v) then continue end
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist <= range then
                    table.insert(list, { model = v, hrp = hrp, dist = dist })
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- ========== ATAQUE (CORRIGIDO) ==========
-- Blox Fruits usa RemoteEvents para dano, mas também aceita Tool:Activate()
-- O método mais confiável é: ir até o mob + ativar a ferramenta via evento

local function GetEquippedTool()
    local c = GetChar()
    if not c then return nil end
    return c:FindFirstChildOfClass("Tool")
end

local function EquipBestWeapon()
    local c = GetChar()
    if not c then return end
    local hum = GetHum()
    if not hum then return end
    local bp = LocalPlayer.Backpack

    -- Prioridade: espadas e katanas
    local priority = {"sword", "katana", "blade", "sabre", "cutlass", "dual", "pole"}
    for _, keyword in ipairs(priority) do
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(keyword) then
                hum:EquipTool(item)
                return item
            end
        end
    end
    -- Fallback: qualquer ferramenta
    local first = bp:FindFirstChildOfClass("Tool")
    if first then hum:EquipTool(first) return first end
end

local function AttackEnemy(entry)
    if not entry then return end
    local mob    = entry.model
    local mobHRP = entry.hrp

    -- Verificar se ainda está vivo
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local root = GetRoot()
    if not root then return end

    -- ✅ CORREÇÃO: posicionar ATRÁS do mob, mesmo nível Y, não embaixo
    -- Usamos LookVector para ficar na frente do mob olhando para ele
    local mobCF  = mobHRP.CFrame
    -- Fica 4 studs atrás do mob (do ponto de vista do mob = na frente do player)
    local targetCF = mobCF * CFrame.new(0, 0, 4)
    -- Garante que o Y do player = Y do mob (não embaixo, não em cima)
    root.CFrame = CFrame.new(
        targetCF.X,
        mobHRP.Position.Y,   -- mesmo nível do mob
        targetCF.Z
    ) * CFrame.Angles(0, math.pi, 0) -- vira para olhar o mob

    -- ✅ CORREÇÃO: garantir que tem ferramenta equipada
    local tool = GetEquippedTool()
    if not tool then
        tool = EquipBestWeapon()
        if not tool then return end
        task.wait(0.1)
    end

    -- ✅ CORREÇÃO: método de ataque correto para Blox Fruits
    -- Tenta via Activate() primeiro (funciona na maioria das ferramentas)
    local ok, err = pcall(function()
        tool:Activate()
    end)

    -- Se Activate falhou, tenta via RemoteEvent (método alternativo)
    if not ok then
        local remote = tool:FindFirstChildOfClass("RemoteEvent")
            or tool:FindFirstChild("Handle") and tool.Handle:FindFirstChildOfClass("RemoteEvent")
        if remote then
            pcall(function() remote:FireServer() end)
        end
    end
end

-- ========== KILL AURA ==========

local KillAuraConn = nil

local function StartKillAura()
    if KillAuraConn then KillAuraConn:Disconnect() end

    KillAuraConn = RunService.Heartbeat:Connect(function()
        if not Settings.KillAura then
            KillAuraConn:Disconnect()
            KillAuraConn = nil
            return
        end
        if not IsAlive() then return end

        local enemies = GetEnemiesInRange(Settings.KillAuraRange, false)
        for _, entry in ipairs(enemies) do
            AttackEnemy(entry)
            task.wait(Settings.KillAuraDelay)
            if not Settings.KillAura then break end
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
        if IsEnemy(v) and IsBoss(v) then return v end
    end
end

local function RaidFarmLoop()
    while Settings.RaidFarm do
        if not IsAlive() then task.wait(3) continue end
        if not IsInRaid() then task.wait(1) continue end

        if Settings.BuddhaMode then
            local boss = GetRaidBoss()
            if boss then
                local root = GetRoot()
                local bossHRP = boss:FindFirstChild("HumanoidRootPart")
                if root and bossHRP then
                    -- ✅ Fica EM CIMA do boss (modo Buda = no topo)
                    root.CFrame = CFrame.new(
                        bossHRP.Position.X,
                        bossHRP.Position.Y + 8,  -- acima da cabeça
                        bossHRP.Position.Z
                    )
                end
            end
            -- Ataca mobs normais ao redor (ignora boss)
            local enemies = GetEnemiesInRange(Settings.RaidRange, true)
            for _, entry in ipairs(enemies) do
                AttackEnemy(entry)
                task.wait(0.1)
            end
        else
            local enemies = GetEnemiesInRange(Settings.RaidRange, false)
            for _, entry in ipairs(enemies) do
                AttackEnemy(entry)
                task.wait(0.1)
            end
        end

        task.wait(0.05)
    end
end

-- ========== AUTO MOB FARM ==========

local function MobFarmLoop()
    -- Teleporta para a ilha selecionada
    if Settings.TeleportOnStart then
        local coord = GetIslandCoord(Settings.SelectedIsland)
        if coord then
            TeleportTo(coord)
            Rayfield:Notify({
                Title = "🏝️ Mob Farm",
                Content = "Teleportado para: " .. Settings.SelectedIsland,
                Duration = 3
            })
            task.wait(2.5)
        end
    end

    while Settings.MobFarm do
        -- Se morreu, espera respawnar e volta para a ilha
        if not IsAlive() then
            task.wait(4)
            local coord = GetIslandCoord(Settings.SelectedIsland)
            if coord then
                TeleportTo(coord)
                task.wait(2)
            end
            continue
        end

        local enemies = GetEnemiesInRange(Settings.MobRange, false)

        if #enemies == 0 then
            -- Nenhum mob próximo: aguarda um ciclo
            task.wait(0.8)
        else
            -- Ataca cada mob encontrado
            for _, entry in ipairs(enemies) do
                if not Settings.MobFarm then break end
                if not IsAlive() then break end

                local hum = entry.model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    AttackEnemy(entry)
                    task.wait(Settings.MobDelay)
                end
            end
        end
    end
end

-- ========== ESP ==========

local ESPList = {}

local function ClearESP()
    for _, h in pairs(ESPList) do
        pcall(function() h:Destroy() end)
    end
    ESPList = {}
end

local ESPConn = nil
local function StartESP()
    if ESPConn then ESPConn:Disconnect() end
    ESPConn = RunService.Heartbeat:Connect(function()
        if not Settings.ESPEnabled then
            ClearESP()
            ESPConn:Disconnect()
            return
        end
        -- Atualiza a cada 2 segundos aprox
        task.wait(2)
        ClearESP()
        for _, v in ipairs(workspace:GetDescendants()) do
            if IsEnemy(v) then
                local ok, h = pcall(function()
                    local highlight = Instance.new("Highlight")
                    highlight.FillColor    = Color3.fromRGB(220, 50, 50)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.55
                    highlight.Parent = v
                    return highlight
                end)
                if ok then table.insert(ESPList, h) end
            end
        end
    end)
end

-- ========== NOCLIP ==========

local NoclipConn = nil
local function StartNoclip()
    if NoclipConn then NoclipConn:Disconnect() end
    NoclipConn = RunService.Stepped:Connect(function()
        if not Settings.NoclipEnabled then
            NoclipConn:Disconnect()
            NoclipConn = nil
            return
        end
        local c = GetChar()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
        end
    end)
end

-- ========== AUTO COLETAR FRUTAS ==========

local function AutoCollectLoop()
    while Settings.AutoCollect do
        local root = GetRoot()
        if root then
            for _, v in ipairs(workspace:GetDescendants()) do
                local name = v.Name:lower()
                if v:IsA("BasePart") and (name:find("fruit") or name:find("devil")) then
                    local dist = (v.Position - root.Position).Magnitude
                    if dist < 300 then
                        TeleportTo(v.Position)
                        task.wait(0.4)
                        local prompt = v:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then pcall(fireproximityprompt, prompt) end
                        task.wait(0.3)
                    end
                end
            end
        end
        task.wait(3)
    end
end

-- ========== INTERFACE ==========

local Window = Rayfield:CreateWindow({
    Name = "NCHub v3.0 – Blox Fruits",
    LoadingTitle = "NCHub",
    LoadingSubtitle = "by NCMine  •  v3.0",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NCHub",
        FileName = "Config"
    },
    KeySystem = false
})

-- ===== ABA: KILL AURA =====
local AuraTab = Window:CreateTab("⚡ Kill Aura", 4483362458)

AuraTab:CreateSection("Ativar")

AuraTab:CreateToggle({
    Name = "⚡ Kill Aura",
    CurrentValue = false,
    Flag = "KillAura",
    Callback = function(v)
        Settings.KillAura = v
        if v then
            EquipBestWeapon()
            StartKillAura()
            Rayfield:Notify({ Title = "Kill Aura ✅", Content = "Atacando mobs próximos. NPCs de missão ignorados.", Duration = 3 })
        else
            Rayfield:Notify({ Title = "Kill Aura ❌", Content = "Desativado.", Duration = 2 })
        end
    end
})

AuraTab:CreateSection("Ajustes")

AuraTab:CreateSlider({
    Name = "📏 Alcance",
    Range = {10, 120},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = Settings.KillAuraRange,
    Flag = "KillAuraRange",
    Callback = function(v) Settings.KillAuraRange = v end
})

AuraTab:CreateSlider({
    Name = "⏱️ Velocidade de ataque",
    Range = {0.05, 1.0},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Settings.KillAuraDelay,
    Flag = "KillAuraDelay",
    Callback = function(v) Settings.KillAuraDelay = v end
})

AuraTab:CreateSection("Ferramentas")

AuraTab:CreateButton({
    Name = "🗡️ Equipar melhor arma",
    Callback = function()
        local t = EquipBestWeapon()
        Rayfield:Notify({
            Title = "Equip",
            Content = t and ("Equipado: " .. t.Name) or "Nenhuma arma encontrada no inventário.",
            Duration = 3
        })
    end
})

-- ===== ABA: RAID FARM =====
local RaidTab = Window:CreateTab("⚔️ Raid Farm", 4483362458)

RaidTab:CreateSection("Ativar")

RaidTab:CreateToggle({
    Name = "⚔️ Auto Raid Farm",
    CurrentValue = false,
    Flag = "RaidFarm",
    Callback = function(v)
        Settings.RaidFarm = v
        if v then
            task.spawn(RaidFarmLoop)
            Rayfield:Notify({ Title = "Raid Farm ✅", Content = "Esperando você entrar em uma Raid...", Duration = 3 })
        else
            Rayfield:Notify({ Title = "Raid Farm ❌", Content = "Desativado.", Duration = 2 })
        end
    end
})

RaidTab:CreateToggle({
    Name = "🪷 Modo Buda",
    CurrentValue = false,
    Flag = "BuddhaMode",
    Callback = function(v)
        Settings.BuddhaMode = v
        Rayfield:Notify({
            Title = "Modo Buda",
            Content = v and "Ficará em cima do boss." or "Desativado.",
            Duration = 2
        })
    end
})

RaidTab:CreateSection("Ajustes")

RaidTab:CreateSlider({
    Name = "📏 Alcance na Raid",
    Range = {30, 150},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = Settings.RaidRange,
    Flag = "RaidRange",
    Callback = function(v) Settings.RaidRange = v end
})

RaidTab:CreateSection("Ajuda")

RaidTab:CreateButton({
    Name = "ℹ️ Como funciona",
    Callback = function()
        Rayfield:Notify({
            Title = "Raid Farm",
            Content = "1. Ative o toggle.\n2. Vá até a ilha de Raid.\n3. Entre na Raid normalmente.\n4. O script detecta e ataca sozinho.\n5. Modo Buda = fica no topo do boss.",
            Duration = 8
        })
    end
})

-- ===== ABA: MOB FARM =====
local MobTab = Window:CreateTab("🏝️ Mob Farm", 4483362458)

MobTab:CreateSection("Ilha alvo")

local islandNames = {}
for _, i in ipairs(Islands) do table.insert(islandNames, i[1]) end

MobTab:CreateDropdown({
    Name = "🏝️ Selecionar Ilha",
    Options = islandNames,
    CurrentOption = Settings.SelectedIsland,
    Flag = "SelectedIsland",
    Callback = function(opt)
        Settings.SelectedIsland = opt
        Rayfield:Notify({ Title = "Ilha", Content = "Selecionada: " .. opt, Duration = 2 })
    end
})

MobTab:CreateButton({
    Name = "📍 Teleportar agora",
    Callback = function()
        local coord = GetIslandCoord(Settings.SelectedIsland)
        if coord then
            TeleportTo(coord)
            Rayfield:Notify({ Title = "Teleport ✅", Content = Settings.SelectedIsland, Duration = 2 })
        end
    end
})

MobTab:CreateSection("Farm")

MobTab:CreateToggle({
    Name = "🤖 Auto Mob Farm",
    CurrentValue = false,
    Flag = "MobFarm",
    Callback = function(v)
        Settings.MobFarm = v
        if v then
            task.spawn(MobFarmLoop)
            Rayfield:Notify({ Title = "Mob Farm ✅", Content = "Farmando: " .. Settings.SelectedIsland, Duration = 3 })
        else
            Rayfield:Notify({ Title = "Mob Farm ❌", Content = "Desativado.", Duration = 2 })
        end
    end
})

MobTab:CreateToggle({
    Name = "🚀 Teleportar ao iniciar",
    CurrentValue = true,
    Flag = "TeleportOnStart",
    Callback = function(v) Settings.TeleportOnStart = v end
})

MobTab:CreateSection("Ajustes")

MobTab:CreateSlider({
    Name = "📏 Alcance de detecção",
    Range = {30, 200},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = Settings.MobRange,
    Flag = "MobRange",
    Callback = function(v) Settings.MobRange = v end
})

MobTab:CreateSlider({
    Name = "⏱️ Delay entre ataques",
    Range = {0.05, 1.0},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Settings.MobDelay,
    Flag = "MobDelay",
    Callback = function(v) Settings.MobDelay = v end
})

-- ===== ABA: UTILIDADES =====
local UtilTab = Window:CreateTab("🔧 Utilidades", 4483362458)

UtilTab:CreateSection("Visual")

UtilTab:CreateToggle({
    Name = "👁️ ESP – Destacar Mobs",
    CurrentValue = false,
    Flag = "ESPEnabled",
    Callback = function(v)
        Settings.ESPEnabled = v
        if v then StartESP() end
        Rayfield:Notify({ Title = "ESP", Content = v and "Mobs em vermelho ativado." or "Desativado.", Duration = 2 })
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
        Rayfield:Notify({ Title = "Noclip", Content = v and "Atravessa paredes." or "Desativado.", Duration = 2 })
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
        Rayfield:Notify({ Title = "Auto Collect", Content = v and "Coletando frutas!" or "Desativado.", Duration = 2 })
    end
})

UtilTab:CreateSection("Ações Rápidas")

UtilTab:CreateButton({
    Name = "💀 Respawn rápido",
    Callback = function()
        local h = GetHum()
        if h then h.Health = 0 end
        Rayfield:Notify({ Title = "Respawn", Content = "Morrendo para respawnar...", Duration = 2 })
    end
})

UtilTab:CreateButton({
    Name = "📊 Ver status",
    Callback = function()
        Rayfield:Notify({
            Title = "Status Atual",
            Content = string.format(
                "Kill Aura: %s\nRaid Farm: %s\nMob Farm: %s\nESP: %s\nNoclip: %s",
                Settings.KillAura    and "✅" or "❌",
                Settings.RaidFarm   and "✅" or "❌",
                Settings.MobFarm    and "✅" or "❌",
                Settings.ESPEnabled and "✅" or "❌",
                Settings.NoclipEnabled and "✅" or "❌"
            ),
            Duration = 6
        })
    end
})

-- ========== INÍCIO ==========
task.wait(1)
Rayfield:Notify({
    Title = "✅ NCHub v3.0 carregado!",
    Content = "Kill Aura e Mob Farm corrigidos. Bom upar! 💪",
    Duration = 5
})
