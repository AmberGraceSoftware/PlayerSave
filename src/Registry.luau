--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Save = require(ReplicatedStorage.Packages.PlayerSave.Save)
export type Save = Save.Save

local Registry = {}
Registry.__index = {}

function Registry.new()
    local self = {}
    self._map = {} :: {[Player]: Save}
    self._onRegistryInsertOrHeartbeat = Instance.new("BindableEvent")
    self._heartbeatConn = RunService.Heartbeat:Connect(function()
        self._onRegistryInsertOrHeartbeat:Fire()
    end)

    setmetatable(self, Registry)
    return self
end

function Registry:Destroy()
    self._heartbeatConn:Disconnect()
    self._onRegistryInsertOrHeartbeat:Destroy()
end

export type Registry = typeof(Registry.new())

function Registry.__index.OpenSave(
    self: Registry,
    player: Player
): Save
    local save = Save.new()
    self._map[player] = save
    task.defer(function()
        self._onRegistryInsertOrHeartbeat:Fire()
    end)
    return save
end

function Registry.__index.CloseSave(
    self: Registry,
    player: Player
): Save?
    local save = self._map[player]
    if not save then
        return nil
    end
    save._closed = true
    return save
end

function Registry.__index.Get(self: Registry, player: Player)
    return self._map[player]
end

function Registry.__index.WaitFor(
    self: Registry,
    player: Player,
    timeout: number?
): Save?
    local expires = if timeout then os.clock() + timeout else math.huge
    while os.clock() < expires
    and player.Parent == Players do
        local save = self:Get(player)
        if save then
            return save
        end
        self._onRegistryInsertOrHeartbeat.Event:Wait()
    end
    return nil
end

return Registry