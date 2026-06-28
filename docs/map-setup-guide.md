# Guia de Construção do Mapa — Mansão Abandonada

**Projeto:** Caçada Sombria (Roblox)
**Épico:** E4 — Mapa MVP
**Idioma:** PT-BR
**Nível do Desenvolvedor:** Iniciante em Roblox Studio

---

## VISÃO GERAL

Este guia ensina como construir a **Mansão Abandonada** no Roblox Studio, passo a passo.
Você NÃO precisa saber modelagem 3D — vamos usar **Parts básicas** (blocos, cilindros, wedges)
para construir paredes, pisos, tetos e móveis simples.

**Duração estimada:** 2 a 4 horas para um desenvolvedor iniciante.

> ⚠️ **IMPORTANTE:** Todas as coordenadas neste guia estão em **studs** (unidade de medida do Roblox).
> A origem do mapa (0, 0, 0) é o centro do **Hall de Entrada** no térreo.

---

## ANTES DE COMEÇAR

### O que você precisa
- Roblox Studio instalado e conectado ao Rojo (live sync)
- Projeto `assym-roblox-game` aberto no Roblox Studio
- `rojo serve` rodando no terminal

### Configuração inicial
1. Abra o Roblox Studio
2. Conecte o plugin Rojo: **Plugins → Rojo → Connect → localhost**
3. No **Explorer**, crie um **Model** em `Workspace` chamado **"Map"**
4. Dentro de `Map`, crie uma **Folder** chamada **"Rooms"**
5. Dentro de `Map`, crie uma **Folder** chamada **"HidingSpots"**
6. Dentro de `Map`, crie uma **Folder** chamada **"Generators"**
7. Dentro de `Map`, crie uma **Folder** chamada **"Cages"**
8. Dentro de `Map`, crie uma **Folder** chamada **"Doors"**
9. Dentro de `Map`, crie uma **Folder** chamada **"Lighting"**

### Atalhos úteis no Roblox Studio

| Tecla | Ação |
|-------|------|
| **Ctrl+1** | Ferramenta Selecionar |
| **Ctrl+2** | Ferramenta Mover |
| **Ctrl+3** | Ferramenta Rotacionar |
| **Ctrl+4** | Ferramenta Escalar |
| **F** | Centralizar câmera no objeto selecionado |
| **Ctrl+D** | Duplicar objeto selecionado |
| **Ctrl+G** | Agrupar em Model |
| **Alt+1** | Vista frontal |
| **Alt+2** | Vista superior |
| **Alt+3** | Vista lateral |

---

## PASSO 1: CONSTRUIR O TÉRREO (Ground Floor)

O térreo tem **6 cômodos** conectados. Vamos construir um cômodo de cada vez.

### Técnica básica: Construir uma sala

Cada sala é uma **caixa oca** feita de 6 Parts (chão + teto + 4 paredes).
Vamos usar **Parts de 1 stud de espessura**.

**Exemplo: Sala de 14x10x14 studs (Largura x Altura x Profundidade)**

1. **Chão** — crie uma Part: Size (14, 1, 14), Position (0, 0, 0), Name "Floor"
   - Material: **WoodPlanks** ou **Concrete**
   - Color: marrom escuro (RGB: 60, 40, 25)
2. **Teto** — duplique o chão (Ctrl+D), mova Y para +10, Name "Ceiling"
3. **Parede Norte** — crie Part: Size (14, 10, 1), Position (0, 5, -7)
4. **Parede Sul** — duplique a Norte, Z +14, Position (0, 5, 7)
5. **Parede Leste** — crie Part: Size (1, 10, 14), Position (7, 5, 0)
6. **Parede Oeste** — duplique a Leste, X -14, Position (-7, 5, 0)
7. Selecione todas as 6 Parts e agrupe (Ctrl+G) → "SalaModelo"
8. Mova para `Workspace.Map.Rooms`

**Dica:** Use o material `SmoothPlastic` nas paredes internas para um visual mais limpo.
Aplique `WoodPlanks` ou `Wood` no chão.

### 1.1 — Hall de Entrada (14x10x14)

**Center:** (0, 5, 0)

```
Tarefas:
[ ] Criar sala 14x10x14 em (0, 5, 0)
[ ] Deixar aberturas para portas nas 4 direções (ver PASSO 4)
[ ] Adicionar lustre no centro (Cylinder no teto, Y=9.5)
[ ] Adicionar carpete vermelho (Part fina no chão, cor vinho escuro)
[ ] Colocar quadros na parede (Parts planas com Decal)
```

