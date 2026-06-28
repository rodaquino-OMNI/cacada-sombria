--[[
  GameConstants.lua
  Constantes globais de Cacada Sombria
  Compartilhado entre Server e Client via ReplicatedStorage
]]

local GameConstants = {}

-- ==========================================
-- KILLERS
-- ==========================================
GameConstants.Killers = {
  Distorcido = {
    HP = 1100,
    Speed = 26,
    SpeedRage = 28,
    Abilities = {
      -- M1 — Tapa (ataque corpo a corpo)
      M1_Damage = 20,
      M1_Damage_Rage = 25,
      M1_Range = 6,               -- studs de alcance
      M1_Windup = 0.6,            -- segundos de preparação
      M1_Recovery = 0.3,          -- segundos de recuperação
      M1_Cooldown = 0.8,          -- segundos entre ataques

      -- Q — Braço Esticado (puxão)
      Braco_Esticado_Range = 40,  -- studs de alcance
      Braco_Esticado_Width = 2,   -- studs de largura do projétil
      Braco_Esticado_Windup = 0.4,
      Braco_Esticado_Cooldown = 12,
      Braco_Esticado_Stun = 0.5,  -- segundos de atordoamento ao puxar
      Braco_Esticado_Pull_Distance = 4, -- studs de distância após puxar

      -- Medidor de Fúria
      Fury_Max = 100,
      Fury_Gain_Dealing_Damage = 15,
      Fury_Gain_Receiving_Damage = 10,
      Fury_Gain_Rescue_Nearby = 20,
      Fury_Rescue_Range = 40,     -- studs de alcance para ganhar fúria por resgate

      -- R — Rage (Transformação)
      Rage_Duration = 30,         -- segundos de duração
      Rage_Speed = 28,            -- velocidade durante Rage
      Rage_M1_Damage = 25,        -- dano do M1 durante Rage

      -- E — Grito (Scream)
      Grito_Windup = 0.8,
      Grito_Cooldown = 25,
      Grito_Slow_Range = 60,      -- studs para lentidão + blur
      Grito_Slow_Duration = 3,    -- segundos de lentidão/blur
      Grito_Slow_Percent = 0.4,   -- 40% de redução de velocidade
      Grito_Reveal_Range = 100,   -- studs para revelação
      Grito_Reveal_Duration = 4,  -- segundos de revelação
    }
  },
  BonecoDePano = {
    HP = 400,
    Speed = 26,
    Abilities = {
      M1_Damage = 20,
      Dash_Windup = 3,
      Dash_Duration = 10,
      Dash_Damage = 30,
      Dash_Slow_Duration = 3,
      Laser_Duration = 10,
      Laser_HealPerSec = 20,
      Laser_DamagePerSec = 5,
      Laser_Slow_Reveal_Duration = 15,
    }
  },
  Soldado = {
    HP = 1500,
    Speed = 24,
    Abilities = {
      M1_Damage = 30,
      Sentinela_Max = 5,
      Missil_Damage = 35,
      Missil_Explosion_Damage = 5,
      Teleporte_Damage = 20,
      Teleporte_Speed_Duration = 5,
      Teleporte_Windup = 1.5,
    }
  },
  Compasso = {
    HP = 1234,
    Speed = 28,
    Abilities = {
      M1_Damage = 15,
      M1_Bleed_Damage = 10,
      M1_Bleed_Duration = 4,
      Dash_Duration = 10,
      Dash_MaxCaptured = 3,
      Lapis_Damage = 10,
      Lapis_Windup = 1.5,
      Lapis_Stuck_Duration = 20,
      Lapis_Bonus_Damage = 5,
      Lapis_Ragdoll_Duration = 3,
      Recall_Damage = 10,
    }
  },
}

