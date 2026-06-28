--!strict
--[[
  ObjectiveService.lua
  Serviço que gerencia os objetivos da partida e condições de vitória.

  Responsável por:
  - Portão de fuga: 2 portões em lados opostos (E5.4)
  - Ativação após 5 geradores consertados
  - Interação na alavanca (3s) → portão abre em 8s
  - Ambos os portões abrem quando um é ativado
  - Som audível a 60 studs
  - Condição de vitória dos Sobreviventes: ≥1 escapa pelo portão (E5.5)
  - Condição de vitória do Caçador: 4 Sobreviventes em jaulas (E5.6)
  - Timeout/Colapso: 15 min → portão abre 30s e fecha permanentemente (E5.7)

  Toda validação é server-side.
  Comunicação entre serviços via Signal (pub/sub).

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo por performance)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)

-- ==========================================
-- CONSTANTES
-- ==========================================

-- Duração total da partida em segundos (15 minutos)
local MATCH_DURATION = GameConstants.Game.MatchDuration -- 900s

-- Quando começa o colapso (30s antes do fim)
local COLLAPSE_START_TIME = MATCH_DURATION - 30 -- 870s = 14:30

-- Duração do colapso (portão fica aberto)
local COLLAPSE_DURATION = 30

-- Tempo de interação na alavanca (segundos)
local LEVER_INTERACT_TIME = 3

-- Tempo de abertura do portão (segundos)
local GATE_OPEN_TIME = 8

-- Raio de interação com a alavanca (studs)
local INTERACT_RANGE = 6

-- Raio do som do portão (studs)
local GATE_SOUND_RADIUS = 60

-- Número de Sobreviventes por partida
local SURVIVORS_PER_MATCH = GameConstants.Game.SurvivorsPerMatch -- 4

-- Posições dos 2 portões de fuga (lados opostos do mapa)
-- Serão ajustadas com o mapa real no E4
local GATE_POSITIONS: {Vector3} = {
	Vector3.new(50, 0, 0),    -- Portão 1 — lado leste (frente da mansão)
	Vector3.new(-50, 0, 0),   -- Portão 2 — lado oeste (fundos da mansão)
}

-- ==========================================
-- ESTADOS DO PORTÃO
-- ==========================================
local GateState = {
	Locked = "Locked",         -- Trancado (geradores não completados)
	Unlocked = "Unlocked",     -- Destrancado (todos geradores consertados, pode interagir)
	Opening = "Opening",       -- Abrindo (alavanca ativada, portão subindo)
	Opened = "Opened",         -- Aberto (Sobreviventes podem escapar)
	Closed = "Closed",         -- Fechado permanentemente (após colapso)
}

-- ==========================================
-- TIPOS INTERNOS
-- ==========================================

-- Representa o estado de um portão
-- type GateData = {
--     id: number,
--     position: Vector3,
--     state: string,              -- Locked/Unlocked/Opening/Opened/Closed
--     leverInteracting: Player?,  -- quem está ativando a alavanca
--     leverStartTime: number?,    -- timestamp de início da interação
--     openStartTime: number?,     -- timestamp de início da abertura
--     openProgress: number,       -- 0 a 100 (% de abertura)
-- }

-- ==========================================
-- SERVIÇO OBJECTIVESERVICE
-- ==========================================
local ObjectiveService = {}
ObjectiveService.__index = ObjectiveService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
ObjectiveService.GateActivated = Signal.new()      -- params: gateId
ObjectiveService.GateOpened = Signal.new()          -- params: gateId
ObjectiveService.GateClosed = Signal.new()          -- params: gateId
ObjectiveService.SurvivorsWin = Signal.new()         -- sem parâmetros
ObjectiveService.KillerWin = Signal.new()            -- params: reason ("allCaged" | "timeout")
ObjectiveService.CollapseStarted = Signal.new()      -- params: secondsRemaining
ObjectiveService.SurvivorEscaped = Signal.new()      -- params: player

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Referências aos RemoteEvents e serviços
local _gameStateEvent: RemoteEvent? = nil
local _uiSyncEvent: RemoteEvent? = nil
local _playerActionEvent: RemoteEvent? = nil
local _matchService: any = nil
local _generatorService: any = nil

