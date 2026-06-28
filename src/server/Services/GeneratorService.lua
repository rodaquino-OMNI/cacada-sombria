--!strict
--[[
  GeneratorService.lua
  Serviço que gerencia os geradores do mapa.

  Responsável por:
  - Spawn aleatório de 5 geradores em 7 posições possíveis (E5.1)
  - Mecânica de reparo: canal de 8s, bloqueio de movimento (E5.2)
  - Skill checks QTE: ponteiro giratório, zona de acerto (E5.3)
  - Progresso de reparo e bônus/penalidade de skill check
  - Dificuldade progressiva (mais geradores = mais difícil)
  - Som de zumbido em raio de 40 studs
  - Alerta global em falha de skill check

  Toda validação é server-side. O cliente apenas envia input (Interact).
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

-- Número de geradores ativos por partida
local GENERATORS_ACTIVE = GameConstants.Game.GeneratorsToRepair -- 5

-- Tempo total de reparo em segundos
local REPAIR_TIME = GameConstants.Game.RepairTime -- 8s

-- Raio de interação (studs) — quão perto o Sobrevivente precisa estar
local INTERACT_RANGE = 6

-- Raio do som de zumbido (studs)
local BUZZ_RADIUS = 40

-- Raio do alerta sonoro (studs) — global para o mapa
local ALERT_RADIUS = 500

-- Intervalo entre skill checks (segundos)
local SKILL_CHECK_MIN_INTERVAL = 3
local SKILL_CHECK_MAX_INTERVAL = 6

-- Duração da janela de skill check (segundos) — tempo total que o jogador tem
local SKILL_CHECK_DURATION = 2.0

-- Bônus de progresso ao acertar skill check (%)
local SKILL_CHECK_BONUS = 5

-- Penalidade de progresso ao errar skill check (%)
local SKILL_CHECK_PENALTY = 10

-- 7 posições possíveis para geradores (serão ajustadas com o mapa real no E4)
-- Posições distribuídas pela mansão em locais estratégicos
local GENERATOR_POSITIONS: {Vector3} = {
	Vector3.new(15, 0, 10),    -- Sala de Estar (1º andar)
	Vector3.new(-12, 0, 8),    -- Cozinha (1º andar)
	Vector3.new(20, 0, -15),   -- Corredor Leste (1º andar)
	Vector3.new(-18, 0, -12),  -- Biblioteca (1º andar)
	Vector3.new(10, 5, 5),     -- Quarto Principal (2º andar)
	Vector3.new(-8, 5, -10),   -- Quarto de Hóspedes (2º andar)
	Vector3.new(0, -5, 0),     -- Porão (subsolo)
}

-- Dificuldade do skill check baseada em geradores completados
-- Cada entrada: {windowHalfWidth} — metade da largura da janela de acerto em segundos
local SKILL_CHECK_DIFFICULTY: {{windowHalfWidth: number}} = {
	{windowHalfWidth = 0.30},  -- 0 geradores completos → janela de ±0.30s
	{windowHalfWidth = 0.25},  -- 1 gerador completo
	{windowHalfWidth = 0.20},  -- 2 geradores completos
	{windowHalfWidth = 0.15},  -- 3 geradores completos
	{windowHalfWidth = 0.10},  -- 4 geradores completos
}

-- ==========================================
-- TIPOS INTERNOS
-- ==========================================

-- Representa o estado de um gerador
-- type GeneratorState = {
--     id: number,                    -- 1 a 7 (índice em GENERATOR_POSITIONS)
--     position: Vector3,             -- posição no mundo
--     isActive: boolean,             -- true se é um dos 5 ativos na partida
--     progress: number,              -- 0 a 100 (% de reparo completo)
--     isCompleted: boolean,          -- true se reparo concluído
--     currentRepairer: Player?,      -- jogador que está reparando (nil se ninguém)
--     repairStartTime: number?,      -- timestamp de quando o reparo começou
--     skillCheckActive: boolean,     -- true se um skill check está ativo agora
--     skillCheckStartTime: number?,  -- timestamp de início do skill check
--     skillCheckTargetTime: number?, -- tempo alvo (centro da janela de acerto)
--     lastSkillCheckTime: number?,   -- timestamp do último skill check
-- }

-- ==========================================
-- SERVIÇO GENERATORSERVICE
-- ==========================================
local GeneratorService = {}
GeneratorService.__index = GeneratorService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
GeneratorService.GeneratorRepaired = Signal.new()     -- params: generatorId, totalRepaired
GeneratorService.AllGeneratorsRepaired = Signal.new()  -- sem parâmetros
GeneratorService.GeneratorAlert = Signal.new()         -- params: generatorPosition
GeneratorService.SkillCheckHit = Signal.new()           -- params: player, generatorId
GeneratorService.SkillCheckMiss = Signal.new()          -- params: player, generatorId

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Referências aos RemoteEvents e serviços
local _gameStateEvent: RemoteEvent? = nil
local _uiSyncEvent: RemoteEvent? = nil
local _playerActionEvent: RemoteEvent? = nil
local _matchService: any = nil

-- Estado de todos os geradores (índice 1-7)
local _generators: {any} = {}

-- Contador de geradores consertados
local _repairedCount: number = 0

-- Se os geradores já foram spawnados nesta partida
local _generatorsSpawned: boolean = false

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
-- @param gameStateEvent — RemoteEvent para estado do jogo
-- @param uiSyncEvent — RemoteEvent para sincronização de HUD
-- @param playerActionEvent — RemoteEvent para ações do jogador
-- @param matchService — Referência ao MatchService
function GeneratorService.Init(
	gameStateEvent: RemoteEvent,
	uiSyncEvent: RemoteEvent,
	playerActionEvent: RemoteEvent,
	matchService: any
)
	_gameStateEvent = gameStateEvent
	_uiSyncEvent = uiSyncEvent
	_playerActionEvent = playerActionEvent
	_matchService = matchService

	-- Inicializa o array de geradores (todos inativos por enquanto)
	for i = 1, #GENERATOR_POSITIONS do
		_generators[i] = {
			id = i,
			position = GENERATOR_POSITIONS[i],
			isActive = false,
			progress = 0,
			isCompleted = false,
			currentRepairer = nil,
			repairStartTime = nil,
			skillCheckActive = false,
			skillCheckStartTime = nil,
			skillCheckTargetTime = nil,
			lastSkillCheckTime = nil,
		}
	end

	print("[CacadaSombria] GeneratorService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function GeneratorService.Start()
	-- Conecta ao sinal de início da partida para spawnar geradores
	_matchService.MatchStarted:Connect(function()
		GeneratorService:_onMatchStarted()
	end)

	-- Conecta ao game loop via Heartbeat
	RunService.Heartbeat:Connect(function(dt: number)
		GeneratorService:_update(dt)
	end)

	print("[CacadaSombria] GeneratorService iniciado.")
end

-- ==========================================
-- SPAWN DE GERADORES
-- ==========================================

-- Chamado quando a partida entra em estado Hunting
-- Seleciona aleatoriamente 5 das 7 posições e ativa os geradores
function GeneratorService:_onMatchStarted()
	print("[CacadaSombria] Spawnando geradores...")

	-- Reseta o estado de todos os geradores
	_repairedCount = 0
	_generatorsSpawned = true

	for i = 1, #_generators do
		local gen = _generators[i]
		gen.isActive = false
		gen.progress = 0
		gen.isCompleted = false
		gen.currentRepairer = nil
		gen.repairStartTime = nil
		gen.skillCheckActive = false
		gen.skillCheckStartTime = nil
		gen.skillCheckTargetTime = nil
		gen.lastSkillCheckTime = nil
	end

	-- Seleciona aleatoriamente 5 posições das 7 disponíveis
	-- Algoritmo: cria lista de índices 1-7, embaralha, pega os primeiros 5
	local indices = {1, 2, 3, 4, 5, 6, 7}
	GeneratorService:_shuffle(indices)

	for i = 1, GENERATORS_ACTIVE do
		local idx = indices[i]
		_generators[idx].isActive = true
		print(string.format("[CacadaSombria] Gerador #%d ativado em (%.0f, %.0f, %.0f)",
			idx,
			GENERATOR_POSITIONS[idx].X,
			GENERATOR_POSITIONS[idx].Y,
			GENERATOR_POSITIONS[idx].Z
		))
	end

	-- Notifica todos os clientes sobre o estado inicial dos geradores
	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.GENERATOR_UPDATE,
			0,
			GENERATORS_ACTIVE
		)
	end

	print(string.format("[CacadaSombria] %d geradores spawnados.", GENERATORS_ACTIVE))
end

-- Embaralha um array in-place (Fisher-Yates)
function GeneratorService:_shuffle(t: {})
	local n = #t
	for i = n, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

-- ==========================================
-- INTERAÇÃO COM GERADOR (REPARO)
-- ==========================================

-- Verifica se um jogador pode começar a reparar um gerador
-- @param player — O jogador (deve ser Sobrevivente)
-- @param generatorId — ID do gerador (1-7)
-- @return boolean, string? — true se pode reparar, ou false + motivo
function GeneratorService:canStartRepair(player: Player, generatorId: number): (boolean, string?)
	-- Verifica se o gerador existe
	if generatorId < 1 or generatorId > #_generators then
		return false, "Gerador inexistente"
	end

	local gen = _generators[generatorId]

	-- Verifica se o gerador está ativo
	if not gen.isActive then
		return false, "Gerador inativo"
	end

	-- Verifica se já foi consertado
	if gen.isCompleted then
		return false, "Gerador já consertado"
	end

	-- Verifica se alguém já está reparando
	if gen.currentRepairer then
		return false, "Gerador já está sendo reparado"
	end

	-- Verifica se o jogador é um Sobrevivente
	local state = _matchService:getPlayerState(player)
	if not state then
		return false, "Jogador sem estado"
	end

	if state.role ~= "Survivor" then
		return false, "Apenas Sobreviventes podem reparar"
	end

	if not state.isAlive then
		return false, "Jogador não está vivo"
	end

	if state.isInCage then
		return false, "Jogador está em jaula"
	end

	-- Verifica distância até o gerador
	if state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - gen.position).Magnitude
			if dist > INTERACT_RANGE then
				return false, string.format("Muito longe (%.1f studs)", dist)
			end
		end
	end

	return true, nil
end

-- Inicia o reparo de um gerador por um Sobrevivente
-- Bloqueia o movimento do jogador durante o reparo
-- @param player — O Sobrevivente
-- @param generatorId — ID do gerador
function GeneratorService:startRepair(player: Player, generatorId: number)
	local ok, reason = GeneratorService:canStartRepair(player, generatorId)
	if not ok then
		print(string.format("[CacadaSombria] %s não pode reparar gerador #%d: %s",
			player.Name, generatorId, reason))
		return
	end

	local gen = _generators[generatorId]
	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Inicia o reparo
	gen.currentRepairer = player
	gen.repairStartTime = os.clock()
	gen.lastSkillCheckTime = os.clock()

	-- Bloqueia o movimento do jogador
	if state.humanoid then
		state.humanoid.WalkSpeed = 0
	end

	-- Notifica o cliente que o reparo começou
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.REPAIR_START,
			generatorId,
			REPAIR_TIME
		)
	end

	-- Ativa o som de zumbido para o gerador (enviar para todos próximos)
	if _uiSyncEvent then
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.GENERATOR_BUZZ,
			generatorId,
			true
		)
	end

	print(string.format("[CacadaSombria] %s iniciou reparo do gerador #%d (progresso: %.0f%%)",
		player.Name, generatorId, gen.progress))
