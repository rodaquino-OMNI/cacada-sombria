--!strict
--[[
	SurvivorService.lua
	Serviço que gerencia todas as mecânicas dos Sobreviventes.
	
	Responsável por:
	- Habilidades das 5 classes de Sobrevivente (Soldado, Sackboy, Robô, Enfermeira, Campeão)
	- Gerenciamento de cooldowns server-authoritative
	- Aplicação de dano e efeitos de controle ao Caçador
	- Modos LMS (Last Man Standing) — bônus por vínculo narrativo
	- Validação server-side de alcance, estado e cooldown de cada habilidade

	Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)
local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- ==========================================
-- CONSTANTES DE COOLDOWN (centralizadas em GameConstants.Survivors[name].Abilities)
-- ==========================================

-- ==========================================
-- CONSTANTES DE EFEITOS DE CONTROLE
-- ==========================================

-- Efeitos que podem ser aplicados ao Caçador
-- Cada efeito é armazenado como {type, endTime, value}

local EFFECT_SILENCE = "Silence"        -- impede uso de habilidades
local EFFECT_SLOW = "Slow"              -- reduz velocidade (multiplicador)
local EFFECT_STUN = "Stun"              -- impede movimento e ações
local EFFECT_BLUR = "Blur"              -- efeito visual de tela borrada
local EFFECT_GROUNDED = "Grounded"      -- impede movimento (sem atordoar)
local EFFECT_INVINCIBLE = "Invincible"  -- imune a dano
local EFFECT_REVEAL = "Reveal"          -- visível através de paredes

-- ==========================================
-- SERVIÇO SURVIVORSERVICE
-- ==========================================
local SurvivorService = {}
SurvivorService.__index = SurvivorService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
-- Outros serviços podem se conectar a estes sinais
SurvivorService.SurvivorUsedAbility = Signal.new()
SurvivorService.SurvivorHealed = Signal.new()
SurvivorService.SurvivorShielded = Signal.new()

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Tabela de extensão de estado por Sobrevivente
-- Armazena dados específicos de habilidades que não estão no MatchService
-- Chave: player.UserId
-- Valor: { isUsingBazooka, bazookaTimer, chargeLevel, isCharging, isBlocking,
--          sacrificeState, comboHits, comboLastHitTime, isShielded,
--          lastDashAttackTime, etc. }
local _survivorState: {[number]: any} = {}

-- Referências injetadas durante Init
local _gameStateEvent: RemoteEvent? = nil
local _playerActionEvent: RemoteEvent? = nil
local _uISyncEvent: RemoteEvent? = nil
local _matchService: any = nil

-- ==========================================
-- FUNÇÕES AUXILIARES — POSIÇÃO E ALCANCE
-- ==========================================

-- Obtém a posição do HumanoidRootPart de um jogador
local function getPlayerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then return nil end
	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	return rootPart.Position
end

-- Obtém a direção para onde o jogador está olhando (lookVector)
local function getPlayerLookVector(player: Player): Vector3?
	local character = player.Character
	if not character then return nil end
	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	return rootPart.CFrame.LookVector
end

-- Obtém o Humanoid de um jogador
local function getPlayerHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("Humanoid")
end

-- ==========================================
-- FUNÇÕES AUXILIARES — COOLDOWNS
-- ==========================================

-- Verifica se uma habilidade está fora de cooldown
local function canUseAbility(state: any, abilityName: string): boolean
	local cooldownEnd = state.cooldowns[abilityName] as number?
	if not cooldownEnd then return true end
	return os.clock() >= cooldownEnd
end

-- Inicia o cooldown de uma habilidade e notifica o cliente
local function startCooldown(state: any, abilityName: string, durationSeconds: number)
	state.cooldowns[abilityName] = os.clock() + durationSeconds
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			UISyncEvent.MESSAGES.COOLDOWN_START,
			abilityName,
			durationSeconds
		)
	end
	print(string.format(
		"[CacadaSombria] Cooldown iniciado: %s → %s (%.1fs)",
		state.player.Name, abilityName, durationSeconds
	))
end

-- ==========================================
-- FUNÇÕES AUXILIARES — EFEITOS NO CAÇADOR
-- ==========================================

-- Aplica um efeito de controle ao Caçador
local function applyEffectToKiller(killerState: any, effectType: string, duration: number, value: number?)
	-- Garante que a tabela de efeitos existe
	if not killerState.activeEffects then
		killerState.activeEffects = {}
	end

	-- Remove efeito existente do mesmo tipo (substitui)
	for i, eff in ipairs(killerState.activeEffects) do
		if eff.type == effectType then
			table.remove(killerState.activeEffects, i)
			break
		end
	end

	-- Adiciona o novo efeito
	local effect = {
		type = effectType,
		endTime = os.clock() + duration,
		value = value,
	}
	table.insert(killerState.activeEffects, effect)

	print(string.format(
		"[CacadaSombria] Efeito aplicado ao Caçador: %s (%ss)",
		effectType, duration
	))
end

-- Verifica se o Caçador está sob um efeito específico
local function hasKillerEffect(killerState: any, effectType: string): boolean
	if not killerState.activeEffects then return false end
	local now = os.clock()
	for _, eff in killerState.activeEffects do
		if eff.type == effectType and eff.endTime > now then
			return true
		end
	end
	return false
end

-- Aplica dano ao Caçador (via MatchService)
local function damageKiller(killerPlayer: Player, amount: number)
	if not _matchService then
		warn("[CacadaSombria] MatchService não disponível para aplicar dano ao Caçador")
		return
	end
	_matchService:applyDamage(killerPlayer, amount)
end

-- ==========================================
-- FUNÇÕES AUXILIARES — LMS (VÍNCULOS)
-- ==========================================

-- Verifica se há bônus de LMS ativo e retorna os modificadores
-- LMS = "Last Man Standing" — bônus narrativos quando Sobrevivente enfrenta
-- o Caçador vinculado à sua história
-- @return speedBonus, damageMultiplier, staminaBonus
local function getLMSBonuses(survivorClass: string?, killerClass: string?): (number, number, number)
	if not survivorClass or not killerClass then
		return 0, 1.0, 0
	end

	-- Soldado vs Soldado Killer: +2 speed, +30% dano Bazuca
	if survivorClass == "Soldado" and killerClass == "Soldado" then
		return 2, 1.3, 0
	end

	-- Sackboy vs Boneco de Pano: +2 speed, +20 stamina
	if survivorClass == "Sackboy" and killerClass == "BonecoDePano" then
		return 2, 1.0, 20
	end

	return 0, 1.0, 0
end

-- Aplica bônus de LMS a um Sobrevivente (velocidade e stamina extra)
local function applyLMSBonuses(state: any, killerClass: string?)
	if not state.className then return end
	local speedBonus, _, staminaBonus = getLMSBonuses(state.className, killerClass)

	if speedBonus > 0 or staminaBonus > 0 then
		print(string.format(
			"[CacadaSombria] Bônus LMS ativado: %s vs %s (+%d speed, +%d stamina)",
			state.className, killerClass or "?", speedBonus, staminaBonus
		))

		-- Aplica bônus de velocidade
		if speedBonus > 0 and state.humanoid then
			state.humanoid.WalkSpeed = (GameConstants.Survivors[state.className].Speed or GameConstants.Survivors.Base.Speed) + speedBonus
			if state.isSprinting then
				state.humanoid.WalkSpeed += GameConstants.Survivors.Base.Stamina_Speed_Bonus
			end
		end

		-- Aplica bônus de stamina
		if staminaBonus > 0 then
			local staminaMax = GameConstants.Game.Stamina.Stamina_Max
			state.stamina = math.min(staminaMax, (state.stamina or staminaMax) + staminaBonus)
			state.maxStamina = staminaMax + staminaBonus
		end
	end
end

-- ==========================================
-- FUNÇÕES AUXILIARES — VALIDAÇÃO DE AÇÃO
-- ==========================================

