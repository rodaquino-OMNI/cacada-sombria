--!strict
--[[
  CaptureEvents.lua
  Handlers de eventos de captura no servidor.

  Responsável por:
  - Receber ações de captura via PlayerActionEvent
  - Validar e encaminhar para CaptureService
  - Rate limiting básico anti-spam

  Toda ação de captura passa por validação aqui
  antes de chegar ao CaptureService.

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- ==========================================
-- CONSTANTES
-- ==========================================
-- Intervalo mínimo entre ações de captura (anti-spam)
local RATE_LIMIT = 0.2 -- 200ms (um pouco mais relaxado que ações de combate)

-- ==========================================
-- SERVIÇO CAPTUREEVENTS
-- ==========================================
local CaptureEvents = {}

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Timestamps da última ação de captura por jogador (rate limiting)
local _lastActionTime: {[number]: number} = {}

-- Referência ao CaptureService (setada durante Init)
local _captureService: any = nil
local _matchService: any = nil

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init
-- @param playerActionEvent — RemoteEvent para ações do jogador
-- @param captureService — Referência ao CaptureService
-- @param matchService — Referência ao MatchService
function CaptureEvents.Init(
	playerActionEvent: RemoteEvent,
	captureService: any,
	matchService: any
)
	_captureService = captureService
	_matchService = matchService

	-- Registra handlers para ações de captura
	playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
		CaptureEvents:_handleCaptureAction(player, action, ...)
	end)

	print("[CacadaSombria] CaptureEvents inicializado.")
end

-- ==========================================
-- HANDLER CENTRAL DE AÇÕES DE CAPTURA
-- ==========================================

-- Roteia ações de captura para o CaptureService
-- @param player — O jogador que enviou a ação
-- @param action — Tipo de ação (string)
-- @param ... — Parâmetros adicionais
function CaptureEvents:_handleCaptureAction(player: Player, action: string, ...: any)
	-- Só processa ações de captura
	if action ~= PlayerActionEvent.ACTIONS.CARRY_PICKUP
		and action ~= PlayerActionEvent.ACTIONS.CAGE_DEPOSIT
		and action ~= PlayerActionEvent.ACTIONS.RESCUE_START
		and action ~= PlayerActionEvent.ACTIONS.WIGGLE then
		return -- Não é ação de captura, ignora
	end

	-- Rate limiting
	local now = os.clock()
	local lastTime = _lastActionTime[player.UserId] or 0
	if now - lastTime < RATE_LIMIT then
		return -- Muitas ações, descarta silenciosamente
	end
	_lastActionTime[player.UserId] = now

	-- Validações básicas
	local state = _matchService:getPlayerState(player)
	if not state then
		warn(string.format("[CacadaSombria] Ação de captura '%s' de jogador sem estado: %s", action, player.Name))
		return
	end

	-- ============================
	-- ROTEAMENTO POR TIPO DE AÇÃO
	-- ============================

	if action == PlayerActionEvent.ACTIONS.CARRY_PICKUP then
		-- Killer pega Sobrevivente derrubado
		-- params: targetPlayer (Player) opcional — se não especificado, busca o mais próximo
		local target: Player? = ...
		CaptureEvents:_validateAndHandleCarryPickup(player, target)

	elseif action == PlayerActionEvent.ACTIONS.CAGE_DEPOSIT then
		-- Killer deposita Sobrevivente na jaula
		-- params: cageId (number)
		local cageId: number? = ...
		CaptureEvents:_validateAndHandleCageDeposit(player, cageId)

	elseif action == PlayerActionEvent.ACTIONS.RESCUE_START then
		-- Sobrevivente inicia resgate
		-- params: cageId (number)
		local cageId: number? = ...
		CaptureEvents:_validateAndHandleRescueStart(player, cageId)

	elseif action == PlayerActionEvent.ACTIONS.WIGGLE then
		-- Sobrevivente carregado tenta se libertar
		CaptureEvents:_validateAndHandleWiggle(player)
	end
end

-- ==========================================
-- VALIDAÇÕES ESPECÍFICAS
-- ==========================================

-- Valida e processa CarryPickup
function CaptureEvents:_validateAndHandleCarryPickup(player: Player, target: Player?)
	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Apenas o Killer pode pegar Sobreviventes
	if state.role ~= "Killer" then
		print(string.format("[CacadaSombria] %s tentou pegar Sobrevivente mas não é o Killer.", player.Name))
		return
	end

	-- Killer precisa estar vivo
	if not state.isAlive then return end

	-- Killer não pode estar carregando outro Sobrevivente
	if state.isCarrying then
		print(string.format("[CacadaSombria] %s já está carregando um Sobrevivente.", player.Name))
		return
	end

	-- Encaminha para CaptureService
	_captureService:handleCarryPickup(player, target)
end

-- Valida e processa CageDeposit
function CaptureEvents:_validateAndHandleCageDeposit(player: Player, cageId: number?)
	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Apenas o Killer pode depositar em jaulas
	if state.role ~= "Killer" then
		print(string.format("[CacadaSombria] %s tentou depositar em jaula mas não é o Killer.", player.Name))
		return
	end

	-- Killer precisa estar vivo
	if not state.isAlive then return end

	-- Killer precisa estar carregando alguém
	if not state.isCarrying then
		print(string.format("[CacadaSombria] %s tentou depositar mas não está carregando ninguém.", player.Name))
		return
	end

	-- cageId obrigatório
	if not cageId then
		warn(string.format("[CacadaSombria] %s tentou depositar sem especificar jaula.", player.Name))
		return
	end

	-- Encaminha para CaptureService
	_captureService:handleCageDeposit(player, cageId)
end

-- Valida e processa RescueStart
function CaptureEvents:_validateAndHandleRescueStart(player: Player, cageId: number?)
	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Apenas Sobreviventes podem resgatar
	if state.role ~= "Survivor" then
		print(string.format("[CacadaSombria] %s tentou resgatar mas não é Sobrevivente.", player.Name))
		return
	end

	-- Sobrevivente precisa estar vivo e não derrubado
	if not state.isAlive or state.isDowned then
		print(string.format("[CacadaSombria] %s não pode resgatar (derrubado ou morto).", player.Name))
		return
	end

	-- Não pode resgatar se estiver em jaula
	if state.isInCage then return end

	-- cageId obrigatório
	if not cageId then
		warn(string.format("[CacadaSombria] %s tentou resgatar sem especificar jaula.", player.Name))
		return
	end

	-- Encaminha para CaptureService
	_captureService:handleRescueStart(player, cageId)
end

-- Valida e processa Wiggle
function CaptureEvents:_validateAndHandleWiggle(player: Player)
	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- O Sobrevivente precisa estar sendo carregado
	if not state.carriedByKillerId then
		-- Não está sendo carregado, ignora silenciosamente
		return
	end

	-- Encaminha para CaptureService
	_captureService:handleWiggle(player)
end

-- ==========================================
-- CLEANUP
-- ==========================================

function CaptureEvents.Destroy()
	_captureService = nil
	_matchService = nil
	table.clear(_lastActionTime)
	print("[CacadaSombria] CaptureEvents destruído.")
end

return CaptureEvents
