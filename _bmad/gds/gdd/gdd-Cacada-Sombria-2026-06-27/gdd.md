---
title: "Caçada Sombria"
game_type: horror
platforms:
  - Roblox
created: 2026-06-27
updated: 2026-06-28
author: familia
status: draft
---

# Caçada Sombria — Game Design Document

**Autor:** familia
**Tipo de Jogo:** Terror Assimétrico (Horror — PvP Multijogador)
**Plataforma:** Roblox (exclusivo)
**Data:** 28 de Junho de 2026

---

## Resumo Executivo

### Conceito Central

Caçada Sombria é um jogo multijogador assimétrico de terror e sobrevivência para Roblox. Em cada partida, **1 jogador assume o papel de um Caçador** — uma criatura sobrenatural com habilidades únicas e aterradoras — enquanto **4 jogadores cooperam como Sobreviventes** tentando consertar geradores, abrir o portão de fuga e escapar antes de serem capturados.

Cada lado joga um jogo completamente diferente: o Caçador é forte, solitário e implacável; os Sobreviventes são frágeis individualmente mas capazes de virar o jogo através de cooperação, comunicação e uso inteligente de habilidades de classe.

Inspirado por *Dead by Daylight*, *Pwned by 14* e *Flee the Facility*, o jogo entrega a fantasia central de ser o predador implacável ou a presa que precisa usar tudo que tem para sobreviver — com a acessibilidade e o ritmo rápido que o público do Roblox espera.

### Público-Alvo

- **Primário:** Jogadores de Roblox entre 12 e 18 anos que curtem jogos competitivos, experiências multiplayer sociais e terror leve/acessível (sem gore, sem jumpscares excessivos).
- **Secundário:** Jogadores mais velhos (18+) familiarizados com o gênero assimétrico que buscam uma versão casual e rápida dentro do ecossistema Roblox.

### Diferenciais (USPs)

1. **Acessibilidade Roblox-first:** Projetado nativamente para Roblox — controles, desempenho e audiência — não um port de outra plataforma.
2. **Terror moderado:** Atmosfera sombria e tensão sem sangue, gore ou jumpscares gratuitos. Adequado para 12+.
3. **Assimetria profunda mas acessível:** Cada Caçador e cada Sobrevivente têm habilidades únicas com identidade forte, mas curvas de aprendizado graduais.
4. **Posições aleatórias por partida:** Geradores, jaulas e esconderijos mudam de posição a cada partida no mesmo mapa, garantindo rejogabilidade sem precisar de dezenas de mapas.
5. **MVP enxuto e realista:** Escopo controlado para um desenvolvedor iniciante — 1 Caçador, 1 Mapa, 5 Sobreviventes, lobby local. Documentação completa que serve como aprendizado.

---

## Objetivos e Contexto

### Objetivos do Projeto

1. **Validar a dinâmica assimétrica no Roblox:** Provar que jogadores de Roblox se divertem com Caçador vs Sobreviventes em partidas de 8–12 minutos.
2. **Entregar um MVP jogável e polido em 3–4 semanas:** Foco em um Caçador, um Mapa e o loop principal funcional com todas as 5 classes de Sobreviventes.
3. **Servir como plataforma de aprendizado:** O desenvolvedor (iniciante em Roblox Studio e Luau) aprende fazendo — cada sistema documentado, cada decisão justificada.
4. **Base para expansão:** O design do MVP é modular — novos Caçadores, mapas e sistema de progressão são planejados para fases posteriores.

### Contexto e Justificativa

O gênero assimétrico tem bases sólidas no Roblox (Pwned by 14, Flee the Facility) e fora dele (Dead by Daylight, 60M+ jogadores). No entanto, muitos títulos do gênero no Roblox são ou complexos demais ou rasos demais. Caçada Sombria ocupa o espaço do "assimétrico acessível mas com profundidade estratégica" — mais tático que Flee the Facility, menos complexo que Pwned by 14.

O projeto é desenvolvido por um único desenvolvedor iniciante (`familia`), que está aprendendo Roblox Studio e Luau durante o processo. O GDD serve como fonte canônica de verdade para todas as decisões de design, alimentando as fases de arquitetura (`gds-game-architecture`) e criação de épicos e histórias (`gds-create-epics-and-stories`).

---

## Gameplay Principal

### Pilares do Jogo

| Pilar | Descrição |
|-------|-----------|
| **P1 — Poder Assimétrico** | Cada lado joga um jogo completamente diferente. O Caçador é forte, solitário e implacável — sua presença domina o mapa. Os Sobreviventes são frágeis individualmente mas fortes em equipe — cada classe traz uma capacidade única que, combinada, pode virar a partida. A assimetria não está só nos números, mas na experiência: Caçador joga na primeira pessoa; Sobreviventes na terceira. |
| **P2 — Tensão e Gato-e-Rato** | Cada partida é uma montanha-russa emocional: momentos de silêncio tenso e furtividade interrompidos por perseguições frenéticas. A proximidade do Caçador é sentida através de áudio (batimentos cardíacos, passos), distorção visual (grito) e a constante incerteza de onde ele está. Ninguém está seguro por muito tempo. |
| **P3 — Cooperação Estratégica** | Sobreviventes precisam se comunicar, dividir tarefas e arriscar-se para salvar aliados capturados. Jogar sozinho é quase sempre fatal. Classes foram projetadas para sinergia: a Enfermeira cura, o Campeão enfrenta, o Robô se sacrifica, o Soldado controla, o Sackboy atrapalha. |
| **P4 — Variedade e Rejogabilidade** | Múltiplos Caçadores com habilidades radicalmente diferentes, 5 classes de Sobreviventes com identidades próprias, posições aleatórias de objetivos a cada partida e um mapa com rotas e esconderijos variados. Nenhuma partida é igual à anterior. |

### Loop Principal de Gameplay

```
┌──────────────────────────────────────────────────────────┐
│ 1. PREPARAÇÃO                                            │
│    Sobreviventes spawnam em posições aleatórias.         │
│    Caçador spawna em local fixo.                         │
│    Timer de 5s antes do início da caçada.                │
├──────────────────────────────────────────────────────────┤
│ 2. CAÇA                                                  │
│    Caçador patrulha usando sentidos e habilidades.       │
│    Sobreviventes consertam geradores, se escondem,       │
│    movem-se furtivamente e se ajudam.                    │
├──────────────────────────────────────────────────────────┤
│ 3. PERSEGUIÇÃO                                           │
│    Encontro Caçador–Sobrevivente → perseguição intensa.  │
│    Sobrevivente usa obstáculos, habilidades defensivas   │
│    e looping para escapar.                               │
│    Caçador usa M1, Braço Esticado e Grito para capturar. │
├──────────────────────────────────────────────────────────┤
│ 4. CAPTURA OU FUGA                                       │
│    Sobrevivente derrubado → levado para jaula.           │
│    Aliados podem resgatar (3s, interrompível).           │
│    Todos capturados → Caçador vence.                     │
│    5 geradores → portão aberto → Sobreviventes escapam.  │
└──────────────────────────────────────────────────────────┘
```

### Condições de Vitória e Derrota

| Condição | Vencedor | Gatilho |
|----------|----------|---------|
| **Captura Total** | Caçador | Todos os 4 Sobreviventes estão em jaulas simultaneamente. |
| **Fuga** | Sobreviventes | Pelo menos 1 Sobrevivente escapa pelo portão de saída após todos os 5 geradores serem consertados. |
| **Tempo Esgotado** | Caçador | Após 15 minutos de partida sem fuga (mecanismo de fim de jogo — collapse). |