-- Validação básica: o Sobrevivente pode usar habilidades?
local function validateSurvivorAction(state: any, abilityName: string): boolean
	-- 1. Está vivo?
	if not state.isAlive then
		print(string.format("[CacadaSombria] %s tentou usar %s mas está morto/derrubado",
			state.player.Name, abilityName))
		return false
	end

	-- 2. Está em jaula?
	if state.isInCage then
		return false
	end

	-- 3. Está escondido?
	if state.isHiding then
		return false
	end

	-- 4. Tem cooldown?
	if not canUseAbility(state, abilityName) then
		print(string.format("[CacadaSombria] %s tentou usar %s em cooldown",
			state.player.Name, abilityName))
		return false
	end

	-- 5. É um Sobrevivente?
	if state.role ~= "Survivor" then
		return false
	end

	return true
end

-- Encontra o Caçador (Killer) ativo na partida
local function getKillerState(): any?
	if not _matchService then return nil end
	local killers = _matchService:getPlayersByRole("Killer")
	if not killers or #killers == 0 then return nil end
	local killerPlayer = killers[1]
	return _matchService:getPlayerState(killerPlayer)
end

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init (síncrono, sem yield)
function SurvivorService.Init(
	gameStateEvent: RemoteEvent,
	playerActionEvent: RemoteEvent,
	uiSyncEvent: RemoteEvent,
	matchService: any
)
	_gameStateEvent = gameStateEvent
	_playerActionEvent = playerActionEvent
	_uISyncEvent = uiSyncEvent
	_matchService = matchService

	print("[CacadaSombria] SurvivorService inicializado.")
end

-- Chamado pelo GameManager durante a fase Start (pode yield)
function SurvivorService.Start()
	print("[CacadaSombria] SurvivorService iniciado. Aguardando ações de habilidades...")

	-- Conecta ao sinal de início de partida para aplicar bônus LMS
	if _matchService and _matchService.MatchStarted then
		_matchService.MatchStarted:Connect(function()
			SurvivorService:_applyLMSBonusesToAll()
		end)
	end
end

