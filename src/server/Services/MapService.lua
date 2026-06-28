--!strict
--[[
	MapService.lua
	Serviço que gerencia o estado do mapa da partida.

	Responsável por:
	- Carregar dados da Mansão (MansionData)
	- Selecionar esconderijos ativos (12 de 15 aleatórios)
	- Bloquear 3 esconderijos aleatórios por partida
	- Gerenciar entradas/saídas de esconderijos (validação server-side)
	- Verificar limite de tempo nos esconderijos (20s)
	- Selecionar pontos de spawn dos Sobreviventes (min 30 studs do Killer)
	- Expor informações de cômodos e iluminação
	- Aplicar configurações de iluminação (dramática, porão escuro, névoa)

	Autoridade: 100% server-side. O servidor decide quais esconderijos
	estão ativos, bloqueados e onde cada jogador spawna.

	Contexto: Server (ServerScriptService)
]]

-- ==========================================
-- SERVICES DO ROBLOX (cache no topo por performance)
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

-- ==========================================
-- DEPENDÊNCIAS
-- ==========================================
local GameConstants = require(ReplicatedStorage.GameConstants)
local MansionData = require(ReplicatedStorage.MapData.MansionData)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)

-- ==========================================
-- CONSTANTES LOCAIS
-- ==========================================
local TOTAL_SPOTS = MansionData.TOTAL_HIDING_SPOTS       -- 15
local ACTIVE_SPOTS = MansionData.ACTIVE_HIDING_SPOTS     -- 12
local BLOCKED_SPOTS = TOTAL_SPOTS - ACTIVE_SPOTS         -- 3
local MAX_HIDING_TIME = MansionData.MAX_HIDING_TIME      -- 20s
local MIN_SPAWN_DISTANCE = MansionData.MIN_SPAWN_DISTANCE -- 30 studs

-- ==========================================
-- SERVIÇO MAPSERVICE
-- ==========================================
local MapService = {}
MapService.__index = MapService

-- ==========================================
-- SINAIS (PUB/SUB)
-- ==========================================
-- Outros serviços podem se conectar a estes sinais para reagir a eventos do mapa
MapService.MapLoaded = Signal.new()                -- Mapa carregado e configurado
MapService.HidingSpotEntered = Signal.new()        -- player entrou em esconderijo
MapService.HidingSpotExited = Signal.new()         -- player saiu de esconderijo
MapService.HidingSpotBlocked = Signal.new()        -- lista de esconderijos bloqueados definida
MapService.LightingApplied = Signal.new()          -- iluminação configurada

-- ==========================================
-- ESTADO INTERNO
-- ==========================================

-- Conjunto de IDs de esconderijos ativos nesta partida
local _activeHidingSpots: {[number]: boolean} = {}

-- Conjunto de IDs de esconderijos bloqueados nesta partida
local _blockedHidingSpots: {[number]: boolean} = {}

-- Referências aos RemoteEvents (setados durante Init)
local _gameStateEvent: RemoteEvent?
local _uiSyncEvent: RemoteEvent?

-- Referência ao MatchService (setada durante Init)
local _matchService: any = nil

-- Flag: o mapa já foi carregado?
local _isLoaded = false

-- Referência ao modelo do mapa no Workspace
local _mapModel: Model?

-- IDs dos esconderijos que estão ocupados neste momento
-- Chave: hidingSpotId, Valor: userId do jogador ocupante
local _occupiedSpots: {[number]: number} = {}

-- ==========================================
-- INICIALIZAÇÃO (PADRÃO Init/Start)
-- ==========================================

-- Fase Init: setup síncrono, conecta eventos e dependências
-- Chamado pelo GameManager no startup do servidor
function MapService.Init(gameStateEvent: RemoteEvent, uiSyncEvent: RemoteEvent, matchService: any)
	_gameStateEvent = gameStateEvent
	_uiSyncEvent = uiSyncEvent
	_matchService = matchService

	print("[CacadaSombria] MapService inicializado. (Init)")
end

