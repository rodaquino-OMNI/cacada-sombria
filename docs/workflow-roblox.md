# Guia: Como Desenvolver e Publicar no Roblox

## 🔧 Ferramentas

| Ferramenta | Função |
|-----------|--------|
| **Roblox Studio** | Editor visual, testar, publicar |
| **Rojo** (v7.6.1) | Sincroniza arquivos locais ↔ Roblox Studio |
| **VS Code** | Editar código Luau com syntax highlight |
| **Git + GitHub** | Versionamento do código |

---

## 📁 Estrutura do Projeto

```
assym-roblox-game/
├── default.project.json    ← Config do Rojo (mapeia pastas → Instances Roblox)
├── .gitignore              ← Ignora builds e arquivos do Roblox Studio
├── src/
│   ├── server/             ← ServerScriptService (lógica do servidor)
│   ├── client/             ← StarterPlayerScripts (lógica do cliente)
│   ├── shared/             ← ReplicatedStorage (módulos compartilhados)
│   └── assets/             ← ServerStorage (assets, sons, etc.)
├── docs/                   ← Documentação (GDD, Arquitetura)
└── _bmad/                  ← Documentos de design (Brief, GDD, etc.)
```

---

## 🚀 Fluxo Diário de Desenvolvimento

### 1. Iniciar o servidor Rojo (live sync)

```bash
cd /Users/familia/assym-roblox-game
rojo serve
```

Isso inicia um servidor local. Deixe rodando.

### 2. Abrir Roblox Studio

1. Instale o **plugin Rojo** no Roblox Studio
   - Vá em: Plugins → Manage Plugins → procurar "Rojo"
   - Instale o plugin oficial
2. No Roblox Studio: Plugins → Rojo → **Connect**
3. Insira: `localhost` (porta padrão)

Pronto! Agora ao salvar qualquer arquivo `.lua` no VS Code, ele aparece automaticamente no Roblox Studio.

### 3. Testar no Roblox Studio

- Pressione **F5** ou **Play** no Roblox Studio
- Teste com múltiplos clientes: Test → Clients and Servers → 5 players
- Veja o Output (View → Output) para logs/debug

### 4. Commitar no Git

```bash
git add .
git commit -m "feat: descrição do que foi feito"
git push origin main
```

---

## 🌐 Publicar no Roblox

### Publicação (dentro do Roblox Studio)

1. **File → Publish to Roblox**
2. Preencha:
   - **Name:** Caçada Sombria
   - **Description:** Jogo assimétrico de terror...
   - **Genre:** Horror
3. Clique **Create** (primeira vez) ou **Update** (atualizações)

### Configurações importantes na página do jogo (roblox.com):

| Configuração | Recomendado |
|-------------|-------------|
| **Privacy** | Public (ou Friends para teste) |
| **Max Players** | 5 (1 Killer + 4 Survivors) |
| **Allow Copying** | Off (protege seu código) |
| **Device** | Computer + Phone + Tablet |

---

## 🔄 Ciclo Completo

```
VS Code (editar) → Rojo sync → Roblox Studio (testar) → Git (commitar) → Roblox (publicar)
```

### Atalhos importantes:

```bash
# Sync ao vivo
rojo serve

# Build standalone (se precisar de .rbxlx)
rojo build -o CacadaSombria.rbxlx

# Status do Git
git status

# Histórico
git log --oneline
```
