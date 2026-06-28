--!strict
--[[
  KillerService.lua
  Serviço que gerencia toda a lógica do Caçador (O Distorcido).

  Responsável por:
  - Sistema de HP (recebe dano, não morre)
  - Ataque M1 — Tapa corpo a corpo
  - Q: Braço Esticado — puxa Sobreviventes
  - Medidor de Fúria (0–100)
  - R: Rage — transformação temporária
  - E: Grito — lentidão, blur e revelação

  Toda validação é server-side. O cliente apenas envia input.
  Comunicação entre serviços via Signal (pub/sub).

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo por performance)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)

-- ==========================================
-- ATALHO PARA CONSTANTES DO DISTORCIDO
-- ==========================================
local DIST = GameConstants.Killers.Distorcido
local DIST_AB = DIST.Abilities

-- ==========================================
-- TIPO: KillerAbility
-- ==========================================
-- Representa uma habilidade do Caçador com seus parâmetros
-- type KillerAbility = {
--     name: string,
--     cooldown: number,
--     windup: number?,
--     recovery: number?,
-- }

-- ==========================================
-- SERVIÇO KILLERSERVICE
-- ==========================================
local KillerService = {}
KillerService.__index = KillerService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
-- Outros serviços podem se conectar a estes sinais para reagir
KillerService.DamageDealt = Signal.new()       -- params: player, target, amount
KillerService.FuryChanged = Signal.new()       -- params: player, currentFury, maxFury
KillerService.RageActivated = Signal.new()     -- params: player
KillerService.RageEnded = Signal.new()         -- params: player
KillerService.GritoUsed = Signal.new()         -- params: player
KillerService.SurvivorPulled = Signal.new()    -- params: killerPlayer, survivorPlayer

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Referências aos RemoteEvents e serviços
local _gameStateEvent: RemoteEvent? = nil
local _uiSyncEvent: RemoteEvent? = nil
local _matchService: any = nil

-- Estado do Rage ativo
-- Dados do Rage por jogador (userId → {endTime, ...})
local _rageStates: {[number]: {endTime: number, connections: {RBXScriptConnection}}} = {}

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
-- @param gameStateEvent — RemoteEvent para estado do jogo
-- @param uiSyncEvent — RemoteEvent para sincronização de HUD
-- @param matchService — Referência ao MatchService
function KillerService.Init(gameStateEvent: RemoteEvent, uiSyncEvent: RemoteEvent, matchService: any)
	_gameStateEvent = gameStateEvent
	_uiSyncEvent = uiSyncEvent
	_matchService = matchService

	print("[CacadaSombria] KillerService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function KillerService.Start()
	-- Conecta ao game loop para atualizar estados do Rage
	RunService.Heartbeat:Connect(function(dt: number)
		KillerService:_updateRageStates(dt)
	end)

	print("[CacadaSombria] KillerService iniciado. Aguardando Caçador...")
end

-- ==========================================
-- SISTEMA DE HP DO CAÇADOR
-- ==========================================

-- Aplica dano ao Caçador
-- O Caçador NUNCA morre — HP para no mínimo 1
-- @param player — O Caçador (Player)
-- @param amount — Quantidade de dano recebido
-- @param sourcePlayer — Quem causou o dano (opcional)
function KillerService:applyDamageToKiller(player: Player, amount: number, sourcePlayer: Player?)
	if not _matchService then
		warn("[CacadaSombria] KillerService: MatchService não disponível")
		return
	end

	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Valida: só Caçador recebe dano por este sistema
	if state.role ~= "Killer" then return end

	-- Valida: dano deve ser positivo
	if amount <= 0 then return end

	-- Aplica o dano (mínimo 1 HP — Caçador não morre)
	state.hp = math.max(1, state.hp - amount)

	print(string.format(
		"[CacadaSombria] Caçador %s recebeu %.0f de dano. HP: %d/%d",
		player.Name, amount, state.hp, state.maxHp
	))

	-- Notifica o cliente sobre o HP atualizado
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			player,
			GameStateEvent.MESSAGES.HP_UPDATE,
			state.hp,
			state.maxHp
		)
	end

	-- Ganha Fúria ao receber dano
	KillerService:addFury(player, DIST_AB.Fury_Gain_Receiving_Damage)
end

-- ==========================================
-- ATAQUE M1 — TAPA (CORPO A CORPO)
-- ==========================================

