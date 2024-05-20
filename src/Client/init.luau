--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationClient = require(script.Mechanisms.ReplicationClient)
local Registry = require(ReplicatedStorage.Packages.PlayerSave.Registry)
export type Registry = Registry.Registry

local PlayerSaveClient = {}

function PlayerSaveClient.Start(registry: Registry)
    ReplicationClient.Start(registry)
end

return PlayerSaveClient