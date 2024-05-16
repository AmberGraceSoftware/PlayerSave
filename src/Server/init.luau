--!strict
local DataStoreWrapper = require(script.DataStoreWrapper)
local AutoSaving = require(script.Mechanisms.AutoSaving)
local BindToClose = require(script.Mechanisms.BindToClose)
local EnterLoadAndExitSave = require(script.Mechanisms.EnterLoadAndExitSave)
local Registry = require(script.Parent.Registry)
local SaveScheduler = require(script.SaveScheduler)
export type Registry = Registry.Registry
export type DataStoreWrapper = DataStoreWrapper.DataStoreWrapper
export type Save = Registry.Save

local PlayerSaveServer = {}

function PlayerSaveServer.Start(
    registry: Registry,
    libraryVersion: string
)
    -- Save Loading Mechanism
    local dataStoreWrapper = DataStoreWrapper.new()
    local saveScheduler = SaveScheduler.new(dataStoreWrapper, libraryVersion)
    
    -- Start component mechanisms
    saveScheduler:StartProcessLoop()
    EnterLoadAndExitSave.Start(registry, saveScheduler, dataStoreWrapper)
    AutoSaving.Start(registry, saveScheduler)
    BindToClose.Start(registry, saveScheduler)
end

return PlayerSaveServer