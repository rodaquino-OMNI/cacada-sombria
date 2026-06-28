--!strict
--[[
  AudioService.lua
  Serviço de áudio do servidor — decide O QUE tocar com base na
  distância Killer↔Sobrevivente, estado da partida e ações dos jogadores.
  
  Responsável por:
  - Sistema de 3 camadas de música dinâmica com crossfade
  - Batimentos cardíacos por proximidade (volume e ritmo)
  - Disparar SFX de habilidades do Caçador e Sobreviventes
  - Sons ambientes posicionais (vento, rangidos, trovões, sussurros)
  - Sons de UI (skill check, alarmes, portão, vitória/derrota)
  
  O servidor decide O QUE tocar (camada, volume, posição).
  O cliente executa a reprodução via AudioManager.
  Comunicação: UISyncEvent (RemoteEvent já existente).
  
  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo)
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
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)

-- ==========================================
-- ATALHO PARA CONSTANTES DE ÁUDIO
-- ==========================================
local AUDIO = {
	-- Limiares de distância para as camadas de música (em studs)
	MUSIC_LAYER_AMBIENT = 60,    -- >60 studs = Layer 1 (Exploração)
	MUSIC_LAYER_ALERT = 30,      -- 30-60 studs = Layer 2 (Alerta)
	-- <30 studs = Layer 3 (Perseguição)
	
	-- Crossfade
	CROSSFADE_DURATION = 2.0,    -- Duração do crossfade em segundos
	
	-- Batimentos cardíacos
	HEARTBEAT_MAX_RANGE = 40,    -- Alcance máximo para ouvir batimentos (studs)
	HEARTBEAT_UPDATE_INTERVAL = 0.5,  -- Atualizar a cada 500ms
	
	-- Intervalo de sons ambientes
	AMBIENT_MIN_INTERVAL = 8,    -- Intervalo mínimo entre sons ambientes (segundos)
	AMBIENT_MAX_INTERVAL = 25,   -- Intervalo máximo entre sons ambientes (segundos)
	
	-- Raio dos sons ambientes posicionais (studs ao redor do jogador)
	AMBIENT_SPAWN_RADIUS = 30,   -- Raio para spawnar sons ambientes ao redor
}

-- ==========================================
-- SERVIÇO AUDIOSERVICE
-- ==========================================
local AudioService = {}
AudioService.__index = AudioService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
-- Disparado quando um SFX de habilidade deve tocar
AudioService.AbilitySFX = Signal.new()  -- params: player, soundName, volume?

-- ==========================================
-- ESTADO INTERNO
-- ==========================================
local _uiSyncEvent: RemoteEvent? = nil
local _matchService: any = nil

-- Tabela para rastrear última camada de música enviada por sobrevivente
-- Evita enviar comandos redundantes
local _lastMusicLayer: {[number]: number} = {}

-- Temporizador para atualização de proximidade (Heartbeat)
local _proximityTimer: number = 0

-- Temporizador para sons ambientes aleatórios
local _ambientTimer: number = 0
local _nextAmbientInterval: number = 0

-- Flag de estado da partida
local _isMatchActive: boolean = false

-- ==========================================
-- FUNÇÕES AUXILIARES
-- ==========================================

-- Calcula a distância entre duas posições (ignorando Y para simplicidade)
local function calculateDistance(pos1: Vector3, pos2: Vector3): number
	return (Vector3.new(pos1.X, 0, pos1.Z) - Vector3.new(pos2.X, 0, pos2.Z)).Magnitude
end

-- Obtém a posição do character de um jogador (ou Vector3.zero se não disponível)
local function getPlayerPosition(player: Player): Vector3
	local character = player.Character
	if not character then
		return Vector3.zero
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return Vector3.zero
	end
	
	return humanoidRootPart.Position
end

