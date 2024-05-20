--!strict
local Types = require(script.Parent.Types)
type Registry = Types.Registry
type Save = Types.Save
type DeepSelectionQuery = Types.DeepSelectionQuery
local ReplicationClient = {}

function ReplicationClient.Start(registry: Registry)
    local onLoadSelectionQueue: {[Player]: {
        query: {[string]: DeepSelectionQuery},
        values: {[string]: any}}
    } = {}
    local function addToAccumulatedQuery(
        currentQuery: {[string | number]: DeepSelectionQuery},
        currentValues: {[string | number]: any},
        queryToAdd: {[string | number]: DeepSelectionQuery},
        valuesToAdd: {[string | number]: any}
    )
        for childKey, childQueryToAdd in queryToAdd do
            local currentQueryAtKey = currentQuery[childKey]
            if typeof(currentQueryAtKey) == "boolean" then
                currentValues[childKey] = valuesToAdd[childKey]
                continue
            end
            if typeof(childQueryToAdd) == "boolean" then
                currentValues[childKey] = valuesToAdd[childKey]
                continue
            end
            -- Else, both queries are tables, so let's merge recursively
            local currentValuesAtKey = currentValues[childKey]
            if typeof(currentValuesAtKey) ~= "table" then
                currentValues[childKey] = valuesToAdd[childKey]
                continue
            end
            addToAccumulatedQuery(
                currentQueryAtKey,
                currentValuesAtKey,
                childQueryToAdd,
                valuesToAdd[childKey]
            )
        end
    end
    local function initializeSaveIdempotent(save: Save)
        if save._loaded or save._closed then
            return
        end
        save._loaded = true
        registry.SaveLoaded:Fire(save._player)
    end
    task.spawn(function()
        local replicateEvent =
            script.Parent.Parent.Parent:WaitForChild("ReplicateData", 60)
        if not replicateEvent then
            error("PlayerSave is not being used by the server! Please require"
                .. " PlayerSave somewhere in the server's code.")
        end
        if not replicateEvent:IsA("RemoteEvent") then
            error(`{replicateEvent:GetFullName()} is not a RemoteEvent!`)
        end

        replicateEvent.OnClientEvent:Connect(function(
            target: Player?,
            query: {[string]: DeepSelectionQuery},
            values: {[string]: any}
        )
            print("Replication event", target, query, values)
            if not target then
                return
            end
            local save = registry:Get(target)
            if not save then
                local existingQueue = onLoadSelectionQueue[target]
                if existingQueue then
                    -- Merge new values into existing queue
                    addToAccumulatedQuery(
                        existingQueue.query,
                        existingQueue.values,
                        query,
                        values
                    )
                else
                    onLoadSelectionQueue[target] = {
                        query = query,
                        values = values
                    }
                end
            else
                save:DeferListeners(function()
                    save._skipDataValidation = true
                    save:SetInSelection(query, values)
                    save._skipDataValidation = false
                    initializeSaveIdempotent(save)
                end)
            end
        end)
    end)
    registry.SaveOpened.Event:Connect(function(player: Player)
        local save = registry:Get(player)
        if not save then
            return
        end
        local queue = onLoadSelectionQueue[player]
        if queue then
            onLoadSelectionQueue[player] = nil
            save:DeferListeners(function()
                save._skipDataValidation = true
                save:SetInSelection(queue.query, queue.values)
                save._skipDataValidation = false
                initializeSaveIdempotent(save)
            end)
        end
    end)
    registry.SaveClosed.Event:Connect(function(closure: () -> (Player, Save))
        local player = closure()
        onLoadSelectionQueue[player] = nil
    end)
end

return ReplicationClient