-- Estado dos 2 portões
local _gates: {any} = {}

-- Timer da partida (segundos restantes)
local _matchTimeRemaining: number = MATCH_DURATION

-- Controle de colapso
local _collapseActive: boolean = false
local _collapseTimer: number = 0
local _gateAutoOpened: boolean = false

-- Controle de vitória (evita múltiplas transições)
local _victoryDeclared: boolean = false

-- Contagem de Sobreviventes que escaparam
local _escapedCount: number = 0

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
-- @param gameStateEvent — RemoteEvent para estado do jogo
-- @param uiSyncEvent — RemoteEvent para sincronização de HUD
-- @param playerActionEvent — RemoteEvent para ações do jogador
-- @param matchService — Referência ao MatchService
-- @param generatorService — Referência ao GeneratorService
function ObjectiveService.Init(
	gameStateEvent: RemoteEvent,
	uiSyncEvent: RemoteEvent,
	playerActionEvent: RemoteEvent,
	matchService: any,
	generatorService: any
)
	_gameStateEvent = gameStateEvent
	_uiSyncEvent = uiSyncEvent
	_playerActionEvent = playerActionEvent
	_matchService = matchService
	_generatorService = generatorService

	-- Inicializa os portões
	for i = 1, #GATE_POSITIONS do
		_gates[i] = {
			id = i,
			position = GATE_POSITIONS[i],
			state = GateState.Locked,
			leverInteracting = nil,
			leverStartTime = nil,
			openStartTime = nil,
			openProgress = 0,
		}
	end

	print("[CacadaSombria] ObjectiveService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function ObjectiveService.Start()
	-- Quando a partida começar...
	_matchService.MatchStarted:Connect(function()
		ObjectiveService:_onMatchStarted()
	end)

	-- Quando todos os geradores forem consertados → destrancar portões
	_generatorService.AllGeneratorsRepaired:Connect(function()
		ObjectiveService:_onAllGeneratorsRepaired()
	end)

	-- Quando um Sobrevivente for capturado (será expandido no E6)
	-- Por enquanto, verificamos via polling no update

	-- Game loop via Heartbeat
	RunService.Heartbeat:Connect(function(dt: number)
		ObjectiveService:_update(dt)
	end)

	print("[CacadaSombria] ObjectiveService iniciado.")
end

-- ==========================================
-- INÍCIO DA PARTIDA
-- ==========================================

-- Chamado quando a partida entra em Hunting
function ObjectiveService:_onMatchStarted()
	-- Reseta todo o estado
	_matchTimeRemaining = MATCH_DURATION
	_collapseActive = false
	_collapseTimer = 0
	_gateAutoOpened = false
	_victoryDeclared = false
	_escapedCount = 0

	-- Reseta os portões
	for i = 1, #_gates do
		local gate = _gates[i]
		gate.state = GateState.Locked
		gate.leverInteracting = nil
		gate.leverStartTime = nil
		gate.openStartTime = nil
		gate.openProgress = 0
	end

	print("[CacadaSombria] Objetivos resetados para nova partida.")
end

-- ==========================================
-- DESTRANCAR PORTÕES (TODOS GERADORES CONSERTADOS)
-- ==========================================

-- Chamado quando GeneratorService.AllGeneratorsRepaired dispara
function ObjectiveService:_onAllGeneratorsRepaired()
	print("[CacadaSombria] Todos os geradores consertados! Portões destrancados.")

	for i = 1, #_gates do
		local gate = _gates[i]
		if gate.state == GateState.Locked then
			gate.state = GateState.Unlocked
		end
	end

	-- Notifica todos os clientes que os portões estão disponíveis
	if _gameStateEvent then
		for i = 1, #_gates do
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.GATE_ACTIVATED,
				i,
				_gates[i].position
			)
		end
	end
end

-- ==========================================
-- INTERAÇÃO COM A ALAVANCA DO PORTÃO
-- ==========================================

