--!strict
--[[
    Wrapper layer for performing DataStore API requests.
    If DataStores aren't available, this will be reported to the logger and
    requests will return mock values as though the player is playing from a
    fresh save.
]]
local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

local DataStoreWrapper = {}

-- Make initial GetDataStore() call once, log any errors, and cache the result
-- for all future calls
local getDataStore: () -> DataStore?
do
    local cacheResult: {
        dataStore: DataStore?,
        getDataStoreError: string?
    }?
    getDataStore = function()
        if cacheResult then
            return cacheResult.dataStore
        end
        local dataStore
        local success, err = pcall(function()
            dataStore = DataStoreService:GetDataStore(
                Config.DataStore.Name,
                Config.DataStore.Scope,
                Config.DataStore.Options
            )
        end)
        if success then
            cacheResult = {
                dataStore = dataStore,
            }
        else
            cacheResult = {
                getDataStoreError = err,
            }
        end
        return dataStore
    end
end

local function getPlayerSaveKey(player: Player): (boolean, any)
    local playerSaveKey: string?
    local success, err = pcall(function()
        playerSaveKey = Config.DataStore.PlayerSaveKey(player)
    end)

    if success then
        if typeof(playerSaveKey) == "string" then
            return true, playerSaveKey
        else
            return false, "Bad return value for "
                .. "Config.DataStore.PlayerSaveKey(player): Expected string, got "
                .. typeof(playerSaveKey)
                .. ": "
                .. tostring(playerSaveKey)
        end
    else
        return false, "Error while calling "
            .. "Config.DataStore.PlayerSaveKey(player): "
            .. err
    end
end

function DataStoreWrapper.SetAsync(
    player: Player,
    data: any
): (boolean, string)
    local dataStore = getDataStore()
    local keySuccess, keyOrErr = getPlayerSaveKey(player)
    if not keySuccess then
        return false, keyOrErr
    end
    local setOptions: DataStoreSetOptions?
    if Config.DataStore.SetOptions then
        local success, err = pcall(function()
            setOptions = Config.DataStore.SetOptions(player, data)
        end)
        if not success then
            return false, err
        end
    end
    local newVersion: string = "usingMockDataStore"
    if dataStore then
        local success, err = pcall(function()
            newVersion = dataStore:SetAsync(
                keyOrErr,
                data,
                {player.UserId},
                setOptions
            )
        end)
        if not success then
            return false, err
        end
    end
    return true, newVersion
end

function DataStoreWrapper.GetAsync(player: Player): (boolean, any)
    local dataStore = getDataStore()
    local keySuccess, keyOrErr = getPlayerSaveKey(player)
    if not keySuccess then
        return false, keyOrErr
    end
    local getOptions: DataStoreGetOptions?
    if Config.DataStore.GetOptions then
        local success, err = pcall(function()
            getOptions = Config.DataStore.GetOptions(player)
        end)
        if not success then
            return false, err
        end
    end
    local returnValue: any?
    if dataStore then
        local success, err = pcall(function()
            returnValue = dataStore:GetAsync(
                keyOrErr,
                getOptions :: DataStoreGetOptions
            )
        end)
        if not success then
            return false, err
        end
    end
    return true, returnValue
end

return DataStoreWrapper