-- Aplica bônus de LMS a todos os Sobreviventes ativos na partida
function SurvivorService:_applyLMSBonusesToAll()
	if not _matchService then return end
	local survivors = _matchService:getPlayersByRole("Survivor")
	local killers = _matchService:getPlayersByRole("Killer")
	local killerClass: string? = nil
	if killers and #killers > 0 then
		local killerState = _matchService:getPlayerState(killers[1])
		if killerState then
			killerClass = killerState.className
		end
	end

	for _, survivor in survivors do
		local state = _matchService:getPlayerState(survivor)
		if state then
			applyLMSBonuses(state, killerClass)
		end
	end
	print(string.format("[CacadaSombria] Bônus LMS verificados para %d Sobreviventes (Killer: %s)",
		#(survivors or {}), killerClass or "?"))
end

-- ==========================================
-- HANDLER PRINCIPAL DE AÇÕES
-- ==========================================

-- Roteador de ações de habilidade vindas do PlayerActionEvent
-- Chamado externamente (pelo MatchService ou GameManager)
-- @param player — O jogador que enviou a ação
-- @param action — String da ação (Ability1, Ability2, Ability3)
-- @param ... — Parâmetros adicionais
function SurvivorService:handleAbilityAction(player: Player, action: string, ...: any)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	if state.role ~= "Survivor" then return end

	local className = state.className

	-- Roteia para a classe correta
	if className == "Soldado" then
		if action == "Ability1" then
			self:_handleSoldadoDash(state)
		elseif action == "Ability2" then
			self:_handleSoldadoBazooka(state)
		elseif action == "Ability3" then
			-- Ability3 durante Bazooka = disparar
			local survState = _survivorState[state.userId]
			if survState and survState.isUsingBazooka then
				self:_fireBazooka(state)
			end
		end
	elseif className == "Sackboy" then
		if action == "Ability1" then
			self:_handleSackboyTintaStart(state)
		elseif action == "Ability2" then
			self:_handleSackboySurto(state)
		elseif action == "Ability3" then
			self:_handleSackboyTintaFire(state)
		end
	elseif className == "Robo" then
		if action == "Ability1" then
			self:_handleRoboAgarrar(state)
		elseif action == "Ability2" then
			self:_handleRoboBlock(state)
		elseif action == "Ability3" then
			self:_handleRoboSacrificio(state)
		end
	elseif className == "Enfermeira" then
		if action == "Ability1" then
			self:_handleEnfermeiraCurativo(state, ...)
		elseif action == "Ability2" then
			self:_handleEnfermeiraAdrenalina(state, ...)
		end
	elseif className == "Campeao" then
		if action == "Ability1" then
			self:_handleCampeaoAgarrao(state)
		elseif action == "Ability2" then
			self:_handleCampeaoSequencia(state)
		end
	end
end

-- ==========================================
-- ATUALIZAÇÃO POR FRAME (efeitos contínuos)
-- ==========================================

-- Atualização chamada a cada frame (via Heartbeat no GameManager)
-- Processa efeitos ativos e limpa efeitos expirados
function SurvivorService:update(dt: number)
	local now = os.clock()

	-- Itera sobre todos os Sobreviventes
	for userId, survState in _survivorState do
		-- Obtém o playerState correspondente
		local player = Players:GetPlayerByUserId(userId)
		local state = player and _matchService:getPlayerState(player)

		-- Verifica timer da Bazuca (Soldado)
		if survState.isUsingBazooka then
			if survState.bazookaTimer and now >= survState.bazookaTimer then
				-- Tempo da Bazuca expirou — cancela automaticamente
				self:_cancelBazookaForState(state, survState)
			end
		end

		-- Verifica estado de sacrifício (Robô)
		if survState.sacrificeState == "channelling" then
			if survState.sacrificeTimer and now >= survState.sacrificeTimer then
				-- Windup terminou, inicia fase de velocidade
				self:_onSacrificeWindupComplete(survState)
			end
		elseif survState.sacrificeState == "speedBoost" then
			if survState.sacrificeTimer and now >= survState.sacrificeTimer then
				-- Fase de velocidade terminou, EXPLODE
				self:_onSacrificeExplode(survState)
			end
		end

		-- Verifica janela de Block (Robô)
		if survState.isBlocking and survState.blockTimer and now >= survState.blockTimer then
			survState.isBlocking = false
			print("[CacadaSombria] Block do Robô expirou")
		end

		-- Verifica janela de sequência de socos (Campeão)
		if survState.comboHits and survState.comboHits > 0 then
			if survState.comboLastHitTime and
				now - survState.comboLastHitTime > GameConstants.Survivors.Campeao.Abilities.Sequencia_Hit_Window then
				survState.comboHits = 0
			end
		end
	end

	-- Limpa efeitos expirados do Caçador
	local killerState = getKillerState()
	if killerState and killerState.activeEffects then
		local i = 1
		while i <= #killerState.activeEffects do
			local eff = killerState.activeEffects[i]
			if eff.endTime <= now then
				-- Efeito expirou — restaura estado do Caçador
				self:_onKillerEffectExpired(killerState, eff)
				table.remove(killerState.activeEffects, i)
			else
				i += 1
			end
		end
	end
end

-- ==========================================
-- QUANDO UM EFEITO DO CAÇADOR EXPIRA
-- ==========================================

function SurvivorService:_onKillerEffectExpired(killerState: any, effect: any)
	print(string.format("[CacadaSombria] Efeito expirou no Caçador: %s", effect.type))

	if effect.type == EFFECT_SLOW or effect.type == EFFECT_STUN or effect.type == EFFECT_GROUNDED then
		-- Restaura velocidade normal do Caçador
		if killerState.humanoid then
			local baseKillerSpeed = GameConstants.Killers.Distorcido.Speed
			-- Se o Caçador for de outra classe, ajusta aqui
			if killerState.className == "Soldado" then
				baseKillerSpeed = GameConstants.Killers.Soldado.Speed
			elseif killerState.className == "BonecoDePano" then
				baseKillerSpeed = GameConstants.Killers.BonecoDePano.Speed
			elseif killerState.className == "Compasso" then
				baseKillerSpeed = GameConstants.Killers.Compasso.Speed
			end
			killerState.humanoid.WalkSpeed = baseKillerSpeed
		end
	end
end

-- ==========================================
-- CLASSE: SOLDADO (HP 120, Speed 20)
-- ==========================================

-- Habilidade Q: Dash Tático
-- Avança como Compasso. Se atingir o Caçador: empurra 10 studs + silence 3s
function SurvivorService:_handleSoldadoDash(state: any)
	if not validateSurvivorAction(state, "DashTatico") then return end

	-- Obtém posição e direção do Soldado
	local player = state.player
	local pos = getPlayerPosition(player)
	local lookDir = getPlayerLookVector(player)
	if not pos or not lookDir then
		print("[CacadaSombria] Dash Tático: posição/direção inválida")
		return
	end

	print(string.format("[CacadaSombria] %s usou Dash Tático!", player.Name))

	-- Inicia cooldown
	startCooldown(state, "DashTatico", GameConstants.Survivors.Soldado.Abilities.Dash_Cooldown)

	-- Calcula posição final do dash (avança na direção do olhar)
	local dashDistance = GameConstants.Survivors.Soldado.Abilities.Dash_Speed * GameConstants.Survivors.Soldado.Abilities.Dash_Duration -- ≈12 studs
	local targetPos = pos + lookDir * dashDistance

	-- Move o personagem (teleport suave com animação)
	if state.humanoid and state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- Aplica um impulso (AssemblyLinearVelocity) para o dash
			-- Nota: em Luau Roblox, usamos ApplyImpulse ou LinearVelocity
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = lookDir * GameConstants.Survivors.Soldado.Abilities.Dash_Speed
			bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
			bodyVelocity.P = 1000
			bodyVelocity.Parent = rootPart

			-- Remove após a duração do dash
			task.delay(GameConstants.Survivors.Soldado.Abilities.Dash_Duration, function()
				if bodyVelocity and bodyVelocity.Parent then
					bodyVelocity:Destroy()
				end
			end)
		end
	end

	-- Verifica colisão com o Caçador durante o dash
	local killerState = getKillerState()
	if not killerState or not killerState.player then
		print("[CacadaSombria] Dash Tático: Caçador não encontrado")
		return
	end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	-- Verifica se o Caçador está na direção do dash e dentro do alcance
	local distToKiller = (pos - killerPos).Magnitude
	local dotToKiller = lookDir:Dot((killerPos - pos).Unit)

	if distToKiller <= dashDistance and dotToKiller > 0.7 then
		-- Atingiu o Caçador!
		print("[CacadaSombria] Dash Tático ATINGIU o Caçador!")

		-- Empurra o Caçador 10 studs
		local pushDir = lookDir
		if killerState.character then
			local killerRootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
			if killerRootPart then
				local pushForce = Instance.new("BodyVelocity")
				pushForce.Velocity = pushDir * 40
				pushForce.MaxForce = Vector3.new(50000, 50000, 50000)
				pushForce.P = 1000
				pushForce.Parent = killerRootPart

				task.delay(0.5, function()
					if pushForce and pushForce.Parent then
						pushForce:Destroy()
					end
				end)
			end
		end

		-- Silence no Caçador (3s — impede uso de habilidades)
		applyEffectToKiller(killerState, EFFECT_SILENCE, GameConstants.Survivors.Soldado.Abilities.Dash_Silence_Duration)

		-- Notifica o Caçador via UI
		if _gameStateEvent then
			GameStateEvent.sendToClient(
				_gameStateEvent,
				killerPlayer,
				GameStateEvent.MESSAGES.SILENCED,
				GameConstants.Survivors.Soldado.Abilities.Dash_Silence_Duration
			)
		end
	end
end

-- Habilidade E: Bazuca
-- Ativa: mira por até 10s, dispara feixe instantâneo de longo alcance
function SurvivorService:_handleSoldadoBazooka(state: any)
	if not validateSurvivorAction(state, "Bazooka") then return end

	-- Inicializa estado da Bazuca para este Sobrevivente
	local survState = _survivorState[state.userId]
	if not survState then
		survState = {}
		_survivorState[state.userId] = survState
	end

	-- Se já está usando Bazuca, cancela
	if survState.isUsingBazooka then
		self:_cancelBazooka(survState)
		return
	end

	print(string.format("[CacadaSombria] %s ativou a Bazuca! (%ds para disparar)",
		state.player.Name, GameConstants.Survivors.Soldado.Abilities.Bazooka_Fire_Window))

	-- Entra em modo de mira
	survState.isUsingBazooka = true
	survState.bazookaTimer = os.clock() + GameConstants.Survivors.Soldado.Abilities.Bazooka_Fire_Window

	-- Reduz velocidade durante a mira
	if state.humanoid then
		survState.originalSpeed = state.humanoid.WalkSpeed
		state.humanoid.WalkSpeed = state.humanoid.WalkSpeed * GameConstants.Survivors.Soldado.Abilities.Bazooka_Slow
	end

	-- Notifica o cliente para mostrar UI de mira da Bazuca
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"BazookaStart",
			GameConstants.Survivors.Soldado.Abilities.Bazooka_Fire_Window
		)
	end
end

-- Dispara o feixe da Bazuca
function SurvivorService:_fireBazooka(state: any)
	local survState = _survivorState[state.userId]
	if not survState or not survState.isUsingBazooka then return end

	print(string.format("[CacadaSombria] %s DISPAROU a Bazuca!", state.player.Name))

	-- Inicia cooldown (cheio)
	startCooldown(state, "Bazooka", GameConstants.Survivors.Soldado.Abilities.Bazooka_Cooldown)

	-- Limpa estado de mira
	survState.isUsingBazooka = false
	survState.bazookaTimer = nil

	-- Restaura velocidade
	if state.humanoid and survState.originalSpeed then
		state.humanoid.WalkSpeed = survState.originalSpeed
		survState.originalSpeed = nil
	end

	-- Notifica o cliente para remover UI
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"BazookaEnd"
		)
	end

	-- Calcula dano com bônus LMS
	local _, dmgMultiplier, _ = getLMSBonuses(state.className, getKillerState() and getKillerState().className)
	local baseDamage = 50 -- dano base da Bazuca
	local damage = math.floor(baseDamage * dmgMultiplier)

	-- Verifica se atingiu o Caçador (feixe instantâneo na direção da mira)
	local pos = getPlayerPosition(state.player)
	local lookDir = getPlayerLookVector(state.player)
	if not pos or not lookDir then return end

	local killerState = getKillerState()
	if not killerState then return end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	-- Verifica se o Caçador está na linha de tiro (feixe fino)
	local dirToKiller = (killerPos - pos).Unit
	local dotProduct = lookDir:Dot(dirToKiller)
	local distToKiller = (killerPos - pos).Magnitude

	if distToKiller <= GameConstants.Survivors.Soldado.Abilities.Bazooka_Range and dotProduct > 0.95 then
		-- Atingiu! Aplica dano
		damageKiller(killerPlayer, damage)
		print(string.format("[CacadaSombria] Bazuca atingiu o Caçador! Dano: %d", damage))

		-- Notifica o Caçador
		if _gameStateEvent then
			GameStateEvent.sendToClient(
				_gameStateEvent,
				killerPlayer,
				"BazookaHit",
				damage
			)
		end
	else
		print("[CacadaSombria] Bazuca errou o Caçador")
	end
end

