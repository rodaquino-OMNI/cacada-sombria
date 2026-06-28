--!strict
--[[
	MansionData.lua
	Dados completos da Mansão Abandonada — mapa MVP de Caçada Sombria.

	Contém:
	- Definição de cada cômodo (nome, andar, limites, conexões)
	- Posições dos 15 esconderijos
	- Pontos de spawn (1 Killer, 4+ Survivors)
	- Posições dos geradores (5)
	- Posições das jaulas (3)
	- Configurações de iluminação por cômodo
	- Conexões entre cômodos (portas, escadas, alçapão)

	Todas as coordenadas são em studs (1 stud ≈ 28 cm).
	A origem (0, 0, 0) é o centro do Hall de Entrada (térreo).

	Contexto: Shared (ReplicatedStorage)
	Uso: Tanto o servidor (MapService) quanto o cliente podem referenciar
	      esses dados, mas o servidor É a autoridade.
]]

local MansionData = {}

-- ==========================================
-- CONSTANTES DO MAPA
-- ==========================================

-- Número total de esconderijos no mapa
MansionData.TOTAL_HIDING_SPOTS = 15

-- Quantos esconderijos ficam ativos por partida
MansionData.ACTIVE_HIDING_SPOTS = 12

-- Tempo máximo que um Sobrevivente pode ficar escondido (segundos)
MansionData.MAX_HIDING_TIME = 20

-- Distância mínima entre o spawn do Killer e o spawn de um Survivor (studs)
MansionData.MIN_SPAWN_DISTANCE = 30

-- Quantidade de geradores no mapa
MansionData.GENERATOR_COUNT = 5

-- Quantidade de jaulas no mapa
MansionData.CAGE_COUNT = 3

-- Brilho do porão (0 = escuridão total, 1 = luz normal)
MansionData.BASEMENT_BRIGHTNESS = 0.2

-- Intensidade da névoa no porão
MansionData.BASEMENT_FOG_DENSITY = 0.8

-- ==========================================
-- DEFINIÇÃO DOS CÔMODOS
-- ==========================================

-- Cada cômodo tem:
--   name        — nome em português
--   floor       — "ground" | "upper" | "basement"
--   center      — Vector3 com o centro do cômodo
--   size        — Vector3 com largura (X), altura (Y), profundidade (Z)
--   connections — lista de nomes de cômodos conectados
--   brightness  — multiplicador de brilho (1 = normal)
--   fog         — densidade de névoa (0 = sem névoa)
--   color       — cor da iluminação (Color3)

type RoomDef = {
	name: string,
	floor: string,
	center: Vector3,
	size: Vector3,
	connections: {string},
	brightness: number,
	fog: number,
	color: Color3?,
}

--[[
	LAYOUT DO TÉRREO (Ground Floor):
	
	                    Cozinha
	                   (12x8x16)
	                 ┌───────────┐
	                 │           │
	    Sala de     │  cozinha  │    Escritório
	    Estar       │           │   (10x8x12)
	  (14x8x12)     └─────┬─────┘  ┌──────────┐
	 ┌──────────┐         │        │          │
	 │          │    Corredor      │ escrit.  │
	 │  estar   │    dos Fundos    │          │
	 │          │   (6x8x20)      └────┬─────┘
	 └────┬─────┘         │            │
	      │          ┌────┴────┐       │
	      │          │  Hall   │       │
	      └──────────┤ Entrada ├───────┘
	                 │(14x10x14)│
	                 └────┬─────┘
	                      │
	                 ┌────┴─────┐
	                 │  Sala de │
	                 │  Jantar  │
	                 │(12x8x14) │
	                 └──────────┘
]]

MansionData.Rooms = {}

-- TÉRREO
MansionData.Rooms["HallEntrada"] = {
	name = "Hall de Entrada",
	floor = "ground",
	center = Vector3.new(0, 5, 0),
	size = Vector3.new(14, 10, 14),
	connections = {"SalaEstar", "SalaJantar", "CorredorFundos", "Escritorio"},
	brightness = 0.7,
	fog = 0,
	color = Color3.fromRGB(255, 240, 200), -- luz amarelada de velas
}

