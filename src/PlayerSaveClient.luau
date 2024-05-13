--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreWrapper = require(ReplicatedStorage.Packages.PlayerSave.DataStoreWrapper)
local Registry = require(ReplicatedStorage.Packages.PlayerSave.Registry)
export type Registry = Registry.Registry
export type DataStoreWrapper = DataStoreWrapper.DataStoreWrapper

local PlayerSaveClient = {}

function PlayerSaveClient.Start(_registry: Registry)
    
end

return PlayerSaveClient