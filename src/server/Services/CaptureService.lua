--!strict
--[[
  CaptureService.lua
  Serviço que gerencia o sistema de captura: derrubada, transporte, jaula e resgate.

  Responsável por:
  - Estado de Derrubado (Down): HP=0 → movimento 30%, sem habilidades, sangramento 60s
  - Transporte (Carry): Killer carrega Sobrevivente derrubado (1.5s de interação)
  - Debate (Wiggle): Sobrevivente carregado preenche barra em 10s → liberta + atordoa Killer 2s
  - Jaulas: 5 posições fixas, 3 ativas por partida. Depósito (2s). Eliminação em 120s
  - Resgate: Aliado interage com jaula (3s de canal). Restaura 50% HP + 3s invulnerabilidade
  - Integração com Fúria: Resgate dentro de 40 studs → +20 Fúria ao Killer

  Toda validação é server-side. O cliente apenas envia input.
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
-- ATALHOS PARA CONSTANTES DE CAPTURA
-- ==========================================
local CAP = GameConstants.Capture

-- Posições das 5 jaulas no mapa (studs)
-- Serão ajustadas quando o mapa real estiver pronto (Épico E4)
-- Coordenadas relativas ao centro da Mansão Abandonada
local CAGE_POSITIONS: {Vector3} = {
	Vector3.new(30, 0, 20),    -- Jaula 1 — Salão Principal
	Vector3.new(-25, 0, 15),   -- Jaula 2 — Biblioteca
	Vector3.new(10, -5, -30),  -- Jaula 3 — Porão
	Vector3.new(-20, 0, -20),  -- Jaula 4 — Cozinha
	Vector3.new(0, 5, 0),      -- Jaula 5 — Sótão
}

-- ==========================================
-- ESTADOS DE JAULA
-- ==========================================
local CageState = {
	Inactive = "Inactive",     -- Jaula não está ativa nesta partida
	Empty = "Empty",           -- Jaula ativa, vazia
	Occupied = "Occupied",     -- Jaula ocupada por Sobrevivente
	BeingRescued = "BeingRescued", -- Alguém está resgatando
}

-- ==========================================
-- TIPOS INTERNOS
-- ==========================================

-- Dados de extensão de captura por Sobrevivente
-- type CaptureExtData = {
--     downStartTime: number?,          -- timestamp de quando foi derrubado (nil se não estiver down)
--     bleedOutTimer: number?,          -- tempo restante em segundos
--     wiggleProgress: number,          -- progresso do debate (0 a 100)
--     isBeingCarried: boolean,         -- está sendo carregado pelo Killer?
--     carriedByKillerId: number?,      -- UserId do Killer
--     isInCage: boolean,               -- está dentro de uma jaula?
--     cageId: number?,                 -- ID da jaula (1-5)
--     cageStartTime: number?,          -- timestamp de quando entrou na jaula
--     cageTimer: number?,              -- tempo restante na jaula
--     cageRescueCount: number,         -- quantas vezes foi resgatado de jaula (máx 2)
--     isInvincible: boolean,           -- invulnerável após resgate
--     invincibleEndTime: number?,      -- timestamp do fim da invulnerabilidade
-- }

-- Dados de uma jaula
-- type CageData = {
--     id: number,
--     position: Vector3,
--     state: string,                   -- Inactive / Empty / Occupied / BeingRescued
--     occupiedBy: Player?,             -- Sobrevivente na jaula
--     rescuer: Player?,                -- Quem está resgatando
--     rescueStartTime: number?,        -- timestamp de início do resgate
--     rescueProgress: number,          -- progresso do resgate (0 a 100)
-- }

-- ==========================================
-- SERVIÇO CAPTURESERVICE
-- ==========================================
local CaptureService = {}
CaptureService.__index = CaptureService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
CaptureService.SurvivorDowned = Signal.new()       -- params: player (Sobrevivente derrubado)
CaptureService.SurvivorCarried = Signal.new()      -- params: killer, survivor
CaptureService.SurvivorCaged = Signal.new()        -- params: player, cageId
CaptureService.SurvivorRescued = Signal.new()      -- params: rescuedPlayer, rescuerPlayer, cageId
CaptureService.SurvivorEliminated = Signal.new()   -- params: player, reason ("bleedOut" | "cageTimer")
CaptureService.WiggleBreak = Signal.new()          -- params: survivor, killer (Sobrevivente se libertou)
CaptureService.FuryGainedFromRescue = Signal.new() -- params: killerPlayer, furyAmount (Killer ganhou Fúria)

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Referências aos RemoteEvents e serviços
local _gameStateEvent: RemoteEvent? = nil
local _uiSyncEvent: RemoteEvent? = nil
local _playerActionEvent: RemoteEvent? = nil
local _matchService: any = nil

-- Jaulas do mapa
local _cages: {any} = {}

-- IDs das jaulas ativas nesta partida (3 de 5, escolhidas aleatoriamente)
local _activeCageIds: {number} = {}

-- Extensão de dados de captura por userId
local _captureExt: {[number]: any} = {}

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
-- @param gameStateEvent — RemoteEvent para estado do jogo
-- @param uiSyncEvent — RemoteEvent para sincronização de HUD
-- @param playerActionEvent — RemoteEvent para ações do jogador
-- @param matchService — Referência ao MatchService
function CaptureService.Init(
	gameStateEvent: RemoteEvent,
	uiSyncEvent: RemoteEvent,
	playerActionEvent: RemoteEvent,
	matchService: any
)
	_gameStateEvent = gameStateEvent
	_uiSyncEvent = uiSyncEvent
	_playerActionEvent = playerActionEvent
	_matchService = matchService

	-- Inicializa as 5 jaulas como Inactive
	for i = 1, CAP.CageTotalPositions do
		_cages[i] = {
			id = i,
			position = CAGE_POSITIONS[i],
			state = CageState.Inactive,
			occupiedBy = nil,
			rescuer = nil,
			rescueStartTime = nil,
			rescueProgress = 0,
		}
	end

	print("[CacadaSombria] CaptureService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function CaptureService.Start()
	-- Quando a partida começar → ativar jaulas aleatórias
	_matchService.MatchStarted:Connect(function()
		CaptureService:_onMatchStarted()
	end)

	-- Quando a partida terminar → limpar estado
	_matchService.MatchEnded:Connect(function()
		CaptureService:_onMatchEnded()
	end)

	-- Quando um Sobrevivente for derrubado → iniciar estado Down
	_matchService.PlayerDowned:Connect(function(player: Player)
		CaptureService:_onPlayerDowned(player)
	end)

	print("[CacadaSombria] CaptureService iniciado.")
end

-- ==========================================
-- UPDATE PÚBLICO (chamado pelo GameManager)
-- ==========================================

-- Atualização principal delegada pelo GameManager
-- @param dt — delta time (tempo desde o último frame)
function CaptureService:update(dt: number)
	CaptureService:_update(dt)
end

-- ==========================================
-- INÍCIO / FIM DA PARTIDA
-- ==========================================

-- Chamado quando a partida entra em Hunting
function CaptureService:_onMatchStarted()
	-- Escolhe 3 jaulas aleatórias das 5 posições
	CaptureService:_selectRandomCages()

	-- Limpa todos os dados de extensão
	table.clear(_captureExt)

	print(string.format("[CacadaSombria] %d jaulas ativadas aleatoriamente.", CAP.CageActivePerMatch))
end

-- Seleciona aleatoriamente 3 das 5 jaulas para ativar
function CaptureService:_selectRandomCages()
	-- Cria lista de índices [1,2,3,4,5] e embaralha
	local indices = {}
	for i = 1, CAP.CageTotalPositions do
		table.insert(indices, i)
	end

	-- Fisher-Yates shuffle
	for i = #indices, 2, -1 do
		local j = math.random(i)
		indices[i], indices[j] = indices[j], indices[i]
	end

	-- Pega os primeiros 3
	_activeCageIds = {}
	for i = 1, CAP.CageActivePerMatch do
		table.insert(_activeCageIds, indices[i])
		_cages[indices[i]].state = CageState.Empty
	end

	-- As outras 2 permanecem Inactive
end

-- Chamado quando a partida termina
function CaptureService:_onMatchEnded()
	-- Reseta todas as jaulas
	for i = 1, CAP.CageTotalPositions do
		_cages[i].state = CageState.Inactive
		_cages[i].occupiedBy = nil
		_cages[i].rescuer = nil
		_cages[i].rescueStartTime = nil
		_cages[i].rescueProgress = 0
	end

	_activeCageIds = {}
	table.clear(_captureExt)
end

-- ==========================================
-- HANDLER: SOBREVIVENTE DERRUBADO
-- ==========================================

-- Chamado quando MatchService.PlayerDowned dispara
-- @param player — O Sobrevivente derrubado
function CaptureService:_onPlayerDowned(player: Player)
	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Inicializa dados de extensão se não existirem
	local ext = _captureExt[player.UserId]
	if not ext then
		ext = {
			downStartTime = nil,
			bleedOutTimer = nil,
			wiggleProgress = 0,
			isBeingCarried = false,
			carriedByKillerId = nil,
			isInCage = false,
			cageId = nil,
			cageStartTime = nil,
			cageTimer = nil,
			cageRescueCount = 0,
			isInvincible = false,
			invincibleEndTime = nil,
		}
		_captureExt[player.UserId] = ext
	end

	-- Configura o temporizador de sangramento (bleed-out)
	local now = os.clock()
	ext.downStartTime = now
	ext.bleedOutTimer = CAP.DownBleedOutTime
	ext.wiggleProgress = 0
	ext.isBeingCarried = false
	ext.carriedByKillerId = nil

	-- Espelha no state do MatchService
	state.bleedOutTimer = CAP.DownBleedOutTime

	-- Reduz a velocidade de movimento para 30%
	if state.humanoid then
		local baseSpeed = GameConstants.Survivors.Base.Speed -- 22
		state.humanoid.WalkSpeed = baseSpeed * CAP.DownMoveSpeedMultiplier -- ~6.6
	end

	-- Notifica o cliente
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			player,
			GameStateEvent.MESSAGES.DOWN_STATE,
			true,
			CAP.DownBleedOutTime
		)
	end

	-- Notifica o HUD com o timer de sangramento
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.BLEED_OUT_TIMER,
			CAP.DownBleedOutTime
		)
	end

	-- Dispara sinal
	CaptureService.SurvivorDowned:Fire(player)

	print(string.format("[CacadaSombria] %s está DERRUBADO. Sangramento: %.0fs. Movimento: %.0f%%.",
		player.Name, CAP.DownBleedOutTime, CAP.DownMoveSpeedMultiplier * 100))
end

-- ==========================================
-- HANDLER: KILLER PEGA SOBREVIVENTE DERRUBADO
-- ==========================================

-- Chamado quando o Killer interage com um Sobrevivente derrubado
-- @param killer — O Caçador
-- @param targetPlayer — O Sobrevivente derrubado (pode ser nil, obtemos do mais próximo)
function CaptureService:handleCarryPickup(killer: Player, targetPlayer: Player?)
	local killerState = _matchService:getPlayerState(killer)
	if not killerState or killerState.role ~= "Killer" then return end

	-- Killer já está carregando alguém?
	if killerState.isCarrying then
		print(string.format("[CacadaSombria] %s já está carregando um Sobrevivente.", killer.Name))
		return
	end

	-- Encontra o Sobrevivente derrubado mais próximo se targetPlayer não for especificado
	local survivor: Player? = targetPlayer
	if not survivor then
		survivor = CaptureService:_findNearestDownedSurvivor(killer, 6) -- alcance de 6 studs
	end

	if not survivor then
		print(string.format("[CacadaSombria] %s tentou pegar, mas não há Sobrevivente derrubado por perto.", killer.Name))
		return
	end

	local survivorState = _matchService:getPlayerState(survivor)
	if not survivorState then return end

	-- Validações
	if not survivorState.isDowned then
		print(string.format("[CacadaSombria] %s não está derrubado.", survivor.Name))
		return
	end

	if survivorState.isInCage then
		print(string.format("[CacadaSombria] %s já está em uma jaula.", survivor.Name))
		return
	end

	local ext = _captureExt[survivor.UserId]
	if ext and ext.isBeingCarried then
		print(string.format("[CacadaSombria] %s já está sendo carregado.", survivor.Name))
		return
	end

	-- Verifica a distância
	local dist = _matchService:getDistanceBetween(killer, survivor)
	if not dist or dist > 6 then
		print(string.format("[CacadaSombria] %s está muito longe para ser pego (%.1f studs).", survivor.Name, dist or 999))
		return
	end

	-- Inicia a interação de pegar (1.5 segundos de canal)
	print(string.format("[CacadaSombria] %s está pegando %s (%.1fs)...", killer.Name, survivor.Name, CAP.CarryPickupTime))

	-- Bloqueia o movimento do Killer durante a interação
	local originalKillerSpeed = killerState.humanoid and killerState.humanoid.WalkSpeed or 26
	if killerState.humanoid then
		killerState.humanoid.WalkSpeed = 0
	end

	task.delay(CAP.CarryPickupTime, function()
		-- Verifica se ambos ainda estão válidos
		local kState = _matchService:getPlayerState(killer)
		local sState = _matchService:getPlayerState(survivor)
		if not kState or not sState then
			-- Restaura velocidade
			if killerState.humanoid then
				killerState.humanoid.WalkSpeed = originalKillerSpeed
			end
			return
		end

		if not sState.isDowned or sState.isInCage or sState.isAlive == false then
			if killerState.humanoid then
				killerState.humanoid.WalkSpeed = originalKillerSpeed
			end
			return
		end

		-- Verifica distância novamente
		local currentDist = _matchService:getDistanceBetween(killer, survivor)
		if currentDist and currentDist > 8 then
			if killerState.humanoid then
				killerState.humanoid.WalkSpeed = originalKillerSpeed
			end
			print(string.format("[CacadaSombria] %s se afastou demais. Transporte cancelado.", survivor.Name))
			return
		end

		-- PEGOU O SOBREVIVENTE!
		_matchService:setPlayerCarrying(killer, survivor)

		-- Atualiza extensão de captura
		local sExt = _captureExt[survivor.UserId]
		if not sExt then
			sExt = {
				downStartTime = nil,
				bleedOutTimer = nil,
				wiggleProgress = 0,
				isBeingCarried = false,
				carriedByKillerId = nil,
				isInCage = false,
				cageId = nil,
				cageStartTime = nil,
				cageTimer = nil,
				cageRescueCount = 0,
				isInvincible = false,
				invincibleEndTime = nil,
			}
			_captureExt[survivor.UserId] = sExt
		end
		sExt.isBeingCarried = true
		sExt.carriedByKillerId = killer.UserId
		sExt.wiggleProgress = 0

		-- Pausa o sangramento enquanto é carregado
		sExt.bleedOutTimer = sState.bleedOutTimer

		-- Reduz a velocidade do Killer para 80%
		if killerState.humanoid then
			killerState.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed * CAP.CarryKillerSpeedMultiplier
		end

		-- Sobrevivente fica imóvel (está sendo carregado)
		if sState.humanoid then
			sState.humanoid.WalkSpeed = 0
		end

		-- Notifica clientes
		if _gameStateEvent then
			-- Notifica o Sobrevivente que está sendo carregado
			GameStateEvent.sendToClient(
				_gameStateEvent,
				survivor,
				GameStateEvent.MESSAGES.CARRIED_STATE,
				true,
				killer.Name
			)

			-- Notifica o Killer sobre o estado de carregamento
			if _uiSyncEvent then
				UISyncEvent.sendToClient(
					_uiSyncEvent,
					killer,
					UISyncEvent.MESSAGES.CARRY_STATUS,
					true,
					survivor.Name
				)
			end
		end

		-- Dispara sinal
		CaptureService.SurvivorCarried:Fire(killer, survivor)

		print(string.format("[CacadaSombria] %s está CARREGANDO %s! (velocidade: %.0f%%)",
			killer.Name, survivor.Name, CAP.CarryKillerSpeedMultiplier * 100))
	end)
end

-- Encontra o Sobrevivente derrubado mais próximo dentro do alcance
-- @param killer — O Caçador
-- @param maxRange — Alcance máximo em studs
-- @return Player? — O Sobrevivente mais próximo, ou nil
function CaptureService:_findNearestDownedSurvivor(killer: Player, maxRange: number): Player?
	local nearest: Player? = nil
	local nearestDist = maxRange + 1

	local survivors = _matchService:getPlayersByRole("Survivor")
	for _, survivor in survivors do
		local sState = _matchService:getPlayerState(survivor)
		if sState and sState.isDowned and not sState.isInCage then
			local ext = _captureExt[survivor.UserId]
			-- Não pegar Sobrevivente que já está sendo carregado
			if ext and ext.isBeingCarried then continue end

			local dist = _matchService:getDistanceBetween(killer, survivor)
			if dist and dist < nearestDist then
				nearestDist = dist
				nearest = survivor
			end
		end
	end

	return nearest
end

-- ==========================================
-- HANDLER: DEBATE (WIGGLE)
-- ==========================================

-- Chamado a cada frame para Sobreviventes que estão sendo carregados
-- O progresso do debate é controlado pelo cliente (ação "Wiggle")
-- @param survivor — O Sobrevivente que está tentando se libertar
function CaptureService:handleWiggle(survivor: Player)
	local sState = _matchService:getPlayerState(survivor)
	if not sState then return end

	local ext = _captureExt[survivor.UserId]
	if not ext then return end

	if not ext.isBeingCarried then
		return
	end

	-- Incrementa o progresso do debate (o cliente envia ação Wiggle periodicamente)
	-- A barra enche completamente em CAP.WiggleTimeToBreak segundos
	-- Cada chamada incrementa proporcionalmente
	-- Como o cliente envia a ação a cada ~0.1s, calculamos o incremento por ação
	-- Mas o ideal é que o update(dt) controle isso. O cliente apenas sinaliza que está tentando.

	-- O servidor incrementa o progresso no update(), aqui apenas validamos
	-- e marcamos que o Sobrevivente está ativamente debatendo
	sState.wiggleProgress = math.min(100, sState.wiggleProgress + (100 / CAP.WiggleTimeToBreak * 0.1))

	-- Notifica o HUD sobre o progresso
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			survivor,
			UISyncEvent.MESSAGES.WIGGLE_PROGRESS,
			sState.wiggleProgress
		)
	end

	-- Verifica se a barra encheu completamente → libertou-se!
	if sState.wiggleProgress >= 100 then
		CaptureService:_onWiggleBreak(survivor)
	end
