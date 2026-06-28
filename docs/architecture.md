# Arquitetura do Jogo — Caçada Sombria

**Autor:** familia
**Data:** 28 de Junho de 2026
**Versão:** 1.0
**Plataforma:** Roblox (Luau)
**Idioma:** PT-BR

---

## Resumo Executivo

Este documento define a arquitetura técnica de **Caçada Sombria**, um jogo de terror assimétrico PvP para Roblox. A arquitetura segue o modelo **cliente-servidor** nativo do Roblox, com **validação 100% server-side** e comunicação via `RemoteEvent`/`RemoteFunction`. Toda a lógica de jogo é autoritativa no servidor; os clientes são responsáveis apenas por input, renderização e HUD.

O projeto é desenvolvido por um desenvolvedor iniciante em Roblox Studio e Luau. Por isso, a arquitetura prioriza **simplicidade, clareza e padrões bem documentados**, evitando frameworks externos desnecessários. O MVP usa **host local como servidor** (sem DataStore, sem servidores dedicados).

---

## Estrutura de Pastas do Projeto

```
src/
├── server/                          → ServerScriptService
│   ├── GameManager.server.lua       ← Script principal do servidor (init, game loop)
│   ├── Services/                    ← Módulos de lógica de jogo (ModuleScripts)
│   │   ├── MatchService.lua         ← Gerenciamento do fluxo da partida
│   │   ├── KillerService.lua        ← Lógica do Caçador (HP, habilidades, rage)
│   │   ├── SurvivorService.lua      ← Lógica dos Sobreviventes (HP, stamina, classes)
│   │   ├── GeneratorService.lua     ← Geradores (reparo, progresso, skill checks)
│   │   ├── CaptureService.lua       ← Captura (down, carry, jaula, resgate)
│   │   ├── ObjectiveService.lua     ← Condições de vitória/derrota
│   │   └── AudioService.lua         ← Gerenciamento de áudio dinâmico
│   └── Events/                      ← Handlers de eventos do servidor
│       ├── PlayerEvents.lua         ← Entrada/saída de jogadores
│       ├── KillerEvents.lua         ← Handlers para ações do Caçador
│       ├── SurvivorEvents.lua       ← Handlers para ações de Sobreviventes
│       └── GameEvents.lua           ← Handlers para eventos de jogo
│
├── client/                          → StarterPlayerScripts
│   ├── ClientManager.client.lua     ← Script principal do cliente (HUD, input, câmera)
│   ├── UI/                          ← HUD e menus
│   │   ├── SurvivorHUD.lua          ← HUD do Sobrevivente (HP, stamina, habilidades)
│   │   ├── KillerHUD.lua            ← HUD do Caçador (fúria, habilidades, contador)
│   │   ├── GameOverUI.lua           ← Tela de resultado (vitória/derrota)
│   │   └── CharacterSelectUI.lua    ← Tela de seleção de personagem
│   ├── Input/                       ← Sistema de input
│   │   └── InputManager.lua         ← Mapeamento de teclas → ações
│   └── Camera/                      ← Sistema de câmera
│       └── CameraManager.lua        ← 1ª pessoa (Caçador) / 3ª pessoa (Sobrevivente)
│
├── shared/                          → ReplicatedStorage
│   ├── GameConstants.lua            ← Constantes globais (HP, velocidades, danos)
│   ├── Types.lua                    ← Definições de tipos Luau
│   ├── Events/                      ← RemoteEvents (comunicação rede)
│   │   ├── PlayerActionEvent        ← Cliente → Servidor (input de ações)
│   │   ├── GameStateEvent           ← Servidor → Cliente (atualizações de estado)
│   │   ├── UISyncEvent             ← Servidor → Cliente (atualizações HUD)
│   │   └── AudioEvent              ← Servidor → Cliente (gatilhos de áudio)
│   ├── Functions/                   ← RemoteFunctions (requisições síncronas)
│   │   └── GetMatchInfoFunction     ← Cliente → Servidor (info da partida)
│   └── Util/                        ← Utilitários compartilhados
│       ├── Signal.lua               ← Implementação de Signal (pub/sub)
│       └── MathUtil.lua             ← Funções matemáticas (distância, clamp, etc.)
│
└── assets/                          → ServerStorage
    ├── Models/                      ← Modelos 3D
    ├── Sounds/                      ← Efeitos sonoros e música
    └── Animations/                  ← Animações
```

### Regras de Organização

| Pasta | Serviço Roblox | Acesso | Conteúdo |
|-------|---------------|--------|----------|
| `src/server/` | `ServerScriptService` | **Servidor apenas** | Scripts e ModuleScripts que NUNCA chegam ao cliente |
| `src/client/` | `StarterPlayerScripts` | **Cliente apenas** | LocalScripts de UI, input e câmera |
| `src/shared/` | `ReplicatedStorage` | **Ambos** | Constantes, tipos, RemoteEvents, RemoteFunctions, utilitários |
| `src/assets/` | `ServerStorage` | **Servidor apenas** | Assets que o servidor clona para o Workspace quando necessário |

