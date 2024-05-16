--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local SerializeUtil = require(script.Parent.SerializeUtil)
local DataStoreWrapper = require(script.DataStoreWrapper)
local Registry = require(script.Parent.Registry)
local SaveFormat = require(script.SaveFormat)
local SaveScheduler = require(script.SaveScheduler)
export type Registry = Registry.Registry
export type DataStoreWrapper = DataStoreWrapper.DataStoreWrapper

local PlayerSaveServer = {}

local function processStoredValue(storedValue: unknown): (boolean, any)
    if not storedValue then
        -- Case 1: Encountered a new save
        return true, nil
    elseif SaveFormat.IsSavedValueInPlayerSaveFormat(storedValue) then
        -- Case 2: Encountered a save managed by PlayerSave
        local success, returnValueOrErr = pcall(function()
            return SaveFormat.DeserializeStoredValue(storedValue)
        end)
        return success, returnValueOrErr
    elseif Config.MigrateLegacyData then
        -- Case 3: Encountered legacy data; run MigrateLegacyData config
        local success, migrationOrErr: any = pcall(function()
            return Config.MigrateLegacyData(storedValue)
        end)
        if not success then
            return false, "Data migration failure: " .. migrationOrErr
        end
        local storableSuccess, storableErr
            = SerializeUtil.ValueIsStorable(migrationOrErr)
        if storableSuccess then
            return true, storedValue
        end
        return false, "Data migration failure: " .. (
            storableErr
            or "result of callback Config.MigrateLegacyData() is not a "
                .. "storable object! Must be a table with string and number "
                .. "keys."
        )
    else
        warn("Encountered legacy data", storedValue)
        -- Case 4: Encountered legacy data; no MigrateLegacyData callback was
        -- specified.
        if typeof(storedValue) ~= "table" then
            return false, "Saved value is not a table!"
        end
        local storableSuccess, storableErr
            = SerializeUtil.ValueIsStorable(storedValue)
        if storableSuccess then
            return true, storedValue
        end
        return false, storableErr
    end
end

function PlayerSaveServer.Start(
    registry: Registry,
    libraryVersion: string
)
    -- Save Loading Mechanism
    local dataStoreWrapper = DataStoreWrapper.new()
    local saveScheduler = SaveScheduler.new(dataStoreWrapper, libraryVersion)
    saveScheduler:Start()
    Players.PlayerAdded:Connect(function(player)
        local save = registry:OpenSave(player)
        -- (Blocking) Request initial data
        local success, loadedDataOrErr = dataStoreWrapper:GetAsync(player)
        if not save:PlayerIsStillInGame() then
            return
        end

        local wasSafelyLoaded
        local dataToInitialize: {[string]: any}? = nil
        if success then
            local processSuccess, processedDataOrErr =
                processStoredValue(loadedDataOrErr)
            wasSafelyLoaded = processSuccess
            if processSuccess then
                dataToInitialize = processedDataOrErr
            else
                warn(processedDataOrErr)
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

        registry.SaveLoaded:Fire(player)
    end)

    -- Exit save mechanism
    Players.PlayerRemoving:Connect(function(player)
        task.defer(function()
            local save = registry:CloseSave(player)
            if not save then
                return
            end
            saveScheduler:ScheduleSave(save, "ExitSave")
        end)
    end)

    -- BindToClose mechanism
    game:BindToClose(function()
        saveScheduler:ProcessQueue()
        while #registry:GetOpenSaves() > 0
        or not saveScheduler:AllSavesHaveBeenProcessed() do
            RunService.Heartbeat:Wait()
            saveScheduler:ProcessQueue()
        end
    end)
end

return PlayerSaveServer