end

-- Sobrevivente se libertou do carregamento
-- @param survivor — O Sobrevivente que se libertou
function CaptureService:_onWiggleBreak(survivor: Player)
	local sState = _matchService:getPlayerState(survivor)
	if not sState then return end

	local ext = _captureExt[survivor.UserId]
	if not ext then return end

	local killerId = ext.carriedByKillerId
	if not killerId then return end

	local killer = Players:GetPlayerByUserId(killerId)
	if not killer then return end

	local killerState = _matchService:getPlayerState(killer)
	if not killerState then return end

	-- Libera o Sobrevivente
	_matchService:setPlayerCarrying(killer, nil)
	ext.isBeingCarried = false
	ext.carriedByKillerId = nil
	ext.wiggleProgress = 0
	sState.wiggleProgress = 0
	sState.carriedByKillerId = nil

	-- Restaura a velocidade do Killer
	if killerState.humanoid then
		killerState.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
	end

	-- Sobrevivente continua derrubado! Velocidade de 30%
	if sState.humanoid then
		sState.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed * CAP.DownMoveSpeedMultiplier
	end

	-- Retoma o sangramento
	sState.bleedOutTimer = ext.bleedOutTimer

	-- ATORDOA o Killer por 2 segundos
	if killerState.humanoid then
		killerState.humanoid.WalkSpeed = 0
	end

	task.delay(CAP.WiggleBreakStunDuration, function()
		local kState = _matchService:getPlayerState(killer)
		if kState and kState.humanoid then
			kState.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
		end
	end)

	-- Notifica todos os clientes
	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.WIGGLE_BREAK,
			survivor.Name
		)
	end

	-- Notifica o Killer que perdeu o Sobrevivente
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			killer,
			UISyncEvent.MESSAGES.CARRY_STATUS,
			false,
			nil
		)
	end

	-- Dispara sinal
	CaptureService.WiggleBreak:Fire(survivor, killer)

	print(string.format("[CacadaSombria] %s SE LIBERTOU de %s! Killer atordoado por %.0fs.",
		survivor.Name, killer.Name, CAP.WiggleBreakStunDuration))
