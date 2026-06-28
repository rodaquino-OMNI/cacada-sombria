--[[
  GameManager.server.lua
  Script principal do servidor — gerencia o game loop
  Roda em ServerScriptService
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConstants = require(ReplicatedStorage.GameConstants)

-- ==========================================
-- ESTADO DA PARTIDA
-- ==========================================
local MatchState = {
  Waiting = "Waiting",       -- Aguardando jogadores
  Preparing = "Preparing",   -- Spawn, preparação
  Hunting = "Hunting",       -- Caça ativa
  Ending = "Ending",         -- Resultado
}

local currentState = MatchState.Waiting

-- ==========================================
-- FUNÇÕES PRINCIPAIS (stubs — serão implementadas pelo Game Dev)
-- ==========================================
local function startMatch()
  print("[CacadaSombria] Partida iniciada!")
  currentState = MatchState.Preparing
  -- TODO: Selecionar Killer aleatório dentre jogadores
  -- TODO: Spawnar Sobreviventes espalhados
  -- TODO: Spawnar Killer em posição fixa
  -- TODO: Inicializar geradores
end

local function endMatch(winner)
  print("[CacadaSombria] Partida encerrada! Vencedor: " .. winner)
  currentState = MatchState.Ending
  -- TODO: Anunciar resultado
  -- TODO: Resetar mapa
end

-- ==========================================
-- EVENTOS DE JOGADOR
-- ==========================================
Players.PlayerAdded:Connect(function(player)
  print("[CacadaSombria] Jogador entrou: " .. player.Name)
  -- TODO: Adicionar ao lobby
end)

Players.PlayerRemoving:Connect(function(player)
  print("[CacadaSombria] Jogador saiu: " .. player.Name)
  -- TODO: Remover do lobby, lidar com DC mid-match
end)

print("[CacadaSombria] GameManager carregado.")