-- Verifica se um Sobrevivente pode interagir com a alavanca de um portão
-- @param player — O jogador (deve ser Sobrevivente)
-- @param gateId — ID do portão (1 ou 2)
-- @return boolean, string? — true se pode interagir, ou false + motivo
function ObjectiveService:canInteractWithGate(player: Player, gateId: number): (boolean, string?)
	if gateId < 1 or gateId > #_gates then
		return false, "Portão inexistente"
	end

	local gate = _gates[gateId]

	-- Verifica o estado do portão
	if gate.state == GateState.Locked then
		return false, "Portão trancado (conserte os geradores)"
	end
	if gate.state == GateState.Opening then
		return false, "Portão já está abrindo"
	end
	if gate.state == GateState.Opened then
		return false, "Portão já está aberto"
	end
	if gate.state == GateState.Closed then
		return false, "Portão fechado permanentemente"
	end

	-- Verifica se alguém já está interagindo
	if gate.leverInteracting then
		return false, "Alguém já está ativando a alavanca"
	end

	-- Verifica se o jogador é um Sobrevivente
	local state = _matchService:getPlayerState(player)
	if not state then
		return false, "Jogador sem estado"
	end
	if state.role ~= "Survivor" then
		return false, "Apenas Sobreviventes podem ativar o portão"
	end
	if not state.isAlive then
		return false, "Jogador não está vivo"
	end
	if state.isInCage then
		return false, "Jogador está em jaula"
	end

	-- Verifica distância até o portão
	if state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - gate.position).Magnitude
			if dist > INTERACT_RANGE then
				return false, string.format("Muito longe (%.1f studs)", dist)
			end
		end
	end

	return true, nil
end

-- Inicia a ativação da alavanca do portão
-- Canal de 3 segundos, depois o portão começa a abrir
-- @param player — O Sobrevivente
-- @param gateId — ID do portão
function ObjectiveService:activateGateLever(player: Player, gateId: number)
	local ok, reason = ObjectiveService:canInteractWithGate(player, gateId)
	if not ok then
		print(string.format("[CacadaSombria] %s não pode ativar portão #%d: %s",
			player.Name, gateId, reason))
		return
	end

	local gate = _gates[gateId]

	-- Inicia a interação na alavanca
	gate.leverInteracting = player
	gate.leverStartTime = os.clock()

	-- Bloqueia movimento durante a interação
	local state = _matchService:getPlayerState(player)
	if state and state.humanoid then
		state.humanoid.WalkSpeed = 0
	end

	print(string.format("[CacadaSombria] %s está ativando a alavanca do portão #%d (%.0fs)...",
		player.Name, gateId, LEVER_INTERACT_TIME))
end

-- Cancela a interação com a alavanca
function ObjectiveService:_cancelLeverInteraction(gateId: number, reason: string?)
	local gate = _gates[gateId]
	if not gate or not gate.leverInteracting then return end

	local player = gate.leverInteracting
	local state = _matchService:getPlayerState(player)

	-- Restaura velocidade
	if state and state.humanoid then
		state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
	end

	gate.leverInteracting = nil
	gate.leverStartTime = nil

	print(string.format("[CacadaSombria] Interação com alavanca do portão #%d cancelada (%s).",
		gateId, reason or "desconhecido"))
end

-- ==========================================
-- ABERTURA DO PORTÃO
-- ==========================================

-- Inicia a abertura de ambos os portões
-- Chamado quando a interação na alavanca é completada (3s)
function ObjectiveService:_startGateOpening(activatedGateId: number)
	print(string.format("[CacadaSombria] Portão #%d ativado! Abrindo ambos os portões...", activatedGateId))

	-- Abre AMBOS os portões
	for i = 1, #_gates do
		local gate = _gates[i]
		if gate.state == GateState.Unlocked then
			gate.state = GateState.Opening
			gate.openStartTime = os.clock()
			gate.openProgress = 0

			if _gameStateEvent then
				GameStateEvent.sendToAll(
					_gameStateEvent,
					GameStateEvent.MESSAGES.GATE_OPENED,
					i
				)
			end

			print(string.format("[CacadaSombria] Portão #%d começou a abrir.", i))
		end
	end

	-- Dispara sinal
	ObjectiveService.GateActivated:Fire(activatedGateId)
end