end

-- ==========================================
-- HANDLER: DEPOSITAR NA JAULA
-- ==========================================

-- Chamado quando o Killer deposita o Sobrevivente em uma jaula
-- @param killer — O Caçador
-- @param cageId — ID da jaula (1-5)
function CaptureService:handleCageDeposit(killer: Player, cageId: number)
	local killerState = _matchService:getPlayerState(killer)
	if not killerState or killerState.role ~= "Killer" then return end

	-- Killer está carregando alguém?
	if not killerState.isCarrying or not killerState.carriedSurvivorId then
		print(string.format("[CacadaSombria] %s tentou depositar mas não está carregando ninguém.", killer.Name))
		return
	end

	-- Encontra o Sobrevivente carregado
	local survivorId = killerState.carriedSurvivorId
	local survivor = Players:GetPlayerByUserId(survivorId)
	if not survivor then return end

	local survivorState = _matchService:getPlayerState(survivor)
	if not survivorState then return end

	-- Valida a jaula
	if cageId < 1 or cageId > #_cages then
		print(string.format("[CacadaSombria] Jaula #%d inválida.", cageId))
		return
	end

	local cage = _cages[cageId]
	if cage.state ~= CageState.Empty then
		print(string.format("[CacadaSombria] Jaula #%d não está disponível (estado: %s).", cageId, cage.state))
		return
	end

	-- Verifica distância até a jaula
	if killerState.character then
		local rootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - cage.position).Magnitude
			if dist > 8 then
				print(string.format("[CacadaSombria] %s está muito longe da jaula #%d (%.1f studs).", killer.Name, cageId, dist))
				return
			end
		end
	end

	-- Verifica limite de resgates do Sobrevivente
	local ext = _captureExt[survivor.UserId]
	if not ext then
		ext = {
			downStartTime = os.clock(),
			bleedOutTimer = nil,
			wiggleProgress = 0,
			isBeingCarried = false,
			carriedByKillerId = nil,
			isInCage = false,
			cageId = nil,
			cageStartTime = nil,
			cageTimer = nil,
			cageRescueCount = 0,
			isInvincible = false,
			invincibleEndTime = nil,
		}
		_captureExt[survivor.UserId] = ext
	end

	-- Inicia o depósito (2 segundos de canal)
	print(string.format("[CacadaSombria] %s está depositando %s na jaula #%d (%.0fs)...",
		killer.Name, survivor.Name, cageId, CAP.CageDepositTime))

	-- Bloqueia movimento durante depósito
	local originalKillerSpeed = killerState.humanoid and killerState.humanoid.WalkSpeed or 26
	if killerState.humanoid then
		killerState.humanoid.WalkSpeed = 0
	end

	-- Marca a jaula como ocupada (para evitar race condition)
	cage.state = CageState.Occupied

	task.delay(CAP.CageDepositTime, function()
		local kState = _matchService:getPlayerState(killer)
		local sState = _matchService:getPlayerState(survivor)

		if not kState or not sState then
			cage.state = CageState.Empty
			return
		end

		-- Verifica se o Killer ainda está carregando o mesmo Sobrevivente
		if kState.carriedSurvivorId ~= survivor.UserId then
			cage.state = CageState.Empty
			return
		end

		-- Verifica distância novamente
		if kState.character then
			local rootPart: BasePart? = kState.character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local dist = (rootPart.Position - cage.position).Magnitude
				if dist > 10 then
					cage.state = CageState.Empty
					if kState.humanoid then
						kState.humanoid.WalkSpeed = originalKillerSpeed
					end
					print(string.format("[CacadaSombria] %s se afastou da jaula. Depósito cancelado.", killer.Name))
					return
				end
			end
		end

		-- DEPOSITOU NA JAULA!
		local now = os.clock()

		-- Libera o Killer
		_matchService:setPlayerCarrying(killer, nil)
		if kState.humanoid then
			kState.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
		end

		-- Atualiza o Sobrevivente
		sState.isInCage = true
		sState.isDowned = false -- Não está mais derrubado, está na jaula
		sState.bleedOutTimer = nil
		sState.wiggleProgress = 0

		ext.isBeingCarried = false
		ext.carriedByKillerId = nil
		ext.isInCage = true
		ext.cageId = cageId
		ext.cageStartTime = now
		ext.cageTimer = CAP.CageEliminationTime

		-- Atualiza estado da jaula
		cage.state = CageState.Occupied
		cage.occupiedBy = survivor

		-- Sobrevivente fica imóvel na jaula
		if sState.humanoid then
			sState.humanoid.WalkSpeed = 0
		end

		-- Notifica todos os clientes
		if _gameStateEvent then
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.CAGE_STATE,
				true,
				cageId,
				CAP.CageEliminationTime
			)

			-- Envia para o Sobrevivente específico
			GameStateEvent.sendToClient(
				_gameStateEvent,
				survivor,
				GameStateEvent.MESSAGES.CAGE_STATE,
				true,
				cageId,
				CAP.CageEliminationTime
			)
		end

		-- Notifica HUD do Sobrevivente com timer da jaula
		if _uiSyncEvent then
			UISyncEvent.sendToClient(
				_uiSyncEvent,
				survivor,
				UISyncEvent.MESSAGES.CAGE_TIMER,
				CAP.CageEliminationTime,
				CAP.CageEliminationTime
			)

			-- Notifica Killer que não está mais carregando
			UISyncEvent.sendToClient(
				_uiSyncEvent,
				killer,
				UISyncEvent.MESSAGES.CARRY_STATUS,
				false,
				nil
			)
		end

		-- Dispara sinal
		CaptureService.SurvivorCaged:Fire(survivor, cageId)

		print(string.format("[CacadaSombria] %s depositou %s na JAULA #%d! Eliminação em %.0fs.",
			killer.Name, survivor.Name, cageId, CAP.CageEliminationTime))
	end)
