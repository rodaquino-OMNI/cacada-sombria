--!strict
--[[
  CameraManager.lua
  Gerencia a câmera do jogador no cliente.
  
  Suporta dois modos:
  1. TERCEIRA PESSOA (Sobreviventes): Câmera atrás do personagem,
     com mouse look e distância ajustável.
  2. PRIMEIRA PESSOA (Caçador): Câmera nos olhos do personagem,
     FOV 90°, imersão total.

  Responsável por:
  - Configurar o modo de câmera baseado no papel do jogador
  - Controlar rotação da câmera via mouse
  - Gerenciar zoom e distância (3ª pessoa)
  - FOV (campo de visão) para 1ª pessoa
  - Suporte a mobile (toque) — FUTURO

  Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- ==========================================
-- CONSTANTES DE CÂMERA
-- ==========================================

-- Terceira Pessoa (Sobreviventes)
local THIRD_PERSON_DISTANCE = 10       -- Distância da câmera atrás do personagem (studs)
local THIRD_PERSON_HEIGHT_OFFSET = 2    -- Altura da câmera em relação ao personagem
local THIRD_PERSON_FOV = 70             -- Campo de visão em graus
local MOUSE_SENSITIVITY = 0.5           -- Sensibilidade do mouse (multiplicador)

-- Primeira Pessoa (Caçador)
local FIRST_PERSON_FOV = 90             -- Campo de visão do Caçador
local FIRST_PERSON_HEIGHT_OFFSET = 1.5  -- Altura dos "olhos" do Caçador

-- ==========================================
-- SERVIÇO CAMERAMANAGER
-- ==========================================
local CameraManager = {}
CameraManager.__index = CameraManager

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

local _camera: Camera? = nil                    -- Referência à câmera atual
local _currentMode: string = "ThirdPerson"      -- "ThirdPerson" ou "FirstPerson"
local _player: Player = Players.LocalPlayer     -- Jogador local

-- Controle de rotação (apenas horizontal + vertical)
local _yaw: number = 0    -- Rotação horizontal (esquerda/direita), em radianos
local _pitch: number = 0  -- Rotação vertical (cima/baixo), em radianos

-- Limites de pitch para evitar que a câmera dê loop
local PITCH_MIN = math.rad(-80)  -- Olhar quase reto para baixo
local PITCH_MAX = math.rad(80)   -- Olhar quase reto para cima

-- Conexões para cleanup
local _connections: {RBXScriptConnection} = {}

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Inicializa o CameraManager
-- Deve ser chamado pelo ClientManager após receber o papel do servidor
-- @param mode — "ThirdPerson" para Sobreviventes, "FirstPerson" para Caçador
function CameraManager.Init(mode: string?)
	_currentMode = mode or "ThirdPerson"

	-- Obtém a câmera atual do workspace
	_camera = Workspace.CurrentCamera

	if not _camera then
		warn("[CacadaSombria] CameraManager: Câmera não encontrada!")
		return
	end

	-- Configura a câmera de acordo com o modo
	if _currentMode == "FirstPerson" then
		CameraManager:_setupFirstPerson()
	else
		CameraManager:_setupThirdPerson()
	end

	-- Conecta ao loop de renderização para atualização suave
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		CameraManager:_update(dt)
	end)
	table.insert(_connections, conn)

	print(string.format("[CacadaSombria] CameraManager inicializado no modo: %s", _currentMode))
end

-- ==========================================
-- CONFIGURAÇÃO: TERCEIRA PESSOA
-- ==========================================

-- Configura a câmera para o modo Terceira Pessoa (Sobreviventes)
function CameraManager:_setupThirdPerson()
	if not _camera then return end

	-- 🔧 Configurações da câmera no Roblox
	_camera.CameraType = Enum.CameraType.Custom -- Nós controlamos a câmera
	_camera.FieldOfView = THIRD_PERSON_FOV

	-- Inicializa os ângulos baseado na orientação atual do personagem
	local character = _player.Character
	if character then
		local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- Extrai yaw (rotação horizontal) do CFrame do personagem
			local lookVector = rootPart.CFrame.LookVector
			_yaw = math.atan2(lookVector.X, lookVector.Z)
			_pitch = 0 -- Começa olhando reto
		end
	end

	print("[CacadaSombria] Câmera configurada: TERCEIRA PESSOA (Sobrevivente)")
end

-- ==========================================
-- CONFIGURAÇÃO: PRIMEIRA PESSOA
-- ==========================================

-- Configura a câmera para o modo Primeira Pessoa (Caçador)
function CameraManager:_setupFirstPerson()
	if not _camera then return end

	-- Configurações de câmera em 1ª pessoa
	_camera.CameraType = Enum.CameraType.Custom
	_camera.FieldOfView = FIRST_PERSON_FOV -- 90° (mais amplo que o padrão 70°)

	-- Inicializa ângulos
	local character = _player.Character
	if character then
		local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local lookVector = rootPart.CFrame.LookVector
			_yaw = math.atan2(lookVector.X, lookVector.Z)
			_pitch = 0
		end
	end

	print("[CacadaSombria] Câmera configurada: PRIMEIRA PESSOA (Caçador) | FOV: 90°")
end

-- ==========================================
-- ATUALIZAÇÃO DA CÂMERA (CHAMADA A CADA FRAME)
-- ==========================================

-- Atualiza a posição e rotação da câmera
-- Chamada via RenderStepped para máxima fluidez
function CameraManager:_update(dt: number)
	if not _camera then return end

	-- Obtém o character atual do jogador
	local character = _player.Character
	if not character then return end

	-- Obtém a HumanoidRootPart (centro do personagem)
	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Obtém o Humanoid (para detectar estado de agachamento)
	local humanoid: Humanoid? = character:FindFirstChild("Humanoid")

	-- ==========================
	-- ATUALIZA ROTAÇÃO PELO MOUSE
	-- ==========================
	-- Lê o delta do mouse (movimento desde o último frame)
	local mouseDelta = UserInputService:GetMouseDelta()

	-- Aplica sensibilidade
	local deltaYaw = mouseDelta.X * MOUSE_SENSITIVITY * 0.01   -- Movimento horizontal
	local deltaPitch = mouseDelta.Y * MOUSE_SENSITIVITY * 0.01  -- Movimento vertical

	-- Atualiza ângulos acumulados
	_yaw = _yaw - deltaYaw       -- Negativo porque o Roblox usa orientação diferente
	_pitch = _pitch - deltaPitch

	-- Limita o pitch para a câmera não girar 360° na vertical
	_pitch = math.clamp(_pitch, PITCH_MIN, PITCH_MAX)

	-- ==========================
	-- CALCULA POSIÇÃO DA CÂMERA
	-- ==========================
	local cameraPosition: Vector3
	local cameraLookAt: Vector3

	if _currentMode == "FirstPerson" then
		-- ==========================
		-- MODO: PRIMEIRA PESSOA
		-- ==========================
		-- A câmera fica na posição dos "olhos" do personagem

		-- Posição base = cabeça do personagem
		local head: BasePart? = character:FindFirstChild("Head")
		if head then
			cameraPosition = head.Position
		else
			-- Fallback: usa a RootPart mais offset
			cameraPosition = rootPart.Position + Vector3.new(0, FIRST_PERSON_HEIGHT_OFFSET, 0)
		end

		-- A câmera olha na direção do mouse
		-- Constrói CFrame a partir de yaw e pitch
		local lookCFrame = CFrame.new(cameraPosition) *
			CFrame.Angles(0, _yaw, 0) *           -- Rotação horizontal
			CFrame.Angles(_pitch, 0, 0)            -- Rotação vertical

		_camera.CFrame = lookCFrame

		-- Em 1ª pessoa, o personagem rotaciona para acompanhar para onde olhamos
		-- Isso é importante para o movimento WASD ser relativo à visão
		rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, _yaw, 0)

	else
		-- ==========================
		-- MODO: TERCEIRA PESSOA
		-- ==========================

		-- Posição do personagem (com offset de altura)
		local characterPos = rootPart.Position + Vector3.new(0, THIRD_PERSON_HEIGHT_OFFSET, 0)

		-- Se estiver agachado, abaixa um pouco a câmera
		if humanoid and humanoid.HipHeight < 2 then
			characterPos = rootPart.Position + Vector3.new(0, 1, 0)
		end

		-- Calcula a direção da câmera baseada nos ângulos yaw e pitch
		-- A câmera fica ATRÁS do personagem (daí o sinal negativo na distância)
		local cameraOffset = Vector3.new(0, 0, THIRD_PERSON_DISTANCE)

		-- Constrói o CFrame da câmera:
		-- 1. Começa na posição do personagem
		-- 2. Rotaciona horizontalmente (yaw)
		-- 3. Rotaciona verticalmente (pitch)
		-- 4. Move para trás (distância da câmera)
		local cameraCFrame = CFrame.new(characterPos) *
			CFrame.Angles(0, _yaw, 0) *
			CFrame.Angles(_pitch, 0, 0) *
			CFrame.new(cameraOffset)

		_camera.CFrame = cameraCFrame

		-- O personagem gira para acompanhar a direção da câmera
		-- (apenas a rotação horizontal)
		rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, _yaw, 0)
	end
