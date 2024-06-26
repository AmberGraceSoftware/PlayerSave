--!strict
--[[
    Wrapper class for player data store
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ListenerTree = require(script.Parent.ListenerTree)
local SerializeUtil = require(script.Parent.SerializeUtil)
export type KeyPath = SerializeUtil.KeyPath
export type KeyList = SerializeUtil.KeyList
export type DeepSelectionQuery = ListenerTree.DeepSelectionQuery

local Save = {}
Save.__index = {}

--[=[
    @class Save
]=]
function Save.new(player: Player)
    local self = {}
    self._safeToSave = true
    self._loaded = false
    self._closed = false
    self._isSaving = false
    self._skipDataValidation = false
    self._deferredListenerMap = nil :: {[(value: any) -> ()]: any}?
    self._deferredKeypathListenerMap = nil :: {
        [(keyList: KeyList) -> ()]: {string | number}
    }?
    self._player = player
    self._data = {} :: {[string]: any}
    self._listenerTree = ListenerTree.new()
    self._anyKeypathListeners = {}
        :: {[(keyList: KeyList) -> ()]: boolean}

    setmetatable(self, Save)
    return self
end

export type Save = typeof(Save.new(nil :: any))

function Save.__index.PlayerIsStillInGame(self: Save)
    return (self._player.Parent == Players)
        and not self._closed
end

--[=[
    @method Get
    @within Save
    @param keyPath KeyPath
    @param defaultValue: any?
    @return any
]=]
function Save.__index.Get(
    self: Save,
    keyPath: KeyPath,
    defaultValue: any?
): any
    local keyList = SerializeUtil.ParseKeypath(keyPath, 0)
    local finalValue: {[any]: any} = self._data
    for i = 1, #keyList - 1 do
        local nextValue = finalValue[keyList[i]]
        if typeof(nextValue) ~= "table" then
            return nil
        end
        finalValue = nextValue
    end
    local returnValue = finalValue[keyList[#keyList]]
    if returnValue == nil
    and defaultValue ~= nil then
        self:Set(keyPath, defaultValue)
        return defaultValue
    end
    return returnValue
end
function Save.__index.GetDeepCopy(
    self: Save,
    keyPath: KeyPath,
    defaultValue: any?
): any
    return SerializeUtil.DeepCopyValue(self:Get(keyPath, defaultValue))
end

local function getFromSelectionQuery(
    data: {[string | number]: any},
    query: DeepSelectionQuery
): any
    if typeof(query) == "table" then
        local result = {}
        for k, marker in query do
            local dataAtValue = data[k]
            if typeof(dataAtValue) == "table" then
                result[k] = getFromSelectionQuery(data[k], marker)
            else
                result[k] = if marker == true
                    then dataAtValue
                    else nil
            end
        end
        return result
    elseif query == true then
        return data
    else
        return nil
    end
end
function Save.__index.GetSelection(
    self: Save,
    query: DeepSelectionQuery
)
    return getFromSelectionQuery(self._data, query)
end

local function checkKey(
    parentTable: {[string | number]: any},
    key: unknown,
    debugKeyIndex: number?,
    debugKeyList: KeyList
)
    if typeof(key) == "number" then
        if key > #parentTable + 1
        or key < 1
        or key ~= key
        or key ~= math.floor(key) then
            error("Array indices must be sequential! Got key "
                .. tostring(key)
                .. " in path "
                .. SerializeUtil.KeyListToString(debugKeyList, debugKeyIndex)
                .. "; expected an integer index between 1 and "
                .. tostring(#parentTable + 1))
        end
    elseif typeof(key) == "string" then
        if not utf8.len(key) then
            error("Unexpected non-utf8 character for string key '"
                .. key
                .. " in path "
                .. SerializeUtil.KeyListToString(debugKeyList, debugKeyIndex))
        end
    else
        error("Unexpected key '"
            .. tostring(key)
            .. "' of type '"
            .. typeof(key)
            .. "; expected string or number!")
    end
end

--[=[
    @method Set
    @within Save
    @param keyPath KeyPath
    @param newValue any
]=]
function Save.__index.Set(
    self: Save,
    keyPath: KeyPath,
    newValue: any
)
    if RunService:IsServer() and not self._loaded then
        warn("Save:Set() was called on " .. self._player.Name .. "'s save "
            .. "before the save was loaded! This may have been a mistake, as "
            .. "the value written to the save will get overwritten once the "
            .. "player's data loads. traceback:\n"
            .. debug.traceback())
    end
    local keyList = SerializeUtil.ParseKeypath(keyPath, 1)

    -- Traverse parent tables and validate if our keys are strings or sequential
    -- numbers
    local rootTable: {[string | number]: any} = self._data
    for i = 1, #keyList - 1 do
        local key = keyList[i]
        checkKey(rootTable, key, i, keyList)
        local nextTable = rootTable[key]
        if nextTable == nil then
            nextTable = {}
            rootTable[key] = nextTable
        elseif typeof(nextTable) ~= "table" then
            error("Invalid attempt to write over keypath "
                .. SerializeUtil.KeyListToString(keyList, i)
                .. ":\nValue at key '"
                .. key
                .. "' is not a table! Got value "
                .. tostring(nextTable)
                .. " (of type "
                .. typeof(nextTable)
                .. ") instead!")
        end
        rootTable = nextTable
    end

    -- Validate the type of the value being assigned
    local isStorable, reason = SerializeUtil.ValueIsStorable(newValue)
    if not isStorable then
        if reason then
            error("Error when setting value "
                .. tostring(newValue)
                .. " at keypath '"
                .. SerializeUtil.KeyListToString(keyList)
                .. ":\n"
                .. reason)
        end
        return
    end

    local finalKey = keyList[#keyList]
    local oldValue = rootTable[finalKey]
    checkKey(rootTable, finalKey, #keyList, keyList)

    -- If the user called :Set() with the existing table as an argument, throw
    -- an error; this means the user is mutating data that they shouldn't be
    -- mutating.
    if oldValue == newValue then
        if typeof(oldValue) == "table" then
            error("Attempt to set a table to itself at keypath "
                .. SerializeUtil.KeyListToString(keyList)
                .. "!\nThis likely happened because data returend from "
                .. "save:Get() is being mutated somewhere.\n"
                .. "You should always use :GetDeepCopy() when mutating a value"
                .. "in a player's save! See:\n"
                .. "https://playersave.ambergracesoftware.com/docs/incorrect_api_usage#table-mutations")
        end
        return
    else
        -- Deep copy any newly-added tables to prevent mutation.
        newValue = SerializeUtil.DeepCopyValue(newValue)
    end

    -- If we're setting the newValue to nil, throw an error if this cuts
    -- an array in the middle
    if newValue == nil then
        if typeof((next(rootTable))) == "number" then
            if newValue < #rootTable then
                error("Attempt to set a value in the middle of an array to nil "
                    .. "(at keypath " .. SerializeUtil.KeyListToString(keyList)
                    .."); this would create a non-sequential array!")
            end
        end
    end

    local listenersHit = self._listenerTree:GetListenersHit(
        keyList,
        oldValue,
        newValue,
        self._data
    )
    local keyListListenersHit = {}
    for listener in self._anyKeypathListeners do
        table.insert(keyListListenersHit, listener)
    end

    rootTable[finalKey] = newValue
    if self._deferredListenerMap then
        for listener, value in listenersHit do
            self._deferredListenerMap[listener] = value
        end
    else
        for listener, value in listenersHit do
            listener(value)
        end
    end
    if self._deferredKeypathListenerMap then
        for _, listener in keyListListenersHit do
            self._deferredKeypathListenerMap[listener] = keyList
        end
    else
        for _, listener in keyListListenersHit do
            listener(keyList)
        end
    end
end

local function setDataInSelection(
    parentDataTable: {[string | number]: any},
    key: string | number,
    query: DeepSelectionQuery,
    newValue: any,
    outputKeyListsChanged: {KeyList},
    workingKeyList: KeyList,
    shouldValidateData: boolean
)
    -- Leaf values
    if typeof(query) == "boolean" then
        if query == false then
            return
        end
        if parentDataTable[key] == newValue then
            return
        end
        if shouldValidateData then
            local isStorable, reason = SerializeUtil.ValueIsStorable(newValue)
            if not isStorable then
                if reason then
                    error("Error when setting value "
                        .. tostring(newValue)
                        .. " at keypath '"
                        .. SerializeUtil.KeyListToString(workingKeyList)
                        .. ":\n"
                        .. reason)
                end
                return
            end
        end
        parentDataTable[key] = newValue
        table.insert(outputKeyListsChanged, table.clone(workingKeyList))
    else
        local nextDataTable = parentDataTable[key]
        if typeof(nextDataTable) ~= "table" then
            nextDataTable = {}
            parentDataTable[key] = nextDataTable
        end
        if typeof(newValue) ~= "table" then
            if parentDataTable[key] == newValue then
                return
            end
            if shouldValidateData then
                local isStorable, reason =
                    SerializeUtil.ValueIsStorable(newValue)
                if not isStorable then
                    if reason then
                        error("Error when setting value "
                            .. tostring(newValue)
                            .. " at keypath '"
                            .. SerializeUtil.KeyListToString(workingKeyList)
                            .. ":\n"
                            .. reason)
                    end
                    return
                end
            end
            parentDataTable[key] = newValue
            table.insert(outputKeyListsChanged, table.clone(workingKeyList))
            return
        end
        if shouldValidateData then
            for childKey in query do
                checkKey(nextDataTable, childKey, #workingKeyList + 1,
                    workingKeyList)
            end
        end
        for childKey, childQuery in query do
            table.insert(workingKeyList, childKey)
            setDataInSelection(
                nextDataTable,
                childKey,
                childQuery,
                newValue[childKey],
                outputKeyListsChanged,
                workingKeyList,
                shouldValidateData
            )
            table.remove(workingKeyList)
        end
    end
end
function Save.__index.SetInSelection(
    self: Save,
    query: DeepSelectionQuery,
    newValues: {[string]: any}
)
    if RunService:IsServer() and not self._loaded then
        warn("Save:SetInSelection() was called on " .. self._player.Name
            .. "'s save before the save was loaded! This may have been a "
            .. "mistake, as the value written to the save will get overwritten "
            .. "once the player's data loads. traceback:\n"
            .. debug.traceback())
    end
    local shouldValidateData = not self._skipDataValidation
    if shouldValidateData then
        local queryRootHasAllStringKeys = false
        if typeof(query) == "table" then
            queryRootHasAllStringKeys = true
            for key in query do
                if typeof(key) ~= "string" then
                    queryRootHasAllStringKeys = false
                    break
                end
            end
        end
        if not queryRootHasAllStringKeys then
            error("Invalid query: Root level of query must be table with string "
                .. "keys, got " .. typeof(query))
        end
        local valueRootHasAllStringKeys = false
        if typeof(newValues) ~= "table" then
            valueRootHasAllStringKeys = true
            for key in newValues do
                if typeof(key) ~= "string" then
                    valueRootHasAllStringKeys = false
                    break
                end
            end
        end
        if not valueRootHasAllStringKeys then
            error("Invalid newValues: Root level of newValues must be table with "
                .. "string keys, got " .. typeof(newValues))
        end
    end

    local keyListsChanged = {}
    for rootKey in newValues do
        setDataInSelection(
            self._data,
            rootKey,
            (query :: any)[rootKey],
            newValues[rootKey],
            keyListsChanged,
            {rootKey},
            shouldValidateData
        )
    end
    local listenersHit = self._listenerTree:GetListenersHitInSelection(
        query,
        self._data
    )
    local keyListListenersHit = {}
    for listener in self._anyKeypathListeners do
        table.insert(keyListListenersHit, listener)
    end

    if self._deferredListenerMap then
        for listener, value in listenersHit do
            self._deferredListenerMap[listener] = value
        end
    else
        for listener, value in listenersHit do
            listener(value)
        end
    end
    if self._deferredKeypathListenerMap then
        for _, keyList in keyListsChanged do
            for _, listener in keyListListenersHit do
                self._deferredKeypathListenerMap[listener] = keyList
            end
        end
    else
        for _, keyList in keyListsChanged do
            for _, listener in keyListListenersHit do
                listener(keyList)
            end
        end
    end
end

function Save.__index.Increment(
    self: Save,
    keyPath: KeyPath,
    amount: number?
): number
    local oldValue = self:Get(keyPath, 0)
    if typeof(oldValue) ~= "number" then
        local keyList = SerializeUtil.ParseKeypath(keyPath, 1)
        error("Attempt to increment non-number value at key path '"
            .. SerializeUtil.KeyListToString(keyList) .. "'")
    end
    local newValue = oldValue + (amount or 1)
    self:Set(keyPath, newValue)
    return newValue
end

function Save.__index.ListInsert(
    self: Save,
    keyPath: KeyPath,
    indexOrValue: any,
    value: any?
)
    local keyList = SerializeUtil.ParseKeypath(keyPath, 1)
    local existingList = self:Get(keyList)
    if typeof((next(existingList))) ~= "number" then
        error("Invalid attempt to call ListInsert:\n"
            .. "Value at keypath "
            .. SerializeUtil.KeyListToString(keyList)
            .. " has non-numeric keys!")
    end
    local indexToInsert
    local valueToInsert
    if value == nil then
        valueToInsert = indexOrValue
        indexToInsert = #existingList + 1
    else
        indexToInsert = indexOrValue
        valueToInsert = value
        if indexToInsert ~= indexToInsert
        or math.floor(indexToInsert) ~= indexToInsert
        or indexToInsert < 1
        or indexToInsert > #existingList + 1 then
            error("Invalid attempt to call ListInsert:\n"
                .. "Index "
                .. tostring(indexToInsert)
                .. " is not an integer, or is outside of range 1 <= i <= "
                .. tostring(#existingList + 1))
        end
    end
    if indexToInsert >= #existingList then
        local keyPathToAssign = table.clone(keyList)
        table.insert(keyPathToAssign, indexToInsert)
        self:Set(keyPathToAssign, valueToInsert)
    else
        local newList = table.clone(existingList)
        table.insert(newList, indexToInsert, valueToInsert)
        self:Set(keyPath, newList)
    end
end

function Save.__index.ListRemove(
    self: Save,
    keyPath: KeyPath,
    indexToRemove: number?
): any
    local keyList = SerializeUtil.ParseKeypath(keyPath, 1)
    local existingList = self:Get(keyList)
    if typeof((next(existingList))) ~= "number" then
        error("Invalid attempt to call ListInsert:\n"
            .. "Value at keypath "
            .. SerializeUtil.KeyListToString(keyList)
            .. " has non-numeric keys!")
    end
    local chosenIndex = indexToRemove or #existingList
    local valueToRemove = existingList[chosenIndex]
    if valueToRemove == nil then
        return nil
    end
    if chosenIndex == #existingList then
        local keyPathToAssign = table.clone(keyList)
        table.insert(keyPathToAssign, chosenIndex)
        self:Set(keyPathToAssign, nil)
    else
        local newList = table.clone(existingList)
        table.remove(newList, chosenIndex)
        self:Set(keyPath, newList)
    end
    return valueToRemove
end

function Save.__index.ListSwapRemove(
    self: Save,
    keyPath: KeyPath,
    indexToRemove: number
): any
    local keyList = SerializeUtil.ParseKeypath(keyPath, 1)
    local existingList = self:Get(keyList)
    if typeof((next(existingList))) ~= "number" then
        error("Invalid attempt to call ListInsert:\n"
            .. "Value at keypath "
            .. SerializeUtil.KeyListToString(keyList)
            .. " has non-numeric keys!")
    end
    local chosenIndex = indexToRemove or #existingList
    local valueToRemove = existingList[chosenIndex]
    if valueToRemove == nil then
        return nil
    end
    if chosenIndex == #existingList then
        local keyPathToAssign = table.clone(keyList)
        table.insert(keyPathToAssign, chosenIndex)
        self:Set(keyPathToAssign, nil)
    else
        local keyPathToAssignI = table.clone(keyList)
        table.insert(keyPathToAssignI, chosenIndex)
        local keyPathToAssignN = table.clone(keyPathToAssignI)
        keyPathToAssignN[#keyPathToAssignN] = #existingList
        self:Set(keyPathToAssignI, existingList[#existingList])
        self:Set(keyPathToAssignN, nil)
    end
    return valueToRemove
end

--[=[
    @method Subscribe
    @within Save
    @param keyPath KeyPath
    @param listener (value: any) -> ()
    @param immediatelyCallListener boolean?
    @return () -> ()
]=]
function Save.__index.Subscribe(
    self: Save,
    keyPath: KeyPath,
    listener: (value: any) -> (),
    immediatelyCallListener: boolean?
): (() -> ())
    local keyList = SerializeUtil.ParseKeypath(keyPath, 0)
    local unsubscribed = false
    local function spawnListener(value: any)
        if unsubscribed then
            return
        end
        task.spawn(listener, value)
    end
    self._listenerTree:Subscribe(keyList, spawnListener)
    if immediatelyCallListener then
        spawnListener(self:Get(keyPath))
    end
    return function()
        if unsubscribed then
            return
        end
        unsubscribed = true
        self._listenerTree:Unsubscribe(keyList, spawnListener)
    end
end

function Save.__index.SubscribeAnyKeypathWasSet(
    self: Save,
    listener: (keyList: KeyList) -> ()
)
    local unsubscribed = false
    local function spawnListener(keyList: KeyList)
        if unsubscribed then
            return
        end
        task.spawn(listener, keyList)
    end
    self._anyKeypathListeners[spawnListener] = true
    return function()
        if unsubscribed then
            return
        end
        unsubscribed = true
        self._anyKeypathListeners[spawnListener] = nil
    end
end

function Save.__index.IsSafeToSave(
    self: Save
)
    return self._safeToSave
end

function Save.__index.IsLoaded(
    self: Save
)
    return self._loaded and not self._closed
end

function Save.__index.IsSaving(
    self: Save
)
    return self._isSaving
end

function Save.__index.WaitUntilLoaded(
    self: Save,
    timeout: number?
): boolean
    local expires = if timeout then os.clock() + timeout else math.huge
    while os.clock() < expires
    and not self._closed
    and not self._loaded do
        RunService.Heartbeat:Wait()
    end
    return self:IsLoaded()
end

function Save.__index.DeferListeners(self: Save, scopeCallback: () -> ())
    if self._deferredListenerMap then
        scopeCallback()
        return
    end
    local valueListenerMap = {}
    local keyListListenerMap = {}
    self._deferredListenerMap = valueListenerMap
    self._deferredKeypathListenerMap = keyListListenerMap
    task.spawn(scopeCallback)
    self._deferredListenerMap = nil
    self._deferredKeypathListenerMap = nil
    for listener, value in valueListenerMap do
        listener(value)
    end
    for listener, keyList in keyListListenerMap do
        listener(keyList)
    end
end

return Save