-- ==========================================
-- SURVIVORS
-- ==========================================
GameConstants.Survivors = {
  Base = {
    HP = 120,
    Speed = 22,
    Stamina_Speed_Bonus = 2,
  },
  Soldado = {
    HP = 120,
    Speed = 20,
    Abilities = {
      -- Dash Tático (Q)
      Dash_Cooldown = 12,            -- segundos
      Dash_Speed = 40,               -- studs/s
      Dash_Duration = 0.3,           -- segundos
      Dash_Push_Studs = 10,
      Dash_Silence_Duration = 3,
      -- Bazuca (E)
      Bazooka_Cooldown = 45,         -- segundos
      Bazooka_Range = 200,           -- studs
      Bazooka_Slow = 0.6,            -- multiplicador ao mirar
      Bazooka_Aim_Time = 2,
      Bazooka_Fire_Window = 10,
    }
  },
  Sackboy = {
    HP = 110,
    Speed = 26,
    Abilities = {
      -- Arma de Tinta (Q)
      Tinta_Cooldown = 15,           -- segundos
      Tinta_Range = 30,              -- studs
      Charge_Level1_Slow = 1,
      Charge_Level2_Silence = 4,
      Charge_Level3_Stun = true,
      -- Surto (E)
      Surto_Duration = 5,
      Surto_Speed_Bonus = 6,
      Surto_Jump_Bonus = 1.5,        -- multiplicador
      Surto_Cooldown = 20,           -- segundos
    }
  },
  Robo = {
    HP = 150,
    Speed = 18,
    Abilities = {
      -- Agarrar (Q)
      Agarrar_Cooldown = 20,         -- segundos
      Agarrar_Range = 20,            -- studs
      Agarrar_Killer_Invincible = 8,
      Agarrar_Killer_Silence = 2,
      -- Block (E)
      Block_Cooldown = 15,           -- segundos
      Block_Duration = 1.5,          -- segundos
      Block_Range = 5,               -- studs
      Block_Silence = 3,
      Block_Heal = 10,
      -- Sacrifício (R)
      Sacrificio_Cooldown = 60,      -- segundos
      Sacrificio_Windup = 3,
      Sacrificio_Speed_Boost = 5,    -- segundos de boost extra
      Sacrificio_Speed_Duration = 5,
      Sacrificio_Self_Damage = 40,
      Sacrificio_Self_Slow = 8,
      Sacrificio_Killer_Throw = 100,
      Sacrificio_Killer_Stun = 6,
    }
  },
  Enfermeira = {
    HP = 105,
    Speed = 22,
    Abilities = {
      -- Curativo (Q)
      Curativo_Cooldown = 18,        -- segundos
      Curativo_Range = 10,           -- studs
      Curativo_Channel = 2,
      Curativo_Heal = 25,
      Curativo_Glow_Range = 40,      -- studs, visível ao killer
      -- Adrenalina (E)
      Adrenalina_Cooldown = 30,      -- segundos
      Adrenalina_Range = 15,         -- studs
      Adrenalina_Speed_Bonus = 3,
      Adrenalina_Shield_Duration = 5,
      Adrenalina_Reveal_Duration = 2,
    }
  },
  Campeao = {
    HP = 130,
    Speed = 22,
    Abilities = {
      -- Agarrão (Q)
      Agarron_Cooldown = 15,         -- segundos
      Agarron_Range = 8,              -- studs
      Agarron_Damage = 20,
      Agarron_Throw = 8,
      Agarron_Grounded = 1,
      -- Sequência de 3 Socos (E)
      Sequencia_Cooldown = 12,       -- segundos
      Sequencia_Range = 5,           -- studs
      Sequencia_Hit_Window = 2,      -- segundos máximos entre socos
      Sequencia_Combo_Reduction = 5, -- segundos reduzidos do Agarrão
      Sequencia_Damage_PerHit = 5,
      Sequencia_Third_Bonus = 5,
    }
  },
}

-- ==========================================
-- GAME RULES
-- ==========================================
GameConstants.Game = {
	SurvivorsPerMatch = 4,
	GeneratorsToRepair = 5,
	RepairTime = 8,                  -- seconds per generator (solo)
	MaxCageRescues = 2,              -- times a survivor can be caged
	MatchDuration = 900,             -- 15 minutes

	-- Stamina dos Sobreviventes
	Stamina = {
		Stamina_Max = 100,              -- stamina máxima
		Stamina_Consume_Rate = 20,      -- por segundo correndo
		Stamina_Regen_Rate = 10,        -- por segundo parado/andando
		Stamina_Exhausted_Cooldown = 3, -- segundos sem correr após esgotar
	},
}

-- ==========================================
-- CAPTURA — Épico E6
-- ==========================================
GameConstants.Capture = {
	-- Estado de Derrubado (Down)
	DownBleedOutTime = 60,           -- segundos até morte automática
	DownMoveSpeedMultiplier = 0.3,   -- 30% da velocidade base ao ser derrubado

	-- Transporte (Carry)
	CarryPickupTime = 1.5,           -- segundos para o Killer pegar o Sobrevivente
	CarryKillerSpeedMultiplier = 0.8,-- 80% da velocidade do Killer ao carregar
	CarryCanAttack = false,          -- Killer não pode atacar enquanto carrega
	WiggleTimeToBreak = 10,          -- segundos para o Sobrevivente se libertar
	WiggleBreakStunDuration = 2,     -- segundos de atordoamento no Killer ao se libertar

	-- Jaulas
	CageTotalPositions = 3,          -- posições fixas no mapa (MansionData.Cages)
	CageActivePerMatch = 3,          -- jaulas ativas por partida
	CageDepositTime = 2,             -- segundos para depositar o Sobrevivente
	CageEliminationTime = 120,       -- segundos até eliminação na jaula
	CageMaxRescuesPerSurvivor = 2,   -- máximo de resgates por Sobrevivente (espelho de Game.MaxCageRescues)

	-- Resgate
	RescueChannelTime = 3,           -- segundos de canalização para resgatar
	RescueHPRestorePercent = 0.5,    -- 50% do HP máximo restaurado
	RescueInvulnerabilityTime = 3,   -- segundos de invulnerabilidade após resgate

	-- Integração com Fúria
	FuryRescueGain = 20,             -- Fúria ganha pelo Killer ao presenciar resgate
	FuryRescueRange = 40,            -- studs de alcance para ganhar Fúria por resgate próximo
}

-- ==========================================
-- MAP: Mansão Abandonada
-- ==========================================
GameConstants.MapaMVP = {
  RoomCount = {8, 10},
  Floors = 2,
  HasBasement = true,
  GeneratorCount = 5,
  CageCount = 3,

  -- Esconderijos
  TotalHidingSpots = 15,            -- total de esconderijos no mapa
  ActiveHidingSpotsPerMatch = 12,   -- quantos ficam ativos (3 bloqueados aleatoriamente)
  MaxHidingTime = 20,               -- segundos máximos dentro de um esconderijo

  -- Spawn
  MinSpawnDistance = 30,            -- distância mínima (studs) entre spawn do Killer e Survivor

  -- Iluminação do Porão
  BasementBrightness = 0.2,         -- 20% do brilho normal
  BasementFogDensity = 0.8,         -- densidade da névoa (0 a 1)

  -- Performance Mobile
  MaxParts = 500,                   -- limite de Parts no mapa
  MaxParticleEmitters = 5,          -- limite de emissores de partículas simultâneos
}

return GameConstants
