--!strict
--[[
  GameStateEvent.lua
  Definições para RemoteEvent de estado do jogo (Servidor → Clientes).
  
  O servidor envia atualizações de estado para os clientes:
  - Papel do jogador (Killer/Survivor)
  - Atribuição de classe
  - Estado da partida
  - HP, stamina, fury
  - Geradores, portão, condições de vitória (E5)

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
	GENERATOR_REPAIRED = "GeneratorRepaired", -- params: generatorId, totalRepaired, totalNeeded
	GENERATOR_ALL_REPAIRED = "GeneratorAllRepaired", -- sem parâmetros — todos os 5 consertados

	-- Portão de fuga (Épico E5)
	GATE_ACTIVATED = "GateActivated",     -- params: gateId, gatePosition
	GATE_OPENED = "GateOpened",           -- params: gateId
	GATE_CLOSED = "GateClosed",           -- params: gateId (colapso fecha permanentemente)

	-- Colapso (Épico E5)
	COLLAPSE_STARTED = "CollapseStarted", -- params: secondsRemaining

	-- Fuga / Captura (Épico E5)
	ESCAPED = "Escaped",                  -- params: playerName (Sobrevivente escapou)

	-- Resultado da partida
	GAME_OVER = "GameOver",             -- params: winner ("Killer" | "Survivors")

	-- Efeitos de controle (Épico E3 — Sobreviventes)
	SILENCED = "Silenced",              -- params: duration (Caçador silenciado)
	SLOWED = "Slowed",                  -- params: slowPercent, duration
	STUNNED = "Stunned",                -- params: duration
	KILLER_REVEALED = "KillerRevealed", -- params: killerPlayer, duration

	-- Captura — Épico E6
	DOWN_STATE = "DownState",               -- params: isDowned (boolean), bleedOutTime (number)
	CARRIED_STATE = "CarriedState",         -- params: isCarried (boolean), carriedBy (string?)
	CAGE_STATE = "CageState",               -- params: isInCage (boolean), cageId (number?), eliminationTime (number?)
	CAGE_SURVIVOR_ELIMINATED = "CageSurvivorEliminated", -- params: playerName (Sobrevivente eliminado na jaula)
	RESCUED = "Rescued",                    -- params: rescuedPlayerName, rescuerPlayerName
	WIGGLE_BREAK = "WiggleBreak",           -- params: survivorName (Sobrevivente se libertou do carregamento)

	-- Lobby e Seleção de Personagem (Épico E7)
	LOBBY_UPDATE = "LobbyUpdate",       -- params: lobbyData (tabela serializável)
	CHARACTER_SELECT = "CharacterSelect", -- params: availableClasses (tabela)
	CHARACTER_SELECTED = "CharacterSelected", -- params: playerName, className
	HOST_ASSIGNED = "HostAssigned",     -- params: isHost (boolean)
	SELECT_START = "SelectStart",       -- inicia tela de seleção de personagem
	SELECT_TIMER = "SelectTimer",       -- params: secondsRemaining
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
