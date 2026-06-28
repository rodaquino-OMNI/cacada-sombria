--!strict
--[[
  GeneratorEvents.lua
  Handlers de eventos para interação com geradores e portão no servidor.

  Responsável por:
  - Receber ações de Interact via PlayerActionEvent
  - Roteamento: Interact → gerador (reparo/skill check) ou portão (alavanca/fuga)
  - Validações de segurança server-side
  - Rate limiting básico anti-spam

  Toda ação passa por validação aqui antes de chegar aos serviços.
  Trabalha em conjunto com GeneratorService e ObjectiveService.

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- ==========================================
-- CONSTANTES
-- ==========================================

-- Intervalo mínimo entre ações do mesmo jogador (anti-spam)
local RATE_LIMIT = 0.15  -- 150ms entre interações

-- ==========================================
-- MÓDULO GENERATOREVENTS
-- ==========================================
local GeneratorEvents = {}

-- ==========================================
-- TIPOS DE AÇÃO ESPECÍFICOS
-- ==========================================

-- Ações adicionais que expandem PlayerActionEvent
GeneratorEvents.ACTIONS = {
	GENERATOR_REPAIR_START = "GeneratorRepairStart",   -- inicia reparo de gerador
	GENERATOR_SKILL_CHECK = "GeneratorSkillCheck",     -- acerto de skill check (pressionou E durante QTE)
	GATE_LEVER_ACTIVATE = "GateLeverActivate",         -- ativa alavanca do portão
	GATE_ESCAPE = "GateEscape",                        -- Sobrevivente escapou pelo portão
}

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Timestamps da última ação por jogador (rate limiting)
local _lastActionTime: {[number]: number} = {}

-- Referências aos serviços (setadas durante Init)
local _generatorService: any = nil
local _objectiveService: any = nil
local _matchService: any = nil

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init
-- @param playerActionEvent — RemoteEvent de ações do jogador
-- @param generatorService — Referência ao GeneratorService
-- @param objectiveService — Referência ao ObjectiveService
-- @param matchService — Referência ao MatchService (para validações)
function GeneratorEvents.Init(
	playerActionEvent: RemoteEvent,
	generatorService: any,
	objectiveService: any,
	matchService: any
)
	_generatorService = generatorService
	_objectiveService = objectiveService
	_matchService = matchService

	-- Registra o handler central de interações
	playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
		GeneratorEvents:_handleInteraction(player, action, ...)
	end)

	print("[CacadaSombria] GeneratorEvents inicializado.")
end

-- ==========================================
-- HANDLER CENTRAL DE INTERAÇÕES
-- ==========================================

-- Processa ações de interação com geradores e portões
-- Aplica rate limiting e validações antes de encaminhar
function GeneratorEvents:_handleInteraction(player: Player, action: string, ...: any)
	-- Rate limiting: evita spam de ações
	local now = os.clock()
	local lastTime = _lastActionTime[player.UserId] or 0
	if now - lastTime < RATE_LIMIT then
		return -- Descarta silenciosamente
	end
	_lastActionTime[player.UserId] = now

	-- ============================
	-- ROTEAMENTO POR TIPO DE AÇÃO
	-- ============================

	if action == "Interact" then
		-- Interação genérica — o servidor decide o que fazer baseado no contexto
		local target: Instance? = ...
		GeneratorEvents:_handleInteract(player, target)

	elseif action == GeneratorEvents.ACTIONS.GENERATOR_SKILL_CHECK then
		-- Skill check: jogador pressionou E durante o QTE
		local generatorId: number = ...
		GeneratorEvents:_handleSkillCheck(player, generatorId)

	elseif action == GeneratorEvents.ACTIONS.GATE_LEVER_ACTIVATE then
		-- Ativar alavanca do portão
		local gateId: number = ...
		GeneratorEvents:_handleGateLever(player, gateId)

	elseif action == GeneratorEvents.ACTIONS.GATE_ESCAPE then
		-- Escapar pelo portão
		local gateId: number = ...
		GeneratorEvents:_handleGateEscape(player, gateId)

	else
		-- Ações não relacionadas a geradores/portão — ignoramos silenciosamente
		-- (outras ações são tratadas por MatchService, KillerEvents, SurvivorEvents)
	end
end

-- ==========================================
-- HANDLER DE INTERAÇÃO GENÉRICA
-- ==========================================

-- Lida com a ação Interact (tecla E) — servidor decide o contexto
-- O servidor verifica o que está próximo do jogador e roteia adequadamente
function GeneratorEvents:_handleInteract(player: Player, target: Instance?)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	if not state.isAlive then return end

	-- Apenas Sobreviventes podem interagir com geradores e portões
	if state.role ~= "Survivor" then return end
	if state.isInCage then return end

	-- Se o jogador está atualmente reparando um gerador...
	-- Verifica se há um skill check ativo para este jogador
	for i = 1, 7 do
		if _generatorService:isBeingRepaired(i) then
			-- Tenta processar como skill check
			_generatorService:processSkillCheckHit(player, i)
			return
		end
	end

	-- Se não está reparando, tenta encontrar um gerador ou portão próximo
	-- O cliente pode enviar a referência do objeto (target) ou o servidor busca
	if target then
		local targetName = target.Name or ""

		-- Verifica se o alvo é um gerador (nome contém "Generator" ou "Gerador")
		if string.find(string.lower(targetName), "generator") or string.find(string.lower(targetName), "gerador") then
			-- Tenta extrair o ID do gerador do nome
			local genId = GeneratorEvents:_extractIdFromName(targetName)
			if genId then
				-- Se o gerador já está sendo reparado por este jogador, é um skill check
				if _generatorService:isBeingRepaired(genId) then
					_generatorService:processSkillCheckHit(player, genId)
				else
					-- Inicia reparo
					_generatorService:startRepair(player, genId)
				end
				return
			end
		end

		-- Verifica se o alvo é um portão (nome contém "Gate" ou "Portao")
		if string.find(string.lower(targetName), "gate") or string.find(string.lower(targetName), "portao") then
			local gateId = GeneratorEvents:_extractIdFromName(targetName)
			if gateId then
				-- Verifica se o portão está destrancado e tenta ativar a alavanca
				local gateState = _objectiveService:getGateState(gateId)
				if gateState == "Unlocked" then
					_objectiveService:activateGateLever(player, gateId)
				elseif gateState == "Opened" then
					-- Portão aberto → tentar escapar
					_objectiveService:tryEscape(player, gateId)
				end
				return
			end
		end
	end

	-- Se chegou aqui, o jogador pressionou E sem um alvo específico
	-- Busca geradores próximos para iniciar reparo
	GeneratorEvents:_tryNearbyGenerator(player) or GeneratorEvents:_tryNearbyGate(player)
end

-- ==========================================
-- BUSCA POR PROXIMIDADE
-- ==========================================

-- Tenta encontrar um gerador próximo para iniciar reparo
function GeneratorEvents:_tryNearbyGenerator(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state or not state.character then return false end

	local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	-- Verifica todos os geradores ativos e não completados
	for i = 1, 7 do
		local pos = _generatorService:getGeneratorPosition(i)
		if pos then
			local dist = (rootPart.Position - pos).Magnitude
			if dist <= 6 then -- INTERACT_RANGE
				-- Se já está sendo reparado por este jogador → skill check
				if _generatorService:isBeingRepaired(i) then
					_generatorService:processSkillCheckHit(player, i)
				else
					_generatorService:startRepair(player, i)
				end
				return true
			end
		end
	end

	return false
end

-- Tenta encontrar um portão próximo para interagir
function GeneratorEvents:_tryNearbyGate(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state or not state.character then return false end

	local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	for i = 1, 2 do
		local pos = _objectiveService:getGatePosition(i)
		if pos then
			local dist = (rootPart.Position - pos).Magnitude
			if dist <= 6 then -- INTERACT_RANGE
				local gateState = _objectiveService:getGateState(i)
				if gateState == "Unlocked" then
					_objectiveService:activateGateLever(player, i)
				elseif gateState == "Opened" then
					_objectiveService:tryEscape(player, i)
				end
				return true
			end
		end
	end

	return false
end

-- ==========================================
-- HANDLERS ESPECÍFICOS
-- ==========================================

-- Skill check: jogador pressionou E durante o QTE
function GeneratorEvents:_handleSkillCheck(player: Player, generatorId: number)
	-- Validação básica
	local state = _matchService:getPlayerState(player)
	if not state then return end
	if not state.isAlive then return end
	if state.role ~= "Survivor" then return end
	if state.isInCage then return end

	_generatorService:processSkillCheckHit(player, generatorId)
end

-- Ativar alavanca do portão
function GeneratorEvents:_handleGateLever(player: Player, gateId: number)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	if not state.isAlive then return end
	if state.role ~= "Survivor" then return end
	if state.isInCage then return end

	_objectiveService:activateGateLever(player, gateId)
end

-- Escapar pelo portão
function GeneratorEvents:_handleGateEscape(player: Player, gateId: number)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	if not state.isAlive then return end
	if state.role ~= "Survivor" then return end
	if state.isInCage then return end

	_objectiveService:tryEscape(player, gateId)
end

-- ==========================================
-- UTILITÁRIOS
-- ==========================================

-- Extrai um ID numérico de um nome de instância (ex: "Generator3" → 3)
function GeneratorEvents:_extractIdFromName(name: string): number?
	local id = string.match(name, "(%d+)")
	if id then
		return tonumber(id)
	end
	return nil
end

-- ==========================================
-- CLEANUP
-- ==========================================

function GeneratorEvents:Destroy()
	table.clear(_lastActionTime)
	_generatorService = nil
	_objectiveService = nil
	_matchService = nil
	print("[CacadaSombria] GeneratorEvents destruído.")
end

return GeneratorEvents