-- Finaliza a abertura de um portão
function ObjectiveService:_finishGateOpening(gateId: number)
	local gate = _gates[gateId]
	if not gate or gate.state ~= GateState.Opening then return end

	gate.state = GateState.Opened
	gate.openProgress = 100

	print(string.format("[CacadaSombria] Portão #%d completamente aberto! Sobreviventes podem escapar.", gateId))

	-- Dispara sinal
	ObjectiveService.GateOpened:Fire(gateId)
end

-- ==========================================
-- FUGA DE SOBREVIVENTE PELO PORTÃO
-- ==========================================

-- Verifica se um Sobrevivente pode escapar por um portão
-- @param player — O Sobrevivente
-- @param gateId — ID do portão
-- @return boolean — true se escapou com sucesso
function ObjectiveService:tryEscape(player: Player, gateId: number): boolean
	if _victoryDeclared then return false end

	local gate = _gates[gateId]
	if not gate then return false end

	-- O portão precisa estar aberto
	if gate.state ~= GateState.Opened then
		return false
	end

	-- Verifica se o jogador é um Sobrevivente válido
	local state = _matchService:getPlayerState(player)
	if not state then return false
	if state.role ~= "Survivor" then return false
	if not state.isAlive then return false
	if state.isInCage then return false

	-- Verifica distância até o portão
	if state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - gate.position).Magnitude
			if dist > INTERACT_RANGE * 2 then -- alcance maior para escapar
				return false
			end
		end
	end

	-- SOBREVIVENTE ESCAPOU!
	_escapedCount = _escapedCount + 1

	-- Notifica todos os clientes
	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.ESCAPED,
			player.Name
		)
	end

	print(string.format("[CacadaSombria] %s ESCAPOU pelo portão #%d! (%d escaparam)",
		player.Name, gateId, _escapedCount))

	-- Dispara sinal
	ObjectiveService.SurvivorEscaped:Fire(player)

	-- Verifica condição de vitória dos Sobreviventes (≥1 escapou)
	ObjectiveService:_checkSurvivorVictory()

	return true
end

-- ==========================================
-- CONDIÇÕES DE VITÓRIA
-- ==========================================

-- Verifica vitória dos Sobreviventes: pelo menos 1 escapou
function ObjectiveService:_checkSurvivorVictory()
	if _victoryDeclared then return end

	if _escapedCount >= 1 then
		_victoryDeclared = true
		print("[CacadaSombria] VITÓRIA DOS SOBREVIVENTES! Pelo menos 1 escapou pelo portão.")

		if _gameStateEvent then
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.GAME_OVER,
				"Survivors"
			)
		end

		ObjectiveService.SurvivorsWin:Fire()

		-- Transita para o estado de Ending
		if _matchService.transitionTo then
			_matchService:transitionTo("Ending")
		end
	end
end

-- Verifica vitória do Caçador: todos os 4 Sobreviventes em jaulas
-- Chamado a cada frame no update
function ObjectiveService:_checkKillerVictory()
	if _victoryDeclared then return end

	-- Conta Sobreviventes vivos e em jaula
	local survivorsInCage = 0
	local survivorsAlive = 0

	local survivorsList = _matchService:getPlayersByRole("Survivor")
	for _, player in survivorsList do
		local state = _matchService:getPlayerState(player)
		if state then
			if state.isAlive and not state.isInCage then
				survivorsAlive = survivorsAlive + 1
			end
			if state.isInCage then
				survivorsInCage = survivorsInCage + 1
			end
		end
	end

	-- Se não há mais Sobreviventes livres e todos estão em jaulas
	if survivorsAlive == 0 and survivorsInCage == SURVIVORS_PER_MATCH then
		_victoryDeclared = true
		print("[CacadaSombria] VITÓRIA DO CAÇADOR! Todos os Sobreviventes estão em jaulas.")

		if _gameStateEvent then
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.GAME_OVER,
				"Killer"
			)
		end

		ObjectiveService.KillerWin:Fire("allCaged")

		if _matchService.transitionTo then
			_matchService:transitionTo("Ending")
		end
	end
end

