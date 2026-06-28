# Caçada Sombria — Épicos de Desenvolvimento

**Documento complementar ao GDD.** Detalhamento dos épicos, histórias de alto nível e sequência de desenvolvimento.

---

## E1 — Fundação: Movimento e Controles

**Objetivo:** Estabelecer o esqueleto jogável — personagens se movem, câmeras funcionam, inputs respondem.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E1.1 | Movimento básico do Sobrevivente | Implementar WASD/joystick, câmera em terceira pessoa, mouse para olhar ao redor. | Personagem se move suavemente em todas as direções. Câmera segue atrás. |
| E1.2 | Sistema de corrida e stamina | Implementar Shift para correr (+2 speed), barra de stamina que consome 20/s e regenera 10/s. | Correr consome stamina. Quando vazia, não pode correr por 3s. |
| E1.3 | Agachar e furtividade | Implementar Ctrl para agachar. Sistema de raio de som de passos (30 studs normal, 10 agachado). | Caçador consegue "ouvir" passos apenas dentro do raio correto. |
| E1.4 | Movimento do Caçador | Implementar movimento em primeira pessoa, visão com FOV 90°, mesma velocidade base (26 studs/s). | Caçador vê em primeira pessoa. Movimento fluido. |
| E1.5 | Sistema de esconderijo | Criar armários e móveis interagíveis. Entrar (1s animação), ficar escondido (máx 20s), sair. | Sobrevivente entra e sai de esconderijos. Indetectável a 5+ studs. |

### Dependências
- Nenhuma (épico fundacional).

---

## E2 — O Caçador: O Distorcido

**Objetivo:** Implementar todas as mecânicas do Caçador MVP — ataque, habilidades, medidor de Fúria.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E2.1 | HP e sistema de dano do Caçador | Implementar HP 1100. Caçador recebe dano de habilidades de Sobreviventes. | HP reduz corretamente. Caçador não morre (sem morte de Caçador). |
| E2.2 | M1 — Tapa (Ataque Básico) | Ataque corpo a corpo: 20 dano (25 em Rage), alcance 6 studs, windup 0.6s, recovery 0.3s, cooldown 0.8s. | Acerta Sobreviventes no alcance. Animação e dano corretos. |
| E2.3 | Q — Braço Esticado (Pull) | Braço se estica 40 studs na direção da mira. Atingir puxa Sobrevivente para perto + stun 0.5s. Windup 0.4s, cooldown 12s. | Projétil estreito (2 studs). Pull funciona. Cooldown respeitado. |
| E2.4 | Medidor de Fúria | Barra 0-100. Ganha ao causar dano (+15), receber dano (+10), resgate próximo (+20). | Barra preenche corretamente. Visual no HUD. |
| E2.5 | R — Rage (Transformação) | Ativável com Fúria 100. 30s: velocidade 28, dano M1 25, timer pausa. Forma visual alterada. | Transformação funciona. Efeitos aplicados. Timer pausa. Medidor zera ao terminar. |
| E2.6 | E — Grito (Scream) | Windup 0.8s. Raio 60 studs: slow 40% + blur 3s. Raio 100 studs: revelação 4s. Cooldown 25s. | Efeitos aplicados apenas nos raios corretos. Sobreviventes revelados através de paredes. |

### Dependências
- E1 (movimento base do Caçador).

---

## E3 — Os Sobreviventes: 5 Classes