> **Por que separar `Events/` e `Functions/` dentro de `shared/`:** RemoteEvents e RemoteFunctions são a espinha dorsal da comunicação. Centralizá-los em pastas dedicadas evita duplicação e facilita auditoria de segurança (quais eventos o cliente pode disparar?).

---

## Modelo de Comunicação Cliente-Servidor

### Princípio Fundamental

```
┌──────────┐   Input/RemoteEvent    ┌──────────────┐   Replicação    ┌──────────┐
│  CLIENTE │ ──────────────────────→ │   SERVIDOR   │ ──────────────→ │  CLIENTE │
│ (input)  │                         │ (autoritativo)│                 │ (render) │
└──────────┘                         └──────────────┘                 └──────────┘
                                           │
                                     Valida TODA ação:
                                     - Posição válida?
                                     - HP dentro do range?
                                     - Cooldown respeitado?
                                     - Distância permitida?
```

**O cliente NUNCA altera estado de jogo diretamente.** O fluxo é:

1. Cliente detecta input (tecla pressionada)
2. Cliente envia `RemoteEvent:FireServer(action, params)`
3. Servidor **valida** a ação (sanity checks, rate limiting, anti-cheat)
4. Servidor aplica a mudança de estado (HP, posição, cooldown)
5. Servidor replica o resultado para **todos** os clientes via `RemoteEvent:FireAllClients` ou `RemoteEvent:FireClient`

### Eventos de Rede (RemoteEvents)

| Evento | Direção | Uso | Frequência |
|--------|---------|-----|------------|
| `PlayerActionEvent` | Cliente → Servidor | Input do jogador (mover, atacar, interagir, habilidade) | Alta (~60/s por jogador em ações contínuas) |
| `GameStateEvent` | Servidor → Todos | Estado do jogo (HP, posição de geradores, jaulas) | Média (on-change) |
| `UISyncEvent` | Servidor → Cliente | Atualizações de HUD (cooldowns, progresso, alertas) | Média (on-change) |
| `AudioEvent` | Servidor → Cliente | Gatilhos de áudio (passos, habilidade, ambiente) | Média |

**Padrão de nomenclatura:** Use nomes descritivos e verbos no infinitivo para ações do cliente, e substantivos para estado do servidor.

### RemoteFunctions (Uso Limitado)

`RemoteFunctions` são síncronos (cliente espera resposta) e devem ser usados com **extrema moderação**. No MVP, usamos apenas para:

- `GetMatchInfoFunction`: Cliente pergunta "quais personagens estão disponíveis?" antes da seleção.

**Por que evitar RemoteFunctions:** Se o cliente desconectar durante uma chamada, o script trava indefinidamente. Prefira sempre `RemoteEvent` + callback assíncrono.

### Rate Limiting e Anti-Cheat

```lua
-- Exemplo de rate limiting no servidor (dentro de KillerEvents.lua)
local lastActionTime: {[number]: number} = {}
local RATE_LIMIT = 0.1 -- mínimo 100ms entre ações do mesmo jogador

PlayerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...)
    local now = os.clock()
    local last = lastActionTime[player.UserId] or 0

    if now - last < RATE_LIMIT then
        return -- Descarta silenciosamente (não pune na primeira violação)
    end
    lastActionTime[player.UserId] = now

    -- Validação da ação específica...
end)
```

**Checklist de validação server-side para cada ação:**
- [ ] O jogador está vivo?
- [ ] O jogador está no estado correto (não atordoado, não em jaula)?
- [ ] O cooldown da habilidade foi respeitado?
- [ ] O alvo está dentro do alcance permitido?
- [ ] Os valores (dano, cura, duração) estão dentro dos ranges definidos em `GameConstants`?
- [ ] A stamina do jogador é suficiente (para ações que consomem)?

---

## Máquina de Estados da Partida

O fluxo completo da partida é gerenciado por `MatchService` no servidor. Os estados são:

```
                    ┌──────────┐
                    │ WAITING  │  Aguardando jogadores no lobby
                    └────┬─────┘
                         │ Host pressiona "Iniciar"
                         ▼
                    ┌──────────┐
                    │  SELECT  │  Seleção de personagens (15s)
                    └────┬─────┘
                         │ Timer acaba ou todos escolheram
                         ▼
                    ┌──────────┐
                    │ PREPARE  │  Spawn, timer de 5s antes da caçada
                    └────┬─────┘
                         │ Timer 5s acaba
                         ▼
              ┌─────────────────────┐
              │      HUNTING        │  Caça ativa (loop principal)
              │  ┌───────────────┐  │
              │  │ Sub-estados:  │  │
              │  │ • Normal      │  │
              │  │ • Rage ativa  │  │
              │  │ • Colapso     │  │  (últimos 30s)
              │  └───────────────┘  │
              └─────────┬───────────┘
                        │ Condição de vitória atingida
                        ▼
                   ┌──────────┐
                   │  ENDING  │  Resultado (5s) → retorna a WAITING
                   └──────────┘
```