MansionData.Rooms["SalaEstar"] = {
	name = "Sala de Estar",
	floor = "ground",
	center = Vector3.new(-16, 5, -8),
	size = Vector3.new(14, 8, 12),
	connections = {"HallEntrada", "CorredorFundos"},
	brightness = 0.5,
	fog = 0,
	color = Color3.fromRGB(220, 200, 160), -- luz âmbar fraca
}

MansionData.Rooms["Cozinha"] = {
	name = "Cozinha",
	floor = "ground",
	center = Vector3.new(-2, 5, -18),
	size = Vector3.new(12, 8, 16),
	connections = {"CorredorFundos", "EscadaPorao"},
	brightness = 0.4,
	fog = 0.1,
	color = Color3.fromRGB(200, 180, 140), -- luz suja / enferrujada
}

MansionData.Rooms["Escritorio"] = {
	name = "Escritório",
	floor = "ground",
	center = Vector3.new(14, 5, -6),
	size = Vector3.new(10, 8, 12),
	connections = {"HallEntrada", "CorredorFundos", "AlcapaoSuperior"},
	brightness = 0.6,
	fog = 0,
	color = Color3.fromRGB(180, 200, 220), -- luz azulada fria (janela)
}

MansionData.Rooms["SalaJantar"] = {
	name = "Sala de Jantar",
	floor = "ground",
	center = Vector3.new(0, 5, 14),
	size = Vector3.new(12, 8, 14),
	connections = {"HallEntrada"},
	brightness = 0.55,
	fog = 0,
	color = Color3.fromRGB(230, 210, 170), -- luz de lustre
}

MansionData.Rooms["CorredorFundos"] = {
	name = "Corredor dos Fundos",
	floor = "ground",
	center = Vector3.new(-8, 5, -12),
	size = Vector3.new(6, 8, 20),
	connections = {"HallEntrada", "SalaEstar", "Cozinha", "Escritorio", "EscadaSuperior"},
	brightness = 0.3,
	fog = 0.15,
	color = Color3.fromRGB(160, 140, 100), -- luz fraca de corredor
}

-- SEGUNDO ANDAR
MansionData.Rooms["CorredorSuperior"] = {
	name = "Corredor Superior",
	floor = "upper",
	center = Vector3.new(-4, 15, -6),
	size = Vector3.new(8, 8, 18),
	connections = {"QuartoPrincipal", "QuartoHospedes", "Banheiro", "EscadaSuperior"},
	brightness = 0.35,
	fog = 0.1,
	color = Color3.fromRGB(150, 130, 100),
}

MansionData.Rooms["QuartoPrincipal"] = {
	name = "Quarto Principal",
	floor = "upper",
	center = Vector3.new(-16, 15, -6),
	size = Vector3.new(14, 8, 14),
	connections = {"CorredorSuperior"},
	brightness = 0.4,
	fog = 0,
	color = Color3.fromRGB(180, 150, 180), -- luz púrpura suave
}

MansionData.Rooms["QuartoHospedes"] = {
	name = "Quarto de Hóspedes",
	floor = "upper",
	center = Vector3.new(5, 15, -2),
	size = Vector3.new(10, 8, 10),
	connections = {"CorredorSuperior"},
	brightness = 0.3,
	fog = 0,
	color = Color3.fromRGB(150, 170, 150), -- luz esverdeada fraca
}

MansionData.Rooms["Banheiro"] = {
	name = "Banheiro",
	floor = "upper",
	center = Vector3.new(5, 15, -15),
	size = Vector3.new(8, 8, 10),
	connections = {"CorredorSuperior"},
	brightness = 0.25,
	fog = 0.2,
	color = Color3.fromRGB(140, 160, 180), -- luz azulada fria
}

-- PORÃO
MansionData.Rooms["Porao"] = {
	name = "Porão",
	floor = "basement",
	center = Vector3.new(-2, -6, -24),
	size = Vector3.new(18, 6, 22),
	connections = {"EscadaPorao"},
	brightness = 0.2,
	fog = 0.8,
	color = Color3.fromRGB(100, 80, 60), -- escuridão quase total
}