**Objetivo:** Implementar HP, habilidades de classe e mecânicas compartilhadas para todos os 5 Sobreviventes.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E3.1 | HP e sistema de dano dos Sobreviventes | Cada classe com seu HP base. Dano do Caçador reduz HP. Estado Derrubado ao chegar a 0. | HP de cada classe correto. Derrubado ativa ao chegar a 0. |
| E3.2 | Soldado Sobrevivente | HP 120, speed 20. Dash Tático (empurra 10 studs + silence 3s). Bazuca (mira 10s, feixe instantâneo). | Ambas habilidades funcionais. Cooldowns corretos. |
| E3.3 | Sackboy Sobrevivente | HP 110, speed 26, stamina 60. Arma de Tinta (3 níveis de carga). Surto (+6 speed, +50% pulo, 5s). | Carga progressiva da arma. Surto aplica bônus corretamente. |
| E3.4 | Robô | HP 150, speed 18. Agarrar (puxa Caçador, invencibilidade 8s + silence 2s). Block (contra-ataque, cura 10 HP). Sacrifício (auto-dano 40, arremessa Caçador 100 studs, stun 6s). | Robô não pode ser curado externamente. Block é única cura. Sacrifício causa auto-dano. |
| E3.5 | Enfermeira | HP 105, speed 22. Curativo (cura 25 HP, 2s canalização, brilho verde visível). Injeção de Adrenalina (projétil, +3 speed, escudo 5s). | Cura funciona em aliados no alcance. Brilho verde visível ao Caçador. Escudo bloqueia 1 hit. |
| E3.6 | Campeão | HP 130, speed 22. Agarrão (avança 8 studs, 20 dano, arremessa Caçador 8 studs, grounded 1s). Sequência (3 socos, dano 5+5+10, slow no terceiro). | Agarrão pune erro com auto-slow. Sequência reduz cooldown do Agarrão se acertar 3. |
| E3.7 | Modos LMS (vínculos) | Soldado vs Soldado Caçador: +2 speed, +30% dano Bazuca. Sackboy vs Boneco de Pano: +2 speed, +20 stamina. | Bônus aplicados apenas nas matchups corretas. |

### Dependências
- E1 (movimento), E2 (para teste de dano e interação).

---

## E4 — A Mansão: Mapa MVP

**Objetivo:** Construir o layout completo da Mansão Abandonada com esconderijos, iluminação e pontos de interesse.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E4.1 | Layout do térreo | Construir 5-6 salas: Hall, Sala de Estar, Cozinha, Escritório, Sala de Jantar, Corredor dos Fundos. Conexões e portas. | Layout navegável. Salas distintas com conexões corretas. |
| E4.2 | Layout do segundo andar | Construir 3-4 salas: Corredor Superior, Quarto Principal, Quarto de Visitas, Banheiro. Alçapão para Escritório. | Conexão vertical via escada principal e alçapão secreto. |
| E4.3 | Porão | Área escura (20% luminosidade), escada estreita da Cozinha. Ambiente opressivo com névoa. | Iluminação reduzida. Única entrada/saída (alto risco). |
| E4.4 | Esconderijos | Posicionar ~15 esconderijos (armários, atrás de móveis). Lógica de entrar/sair, limite de 20s. | 12 de 15 ativos por partida (3 bloqueados aleatoriamente). |
| E4.5 | Spawn points | Spawn fixo do Caçador (Hall). 4+ spawn points de Sobreviventes (aleatórios). | Ninguém spawna ao lado do Caçador. Mínimo 30 studs de distância. |
| E4.6 | Iluminação e atmosfera | Configurar iluminação dramática: alto contraste, cores escuras, feixes de luz da lua. Névoa no porão. | FPS sustentado com iluminação configurada. Atmosfera sombria alcançada. |
| E4.7 | Otimização mobile | Light baking, redução de partículas, LOD em objetos distantes. Testar FPS em dispositivo móvel. | ≥28 FPS em mobile durante perseguição na mansão. |

### Dependências
- E1 (movimento para testar navegação).

---

## E5 — Objetivos: Geradores e Portão

