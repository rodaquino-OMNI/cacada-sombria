# Caçada Sombria — Registro de Decisões (Decision Log)

**Criado:** 2026-06-28
**Propósito:** Rastrear cada decisão de design, mudança e transição de versão durante o desenvolvimento do GDD.

---

## Decisões de Design

### D001 — Tipo de Jogo: Horror (Assimétrico PvP)
- **Data:** 2026-06-28
- **Decisão:** Classificar Caçada Sombria como game type "horror" (do catálogo `game-types.csv`), com tags: atmosfera, tensão, medo.
- **Justificativa:** O jogo combina terror atmosférico com PvP assimétrico. O gênero horror captura os pilares de Tensão e Gato-e-Rato, enquanto a assimetria é modelada como mecânica primária dentro deste framework.
- **Nota:** A tag `survival` do CSV não se aplica por não haver crafting/recursos — a escassez é inerente à assimetria. A tag `moba` também não se aplica por não haver lanes, economia ou times simétricos.
- **Impacto:** GDD segue o template de horror com seções de Atmosphere, Fear Mechanics, Enemy/Threat Design, Resource Scarcity, Safe Zones e Puzzle Integration.
- **Narrative flag:** `needs_narrative = true` (horror tem `<narrative-workflow-recommended>`).

### D002 — Caçador MVP: O Distorcido (não O Espectro)
- **Data:** 2026-06-28
- **Decisão:** O Caçador do MVP é "O Distorcido", não "O Espectro" como mencionado no Game Brief original.
- **Justificativa:** A evolução de design (capturada no addendum e contexto da tarefa) substituiu o conceito inicial do Espectro (visão através de paredes como habilidade principal) por um design mais completo e distinto — O Distorcido com 4 habilidades (M1, Braço Esticado, Rage, Grito) e mecânica de Fúria.
- **Impacto:** A visão através de paredes do Espectro foi absorvida como componente do Grito do Distorcido (revelação em 100 studs por 4s). O design do Espectro é considerado obsoleto.

### D003 — 5 Classes de Sobreviventes no MVP
- **Data:** 2026-06-28
- **Decisão:** Incluir todas as 5 classes de Sobreviventes no MVP, não apenas um modelo base genérico.
- **Justificativa:** O contexto da tarefa especifica 5 Sobreviventes completos com habilidades, HP e velocidades distintas. O MVP deve validar não apenas o core loop, mas a diversidade de classes — que é um dos diferenciais do jogo.
- **Impacto:** Épico E3 cobre todas as 5 classes. O escopo do MVP aumenta (5-7 dias para E3), mas a validação é mais rica.

### D004 — 4 Sobreviventes por Partida
- **Data:** 2026-06-28
- **Decisão:** Partidas têm 4 Sobreviventes simultâneos (escolhidos entre 5 classes disponíveis).
- **Justificativa:** O contexto especifica "1 Killer vs 4 Survivors per match". Este número equilibra o tamanho do mapa (8-10 salas), a dinâmica de perseguição e a capacidade de cooperação.
- **Impacto:** Condição de vitória do Caçador: capturar 4 (todos). Balanceamento de 5 geradores com 4 jogadores.

### D005 — Sistema de Jaulas (não Ganchos)
- **Data:** 2026-06-28
- **Decisão:** Sobreviventes capturados vão para jaulas, não ganchos (como em Dead by Daylight).
- **Justificativa:** Jaulas são mais temáticas para o universo de brinquedos/toy horror. Além disso, simplifica a implementação (posições fixas no mapa) sem sacrificar profundidade (timer de 120s, resgate em 3s, invulnerabilidade pós-resgate).
- **Impacto:** Design de captura documentado como M3 e detalhado no Épico E6.

### D006 — Lobby Local (Host) para MVP
- **Data:** 2026-06-28
- **Decisão:** MVP usa lobby local onde o host cria sala e amigos entram. Sem matchmaking automatizado ou servidores dedicados.
- **Justificativa:** O desenvolvedor é iniciante em networking Roblox. Modelo host = servidor reduz complexidade técnica. Matchmaking exige servidores dedicados e filas — pós-MVP.
- **Impacto:** Épico E7 focado em lobby simples. Sem dependência de DataStore ou serviços externos.