**Portas do Hall:**
- Norte: abertura na posição (-4, 4, -5), tamanho (3, 7, 0.5)
- Sul: abertura na posição (0, 4, 7), tamanho (3, 7, 0.5)
- Leste: abertura na posição (7, 4, -2), tamanho (3, 7, 0.5)
- Oeste: abertura na posição (-7, 4, -4), tamanho (3, 7, 0.5)

### 1.2 — Sala de Estar (14x8x12)

**Center:** (-16, 5, -8)

```
Tarefas:
[ ] Criar sala 14x8x12 em (-16, 5, -8)
[ ] Adicionar sofá: 3 Parts retangulares (assento + encosto + braço)
[ ] Adicionar lareira na parede norte (posição: -22, 4, -12)
      - Use Parts escuras e um PointLight laranja dentro
[ ] Adicionar mesinha de centro (Part baixa)
[ ] Adicionar tapete felpudo
[ ] Conectar ao Hall (porta leste) e ao Corredor dos Fundos (porta sul)
```

**Esconderijos nesta sala:**
- #2: Atrás do Sofá (posição: -22, 2.5, -12)
- #3: Armário (posição: -10, 2.5, -2)
- #4: Lareira (posição: -22, 2, -2)

### 1.3 — Cozinha (12x8x16)

**Center:** (-2, 5, -18)

```
Tarefas:
[ ] Criar sala 12x8x16 em (-2, 5, -18)
[ ] Adicionar bancada (Parts longas ao longo das paredes)
[ ] Adicionar fogão (Part preta com PointLight vermelho)
[ ] Adicionar pia (Part cinza metálica)
[ ] Adicionar mesa pequena no centro
[ ] Conectar ao Corredor dos Fundos (porta sul)
[ ] Conectar à Escada do Porão (abertura no chão na posição -2, 0, -22)
```

**Escada para o Porão:**
- É uma abertura no chão da Cozinha, com escada descendo até Y=-6
- Construa com Parts inclinadas (use WedgePart para os degraus)
- A escada deve ser estreita (2-3 studs de largura)

### 1.4 — Escritório (10x8x12)

**Center:** (14, 5, -6)

```
Tarefas:
[ ] Criar sala 10x8x12 em (14, 5, -6)
[ ] Adicionar escrivaninha (Part grande + Part menor como cadeira)
[ ] Adicionar estante de livros (Parts verticais + Parts horizontais finas)
[ ] Adicionar abajur (Cylinder + PointLight)
[ ] Conectar ao Hall (porta oeste) e ao Corredor dos Fundos (porta sul)
[ ] Construir alçapão secreto no teto (ver PASSO 2)
```

**Alçapão Secreto:**
- É uma abertura no teto do Escritório que leva ao Corredor Superior
- Posição: (10, 10, -6)
- Deve parecer uma escotilha disfarçada (Part de madeira no teto, semiaberta)

### 1.5 — Sala de Jantar (12x8x14)

**Center:** (0, 5, 14)

```
Tarefas:
[ ] Criar sala 12x8x14 em (0, 5, 14)
[ ] Adicionar mesa grande (Part retangular, 8x1x4)
[ ] Adicionar 6 cadeiras ao redor (Parts pequenas)
[ ] Adicionar lustre elegante (Cylinder + PointLight warm)
[ ] Adicionar armário de louças (Part vertical na parede)
[ ] Conectar ao Hall (porta norte)
```

### 1.6 — Corredor dos Fundos (6x8x20)

**Center:** (-8, 5, -12)

```
Tarefas:
[ ] Criar corredor 6x8x20 em (-8, 5, -12)
[ ] Corredor estreito e escuro — pouca decoração
[ ] Adicionar quadros tortos nas paredes
[ ] Adicionar carpete gasto (Part fina desbotada)
[ ] Conectar a: Hall (leste), Sala de Estar (oeste), Cozinha (norte),
      Escritório (leste/sul), Escada Superior (centro)
```

---

## PASSO 2: CONSTRUIR O SEGUNDO ANDAR (Upper Floor)

O segundo andar fica **10 studs acima** do térreo (Y = 15 no centro das salas).

### 2.1 — Escada para o 2º Andar

