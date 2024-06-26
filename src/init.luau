--!strict
--[[
    A holistic library for storing, replicating, and observing player save data
]]

--[=[
    @class PlayerSave

    :::warning
    PlayerSave is still a work in progress and does not currently have a full
    release! Please avoid using PlayerSave in production-bound projects, as the
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
local PlayerSaveClient = require(script.Client)
local PlayerSaveServer = require(script.Server)
local Registry = require(script.Registry)
export type KeyPath = Save.KeyPath
export type Save = Save.Save
export type DeepSelectionQuery = Save.DeepSelectionQuery
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

    
    -- Merge VisibileToAllClients values over VisibleToOwnClient
    local function deepExtendVisibilityTrees(
        original: DeepSelectionQuery?,
        extension: DeepSelectionQuery
    ): DeepSelectionQuery
        if typeof(extension) == "boolean" then
            if extension == true then
                return true
            else
                return if original ~= nil then original else false
            end
        else -- typeof(extession) == "table"
            if typeof(original) == "table" then
                for k, v in extension do
                    original[k] = deepExtendVisibilityTrees(original[k], v)
                end
                return original
            elseif original == true then
                return true
            else
                return extension
            end
        end
    end
    if typeof(Config.DataVisibility.VisibleToAllClients) == "table"
    and typeof(Config.DataVisibility.VisibleToOwnClient) == "table" then
        Config.DataVisibility.VisibleToOwnClient
            = deepExtendVisibilityTrees(
                Config.DataVisibility.VisibleToOwnClient,
                Config.DataVisibility.VisibleToAllClients
            )
    end
end

-- Server/client runtime function
function Start()
    registry:StartHeartbeatLoop()
    if RunService:IsServer() then
        PlayerSaveServer.Start(registry, LIBRARY_VERSION)
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

function PlayerSave.OnSaveOpened(
    listener: (player: Player, save: Save) -> ()
)
    local connection = registry.SaveOpened.Event:Connect(function(player)
        listener(player, registry:Get(player) :: Save)
    end)
    return function()
        connection:Disconnect()
    end
end

function PlayerSave.OnSaveLoaded(
    listener: (player: Player, save: Save) -> ()
)
    local connection = registry.SaveLoaded.Event:Connect(function(player)
        listener(player, registry:Get(player) :: Save)
    end)
    return function()
        connection:Disconnect()
    end
end

function PlayerSave.OnSaveClosed(
    listener: (player: Player, save: Save) -> ()
)
    local connection = registry.SaveClosed.Event:Connect(function(
        closure: () -> (Player, Save)
    )
        listener(closure())
    end)
    return function()
        connection:Disconnect()
    end
end

function PlayerSave.GetOpenSaves()
    return registry:GetOpenSaves()
end

function PlayerSave.GetLoadedSaves()
    return registry:GetLoadedSaves()
end

PlayerSave.Version = LIBRARY_VERSION

return PlayerSave