### D007 — 5 Geradores + Portão (mecânica de fuga)
- **Data:** 2026-06-28
- **Decisão:** Objetivo dos Sobreviventes é consertar 5 geradores para abrir o portão de fuga.
- **Justificativa:** Inspirado em Dead by Daylight — é uma mecânica comprovada, intuitiva e que força os Sobreviventes a se espalharem. Os QTE (skill checks) adicionam camada de habilidade e risco. O número 5 foi validado pelo contexto.
- **Impacto:** Design documentado como M1 e M2. Épico E5 dedicado ao sistema de objetivos.

### D008 — Sem Cura Passiva
- **Data:** 2026-06-28
- **Decisão:** HP dos Sobreviventes não regenera passivamente. Apenas Enfermeira (Curativo, 25 HP) e Robô (Block, 10 HP) podem curar.
- **Justificativa:** Reforça o pilar de Cooperação Estratégica — a Enfermeira é essencial para sustentar a equipe. Cura limitada aumenta a tensão (pilar 2). Robô como exceção (só se cura com Block) cria identidade de tanque auto-suficiente.
- **Impacto:** Balanceamento de dano do Caçador assume cura limitada. Enfermeira se torna alvo prioritário do Caçador.

### D009 — Sem Lanternas ou Ferramentas de Luz no MVP
- **Data:** 2026-06-28
- **Decisão:** Sobreviventes não têm lanternas. A escuridão é ameaça ambiental, não recurso gerenciável.
- **Justificativa:** Simplifica o MVP sem sacrificar a atmosfera de terror. A escuridão do porão (20% luminosidade) já cria tensão suficiente. Lanternas podem ser adicionadas pós-MVP como ferramenta de contra-jogo.
- **Impacto:** Sem sistema de bateria ou durabilidade. Design de escuridão é puramente ambiental.

### D010 — Balanceamento: 45-55% Win Rate para Caçador
- **Data:** 2026-06-28
- **Decisão:** Meta de balanceamento: Caçador vence 45-55% das partidas.
- **Justificativa:** Em jogos assimétricos, uma leve vantagem do Caçador (50-55%) é aceitável para manter a fantasia de poder. Abaixo de 45%, Sobreviventes dominam e o Caçador perde apelo. Os números de HP, dano e cooldown foram definidos como ponto de partida; ajustes virão do playtest (E9).
- **Impacto:** Métricas de sucesso incluem win rate como indicador chave.

---

## Transições de Versão

### v1.0 → Criação Inicial
- **Data:** 2026-06-28
- **Arquivos:** `gdd.md` (completo), `epics.md` (completo), `decision-log.md` (este arquivo)
- **Resumo:** Primeira versão completa do GDD. Caçador MVP = O Distorcido. 5 classes de Sobreviventes. Mapa = Mansão Abandonada. 9 épicos de desenvolvimento.

---

## Perguntas em Aberto (Respondidas Durante o GDD)

| Pergunta Original (do Brief) | Resolução |
|------------------------------|-----------|
| Tema exato do primeiro Caçador | O Distorcido — criatura físico-distinta com transformação (Rage). Mais viável mecanicamente que o Espectro. |
| Mecânica de fuga específica | Geradores (estilo DBD) — 5 geradores + portão. Com QTE de skill check. |
| Sistema de progressão | Pós-MVP. MVP sem progressão persistente. |
| Monetização | Pós-MVP. MVP gratuito sem compras. |
| Número ideal de Sobreviventes | 4 por partida (de 5 classes disponíveis). |
| Habilidades dos Sobreviventes | Classes fixas com habilidades definidas. Sem perks customizáveis no MVP. |
| Matchmaking / jogadores saindo | Lobby local no MVP. Se jogador sai: vai direto para jaula. Se Caçador sai: partida encerra. |

---

## Itens Deferidos (Pós-MVP)

| Item | Justificativa do Adiamento |
|------|---------------------------|
| 3 Caçadores adicionais | MVP valida com 1. Design completo está no GDD. |
| 2 mapas adicionais | MVP valida com 1. |
| Sistema de progressão completo | Adiciona complexidade de DataStore desnecessária para MVP. |
| Monetização | Não bloqueia validação do core loop. |
| Servidores dedicados + matchmaking | Infraestrutura complexa, pós-validação. |
| Modo espectador | Qualidade de vida pós-MVP. |
| Perks customizáveis | Balanceamento complexo, classes já oferecem variedade. |
| Tutorial interativo | Dicas contextuais suprem MVP. |
| Bot AI (preencher vagas) | Lobby local supre com amigos. |