end

-- ==========================================
-- HANDLER: RESGATE DE JAULA
-- ==========================================

-- Inicia o resgate de um Sobrevivente na jaula
-- @param rescuer — O Sobrevivente que está resgatando
-- @param cageId — ID da jaula
function CaptureService:handleRescueStart(rescuer: Player, cageId: number)
	local rescuerState = _matchService:getPlayerState(rescuer)
	if not rescuerState then return end

	-- Apenas Sobreviventes podem resgatar
	if rescuerState.role ~= "Survivor" then return end

	-- O resgatador precisa estar vivo e não derrubado
	if not rescuerState.isAlive or rescuerState.isDowned then return end
	if rescuerState.isInCage then return end

	-- Valida a jaula
	if cageId < 1 or cageId > #_cages then return end

	local cage = _cages[cageId]
	if cage.state ~= CageState.Occupied then
		print(string.format("[CacadaSombria] Jaula #%d não está ocupada (estado: %s).", cageId, cage.state))
		return
	end

	if not cage.occupiedBy then
		print(string.format("[CacadaSombria] Jaula #%d está marcada como ocupada mas sem Sobrevivente.", cageId))
		return
	end

	-- Já tem alguém resgatando?
	if cage.state == CageState.BeingRescued then
		print(string.format("[CacadaSombria] Jaula #%d já está sendo resgatada.", cageId))
		return
	end

	local prisoner = cage.occupiedBy
	local prisonerState = _matchService:getPlayerState(prisoner)
	if not prisonerState or not prisonerState.isInCage then
		-- Estado inconsistente, corrije
		cage.state = CageState.Empty
		cage.occupiedBy = nil
		return
	end

	-- Verifica se o Sobrevivente ainda pode ser resgatado (máx 2 vezes)
	local prisonerExt = _captureExt[prisoner.UserId]
	if prisonerExt and prisonerExt.cageRescueCount >= CAP.CageMaxRescuesPerSurvivor then
		print(string.format("[CacadaSombria] %s já foi resgatado %d vezes. Não pode mais ser salvo.",
			prisoner.Name, prisonerExt.cageRescueCount))
		return
	end

	-- Verifica distância até a jaula
	if rescuerState.character then
		local rootPart: BasePart? = rescuerState.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - cage.position).Magnitude
			if dist > 6 then
				print(string.format("[CacadaSombria] %s está muito longe da jaula #%d (%.1f studs).", rescuer.Name, cageId, dist))
				return
			end
		end
	end

	-- Inicia o resgate (3 segundos de canalização)
	print(string.format("[CacadaSombria] %s está RESGATANDO %s da jaula #%d (%.0fs)...",
		rescuer.Name, prisoner.Name, cageId, CAP.RescueChannelTime))

	-- Bloqueia movimento do resgatador
	if rescuerState.humanoid then
		rescuerState.humanoid.WalkSpeed = 0
	end

	cage.state = CageState.BeingRescued
	cage.rescuer = rescuer
	cage.rescueStartTime = os.clock()
	cage.rescueProgress = 0

	-- Notifica HUD do resgatador sobre progresso
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			rescuer,
			UISyncEvent.MESSAGES.RESCUE_START,
			cageId,
			rescuer.Name
		)
	end

	-- O resgate será concluído no update() quando o progresso atingir 100%