-- CONEXÕES ESPECIAIS (escadas e alçapão)
MansionData.Rooms["EscadaSuperior"] = {
	name = "Escada para o 2º Andar",
	floor = "ground", -- começa no térreo, vai até o superior
	center = Vector3.new(-4, 10, -12),
	size = Vector3.new(4, 18, 4),
	connections = {"CorredorFundos", "CorredorSuperior"},
	brightness = 0.3,
	fog = 0.1,
	color = Color3.fromRGB(140, 120, 90),
}

MansionData.Rooms["EscadaPorao"] = {
	name = "Escada para o Porão",
	floor = "ground", -- começa no térreo, desce ao porão
	center = Vector3.new(-2, 0, -22),
	size = Vector3.new(3, 12, 3),
	connections = {"Cozinha", "Porao"},
	brightness = 0.15,
	fog = 0.5,
	color = Color3.fromRGB(80, 60, 40),
}

MansionData.Rooms["AlcapaoSuperior"] = {
	name = "Alçapão Secreto",
	floor = "upper", -- conecta Escritório ao Corredor Superior
	center = Vector3.new(10, 10, -6),
	size = Vector3.new(3, 12, 3),
	connections = {"Escritorio", "CorredorSuperior"},
	brightness = 0.2,
	fog = 0.3,
	color = Color3.fromRGB(100, 90, 70),
}

-- ==========================================
-- ESCONDERIJOS (15 no total)
-- ==========================================

-- Cada esconderijo tem:
--   id      — número identificador (1 a 15)
--   name    — descrição em português
--   room    — nome do cômodo onde está
--   position — Vector3 com a posição exata
--   size    — Vector3 com as dimensões do esconderijo
--   rotation — Vector3 com a rotação (graus)
--   type    — "armario" | "atras_movel" | "cortina" | "bau" | "fresta"

type HidingSpotDef = {
	id: number,
	name: string,
	room: string,
	position: Vector3,
	size: Vector3,
	rotation: Vector3,
	spotType: string,
}

MansionData.HidingSpots = {}

-- Térreo (9 esconderijos)

MansionData.HidingSpots[1] = {
	id = 1,
	name = "Armário do Hall",
	room = "HallEntrada",
	position = Vector3.new(6, 2.5, -4),
	size = Vector3.new(3, 5, 2),
	rotation = Vector3.new(0, 0, 0),
	spotType = "armario",
}

MansionData.HidingSpots[2] = {
	id = 2,
	name = "Atrás do Sofá",
	room = "SalaEstar",
	position = Vector3.new(-22, 2.5, -12),
	size = Vector3.new(4, 4, 2),
	rotation = Vector3.new(0, 0, 0),
	spotType = "atras_movel",
}

MansionData.HidingSpots[3] = {
	id = 3,
	name = "Armário da Sala de Estar",
	room = "SalaEstar",
	position = Vector3.new(-10, 2.5, -2),
	size = Vector3.new(3, 5, 2),
	rotation = Vector3.new(0, 90, 0),
	spotType = "armario",
}

