--!strict
--[[
	LobbyService.lua
	Serviço que gerencia o lobby — host, seleção de personagem, início de partida.
	
	Responsável por:
	- Definir o host da sala (primeiro jogador a entrar)
	- Gerenciar a lista de jogadores no lobby
	- Fase de seleção de personagens (15 segundos)
	- Atribuição do papel de Caçador (host escolhe)
	- Botão "Iniciar Partida" (apenas host)
	- Gerenciar desconexões durante lobby/seleção
	- Coordenar transição para a fase de preparação

	Regras:
	- Máximo 5 jogadores (1 Caçador + 4 Sobreviventes)
	- Múltiplos jogadores podem escolher a mesma classe de Sobrevivente
	- Host atribui o Caçador; se não atribuir, é aleatório
	- Se o host sair, o próximo jogador assume
	- Se todos os jogadores saírem, volta ao estado inicial

	Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo por performance)
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- SERVIÇO LOBBIESERVICE
-- ==========================================
local LobbyService = {}
LobbyService.__index = LobbyService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
LobbyService.LobbyReady = Signal.new()           -- Todos prontos, host pode iniciar
LobbyService.MatchStartRequested = Signal.new()  -- Host solicitou início da partida
LobbyService.KillerAssigned = Signal.new()       -- Caçador foi atribuído

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Armazena informações de cada jogador no lobby
-- Chave: player.UserId
-- Valor: {player, selectedClass, isReady}
local _lobbyPlayers: {[number]: any} = {}

-- ID do host atual (userId)
local _hostUserId: number? = nil

-- ID do Caçador atribuído (userId)
local _killerUserId: number? = nil

-- Referências aos serviços e RemoteEvents
local _gameStateEvent: RemoteEvent? = nil
local _matchService: any = nil
local _playerActionEvent: RemoteEvent? = nil

-- Classes de Sobreviventes disponíveis (extraídas dos GameConstants)
local SURVIVOR_CLASSES = {"Soldado", "Sackboy", "Robo", "Enfermeira", "Campeao"}

-- Máximo de jogadores por partida
local MAX_PLAYERS = 5

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
-- @param gameStateEvent — RemoteEvent para comunicação com clientes
-- @param matchService — Referência ao MatchService
-- @param playerActionEvent — RemoteEvent para receber ações dos clientes
function LobbyService.Init(
	gameStateEvent: RemoteEvent,
	matchService: any,
	playerActionEvent: RemoteEvent
)
	_gameStateEvent = gameStateEvent
	_matchService = matchService
	_playerActionEvent = playerActionEvent

	-- Registra handler para ações de lobby (SelectClass, AssignKiller, StartMatch)
	if _playerActionEvent then
		local conn = _playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...)
			LobbyService:_handleLobbyAction(player, action, ...)
		end)
		table.insert(_connections, conn)
	end

	print("[CacadaSombria] LobbyService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function LobbyService.Start()
	-- Escuta entrada de jogadores
	local conn1 = Players.PlayerAdded:Connect(function(player: Player)
		LobbyService:_onPlayerJoined(player)
	end)
	table.insert(_connections, conn1)

	-- Escuta saída de jogadores (desconexão)
	local conn2 = Players.PlayerRemoving:Connect(function(player: Player)
		LobbyService:_onPlayerLeft(player)
	end)
	table.insert(_connections, conn2)

	-- Escuta sinais do MatchService
	if _matchService then
		-- Quando a seleção começa
		local conn3 = _matchService.SelectStarted:Connect(function()
			LobbyService:_onSelectStarted()
		end)
		table.insert(_connections, conn3)

		-- Quando o timer de seleção expira
		local conn4 = _matchService.SelectTimerExpired:Connect(function()
			LobbyService:_onSelectTimerExpired()
		end)
		table.insert(_connections, conn4)

		-- Quando um jogador desconecta (para tratar durante a partida)
		local conn5 = _matchService.PlayerDisconnected:Connect(function(player: Player, role: string?, matchState: string)
			LobbyService:_onPlayerDisconnected(player, role, matchState)
		end)
		table.insert(_connections, conn5)

		-- Quando retorna ao lobby (após partida)
		local conn6 = _matchService.ReturnToLobby:Connect(function()
			LobbyService:_onReturnToLobby()
		end)
		table.insert(_connections, conn6)
	end

	print("[CacadaSombria] LobbyService iniciado. Aguardando jogadores...")
end

-- ==========================================
-- GERENCIAMENTO DE JOGADORES NO LOBBY
-- ==========================================

-- Chamado quando um jogador entra no servidor
function LobbyService:_onPlayerJoined(player: Player)
	local matchState = _matchService and _matchService.GetState() or "Waiting"

	-- Só adiciona ao lobby se estiver no estado Waiting
	if matchState ~= "Waiting" then
		print(string.format("[CacadaSombria] %s entrou mas partida já está em andamento (%s)", player.Name, matchState))
		return
	end

	-- Verifica limite de jogadores
	local playerCount = 0
	for _ in _lobbyPlayers do playerCount = playerCount + 1 end
	if playerCount >= MAX_PLAYERS then
		print(string.format("[CacadaSombria] %s tentou entrar mas lobby está cheio (%d/%d)", player.Name, playerCount, MAX_PLAYERS))
		-- Notifica o jogador que o lobby está cheio
		if _gameStateEvent then
			GameStateEvent.sendToClient(_gameStateEvent, player, "LobbyUpdate", {error = "cheio"})
		end
		return
	end

	-- Cria entrada no lobby
	_lobbyPlayers[player.UserId] = {
		player = player,
		selectedClass = nil,  -- nil = ainda não escolheu
		isReady = false,
	}

	-- Define o host se for o primeiro jogador
	if not _hostUserId then
		_hostUserId = player.UserId
		print(string.format("[CacadaSombria] %s é o HOST do lobby", player.Name))
		if _gameStateEvent then
			GameStateEvent.sendToClient(_gameStateEvent, player, GameStateEvent.MESSAGES.HOST_ASSIGNED, true)
		end
	end

	print(string.format("[CacadaSombria] %s entrou no lobby. Total: %d jogadores", player.Name, playerCount + 1))

	-- Envia atualização do lobby para todos
	LobbyService:_broadcastLobbyUpdate()
end

-- Chamado quando um jogador sai do servidor (desconexão)
function LobbyService:_onPlayerLeft(player: Player)
	local userId = player.UserId

	-- Remove do lobby se estiver presente
	if _lobbyPlayers[userId] then
		_lobbyPlayers[userId] = nil
		print(string.format("[CacadaSombria] %s saiu do lobby", player.Name))

		-- Se era o host, passa para o próximo jogador
		if _hostUserId == userId then
			_hostUserId = nil
			-- Escolhe o próximo jogador como host
			for uid, data in _lobbyPlayers do
				_hostUserId = uid
				print(string.format("[CacadaSombria] Novo HOST: %s", data.player.Name))
				if _gameStateEvent then
					GameStateEvent.sendToClient(_gameStateEvent, data.player, GameStateEvent.MESSAGES.HOST_ASSIGNED, true)
				end
				break
			end
		end

		-- Se era o Caçador, reseta a atribuição
		if _killerUserId == userId then
			_killerUserId = nil
		end

		-- Se não há mais jogadores, reseta o lobby completamente
		local playerCount = 0
		for _ in _lobbyPlayers do playerCount = playerCount + 1 end
		if playerCount == 0 then
			_hostUserId = nil
			_killerUserId = nil
			print("[CacadaSombria] Lobby vazio — resetado")
		end

		-- Envia atualização do lobby
		LobbyService:_broadcastLobbyUpdate()
	end
end

-- ==========================================
-- TRATAMENTO DE DESCONEXÃO DURANTE A PARTIDA
-- ==========================================

-- Chamado quando um jogador desconecta durante a partida (via MatchService.PlayerDisconnected)
-- @param player — O jogador que desconectou
-- @param role — Papel do jogador ("Killer", "Survivor" ou nil)
-- @param matchState — Estado atual da partida
function LobbyService:_onPlayerDisconnected(player: Player, role: string?, matchState: string)
	local userId = player.UserId

	-- Se está no lobby ou seleção, já tratado por _onPlayerLeft
	if matchState == "Waiting" or matchState == "Selecting" then
		return
	end

	-- Durante a partida ativa (Preparing, Hunting, Ending)
	if role == "Survivor" then
		-- Sobrevivente desconectou → vai direto para a jaula
		print(string.format("[CacadaSombria] Sobrevivente %s desconectou durante a partida → enviado para jaula", player.Name))
		-- Notifica os clientes restantes
		if _gameStateEvent then
			GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.ESCAPED, player.Name .. " (desconectou)")
		end
		-- Futuro: CaptureService:forceCage(player)

	elseif role == "Killer" then
		-- Caçador desconectou → partida termina, Sobreviventes vencem
		print(string.format("[CacadaSombria] CAÇADOR %s desconectou! Partida encerrada — Sobreviventes vencem.", player.Name))

		-- Força a transição para Ending
		if _matchService and matchState ~= "Ending" then
			-- Notifica vitória dos Sobreviventes
			if _gameStateEvent then
				GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.GAME_OVER, "Survivors", "CaçadorDesconectou")
			end
			_matchService:transitionTo("Ending")
		end
	end