end

-- Cancela o resgate em andamento (chamado quando o resgatador se move ou é interrompido)
-- @param cageId — ID da jaula
-- @param reason — Motivo do cancelamento
function CaptureService:cancelRescue(cageId: number, reason: string?)
	if cageId < 1 or cageId > #_cages then return end

	local cage = _cages[cageId]
	if cage.state ~= CageState.BeingRescued then return end

	local rescuer = cage.rescuer
	cage.state = CageState.Occupied -- Volta a ser apenas ocupada
	cage.rescuer = nil
	cage.rescueStartTime = nil
	cage.rescueProgress = 0

	-- Restaura movimento do resgatador
	if rescuer then
		local rescuerState = _matchService:getPlayerState(rescuer)
		if rescuerState and rescuerState.humanoid and rescuerState.isAlive then
			rescuerState.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
		end

		-- Notifica HUD que o resgate parou
		if _uiSyncEvent then
			UISyncEvent.sendToClient(
				_uiSyncEvent,
				rescuer,
				UISyncEvent.MESSAGES.RESCUE_STOP,
				cageId,
				reason or "interrompido"
			)
		end
	end

	print(string.format("[CacadaSombria] Resgate na jaula #%d cancelado (%s).", cageId, reason or "desconhecido"))
end

-- ==========================================
-- GAME LOOP (UPDATE)
-- ==========================================

