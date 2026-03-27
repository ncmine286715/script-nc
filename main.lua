--[[
    NCHub Minimalista - Blox Fruits
    Foco: Leveza, Estabilidade e Funcionalidade
]]

local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexsoftware/Orion/main/source')))()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configurações Ativas
local _G = {
    KillAura = false,
    AutoFruit = false,
    AutoRaid = false,
    RaidType = "Flame"
}

-- ==========================================
-- 🛡️ SISTEMA ANTI-AFK (NÃO DEIXA O JOGO FECHAR)
-- ==========================================
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

-- ==========================================
-- ⚔️ FUNÇÕES DE COMBATE E COLETA
-- ==========================================

-- Equipa a arma melee automaticamente
local function EquipWeapon()
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool.ToolTip == "Melee" or tool.ToolTip == "Sword" then
            tool.Parent = LocalPlayer.Character
            break
        end
    end
end

-- Ataca o alvo de forma segura
local function Attack(target)
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and target:FindFirstChild("HumanoidRootPart") then
            -- Fica acima do inimigo para não apanhar
            char.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 7, 0)
            char.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0) -- Evita ser jogado longe
            
            EquipWeapon()
            game:GetService("VirtualUser"):ClickButton1(Vector2.new(0, 0))
        end
    end)
end

-- ==========================================
-- 🔄 LOOPS PRINCIPAIS
-- ==========================================

-- Loop Kill Aura
task.spawn(function()
    while task.wait(0.1) do
        if _G.KillAura then
            pcall(function()
                for _, enemy in pairs(workspace.Enemies:GetChildren()) do
                    if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                        Attack(enemy)
                        break -- Foca em um por vez
                    end
                end
            end)
        end
    end
end)

-- Loop Coletar e Guardar Fruta
task.spawn(function()
    while task.wait(1) do
        if _G.AutoFruit then
            pcall(function()
                local char = LocalPlayer.Character
                -- 1. Coleta a fruta no chão
                for _, item in pairs(workspace:GetChildren()) do
                    if item:IsA("Tool") and item.Name:find("Fruit") then
                        char.HumanoidRootPart.CFrame = item.Handle.CFrame
                        task.wait(0.5)
                    end
                end
                
                -- 2. Guarda a fruta no inventário (Armazém)
                for _, tool in pairs(char:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name:find("Fruit") then
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", tool:GetAttribute("OriginalName") or tool.Name)
                    end
                end
                for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name:find("Fruit") then
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", tool:GetAttribute("OriginalName") or tool.Name)
                    end
                end
            end)
        end
    end
end)

-- Loop Auto Raid
task.spawn(function()
    while task.wait(1) do
        if _G.AutoRaid then
            pcall(function()
                -- Tenta comprar o chip e iniciar (precisa de fragmentos/dinheiro)
                ReplicatedStorage.Remotes.CommF_:InvokeServer("Raids", "Start", _G.RaidType)
                
                -- Se estiver dentro da raid, mata os bichos
                if workspace:FindFirstChild("Enemies") then
                    for _, enemy in pairs(workspace.Enemies:GetChildren()) do
                        if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            Attack(enemy)
                        end
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- 🎨 INTERFACE MINIMALISTA (ORION)
-- ==========================================

local Window = OrionLib:MakeWindow({
    Name = "NCHub Lite", 
    HidePremium = false, 
    SaveConfig = false, 
    IntroText = "Carregando NCHub..."
})

local MainTab = Window:MakeTab({
    Name = "Principal",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MainTab:AddToggle({
    Name = "⚔️ Kill Aura (Bater Automático)",
    Default = false,
    Callback = function(Value)
        _G.KillAura = Value
    end
})

MainTab:AddToggle({
    Name = "🍎 Coletar & Guardar Frutas",
    Default = false,
    Callback = function(Value)
        _G.AutoFruit = Value
    end
})

MainTab:AddToggle({
    Name = "⚡ Auto Raid (Zerar)",
    Default = false,
    Callback = function(Value)
        _G.AutoRaid = Value
    end
})

MainTab:AddDropdown({
    Name = "🔥 Tipo de Raid",
    Default = "Flame",
    Options = {"Flame", "Ice", "Sand", "Dark", "Light", "Magma", "Water"},
    Callback = function(Value)
        _G.RaidType = Value
    end
})

MainTab:AddLabel("✔️ Anti-AFK ativado permanentemente.")

OrionLib:Init()