```
Tarefas:
[ ] Construir escada do Corredor dos Fundos (Y=0) até o Corredor Superior (Y=15)
[ ] Posição dos degraus: (-4, variável, -12)
[ ] Use WedgeParts empilhadas para os degraus
[ ] Adicione corrimão (Parts cilíndricas finas nas laterais)
[ ] Iluminação fraca (PointLight laranja, Range=6, Brightness=0.5)
```

### 2.2 — Corredor Superior (8x8x18)

**Center:** (-4, 15, -6)

```
Tarefas:
[ ] Criar corredor 8x8x18 em (-4, 15, -6)
[ ] Similar ao Corredor dos Fundos: estreito, escuro
[ ] Conectar a: Quarto Principal (oeste), Quarto de Hóspedes (leste/norte),
      Banheiro (leste/sul), Alçapão Secreto (sudeste)
```

### 2.3 — Quarto Principal (14x8x14)

**Center:** (-16, 15, -6)

```
Tarefas:
[ ] Criar quarto 14x8x14 em (-16, 15, -6)
[ ] Adicionar cama grande (Parts para cabeceira + colchão + travesseiros)
[ ] Adicionar guarda-roupa (Part vertical grande)
[ ] Adicionar criado-mudo + abajur
[ ] Adicionar espelho quebrado (Part com Reflectance alto + trincas)
[ ] Janela com luz da lua (ver PASSO 5)
```

### 2.4 — Quarto de Hóspedes (10x8x10)

**Center:** (5, 15, -2)

```
Tarefas:
[ ] Criar quarto 10x8x10 em (5, 15, -2)
[ ] Adicionar cama simples
[ ] Adicionar armário pequeno
[ ] Adicionar baú aos pés da cama
[ ] Ambiente mais modesto que o Quarto Principal
```

### 2.5 — Banheiro (8x8x10)

**Center:** (5, 15, -15)

```
Tarefas:
[ ] Criar banheiro 8x8x10 em (5, 15, -15)
[ ] Adicionar banheira (Part côncava — use um Cylinder cortado ou várias Parts)
[ ] Adicionar pia + espelho
[ ] Adicionar vaso sanitário (se quiser — opcional)
[ ] Piso de azulejo (Material: SmoothPlastic, cor clara gasta)
[ ] Névoa fraca (PointLight azul-claro fraco)
```

### 2.6 — Alçapão Secreto

```
Tarefas:
[ ] No Escritório (térreo), crie uma abertura no teto em (10, 10, -6)
[ ] Construa um túnel vertical estreito (2x12x2) que sobe até Y=15
[ ] No topo, a saída fica no canto do Corredor Superior
[ ] Adicione uma escada de corda (Parts cilíndricas + cordas)
[ ] O alçapão deve ser semiaberto (rotacionado ~45°)
```

---

## PASSO 3: CONSTRUIR O PORÃO (Basement)

O porão é a área mais **aterrorizante** do mapa.

### 3.1 — Porão (18x6x22)

**Center:** (-2, -6, -24)

```
Tarefas:
[ ] Criar porão 18x6x22 em (-2, -6, -24)
[ ] Paredes de pedra bruta (Material: Slate ou Concrete, cor cinza escuro)
[ ] Chão de terra batida (Material: Ground ou Mud)
[ ] Teto baixo (Y do teto: -3) — sensação de claustrofobia
[ ] Iluminação MUITO fraca: apenas 1-2 PointLights vermelhas/âmbar
      (Brightness 0.2, Range 10)
[ ] NÉVOA: crie Parts semi-transparentes (Transparency=0.7, cor cinza)
      ou use ParticleEmitter com fumaça
[ ] Adicionar correntes penduradas no teto
[ ] Adicionar poças de água (Parts planas azul-escuras com Reflectance)
[ ] Adicionar caixas e barris velhos empilhados
```

### 3.2 — Jaula do Porão

```
Tarefas:
[ ] Construir jaula com barras de metal (Parts cilíndricas verticais)
[ ] Posição: (0, -4, -26)
[ ] Tamanho da jaula: 4x5x4
[ ] Barras espaçadas a cada 1 stud
[ ] Porta da jaula (pode ser uma Part que abre/desliza)
[ ] Nome da jaula: "Cage1"
[ ] Adicionar atributo "CageId" = 1 (em Properties → Attributes)
```

---

## PASSO 4: PORTAS E CONEXÕES

### Construindo uma porta

Cada porta é uma **Part fina** (3x7x0.5 studs) que preenche a abertura entre cômodos.