-- Atualização principal, chamada a cada frame via RunService.Heartbeat
-- @param dt — delta time (tempo desde o último frame)
function CaptureService:_update(dt: number)
	local now = os.clock()

	-- Processa todos os Sobreviventes com estado de captura
	for userId, ext in _captureExt do
		local player = Players:GetPlayerByUserId(userId)
		if not player then continue end

		local state = _matchService:getPlayerState(player)
		if not state then continue end

		-- ========== TIMER DE SANGRAMENTO (BLEED-OUT) ==========
		if state.isDowned and ext.bleedOutTimer and not ext.isBeingCarried then
			ext.bleedOutTimer = ext.bleedOutTimer - dt
			state.bleedOutTimer = ext.bleedOutTimer

			-- Notifica HUD a cada 1 segundo
			if _uiSyncEvent and not CaptureService._bleedNotifyTimer then
				CaptureService._bleedNotifyTimer = 0
			end
			CaptureService._bleedNotifyTimer = (CaptureService._bleedNotifyTimer or 0) + dt
			if CaptureService._bleedNotifyTimer >= 1 then
				CaptureService._bleedNotifyTimer = 0
				if _uiSyncEvent then
					UISyncEvent.sendToClient(
						_uiSyncEvent,
						player,
						UISyncEvent.MESSAGES.BLEED_OUT_TIMER,
						math.max(0, ext.bleedOutTimer)
					)
				end
			end

			-- Sangramento esgotou → morte
			if ext.bleedOutTimer <= 0 then
				CaptureService:_eliminateSurvivor(player, "bleedOut")
			end
		end

		-- ========== TIMER DA JAULA ==========
		if state.isInCage and ext.isInCage then
			ext.cageTimer = (ext.cageTimer or CAP.CageEliminationTime) - dt

			-- Notifica HUD a cada 1 segundo
			if not CaptureService._cageNotifyTimer then
				CaptureService._cageNotifyTimer = 0
			end
			CaptureService._cageNotifyTimer = CaptureService._cageNotifyTimer + dt
			if CaptureService._cageNotifyTimer >= 1 then
				CaptureService._cageNotifyTimer = 0
				if _uiSyncEvent then
					UISyncEvent.sendToClient(
						_uiSyncEvent,
						player,
						UISyncEvent.MESSAGES.CAGE_TIMER,
						math.max(0, ext.cageTimer),
						CAP.CageEliminationTime
					)
				end
			end

			-- Timer da jaula esgotou → eliminação
			if ext.cageTimer <= 0 then
				CaptureService:_eliminateSurvivor(player, "cageTimer")
			end
		end

		-- ========== PROGRESSO DE DEBATE (WIGGLE) ==========
		if ext.isBeingCarried and not state.isInCage then
			-- O progresso do debate é controlado pelo cliente (ação Wiggle)
			-- Apenas sincronizamos com o state
			ext.wiggleProgress = state.wiggleProgress
		end
	end

	-- ========== PROGRESSO DE RESGATE ==========
	for i = 1, #_cages do
		local cage = _cages[i]
		if cage.state == CageState.BeingRescued and cage.rescueStartTime then
			local elapsed = now - cage.rescueStartTime
			cage.rescueProgress = math.min(100, (elapsed / CAP.RescueChannelTime) * 100)

			-- Verifica se o resgatador ainda está na jaula
			if cage.rescuer then
				local rescuerState = _matchService:getPlayerState(cage.rescuer)
				if rescuerState and rescuerState.character then
					local rootPart: BasePart? = rescuerState.character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local dist = (rootPart.Position - cage.position).Magnitude
						if dist > 6 then
							-- Resgatador se afastou → cancela
							CaptureService:cancelRescue(i, "afastou da jaula")
							continue
						end
					end
				else
					-- Resgatador perdeu character → cancela
					CaptureService:cancelRescue(i, "resgatador indisponível")
					continue
				end
			end

			-- Notifica progresso a cada ~0.5s
			if not CaptureService._rescueNotifyTimer then
				CaptureService._rescueNotifyTimer = 0
			end
			CaptureService._rescueNotifyTimer = CaptureService._rescueNotifyTimer + dt
			if CaptureService._rescueNotifyTimer >= 0.5 then
				CaptureService._rescueNotifyTimer = 0
				if _uiSyncEvent and cage.rescuer then
					UISyncEvent.sendToClient(
						_uiSyncEvent,
						cage.rescuer,
						UISyncEvent.MESSAGES.RESCUE_PROGRESS,
						cage.rescueProgress,
						cage.rescuer.Name
					)
				end
			end

			-- Resgate concluído!
			if cage.rescueProgress >= 100 then
				CaptureService:_completeRescue(i)
			end
		end
	end