end

-- Cancela o reparo de um gerador (jogador se moveu ou foi interrompido)
-- @param generatorId — ID do gerador
-- @param reason — Motivo do cancelamento ("moveu", "dano", "stun", etc.)
function GeneratorService:cancelRepair(generatorId: number, reason: string?)
	local gen = _generators[generatorId]
	if not gen or not gen.currentRepairer then return end

	local player = gen.currentRepairer
	local state = _matchService:getPlayerState(player)

	-- Restaura a velocidade do jogador
	if state and state.humanoid then
		local baseSpeed = GameConstants.Survivors.Base.Speed
		state.humanoid.WalkSpeed = baseSpeed
	end

	-- Limpa o estado de reparo
	gen.currentRepairer = nil
	gen.repairStartTime = nil
	gen.skillCheckActive = false
	gen.skillCheckStartTime = nil
	gen.skillCheckTargetTime = nil

	-- Notifica o cliente
	if _uiSyncEvent and player then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.REPAIR_STOP,
			generatorId,
			reason or "cancelado"
		)
	end

	-- Desativa o som de zumbido
	if _uiSyncEvent then
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.GENERATOR_BUZZ,
			generatorId,
			false
		)
	end

	print(string.format("[CacadaSombria] Reparo do gerador #%d cancelado (%s). Progresso: %.0f%%",
		generatorId, reason or "desconhecido", gen.progress))
