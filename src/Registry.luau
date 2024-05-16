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
    self._heartbeatConn = nil :: RBXScriptConnection?
    self.SaveOpened = Instance.new("BindableEvent")
    self.SaveLoaded = Instance.new("BindableEvent")
    self.SaveClosed = Instance.new("BindableEvent")

    setmetatable(self, Registry)
    return self
end

export type Registry = typeof(Registry.new())

function Registry.__index.StartHeartbeatLoop(self: Registry)
    RunService.Heartbeat:Connect(function()
        self._onRegistryInsertOrHeartbeat:Fire()
    end)
end

function Registry.__index.StopHeartbeatLoop(self: Registry)
    if self._heartbeatConn then
        self._heartbeatConn:Disconnect()
        self._heartbeatConn = nil
    end
end

function Registry.__index.OpenSave(
    self: Registry,
    player: Player
): Save
    local save = Save.new(player)
    self._map[player] = save
    task.defer(function()
        self._onRegistryInsertOrHeartbeat:Fire()
    end)
    self.SaveOpened:Fire(player)
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
    self.SaveClosed:Fire(function()
        return player, save
    end)
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