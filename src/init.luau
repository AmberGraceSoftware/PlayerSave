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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Save = require(script.Save)
local Config = require(script.Config)
export type KeyPath = Save.KeyPath
export type Save = Save.Save
export type Config = Config.Config
export type ConfigPartial = Config.ConfigPartial

local PlayerSave = {}

local initialized = false
local registry: {[Player]: Save} = {}
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
    deepMerge(Config, config :: any)

    Players.PlayerAdded:Connect(function(player)
        registry[player] = Save.new()
    end)
    Players.PlayerRemoving:Connect(function(player)
        task.defer(function()
            local store = registry[player]
            if not store then
                return
            end
            registry[player] = nil
            store._closed = true
        end)
    end)
end

function PlayerSave.Get(player: Player): Save?
    return registry[player]
end

function PlayerSave.GetLoaded(player: Player): Save?
    local store = PlayerSave.Get(player)
    if not store then
        return nil
    end
    if not store:IsLoaded() then
        return nil
    end
    return store
end
 
function PlayerSave.WaitFor(
    player: Player,
    timeout: number?
): Save?
    local expires = if timeout then os.clock() + timeout else math.huge
    while os.clock() < expires
    and player.Parent == Players do
        local store = PlayerSave.Get(player)
        if store then
            return store
        end
        RunService.Heartbeat:Wait()
    end
    return nil
end

function PlayerSave.WaitForLoaded(
    player: Player,
    timeout: number?
): Save?
    local startTime = os.clock()
    local store = PlayerSave.WaitFor(player, timeout)
    if not store then
        return nil
    end
    local remaining = if timeout
        then (startTime + timeout) - os.clock()
        else math.huge
    if remaining < 0 then
        return nil
    end
    if store:WaitUntilLoaded(remaining) then
        return store
    end
    return nil
end

return PlayerSave