### Definição dos Estados

| Estado | Duração | O que acontece |
|--------|---------|----------------|
| `WAITING` | Indeterminado | Jogadores entram no lobby. Host vê botão "Iniciar". Mínimo 2 jogadores (1 Caçador + 1 Sobrevivente). |
| `SELECT` | 15 segundos | Cada jogador escolhe entre as 5 classes de Sobrevivente ou Caçador (se disponível). Timer força seleção aleatória ao expirar. |
| `PREPARE` | 5 segundos | Sobreviventes spawnam em posições aleatórias. Caçador spawna no Hall de Entrada. HUD mostra contagem regressiva. |
| `HUNTING` | Até 15 minutos | Loop principal do jogo (ver sub-estados abaixo). |
| `ENDING` | 5 segundos | Anuncia vencedor. Tela de resultado. Retorna a `WAITING`. |

### Sub-estados de HUNTING

| Sub-estado | Condição | Efeito |
|------------|----------|--------|
| `Normal` | Padrão | Jogo normal. Timer da partida avança. |
| `Rage` | Medidor de Fúria atinge 100 | Timer da partida **pausa**. Caçador ganha bônus por 30s. |
| `Collapse` | Faltam 30s para o limite (14:30) | Portão abre automaticamente. Caçador recebe indicador de todos os Sobreviventes. |

### Condições de Transição

```lua
-- Em MatchService.lua (pseudocódigo)
local function checkVictoryConditions()
    local aliveSurvivors = getAliveSurvivors()      -- Não em jaula, não eliminados
    local escapedSurvivors = getEscapedSurvivors()   -- Passaram pelo portão
    local repairedGenerators = getRepairedGenerators()

    -- Vitória dos Sobreviventes: ≥1 escapou pelo portão
    if escapedSurvivors >= 1 then
        return "Survivors"
    end

    -- Vitória do Caçador: todos os 4 na jaula simultaneamente
    if aliveSurvivors == 0 and repairedGenerators < 5 then
        return "Killer"
    end

    -- Vitória do Caçador: tempo esgotado sem fuga
    if matchTime >= MATCH_DURATION then -- 900s = 15 min
        return "Killer"
    end

    return nil -- Partida continua
end
```

### Implementação em Código

```lua
-- MatchService.lua (simplificado)
local MatchService = {}
local currentState = "WAITING"

function MatchService.TransitionTo(newState: string)
    local validTransitions = {
        WAITING  = {"SELECT"},
        SELECT   = {"PREPARE"},
        PREPARE  = {"HUNTING"},
        HUNTING  = {"ENDING"},
        ENDING   = {"WAITING"},
    }

    local allowed = validTransitions[currentState]
    if not table.find(allowed, newState) then
        warn("Transição inválida: " .. currentState .. " → " .. newState)
        return
    end

    currentState = newState
    MatchService._onStateChanged(newState)
end

function MatchService.GetState(): string
    return currentState
end

return MatchService
```

---

## Padrões de Dados

### GameConstants — Fonte Única da Verdade

**`src/shared/GameConstants.lua`** é o arquivo canônico para **TODOS** os valores numéricos do jogo. Nem o servidor nem o cliente devem hardcodar números — sempre referenciar `GameConstants`.

```lua
-- ✅ CORRETO
local dmg = GameConstants.Killers.Distorcido.Abilities.M1_Damage

-- ❌ ERRADO
local dmg = 20  -- NUNCA hardcode números de jogo
```

**Regra:** Se um valor aparece no GDD (HP, dano, velocidade, duração, alcance), ele DEVE estar em `GameConstants.lua`.

### Gerenciamento de Estado por Jogador

Cada jogador tem um **objeto de estado** mantido no servidor (não replicado diretamente):

```lua
-- Representação do estado de um jogador no servidor
type PlayerState = {
    -- Identidade
    userId: number,
    player: Player,
    role: "Killer" | "Survivor" | "Spectator",
    characterClass: string?,  -- "Soldado", "Enfermeira", etc. (nil para Killer)

    -- Vida e status
    hp: number,
    maxHp: number,
    isAlive: boolean,
    isDowned: boolean,
    isInCage: boolean,
    cageTimer: number?,       -- segundos restantes na jaula (nil se não estiver)

    -- Stamina (Sobreviventes apenas)
    stamina: number?,         -- 0 a 100
    isRunning: boolean?,
    isCrouching: boolean?,

    -- Caçador (apenas se role == "Killer")
    fury: number?,            -- 0 a 100
    isRageActive: boolean?,
    isCarrying: boolean?,
    carriedSurvivorId: number?,

    -- Cooldowns
    cooldowns: {[string]: number},  -- nome_da_habilidade → timestamp de quando expira

    -- Estado de habilidades
    activeEffects: {Effect},  -- lista de efeitos ativos (slow, stun, shield, etc.)
}
```

