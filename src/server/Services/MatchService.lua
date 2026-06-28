--!strict
--[[
  MatchService.lua
  Serviço que gerencia o fluxo da partida e o estado de cada jogador.
  
  Responsável por:
  - Máquina de estados da partida (Waiting → Preparing → Hunting → Ending)
  - Registro de jogadores no lobby
  - Atribuição de papéis (Killer / Survivor)
  - Gerenciamento de HP, stamina, estado de movimento
  - Validação de ações dos jogadores
  - Transições entre estados

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo por performance)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- CONSTANTES
-- ==========================================
local STAMINA_MAX = 100
local STAMINA_CONSUME_RATE = 20        -- por segundo correndo
local STAMINA_REGEN_RATE = 10          -- por segundo parado/andando
local STAMINA_EXHAUSTED_COOLDOWN = 3   -- segundos sem poder correr após esgotar

local MATCH_DURATION = GameConstants.Game.MatchDuration -- 900s (15 min)
local PREPARE_DURATION = 5             -- 5 segundos de preparação

-- ==========================================
-- ESTADOS DA PARTIDA
-- ==========================================
local MatchState = {
	Waiting = "Waiting",       -- Aguardando jogadores no lobby
	Selecting = "Selecting",   -- Seleção de personagens (Épico E7)
	Preparing = "Preparing",   -- Timer de preparação antes da caçada
	Hunting = "Hunting",       -- Caçada ativa (loop principal)
	Ending = "Ending",         -- Resultado, retorna ao lobby
}

-- ==========================================
-- TRANSIÇÕES VÁLIDAS ENTRE ESTADOS
-- ==========================================
-- Cada estado só pode transitar para os estados listados aqui.
-- Isso evita bugs de transições impossíveis (ex: Ending → Hunting).
local VALID_TRANSITIONS: {[string]: {string}} = {
	[MatchState.Waiting]   = {MatchState.Selecting},
	[MatchState.Selecting] = {MatchState.Preparing, MatchState.Waiting},
	[MatchState.Preparing] = {MatchState.Hunting},
	[MatchState.Hunting]   = {MatchState.Ending},
	[MatchState.Ending]    = {MatchState.Waiting},
}

-- ==========================================
-- SERVIÇO MATCHSERVICE
-- ==========================================
local MatchService = {}
MatchService.__index = MatchService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
-- Outros serviços podem se conectar a estes sinais para reagir a eventos
MatchService.MatchStarted = Signal.new()
MatchService.MatchEnded = Signal.new()
MatchService.PlayerRoleAssigned = Signal.new()
MatchService.PlayerDied = Signal.new()
MatchService.PlayerDowned = Signal.new()    -- Épico E6: Sobrevivente derrubado (HP=0, mas ainda vivo)
MatchService.StaminaChanged = Signal.new()
MatchService.SelectStarted = Signal.new()          -- Épico E7: fase de seleção iniciou
MatchService.SelectTimerExpired = Signal.new()     -- Épico E7: timer de seleção esgotou
MatchService.PlayerDisconnected = Signal.new()     -- Épico E7: jogador desconectou
MatchService.ReturnToLobby = Signal.new()          -- Épico E7: retorno ao lobby após partida

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Armazena o estado de cada jogador ativo na partida
-- Chave: player.UserId
-- Valor: tabela PlayerState (ver definição abaixo)
local _playerStates: {[number]: any} = {}

-- Estado atual da máquina de estados
local _currentState: string = MatchState.Waiting

-- Referências aos RemoteEvents (setados durante Init)
local _gameStateEvent: RemoteEvent? = nil
local _playerActionEvent: RemoteEvent? = nil

-- Tempo restante da partida em segundos
local _matchTimeRemaining: number = MATCH_DURATION

-- ==========================================
-- TIPO: PlayerState
-- ==========================================
-- Estrutura que representa o estado de um jogador no servidor
-- type PlayerState = {
--     userId: number,
--     player: Player,
--     character: Model?,
--     humanoid: Humanoid?,
--     role: "Killer" | "Survivor" | nil,   -- papel na partida
--     className: string?,                    -- classe escolhida (ex: "Soldado", nil para Killer)
--     hp: number,
--     maxHp: number,
--     isAlive: boolean,
--     isDowned: boolean,
--     isInCage: boolean,
--     stamina: number,                       -- 0 a 100
--     isSprinting: boolean,
--     isCrouching: boolean,
--     isExhausted: boolean,                  -- true se esgotou stamina e está no cooldown
--     exhaustedTimer: number,                -- timestamp de quando poderá correr de novo
--     isHiding: boolean,                     -- true se está dentro de um esconderijo
--     hidingSpot: Instance?,                 -- referência ao esconderijo
--     hidingEnterTime: number?,              -- timestamp de quando entrou
--     fury: number,                          -- 0 a 100 (apenas Killer)
--     isRageActive: boolean,                 -- apenas Killer
--     cooldowns: {[string]: number},         -- nome_habilidade → timestamp de quando expira
--     connections: {RBXScriptConnection},    -- conexões para cleanup
--
--     -- Épico E6: Captura
--     isCarrying: boolean?,                  -- Killer está carregando Sobrevivente?
--     carriedSurvivorId: number?,            -- UserId do Sobrevivente carregado
--     carriedByKillerId: number?,            -- UserId do Killer que carrega (Sobrevivente)
--     bleedOutTimer: number?,                -- tempo restante de sangramento (derrubado)
--     cageRescueCount: number,               -- resgates de jaula já recebidos
--     wiggleProgress: number,                -- progresso do debate (0 a 100)
--     isInvincible: boolean?,                -- invulnerável temporário
--     invincibleTimer: number?,              -- timestamp do fim da invulnerabilidade
-- }

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
function MatchService.Init(gameStateEvent: RemoteEvent, playerActionEvent: RemoteEvent)
	_gameStateEvent = gameStateEvent
	_playerActionEvent = playerActionEvent

	-- Registra o handler para ações dos jogadores
	_playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
		MatchService:_handlePlayerAction(player, action, ...)
	end)

	print("[CacadaSombria] MatchService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function MatchService.Start()
	-- Configura listeners de entrada/saída de jogadores
	Players.PlayerAdded:Connect(function(player: Player)
		MatchService:_onPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		MatchService:_onPlayerRemoving(player)
	end)

	-- Conecta o game loop ao Heartbeat
	RunService.Heartbeat:Connect(function(dt: number)
		MatchService:_update(dt)
	end)

	print("[CacadaSombria] MatchService iniciado. Aguardando jogadores...")
end

-- ==========================================
-- GERENCIAMENTO DE JOGADORES
-- ==========================================

-- Chamado quando um jogador entra no servidor
function MatchService:_onPlayerAdded(player: Player)
	print(string.format("[CacadaSombria] Jogador entrou: %s (UserId: %d)",
		player.Name, player.UserId))

	-- Aguarda o character spawnar antes de configurar
	-- CharacterAdded dispara quando o jogador ganha um personagem (spawn ou respawn)
	player.CharacterAdded:Connect(function(character: Model)
		MatchService:_onCharacterAdded(player, character)
	end)

	-- Se o jogador JÁ tem um character (raro, mas possível)
	if player.Character then
		task.spawn(function()
			MatchService:_onCharacterAdded(player, player.Character)
		end)
	end

	-- Cria o estado inicial do jogador (papel ainda não definido)
	_playerStates[player.UserId] = {
		userId = player.UserId,
		player = player,
		character = player.Character,
		humanoid = nil,
		role = nil,
		className = nil,
		hp = 0,
		maxHp = 0,
		isAlive = true,
		isDowned = false,
		isInCage = false,
		stamina = STAMINA_MAX,
		isSprinting = false,
		isCrouching = false,
		isExhausted = false,
		exhaustedTimer = 0,
		isHiding = false,
		hidingSpot = nil,
		hidingEnterTime = nil,
		fury = 0,
		isRageActive = false,
		cooldowns = {},
		connections = {},

		-- Épico E6: Captura
		isCarrying = false,              -- Killer está carregando um Sobrevivente?
		carriedSurvivorId = nil,         -- UserId do Sobrevivente carregado (Killer)
		carriedByKillerId = nil,         -- UserId do Killer que está carregando (Sobrevivente)
		bleedOutTimer = nil,             -- tempo restante de sangramento (Sobrevivente derrubado)
		cageRescueCount = 0,             -- quantas vezes este Sobrevivente foi resgatado da jaula
		wiggleProgress = 0,              -- progresso do debate (0 a 100)
		isInvincible = false,            -- invulnerável após resgate
		invincibleTimer = nil,           -- timestamp até o fim da invulnerabilidade
	}
end

-- Chamado quando o character de um jogador é criado/respawnado
function MatchService:_onCharacterAdded(player: Player, character: Model)
	local state = _playerStates[player.UserId]
	if not state then return end

	-- Atualiza a referência ao character
	state.character = character

	-- Aguarda o Humanoid ficar disponível (pode levar alguns frames)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		warn(string.format("[CacadaSombria] Humanoid não encontrado para %s", player.Name))
		return
	end

	state.humanoid = humanoid

	-- Configura a velocidade base de acordo com o papel
	if state.role == "Killer" then
		humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed -- 26
	elseif state.role == "Survivor" then
		humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed -- 22
	end

	-- Configura o estado de agachamento
	humanoid.AutoRotate = true

	print(string.format("[CacadaSombria] Character spawnado para %s (papel: %s)",
		player.Name, state.role or "não definido"))
end

-- Chamado quando um jogador sai do servidor
function MatchService:_onPlayerRemoving(player: Player)
	print(string.format("[CacadaSombria] Jogador saiu: %s", player.Name))

	local state = _playerStates[player.UserId]

	-- Dispara sinal de desconexão ANTES de limpar o estado
	if state then
		MatchService.PlayerDisconnected:Fire(player, state.role, _currentState)
	end

	-- Limpa as conexões do jogador
	if state and state.connections then
		for _, conn in state.connections do
			conn:Disconnect()
		end
	end

	-- Remove o estado do jogador
	_playerStates[player.UserId] = nil
end

-- ==========================================
-- ATRIBUIÇÃO DE PAPÉIS
-- ==========================================

-- Atribui um papel (Killer ou Survivor) e uma classe a um jogador
-- @param player — O jogador
-- @param role — "Killer" ou "Survivor"
-- @param className — Nome da classe (ex: "Soldado", nil para Killer)
function MatchService:assignRole(player: Player, role: string, className: string?)
	local state = _playerStates[player.UserId]
	if not state then
		warn(string.format("[CacadaSombria] Tentativa de atribuir papel a jogador sem estado: %s",
			player.Name))
		return
	end

	state.role = role
	state.className = className

	-- Configura HP base de acordo com o papel e classe
	if role == "Killer" then
		state.maxHp = GameConstants.Killers.Distorcido.HP -- 1100
		state.hp = state.maxHp
		state.fury = 0
	elseif role == "Survivor" then
		-- Busca o HP da classe específica nos GameConstants
		local classData = GameConstants.Survivors[className]
		if classData then
			state.maxHp = classData.HP
		else
			-- Fallback para HP base se a classe não for encontrada
			state.maxHp = GameConstants.Survivors.Base.HP -- 120
			warn(string.format("[CacadaSombria] Classe '%s' não encontrada, usando HP base", className or "nil"))
		end
		state.hp = state.maxHp
		state.stamina = STAMINA_MAX
	end

	-- Atualiza a velocidade se o character já existe
	if state.humanoid then
		if role == "Killer" then
			state.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
		else
			state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
		end
	end

	-- Notifica o cliente sobre seu papel
	if _gameStateEvent then
		GameStateEvent.sendToClient(_gameStateEvent, player, GameStateEvent.MESSAGES.ROLE_ASSIGN, role, className)
	end

	-- Dispara o sinal para outros serviços
	MatchService.PlayerRoleAssigned:Fire(player, role, className)

	print(string.format("[CacadaSombria] Papel atribuído: %s é %s (%s)",
		player.Name, role, className or "genérico"))
end

-- ==========================================
-- MÁQUINA DE ESTADOS DA PARTIDA
-- ==========================================

-- Retorna o estado atual da partida
function MatchService.GetState(): string
	return _currentState
end

-- Tenta fazer a transição para um novo estado
-- Retorna true se a transição foi bem-sucedida
function MatchService:transitionTo(newState: string): boolean
	local allowed = VALID_TRANSITIONS[_currentState]
	if not allowed then
		warn(string.format("[CacadaSombria] Estado atual '%s' não tem transições definidas", _currentState))
		return false
	end

	-- Verifica se a transição é permitida
	local isAllowed = false
	for _, s in allowed do
		if s == newState then
			isAllowed = true
			break
		end
	end

	if not isAllowed then
		warn(string.format("[CacadaSombria] Transição inválida: %s → %s", _currentState, newState))
		return false
	end

	-- Executa a transição
	local oldState = _currentState
	_currentState = newState

	print(string.format("[CacadaSombria] Estado da partida: %s → %s", oldState, newState))

	-- Ações específicas para cada transição
	if newState == MatchState.Selecting then
		MatchService:_onEnterSelecting()
	elseif newState == MatchState.Preparing then
		MatchService:_onEnterPreparing()
	elseif newState == MatchState.Hunting then
		MatchService:_onEnterHunting()
	elseif newState == MatchState.Ending then
		MatchService:_onEnterEnding()
	elseif newState == MatchState.Waiting then
		MatchService:_onEnterWaiting()
	end

	-- Notifica clientes sobre o novo estado
	if _gameStateEvent then
		GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.MATCH_STATE, newState)
	end

	return true