-- Executa o ataque M1 do Caçador
-- Valida range, cooldown, windup e recovery
-- @param player — O Caçador
-- @param aimDirection — Direção do mouse/olhar (Vector3)
function KillerService:performM1(player: Player, aimDirection: Vector3)
	if not _matchService then return end

	local state = _matchService:getPlayerState(player)
	if not state or state.role ~= "Killer" then return end

	-- ==========================
	-- VALIDAÇÕES
	-- ==========================

	-- Verifica se o jogador está vivo e não está atordoado
	if not state.isAlive then return end

	-- Verifica cooldown do M1
	if not KillerService:_canUseAbility(state, "M1") then
		print(string.format("[CacadaSombria] M1 em cooldown para %s", player.Name))
		return
	end

	-- Verifica se o Caçador está carregando alguém (futuro)
	-- if state.isCarrying then return end

	-- Verifica se o character existe
	local character = state.character
	if not character then return end

	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- ==========================
	-- WINDUP (preparação)
	-- ==========================
	-- O Caçador fica momentaneamente sem poder agir durante o windup
	-- Em uma implementação real, isso seria sincronizado com animação
	task.wait(DIST_AB.M1_Windup)

	-- Revalida que o jogador ainda está no jogo após o windup
	state = _matchService:getPlayerState(player)
	if not state or not state.isAlive then return end

	-- ==========================
	-- HIT DETECTION (detecção de acerto)
	-- ==========================
	-- Busca Sobreviventes dentro do alcance do M1
	local targetState, targetPlayer = KillerService:_findSurvivorInRange(
		rootPart.Position,
		aimDirection,
		DIST_AB.M1_Range,
		60  -- Cone de 60° para o M1 (ataque de varredura)
	)

	if targetState and targetPlayer then
		-- Determina o dano baseado no estado de Rage
		local damage = KillerService:_isRageActive(state)
			and DIST_AB.M1_Damage_Rage
			or DIST_AB.M1_Damage

		-- Aplica dano ao Sobrevivente
		_matchService:applyDamage(targetPlayer, damage)

		-- Ganha Fúria por causar dano
		KillerService:addFury(player, DIST_AB.Fury_Gain_Dealing_Damage)

		-- Dispara sinal de dano causado
		KillerService.DamageDealt:Fire(player, targetPlayer, damage)

		print(string.format(
			"[CacadaSombria] M1 acertou %s! Dano: %.0f (Rage: %s)",
			targetPlayer.Name, damage, tostring(KillerService:_isRageActive(state))
		))
	else
		print(string.format("[CacadaSombria] M1 de %s não acertou ninguém", player.Name))
	end

	-- ==========================
	-- RECOVERY (recuperação)
	-- ==========================
	task.wait(DIST_AB.M1_Recovery)

	-- ==========================
	-- INICIAR COOLDOWN
	-- ==========================
	KillerService:_startCooldown(state, "M1", DIST_AB.M1_Cooldown, player)
end

-- ==========================================
-- HABILIDADE Q — BRAÇO ESTICADO (PUXÃO)
-- ==========================================

