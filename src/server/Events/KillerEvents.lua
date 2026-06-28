--!strict
--[[
  KillerEvents.lua
  Handlers de eventos do Caçador no servidor.

  Responsável por:
  - Receber ações do Caçador via PlayerActionEvent
  - Validar e encaminhar para KillerService
  - Rate limiting básico anti-spam
  - Validações de segurança server-side

  Toda ação do Caçador passa por validação aqui
  antes de chegar ao KillerService.

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- ==========================================
-- CONSTANTES
-- ==========================================
-- Intervalo mínimo entre ações do mesmo jogador (anti-spam)
local RATE_LIMIT = 0.1  -- 100ms

-- ==========================================
-- SERVIÇO KILLEREVENTS
-- ==========================================
local KillerEvents = {}

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Timestamps da última ação por jogador (rate limiting)
local _lastActionTime: {[number]: number} = {}

-- Referência ao KillerService (setada durante Init)
local _killerService: any = nil

-- Referência ao MatchService (para validações)
local _matchService: any = nil

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init
-- @param playerActionEvent — RemoteEvent de ações do jogador
-- @param killerService — Referência ao KillerService
-- @param matchService — Referência ao MatchService
function KillerEvents.Init(playerActionEvent: RemoteEvent, killerService: any, matchService: any)
	_killerService = killerService
	_matchService = matchService

	-- Registra o handler central de ações do Caçador
	playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
		KillerEvents:_handleKillerAction(player, action, ...)
	end)

	print("[CacadaSombria] KillerEvents inicializado.")
end

-- ==========================================
-- HANDLER CENTRAL DE AÇÕES DO CAÇADOR
-- ==========================================

-- Processa uma ação vinda do cliente do Caçador
-- Aplica rate limiting e validações antes de encaminhar
function KillerEvents:_handleKillerAction(player: Player, action: string, ...: any)
	-- ==========================
	-- VALIDAÇÕES BÁSICAS
	-- ==========================

	-- Verifica se é uma ação de Caçador
	if not KillerEvents:_isKillerAction(action) then
		return  -- Não é ação de Caçador, ignora
	end

	-- Rate limiting: evita spam de ações
	if not KillerEvents:_checkRateLimit(player) then
		return  -- Ação muito rápida, descarta
	end

	-- Verifica se o jogador é o Caçador
	if not _matchService then return end
	local state = _matchService:getPlayerState(player)
	if not state or state.role ~= "Killer" then
		-- Não é o Caçador tentando usar ação de Caçador
		-- Possível tentativa de exploit
		print(string.format("[CacadaSombria] ALERTA: %s (não-Caçador) tentou usar ação '%s'", player.Name, action))
		return
	end

	-- Verifica se está vivo
	if not state.isAlive then return end

	-- Verifica se está atordoado
	if state.isStunned then return end

	-- Verifica se está escondido (Killer não se esconde, mas por segurança)
	if state.isHiding then return end

	-- ==========================
	-- ROTEAMENTO POR TIPO DE AÇÃO
	-- ==========================

	if action == PlayerActionEvent.ACTIONS.KILLER_M1 then
		-- M1: Tapa (ataque corpo a corpo)
		KillerEvents:_handleM1(player)

	elseif action == PlayerActionEvent.ACTIONS.ABILITY_1 then
		-- Q: Braço Esticado (puxão)
		KillerEvents:_handleBracoEsticado(player)

	elseif action == PlayerActionEvent.ACTIONS.ABILITY_2 then
		-- E: Grito (scream)
		KillerEvents:_handleGrito(player)

	elseif action == PlayerActionEvent.ACTIONS.ABILITY_3 then
		-- R: Rage (transformação)
		KillerEvents:_handleRage(player)
	end
end

-- ==========================================
-- HANDLERS ESPECÍFICOS DE HABILIDADES
-- ==========================================

-- M1 — Tapa (ataque corpo a corpo)
function KillerEvents:_handleM1(player: Player)
	if not _killerService then return end

	-- Obtém a direção do olhar do Caçador
	local aimDirection = KillerEvents:_getPlayerLookDirection(player)
	if not aimDirection then return end

	print(string.format("[CacadaSombria] Caçador %s usou M1", player.Name))
	_killerService:performM1(player, aimDirection)
end

-- Q — Braço Esticado (puxão)
function KillerEvents:_handleBracoEsticado(player: Player)
	if not _killerService then return end

	-- Obtém a direção do olhar
	local aimDirection = KillerEvents:_getPlayerLookDirection(player)
	if not aimDirection then return end

	print(string.format("[CacadaSombria] Caçador %s usou Braço Esticado (Q)", player.Name))
	_killerService:performBracoEsticado(player, aimDirection)
end

-- R — Rage (transformação)
function KillerEvents:_handleRage(player: Player)
	if not _killerService then return end

	print(string.format("[CacadaSombria] Caçador %s tentou ativar Rage (R)", player.Name))
	_killerService:activateRage(player)
end

-- E — Grito (scream)
function KillerEvents:_handleGrito(player: Player)
	if not _killerService then return end

	print(string.format("[CacadaSombria] Caçador %s usou Grito (E)", player.Name))
	_killerService:performGrito(player)
end

-- ==========================================
-- UTILITÁRIOS
-- ==========================================

-- Verifica se uma ação é específica do Caçador
-- @param action — Tipo de ação (string)
-- @return true se for ação de Caçador
function KillerEvents:_isKillerAction(action: string): boolean
	return action == PlayerActionEvent.ACTIONS.KILLER_M1
		or action == PlayerActionEvent.ACTIONS.ABILITY_1
		or action == PlayerActionEvent.ACTIONS.ABILITY_2
		or action == PlayerActionEvent.ACTIONS.ABILITY_3
end

-- Rate limiting: verifica se o jogador pode enviar uma ação agora
-- @param player — O jogador
-- @return true se pode prosseguir
function KillerEvents:_checkRateLimit(player: Player): boolean
	local now = os.clock()
	local last = _lastActionTime[player.UserId] or 0

	if now - last < RATE_LIMIT then
		-- Descarta silenciosamente (não pune na primeira violação)
		return false
	end

	_lastActionTime[player.UserId] = now
	return true
end

-- Obtém a direção para onde o jogador está olhando
-- @param player — O jogador
-- @return Vector3 normalizado ou nil se não for possível determinar
function KillerEvents:_getPlayerLookDirection(player: Player): Vector3?
	if not _matchService then return nil end

	local state = _matchService:getPlayerState(player)
	if not state or not state.character then return nil end

	-- Usa o HumanoidRootPart para determinar a direção do olhar
	local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	-- O CFrame.LookVector do RootPart indica para onde o personagem está olhando
	-- (assumindo que AutoRotate está ligado e o personagem olha na direção do movimento)
	-- Em uma implementação mais precisa, usaríamos a câmera do jogador
	return rootPart.CFrame.LookVector
end

-- ==========================================
-- CLEANUP
-- ==========================================

function KillerEvents:Destroy()
	table.clear(_lastActionTime)
	_killerService = nil
	_matchService = nil
	print("[CacadaSombria] KillerEvents destruído.")
end

return KillerEvents