**Regra de fuga parcial:** Se pelo menos 1 Sobrevivente escapar, a vitória é dos Sobreviventes (vitória de equipe). O objetivo do Caçador é evitar QUALQUER fuga. Esta regra incentiva os Sobreviventes a arriscarem-se para salvar aliados e desencoraja o Caçador de "acampar" um único sobrevivente.

---

## Mecânicas do Jogo

### Mecânicas Primárias

#### M1 — Geradores

- **Quantidade:** 5 geradores espalhados pelo mapa.
- **Posicionamento:** Aleatório a cada partida, dentro de spawn points pré-definidos no layout da Mansão Abandonada.
- **Mecânica de reparo:**
  - Sobrevivente interage com o gerador (tecla E, 3s de canalização).
  - Durante o reparo, o Sobrevivente fica vulnerável — não pode se mover.
  - O gerador emite som audível em raio de 40 studs, alertando o Caçador.
  - Ao terminar o reparo, o gerador acende uma luz verde e para de emitir som.
- **Testes de Perícia (Skill Checks):** A cada 1s de reparo, um QTE circular aparece. Se o jogador errar, o gerador perde 10% do progresso e emite um som alto (alerta global para o Caçador). Se acertar, ganha 5% de bônus de progresso.
- **Progresso do reparo:** 100% por gerador. O progresso persiste se interrompido.

#### M2 — Portão de Fuga

- **Ativação:** Disponível apenas quando os 5 geradores estão consertados.
- **Posição:** 2 portões em lados opostos do mapa (ambos abrem simultaneamente quando o primeiro é ativado).
- **Mecânica:** Sobrevivente interage com a alavanca do portão (3s). Após ativado, o portão abre lentamente ao longo de 8s, emitindo som audível em 60 studs.
- **Fuga:** Sobrevivente atravessa o portão aberto → escapa da partida.
- **Fim de jogo por collapse:** Se o tempo da partida atingir 15 minutos sem escape, o portão abre automaticamente por 30s e depois fecha permanentemente (mecanismo anti-stall).

#### M3 — Captura e Jaula

- **Derrubada (Down):**
  - Quando o HP de um Sobrevivente chega a 0, ele cai no estado "Derrubado" (downed).
  - No estado Derrubado: move-se a 30% da velocidade base, não pode usar habilidades, pode ser carregado pelo Caçador.
  - Após 60s no estado Derrubado sem ser capturado, o Sobrevivente morre automaticamente e reaparece em uma jaula aleatória.
- **Transporte:**
  - Caçador interage com Sobrevivente derrubado para carregá-lo (1.5s de animação).
  - Enquanto carrega: Caçador move-se a 80% da velocidade, não pode atacar ou usar habilidades.
  - Sobrevivente carregado pode se debater (preenche barra de luta em 10s) para se libertar, atordoando o Caçador por 2s.
- **Jaula:**
  - Caçador deposita o Sobrevivente em uma jaula (2s de animação).
  - Jaulas são posições fixas no mapa (5 jaulas, posições aleatórias por partida).
  - Sobrevivente na jaula: não pode se mover ou usar habilidades. Pode girar a câmera e usar chat.
  - Duração da jaula: 120s. Após o tempo, o Sobrevivente é eliminado da partida.
  - **Libertação:** Aliado interage com a jaula por 3s. Se interrompido, o progresso reseta. Libertação bem-sucedida restaura o Sobrevivente com 50% do HP máximo.

#### M4 — Furtividade

- **Agachar:** Reduz o raio de passos audíveis de 30 studs para 10 studs.
- **Esconderijos:** Armários, atrás de móveis, embaixo de escadas. Entrar/sair leva 1s.
  - Dentro do esconderijo: Sobrevivente não é visível ao Caçador a menos que o Caçador esteja a 5 studs de distância e olhando diretamente.
  - Capacidade: 1 Sobrevivente por esconderijo.
- **Correr:** Aumenta a velocidade em 2 studs/s, mas faz passos audíveis em 50 studs e consome stamina.

#### M5 — Stamina dos Sobreviventes

- **Capacidade:** 100 pontos de stamina.
- **Consumo ao correr:** 20 pontos por segundo.
- **Regeneração:** 10 pontos por segundo quando não está correndo.
- **Quando esgotada:** Não pode correr por 3s. Regeneração inicia após 1s de pausa.

### Mecânicas do Caçador

#### M6 — Rage (Fúria — exclusiva de O Distorcido)

- **Medidor de Fúria:** Barra de 0 a 100.
- **Ganho de Fúria:**
  - Causar dano a Sobrevivente: +15 de Fúria.
  - Receber dano ou atordoamento: +10 de Fúria.
  - Sobrevivente resgatado de jaula próxima (40 studs): +20 de Fúria.
- **Ativação da Transformação (Rage):**
  - Disponível apenas quando o medidor está em 100.
  - Duração: 30 segundos.
  - Durante a transformação: o timer da partida pausa.
  - Efeitos da Rage: velocidade aumentada para 28, dano do M1 aumentado para 25. Visual: o Caçador revela sua forma verdadeira — uma criatura negra alta e distorcida.
  - Após 30s: retorna à forma normal. Medidor de Fúria zera.

#### M7 — Visão do Caçador

- **Perspectiva:** Primeira pessoa (Caçador).
- **Campo de visão:** 90° horizontal.
- **Indicadores visuais:** Sobreviventes que fazem barulho (correr, falhar skill check, usar habilidade) geram uma notificação visual no HUD do Caçador (marcador direcional).

### Controles e Input

#### Sobreviventes (Terceira Pessoa)

| Ação | Input (PC) | Input (Mobile) |
|------|-----------|----------------|
| Mover | WASD | Joystick virtual esquerdo |
| Olhar | Mouse | Toque/arrastar na tela |
| Correr | Shift (segurar) | Botão dedicado (segurar) |
| Agachar | Ctrl (toggle) | Botão dedicado (toggle) |
| Interagir (gerador, jaula, esconderijo) | E | Botão de interação (contextual) |
| Habilidade 1 | Q | Botão de habilidade 1 |
| Habilidade 2 | Botão Direito | Botão de habilidade 2 |
| Habilidade 3 (Robô) | F | Botão de habilidade 3 |

#### Caçador (Primeira Pessoa)

| Ação | Input (PC) | Input (Mobile) |
|------|-----------|----------------|
| Mover | WASD | Joystick virtual esquerdo |
| Olhar | Mouse | Toque/arrastar na tela |
| M1 (Ataque Básico) | Clique Esquerdo | Botão de ataque |
| Habilidade 1 (Braço Esticado) | Q | Botão de habilidade 1 |
| Habilidade 2 (Grito) | E | Botão de habilidade 2 |
| Habilidade 3 (Rage) | R | Botão de habilidade 3 |
| Interagir (carregar, jaula) | F | Botão de interação (contextual) |

### Mecânicas Específicas do Gênero (Horror)

---

## Design Específico de Terror

### Atmosfera e Construção de Tensão

#### Design Visual de Atmosfera

- **Paleta de cores:** Azul escuro, roxo profundo, preto e cinza para o ambiente. Detalhes em vermelho desaturado e âmbar para elementos de perigo e o Caçador.
- **Iluminação:** Iluminação dramática com alto contraste. Luzes piscantes em corredores. Feixes de luz da lua entrando por janelas quebradas. Áreas de escuridão quase total no porão.
- **Névoa volumétrica leve:** Presente no porão e em áreas externas (jardim da mansão), reduzindo visibilidade e criando silhuetas ameaçadoras.
- **Decoração ambiental:** Retratos de família rasgados, móveis cobertos com panos empoeirados, livros espalhados, manchas escuras nas paredes. A mansão conta a história de uma família que desapareceu misteriosamente.