### Padrão de Cooldowns

Cooldowns são gerenciados no servidor comparando timestamps:

```lua
-- Em KillerService.lua
local function canUseAbility(playerState: PlayerState, abilityName: string): boolean
    local cooldownEnd = playerState.cooldowns[abilityName]
    if not cooldownEnd then return true end
    return os.clock() >= cooldownEnd
end

local function useAbility(playerState: PlayerState, abilityName: string, cooldownSeconds: number)
    playerState.cooldowns[abilityName] = os.clock() + cooldownSeconds
    -- Notificar cliente sobre o cooldown iniciado
    UISyncEvent:FireClient(playerState.player, "CooldownStart", abilityName, cooldownSeconds)
end
```

### Padrão de HP e Dano

```lua
-- Em SurvivorService.lua
local function applyDamage(playerState: PlayerState, amount: number)
    playerState.hp = math.max(0, playerState.hp - amount)

    -- Replicar novo HP para o cliente afetado
    UISyncEvent:FireClient(playerState.player, "HPUpdate", playerState.hp, playerState.maxHp)

    -- Verificar se foi derrubado
    if playerState.hp <= 0 and not playerState.isDowned then
        downSurvivor(playerState)
    end
end
```

---

## Mapeamento: Épicos → Módulos de Código

| Épico | Nome | Módulos Envolvidos |
|-------|------|---------------------|
| **E1** | Fundação — Movimento e Controles | `ClientManager`, `InputManager`, `CameraManager`, `GameManager` |
| **E2** | O Distorcido — Caçador MVP | `KillerService`, `KillerEvents`, `KillerHUD` |
| **E3** | Sobreviventes — 5 Classes | `SurvivorService`, `SurvivorEvents`, `SurvivorHUD` |
| **E4** | A Mansão — Mapa MVP | `Workspace` (construção no Studio), `ServerStorage` (modelos) |
| **E5** | Objetivos — Geradores e Portão | `GeneratorService`, `ObjectiveService`, `GameStateEvent` |
| **E6** | Captura — Der., Jaula e Resgate | `CaptureService`, `GameStateEvent` |
| **E7** | Lobby e Fluxo de Partida | `MatchService`, `CharacterSelectUI`, `GameOverUI`, `PlayerEvents` |
| **E8** | Áudio e Atmosfera | `AudioService`, `AudioEvent` |
| **E9** | Polimento e Balanceamento | `GameConstants` (ajuste de números), todos os Services |

### Ordem de Implementação

A ordem dos épicos é **sequencial e cumulativa** — cada épico depende dos anteriores:

```
E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → E9
```

**Épicos paralelizáveis (para o futuro, com mais devs):**
- E2 e E3 podem ser desenvolvidos em paralelo (Caçador e Sobreviventes são sistemas independentes)
- E8 (Áudio) pode começar assim que E1 estiver pronto (sons de passos, ambiente)
- E4 (Mapa) pode ser construído em paralelo com E2/E3

---

## Padrões de Implementação Roblox

### 1. Service Architecture (Recomendado)

**Toda lógica de servidor** fica em ModuleScripts dentro de `src/server/Services/`. Um único Script (`GameManager.server.lua`) inicializa todos os serviços em ordem:

```lua
-- GameManager.server.lua
local services = {
    MatchService = require(script.Services.MatchService),
    KillerService = require(script.Services.KillerService),
    SurvivorService = require(script.Services.SurvivorService),
    GeneratorService = require(script.Services.GeneratorService),
    CaptureService = require(script.Services.CaptureService),
    ObjectiveService = require(script.Services.ObjectiveService),
    AudioService = require(script.Services.AudioService),
}

-- Fase Init: setup síncrono (sem yield), conectar eventos
for name, service in services do
    if service.Init then
        service:Init()
    end
end

-- Fase Start: inicialização que pode yield
for name, service in services do
    if service.Start then
        task.spawn(service.Start, service)
    end
end
```

### 2. Signal Pattern (Pub/Sub Interno)

Para comunicação entre serviços no mesmo contexto (server↔server), use um Signal pattern simples:

```lua
-- src/shared/Util/Signal.lua
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({
        _listeners = {},
    }, Signal)
end

function Signal:Connect(fn)
    table.insert(self._listeners, fn)
    return {
        Disconnect = function()
            local idx = table.find(self._listeners, fn)
            if idx then table.remove(self._listeners, idx) end
        end
    }
end

function Signal:Fire(...)
    for _, fn in self._listeners do
        task.spawn(fn, ...)
    end
end

return Signal
```

