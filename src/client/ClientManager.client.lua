--[[
  ClientManager.client.lua
  Script do cliente — HUD, input, câmera
  Roda em StarterPlayerScripts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GameConstants = require(ReplicatedStorage.GameConstants)

-- ==========================================
-- ESTADO DO CLIENTE
-- ==========================================
local localRole = nil  -- "Killer" ou "Survivor"
local isAlive = true

-- ==========================================
-- HUD (stubs)
-- ==========================================
local function createHUD()
  print("[CacadaSombria] Criando HUD...")
  -- TODO: Criar ScreenGui com:
  -- - Barra de HP
  -- - Indicador de stamina
  -- - Ícones de habilidade com cooldown
  -- - Indicador de geradores restantes
  -- - Mini-mapa (se Sobrevivente)
end

-- ==========================================
-- INPUT
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  -- TODO: Mapear teclas para habilidades
  -- M1 = clique esquerdo
  -- Q/E/R = habilidades 1/2/3
end)

print("[CacadaSombria] ClientManager carregado para: " .. player.Name)