#### Design de Áudio de Tensão

- **Trilha dinâmica em camadas:**
  - **Camada 1 (Exploração):** Tons graves ambientes, notas de piano esparsas, cordas suaves.
  - **Camada 2 (Alerta — Caçador a 60 studs):** Cordas em crescendo, percussão leve.
  - **Camada 3 (Perseguição — Caçador a 30 studs):** Percussão intensa, metais, ritmo cardíaco acelerado.
  - Transições entre camadas são graduais (crossfade de 2s).
- **Efeitos sonoros de tensão:**
  - Batimentos cardíacos do Sobrevivente (volume e ritmo aumentam com proximidade do Caçador).
  - Rangidos de madeira aleatórios (independem de jogadores, mantêm o jogador em alerta).
  - Sussurros abafados em áreas específicas.
  - Passos do Caçador com peso distinto (graves, com leve distorção).

#### Ritmo de Tensão

- **Estrutura de 3 atos por partida:**
  - **Ato 1 (0–3 min):** Tensão baixa. Sobreviventes se espalham, primeiros geradores. Caçador patrulha. Encontros são raros.
  - **Ato 2 (3–10 min):** Tensão alta. Sobreviventes foram localizados, algumas jaulas já ocorreram. Perseguições e resgates. Rage do Caçador provavelmente ativada.
  - **Ato 3 (10–15 min):** Tensão máxima. 3+ geradores concluídos. Caçador desesperado para impedir a fuga. Portão aberto, decisões de vida ou morte.
- **Sem jumpscares programados:** O terror vem da antecipação e da perseguição, não de sustos baratos. O momento mais assustador deve ser ouvir os passos do Caçador se aproximando enquanto você conserta um gerador.

### Mecânicas de Medo

#### Visibilidade e Escuridão

- **Iluminação variável por área:**
  - Salas principais: 60% de luminosidade.
  - Corredores: 40% de luminosidade.
  - Porão: 20% de luminosidade (quase escuridão total, apenas feixes de luz).
- **Sem lanterna para Sobreviventes no MVP:** A escuridão é uma ameaça ambiental, não um recurso gerenciável. Força o uso de conhecimento do mapa e áudio.
- **Silhueta do Caçador:** O Caçador é sempre levemente mais escuro que o ambiente. Na escuridão, muitas vezes é visto como uma silhueta recortada contra fontes de luz distantes.

#### Vulnerabilidade

- **Sobreviventes não podem atacar o Caçador** (exceto Campeão com Agarrão e Soldado com Bazuca, que causam knockback/controle, não dano letal).
- **Sem bloqueio ou esquiva:** A única defesa é posicionamento, furtividade e habilidades de classe.
- **Stamina limitada:** Correr é um recurso finito. Usar na hora errada significa não ter como escapar depois.
- **Interação deixa vulnerável:** Consertar gerador, resgatar aliado ou abrir portão são ações que travam o jogador no lugar.

#### Indicadores de Proximidade

- **Batimentos cardíacos:** Audíveis para o Sobrevivente quando o Caçador está a 40 studs. Intensidade e ritmo aumentam linearmente com a proximidade.
- **Efeito visual de distorção:** Borda da tela do Sobrevivente começa a escurecer quando o Caçador está a 20 studs.

### Design de Inimigo/Ameaça

#### O Distorcido (Caçador MVP)

| Atributo | Valor |
|----------|-------|
| **HP** | 1100 |
| **Velocidade base** | 26 studs/s |
| **Velocidade em Rage** | 28 studs/s |
| **Aparência base** | Humanoide quebrado/distorto — como se cada articulação estivesse no ângulo errado. Roupas rasgadas e sujas, pele acinzentada. |
| **Aparência em Rage** | Transforma-se em uma criatura negra, alta e distorcida. Membros alongados, ausência de rosto (apenas duas fendas brilhantes onde deveriam estar os olhos). Uma aura escura emana do corpo. |
| **Som de passos** | Passos pesados com um eco distorcido — como se o som fosse levemente deslocado da posição real. |
| **Música de proximidade** | Drone grave com camadas de distorção e sussurros ininteligíveis. |

#### Habilidades d'O Distorcido

**1. M1 — Tapa (Ataque Básico)**
- **Dano:** 20 (25 em Rage).
- **Alcance:** 6 studs à frente do Caçador.
- **Velocidade:** 0.6s de windup, 0.3s de recovery.
- **Ao acertar:** Empurra o Sobrevivente 3 studs para trás + animação de impacto.
- **Cooldown:** 0.8s entre ataques.

**2. Q — Braço Esticado (Pull)**
- **Descrição:** O braço do Caçador se estica em linha reta na direção da mira. Se atingir um Sobrevivente, o puxa em direção ao Caçador.
- **Alcance:** 40 studs.
- **Largura do projétil:** 2 studs (hitbox estreita, exige precisão).
- **Velocidade do braço:** 60 studs/s (atinge o alcance máximo em 0.67s).
- **Efeito no Sobrevivente atingido:** Puxado até ficar a 4 studs do Caçador. Atordoado por 0.5s após ser puxado.
- **Windup:** 0.4s (braço recua antes de esticar — dica visual para o Sobrevivente).
- **Recovery:** 0.6s após o braço retornar.
- **Cooldown:** 12s.

**3. R — Rage (Transformação)**
- **Descrição:** Ativa a forma alternativa do Caçador. O Distorcido revela sua verdadeira forma — uma criatura negra e distorcida.
- **Condição:** Medidor de Fúria em 100.
- **Duração:** 30s.
- **Efeitos durante Rage:**
  - Velocidade aumentada para 28 studs/s.
  - Dano do M1 aumentado para 25.
  - Timer da partida pausa (a duração da partida é estendida).
  - Todas as outras habilidades funcionam normalmente.
  - Visual: transformação instantânea com efeito de partículas escuras.
- **Ao terminar:** Retorna à forma normal. Medidor zera. Sem penalidade pós-Rage.
- **Som de ativação:** Rugido distorcido audível em todo o mapa (alerta global).

**4. E — Grito (Scream)**
- **Descrição:** O Caçador emite um grito sobrenatural que afeta todos os Sobreviventes no alcance.
- **Windup:** 0.8s (Caçador para e emite partículas sonoras visíveis).
- **Raio de Lentidão + Visão Turva:** 60 studs.
  - Efeito: Sobreviventes dentro deste raio têm velocidade reduzida em 40% por 3s e a tela fica borrada (dificultando navegação e perseguição).
- **Raio de Revelação:** 100 studs.
  - Efeito: Todos os Sobreviventes dentro de 100 studs são revelados ao Caçador (silhueta visível através de paredes) por 4s após o grito.
  - Nota: Sobreviventes a 60–100 studs recebem apenas a revelação, não o slow/blur.
- **Recovery:** 1s após o grito.
- **Cooldown:** 25s.

#### Estratégia de Patrulha do Caçador

- **Início da partida:** Caçador spawna no hall principal da mansão. Primeiros 30s: patrulhar geradores prováveis.
- **Meio da partida:** Usar Grito para revelar posições e isolar Sobreviventes. Braço Esticado para punir erros de posicionamento. Construir Fúria para a Transformação.
- **Fim da partida:** Com geradores quase prontos, patrulhar os dois portões. Usar Grito para verificar quem está tentando abrir.
- **Contra Sobreviventes específicos:**
  - Enfermeira é prioridade (cura aliados).
  - Campeão é perigoso (pode agarrar o Caçador).
  - Robô é resistente mas lento — cercar, não perseguir em linha reta.

### Escassez de Recursos

Como jogo assimétrico, a escassez é inerente ao papel de Sobrevivente:

