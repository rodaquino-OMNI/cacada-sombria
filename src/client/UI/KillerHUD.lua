--!strict
--[[
  KillerHUD.lua
  Interface do Caçador — barra de Fúria, cooldowns e contador de Sobreviventes.
  
  Exibe:
  - Barra de Fúria (centro inferior)
  - Ícones de habilidade com cooldown (M1, Q, E, R)
  - Contador de Sobreviventes vivos/em jaula
  - Indicadores de notificação (Rage ativo, etc.)

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
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)

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

-- Elementos de habilidades
local _abilityM1: Frame? = nil
local _abilityM1Cooldown: Frame? = nil
local _abilityM1Label: TextLabel? = nil
local _abilityQ: Frame? = nil
local _abilityQCooldown: Frame? = nil
local _abilityQLabel: TextLabel? = nil
local _abilityE: Frame? = nil
local _abilityECooldown: Frame? = nil
local _abilityELabel: TextLabel? = nil
local _abilityR: Frame? = nil
local _abilityRCooldown: Frame? = nil
local _abilityRLabel: TextLabel? = nil

-- Rótulo de Rage ativo
local _rageActiveLabel: TextLabel? = nil

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
local ABILITY_ICON_SIZE = 48
local ABILITY_BG_COLOR = Color3.fromRGB(30, 30, 30)
local COOLDOWN_COLOR = Color3.fromRGB(0, 0, 0)
local RAGE_ACTIVE_COLOR = Color3.fromRGB(255, 30, 30)

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
	KillerHUD:_createAbilityIcons()
	KillerHUD:_createRageLabel()

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

-- Cria os ícones de habilidade (M1, Q, E, R) com overlay de cooldown
function KillerHUD:_createAbilityIcons()
	if not _screenGui then return end

	-- Container dos ícones (centro inferior, acima da barra de Fúria)
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "AbilityIcons"
	iconContainer.Size = UDim2.new(0, ABILITY_ICON_SIZE * 4 + 12, 0, ABILITY_ICON_SIZE)
	iconContainer.Position = UDim2.new(0.5, -(ABILITY_ICON_SIZE * 4 + 12) / 2, 1, -(BAR_HEIGHT + 80))
	iconContainer.AnchorPoint = Vector2.new(0, 1)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = _screenGui

	-- Layout horizontal
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = iconContainer

	-- Cria cada ícone de habilidade
	-- M1 (Clique Esquerdo)
	_abilityM1, _abilityM1Cooldown, _abilityM1Label = KillerHUD:_createAbilityIcon(iconContainer, "M1")
	-- Q (Braço Esticado)
	_abilityQ, _abilityQCooldown, _abilityQLabel = KillerHUD:_createAbilityIcon(iconContainer, "Q")
	-- E (Grito)
	_abilityE, _abilityECooldown, _abilityELabel = KillerHUD:_createAbilityIcon(iconContainer, "E")
	-- R (Rage)
	_abilityR, _abilityRCooldown, _abilityRLabel = KillerHUD:_createAbilityIcon(iconContainer, "R")
end

-- Cria um único ícone de habilidade com overlay de cooldown
-- @return frame, cooldownFrame, label
function KillerHUD:_createAbilityIcon(parent: Instance, keyName: string): (Frame, Frame, TextLabel)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "Ability_" .. keyName
	iconFrame.Size = UDim2.new(0, ABILITY_ICON_SIZE, 0, ABILITY_ICON_SIZE)
	iconFrame.BackgroundColor3 = ABILITY_BG_COLOR
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = iconFrame

	-- Letra da tecla
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(1, 0, 0, 20)
	keyLabel.Position = UDim2.new(0, 0, 0, 4)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = TEXT_COLOR
	keyLabel.Text = keyName
	keyLabel.TextSize = 16
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Parent = iconFrame

	-- Nome da habilidade (abreviado)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 1, -22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextStrokeTransparency = 0.8

	-- Nomes amigáveis das habilidades
	local names = {
		M1 = "Tapa",
		Q = "Braço",
		E = "Grito",
		R = "Rage",
	}
	nameLabel.Text = names[keyName] or keyName
	nameLabel.Parent = iconFrame

	-- Overlay de cooldown (cobre o ícone de cima para baixo)
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 0, 0) -- Começa invisível
	cooldownOverlay.Position = UDim2.new(0, 0, 0, 0)
	cooldownOverlay.AnchorPoint = Vector2.new(0, 0)
	cooldownOverlay.BackgroundColor3 = COOLDOWN_COLOR
	cooldownOverlay.BackgroundTransparency = 0.4
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.Visible = false
	cooldownOverlay.Parent = iconFrame

	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 6)
	overlayCorner.Parent = cooldownOverlay

	-- Texto do cooldown (segundos restantes)
	local cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "CooldownLabel"
	cdLabel.Size = UDim2.new(1, 0, 1, 0)
	cdLabel.BackgroundTransparency = 1
	cdLabel.TextColor3 = TEXT_COLOR
	cdLabel.Text = ""
	cdLabel.TextSize = 18
	cdLabel.Font = Enum.Font.GothamBold
	cdLabel.Parent = cooldownOverlay

	return iconFrame, cooldownOverlay, cdLabel