-- Determina qual camada de música tocar baseado na distância
local function getMusicLayerForDistance(distance: number): number
	if distance > AUDIO.MUSIC_LAYER_AMBIENT then
		return 1  -- Exploração (ambiente)
	elseif distance > AUDIO.MUSIC_LAYER_ALERT then
		return 2  -- Alerta (tensão média)
	else
		return 3  -- Perseguição (tensão máxima)
	end
end

-- Calcula o volume dos batimentos cardíacos (linear de 0 a 1)
local function getHeartbeatVolume(distance: number): number
	if distance >= AUDIO.HEARTBEAT_MAX_RANGE then
		return 0  -- Fora do alcance, sem batimentos
	end
	-- Volume linear: 1 (perto) a 0 (no limite de 40 studs)
	return math.clamp(1.0 - (distance / AUDIO.HEARTBEAT_MAX_RANGE), 0, 1)
end

-- ==========================================
-- FUNÇÃO: Enviar crossfade de música para um sobrevivente
-- ==========================================
local function sendMusicCrossfade(player: Player, targetLayer: number)
	if not _uiSyncEvent then return end
	
	local userId = player.UserId
	if _lastMusicLayer[userId] == targetLayer then
		return  -- Já está na camada correta, não reenviar
	end
	
	_lastMusicLayer[userId] = targetLayer
	
	UISyncEvent.sendToClient(
		_uiSyncEvent,
		player,
		UISyncEvent.MESSAGES.MUSIC_CROSSFADE,
		targetLayer,
		AUDIO.CROSSFADE_DURATION
	)
end

-- ==========================================
-- FUNÇÃO: Enviar atualização de batimentos cardíacos
-- ==========================================
local function sendHeartbeatUpdate(player: Player, distance: number)
	if not _uiSyncEvent then return end
	
	local volume = getHeartbeatVolume(distance)
	
	UISyncEvent.sendToClient(
		_uiSyncEvent,
		player,
		UISyncEvent.MESSAGES.HEARTBEAT_UPDATE,
		volume
	)
end

-- ==========================================
-- FUNÇÃO: Enviar comando de SFX para um jogador
-- ==========================================
local function sendSFX(player: Player, soundName: string, position: Vector3?, volume: number?)
	if not _uiSyncEvent then return end
	
	UISyncEvent.sendToClient(
		_uiSyncEvent,
		player,
		UISyncEvent.MESSAGES.PLAY_SFX,
		soundName,
		position or Vector3.zero,
		volume or 1.0
	)
end

-- ==========================================
-- FUNÇÃO: Enviar SFX para todos os jogadores
-- ==========================================
local function sendSFXToAll(soundName: string, position: Vector3?, volume: number?)
	if not _uiSyncEvent then return end
	
	UISyncEvent.sendToAll(
		_uiSyncEvent,
		UISyncEvent.MESSAGES.PLAY_SFX,
		soundName,
		position or Vector3.zero,
		volume or 1.0
	)
end

-- ==========================================
-- FUNÇÃO: Enviar som ambiente para um jogador
-- ==========================================
local function sendAmbientSFX(player: Player, soundName: string, position: Vector3)
	if not _uiSyncEvent then return end
	
	UISyncEvent.sendToClient(
		_uiSyncEvent,
		player,
		UISyncEvent.MESSAGES.PLAY_AMBIENT,
		soundName,
		position
	)
end

-- ==========================================
-- MÉTODO: Init — Setup síncrono, injeta dependências
-- ==========================================
function AudioService.Init(
	uiSyncEvent: RemoteEvent,
	matchService: any
)
	_uiSyncEvent = uiSyncEvent
	_matchService = matchService
	
	print("[CacadaSombria] AudioService.Init — Dependências injetadas")
end