end

-- ==========================================
-- SKILL CHECKS (QTE)
-- ==========================================

-- Inicia um skill check para um gerador sendo reparado
-- Define a janela de acerto baseada na dificuldade progressiva
-- @param generatorId — ID do gerador
function GeneratorService:_startSkillCheck(generatorId: number)
	local gen = _generators[generatorId]
	if not gen or not gen.currentRepairer then return end

	-- Calcula a dificuldade baseada em quantos geradores já foram completados
	local completedCount = _repairedCount
	local diffIdx = math.min(completedCount + 1, #SKILL_CHECK_DIFFICULTY)
	local diff = SKILL_CHECK_DIFFICULTY[diffIdx]
	local windowHalf = diff.windowHalfWidth

	-- Define o tempo alvo (centro da janela) — entre windowHalf e SKILL_CHECK_DURATION - windowHalf
	local targetTime = windowHalf + math.random() * (SKILL_CHECK_DURATION - 2 * windowHalf)

	-- Ativa o skill check
	gen.skillCheckActive = true
	gen.skillCheckStartTime = os.clock()
	gen.skillCheckTargetTime = targetTime

	-- Notifica o cliente para mostrar o QTE visual
	if _uiSyncEvent and gen.currentRepairer then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			gen.currentRepairer,
			UISyncEvent.MESSAGES.SKILL_CHECK_START,
			generatorId,
			SKILL_CHECK_DURATION,
			completedCount -- dificuldade (0-4)
		)
	end

	print(string.format(
		"[CacadaSombria] Skill check iniciado no gerador #%d (dificuldade %d, janela ±%.2fs, alvo %.2fs)",
		generatorId, completedCount, windowHalf, targetTime
	))