**Objetivo:** Implementar o sistema de objetivos — reparo de geradores com skill checks, abertura do portão de fuga, condições de vitória.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E5.1 | Spawn de geradores | 7 posições possíveis, 5 ativas por partida. Aleatoriedade na seleção. | Geradores aparecem em posições diferentes a cada partida. |
| E5.2 | Mecânica de reparo | Interagir (E) para iniciar reparo (3s canalização). Som de zumbido em 40 studs. | Reparo bloqueia movimento. Som audível atrai Caçador. |
| E5.3 | Skill checks (QTE) | Ponteiro giratório, zona de sucesso. Acerto: +5% bônus. Erro: -10% progresso + alerta global. Dificuldade progressiva. | QTE aparece a cada 1s. Penalidade/benefício aplicados. Dificuldade aumenta por gerador concluído. |
| E5.4 | Portão de fuga | Ativável após 5 geradores. 2 portões (lados opostos). Interação 3s na alavanca, porta abre em 8s. Som audível 60 studs. | Ambos portões abrem quando um é ativado. Travessia = fuga do mapa. |
| E5.5 | Condição de vitória dos Sobreviventes | Pelo menos 1 Sobrevivente escapa pelo portão → vitória da equipe. | Tela de vitória ao primeiro escape. Partida encerra para todos. |
| E5.6 | Condição de vitória do Caçador | Todos os 4 Sobreviventes em jaulas simultaneamente. | Partida encerra, tela de vitória do Caçador. |
| E5.7 | Timeout (collapse) | 15 minutos de partida → portão abre automaticamente por 30s e fecha. | Mecanismo anti-stall funcional. Sem empates infinitos. |

### Dependências
- E4 (mapa com posições de geradores e portões).

---

## E6 — Captura: Derrubada, Jaula e Resgate

**Objetivo:** Implementar o sistema completo de captura e resgate.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E6.1 | Estado Derrubado (Down) | HP = 0 → cai. Move 30% speed, sem habilidades. Timer 60s até morte automática. | Animação de queda. Movimento reduzido. Timer visível. |
| E6.2 | Carregamento | Caçador interage (F, 1.5s) para carregar Sobrevivente derrubado. Move a 80% speed, sem atacar. | Animação de carga. Velocidade reduzida. Habilidades bloqueadas. |
| E6.3 | Debate (Wiggle) | Sobrevivente carregado preenche barra em 10s. Ao preencher: liberta-se, Caçador atordoado 2s. | Barra de progresso. Atordoamento ao libertar. |
| E6.4 | Jaulas | 5 posições fixas, 3 ativas por partida. Caçador deposita Sobrevivente (2s). Timer 120s até eliminação. | Depósito funciona. Timer visível para todos. Eliminação após 120s. |
| E6.5 | Resgate | Aliado interage com jaula (3s). Progresso reseta se interrompido. Sobrevivente resgatado: 50% HP, 3s invulnerabilidade. | Resgate bem-sucedido restaura HP e dá invulnerabilidade. |
| E6.6 | Interação com Fúria | Resgate próximo (40 studs) dá +20 Fúria ao Caçador. | Medidor de Fúria ganha carga ao presenciar resgate. |

### Dependências
- E2 (Caçador para interação), E3 (Sobreviventes para estado derrubado).

---

## E7 — Lobby e Fluxo de Partida

**Objetivo:** Criar o sistema de lobby local, seleção de personagem e gerenciamento de partida.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E7.1 | Lobby do Host | Um jogador cria sala (host). Sala aparece na lista de amigos. | Host consegue criar sala. Nome da sala visível. |
| E7.2 | Entrada na sala | Amigos entram na sala via lista. Máximo 5 jogadores (1 Caçador + 4 Sobreviventes). | 5 jogadores máximos. Entrada e saída funcionais. |
| E7.3 | Seleção de personagem | Tela com cards de cada classe. Jogador escolhe Sobrevivente. Host define quem é o Caçador. | Todos escolhem antes da partida. Sem conflitos de classe (múltiplos podem escolher a mesma). |
| E7.4 | Início da partida | Host clica "Iniciar". Todos carregam o mapa. Timer de 5s de preparação antes do início da caçada. | Spawn em posições corretas. Timer de preparação visível. |
| E7.5 | Fim da partida | Tela de resultado: quem venceu, estatísticas (geradores, capturas, resgates). Botão "Voltar ao Lobby". | Estatísticas pós-partida. Retorno ao lobby funcional. |
| E7.6 | Abandono de partida | Se um jogador sair: Sobrevivente vai direto para jaula (sem derrubada). Caçador → partida encerra. | Handled gracefully. Sem crash. |

### Dependências
- Todos os épicos anteriores (para ter jogo funcional).

---

## E8 — Áudio e Atmosfera