-- Executa o Braço Esticado — estica o braço e puxa um Sobrevivente
-- @param player — O Caçador
-- @param aimDirection — Direção do mouse/olhar (Vector3)
function KillerService:performBracoEsticado(player: Player, aimDirection: Vector3)
	if not _matchService then return end

	local state = _matchService:getPlayerState(player)
	if not state or state.role ~= "Killer" then return end

	-- ==========================
	-- VALIDAÇÕES
	-- ==========================
	if not state.isAlive then return end

	-- Verifica cooldown
	if not KillerService:_canUseAbility(state, "BracoEsticado") then
		print(string.format("[CacadaSombria] Braço Esticado em cooldown para %s", player.Name))
		return
	end

	-- Verifica se está em Rage? (mantém a habilidade, sem restrição)
	-- if state.isCarrying then return end

	local character = state.character
	if not character then return end

	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- ==========================
	-- INICIAR COOLDOWN (antes do windup para evitar spam)
	-- ==========================
	KillerService:_startCooldown(state, "BracoEsticado", DIST_AB.Braco_Esticado_Cooldown, player)

	-- ==========================
	-- WINDUP (preparação do braço)
	-- ==========================
	task.wait(DIST_AB.Braco_Esticado_Windup)

	-- Revalida estado após windup
	state = _matchService:getPlayerState(player)
	if not state or not state.isAlive then return end

	-- ==========================
	-- DETECÇÃO DE ACERTO — LINHA (raycast de 40 studs, 2 studs de largura)
	-- ==========================
	-- Verifica Sobreviventes dentro de um cone estreito à frente do Caçador
	local targetState, targetPlayer = KillerService:_findSurvivorInNarrowCone(
		rootPart.Position,
		aimDirection,
		DIST_AB.Braco_Esticado_Range,   -- 40 studs
		DIST_AB.Braco_Esticado_Width,    -- 2 studs de tolerância lateral
		player                           -- exclui o próprio Caçador
	)

	if targetState and targetPlayer then
		-- Puxa o Sobrevivente para perto do Caçador
		local targetChar = targetState.character
		if targetChar then
			local targetRoot: BasePart? = targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot and rootPart then
				-- Calcula a posição de destino (à frente do Caçador)
				local pullPos = rootPart.Position + (aimDirection * DIST_AB.Braco_Esticado_Pull_Distance)
				targetRoot.CFrame = CFrame.new(pullPos)

				-- Atordoa o Sobrevivente brevemente (0.5s)
				KillerService:_applyStun(targetState, DIST_AB.Braco_Esticado_Stun)

				-- Ganha Fúria por acertar o Braço Esticado (metade do dano, já que não causa dano direto)
				KillerService:addFury(player, DIST_AB.Fury_Gain_Dealing_Damage)

				-- Dispara sinal de puxão
				KillerService.SurvivorPulled:Fire(player, targetPlayer)

				print(string.format(
					"[CacadaSombria] Braço Esticado acertou %s! Puxado para perto do Caçador.",
					targetPlayer.Name
				))
			end
		end
	else
		print(string.format("[CacadaSombria] Braço Esticado de %s não acertou ninguém", player.Name))
	end
end

-- ==========================================
-- SISTEMA DE FÚRIA (FURY METER)
-- ==========================================

-- Adiciona Fúria ao medidor do Caçador
-- @param player — O Caçador
-- @param amount — Quantidade de Fúria a adicionar
function KillerService:addFury(player: Player, amount: number)
	if not _matchService then return end

	local state = _matchService:getPlayerState(player)
	if not state or state.role ~= "Killer" then return end

	-- Não ganha Fúria se já está em Rage
	if state.isRageActive then return end

	-- Adiciona Fúria (limitada ao máximo)
	local oldFury = state.fury or 0
	state.fury = math.min((state.fury or 0) + amount, DIST_AB.Fury_Max)

	print(string.format(
		"[CacadaSombria] Fúria de %s: %d → %d (+%d)",
		player.Name, oldFury, state.fury, amount
	))

	-- Notifica o cliente sobre a Fúria atualizada
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			player,
			GameStateEvent.MESSAGES.FURY_UPDATE,
			state.fury,
			DIST_AB.Fury_Max
		)
	end

	-- Sincroniza via UISyncEvent também (redundância para HUD específica)
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.FURY_UPDATE,
			state.fury,
			DIST_AB.Fury_Max
		)
	end

	-- Dispara sinal
	KillerService.FuryChanged:Fire(player, state.fury, DIST_AB.Fury_Max)

	-- Verifica se a Fúria atingiu o máximo
	if state.fury >= DIST_AB.Fury_Max and not state.isRageActive then
		print(string.format("[CacadaSombria] FÚRIA MÁXIMA! %s pode ativar o Rage!", player.Name))
		-- Notifica o cliente que o Rage está disponível
		if _uiSyncEvent then
			UISyncEvent.sendToClient(
				_uiSyncEvent,
				player,
				UISyncEvent.MESSAGES.FURY_UPDATE,
				state.fury,
				DIST_AB.Fury_Max
			)
		end
	end
end

-- Notifica que um resgate ocorreu próximo ao Caçador
-- Chamado pelo CaptureService (Épico E6) quando um Sobrevivente é resgatado da jaula
-- @param rescuePosition — Posição onde o resgate ocorreu (Vector3)
function KillerService:onRescueNearby(rescuePosition: Vector3)
	if not _matchService then return end

	-- Busca o Caçador
	local killerPlayers = _matchService:getPlayersByRole("Killer")
	for _, killer in killerPlayers do
		local state = _matchService:getPlayerState(killer)
		if state and state.isAlive and state.character then
			local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local dist = MathUtil.distance(rootPart.Position, rescuePosition)
				if dist <= DIST_AB.Fury_Rescue_Range then
					-- Caçador está dentro do alcance, ganha Fúria por resgate próximo
					KillerService:addFury(killer, DIST_AB.Fury_Gain_Rescue_Nearby)
					print(string.format(
						"[CacadaSombria] Resgate a %.1f studs de %s! +%d Fúria",
						dist, killer.Name, DIST_AB.Fury_Gain_Rescue_Nearby
					))
				end
			end
		end
	end
