--!strict
--[[
  Signal.lua
  Implementação simples de Signal (pub/sub) para comunicação interna
  entre módulos no mesmo contexto (server↔server ou client↔client).

  Uso:
    local meuSignal = require(script.Parent.Signal)
    local sig = meuSignal.new()
    sig:Connect(function(...) print(...) end)
    sig:Fire("Olá", "mundo")

  Contexto: Shared (ReplicatedStorage)
]]

local Signal = {}
Signal.__index = Signal

-- Cria um novo objeto Signal
function Signal.new()
	-- self é uma tabela vazia com metatable Signal
	local self = setmetatable({}, Signal)

	-- Lista de funções listeners registradas
	self._listeners = {}

	-- Contador para gerar IDs únicos de conexão
	self._idCounter = 0

	return self
end

-- Conecta uma função listener ao Signal
-- Retorna um objeto de conexão com método :Disconnect()
function Signal:Connect(fn: (...any) -> ())
	-- Gera um ID único para esta conexão
	self._idCounter += 1
	local id = self._idCounter

	-- Armazena a função com seu ID
	self._listeners[id] = fn

	print(string.format(
		"[CacadaSombria] Signal: Listener #%d conectado (total: %d)",
		id,
		#self._listeners
	))

	-- Retorna um objeto de conexão que permite desconectar depois
	return {
		Disconnect = function()
			self._listeners[id] = nil
		end,
	}
end

-- Dispara o Signal, chamando todos os listeners registrados
-- Usa task.spawn para cada listener evitar que um erro em um listener
-- impeça os outros de serem chamados
function Signal:Fire(...: any)
	for _, fn in self._listeners do
		-- task.spawn executa a função em uma nova thread,
		-- então se uma função der erro, as outras ainda rodam
		task.spawn(fn, ...)
	end
end

-- Remove todos os listeners
function Signal:Destroy()
	table.clear(self._listeners)
end

return Signal