-- Vitória do Caçador por timeout
function ObjectiveService:_declareKillerTimeoutVictory()
	if _victoryDeclared then return end
	_victoryDeclared = true

	print("[CacadaSombria] VITÓRIA DO CAÇADOR! Tempo esgotado — Sobreviventes não escaparam.")

	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.GAME_OVER,
			"Killer"
		)
	end

	ObjectiveService.KillerWin:Fire("timeout")

	if _matchService.transitionTo then
		_matchService:transitionTo("Ending")
	end
end

-- ==========================================
-- COLAPSO (TIMEOUT)
-- ==========================================

-- Ativa o colapso: portão abre automaticamente por 30s
function ObjectiveService:_startCollapse()
	_collapseActive = true
	_collapseTimer = COLLAPSE_DURATION

	print(string.format("[CacadaSombria] COLAPSO INICIADO! Portão abre por %.0f segundos.", COLLAPSE_DURATION))

	-- Notifica todos os clientes
	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.COLLAPSE_STARTED,
			COLLAPSE_DURATION
		)
	end

	ObjectiveService.CollapseStarted:Fire(COLLAPSE_DURATION)

	-- Abre todos os portões automaticamente (pulando a alavanca)
	for i = 1, #_gates do
		local gate = _gates[i]
		if gate.state == GateState.Locked or gate.state == GateState.Unlocked then
			gate.state = GateState.Opening
			gate.openStartTime = os.clock()
			gate.openProgress = 0

			if _gameStateEvent then
				GameStateEvent.sendToAll(
					_gameStateEvent,
					GameStateEvent.MESSAGES.GATE_OPENED,
					i
				)
			end
		end
		-- Cancela qualquer interação de alavanca em andamento
		if gate.leverInteracting then
			ObjectiveService:_cancelLeverInteraction(i, "colapso iniciado")
		end
	end
end

-- Finaliza o colapso: fecha os portões permanentemente
function ObjectiveService:_endCollapse()
	print("[CacadaSombria] COLAPSO ENCERRADO! Portões fechados permanentemente.")

	for i = 1, #_gates do
		local gate = _gates[i]
		gate.state = GateState.Closed
		gate.openProgress = 0

		if _gameStateEvent then
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.GATE_CLOSED,
				i
			)
		end

		ObjectiveService.GateClosed:Fire(i)
	end

	_collapseActive = false

	-- Após fechar os portões, declara vitória do Caçador (ninguém escapou)
	ObjectiveService:_declareKillerTimeoutVictory()
end

-- ==========================================
-- GAME LOOP (UPDATE)
-- ==========================================

