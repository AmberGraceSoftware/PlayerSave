--!strict
--[[
    A simple DataStore player data management library.
    The architecture + API is similar to ProfileService, but utilizes some extra
    techinques for fault tolerance and dupe prevention.

    Features:
        - Player data saves on exit
        - Tolerance for server crashes, universe teleports, trading API (WIP)
        - Configurable auto-saving and on-demand saving
        - Configurable replication of a player's own data to the client
        - Get, Set, Subscribe for different values in the player's data store
        - Client-side prediction
]]

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