-- Cancela a Bazuca (meio cooldown)
function SurvivorService:_cancelBazookaForState(playerState: any, survState: any)
	if not survState.isUsingBazooka then return end

	survState.isUsingBazooka = false
	survState.bazookaTimer = nil

	-- Restaura velocidade
	if playerState and playerState.humanoid and survState.originalSpeed then
		playerState.humanoid.WalkSpeed = survState.originalSpeed
		survState.originalSpeed = nil
	end

	-- Meio cooldown por cancelamento
	if playerState then
		startCooldown(playerState, "Bazooka", GameConstants.Survivors.Soldado.Abilities.Bazooka_Cooldown / 2)
	end

	-- Notifica o cliente
	if playerState and _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			playerState.player,
			"BazookaCancel"
		)
	end

	print(string.format("[CacadaSombria] Bazuca cancelada — meia penalidade de cooldown"))
end

-- Cancela a Bazuca (chamado de _handleSoldadoBazooka que já tem o state)
function SurvivorService:_cancelBazooka(survState: any)
	-- Procura o playerState correspondente
	for userId, s in _survivorState do
		if s == survState then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				local playerState = _matchService:getPlayerState(player)
				self:_cancelBazookaForState(playerState, survState)
				return
			end
			break
		end
	end
end

-- ==========================================
-- CLASSE: SACKBOY (HP 110, Speed 26, Stamina reduzida)
-- ==========================================

-- Inicia o carregamento da Arma de Tinta
function SurvivorService:_handleSackboyTintaStart(state: any)
	if not validateSurvivorAction(state, "TintaCharge") then return end

	local survState = _survivorState[state.userId]
	if not survState then
		survState = {}
		_survivorState[state.userId] = survState
	end

	print(string.format("[CacadaSombria] %s começou a carregar a Arma de Tinta!", state.player.Name))

	survState.isCharging = true
	survState.chargeStartTime = os.clock()
	survState.chargeLevel = 0

	-- Notifica o cliente para mostrar barra de carga
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"TintaChargeStart"
		)
	end
end

-- Dispara a Arma de Tinta (chamado via Ability3 ou ao soltar o botão)
function SurvivorService:_handleSackboyTintaFire(state: any)
	local survState = _survivorState[state.userId]
	if not survState or not survState.isCharging then
		return
	end

	survState.isCharging = false
	local chargeDuration = os.clock() - (survState.chargeStartTime or 0)
	survState.chargeStartTime = nil

	-- Determina o nível de carga
	-- Nível 1: ≥1s — slow + small push
	-- Nível 2: ≥2s — slow + medium push + silence 4s
	-- Nível 3: ≥3s — stun + blur + push
	local chargeLevel = 1
	if chargeDuration >= 3 then
		chargeLevel = 3
	elseif chargeDuration >= 2 then
		chargeLevel = 2
	elseif chargeDuration >= 1 then
		chargeLevel = 1
	else
		-- Menos de 1s: disparo fraco, sem efeitos
		chargeLevel = 0
	end

	print(string.format(
		"[CacadaSombria] %s disparou Arma de Tinta — Carga nível %d (%.1fs)",
		state.player.Name, chargeLevel, chargeDuration
	))

	-- Só aplica cooldown se disparou (com carga ≥ 1s)
	if chargeLevel >= 1 then
		startCooldown(state, "TintaCharge", GameConstants.Survivors.Sackboy.Abilities.Tinta_Cooldown)
	end

	-- Verifica alcance e direção
	local pos = getPlayerPosition(state.player)
	local lookDir = getPlayerLookVector(state.player)
	if not pos or not lookDir then return end

	local killerState = getKillerState()
	if not killerState then return end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	local distToKiller = (killerPos - pos).Magnitude
	local dirToKiller = (killerPos - pos).Unit
	local dotProduct = lookDir:Dot(dirToKiller)

	if distToKiller > GameConstants.Survivors.Sackboy.Abilities.Tinta_Range or dotProduct < 0.7 then
		print("[CacadaSombria] Arma de Tinta: Caçador fora de alcance")
		if _uISyncEvent then
			UISyncEvent.sendToClient(_uISyncEvent, state.player, "TintaChargeEnd", chargeLevel, false)
		end
		return
	end

	-- Aplica efeitos baseados no nível de carga
	local pushForce = chargeLevel * 8 -- studs de empurrão

	if chargeLevel >= 3 then
		-- Nível 3: Stun + Blur + Push
		applyEffectToKiller(killerState, EFFECT_STUN, 3)
		applyEffectToKiller(killerState, EFFECT_BLUR, 4)
		print("[CacadaSombria] Arma de Tinta Nível 3: STUN + BLUR no Caçador!")

		-- Reduz velocidade do Caçador a 0 durante stun
		if killerState.humanoid then
			killerState.humanoid.WalkSpeed = 0
		end

	elseif chargeLevel >= 2 then
		-- Nível 2: Slow + Push médio + Silence 4s
		applyEffectToKiller(killerState, EFFECT_SLOW, 3, 0.5) -- 50% velocidade
		applyEffectToKiller(killerState, EFFECT_SILENCE, GameConstants.Survivors.Sackboy.Abilities.Charge_Level2_Silence)
		if killerState.humanoid then
			killerState.humanoid.WalkSpeed = (killerState.humanoid.WalkSpeed or 26) * 0.5
		end
		print("[CacadaSombria] Arma de Tinta Nível 2: SLOW + SILENCE no Caçador!")

	elseif chargeLevel >= 1 then
		-- Nível 1: Slow leve + empurrão pequeno
		applyEffectToKiller(killerState, EFFECT_SLOW, 2, 0.7) -- 70% velocidade
		if killerState.humanoid then
			killerState.humanoid.WalkSpeed = (killerState.humanoid.WalkSpeed or 26) * 0.7
		end
		print("[CacadaSombria] Arma de Tinta Nível 1: SLOW no Caçador!")
	end

	-- Aplica empurrão no Caçador
	if pushForce > 0 and killerState.character then
		local killerRootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
		if killerRootPart then
			local pushDir = (killerPos - pos).Unit
			pushDir = Vector3.new(pushDir.X, 0.3, pushDir.Z).Unit -- leve ângulo para cima

			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = pushDir * pushForce * 5
			bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
			bodyVelocity.P = 1000
			bodyVelocity.Parent = killerRootPart

			task.delay(0.4, function()
				if bodyVelocity and bodyVelocity.Parent then
					bodyVelocity:Destroy()
				end
			end)
		end
	end

	-- Notifica o cliente
	if _uISyncEvent then
		UISyncEvent.sendToClient(_uISyncEvent, state.player, "TintaChargeEnd", chargeLevel, true)
	end
end

-- Surto: +Speed + Jump por 5s
function SurvivorService:_handleSackboySurto(state: any)
	if not validateSurvivorAction(state, "Surto") then return end

	print(string.format("[CacadaSombria] %s entrou em SURTO!", state.player.Name))

	startCooldown(state, "Surto", GameConstants.Survivors.Sackboy.Abilities.Surto_Cooldown)

	-- Salva valores originais
	local survState = _survivorState[state.userId]
	if not survState then
		survState = {}
		_survivorState[state.userId] = survState
	end

	-- Aplica bônus de velocidade e pulo
	if state.humanoid then
		survState.originalSpeed = state.humanoid.WalkSpeed
		survState.originalJump = state.humanoid.JumpPower
		state.humanoid.WalkSpeed = (survState.originalSpeed or GameConstants.Survivors.Sackboy.Speed) + GameConstants.Survivors.Sackboy.Abilities.Surto_Speed_Bonus
		state.humanoid.JumpPower = (survState.originalJump or 50) * GameConstants.Survivors.Sackboy.Abilities.Surto_Jump_Bonus
	end

	-- Notifica o cliente
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"SackboySurtoStart",
			GameConstants.Survivors.Sackboy.Abilities.Surto_Duration
		)
	end

	-- Agenda fim do Surto
	task.delay(GameConstants.Survivors.Sackboy.Abilities.Surto_Duration, function()
		local currentState = _matchService:getPlayerState(state.player)
		if not currentState then return end

		if currentState.humanoid then
			currentState.humanoid.WalkSpeed = survState.originalSpeed or GameConstants.Survivors.Sackboy.Speed
			currentState.humanoid.JumpPower = survState.originalJump or 50
		end

		if _uISyncEvent then
			UISyncEvent.sendToClient(
				_uISyncEvent,
				state.player,
				"SackboySurtoEnd"
			)
		end
		print(string.format("[CacadaSombria] Surto de %s terminou", state.player.Name))
	end)
