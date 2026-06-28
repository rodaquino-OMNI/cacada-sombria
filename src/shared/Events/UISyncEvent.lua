--!strict
--[[
  UISyncEvent.lua
  Definições para RemoteEvent de sincronização de HUD (Servidor → Clientes).

  O servidor envia atualizações de interface para os clientes:
  - Atualizações de cooldown de habilidades
  - Barra de Fúria do Caçador
  - Estado de Rage ativo
  - Efeitos visuais (blur de Grito, indicadores)
  - Progresso de geradores, skill checks, portão (E5)

  ATENÇÃO: Este módulo define as constantes e funções auxiliares.
  O RemoteEvent em si é criado pelo GameManager.

  Contexto: Shared (ReplicatedStorage)
]]

local UI_SYNC_EVENT_NAME = "UISyncEvent"

local UISyncEvent = {}

-- ==========================================
-- TIPOS DE MENSAGEM DE SINCRONIZAÇÃO DE UI
-- ==========================================

UISyncEvent.MESSAGES = {
	-- Cooldowns de habilidades
	COOLDOWN_START = "CooldownStart",       -- params: abilityName (string), totalSeconds (number)
	COOLDOWN_END = "CooldownEnd",           -- params: abilityName (string)

	-- Barra de Fúria (Caçador)
	FURY_UPDATE = "FuryUpdate",             -- params: currentFury (number), maxFury (number)

	-- Estado de Rage
	RAGE_START = "RageStart",               -- params: duration (number)
	RAGE_END = "RageEnd",                   -- sem parâmetros

	-- Efeitos do Grito (enviado para Sobreviventes afetados)
	GRITO_SLOW_START = "GritolowStart",    -- params: slowPercent (number), duration (number)
	GRITO_REVEAL_START = "GritoRevealStart",-- params: duration (number)
	GRITO_REVEAL_END = "GritoRevealEnd",    -- sem parâmetros

	-- Indicador de Sobreviventes (contagem)
	SURVIVOR_COUNT = "SurvivorCount",       -- params: alive (number), inCage (number), escaped (number)

	-- ==========================================
	-- GERADORES — Épico E5
	-- ==========================================

	-- Progresso de reparo de um gerador específico (HUD local)
	GENERATOR_PROGRESS = "GeneratorProgress",     -- params: generatorId, progress (0-100)

	-- Início do reparo (mostrar barra de progresso)
	REPAIR_START = "RepairStart",                 -- params: generatorId, totalTime

	-- Reparo cancelado ou interrompido
	REPAIR_STOP = "RepairStop",                   -- params: generatorId, reason

	-- Skill check — início (mostrar QTE visual)
	SKILL_CHECK_START = "SkillCheckStart",        -- params: generatorId, duration, difficulty

	-- Skill check — resultado do acerto
	SKILL_CHECK_RESULT = "SkillCheckResult",      -- params: generatorId, isHit (boolean), progressChange

	-- Skill check — término (encerrar QTE visual)
	SKILL_CHECK_END = "SkillCheckEnd",            -- params: generatorId

	-- ==========================================
	-- PORTÃO DE FUGA — Épico E5
	-- ==========================================

	-- Progresso de abertura do portão
	GATE_PROGRESS = "GateProgress",               -- params: gateId, progress (0-100)

	-- ==========================================
	-- ALERTAS SONOROS — Épico E5
	-- ==========================================

	-- Alerta de gerador (skill check falhou — som alto global)
	GENERATOR_ALERT = "GeneratorAlert",           -- params: generatorPosition (Vector3)

	-- Som de zumbido do gerador (para Sobreviventes próximos)
	GENERATOR_BUZZ = "GeneratorBuzz",             -- params: generatorId, isActive (boolean)
}

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar o RemoteEvent
-- ==========================================

function UISyncEvent.createEvent(parent: Instance): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = UI_SYNC_EVENT_NAME
	event.Parent = parent
	print("[CacadaSombria] UISyncEvent criado em ReplicatedStorage.Events")
	return event
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Enviar para um cliente específico
-- ==========================================

function UISyncEvent.sendToClient(
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

function UISyncEvent.sendToAll(
	event: RemoteEvent,
	messageType: string,
	...: any
)
	event:FireAllClients(messageType, ...)
end

return UISyncEvent
