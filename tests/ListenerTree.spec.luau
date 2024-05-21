--!strict

return function()
    local ListenerTree = require(game.ReplicatedStorage.Packages.PlayerSave.ListenerTree)
    local tree = ListenerTree.new()
    it("should initialize with no listeners", function()
        expect((next(tree:GetListenersHit({}, false, true, {})))).to.equal(nil)
    end)

    local function subscribeAndTrackCalls(keyList: {string | number})
        local newValues: {any} = {}
        local closure = function(value)
            table.insert(newValues, value)
        end
        tree:Subscribe(keyList, closure)
        local tracker = {
            expectCallCount = function(expect, callCount: number)
                expect(#newValues).to.equal(callCount)
            end,
            expectValues = function(expect, valueList: {any})
                expect(#newValues).to.equal(#valueList)
                for i = 1, #valueList do
                    expect(newValues[i]).to.equal(valueList[i])
                end
            end,
            clearValues = function()
                newValues = {}
            end,
            unsubscribe = function()
                tree:Unsubscribe(keyList, closure)
            end,
        }
        return tracker
    end
    local function createMockSave()
        local mockData = {}
        return {
            Set = function(keyList: {string | number}, newValue: any)
                local parentTable = {}
                for i = 1, #keyList - 1 do
                    local key = keyList[i]
                    parentTable[key] = parentTable[key] or {}
                    parentTable = parentTable[key]
                end
                local oldValue = parentTable[keyList[#keyList]]
                parentTable[keyList[#keyList]] = newValue
                for listener, value in tree:GetListenersHit(
                    keyList, oldValue, newValue, mockData
                ) do
                    listener(value)
                end
            end,
        }
    end
    describe("Subscribe", function()
        it("should subscribe/unsubscribe top-level keypaths", function()
            local trackerCoins = subscribeAndTrackCalls({"Coins"})
            local trackerName = subscribeAndTrackCalls({"Name"})
            local mockSave = createMockSave()

            mockSave.Set({"Coins"}, 10)

            trackerCoins.expectCallCount(expect, 1)
            trackerCoins.expectValues(expect, {10})
            trackerName.expectCallCount(expect, 0)
            trackerCoins.clearValues()

            mockSave.Set({"Name"}, "Bob")

            trackerCoins.expectCallCount(expect, 0)
            trackerName.expectCallCount(expect, 1)
            trackerName.expectValues(expect, {"Bob"})
            trackerName.clearValues()

            trackerCoins.unsubscribe()
            trackerName.unsubscribe()

            mockSave.Set({"Name"}, "Bob")

            trackerCoins.expectCallCount(expect, 0)
            trackerName.expectCallCount(expect, 0)
        end)
    end)
end