end

-- Handlers de entrada para cada estado

function MatchService:_onEnterSelecting()
	print("[CacadaSombria] Fase de SELEÇÃO iniciada — jogadores escolhem personagens (15s)")
	-- A seleção tem 15 segundos. Quem não escolher recebe classe aleatória.
	-- O LobbyService gerencia a lógica detalhada; aqui apenas disparamos o timer.
	task.delay(15, function()
		if _currentState == MatchState.Selecting then
			print("[CacadaSombria] Timer de seleção esgotado — atribuindo classes não escolhidas")
			-- LobbyService:forceAssignUnselected() — será chamado via sinal
			MatchService.SelectTimerExpired:Fire()
		end
	end)
	MatchService.SelectStarted:Fire()
end

function MatchService:_onEnterPreparing()
	print("[CacadaSombria] Fase de PREPARAÇÃO iniciada — aguardando 5s...")
	_matchTimeRemaining = MATCH_DURATION

	-- Timer de 5 segundos antes de iniciar a caçada
	task.delay(PREPARE_DURATION, function()
		if _currentState == MatchState.Preparing then
			MatchService:transitionTo(MatchState.Hunting)
		end
	end)
end

function MatchService:_onEnterHunting()
	print("[CacadaSombria] A CAÇADA COMEÇOU!")
	MatchService.MatchStarted:Fire()
