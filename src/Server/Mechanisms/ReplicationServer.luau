--!strict
local Types = require(script.Parent.Types)

local ReplicationServer = {}

function ReplicationServer.Start(registry: Types.Registry)
    local replicateEvent = Instance.new("BindableEvent")
    replicateEvent.Name = "ReplicateData"
    replicateEvent.Parent = script.Parent.Parent.Parent

    registry.SaveLoaded.Event:Connect(function(player)
        task.defer(function()
            local save = registry:Get(player)
            if not save or save._closed then
                return
            end
            -- Begin initial replication to own client for visible keys
            -- Begin initial data replication to other clients for visible keys
        end)
    end)

    --[[
        We want replication to send the minimal amount of information every
        heartbeat to the client, minimizing observer updates.

        -- Architecture overview:
        - Data structure to use here: "DeepSelectionQuery"
            - type DeepSelectionQuery = {[string | number]: boolean | DeepSelectionQuery}
            - e.g. { Coins = true, { Units = { [1] = true, [5] = true } } }
        - Add public method to save `save:GetSelection(query: DeepSelectionQuery)`
        - Add public method `save:SubscribeAnyKeypathWasSet()`, which emits the
            keyList for every change that happens in the data
        - Use a closure variable in ReplicationServer called `playerToNextQuery`
            - This contains a cumulative query based on Set calls since the last
                replication frame.
            - When any keypath changes (via public subscribe method), add any
                new keys to the cumulative query. Overwrite deep tables with
                `true`, but not the other way around.
        - On heartbeat -> task.defer -> task.defer, flush the cumulated query.

        - Add public method save:DeferListeners, which allows an inner function
            to make multiple set calls before listeners get fired. This will be
            used by the replication receiver on the client to ensure listeners
            fire in sync, once all of the data has been updated together.
        - Add method ListenerTree:GetListenersHitInSelection() which allows \
            listener updates to be collated.
        - Add public method save:SubscribeMultipleKeypaths() which collates
            updates from multiple keypaths at once in a deferred thread.
    ]]
end

return ReplicationServer
