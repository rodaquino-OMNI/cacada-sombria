--!strict
--[[
	CharacterSelectUI.lua
	Tela de seleção de personagem — exibida durante a fase de seleção no lobby.
	
	Responsável por:
	- Exibir cards com as 5 classes de Sobrevivente
	- Permitir ao jogador clicar para escolher sua classe
	- Mostrar timer de 15 segundos
	- Mostrar qual classe cada jogador já escolheu
	- Indicar quem é o Caçador (atribuído pelo host)
	- Enviar a escolha para o servidor via PlayerActionEvent

	Design:
	- Fundo escuro semi-transparente (overlay)
	- Grade de cards centralizada
	- Cada card mostra: nome da classe, HP, velocidade, ícone (placeholder)
	- Timer no topo da tela
	- Lista de jogadores e suas escolhas na lateral

	Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- SERVIÇO CHARACTERSELECTUI
-- ==========================================
local CharacterSelectUI = {}
CharacterSelectUI.__index = CharacterSelectUI

-- ==========================================
-- ESTADO INTERNO
-- ==========================================
local _player = Players.LocalPlayer
local _playerGui: PlayerGui? = nil
local _screenGui: ScreenGui? = nil
local _isVisible = false

-- Elementos da UI
local _mainFrame: Frame? = nil
local _titleLabel: TextLabel? = nil
local _timerLabel: TextLabel? = nil
local _cardsContainer: Frame? = nil
local _playerListFrame: Frame? = nil
local _selectButton: TextButton? = nil
local _selectedClass: string? = nil  -- Classe escolhida pelo jogador local

-- Cards de classe (Frame para cada um)
local _classCards: {[string]: Frame} = {}

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- Referência ao PlayerActionEvent (para enviar escolha ao servidor)
local _playerActionEvent: RemoteEvent? = nil

-- ==========================================
-- CONSTANTES DE DESIGN
-- ==========================================
local CARD_WIDTH = 140         -- Largura de cada card
local CARD_HEIGHT = 200        -- Altura de cada card
local CARD_SPACING = 16        -- Espaçamento entre cards
local CORNER_RADIUS = UDim.new(0, 8)  -- Cantos arredondados

-- Cores do tema (sombrio / horror)
local BG_COLOR = Color3.fromRGB(20, 20, 25)
local CARD_BG = Color3.fromRGB(35, 35, 45)
local CARD_SELECTED_BG = Color3.fromRGB(60, 80, 60)  -- Verde escuro para selecionado
local CARD_HOVER_BG = Color3.fromRGB(50, 50, 65)
local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
local TIMER_COLOR = Color3.fromRGB(255, 200, 80)     -- Âmbar
local TIMER_URGENT = Color3.fromRGB(255, 80, 80)     -- Vermelho (últimos 5s)
local ACCENT_COLOR = Color3.fromRGB(180, 50, 50)     -- Vermelho escuro (acento)

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Cria a tela de seleção de personagem
-- Chamado pelo ClientManager quando o servidor envia SelectStart
function CharacterSelectUI.Init()
	-- Obtém o PlayerGui
	_playerGui = _player:FindFirstChild("PlayerGui")
	if not _playerGui then
		warn("[CacadaSombria] CharacterSelectUI: PlayerGui não encontrado!")
		return
	end

	-- Obtém o PlayerActionEvent para enviar escolhas
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_playerActionEvent = eventsFolder:FindFirstChild("PlayerActionEvent")
	end

	-- Cria o ScreenGui (oculto inicialmente)
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "CharacterSelectUI"
	_screenGui.ResetOnSpawn = false
	_screenGui.Enabled = false
	_screenGui.Parent = _playerGui

	-- Cria a estrutura da tela
	CharacterSelectUI:_createOverlay()
	CharacterSelectUI:_createMainFrame()
	CharacterSelectUI:_createTitle()
	CharacterSelectUI:_createTimer()
	CharacterSelectUI:_createClassCards()
	CharacterSelectUI:_createPlayerList()
	CharacterSelectUI:_createReadyButton()

	-- Registra listeners de eventos do servidor
	CharacterSelectUI:_registerEventListeners()

	print("[CacadaSombria] CharacterSelectUI criado.")
end

-- ==========================================
-- CRIAÇÃO DA ESTRUTURA VISUAL
-- ==========================================

-- Cria o fundo escuro (overlay)
function CharacterSelectUI:_createOverlay()
	if not _screenGui then return end

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel = 0
	overlay.Parent = _screenGui
end

-- Cria o container principal
function CharacterSelectUI:_createMainFrame()
	if not _screenGui then return end

	_mainFrame = Instance.new("Frame")
	_mainFrame.Name = "MainFrame"
	_mainFrame.Size = UDim2.new(0, 800, 0, 520)
	_mainFrame.Position = UDim2.new(0.5, -400, 0.5, -260)
	_mainFrame.BackgroundColor3 = BG_COLOR
	_mainFrame.BackgroundTransparency = 0.15
	_mainFrame.BorderSizePixel = 0
	_mainFrame.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = _mainFrame

	-- Borda decorativa
	local border = Instance.new("UIStroke")
	border.Thickness = 1.5
	border.Color = ACCENT_COLOR
	border.Transparency = 0.5
	border.Parent = _mainFrame
end

-- Cria o título "ESCOLHA SEU PERSONAGEM"
function CharacterSelectUI:_createTitle()
	if not _mainFrame then return end

	_titleLabel = Instance.new("TextLabel")
	_titleLabel.Name = "Title"
	_titleLabel.Size = UDim2.new(1, 0, 0, 40)
	_titleLabel.Position = UDim2.new(0, 0, 0, 12)
	_titleLabel.BackgroundTransparency = 1
	_titleLabel.Text = "ESCOLHA SEU PERSONAGEM"
	_titleLabel.TextColor3 = TEXT_COLOR
	_titleLabel.TextSize = 26
	_titleLabel.Font = Enum.Font.GothamBold
	_titleLabel.Parent = _mainFrame
end

-- Cria o label do timer (ex: "Tempo restante: 12s")
function CharacterSelectUI:_createTimer()
	if not _mainFrame then return end

	_timerLabel = Instance.new("TextLabel")
	_timerLabel.Name = "Timer"
	_timerLabel.Size = UDim2.new(1, 0, 0, 30)
	_timerLabel.Position = UDim2.new(0, 0, 0, 50)
	_timerLabel.BackgroundTransparency = 1
	_timerLabel.Text = "Tempo restante: 15s"
	_timerLabel.TextColor3 = TIMER_COLOR
	_timerLabel.TextSize = 20
	_timerLabel.Font = Enum.Font.GothamBold
	_timerLabel.Parent = _mainFrame
end

-- Cria os cards das 5 classes de Sobrevivente
function CharacterSelectUI:_createClassCards()
	if not _mainFrame then return end

	-- Container para os cards
	_cardsContainer = Instance.new("Frame")
	_cardsContainer.Name = "CardsContainer"
	_cardsContainer.Size = UDim2.new(0, 780, 0, CARD_HEIGHT + 10)
	_cardsContainer.Position = UDim2.new(0, 10, 0, 90)
	_cardsContainer.BackgroundTransparency = 1
	_cardsContainer.Parent = _mainFrame

	-- Layout da grade de cards
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	gridLayout.CellPadding = UDim2.new(0, CARD_SPACING, 0, 4)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.Parent = _cardsContainer

	-- Cria um card para cada classe
	local classes = {"Soldado", "Sackboy", "Robo", "Enfermeira", "Campeao"}
	local classData = GameConstants.Survivors

	for _, className in classes do
		local data = classData[className]
		if data then
			CharacterSelectUI:_createClassCard(className, data.HP, data.Speed)
		end
	end
end

-- Cria um card individual para uma classe
-- @param className — Nome da classe (ex: "Soldado")
-- @param hp — HP da classe
-- @param speed — Velocidade da classe
function CharacterSelectUI:_createClassCard(className: string, hp: number, speed: number)
	if not _cardsContainer then return end

	local card = Instance.new("Frame")
	card.Name = className .. "Card"
	card.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	card.BackgroundColor3 = CARD_BG
	card.BorderSizePixel = 0
	card.Parent = _cardsContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = card

	-- Borda fina
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(80, 80, 100)
	stroke.Parent = card

	-- Nome da classe
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ClassName"
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = className
	nameLabel.TextColor3 = TEXT_COLOR
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	-- Ícone placeholder (círculo com emoji)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "Icon"
	iconFrame.Size = UDim2.new(0, 64, 0, 64)
	iconFrame.Position = UDim2.new(0.5, -32, 0, 50)
	iconFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)  -- Círculo
	iconCorner.Parent = iconFrame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "🦸"
	iconLabel.TextSize = 32
	iconLabel.Parent = iconFrame

	-- Stats: HP e Velocidade
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.Size = UDim2.new(1, 0, 0, 40)
	statsLabel.Position = UDim2.new(0, 0, 0, 125)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = string.format("❤️ %d HP\n🏃 %.0f Vel", hp, speed)
	statsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statsLabel.TextSize = 13
	statsLabel.Font = Enum.Font.Gotham
	-- TextLineSpacing não é suportado em TextLabel no Roblox
	statsLabel.Parent = card

	-- Botão invisível para clique (cobre todo o card)
	local selectButton = Instance.new("TextButton")
	selectButton.Name = "SelectButton"
	selectButton.Size = UDim2.new(1, 0, 1, 0)
	selectButton.BackgroundTransparency = 1
	selectButton.Text = ""
	selectButton.Parent = card

	-- Hover: destaca o card
	selectButton.MouseEnter:Connect(function()
		if _selectedClass ~= className then
			card.BackgroundColor3 = CARD_HOVER_BG
			stroke.Color = Color3.fromRGB(150, 150, 180)
		end
	end)

	selectButton.MouseLeave:Connect(function()
		if _selectedClass ~= className then
			card.BackgroundColor3 = CARD_BG
			stroke.Color = Color3.fromRGB(80, 80, 100)
		end
	end)

	-- Clique: seleciona a classe
	selectButton.MouseButton1Click:Connect(function()
		CharacterSelectUI:selectClass(className)
	end)

	_classCards[className] = card
end

-- Cria a lista de jogadores (lateral direita)
function CharacterSelectUI:_createPlayerList()
	if not _mainFrame then return end

	_playerListFrame = Instance.new("Frame")
	_playerListFrame.Name = "PlayerList"
	_playerListFrame.Size = UDim2.new(0, 200, 0, 180)
	_playerListFrame.Position = UDim2.new(1, -215, 0, 310)
	_playerListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	_playerListFrame.BackgroundTransparency = 0.3
	_playerListFrame.BorderSizePixel = 0
	_playerListFrame.Parent = _mainFrame

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = CORNER_RADIUS
	pCorner.Parent = _playerListFrame

	-- Título da lista
	local listTitle = Instance.new("TextLabel")
	listTitle.Name = "PlayerListTitle"
	listTitle.Size = UDim2.new(1, 0, 0, 24)
	listTitle.Position = UDim2.new(0, 0, 0, 4)
	listTitle.BackgroundTransparency = 1
	listTitle.Text = "JOGADORES"
	listTitle.TextColor3 = ACCENT_COLOR
	listTitle.TextSize = 14
	listTitle.Font = Enum.Font.GothamBold
	listTitle.Parent = _playerListFrame
end

-- Cria o botão de "Pronto" / "Confirmar"
function CharacterSelectUI:_createReadyButton()
	if not _mainFrame then return end

	_selectButton = Instance.new("TextButton")
	_selectButton.Name = "ReadyButton"
	_selectButton.Size = UDim2.new(0, 200, 0, 36)
	_selectButton.Position = UDim2.new(0.5, -100, 0, 305)
	_selectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	_selectButton.BorderSizePixel = 0
	_selectButton.Text = "ESCOLHA UMA CLASSE"
	_selectButton.TextColor3 = TEXT_COLOR
	_selectButton.TextSize = 16
	_selectButton.Font = Enum.Font.GothamBold
	_selectButton.AutoButtonColor = false
	_selectButton.Parent = _mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = _selectButton

	_selectButton.MouseButton1Click:Connect(function()
		if _selectedClass then
			CharacterSelectUI:_confirmSelection()
		end
	end)
end

-- ==========================================
-- LISTENERS DE EVENTOS DO SERVIDOR
-- ==========================================

-- Registra handlers para mensagens do servidor via GameStateEvent
function CharacterSelectUI:_registerEventListeners()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[CacadaSombria] CharacterSelectUI: Pasta 'Events' não encontrada")
		return
	end

	local gameStateEvent: RemoteEvent? = eventsFolder:FindFirstChild("GameStateEvent")
	if not gameStateEvent then
		warn("[CacadaSombria] CharacterSelectUI: GameStateEvent não encontrado")
		return
	end

	local conn = gameStateEvent.OnClientEvent:Connect(function(messageType: string, ...)
		CharacterSelectUI:_handleServerMessage(messageType, ...)
	end)
	table.insert(_connections, conn)

	print("[CacadaSombria] CharacterSelectUI: Listener de GameStateEvent registrado.")
end

-- Processa mensagens recebidas do servidor
function CharacterSelectUI:_handleServerMessage(messageType: string, ...)
	local args = {...}

	-- ==========================
	-- INÍCIO DA SELEÇÃO
	-- ==========================
	if messageType == GameStateEvent.MESSAGES.CHARACTER_SELECT then
		-- Recebeu a lista de classes disponíveis
		local availableClasses = args[1]  -- tabela de strings
		print("[CacadaSombria] CharacterSelectUI: Seleção de personagem iniciada!")

		-- Mostra a tela
		CharacterSelectUI:show()

	-- ==========================
	-- TIMER DA SELEÇÃO
	-- ==========================
	elseif messageType == GameStateEvent.MESSAGES.SELECT_TIMER then
		local seconds: number = args[1]
		if _timerLabel then
			_timerLabel.Text = string.format("Tempo restante: %ds", seconds)
			if seconds <= 5 then
				_timerLabel.TextColor3 = TIMER_URGENT
			else
				_timerLabel.TextColor3 = TIMER_COLOR
			end
		end

	-- ==========================
	-- OUTRO JOGADOR ESCOLHEU CLASSE
	-- ==========================
	elseif messageType == GameStateEvent.MESSAGES.CHARACTER_SELECTED then
		local playerName: string = args[1]
		local className: string = args[2]
		CharacterSelectUI:_updatePlayerChoice(playerName, className)

	-- ==========================
	-- CAÇADOR ATRIBUÍDO
	-- ==========================
	elseif messageType == "KillerAssigned" then
		local playerName: string = args[1]
		CharacterSelectUI:_updateKillerAssigned(playerName)

	-- ==========================
	-- LOBBY ATUALIZADO
	-- ==========================
	elseif messageType == GameStateEvent.MESSAGES.LOBBY_UPDATE then
		local lobbyData = args[1]
		if lobbyData and lobbyData.players then
			CharacterSelectUI:_updatePlayerList(lobbyData.players)
		end
	end
end

-- ==========================================
-- AÇÕES DO USUÁRIO
-- ==========================================

-- Seleciona uma classe visualmente (ainda não confirma)
-- @param className — Nome da classe escolhida
function CharacterSelectUI:selectClass(className: string)
	-- Desseleciona o card anterior
	if _selectedClass and _classCards[_selectedClass] then
		local prevCard = _classCards[_selectedClass]
		prevCard.BackgroundColor3 = CARD_BG
		local prevStroke = prevCard:FindFirstChild("UIStroke")
		if prevStroke then
			prevStroke.Color = Color3.fromRGB(80, 80, 100)
		end
	end

	-- Seleciona o novo card
	_selectedClass = className
	if _classCards[className] then
		local card = _classCards[className]
		card.BackgroundColor3 = CARD_SELECTED_BG
		local stroke = card:FindFirstChild("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(100, 255, 100)  -- Verde brilhante
		end
	end

	-- Atualiza o botão
	if _selectButton then
		_selectButton.Text = "CONFIRMAR " .. className:upper()
		_selectButton.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
	end

	print(string.format("[CacadaSombria] CharacterSelectUI: %s selecionado (aguardando confirmação)", className))
end

-- Confirma a seleção e envia para o servidor
function CharacterSelectUI:_confirmSelection()
	if not _selectedClass then return end
	if not _playerActionEvent then
		warn("[CacadaSombria] CharacterSelectUI: PlayerActionEvent não disponível para enviar escolha")
		return
	end

	-- Envia a escolha para o servidor
	_playerActionEvent:FireServer("SelectClass", _selectedClass)

	-- Atualiza visual do botão
	if _selectButton then
		_selectButton.Text = "✓ ESCOLHIDO: " .. _selectedClass:upper()
		_selectButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
		_selectButton.AutoButtonColor = false
	end

	print(string.format("[CacadaSombria] CharacterSelectUI: Escolha '%s' enviada ao servidor", _selectedClass))
end

-- ==========================================
-- ATUALIZAÇÕES DA UI
-- ==========================================

-- Atualiza a lista de jogadores e suas escolhas
function CharacterSelectUI:_updatePlayerList(players: {any})
	if not _playerListFrame then return end

	-- Limpa a lista atual (remove entradas antigas, mantendo o título)
	local children = _playerListFrame:GetChildren()
	for _, child in children do
		if child:IsA("TextLabel") and child.Name ~= "PlayerListTitle" then
			child:Destroy()
		end
	end

	-- Adiciona cada jogador
	local yOffset = 30
	for _, pData in players do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 0, 20)
		label.Position = UDim2.new(0, 4, 0, yOffset)
		label.BackgroundTransparency = 1
		label.TextSize = 12
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left

		local statusIcon = ""
		if pData.isHost then statusIcon = "👑 " end
		if pData.isKiller then statusIcon = statusIcon .. "💀 " end

		local choiceText = ""
		if pData.selectedClass then
			choiceText = " → " .. pData.selectedClass
		elseif pData.isKiller then
			choiceText = " → CAÇADOR"
		end

		label.Text = string.format("%s%s%s", statusIcon, pData.name, choiceText)
		label.TextColor3 = pData.isKiller and Color3.fromRGB(255, 100, 100) or TEXT_COLOR
		label.Parent = _playerListFrame

		yOffset = yOffset + 22
	end
end

-- Atualiza quando outro jogador escolhe uma classe
function CharacterSelectUI:_updatePlayerChoice(playerName: string, className: string)
	print(string.format("[CacadaSombria] CharacterSelectUI: %s escolheu %s", playerName, className))
	-- A lista completa será atualizada via LobbyUpdate
end

-- Atualiza quando o Caçador é atribuído
function CharacterSelectUI:_updateKillerAssigned(playerName: string)
	print(string.format("[CacadaSombria] CharacterSelectUI: %s é o CAÇADOR", playerName))
end

-- ==========================================
-- MOSTRAR / ESCONDER
-- ==========================================

-- Mostra a tela de seleção
function CharacterSelectUI:show()
	if _screenGui then
		_screenGui.Enabled = true
		_isVisible = true
		print("[CacadaSombria] CharacterSelectUI: Tela exibida")
	end
end

-- Esconde a tela de seleção
function CharacterSelectUI:hide()
	if _screenGui then
		_screenGui.Enabled = false
		_isVisible = false
		print("[CacadaSombria] CharacterSelectUI: Tela escondida")
	end
end

-- Verifica se está visível
function CharacterSelectUI:isVisible(): boolean
	return _isVisible
end

-- ==========================================
-- LIMPEZA
-- ==========================================

function CharacterSelectUI.Destroy()
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end

	_isVisible = false

	print("[CacadaSombria] CharacterSelectUI destruído.")
end

return CharacterSelectUI
