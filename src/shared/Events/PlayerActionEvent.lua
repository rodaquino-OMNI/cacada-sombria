--!strict
--[[
  PlayerActionEvent.lua
  RemoteEvent compartilhado para comunicação Cliente → Servidor.
  
  O cliente envia ações do jogador (mover, correr, agachar, interagir)
  e o servidor valida e aplica.

  ATENÇÃO: Este módulo NÃO cria o RemoteEvent — ele apenas fornece
  o caminho/nome padronizado. O RemoteEvent em si é criado pelo
  GameManager no servidor e replicado para os clientes via
  ReplicatedStorage.

  Contexto: Shared (ReplicatedStorage)
]]

-- Nome padronizado do RemoteEvent — use este nome ao criar o objeto no Roblox
local PLAYER_ACTION_EVENT_NAME = "PlayerActionEvent"

-- ==========================================
-- TIPOS DE AÇÃO (Action Types)
-- ==========================================
-- Estes são os valores aceitos para o parâmetro "action"
-- enviado do cliente para o servidor

local PlayerActionEvent = {}

-- Ações de movimento
PlayerActionEvent.ACTIONS = {
	-- Movimento básico (enviado a cada frame de input)
	MOVE = "Move",               -- params: direction (Vector3)

	-- Sprint / Corrida
	SPRINT_START = "SprintStart", -- inicia corrida
	SPRINT_STOP = "SprintStop",   -- para corrida

	-- Agachar / Furtividade
	CROUCH_TOGGLE = "CrouchToggle", -- alterna estado de agachado

	-- Interação com objetos do mundo
	INTERACT = "Interact",         -- interage com objeto próximo (gerador, jaula, esconderijo)

	-- Esconderijo
	ENTER_HIDING = "EnterHiding",  -- entra em um esconderijo
	EXIT_HIDING = "ExitHiding",    -- sai de um esconderijo

	-- Habilidades (serão implementadas nos épicos E2 e E3)
	ABILITY_1 = "Ability1",        -- tecla Q
	ABILITY_2 = "Ability2",        -- tecla E (ou botão direito)
	ABILITY_3 = "Ability3",        -- tecla R (ou F)

	-- Caçador específico
	KILLER_M1 = "KillerM1",        -- ataque básico do Caçador (clique esquerdo)
}

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar o RemoteEvent
-- ==========================================
-- Deve ser chamada pelo servidor (GameManager) durante a inicialização.
-- Coloca o RemoteEvent dentro da pasta Events em ReplicatedStorage.

function PlayerActionEvent.createEvent(parent: Instance): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = PLAYER_ACTION_EVENT_NAME
	event.Parent = parent
	print("[CacadaSombria] PlayerActionEvent criado em ReplicatedStorage.Events")
	return event
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Enviar ação (cliente)
-- ==========================================

-- Envia uma ação do cliente para o servidor para validação
-- @param remoteEvent — referência ao RemoteEvent (obtido via ReplicatedStorage)
-- @param action — string, use PlayerActionEvent.ACTIONS
-- @param ... — parâmetros adicionais da ação
function PlayerActionEvent.fireAction(remoteEvent: RemoteEvent, action: string, ...: any)
	remoteEvent:FireServer(action, ...)
end

return PlayerActionEvent