-- ==========================================
-- MÉTODO: Start — Inicialização assíncrona
-- ==========================================
function AudioService.Start()
	print("[CacadaSombria] AudioService.Start — Iniciando sistema de áudio...")
	
	-- Define o próximo intervalo de som ambiente
	_nextAmbientInterval = AUDIO.AMBIENT_MIN_INTERVAL
		+ math.random() * (AUDIO.AMBIENT_MAX_INTERVAL - AUDIO.AMBIENT_MIN_INTERVAL)
	
	print("[CacadaSombria] AudioService pronto!")
end

-- ==========================================
-- MÉTODO: update — Chamado a cada frame pelo Heartbeat
-- ==========================================
function AudioService:update(dt: number)
	if not _isMatchActive then return end
	if not _matchService then return end
	
	-- Acumula o temporizador de proximidade
	_proximityTimer += dt
	
	-- Atualiza música e batimentos a cada 500ms
	if _proximityTimer >= AUDIO.HEARTBEAT_UPDATE_INTERVAL then
		_proximityTimer = 0
		self:updateProximityForAll()
	end
	
	-- Sons ambientes aleatórios
	_ambientTimer += dt
	if _ambientTimer >= _nextAmbientInterval then
		_ambientTimer = 0
		_nextAmbientInterval = AUDIO.AMBIENT_MIN_INTERVAL
			+ math.random() * (AUDIO.AMBIENT_MAX_INTERVAL - AUDIO.AMBIENT_MIN_INTERVAL)
		self:triggerRandomAmbient()
	end
end

-- ==========================================
-- MÉTODO: updateProximityForAll — Verifica distância de cada sobrevivente ao Caçador
-- ==========================================
function AudioService:updateProximityForAll()
	if not _matchService then return end
	
	-- Encontra todos os jogadores Caçadores
	local killerPlayers = _matchService:getPlayersByRole("Killer")
	if #killerPlayers == 0 then return end
	
	local killerPlayer = killerPlayers[1]
	local killerPos = getPlayerPosition(killerPlayer)
	if killerPos == Vector3.zero then return end  -- Killer não tem character
	
	-- Para cada sobrevivente, calcula distância e atualiza música + batimentos
	local survivorPlayers = _matchService:getPlayersByRole("Survivor")
	
	for _, survivorPlayer in survivorPlayers do
		local survivorPos = getPlayerPosition(survivorPlayer)
		
		if survivorPos ~= Vector3.zero then
			-- Verifica se está vivo
			local state = _matchService:getPlayerState(survivorPlayer)
			if state and state.isAlive then
				local distance = calculateDistance(killerPos, survivorPos)
				
				-- Atualiza camada de música (crossfade)
				local layer = getMusicLayerForDistance(distance)
				sendMusicCrossfade(survivorPlayer, layer)
				
				-- Atualiza batimentos cardíacos
				sendHeartbeatUpdate(survivorPlayer, distance)
			end
		end
	end
end

