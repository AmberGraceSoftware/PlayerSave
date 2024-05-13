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

local RunService = game:GetService("RunService")
local Save = require(script.Save)
local Config = require(script.Config)
local DataStoreWrapper = require(script.DataStoreWrapper)
local PlayerSaveClient = require(script.PlayerSaveClient)
local PlayerSaveServer = require(script.PlayerSaveServer)
local Registry = require(script.Registry)
export type KeyPath = Save.KeyPath
export type Save = Save.Save
export type Config = Config.Config
export type ConfigPartial = Config.ConfigPartial

local registry = Registry.new()
local PlayerSave = {}

function PlayerSave.SetConfig(config: ConfigPartial)
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
    deepMerge(Config, config)
end

-- Server/client runtime function
function Start()
    registry:StartHeartbeatLoop()
    local dataStoreWrapper = DataStoreWrapper.new()
    if RunService:IsServer() then
        PlayerSaveServer.Start(registry, dataStoreWrapper, LIBRARY_VERSION)
    else
        PlayerSaveClient.Start(registry)
    end
end

-- Start runtime logic only if we're in a running game (i.e. not editing in
-- studio, or in a unit test environment)
if RunService:IsRunning() then
    task.defer(task.defer, Start)
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

PlayerSave.Version = LIBRARY_VERSION

return PlayerSave