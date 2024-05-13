--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)
local SerializeUtil = require(script.Parent.SerializeUtil)
local DataStoreWrapper = require(ReplicatedStorage.Packages.PlayerSave.DataStoreWrapper)
local Registry = require(ReplicatedStorage.Packages.PlayerSave.Registry)
export type Registry = Registry.Registry
export type DataStoreWrapper = DataStoreWrapper.DataStoreWrapper

local PlayerSaveServer = {}

function PlayerSaveServer.Start(
    registry: Registry,
    wrapper: DataStoreWrapper,
    libraryVersion: string
)
    Players.PlayerAdded:Connect(function(player)
        local save = registry:OpenSave(player)
        -- (Blocking) Request initial data
        local success, loadedDataOrErr = wrapper:GetAsync(player)
        if not save:PlayerIsStillInGame() then
            return
        end

        local wasSafelyLoaded
        local dataToInitialize: {[string]: any}? = nil
        if success then
            if not loadedDataOrErr then
                wasSafelyLoaded = true
            elseif loadedDataOrErr.PlayerSaveLibraryVersion
            and loadedDataOrErr.SaveData then
                dataToInitialize = loadedDataOrErr.SaveData
                wasSafelyLoaded = true
            elseif Config.MigrateLegacyData then
                local migration: any
                local migrationScucess, migrationErr = pcall(function()
                    migration = Config.MigrateLegacyData(loadedDataOrErr)
                end)
                if not migrationScucess then
                    warn("Data migration failure: " .. migrationErr)
                    wasSafelyLoaded = false
                else
                    local storableSuccess, storableErr
                        = SerializeUtil.ValueIsStorable(migration)
                    if storableSuccess then
                        wasSafelyLoaded = true
                        dataToInitialize = migration
                    else
                        warn("Data migration failure: "
                            .. (storableErr or "Config.MigrateLegacyData() "
                                .. "result is not storeable!"))
                        wasSafelyLoaded = false
                    end
                end
            else
                wasSafelyLoaded = false
                dataToInitialize = loadedDataOrErr
            end
        else
            wasSafelyLoaded = false
            warn(loadedDataOrErr)
        end
        save._safeToSave = wasSafelyLoaded
        save._loaded = true
        
        if dataToInitialize then
            save._data = dataToInitialize
            save._listenerTree:FireAllListeners(save._data)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        task.defer(function()
            local save = registry:CloseSave(player)
            if not save then
                return
            end
            if save:IsSafeToSave() then
                wrapper:SetAsync(player, {
                    PlayerSaveLibraryVersion = libraryVersion,
                    SaveData = save._data,
                })
            end
        end)
    end)
end

return PlayerSaveServer