- **HP limitado:** Cada erro contra o Caçador custa HP. A única cura disponível é via Enfermeira (Curativo, 25 HP, 18s de cooldown) ou Robô (Block, 10 HP de autocura). Não há itens de cura no mapa.
- **Stamina finita:** Correr demais significa ficar sem fôlego na hora crítica.
- **Tempo de jaula:** Um aliado na jaula tem 120s para ser salvo. Isso cria pressão sobre a equipe — resgatar significa expor outro Sobrevivente.
- **Sem recursos de luz:** Não há lanternas ou baterias. A escuridão do porão é permanente.

### Zonas Seguras e Respiro

#### Esconderijos

- **Tipos:** Armários, atrás de móveis grandes, embaixo de escadas.
- **Quantidade por mapa:** ~15 esconderijos (distribuídos pelos 2 andares + porão).
- **Mecânica de segurança:** Dentro do esconderijo, o Sobrevivente é indetectável a menos que o Caçador esteja a 5 studs e olhando diretamente.
- **Duração máxima:** 20s dentro do esconderijo. Após isso, o Sobrevivente sai automaticamente (ofegante, emitindo som). Força o uso tático, não o abuso.

#### Zonas de Transição

- **Escadas e cantos:** Oferecem quebra de linha de visão. O Caçador (primeira pessoa) perde o rastro facilmente em corredores com curvas.
- **Salas com múltiplas saídas:** Permitem rotas de fuga com 2+ opções, recompensando conhecimento do mapa.

#### Estado Pós-Resgate

- Após ser resgatado da jaula, o Sobrevivente ganha 3s de invulnerabilidade (não pode ser atacado). Permite reposicionamento sem ser imediatamente derrubado de novo.

### Integração de Puzzles

#### Geradores como Puzzles Rítmicos

- Os QTE (Skill Checks) durante o reparo de geradores são o elemento de "puzzle" do jogo.
- **Agulha oscilante:** Um ponteiro gira em sentido horário. Uma zona de sucesso (30° do círculo) aparece a cada 1s.
- **Acerto:** +5% de bônus de progresso + som de clique satisfatório.
- **Erro:** -10% de progresso + faísca elétrica + som alto (alerta global para o Caçador).
- **Dificuldade progressiva:** A cada gerador concluído, a zona de sucesso diminui (30° → 25° → 20° → 18° → 15°) e a velocidade do ponteiro aumenta levemente.

#### Conhecimento do Mapa como Puzzle

- Não há minimapa. O Sobrevivente aprende o layout da mansão através da exploração.
- Geradores não têm indicadores direcionais — o jogador os encontra por tentativa e erro ou seguindo o som (zumbido elétrico leve, audível a 30 studs).
- Isso transforma a navegação em um puzzle ambiental que recompensa experiência e comunicação da equipe.

---

## Personagens — Elenco Completo

### Caçadores

#### 1. O DISTORCIDO (MVP)

- **HP:** 1100
- **Velocidade:** 26 studs/s (28 em Rage)
- **Aparência:** Humanoide quebrado e distorcido. Articulações em ângulos impossíveis. Roupas rasgadas e sujas. Pele acinzentada e esticada sobre ossos proeminentes. Quando a Fúria preenche o medidor, revela sua forma verdadeira: uma criatura negra, alta e distorcida, com membros alongados, rosto ausente e duas fendas brilhantes onde deveriam estar os olhos.
- **Lore:** "Ninguém sabe o que aconteceu com o antigo morador da mansão. Dizem que ele tentou algo proibido no porão — e pagou com sua humanidade. Agora, O Distorcido vaga pelo que restou de sua casa, arrastando qualquer intruso para as sombras com seus membros desarticulados. Às vezes, quando a fúria o consome, você ainda pode ver o que ele era — por um instante, nos olhos da criatura."
- **Habilidades:** Descritas na seção Design de Inimigo/Ameaça acima.

#### 2. BONECO DE PANO (Futuro — Pós-MVP)

- **HP:** 400
- **Velocidade:** 26 studs/s
- **Aparência:** Um boneco de pano (sackboy) rasgado, com uma pedra brilhante no lugar do zíper. A cor da pedra muda conforme o modo do laser: VERMELHO = ataque, VERDE = cura, AZUL = lentidão. Movimentos erráticos e desarticulados, como uma marionete controlada por algo dentro dele.
- **Lore:** "Era o brinquedo favorito de uma criança. Mas a pedra que agora brilha em seu peito nunca deveria ter sido encontrada. O boneco agora age sozinho, e a pedra parece estar... faminta."
- **Habilidades:**

| Habilidade | Descrição | Números |
|-----------|-----------|---------|
| **M1** | Ataque corpo a corpo. | 20 de dano. Alcance 5 studs. |
| **Dash** | Após 3s de windup, voa na direção do olhar por 10s. Se atingir um Sobrevivente: 30 de dano + lentidão por 3s. | Windup 3s, duração 10s, dano 30, slow 3s. |
| **Laser (3 modos)** | Ativa laser por 10s. Movimento fica muito lento durante o uso. Cicla entre modos com tecla R. | Duração 10s. Cooldown 20s. |
| — Modo Vermelho | Cura o Boneco de Pano. | 20 HP/s. |
| — Modo Verde | Dano contínuo ao Sobrevivente. | 5 dano/s. |
| — Modo Azul | Lentidão no Sobrevivente + revelação. | Slow 40%, revelação 15s. |

#### 3. SOLDADO (Futuro — Pós-MVP)

- **HP:** 1500
- **Velocidade:** 24 studs/s
- **Aparência:** Uma aberração feita de soldadinhos de brinquedo derretidos e fundidos em um único soldado grande. Plástico retorcido, marcas de queimado. Move-se com passos pesados e metálicos.
- **Lore:** "Uma caixa inteira de soldadinhos foi exposta a algo que os derreteu e fundiu. Agora eles são um só — uma massa de plástico retorcido que ainda marcha, ainda luta, e não vai parar até que todos os 'inimigos' sejam eliminados."
- **Habilidades:**

| Habilidade | Descrição | Números |
|-----------|-----------|---------|
| **M1** | Ataque corpo a corpo pesado. | 30 de dano. Alcance 5 studs. |
| **Sentinela** | Posiciona um soldado sentinela que atira em Sobreviventes próximos, causando lentidão, revelação e BLOQUEIO de habilidades (sem dano). | Máx. 5 sentinelas ativas. Atira em múltiplos alvos. |
| **Míssil Bazuca** | Para por 2s, dispara míssil rápido. Impacto direto: 35 dano + explosão (5 dano + slow em área). | Windup 2s. Dano direto 35, dano de área 5, slow 3s. Cooldown 18s. |
| **Marca** | Deixa um pedaço de si no chão (marca de teleporte). | Máx. 1 marca ativa. |
| **Teleporte** | Para por 1.5s, teleporta para a marca. Ao chegar: 20 de dano em Sobreviventes próximos + boost de velocidade por 5s. | Windup 1.5s. Dano 20 em área. Speed boost 5s. Cooldown 30s. |

#### 4. COMPASSO (Futuro — Pós-MVP)

- **HP:** 1234
- **Velocidade:** 28 studs/s
- **Aparência:** Materiais escolares fundidos em uma forma grotesca — uma mão de compasso gigante como braço direito, um lápis cravado no torso, réguas e borrachas incrustadas na pele. Move-se com um andar errático mas veloz.
- **Lore:** "Na sala de aula abandonada, o material escolar ganhou vida — ou algo entrou nele. O Compasso não perdoa erros. Seu lápis marca o alvo, e a lâmina do compasso... bem, ela não mede, ela corta."
- **Habilidades:**