-- Fase Start: inicialização assíncrona, pode usar task.wait
-- Aguarda o mapa estar disponível no Workspace e configura iluminação
function MapService.Start()
	print("[CacadaSombria] MapService: Aguardando carregamento do mapa...")

	-- Aguarda o modelo do mapa aparecer no Workspace
	_mapModel = Workspace:WaitForChild("Map", 15)
	if not _mapModel then
		warn("[CacadaSombria] MapService: Modelo 'Map' não encontrado no Workspace após 15s!")
		warn("[CacadaSombria] MapService: O desenvolvedor precisa construir o mapa no Roblox Studio.")
		warn("[CacadaSombria] MapService: Consulte docs/map-setup-guide.md para instruções.")
		return
	end

	print(string.format("[CacadaSombria] MapService: Mapa '%s' encontrado no Workspace.", _mapModel.Name))

	-- Configura iluminação dramática
	MapService:_applyLighting()

	-- Seleciona esconderijos aleatórios para esta partida
	MapService:_selectHidingSpots()

	-- Configura os esconderijos no Workspace
	MapService:_setupHidingSpotsInWorld()

	_isLoaded = true

	-- Dispara sinal de mapa carregado
	MapService.MapLoaded:Fire()
	print("[CacadaSombria] MapService: Mapa carregado e configurado com sucesso!")
	print(string.format("[CacadaSombria] MapService: %d/%d esconderijos ativos, %d bloqueados.",
		ACTIVE_SPOTS, TOTAL_SPOTS, BLOCKED_SPOTS))
end

-- ==========================================
-- ILUMINAÇÃO DRAMÁTICA
-- ==========================================

-- Aplica as configurações de iluminação definidas em MansionData.Lighting
function MapService:_applyLighting()
	local lightCfg = MansionData.Lighting

	-- Iluminação global
	Lighting.Ambient = lightCfg.Ambient
	Lighting.OutdoorAmbient = lightCfg.OutdoorAmbient
	Lighting.Brightness = lightCfg.Brightness
	Lighting.ClockTime = lightCfg.ClockTime
	Lighting.FogStart = lightCfg.FogStart
	Lighting.FogEnd = lightCfg.FogEnd
	Lighting.FogColor = lightCfg.FogColor
	Lighting.ShadowSoftness = lightCfg.ShadowSoftness

	-- Tecnologia de iluminação: Future (mais realista) ou ShadowMap (mais performático)
	-- Future é mais dramático para o terror; se causar problemas de performance no mobile, usar ShadowMap
	Lighting.Technology = Enum.Technology.Future

	print("[CacadaSombria] MapService: Iluminação dramática aplicada.")
	print(string.format("[CacadaSombria] MapService: Brilho=%.1f, Névoa=%d-%d studs, Relógio=%dh",
		lightCfg.Brightness, lightCfg.FogStart, lightCfg.FogEnd, lightCfg.ClockTime))

	MapService.LightingApplied:Fire()
end

-- ==========================================
-- SELEÇÃO DE ESCONDERIJOS
-- ==========================================

-- Seleciona aleatoriamente 12 de 15 esconderijos para ficarem ativos.
-- Os 3 bloqueados são escolhidos aleatoriamente e ficam visivelmente trancados.
function MapService:_selectHidingSpots()
	-- Cria uma lista com todos os IDs (1 a 15)
	local allIds = {}
	for i = 1, TOTAL_SPOTS do
		table.insert(allIds, i)
	end

	-- Embaralha usando Fisher-Yates
	for i = #allIds, 2, -1 do
		local j = Random.new():NextInteger(1, i)
		allIds[i], allIds[j] = allIds[j], allIds[i]
	end

	-- Os primeiros ACTIVE_SPOTS são ativos
	for i = 1, ACTIVE_SPOTS do
		_activeHidingSpots[allIds[i]] = true
	end

	-- Os últimos BLOCKED_SPOTS são bloqueados
	for i = ACTIVE_SPOTS + 1, TOTAL_SPOTS do
		_blockedHidingSpots[allIds[i]] = true
	end

	-- Log dos esconderijos bloqueados para debug
	local blockedNames = {}
	for id in _blockedHidingSpots do
		local spot = MansionData.HidingSpots[id]
		if spot then
			table.insert(blockedNames, string.format("#%d %s", id, spot.name))
		end
	end
	print(string.format("[CacadaSombria] MapService: Esconderijos bloqueados: %s",
		table.concat(blockedNames, ", ")))

	-- Dispara sinal para outros serviços saberem quais estão bloqueados
	MapService.HidingSpotBlocked:Fire(_blockedHidingSpots)