end

-- ==========================================
-- CLASSE: ROBÔ (HP 150, Speed 18, Não pode ser curado por outros)
-- ==========================================

-- Habilidade Q: Agarrar — Puxa o Caçador
function SurvivorService:_handleRoboAgarrar(state: any)
	if not validateSurvivorAction(state, "Agarrar") then return end

	local pos = getPlayerPosition(state.player)
	local lookDir = getPlayerLookVector(state.player)
	if not pos or not lookDir then return end

	local killerState = getKillerState()
	if not killerState then return end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	local distToKiller = (killerPos - pos).Magnitude
	if distToKiller > GameConstants.Survivors.Robo.Abilities.Agarrar_Range then
		print(string.format("[CacadaSombria] Agarrar do Robô: Caçador muito longe (%.1f studs)", distToKiller))
		return
	end

	print(string.format("[CacadaSombria] Robô %s usou AGARRAR no Caçador!", state.player.Name))

	startCooldown(state, "Agarrar", GameConstants.Survivors.Robo.Abilities.Agarrar_Cooldown)

	-- Puxa o Caçador para perto do Robô
	if killerState.character then
		local killerRootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
		local robRootPart: BasePart? = state.character and state.character:FindFirstChild("HumanoidRootPart")

		if killerRootPart and robRootPart then
			-- Teleporta o Caçador para perto do Robô (na frente)
			local pullTarget = robRootPart.Position + lookDir * 5
			killerRootPart.CFrame = CFrame.new(pullTarget)
		end
	end

	-- Caçador fica INVINCIBLE por 8s + SILENCED por 2s
	applyEffectToKiller(killerState, EFFECT_INVINCIBLE, GameConstants.Survivors.Robo.Abilities.Agarrar_Killer_Invincible)
	applyEffectToKiller(killerState, EFFECT_SILENCE, GameConstants.Survivors.Robo.Abilities.Agarrar_Killer_Silence)

	-- Aplica lentidão ao Caçador durante a invencibilidade
	if killerState.humanoid then
		killerState.humanoid.WalkSpeed = 4 -- quase parado
		-- Agenda restauração após a invencibilidade
		task.delay(GameConstants.Survivors.Robo.Abilities.Agarrar_Killer_Invincible, function()
			local ks = getKillerState()
			if ks and ks.humanoid then
				ks.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
			end
		end)
	end

	print("[CacadaSombria] Caçador está INVINCIBLE (8s) e SILENCED (2s)!")
end

-- Habilidade E: Block — Contra-ataque
function SurvivorService:_handleRoboBlock(state: any)
	if not validateSurvivorAction(state, "Block") then return end

	local survState = _survivorState[state.userId]
	if not survState then
		survState = {}
		_survivorState[state.userId] = survState
	end

	print(string.format("[CacadaSombria] Robô %s ativou BLOCK!", state.player.Name))

	startCooldown(state, "Block", GameConstants.Survivors.Robo.Abilities.Block_Cooldown)

	-- Entra em estado de bloqueio por 1.5s
	survState.isBlocking = true
	survState.blockTimer = os.clock() + GameConstants.Survivors.Robo.Abilities.Block_Duration

	-- Notifica o cliente
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"RoboBlockStart",
			GameConstants.Survivors.Robo.Abilities.Block_Duration
		)
	end

	-- O contra-ataque acontece quando o Caçador ataca o Robô durante o block
	-- Isso precisa ser verificado pelo KillerService no Épico E2
	-- Por enquanto, implementamos a lógica de verificação aqui:
	-- Verifica se o Caçador está próximo e tentando atacar
	local killerState = getKillerState()
	if not killerState then return end

	-- Agenda uma verificação após a janela de block
	task.delay(GameConstants.Survivors.Robo.Abilities.Block_Duration, function()
		survState.isBlocking = false
		if _uISyncEvent then
			UISyncEvent.sendToClient(_uISyncEvent, state.player, "RoboBlockEnd")
		end
	end)
end

-- Função chamada quando o Caçador atinge o Robô durante o Block (contra-ataque bem-sucedido)
function SurvivorService:onRoboBlockCounter(roboState: any, killerState: any)
	print("[CacadaSombria] Robô CONTRA-ATACOU com sucesso!")

	-- Silence no Caçador por 3s
	applyEffectToKiller(killerState, EFFECT_SILENCE, GameConstants.Survivors.Robo.Abilities.Block_Silence)

	-- Cura o Robô em 10 HP (única fonte de cura do Robô)
	roboState.hp = math.min(roboState.maxHp, roboState.hp + GameConstants.Survivors.Robo.Abilities.Block_Heal)
	print(string.format("[CacadaSombria] Robô curou %d HP (Block). HP atual: %d/%d",
		GameConstants.Survivors.Robo.Abilities.Block_Heal, roboState.hp, roboState.maxHp))

	-- Notifica o cliente do Robô sobre a cura
	if _gameStateEvent then
		GameStateEvent.sendToClient(
			_gameStateEvent,
			roboState.player,
			GameStateEvent.MESSAGES.HP_UPDATE,
			roboState.hp,
			roboState.maxHp
		)
	end

	SurvivorService.SurvivorHealed:Fire(roboState.player, GameConstants.Survivors.Robo.Abilities.Block_Heal)
end

-- Habilidade R: Sacrifício
-- Para por 3s → boost de velocidade 5s → EXPLODE
function SurvivorService:_handleRoboSacrificio(state: any)
	if not validateSurvivorAction(state, "Sacrificio") then return end

	local survState = _survivorState[state.userId]
	if not survState then
		survState = {}
		_survivorState[state.userId] = survState
	end

	print(string.format("[CacadaSombria] Robô %s iniciou SACRIFÍCIO!", state.player.Name))

	startCooldown(state, "Sacrificio", GameConstants.Survivors.Robo.Abilities.Sacrificio_Cooldown)

	-- Fase 1: Windup (parado por 3s)
	survState.sacrificeState = "channelling"
	survState.sacrificeTimer = os.clock() + GameConstants.Survivors.Robo.Abilities.Sacrificio_Windup

	-- Impede movimento durante windup
	if state.humanoid then
		state.humanoid.WalkSpeed = 0
	end

	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"RoboSacrificeStart",
			GameConstants.Survivors.Robo.Abilities.Sacrificio_Windup
		)
	end
end

-- Fase 2 do Sacrifício: Windup completo, boost de velocidade
function SurvivorService:_onSacrificeWindupComplete(survState: any)
	-- Encontra o state do MatchService
	local state = nil
	for userId, s in _survivorState do
		if s == survState then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				state = _matchService:getPlayerState(player)
			end
			break
		end
	end

	if not state then return end

	print(string.format("[CacadaSombria] Robô %s: Windup completo! Boost de velocidade!", state.player.Name))

	survState.sacrificeState = "speedBoost"
	survState.sacrificeTimer = os.clock() + GameConstants.Survivors.Robo.Abilities.Sacrificio_Speed_Duration

	-- Boost de velocidade
	if state.humanoid then
		survState.originalSpeed = state.humanoid.WalkSpeed
		state.humanoid.WalkSpeed = (GameConstants.Survivors.Robo.Speed or 18) + 10 -- +10 de boost
	end

	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"RoboSacrificeSpeed",
			GameConstants.Survivors.Robo.Abilities.Sacrificio_Speed_Duration
		)
	end