end

function MatchService:_onEnterEnding()
	print("[CacadaSombria] Partida encerrada!")
	MatchService.MatchEnded:Fire()

	-- Após 5 segundos, volta ao lobby
	task.delay(5, function()
		if _currentState == MatchState.Ending then
			MatchService:transitionTo(MatchState.Waiting)
		end
	end)
end

function MatchService:_onEnterWaiting()
	print("[CacadaSombria] Retornando ao lobby. Aguardando jogadores...")
	-- Limpa estados dos jogadores
	MatchService:_resetAllPlayerStates()
	-- Dispara sinal de retorno ao lobby (Épico E7)
	MatchService.ReturnToLobby:Fire()
end

-- Reseta o estado de todos os jogadores para uma nova partida
function MatchService:_resetAllPlayerStates()
	for userId, state in _playerStates do
		state.role = nil
		state.className = nil
		state.hp = 0
		state.maxHp = 0
		state.isAlive = true
		state.isDowned = false
		state.isInCage = false
		state.stamina = STAMINA_MAX
		state.isSprinting = false
		state.isCrouching = false
		state.isExhausted = false
		state.exhaustedTimer = 0
		state.isHiding = false
		state.fury = 0
		state.isRageActive = false
		table.clear(state.cooldowns)

		-- Épico E6: resetar estado de captura
		state.isCarrying = false
		state.carriedSurvivorId = nil
		state.carriedByKillerId = nil
		state.bleedOutTimer = nil
		state.cageRescueCount = 0
		state.wiggleProgress = 0
		state.isInvincible = false
		state.invincibleTimer = nil
	end