end

-- Cria o rótulo de Rage ativo
function KillerHUD:_createRageLabel()
	if not _screenGui then return end

	_rageActiveLabel = Instance.new("TextLabel")
	_rageActiveLabel.Name = "RageActiveLabel"
	_rageActiveLabel.Size = UDim2.new(0, 200, 0, 30)
	_rageActiveLabel.Position = UDim2.new(0.5, -100, 0.15, 0)
	_rageActiveLabel.BackgroundTransparency = 0.3
	_rageActiveLabel.BackgroundColor3 = RAGE_ACTIVE_COLOR
	_rageActiveLabel.TextColor3 = TEXT_COLOR
	_rageActiveLabel.Text = "RAGE ATIVO!"
	_rageActiveLabel.TextSize = 20
	_rageActiveLabel.Font = Enum.Font.GothamBold
	_rageActiveLabel.TextStrokeTransparency = 0.3
	_rageActiveLabel.Visible = false
	_rageActiveLabel.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = _rageActiveLabel
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

	-- Listener do GameStateEvent (Fury, HP)
	local gameStateEvent: RemoteEvent? = eventsFolder:FindFirstChild("GameStateEvent")
	if gameStateEvent then
		local conn1 = gameStateEvent.OnClientEvent:Connect(function(messageType: string, ...)
			KillerHUD:_handleGameStateMessage(messageType, ...)
		end)
		table.insert(_connections, conn1)
	else
		warn("[CacadaSombria] KillerHUD: GameStateEvent não encontrado")
	end

	-- Listener do UISyncEvent (Cooldowns, Rage, Grito)
	local uiSyncEvent: RemoteEvent? = eventsFolder:FindFirstChild("UISyncEvent")
	if uiSyncEvent then
		local conn2 = uiSyncEvent.OnClientEvent:Connect(function(messageType: string, ...)
			KillerHUD:_handleUISyncMessage(messageType, ...)
		end)
		table.insert(_connections, conn2)
	else
		warn("[CacadaSombria] KillerHUD: UISyncEvent não encontrado")
	end
end

-- Processa mensagens de GameStateEvent (estado do jogo)
function KillerHUD:_handleGameStateMessage(messageType: string, ...)
	local args = {...}

	if messageType == GameStateEvent.MESSAGES.FURY_UPDATE then
		local currentFury: number = args[1]
		local maxFury: number = args[2] or 100
		KillerHUD:updateFury(currentFury, maxFury)
	end
end

-- Processa mensagens de UISyncEvent (cooldowns, rage, etc.)
function KillerHUD:_handleUISyncMessage(messageType: string, ...)
	local args = {...}

	if messageType == UISyncEvent.MESSAGES.COOLDOWN_START then
		-- Cooldown iniciado
		local abilityName: string = args[1]
		local totalSeconds: number = args[2]
		KillerHUD:_startCooldownAnimation(abilityName, totalSeconds)

	elseif messageType == UISyncEvent.MESSAGES.COOLDOWN_END then
		-- Cooldown terminou
		local abilityName: string = args[1]
		KillerHUD:_endCooldownAnimation(abilityName)

	elseif messageType == UISyncEvent.MESSAGES.RAGE_START then
		-- Rage ativado
		local duration: number = args[1]
		KillerHUD:_showRageActive(duration)

	elseif messageType == UISyncEvent.MESSAGES.RAGE_END then
		-- Rage terminou
		KillerHUD:_hideRageActive()

	elseif messageType == UISyncEvent.MESSAGES.FURY_UPDATE then
		-- Atualização de Fúria via UISyncEvent (redundante com GameStateEvent)
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
		-- Notifica o jogador que o Rage está disponível
		if _abilityR and _abilityRCooldown then
			_abilityR.BackgroundColor3 = Color3.fromRGB(60, 0, 0) -- Fundo vermelho escuro
		end
	else
		_furyFill.BackgroundColor3 = FURY_COLOR
		if _abilityR then
			_abilityR.BackgroundColor3 = ABILITY_BG_COLOR
		end
	end