**Uso no servidor:**
```lua
-- Em MatchService.lua
MatchService.MatchStarted = Signal.new()
-- ...
MatchService.MatchStarted:Fire()

-- Em AudioService.lua
function AudioService:Init()
    MatchService.MatchStarted:Connect(function()
        self:StartAmbientMusic()
    end)
end
```

### 3. Object Pooling (Projéteis e Efeitos)

Para habilidades que criam objetos temporários (Braço Esticado, projétil da Bazuca, efeitos de partículas):

```lua
-- Pool genérico (simplificado)
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(template: Instance, initialSize: number)
    local self = setmetatable({}, ObjectPool)
    self._template = template
    self._pool = {}

    for _ = 1, initialSize do
        local obj = template:Clone()
        obj.Parent = nil
        table.insert(self._pool, obj)
    end

    return self
end

function ObjectPool:Get(): Instance
    local obj = table.remove(self._pool)
    if not obj then
        obj = self._template:Clone()
    end
    return obj
end

function ObjectPool:Return(obj: Instance)
    obj.Parent = nil
    table.insert(self._pool, obj)
end
```

### 4. Cleanup Pattern (Gerenciamento de Conexões)

**SEMPRE** desconecte event listeners quando um objeto não for mais necessário:

```lua
local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(model: Model)
    local self = setmetatable({}, Enemy)
    self._model = model
    self._connections = {}  -- Track de todas as conexões

    table.insert(self._connections,
        model.Humanoid.Died:Connect(function()
            self:_onDied()
        end)
    )

    return self
end

function Enemy:Destroy()
    for _, conn in self._connections do
        conn:Disconnect()
    end
    table.clear(self._connections)
    self._model:Destroy()
end
```

### 5. WaitForChild com Timeout

Nunca acesse children do Workspace sem `WaitForChild` com timeout:

```lua
-- ❌ ERRADO
local map = workspace.Map

-- ✅ CORRETO
local map = workspace:WaitForChild("Map", 10)
if not map then
    warn("Mapa não carregou em 10 segundos")
    return
end
```

### 6. Client Startup Sequence

No cliente, scripts executam em ordem previsível:

1. `ReplicatedFirst` carrega (loading screen)
2. `game.Loaded` dispara → `game:IsLoaded()` retorna true
3. Scripts do cliente (`StarterPlayerScripts`) rodam
4. `Players.LocalPlayer.Character` fica disponível (use `CharacterAdded`!)

```lua
-- ClientManager.client.lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- NUNCA assuma que o Character existe no startup
player.CharacterAdded:Connect(function(character)
    print("Character spawnou:", character.Name)
    setupCharacter(character)
end)

-- Se o character JÁ existe (respawn), o evento não dispara —
-- verifique manualmente:
if player.Character then
    setupCharacter(player.Character)
end
```

---

## Segurança e Anti-Cheat

### Princípios Fundamentais

1. **Toda lógica de jogo no servidor.** O cliente é ONLY input + render.
2. **Validar, validar, validar.** Nunca confie em dados do cliente.
3. **Rate limiting.** Cada jogador tem limites de ações por segundo.
4. **ServerStorage para assets sensíveis.** Modelos e sons que o cliente não deve acessar vão em `ServerStorage`.

### O Que NUNCA Fazer

| ❌ Errado | ✅ Certo | Por quê |
|-----------|---------|---------|
| Cliente aplica dano no Caçador | Cliente envia input → Servidor valida dano → Servidor aplica | Cliente pode modificar valores |
| Cliente teleporta o personagem | Servidor movimenta via Humanoid:MoveTo() | Cliente pode se teleportar para qualquer lugar |
| Cliente reseta próprio cooldown | Servidor gerencia cooldowns via timestamps | Cliente pode remover cooldowns |
| Constantes no cliente como autoridade | `GameConstants` é referência; servidor É a autoridade | Exploit pode alterar valores no cliente |

### Validações Obrigatórias para Cada Ação Remota

```lua
-- Template de handler seguro de RemoteEvent
someEvent.OnServerEvent:Connect(function(player: Player, ...)
    -- 1. Jogador está na partida?
    local playerState = MatchService:GetPlayerState(player)
    if not playerState then return end

    -- 2. Jogador está vivo?
    if not playerState.isAlive then return end

    -- 3. Jogador está no estado correto (não stunned, não em jaula)?
    if playerState.isStunned or playerState.isInCage then return end

    -- 4. Rate limiting
    if not RateLimiter:Check(player.UserId, "ActionName") then return end

    -- 5. Range check
    local distance = calculateDistance(player, target)
    if distance > maxAllowedRange then return end

    -- 6. Value sanity check
    local damage = args[1]
    if damage < 0 or damage > GameConstants.MAX_DAMAGE then return end

    -- 7. Executar ação validada
    applyValidatedAction(playerState, ...)
end)
```

