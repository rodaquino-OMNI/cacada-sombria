# Addendum — Caçada Sombria

> Material complementar que pertence ao contexto do jogo mas não cabe no Game Brief principal.  
> Será consumido pelo GDD e documentos subsequentes.

---

## Ideias para Caçadores Futuros (pós-MVP)

### O Espectro (MVP)
- **Tema:** Fantasma vingativo, preso entre mundos.
- **Habilidade:** Visão Sombria — revela silhuetas de Sobreviventes através de paredes por 3 segundos (cooldown: 20s).
- **Fraqueza:** Lento, vulnerável a luz (Sobreviventes podem usar lanternas para atordoar brevemente).

### A Besta (2º Caçador)
- **Tema:** Criatura bestial, caçador físico.
- **Habilidade:** Carga Furiosa — avança em linha reta destruindo obstáculos e derrubando Sobreviventes no caminho.
- **Fraqueza:** Barulhento (passos altos), visão limitada (não vê através de paredes).

### O Marionetista (3º Caçador)
- **Tema:** Mestre das armadilhas, manipulador.
- **Habilidade:** Armadilha de Sombras — coloca armadilhas no mapa que paralisam Sobreviventes por 5s (máx 3 ativas).
- **Fraqueza:** Sem habilidade ofensiva direta, depende de emboscadas.

---

## Ideias para Mapas (pós-MVP)

### Mansão Abandonada (MVP)
- **Tema:** Mansão vitoriana decadente, dois andares + porão.
- **Tamanho:** Médio (8-10 salas).
- **Características:** Corredores estreitos, escadas, esconderijos em armários.
- **Lore:** Antiga residência de uma família que desapareceu misteriosamente.

### Floresta Sombria (2º Mapa)
- **Tema:** Floresta densa à noite, cabana abandonada no centro.
- **Tamanho:** Grande (aberto, mas com vegetação densa).
- **Características:** Árvores como cobertura, névoa, terreno irregular.
- **Lore:** Local de rituais antigos; a Besta faz seu ninho aqui.

### Fábrica (3º Mapa)
- **Tema:** Fábrica industrial abandonada, múltiplos andares, esteiras, maquinário.
- **Tamanho:** Médio-Grande (verticalidade).
- **Características:** Esteiras que movem jogadores, alarmes que revelam posição, quedas de altura.
- **Lore:** Produzia algo sinistro; o Marionetista era o capataz.

---

## Detalhamento de Habilidades dos Sobreviventes

### Habilidades Universais (todos os Sobreviventes)
- **Correr:** Velocidade aumentada por 3s (stamina).
- **Esconder:** Entrar em armários, atrás de móveis, em arbustos.
- **Agachar:** Reduz ruído de passos.
- **Salvar:** Resgatar aliado de jaula (leva 3s, pode ser interrompido).

### Habilidades de Classe (a definir no GDD)
Possíveis classes para Sobreviventes:
- **Médico:** Cura aliados mais rápido, pode se auto-curar.
- **Explorador:** Vê o Caçador brevemente no minimapa.
- **Engenheiro:** Conserta objetivos 20% mais rápido.
- **Atleta:** Corre mais rápido e por mais tempo.

---

## Sistema de Progressão (Detalhamento Preliminar)

### Estrutura proposta:
- **Nível de conta:** XP ganho por partida (baseado em tempo sobrevivendo, objetivos completados, salvamentos).
- **Perks:** Desbloqueados a cada 5 níveis. Máximo de 2 perks equipados por partida.
- **Skins:** Desbloqueadas por conquistas (ex: "Escape 10 vezes", "Capture 50 Sobreviventes").
- **Moeda:** Ganha por partida. Gasta em skins cosméticas e perks.
- **Leaderboard:** Ranking por nível, escapes, capturas.

---

## Referências Técnicas para Estudo

### Tutoriais recomendados para iniciante em Roblox:
1. [Roblox Studio Basics](https://create.roblox.com/docs/tutorials/fundamentals) — fundamentos
2. [Scripting in Luau](https://create.roblox.com/docs/tutorials/scripting) — programação
3. [Multiplayer / Networking](https://create.roblox.com/docs/scripting/networking) — essencial para jogo multiplayer
4. [DataStore](https://create.roblox.com/docs/cloud-services/data-stores) — progressão

### Assets gratuitos úteis:
- Biblioteca de áudio do Roblox (sons de terror, ambiente)
- Modelos gratuitos no Toolbox (móveis, decoração)

---

## Análise de Concorrência (Detalhada)

| Jogo | DAU estimado | Forças | Fraquezas |
|------|-------------|--------|-----------|
| Pwned by 14 | ~5K-10K | Atmosfera, variedade | Complexidade, curva de aprendizado |
| Flee the Facility | ~20K-30K | Acessibilidade, ritmo | Profundidade limitada, repetitivo |
| The Mimic | ~10K-20K | Narrativa, terror | Single-player focado |
| Dead by Daylight (fora Roblox) | ~50K | Polimento, conteúdo | Não está no Roblox, violento |

**Oportunidade:** Caçada Sombria ocupa o nicho do "assimétrico acessível mas com profundidade" — mais estratégico que Flee the Facility, menos complexo que Pwned by 14.

---

## Perguntas para o Usuário (a responder antes do GDD)

1. Você prefere que o primeiro Caçador seja baseado em informação (Espectro) ou em perseguição física (Besta)? Isso afeta o que você programa primeiro.
2. Quer manter 4 Sobreviventes ou prefere testar com 5?
3. Tem preferência por tema de mapa? Mansão gótica, floresta, ou fábrica?
4. Quer monetização no MVP ou só depois? (Game passes, itens cosméticos)
5. Prefere progressão simples (níveis) ou com perks customizáveis?