end

-- ==========================================
-- SISTEMA DE STAMINA
-- ==========================================

-- Consome stamina ao correr. Chamado a cada frame de update.
-- @param state — PlayerState do jogador
-- @param dt — delta time (tempo desde o último frame)
function MatchService:_consumeStamina(state: any, dt: number)
	-- Apenas Sobreviventes têm stamina
	if state.role ~= "Survivor" then return end

	-- Sobrevivente derrubado não pode correr
	if state.isDowned then
		state.isSprinting = false
		return
	end

	-- Se não está correndo, regenera stamina
	if not state.isSprinting then
		-- Regenera stamina (se não estiver esgotado)
		if not state.isExhausted then
			state.stamina = math.min(state.stamina + STAMINA_REGEN_RATE * dt, STAMINA_MAX)
		end
		return
	end

	-- Se está exausto, verifica se o cooldown já passou
	if state.isExhausted then
		if os.clock() >= state.exhaustedTimer then
			-- Cooldown terminou, pode correr novamente
			state.isExhausted = false
			print(string.format("[CacadaSombria] %s se recuperou da exaustão", state.player.Name))
		else
			-- Ainda não pode correr — força o jogador a andar
			state.isSprinting = false
			if state.humanoid then
				local baseSpeed = GameConstants.Survivors.Base.Speed
				state.humanoid.WalkSpeed = baseSpeed
			end
			return
		end
	end

	-- Consome stamina
	state.stamina = math.max(state.stamina - STAMINA_CONSUME_RATE * dt, 0)

	-- Notifica o cliente sobre a stamina atual
	if _gameStateEvent and state.stamina then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			state.player,
			GameStateEvent.MESSAGES.STAMINA_UPDATE,
			state.stamina,
			STAMINA_MAX
		)
	end

	-- Verifica se esgotou a stamina
	if state.stamina <= 0 then
		state.isExhausted = true
		state.exhaustedTimer = os.clock() + STAMINA_EXHAUSTED_COOLDOWN
		state.isSprinting = false

		-- Reduz velocidade para a base
		if state.humanoid then
			state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
		end

		print(string.format("[CacadaSombria] %s esgotou a stamina! Recuperação em %.1fs",
			state.player.Name, STAMINA_EXHAUSTED_COOLDOWN))
	end