end

-- ==========================================
-- AÇÕES DE LOBBY (RECEBIDAS DO CLIENTE)
-- ==========================================

-- Processa ações enviadas pelos clientes durante o lobby
-- @param player — O jogador que enviou a ação
-- @param action — Tipo de ação ("SelectClass", "AssignKiller", "StartMatch", "ReturnToLobby")
function LobbyService:_handleLobbyAction(player: Player, action: string, ...)
	local userId = player.UserId

	-- ==========================
	-- SELECIONAR CLASSE DE SOBREVIVENTE
	-- ==========================
	if action == "SelectClass" then
		local className: string = ...
		if not className then
			warn(string.format("[CacadaSombria] SelectClass sem className de %s", player.Name))
			return
		end

		-- Verifica se a classe é válida
		local validClass = false
		for _, c in SURVIVOR_CLASSES do
			if c == className then
				validClass = true
				break
			end
		end

		if not validClass then
			warn(string.format("[CacadaSombria] Classe inválida '%s' escolhida por %s", className, player.Name))
			return
		end

		-- Verifica se o jogador está no lobby
		local lobbyData = _lobbyPlayers[userId]
		if not lobbyData then
			warn(string.format("[CacadaSombria] %s tentou escolher classe mas não está no lobby", player.Name))
			return
		end

		-- Salva a escolha
		lobbyData.selectedClass = className
		lobbyData.isReady = true

		print(string.format("[CacadaSombria] %s escolheu a classe: %s", player.Name, className))

		-- Notifica todos sobre a escolha
		if _gameStateEvent then
			GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.CHARACTER_SELECTED, player.Name, className)
		end

		-- Envia atualização do lobby
		LobbyService:_broadcastLobbyUpdate()

	-- ==========================
	-- ATRIBUIR CAÇADOR (APENAS HOST)
	-- ==========================
	elseif action == "AssignKiller" then
		-- Verifica se é o host
		if _hostUserId ~= userId then
			warn(string.format("[CacadaSombria] %s tentou atribuir Caçador mas não é o host", player.Name))
			return
		end

		local targetName: string = ...
		if not targetName then
			warn("[CacadaSombria] AssignKiller sem nome do jogador alvo")
			return
		end

		-- Encontra o jogador pelo nome
		local targetPlayer: Player? = nil
		for _, data in _lobbyPlayers do
			if data.player.Name == targetName then
				targetPlayer = data.player
				break
			end
		end

		if not targetPlayer then
			warn(string.format("[CacadaSombria] Jogador '%s' não encontrado para ser Caçador", targetName))
			return
		end

		-- Atribui o Caçador
		_killerUserId = targetPlayer.UserId
		print(string.format("[CacadaSombria] %s foi atribuído como CAÇADOR pelo host %s", targetName, player.Name))

		-- Notifica todos
		if _gameStateEvent then
			GameStateEvent.sendToAll(_gameStateEvent, "KillerAssigned", targetName)
		end

		LobbyService.KillerAssigned:Fire(targetPlayer)
		LobbyService:_broadcastLobbyUpdate()

	-- ==========================
	-- INICIAR PARTIDA (APENAS HOST)
	-- ==========================
	elseif action == "StartMatch" then
		-- Verifica se é o host
		if _hostUserId ~= userId then
			warn(string.format("[CacadaSombria] %s tentou iniciar partida mas não é o host", player.Name))
			return
		end

		-- Verifica mínimo de jogadores (2: host + pelo menos mais 1)
		local playerCount = 0
		for _ in _lobbyPlayers do playerCount = playerCount + 1 end
		if playerCount < 2 then
			print(string.format("[CacadaSombria] Host %s tentou iniciar mas só há %d jogador(es) (mínimo 2)", player.Name, playerCount))
			if _gameStateEvent then
				GameStateEvent.sendToClient(_gameStateEvent, player, "LobbyUpdate", {error = "minimo_jogadores"})
			end
			return
		end

		print(string.format("[CacadaSombria] HOST %s iniciou a partida! (%d jogadores)", player.Name, playerCount))

		-- Se nenhum Caçador foi atribuído, escolhe aleatoriamente (excluindo o host)
		if not _killerUserId then
			-- Escolhe um jogador aleatório que não seja o host
			local eligiblePlayers = {}
			for uid, data in _lobbyPlayers do
				if uid ~= _hostUserId then
					table.insert(eligiblePlayers, data.player)
				end
			end
			if #eligiblePlayers > 0 then
				local randomIndex = math.random(1, #eligiblePlayers)
				local killerPlayer = eligiblePlayers[randomIndex]
				_killerUserId = killerPlayer.UserId
				print(string.format("[CacadaSombria] Caçador atribuído aleatoriamente: %s", killerPlayer.Name))
			else
				-- Só o host na sala? (não deveria acontecer pela verificação de mínimo)
				_killerUserId = _hostUserId
				print(string.format("[CacadaSombria] Apenas host na sala — host será o Caçador"))
			end
		end

		-- Atribui papéis a todos os jogadores
		LobbyService:_assignAllRoles()

		-- Transita para Selecting (MatchService gerencia a transição)
		if _matchService then
			local ok = _matchService:transitionTo("Selecting")
			if not ok then
				warn("[CacadaSombria] Falha ao transitar para Selecting")
			end
		end

	-- ==========================
	-- VOLTAR AO LOBBY (após fim de partida)
	-- ==========================
	elseif action == "ReturnToLobby" then
		print(string.format("[CacadaSombria] %s solicitou voltar ao lobby", player.Name))
		-- Se estiver no estado Ending, força transição para Waiting
		if _matchService then
			local currentState = _matchService.GetState()
			if currentState == "Ending" then
				_matchService:transitionTo("Waiting")
			end
		end
	end
end

-- ==========================================
-- ATRIBUIÇÃO DE PAPÉIS
-- ==========================================

-- Atribui os papéis a todos os jogadores no lobby
-- O Caçador é definido por _killerUserId; os demais são Sobreviventes
function LobbyService:_assignAllRoles()
	if not _matchService then return end

	for userId, data in _lobbyPlayers do
		if userId == _killerUserId then
			-- Atribui como Caçador
			_matchService:assignRole(data.player, "Killer", nil)
			print(string.format("[CacadaSombria] %s → CAÇADOR (O Distorcido)", data.player.Name))
		else
			-- Atribui como Sobrevivente com a classe escolhida (ou aleatória se não escolheu)
			local className = data.selectedClass
			if not className then
				-- Escolhe classe aleatória
				local randomIndex = math.random(1, #SURVIVOR_CLASSES)
				className = SURVIVOR_CLASSES[randomIndex]
				print(string.format("[CacadaSombria] %s não escolheu classe — atribuída %s (aleatória)", data.player.Name, className))
			end
			_matchService:assignRole(data.player, "Survivor", className)
			print(string.format("[CacadaSombria] %s → SOBREVIVENTE (%s)", data.player.Name, className))
		end
	end

	-- Dispara sinal de partida solicitada
	LobbyService.MatchStartRequested:Fire()
end

-- ==========================================
-- GERENCIAMENTO DA FASE DE SELEÇÃO
-- ==========================================

-- Chamado quando o MatchService entra no estado Selecting
function LobbyService:_onSelectStarted()
	print("[CacadaSombria] LobbyService: fase de seleção iniciada!")

	-- Envia para todos os clientes a lista de classes disponíveis
	if _gameStateEvent then
		GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.CHARACTER_SELECT, SURVIVOR_CLASSES)
	end

	-- Inicia timer de 15 segundos na tela de seleção
	for seconds = 15, 1, -1 do
		if _matchService and _matchService.GetState() ~= "Selecting" then break end
		if _gameStateEvent then
			GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.SELECT_TIMER, seconds)
		end
		task.wait(1)
	end
