--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Parent.Config)
local Types = require(script.Parent.Types)
type DeepSelectionQuery = Types.DeepSelectionQuery
type Save = Types.Save
type KeyList = Types.KeyList

local ReplicationServer = {}

function ReplicationServer.Start(registry: Types.Registry)
    local replicateEvent = Instance.new("RemoteEvent")
    replicateEvent.Name = "ReplicateData"
    replicateEvent.Parent = script.Parent.Parent.Parent

    -- Helper cache: Accumulate a deep sleection query for every KeyList that
    -- was changed this frame, filtered by visibility config, and flush each
    -- deferred heartbeat.
    local playerToSelfAccumulatedQuery = {}
        :: {[Player]: {[string | number]: DeepSelectionQuery}}
    local playerToOthersAccumulatedQuery = {}
        :: {[Player]: {[string | number]: DeepSelectionQuery}}
    local function addToAccumulatedQuery(
        accumulatedQuery: {[string | number]: DeepSelectionQuery},
        keyList: KeyList,
        visibilityConfig: DeepSelectionQuery,
        cursor: number?
    )
        local index = cursor or 1
        local nextKey = keyList[index]
        local nextQueryMarker = accumulatedQuery[nextKey]
        local nextAllowed
        if typeof(visibilityConfig) == "table" then
            -- Map {true} config to allow all keys in array to replicate as well
            local visibilityKey = if typeof(nextKey) == "number"
                then next(visibilityConfig) :: any
                else nextKey
            nextAllowed = visibilityConfig[visibilityKey]
        else
            nextAllowed = visibilityConfig
        end
        if not nextAllowed then
            return
        end
        if typeof(nextQueryMarker) == "table" then
            if cursor == #keyList then
                accumulatedQuery[nextKey] = true
            else
                addToAccumulatedQuery(nextQueryMarker, keyList, nextAllowed,
                    index + 1)
            end
        elseif nextQueryMarker == nil then
            if cursor == #keyList then
                accumulatedQuery[nextKey] = true
            else
                local nextAccumulatedQuery = {}
                accumulatedQuery[nextKey] = nextAccumulatedQuery
                addToAccumulatedQuery(nextAccumulatedQuery, keyList,
                    nextAllowed, index + 1)
            end
        end
    end
    local function getInitialValuesFromVisibilityConfig(
        save: Save,
        visibilityConfig: DeepSelectionQuery
    ): ({[string]: DeepSelectionQuery}, {[string]: any})
        if typeof(visibilityConfig) == "boolean" then
            if visibilityConfig then
                local allKeysQuery = {}
                for k in save._data do
                    allKeysQuery[k] = true
                end
                return allKeysQuery, save._data
            end
            return {}, {}
        else
            local allKeysQuery = {}
            for k, childConfig in visibilityConfig do
                if typeof(k) == "number" then
                    continue
                end
                allKeysQuery[k] = childConfig
            end
            return allKeysQuery, save:GetSelection(allKeysQuery)
        end
    end

    -- Listen to Save events
    local unsubscribesByPlayer: {[Player]: {() -> ()}}  = {}
    registry.SaveLoaded.Event:Connect(function(player)
        task.defer(function()
            local save = registry:Get(player)
            if not save or save._closed then
                return
            end

            -- Send initial data replication payload
            replicateEvent:FireClient(
                player,
                player,
                getInitialValuesFromVisibilityConfig(
                    save,
                    Config.DataVisibility.VisibleToOwnClient
                )
            )
            local othersInitQuery, othersInitValues = 
                getInitialValuesFromVisibilityConfig(
                    save,
                    Config.DataVisibility.VisibleToAllClients
                )
            for _, other in Players:GetPlayers() do
                if other == player then
                    continue
                end
                replicateEvent:FireClient(
                    other,
                    player,
                    othersInitQuery,
                    othersInitValues
                )
            end
            

            -- Subscribe to keypath changes and build accumulated query that is
            -- flushed each frame
            local unsubscribes = {}
            unsubscribesByPlayer[player] = unsubscribes
            playerToSelfAccumulatedQuery[player] = {}
            playerToOthersAccumulatedQuery[player] = {}


            table.insert(unsubscribes,
                save:SubscribeAnyKeypathWasSet(function(keyList)
                    addToAccumulatedQuery(
                        playerToSelfAccumulatedQuery[player],
                        keyList,
                        Config.DataVisibility.VisibleToOwnClient
                    )
                    addToAccumulatedQuery(
                        playerToOthersAccumulatedQuery[player],
                        keyList,
                        Config.DataVisibility.VisibleToAllClients
                    )
                end)
            )
        end)
    end)
    registry.SaveClosed.Event:Connect(function(closure: () -> (Player, Save))
        local player = closure()
        local unsubscribes = unsubscribesByPlayer[player]
        if unsubscribes then
            unsubscribesByPlayer[player] = nil
            for _, unsubscribe in unsubscribes do
                unsubscribe()
            end
        end
        playerToSelfAccumulatedQuery[player] = nil
        playerToOthersAccumulatedQuery[player] = nil
    end)

    -- Flush accumulated query each heartbeat (deferred)
    RunService.Heartbeat:Connect(function()
        task.defer(task.defer, function()
            for player, accumulatedQuery in playerToSelfAccumulatedQuery do
                if not next(accumulatedQuery) then
                    continue
                end
                local save = registry:Get(player)
                if not save or save._closed then
                    continue
                end
                local selection = save:GetSelection(accumulatedQuery)
                if not selection then
                    continue
                end
                replicateEvent:FireClient(
                    player,
                    player,
                    accumulatedQuery,
                    selection
                )
                playerToSelfAccumulatedQuery[player] = {}
            end
            for player, accumulatedQuery in playerToOthersAccumulatedQuery do
                if not next(accumulatedQuery) then
                    continue
                end
                local save = registry:Get(player)
                if not save or save._closed then
                    continue
                end
                local selection = save:GetSelection(accumulatedQuery)
                if not selection then
                    continue
                end
                for _, other in Players:GetPlayers() do
                    if other == player then
                        continue
                    end
                    replicateEvent:FireClient(
                        other,
                        player,
                        accumulatedQuery,
                        selection
                    )
                end
                playerToOthersAccumulatedQuery[player] = {}
            end
        end)
    end)
end

return ReplicationServer
