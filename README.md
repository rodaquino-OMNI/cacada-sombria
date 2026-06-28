# 🕯️ Caçada Sombria

> **Gênero:** Terror Assimétrico (1v4) • **Plataforma:** Roblox • **Público:** 12+  
> **Tema:** Brinquedos com almas em uma mansão abandonada

---

## 📖 Sobre o Jogo

**Caçada Sombria** é um jogo multiplayer assimétrico de terror leve onde **1 Caçador** enfrenta **4 Sobreviventes** em uma mansão abandonada. O Caçador — uma criatura distorcida e implacável — deve capturar todos os Sobreviventes antes que eles consigam consertar 5 geradores e escapar pelo portão.

O jogo se passa em uma **Mansão Abandonada** com 8 a 10 cômodos distribuídos em 2 andares + porão, com iluminação dramática, névoa e esconderijos. Não há sangue ou gore — o terror vem da atmosfera, perseguição e tensão.

---

## 🎮 Como Jogar

### Controles (PC)

| Tecla | Ação |
|-------|------|
| `W A S D` | Mover |
| `Mouse` | Olhar ao redor |
| `Shift` | Correr (Sobrevivente: gasta stamina) |
| `Ctrl` | Agachar (alterna) |
| `E` | Interagir (gerador, portão, esconderijo) |
| `Q` | Habilidade 1 |
| `Botão Direito` | Habilidade 2 |
| `R` | Habilidade 3 (Sobrevivente) / Rage (Caçador) |
| `F` | Interagir (Caçador: carregar Sobrevivente) |
| `Clique Esquerdo` | Ataque M1 (Caçador) |
| `Espaço` | Pular |

### Objetivos

**Sobreviventes:** Consertar 5 geradores espalhados pela mansão → abrir o portão de fuga → escapar. Trabalhem em equipe, usem esconderijos e distraiam o Caçador.

**Caçador:** Derrubar os Sobreviventes, carregá-los até as jaulas e eliminar todos antes que fujam. Use suas 4 habilidades para pressionar e capturar.

### Regras da Partida
- **Duração:** 15 minutos
- **Colapso:** Nos últimos 30 segundos, o portão abre automaticamente
- **Captura:** Sobreviventes derrubados podem ser carregados e colocados em jaulas
- **Resgate:** Aliados podem salvar Sobreviventes das jaulas (canal de 3s)
- **Morte:** 2 capturas em jaula = eliminação permanente

---

## 👹 Caçadores (Killers)

### 🏆 O Distorcido *(MVP — Implementado)*
**HP:** 1100 • **Velocidade:** 26 (28 no Rage) • **Estilo:** Brawler / Transformação

| Tecla | Habilidade | Descrição |
|-------|-----------|-----------|
| M1 | **Tapa** | Ataque corpo a corpo. Dano: 20 (25 no Rage) |
| Q | **Braço Esticado** | Estica o braço 40 studs e puxa o Sobrevivente. Cooldown: 12s |
| R | **Rage (Transformação)** | Medidor cheio → ativa modo transformado por 30s. +Velocidade, +Dano, visual aterrorizante |
| E | **Grito** | Lentidão + blur em Sobreviventes a 60 studs. Revela todos a 100 studs por 4s. Cooldown: 25s |

**Medidor de Fúria:** Enche ao causar/receber dano. Quando atinge 100, o Rage fica disponível.

---

### 🧵 O Boneco de Pano *(Planejado)*
**HP:** 400 • **Velocidade:** 26 • **Estilo:** Sniper / Utilitário

| Tecla | Habilidade | Descrição |
|-------|-----------|-----------|
| M1 | **Tapa** | Dano: 20 |
| Q | **Dash** | 3s de preparação → voa por 10s. Dano: 30 + slow 3s |
| E | **Laser (3 modos)** | 🔴 Dano, 🟢 Cura própria, 🔵 Slow + revelação. Dura 10s |

---

### 🪖 O Soldado *(Planejado)*
**HP:** 1500 • **Velocidade:** 24 • **Estilo:** Zone Control / Tank

| Tecla | Habilidade | Descrição |
|-------|-----------|-----------|
| M1 | **Tiro** | Dano: 30 |
| Q | **Sentinela** | Posiciona parceiros (máx 5) que atiram em Sobreviventes próximos |
| E | **Míssil** | 2s de preparo → míssil rápido. Dano: 35 + 5 explosão |
| R | **Marca de Teleporte** | Deixa marca no chão |
| F | **Teleporte** | 1.5s preparo → teleporta para a marca. Dano: 20 em área + speed boost |