| Habilidade | Descrição | Números |
|-----------|-----------|---------|
| **M1** | Corte com o compasso. Causa sangramento. | 15 dano + 10 de sangramento ao longo de 4s. |
| **Dash (Estilo Colossus)** | Avança com leve controle de curva. Até 3 Sobreviventes no caminho são empalados e arremessados em ragdoll ao final. | Duração 10s. Captura até 3 alvos. |
| **Lápis** | Arremessa o lápis na direção do mouse (1.5s windup). Se atingir Sobrevivente: 10 dano + ragdoll 3s + "cravado" por 20s. | Dano 10, ragdoll 3s, duração do cravo 20s. |
| — Efeito "Cravado" | Sobrevivente toma +5 de dano de ataques. Revelado ao Caçador até remover o lápis. | +5 dano recebido. Revelação permanente. |
| **Recall** | Chama o lápis de volta se estiver próximo. Causa 10 de dano ao portador. Dá velocidade e invencibilidade temporária ao Caçador. | Dano 10 ao portador. Speed boost. Invencibilidade (não toma dano nem pode ser alvo). M1 com lápis não tem cooldown. |

### Sobreviventes

Todos os Sobreviventes compartilham:
- **Velocidade base:** 22 studs/s (24 studs/s correndo com stamina).

---

#### 1. SOLDADO SOBREVIVENTE

- **HP:** 120
- **Velocidade:** 20 studs/s (abaixo da média — compensa com utilidade ofensiva)
- **Lore:** "O único sobrevivente da caixa de soldadinhos usada para criar o Soldado Caçador. Ele escapou antes da fusão final — mas nunca deixou de ser um soldado. Agora luta ao lado dos outros brinquedos, carregando a bazuca que sobrou do arsenal."
- **Vínculo LMS:** Modo exclusivo de Último Sobrevivente (Last Man Standing) quando enfrenta o Soldado Caçador. Velocidade aumentada para 22, dano da Bazuca aumentado em 30%.

| Habilidade | Input | Descrição | Números |
|-----------|-------|-----------|---------|
| **Dash Tático** | Q | Avança como o dash do Compasso, mas mais lento. Se atingir o Caçador: empurra 10 studs + silencia habilidades por 3s. | Empurrão 10 studs, silence 3s. Cooldown 20s. |
| **Bazuca** | E | Ativa modo de mira: tela reduz, mira aparece, 10s para disparar. Disparo: feixe longo e instantâneo (não projétil). | 10s de janela. Se cancelar: metade do cooldown. Cooldown cheio: 30s. |

---

#### 2. SACKBOY SOBREVIVENTE

- **HP:** 110
- **Velocidade:** 26 studs/s (mais rápido, mas baixa stamina)
- **Stamina:** 60 pontos (abaixo da média — compensa com Arma de Tinta)
- **Lore:** "Um sackboy intacto — sem rasgos, sem pedra no peito. Ele escapou antes que a pedra encontrasse um hospedeiro. Agora usa sua arma de tinta — um brinquedo que era para ser inofensivo — para atrapalhar a criatura que quase o possuiu."
- **Vínculo LMS:** Modo exclusivo contra Boneco de Pano. Velocidade aumentada para 28, stamina aumentada para 80.

| Habilidade | Input | Descrição | Números |
|-----------|-------|-----------|---------|
| **Arma de Tinta** | Q | Ativa/desativa à vontade. Segurar para carregar o disparo. Sem cooldown até disparar. | — |
| — Carga 1s | — | Lentidão + pequeno empurrão no Caçador. | Slow 30% por 2s. Cooldown 8s. |
| — Carga 2s | — | Lentidão + empurrão médio + silencia habilidades do Caçador por 4s. | Slow 40% por 2s, silence 4s. Cooldown 12s. |
| — Carga 3s | — | Stun + tela borrada + empurrão (menor que Soldado). | Stun 2s, blur 2s. Cooldown 16s. |
| **Surto** | E | +Velocidade + pulo mais alto por 5s. | +6 speed, +50% altura de pulo. Cooldown 20s. |

---

#### 3. ROBÔ

- **HP:** 150 (maior HP entre Sobreviventes)
- **Velocidade:** 18 studs/s (o mais lento — tanque)
- **Lore:** "Um robô de brinquedo que nunca deveria ter sido ligado. Seus circuitos são antigos e seu corpo de lata range — mas ele é resistente. E tem um protocolo final que nenhum brinquedo deveria ter: auto-destruição."
- **Restrição de Cura:** Não pode ser curado por outros meios. A única fonte de cura do Robô é seu próprio Block (habilidade 2).

| Habilidade | Input | Descrição | Números |
|-----------|-------|-----------|---------|
| **Agarrar** | Q | Puxa o Caçador (como Braço Esticado do Distorcido, mas invertido). Se acertar: Caçador fica INVENCÍVEL por 8s + silenciado por 2s. | Invencibilidade 8s, silence 2s. Cooldown 22s. |
| **Block** | E | Postura de contra-ataque por 1.5s. Se atingido pelo Caçador: silencia habilidades do Caçador por 3s + cura Robô em 10 HP. Se não for atingido: nada acontece. | Janela 1.5s, silence 3s, cura 10 HP. Cooldown 14s. |
| **Sacrifício** | F | Para por 3s → ganha boost de velocidade por 5s → EXPLODE. Causa 40 de dano a si mesmo + lentidão por 8s. Se explosão atingir o Caçador: arremessa 100 studs + stun 6s. | Carga 3s, boost 5s, auto-dano 40, slow 8s, arremesso 100 studs, stun 6s. Cooldown 60s. |

---

#### 4. ENFERMEIRA (Ursinha de Pelúcia Enfermeira)

- **HP:** 105
- **Velocidade:** 22 studs/s
- **Lore:** "Uma ursinha de pelúcia com um chapéu de enfermeira e uma seringa na pata. Ela era o brinquedo que cuidava dos outros brinquedos quando ninguém estava olhando. Agora, no pesadelo da mansão, ela continua fazendo seu trabalho — curando, protegendo, mantendo seus amigos vivos."
- **Indicador Visual:** Quando a Enfermeira está curando um aliado, ela brilha em verde — visível para o Caçador através de paredes em um raio de 40 studs. Alto risco, alta recompensa.

| Habilidade | Input | Descrição | Números |
|-----------|-------|-----------|---------|
| **Curativo** | Q | Canaliza por 2s em aliado a até 10 studs. Cura 25 HP. Durante a cura, Enfermeira brilha em verde (visível ao Caçador através de paredes, 40 studs). | Cura 25 HP, alcance 10 studs, canalização 2s. Cooldown 18s. |
| **Injeção de Adrenalina** | E | Dispara projétil de seringa (15 studs). Aliado atingido ganha +3 de velocidade + ignora o próximo hit (escudo) por 5s. Se o escudo bloquear um hit: Caçador é revelado ao Sobrevivente protegido por 2s. | +3 speed, escudo 5s, revelação 2s. Cooldown 30s. |

---

#### 5. CAMPEÃO (Action Figure Luchador)

- **HP:** 130
- **Velocidade:** 22 studs/s
- **Lore:** "Um boneco de ação de luchador — máscara, capa, pose de combate. Ele foi feito para lutar. Na mansão, ele é o único que não foge — ele enfrenta. Cada golpe que dá é um segundo a mais que seus aliados têm para escapar."
- **Estilo de jogo:** Front-liner. O Campeão é o Sobrevivente que ativamente enfrenta o Caçador para criar espaço para a equipe.