end

-- Configura os esconderijos no Workspace (marca bloqueados visualmente)
function MapService:_setupHidingSpotsInWorld()
	if not _mapModel then return end

	-- Procura por Parts com o atributo "HidingSpot" dentro do mapa
	for _, child: Instance in _mapModel:GetDescendants() do
		if child:IsA("BasePart") then
			local spotId: number? = child:GetAttribute("HidingSpotId")
			if spotId then
				if _blockedHidingSpots[spotId] then
					-- Marca visualmente como bloqueado (cor escura, trancado)
					child.Color = Color3.fromRGB(40, 30, 20) -- marrom escuro = trancado
					child.Material = Enum.Material.WoodPlanks
					-- Adiciona uma placa de "trancado" como atributo
					child:SetAttribute("IsBlocked", true)
				elseif _activeHidingSpots[spotId] then
					-- Ativo: cor normal, interagível
					child:SetAttribute("IsBlocked", false)
					child:SetAttribute("IsOccupied", false)
				end
			end
		end
	end

	print("[CacadaSombria] MapService: Esconderijos configurados no Workspace.")
end

-- ==========================================
-- GERENCIAMENTO DE ESCONDERIJOS
-- ==========================================

-- Verifica se um esconderijo está ativo (não bloqueado)
-- @param spotId — ID do esconderijo (1 a 15)
-- @return boolean — true se o esconderijo pode ser usado
function MapService:isHidingSpotActive(spotId: number): boolean
	return _activeHidingSpots[spotId] == true and not _blockedHidingSpots[spotId]
end

-- Verifica se um esconderijo está ocupado
-- @param spotId — ID do esconderijo
-- @return boolean — true se tem alguém dentro
function MapService:isHidingSpotOccupied(spotId: number): boolean
	return _occupiedSpots[spotId] ~= nil
end

-- Tenta entrar em um esconderijo
-- @param player — O jogador tentando entrar
-- @param spotId — ID do esconderijo (1 a 15)
-- @return boolean, string — sucesso e mensagem de erro (se falhou)
function MapService:tryEnterHidingSpot(player: Player, spotId: number): (boolean, string?)
	-- Validações server-side

	-- 1. O esconderijo está ativo?
	if not self:isHidingSpotActive(spotId) then
		return false, "Esconderijo bloqueado ou inexistente."
	end

	-- 2. O esconderijo já está ocupado?
	if self:isHidingSpotOccupied(spotId) then
		return false, "Esconderijo já está ocupado."
	end

	-- 3. O jogador existe na partida?
	if not _matchService then
		return false, "MatchService não disponível."
	end
	local state = _matchService:getPlayerState(player)
	if not state then
		return false, "Jogador não está na partida."
	end

	-- 4. Apenas Sobreviventes podem se esconder
	if state.role ~= "Survivor" then
		return false, "Apenas Sobreviventes podem se esconder."
	end

	-- 5. Já está escondido?
	if state.isHiding then
		return false, "Você já está escondido."
	end

	-- 6. Está vivo?
	if not state.isAlive then
		return false, "Você está derrubado."
	end

	-- 7. Verifica distância até o esconderijo
	local spotData = MansionData.HidingSpots[spotId]
	if not spotData then
		return false, "Dados do esconderijo não encontrados."
	end

	if state.character then
		local rootPart: BasePart? = state.character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (rootPart.Position - spotData.position).Magnitude
			if dist > 5 then
				return false, string.format("Muito longe do esconderijo (%.1f studs).", dist)
			end
		end
	end

	-- Marca como ocupado (reserva para evitar dois jogadores entrarem ao mesmo tempo)
	_occupiedSpots[spotId] = player.UserId

	-- Atualiza o atributo no Workspace
	MapService:_updateHidingSpotAttribute(spotId, "IsOccupied", true)

	-- Notifica o MatchService para aplicar o estado de hiding
	-- (o MatchService já tem _handleEnterHiding que gerencia transparência etc.)
	-- O MapService gerencia apenas a reserva e validação

	print(string.format("[CacadaSombria] MapService: %s entrou no esconderijo #%d (%s)",
		player.Name, spotId, spotData.name))

	MapService.HidingSpotEntered:Fire(player, spotId)

	return true, nil