end

-- ==========================================
-- FUNÇÕES PÚBLICAS
-- ==========================================

-- Alterna entre modos de câmera (útil para debug)
function CameraManager.toggleMode()
	if _currentMode == "ThirdPerson" then
		_currentMode = "FirstPerson"
		CameraManager:_setupFirstPerson()
	else
		_currentMode = "ThirdPerson"
		CameraManager:_setupThirdPerson()
	end
end

-- Retorna o modo atual da câmera
function CameraManager.getMode(): string
	return _currentMode
end

-- Ajusta a sensibilidade do mouse
function CameraManager.setSensitivity(value: number)
	MOUSE_SENSITIVITY = math.max(0.1, math.min(value, 2.0))
end

-- Retorna a direção para onde a câmera está olhando (vetor normalizado)
-- Útil para habilidades que disparam na direção da mira
function CameraManager.getLookDirection(): Vector3
	if not _camera then return Vector3.new(0, 0, -1) end
	return _camera.CFrame.LookVector
end

-- ==========================================
-- LIMPEZA (CLEANUP)
-- ==========================================

function CameraManager.Destroy()
	-- Desconecta todos os handlers
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	-- Reseta a câmera para o comportamento padrão
	if _camera then
		_camera.CameraType = Enum.CameraType.Custom
		_camera.FieldOfView = 70
	end

	print("[CacadaSombria] CameraManager destruído.")
end

return CameraManager