end

-- Chamado quando o timer de seleção expira (15s)
function LobbyService:_onSelectTimerExpired()
	print("[CacadaSombria] LobbyService: timer de seleção expirado!")

	-- Para jogadores que não escolheram classe, atribui aleatória
	for userId, data in _lobbyPlayers do
		if not data.selectedClass then
			local randomIndex = math.random(1, #SURVIVOR_CLASSES)
			data.selectedClass = SURVIVOR_CLASSES[randomIndex]
			print(string.format("[CacadaSombria] %s recebeu classe aleatória: %s", data.player.Name, data.selectedClass))
		end
	end

	-- Reatribui papéis com as classes atualizadas
	LobbyService:_assignAllRoles()

	-- Transita para Preparing (início da partida)
	if _matchService then
		_matchService:transitionTo("Preparing")
	end
end

-- ==========================================
-- RETORNO AO LOBBY
-- ==========================================

-- Chamado quando a partida termina e volta ao estado Waiting
function LobbyService:_onReturnToLobby()
	print("[CacadaSombria] Retornando ao lobby...")

	-- Limpa o estado do lobby
	_lobbyPlayers = {}
	_hostUserId = nil
	_killerUserId = nil

	-- Re-adiciona jogadores que ainda estão conectados
	for _, player in Players:GetPlayers() do
		LobbyService:_onPlayerJoined(player)
	end

	LobbyService:_broadcastLobbyUpdate()
end

-- ==========================================
-- UTILITÁRIOS DE COMUNICAÇÃO
-- ==========================================

-- Envia o estado atual do lobby para todos os clientes
function LobbyService:_broadcastLobbyUpdate()
	if not _gameStateEvent then return end

	-- Constrói dados serializáveis do lobby
	local playerList = {}
	for userId, data in _lobbyPlayers do
		table.insert(playerList, {
			name = data.player.Name,
			userId = userId,
			selectedClass = data.selectedClass,
			isReady = data.isReady,
			isHost = (userId == _hostUserId),
			isKiller = (userId == _killerUserId),
		})
	end

	local lobbyData = {
		players = playerList,
		hostUserId = _hostUserId,
		killerUserId = _killerUserId,
		maxPlayers = MAX_PLAYERS,
	}

	GameStateEvent.sendToAll(_gameStateEvent, GameStateEvent.MESSAGES.LOBBY_UPDATE, lobbyData)
end

-- ==========================================
-- FUNÇÕES DE CONSULTA
-- ==========================================

-- Retorna se um jogador é o host
function LobbyService:isHost(player: Player): boolean
	return player.UserId == _hostUserId
end

-- Retorna o jogador host
function LobbyService:getHostPlayer(): Player?
	if not _hostUserId then return nil end
	local data = _lobbyPlayers[_hostUserId]
	return data and data.player
end

-- Retorna o jogador Caçador
function LobbyService:getKillerPlayer(): Player?
	if not _killerUserId then return nil end
	local data = _lobbyPlayers[_killerUserId]
	return data and data.player
end

-- Retorna a classe escolhida por um jogador
function LobbyService:getSelectedClass(player: Player): string?
	local data = _lobbyPlayers[player.UserId]
	return data and data.selectedClass
end

-- ==========================================
-- CLEANUP
-- ==========================================

function LobbyService:Destroy()
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)
	table.clear(_lobbyPlayers)
	_hostUserId = nil
	_killerUserId = nil
	print("[CacadaSombria] LobbyService destruído.")
end

return LobbyService
