--!strict
--[[
  UISyncEvent.lua
  Definições para RemoteEvent de sincronização de HUD (Servidor → Clientes).

  O servidor envia atualizações de interface para os clientes:
  - Atualizações de cooldown de habilidades
  - Barra de Fúria do Caçador
  - Estado de Rage ativo
  - Efeitos visuais (blur de Grito, indicadores)

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
