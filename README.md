# CacadaSombria

## Scripts Roblox por Tipo

| Pasta | Destino Roblox | Propósito |
|-------|---------------|-----------|
| `src/server/` | ServerScriptService | Lógica do servidor (game loop, dano, captura) |
| `src/client/` | StarterPlayerScripts | Lógica do cliente (HUD, input, câmera) |
| `src/shared/` | ReplicatedStorage | Módulos compartilhados (constantes, tipos) |
| `src/assets/` | ServerStorage | Assets referenciados em runtime |

## Rojo Sync

```bash
# Iniciar servidor Rojo (para live-sync com Roblox Studio)
rojo serve

# Build standalone
rojo build -o CacadaSombria.rbxlx
```
