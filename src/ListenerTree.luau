--!strict
--[[
    Data structure to simplify the process of subscribing to any key path
]]

local SerializeUtil = require(script.Parent.SerializeUtil)
type KeyList = SerializeUtil.KeyList

export type Listener = (value: any) -> ()
type ChildMap = {[any]: Node}
type ListenerSet = {[Listener]: boolean}
type Node = {
    children: ChildMap?,
    listenerSet: ListenerSet?,
}
export type DeepSelectionQuery = boolean
    | {[string | number]: DeepSelectionQuery}

local ListenerTree = {}
ListenerTree.__index = {}

function ListenerTree.new()
    local self = {}
    self._root = {} :: Node

    setmetatable(self, ListenerTree)
    return self
end

export type ListenerTree = typeof(ListenerTree.new())

function ListenerTree.__index.Subscribe(
    self: ListenerTree,
    keyList: {string | number},
    listener: Listener
)
    local node = self._root
    for key in keyList do
        local children
        if node.children then
            children = node.children
        else
            children = {}
            node.children = children
        end
        if children[key] then
            node = children[key]
        else
            local nextNode: Node = {}
            children[key] = nextNode
            node = nextNode
        end
    end
    local listenerSet
    if node.listenerSet then
        listenerSet = node.listenerSet
    else
        listenerSet = {}
        node.listenerSet = listenerSet
    end
    listenerSet[listener] = true
end

