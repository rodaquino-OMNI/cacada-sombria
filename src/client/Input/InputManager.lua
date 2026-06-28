--!strict
--[[
  InputManager.lua
  Gerencia todo o input do jogador no cliente.
  
  Responsável por:
  - Capturar teclas pressionadas (WASD, Shift, Ctrl, E, Q, R, F)
  - Capturar mouse (movimento, cliques)
  - Mapear inputs para ações do jogo
  - Enviar ações para o servidor via RemoteEvent
  - Suporte a mobile (joystick virtual e botões) — FUTURO

  Controles PC:
    WASD          → Mover
    Mouse         → Olhar ao redor
    Shift         → Correr (segurar)
    Ctrl          → Agachar (alternar/toggle)
    E             → Interagir
    Q             → Habilidade 1
    Botão Direito → Habilidade 2 (Sobreviventes)
    R             → Habilidade 3 / Rage (Caçador)
    F             → Interagir (Caçador: carregar/jaula; Robô: Sacrifício)
    Clique Esq.   → M1 (Caçador: ataque básico)
    Espaço        → Pular

  Contexto: Client (StarterPlayerScripts)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- ==========================================
-- SERVIÇO INPUTMANAGER
-- ==========================================
local InputManager = {}
InputManager.__index = InputManager

-- ==========================================
-- TIPOS DE AÇÃO DE INPUT
-- ==========================================
-- Mapeamos teclas físicas para "ações lógicas" do jogo
-- Assim, se mudarmos a tecla, só mudamos o mapa, não o código todo

local KEY_MAP = {
	-- Movimento
	MoveForward = Enum.KeyCode.W,
	MoveBackward = Enum.KeyCode.S,
	MoveLeft = Enum.KeyCode.A,
	MoveRight = Enum.KeyCode.D,
	Jump = Enum.KeyCode.Space,

	-- Ações
	Sprint = Enum.KeyCode.LeftShift,
	Crouch = Enum.KeyCode.LeftControl,
	Interact = Enum.KeyCode.E,
	Ability1 = Enum.KeyCode.Q,
	Ability2 = Enum.KeyCode.ButtonR2, -- Botão Direito do Mouse
	Ability3 = Enum.KeyCode.R,
	KillerInteract = Enum.KeyCode.F,
	KillerM1 = Enum.KeyCode.ButtonR1, -- Botão Esquerdo do Mouse
}

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Referência ao RemoteEvent (setado durante Init)
local _actionEvent: RemoteEvent? = nil

-- Estado das teclas (true = pressionada, false/nil = solta)
local _keysPressed: {[Enum.KeyCode]: boolean} = {}

-- Estado de movimento atual
local _moveDirection = Vector3.new(0, 0, 0) -- Direção de movimento (WASD combinado)

-- Estado do mouse
local _mouseDelta = Vector2.new(0, 0) -- Movimento do mouse desde o último frame

-- Estado de toggle
local _isCrouching = false -- Ctrl é toggle (liga/desliga)
local _isSprinting = false -- Shift é hold (segurar)

-- Conexões de eventos para cleanup
local _connections: {RBXScriptConnection} = {}

-- Callbacks registrados
local _onMoveCallback: ((direction: Vector3) -> ())? = nil
local _onLookCallback: ((delta: Vector2) -> ())? = nil

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Inicializa o InputManager
-- Deve ser chamado pelo ClientManager durante a fase Init
function InputManager.Init(actionEvent: RemoteEvent)
	_actionEvent = actionEvent

	-- Registra handlers de input
	InputManager:_registerInputHandlers()

	-- Registra ações de movimento via ContextActionService
	-- Isso permite que bindings de mobile funcionem automaticamente
	InputManager:_registerContextActions()

	print("[CacadaSombria] InputManager inicializado.")
end

-- ==========================================
-- HANDLERS DE INPUT
-- ==========================================

-- Registra todos os listeners de input
function InputManager:_registerInputHandlers()
	-- ⚠️ Importante: Sempre guardar as conexões para poder desconectar depois
	-- Isso evita memory leaks

	-- Quando qualquer tecla é pressionada
	local conn1 = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		InputManager:_onInputBegan(input, gameProcessed)
	end)
	table.insert(_connections, conn1)

	-- Quando qualquer tecla é solta
	local conn2 = UserInputService.InputEnded:Connect(function(input: InputObject)
		InputManager:_onInputEnded(input)
	end)
	table.insert(_connections, conn2)

	-- Quando o mouse se move
	local conn3 = UserInputService.InputChanged:Connect(function(input: InputObject)
		InputManager:_onInputChanged(input)
	end)
	table.insert(_connections, conn3)

	print("[CacadaSombria] Handlers de input registrados.")
end

-- Chamado quando uma tecla/mouse é pressionado
function InputManager:_onInputBegan(input: InputObject, gameProcessed: boolean)
	-- gameProcessed = true significa que o Roblox já processou esse input
	-- (ex: o jogador estava digitando no chat). Nós ignoramos nesse caso.
	if gameProcessed then return end

	local keyCode = input.KeyCode
	local userInputType = input.UserInputType

	-- Registra a tecla como pressionada
	_keysPressed[keyCode] = true

	-- ==========================
	-- AÇÕES DISPARADAS NO PRESSIONAR
	-- ==========================

	-- Tecla de agachar (Ctrl) — TOGGLE (alterna)
	if keyCode == KEY_MAP.Crouch then
		_isCrouching = not _isCrouching
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.CROUCH_TOGGLE)
		end
		print(string.format("[CacadaSombria] Agachar: %s", _isCrouching and "SIM" or "NÃO"))
	end

	-- Tecla de interagir (E)
	if keyCode == KEY_MAP.Interact then
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.INTERACT)
		end
	end

	-- Tecla de habilidade 1 (Q)
	if keyCode == KEY_MAP.Ability1 then
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.ABILITY_1)
		end
	end

	-- Botão direito do mouse — Habilidade 2
	if userInputType == Enum.UserInputType.MouseButton2 then
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.ABILITY_2)
		end
	end

	-- Tecla R — Habilidade 3
	if keyCode == KEY_MAP.Ability3 then
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.ABILITY_3)
		end
	end

	-- Tecla F — Interagir (Caçador: carregar Sobrevivente)
	if keyCode == KEY_MAP.KillerInteract then
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.INTERACT)
		end
	end

	-- Clique esquerdo — M1 do Caçador
	if userInputType == Enum.UserInputType.MouseButton1 then
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.KILLER_M1)
		end
	end

	-- ==========================
	-- CORRIDA (SPRINT) — HOLD (segurar)
	-- ==========================
	-- Shift inicia a corrida; soltar Shift para
	if keyCode == KEY_MAP.Sprint then
		if not _isSprinting then
			_isSprinting = true
			if _actionEvent then
				PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.SPRINT_START)
			end
		end
	end