```
Tarefas:
[ ] Para cada porta listada em MansionData.Doors:
      - Posicione a Part na coordenada indicada
      - Ajuste o Size conforme o campo "size"
      - Material: Wood ou WoodPlanks
      - Cor: marrom escuro (RGB: 70, 45, 20)
      - Nome: "Door_HallEntrada_SalaEstar" (from_to)
      - Adicione atributo "DoorId" com o valor "{from}_{to}"
      - Mova para Map.Doors
      - A porta DEVE ser unanchored (para poder abrir)
      - Configure um HingeConstraint se quiser porta que abre
        (opcional para MVP — portas estáticas são aceitáveis)
```

### Lista completa de portas

| De | Para | Posição | Tamanho |
|----|------|---------|---------|
| HallEntrada | SalaEstar | (-7, 4, -4) | 3x7x0.5 |
| HallEntrada | SalaJantar | (0, 4, 7) | 3x7x0.5 |
| HallEntrada | Escritorio | (7, 4, -2) | 3x7x0.5 |
| HallEntrada | CorredorFundos | (-4, 4, -5) | 3x7x0.5 |
| SalaEstar | CorredorFundos | (-14, 4, -10) | 0.5x7x3 |
| Cozinha | CorredorFundos | (-6, 4, -16) | 3x7x0.5 |
| Escritorio | CorredorFundos | (10, 4, -10) | 0.5x7x3 |
| CorredorSuperior | QuartoPrincipal | (-11, 14, -6) | 0.5x7x3 |
| CorredorSuperior | QuartoHospedes | (0, 14, 0) | 3x7x0.5 |
| CorredorSuperior | Banheiro | (1, 14, -10) | 0.5x7x3 |

---

## PASSO 5: ILUMINAÇÃO DRAMÁTICA

### Configuração Global

O servidor (MapService) configura a iluminação automaticamente ao carregar.
Você só precisa posicionar as **fontes de luz** no mapa.

### Feixes de Luz da Lua (Moon Beams)

Crie feixes de luz visíveis entrando pelas janelas usando **Parts com SurfaceLight** ou **SpotLight**:

```
Tarefas:
[ ] Sala de Estar — janela voltada para sul
      - Criar Part transparente (Transparency=0.8) na parede sul
      - Adicionar SpotLight no exterior apontando para dentro
      - Cor: azul pálido (RGB: 150, 180, 220)
      - Angle: 30°, Range: 30, Brightness: 0.6
      - Posição: (-16, 10, 2), Direção: (0, -0.7, 1)

[ ] Escritório — janela voltada para leste
      - SpotLight externo, cor azul fria
      - Posição: (20, 10, -2), Direção: (-1, -0.7, 0)

[ ] Quarto Principal — janela no teto ou parede oeste
      - SpotLight, cor prateada
      - Posição: (-22, 20, -2), Direção: (1, -0.5, 0)

[ ] Corredor dos Fundos — fresta no teto
      - SpotLight fraco entrando por rachadura
      - Posição: (-10, 10, -20), Direção: (0, -0.7, 1)
```

### Iluminação por Cômodo

Cada cômodo deve ter **1-2 PointLights** para iluminação ambiente:

| Cômodo | Luz | Brilho | Range | Cor |
|--------|-----|--------|-------|-----|
| Hall Entrada | Lustre central | 0.7 | 12 | Amarelo velas (255, 240, 200) |
| Sala de Estar | Lareira | 0.5 | 15 | Laranja (255, 150, 50) |
| Cozinha | Luz suja no teto | 0.4 | 10 | Amarelo sujo (200, 180, 140) |
| Escritório | Abajur | 0.6 | 8 | Branco azulado (180, 200, 220) |
| Sala de Jantar | Lustre | 0.55 | 12 | Âmbar (230, 210, 170) |
| Corredor Fundos | Luz fraca na parede | 0.3 | 8 | Marrom claro (160, 140, 100) |
| Corredor Superior | Luz fraca | 0.35 | 8 | Marrom (150, 130, 100) |
| Quarto Principal | Abajur + janela | 0.4 | 10 | Púrpura suave (180, 150, 180) |
| Quarto Hóspedes | Luz de teto fraca | 0.3 | 8 | Esverdeada (150, 170, 150) |
| Banheiro | Luz azulada | 0.25 | 6 | Azul frio (140, 160, 180) |
| Porão | Luz vermelha | 0.2 | 8 | Vermelho escuro (100, 30, 20) |

