--!strict
--[[
  GameStateEvent.lua
  Definições para RemoteEvent de estado do jogo (Servidor → Clientes).
  
  O servidor envia atualizações de estado para os clientes:
  - Papel do jogador (Killer/Survivor)
  - Atribuição de classe
  - Estado da partida
  - HP, stamina, fury

  ATENÇÃO: Este módulo define as constantes e funções auxiliares.
  O RemoteEvent em si é criado pelo GameManager.

  Contexto: Shared (ReplicatedStorage)
]]

local GAME_STATE_EVENT_NAME = "GameStateEvent"

local GameStateEvent = {}

-- ==========================================
-- TIPOS DE MENSAGEM DE ESTADO
-- ==========================================

GameStateEvent.MESSAGES = {
	-- Atribuição de papel ao jogador (enviado a cada jogador individualmente)
	ROLE_ASSIGN = "RoleAssign",         -- params: role ("Killer" | "Survivor"), className
	MATCH_STATE = "MatchState",         -- params: state ("Waiting" | "Hunting" | "Ending")
	PREPARE_COUNTDOWN = "PrepareCountdown", -- params: secondsRemaining

	-- Estado do jogador (HP, stamina)
	HP_UPDATE = "HPUpdate",             -- params: currentHP, maxHP
	STAMINA_UPDATE = "StaminaUpdate",   -- params: currentStamina, maxStamina
	FURY_UPDATE = "FuryUpdate",         -- params: currentFury, maxFury (para Caçador)

	-- Estado de movimento
	SPRINT_STATE = "SprintState",       -- params: isSprinting (boolean)
	CROUCH_STATE = "CrouchState",       -- params: isCrouching (boolean)

	-- Geradores e objetivos (Épico E5)
	GENERATOR_UPDATE = "GeneratorUpdate", -- params: repaired, total

	-- Resultado da partida
	GAME_OVER = "GameOver",             -- params: winner ("Killer" | "Survivors")
}

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar o RemoteEvent
-- ==========================================

function GameStateEvent.createEvent(parent: Instance): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = GAME_STATE_EVENT_NAME
	event.Parent = parent
	print("[CacadaSombria] GameStateEvent criado em ReplicatedStorage.Events")
	return event
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Enviar para um cliente específico
-- ==========================================

function GameStateEvent.sendToClient(
	event: RemoteEvent,
	player: Player,
	messageType: string,
	...: any
)
	event:FireClient(player, messageType, ...)
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Enviar para todos os clientes
-- ==========================================

function GameStateEvent.sendToAll(
	event: RemoteEvent,
	messageType: string,
	...: any
)
	event:FireAllClients(messageType, ...)
end

return GameStateEvent
