--!strict
--[[
  SurvivorHUD.lua
  Interface do Sobrevivente — barras de HP e Stamina.
  
  Exibe:
  - Barra de HP (canto inferior esquerdo)
  - Barra de Stamina (abaixo da barra de HP)
  - Indicador de estado (correndo, agachado, escondido)
  - Ícones de habilidade com cooldown (Épico E3)

  Design: Minimalista — barras com gradiente suave, texto pequeno.
  Todas as atualizações são recebidas do servidor via GameStateEvent.

  Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)

-- ==========================================
-- SERVIÇO SURVIVORHUD
-- ==========================================
local SurvivorHUD = {}
SurvivorHUD.__index = SurvivorHUD

-- ==========================================
-- ESTADO INTERNO
-- ==========================================
local _player = Players.LocalPlayer
local _playerGui: PlayerGui? = nil
local _screenGui: ScreenGui? = nil
local _isSetup = false

-- Elementos da UI
local _hpBar: Frame? = nil
local _hpFill: Frame? = nil
local _hpLabel: TextLabel? = nil
local _staminaBar: Frame? = nil
local _staminaFill: Frame? = nil
local _staminaLabel: TextLabel? = nil
local _stateLabel: TextLabel? = nil

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- ==========================================
-- CONSTANTES DE DESIGN
-- ==========================================
local BAR_WIDTH = 180          -- Largura das barras em pixels
local BAR_HEIGHT = 20          -- Altura das barras
local BAR_MARGIN = 10          -- Margem da borda da tela
local BAR_SPACING = 5          -- Espaço entre barras
local CORNER_RADIUS = UDim.new(0, 4) -- Cantos arredondados

-- Cores
local HP_COLOR = Color3.fromRGB(200, 50, 50)        -- Vermelho para HP
local HP_BG_COLOR = Color3.fromRGB(40, 10, 10)      -- Fundo escuro da barra de HP
local STAMINA_COLOR = Color3.fromRGB(50, 150, 200)   -- Azul para Stamina
local STAMINA_BG_COLOR = Color3.fromRGB(10, 30, 40)  -- Fundo escuro da barra de Stamina
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)     -- Texto branco

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Cria a HUD do Sobrevivente
-- Deve ser chamado pelo ClientManager após receber ROLE_ASSIGN do servidor
function SurvivorHUD.Init()
	-- Obtém o PlayerGui (container de UI do jogador)
	_playerGui = _player:FindFirstChild("PlayerGui")
	if not _playerGui then
		warn("[CacadaSombria] SurvivorHUD: PlayerGui não encontrado!")
		return
	end

	-- Cria o ScreenGui que vai conter toda a HUD
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "SurvivorHUD"
	_screenGui.ResetOnSpawn = false -- 🔑 Importante: não resetar ao morrer/respawnar!
	_screenGui.Parent = _playerGui

	-- Cria os elementos da HUD
	SurvivorHUD:_createHPBar()
	SurvivorHUD:_createStaminaBar()
	SurvivorHUD:_createStateLabel()

	-- Registra o listener de eventos do servidor
	SurvivorHUD:_registerEventListeners()

	_isSetup = true

	print("[CacadaSombria] SurvivorHUD criado e configurado.")
end

-- ==========================================
-- CRIAÇÃO DOS ELEMENTOS VISUAIS
-- ==========================================

-- Cria a barra de HP
function SurvivorHUD:_createHPBar()
	if not _screenGui then return end

	-- Container da barra (fundo escuro)
	_hpBar = Instance.new("Frame")
	_hpBar.Name = "HPBar"
	_hpBar.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	_hpBar.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT * 2 + BAR_SPACING + BAR_MARGIN))
	_hpBar.AnchorPoint = Vector2.new(0, 1) -- Ancorado no canto inferior esquerdo
	_hpBar.BackgroundColor3 = HP_BG_COLOR
	_hpBar.BorderSizePixel = 0
	_hpBar.Parent = _screenGui

	-- Adiciona cantos arredondados
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = CORNER_RADIUS
	barCorner.Parent = _hpBar

	-- Preenchimento da barra (a parte colorida que diminui com o dano)
	_hpFill = Instance.new("Frame")
	_hpFill.Name = "HPFill"
	_hpFill.Size = UDim2.new(1, 0, 1, 0) -- Começa cheio (100% HP)
	_hpFill.BackgroundColor3 = HP_COLOR
	_hpFill.BorderSizePixel = 0
	_hpFill.Parent = _hpBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = CORNER_RADIUS
	fillCorner.Parent = _hpFill

	-- Texto "HP: 120/120"
	_hpLabel = Instance.new("TextLabel")
	_hpLabel.Name = "HPLabel"
	_hpLabel.Size = UDim2.new(1, 0, 1, 0)
	_hpLabel.BackgroundTransparency = 1 -- Fundo transparente (só o texto)
	_hpLabel.TextColor3 = TEXT_COLOR
	_hpLabel.Text = "HP: 120/120"
	_hpLabel.TextSize = 14
	_hpLabel.Font = Enum.Font.GothamBold
	_hpLabel.TextStrokeTransparency = 0.5 -- Contorno para legibilidade
	_hpLabel.Parent = _hpBar