end

-- ==========================================
-- HABILIDADE R — RAGE (TRANSFORMAÇÃO)
-- ==========================================

-- Ativa o modo Rage do Caçador
-- Só pode ser ativado com Fúria em 100
-- @param player — O Caçador
function KillerService:activateRage(player: Player)
	if not _matchService then return end

	local state = _matchService:getPlayerState(player)
	if not state or state.role ~= "Killer" then return end

	-- ==========================
	-- VALIDAÇÕES
	-- ==========================
	if not state.isAlive then return end

	-- Verifica se a Fúria está cheia
	if (state.fury or 0) < DIST_AB.Fury_Max then
		print(string.format(
			"[CacadaSombria] %s tentou ativar Rage com Fúria insuficiente (%d/%d)",
			player.Name, state.fury or 0, DIST_AB.Fury_Max
		))
		return
	end

	-- Verifica se já está em Rage
	if state.isRageActive then return end

	-- ==========================
	-- ATIVAR RAGE
	-- ==========================
	state.isRageActive = true

	-- Reseta a Fúria (consumida ao ativar Rage)
	state.fury = 0

	-- Registra o estado do Rage para controle de duração
	local userId = player.UserId
	local rageEndTime = os.clock() + DIST_AB.Rage_Duration

	-- Cria conexões para cleanup
	local connections: {RBXScriptConnection} = {}
	_rageStates[userId] = {endTime = rageEndTime, connections = connections}

	-- Aumenta a velocidade do Caçador
	if state.humanoid then
		state.humanoid.WalkSpeed = DIST_AB.Rage_Speed  -- 28 studs/s
	end

	-- TODO: Pausar o timer da partida
	-- Isso será integrado com MatchService no futuro
	-- MatchService:pauseMatchTimer()

	-- TODO: Mudança visual (criatura preta, alta e distorcida)
	-- Será implementado no Épico E4/E8

	-- ==========================
	-- NOTIFICAÇÕES
	-- ==========================

	-- Notifica o cliente sobre Fúria zerada
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			player,
			GameStateEvent.MESSAGES.FURY_UPDATE,
			state.fury,
			DIST_AB.Fury_Max
		)
	end

	-- Notifica início do Rage
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.RAGE_START,
			DIST_AB.Rage_Duration
		)
	end

	-- Dispara sinal
	KillerService.RageActivated:Fire(player)

	print(string.format(
		"[CacadaSombria] %s ATIVOU O RAGE! Duração: %ds, Velocidade: %d",
		player.Name, DIST_AB.Rage_Duration, DIST_AB.Rage_Speed
	))
end

-- Verifica e finaliza estados de Rage expirados
-- Chamado a cada frame pelo Heartbeat
function KillerService:_updateRageStates(dt: number)
	local now = os.clock()

	for userId, rageData in _rageStates do
		if now >= rageData.endTime then
			-- Rage expirou
			local player = Players:GetPlayerByUserId(userId)
			if player then
				KillerService:_endRage(player)
			end
		end
	end
end

-- Finaliza o Rage de um Caçador
-- @param player — O Caçador
function KillerService:_endRage(player: Player)
	if not _matchService then return end

	local state = _matchService:getPlayerState(player)
	if not state then return end

	-- Só processa se realmente estiver em Rage
	if not state.isRageActive then return end

	state.isRageActive = false

	-- Restaura a velocidade normal
	if state.humanoid then
		state.humanoid.WalkSpeed = DIST.Speed  -- 26 studs/s
	end

	-- TODO: Restaurar timer da partida
	-- MatchService:resumeMatchTimer()

	-- TODO: Reverter mudanças visuais

	-- Limpa o estado do Rage
	local rageData = _rageStates[player.UserId]
	if rageData then
		for _, conn in rageData.connections do
			conn:Disconnect()
		end
		_rageStates[player.UserId] = nil
	end

	-- Notifica o cliente
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.RAGE_END
		)
	end

	-- Dispara sinal
	KillerService.RageEnded:Fire(player)

	print(string.format("[CacadaSombria] Rage de %s terminou.", player.Name))