end

-- ==========================================
-- ANIMAÇÕES DE COOLDOWN
-- ==========================================

-- Mapeia nome da habilidade para os elementos da UI
local _abilityElements: {[string]: {frame: Frame?, cooldown: Frame?, label: TextLabel?}} = {}

-- Inicializa o mapa de elementos de habilidade
local function _initAbilityElements()
	_abilityElements = {
		M1 = {frame = _abilityM1, cooldown = _abilityM1Cooldown, label = _abilityM1Label},
		BracoEsticado = {frame = _abilityQ, cooldown = _abilityQCooldown, label = _abilityQLabel},
		Grito = {frame = _abilityE, cooldown = _abilityECooldown, label = _abilityELabel},
		Rage = {frame = _abilityR, cooldown = _abilityRCooldown, label = _abilityRLabel},
	}
end

-- Inicia a animação de cooldown para uma habilidade
-- @param abilityName — Nome da habilidade
-- @param totalSeconds — Duração total do cooldown
function KillerHUD:_startCooldownAnimation(abilityName: string, totalSeconds: number)
	_initAbilityElements()
	local elements = _abilityElements[abilityName]
	if not elements or not elements.cooldown or not elements.label then
		return
	end

	local cooldownFrame = elements.cooldown
	local cdLabel = elements.label

	-- Torna o overlay visível
	cooldownFrame.Visible = true
	cooldownFrame.Size = UDim2.new(1, 0, 1, 0) -- Cobertura total

	-- Inicia o contador regressivo
	local remaining = totalSeconds
	cdLabel.Text = string.format("%.0f", remaining)

	-- Atualiza a cada 0.1s usando uma thread
	task.spawn(function()
		while remaining > 0 do
			task.wait(0.1)
			remaining = remaining - 0.1
			if remaining <= 0 then
				break
			end

			-- Atualiza o overlay de cooldown (preenche de cima para baixo)
			local percent = remaining / totalSeconds
			if cooldownFrame and cooldownFrame.Parent then
				cooldownFrame.Size = UDim2.new(1, 0, percent, 0)
			end
			if cdLabel and cdLabel.Parent then
				if remaining >= 1 then
					cdLabel.Text = string.format("%.0f", remaining)
				else
					cdLabel.Text = string.format("%.1f", remaining)
				end
			end
		end

		-- Cooldown terminou
		if cooldownFrame and cooldownFrame.Parent then
			cooldownFrame.Visible = false
		end
		if cdLabel and cdLabel.Parent then
			cdLabel.Text = ""
		end
	end)
end

-- Encerra a animação de cooldown de uma habilidade
-- @param abilityName — Nome da habilidade
function KillerHUD:_endCooldownAnimation(abilityName: string)
	_initAbilityElements()
	local elements = _abilityElements[abilityName]
	if not elements or not elements.cooldown then
		return
	end

	elements.cooldown.Visible = false
	if elements.label then
		elements.label.Text = ""
	end
end

-- ==========================================
-- RAGE ATIVO
-- ==========================================

-- Mostra o indicador de Rage ativo
-- @param duration — Duração do Rage em segundos
function KillerHUD:_showRageActive(duration: number)
	if not _rageActiveLabel then return end

	_rageActiveLabel.Visible = true
	_rageActiveLabel.Text = string.format("RAGE ATIVO! (%.0fs)", duration)

	-- Inicia um contador regressivo que atualiza o rótulo
	task.spawn(function()
		local remaining = duration
		while remaining > 0 and _rageActiveLabel and _rageActiveLabel.Parent do
			task.wait(0.5)
			remaining = remaining - 0.5
			if remaining <= 0 then break end
			if _rageActiveLabel and _rageActiveLabel.Parent then
				_rageActiveLabel.Text = string.format("RAGE ATIVO! (%.0fs)", remaining)
			end
		end
	end)
end

-- Esconde o indicador de Rage ativo
function KillerHUD:_hideRageActive()
	if _rageActiveLabel then
		_rageActiveLabel.Visible = false
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
