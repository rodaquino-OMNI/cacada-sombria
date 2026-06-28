--!strict
--[[
  AudioManager.lua
  Gerenciador de áudio do cliente — executa a reprodução dos sons
  conforme comandos recebidos do servidor via UISyncEvent.
  
  Responsável por:
  - Crossfade entre 3 camadas de música dinâmica
  - Reprodução de batimentos cardíacos com volume/ritmo variável
  - Reprodução de SFX de habilidades (posicionais 3D)
  - Sons ambientes posicionais aleatórios
  - Sons de UI (skill check, alarmes, vitória/derrota)
  
  Princípios:
  - Todo áudio deve ser MONO para espacialização 3D
  - Usar SoundService e SoundGroups do Roblox
  - Placeholders: usar IDs de assets gratuitos da biblioteca Roblox
  - Respeitar volume e posição enviados pelo servidor
  
  Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)

-- ==========================================
-- CONSTANTES DE ÁUDIO (PLACEHOLDERS — IDs REAIS)
-- ==========================================
-- Estes IDs são placeholders da biblioteca gratuita do Roblox.
-- Consulte docs/audio-setup-guide.md para os IDs corretos.
-- Para encontrar no Toolbox: buscar pelo termo de pesquisa indicado.

local AUDIO_IDS = {
	-- ========================================
	-- MÚSICA — 3 CAMADAS DINÂMICAS
	-- ========================================
	-- Layer 1: Exploração (>60 studs do Caçador)
	-- Som: Ambiente tranquilo, tons graves, drones suaves
	-- Buscar no Toolbox: "horror ambient drone dark"
	Music_Layer1 = "rbxassetid://1837841298",  -- Placeholder: Dark ambient drone
	
	-- Layer 2: Alerta (30–60 studs do Caçador)
	-- Som: Cordas tensas, percussão leve, pulsação
	-- Buscar no Toolbox: "horror tension strings suspense"
	Music_Layer2 = "rbxassetid://1837841322",  -- Placeholder: Tension strings
	
	-- Layer 3: Perseguição (<30 studs do Caçador)
	-- Som: Percussão intensa, metais, batimentos agressivos
	-- Buscar no Toolbox: "horror chase intense percussion"
	Music_Layer3 = "rbxassetid://1837841345",  -- Placeholder: Chase percussion
	
	-- ========================================
	-- BATIMENTOS CARDÍACOS
	-- ========================================
	-- Som: Batida de coração única (loop será feito via script)
	-- Buscar no Toolbox: "heartbeat sound effect"
	Heartbeat = "rbxassetid://1837840987",  -- Placeholder: Heartbeat
	
	-- ========================================
	-- SFX — CAÇADOR (O DISTORCIDO)
	-- ========================================
	-- Buscar no Toolbox: "slap hit impact"
	SFX_Killer_Slap = "rbxassetid://1837841001",
	-- Buscar no Toolbox: "stretch elastic pull"
	SFX_Killer_ArmStretch = "rbxassetid://1837841015",
	-- Buscar no Toolbox: "monster roar transform"
	SFX_Killer_RageTransform = "rbxassetid://1837841028",
	-- Buscar no Toolbox: "horror scream monster"
	SFX_Killer_Scream = "rbxassetid://1837841040",
	
	-- ========================================
	-- SFX — SOBREVIVENTES
	-- ========================================
	-- Soldado
	-- Buscar no Toolbox: "dash whoosh fast"
	SFX_Soldier_Dash = "rbxassetid://1837841053",
	-- Buscar no Toolbox: "bazooka rocket launch"
	SFX_Soldier_Bazooka = "rbxassetid://1837841065",
	
	-- Sackboy
	-- Buscar no Toolbox: "paint splat squish"
	SFX_Sackboy_InkGun = "rbxassetid://1837841078",
	-- Buscar no Toolbox: "speed boost rush"
	SFX_Sackboy_Surge = "rbxassetid://1837841090",
	
	-- Robô
	-- Buscar no Toolbox: "robot grab mechanical"
	SFX_Robot_Grab = "rbxassetid://1837841102",
	-- Buscar no Toolbox: "metal block shield"
	SFX_Robot_Block = "rbxassetid://1837841115",
	-- Buscar no Toolbox: "explosion sacrifice"
	SFX_Robot_Sacrifice = "rbxassetid://1837841127",
	
	-- Enfermeira
	-- Buscar no Toolbox: "heal magic sparkle"
	SFX_Nurse_Heal = "rbxassetid://1837841140",
	-- Buscar no Toolbox: "injection syringe"
	SFX_Nurse_Adrenaline = "rbxassetid://1837841152",
	
	-- Campeão
	-- Buscar no Toolbox: "grab grapple hook"
	SFX_Champion_Grab = "rbxassetid://1837841165",
	-- Buscar no Toolbox: "punch combo fighting"
	SFX_Champion_Combo = "rbxassetid://1837841178",
	
	-- ========================================
	-- SFX — EVENTOS DO JOGO
	-- ========================================
	-- Buscar no Toolbox: "generator power up complete"
	SFX_Generator_Complete = "rbxassetid://1837841190",
	-- Buscar no Toolbox: "alarm siren loud"
	SFX_Generator_Alert = "rbxassetid://1837841202",
	-- Buscar no Toolbox: "all complete fanfare short"
	SFX_AllGenerators_Done = "rbxassetid://1837841215",
	-- Buscar no Toolbox: "gate alarm buzzer"
	SFX_Gate_Alarm = "rbxassetid://1837841227",
	-- Buscar no Toolbox: "gate open heavy metal"
	SFX_Gate_Open = "rbxassetid://1837841240",
	-- Buscar no Toolbox: "collapse destruction rumble"
	SFX_Collapse_Alarm = "rbxassetid://1837841252",
	
	-- ========================================
	-- SFX — RESULTADOS
	-- ========================================
	-- Buscar no Toolbox: "victory fanfare survivors"
	SFX_Victory_Survivors = "rbxassetid://1837841265",
	-- Buscar no Toolbox: "victory dark killer"
	SFX_Victory_Killer = "rbxassetid://1837841278",
	-- Buscar no Toolbox: "escape door close"
	SFX_Escape = "rbxassetid://1837841290",
	
	-- ========================================
	-- SFX — COMBATE E INTERAÇÃO
	-- ========================================
	-- Buscar no Toolbox: "hit taken ouch pain"
	SFX_Hit_Taken = "rbxassetid://1837841358",
	-- Buscar no Toolbox: "hit landed punch impact"
	SFX_Hit_Landed = "rbxassetid://1837841370",
	-- Buscar no Toolbox: "heal restore potion"
	SFX_Heal = "rbxassetid://1837841383",
	-- Buscar no Toolbox: "shield activate energy"
	SFX_Shield = "rbxassetid://1837841395",
	
	-- ========================================
	-- SFX — SKILL CHECKS
	-- ========================================
	-- Buscar no Toolbox: "click success correct"
	SFX_SkillCheck_Success = "rbxassetid://1837841408",
	-- Buscar no Toolbox: "error fail buzzer"
	SFX_SkillCheck_Fail = "rbxassetid://1837841420",
	
	-- ========================================
	-- SONS AMBIENTES
	-- ========================================
	-- Buscar no Toolbox: "wind howl ambient"
	Ambient_Wind = "rbxassetid://1837841433",
	-- Buscar no Toolbox: "wood creak floorboard"
	Ambient_WoodCreak = "rbxassetid://1837841445",
	-- Buscar no Toolbox: "distant thunder rumble"
	Ambient_DistantThunder = "rbxassetid://1837841458",
	-- Buscar no Toolbox: "whisper ghost creepy"
	Ambient_Whisper = "rbxassetid://1837841470",
	-- Buscar no Toolbox: "floorboard step creak"
	Ambient_Floorboard = "rbxassetid://1837841483",
	-- Buscar no Toolbox: "door creak open"
	Ambient_DoorCreak = "rbxassetid://1837841495",
}

-- ==========================================
-- GERENCIADOR AUDIOMANAGER
-- ==========================================
local AudioManager = {}
AudioManager.__index = AudioManager

-- ==========================================
-- ESTADO INTERNO
-- ==========================================
local _player = Players.LocalPlayer

-- Referências aos objetos Sound ativos
local _musicLayers: {[number]: Sound} = {}       -- Tabela {layerNumber -> Sound}
local _heartbeatSound: Sound? = nil               -- Som do batimento cardíaco
local _activeSFX: {Sound} = {}                    -- Lista de SFX ativos para cleanup
local _activeAmbient: {Sound} = {}                -- Lista de sons ambientes ativos

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- Grupo de som personalizado para controle de volume mestre
local _soundGroup: SoundGroup? = nil

-- ==========================================
-- FUNÇÕES AUXILIARES
-- ==========================================

-- Cria um objeto Sound configurado corretamente (MONO para 3D)
local function createSound(soundId: string, parent: Instance?, volume: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1.0
	sound.PlaybackSpeed = 1.0
	sound.Looped = false
	
	-- Importante: MONO para espacialização 3D funcionar
	-- (No Roblox, Sounds são stereo por padrão, mas a espacialização
	--  funciona melhor com sons mono; o engine trata automaticamente)
	
	if parent then
		sound.Parent = parent
	end
	
	-- Usa o SoundGroup personalizado para controle de volume
	if _soundGroup then
		sound.SoundGroup = _soundGroup
	end
	
	return sound
end

-- Limpa uma tabela de sons, parando e destruindo cada um
local function cleanupSounds(soundTable: {Sound})
	for _, sound in soundTable do
		if sound.IsPlaying then
			sound:Stop()
		end
		sound:Destroy()
	end
	table.clear(soundTable)
end

-- Posiciona um som em uma localização 3D (via Attachment ou parte)
local function positionSound3D(sound: Sound, position: Vector3)
	-- Cria uma parte invisível para ancorar o som na posição 3D
	-- (Roblox espacializa sons baseado na posição do Parent)
	local anchor = Instance.new("Part")
	anchor.Name = "AudioAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1.0
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Position = position
	anchor.Parent = Workspace
	
	sound.Parent = anchor
	
	-- Destroi a âncora quando o som terminar
	sound.Ended:Connect(function()
		anchor:Destroy()
	end)
	
	return anchor
end

-- ==========================================
-- INICIALIZAÇÃO DO SISTEMA DE ÁUDIO
-- ==========================================

-- Cria/obtém o SoundGroup personalizado
function AudioManager:setupSoundGroups()
	-- O SoundGroup "GameAudio" permite controle de volume mestre
	-- independente do volume do sistema
	_soundGroup = SoundService:FindFirstChild("GameAudio")
	if not _soundGroup then
		_soundGroup = Instance.new("SoundGroup")
		_soundGroup.Name = "GameAudio"
		_soundGroup.Volume = 1.0
		_soundGroup.Parent = SoundService
	end
	
	print("[CacadaSombria] AudioManager: SoundGroup configurado")
end

-- Inicializa as 3 camadas de música (paradas inicialmente)
function AudioManager:setupMusicLayers()
	for layer = 1, 3 do
		local soundId = AUDIO_IDS["Music_Layer" .. layer]
		if soundId then
			local sound = createSound(soundId, SoundService, 0)
			sound.Looped = true  -- Música toca em loop
			sound.Name = "Music_Layer" .. layer
			_musicLayers[layer] = sound
			
			print(string.format("[CacadaSombria] AudioManager: Music_Layer%d carregada", layer))
		end
	end
end

-- Inicializa o som de batimento cardíaco
function AudioManager:setupHeartbeat()
	local soundId = AUDIO_IDS.Heartbeat
	if soundId then
		_heartbeatSound = createSound(soundId, SoundService, 0)
		_heartbeatSound.Name = "Heartbeat"
		-- Não é loop — será controlado via PlaybackSpeed para variar o ritmo
		
		print("[CacadaSombria] AudioManager: Heartbeat configurado")
	end
end

-- ==========================================
-- MÉTODOS: Controle de Música
-- ==========================================

-- Inicia a reprodução da música na camada especificada
function AudioManager:startMusic(layer: number)
	for lyr, sound in _musicLayers do
		if not sound.IsPlaying then
			sound:Play()
		end
		-- Começa com volume 0 (será ajustado pelo crossfade)
		sound.Volume = 0
	end
end

-- Para toda a música
function AudioManager:stopMusic()
	for _, sound in _musicLayers do
		if sound.IsPlaying then
			sound:Stop()
		end
		sound.Volume = 0
	end
end

-- Crossfade entre camadas de música
-- targetLayer: 1, 2 ou 3
-- duration: duração do crossfade em segundos
function AudioManager:crossfadeMusic(targetLayer: number, duration: number)
	if duration <= 0 then
		-- Crossfade instantâneo
		for lyr, sound in _musicLayers do
			sound.Volume = (lyr == targetLayer) and 1.0 or 0.0
		end
		return
	end
	
	-- Crossfade gradual usando TweenService
	local TweenService = game:GetService("TweenService")
	
	for lyr, sound in _musicLayers do
		local targetVolume = (lyr == targetLayer) and 1.0 or 0.0
		
		-- Cria um tween para transição suave de volume
		local tweenInfo = TweenInfo.new(
			duration,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)
		
		local tween = TweenService:Create(sound, tweenInfo, {Volume = targetVolume})
		tween:Play()
		
		-- Se está fazendo fade out (volume → 0), para o som após o fade
		if targetVolume == 0 then
			task.delay(duration, function()
				if sound and sound.Volume < 0.01 then
					-- Mantém o som tocando em loop mas em volume baixíssimo
					-- (evita delay ao voltar para esta camada)
				end
			end)
		end
	end
	
	print(string.format("[CacadaSombria] AudioManager: Crossfade → Layer %d (%.1fs)", targetLayer, duration))
end

-- ==========================================
-- MÉTODOS: Batimentos Cardíacos
-- ==========================================

-- Atualiza o volume e ritmo dos batimentos cardíacos
-- volume: 0 (sem batimento) a 1 (batimento máximo)
function AudioManager:updateHeartbeat(volume: number)
	if not _heartbeatSound then return end
	
	if volume <= 0.01 then
		-- Praticamente inaudível — para o som
		if _heartbeatSound.IsPlaying then
			_heartbeatSound:Stop()
		end
		return
	end
	
	-- Ajusta volume
	_heartbeatSound.Volume = volume
	
	-- Ajusta ritmo: mais rápido conforme volume aumenta
	-- Volume 0 → PlaybackSpeed 0.7 (lento), Volume 1 → PlaybackSpeed 1.5 (rápido)
	_heartbeatSound.PlaybackSpeed = 0.7 + (volume * 0.8)
	
	-- Se não está tocando, inicia
	if not _heartbeatSound.IsPlaying then
		_heartbeatSound:Play()
	end
end

-- Para os batimentos cardíacos completamente
function AudioManager:stopHeartbeat()
	if _heartbeatSound then
		_heartbeatSound:Stop()
		_heartbeatSound.Volume = 0
		_heartbeatSound.PlaybackSpeed = 1.0
	end
end

-- ==========================================
-- MÉTODOS: SFX
-- ==========================================

-- Toca um SFX pelo nome (da tabela AUDIO_IDS)
-- Se position for fornecida, o som é espacializado em 3D
-- Se position for nil ou Vector3.zero, o som é tocado localmente (2D)
function AudioManager:playSFX(soundName: string, position: Vector3?, volume: number?)
	local soundId = AUDIO_IDS[soundName]
	if not soundId then
		warn(string.format("[CacadaSombria] AudioManager: SFX '%s' não encontrado na tabela AUDIO_IDS", soundName))
		return
	end
	
	local sound = createSound(soundId, nil, volume or 1.0)
	
	-- Decide se é som 2D (local) ou 3D (posicional)
	if position and position ~= Vector3.zero then
		-- Som posicional 3D
		positionSound3D(sound, position)
	else
		-- Som local 2D (tocado no SoundService)
		sound.Parent = SoundService
	end
	
	-- Toca e agenda limpeza
	sound:Play()
	
	-- Insere na lista de SFX ativos
	table.insert(_activeSFX, sound)
	
	-- Remove da lista quando terminar
	sound.Ended:Connect(function()
		for i, s in _activeSFX do
			if s == sound then
				table.remove(_activeSFX, i)
				break
			end
		end
		-- Destroi o som após tocar (a âncora já foi destruída em positionSound3D)
		sound:Destroy()
	end)
end

-- Toca um som ambiente (sempre posicional 3D)
function AudioManager:playAmbient(soundName: string, position: Vector3)
	self:playSFX(soundName, position, 0.5)  -- Volume reduzido para ambientes
end

-- ==========================================
-- LIMPEZA PERIÓDICA DE SONS
-- ==========================================

-- Remove sons que já terminaram da lista de ativos
function AudioManager:cleanupFinishedSounds()
	-- Limpa SFX que já terminaram
	for i = #_activeSFX, 1, -1 do
		local sound = _activeSFX[i]
		if not sound or not sound.Parent then
			table.remove(_activeSFX, i)
		end
	end
end

-- ==========================================
-- INICIALIZAÇÃO PRINCIPAL
-- ==========================================

function AudioManager.Init()
	print("[CacadaSombria] AudioManager.Init — Inicializando sistema de áudio do cliente...")
	
	-- Configura grupos de som
	AudioManager:setupSoundGroups()
	
	-- Configura as 3 camadas de música
	AudioManager:setupMusicLayers()
	
	-- Configura batimentos cardíacos
	AudioManager:setupHeartbeat()
	
	-- Conecta ao UISyncEvent para receber comandos do servidor
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[CacadaSombria] AudioManager: Pasta 'Events' não encontrada")
		return
	end
	
	-- Busca o RemoteEvent (não o ModuleScript de mesmo nome)
	-- IMPORTANTE: FindFirstChild pode retornar o ModuleScript UISyncEvent.lua
	-- Precisamos especificamente do RemoteEvent criado pelo servidor
	local uiSyncEvent = nil
	for _, child in eventsFolder:GetChildren() do
		if child:IsA("RemoteEvent") and child.Name == "UISyncEvent" then
			uiSyncEvent = child
			break
		end
	end
	if not uiSyncEvent then
		warn("[CacadaSombria] AudioManager: RemoteEvent UISyncEvent não encontrado")
		return
	end
	
	-- Registra listener para mensagens de áudio do servidor
	local conn = uiSyncEvent.OnClientEvent:Connect(function(messageType: string, ...)
		AudioManager:onServerMessage(messageType, ...)
	end)
	table.insert(_connections, conn)
	
	print("[CacadaSombria] AudioManager inicializado! Aguardando comandos do servidor...")
end

-- ==========================================
-- HANDLER DE MENSAGENS DO SERVIDOR
-- ==========================================

function AudioManager:onServerMessage(messageType: string, ...)
	-- Música
	if messageType == UISyncEvent.MESSAGES.MUSIC_START then
		local layer = select(1, ...) or 1
		self:startMusic(layer)
		
	elseif messageType == UISyncEvent.MESSAGES.MUSIC_STOP then
		self:stopMusic()
		
	elseif messageType == UISyncEvent.MESSAGES.MUSIC_CROSSFADE then
		local targetLayer: number = select(1, ...)
		local duration: number = select(2, ...) or 2.0
		self:crossfadeMusic(targetLayer, duration)
		
	-- Batimentos cardíacos
	elseif messageType == UISyncEvent.MESSAGES.HEARTBEAT_UPDATE then
		local volume: number = select(1, ...) or 0
		self:updateHeartbeat(volume)
		
	elseif messageType == UISyncEvent.MESSAGES.HEARTBEAT_STOP then
		self:stopHeartbeat()
		
	-- SFX e sons ambientes
	elseif messageType == UISyncEvent.MESSAGES.PLAY_SFX then
		local soundName: string = select(1, ...)
		local position: Vector3 = select(2, ...)
		local volume: number? = select(3, ...)
		self:playSFX(soundName, position, volume)
		
	elseif messageType == UISyncEvent.MESSAGES.PLAY_AMBIENT then
		local soundName: string = select(1, ...)
		local position: Vector3 = select(2, ...)
		self:playAmbient(soundName, position)
	end
end

-- ==========================================
-- CLEANUP AO DESTRUIR
-- ==========================================

function AudioManager:destroy()
	-- Desconecta todos os listeners
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)
	
	-- Para e limpa música
	self:stopMusic()
	for _, sound in _musicLayers do
		sound:Destroy()
	end
	table.clear(_musicLayers)
	
	-- Para batimentos
	self:stopHeartbeat()
	if _heartbeatSound then
		_heartbeatSound:Destroy()
		_heartbeatSound = nil
	end
	
	-- Limpa SFX ativos
	cleanupSounds(_activeSFX)
	cleanupSounds(_activeAmbient)
	
	print("[CacadaSombria] AudioManager destruído")
end

return AudioManager