---

### 📐 O Compasso *(Planejado)*
**HP:** 1234 • **Velocidade:** 28 • **Estilo:** Rushdown / Assassino

| Tecla | Habilidade | Descrição |
|-------|-----------|-----------|
| M1 | **Ataque** | Dano: 15 + 10 de sangramento (4s) |
| Q | **Dash** | Avança capturando até 3 Sobreviventes. Arremessa ao final |
| E | **Lápis** | 1.5s preparo → lança na direção do mouse. Dano: 10 + ragdoll 3s + preso 20s |
| R | **Recall** | Se perto do lápis: dano no portador + speed + invencibilidade |

---

## 🧸 Sobreviventes

### 🪖 Soldado *(HP 120, Vel 20)*
| Tecla | Habilidade | Cooldown | Descrição |
|-------|-----------|----------|-----------|
| Q | **Dash Tático** | 12s | Avança. Se atinge o Caçador: empurra 10 studs + silencia habilidades por 3s |
| E | **Bazuca** | 45s | Ativa mira (2s). Dispara feixe de 200 studs (50 dano). Cancelar = meia penalidade |

**LMS Bonus (vs Soldado Killer):** +2 speed, +30% dano Bazuca

---

### 🧸 Sackboy *(HP 110, Vel 26)*
| Tecla | Habilidade | Cooldown | Descrição |
|-------|-----------|----------|-----------|
| Q (hold) | **Arma de Tinta** | 15s | Carrega 1-3s. Nível 1: slow+push. Nível 2: +silence 4s. Nível 3: stun+blur |
| E | **Surto** | 20s | +6 speed, +50% altura de pulo por 5s |

**LMS Bonus (vs Boneco de Pano):** +2 speed, +20 stamina

---

### 🤖 Robô *(HP 150, Vel 18)*
| Tecla | Habilidade | Cooldown | Descrição |
|-------|-----------|----------|-----------|
| Q | **Agarrar** | 20s | Puxa o Caçador (20 studs). Killer fica invencível 8s + silenciado 2s |
| E | **Block** | 15s | Postura defensiva 1.5s. Contra-ataque: silence 3s no Killer + auto-cura 10 HP |
| R | **Sacrifício** | 60s | 3s parado → 5s de velocidade → EXPLODE. 40 auto-dano + arremessa Killer 100 studs + stun 6s |

⚠️ **Robô não pode ser curado por outros.** Única cura é o Block.

---

### 💉 Enfermeira *(HP 105, Vel 22)*
| Tecla | Habilidade | Cooldown | Descrição |
|-------|-----------|----------|-----------|
| Q | **Curativo** | 18s | Canal 2s em aliado (10 studs). Cura 25 HP. Brilho visível ao Killer a 40 studs. **Não funciona em Robô** |
| E | **Adrenalina** | 30s | Projétil (15 studs). Aliado ganha +3 speed + escudo (ignora 1 hit) por 5s |

---

### 🥊 Campeão *(HP 130, Vel 22)*
| Tecla | Habilidade | Cooldown | Descrição |
|-------|-----------|----------|-----------|
| Q | **Agarrão** | 15s | Avança 8 studs. Acerta: 20 dano + arremessa 8 studs + grounded 1s. Erra: auto-slow 2s |
| E | **Sequência** | 12s | 3 socos rápidos (5 studs). 5 dano cada. 3º: +5 dano bônus + slow 1s. Acertar todos: -5s no Agarrão |

---

## 🗺️ A Mansão

| Característica | Valor |
|---------------|-------|
| Cômodos | 8 a 10 (Hall, Sala de Estar, Cozinha, Escritório, Sala de Jantar, Corredores, Quartos, Banheiro, Porão) |
| Andares | 2 + Porão |
| Esconderijos | 15 (12 ativos por partida, 3 bloqueados aleatoriamente) |
| Tempo máximo escondido | 20 segundos |
| Iluminação | Dramática, escura, com névoa no porão |

---

## 🧪 Como Testar no Roblox Studio

