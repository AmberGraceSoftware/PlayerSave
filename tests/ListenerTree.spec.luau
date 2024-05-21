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
            if value == nil then
                value = ListenerTree.NIL_SYMBOL
            end
            table.insert(newValues, value)
        end
        tree:Subscribe(keyList, closure)
        local tracker = {
            expectNewValues = function(expect: any, ...: any)
                local n = select("#", ...)
                local valueList = {...}
                expect(#newValues).to.equal(n)
                for i = 1, n do
                    expectDeepEqual(
                        expect,
                        valueList[i],
                        if newValues[i] == ListenerTree.NIL_SYMBOL
                            then nil
                            else newValues[i]
                    )
                end
                newValues = {}
            end,
            expectNoNewValues = function(expect: any)
                expect(#newValues).to.equal(0)
                newValues = {}
            end,
            unsubscribe = function()
                tree:Unsubscribe(keyList, closure)
                newValues = {}
            end,
        }
        return tracker
    end
    local function createMockSave()
        local mockData: {[string]: any} = {}
        return {
            Set = function(keyList: {string | number}, newValue: any)
                local parentTable: {[string | number]: any} = mockData
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
            Get = function()
                return mockData
            end,
        }
    end
    describe("Subscribe", function()
        it("should subscribe/unsubscribe top-level keypaths", function()
            local trackerCoins = subscribeAndTrackCalls({"Coins"})
            local trackerName = subscribeAndTrackCalls({"Name"})
            local mockSave = createMockSave()

            mockSave.Set({"Coins"}, 10)

            trackerCoins.expectNewValues(expect, 10)
            trackerName.expectNoNewValues(expect)

            mockSave.Set({"Name"}, "Bob")

            trackerCoins.expectNoNewValues(expect)
            trackerName.expectNewValues(expect, "Bob")

            trackerCoins.unsubscribe()
            trackerName.unsubscribe()

            mockSave.Set({"Name"}, "Bob")

            trackerCoins.expectNoNewValues(expect)
            trackerName.expectNoNewValues(expect)
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)

        it("should subscribe an ancestor to descendant changes", function()
            local trackerCurrencies = subscribeAndTrackCalls({"Currencies"})
            local trackerCoins = subscribeAndTrackCalls({"Currencies", "Coins"})
            local trackerShards =
                subscribeAndTrackCalls({"Currencies", "Shards"})
            local mockSave = createMockSave()

            mockSave.Set({"Currencies", "Coins"}, 10)
            mockSave.Set({"Currencies", "Shards"}, 20)

            trackerCurrencies.expectNewValues(expect,
                {Coins = 10},
                {Coins = 10, Shards = 20}
            )
            trackerCoins.expectNewValues(expect, 10)
            trackerShards.expectNewValues(expect, 20)

            trackerShards.unsubscribe()
            trackerCurrencies.unsubscribe()
            mockSave.Set({"Currencies", "Shards"}, 30)
            mockSave.Set({"Currencies", "Coins"}, 40)

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNewValues(expect, 40)
            trackerShards.expectNoNewValues(expect)

            trackerCoins.unsubscribe()
            mockSave.Set({"Currencies", "Coins"}, 50)
            mockSave.Set({"Currencies", "Shards"}, 60)

            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)

        it("should subscribe a descendant to ancestor changes", function()
            local trackerCurrencies = subscribeAndTrackCalls({"Currencies"})
            local trackerCoins = subscribeAndTrackCalls({"Currencies", "Coins"})
            local trackerShards =
                subscribeAndTrackCalls({"Currencies", "Shards"})
            local mockSave = createMockSave()

            mockSave.Set({"Currencies"}, {Coins = 10})
            mockSave.Set({"Currencies"}, {Coins = 20, Shards = 20})
            
            trackerCurrencies.expectNewValues(expect,
                {Coins = 10},
                {Coins = 20, Shards = 20}
            )
            trackerCoins.expectNewValues(expect, 10, 20)
            trackerShards.expectNewValues(expect, 20)

            trackerShards.unsubscribe()
            trackerCurrencies.unsubscribe()
            mockSave.Set({"Currencies"}, {Shards = 30, Coins = 40})

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNewValues(expect, 40)
            trackerShards.expectNoNewValues(expect)

            trackerCoins.unsubscribe()
            mockSave.Set({"Currencies"}, {Shards = 50, Coins = 60})

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNoNewValues(expect)
            trackerShards.expectNoNewValues(expect)
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)

        it("should guard against top-level redundant changes", function()
            local trackerCoins = subscribeAndTrackCalls({"Currencies", "Coins"})
            local trackerName = subscribeAndTrackCalls({"Name"})
            local mockSave = createMockSave()

            mockSave.Set({"Currencies", "Coins"}, 10)
            mockSave.Set({"Name"}, "Joey")

            trackerCoins.expectNewValues(expect, 10)
            trackerName.expectNewValues(expect, "Joey")

            mockSave.Set({"Currencies", "Coins"}, 10)
            mockSave.Set({"Name"}, "Joey")

            trackerCoins.expectNoNewValues(expect)
            trackerName.expectNoNewValues(expect)
            
            trackerCoins.unsubscribe()
            trackerName.unsubscribe()

            mockSave.Set({"Currencies", "Coins"}, 10)
            mockSave.Set({"Name"}, "Joey")

            trackerCoins.expectNoNewValues(expect)
            trackerName.expectNoNewValues(expect)
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)

        it("should guard against nested redundant changes", function()
            local trackerCurrencies = subscribeAndTrackCalls({"Currencies"})
            local trackerCoins = subscribeAndTrackCalls({"Currencies", "Coins"})
            local trackerShards =
                subscribeAndTrackCalls({"Currencies", "Shards"})
            local mockSave = createMockSave()

            mockSave.Set({"Currencies"}, {Coins = 10})
            mockSave.Set({"Currencies"}, {Coins = 10, Shards = 20})
            
            trackerCurrencies.expectNewValues(expect,
                {Coins = 10},
                {Coins = 10, Shards = 20}
            )
            trackerCoins.expectNewValues(expect, 10)
            trackerShards.expectNewValues(expect, 20)

            mockSave.Set({"Currencies", "Coins"}, 10)
            mockSave.Set({"Currencies", "Shards"}, 20)

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNoNewValues(expect)
            trackerShards.expectNoNewValues(expect)

            trackerCurrencies.unsubscribe()
            mockSave.Set({"Currencies"}, {Coins = 10, Shards = 20})

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNoNewValues(expect)
            trackerShards.expectNoNewValues(expect)
            
            trackerCoins.unsubscribe()
            trackerShards.unsubscribe()
            mockSave.Set({"Currencies"}, {Coins = 10, Shards = 20})

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNoNewValues(expect)
            trackerShards.expectNoNewValues(expect)
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)
    end)

    describe("FireAllListeners", function()
        it("Should fire all listeners for redundant and non-redundant changes", function()
            local trackerCurrencies = subscribeAndTrackCalls({"Currencies"})
            local trackerCoins = subscribeAndTrackCalls({"Currencies", "Coins"})
            local trackerNonexistent = subscribeAndTrackCalls({"Nonexistent"})
            local trackerShards =
                subscribeAndTrackCalls({"Currencies", "Shards"})
            local mockSave = createMockSave()

            mockSave.Set({"Currencies"}, {Coins = 10})
            mockSave.Set({"Currencies"}, {Coins = 10, Shards = 20})
            
            trackerCurrencies.expectNewValues(expect,
                {Coins = 10},
                {Coins = 10, Shards = 20}
            )
            trackerCoins.expectNewValues(expect, 10)
            trackerShards.expectNewValues(expect, 20)
            trackerNonexistent.expectNoNewValues(expect)
            
            tree:FireAllListeners({Currencies = {Coins = 20, Shards = 20}})

            trackerCurrencies.expectNewValues(expect, {Coins = 20, Shards = 20})
            trackerCoins.expectNewValues(expect, 20)
            trackerShards.expectNewValues(expect, 20)
            trackerNonexistent.expectNewValues(expect, nil)

            trackerCurrencies.unsubscribe()
            trackerCoins.unsubscribe()
            trackerShards.unsubscribe()
            trackerNonexistent.unsubscribe()
            tree:FireAllListeners({Currencies = {Coins = 30, Shards = 20}})

            trackerCurrencies.expectNoNewValues(expect)
            trackerCoins.expectNoNewValues(expect)
            trackerShards.expectNoNewValues(expect)
            trackerNonexistent.expectNoNewValues(expect)
            expect(tree._root.listenerSet).to.equal(nil)
            expect(tree._root.children).to.equal(nil)
        end)
    end)
end