---

## Áudio — Arquitetura de Camadas Dinâmicas

O sistema de áudio usa **3 camadas de música** que fazem crossfade baseado na distância do Caçador ao Sobrevivente:

### Camadas de Música

| Camada | Nome | Distância | Intensidade | Gatilho |
|--------|------|-----------|-------------|---------|
| **Layer 1** | Exploração | >60 studs | Baixa | Música ambiente, tons graves |
| **Layer 2** | Alerta | 30–60 studs | Média | Cordas, percussão leve |
| **Layer 3** | Perseguição | <30 studs | Alta | Percussão intensa, metais, batimentos |

### Crossfade

```lua
-- Em AudioService.lua (servidor)
function AudioService:UpdateProximity(survivorId: number, distanceToKiller: number)
    local targetLayer
    if distanceToKiller > 60 then
        targetLayer = 1
    elseif distanceToKiller > 30 then
        targetLayer = 2
    else
        targetLayer = 3
    end

    -- Envia para o cliente fazer o crossfade
    AudioEvent:FireClient(survivorPlayer, "Crossfade", targetLayer, 2.0) -- 2s de transição
end
```

### Batimentos Cardíacos

O volume e ritmo dos batimentos cardíacos aumentam linearmente com a proximidade do Caçador:

```lua
-- No servidor, atualiza a cada 500ms
local heartbeatVolume = math.clamp(1 - (distanceToKiller / 40), 0, 1)
AudioEvent:FireClient(survivorPlayer, "Heartbeat", heartbeatVolume)
```

---

## Sistema de Habilidades — Arquitetura

Cada habilidade segue o mesmo padrão de implementação:

```lua
-- Template de habilidade (em KillerService ou SurvivorService)
type Ability = {
    name: string,
    inputKey: string,           -- "Q", "E", "R", "M1"
    cooldown: number,           -- segundos
    windup: number?,            -- segundos antes do efeito
    recovery: number?,          -- segundos após o efeito
    onCast: (playerState: PlayerState, targetData: any) -> (),
    onValidate: (playerState: PlayerState) -> boolean,
    getHUDInfo: () -> {icon: string, remainingCooldown: number},
}
```

### Exemplo: Braço Esticado (Pull)

```lua
-- Em KillerService.lua
local BRACO_ESTICADO: Ability = {
    name = "BracoEsticado",
    inputKey = "Q",
    cooldown = 12,
    windup = 0.4,
    recovery = 0.6,

    onValidate = function(playerState)
        return canUseAbility(playerState, "BracoEsticado")
            and not playerState.isCarrying
            and not playerState.isStunned
    end,

    onCast = function(playerState, aimDirection)
        -- 1. Calcular hitbox (linha de 40 studs, 2 studs de largura)
        -- 2. Verificar se atingiu algum Sobrevivente
        -- 3. Se sim: puxar para 4 studs do Caçador, stun 0.5s
        -- 4. Iniciar cooldown
        useAbility(playerState, "BracoEsticado", BRACO_ESTICADO.cooldown)
    end,
}
```

---

## UI / HUD — Arquitetura

### Estrutura de ScreenGuis

```
PlayerGui (por jogador)
├── SurvivorHUD (ScreenGui, ResetOnSpawn = false)
│   ├── HPBar (Frame)
│   ├── StaminaBar (Frame)
│   ├── AbilityIcons (Frame)     ← Q, E, R com cooldown overlay
│   ├── GeneratorCounter (Text)  ← "3/5 geradores"
│   └── HeartbeatOverlay (Frame) ← efeito de proximidade
│
├── KillerHUD (ScreenGui, ResetOnSpawn = false)
│   ├── FuryBar (Frame)
│   ├── AbilityIcons (Frame)
│   ├── SurvivorTracker (Frame)  ← "3 vivos, 1 na jaula"
│   └── NotificationMarkers (Frame) ← indicadores direcionais
│
├── CharacterSelectUI (ScreenGui, Enabled = false)
│   └── CharacterCards (Frame)
│
└── GameOverUI (ScreenGui, Enabled = false)
    └── ResultScreen (Frame)
```

### Atualização de HUD via Eventos

O servidor envia atualizações de HUD via `UISyncEvent`:

```lua
-- Servidor → Cliente
UISyncEvent:FireClient(player, "HPUpdate", currentHP, maxHP)
UISyncEvent:FireClient(player, "StaminaUpdate", currentStamina, maxStamina)
UISyncEvent:FireClient(player, "CooldownUpdate", abilityName, remainingSeconds)
UISyncEvent:FireClient(player, "FuryUpdate", currentFury)
UISyncEvent:FireClient(player, "GeneratorUpdate", repaired, total)
```

