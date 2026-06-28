--!strict
--[[
	SurvivorEvents.lua
	Handlers auxiliares e constantes para ações de Sobreviventes.
	
	Responsável por:
	- Definir tipos de ação específicos de Sobreviventes
	- Funções auxiliares para criar efeitos visuais (feixes, projéteis)
	- Gerenciamento de indicadores visuais (brilho de cura, revelação)
	- Conexão entre PlayerActionEvent e SurvivorService

	Contexto: Server (ServerScriptService)
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

-- ==========================================
-- MÓDULO SURVIVOREVENTS
-- ==========================================
local SurvivorEvents = {}

-- ==========================================
-- REFERÊNCIAS INJETADAS NO INIT
-- ==========================================
local _playerActionEvent: RemoteEvent? = nil
local _survivorService: any = nil
local _matchService: any = nil

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

-- Chamado pelo GameManager durante a fase Init
-- Registra handlers de Ability1/2/3 para roteamento ao SurvivorService
function SurvivorEvents.Init(playerActionEvent: RemoteEvent, survivorService: any, matchService: any)
	_playerActionEvent = playerActionEvent
	_survivorService = survivorService
	_matchService = matchService

	-- Registra listener para ações de habilidade (Ability1/2/3) no PlayerActionEvent
	-- As ações são roteadas para o SurvivorService:handleAbilityAction
	_playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
		-- Só processa ações de habilidade de Sobreviventes
		if action == "Ability1" or action == "Ability2" or action == "Ability3" then
			-- Verifica se o jogador é um Sobrevivente
			local state = _matchService:getPlayerState(player)
			if state and state.role == "Survivor" and state.isAlive then
				_survivorService:handleAbilityAction(player, action, ...)
			end
		end
	end)

	print("[CacadaSombria] SurvivorEvents inicializado — listener de habilidades registrado.")
end

-- ==========================================
-- TIPOS DE AÇÃO ESPECÍFICOS DE SOBREVIVENTES
-- ==========================================
-- Expandem os tipos base de PlayerActionEvent

SurvivorEvents.ACTIONS = {
	-- Soldado
	SOLDADO_DASH = "SoldadoDash",           -- Dash Tático (Q)
	SOLDADO_BAZOOKA_START = "SoldadoBazookaStart", -- Iniciar mira da Bazuca (E)
	SOLDADO_BAZOOKA_FIRE = "SoldadoBazookaFire",   -- Disparar Bazuca (clique)
	SOLDADO_BAZOOKA_CANCEL = "SoldadoBazookaCancel", -- Cancelar Bazuca

	-- Sackboy
	SACKBOY_TINTA_CHARGE = "SackboyTintaCharge",  -- Iniciar/Hold carga da Arma de Tinta (Q)
	SACKBOY_TINTA_FIRE = "SackboyTintaFire",      -- Disparar Arma de Tinta (soltar Q)
	SACKBOY_SURTO = "SackboySurto",               -- Ativar Surto (E)

	-- Robô
	ROBO_AGARRAR = "RoboAgarrar",          -- Agarrar (puxar Caçador) (Q)
	ROBO_BLOCK = "RoboBlock",              -- Ativar Block (E)
	ROBO_SACRIFICIO = "RoboSacrificio",    -- Iniciar Sacrifício (R)

	-- Enfermeira
	ENFERMEIRA_CURATIVO = "EnfermeiraCurativo",     -- Curativo em aliado (Q)
	ENFERMEIRA_ADRENALINA = "EnfermeiraAdrenalina", -- Injeção de Adrenalina (E)

	-- Campeão
	CAMPEAO_AGARRAO = "CampeaoAgarrao",    -- Agarrão (Q)
	CAMPEAO_SEQUENCIA = "CampeaoSequencia", -- Sequência de socos (E)
}

-- ==========================================
-- TIPOS DE MENSAGEM DE EFEITOS VISUAIS
-- ==========================================
-- Enviados do Servidor → Cliente via GameStateEvent/UISyncEvent

SurvivorEvents.EFFECT_MESSAGES = {
	-- Efeitos no Sobrevivente
	SURVIVOR_SHIELD_ACTIVE = "SurvivorShieldActive",   -- Escudo de Adrenalina ativo
	SURVIVOR_SHIELD_BROKEN = "SurvivorShieldBroken",   -- Escudo quebrou (bloqueou hit)
	SURVIVOR_HEAL_RECEIVED = "SurvivorHealReceived",   -- Recebeu cura
	SURVIVOR_SPEED_BOOST = "SurvivorSpeedBoost",       -- Bônus de velocidade
	SURVIVOR_SLOWED = "SurvivorSlowed",                -- Lentidão aplicada
	SURVIVOR_STUNNED = "SurvivorStunned",              -- Atordoado

	-- Efeitos no Caçador (enviados ao Caçador)
	KILLER_SILENCED = "KillerSilenced",                -- Silenciado (sem habilidades)
	KILLER_SLOWED = "KillerSlowed",                    -- Lentidão
	KILLER_STUNNED = "KillerStunned",                  -- Atordoado
	KILLER_BLURRED = "KillerBlurred",                  -- Visão borrada
	KILLER_GROUNDED = "KillerGrounded",                -- Impedido de mover
	KILLER_REVEALED = "KillerRevealed",                -- Revelado a Sobreviventes

	-- Efeitos visuais de habilidades
	BAZOOKA_BEAM = "BazookaBeam",                      -- Feixe da Bazuca
	TINTA_BLAST = "TintaBlast",                        -- Explosão da Arma de Tinta
	SACRIFICIO_EXPLOSION = "SacrificioExplosion",      -- Explosão do Sacrifício
	CURATIVO_GLOW = "CurativoGlow",                    -- Brilho verde do Curativo
	ADRENALINA_PROJECTILE = "AdrenalinaProjectile",    -- Projétil da Adrenalina

	-- Estados de habilidade
	BAZOOKA_AIMING = "BazookaAiming",                  -- Mirando com Bazuca
	BLOCK_ACTIVE = "BlockActive",                      -- Block do Robô ativo
	SURTO_ACTIVE = "SurtoActive",                      -- Surto do Sackboy ativo
}

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar feixe visual (Bazuca)
-- ==========================================
-- Cria um efeito visual de feixe entre duas posições
-- Usado pela Bazuca do Soldado e potencialmente outras habilidades
-- @param origin — Posição de origem do feixe (Vector3)
-- @param direction — Direção do feixe (Vector3 normalizado)
-- @param length — Comprimento do feixe em studs
-- @param color — Cor do feixe (Color3, padrão: vermelho alaranjado)
-- @return Part — A parte do feixe criada
function SurvivorEvents.createBeam(origin: Vector3, direction: Vector3, length: number, color: Color3?): BasePart?
	-- Cria uma parte alongada para representar o feixe
	local beam = Instance.new("Part")
	beam.Name = "BazookaBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = color or Color3.fromRGB(255, 80, 20) -- Laranja avermelhado
	beam.Size = Vector3.new(0.3, 0.3, length)          -- Fino e comprido
	beam.Transparency = 0.3

	-- Posiciona e orienta
	local midPoint = origin + direction * (length / 2)
	beam.CFrame = CFrame.lookAt(midPoint, origin + direction * length)

	beam.Parent = workspace

	-- Auto-destrói após 0.3s
	task.delay(0.3, function()
		if beam and beam.Parent then
			beam:Destroy()
		end
	end)

	return beam
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar projétil visual
-- ==========================================
-- Cria um projétil visual que se move em linha reta
-- Usado pela Injeção de Adrenalina da Enfermeira
-- @param origin — Posição de origem
-- @param target — Posição de destino
-- @param speed — Velocidade do projétil em studs/s
-- @param color — Cor do projétil
function SurvivorEvents.createProjectile(origin: Vector3, target: Vector3, speed: number, color: Color3?)
	local direction = (target - origin).Unit
	local distance = (target - origin).Magnitude
	local travelTime = distance / speed

	local projectile = Instance.new("Part")
	projectile.Name = "AdrenalinaProjectile"
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.Material = Enum.Material.Neon
	projectile.Color = color or Color3.fromRGB(0, 255, 100) -- Verde brilhante
	projectile.Size = Vector3.new(0.4, 0.4, 0.4)
	projectile.Shape = Enum.PartType.Ball
	projectile.Transparency = 0.2

	projectile.Position = origin
	projectile.Parent = workspace

	-- Move o projétil usando TweenService
	local TweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local goal = {Position = target}
	local tween = TweenService:Create(projectile, tweenInfo, goal)
	tween:Play()

	-- Destrói ao chegar
	task.delay(travelTime + 0.1, function()
		if projectile and projectile.Parent then
			projectile:Destroy()
		end
	end)

	return projectile
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar efeito de explosão
-- ==========================================
-- Cria um efeito visual de explosão esférica
-- Usado pelo Sacrifício do Robô
-- @param position — Centro da explosão
-- @param radius — Raio da explosão em studs
function SurvivorEvents.createExplosionEffect(position: Vector3, radius: number)
	local explosion = Instance.new("Part")
	explosion.Name = "SacrificeExplosion"
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 100, 0) -- Laranja
	explosion.Size = Vector3.new(0.5, 0.5, 0.5)
	explosion.Shape = Enum.PartType.Ball
	explosion.Transparency = 0.5

	explosion.Position = position
	explosion.Parent = workspace

	-- Expande e desaparece
	local TweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 1}
	local tween = TweenService:Create(explosion, tweenInfo, goal)
	tween:Play()

	task.delay(1.1, function()
		if explosion and explosion.Parent then
			explosion:Destroy()
		end
	end)

	return explosion
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Criar indicador de brilho (Curativo)
-- ==========================================
-- Cria um efeito de brilho verde ao redor de um Sobrevivente sendo curado
-- Visível através de paredes (Adornee)
-- @param character — Model do Sobrevivente
-- @param visible — true para mostrar, false para esconder
function SurvivorEvents.setCurativoGlow(character: Model, visible: boolean)
	if not character then return end

	-- Procura ou cria um Highlight no character
	local highlight: Highlight? = character:FindFirstChild("CurativoHighlight")

	if visible then
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "CurativoHighlight"
			highlight.FillColor = Color3.fromRGB(0, 255, 100) -- Verde
			highlight.FillTransparency = 0.7
			highlight.OutlineColor = Color3.fromRGB(0, 200, 50)
			highlight.OutlineTransparency = 0.3
			highlight.Adornee = character
			highlight.Parent = character
		end
	else
		if highlight then
			highlight:Destroy()
		end
	end
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Aplicar efeito de blur no Caçador
-- ==========================================
-- Envia comando ao cliente do Caçador para aplicar blur na tela
-- @param killerPlayer — O jogador Caçador
-- @param duration — Duração do blur em segundos
-- @param intensity — Intensidade do blur (0-1)
function SurvivorEvents.applyKillerBlur(killerPlayer: Player, duration: number, intensity: number?)
	-- Esta função precisa enviar um comando via RemoteEvent ao cliente do Caçador
	-- O cliente (CameraManager ou KillerHUD) aplicará o efeito visual
	-- Por enquanto, registramos a intenção — a implementação completa depende da UI

	print(string.format(
		"[CacadaSombria] Blur aplicado ao Caçador %s: %.1fs, intensidade %.1f",
		killerPlayer.Name, duration, intensity or 0.5
	))

	-- O envio real via RemoteEvent será feito pelo SurvivorService
	-- que tem acesso ao _gameStateEvent