end

-- Cria a barra de Stamina
function SurvivorHUD:_createStaminaBar()
	if not _screenGui then return end

	-- Container da barra
	_staminaBar = Instance.new("Frame")
	_staminaBar.Name = "StaminaBar"
	_staminaBar.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	_staminaBar.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT + BAR_MARGIN))
	_staminaBar.AnchorPoint = Vector2.new(0, 1)
	_staminaBar.BackgroundColor3 = STAMINA_BG_COLOR
	_staminaBar.BorderSizePixel = 0
	_staminaBar.Parent = _screenGui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = CORNER_RADIUS
	barCorner.Parent = _staminaBar

	-- Preenchimento
	_staminaFill = Instance.new("Frame")
	_staminaFill.Name = "StaminaFill"
	_staminaFill.Size = UDim2.new(1, 0, 1, 0) -- Começa cheio
	_staminaFill.BackgroundColor3 = STAMINA_COLOR
	_staminaFill.BorderSizePixel = 0
	_staminaFill.Parent = _staminaBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = CORNER_RADIUS
	fillCorner.Parent = _staminaFill

	-- Texto "Stamina: 100/100"
	_staminaLabel = Instance.new("TextLabel")
	_staminaLabel.Name = "StaminaLabel"
	_staminaLabel.Size = UDim2.new(1, 0, 1, 0)
	_staminaLabel.BackgroundTransparency = 1
	_staminaLabel.TextColor3 = TEXT_COLOR
	_staminaLabel.Text = "Stamina: 100/100"
	_staminaLabel.TextSize = 14
	_staminaLabel.Font = Enum.Font.GothamBold
	_staminaLabel.TextStrokeTransparency = 0.5
	_staminaLabel.Parent = _staminaBar
end

-- Cria o label de estado (Correndo, Agachado, Escondido...)
function SurvivorHUD:_createStateLabel()
	if not _screenGui then return end

	_stateLabel = Instance.new("TextLabel")
	_stateLabel.Name = "StateLabel"
	_stateLabel.Size = UDim2.new(0, 200, 0, 24)
	_stateLabel.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT * 2 + BAR_SPACING + BAR_MARGIN + 28))
	_stateLabel.AnchorPoint = Vector2.new(0, 1)
	_stateLabel.BackgroundTransparency = 1
	_stateLabel.TextColor3 = Color3.fromRGB(255, 255, 100) -- Amarelo claro
	_stateLabel.Text = ""
	_stateLabel.TextSize = 12
	_stateLabel.Font = Enum.Font.Gotham
	_stateLabel.TextStrokeTransparency = 0.5
	_stateLabel.Parent = _screenGui
end

-- ==========================================
-- LISTENERS DE EVENTOS DO SERVIDOR
-- ==========================================

-- Registra os handlers para mensagens do servidor via GameStateEvent
function SurvivorHUD:_registerEventListeners()
	-- Usa utilitário seguro que garante RemoteEvent (não ModuleScript)
	local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
	local gameStateEvent = RemoteEventUtils.find("GameStateEvent")
	
	if not gameStateEvent then
		warn("[CacadaSombria] SurvivorHUD: RemoteEvent GameStateEvent não encontrado")
		return
	end

	-- Escuta mensagens do servidor
	local conn = gameStateEvent.OnClientEvent:Connect(function(messageType: string, ...)
		SurvivorHUD:_handleServerMessage(messageType, ...)
	end)
	table.insert(_connections, conn)

	print("[CacadaSombria] SurvivorHUD: Listener de GameStateEvent registrado.")
end

