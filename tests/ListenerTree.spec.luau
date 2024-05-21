--!strict

return function()
    local ListenerTree = require(game.ReplicatedStorage.Packages.PlayerSave.ListenerTree)
    local SerializeUtil = require(game.ReplicatedStorage.Packages.PlayerSave.SerializeUtil)
    local tree = ListenerTree.new()
    it("should initialize with no listeners", function()
        expect((next(tree:GetListenersHit({}, false, true, {})))).to.equal(nil)
    end)

    local function expectDeepEqual(
        expect: any,
        expectation: any,
        actualValue: any
    )
        if typeof(actualValue) ~= typeof(expectation)
        or typeof(actualValue) ~= "table" then
            expect(actualValue).to.equal(expectation)
        else
            for k, v in actualValue do
                expectDeepEqual(expect, expectation[k], v)
            end
            for k, v in expectation do
                if actualValue[k] == nil then
                    expectDeepEqual(expect, v, nil)
                end
            end
        end
    end

    local function subscribeAndTrackCalls(keyList: {string | number})
        local newValues: {any} = {}
        local closure = function(value)
            if typeof(value) == "table" then
                value = SerializeUtil.DeepCopyValue(value)
            end
            table.insert(newValues, value)
        end
        tree:Subscribe(keyList, closure)
        local tracker = {
            expectCallCount = function(expect: any, callCount: number)
                expect(#newValues).to.equal(callCount)
            end,
            expectValues = function(expect: any, valueList: {any})
                expect(#newValues).to.equal(#valueList)
                for i = 1, #valueList do
                    expectDeepEqual(expect, newValues[i], valueList[i])
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
                local parentTable = mockData
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
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)

        it("should subscribe/unsubscribe nested keypaths", function()
            local trackerCurrencies = subscribeAndTrackCalls({"Currencies"})
            local trackerCoins = subscribeAndTrackCalls({"Currencies", "Coins"})
            local trackerShards =
                subscribeAndTrackCalls({"Currencies", "Shards"})
            local mockSave = createMockSave()

            print(tree._root)

            mockSave.Set({"Currencies", "Coins"}, 10)
            mockSave.Set({"Currencies", "Shards"}, 20)

            trackerCurrencies.expectCallCount(expect, 2)
            trackerCurrencies.expectValues(expect,{
                {Coins = 10},
                {Coins = 10, Shards = 20}
            })
            trackerCoins.expectCallCount(expect, 1)
            trackerCoins.expectValues(expect, {10})
            trackerShards.expectCallCount(expect, 1)
            trackerShards.expectValues(expect, {20})
            trackerCurrencies.clearValues()
            trackerCoins.clearValues()
            trackerShards.clearValues()

            trackerShards.unsubscribe()
            trackerCurrencies.unsubscribe()
            mockSave.Set({"Currencies", "Shards"}, 30)
            mockSave.Set({"Currencies", "Coins"}, 40)

            trackerCurrencies.expectCallCount(expect, 0)
            trackerCoins.expectCallCount(expect, 1)
            trackerCoins.expectValues(expect, {40})
            trackerShards.expectCallCount(expect, 0)
            trackerCoins.clearValues()

            trackerCoins.unsubscribe()
            mockSave.Set({"Currencies", "Coins"}, 50)
            mockSave.Set({"Currencies", "Shards"}, 60)

            trackerCurrencies.expectCallCount(expect, 0)
            trackerCoins.expectCallCount(expect, 0)
            trackerShards.expectCallCount(expect, 0)
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)
    end)
end