end

-- Processa o acerto do skill check (jogador pressionou E durante o QTE)
-- @param player — O jogador
-- @param generatorId — ID do gerador
function GeneratorService:processSkillCheckHit(player: Player, generatorId: number)
	local gen = _generators[generatorId]
	if not gen then return end

	-- Verifica se o jogador é quem está reparando
	if gen.currentRepairer ~= player then
		print(string.format("[CacadaSombria] %s tentou skill check em gerador #%d mas não é o reparador",
			player.Name, generatorId))
		return
	end

	-- Verifica se há um skill check ativo
	if not gen.skillCheckActive or not gen.skillCheckStartTime or not gen.skillCheckTargetTime then
		-- Jogador pressionou E mas não há skill check ativo → ignora (provavelmente iniciou reparo)
		return
	end

	-- Calcula o tempo decorrido desde o início do skill check
	local elapsed = os.clock() - gen.skillCheckStartTime

	-- Verifica se ainda está dentro da janela de duração
	if elapsed > SKILL_CHECK_DURATION then
		-- Skill check já expirou
		GeneratorService:_handleSkillCheckMiss(player, generatorId, "tempo esgotado")
		return
	end

	-- Calcula a distância do tempo alvo
	local diff = math.abs(elapsed - gen.skillCheckTargetTime)

	-- Determina a janela de acerto baseada na dificuldade
	local completedCount = _repairedCount
	local diffIdx = math.min(completedCount + 1, #SKILL_CHECK_DIFFICULTY)
	local windowHalf = SKILL_CHECK_DIFFICULTY[diffIdx].windowHalfWidth

	-- Verifica se acertou
	if diff <= windowHalf then
		-- ACERTOU!
		GeneratorService:_handleSkillCheckHit(player, generatorId)
	else
		-- ERROU!
		GeneratorService:_handleSkillCheckMiss(player, generatorId,
			string.format("fora da janela (%.2fs do alvo)", diff))
	end
end

-- Handler para skill check bem-sucedido
function GeneratorService:_handleSkillCheckHit(player: Player, generatorId: number)
	local gen = _generators[generatorId]
	if not gen then return end

	-- Aplica bônus de progresso
	local bonus = SKILL_CHECK_BONUS
	gen.progress = math.min(100, gen.progress + bonus)

	-- Desativa o skill check
	gen.skillCheckActive = false
	gen.skillCheckStartTime = nil
	gen.skillCheckTargetTime = nil

	-- Notifica o cliente
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.SKILL_CHECK_RESULT,
			generatorId,
			true, -- isHit
			bonus
		)
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.SKILL_CHECK_END,
			generatorId
		)
	end

	-- Dispara sinal
	GeneratorService.SkillCheckHit:Fire(player, generatorId)

	print(string.format("[CacadaSombria] %s ACERTOU skill check no gerador #%d (+%.0f%% → %.0f%%)",
		player.Name, generatorId, bonus, gen.progress))