### Névoa no Porão

Para criar o efeito de névoa no porão:
1. Crie várias **Parts** grandes com:
   - Transparency: 0.85
   - Color: cinza escuro (60, 55, 50)
   - Material: Glass (para o visual de névoa)
   - Posicione-as espalhadas pelo porão em alturas diferentes
2. Alternativa: use **ParticleEmitter** com:
   - Texture: nuvem/fumaça
   - Rate: 5
   - Speed: 0.5
   - Lifetime: 10
   - Size: 5-10
   - Transparency: 0.7-0.9
   - Color: cinza escuro
3. **OU:** use o sistema de névoa nativo do Roblox:
   - `Lighting.FogStart = 0` (névoa começa imediatamente no porão)
   - Isso é configurado automaticamente pelo MapService

---

## PASSO 6: ESCONDERIJOS (Hiding Spots)

Os esconderijos são Parts especiais que precisam ser configuradas com **atributos personalizados**
para que o servidor (MapService) possa identificá-los e gerenciá-los.

### Como criar um esconderijo

Para cada um dos **15 esconderijos** listados:

1. Crie a geometria visual (armário, baú, espaço atrás de móvel, cortina)
2. Adicione uma **Part INVISÍVEL** (Transparency=1, CanCollide=false) que serve como
   **zona de interação** (trigger zone)
3. Nesta Part invisível, adicione os atributos em **Properties → Attributes**:

| Atributo | Tipo | Valor | Descrição |
|----------|------|-------|-----------|
| `HidingSpotId` | number | 1 a 15 | ID do esconderijo (conforme MansionData) |
| `IsBlocked` | bool | false | Se está bloqueado (servidor atualiza) |
| `IsOccupied` | bool | false | Se está ocupado (servidor atualiza) |
| `MaxOccupancy` | number | 1 | Máximo de jogadores (sempre 1) |

4. Nomeie a Part invisível: `HidingSpot_Trigger`
5. Posicione-a EXATAMENTE nas coordenadas listadas no MansionData
6. Coloque-a dentro de `Workspace.Map.HidingSpots`

### Lista completa dos 15 esconderijos

| # | Nome | Cômodo | Posição | Tipo |
|---|------|--------|---------|------|
| 1 | Armário do Hall | HallEntrada | (6, 2.5, -4) | Armário |
| 2 | Atrás do Sofá | SalaEstar | (-22, 2.5, -12) | Atrás de Móvel |
| 3 | Armário da Sala | SalaEstar | (-10, 2.5, -2) | Armário |
| 4 | Lareira | SalaEstar | (-22, 2, -2) | Fresta |
| 5 | Armário da Cozinha | Cozinha | (-6, 2.5, -22) | Armário |
| 6 | Atrás da Mesa | SalaJantar | (0, 2.5, 20) | Atrás de Móvel |
| 7 | Atrás da Estante | Escritorio | (18, 2.5, -10) | Atrás de Móvel |
| 8 | Cortina do Corredor | CorredorFundos | (-10, 2.5, -16) | Cortina |
| 9 | Baú no Corredor | CorredorFundos | (-6, 1.5, -8) | Baú |
| 10 | Guarda-Roupa | QuartoPrincipal | (-22, 18, -10) | Armário |
| 11 | Embaixo da Cama | QuartoPrincipal | (-12, 16, -2) | Fresta |
| 12 | Armário de Hóspedes | QuartoHospedes | (10, 18, 2) | Armário |
| 13 | Atrás da Banheira | Banheiro | (8, 16, -20) | Atrás de Móvel |
| 14 | Atrás das Caixas | Porao | (6, -4, -30) | Atrás de Móvel |
| 15 | Barril Velho | Porao | (-8, -4, -18) | Fresta |

### Dica para esconderijos tipo "Armário"

Use 3 Parts para formar um armário simples:
- 2 Parts laterais (paredes)
- 1 Part frontal (porta) com HingeConstraint (para abrir quando interagir)
- 1 Part traseira (opcional, pode ser a parede da sala)
- A Part trigger invisível dentro do armário

### Dica para esconderijos tipo "Atrás de Móvel"

- Construa o móvel (sofá, mesa, estante) normalmente
- Deixe um espaço de 2-3 studs entre o móvel e a parede
- A Part trigger fica nesse espaço
- O jogador "entra" nesse espaço ao interagir

---

## PASSO 7: GERADORES E JAULAS