### Pré-requisitos
- [Roblox Studio](https://create.roblox.com) instalado
- [Rojo](https://rojo.space) instalado (`cargo install rojo`)

### Setup Rápido

```bash
# 1. Clone o projeto
git clone <repo-url> CacadaSombria
cd CacadaSombria

# 2. Inicie o Rojo para live-sync
rojo serve
```

### No Roblox Studio
1. Abra o Roblox Studio
2. Instale o plugin **Rojo** da loja de plugins
3. Conecte ao servidor Rojo (`rojo serve`)
4. O projeto será sincronizado automaticamente

### Team Test (Teste em Equipe)
1. No Roblox Studio, vá em **Test → Start** (F5)
2. Para simular múltiplos jogadores: **Test → Clients and Servers**
3. Inicie 1 servidor + 5 clientes (1 Caçador + 4 Sobreviventes)
4. Na janela do servidor, você pode ver os logs em PT-BR com prefixo `[CacadaSombria]`

### Testando Localmente
1. Clique em **Play** (F5) no Studio
2. Você será o Host (primeiro jogador = host do lobby)
3. Atribua o Caçador e inicie a partida
4. Use as teclas conforme a tabela de controles

---

## 🚀 Como Publicar

```bash
# Build standalone (.rbxlx)
rojo build -o CacadaSombria.rbxlx
```

1. Faça upload do arquivo `.rbxlx` no [Roblox Creator Hub](https://create.roblox.com)
2. Configure o jogo como **Pago** ou **Free-to-Play**
3. Defina até 5 jogadores por servidor
4. Habilite **Team Create** se for desenvolver em equipe

---

## 🏗️ Arquitetura do Projeto

```
src/
├── server/                    # ServerScriptService
│   ├── GameManager.server.lua # Ponto de entrada do servidor
│   ├── Services/              # 9 serviços (um por domínio)
│   │   ├── MatchService.lua   # Estado da partida e jogadores
│   │   ├── LobbyService.lua   # Lobby e seleção de personagem
│   │   ├── KillerService.lua  # Lógica do Caçador
│   │   ├── SurvivorService.lua# 5 classes de Sobreviventes
│   │   ├── MapService.lua     # Mapa, esconderijos, spawns
│   │   ├── GeneratorService.lua # Geradores e skill checks
│   │   ├── ObjectiveService.lua # Portão e condições de vitória
│   │   ├── CaptureService.lua # Captura, jaulas e resgate
│   │   └── AudioService.lua   # Música dinâmica e SFX
│   └── Events/                # Handlers de RemoteEvents
│       ├── PlayerEvents.lua
│       ├── KillerEvents.lua
│       ├── SurvivorEvents.lua
│       ├── GeneratorEvents.lua
│       └── CaptureEvents.lua
├── client/                    # StarterPlayerScripts
│   ├── ClientManager.client.lua
│   ├── UI/                    # Interfaces
│   ├── Input/                 # Sistema de input
│   ├── Camera/                # Câmera 1ª/3ª pessoa
│   └── Audio/                 # Reprodução de áudio
└── shared/                    # ReplicatedStorage
    ├── GameConstants.lua      # Constantes de balanceamento
    ├── Events/                # Definições de RemoteEvents
    ├── Util/                  # Signal, MathUtil
    └── MapData/               # Dados da Mansão
```

### Estatísticas do Código
- **30 arquivos `.lua`**
- **16.219 linhas de código**
- 100% comentários em PT-BR
- 100% tipagem estrita (`--!strict`)
- Padrão Init/Start em todos os serviços
- Comunicação pub/sub via Signal

---

## 📋 Status do Desenvolvimento

| Épico | Nome | Status |
|-------|------|--------|
| E1 | Fundação — Movimento e Controles | ✅ Completo |
| E2 | O Distorcido — Caçador MVP | ✅ Completo |
| E3 | Sobreviventes — 5 Classes | ✅ Completo |
| E4 | A Mansão — Mapa MVP | ✅ Completo |
| E5 | Objetivos — Geradores e Portão | ✅ Completo |
| E6 | Captura — Derrubar, Jaula e Resgate | ✅ Completo |
| E7 | Lobby e Fluxo de Partida | ✅ Completo |
| E8 | Áudio e Atmosfera | ✅ Completo |
| E9 | Polimento e Balanceamento | ✅ Completo |

---

*"Na mansão abandonada, os brinquedos ganham vida — mas nem todos têm boas intenções."*
