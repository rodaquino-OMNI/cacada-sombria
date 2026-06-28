# Guia de Configuração de Áudio — Caçada Sombria (Épico E8)

> **Idioma:** PT-BR  
> **Última atualização:** 28 de Junho de 2026  
> **Status:** Placeholders — aguardando substituição por IDs reais da biblioteca gratuita do Roblox

---

## 📋 Visão Geral

Este guia lista todos os assets de áudio necessários para o Épico E8 do Caçada Sombria.  
Todos os sons devem ser **MONO** (canal único) para que a espacialização 3D funcione corretamente.

O sistema de áudio usa um **AudioService** (servidor) que decide O QUE tocar e um **AudioManager** (cliente) que executa a reprodução.

### Estrutura de Arquivos

```
src/
├── server/Services/AudioService.lua      ← Lógica do servidor (o que tocar)
├── client/Audio/AudioManager.lua         ← Reprodução no cliente (como tocar)
├── shared/Events/UISyncEvent.lua         ← Mensagens de áudio adicionadas
└── shared/GameConstants.lua              ← Constantes de áudio (futuro)
```

---

## 🎵 MÚSICA — 3 CAMADAS DINÂMICAS

O sistema usa **3 camadas de música** que fazem crossfade baseado na distância do Sobrevivente ao Caçador.

| Camada | Nome | Distância | Intensidade | Duração |
|--------|------|-----------|-------------|---------|
| **Layer 1** | Exploração | >60 studs | Baixa | Loop |
| **Layer 2** | Alerta | 30–60 studs | Média | Loop |
| **Layer 3** | Perseguição | <30 studs | Alta | Loop |

**Crossfade:** 2.0 segundos de transição suave entre camadas.

### Assets Necessários

| ID no Código | Descrição | Pesquisar no Toolbox | Tipo |
|-------------|-----------|---------------------|------|
| `Music_Layer1` | Drone ambiente escuro, tons graves, calmo | `horror ambient drone dark` | Loop |
| `Music_Layer2` | Cordas tensas, percussão leve, pulsação | `horror tension strings suspense` | Loop |
| `Music_Layer3` | Percussão intensa, metais, batimentos agressivos | `horror chase intense percussion` | Loop |

### Dicas para Encontrar

1. Abra o **Toolbox** no Roblox Studio
2. Selecione **Audio** no dropdown de categorias
3. Filtre por **"Free"** (gratuito)
4. Busque pelos termos indicados acima
5. Verifique se o som é **MONO** (não stereo)
6. Clique com botão direito → **Copy Asset ID** → cole no código

### Alternativas da Biblioteca Roblox

Se os termos acima não retornarem resultados, tente estas alternativas:

- **Layer 1:** `ambient dark`, `creepy atmosphere`, `haunted house background`
- **Layer 2:** `tension building`, `suspense music`, `horror strings`
- **Layer 3:** `chase music`, `intense horror`, `boss battle`, `panic`

---

## 💓 BATIMENTOS CARDÍACOS

Volume e velocidade aumentam linearmente com a proximidade do Caçador (0–40 studs).

| ID no Código | Descrição | Pesquisar no Toolbox |
|-------------|-----------|---------------------|
| `Heartbeat` | Batida de coração única (curta, ~1s) | `heartbeat sound effect` |

**Funcionamento:** O AudioManager altera o `PlaybackSpeed` (0.7 a 1.5x) para variar o ritmo.  
O som NÃO deve ser um loop — deve ser uma batida única que o script repete.

---

## 🎯 SFX — CAÇADOR (O DISTORCIDO)

| ID no Código | Habilidade | Descrição | Pesquisar no Toolbox |
|-------------|-----------|-----------|---------------------|
| `SFX_Killer_Slap` | M1 — Tapa | Impacto corpo a corpo, pancada seca | `slap hit impact` |
| `SFX_Killer_ArmStretch` | Q — Braço Esticado | Elástico esticando, som de "puxão" | `stretch elastic pull` |
| `SFX_Killer_RageTransform` | R — Rage | Rugido monstruoso, transformação | `monster roar transform` |
| `SFX_Killer_Scream` | E — Grito | Grito aterrorizante, agudo | `horror scream monster` |

---

## 🎯 SFX — SOBREVIVENTES

### Soldado

| ID no Código | Habilidade | Descrição | Pesquisar no Toolbox |
|-------------|-----------|-----------|---------------------|
| `SFX_Soldier_Dash` | Q — Dash Tático | Avanço rápido, whoosh | `dash whoosh fast` |
| `SFX_Soldier_Bazooka` | E — Bazuca | Lançamento de foguete/projétil | `bazooka rocket launch` |

### Sackboy