end

-- Fase 3 do Sacrifício: EXPLODE
function SurvivorService:_onSacrificeExplode(survState: any)
	-- Encontra o state do MatchService
	local state = nil
	for userId, s in _survivorState do
		if s == survState then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				state = _matchService:getPlayerState(player)
			end
			break
		end
	end

	if not state then return end

	print(string.format("[CacadaSombria] Robô %s EXPLODIU!", state.player.Name))

	survState.sacrificeState = nil
	survState.sacrificeTimer = nil

	-- Auto-dano: 40 HP
	local selfDamage = GameConstants.Survivors.Robo.Abilities.Sacrificio_Self_Damage
	if _matchService then
		_matchService:applyDamage(state.player, selfDamage)
	end
	print(string.format("[CacadaSombria] Robô sofreu %d de auto-dano", selfDamage))

	-- Auto-slow: 8s
	applyEffectToKiller(state, EFFECT_SLOW, GameConstants.Survivors.Robo.Abilities.Sacrificio_Self_Slow, 0.5)
	if state.humanoid then
		state.humanoid.WalkSpeed = (survState.originalSpeed or 18) * 0.5
		task.delay(GameConstants.Survivors.Robo.Abilities.Sacrificio_Self_Slow, function()
			if state.humanoid then
				state.humanoid.WalkSpeed = survState.originalSpeed or GameConstants.Survivors.Robo.Speed
			end
		end)
	end

	-- Verifica se o Caçador está no alcance da explosão
	local pos = getPlayerPosition(state.player)
	if not pos then return end

	local killerState = getKillerState()
	if not killerState then return end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	local distToKiller = (killerPos - pos).Magnitude
	local explosionRange = 30 -- studs de alcance da explosão

	if distToKiller <= explosionRange then
		print("[CacadaSombria] EXPLOSÃO atingiu o Caçador!")

		-- Arremessa o Caçador 100 studs
		if killerState.character then
			local killerRootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
			if killerRootPart then
				local throwDir = (killerPos - pos).Unit
				throwDir = Vector3.new(throwDir.X, 0.5, throwDir.Z).Unit

				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.Velocity = throwDir * GameConstants.Survivors.Robo.Abilities.Sacrificio_Killer_Throw
				bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
				bodyVelocity.P = 1000
				bodyVelocity.Parent = killerRootPart

				task.delay(1, function()
					if bodyVelocity and bodyVelocity.Parent then
						bodyVelocity:Destroy()
					end
				end)
			end
		end

		-- Stun no Caçador por 6s
		applyEffectToKiller(killerState, EFFECT_STUN, GameConstants.Survivors.Robo.Abilities.Sacrificio_Killer_Stun)
		if killerState.humanoid then
			killerState.humanoid.WalkSpeed = 0
		end
	end

	if _uISyncEvent then
		UISyncEvent.sendToClient(_uISyncEvent, state.player, "RoboSacrificeExplode")
	end
end

-- ==========================================
-- CLASSE: ENFERMEIRA (HP 105, Speed 22)
-- ==========================================

-- Habilidade Q: Curativo — Cura aliado em 10 studs (canalização 2s)
-- Não pode curar Robô
-- Brilho verde visível ao Caçador a 40 studs através de paredes
function SurvivorService:_handleEnfermeiraCurativo(state: any, targetPlayer: Player?)
	if not validateSurvivorAction(state, "Curativo") then return end

	if not targetPlayer then
		print("[CacadaSombria] Curativo: Sem alvo especificado")
		return
	end

	local targetState = _matchService:getPlayerState(targetPlayer)
	if not targetState then
		print(string.format("[CacadaSombria] Curativo: Alvo %s sem estado", targetPlayer.Name))
		return
	end

	-- Verifica se o alvo é um Sobrevivente
	if targetState.role ~= "Survivor" then
		print("[CacadaSombria] Curativo: Alvo não é Sobrevivente")
		return
	end

	-- Verifica se o alvo é Robô (não pode ser curado)
	if targetState.className == "Robo" then
		print("[CacadaSombria] Curativo: Robô não pode ser curado por outros!")
		return
	end

	-- Verifica alcance (10 studs)
	local nursePos = getPlayerPosition(state.player)
	local targetPos = getPlayerPosition(targetPlayer)
	if not nursePos or not targetPos then return end

	local dist = (nursePos - targetPos).Magnitude
	if dist > GameConstants.Survivors.Enfermeira.Abilities.Curativo_Range then
		print(string.format("[CacadaSombria] Curativo: Alvo muito longe (%.1f studs)", dist))
		return
	end

	-- Verifica se o alvo já está com HP cheio
	if targetState.hp >= targetState.maxHp then
		print("[CacadaSombria] Curativo: Alvo já está com HP cheio")
		return
	end

	print(string.format("[CacadaSombria] Enfermeira %s iniciou CURATIVO em %s (2s de canalização)",
		state.player.Name, targetPlayer.Name))

	startCooldown(state, "Curativo", GameConstants.Survivors.Enfermeira.Abilities.Curativo_Cooldown)

	-- Brilho verde visível ao Caçador a 40 studs
	local killerState = getKillerState()
	if killerState and killerState.player then
		local killerPlayer = killerState.player
		local killerPos = getPlayerPosition(killerPlayer)
		if killerPos then
			local distToTarget = (killerPos - targetPos).Magnitude
			if distToTarget <= GameConstants.Survivors.Enfermeira.Abilities.Curativo_Glow_Range then
				-- Notifica o Caçador sobre a cura em andamento
				if _gameStateEvent then
					GameStateEvent.sendToClient(
						_gameStateEvent,
						killerPlayer,
						"CurativoGlow",
						targetPlayer,
						true -- visível
					)
				end
			end
		end
	end

	-- Canalização de 2 segundos
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"CurativoStart",
			GameConstants.Survivors.Enfermeira.Abilities.Curativo_Channel
		)
		UISyncEvent.sendToClient(
			_uISyncEvent,
			targetPlayer,
			"CurativoReceiving",
			state.player,
			GameConstants.Survivors.Enfermeira.Abilities.Curativo_Channel
		)
	end

	-- Agenda a aplicação da cura após 2s
	task.delay(GameConstants.Survivors.Enfermeira.Abilities.Curativo_Channel, function()
		local currentState = _matchService:getPlayerState(state.player)
		local currentTargetState = _matchService:getPlayerState(targetPlayer)
		if not currentState or not currentTargetState then return end

		-- Verifica se ainda estão no alcance
		local nPos = getPlayerPosition(state.player)
		local tPos = getPlayerPosition(targetPlayer)
		if not nPos or not tPos then return end
		if (nPos - tPos).Magnitude > GameConstants.Survivors.Enfermeira.Abilities.Curativo_Range + 2 then
			print("[CacadaSombria] Curativo interrompido: alvo se afastou")
			return
		end

		-- Aplica cura de 25 HP
		local healAmount = GameConstants.Survivors.Enfermeira.Abilities.Curativo_Heal
		currentTargetState.hp = math.min(
			currentTargetState.maxHp,
			currentTargetState.hp + healAmount
		)

		print(string.format("[CacadaSombria] Curativo aplicado! %s curou %d HP (HP: %d/%d)",
			targetPlayer.Name, healAmount, currentTargetState.hp, currentTargetState.maxHp))

		-- Notifica ambos os clientes
		if _gameStateEvent then
			GameStateEvent.sendToClient(
				_gameStateEvent,
				targetPlayer,
				GameStateEvent.MESSAGES.HP_UPDATE,
				currentTargetState.hp,
				currentTargetState.maxHp
			)
		end

		-- Remove brilho verde do Caçador
		if killerState and _gameStateEvent then
			GameStateEvent.sendToClient(
				_gameStateEvent,
				killerState.player,
				"CurativoGlow",
				targetPlayer,
				false -- não visível
			)
		end

		SurvivorService.SurvivorHealed:Fire(targetPlayer, healAmount)

		-- Notifica fim
		if _uISyncEvent then
			UISyncEvent.sendToClient(_uISyncEvent, state.player, "CurativoEnd")
			UISyncEvent.sendToClient(_uISyncEvent, targetPlayer, "CurativoEnd")
		end
	end)
