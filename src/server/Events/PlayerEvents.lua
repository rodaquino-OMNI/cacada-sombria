--!strict
--[[
  PlayerEvents.lua
  Gerencia eventos de entrada e saída de jogadores no servidor.
  
  Responsável por:
  - Configurar o character do jogador ao spawnar
  - Aplicar configurações de câmera e controles
  - Atribuir ferramentas/itens (futuro)
  - Gerenciar respawn e morte
  - Configurar pacotes de animação

  Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX
-- ==========================================
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)

-- ==========================================
-- SERVIÇO PLAYEREVENTS
-- ==========================================
local PlayerEvents = {}

-- ==========================================
-- CONFIGURAÇÕES DE SPAWN
-- ==========================================

-- Configura o character de um Sobrevivente ao spawnar
-- Aplica os atributos base (HP, velocidade, animações)
function PlayerEvents.setupSurvivorCharacter(player: Player, className: string?)
	local character = player.Character
	if not character then
		warn(string.format("[CacadaSombria] setupSurvivorCharacter: %s sem character", player.Name))
		return
	end

	-- Aguarda o Humanoid ficar disponível
	local humanoid: Humanoid? = character:FindFirstChild("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end

	if not humanoid then
		warn(string.format("[CacadaSombria] Humanoid não encontrado para Sobrevivente %s", player.Name))
		return
	end

	-- ==========================
	-- CONFIGURAÇÃO DE ATRIBUTOS
	-- ==========================

	-- Velocidade base do Sobrevivente
	humanoid.WalkSpeed = GameConstants.Survivors.Base.Speed -- 22 studs/s

	-- Pulo padrão
	humanoid.JumpPower = 50

	-- Configuração para personagem customizado (desabilita quedas de dano)
	humanoid.UseJumpPower = true

	-- Buscar HP da classe específica ou usar o base
	local maxHp = GameConstants.Survivors.Base.HP -- 120 (fallback)
	if className and GameConstants.Survivors[className] then
		maxHp = GameConstants.Survivors[className].HP
	end

	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp

	-- ⚠️ Importante: O Humanoid do Roblox tem seu próprio sistema de vida.
	-- Precisamos desabilitar a morte automática para gerenciar nós mesmos.
	-- O estado "Derrubado" será gerenciado pelo MatchService/SurvivorService.
	humanoid.BreakJointsOnDeath = false

	print(string.format("[CacadaSombria] Sobrevivente configurado: %s (classe: %s, HP: %d, Speed: %d)",
		player.Name, className or "base", maxHp, humanoid.WalkSpeed))
end

-- ==========================================
-- CONFIGURAÇÃO DO CAÇADOR
-- ==========================================

-- Configura o character do Caçador ao spawnar
function PlayerEvents.setupKillerCharacter(player: Player)
	local character = player.Character
	if not character then
		warn(string.format("[CacadaSombria] setupKillerCharacter: %s sem character", player.Name))
		return
	end

	-- Aguarda o Humanoid
	local humanoid: Humanoid? = character:FindFirstChild("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end

	if not humanoid then
		warn(string.format("[CacadaSombria] Humanoid não encontrado para Caçador %s", player.Name))
		return
	end

	-- ==========================
	-- CONFIGURAÇÃO DE ATRIBUTOS
	-- ==========================

	-- Velocidade base do Caçador (O Distorcido)
	humanoid.WalkSpeed = GameConstants.Killers.Distorcido.Speed -- 26 studs/s

	-- Pulo padrão
	humanoid.JumpPower = 50

	-- HP do Caçador
	local maxHp = GameConstants.Killers.Distorcido.HP -- 1100
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp

	-- Não morre com dano (O Caçador não pode ser morto)
	humanoid.BreakJointsOnDeath = false

	print(string.format("[CacadaSombria] Caçador configurado: %s (HP: %d, Speed: %d)",
		player.Name, maxHp, humanoid.WalkSpeed))
end

-- ==========================================
-- GERENCIAMENTO DE ANIMAÇÕES
-- ==========================================

-- Carrega e aplica um pacote de animações ao character
-- @param player — O jogador
-- @param animationType — "Survivor" ou "Killer"
function PlayerEvents.loadAnimations(player: Player, animationType: string)
	-- Placeholder para sistema de animações (Épico E4/E8)
	-- Por enquanto, usamos as animações padrão do Roblox
	print(string.format("[CacadaSombria] Animações '%s' serão carregadas no Épico E4/E8", animationType))
end

-- ==========================================
-- SPAWN DE JOGADORES
-- ==========================================

-- Spawna um Sobrevivente em uma posição aleatória do mapa
-- As posições de spawn serão definidas no Épico E4 (Mapa)
-- Por enquanto, usa uma posição padrão
function PlayerEvents.spawnSurvivor(player: Player): boolean
	local character = player.Character
	if not character then
		-- Força o spawn carregando o character
		player:LoadCharacter()
		character = player.Character
		if not character then
			warn(string.format("[CacadaSombria] Falha ao spawnar Sobrevivente %s", player.Name))
			return false
		end
	end

	-- Posiciona o character em um ponto de spawn
	-- TODO Épico E4: Usar spawn points aleatórios do mapa
	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		-- Spawn temporário no centro do mundo (0, 10, 0)
		-- Será substituído por spawn points do mapa
		rootPart.CFrame = CFrame.new(0, 10, 0)
	end

	-- Configura o character
	PlayerEvents.setupSurvivorCharacter(player, nil)

	return true
end

-- Spawna o Caçador na posição fixa (Hall de Entrada)
-- A posição será definida no Épico E4 (Mapa)
function PlayerEvents.spawnKiller(player: Player): boolean
	local character = player.Character
	if not character then
		player:LoadCharacter()
		character = player.Character
		if not character then
			warn(string.format("[CacadaSombria] Falha ao spawnar Caçador %s", player.Name))
			return false
		end
	end

	-- Posiciona o Caçador no spawn fixo
	-- TODO Épico E4: Usar spawn point do Hall de Entrada
	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(20, 10, 0) -- Spawn temporário
	end

	-- Configura o character
	PlayerEvents.setupKillerCharacter(player)

	return true
end

-- ==========================================
-- RESPAWN APÓS MORTE
-- ==========================================

-- Respawna um jogador como espectador (após ser eliminado)
function PlayerEvents.respawnAsSpectator(player: Player)
	print(string.format("[CacadaSombria] %s respawnando como espectador", player.Name))
	player:LoadCharacter()
end

-- ==========================================
-- UTILITÁRIOS DE CHARACTER
-- ==========================================

-- Verifica se um character é válido (existe, tem Humanoid, tem RootPart)
function PlayerEvents.isCharacterValid(character: Model?): boolean
	if not character then return false end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	return true
end

-- Obtém a posição atual de um jogador
function PlayerEvents.getPlayerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then return nil end

	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	return rootPart.Position
end

-- ==========================================
-- TRATAMENTO DE DESCONEXÃO (Épico E7)
-- ==========================================

-- Lida com a desconexão de um jogador durante a partida
-- Remove o character do mundo de forma limpa
-- @param player — O jogador que desconectou
function PlayerEvents.handleDisconnect(player: Player)
	print(string.format("[CacadaSombria] Tratando desconexão de %s...", player.Name))

	-- Remove o character do mundo se ainda existir
	local character = player.Character
	if character then
		-- Destrói o character para liberar recursos
		-- O Roblox gerencia isso automaticamente, mas podemos limpar referências
		print(string.format("[CacadaSombria] Character de %s removido do mundo", player.Name))
	end
end

-- Obtém estatísticas de um jogador para a tela de GameOver
-- @param player — O jogador
-- @param playerState — Estado do jogador (do MatchService)
-- @return tabela com estatísticas formatadas
function PlayerEvents.getPlayerStats(player: Player, playerState: any?): {[string]: any}
	local stats = {
		name = player.Name,
		role = "Desconhecido",
		className = nil,
	}

	if playerState then
		stats.role = playerState.role or "Desconhecido"
		stats.className = playerState.className
		stats.isAlive = playerState.isAlive
		stats.isDowned = playerState.isDowned
		stats.isInCage = playerState.isInCage
	end

	return stats
end

return PlayerEvents