| Habilidade | Input | Descrição | Números |
|-----------|-------|-----------|---------|
| **Agarrão** | Q | Avança 8 studs. Se agarrar o Caçador: 20 de dano + arremessa para trás 8 studs + Caçador fica grounded 1s. Se errar: auto-lentidão 2s. | Dano 20, arremesso 8 studs, grounded 1s. Cooldown 15s. |
| **Sequência** | E | Três socos rápidos em 1.2s (alcance 5 studs). Cada soco: 5 de dano. Terceiro soco: +5 de dano + lentidão 1s no Caçador. Se acertar os 3: reduz cooldown do Agarrão em 5s. | Dano por soco: 5 + 5 + 10 = 20 total. Slow 1s no terceiro. Cooldown 12s. |

---

## Design do Mapa — Mansão Abandonada (MVP)

### Visão Geral

| Atributo | Valor |
|----------|-------|
| **Nome** | Mansão Abandonada |
| **Tamanho** | Médio |
| **Andares** | 2 andares + porão |
| **Salas** | 8–10 salas |
| **Estilo** | Gótico vitoriano decadente |
| **Tempo estimado de travessia** | ~25s de ponta a ponta (Sobrevivente correndo) |

### Layout

#### Térreo (5-6 salas)

1. **Hall de Entrada:** Espaço central com escadaria imponente. Spawn do Caçador. Lustre caído, porta da frente lacrada. Conexão com Sala de Estar, Cozinha e Escritório.
2. **Sala de Estar:** Móveis cobertos, lareira apagada. 2 esconderijos (atrás do sofá, dentro do armário). 1 spawn point de gerador.
3. **Cozinha:** Armários entreabertos, panelas no chão. 1 esconderijo (despensa). 1 spawn point de gerador. Conexão com a despensa que leva ao porão.
4. **Escritório:** Estante tombada, papéis espalhados. 1 esconderijo (atrás da estante). 1 spawn point de gerador.
5. **Sala de Jantar:** Mesa longa, cadeiras quebradas. Conexão com Hall e Corredor dos Fundos.
6. **Corredor dos Fundos:** Conexão entre Sala de Jantar, Lavabo e escada para o segundo andar.

#### Segundo Andar (3-4 salas)

7. **Corredor Superior:** Sacada com vista para o Hall de Entrada. Conexão com Quarto Principal, Quarto de Visitas e Banheiro.
8. **Quarto Principal:** Cama de dossel rasgada, retratos na parede. 1 esconderijo (dentro do guarda-roupa). 1 spawn point de gerador. Conexão secreta (alçapão) para o Escritório no térreo.
9. **Quarto de Visitas:** Berço quebrado, brinquedos espalhados. 1 esconderijo (armário). 1 spawn point de gerador.
10. **Banheiro:** Espelho quebrado, banheira manchada. Sem esconderijos. Conexão apenas com Corredor Superior.

#### Porão (1-2 áreas)

11. **Porão:** Escuridão quase total (20% luminosidade). Canos expostos, poças d'água, ferramentas de tortura antigas. 1 spawn point de jaula fixo. Conexão apenas com a Cozinha (escada estreita).

### Pontos de Interesse

| Tipo | Quantidade | Posicionamento |
|------|-----------|----------------|
| **Spawn points de geradores** | 7 possíveis (5 ativos por partida) | Térreo: Sala de Estar, Cozinha, Escritório, Corredor dos Fundos. Segundo Andar: Quarto Principal, Quarto de Visitas. Porão: próximo à escada. |
| **Spawn points de jaulas** | 5 fixos (3 ativos por partida) | Um por andar garantido. Os outros 2 aleatórios. |
| **Esconderijos** | ~15 | Armários, atrás de móveis, sob escadas. |
| **Portões de Saída** | 2 | Fachada da mansão (próximo ao Hall) e Jardim dos Fundos (próximo ao Corredor dos Fundos). |

### Fluxo de Navegação

- **Rotas de looping:** A mansão é projetada com múltiplos ciclos — o Sobrevivente pode correr da Sala de Estar → Hall → Corredor → Cozinha → Sala de Estar (loop completo no térreo). Similarmente no segundo andar: Quarto Principal → Corredor Superior → Quarto de Visitas → Banheiro → Corredor Superior → Quarto Principal.
- **Conexões verticais:**
  - Escada principal (Hall → Corredor Superior): rota principal e mais rápida.
  - Escada da cozinha (Cozinha → Porão): estreita, sem saída alternativa — alto risco.
  - Alçapão (Quarto Principal → Escritório): rota secreta, rápida mas barulhenta (range ao abrir).
- **Zonas mortas:** Banheiro (uma entrada/saída) e Porão (uma entrada/saída) são armadilhas naturais se o Caçador estiver próximo. Alto risco, mas também podem despistar se usados com timing.

### Variação por Partida

| Elemento | Variação |
|----------|----------|
| Geradores | 5 de 7 posições possíveis, escolhidos aleatoriamente. |
| Jaulas | 3 de 5 posições fixas, escolhidos aleatoriamente. |
| Esconderijos | 12 de 15, escolhidos aleatoriamente (3 ficam bloqueados/destruídos). |
| Portões | Sempre as mesmas 2 posições. |

---

## Progressão e Balanceamento

### Progressão de Jogador (Fora de Partida)

**Nota:** O sistema de progressão completa é pós-MVP. O MVP inclui apenas o básico para validação.

#### MVP — Progressão Mínima

- **Sem níveis de conta ou XP persistente no MVP.**
- **Seleção de personagem:** Antes da partida, cada jogador escolhe entre os Sobreviventes disponíveis (5 classes) ou o Caçador (1). Sem restrições — qualquer combinação de classes é permitida.
- **Rotação de Caçador:** Se múltiplos jogadores quiserem ser o Caçador, o host decide ou usa seleção aleatória.

#### Pós-MVP — Progressão Planejada

- **Nível de Conta:** XP ganho por partida com base em: tempo sobrevivendo, geradores consertados, aliados resgatados, dano causado ao Caçador, Sobreviventes capturados (como Caçador).
- **Desbloqueio de Caçadores:** Boneco de Pano (nível 5), Soldado (nível 10), Compasso (nível 15).
- **Skins por Conquista:** Ex: "Escape 10 vezes", "Capture 50 Sobreviventes".
- **Moeda virtual:** Ganha por partida. Gasta em skins cosméticas.

### Curva de Dificuldade

- **Aprendizado do Caçador:** O Distorcido é projetado como o Caçador de entrada. Suas habilidades são diretas (pull, grito, rage) mas recompensam domínio (timing do Braço Esticado, quando ativar a Fúria, posicionamento do Grito).
- **Aprendizado dos Sobreviventes:**
  - **Fácil:** Soldado (habilidades intuitivas — dash, bazuca).
  - **Médio:** Campeão (requer timing para Agarrão), Sackboy (gerenciar carga da Arma de Tinta).
  - **Difícil:** Robô (posicionamento para Block, decisão de quando usar Sacrifício), Enfermeira (alto risco de ser detectada durante Cura).
- **Curva da partida:** Os primeiros 2 geradores são os mais fáceis (Caçador está se posicionando). Os últimos 2 são os mais difíceis (Caçador sabe as áreas restantes e pode patrulhar).

### Economia e Recursos

| Recurso | Tipo | Descrição |
|---------|------|-----------|
| **HP** | Renovável (limitado) | Apenas Enfermeira (25 HP) e Robô (Block, 10 HP) podem curar. HP não regenera passivamente. |
| **Stamina** | Renovável (automático) | Regenera 10/s quando não correndo. |
| **Fúria (Caçador)** | Acumulativa | Ganha ao causar/receber dano e em resgates próximos. Zera ao usar Rage. |
| **Cooldowns** | Tempo real | Cada habilidade tem seu próprio cooldown, rastreado individualmente. |

