--!strict
--[[
  RemoteEventUtils.lua
  Utilitário para buscar RemoteEvents em ReplicatedStorage.Events
  de forma segura, evitando confundir ModuleScripts (Rojo) com RemoteEvents (servidor).
  
  Contexto: Shared (ReplicatedStorage) — pode ser usado por Server e Client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEventUtils = {}

-- Busca um RemoteEvent pelo nome em ReplicatedStorage.Events
-- Garante que retorna APENAS RemoteEvents (não ModuleScripts)
function RemoteEventUtils.find(name: string): RemoteEvent?
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		return nil
	end

	for _, child in eventsFolder:GetChildren() do
		if child:IsA("RemoteEvent") and child.Name == name then
			return child
		end
	end

	return nil
end

-- Busca múltiplos RemoteEvents de uma vez
-- Retorna uma tabela {name = RemoteEvent}
function RemoteEventUtils.findAll(names: {string}): {[string]: RemoteEvent}
	local result = {}
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		return result
	end

	for _, child in eventsFolder:GetChildren() do
		if child:IsA("RemoteEvent") then
			for _, name in names do
				if child.Name == name then
					result[name] = child
				end
			end
		end
	end

	return result
end

return RemoteEventUtils