end

-- Sai de um esconderijo
-- @param player — O jogador saindo
-- @param spotId — ID do esconderijo
function MapService:exitHidingSpot(player: Player, spotId: number)
	-- Remove a ocupação
	if _occupiedSpots[spotId] == player.UserId then
		_occupiedSpots[spotId] = nil
		MapService:_updateHidingSpotAttribute(spotId, "IsOccupied", false)

		local spotData = MansionData.HidingSpots[spotId]
		local spotName = spotData and spotData.name or "desconhecido"
		print(string.format("[CacadaSombria] MapService: %s saiu do esconderijo #%d (%s)",
			player.Name, spotId, spotName))
	end

	MapService.HidingSpotExited:Fire(player, spotId)
end

-- Atualiza um atributo em um esconderijo no Workspace
function MapService:_updateHidingSpotAttribute(spotId: number, attributeName: string, value: any)
	if not _mapModel then return end

	for _, child: Instance in _mapModel:GetDescendants() do
		if child:IsA("BasePart") then
			local childSpotId = child:GetAttribute("HidingSpotId")
			if childSpotId == spotId then
				child:SetAttribute(attributeName, value)
				break
			end
		end
	end
end

-- Verifica os timeouts dos esconderijos (chamado periodicamente pelo game loop)
-- Força a saída de jogadores que excederam o tempo máximo de 20 segundos
function MapService:checkHidingTimeouts()
	if not _matchService then return end

	for spotId, userId in _occupiedSpots do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			-- Jogador desconectou, limpa ocupação
			_occupiedSpots[spotId] = nil
			MapService:_updateHidingSpotAttribute(spotId, "IsOccupied", false)
			continue
		end

		local state = _matchService:getPlayerState(player)
		if not state or not state.isHiding then
			-- Estado inconsistente: jogador não está mais escondido mas spot está ocupado
			_occupiedSpots[spotId] = nil
			MapService:_updateHidingSpotAttribute(spotId, "IsOccupied", false)
			continue
		end

		-- Verifica se excedeu o tempo máximo
		if state.hidingEnterTime then
			local elapsed = os.clock() - state.hidingEnterTime
			if elapsed > MAX_HIDING_TIME then
				print(string.format("[CacadaSombria] MapService: %s excedeu %ds no esconderijo #%d. Expulsando...",
					player.Name, MAX_HIDING_TIME, spotId))
				-- Força a saída via MatchService
				if _matchService._handleExitHiding then
					_matchService:_handleExitHiding(state)
				end
				_occupiedSpots[spotId] = nil
				MapService:_updateHidingSpotAttribute(spotId, "IsOccupied", false)
				MapService.HidingSpotExited:Fire(player, spotId)
			end
		end
	end
end

-- ==========================================
-- SELEÇÃO DE SPAWN DOS SOBREVIVENTES
-- ==========================================

