--!strict
local RegistryClient = require(script.Mechanisms.RegistryClient)
local ReplicationClient = require(script.Mechanisms.ReplicationClient)
local Registry = require(script.Parent.Registry)
export type Registry = Registry.Registry

local PlayerSaveClient = {}

function PlayerSaveClient.Start(registry: Registry)
    RegistryClient.Start(registry)
    ReplicationClient.Start(registry)
end

return PlayerSaveClient