end

-- ==========================================
-- ELIMINAÇÃO DE SOBREVIVENTE
-- ==========================================

-- Elimina definitivamente um Sobrevivente
-- @param player — O Sobrevivente
-- @param reason — "bleedOut" ou "cageTimer"
function CaptureService:_eliminateSurvivor(player: Player, reason: string)
	local state = _matchService:getPlayerState(player)
	if not state then return end

	local ext = _captureExt[player.UserId]
	if not ext then return end

	-- Se estava em uma jaula, libera a jaula
	if ext.isInCage and ext.cageId then
		local cage = _cages[ext.cageId]
		if cage then
			cage.state = CageState.Empty
			cage.occupiedBy = nil
			cage.rescuer = nil
			cage.rescueStartTime = nil
			cage.rescueProgress = 0
		end
	end

	-- Notifica todos os clientes sobre a eliminação
	if _gameStateEvent then
		if reason == "cageTimer" then
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.CAGE_SURVIVOR_ELIMINATED,
				player.Name
			)
		end
	end

	-- Elimina via MatchService
	_matchService:killPlayer(player)

	-- Limpa extensão
	ext.isBeingCarried = false
	ext.carriedByKillerId = nil
	ext.isInCage = false
	ext.cageId = nil
	ext.cageStartTime = nil
	ext.cageTimer = nil
	ext.bleedOutTimer = nil
	ext.wiggleProgress = 0

	-- Dispara sinal
	CaptureService.SurvivorEliminated:Fire(player, reason)

	print(string.format("[CacadaSombria] %s foi ELIMINADO (%s).",
		player.Name, reason == "bleedOut" and "sangramento" or "tempo da jaula"))
end

-- ==========================================
-- CONCLUSÃO DO RESGATE
-- ==========================================