end

-- Habilidade E: Injeção de Adrenalina
-- Projétil de seringa (15 studs). Ally: +3 speed + escudo (ignora próximo hit) 5s
function SurvivorService:_handleEnfermeiraAdrenalina(state: any, targetPlayer: Player?)
	if not validateSurvivorAction(state, "Adrenalina") then return end

	if not targetPlayer then
		print("[CacadaSombria] Adrenalina: Sem alvo especificado")
		return
	end

	local targetState = _matchService:getPlayerState(targetPlayer)
	if not targetState then
		print(string.format("[CacadaSombria] Adrenalina: Alvo %s sem estado", targetPlayer.Name))
		return
	end

	-- Verifica se o alvo é um Sobrevivente
	if targetState.role ~= "Survivor" then
		print("[CacadaSombria] Adrenalina: Alvo não é Sobrevivente")
		return
	end

	-- Verifica alcance (15 studs)
	local nursePos = getPlayerPosition(state.player)
	local targetPos = getPlayerPosition(targetPlayer)
	if not nursePos or not targetPos then return end

	local dist = (nursePos - targetPos).Magnitude
	if dist > GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Range then
		print(string.format("[CacadaSombria] Adrenalina: Alvo muito longe (%.1f studs)", dist))
		return
	end

	print(string.format("[CacadaSombria] Enfermeira %s aplicou ADRENALINA em %s!",
		state.player.Name, targetPlayer.Name))

	startCooldown(state, "Adrenalina", GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Cooldown)

	-- Aplica bônus de velocidade (+3)
	local survState = _survivorState[targetState.userId]
	if not survState then
		survState = {}
		_survivorState[targetState.userId] = survState
	end

	if targetState.humanoid then
		survState.adrenalinaOriginalSpeed = targetState.humanoid.WalkSpeed
		targetState.humanoid.WalkSpeed = (survState.adrenalinaOriginalSpeed or GameConstants.Survivors.Base.Speed) +
			GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Speed_Bonus
	end

	-- Aplica escudo (ignora o próximo hit)
	survState.isShielded = true
	survState.shieldEndTime = os.clock() + GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Shield_Duration

	print(string.format("[CacadaSombria] %s ganhou +3 speed e ESCUDO por %ds!",
		targetPlayer.Name, GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Shield_Duration))

	-- Notifica ambos os clientes
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"AdrenalinaCast",
			targetPlayer
		)
		UISyncEvent.sendToClient(
			_uISyncEvent,
			targetPlayer,
			"AdrenalinaReceived",
			GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Shield_Duration
		)
	end

	SurvivorService.SurvivorShielded:Fire(targetPlayer)

	-- Agenda fim do escudo e bônus de velocidade
	task.delay(GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Shield_Duration, function()
		local currentTargetState = _matchService:getPlayerState(targetPlayer)
		if not currentTargetState then return end

		survState.isShielded = false
		survState.shieldEndTime = nil

		-- Restaura velocidade
		if currentTargetState.humanoid and survState.adrenalinaOriginalSpeed then
			currentTargetState.humanoid.WalkSpeed = survState.adrenalinaOriginalSpeed
		end

		if _uISyncEvent then
			UISyncEvent.sendToClient(_uISyncEvent, targetPlayer, "AdrenalinaEnd")
		end
	end)
end

-- ==========================================
-- CLASSE: CAMPEÃO (HP 130, Speed 22)
-- ==========================================

-- Habilidade Q: Agarrão
-- Avança 8 studs. Se agarrar Caçador: 20 dano + arremessa 8 studs + grounded 1s
-- Se errar: auto-slow 2s
function SurvivorService:_handleCampeaoAgarrao(state: any)
	if not validateSurvivorAction(state, "Agarrao") then return end

	local pos = getPlayerPosition(state.player)
	local lookDir = getPlayerLookVector(state.player)
	if not pos or not lookDir then return end

	print(string.format("[CacadaSombria] Campeão %s usou AGARRÃO!", state.player.Name))

	startCooldown(state, "Agarrao", GameConstants.Survivors.Campeao.Abilities.Agarron_Cooldown)

	-- Avança 8 studs
	local dashDistance = GameConstants.Survivors.Campeao.Abilities.Agarron_Range
	local targetPos = pos + lookDir * dashDistance

	-- Move o personagem
	if state.humanoid and state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = lookDir * 30
			bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
			bodyVelocity.P = 1000
			bodyVelocity.Parent = rootPart

			task.delay(0.3, function()
				if bodyVelocity and bodyVelocity.Parent then
					bodyVelocity:Destroy()
				end
			end)
		end
	end

	-- Verifica se atingiu o Caçador
	local killerState = getKillerState()
	if not killerState then
		-- Sem Caçador — não pune
		print("[CacadaSombria] Agarrão: Caçador não encontrado")
		return
	end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	local distToKiller = (pos - killerPos).Magnitude
	if distToKiller <= dashDistance + 3 then
		local dotToKiller = lookDir:Dot((killerPos - pos).Unit)
		if dotToKiller > 0.5 then
			-- ATINGIU o Caçador!
			print("[CacadaSombria] Agarrão CONECTOU no Caçador!")

			-- 20 de dano
			damageKiller(killerPlayer, GameConstants.Survivors.Campeao.Abilities.Agarron_Damage)

			-- Arremessa o Caçador 8 studs para trás
			if killerState.character then
				local killerRootPart: BasePart? = killerState.character:FindFirstChild("HumanoidRootPart")
				if killerRootPart then
					local throwDir = -lookDir -- para trás do Campeão
					throwDir = Vector3.new(throwDir.X, 0.3, throwDir.Z).Unit

					local bodyVelocity = Instance.new("BodyVelocity")
					bodyVelocity.Velocity = throwDir * GameConstants.Survivors.Campeao.Abilities.Agarron_Throw * 5
					bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
					bodyVelocity.P = 1000
					bodyVelocity.Parent = killerRootPart

					task.delay(0.4, function()
						if bodyVelocity and bodyVelocity.Parent then
							bodyVelocity:Destroy()
						end
					end)
				end
			end

			-- Grounded 1s (impede movimento)
			applyEffectToKiller(killerState, EFFECT_GROUNDED, GameConstants.Survivors.Campeao.Abilities.Agarron_Grounded)
			if killerState.humanoid then
				killerState.humanoid.WalkSpeed = 0
				task.delay(GameConstants.Survivors.Campeao.Abilities.Agarron_Grounded, function()
					if killerState.humanoid then
						killerState.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
					end
				end)
			end
			return
		end
	end

	-- Errou! Auto-slow 2s
	print("[CacadaSombria] Agarrão ERROU! Auto-slow 2s")
	if state.humanoid then
		local survState = _survivorState[state.userId]
		if not survState then
			survState = {}
			_survivorState[state.userId] = survState
		end
		survState.agarrãoOriginalSpeed = state.humanoid.WalkSpeed
		state.humanoid.WalkSpeed = (survState.agarrãoOriginalSpeed or GameConstants.Survivors.Campeao.Speed) * 0.5

		task.delay(2, function()
			local currentState = _matchService:getPlayerState(state.player)
			if currentState and currentState.humanoid then
				currentState.humanoid.WalkSpeed = survState.agarrãoOriginalSpeed or GameConstants.Survivors.Campeao.Speed
			end
		end)
	end
end

