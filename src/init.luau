--!strict
--[[
    A holistic library for storing, replicating, and observing player save data
]]

--[=[
    @class PlayerSave

    :::warning
    PlayerSave is still a work in progress and does not currently have a full
    release! Please avoiding PlayerSave in production-bound projects, as the
    library is not fully tested, and the API may be subject to change
    :::
    
    PlayerSave is a holistic library that handles storing, replicating,
    and observing player data in a simple and fault-tolerant way.

    PlayerSave provides a number of key [Mechanisms](../docs/mechanisms) that
    can be configured to the needs of a project. PlayerSave is designed to
    function as expected without much configuration out-of-the-gate, but you
    should also read the documentation to customize your configuration depending
    on the features your game includes (for example, trading).
    
    For more information, see the [Usage Guide](../docs/intro)
]=]

local LIBRARY_VERSION = "0.0.1"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Save = require(script.Save)
local Config = require(script.Config)
local DataStoreWrapper = require(script.DataStoreWrapper)
local SerializeUtil = require(script.SerializeUtil)
local Registry = require(script.Registry)
export type KeyPath = Save.KeyPath
export type Save = Save.Save
export type Config = Config.Config
export type ConfigPartial = Config.ConfigPartial

local PlayerSave = {}

local initialized = false
local registry = Registry.new()
function PlayerSave.Init(config: ConfigPartial?)
    if initialized then
        error("PlayerSave.Init has already been called!")
    end
    if not RunService:IsServer() then
        error("PlayerSave.Init can only be called on the server!")
    end

    -- Perform deep merge of config keys
    local function deepMerge(table1: {[string]: any}, table2: {[string]: any})
        for k, v in table2 do
            if typeof(v) == "table"
            and typeof(table1[k]) == "table" then
                deepMerge(table1[k], v)
            else
                table1[k] = v
            end
        end
    end
    if config then
        deepMerge(Config, config)
    end

    local wrapper = DataStoreWrapper.new()
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
            if initialized then
                save._listenerTree:FireAllListeners(save._data)
            end
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
                    PlayerSaveLibraryVersion = LIBRARY_VERSION,
                    SaveData = save._data,
                })
            end
        end)
    end)
end

function PlayerSave.Get(player: Player): Save?
    return registry:Get(player)
end

function PlayerSave.GetLoaded(player: Player): Save?
    local save = PlayerSave.Get(player)
    if not save then
        return nil
    end
    if not save:IsLoaded() then
        return nil
    end
    return save
end
 
function PlayerSave.WaitFor(
    player: Player,
    timeout: number?
): Save?
    return registry:WaitFor(player, timeout)
end

function PlayerSave.WaitForLoaded(
    player: Player,
    timeout: number?
): Save?
    local startTime = os.clock()
    local save = PlayerSave.WaitFor(player, timeout)
    if not save then
        return nil
    end
    local remaining = if timeout
        then (startTime + timeout) - os.clock()
        else math.huge
    if remaining < 0 then
        return nil
    end
    if save:WaitUntilLoaded(remaining) then
        return save
    end
    return nil
end

return PlayerSave