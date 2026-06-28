--!strict
--[[
  GameManager.server.lua
  Script principal do servidor — inicializa todos os serviços.
  
  Responsável por:
  - Inicializar serviços em ordem correta (Init → Start)
  - Criar RemoteEvents em ReplicatedStorage
  - Conectar serviços entre si via Signal (pub/sub)
  - Gerenciar o ciclo de vida da aplicação

  Fluxo de inicialização:
  1. Carrega todos os módulos (require)
  2. Cria RemoteEvents e RemoteFunctions
  3. Fase Init: setup síncrono de cada serviço
  4. Fase Start: inicialização assíncrona (task.spawn)

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- ==========================================
-- DEPENDÊNCIAS — MÓDULOS DO SERVIDOR
-- ==========================================
local MatchService = require(ServerScriptService.Services.MatchService)
local PlayerEvents = require(ServerScriptService.Events.PlayerEvents)

-- ==========================================
-- DEPENDÊNCIAS — MÓDULOS COMPARTILHADOS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- VARIÁVEIS DE ESTADO
-- ==========================================
-- Referências aos RemoteEvents (criados no Init)
local gameStateEvent: RemoteEvent
local playerActionEvent: RemoteEvent

-- ==========================================
-- FUNÇÃO: Garantir estrutura de pastas
-- ==========================================

-- Garante que as pastas necessárias existam em ReplicatedStorage
-- Isso é necessário porque o Rojo pode não criar as pastas automaticamente
local function ensureFolder(parent: Instance, folderName: string): Folder
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end
	return folder
end

-- ==========================================
-- FUNÇÃO: Criar RemoteEvents
-- ==========================================

-- Cria todos os RemoteEvents em ReplicatedStorage.Events
local function createRemoteEvents()
	-- Garante que a pasta Events existe
	local eventsFolder = ensureFolder(ReplicatedStorage, "Events")

	-- Cria cada RemoteEvent usando os módulos compartilhados
	gameStateEvent = GameStateEvent.createEvent(eventsFolder)
	playerActionEvent = PlayerActionEvent.createEvent(eventsFolder)

	print("[CacadaSombria] RemoteEvents criados em ReplicatedStorage.Events")
end

-- ==========================================
-- FUNÇÃO: Criar RemoteFunctions
-- ==========================================

-- Cria RemoteFunctions em ReplicatedStorage.Functions
-- (Apenas GetMatchInfo por enquanto, conforme ADR-003)
local function createRemoteFunctions()
	local functionsFolder = ensureFolder(ReplicatedStorage, "Functions")

	-- GetMatchInfoFunction — cliente pergunta informações da partida
	local getMatchInfo = Instance.new("RemoteFunction")
	getMatchInfo.Name = "GetMatchInfoFunction"
	getMatchInfo.Parent = functionsFolder

	-- Handler: retorna informações básicas da partida
	getMatchInfo.OnServerInvoke = function(player: Player)
		local state = MatchService:getPlayerState(player)
		if not state then
			return {
				role = nil,
				className = nil,
				matchState = MatchService.GetState(),
			}
		end

		return {
			role = state.role,
			className = state.className,
			matchState = MatchService.GetState(),
		}
	end

	print("[CacadaSombria] RemoteFunctions criados em ReplicatedStorage.Functions")
end

-- ==========================================
-- FUNÇÃO: Criar pastas de Services (se necessário)
-- ==========================================

-- Garante que ServerStorage tenha as pastas para assets
local function ensureServerStorageFolders()
	ensureFolder(ServerStorage, "Models")
	ensureFolder(ServerStorage, "Sounds")
	ensureFolder(ServerStorage, "Animations")
	print("[CacadaSombria] Pastas de assets verificadas em ServerStorage")
end

-- ==========================================
-- FUNÇÃO: Inicializar Serviços (Fase Init)
-- ==========================================

-- Fase Init: setup síncrono, sem yield
-- Conecta eventos, configura dependências
local function initServices()
	print("[CacadaSombria] ═══ FASE INIT — Inicializando serviços... ═══")

	-- MatchService precisa das referências aos RemoteEvents
	MatchService.Init(gameStateEvent, playerActionEvent)

	-- Serviços futuros serão inicializados aqui:
	-- KillerService.Init(...)
	-- SurvivorService.Init(...)
	-- GeneratorService.Init(...)
	-- CaptureService.Init(...)
	-- ObjectiveService.Init(...)
	-- AudioService.Init(...)

	print("[CacadaSombria] ═══ FASE INIT concluída ═══")
end

-- ==========================================
-- FUNÇÃO: Inicializar Serviços (Fase Start)
-- ==========================================

-- Fase Start: inicialização que pode yield (task.wait, etc.)
-- Roda cada serviço em sua própria thread via task.spawn
local function startServices()
	print("[CacadaSombria] ═══ FASE START — Iniciando serviços... ═══")

	-- MatchService.Start configura listeners de jogador e game loop
	task.spawn(function()
		MatchService.Start()
	end)

	-- Serviços futuros:
	-- task.spawn(function() KillerService.Start() end)
	-- task.spawn(function() SurvivorService.Start() end)
	-- task.spawn(function() GeneratorService.Start() end)
	-- task.spawn(function() CaptureService.Start() end)
	-- task.spawn(function() ObjectiveService.Start() end)
	-- task.spawn(function() AudioService.Start() end)

	print("[CacadaSombria] ═══ FASE START concluída ═══")
end

-- ==========================================
-- FUNÇÃO: Conexões entre Serviços (Signals)
-- ==========================================

-- Conecta serviços entre si usando o padrão Signal
-- Exemplo: quando a partida começa, o AudioService toca música
local function wireServiceSignals()
	print("[CacadaSombria] Conectando sinais entre serviços...")

	-- Quando a partida começar...
	MatchService.MatchStarted:Connect(function()
		print("[CacadaSombria] Signal: MatchStarted disparado")
		-- Futuro: AudioService:StartAmbientMusic()
	end)

	-- Quando a partida terminar...
	MatchService.MatchEnded:Connect(function()
		print("[CacadaSombria] Signal: MatchEnded disparado")
		-- Futuro: AudioService:StopMusic()
		-- Futuro: GameOverUI:Show()
	end)

	-- Quando um jogador for derrubado...
	MatchService.PlayerDied:Connect(function(player: Player)
		print(string.format("[CacadaSombria] Signal: PlayerDied — %s", player.Name))
		-- Futuro: CaptureService:HandleDown(player)
	end)

	-- Quando um papel for atribuído...
	MatchService.PlayerRoleAssigned:Connect(function(player: Player, role: string, className: string?)
		print(string.format("[CacadaSombria] Signal: PlayerRoleAssigned — %s é %s (%s)",
			player.Name, role, className or "n/a"))

		-- Spawna o jogador de acordo com seu papel
		if role == "Killer" then
			PlayerEvents.spawnKiller(player)
		elseif role == "Survivor" then
			PlayerEvents.spawnSurvivor(player)
		end
	end)

	print("[CacadaSombria] Sinais conectados.")
end

-- ==========================================
-- PONTO DE ENTRADA PRINCIPAL
-- ==========================================

-- Função principal — ponto de entrada do servidor
local function main()
	print("[CacadaSombria] ╔══════════════════════════════════════╗")
	print("[CacadaSombria] ║   CAÇADA SOMBRIA — SERVIDOR        ║")
	print("[CacadaSombria] ║   GameManager iniciando...         ║")
	print("[CacadaSombria] ╚══════════════════════════════════════╝")

	-- 1. Garantir estrutura de pastas
	ensureServerStorageFolders()

	-- 2. Criar eventos de rede
	createRemoteEvents()
	createRemoteFunctions()

	-- 3. Conectar sinais entre serviços
	wireServiceSignals()

	-- 4. Fase Init (síncrono)
	initServices()

	-- 5. Fase Start (assíncrono, cada serviço em sua thread)
	startServices()

	print("[CacadaSombria] GameManager carregado e funcionando!")
	print("[CacadaSombria] Aguardando jogadores...")
end

-- ==========================================
-- EXECUÇÃO
-- ==========================================

-- Executa a função principal
-- Usamos task.spawn para que erros não derrubem o script inteiro
task.spawn(main)

-- Nota: No Roblox, scripts em ServerScriptService executam automaticamente.
-- Este script é o ponto de entrada principal do servidor.