| ID no Código | Habilidade | Descrição | Pesquisar no Toolbox |
|-------------|-----------|-----------|---------------------|
| `SFX_Sackboy_InkGun` | Q — Arma de Tinta | Tinta espirrando, splat | `paint splat squish` |
| `SFX_Sackboy_Surge` | E — Surto | Rajada de velocidade | `speed boost rush` |

### Robô

| ID no Código | Habilidade | Descrição | Pesquisar no Toolbox |
|-------------|-----------|-----------|---------------------|
| `SFX_Robot_Grab` | Q — Agarrar | Garra metálica, mecânica | `robot grab mechanical` |
| `SFX_Robot_Block` | E — Block | Escudo metálico, bloqueio | `metal block shield` |
| `SFX_Robot_Sacrifice` | R — Sacrifício | Explosão de autodestruição | `explosion sacrifice` |

### Enfermeira

| ID no Código | Habilidade | Descrição | Pesquisar no Toolbox |
|-------------|-----------|-----------|---------------------|
| `SFX_Nurse_Heal` | Q — Curativo | Cura mágica, brilho | `heal magic sparkle` |
| `SFX_Nurse_Adrenaline` | E — Adrenalina | Seringa, injeção | `injection syringe` |

### Campeão

| ID no Código | Habilidade | Descrição | Pesquisar no Toolbox |
|-------------|-----------|-----------|---------------------|
| `SFX_Champion_Grab` | Q — Agarrão | Agarrão, gancho | `grab grapple hook` |
| `SFX_Champion_Combo` | E — Sequência | Socos rápidos, combo | `punch combo fighting` |

---

## 🎯 SFX — EVENTOS DO JOGO

| ID no Código | Evento | Descrição | Pesquisar no Toolbox |
|-------------|--------|-----------|---------------------|
| `SFX_Generator_Complete` | Gerador consertado | Som de "power up", máquina ligando | `generator power up complete` |
| `SFX_Generator_Alert` | Skill check falhou | Alarme alto, sirene | `alarm siren loud` |
| `SFX_AllGenerators_Done` | Todos os 5 prontos | Fanfarra curta, "completo" | `all complete fanfare short` |
| `SFX_Gate_Alarm` | Portão ativado | Alarme de portão, buzzer | `gate alarm buzzer` |
| `SFX_Gate_Open` | Portão abrindo | Metal pesado abrindo, rangido | `gate open heavy metal` |
| `SFX_Collapse_Alarm` | Colapso iniciado | Destruição, tremor, colapso | `collapse destruction rumble` |

---

## 🎯 SFX — RESULTADOS E COMBATE

| ID no Código | Evento | Descrição | Pesquisar no Toolbox |
|-------------|--------|-----------|---------------------|
| `SFX_Victory_Survivors` | Vitória Sobreviventes | Fanfarra alegre/triunfante | `victory fanfare survivors` |
| `SFX_Victory_Killer` | Vitória Caçador | Fanfarra sombria/vitoriosa | `victory dark killer` |
| `SFX_Escape` | Sobrevivente escapou | Porta fechando, fuga | `escape door close` |
| `SFX_Hit_Taken` | Dano recebido | Dor, "ouch", impacto | `hit taken ouch pain` |
| `SFX_Hit_Landed` | Dano causado | Pancada, impacto conectado | `hit landed punch impact` |
| `SFX_Heal` | Cura recebida | Poção, restauração | `heal restore potion` |
| `SFX_Shield` | Escudo ativado | Energia, barreira | `shield activate energy` |

---

## 🎯 SFX — SKILL CHECKS

| ID no Código | Evento | Descrição | Pesquisar no Toolbox |
|-------------|--------|-----------|---------------------|
| `SFX_SkillCheck_Success` | Acertou o clique | Som de "correto", confirmação | `click success correct` |
| `SFX_SkillCheck_Fail` | Errou o clique | Som de "erro", buzzer | `error fail buzzer` |

---

## 🌲 SONS AMBIENTES

Sons posicionais 3D tocados aleatoriamente ao redor dos sobreviventes.  
Intervalo: 8–25 segundos entre cada som.  
Spawn: raio de 10–40 studs do jogador.

| ID no Código | Descrição | Pesquisar no Toolbox |
|-------------|-----------|---------------------|
| `Ambient_Wind` | Vento uivando, assovio | `wind howl ambient` |
| `Ambient_WoodCreak` | Tábuas rangendo, madeira velha | `wood creak floorboard` |
| `Ambient_DistantThunder` | Trovão distante, trovoada | `distant thunder rumble` |
| `Ambient_Whisper` | Sussurro fantasmagórico | `whisper ghost creepy` |
| `Ambient_Floorboard` | Passos em tábua, piso rangendo | `floorboard step creak` |
| `Ambient_DoorCreak` | Porta rangendo, dobradiça | `door creak open` |