end

-- ==========================================
-- VALIDAÇÃO DE AÇÕES
-- ==========================================

-- Handler central de ações recebidas do cliente
-- Toda ação passa por validação antes de ser aplicada
function MatchService:_handlePlayerAction(player: Player, action: string, ...: any)
	local state = _playerStates[player.UserId]
	if not state then
		warn(string.format("[CacadaSombria] Ação '%s' de jogador sem estado: %s", action, player.Name))
		return
	end

	-- Verificações básicas de segurança
	-- 1. O jogador está na partida e tem papel definido? (exceto ações de lobby)
	if action ~= "SelectRole" and action ~= "ReadyUp" then
		if not state.role then return end
	end

	-- 2. O jogador está vivo?
	if not state.isAlive then
		-- Apenas ações permitidas quando morto
		if action ~= "Wiggle" then
			return
		end
	end

	-- 2b. O jogador está derrubado (Down)?
	-- Apenas a ação Wiggle é permitida enquanto derrubado
	if state.isDowned and action ~= "Wiggle" then
		return
	end

	-- 3. O jogador está em jaula?
	if state.isInCage then return end

	-- 4. O jogador está escondido? (ações limitadas enquanto escondido)
	if state.isHiding and action ~= PlayerActionEvent.EXIT_HIDING then
		return
	end

	-- ============================
	-- ROTEAMENTO POR TIPO DE AÇÃO
	-- ============================

	if action == "Move" then
		-- Movimento é primariamente client-side (Humanoid), servidor só valida
		-- O servidor pode aplicar correções se detectar speed hack
		-- Por enquanto, apenas registramos (anti-cheat será refinado no E9)
		MatchService:_validateMovement(player, ...)

	elseif action == "SprintStart" then
		MatchService:_handleSprintStart(state)

	elseif action == "SprintStop" then
		MatchService:_handleSprintStop(state)

	elseif action == "CrouchToggle" then
		MatchService:_handleCrouchToggle(state)

	elseif action == "EnterHiding" then
		local hidingSpot: Instance = ...
		MatchService:_handleEnterHiding(state, hidingSpot)

	elseif action == "ExitHiding" then
		MatchService:_handleExitHiding(state)

	elseif action == "Interact" then
		-- Interação genérica (será expandida em épicos futuros)
		local target: Instance = ...
		MatchService:_handleInteract(state, target)

	elseif action == "CarryPickup" or action == "CageDeposit"
		or action == "RescueStart" or action == "Wiggle" then
		-- Ações de captura — tratadas pelo CaptureEvents (Épico E6)
		-- MatchService apenas as reconhece; não faz processamento adicional
		return

	else
		-- Ação não reconhecida
		warn(string.format("[CacadaSombria] Ação não reconhecida: '%s' de %s", action, player.Name))
	end
end

-- ==========================================
-- HANDLERS ESPECÍFICOS DE AÇÃO
-- ==========================================

-- Valida movimento (anti-speed hack básico)
function MatchService:_validateMovement(player: Player, ...)
	-- Placeholder para validação de movimento
	-- No MVP, confiamos no Humanoid do cliente com verificação periódica
	-- Anti-cheat completo será implementado no Épico E9
end

-- Inicia sprint (corrida)
function MatchService:_handleSprintStart(state: any)
	-- Apenas Sobreviventes podem correr
	if state.role ~= "Survivor" then return end

	-- Derrubado não pode correr
	if state.isDowned then return end

	-- Verifica se está exausto
	if state.isExhausted then
		print(string.format("[CacadaSombria] %s tentou correr mas está exausto", state.player.Name))
		return
	end

	-- Verifica se tem stamina
	if state.stamina <= 0 then
		state.isExhausted = true
		state.exhaustedTimer = os.clock() + STAMINA_EXHAUSTED_COOLDOWN
		return
	end

	-- Ativa sprint
	state.isSprinting = true

	-- Aumenta a velocidade (velocidade base + bônus de sprint)
	if state.humanoid then
		local sprintSpeed = GameConstants.Survivors.Base.Speed + GameConstants.Survivors.Base.Stamina_Speed_Bonus
		state.humanoid.WalkSpeed = sprintSpeed -- 22 + 2 = 24
	end

	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			state.player,
			GameStateEvent.MESSAGES.SPRINT_STATE,
			true
		)
	end
end