function ListenerTree.__index.Unsubscribe(
    self: ListenerTree,
    keyList: {string | number},
    listener: Listener
)
    -- Get the chain of nodes hit until the final listener, and return early
    -- if this listener was not found along that chain.
    local currentNode = self._root
    local nodesHit = {currentNode}
    for key in keyList do
        local children = currentNode.children
        if not children then
            return
        end
        local nextNode = children[key]
        if not nextNode then
            return
        end
        currentNode = nextNode
        table.insert(nodesHit, nextNode)
    end
    local finalListenerSet = currentNode.listenerSet
    if not finalListenerSet then
        return
    end
    if not finalListenerSet[listener] then
        return
    end
    finalListenerSet[listener] = nil

    -- If there are no listeners or children at the final node, remove the
    -- final node. Do the same for each node hit
    if next(finalListenerSet) then
        return
    end
    currentNode.listenerSet = nil
    if currentNode.children then
        return
    end
    local lastChildMap = nodesHit[#nodesHit - 1].children :: ChildMap
    lastChildMap[keyList[#keyList]] = nil
    if next(lastChildMap) then
        return
    end

    -- Continue removing nodes down the chain if no listeners/children are
    -- defined
    for i = #nodesHit, 2, -1 do
        local node = nodesHit[i]
        if next(node.children :: {[any]: Node}) then
            return
        end
        if node.listenerSet then
            return
        end
        local prevNode = nodesHit[i - 1]
        local key = keyList[i - 1]
        local prevChildren = prevNode.children :: ChildMap
        prevChildren[key] = nil
        if next(prevChildren) then
            return
        end
    end
end

local function addAllChildListeners(
    outputMap: {[Listener]: any},
    node: Node,
    newValue: any
)
    if not node.children then
        return
    end
    for childKey, childNode in node.children do
        local childValue = if typeof(newValue) == "table"
            then newValue[childKey]
            else newValue
        if childNode.listenerSet then
            for listener in childNode.listenerSet do
                outputMap[listener] = childValue
            end
        end
        addAllChildListeners(outputMap, childNode, childValue)
    end
end
local function addChildListenersIfDifferent(
    outputMap: {[Listener]: any},
    node: Node,
    oldValue: any,
    newValue: any
)
    if not node.children then
        return
    end

    local bothValuesAreTable = (typeof(oldValue) == "table")
        and (typeof(newValue) == "table")

    -- If we encountered a non-table value, add all/none descendants without
    -- performing a diff.
    if not bothValuesAreTable then
        if newValue ~= oldValue then
            addAllChildListeners(outputMap, node, newValue)
        end
        return
    end
    
    -- Else, add all listeners for this ancestor, and diff children recursively
    for key, childNode in node.children do
        local childValue = if typeof(newValue) == "table"
            then newValue[key]
            else nil
        if childNode.listenerSet then
            for listener in childNode.listenerSet do
                outputMap[listener] = childValue
            end
        end
        local nextOldValue = if bothValuesAreTable
            then oldValue[key]
            else true
        local nextNewValue = if bothValuesAreTable
            then newValue[key]
            else false
        addChildListenersIfDifferent(outputMap, childNode, nextOldValue,
            nextNewValue)
    end
end
function ListenerTree.__index.GetListenersHit(
    self: ListenerTree,
    keyList: KeyList,
    oldValue: any,
    newValue: any,
    allData: {[string]: any}
): {[Listener]: any}
    if oldValue == newValue and typeof(oldValue) ~= "table" then
        return {}
    end
    
    -- Get all ancestor listeners hit up to this key
    local listenersHit: {[Listener]: any} = {}
    local currentNode = self._root
    local currentData: {[string | number]: any} = allData
    for _, key in keyList do
        currentData = if typeof(currentData) == "table"
            then currentData[key]
            else nil
        if currentNode.listenerSet then
            for listener in currentNode.listenerSet do
                listenersHit[listener] = currentData
            end
        end
        if currentNode.children then
            currentNode = currentNode.children[key]
            if not currentNode then
                return listenersHit
            end
        else
            return listenersHit
        end
    end

    -- Add all listeners at this exact value
    local finalListeners = currentNode.listenerSet
    if finalListeners then
        for listener in finalListeners do
            listenersHit[listener] = newValue
        end
    end

    -- If there are child listeners, diff the old and new values, and only call
    -- listeners for values that have changed with this update, plus any parent
    -- listeners to the changed final values
    local finalChildren = currentNode.children
    if not finalChildren then
        return listenersHit
    end
    addChildListenersIfDifferent(listenersHit, currentNode, oldValue, newValue)
    return listenersHit
end

local function addListenersInDeepQuery(
    outputMap: {[Listener]: any},
    query: DeepSelectionQuery,
    node: Node,
    currentData: any
)
    if query == false then
        return
    end

    -- Add ancestor listeners + listeners at each leaf of the query
    if node.listenerSet then
        for listener in node.listenerSet do
            outputMap[listener] = currentData
        end
    end
    if typeof(query) == "boolean" then
        addAllChildListeners(outputMap, node, currentData)
    else
        if not node.children then
            return
        end
        for key, subQuery in query do
            local childNode = node.children[key]
            if not childNode then
                continue
            end
            local childValue = if typeof(currentData) == "table"
                then currentData[key]
                else nil
            addListenersInDeepQuery(outputMap, subQuery, childNode, childValue)
        end
    end
end
function ListenerTree.__index.GetListenersHitInSelection(
    self: ListenerTree,
    query: DeepSelectionQuery,
    currentData: {[string]: any}
): {[Listener]: any}
    local listenersHit: {[Listener]: any} = {}
    addListenersInDeepQuery(listenersHit, query, self._root, currentData)
    return listenersHit
end

function ListenerTree.__index.FireAllListeners(
    self: ListenerTree,
    currentDataTree: any
)
    local callbacksToFire = {}
    local function addRoot(node: Node, value: any)
        if node.listenerSet then
            for listener in node.listenerSet do
                callbacksToFire[listener] = value
            end
        end
        if node.children then
            for key, child in node.children do
                addRoot(child, if typeof(value) == "table"
                    then value[key]
                    else nil)
            end
        end
    end
    addRoot(self._root, currentDataTree)

    for listener, value in callbacksToFire do
        task.spawn(listener, value)
    end
end

return ListenerTree