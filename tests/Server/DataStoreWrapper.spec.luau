--!strict

return function()
    local DataStoreWrapper = require(game.ReplicatedStorage.Packages.PlayerSave.Server.DataStoreWrapper)
    local wrapper = DataStoreWrapper.new(nil, true)
    local mockPlayer: Player = {UserId = -12345} :: any
    it("allows mock GetAsync and SetAsync requests to be performed", function()
        local isYielding = true
        local getSuccess, initDataOrErr
        local setSuccess, versionOrErr
        task.spawn(function()
            getSuccess, initDataOrErr = wrapper:GetAsync(mockPlayer)
            setSuccess, versionOrErr = wrapper:SetAsync(mockPlayer, {})
            isYielding = false
        end)
        expect(isYielding).to.equal(false)
        expect(getSuccess).to.equal(true)
        expect(initDataOrErr).to.equal(nil)
        expect(setSuccess).to.equal(true)
        expect(versionOrErr).to.equal("usingMockDataStore")
    end)
end