---

## Arte e Áudio

### Direção de Arte

#### Estilo Visual

- **Abordagem:** 3D estilizado — low-poly com texturas escuras. Compatível com o motor gráfico do Roblox e performático em dispositivos móveis.
- **Referências:** Estilo sombrio de *Piggy* e *The Mimic* (Roblox), atmosfera gótica de *Resident Evil* (versão leve).
- **Paleta de cores:**
  - **Ambiente:** Azul escuro (#1a1a2e), roxo profundo (#2d1b4e), preto (#0a0a0a), cinza (#3a3a4a).
  - **Caçador:** Preto com detalhes em vermelho desaturado e âmbar (#8b0000, #cc5500).
  - **Sobreviventes:** Cores primárias dessaturadas para cada classe — azul (Soldado), laranja (Sackboy), cinza metálico (Robô), branco com verde (Enfermeira), amarelo (Campeão).
  - **UI/HUD:** Minimalista — ícones brancos com bordas escuras, barras com gradiente suave.

#### Personagens

| Personagem | Estilo |
|-----------|--------|
| **O Distorcido (base)** | Humanoide Roblox com articulações deformadas. Postura curvada. Roupas rasgadas. Pele acinzentada. |
| **O Distorcido (Rage)** | A mesma silhueta, mas alongada em 20%. Textura preta com partículas escuras emanando. Olhos brilhantes (âmbar). |
| **Sobreviventes** | Aparência de brinquedos — plástico, tecido, metal. Proporções Roblox padrão. Cada um com silhueta distinta. |

#### Mapas

- **Mansão Abandonada:** Arquitetura vitoriana decadente. Paredes com papel de parede descascando, janelas com tábuas, móveis cobertos. Iluminação dramática com alto contraste — áreas iluminadas (luz da lua) e escuridão profunda lado a lado.

#### UI / HUD

| Elemento | Descrição |
|----------|-----------|
| **HUD Sobrevivente** | Barra de HP (canto inferior esquerdo), barra de stamina (abaixo do HP), ícone de habilidade com cooldown (canto inferior direito), indicador de proximidade (batimentos cardíacos no centro da tela). |
| **HUD Caçador** | Barra de Fúria (centro inferior), ícones de habilidade com cooldown, contador de Sobreviventes vivos/em jaula. |
| **Tela de Seleção** | Menu simples com cards dos personagens. Imagem de cada classe + habilidades resumidas. |
| **Indicadores In-World** | Geradores: luz piscando (não reparado) / verde fixa (reparado). Jaulas: barras visíveis. Sobreviventes em jaula: destaque sutil. |

#### Efeitos Visuais

- **Partículas do Caçador:** Névoa escura emanando d'O Distorcido (sutil, não atrapalha visibilidade). Intensifica durante Rage.
- **Habilidades:** Braço Esticado deixa rastro escuro. Grito emite ondas de choque visuais (em preto/roxo). Cura da Enfermeira: brilho verde com partículas subindo.
- **Ambiente:** Poeira flutuando em feixes de luz. Névoa rasteira no porão. Folhas secas no chão do térreo.

### Áudio e Música

#### Trilha Sonora

- **Fonte:** Assets gratuitos da biblioteca de áudio do Roblox para MVP. Música original planejada para pós-MVP.
- **Estrutura dinâmica:** 3 camadas que fazem crossfade baseado na distância do Caçador:
  - **Camada 1 — Calma:** Tons graves ambientes, notas de piano esparsas, cordas suaves.
  - **Camada 2 — Alerta:** Cordas em crescendo, percussão leve. Entra quando o Caçador está a 60 studs.
  - **Camada 3 — Perseguição:** Percussão intensa, metais, ritmo cardíaco acelerado. Entra a 30 studs.

#### Efeitos Sonoros

| Categoria | Sons | Prioridade |
|-----------|------|------------|
| **Passos** | Sobrevivente: passos leves (madeira, carpete, concreto por área). Caçador: passos pesados com distorção. | Alta |
| **Habilidades do Caçador** | Braço Esticado: som de estalo/estiramento. Grito: rugido distorcido com reverb. Rage: explosão grave + batimentos abafados. | Alta |
| **Habilidades de Sobreviventes** | Bazuca: zumbido de carga + explosão. Cura: som de líquido/bolhas. Agarrão: impacto. Sacrifício: contagem regressiva + explosão. | Média |
| **Ambiente** | Vento, rangidos de madeira, sussurros abafados, trovões distantes. | Média |
| **Geradores** | Zumbido elétrico (não reparado), clique ao finalizar. Som de faísca ao falhar skill check. | Alta |
| **Interface** | Clique ao acertar skill check, alarme ao errar, som de portão abrindo, som de vitória/derrota. | Média |

---

## Especificações Técnicas

### Requisitos de Desempenho

| Métrica | Alvo | Método de Medição |
|---------|------|-------------------|
| **FPS** | 60 FPS sustentado em PC, 30 FPS sustentado em mobile | Medir durante loop de perseguição com todos os efeitos ativos |
| **Latência de rede** | <100ms de ping para ação responsiva | Testar em partidas com host local e com amigos remotos |
| **Memória** | <500 MB em dispositivos mobile | Monitorar via Roblox Developer Console |
| **Tempo de carregamento** | <15s para entrar no mapa (mobile) | Medir do clique "Iniciar" até o spawn |

### Detalhes Específicos da Plataforma (Roblox)

- **Motor:** Roblox Engine (renderização proprietária).
- **Linguagem:** Luau (scripting).
- **Networking:** Modelo cliente-servidor do Roblox. No MVP, o host da sala atua como servidor (partidas locais/amigos). Servidores dedicados são pós-MVP.
- **Dispositivos alvo:** PC (Windows, Mac), Mobile (iOS, Android). Roblox lida com cross-platform automaticamente.
- **DataStore:** Planejado para progressão de conta (pós-MVP). MVP não usa DataStore — progressão não persiste entre sessões.

### Restrições Técnicas

- **Replicação cliente-servidor:** Toda lógica de jogo deve rodar no servidor e replicar para clientes. Inputs são enviados do cliente, validados no servidor.
- **Segurança:** Validação de todas as ações no servidor para prevenir exploits (speed hacks, teleporte, HP modification).
- **Desempenho mobile:** Limitar contagem de partículas simultâneas a 200. Usar light baking em vez de iluminação dinâmica sempre que possível. Limitar polígonos por modelo a ~2000 tris.
- **Áudio:** Usar assets gratuitos da biblioteca Roblox. Sons devem ser mono para espacialização 3D. Volume máximo combinado de todas as fontes não deve exceder o limite da plataforma.

### Requisitos de Assets

| Categoria | MVP (Quantidade) | Estilo | Fonte |
|-----------|-----------------|--------|-------|
| **Modelos 3D — Caçador** | 1 (O Distorcido, 2 variações: base + Rage) | Low-poly, ~1500 tris | Criado no Roblox Studio ou Blender |
| **Modelos 3D — Sobreviventes** | 5 (um por classe) | Low-poly, ~1000 tris cada | Criado no Roblox Studio ou Blender |
| **Modelos 3D — Mapa** | 1 mansão completa (~50 peças modulares) | Low-poly, texturas escuras | Criado com partes Roblox + modelos gratuitos do Toolbox |
| **Animações** | ~30 (andar, correr, agachar, atacar, habilidades, interações) | Estilo Roblox | Animação built-in + custom |
| **Efeitos Sonoros** | ~25 sons | Terror, ambiente | Biblioteca gratuita Roblox |
| **Música** | 3 faixas (camadas 1, 2, 3) | Orquestral sombrio | Biblioteca gratuita Roblox |
| **UI** | ~10 elementos de HUD + menu de seleção | Minimalista | Criado via ScreenGui Roblox |

---

## Épicos de Desenvolvimento

### Resumo dos Épicos

| Épico | Nome | Escopo | Ordem |
|-------|------|--------|-------|
| **E1** | Fundação — Movimento e Controles | Implementar movimento básico, câmera, controles para Caçador e Sobreviventes | 1 |
| **E2** | O Caçador — O Distorcido | Implementar HP, M1, habilidades (Braço Esticado, Grito, Rage), medidor de Fúria | 2 |
| **E3** | Os Sobreviventes — 5 Classes | Implementar HP, habilidades de todas as 5 classes, stamina, furtividade | 3 |
| **E4** | A Mansão — Mapa MVP | Construir layout da Mansão Abandonada, esconderijos, iluminação, navegação | 4 |
| **E5** | Objetivos — Geradores e Portão | Implementar geradores (reparo, skill checks), portão de fuga, condição de vitória | 5 |
| **E6** | Captura — Derrubada, Jaula e Resgate | Implementar sistema de down, carregamento, jaula, libertação, eliminação | 6 |
| **E7** | Lobby e Fluxo de Partida | Criar lobby local (host), seleção de personagem, início e fim de partida | 7 |
| **E8** | Áudio e Atmosfera | Integrar música dinâmica, efeitos sonoros, sistema de batimentos cardíacos | 8 |
| **E9** | Polimento e Balanceamento | Ajuste de números (HP, dano, cooldown), teste com amigos, correções | 9 |

Detalhamento completo em `epics.md`.

---

## Métricas de Sucesso

### Métricas Técnicas

| Métrica | Alvo | Quando Medir |
|---------|------|-------------|
| **FPS médio (PC)** | ≥55 FPS | Durante perseguição com todos os efeitos |
| **FPS médio (Mobile)** | ≥28 FPS | Durante perseguição com todos os efeitos |
| **Tempo de carregamento (Mobile)** | <18s | Do lobby ao spawn |
| **Desconexões por partida** | <10% das partidas | Ao longo de 20 partidas de teste |
| **Crash rate** | <5% | Ao longo de 20 partidas de teste |

### Métricas de Gameplay

| Métrica | Alvo | Como Medir |
|---------|------|-----------|
| **Duração média da partida** | 8–12 minutos | Registrar timestamps de início/fim |
| **Taxa de vitória do Caçador** | 45–55% | Após 20 partidas, verificar equilíbrio |
| **Tempo até primeira captura** | 2–5 minutos | Garantir que o Caçador encontra alguém cedo |
| **Uso de habilidades por partida** | ≥3 usos por habilidade | Validar que habilidades são usadas, não ignoradas |
| **Resgates por partida** | 1–3 | Garantir que resgates acontecem |
| **Satisfação do jogador** | ≥7/10 em pesquisa informal | Perguntar a amigos testadores |

---

## Fora do Escopo

### MVP — Deliberadamente Excluído

| Item | Justificativa | Planejado Para |
|------|---------------|---------------|
| **Caçadores adicionais** (Boneco de Pano, Soldado, Compasso) | MVP valida com 1 Caçador. Design está pronto para os 3 futuros. | Pós-MVP |
| **Mapas adicionais** (Floresta Sombria, Fábrica) | 1 mapa é suficiente para validar o core loop. | Pós-MVP |
| **Sistema de progressão** (XP, níveis, moeda, skins) | MVP foca na jogabilidade pura. Progressão adiciona complexidade de DataStore. | Pós-MVP |
| **Monetização** (game passes, itens pagos) | Não é necessário para validar a hipótese central. | Pós-MVP |
| **Matchmaking automatizado** | MVP usa lobby local (host convida amigos). Matchmaking exige servidores dedicados. | Pós-MVP |
| **Servidores dedicados** | MVP usa modelo host = servidor (partidas com amigos). | Pós-MVP |
| **Modo espectador** | Não essencial para o core loop do MVP. | Pós-MVP |
| **Customização de perks** | Complexidade de balanceamento desnecessária para MVP. Classes já oferecem variedade. | Pós-MVP |
| **Modo tutorial** | Acessibilidade via design intuitivo + dicas contextuais na primeira partida. | Futuro |
| **Lanternas/ferramentas de luz** | A escuridão é ameaça ambiental, não recurso gerenciável no MVP. | Pós-MVP |
| **Bot AI para preencher vagas** | Não necessário para MVP com lobby local. | Pós-MVP |
| **Leaderboard** | Exige DataStore e progressão. | Pós-MVP |

### Pós-MVP — Planejado para Fase 2

- 3 Caçadores adicionais (Boneco de Pano, Soldado, Compasso)
- 2 mapas adicionais (Floresta Sombria, Fábrica)
- Sistema de progressão completo (níveis, moeda, skins)
- Monetização (game passes cosméticos)
- Matchmaking automatizado
- Servidores dedicados
- Modo espectador
- Personalização de perks
- Tutorial interativo
- Sistema de amigos e invites via Roblox

---

## Premissas e Dependências

### Premissas

| ID | Premissa | Impacto se Incorreta |
|----|----------|----------------------|
| A1 | O desenvolvedor conseguirá aprender Roblox Studio e Luau o suficiente para implementar o MVP em 3–4 semanas. | Atraso significativo; considerar escopo ainda mais reduzido. |
| A2 | O modelo host = servidor (lobby local) é suficiente para testar com amigos e validar o core loop. | Se networking host-based for muito problemático, investir em servidor dedicado antes do planejado. |
| A3 | A biblioteca de áudio gratuita do Roblox tem sons adequados para atmosfera de terror. | Se não houver, será necessário criar ou comprar assets de áudio. |
| A4 | Dispositivos mobile (iOS/Android) conseguem rodar a Mansão Abandonada a 30 FPS com as otimizações propostas. | Se não, reduzir tamanho do mapa ou quantidade de efeitos. |
| A5 | Os números de balanceamento (HP, dano, cooldowns) definidos neste GDD são um ponto de partida razoável e serão ajustados durante testes. | Esperado — ajustes são parte normal do desenvolvimento. |
| A6 | 4 Sobreviventes por partida é o número ideal para o tamanho do mapa MVP. | Se partidas forem muito rápidas ou lentas, ajustar para 3 ou 5. |
| A7 | O gênero de terror assimétrico continua popular e atrai jogadores no Roblox. | Se o gênero saturar, considerar pivotar tema mantendo mecânicas. |

### Dependências

| ID | Dependência | Resolução |
|----|-------------|-----------|
| D1 | Roblox Studio funcional e atualizado no computador do desenvolvedor. | Instalar via site oficial do Roblox. |
| D2 | Conta Roblox com permissão para publicar experiências. | Criar conta de desenvolvedor gratuita. |
| D3 | Amigos disponíveis para testar o MVP (mínimo 3-4 pessoas). | Agendar sessões de teste regulares. |
| D4 | Assets de áudio gratuitos na biblioteca Roblox com qualidade suficiente. | Explorar e catalogar sons antes da implementação. |
| D5 | Modelos gratuitos no Toolbox para mobília e decoração da mansão. | Verificar disponibilidade e licenças antes de usar. |

---

## Registro de Alterações

| Versão | Data | Alteração | Autor |
|--------|------|-----------|-------|
| 1.0 | 2026-06-28 | Criação do GDD — versão inicial completa. Caçador MVP definido como O Distorcido. 5 classes de Sobreviventes. 1 mapa (Mansão Abandonada). | familia |