### Indicadores In-World

Indicadores sobre objetos 3D (geradores, jaulas) são gerenciados pelo servidor via propriedades replicadas:

```lua
-- Servidor altera propriedade do gerador
generator.Model.Light.Color = Color3.fromRGB(0, 255, 0)  -- Verde = reparado
generator.Model.Light.Enabled = true
-- A mudança replica automaticamente para todos os clientes
```

---

## Performance — Diretrizes

### Metas

| Métrica | PC | Mobile |
|---------|-----|--------|
| FPS | ≥55 FPS | ≥28 FPS |
| Tempo de carregamento | <10s | <18s |
| Memória | — | <500 MB |
| Partículas simultâneas | ≤200 | ≤200 |
| Polígonos por modelo | ~2000 tris | ~1500 tris |

### Boas Práticas de Performance

```lua
-- 1. Cache game:GetService() no topo do script
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- 2. Use RunService.Heartbeat para game loop (NUNCA while true do wait())
RunService.Heartbeat:Connect(function(dt)
    updateGameLoop(dt)
end)

-- 3. Use task.wait() em vez de wait()
-- ❌ wait(1)   -- impreciso, legado
-- ✅ task.wait(1)

-- 4. Use task.spawn() para trabalho assíncrono
task.spawn(function()
    doExpensiveOperation()
end)

-- 5. String concatenation: use table.concat
-- ❌ result = ""
-- ❌ for i = 1, 1000 do result = result .. "x" end
-- ✅ local parts = {}
-- ✅ for i = 1, 1000 do parts[i] = "x" end
-- ✅ result = table.concat(parts)

-- 6. Evite Instance.new() em loops — use object pooling

-- 7. Desconecte listeners quando não precisar mais
local conn = event:Connect(handler)
-- ... mais tarde:
conn:Disconnect()
```

### StreamingEnabled

O mapa da Mansão Abandonada (~50 peças modulares) é pequeno o suficiente para **não precisar** de `StreamingEnabled` no MVP. Se no futuro o mapa crescer ou forem adicionados mapas maiores, habilitar:

```lua
workspace.StreamingEnabled = true
```

---

## Decisões de Arquitetura (ADRs)

### ADR-001: Nenhum Framework Externo

**Decisão:** Não usar Knit, AeroGameFramework, ou outros frameworks de serviço no MVP.

**Justificativa:** O desenvolvedor é iniciante. Frameworks adicionam curva de aprendizado e dependências. A arquitetura de serviços com ModuleScripts puros é suficiente para o escopo do MVP (1 Caçador, 5 Sobreviventes, 1 Mapa).

**Revisitar quando:** O projeto tiver 3+ Caçadores, 3+ Mapas e mais de 2 desenvolvedores.

### ADR-002: Sem DataStore no MVP

**Decisão:** Não implementar persistência de dados (XP, progressão) no MVP.

**Justificativa:** DataStore adiciona complexidade (session locking, retry logic, tratamento de erros) desnecessária para validar o core loop. O MVP usa partidas locais com host.

**Revisitar quando:** Pós-MVP, ao implementar sistema de progressão de conta.

### ADR-003: Comunicação via RemoteEvent (não RemoteFunction)

**Decisão:** Usar `RemoteEvent` para toda comunicação cliente→servidor, exceto `GetMatchInfo`.

**Justificativa:** `RemoteFunction` é síncrono — se o cliente desconectar durante a chamada, o script trava. `RemoteEvent` é assíncrono e mais seguro para o padrão de jogo.

### ADR-004: Single-Thread no Servidor (sem Parallel Luau)

**Decisão:** Não usar Parallel Luau no MVP.

**Justificativa:** O escopo do MVP não tem CPU-heavy work que justifique multithreading. Parallel Luau adiciona complexidade significativa (Actors, thread safety, restrições de `require()`).

**Revisitar quando:** NPCs em grande número (bots), pathfinding complexo, ou validação de raycasting em larga escala.

### ADR-005: HUD Vanilla sem Frameworks de UI

**Decisão:** Construir HUD com ScreenGuis nativas do Roblox, sem Fusion ou Roact.

**Justificativa:** O HUD do MVP é simples (barras de HP/stamina/fúria, ícones de habilidade, contador de geradores). Frameworks de UI reativa são overkill para este escopo.

**Revisitar quando:** HUD tiver mais de 15 elementos interativos e o estado da UI ficar difícil de gerenciar manualmente.

### ADR-006: Sistema de Áudio Server-Driven

**Decisão:** O servidor decide qual camada de música e quais sons tocar, enviando comandos para os clientes.

**Justificativa:** Permite lógica centralizada de proximidade e consistência entre todos os clientes. O cliente apenas executa os comandos de áudio recebidos.

---

## Convenções de Código

### Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Módulos/Serviços | PascalCase | `MatchService`, `KillerService` |
| Funções | camelCase | `applyDamage()`, `canUseAbility()` |
| Variáveis | camelCase | `currentState`, `playerHp` |
| Constantes | UPPER_SNAKE_CASE | `MAX_PLAYERS`, `MATCH_DURATION` |
| RemoteEvents | PascalCase + "Event" | `PlayerActionEvent`, `GameStateEvent` |
| Tipos Luau | PascalCase | `PlayerState`, `Ability` |
| Campos de tipo | camelCase | `maxHp`, `isAlive`, `characterClass` |

### Estrutura de Arquivos

Todo arquivo `.lua` do projeto deve começar com:

```lua
--!strict
--[[
  NomeDoModulo.lua
  Breve descrição do que este módulo faz.
  Contexto: Server | Client | Shared
]]
```

### Logging

Use `print()` para desenvolvimento e debugging. Adote o prefixo `[CacadaSombria]` para facilitar filtragem no Output do Roblox Studio:

```lua
print("[CacadaSombria] MatchService: Partida iniciada com " .. playerCount .. " jogadores")
warn("[CacadaSombria] MatchService: Transição de estado inválida: " .. from .. " → " .. to)
```

### Comentários em PT-BR

Todo código é comentado em **português brasileiro**:

```lua
-- Aplica dano a um jogador, validando o valor contra GameConstants
-- @param playerState -- PlayerState do alvo
-- @param amount -- Quantidade de dano (deve ser > 0 e ≤ MAX_DAMAGE)
local function aplicarDano(playerState: PlayerState, amount: number)
    -- ...
end
```

---

## Ambiente de Desenvolvimento

### Ferramentas

| Ferramenta | Uso |
|-----------|-----|
| **Roblox Studio** | Editor visual, teste (F5), publicação |
| **Rojo** (v7.6.1) | Live sync: código local → Roblox Studio |
| **VS Code** | Editor de código externo |
| **Git** | Versionamento do código |

### Fluxo Diário

```bash
# 1. Iniciar sync (terminal deixado rodando)
cd /Users/familia/assym-roblox-game
rojo serve

# 2. Conectar Roblox Studio: Plugins → Rojo → Connect → localhost

# 3. Editar código no VS Code → salva automaticamente → aparece no Studio

# 4. Testar no Studio: F5 (Play)

# 5. Commitar
git add .
git commit -m "feat: descrição"
git push
```

### Teste Multi-Jogador

No Roblox Studio, use **Team Test** (Test → Team Test) para simular 1 servidor + 5 clientes simultaneamente. Use o Client/Server toggle no Explorer para inspecionar estado de cada lado.

---

## Glossário Rápido Roblox

| Termo | Significado |
|-------|-------------|
| **DataModel** | Árvore hierárquica de objetos do jogo (acessada via `game`) |
| **Instance** | Qualquer objeto na DataModel (Part, Script, Model, etc.) |
| **Script** | Roda no servidor (ou cliente, dependendo de `RunContext`) |
| **LocalScript** | Roda apenas no cliente |
| **ModuleScript** | Módulo de código reutilizável, carregado via `require()` |
| **RemoteEvent** | Comunicação unidirecional servidor↔cliente (fire and forget) |
| **RemoteFunction** | Comunicação síncrona servidor↔cliente (request/response) |
| **BindableEvent** | Comunicação interna no mesmo contexto (server↔server ou client↔client) |
| **FilteringEnabled** | Proteção que impede cliente de modificar estado do servidor (sempre ativo) |
| **Workspace** | Serviço que contém o mundo físico (modelos, partes, terreno) |
| **ReplicatedStorage** | Container acessível tanto pelo servidor quanto pelo cliente |
| **ServerScriptService** | Container acessível apenas pelo servidor (código seguro) |
| **ServerStorage** | Container acessível apenas pelo servidor (assets, modelos) |
| **PlayerGui** | Container de UI de cada jogador (clonado de `StarterGui`) |
| **Humanoid** | Objeto que gerencia vida, animações e movimento de personagens |
| **Stud** | Unidade de medida espacial no Roblox (1 stud ≈ 28 cm) |
| **Luau** | Linguagem de scripting do Roblox (superset tipado de Lua 5.1) |

---

## Referências

- [GDD — Caçada Sombria](../_bmad/gds/gdd/gdd-Cacada-Sombria-2026-06-27/gdd.md)
- [GameConstants.lua](../src/shared/GameConstants.lua)
- [Guia de Desenvolvimento Roblox](./workflow-roblox.md)
- [Documentação Oficial Roblox](https://create.roblox.com/docs)
- [Luau Type Checking](https://luau-lang.org/typecheck)

---

_Documento gerado como parte do workflow de arquitetura GDS._
_Data: 28 de Junho de 2026_
_Para: familia_