-- Finaliza o resgate com sucesso
-- @param cageId — ID da jaula
function CaptureService:_completeRescue(cageId: number)
	local cage = _cages[cageId]
	if not cage or cage.state ~= CageState.BeingRescued then return end

	local prisoner = cage.occupiedBy
	local rescuer = cage.rescuer

	if not prisoner or not rescuer then
		cage.state = CageState.Empty
		cage.occupiedBy = nil
		cage.rescuer = nil
		return
	end

	local prisonerState = _matchService:getPlayerState(prisoner)
	local rescuerState = _matchService:getPlayerState(rescuer)

	-- Incrementa contagem de resgates
	local prisonerExt = _captureExt[prisoner.UserId]
	if not prisonerExt then return end

	prisonerExt.cageRescueCount = (prisonerExt.cageRescueCount or 0) + 1

	-- Libera a jaula
	cage.state = CageState.Empty
	cage.occupiedBy = nil
	cage.rescuer = nil
	cage.rescueStartTime = nil
	cage.rescueProgress = 0

	-- Restaura o Sobrevivente resgatado: 50% HP, 3s invulnerabilidade
	_matchService:respawnPlayer(prisoner, CAP.RescueHPRestorePercent)

	-- Configura invulnerabilidade
	local now = os.clock()
	if prisonerState then
		prisonerState.isInvincible = true
		prisonerState.invincibleTimer = now + CAP.RescueInvulnerabilityTime
	end
	prisonerExt.isInvincible = true
	prisonerExt.invincibleEndTime = now + CAP.RescueInvulnerabilityTime
	prisonerExt.isInCage = false
	prisonerExt.cageId = nil

	-- Restaura velocidade do Sobrevivente resgatado
	if prisonerState and prisonerState.humanoid then
		prisonerState.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
	end

	-- Restaura movimento do resgatador
	if rescuerState and rescuerState.humanoid then
		rescuerState.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
	end

	-- Notifica todos os clientes
	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.RESCUED,
			prisoner.Name,
			rescuer.Name
		)

		-- Atualiza estado de jaula para o Sobrevivente resgatado
		GameStateEvent.sendToClient(
			_gameStateEvent,
			prisoner,
			GameStateEvent.MESSAGES.CAGE_STATE,
			false,
			nil,
			nil
		)
	end

	-- Notifica HUD do resgate concluído
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			rescuer,
			UISyncEvent.MESSAGES.RESCUE_COMPLETE,
			prisoner.Name,
			rescuer.Name
		)

		-- Notifica contagem de resgates restantes
		local remainingRescues = CAP.CageMaxRescuesPerSurvivor - prisonerExt.cageRescueCount
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			prisoner,
			UISyncEvent.MESSAGES.RESCUE_COUNT,
			math.max(0, remainingRescues)
		)
	end

	-- FÚRIA DO KILLER: Se o Killer estiver próximo (≤40 studs), ganha +20 Fury
	CaptureService:_checkFuryGainFromRescue(prisoner, cage.position)

	-- Dispara sinal
	CaptureService.SurvivorRescued:Fire(prisoner, rescuer, cageId)

	-- Agenda remoção da invulnerabilidade
	task.delay(CAP.RescueInvulnerabilityTime, function()
		local pState = _matchService:getPlayerState(prisoner)
		if pState then
			pState.isInvincible = false
			pState.invincibleTimer = nil
		end
		local pExt = _captureExt[prisoner.UserId]
		if pExt then
			pExt.isInvincible = false
			pExt.invincibleEndTime = nil
		end
	end)

	print(string.format("[CacadaSombria] %s RESGATOU %s da jaula #%d! HP: 50%%, Invulnerável por %.0fs.",
		rescuer.Name, prisoner.Name, cageId, CAP.RescueInvulnerabilityTime))
end

-- ==========================================
-- INTEGRAÇÃO COM FÚRIA
-- ==========================================

-- Verifica se o Killer está próximo o suficiente para ganhar Fúria por presenciar resgate
-- @param rescuedPlayer — O Sobrevivente que foi resgatado
-- @param cagePosition — Posição da jaula onde ocorreu o resgate
function CaptureService:_checkFuryGainFromRescue(rescuedPlayer: Player, cagePosition: Vector3)
	-- Encontra o Killer
	local killers = _matchService:getPlayersByRole("Killer")
	for _, killer in killers do
		local killerState = _matchService:getPlayerState(killer)
		if not killerState then continue end
		if not killerState.isAlive then continue end

		-- Verifica distância do Killer até a jaula
		local dist: number?
		if killerState.character then
			local rootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				dist = (rootPart.Position - cagePosition).Magnitude
			end
		end

		if dist and dist <= CAP.FuryRescueRange then
			-- Killer ganha +20 Fúria!
			killerState.fury = math.min(GameConstants.Killers.Distorcido.Abilities.Fury_Max,
				(killerState.fury or 0) + CAP.FuryRescueGain)

			-- Notifica o cliente do Killer
			if _gameStateEvent then
				GameStateEvent.sendToClient(
					_gameStateEvent,
					killer,
					GameStateEvent.MESSAGES.FURY_UPDATE,
					killerState.fury,
					GameConstants.Killers.Distorcido.Abilities.Fury_Max
				)
			end

			if _uiSyncEvent then
				UISyncEvent.sendToClient(
					_uiSyncEvent,
					killer,
					UISyncEvent.MESSAGES.FURY_UPDATE,
					killerState.fury,
					GameConstants.Killers.Distorcido.Abilities.Fury_Max
				)
			end

			-- Dispara sinal
			CaptureService.FuryGainedFromRescue:Fire(killer, CAP.FuryRescueGain)

			print(string.format("[CacadaSombria] %s ganhou +%d FÚRIA! (%.1f studs do resgate). Fúria atual: %.0f/%.0f",
				killer.Name, CAP.FuryRescueGain, dist, killerState.fury,
				GameConstants.Killers.Distorcido.Abilities.Fury_Max))
		end
	end
end

-- ==========================================
-- FUNÇÕES UTILITÁRIAS DE CONSULTA
-- ==========================================

-- Retorna a quantidade de Sobreviventes atualmente em jaulas
-- Usado pelo ObjectiveService para verificar condição de vitória do Killer
function CaptureService:getCagedCount(): number
	local count = 0
	for _, ext in _captureExt do
		if ext.isInCage then
			count = count + 1
		end
	end
	return count
end

-- Retorna as jaulas ativas e seus estados
function CaptureService:getCages(): {any}
	return _cages
end

-- Retorna os IDs das jaulas ativas
function CaptureService:getActiveCageIds(): {number}
	return _activeCageIds
end

-- Verifica se um Sobrevivente está em estado de captura (derrubado ou em jaula)
function CaptureService:isSurvivorCaptured(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state then return false end
	return state.isDowned == true or state.isInCage == true
end

-- ==========================================
-- CLEANUP
-- ==========================================

function CaptureService:Destroy()
	table.clear(_cages)
	table.clear(_activeCageIds)
	table.clear(_captureExt)
	print("[CacadaSombria] CaptureService destruído.")
end

return CaptureService