-- Para sprint (corrida)
function MatchService:_handleSprintStop(state: any)
	-- Apenas Sobreviventes
	if state.role ~= "Survivor" then return end

	state.isSprinting = false

	-- Retorna à velocidade base
	if state.humanoid then
		state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed -- 22
	end

	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			state.player,
			GameStateEvent.MESSAGES.SPRINT_STATE,
			false
		)
	end
end

-- Alterna estado de agachamento (crouch toggle)
function MatchService:_handleCrouchToggle(state: any)
	-- Ambos Killer e Survivor podem agachar
	state.isCrouching = not state.isCrouching

	if state.isCrouching then
		-- Reduz a velocidade ao agachar (40% da velocidade base)
		if state.humanoid then
			local crouchSpeed: number
			if state.role == "Killer" then
				crouchSpeed = GameConstants.Killers.Distorcido.Speed * 0.4
			else
				crouchSpeed = GameConstants.Survivors.Base.Speed * 0.4
			end
			state.humanoid.WalkSpeed = crouchSpeed
		end
		print(string.format("[CacadaSombria] %s agachou", state.player.Name))
	else
		-- Retorna à velocidade normal
		if state.humanoid then
			local baseSpeed: number
			if state.role == "Killer" then
				baseSpeed = GameConstants.Killers.Distorcido.Speed
			elseif state.isSprinting then
				baseSpeed = GameConstants.Survivors.Base.Speed + GameConstants.Survivors.Base.Stamina_Speed_Bonus
			else
				baseSpeed = GameConstants.Survivors.Base.Speed
			end
			state.humanoid.WalkSpeed = baseSpeed
		end
		print(string.format("[CacadaSombria] %s levantou", state.player.Name))
	end

	-- Notifica o cliente
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			state.player,
			GameStateEvent.MESSAGES.CROUCH_STATE,
			state.isCrouching
		)
	end
end

-- Entra em um esconderijo
function MatchService:_handleEnterHiding(state: any, hidingSpot: Instance?)
	-- Apenas Sobreviventes podem se esconder
	if state.role ~= "Survivor" then return end

	-- Já está escondido?
	if state.isHiding then return end

	-- Verifica se o esconderijo é válido
	if not hidingSpot then
		warn("[CacadaSombria] Tentativa de entrar em esconderijo sem referência")
		return
	end

	-- Verifica distância até o esconderijo (máximo 5 studs)
	if state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - hidingSpot:GetPivot().Position).Magnitude
			if dist > 5 then
				print(string.format("[CacadaSombria] %s muito longe do esconderijo (%.1f studs)",
					state.player.Name, dist))
				return
			end
		end
	end

	-- Inicia a entrada no esconderijo (1 segundo de animação)
	print(string.format("[CacadaSombria] %s está entrando em um esconderijo...", state.player.Name))

	task.delay(1, function()
		-- Verifica se o jogador ainda está no jogo e o esconderijo ainda é válido
		if not _playerStates[state.userId] then return end
		if not hidingSpot or not hidingSpot.Parent then return end

		state.isHiding = true
		state.hidingSpot = hidingSpot
		state.hidingEnterTime = os.clock()

		-- Torna o personagem invisível para outros jogadores
		if state.character then
			for _, part: Instance in state.character:GetChildren() do
				if part:IsA("BasePart") then
					part.Transparency = 1 -- Totalmente transparente
				end
			end
		end

		print(string.format("[CacadaSombria] %s entrou no esconderijo", state.player.Name))
	end)
end

-- Sai de um esconderijo
function MatchService:_handleExitHiding(state: any)
	if not state.isHiding then return end

	print(string.format("[CacadaSombria] %s está saindo do esconderijo...", state.player.Name))

	task.delay(1, function()
		if not _playerStates[state.userId] then return end

		state.isHiding = false
		state.hidingSpot = nil
		state.hidingEnterTime = nil

		-- Restaura a visibilidade do personagem
		if state.character then
			for _, part: Instance in state.character:GetChildren() do
				if part:IsA("BasePart") then
					part.Transparency = 0 -- Totalmente visível
				end
			end
		end

		print(string.format("[CacadaSombria] %s saiu do esconderijo", state.player.Name))
	end)
end

-- Lida com interação genérica (E para interagir)
function MatchService:_handleInteract(state: any, target: Instance?)
	-- Placeholder para interações (geradores, jaulas, portões)
	-- Será implementado nos épicos E5 (Geradores) e E6 (Captura)
	if state.role == "Survivor" then
		print(string.format("[CacadaSombria] %s interagiu com %s", state.player.Name, target and target.Name or "desconhecido"))
	elseif state.role == "Killer" then
		print(string.format("[CacadaSombria] Caçador %s interagiu com %s", state.player.Name, target and target.Name or "desconhecido"))
	end