end

-- ==========================================
-- HABILIDADE E — GRITO (SCREAM)
-- ==========================================

-- Executa o Grito do Caçador
-- Efeitos:
--   - 60 studs: 40% lentidão + blur por 3s em Sobreviventes
--   - 100 studs: revela todos os Sobreviventes por 4s (através de paredes)
-- @param player — O Caçador
function KillerService:performGrito(player: Player)
	if not _matchService then return end

	local state = _matchService:getPlayerState(player)
	if not state or state.role ~= "Killer" then return end

	-- ==========================
	-- VALIDAÇÕES
	-- ==========================
	if not state.isAlive then return end

	-- Verifica cooldown
	if not KillerService:_canUseAbility(state, "Grito") then
		print(string.format("[CacadaSombria] Grito em cooldown para %s", player.Name))
		return
	end

	local character = state.character
	if not character then return end

	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- ==========================
	-- INICIAR COOLDOWN (antes do windup)
	-- ==========================
	KillerService:_startCooldown(state, "Grito", DIST_AB.Grito_Cooldown, player)

	-- ==========================
	-- WINDUP
	-- ==========================
	task.wait(DIST_AB.Grito_Windup)

	-- Revalida estado após windup
	state = _matchService:getPlayerState(player)
	if not state or not state.isAlive then return end
	if not state.character then return end

	rootPart = state.character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local killerPos = rootPart.Position

	print(string.format("[CacadaSombria] %s usou GRITO!", player.Name))

	-- ==========================
	-- EFEITO 1: LENTIDÃO + BLUR (60 studs)
	-- ==========================
	local survivors = _matchService:getPlayersByRole("Survivor")
	for _, surv in survivors do
		local survState = _matchService:getPlayerState(surv)
		if survState and survState.isAlive and survState.character then
			local survRoot: BasePart? = survState.character:FindFirstChild("HumanoidRootPart")
			if survRoot then
				local dist = MathUtil.distance(killerPos, survRoot.Position)

				if dist <= DIST_AB.Grito_Slow_Range then
					-- Dentro do alcance de lentidão (60 studs)
					-- Aplica lentidão de 40%
					KillerService:_applySlow(survState, DIST_AB.Grito_Slow_Percent, DIST_AB.Grito_Slow_Duration)

					-- Notifica o Sobrevivente sobre o efeito de blur
					if _uiSyncEvent then
						UISyncEvent.sendToClient(
							_uiSyncEvent,
							surv,
							UISyncEvent.MESSAGES.GRITO_SLOW_START,
							DIST_AB.Grito_Slow_Percent,
							DIST_AB.Grito_Slow_Duration
						)
					end

					print(string.format(
						"[CacadaSombria] Grito afetou %s (lentidão %.0f%%, %.0fs) — distância: %.1f studs",
						surv.Name, DIST_AB.Grito_Slow_Percent * 100, DIST_AB.Grito_Slow_Duration, dist
					))
				end

				if dist <= DIST_AB.Grito_Reveal_Range then
					-- Dentro do alcance de revelação (100 studs)
					-- Revela o Sobrevivente por 4s
					if _uiSyncEvent then
						UISyncEvent.sendToClient(
							_uiSyncEvent,
							surv,
							UISyncEvent.MESSAGES.GRITO_REVEAL_START,
							DIST_AB.Grito_Reveal_Duration
						)
					end

					-- Agenda o fim da revelação
					task.delay(DIST_AB.Grito_Reveal_Duration, function()
						if _uiSyncEvent then
							UISyncEvent.sendToClient(
								_uiSyncEvent,
								surv,
								UISyncEvent.MESSAGES.GRITO_REVEAL_END
							)
						end
					end)

					print(string.format(
						"[CacadaSombria] Grito revelou %s por %.0fs — distância: %.1f studs",
						surv.Name, DIST_AB.Grito_Reveal_Duration, dist
					))
				end
			end
		end
	end

	-- ==========================
	-- NOTIFICAÇÕES
	-- ==========================

	-- Dispara sinal
	KillerService.GritoUsed:Fire(player)

	print(string.format("[CacadaSombria] Grito de %s executado com sucesso!", player.Name))
end

-- ==========================================
-- UTILITÁRIOS DE DETECÇÃO DE ALVO
-- ==========================================