end

-- ==========================================
-- FUNÇÃO AUXILIAR: Revelar Caçador ao Sobrevivente
-- ==========================================
-- Faz o Caçador ficar visível através de paredes para um Sobrevivente
-- @param survivorPlayer — O Sobrevivente que verá o Caçador
-- @param killerPlayer — O Caçador a ser revelado
-- @param duration — Duração da revelação em segundos
function SurvivorEvents.revealKiller(survivorPlayer: Player, killerPlayer: Player, duration: number)
	print(string.format(
		"[CacadaSombria] Caçador %s revelado a %s por %.1fs",
		killerPlayer.Name, survivorPlayer.Name, duration
	))

	-- Cria um Highlight visível apenas para o Sobrevivente
	local killerCharacter = killerPlayer.Character
	if not killerCharacter then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "KillerRevealHighlight"
	highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Vermelho
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
	highlight.OutlineTransparency = 0.2
	highlight.Adornee = killerCharacter
	highlight.Parent = killerCharacter

	-- Remove após a duração
	task.delay(duration, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- ==========================================
-- VALIDAÇÃO DE CLASSE DE SOBREVIVENTE
-- ==========================================

-- Retorna a classe de um jogador Sobrevivente
-- @param player — O jogador
-- @return string? — Nome da classe ou nil
function SurvivorEvents.getSurvivorClass(player: Player): string?
	-- Esta função é um helper; a fonte da verdade é o MatchService
	-- Retornamos nil aqui para evitar dependência circular
	return nil
end

-- Verifica se uma classe de Sobrevivente é válida
function SurvivorEvents.isValidSurvivorClass(className: string): boolean
	local validClasses = {"Soldado", "Sackboy", "Robo", "Enfermeira", "Campeao"}
	for _, valid in validClasses do
		if className == valid then
			return true
		end
	end
	return false
end

-- ==========================================
-- FUNÇÕES DE MAPEAMENTO DE TECLAS → HABILIDADES
-- ==========================================

-- Mapeia uma classe de Sobrevivente e um slot de habilidade para o nome da ação
-- Usado pelo InputManager do cliente para enviar a ação correta
-- @param className — Classe do Sobrevivente
-- @param abilitySlot — "Ability1" (Q), "Ability2" (E), "Ability3" (R/F)
-- @return string? — Nome da ação específica
function SurvivorEvents.mapAbilityToAction(className: string, abilitySlot: string): string?
	local classMap: {[string]: {[string]: string}} = {
		Soldado = {
			Ability1 = SurvivorEvents.ACTIONS.SOLDADO_DASH,
			Ability2 = SurvivorEvents.ACTIONS.SOLDADO_BAZOOKA_START,
		},
		Sackboy = {
			Ability1 = SurvivorEvents.ACTIONS.SACKBOY_TINTA_CHARGE,
			Ability2 = SurvivorEvents.ACTIONS.SACKBOY_SURTO,
			Ability3 = SurvivorEvents.ACTIONS.SACKBOY_TINTA_FIRE,
		},
		Robo = {
			Ability1 = SurvivorEvents.ACTIONS.ROBO_AGARRAR,
			Ability2 = SurvivorEvents.ACTIONS.ROBO_BLOCK,
			Ability3 = SurvivorEvents.ACTIONS.ROBO_SACRIFICIO,
		},
		Enfermeira = {
			Ability1 = SurvivorEvents.ACTIONS.ENFERMEIRA_CURATIVO,
			Ability2 = SurvivorEvents.ACTIONS.ENFERMEIRA_ADRENALINA,
		},
		Campeao = {
			Ability1 = SurvivorEvents.ACTIONS.CAMPEAO_AGARRAO,
			Ability2 = SurvivorEvents.ACTIONS.CAMPEAO_SEQUENCIA,
		},
	}

	local classActions = classMap[className]
	if not classActions then return nil end
	return classActions[abilitySlot]
end

return SurvivorEvents