---

## 📊 RESUMO — TOTAL DE ASSETS

| Categoria | Quantidade |
|-----------|-----------|
| Música dinâmica (3 camadas) | 3 |
| Batimentos cardíacos | 1 |
| SFX — Caçador | 4 |
| SFX — Sobreviventes (5 classes) | 11 |
| SFX — Eventos do jogo | 6 |
| SFX — Resultados e combate | 7 |
| SFX — Skill checks | 2 |
| Sons ambientes | 6 |
| **TOTAL** | **40 assets** |

---

## 🔧 COMO SUBSTITUIR OS PLACEHOLDERS

Todos os IDs no arquivo `src/client/Audio/AudioManager.lua` são **placeholders** começando com `rbxassetid://183784...`.  
Siga estes passos para substituí-los:

### Passo 1: Encontrar o asset no Toolbox

1. Abra o Roblox Studio com o projeto Caçada Sombria
2. Abra o **Toolbox** (View → Toolbox)
3. Na barra de busca, digite o termo de pesquisa indicado na tabela acima
4. Filtre por **Audio** e marque **Free**

### Passo 2: Verificar qualidade

- O som é **MONO**? (Importante para 3D)
- A duração é adequada? (SFX: 0.5–3s, Música: 30s+, Ambiente: 2–8s)
- O volume é consistente com outros sons?
- Não tem artefatos ou ruídos indesejados?

### Passo 3: Obter o ID

1. Clique com botão direito no asset → **Copy Asset ID**
2. O ID virá no formato: `rbxassetid://NUMERO`
3. Substitua no arquivo `AudioManager.lua`

### Passo 4: Testar

1. Execute o jogo no Studio (Play → Run)
2. Verifique o console (F9) para mensagens `[CacadaSombria] AudioManager`
3. Teste cada som individualmente via comando no console:
   ```lua
   -- No console do cliente (F9):
   local am = require(game.StarterPlayer.StarterPlayerScripts.ClientManager.Audio.AudioManager)
   am:playSFX("SFX_Killer_Slap", nil, 1.0)
   ```

---

## ⚠️ PITFALLS E DICAS

### Som não toca?

1. Verifique se o asset ID está correto (formato `rbxassetid://NUMERO`)
2. Confirme que o asset é **gratuito** e você tem permissão de uso
3. Verifique se o `SoundService` está configurado no jogo
4. Sons 3D precisam de um `Parent` na `Workspace` (o AudioManager cria âncoras automáticas)
5. Se for som local, o `Parent` deve ser `SoundService`

### Som stereo vs mono?

- Sons **stereo** NÃO são espacializados corretamente no Roblox
- O Roblox Engine trata sons stereo como "2D" (tocado no centro)
- Sempre use sons **MONO** para efeitos posicionais 3D
- Música de fundo pode ser stereo (tocada no SoundService, sem posição)

### Performance

- Limite de sons simultâneos no Roblox: ~50 por cliente
- O AudioManager faz cleanup automático de sons finalizados
- Música em loop: 3 sons tocando simultaneamente
- SFX: típico 5-10 sons simultâneos
- Ambiente: 1-2 sons por vez
- **Total típico: <15 sons simultâneos** — bem dentro do limite

### Volume

- Volume mestre controlado pelo `SoundGroup` "GameAudio"
- Cada categoria tem volume base diferente:
  - Música: 1.0
  - Batimentos: 0.0–1.0 (dinâmico)
  - SFX habilidades: 0.6–1.0
  - SFX UI: 0.5–1.0
  - Ambiente: 0.5
- O servidor pode sobrescrever volumes por distância

---

## 🚀 PRÓXIMOS PASSOS

1. [ ] Substituir todos os 40 placeholders por IDs reais
2. [ ] Testar crossfade entre as 3 camadas de música
3. [ ] Testar batimentos cardíacos com variação de distância
4. [ ] Testar SFX de cada habilidade (Caçador + 5 Sobreviventes)
5. [ ] Testar sons ambientes aleatórios
6. [ ] Testar sons de UI (skill checks, vitória, derrota)
7. [ ] Balancear volumes entre categorias
8. [ ] Adicionar sons específicos por classe no futuro (ex: som único da Bazuca do Soldado)

---

## 📞 Suporte

Dúvidas? Consulte:
- `docs/architecture.md` — Seção "Áudio — Arquitetura de Camadas Dinâmicas" (linhas 639–683)
- [Documentação oficial de Áudio do Roblox](https://create.roblox.com/docs/sound)
- `src/server/Services/AudioService.lua` — Lógica do servidor
- `src/client/Audio/AudioManager.lua` — Reprodução no cliente