end

-- ==========================================
-- SISTEMA DE DANO (BÁSICO PARA E1)
-- ==========================================

-- Aplica dano a um jogador
-- @param player — O jogador alvo
-- @param amount — Quantidade de dano
function MatchService:applyDamage(player: Player, amount: number)
	local state = _playerStates[player.UserId]
	if not state then return end
	if not state.isAlive then return end

	-- Se o jogador já está derrubado, não recebe mais dano
	if state.isDowned then return end

	state.hp = math.max(0, state.hp - amount)

	-- Notifica o cliente sobre o HP atualizado
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			player,
			GameStateEvent.MESSAGES.HP_UPDATE,
			state.hp,
			state.maxHp
		)
	end

	-- Verifica se o jogador foi derrubado (HP = 0)
	if state.hp <= 0 then
		if state.role == "Survivor" then
			-- Sobrevivente entra em estado de "Derrubado" (Down)
			-- Continua vivo (isAlive = true), mas incapacitado
			state.isDowned = true
			-- isAlive permanece true — o Sobrevivente só morre após bleed-out ou jaula
			MatchService.PlayerDowned:Fire(player)
			print(string.format("[CacadaSombria] %s foi derrubado! (estado Down)", player.Name))
		else
			-- Killer não entra em down state, morre diretamente
			state.isAlive = false
			state.isDowned = true
			MatchService.PlayerDied:Fire(player)
			print(string.format("[CacadaSombria] %s foi derrotado!", player.Name))
		end
	end
end

-- ==========================================
-- SISTEMA DE ESCONDERIJO — VERIFICAÇÃO DE TEMPO
-- ==========================================

-- Verifica se algum Sobrevivente excedeu o tempo máximo no esconderijo (20s)
function MatchService:_checkHidingTimeouts()
	local now = os.clock()
	for _, state in _playerStates do
		if state.isHiding and state.hidingEnterTime then
			if now - state.hidingEnterTime > 20 then
				-- Excedeu o tempo máximo, força a saída
				print(string.format("[CacadaSombria] %s excedeu o tempo máximo no esconderijo (20s). Saindo...",
					state.player.Name))
				MatchService:_handleExitHiding(state)
			end
		end
	end
end

-- ==========================================
-- GAME LOOP (UPDATE)
-- ==========================================

-- Atualização principal, chamada a cada frame via RunService.Heartbeat
function MatchService:_update(dt: number)
	-- Só processa o game loop durante a caçada (Hunting)
	if _currentState ~= MatchState.Hunting then return end

	-- Atualiza o timer da partida
	_matchTimeRemaining = _matchTimeRemaining - dt

	-- Verifica timeout da partida (15 minutos)
	if _matchTimeRemaining <= 0 then
		print("[CacadaSombria] Tempo esgotado!")
		-- Vitória do Caçador por timeout (será implementado no Épico E5)
		MatchService:transitionTo(MatchState.Ending)
		return
	end

	-- Atualiza stamina de todos os Sobreviventes
	for _, state in _playerStates do
		if state.role == "Survivor" then
			MatchService:_consumeStamina(state, dt)
		end
	end

	-- Verifica timeouts de esconderijo a cada 1 segundo (não todo frame)
	-- Usamos um contador simples para não verificar todo frame
	if not MatchService._hideCheckTimer then
		MatchService._hideCheckTimer = 0
	end
	MatchService._hideCheckTimer = (MatchService._hideCheckTimer or 0) + dt
	if MatchService._hideCheckTimer >= 1 then
		MatchService._hideCheckTimer = 0
		MatchService:_checkHidingTimeouts()
	end
end

-- ==========================================
-- FUNÇÕES UTILITÁRIAS DE CONSULTA
-- ==========================================

-- Retorna o PlayerState de um jogador
function MatchService:getPlayerState(player: Player): any?
	return _playerStates[player.UserId]
end

-- Retorna se um jogador está agachado
function MatchService:isPlayerCrouching(player: Player): boolean
	local state = _playerStates[player.UserId]
	return state and state.isCrouching or false
end

-- Retorna se um jogador está escondido
function MatchService:isPlayerHiding(player: Player): boolean
	local state = _playerStates[player.UserId]
	return state and state.isHiding or false
end

-- Retorna o papel de um jogador
function MatchService:getPlayerRole(player: Player): string?
	local state = _playerStates[player.UserId]
	return state and state.role
end

-- Retorna todos os jogadores com um determinado papel
function MatchService:getPlayersByRole(role: string): {Player}
	local players = {}
	for _, state in _playerStates do
		if state.role == role then
			table.insert(players, state.player)
		end
	end
	return players
end