### Geradores (5)

Os geradores são máquinas que os Sobreviventes precisam consertar.
Construa cada um como um **Model** com Parts formando uma máquina industrial.

```
Tarefas:
[ ] Para cada gerador em MansionData.Generators:
      - Construir máquina com Parts (base + painel + luzes)
      - Posicionar na coordenada indicada
      - Nome: "Generator_1" (use o id)
      - Adicionar atributo "GeneratorId" = id
      - Adicionar PointLight que muda de cor:
          Vermelho = precisa conserto
          Amarelo = consertando
          Verde = consertado
      - Colocar em Workspace.Map.Generators
```

| # | Nome | Cômodo | Posição |
|---|------|--------|---------|
| 1 | Gerador do Hall | HallEntrada | (-4, 3, -4) |
| 2 | Gerador da Sala de Estar | SalaEstar | (-10, 3, -14) |
| 3 | Gerador da Cozinha | Cozinha | (4, 3, -20) |
| 4 | Gerador do Escritório | Escritorio | (12, 3, -12) |
| 5 | Gerador do Quarto Principal | QuartoPrincipal | (-18, 13, -12) |

### Jaulas (3)

As jaulas são onde o Caçador prende os Sobreviventes capturados.

```
Tarefas:
[ ] Para cada jaula em MansionData.Cages:
      - Construir com barras cilíndricas verticais (Parts Cylinder finas)
      - Base e teto de metal
      - Porta com HingeConstraint
      - Adicionar PointLight vermelha fraca dentro
      - Nome: "Cage_1" (use o id)
      - Adicionar atributo "CageId" = id
      - Colocar em Workspace.Map.Cages
```

| # | Nome | Cômodo | Posição |
|---|------|--------|---------|
| 1 | Jaula do Porão | Porao | (0, -4, -26) |
| 2 | Jaula do Corredor | CorredorFundos | (-8, 4, -6) |
| 3 | Jaula do Superior | CorredorSuperior | (-8, 14, -10) |

---

## PASSO 8: DECORAÇÃO E ATMOSFERA

### Para cada cômodo, adicione:
- [ ] **Teias de aranha:** Parts muito finas (Size Y=0.1) nos cantos, Material: SmoothPlastic,
      Transparency=0.5, cor branca
- [ ] **Poeira:** ParticleEmitter com partículas pequenas flutuando (opcional — pode afetar performance mobile)
- [ ] **Quadros tortos:** Parts planas nas paredes com rotação Z=5-10 graus
- [ ] **Pisos manchados:** Parts escuras sobrepostas ao chão com Transparency=0.7
- [ ] **Móveis empoeirados:** usar cores desbotadas (reduzir saturação)

### Sons ambientes (para o futuro Épico E8 — Áudio)
O AudioService tocará sons automaticamente baseado na proximidade do Caçador.
Por enquanto, você PODE adicionar Sounds no Workspace para testar:
- Som de vento (Looping, Volume=0.3)
- Rangidos ocasionais (não-looping, Volume=0.2)
- Passos ecoando

---

## PASSO 9: OTIMIZAÇÃO MOBILE (IMPORTANTE!)

A maioria dos jogadores de Roblox está em dispositivos móveis.
O mapa DEVE rodar bem em celulares.

### Checklist de performance

- [ ] **Parts com CanCollide=false onde possível** — objetos decorativos não precisam de colisão
- [ ] **Ancorar (Anchored=true) tudo que não se move** — objetos anchored são mais baratos
- [ ] **Limitar PartCount:** máximo de 500 Parts no mapa inteiro
- [ ] **Evitar ParticleEmitter em excesso:** no máximo 5 emissores ativos simultaneamente
- [ ] **Usar materiais simples:** SmoothPlastic é mais barato que Wood/Metal com texturas
- [ ] **Transparency > 0.5** — Parts muito transparentes não renderizam na malha de colisão
- [ ] **Sem Union/CSG operations** — use Parts simples, evite Negate/Union
- [ ] **Iluminação:** usar ShadowMap em vez de Future se causar lag (linha no MapService)
- [ ] **MeshPart apenas para objetos realmente necessários** — Parts básicas são mais performáticas
- [ ] **Agrupar decorações em Models** — mais fácil de gerenciar
- [ ] **StreamingEnabled = false** (o mapa é pequeno, não precisa)

### Configuração recomendada no Roblox Studio