-- Seleciona spawn points aleatórios para os Sobreviventes,
-- garantindo distância mínima do spawn do Killer (30 studs)
-- @param survivorCount — Quantos Sobreviventes vão spawnar (normalmente 4)
-- @return tabela de spawns selecionados (cada um com position e lookAt)
function MapService:selectSurvivorSpawns(survivorCount: number?): {{position: Vector3, lookAt: Vector3, id: number, room: string}}
	local count = survivorCount or GameConstants.Game.SurvivorsPerMatch -- 4
	local allSpawns = MansionData.SurvivorSpawns
	local killerSpawnPos = MansionData.KillerSpawn.position

	-- Cria lista de índices dos spawns disponíveis
	local availableIndices = {}
	for i = 1, #allSpawns do
		table.insert(availableIndices, i)
	end

	-- Embaralha
	for i = #availableIndices, 2, -1 do
		local j = Random.new():NextInteger(1, i)
		availableIndices[i], availableIndices[j] = availableIndices[j], availableIndices[i]
	end

	-- Seleciona os primeiros 'count' spawns que respeitem a distância mínima
	local selected = {}
	local checkedIndices = 0

	for _, idx in availableIndices do
		if #selected >= count then break end

		local spawn = allSpawns[idx]
		local dist = (spawn.position - killerSpawnPos).Magnitude

		if dist >= MIN_SPAWN_DISTANCE then
			table.insert(selected, {
				id = spawn.id,
				position = spawn.position,
				lookAt = spawn.lookAt,
				room = spawn.room,
			})
			print(string.format("[CacadaSombria] MapService: Spawn #%d selecionado para Survivor (%s, %.0f studs do Killer)",
				spawn.id, spawn.room, dist))
		else
			print(string.format("[CacadaSombria] MapService: Spawn #%d rejeitado — muito perto do Killer (%.0f studs)",
				spawn.id, dist))
		end

		checkedIndices = checkedIndices + 1
		if checkedIndices >= #allSpawns then break end
	end

	-- Fallback: se não conseguiu spawns suficientes, pega os mais distantes
	if #selected < count then
		warn(string.format("[CacadaSombria] MapService: Apenas %d/%d spawns atenderam distância mínima. Usando fallback...",
			#selected, count))

		-- Ordena os restantes por distância decrescente
		local remaining = {}
		for _, idx in availableIndices do
			local alreadySelected = false
			for _, s in selected do
				if s.id == allSpawns[idx].id then
					alreadySelected = true
					break
				end
			end
			if not alreadySelected then
				local spawn = allSpawns[idx]
				table.insert(remaining, {
					idx = idx,
					dist = (spawn.position - killerSpawnPos).Magnitude,
				})
			end
		end

		table.sort(remaining, function(a, b) return a.dist > b.dist end)

		for _, entry in remaining do
			if #selected >= count then break end
			local spawn = allSpawns[entry.idx]
			table.insert(selected, {
				id = spawn.id,
				position = spawn.position,
				lookAt = spawn.lookAt,
				room = spawn.room,
			})
			print(string.format("[CacadaSombria] MapService: Spawn #%d (fallback) selecionado (%s, %.0f studs do Killer)",
				spawn.id, spawn.room, entry.dist))
		end
	end

	print(string.format("[CacadaSombria] MapService: %d spawns de Survivor selecionados.", #selected))
	return selected
end

-- Retorna o spawn fixo do Killer
-- @return tabela com position e lookAt
function MapService:getKillerSpawn(): {position: Vector3, lookAt: Vector3}
	return MansionData.KillerSpawn
end

-- ==========================================
-- ACESSO A DADOS DO MAPA
-- ==========================================

-- Retorna os dados de um cômodo específico
-- @param roomKey — Chave do cômodo (ex: "HallEntrada")
-- @return RoomDef ou nil
function MapService:getRoomData(roomKey: string): any?
	return MansionData.Rooms[roomKey]
end

-- Retorna a lista de todos os cômodos
-- @return tabela com todas as RoomDef
function MapService:getAllRooms(): any
	return MansionData.Rooms
end

-- Retorna os cômodos de um andar específico
-- @param floor — "ground", "upper" ou "basement"
-- @return tabela com RoomDef filtradas
function MapService:getRoomsByFloor(floor: string): {any}
	local result = {}
	for key, room in MansionData.Rooms do
		if room.floor == floor then
			table.insert(result, room)
		end
	end
	return result
end

-- Retorna os dados de um esconderijo específico
-- @param spotId — ID do esconderijo (1 a 15)
-- @return HidingSpotDef ou nil
function MapService:getHidingSpotData(spotId: number): any?
	return MansionData.HidingSpots[spotId]
end

-- Retorna todos os esconderijos ativos nesta partida
-- @return tabela com HidingSpotDef ativas
function MapService:getActiveHidingSpots(): {any}
	local result = {}
	for id, spot in MansionData.HidingSpots do
		if _activeHidingSpots[id] then
			table.insert(result, spot)
		end
	end
	return result
end

-- Retorna todos os esconderijos bloqueados nesta partida
-- @return tabela com HidingSpotDef bloqueadas
function MapService:getBlockedHidingSpots(): {any}
	local result = {}
	for id, spot in MansionData.HidingSpots do
		if _blockedHidingSpots[id] then
			table.insert(result, spot)
		end
	end
	return result
end

-- Retorna os dados de todos os geradores
-- @return tabela com GeneratorDef
function MapService:getAllGenerators(): any
	return MansionData.Generators
end

-- Retorna os dados de todas as jaulas
-- @return tabela com CageDef
function MapService:getAllCages(): any
	return MansionData.Cages
end

-- Retorna os dados de todas as portas/conexões
-- @return tabela com DoorDef
function MapService:getAllDoors(): any
	return MansionData.Doors
end

-- ==========================================
-- UTILITÁRIOS DE MAPA
-- ==========================================

-- Verifica se uma posição está dentro de um cômodo específico
-- @param position — Vector3 da posição a verificar
-- @param roomKey — Chave do cômodo
-- @return boolean
function MapService:isPositionInRoom(position: Vector3, roomKey: string): boolean
	local room = MansionData.Rooms[roomKey]
	if not room then return false end

	local halfSize = room.size / 2
	local min = room.center - halfSize
	local max = room.center + halfSize

	return position.X >= min.X and position.X <= max.X
		and position.Y >= min.Y and position.Y <= max.Y
		and position.Z >= min.Z and position.Z <= max.Z
end

-- Encontra em qual cômodo uma posição está
-- @param position — Vector3
-- @return string (roomKey) ou nil
function MapService:findRoomAtPosition(position: Vector3): string?
	for key, room in MansionData.Rooms do
		local halfSize = room.size / 2
		local min = room.center - halfSize
		local max = room.center + halfSize

		if position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y
			and position.Z >= min.Z and position.Z <= max.Z then
			return key
		end
	end
	return nil
end

-- Calcula a distância entre dois jogadores
-- @return number (studs) ou nil se não for possível calcular
function MapService:getDistanceBetweenPlayers(player1: Player, player2: Player): number?
	if _matchService and _matchService.getDistanceBetween then
		return _matchService:getDistanceBetween(player1, player2)
	end

	-- Fallback: calcula direto
	local char1 = player1.Character
	local char2 = player2.Character
	if not char1 or not char2 then return nil end

	local root1: BasePart? = char1:FindFirstChild("HumanoidRootPart")
	local root2: BasePart? = char2:FindFirstChild("HumanoidRootPart")
	if not root1 or not root2 then return nil end

	return (root1.Position - root2.Position).Magnitude
end

-- ==========================================
-- GAME LOOP (ATUALIZAÇÃO PERIÓDICA)
-- ==========================================

-- Chamado a cada frame ou a cada N segundos para verificar timeouts
-- Deve ser conectado ao RunService.Heartbeat (ou um timer)
function MapService:update(dt: number)
	if not _isLoaded then return end

	-- Verifica timeouts de esconderijos a cada 1 segundo (não precisa todo frame)
	-- Usamos um contador interno para não chamar toda iteração
	self._timeSinceLastCheck = (self._timeSinceLastCheck or 0) + dt
	if self._timeSinceLastCheck >= 1.0 then
		self._timeSinceLastCheck = 0
		MapService:checkHidingTimeouts()
	end
end

-- ==========================================
-- ESTADO DO MAPA
-- ==========================================

-- Retorna se o mapa está carregado e pronto
-- @return boolean
function MapService:isLoaded(): boolean
	return _isLoaded
end

-- Retorna o modelo do mapa (para outros serviços manipularem)
-- @return Model ou nil
function MapService:getMapModel(): Model?
	return _mapModel
end

-- ==========================================
-- LIMPEZA
-- ==========================================

-- Chamado ao final da partida para resetar o estado do mapa
function MapService:resetForNewMatch()
	-- Limpa ocupações de esconderijos
	_occupiedSpots = {}
	_activeHidingSpots = {}
	_blockedHidingSpots = {}

	-- Reseleciona esconderijos para a próxima partida
	MapService:_selectHidingSpots()

	if _mapModel then
		MapService:_setupHidingSpotsInWorld()
	end

	print("[CacadaSombria] MapService: Estado resetado para nova partida.")
end

-- Limpa completamente o serviço (fim do jogo)
function MapService:Destroy()
	_activeHidingSpots = {}
	_blockedHidingSpots = {}
	_occupiedSpots = {}
	_isLoaded = false
	_mapModel = nil

	print("[CacadaSombria] MapService destruído.")
end

return MapService
