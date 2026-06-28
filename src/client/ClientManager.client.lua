--!strict
--[[
  ClientManager.client.lua
  Script principal do cliente — gerencia HUD, input e câmera.
  
  Responsável por:
  - Aguardar atribuição de papel do servidor
  - Inicializar sistemas de câmera (1ª ou 3ª pessoa)
  - Inicializar HUD (Survivor ou Killer)
  - Inicializar InputManager
  - Gerenciar ciclo de vida (respawn, morte, etc.)

  Fluxo de inicialização:
  1. Aguarda o jogo carregar (game:IsLoaded())
  2. Aguarda o character spawnar
  3. Recebe ROLE_ASSIGN do servidor
  4. Configura câmera e HUD de acordo com o papel
  5. Entra no game loop (input → servidor → render)

  Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- ==========================================
-- DEPENDÊNCIAS — MÓDULOS DO CLIENTE
-- ==========================================
local InputManager = require(script.Input.InputManager)
local CameraManager = require(script.Camera.CameraManager)
local AudioManager = require(script.Audio.AudioManager)
local SurvivorHUD = require(script.UI.SurvivorHUD)
local KillerHUD = require(script.UI.KillerHUD)
local CharacterSelectUI = require(script.UI.CharacterSelectUI)  -- Épico E7
local GameOverUI = require(script.UI.GameOverUI)                -- Épico E7

-- ==========================================
-- DEPENDÊNCIAS — MÓDULOS COMPARTILHADOS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- ==========================================
-- VARIÁVEIS DE ESTADO
-- ==========================================
local player = Players.LocalPlayer
local localRole: string? = nil    -- "Killer" ou "Survivor"
local localClassName: string? = nil
local isAlive = true

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- ==========================================
-- FUNÇÃO: Aguardar Carregamento
-- ==========================================

-- Aguarda o jogo estar completamente carregado antes de inicializar
local function waitForGameLoaded()
	if not game:IsLoaded() then
		print("[CacadaSombria] Aguardando jogo carregar...")
		game.Loaded:Wait()
	end
	print("[CacadaSombria] Jogo carregado!")
end

-- ==========================================
-- FUNÇÃO: Obter Eventos de Rede
-- ==========================================

-- Obtém as referências aos RemoteEvents de ReplicatedStorage
-- Retorna as referências ou nil se não encontradas
local function getRemoteEvents()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[CacadaSombria] ClientManager: Pasta 'Events' não encontrada em ReplicatedStorage")
		return nil, nil
	end

	local gameStateEvent = eventsFolder:FindFirstChild("GameStateEvent")
	local playerActionEvent = eventsFolder:FindFirstChild("PlayerActionEvent")

	if not gameStateEvent then
		warn("[CacadaSombria] ClientManager: GameStateEvent não encontrado")
	end
	if not playerActionEvent then
		warn("[CacadaSombria] ClientManager: PlayerActionEvent não encontrado")
	end

	return gameStateEvent, playerActionEvent
end

-- ==========================================
-- FUNÇÃO: Configurar Cliente
-- ==========================================

-- Configura o cliente baseado no papel recebido do servidor
local function setupClientForRole(role: string, className: string?)
	print(string.format("[CacadaSombria] Configurando cliente: %s como %s (%s)",
		player.Name, role, className or "n/a"))

	localRole = role
	localClassName = className

	if role == "Killer" then
		-- ==========================
		-- CAÇADOR
		-- ==========================

		-- 1. Configura câmera em primeira pessoa
		CameraManager.Init("FirstPerson")

		-- 2. Configura HUD do Caçador
		KillerHUD.Init()
		KillerHUD:show()

		-- 3. Esconde HUD de Sobrevivente (se existir)
		SurvivorHUD:hide()

		-- 4. Trava o mouse (câmera em 1ª pessoa)
		InputManager.lockMouse()

		-- 5. Inicializa o InputManager com o RemoteEvent
		-- (precisamos esperar os RemoteEvents)
		local _, actionEvent = getRemoteEvents()
		if actionEvent then
			InputManager.Init(actionEvent)
		end

		print("[CacadaSombria] Cliente configurado como CAÇADOR (1ª pessoa, FOV 90°)")

	elseif role == "Survivor" then
		-- ==========================
		-- SOBREVIVENTE
		-- ==========================

		-- 1. Configura câmera em terceira pessoa
		CameraManager.Init("ThirdPerson")

		-- 2. Configura HUD do Sobrevivente
		SurvivorHUD.Init()
		SurvivorHUD:show()

		-- 3. Esconde HUD do Caçador (se existir)
		KillerHUD:hide()

		-- 4. Trava o mouse (câmera em 3ª pessoa)
		InputManager.lockMouse()

		-- 5. Inicializa o InputManager
		local _, actionEvent = getRemoteEvents()
		if actionEvent then
			InputManager.Init(actionEvent)
		end

		print("[CacadaSombria] Cliente configurado como SOBREVIVENTE (3ª pessoa)")

	else
		warn(string.format("[CacadaSombria] Papel desconhecido: %s", role))
	end
end

-- ==========================================
-- FUNÇÃO: Registrar Listeners do Servidor
-- ==========================================

-- Escuta mensagens do servidor via GameStateEvent
local function listenForRoleAssignment()
	local gameStateEvent, _ = getRemoteEvents()
	if not gameStateEvent then
		warn("[CacadaSombria] Não foi possível escutar GameStateEvent")
		return
	end

	-- Handler de mensagens do servidor
	local conn = gameStateEvent.OnClientEvent:Connect(function(messageType: string, ...)
		if messageType == GameStateEvent.MESSAGES.ROLE_ASSIGN then
			-- Recebeu atribuição de papel!
			local role: string = select(1, ...)
			local className: string? = select(2, ...)

			print(string.format("[CacadaSombria] Papel recebido: %s (%s)",
				role, className or "n/a"))

			-- Configura o cliente de acordo
			setupClientForRole(role, className)

		elseif messageType == GameStateEvent.MESSAGES.GAME_OVER then
			-- Partida terminou — esconde HUDs, mostra GameOverUI
			local winner: string = select(1, ...)
			local reason: string? = select(2, ...)
			local matchStats: any? = select(3, ...)
			print(string.format("[CacadaSombria] Fim de jogo! Vencedor: %s", winner))

			-- Esconde HUDs de jogo
			SurvivorHUD:hide()
			KillerHUD:hide()

			-- Mostra a tela de resultado
			GameOverUI:showResult(winner, reason, matchStats)

		elseif messageType == GameStateEvent.MESSAGES.PREPARE_COUNTDOWN then
			-- Contagem regressiva antes da caçada
			local seconds: number = select(1, ...)
			StarterGui:SetCore("SendNotification", {
				Title = "Preparar!",
				Text = "A caçada começa em " .. seconds .. "s",
				Duration = 1,
			})

		elseif messageType == GameStateEvent.MESSAGES.CHARACTER_SELECT then
			-- Fase de seleção de personagem iniciou — mostra CharacterSelectUI
			SurvivorHUD:hide()
			KillerHUD:hide()
			CharacterSelectUI:show()

		elseif messageType == GameStateEvent.MESSAGES.MATCH_STATE then
			-- Estado da partida mudou
			local newState: string = select(1, ...)
			print(string.format("[CacadaSombria] Estado da partida: %s", newState))
			-- Se saiu da seleção, esconde a tela de seleção
			if newState == "Preparing" or newState == "Hunting" then
				CharacterSelectUI:hide()
			end

		elseif messageType == GameStateEvent.MESSAGES.SELECT_TIMER then
			-- Timer da seleção (já tratado internamente pelo CharacterSelectUI)

		elseif messageType == GameStateEvent.MESSAGES.CHARACTER_SELECTED then
			-- Outro jogador escolheu classe (já tratado internamente)

		elseif messageType == GameStateEvent.MESSAGES.LOBBY_UPDATE then
			-- Atualização do lobby (já tratado internamente)

		elseif messageType == GameStateEvent.MESSAGES.HOST_ASSIGNED then
			-- Jogador foi designado como host
			local isHost: boolean = select(1, ...)
			if isHost then
				print("[CacadaSombria] Você é o HOST do lobby!")
				StarterGui:SetCore("SendNotification", {
					Title = "Lobby",
					Text = "Você é o HOST! Pressione 'Iniciar' quando todos estiverem prontos.",
					Duration = 5,
				})
			end

		elseif messageType == "KillerAssigned" then
			local killerName: string = select(1, ...)
			print(string.format("[CacadaSombria] Caçador atribuído: %s", killerName))
		end
	end)

	table.insert(_connections, conn)
end

-- ==========================================
-- FUNÇÃO: Character Spawn Handler
-- ==========================================

-- Chamado sempre que o character do jogador spawna/respawna
local function onCharacterAdded(character: Model)
	print(string.format("[CacadaSombria] Character spawnado: %s", character.Name))

	-- Aguarda o Humanoid ficar disponível
	local humanoid: Humanoid? = character:WaitForChild("Humanoid", 5)
	if humanoid then
		-- Configura o estado de acordo com o papel
		-- (a velocidade é controlada pelo servidor, mas podemos configurar
		--  coisas visuais aqui)
		print(string.format("[CacadaSombria] Humanoid pronto para %s", player.Name))
	end

	-- Reseta o estado de vida
	isAlive = true
end

-- ==========================================
-- PONTO DE ENTRADA PRINCIPAL
-- ==========================================

local function main()
	print("[CacadaSombria] ╔══════════════════════════════════════╗")
	print("[CacadaSombria] ║   CAÇADA SOMBRIA — CLIENTE         ║")
	print(string.format("[CacadaSombria] ║   Jogador: %s", player.Name))
	print("[CacadaSombria] ╚══════════════════════════════════════╝")

	-- 1. Aguarda o jogo carregar completamente
	waitForGameLoaded()

	-- 2. Inicializa o sistema de áudio (antes de qualquer outra coisa)
	AudioManager.Init()

	-- 3. Inicializa as UIs de lobby e resultado (Épico E7)
	CharacterSelectUI.Init()
	GameOverUI.Init()

	-- 4. Escuta atribuição de papel do servidor
	listenForRoleAssignment()

	-- 5. Registra handler de spawn de character
	player.CharacterAdded:Connect(onCharacterAdded)

	-- 6. Se o character já existe (ex: respawn), configura agora
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- 7. Configurações iniciais de UI
	-- Reseta o StarterGui para estado limpo
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) -- Chat sempre ativo

	-- 8. Tenta obter papel via RemoteFunction (GetMatchInfo)
	-- Isso é útil se o servidor já atribuiu o papel antes do cliente carregar
	task.spawn(function()
		local functionsFolder = ReplicatedStorage:FindFirstChild("Functions")
		if functionsFolder then
			local getMatchInfo: RemoteFunction? = functionsFolder:FindFirstChild("GetMatchInfoFunction")
			if getMatchInfo then
				-- Aguarda um momento para o servidor processar
				task.wait(1)

				-- Chama a RemoteFunction para obter estado atual
				local ok, result = pcall(function()
					return getMatchInfo:InvokeServer()
				end)

				if ok and result and result.role then
					print(string.format("[CacadaSombria] Papel obtido via GetMatchInfo: %s", result.role))
					setupClientForRole(result.role, result.className)
				end
			end
		end
	end)

	print("[CacadaSombria] ClientManager carregado! Aguardando papel do servidor...")
end

-- ==========================================
-- EXECUÇÃO
-- ==========================================

task.spawn(main)