-- Processa mensagens recebidas do servidor
function SurvivorHUD:_handleServerMessage(messageType: string, ...)
	local args = {...}

	-- ==========================
	-- ATUALIZAÇÃO DE HP
	-- ==========================
	if messageType == GameStateEvent.MESSAGES.HP_UPDATE then
		local currentHP: number = args[1]
		local maxHP: number = args[2]
		SurvivorHUD:updateHP(currentHP, maxHP)

	-- ==========================
	-- ATUALIZAÇÃO DE STAMINA
	-- ==========================
	elseif messageType == GameStateEvent.MESSAGES.STAMINA_UPDATE then
		local currentStamina: number = args[1]
		local maxStamina: number = args[2]
		SurvivorHUD:updateStamina(currentStamina, maxStamina)

	-- ==========================
	-- ATUALIZAÇÃO DE ESTADO DE SPRINT
	-- ==========================
	elseif messageType == GameStateEvent.MESSAGES.SPRINT_STATE then
		local isSprinting: boolean = args[1]
		if _stateLabel then
			if isSprinting then
				_stateLabel.Text = "🏃 CORRENDO"
				_stateLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Verde
			else
				_stateLabel.Text = ""
			end
		end

	-- ==========================
	-- ATUALIZAÇÃO DE ESTADO DE AGACHAMENTO
	-- ==========================
	elseif messageType == GameStateEvent.MESSAGES.CROUCH_STATE then
		local isCrouching: boolean = args[1]
		if _stateLabel then
			if isCrouching then
				_stateLabel.Text = "👣 AGACHADO (furtivo)"
				_stateLabel.TextColor3 = Color3.fromRGB(150, 150, 255) -- Azul claro
			else
				_stateLabel.Text = ""
			end
		end
	end
end

-- ==========================================
-- ATUALIZAÇÕES DE UI
-- ==========================================

-- Atualiza a barra de HP
-- @param currentHP — HP atual
-- @param maxHP — HP máximo
function SurvivorHUD:updateHP(currentHP: number, maxHP: number)
	if not _hpFill or not _hpLabel then return end

	-- Calcula a porcentagem de HP restante
	local percent = math.clamp(currentHP / maxHP, 0, 1)

	-- Atualiza a largura da barra de preenchimento
	_hpFill.Size = UDim2.new(percent, 0, 1, 0)

	-- Atualiza o texto
	_hpLabel.Text = string.format("HP: %.0f/%.0f", currentHP, maxHP)

	-- Muda a cor da barra baseado na quantidade de HP
	-- Verde (> 60%), Amarelo (30-60%), Vermelho (< 30%)
	if percent > 0.6 then
		_hpFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- Verde
	elseif percent > 0.3 then
		_hpFill.BackgroundColor3 = Color3.fromRGB(200, 180, 50) -- Amarelo
	else
		_hpFill.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Vermelho
	end
end

-- Atualiza a barra de Stamina
-- @param currentStamina — Stamina atual (0-100)
-- @param maxStamina — Stamina máxima (100)
function SurvivorHUD:updateStamina(currentStamina: number, maxStamina: number)
	if not _staminaFill or not _staminaLabel then return end

	-- Calcula a porcentagem
	local percent = math.clamp(currentStamina / maxStamina, 0, 1)

	-- Atualiza a barra
	_staminaFill.Size = UDim2.new(percent, 0, 1, 0)

	-- Atualiza o texto
	_staminaLabel.Text = string.format("Stamina: %.0f/%.0f", currentStamina, maxStamina)

	-- Muda a cor quando a stamina está baixa
	if percent < 0.2 then
		_staminaFill.BackgroundColor3 = Color3.fromRGB(200, 100, 50) -- Laranja (baixa)
	else
		_staminaFill.BackgroundColor3 = STAMINA_COLOR -- Azul normal
	end
end

-- ==========================================
-- MOSTRAR / ESCONDER
-- ==========================================

-- Mostra a HUD
function SurvivorHUD:show()
	if _screenGui then
		_screenGui.Enabled = true
	end
end

-- Esconde a HUD
function SurvivorHUD:hide()
	if _screenGui then
		_screenGui.Enabled = false
	end
end

-- ==========================================
-- LIMPEZA
-- ==========================================

function SurvivorHUD.Destroy()
	-- Desconecta listeners
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	-- Destrói a UI
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end

	_isSetup = false

	print("[CacadaSombria] SurvivorHUD destruído.")
end

return SurvivorHUD
