--!strict
--[[
    Wrapper layer for performing DataStore API requests.
    If DataStores aren't available, this will be reported to the logger and
    requests will return mock values as though the player is playing from a
    fresh save.
]]
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Config)

local DataStoreWrapper = {}
DataStoreWrapper.__index = {}

export type FallbackImplementation = {
    GetAsync: (
        key: string,
        options: DataStoreGetOptions?
    ) -> any?,
    SetAsync: (
        key: string,
        value: any,
        userIds: {number}?,
        options: DataStoreSetOptions?
    ) -> string
}

local mockDataStoreFallback: FallbackImplementation = {
    GetAsync = function()
        return nil
    end,
    SetAsync = function()
        return "usingMockDataStore"
    end
}

function DataStoreWrapper.new(
    fallback: FallbackImplementation?,
    forceUseFallback: boolean? -- Set to true to for unit testing environment.
)
    local self = {}
    
    -- Make initial GetDataStore() call once, log any errors, and cache the
    -- result for all future calls
    local cacheResult: {
        dataStore: DataStore?,
        getDataStoreError: string?
    }?
    function self.getDataStore(): DataStore?
        if cacheResult then
            return cacheResult.dataStore
        end
        -- Don't connect to datastores in test environment
        if self.forceUseFallback then
            return nil
        end
        -- No need to attempt to connect to data stores if we're testing from an
        -- unsaved roblox file
        if game.GameId == 0
        and RunService:IsStudio() then
            return nil
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
            warn(err)
        end
        return dataStore
    end
    self.fallback = fallback or mockDataStoreFallback
    self.forceUseFallback = forceUseFallback

    setmetatable(self, DataStoreWrapper)
    return self
end

export type DataStoreWrapper = typeof(DataStoreWrapper.new())

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
function DataStoreWrapper.__index.SetAsync(
    self: DataStoreWrapper,
    player: Player,
    data: any
): (boolean, string)
    local dataStore = self.getDataStore()
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
    local newVersion: string = ""
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
    else
        local success, err = pcall(function()
            newVersion = self.fallback.SetAsync(
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

function DataStoreWrapper.__index.GetAsync(
    self: DataStoreWrapper,
    player: Player
): (boolean, any)
    local dataStore = self.getDataStore()
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
    else
        local success, err = pcall(function()
            returnValue = self.fallback.GetAsync(
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