**Objetivo:** Implementar música dinâmica, efeitos sonoros e feedback de áudio de proximidade.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E8.1 | Sistema de música dinâmica | 3 camadas com crossfade baseado em distância do Caçador. Camada 1 (exploração), 2 (alerta a 60 studs), 3 (perseguição a 30 studs). | Transições suaves (2s crossfade). Camada correta para cada distância. |
| E8.2 | Batimentos cardíacos | Volume e ritmo aumentam com proximidade do Caçador. Audível a 40 studs. | Ritmo acelera linearmente com proximidade. Silencioso acima de 40 studs. |
| E8.3 | Efeitos sonoros de habilidades | Cada habilidade do Caçador e Sobreviventes com som característico. | Som distinto por habilidade. Espacialização 3D funcional. |
| E8.4 | Sons ambientes | Vento, rangidos de madeira, trovões distantes, sussurros. Aleatórios e posicionais. | Som ambiente imersivo. Não interfere na jogabilidade. |
| E8.5 | Sons de interface | Clique de skill check, alarme de erro, som de portão abrindo, vitória/derrota. | Feedback sonoro claro para ações de UI. |

### Dependências
- E2, E3, E4, E5 (para ter contexto de jogo onde os sons se aplicam).

---

## E9 — Polimento e Balanceamento

**Objetivo:** Ajustar números, testar com amigos, corrigir bugs e preparar para lançamento MVP.

### Histórias de Alto Nível

| ID | História | Descrição | Critério de Aceitação |
|----|----------|-----------|----------------------|
| E9.1 | Sessão de teste 1 — Core Loop | 3-5 partidas com amigos. Verificar se o loop funciona: geradores → perseguição → captura/resgate → fuga. | Pelo menos 80% das partidas chegam a uma conclusão natural (vitória ou derrota). |
| E9.2 | Ajuste de balanceamento | Ajustar HP, dano, cooldowns com base no feedback e dados da sessão 1. Alvo: 45-55% win rate do Caçador. | Após ajustes, win rate dentro da faixa alvo em 10 partidas. |
| E9.3 | Sessão de teste 2 — Todas as Classes | Testar cada classe de Sobrevivente em múltiplas partidas. Verificar se alguma é dominada/dominante demais. | Feedback qualitativo: cada classe tem seu momento de brilhar. |
| E9.4 | Correção de bugs | Lista de bugs encontrados nas sessões de teste. Priorizar crash e game-breaking. | Zero bugs críticos remanescentes. |
| E9.5 | Otimização final | Perfil de desempenho no Roblox Developer Console. Otimizar pontos quentes. | FPS dentro dos alvos (60 PC, 30 mobile). |
| E9.6 | Documentação de lançamento | Criar README com instruções de como jogar, lista de controles, descrição das classes. | Qualquer pessoa consegue entender como jogar lendo o README. |

### Dependências
- Todos os épicos anteriores.

---

## Sequência de Desenvolvimento

```
E1 (Fundação)
 │
 ├──▶ E2 (Caçador) ──┐
 │                    │
 ├──▶ E3 (Sobreviventes) ──┤
 │                          │
 └──▶ E4 (Mapa) ────────────┤
                             │
                    ┌────────┘
                    ▼
              E5 (Objetivos)
                    │
                    ▼
              E6 (Captura)
                    │
                    ▼
              E7 (Lobby)
                    │
                    ▼
              E8 (Áudio)
                    │
                    ▼
              E9 (Polimento)
```

**Paralelismo possível:** E2, E3 e E4 podem ser desenvolvidos em paralelo (dependem apenas de E1). E5 e E6 dependem dos sistemas de personagem e mapa, mas são independentes entre si.

**Tempo estimado por épico (desenvolvedor iniciante):**

| Épico | Tempo Estimado |
|-------|---------------|
| E1 | 3-4 dias |
| E2 | 3-4 dias |
| E3 | 5-7 dias |
| E4 | 4-5 dias |
| E5 | 3-4 dias |
| E6 | 3-4 dias |
| E7 | 2-3 dias |
| E8 | 2-3 dias |
| E9 | 3-4 dias |
| **Total** | **28-38 dias (~4-6 semanas)** |