end

-- Handler para skill check falho
function GeneratorService:_handleSkillCheckMiss(player: Player, generatorId: number, reason: string?)
	local gen = _generators[generatorId]
	if not gen then return end

	-- Aplica penalidade de progresso (sem deixar negativo)
	local penalty = SKILL_CHECK_PENALTY
	gen.progress = math.max(0, gen.progress - penalty)

	-- Desativa o skill check
	gen.skillCheckActive = false
	gen.skillCheckStartTime = nil
	gen.skillCheckTargetTime = nil

	-- Notifica o cliente
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.SKILL_CHECK_RESULT,
			generatorId,
			false, -- isHit
			-penalty
		)
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.SKILL_CHECK_END,
			generatorId
		)
	end

	-- ALERTA GLOBAL: notifica todos os jogadores (especialmente o Caçador)
	if _uiSyncEvent then
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.GENERATOR_ALERT,
			gen.position
		)
	end

	-- Dispara sinais
	GeneratorService.SkillCheckMiss:Fire(player, generatorId)
	GeneratorService.GeneratorAlert:Fire(gen.position)

	print(string.format("[CacadaSombria] %s ERROU skill check no gerador #%d (-%.0f%% → %.0f%%) [%s]",
		player.Name, generatorId, penalty, gen.progress, reason or "desconhecido"))
end

-- ==========================================
-- GAME LOOP (UPDATE)
-- ==========================================

-- Atualização principal, chamada a cada frame via RunService.Heartbeat
-- Processa progresso de reparo e inicia skill checks
function GeneratorService:_update(dt: number)
	-- Só processa durante a caçada
	local matchState = _matchService.GetState and _matchService.GetState()
	if matchState ~= "Hunting" then return end

	local now = os.clock()

	for i = 1, #_generators do
		local gen = _generators[i]

		-- Pula geradores inativos ou já completados
		if not gen.isActive or gen.isCompleted then
			-- Se alguém ainda está referenciado como reparador, limpa
			if gen.currentRepairer then
				GeneratorService:cancelRepair(i, "gerador completado/inativo")
			end
			goto skip
		end

		-- Se não há ninguém reparando, pula
		if not gen.currentRepairer then
			goto skip
		end

		-- Verifica se o reparador ainda é válido
		local player = gen.currentRepairer
		local state = _matchService:getPlayerState(player)
		if not state or not state.isAlive or state.isInCage then
			GeneratorService:cancelRepair(i, "jogador inválido")
			goto skip
		end

		-- Verifica se o jogador se moveu (anti-cheat: WalkSpeed foi restaurado)
		if state.humanoid and state.humanoid.WalkSpeed > 0 then
			GeneratorService:cancelRepair(i, "jogador se moveu")
			goto skip
		end

		-- === PROGRESSO DE REPARO ===
		-- Avança o progresso baseado no delta time
		local progressPerSec = 100 / REPAIR_TIME -- 12.5% por segundo para 8s
		gen.progress = math.min(100, gen.progress + progressPerSec * dt)

		-- Notifica o cliente sobre o progresso atual
		if _uiSyncEvent then
			UISyncEvent.sendToClient(
				_uiSyncEvent,
				player,
				UISyncEvent.MESSAGES.GENERATOR_PROGRESS,
				i,
				gen.progress
			)
		end

		-- === SKILL CHECKS ===
		-- Inicia um skill check aleatoriamente durante o reparo
		if not gen.skillCheckActive then
			local timeSinceLastCheck = now - (gen.lastSkillCheckTime or 0)
			if timeSinceLastCheck >= SKILL_CHECK_MIN_INTERVAL then
				-- Chance de iniciar um skill check a cada intervalo
				-- Aproximadamente 1 check a cada 3-6 segundos
				local chance = dt / (SKILL_CHECK_MAX_INTERVAL - SKILL_CHECK_MIN_INTERVAL)
				if math.random() < chance then
					gen.lastSkillCheckTime = now
					GeneratorService:_startSkillCheck(i)
				end
			end
		else
			-- Verifica se o skill check expirou
			local skillElapsed = now - (gen.skillCheckStartTime or now)
			if skillElapsed > SKILL_CHECK_DURATION then
				-- Skill check expirou sem resposta → erro automático
				GeneratorService:_handleSkillCheckMiss(
					gen.currentRepairer,
					i,
					"tempo esgotado"
				)
			end
		end

		-- === CONCLUSÃO DO REPARO ===
		if gen.progress >= 100 then
			GeneratorService:_completeRepair(i)
		end

		::skip::
	end