-- Atualização principal, chamada a cada frame via RunService.Heartbeat
-- Processa timer da partida, colapso, abertura de portões e condições de vitória
function ObjectiveService:_update(dt: number)
	-- Só processa durante a caçada
	local matchState = _matchService.GetState and _matchService.GetState()
	if matchState ~= "Hunting" then return end

	local now = os.clock()

	-- Atualiza o timer da partida
	_matchTimeRemaining = _matchTimeRemaining - dt

	-- === VERIFICA COLAPSO ===
	if not _collapseActive and not _gateAutoOpened and _matchTimeRemaining <= COLLAPSE_START_TIME then
		_gateAutoOpened = true
		ObjectiveService:_startCollapse()
	end

	-- === ATUALIZA COLAPSO ATIVO ===
	if _collapseActive then
		_collapseTimer = _collapseTimer - dt
		if _collapseTimer <= 0 then
			ObjectiveService:_endCollapse()
		end
	end

	-- === ATUALIZA ABERTURA DE PORTÕES ===
	for i = 1, #_gates do
		local gate = _gates[i]

		-- Processa interação na alavanca
		if gate.state == GateState.Unlocked and gate.leverInteracting then
			local leverElapsed = now - (gate.leverStartTime or now)
			if leverElapsed >= LEVER_INTERACT_TIME then
				-- Interação completa!
				local player = gate.leverInteracting
				local state = _matchService:getPlayerState(player)
				if state and state.humanoid then
					state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
				end
				gate.leverInteracting = nil
				gate.leverStartTime = nil
				ObjectiveService:_startGateOpening(i)
			else
				-- Verifica se o jogador ainda está válido
				local player = gate.leverInteracting
				local state = _matchService:getPlayerState(player)
				if not state or not state.isAlive or state.isInCage then
					ObjectiveService:_cancelLeverInteraction(i, "jogador inválido")
				end
				-- Verifica se o jogador se moveu
				if state and state.humanoid and state.humanoid.WalkSpeed > 0 then
					ObjectiveService:_cancelLeverInteraction(i, "jogador se moveu")
				end
			end
		end

		-- Processa abertura do portão
		if gate.state == GateState.Opening then
			local openElapsed = now - (gate.openStartTime or now)
			gate.openProgress = math.min(100, (openElapsed / GATE_OPEN_TIME) * 100)

			-- Notifica clientes sobre o progresso
			if _uiSyncEvent and gate.openProgress % 10 < dt * 100 then -- ~10 vezes por segundo
				UISyncEvent.sendToAll(
					_uiSyncEvent,
					UISyncEvent.MESSAGES.GATE_PROGRESS,
					i,
					gate.openProgress
				)
			end

			if openElapsed >= GATE_OPEN_TIME then
				ObjectiveService:_finishGateOpening(i)
			end
		end
	end

	-- === VERIFICA CONDIÇÕES DE VITÓRIA ===
	-- Vitória do Caçador: todos em jaulas (verifica a cada ~1 segundo)
	if not _victoryDeclared then
		-- Usamos um contador para não verificar todo frame
		if not ObjectiveService._victoryCheckTimer then
			ObjectiveService._victoryCheckTimer = 0
		end
		ObjectiveService._victoryCheckTimer = (ObjectiveService._victoryCheckTimer or 0) + dt
		if ObjectiveService._victoryCheckTimer >= 1 then
			ObjectiveService._victoryCheckTimer = 0
			ObjectiveService:_checkKillerVictory()
		end
	end

	-- === VERIFICA TIMEOUT (fallback) ===
	-- Se a partida durar mais que o tempo máximo SEM colapso ter acontecido
	if _matchTimeRemaining <= 0 and not _victoryDeclared then
		ObjectiveService:_declareKillerTimeoutVictory()
	end
end

-- ==========================================
-- FUNÇÕES UTILITÁRIAS DE CONSULTA
-- ==========================================

-- Retorna o estado de um portão
function ObjectiveService:getGateState(gateId: number): string?
	local gate = _gates[gateId]
	if gate then
		return gate.state
	end
	return nil
end

-- Retorna se um portão está aberto (Sobreviventes podem escapar)
function ObjectiveService:isGateOpen(gateId: number): boolean
	local gate = _gates[gateId]
	return gate and gate.state == GateState.Opened
end

-- Retorna a posição de um portão
function ObjectiveService:getGatePosition(gateId: number): Vector3?
	local gate = _gates[gateId]
	if gate then
		return gate.position
	end
	return nil
end

-- Retorna o número de Sobreviventes que escaparam
function ObjectiveService:getEscapedCount(): number
	return _escapedCount
end

-- Retorna se o colapso está ativo
function ObjectiveService:isCollapseActive(): boolean
	return _collapseActive
end

-- Retorna o tempo restante da partida
function ObjectiveService:getMatchTimeRemaining(): number
	return _matchTimeRemaining
end

-- ==========================================
-- CLEANUP
-- ==========================================

function ObjectiveService:Destroy()
	-- Cancela interações em andamento
	for i = 1, #_gates do
		if _gates[i].leverInteracting then
			ObjectiveService:_cancelLeverInteraction(i, "serviço destruído")
		end
	end

	-- Limpa os sinais
	ObjectiveService.GateActivated:Destroy()
	ObjectiveService.GateOpened:Destroy()
	ObjectiveService.GateClosed:Destroy()
	ObjectiveService.SurvivorsWin:Destroy()
	ObjectiveService.KillerWin:Destroy()
	ObjectiveService.CollapseStarted:Destroy()
	ObjectiveService.SurvivorEscaped:Destroy()

	table.clear(_gates)
	_victoryDeclared = false
	_escapedCount = 0
	_collapseActive = false

	print("[CacadaSombria] ObjectiveService destruído.")
end

return ObjectiveService