end

-- Chamado quando uma tecla/mouse é solta
function InputManager:_onInputEnded(input: InputObject)
	local keyCode = input.KeyCode

	-- Marca a tecla como solta
	_keysPressed[keyCode] = nil

	-- Se soltou o Shift, para de correr
	if keyCode == KEY_MAP.Sprint then
		_isSprinting = false
		if _actionEvent then
			PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.SPRINT_STOP)
		end
	end
end

-- Chamado quando o mouse se move ou um input analógico muda
function InputManager:_onInputChanged(input: InputObject)
	-- Captura movimento do mouse (para câmera)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		_mouseDelta = input.Delta -- Delta = Vector2(dX, dY)

		-- Chama o callback de look, se registrado
		if _onLookCallback then
			_onLookCallback(_mouseDelta)
		end
	end
end

-- ==========================================
-- CONTEXT ACTIONS (SUPORTE A MOBILE FUTURO)
-- ==========================================

-- ContextActionService permite criar ações que funcionam tanto
-- com teclado quanto com touch (mobile) automaticamente
function InputManager:_registerContextActions()
	-- Ação de agachar
	ContextActionService:BindAction(
		"CrouchAction",
		function(actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			if inputState == Enum.UserInputState.Begin then
				_isCrouching = not _isCrouching
				if _actionEvent then
					PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.CROUCH_TOGGLE)
				end
			end
		end,
		false, -- false = não cria botão touch automaticamente
		KEY_MAP.Crouch
	)

	-- Ação de interagir
	ContextActionService:BindAction(
		"InteractAction",
		function(actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			if inputState == Enum.UserInputState.Begin then
				if _actionEvent then
					PlayerActionEvent.fireAction(_actionEvent, PlayerActionEvent.ACTIONS.INTERACT)
				end
			end
		end,
		false,
		KEY_MAP.Interact
	)

	print("[CacadaSombria] ContextActions registradas (Crouch, Interact).")
end

-- ==========================================
-- MOVIMENTO — LEITURA CONTÍNUA
-- ==========================================

-- Calcula a direção de movimento baseada nas teclas WASD pressionadas
-- Retorna um Vector3 normalizado representando a direção
-- Este método é chamado pelo CameraManager ou ClientManager a cada frame
function InputManager.getMoveDirection(): Vector3
	local direction = Vector3.new(0, 0, 0)

	-- W / Seta para cima → Frente
	if _keysPressed[KEY_MAP.MoveForward] then
		direction += Vector3.new(0, 0, -1) -- Negativo em Z = frente no Roblox
	end

	-- S / Seta para baixo → Trás
	if _keysPressed[KEY_MAP.MoveBackward] then
		direction += Vector3.new(0, 0, 1) -- Positivo em Z = trás
	end

	-- A / Seta esquerda → Esquerda
	if _keysPressed[KEY_MAP.MoveLeft] then
		direction += Vector3.new(-1, 0, 0)
	end

	-- D / Seta direita → Direita
	if _keysPressed[KEY_MAP.MoveRight] then
		direction += Vector3.new(1, 0, 0)
	end

	-- Normaliza o vetor para movimento diagonal não ser mais rápido
	-- que movimento em linha reta
	if direction.Magnitude > 0 then
		direction = direction.Unit
	end

	return direction
end

-- Retorna se o jogador está tentando pular neste frame
function InputManager.isJumping(): boolean
	return _keysPressed[KEY_MAP.Jump] == true
end

-- Retorna se o jogador está correndo (Shift pressionado)
function InputManager.isSprinting(): boolean
	return _isSprinting
end

-- Retorna se o jogador está agachado (Ctrl toggle)
function InputManager.isCrouching(): boolean
	return _isCrouching
end

-- Retorna o delta do mouse desde o último frame
function InputManager.getMouseDelta(): Vector2
	return _mouseDelta
end

-- ==========================================
-- CALLBACKS
-- ==========================================

-- Registra um callback para quando o jogador se move
-- @param callback — function(direction: Vector3)
function InputManager.onMove(callback: (direction: Vector3) -> ())
	_onMoveCallback = callback
end

-- Registra um callback para quando o mouse se move
-- @param callback — function(delta: Vector2)
function InputManager.onLook(callback: (delta: Vector2) -> ())
	_onLookCallback = callback
end

-- ==========================================
-- CONTROLE DE MOUSE (CURSOR)
-- ==========================================

-- Trava o mouse no centro da tela (para câmera em 1ª ou 3ª pessoa)
function InputManager.lockMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	print("[CacadaSombria] Mouse travado no centro da tela.")
end

-- Solta o mouse (para menus/UI)
function InputManager.unlockMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	print("[CacadaSombria] Mouse liberado.")
end

-- ==========================================
-- LIMPEZA (CLEANUP)
-- ==========================================

-- Desconecta todos os listeners e libera recursos
function InputManager.Destroy()
	-- Desconecta todos os handlers de input
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	-- Remove ContextActions
	ContextActionService:UnbindAction("CrouchAction")
	ContextActionService:UnbindAction("InteractAction")

	-- Reseta estado
	table.clear(_keysPressed)
	_moveDirection = Vector3.new(0, 0, 0)
	_mouseDelta = Vector2.new(0, 0)
	_isCrouching = false
	_isSprinting = false

	print("[CacadaSombria] InputManager destruído.")
end

return InputManager
