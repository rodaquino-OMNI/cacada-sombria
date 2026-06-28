--!strict
--[[
  MathUtil.lua
  Funções matemáticas utilitárias usadas por todo o jogo.
  Inclui distância, clamp, verificação de alcance, etc.

  Contexto: Shared (ReplicatedStorage)
]]

local MathUtil = {}

-- ==========================================
-- FUNÇÕES DE DISTÂNCIA
-- ==========================================

-- Calcula a distância entre duas posições Vector3 no espaço 3D
-- Uso: saber se um Sobrevivente está perto do Caçador, de um gerador, etc.
function MathUtil.distance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

-- Calcula a distância horizontal (ignora altura/Y) entre duas posições
-- Útil para verificar se jogadores estão no mesmo andar
function MathUtil.horizontalDistance(pos1: Vector3, pos2: Vector3): number
	local diff = pos1 - pos2
	diff = Vector3.new(diff.X, 0, diff.Z)
	return diff.Magnitude
end

-- ==========================================
-- FUNÇÕES DE LIMITE (CLAMP)
-- ==========================================

-- Limita um valor entre um mínimo e um máximo
-- Ex: clamp(150, 0, 100) → 100
--     clamp(-5, 0, 100)  → 0
--     clamp(50, 0, 100)  → 50
function MathUtil.clamp(value: number, min: number, max: number): number
	if value < min then return min end
	if value > max then return max end
	return value
end

-- ==========================================
-- FUNÇÕES DE VERIFICAÇÃO DE ALCANCE
-- ==========================================

-- Verifica se duas posições estão dentro de um determinado alcance (em studs)
-- Retorna true se a distância for ≤ alcance
function MathUtil.isInRange(pos1: Vector3, pos2: Vector3, range: number): boolean
	return (pos1 - pos2).Magnitude <= range
end

-- Verifica se duas posições estão dentro de um alcance horizontal
-- Ignora diferença de altura (útil para sons de passos)
function MathUtil.isInHorizontalRange(pos1: Vector3, pos2: Vector3, range: number): boolean
	local diff = pos1 - pos2
	diff = Vector3.new(diff.X, 0, diff.Z)
	return diff.Magnitude <= range
end

-- ==========================================
-- DIREÇÃO E ORIENTAÇÃO
-- ==========================================

-- Calcula o vetor de direção normalizado de uma posição para outra
-- Retorna um Vector3 de comprimento 1 apontando de `from` para `to`
function MathUtil.direction(from: Vector3, to: Vector3): Vector3
	local diff = to - from
	if diff.Magnitude < 0.001 then
		return Vector3.new(0, 0, 0) -- Evita divisão por zero
	end
	return diff.Unit
end

-- Verifica se a posição `target` está dentro do cone de visão de `observer`
-- lookDirection: para onde o observer está olhando (Vector3 normalizado)
-- fovAngle: ângulo do cone de visão em graus
-- maxRange: alcance máximo (opcional, padrão = infinito)
function MathUtil.isInVisionCone(
	observerPos: Vector3,
	lookDirection: Vector3,
	targetPos: Vector3,
	fovAngle: number,
	maxRange: number?
): boolean
	-- Verifica alcance se especificado
	if maxRange then
		if not MathUtil.isInRange(observerPos, targetPos, maxRange) then
			return false
		end
	end

	-- Calcula direção até o alvo
	local dirToTarget = (targetPos - observerPos).Unit

	-- Calcula o ângulo entre o olhar e o alvo
	-- Dot product: 1 = mesma direção, 0 = 90°, -1 = oposto
	local dot = lookDirection:Dot(dirToTarget)

	-- Converte FOV de graus para o valor de dot product equivalente
	-- cos(0) = 1 (centro), cos(FOV/2) = borda do cone
	local halfFovRad = math.rad(fovAngle / 2)
	local minDot = math.cos(halfFovRad)

	return dot >= minDot
end

return MathUtil