-- Retorna a distância entre dois jogadores
function MatchService:getDistanceBetween(player1: Player, player2: Player): number?
	local state1 = _playerStates[player1.UserId]
	local state2 = _playerStates[player2.UserId]
	if not state1 or not state2 then return nil end
	if not state1.character or not state2.character then return nil end

	local root1: BasePart? = state1.character:FindFirstChild("HumanoidRootPart")
	local root2: BasePart? = state2.character:FindFirstChild("HumanoidRootPart")
	if not root1 or not root2 then return nil end

	return (root1.Position - root2.Position).Magnitude
end

-- ==========================================
-- FUNÇÕES DE CAPTURA — Épico E6
-- ==========================================

-- Elimina definitivamente um jogador (morte final)
-- Usado quando o bleed-out expira ou o timer da jaula zera
-- @param player — O jogador a ser eliminado
function MatchService:killPlayer(player: Player)
	local state = _playerStates[player.UserId]
	if not state then return end

	state.isAlive = false
	state.isDowned = false
	state.isInCage = false
	state.bleedOutTimer = nil

	-- Libera o personagem se estava sendo carregado
	if state.carriedByKillerId then
		local killerState = _playerStates[state.carriedByKillerId]
		if killerState then
			killerState.isCarrying = false
			killerState.carriedSurvivorId = nil
		end
		state.carriedByKillerId = nil
	end

	-- Se era o Killer carregando alguém, libera o Sobrevivente
	if state.isCarrying and state.carriedSurvivorId then
		local survivorState = _playerStates[state.carriedSurvivorId]
		if survivorState then
			survivorState.carriedByKillerId = nil
		end
		state.isCarrying = false
		state.carriedSurvivorId = nil
	end

	MatchService.PlayerDied:Fire(player)
	print(string.format("[CacadaSombria] %s foi ELIMINADO definitivamente.", player.Name))
end

-- Restaura um Sobrevivente após resgate da jaula
-- @param player — O Sobrevivente resgatado
-- @param hpPercent — Percentual do HP máximo a restaurar (ex: 0.5 = 50%)
function MatchService:respawnPlayer(player: Player, hpPercent: number?)
	local state = _playerStates[player.UserId]
	if not state then return end

	hpPercent = hpPercent or 1.0

	state.isAlive = true
	state.isDowned = false
	state.isInCage = false
	state.bleedOutTimer = nil
	state.hp = math.floor(state.maxHp * hpPercent)
	state.wiggleProgress = 0

	-- Remove do estado de carregamento
	state.carriedByKillerId = nil

	print(string.format("[CacadaSombria] %s foi restaurado com %.0f%% HP (%.0f/%.0f).",
		player.Name, hpPercent * 100, state.hp, state.maxHp))
end

-- Define o Killer como carregando um Sobrevivente
-- @param killer — O Caçador
-- @param survivor — O Sobrevivente derrubado (ou nil para liberar)
function MatchService:setPlayerCarrying(killer: Player, survivor: Player?)
	local killerState = _playerStates[killer.UserId]
	if not killerState then return end

	if survivor then
		killerState.isCarrying = true
		killerState.carriedSurvivorId = survivor.UserId

		local survivorState = _playerStates[survivor.UserId]
		if survivorState then
			survivorState.carriedByKillerId = killer.UserId
		end
	else
		-- Libera o Sobrevivente que estava sendo carregado
		if killerState.carriedSurvivorId then
			local survivorState = _playerStates[killerState.carriedSurvivorId]
			if survivorState then
				survivorState.carriedByKillerId = nil
			end
		end
		killerState.isCarrying = false
		killerState.carriedSurvivorId = nil
	end
end

-- Retorna se um jogador está derrubado (down)
function MatchService:isPlayerDowned(player: Player): boolean
	local state = _playerStates[player.UserId]
	return state ~= nil and state.isDowned == true
end

-- Retorna se um jogador está carregando um Sobrevivente
function MatchService:isPlayerCarrying(player: Player): boolean
	local state = _playerStates[player.UserId]
	return state ~= nil and state.isCarrying == true
end

-- Retorna o UserId do Sobrevivente que o Killer está carregando
function MatchService:getCarriedSurvivorId(player: Player): number?
	local state = _playerStates[player.UserId]
	if not state or not state.isCarrying then return nil end
	return state.carriedSurvivorId
end

-- ==========================================
-- CLEANUP
-- ==========================================

function MatchService:Destroy()
	-- Limpa todas as conexões
	for _, state in _playerStates do
		if state.connections then
			for _, conn in state.connections do
				conn:Disconnect()
			end
		end
	end
	table.clear(_playerStates)
	print("[CacadaSombria] MatchService destruído.")
end

return MatchService
