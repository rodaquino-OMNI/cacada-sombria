--!strict
--[[
	GameOverUI.lua
	Tela de resultado da partida — exibida quando a partida termina.
	
	Responsável por:
	- Exibir o vencedor (Caçador ou Sobreviventes)
	- Mostrar estatísticas da partida (geradores consertados, capturas, fugas)
	- Mostrar o desempenho individual de cada jogador
	- Botão "Voltar ao Lobby"
	- Transição visual de fade in/out

	Design:
	- Overlay escuro com painel central
	- Título grande com o resultado
	- Tabela de estatísticas
	- Botão estilizado para retornar ao lobby

	Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- SERVIÇO GAMEOVERUI
-- ==========================================
local GameOverUI = {}
GameOverUI.__index = GameOverUI

-- ==========================================
-- ESTADO INTERNO
-- ==========================================
local _player = Players.LocalPlayer
local _playerGui: PlayerGui? = nil
local _screenGui: ScreenGui? = nil
local _isVisible = false

-- Elementos da UI
local _mainFrame: Frame? = nil
local _resultTitle: TextLabel? = nil
local _resultSubtitle: TextLabel? = nil
local _statsFrame: Frame? = nil
local _playerStatsContainer: Frame? = nil
local _returnButton: TextButton? = nil

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- Referência ao PlayerActionEvent (para enviar "ReturnToLobby" ao servidor)
local _playerActionEvent: RemoteEvent? = nil

-- ==========================================
-- CONSTANTES DE DESIGN
-- ==========================================
local BG_COLOR = Color3.fromRGB(15, 15, 20)
local ACCENT_COLOR = Color3.fromRGB(180, 50, 50)       -- Vermelho escuro
local WIN_COLOR = Color3.fromRGB(255, 215, 0)           -- Dourado (vitória)
local LOSE_COLOR = Color3.fromRGB(180, 50, 50)          -- Vermelho (derrota)
local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
local CORNER_RADIUS = UDim.new(0, 12)

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Cria a tela de resultado
-- Chamado pelo ClientManager durante a inicialização
function GameOverUI.Init()
	-- Obtém o PlayerGui
	_playerGui = _player:FindFirstChild("PlayerGui")
	if not _playerGui then
		warn("[CacadaSombria] GameOverUI: PlayerGui não encontrado!")
		return
	end

	-- Obtém o PlayerActionEvent
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_playerActionEvent = eventsFolder:FindFirstChild("PlayerActionEvent")
	end

	-- Cria o ScreenGui (oculto inicialmente)
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "GameOverUI"
	_screenGui.ResetOnSpawn = false
	_screenGui.Enabled = false
	_screenGui.Parent = _playerGui

	-- Cria os elementos da tela
	GameOverUI:_createOverlay()
	GameOverUI:_createMainPanel()
	GameOverUI:_createResultTitle()
	GameOverUI:_createStatsSection()
	GameOverUI:_createReturnButton()

	-- Registra listeners de eventos
	GameOverUI:_registerEventListeners()

	print("[CacadaSombria] GameOverUI criado.")
end

-- ==========================================
-- CRIAÇÃO DOS ELEMENTOS VISUAIS
-- ==========================================

-- Cria o overlay escuro (fundo)
function GameOverUI:_createOverlay()
	if not _screenGui then return end

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.75
	overlay.BorderSizePixel = 0
	overlay.Parent = _screenGui
end

-- Cria o painel principal centralizado
function GameOverUI:_createMainPanel()
	if not _screenGui then return end

	_mainFrame = Instance.new("Frame")
	_mainFrame.Name = "MainPanel"
	_mainFrame.Size = UDim2.new(0, 500, 0, 400)
	_mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
	_mainFrame.BackgroundColor3 = BG_COLOR
	_mainFrame.BackgroundTransparency = 0.1
	_mainFrame.BorderSizePixel = 0
	_mainFrame.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = _mainFrame

	-- Borda decorativa
	local border = Instance.new("UIStroke")
	border.Thickness = 2
	border.Color = ACCENT_COLOR
	border.Transparency = 0.4
	border.Parent = _mainFrame
end

-- Cria o título do resultado (ex: "SOBREVIVENTES VENCERAM!")
function GameOverUI:_createResultTitle()
	if not _mainFrame then return end

	_resultTitle = Instance.new("TextLabel")
	_resultTitle.Name = "ResultTitle"
	_resultTitle.Size = UDim2.new(1, -40, 0, 50)
	_resultTitle.Position = UDim2.new(0, 20, 0, 30)
	_resultTitle.BackgroundTransparency = 1
	_resultTitle.Text = "FIM DE JOGO"
	_resultTitle.TextColor3 = TEXT_COLOR
	_resultTitle.TextSize = 34
	_resultTitle.Font = Enum.Font.GothamBlack
	_resultTitle.Parent = _mainFrame

	-- Subtítulo (detalhes do resultado)
	_resultSubtitle = Instance.new("TextLabel")
	_resultSubtitle.Name = "ResultSubtitle"
	_resultSubtitle.Size = UDim2.new(1, -40, 0, 24)
	_resultSubtitle.Position = UDim2.new(0, 20, 0, 85)
	_resultSubtitle.BackgroundTransparency = 1
	_resultSubtitle.Text = ""
	_resultSubtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	_resultSubtitle.TextSize = 16
	_resultSubtitle.Font = Enum.Font.Gotham
	_resultSubtitle.Parent = _mainFrame
end

-- Cria a seção de estatísticas
function GameOverUI:_createStatsSection()
	if not _mainFrame then return end

	-- Container das estatísticas
	_statsFrame = Instance.new("Frame")
	_statsFrame.Name = "StatsFrame"
	_statsFrame.Size = UDim2.new(1, -40, 0, 160)
	_statsFrame.Position = UDim2.new(0, 20, 0, 120)
	_statsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	_statsFrame.BackgroundTransparency = 0.3
	_statsFrame.BorderSizePixel = 0
	_statsFrame.Parent = _mainFrame

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 8)
	statsCorner.Parent = _statsFrame

	-- Título da seção
	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "StatsTitle"
	statsTitle.Size = UDim2.new(1, 0, 0, 24)
	statsTitle.Position = UDim2.new(0, 8, 0, 4)
	statsTitle.BackgroundTransparency = 1
	statsTitle.Text = "📊 ESTATÍSTICAS DA PARTIDA"
	statsTitle.TextColor3 = ACCENT_COLOR
	statsTitle.TextSize = 13
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.TextXAlignment = Enum.TextXAlignment.Left
	statsTitle.Parent = _statsFrame

	-- Container para as estatísticas dos jogadores
	_playerStatsContainer = Instance.new("Frame")
	_playerStatsContainer.Name = "PlayerStatsContainer"
	_playerStatsContainer.Size = UDim2.new(1, -16, 0, 120)
	_playerStatsContainer.Position = UDim2.new(0, 8, 0, 32)
	_playerStatsContainer.BackgroundTransparency = 1
	_playerStatsContainer.Parent = _statsFrame

	-- Layout em lista vertical
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = _playerStatsContainer
end

-- Cria o botão "Voltar ao Lobby"
function GameOverUI:_createReturnButton()
	if not _mainFrame then return end

	_returnButton = Instance.new("TextButton")
	_returnButton.Name = "ReturnButton"
	_returnButton.Size = UDim2.new(0, 240, 0, 44)
	_returnButton.Position = UDim2.new(0.5, -120, 0, 300)
	_returnButton.BackgroundColor3 = ACCENT_COLOR
	_returnButton.BorderSizePixel = 0
	_returnButton.Text = "VOLTAR AO LOBBY"
	_returnButton.TextColor3 = TEXT_COLOR
	_returnButton.TextSize = 18
	_returnButton.Font = Enum.Font.GothamBold
	_returnButton.AutoButtonColor = false
	_returnButton.Parent = _mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = _returnButton

	-- Efeito hover
	_returnButton.MouseEnter:Connect(function()
		_returnButton.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
	end)
	_returnButton.MouseLeave:Connect(function()
		_returnButton.BackgroundColor3 = ACCENT_COLOR
	end)

	-- Clique: voltar ao lobby
	_returnButton.MouseButton1Click:Connect(function()
		GameOverUI:_onReturnToLobby()
	end)
end

-- ==========================================
-- LISTENERS DE EVENTOS DO SERVIDOR
-- ==========================================

-- Registra handlers para mensagens do servidor
function GameOverUI:_registerEventListeners()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[CacadaSombria] GameOverUI: Pasta 'Events' não encontrada")
		return
	end

	local gameStateEvent: RemoteEvent? = eventsFolder:FindFirstChild("GameStateEvent")
	if not gameStateEvent then
		warn("[CacadaSombria] GameOverUI: GameStateEvent não encontrado")
		return
	end

	local conn = gameStateEvent.OnClientEvent:Connect(function(messageType: string, ...)
		GameOverUI:_handleServerMessage(messageType, ...)
	end)
	table.insert(_connections, conn)

	print("[CacadaSombria] GameOverUI: Listener de GameStateEvent registrado.")
end

-- Processa mensagens recebidas do servidor
function GameOverUI:_handleServerMessage(messageType: string, ...)
	local args = {...}

	-- ==========================
	-- FIM DE JOGO
	-- ==========================
	if messageType == GameStateEvent.MESSAGES.GAME_OVER then
		local winner: string = args[1]      -- "Killer" ou "Survivors"
		local reason: string? = args[2]      -- motivo (ex: "CaçadorDesconectou", "Fuga", "TempoEsgotado")
		local matchStats: any? = args[3]     -- estatísticas da partida (tabela)

		print(string.format("[CacadaSombria] GameOverUI: Partida encerrada! Vencedor: %s", winner))
		GameOverUI:showResult(winner, reason, matchStats)
	end
end

-- ==========================================
-- EXIBIÇÃO DO RESULTADO
-- ==========================================

-- Mostra o resultado da partida
-- @param winner — "Killer" ou "Survivors"
-- @param reason — Motivo da vitória (opcional)
-- @param matchStats — Estatísticas da partida (opcional)
function GameOverUI:showResult(winner: string, reason: string?, matchStats: any?)
	if not _screenGui then return end

	-- Determina se o jogador local venceu
	local localRole = nil
	-- Tenta obter o papel do jogador local via RemoteFunction ou estado local
	-- Por enquanto, inferimos do vencedor vs papel conhecido
	local isVictory = false
	if winner == "Killer" then
		isVictory = true  -- Placeholder: o jogador pode ser Killer ou Survivor
	else
		isVictory = true  -- Placeholder
	end

	-- ==========================
	-- CONFIGURA O TÍTULO
	-- ==========================
	if winner == "Survivors" then
		_resultTitle.Text = "SOBREVIVENTES VENCERAM!"
		_resultTitle.TextColor3 = WIN_COLOR
	elseif winner == "Killer" then
		_resultTitle.Text = "O CAÇADOR VENCEU!"
		_resultTitle.TextColor3 = LOSE_COLOR
	else
		_resultTitle.Text = "FIM DE JOGO"
	end

	-- ==========================
	-- CONFIGURA O SUBTÍTULO (MOTIVO)
	-- ==========================
	if reason then
		if reason == "CaçadorDesconectou" then
			_resultSubtitle.Text = "O Caçador desconectou — Sobreviventes vencem por W.O."
		elseif reason == "Fuga" then
			_resultSubtitle.Text = "Pelo menos um Sobrevivente escapou pelo portão!"
		elseif reason == "TempoEsgotado" then
			_resultSubtitle.Text = "Tempo esgotado — o Caçador impediu a fuga!"
		elseif reason == "TodosCapturados" then
			_resultSubtitle.Text = "Todos os Sobreviventes foram capturados!"
		else
			_resultSubtitle.Text = "Motivo: " .. reason
		end
	else
		_resultSubtitle.Text = ""
	end

	-- ==========================
	-- CONFIGURA AS ESTATÍSTICAS
	-- ==========================
	if matchStats then
		GameOverUI:_populateStats(matchStats)
	else
		-- Estatísticas padrão (placeholder)
		GameOverUI:_populateDefaultStats(winner)
	end

	-- ==========================
	-- ANIMAÇÃO DE ENTRADA (FADE IN)
	-- ==========================
	_screenGui.Enabled = true
	_isVisible = true

	-- Pequeno delay para o fade (simples: já está visível)
	print("[CacadaSombria] GameOverUI: Resultado exibido")
end

-- Preenche as estatísticas detalhadas da partida
function GameOverUI:_populateStats(stats: any)
	if not _playerStatsContainer then return end

	-- Limpa entradas anteriores
	for _, child in _playerStatsContainer:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Exibe estatísticas gerais da partida
	if stats.generatorsRepaired then
		GameOverUI:_addStatLine(string.format("🔧 Geradores consertados: %d/%d",
			stats.generatorsRepaired or 0, GameConstants.Game.GeneratorsToRepair))
	end
	if stats.survivorsCaptured then
		GameOverUI:_addStatLine(string.format("⛓️ Capturas: %d", stats.survivorsCaptured))
	end
	if stats.survivorsEscaped then
		GameOverUI:_addStatLine(string.format("🚪 Fugas: %d", stats.survivorsEscaped))
	end
	if stats.rescues then
		GameOverUI:_addStatLine(string.format("🆘 Resgates: %d", stats.rescues))
	end
	if stats.matchDuration then
		local minutes = math.floor(stats.matchDuration / 60)
		local seconds = math.floor(stats.matchDuration % 60)
		GameOverUI:_addStatLine(string.format("⏱️ Duração: %02d:%02d", minutes, seconds))
	end

	-- Estatísticas por jogador
	if stats.playerStats then
		GameOverUI:_addStatLine("")  -- Espaçador
		GameOverUI:_addStatLine("─── JOGADORES ───")
		for _, ps in stats.playerStats do
			local playerLine = string.format("%s — %s", ps.name or "???", ps.role or "???")
			if ps.className then
				playerLine = playerLine .. string.format(" (%s)", ps.className)
			end
			GameOverUI:_addStatLine(playerLine)
		end
	end
end

-- Preenche estatísticas padrão quando não há dados do servidor
function GameOverUI:_populateDefaultStats(winner: string)
	if not _playerStatsContainer then return end

	-- Limpa entradas anteriores
	for _, child in _playerStatsContainer:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	GameOverUI:_addStatLine("📊 Estatísticas detalhadas em breve...")
	if winner == "Survivors" then
		GameOverUI:_addStatLine("🔧 Geradores completos: aguardando dados do servidor")
		GameOverUI:_addStatLine("🚪 Fugas bem-sucedidas: aguardando dados")
	else
		GameOverUI:_addStatLine("⛓️ Capturas realizadas: aguardando dados")
	end
end

-- Adiciona uma linha de estatística
-- @param text — Texto da linha
function GameOverUI:_addStatLine(text: string)
	if not _playerStatsContainer then return end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = TEXT_COLOR
	label.TextSize = 13
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = _playerStatsContainer
end

-- ==========================================
-- AÇÕES DO USUÁRIO
-- ==========================================

-- Chamado quando o jogador clica em "Voltar ao Lobby"
function GameOverUI:_onReturnToLobby()
	print("[CacadaSombria] GameOverUI: Solicitando retorno ao lobby...")

	-- Envia a ação para o servidor
	if _playerActionEvent then
		_playerActionEvent:FireServer("ReturnToLobby")
	else
		warn("[CacadaSombria] GameOverUI: PlayerActionEvent não disponível")
	end

	-- Esconde a tela
	GameOverUI:hide()
end

-- ==========================================
-- MOSTRAR / ESCONDER
-- ==========================================

-- Mostra a tela de resultado
function GameOverUI:show()
	if _screenGui then
		_screenGui.Enabled = true
		_isVisible = true
	end
end

-- Esconde a tela de resultado
function GameOverUI:hide()
	if _screenGui then
		_screenGui.Enabled = false
		_isVisible = false
	end
end

-- ==========================================
-- LIMPEZA
-- ==========================================

function GameOverUI.Destroy()
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end

	_isVisible = false

	print("[CacadaSombria] GameOverUI destruído.")
end

return GameOverUI