MansionData.HidingSpots[4] = {
	id = 4,
	name = "Dentro da Lareira",
	room = "SalaEstar",
	position = Vector3.new(-22, 2, -2),
	size = Vector3.new(3, 4, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "fresta",
}

MansionData.HidingSpots[5] = {
	id = 5,
	name = "Armário da Cozinha",
	room = "Cozinha",
	position = Vector3.new(-6, 2.5, -22),
	size = Vector3.new(3, 5, 2),
	rotation = Vector3.new(0, 0, 0),
	spotType = "armario",
}

MansionData.HidingSpots[6] = {
	id = 6,
	name = "Atrás da Mesa de Jantar",
	room = "SalaJantar",
	position = Vector3.new(0, 2.5, 20),
	size = Vector3.new(6, 3, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "atras_movel",
}

MansionData.HidingSpots[7] = {
	id = 7,
	name = "Atrás da Estante",
	room = "Escritorio",
	position = Vector3.new(18, 2.5, -10),
	size = Vector3.new(3, 5, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "atras_movel",
}

MansionData.HidingSpots[8] = {
	id = 8,
	name = "Cortina do Corredor",
	room = "CorredorFundos",
	position = Vector3.new(-10, 2.5, -16),
	size = Vector3.new(1, 6, 4),
	rotation = Vector3.new(0, 0, 0),
	spotType = "cortina",
}

MansionData.HidingSpots[9] = {
	id = 9,
	name = "Baú no Corredor",
	room = "CorredorFundos",
	position = Vector3.new(-6, 1.5, -8),
	size = Vector3.new(3, 3, 4),
	rotation = Vector3.new(0, 0, 0),
	spotType = "bau",
}

-- Segundo Andar (4 esconderijos)

MansionData.HidingSpots[10] = {
	id = 10,
	name = "Guarda-Roupa do Quarto Principal",
	room = "QuartoPrincipal",
	position = Vector3.new(-22, 18, -10),
	size = Vector3.new(4, 6, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "armario",
}

MansionData.HidingSpots[11] = {
	id = 11,
	name = "Embaixo da Cama (Quarto Principal)",
	room = "QuartoPrincipal",
	position = Vector3.new(-12, 16, -2),
	size = Vector3.new(5, 2, 4),
	rotation = Vector3.new(0, 0, 0),
	spotType = "fresta",
}

MansionData.HidingSpots[12] = {
	id = 12,
	name = "Armário do Quarto de Hóspedes",
	room = "QuartoHospedes",
	position = Vector3.new(10, 18, 2),
	size = Vector3.new(3, 5, 2),
	rotation = Vector3.new(0, 90, 0),
	spotType = "armario",
}

MansionData.HidingSpots[13] = {
	id = 13,
	name = "Atrás da Banheira",
	room = "Banheiro",
	position = Vector3.new(8, 16, -20),
	size = Vector3.new(3, 4, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "atras_movel",
}

-- Porão (2 esconderijos)

MansionData.HidingSpots[14] = {
	id = 14,
	name = "Atrás das Caixas (Porão)",
	room = "Porao",
	position = Vector3.new(6, -4, -30),
	size = Vector3.new(4, 4, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "atras_movel",
}

MansionData.HidingSpots[15] = {
	id = 15,
	name = "Barril Velho (Porão)",
	room = "Porao",
	position = Vector3.new(-8, -4, -18),
	size = Vector3.new(3, 4, 3),
	rotation = Vector3.new(0, 0, 0),
	spotType = "fresta",
}

-- ==========================================
-- PONTOS DE SPAWN
-- ==========================================

-- Spawn do Killer: fixo no Hall de Entrada
MansionData.KillerSpawn = {
	position = Vector3.new(0, 5, 4),
	lookAt = Vector3.new(0, 5, -20), -- olhando para o fundo da mansão
}

-- Spawns dos Sobreviventes: 6 possíveis, 4 usados aleatoriamente por partida
MansionData.SurvivorSpawns = {
	{
		id = 1,
		room = "SalaEstar",
		position = Vector3.new(-20, 5, -6),
		lookAt = Vector3.new(-8, 5, -6),
	},
	{
		id = 2,
		room = "Cozinha",
		position = Vector3.new(-4, 5, -24),
		lookAt = Vector3.new(-4, 5, -12),
	},
	{
		id = 3,
		room = "Escritorio",
		position = Vector3.new(18, 5, -4),
		lookAt = Vector3.new(8, 5, -4),
	},
	{
		id = 4,
		room = "SalaJantar",
		position = Vector3.new(0, 5, 20),
		lookAt = Vector3.new(0, 5, 6),
	},
	{
		id = 5,
		room = "QuartoPrincipal",
		position = Vector3.new(-20, 15, -4),
		lookAt = Vector3.new(-8, 15, -4),
	},
	{
		id = 6,
		room = "QuartoHospedes",
		position = Vector3.new(8, 15, 2),
		lookAt = Vector3.new(0, 15, -4),
	},
}

-- ==========================================
-- GERADORES (5)
-- ==========================================

MansionData.Generators = {
	{
		id = 1,
		name = "Gerador do Hall",
		room = "HallEntrada",
		position = Vector3.new(-4, 3, -4),
	},
	{
		id = 2,
		name = "Gerador da Sala de Estar",
		room = "SalaEstar",
		position = Vector3.new(-10, 3, -14),
	},
	{
		id = 3,
		name = "Gerador da Cozinha",
		room = "Cozinha",
		position = Vector3.new(4, 3, -20),
	},
	{
		id = 4,
		name = "Gerador do Escritório",
		room = "Escritorio",
		position = Vector3.new(12, 3, -12),
	},
	{
		id = 5,
		name = "Gerador do Quarto Principal",
		room = "QuartoPrincipal",
		position = Vector3.new(-18, 13, -12),
	},
}

-- ==========================================
-- JAULAS (3)
-- ==========================================

MansionData.Cages = {
	{
		id = 1,
		name = "Jaula do Porão",
		room = "Porao",
		position = Vector3.new(0, -4, -26),
	},
	{
		id = 2,
		name = "Jaula do Corredor dos Fundos",
		room = "CorredorFundos",
		position = Vector3.new(-8, 4, -6),
	},
	{
		id = 3,
		name = "Jaula do Corredor Superior",
		room = "CorredorSuperior",
		position = Vector3.new(-8, 14, -10),
	},
}

-- ==========================================
-- PORTAS / CONEXÕES FÍSICAS
-- ==========================================

-- Posições das portas entre cômodos (para construir no Studio)
MansionData.Doors = {
	-- Térreo
	{ from = "HallEntrada", to = "SalaEstar", position = Vector3.new(-7, 4, -4), size = Vector3.new(3, 7, 0.5) },
	{ from = "HallEntrada", to = "SalaJantar", position = Vector3.new(0, 4, 7), size = Vector3.new(3, 7, 0.5) },
	{ from = "HallEntrada", to = "Escritorio", position = Vector3.new(7, 4, -2), size = Vector3.new(3, 7, 0.5) },
	{ from = "HallEntrada", to = "CorredorFundos", position = Vector3.new(-4, 4, -5), size = Vector3.new(3, 7, 0.5) },
	{ from = "SalaEstar", to = "CorredorFundos", position = Vector3.new(-14, 4, -10), size = Vector3.new(0.5, 7, 3) },
	{ from = "Cozinha", to = "CorredorFundos", position = Vector3.new(-6, 4, -16), size = Vector3.new(3, 7, 0.5) },
	{ from = "Escritorio", to = "CorredorFundos", position = Vector3.new(10, 4, -10), size = Vector3.new(0.5, 7, 3) },

	-- Superior
	{ from = "CorredorSuperior", to = "QuartoPrincipal", position = Vector3.new(-11, 14, -6), size = Vector3.new(0.5, 7, 3) },
	{ from = "CorredorSuperior", to = "QuartoHospedes", position = Vector3.new(0, 14, 0), size = Vector3.new(3, 7, 0.5) },
	{ from = "CorredorSuperior", to = "Banheiro", position = Vector3.new(1, 14, -10), size = Vector3.new(0.5, 7, 3) },
}

-- ==========================================
-- CONFIGURAÇÕES DE ILUMINAÇÃO POR ANDAR
-- ==========================================

MansionData.Lighting = {
	-- Iluminação global do mapa
	Ambient = Color3.fromRGB(60, 50, 70),      -- tom roxo-escuro (noite)
	OutdoorAmbient = Color3.fromRGB(30, 35, 60), -- noite externa
	Brightness = 0.5,                            -- brilho base reduzido
	ClockTime = 2,                               -- 2h da manhã (lua cheia)
	FogStart = 80,                               -- névoa começa a 80 studs
	FogEnd = 200,                                -- névoa total a 200 studs
	FogColor = Color3.fromRGB(40, 45, 60),       -- névoa azul-escura
	ShadowSoftness = 0.8,                        -- sombras suaves (dramáticas)

	-- Feixes de luz da lua (para construir no Studio)
	MoonBeams = {
		{ room = "SalaEstar", position = Vector3.new(-16, 10, 2), direction = Vector3.new(0, -1, 1) },
		{ room = "Escritorio", position = Vector3.new(20, 10, -2), direction = Vector3.new(-1, -1, 0) },
		{ room = "QuartoPrincipal", position = Vector3.new(-22, 20, -2), direction = Vector3.new(1, -1, 0) },
		{ room = "CorredorFundos", position = Vector3.new(-10, 10, -20), direction = Vector3.new(0, -0.7, 1) },
	},
}

return MansionData