-- Habilidade E: Sequência de 3 socos
-- Cada soco: 5 dano, 5 studs de alcance
-- 3º soco: +5 dano bônus + slow 1s no Caçador
-- Se acertar todos os 3: reduz cooldown do Agarrão em 5s
function SurvivorService:_handleCampeaoSequencia(state: any)
	if not validateSurvivorAction(state, "Sequencia") then return end

	local survState = _survivorState[state.userId]
	if not survState then
		survState = {}
		_survivorState[state.userId] = survState
	end

	-- Verifica janela de combo (se o último soco foi há mais de 2s, reseta)
	local now = os.clock()
	if survState.comboLastHitTime and (now - survState.comboLastHitTime) > GameConstants.Survivors.Campeao.Abilities.Sequencia_Hit_Window then
		survState.comboHits = 0
	end

	-- Incrementa combo
	local comboHits = (survState.comboHits or 0) + 1
	if comboHits > 3 then
		comboHits = 1 -- reseta se já fez os 3
	end
	survState.comboHits = comboHits
	survState.comboLastHitTime = now

	-- Verifica se está na primeira ativação da sequência (inicia cooldown)
	if comboHits == 1 then
		startCooldown(state, "Sequencia", GameConstants.Survivors.Campeao.Abilities.Sequencia_Cooldown)
	end

	print(string.format("[CacadaSombria] Campeão %s: SOCo #%d da Sequência!",
		state.player.Name, comboHits))

	-- Calcula dano
	local damage = GameConstants.Survivors.Campeao.Abilities.Sequencia_Damage_PerHit -- 5
	if comboHits == 3 then
		damage += GameConstants.Survivors.Campeao.Abilities.Sequencia_Third_Bonus -- +5 = 10 total no 3º
	end

	-- Verifica se atingiu o Caçador
	local pos = getPlayerPosition(state.player)
	local lookDir = getPlayerLookVector(state.player)
	if not pos or not lookDir then return end

	local killerState = getKillerState()
	if not killerState then return end

	local killerPlayer = killerState.player
	local killerPos = getPlayerPosition(killerPlayer)
	if not killerPos then return end

	local distToKiller = (killerPos - pos).Magnitude
	local dirToKiller = distToKiller > 0 and (killerPos - pos).Unit or Vector3.new(0, 0, 0)
	local dotProduct = lookDir:Dot(dirToKiller)

	if distToKiller <= GameConstants.Survivors.Campeao.Abilities.Sequencia_Range and dotProduct > 0.5 then
		-- Atingiu!
		damageKiller(killerPlayer, damage)
		print(string.format("[CacadaSombria] Soco #%d atingiu! Dano: %d", comboHits, damage))

		-- Efeitos do 3º soco
		if comboHits == 3 then
			-- Slow 1s no Caçador
			applyEffectToKiller(killerState, EFFECT_SLOW, 1, 0.5)
			if killerState.humanoid then
				killerState.humanoid.WalkSpeed = (killerState.humanoid.WalkSpeed or 26) * 0.5
				task.delay(1, function()
					if killerState.humanoid then
						killerState.humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed
					end
				end)
			end
			print("[CacadaSombria] 3º soco: SLOW 1s no Caçador!")
		end

		-- Se acertou todos os 3, reduz cooldown do Agarrão
		if comboHits == 3 then
			-- Verifica se os 3 acertaram (contamos hits bem-sucedidos)
			-- Reduz cooldown do Agarrão em 5s
			local agarraoCooldown = state.cooldowns["Agarrao"]
			if agarraoCooldown then
				state.cooldowns["Agarrao"] = math.max(now, agarraoCooldown - GameConstants.Survivors.Campeao.Abilities.Sequencia_Combo_Reduction)
				print("[CacadaSombria] Combo completo! Cooldown do Agarrão reduzido em 5s!")
			end

			survState.comboHits = 0
		end
	else
		print(string.format("[CacadaSombria] Soco #%d errou o Caçador", comboHits))
	end

	-- Notifica o cliente
	if _uISyncEvent then
		UISyncEvent.sendToClient(
			_uISyncEvent,
			state.player,
			"CampeaoSequencia",
			comboHits,
			damage,
			distToKiller <= GameConstants.Survivors.Campeao.Abilities.Sequencia_Range and dotProduct > 0.5
		)
	end
end

-- ==========================================
-- FUNÇÕES PÚBLICAS DE CONSULTA
-- ==========================================

-- Verifica se um Sobrevivente está com escudo ativo (Adrenalina)
-- Usado pelo KillerService para decidir se o dano é bloqueado
function SurvivorService:isSurvivorShielded(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state then return false end

	local survState = _survivorState[state.userId]
	if not survState then return false end

	if not survState.isShielded then return false end

	-- Verifica se o escudo ainda é válido
	if survState.shieldEndTime and os.clock() > survState.shieldEndTime then
		survState.isShielded = false
		return false
	end

	return true
end

-- Verifica se um Sobrevivente é o Robô (não pode ser curado externamente)
function SurvivorService:isSurvivorRobo(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state then return false end
	return state.className == "Robo"
end

-- Consome o escudo de um Sobrevivente (chamado quando o Caçador acerta)
-- Retorna true se o escudo bloqueou o hit
function SurvivorService:consumeShield(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state then return false end

	local survState = _survivorState[state.userId]
	if not survState or not survState.isShielded then return false end

	-- Consome o escudo
	survState.isShielded = false
	survState.shieldEndTime = nil

	print(string.format("[CacadaSombria] Escudo de %s bloqueou um hit!", player.Name))

	-- Revela o Caçador para o Sobrevivente protegido por 2s
	local killerState = getKillerState()
	if killerState and killerState.player then
		print(string.format("[CacadaSombria] Caçador revelado a %s por 2s", player.Name))
		if _gameStateEvent then
			GameStateEvent.sendToClient(
				_gameStateEvent,
				player,
				"KillerRevealed",
				killerState.player,
				GameConstants.Survivors.Enfermeira.Abilities.Adrenalina_Reveal_Duration
			)
		end
	end

	-- Restaura velocidade após quebrar o escudo
	if state.humanoid then
		local survState2 = _survivorState[state.userId]
		if survState2 and survState2.adrenalinaOriginalSpeed then
			state.humanoid.WalkSpeed = survState2.adrenalinaOriginalSpeed
			survState2.adrenalinaOriginalSpeed = nil
		end
	end

	return true
end

-- Verifica se o Robô está em estado de Block
function SurvivorService:isRoboBlocking(player: Player): boolean
	local state = _matchService:getPlayerState(player)
	if not state then return false end

	local survState = _survivorState[state.userId]
	if not survState then return false end

	if not survState.isBlocking then return false end

	-- Verifica se o timer do block ainda é válido
	if survState.blockTimer and os.clock() > survState.blockTimer then
		survState.isBlocking = false
		return false
	end

	return true
end

-- Obtém o estado de sobrevivente estendido
function SurvivorService:getSurvivorState(player: Player): any?
	local state = _matchService:getPlayerState(player)
	if not state then return nil end
	return _survivorState[state.userId]
end

-- Handler de disparo da Bazuca (chamado externamente via PlayerAction)
function SurvivorService:handleBazookaFire(player: Player)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	self:_fireBazooka(state)
end

-- Handler de cancelamento da Bazuca
function SurvivorService:handleBazookaCancel(player: Player)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	local survState = _survivorState[state.userId]
	if survState then
		self:_cancelBazooka(survState)
	end
end

-- Handler de disparo da Arma de Tinta (Sackboy)
function SurvivorService:handleTintaFire(player: Player)
	local state = _matchService:getPlayerState(player)
	if not state then return end
	self:_handleSackboyTintaFire(state)
end

-- ==========================================
-- CLEANUP
-- ==========================================

function SurvivorService:Destroy()
	-- Limpa estado de todos os Sobreviventes
	for userId, _ in _survivorState do
		_survivorState[userId] = nil
	end
	print("[CacadaSombria] SurvivorService destruído.")
end

return SurvivorService
