--!strict
local Players = game:GetService("Players")

return function()
    local Registry = require(game.ReplicatedStorage.Packages.PlayerSave.Registry)
    it("Constructs, starts, and stops", function()
        local registry = Registry.new()
        registry:StartHeartbeatLoop()
        local conn = registry._heartbeatConn :: RBXScriptConnection
        expect(conn).to.be.ok()
        expect(conn.Connected).to.equal(true)
        registry:StopHeartbeatLoop()
        expect(registry._heartbeatConn).to.equal(nil)
        expect(conn.Connected).to.equal(false)
    end)
    local registry = Registry.new()
    local function createMockPlayer(): Player
        return {
            Parent = Players,
        } :: any
    end
    local player = createMockPlayer()
    it("Opens and closes a save", function()
        local save = registry:OpenSave(player)
        expect(save).to.be.ok()
        expect(registry._map[player]).to.equal(save)
        expect(save._player).to.equal(player)
        expect(save._closed).to.equal(false)
        registry:CloseSave(player)
        expect(save._closed).to.equal(true)
        expect(registry._map[player]).to.equal(nil)
    end)

    -- Not testable on "Deferred" signal behavior.
    -- it("WaitFor blocks thread until deferred event or heartbeat", function()
    --     local save: Registry.Save
    --     local thread = coroutine.create(function()
    --         print(1)
    --         save = registry:WaitFor(player) :: Registry.Save
    --         print(2)
    --     end)
    --     coroutine.resume(thread)
    --     expect(save).to.equal(nil)
    --     expect(coroutine.status(thread)).to.equal("suspended")
    --     local openedSave = registry:OpenSave(player)
    --     print("Firing event")
    --     registry._onRegistryInsertOrHeartbeat:Fire()
    --     print("Event fired")
    --     expect(save).to.be.ok()
    --     expect(save).to.equal(openedSave)
    --     expect(save._player).to.equal(player)
    --     expect(save._closed).to.equal(false)
    --     expect(coroutine.status(thread)).to.equal("dead")
    --     registry:CloseSave(player)
    --     expect(save._closed).to.equal(true)
    -- end)

    it("Gets a loaded save only once the save has been marked as loaded", function()
        expect(registry:Get(player)).to.equal(nil)
        local save = registry:OpenSave(player)
        expect(registry:Get(player)).to.equal(save)
        expect(#registry:GetLoadedSaves()).to.equal(0)
        expect(#registry:GetOpenSaves()).to.equal(1)
        expect(registry:GetOpenSaves()[1]).to.equal(save)
        save._loaded = true
        expect(#registry:GetOpenSaves()).to.equal(1)
        expect(registry:GetOpenSaves()[1]).to.equal(save)
        expect(#registry:GetLoadedSaves()).to.equal(1)
        expect(registry:GetLoadedSaves()[1]).to.equal(save)
        registry:CloseSave(player)
        expect(registry:Get(player)).to.equal(nil)
        expect(#registry:GetLoadedSaves()).to.equal(0)
        expect(#registry:GetOpenSaves()).to.equal(0)
    end)
end