1. Vá em **FILE → Game Settings → Rendering**
2. **Graphics Mode:** Automatic (deixa o Roblox decidir por dispositivo)
3. **Enable VR:** desligado
4. **Rendering → Quality Level:** Automatic

### Teste em dispositivo mobile real

1. Publique o jogo como **privado** no Roblox
2. Instale o app Roblox no celular
3. Entre no jogo pelo celular
4. Caminhe por todos os cômodos e verifique se:
   - FPS se mantém ≥ 28
   - Não há travamentos ao abrir portas
   - Iluminação não causa superaquecimento
   - Porão não fica completamente preto (apenas MUITO escuro)

---

## PASSO 10: VERIFICAÇÃO FINAL (CHECKLIST)

Antes de considerar o mapa pronto, verifique cada item:

### Estrutura
- [ ] Todos os 12 cômodos construídos e posicionados corretamente
- [ ] Todas as portas nas posições corretas
- [ ] Escada para o 2º andar funcional (jogador consegue subir)
- [ ] Escada do porão funcional (jogador consegue descer)
- [ ] Alçapão secreto entre Escritório e Corredor Superior

### Esconderijos
- [ ] 15 esconderijos construídos com Parts trigger invisíveis
- [ ] Cada trigger tem o atributo `HidingSpotId` (1 a 15)
- [ ] Todos posicionados nas coordenadas corretas
- [ ] Todos dentro de `Workspace.Map.HidingSpots`

### Geradores e Jaulas
- [ ] 5 geradores construídos e posicionados
- [ ] 3 jaulas construídas e posicionadas
- [ ] Todos com atributos `GeneratorId` ou `CageId`

### Iluminação
- [ ] PointLights em cada cômodo configuradas
- [ ] Feixes de luz da lua posicionados
- [ ] Porão com iluminação a 20% de brilho
- [ ] Névoa no porão visível

### Organização no Explorer
```
Workspace
└── Map
    ├── Rooms
    │   ├── HallEntrada
    │   ├── SalaEstar
    │   ├── Cozinha
    │   ├── Escritorio
    │   ├── SalaJantar
    │   ├── CorredorFundos
    │   ├── CorredorSuperior
    │   ├── QuartoPrincipal
    │   ├── QuartoHospedes
    │   ├── Banheiro
    │   └── Porao
    ├── HidingSpots
    │   ├── (15 Parts trigger invisíveis)
    ├── Generators
    │   ├── Generator_1
    │   ├── ... (até 5)
    ├── Cages
    │   ├── Cage_1
    │   ├── ... (até 3)
    ├── Doors
    │   ├── (10 Parts porta)
    └── Lighting
        ├── (PointLights, SpotLights)
```

---

## SOLUÇÃO DE PROBLEMAS COMUNS

### "O servidor não encontra o mapa (WaitForChild 'Map' falhou)"
- Verifique se o Model principal se chama EXATAMENTE **"Map"** (case-sensitive)
- Verifique se está no **Workspace** (não em ServerStorage)
- O servidor espera até 15 segundos pelo mapa

### "Esconderijos não funcionam"
- Verifique se a Part trigger tem o atributo `HidingSpotId` com o número correto
- O atributo precisa ser do tipo **number** (não string)
- A Part trigger DEVE estar DENTRO de `Workspace.Map.HidingSpots`
- O jogador precisa estar a no máximo 5 studs de distância

### "O mapa está muito escuro"
- A iluminação dramática é intencional! Mas se estiver injogável:
  1. Aumente o Brightness das PointLights em cada cômodo
  2. Ou ajuste `Lighting.Brightness` no MapService (linha ~110)
  3. Teste em diferentes horários do dia no Studio

### "Performance ruim no celular"
- Reduza PartCount (una Parts decorativas)
- Remova ParticleEmitters
- Use Material SmoothPlastic em vez de Wood/Metal
- Desabilite sombras em objetos pequenos (CastShadow=false)

---

## RECURSOS E REFERÊNCIAS

- **MansionData.lua:** `src/shared/MapData/MansionData.lua` — todas as coordenadas exatas
- **MapService.lua:** `src/server/Services/MapService.lua` — lógica do servidor
- **Arquitetura:** `docs/architecture.md` — visão geral da arquitetura do jogo
- **Documentação Roblox:** https://create.roblox.com/docs

---

**Boa construção!** 🏚️🌙

Qualquer dúvida, consulte a arquitetura do projeto ou pergunte no chat.