-- ==========================================
-- MÉTODO: triggerRandomAmbient — Dispara um som ambiente aleatório
-- ==========================================
function AudioService:triggerRandomAmbient()
	if not _matchService then return end
	
	-- Lista de sons ambientes disponíveis
	local ambientSounds = {
		"Ambient_Wind",
		"Ambient_WoodCreak",
		"Ambient_DistantThunder",
		"Ambient_Whisper",
		"Ambient_Floorboard",
		"Ambient_DoorCreak",
	}
	
	-- Escolhe um som aleatório
	local soundName = ambientSounds[math.random(#ambientSounds)]
	
	-- Para cada sobrevivente vivo, envia o som em uma posição aleatória ao redor
	local survivorPlayers = _matchService:getPlayersByRole("Survivor")
	
	for _, player in survivorPlayers do
		local state = _matchService:getPlayerState(player)
		if state and state.isAlive then
			local playerPos = getPlayerPosition(player)
			
			if playerPos ~= Vector3.zero then
				-- Posição aleatória em um raio ao redor do jogador
				local angle = math.random() * math.pi * 2
				local radius = 10 + math.random() * AUDIO.AMBIENT_SPAWN_RADIUS
				local randomPos = Vector3.new(
					playerPos.X + math.cos(angle) * radius,
					playerPos.Y,
					playerPos.Z + math.sin(angle) * radius
				)
				
				sendAmbientSFX(player, soundName, randomPos)
			end
		end
	end
end

-- ==========================================
-- MÉTODOS PÚBLICOS: Controle de estado da partida
-- ==========================================

-- Chamado quando a partida começa
function AudioService:onMatchStart()
	print("[CacadaSombria] AudioService: Partida iniciada — áudio ativado")
	_isMatchActive = true
	_proximityTimer = 0
	_ambientTimer = 0
	
	-- Limpa cache de camadas de música
	table.clear(_lastMusicLayer)
	
	-- Envia comando de início de música para todos
	if _uiSyncEvent then
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.MUSIC_START,
			1  -- Começa na camada 1 (Exploração)
		)
	end
end

-- Chamado quando a partida termina
function AudioService:onMatchEnd()
	print("[CacadaSombria] AudioService: Partida encerrada — áudio pausado")
	_isMatchActive = false
	
	-- Envia comando de parar música para todos
	if _uiSyncEvent then
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.MUSIC_STOP
		)
		
		-- Para batimentos cardíacos de todos
		UISyncEvent.sendToAll(
			_uiSyncEvent,
			UISyncEvent.MESSAGES.HEARTBEAT_STOP
		)
	end
	
	table.clear(_lastMusicLayer)
end

-- ==========================================
-- MÉTODOS PÚBLICOS: SFX de Habilidades
-- ==========================================

-- Toca SFX de habilidade do Caçador
function AudioService:playKillerAbilitySFX(player: Player, abilityName: string)
	local sfxMap = {
		["M1_Tapa"] = "SFX_Killer_Slap",
		["BracoEsticado"] = "SFX_Killer_ArmStretch",
		["Rage"] = "SFX_Killer_RageTransform",
		["Grito"] = "SFX_Killer_Scream",
	}
	
	local soundName = sfxMap[abilityName]
	if soundName then
		-- O Caçador ouve o som em primeira pessoa (local)
		sendSFX(player, soundName, nil, 1.0)
		
		-- Sobreviventes próximos ouvem o som posicionado
		local killerPos = getPlayerPosition(player)
		if killerPos ~= Vector3.zero and _matchService then
			local survivorPlayers = _matchService:getPlayersByRole("Survivor")
			for _, survPlayer in survivorPlayers do
				local state = _matchService:getPlayerState(survPlayer)
				if state and state.isAlive then
					local distance = calculateDistance(killerPos, getPlayerPosition(survPlayer))
					if distance <= 80 then  -- Alcance máximo para ouvir habilidades do Caçador
						local volumeAtDistance = math.clamp(1.0 - (distance / 80), 0, 1)
						sendSFX(survPlayer, soundName, killerPos, volumeAtDistance)
					end
				end
			end
		end
	end
end

-- Toca SFX de habilidade de Sobrevivente
function AudioService:playSurvivorAbilitySFX(player: Player, abilityName: string)
	local sfxMap = {
		-- Soldado
		["DashTatico"] = "SFX_Soldier_Dash",
		["Bazuca"] = "SFX_Soldier_Bazooka",
		-- Sackboy
		["ArmaDeTinta"] = "SFX_Sackboy_InkGun",
		["Surto"] = "SFX_Sackboy_Surge",
		-- Robô
		["Agarrar"] = "SFX_Robot_Grab",
		["Block"] = "SFX_Robot_Block",
		["Sacrificio"] = "SFX_Robot_Sacrifice",
		-- Enfermeira
		["Curativo"] = "SFX_Nurse_Heal",
		["Adrenalina"] = "SFX_Nurse_Adrenaline",
		-- Campeão
		["Agarrao"] = "SFX_Champion_Grab",
		["Sequencia"] = "SFX_Champion_Combo",
	}
	
	local soundName = sfxMap[abilityName]
	if soundName then
		local playerPos = getPlayerPosition(player)
		
		-- O próprio jogador ouve o som local
		sendSFX(player, soundName, nil, 0.7)
		
		-- O Caçador ouve o som posicionado (se estiver próximo)
		if playerPos ~= Vector3.zero and _matchService then
			local killerPlayers = _matchService:getPlayersByRole("Killer")
			for _, killerPlayer in killerPlayers do
				local distance = calculateDistance(playerPos, getPlayerPosition(killerPlayer))
				if distance <= 60 then  -- Alcance para o Caçador ouvir habilidades
					local volumeAtDistance = math.clamp(1.0 - (distance / 60), 0, 1)
					sendSFX(killerPlayer, soundName, playerPos, volumeAtDistance)
				end
				break  -- Apenas o primeiro Caçador
			end
		end
	end
