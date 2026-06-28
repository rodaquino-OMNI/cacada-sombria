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
local SurvivorService = require(ServerScriptService.Services.SurvivorService)
local KillerService = require(ServerScriptService.Services.KillerService)
local GeneratorService = require(ServerScriptService.Services.GeneratorService)
local ObjectiveService = require(ServerScriptService.Services.ObjectiveService)
local MapService = require(ServerScriptService.Services.MapService)
local PlayerEvents = require(ServerScriptService.Events.PlayerEvents)
local SurvivorEvents = require(ServerScriptService.Events.SurvivorEvents)
local KillerEvents = require(ServerScriptService.Events.KillerEvents)
local GeneratorEvents = require(ServerScriptService.Events.GeneratorEvents)

-- ==========================================
-- DEPENDÊNCIAS — MÓDULOS COMPARTILHADOS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)

-- ==========================================
-- VARIÁVEIS DE ESTADO
-- ==========================================
-- Referências aos RemoteEvents (criados no Init)
local gameStateEvent: RemoteEvent
local playerActionEvent: RemoteEvent
local uiSyncEvent: RemoteEvent

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
	uiSyncEvent = UISyncEvent.createEvent(eventsFolder)

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

	-- KillerService: lógica do Caçador
	KillerService.Init(gameStateEvent, uiSyncEvent, MatchService)

	-- KillerEvents: handlers de ações do Caçador
	-- Registra handlers no PlayerActionEvent existente
	KillerEvents.Init(playerActionEvent, KillerService, MatchService)

	-- SurvivorService: lógica das 5 classes de Sobreviventes
	SurvivorService.Init(gameStateEvent, playerActionEvent, uiSyncEvent, MatchService)

	-- SurvivorEvents: handlers auxiliares de ações de Sobreviventes
	-- Registra handlers no PlayerActionEvent (roteamento de Ability1/2/3)
	SurvivorEvents.Init(playerActionEvent, SurvivorService, MatchService)

	-- MapService: gerenciamento do mapa, esconderijos e spawns
	MapService.Init(gameStateEvent, uiSyncEvent, MatchService)

	-- GeneratorService: geradores, reparo e skill checks (Épico E5)
	GeneratorService.Init(gameStateEvent, uiSyncEvent, playerActionEvent, MatchService)

	-- ObjectiveService: portão de fuga, condições de vitória, colapso (Épico E5)
	ObjectiveService.Init(gameStateEvent, uiSyncEvent, playerActionEvent, MatchService, GeneratorService)

	-- GeneratorEvents: handlers de interação com geradores e portão (Épico E5)
	-- Registra handlers no PlayerActionEvent (roteamento de Interact)
	GeneratorEvents.Init(playerActionEvent, GeneratorService, ObjectiveService, MatchService)

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

	-- KillerService.Start configura game loop do Rage
	task.spawn(function()
		KillerService.Start()
	end)

	-- SurvivorService.Start inicia listeners de habilidades
	task.spawn(function()
		SurvivorService.Start()
	end)

	-- MapService.Start: carrega o mapa, configura iluminação e esconderijos
	task.spawn(function()
		MapService.Start()
	end)

	-- GeneratorService.Start conecta ao game loop e spawn de geradores (Épico E5)
	task.spawn(function()
		GeneratorService.Start()
	end)

	-- ObjectiveService.Start conecta ao game loop, colapso e vitória (Épico E5)
	task.spawn(function()
		ObjectiveService.Start()
	end)

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

	-- ==========================================
	-- SINAIS DO KILLERSERVICE
	-- ==========================================

	-- Quando o Caçador causa dano
	KillerService.DamageDealt:Connect(function(player: Player, target: Player, amount: number)
		print(string.format("[CacadaSombria] Signal: DamageDealt — %s causou %.0f em %s",
			player.Name, amount, target.Name))
		-- Futuro: AudioService:PlayHitSound(target)
		-- Futuro: efeitos visuais de sangue/impacto
	end)

	-- Quando a Fúria muda
	KillerService.FuryChanged:Connect(function(player: Player, fury: number, maxFury: number)
		-- Já notificado via UISyncEvent, mas podemos adicionar efeitos visuais aqui
	end)

	-- Quando o Rage é ativado
	KillerService.RageActivated:Connect(function(player: Player)
		print(string.format("[CacadaSombria] Signal: RageActivated — %s transformou!", player.Name))
		-- Futuro: AudioService:PlayRageSound()
		-- Futuro: efeitos visuais de transformação
		-- Futuro: pausar timer da partida
		-- TODO: MatchService:pauseMatchTimer()
	end)

	-- Quando o Rage termina
	KillerService.RageEnded:Connect(function(player: Player)
		print(string.format("[CacadaSombria] Signal: RageEnded — %s voltou ao normal", player.Name))
		-- Futuro: AudioService:StopRageSound()
		-- Futuro: reverter efeitos visuais
		-- TODO: MatchService:resumeMatchTimer()
	end)

	-- Quando o Grito é usado
	KillerService.GritoUsed:Connect(function(player: Player)
		print(string.format("[CacadaSombria] Signal: GritoUsed — %s gritou!", player.Name))
		-- Futuro: AudioService:PlayScreamSound()
		-- Futuro: efeitos visuais de onda sonora
	end)

	-- Quando um Sobrevivente é puxado
	KillerService.SurvivorPulled:Connect(function(killer: Player, survivor: Player)
		print(string.format("[CacadaSombria] Signal: SurvivorPulled — %s puxou %s",
			killer.Name, survivor.Name))
		-- Futuro: AudioService:PlayPullSound()
		-- Futuro: efeitos visuais do braço
	end)

	-- ==========================================
	-- SINAIS DO SURVIVORSERVICE
	-- ==========================================

	-- Quando um Sobrevivente usa uma habilidade
	SurvivorService.SurvivorUsedAbility:Connect(function(player: Player, abilityName: string)
		print(string.format("[CacadaSombria] Signal: SurvivorUsedAbility — %s usou %s",
			player.Name, abilityName))
		-- Futuro: AudioService:PlayAbilitySound(abilityName)
	end)

	-- Quando um Sobrevivente é curado
	SurvivorService.SurvivorHealed:Connect(function(player: Player, amount: number)
		print(string.format("[CacadaSombria] Signal: SurvivorHealed — %s curou %d HP",
			player.Name, amount))
		-- Futuro: efeitos visuais de cura
	end)

	-- Quando um Sobrevivente recebe escudo (Adrenalina)
	SurvivorService.SurvivorShielded:Connect(function(player: Player)
		print(string.format("[CacadaSombria] Signal: SurvivorShielded — %s ganhou escudo",
			player.Name))
		-- Futuro: efeitos visuais de escudo
	end)

	-- ==========================================
	-- SINAIS DO MAPSERVICE
	-- ==========================================

	-- Quando o mapa termina de carregar
	MapService.MapLoaded:Connect(function()
		print("[CacadaSombria] Signal: MapLoaded — Mapa carregado e pronto!")
	end)

	-- Quando um jogador entra em um esconderijo
	MapService.HidingSpotEntered:Connect(function(player: Player, spotId: number)
		print(string.format("[CacadaSombria] Signal: HidingSpotEntered — %s no esconderijo #%d",
			player.Name, spotId))
		-- Futuro: AudioService:PlayHidingSound(player)
		-- Futuro: NotificationService para o Killer (alerta de proximidade)
	end)

	-- Quando um jogador sai de um esconderijo
	MapService.HidingSpotExited:Connect(function(player: Player, spotId: number)
		print(string.format("[CacadaSombria] Signal: HidingSpotExited — %s saiu do esconderijo #%d",
			player.Name, spotId))
	end)

	-- Quando os esconderijos bloqueados são definidos
	MapService.HidingSpotBlocked:Connect(function(blockedSpots: {[number]: boolean})
		local count = 0
		for _ in blockedSpots do count = count + 1 end
		print(string.format("[CacadaSombria] Signal: HidingSpotBlocked — %d esconderijos bloqueados", count))
	end)

	-- Quando a iluminação é aplicada
	MapService.LightingApplied:Connect(function()
		print("[CacadaSombria] Signal: LightingApplied — Iluminação dramática configurada")
	end)

	-- ==========================================
	-- SINAIS DO GENERATORSERVICE (Épico E5)
	-- ==========================================

	-- Quando um gerador é consertado
	GeneratorService.GeneratorRepaired:Connect(function(generatorId: number, totalRepaired: number)
		print(string.format("[CacadaSombria] Signal: GeneratorRepaired — Gerador #%d (%d/%d)",
			generatorId, totalRepaired, GameConstants.Game.GeneratorsToRepair))
		-- Futuro: AudioService:PlayGeneratorCompleteSound()
	end)

	-- Quando todos os geradores são consertados (portão destrancado)
	GeneratorService.AllGeneratorsRepaired:Connect(function()
		print("[CacadaSombria] Signal: AllGeneratorsRepaired — Portão de fuga destrancado!")
	end)

	-- Quando um skill check falha (alerta global para o Caçador)
	GeneratorService.GeneratorAlert:Connect(function(generatorPosition: Vector3)
		print(string.format("[CacadaSombria] Signal: GeneratorAlert — Alerta em (%.0f, %.0f, %.0f)",
			generatorPosition.X, generatorPosition.Y, generatorPosition.Z))
		-- Futuro: AudioService:PlayGeneratorAlertSound()
		-- Futuro: NotificationService:NotifyKiller(generatorPosition)
	end)

	-- ==========================================
	-- SINAIS DO OBJECTIVESERVICE (Épico E5)
	-- ==========================================

	-- Quando o portão é ativado (alavanca puxada)
	ObjectiveService.GateActivated:Connect(function(gateId: number)
		print(string.format("[CacadaSombria] Signal: GateActivated — Portão #%d ativado!", gateId))
		-- Futuro: AudioService:PlayGateAlarmSound()
	end)

	-- Quando o portão termina de abrir
	ObjectiveService.GateOpened:Connect(function(gateId: number)
		print(string.format("[CacadaSombria] Signal: GateOpened — Portão #%d aberto! Fujam!", gateId))
		-- Futuro: AudioService:PlayGateOpenSound()
	end)

	-- Quando o portão fecha (colapso)
	ObjectiveService.GateClosed:Connect(function(gateId: number)
		print(string.format("[CacadaSombria] Signal: GateClosed — Portão #%d fechado permanentemente.", gateId))
	end)

	-- Vitória dos Sobreviventes
	ObjectiveService.SurvivorsWin:Connect(function()
		print("[CacadaSombria] Signal: SurvivorsWin — SOBREVIVENTES VENCERAM!")
		-- Futuro: AudioService:PlayVictorySound("Survivors")
	end)

	-- Vitória do Caçador
	ObjectiveService.KillerWin:Connect(function(reason: string)
		print(string.format("[CacadaSombria] Signal: KillerWin — CAÇADOR VENCEU! (motivo: %s)", reason))
		-- Futuro: AudioService:PlayVictorySound("Killer")
	end)

	-- Colapso iniciado
	ObjectiveService.CollapseStarted:Connect(function(secondsRemaining: number)
		print(string.format("[CacadaSombria] Signal: CollapseStarted — COLAPSO! Portão abre por %.0fs", secondsRemaining))
		-- Futuro: AudioService:PlayCollapseAlarm()
	end)

	-- Sobrevivente escapou
	ObjectiveService.SurvivorEscaped:Connect(function(player: Player)
		print(string.format("[CacadaSombria] Signal: SurvivorEscaped — %s escapou!", player.Name))
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

	-- 6. Loop de atualização do SurvivorService (efeitos e cooldowns contínuos)
	--    e MapService (verificação de timeouts de esconderijos)
	RunService.Heartbeat:Connect(function(dt: number)
		SurvivorService:update(dt)
		MapService:update(dt)
	end)

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
