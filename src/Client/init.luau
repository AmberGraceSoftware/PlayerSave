--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Packages.PlayerSave.Registry)
export type Registry = Registry.Registry

local PlayerSaveClient = {}

function PlayerSaveClient.Start(_registry: Registry)
    error("PlayerSave Client has not yet been implemented!")
end

return PlayerSaveClient