end

-- ==========================================
-- MÉTODOS PÚBLICOS: SFX de Eventos do Jogo
-- ==========================================

-- Toca som de gerador consertado
function AudioService:playGeneratorRepaired(generatorPosition: Vector3)
	sendSFXToAll("SFX_Generator_Complete", generatorPosition, 0.8)
end

-- Toca alarme de skill check falho (alerta global)
function AudioService:playGeneratorAlert(generatorPosition: Vector3)
	sendSFXToAll("SFX_Generator_Alert", generatorPosition, 1.0)
end

-- Toca som de todos os geradores consertados
function AudioService:playAllGeneratorsRepaired()
	sendSFXToAll("SFX_AllGenerators_Done", nil, 1.0)
end

-- Toca som do portão sendo ativado (alavanca puxada)
function AudioService:playGateActivated(gatePosition: Vector3?)
	sendSFXToAll("SFX_Gate_Alarm", gatePosition, 1.0)
end

-- Toca som do portão abrindo
function AudioService:playGateOpened(gatePosition: Vector3?)
	sendSFXToAll("SFX_Gate_Open", gatePosition, 1.0)
end

-- Toca som de colapso iniciado
function AudioService:playCollapseStarted()
	sendSFXToAll("SFX_Collapse_Alarm", nil, 1.0)
end

-- Toca som de vitória dos Sobreviventes
function AudioService:playVictorySurvivors()
	sendSFXToAll("SFX_Victory_Survivors", nil, 1.0)
end

-- Toca som de vitória do Caçador
function AudioService:playVictoryKiller()
	sendSFXToAll("SFX_Victory_Killer", nil, 1.0)
end

-- Toca som de Sobrevivente escapando
function AudioService:playSurvivorEscaped(player: Player)
	sendSFXToAll("SFX_Escape", getPlayerPosition(player), 0.6)
end

-- Toca som de dano recebido
function AudioService:playDamageTaken(player: Player, amount: number)
	local playerPos = getPlayerPosition(player)
	sendSFX(player, "SFX_Hit_Taken", nil, 0.8)
	
	-- O Caçador ouve o som de acerto
	if _matchService and playerPos ~= Vector3.zero then
		local killerPlayers = _matchService:getPlayersByRole("Killer")
		for _, killerPlayer in killerPlayers do
			sendSFX(killerPlayer, "SFX_Hit_Landed", playerPos, 0.7)
			break  -- Apenas o primeiro Caçador
		end
	end
end

-- Toca som de skill check click
function AudioService:playSkillCheckClick(player: Player, isHit: boolean)
	local soundName = isHit and "SFX_SkillCheck_Success" or "SFX_SkillCheck_Fail"
	sendSFX(player, soundName, nil, 0.6)
end

-- Toca som de cura
function AudioService:playHealSound(player: Player)
	sendSFX(player, "SFX_Heal", nil, 0.5)
end

-- Toca som de escudo ativado
function AudioService:playShieldSound(player: Player)
	sendSFX(player, "SFX_Shield", nil, 0.6)
end

return AudioService