-- Encontra um Sobrevivente dentro do alcance em um cone à frente do Caçador
-- @param origin — Posição de origem (Vector3)
-- @param lookDirection — Direção do olhar (Vector3 normalizado)
-- @param maxRange — Alcance máximo em studs
-- @param fovAngle — Ângulo do cone de visão em graus
-- @return targetState, targetPlayer — Estado e jogador alvo, ou nil se não encontrado
function KillerService:_findSurvivorInRange(
	origin: Vector3,
	lookDirection: Vector3,
	maxRange: number,
	fovAngle: number
): (any?, Player?)
	if not _matchService then return nil, nil end

	local survivors = _matchService:getPlayersByRole("Survivor")
	local closestDist = math.huge
	local closestState: any = nil
	local closestPlayer: Player? = nil

	for _, surv in survivors do
		local survState = _matchService:getPlayerState(surv)
		if survState and survState.isAlive and survState.character then
			local survRoot: BasePart? = survState.character:FindFirstChild("HumanoidRootPart")
			if survRoot then
				local dist = MathUtil.distance(origin, survRoot.Position)

				-- Verifica alcance
				if dist <= maxRange then
					-- Verifica se está dentro do cone de visão
					if MathUtil.isInVisionCone(origin, lookDirection, survRoot.Position, fovAngle, maxRange) then
						-- Pega o Sobrevivente mais próximo
						if dist < closestDist then
							closestDist = dist
							closestState = survState
							closestPlayer = surv
						end
					end
				end
			end
		end
	end

	return closestState, closestPlayer
end

-- Encontra um Sobrevivente em um cone estreito (para o Braço Esticado)
-- Similar ao _findSurvivorInRange mas com verificação de largura lateral
-- @param origin — Posição de origem (Vector3)
-- @param lookDirection — Direção do olhar (Vector3 normalizado)
-- @param maxRange — Alcance máximo em studs
-- @param width — Tolerância lateral em studs (largura do "braço")
-- @param excludePlayer — Jogador a excluir (o próprio Caçador)
-- @return targetState, targetPlayer — Estado e jogador alvo, ou nil
function KillerService:_findSurvivorInNarrowCone(
	origin: Vector3,
	lookDirection: Vector3,
	maxRange: number,
	width: number,
	excludePlayer: Player
): (any?, Player?)
	if not _matchService then return nil, nil end

	local survivors = _matchService:getPlayersByRole("Survivor")
	local closestDist = math.huge
	local closestState: any = nil
	local closestPlayer: Player? = nil

	for _, surv in survivors do
		if surv.UserId == excludePlayer.UserId then continue end

		local survState = _matchService:getPlayerState(surv)
		if survState and survState.isAlive and survState.character then
			local survRoot: BasePart? = survState.character:FindFirstChild("HumanoidRootPart")
			if survRoot then
				local toTarget = survRoot.Position - origin
				local dist = toTarget.Magnitude

				if dist <= maxRange then
					-- Projeta o vetor até o alvo na direção do olhar
					local projection = toTarget:Dot(lookDirection)

					-- O alvo deve estar à frente (projeção positiva)
					if projection > 0 then
						-- Calcula a distância lateral (perpendicular)
						local projectedPoint = origin + (lookDirection * projection)
						local lateralDist = (survRoot.Position - projectedPoint).Magnitude

						-- Verifica se está dentro da largura do braço
						if lateralDist <= width then
							if dist < closestDist then
								closestDist = dist
								closestState = survState
								closestPlayer = surv
							end
						end
					end
				end
			end
		end
	end

	return closestState, closestPlayer
end

-- ==========================================
-- SISTEMA DE EFEITOS DE STATUS
-- ==========================================

-- Aplica atordoamento (stun) a um jogador
-- Impede ações e movimento por `duration` segundos
-- @param state — PlayerState do alvo
-- @param duration — Duração em segundos
function KillerService:_applyStun(state: any, duration: number)
	-- Guarda a velocidade original
	local originalSpeed: number = 0
	if state.humanoid then
		originalSpeed = state.humanoid.WalkSpeed
		state.humanoid.WalkSpeed = 0  -- Impede movimento
	end

	-- Marca como atordoado (para validação de ações)
	state.isStunned = true

	-- Agenda a remoção do stun
	task.delay(duration, function()
		if state and state.humanoid and state.humanoid.Parent then
			state.isStunned = false
			-- Restaura a velocidade apropriada
			if state.isRageActive then
				state.humanoid.WalkSpeed = DIST_AB.Rage_Speed
			elseif state.role == "Killer" then
				state.humanoid.WalkSpeed = DIST.Speed
			elseif state.isSprinting then
				state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed + GameConstants.Survivors.Base.Stamina_Speed_Bonus
			else
				state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
			end
		end
	end)
