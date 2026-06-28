--!strict
--[[
  KillerHUD.lua
  Interface do Caçador — barra de Fúria e contador de Sobreviventes.
  
  Exibe:
  - Barra de Fúria (centro inferior)
  - Ícones de habilidade com cooldown (Épico E2)
  - Contador de Sobreviventes vivos/em jaula
  - Indicadores de notificação (Épico E2)

  Design: Minimalista, tema escuro com detalhes em vermelho/âmbar.

  Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- SERVIÇO KILLERHUD
-- ==========================================
local KillerHUD = {}
KillerHUD.__index = KillerHUD

-- ==========================================
-- ESTADO INTERNO
-- ==========================================
local _player = Players.LocalPlayer
local _playerGui: PlayerGui? = nil
local _screenGui: ScreenGui? = nil
local _isSetup = false

-- Elementos da UI
local _furyBar: Frame? = nil
local _furyFill: Frame? = nil
local _furyLabel: TextLabel? = nil
local _survivorCountLabel: TextLabel? = nil

-- Conexões
local _connections: {RBXScriptConnection} = {}

-- ==========================================
-- CONSTANTES DE DESIGN
-- ==========================================
local BAR_WIDTH = 200
local BAR_HEIGHT = 24
local FURY_COLOR = Color3.fromRGB(200, 100, 0)      -- Laranja/Âmbar
local FURY_BG_COLOR = Color3.fromRGB(40, 20, 0)      -- Fundo escuro
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

function KillerHUD.Init()
	_playerGui = _player:FindFirstChild("PlayerGui")
	if not _playerGui then
		warn("[CacadaSombria] KillerHUD: PlayerGui não encontrado!")
		return
	end

	-- Cria o ScreenGui
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "KillerHUD"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent = _playerGui

	-- Cria elementos
	KillerHUD:_createFuryBar()
	KillerHUD:_createSurvivorCount()

	-- Registra listeners
	KillerHUD:_registerEventListeners()

	_isSetup = true

	print("[CacadaSombria] KillerHUD criado e configurado.")
end

-- Cria a barra de Fúria
function KillerHUD:_createFuryBar()
	if not _screenGui then return end

	-- Container
	_furyBar = Instance.new("Frame")
	_furyBar.Name = "FuryBar"
	_furyBar.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	_furyBar.Position = UDim2.new(0.5, -BAR_WIDTH/2, 1, -(BAR_HEIGHT + 40))
	_furyBar.AnchorPoint = Vector2.new(0, 1)
	_furyBar.BackgroundColor3 = FURY_BG_COLOR
	_furyBar.BorderSizePixel = 0
	_furyBar.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = _furyBar

	-- Preenchimento
	_furyFill = Instance.new("Frame")
	_furyFill.Name = "FuryFill"
	_furyFill.Size = UDim2.new(0, 0, 1, 0) -- Começa vazio
	_furyFill.BackgroundColor3 = FURY_COLOR
	_furyFill.BorderSizePixel = 0
	_furyFill.Parent = _furyBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = _furyFill

	-- Label de Fúria
	_furyLabel = Instance.new("TextLabel")
	_furyLabel.Name = "FuryLabel"
	_furyLabel.Size = UDim2.new(1, 0, 1, 0)
	_furyLabel.BackgroundTransparency = 1
	_furyLabel.TextColor3 = TEXT_COLOR
	_furyLabel.Text = "FÚRIA: 0/100"
	_furyLabel.TextSize = 14
	_furyLabel.Font = Enum.Font.GothamBold
	_furyLabel.TextStrokeTransparency = 0.5
	_furyLabel.Parent = _furyBar
end

-- Cria o contador de Sobreviventes
function KillerHUD:_createSurvivorCount()
	if not _screenGui then return end

	_survivorCountLabel = Instance.new("TextLabel")
	_survivorCountLabel.Name = "SurvivorCount"
	_survivorCountLabel.Size = UDim2.new(0, 200, 0, 20)
	_survivorCountLabel.Position = UDim2.new(1, -210, 0, 10)
	_survivorCountLabel.AnchorPoint = Vector2.new(0, 0)
	_survivorCountLabel.BackgroundTransparency = 1
	_survivorCountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	_survivorCountLabel.Text = "Sobreviventes: 4 vivos"
	_survivorCountLabel.TextSize = 14
	_survivorCountLabel.Font = Enum.Font.Gotham
	_survivorCountLabel.TextStrokeTransparency = 0.5
	_survivorCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	_survivorCountLabel.Parent = _screenGui
end

-- Registra listeners do servidor
function KillerHUD:_registerEventListeners()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[CacadaSombria] KillerHUD: Pasta 'Events' não encontrada")
		return
	end

	local gameStateEvent: RemoteEvent? = eventsFolder:FindFirstChild("GameStateEvent")
	if not gameStateEvent then
		warn("[CacadaSombria] KillerHUD: GameStateEvent não encontrado")
		return
	end

	local conn = gameStateEvent.OnClientEvent:Connect(function(messageType: string, ...)
		KillerHUD:_handleServerMessage(messageType, ...)
	end)
	table.insert(_connections, conn)
end

-- Processa mensagens do servidor
function KillerHUD:_handleServerMessage(messageType: string, ...)
	local args = {...}

	if messageType == GameStateEvent.MESSAGES.FURY_UPDATE then
		local currentFury: number = args[1]
		local maxFury: number = args[2] or 100
		KillerHUD:updateFury(currentFury, maxFury)
	end
end

-- ==========================================
-- ATUALIZAÇÕES
-- ==========================================

-- Atualiza a barra de Fúria
function KillerHUD:updateFury(currentFury: number, maxFury: number)
	if not _furyFill or not _furyLabel then return end

	local percent = math.clamp(currentFury / maxFury, 0, 1)

	-- Atualiza a barra de preenchimento
	_furyFill.Size = UDim2.new(percent, 0, 1, 0)

	-- Atualiza o texto
	_furyLabel.Text = string.format("FÚRIA: %.0f/%.0f", currentFury, maxFury)

	-- Quando a Fúria está cheia, muda a cor para indicar que Rage está pronta
	if percent >= 1 then
		_furyFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Vermelho intenso
	else
		_furyFill.BackgroundColor3 = FURY_COLOR
	end
end

-- ==========================================
-- MOSTRAR / ESCONDER
-- ==========================================

function KillerHUD:show()
	if _screenGui then
		_screenGui.Enabled = true
	end
end

function KillerHUD:hide()
	if _screenGui then
		_screenGui.Enabled = false
	end
end

-- ==========================================
-- LIMPEZA
-- ==========================================

function KillerHUD.Destroy()
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end

	_isSetup = false

	print("[CacadaSombria] KillerHUD destruído.")
end

return KillerHUD