end

-- ==========================================
-- CONCLUSÃO DE REPARO
-- ==========================================

-- Finaliza o reparo de um gerador
-- @param generatorId — ID do gerador
function GeneratorService:_completeRepair(generatorId: number)
	local gen = _generators[generatorId]
	if not gen or gen.isCompleted then return end

	gen.isCompleted = true
	gen.progress = 100
	_repairedCount = _repairedCount + 1

	-- Libera o jogador que estava reparando
	if gen.currentRepairer then
		local player = gen.currentRepairer
		local state = _matchService:getPlayerState(player)
		if state and state.humanoid then
			state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
		end

		-- Notifica o cliente
		if _uiSyncEvent then
			UISyncEvent.sendToClient(
				_uiSyncEvent,
				player,
				UISyncEvent.MESSAGES.REPAIR_STOP,
				generatorId,
				"completado"
			)
		end
	end

	gen.currentRepairer = nil
	gen.repairStartTime = nil
	gen.skillCheckActive = false

	-- Desativa o som de zumbido
	if _uiSyncEvent then
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.GENERATOR_BUZZ,
			generatorId,
			false
		)
	end

	-- Notifica todos os clientes
	if _gameStateEvent then
		GameStateEvent.sendToAll(
			_gameStateEvent,
			GameStateEvent.MESSAGES.GENERATOR_REPAIRED,
			generatorId,
			_repairedCount,
			GENERATORS_ACTIVE
		)
	end

	-- Dispara sinal
	GeneratorService.GeneratorRepaired:Fire(generatorId, _repairedCount)

	print(string.format("[CacadaSombria] Gerador #%d CONSERTADO! (%d/%d)",
		generatorId, _repairedCount, GENERATORS_ACTIVE))

	-- Verifica se TODOS os geradores foram consertados
	if _repairedCount >= GENERATORS_ACTIVE then
		if _gameStateEvent then
			GameStateEvent.sendToAll(
				_gameStateEvent,
				GameStateEvent.MESSAGES.GENERATOR_ALL_REPAIRED
			)
		end
		GeneratorService.AllGeneratorsRepaired:Fire()
		print("[CacadaSombria] TODOS OS GERADORES CONSERTADOS! Portão pode ser ativado.")
	end
end

-- ==========================================
-- FUNÇÕES UTILITÁRIAS DE CONSULTA
-- ==========================================

-- Retorna o número de geradores consertados
function GeneratorService:getRepairedCount(): number
	return _repairedCount
end

-- Retorna se todos os geradores foram consertados
function GeneratorService:areAllRepaired(): boolean
	return _repairedCount >= GENERATORS_ACTIVE
end

-- Retorna a posição de um gerador pelo ID
function GeneratorService:getGeneratorPosition(generatorId: number): Vector3?
	local gen = _generators[generatorId]
	if gen then
		return gen.position
	end
	return nil
end

-- Retorna o progresso de um gerador
function GeneratorService:getGeneratorProgress(generatorId: number): number?
	local gen = _generators[generatorId]
	if gen then
		return gen.progress
	end
	return nil
end

-- Retorna se um gerador está sendo reparado
function GeneratorService:isBeingRepaired(generatorId: number): boolean
	local gen = _generators[generatorId]
	return gen and gen.currentRepairer ~= nil
end

-- ==========================================
-- CLEANUP
-- ==========================================

function GeneratorService:Destroy()
	-- Cancela todos os reparos ativos
	for i = 1, #_generators do
		if _generators[i].currentRepairer then
			GeneratorService:cancelRepair(i, "serviço destruído")
		end
	end

	-- Limpa os sinais
	GeneratorService.GeneratorRepaired:Destroy()
	GeneratorService.AllGeneratorsRepaired:Destroy()
	GeneratorService.GeneratorAlert:Destroy()
	GeneratorService.SkillCheckHit:Destroy()
	GeneratorService.SkillCheckMiss:Destroy()

	table.clear(_generators)
	_generatorsSpawned = false
	_repairedCount = 0

	print("[CacadaSombria] GeneratorService destruído.")
end

return GeneratorService