end

-- Aplica lentidão (slow) a um jogador
-- @param state — PlayerState do alvo
-- @param slowPercent — Porcentagem de redução (0.4 = 40%)
-- @param duration — Duração em segundos
function KillerService:_applySlow(state: any, slowPercent: number, duration: number)
	if not state.humanoid then return end

	local originalSpeed = state.humanoid.WalkSpeed
	local slowedSpeed = originalSpeed * (1 - slowPercent)

	-- Aplica a lentidão
	state.humanoid.WalkSpeed = slowedSpeed

	-- Agenda a restauração da velocidade
	task.delay(duration, function()
		if state and state.humanoid and state.humanoid.Parent then
			-- Restaura a velocidade apropriada
			if state.isRageActive then
				state.humanoid.WalkSpeed = DIST_AB.Rage_Speed
			elseif state.role == "Killer" then
				state.humanoid.WalkSpeed = DIST.Speed
			elseif state.isSprinting then
				state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed + GameConstants.Survivors.Base.Stamina_Speed_Bonus
			else
				state.humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed
			end
		end
	end)

	print(string.format(
		"[CacadaSombria] Lentidão aplicada: %.0f%% por %.0fs (velocidade: %.1f → %.1f)",
		slowPercent * 100, duration, originalSpeed, slowedSpeed
	))
end

-- ==========================================
-- SISTEMA DE COOLDOWNS
-- ==========================================

-- Verifica se uma habilidade pode ser usada (cooldown expirou)
-- @param state — PlayerState do Caçador
-- @param abilityName — Nome da habilidade
-- @return true se pode usar
function KillerService:_canUseAbility(state: any, abilityName: string): boolean
	if not state.cooldowns then return true end
	local cooldownEnd = state.cooldowns[abilityName]
	if not cooldownEnd then return true end
	return os.clock() >= cooldownEnd
end

-- Inicia o cooldown de uma habilidade
-- @param state — PlayerState do Caçador
-- @param abilityName — Nome da habilidade
-- @param seconds — Duração do cooldown
-- @param player — O jogador (para notificação de UI)
function KillerService:_startCooldown(state: any, abilityName: string, seconds: number, player: Player)
	state.cooldowns[abilityName] = os.clock() + seconds

	-- Notifica o cliente sobre o cooldown iniciado
	if _uiSyncEvent then
		UISyncEvent.sendToClient(
			_uiSyncEvent,
			player,
			UISyncEvent.MESSAGES.COOLDOWN_START,
			abilityName,
			seconds
		)
	end
end

-- Retorna o tempo restante de cooldown de uma habilidade
-- @param state — PlayerState do Caçador
-- @param abilityName — Nome da habilidade
-- @return segundos restantes (0 se não estiver em cooldown)
function KillerService:getCooldownRemaining(state: any, abilityName: string): number
	if not state.cooldowns then return 0 end
	local cooldownEnd = state.cooldowns[abilityName]
	if not cooldownEnd then return 0 end
	local remaining = cooldownEnd - os.clock()
	return math.max(0, remaining)
end

-- ==========================================
-- UTILITÁRIOS DE ESTADO DO RAGE
-- ==========================================

-- Verifica se o Caçador está em estado de Rage
-- @param state — PlayerState do Caçador
-- @return true se estiver em Rage
function KillerService:_isRageActive(state: any): boolean
	return state.isRageActive == true
end

-- ==========================================
-- CLEANUP
-- ==========================================

function KillerService:Destroy()
	-- Limpa todos os estados de Rage
	for userId, rageData in _rageStates do
		for _, conn in rageData.connections do
			conn:Disconnect()
		end
	end
	table.clear(_rageStates)

	-- Destroi sinais
	KillerService.DamageDealt:Destroy()
	KillerService.FuryChanged:Destroy()
	KillerService.RageActivated:Destroy()
	KillerService.RageEnded:Destroy()
	KillerService.GritoUsed:Destroy()
	KillerService.SurvivorPulled:Destroy()

	print("[CacadaSombria] KillerService destruído.")
end

return KillerService
