--!strict
--[[
    Wrapper class for player data store
]]

local RunService = game:GetService("RunService")
local ListenerTree = require(script.Parent.ListenerTree)
local SerializeUtil = require(script.Parent.SerializeUtil)
export type KeyPath = SerializeUtil.KeyPath

local Save = {}
Save.__index = {}

function Save.new()
    local self = {}
    self._safeToSave = true
    self._loaded = false
    self._closed = false
    self._data = {}
    self._listenerTree = ListenerTree.new()

    setmetatable(self, Save)
    table.freeze(self)
    return self
end

export type Save = typeof(Save.new())

function Save.__index.PlayerIsStillInGame(self: Save)
    return self._loaded and not self._closed
end

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

function Save.__index.Set(
    self: Save,
    keyPath: KeyPath,
    newValue: any
)
    local keyList = SerializeUtil.ParseKeypath(keyPath, 1)
    local function checkKey(parentTable: {[string | number]: any}, key: unknown)
        if typeof(key) == "number" then
            if key > #parentTable + 1
            or key < 1
            or key ~= key
            or key ~= math.floor(key) then
                error("Array indices must be sequential! Got key "
                    .. tostring(key)
                    .. " in path "
                    .. SerializeUtil.KeyListToString(keyList)
                    .. "; expected an integer index between 1 and "
                    .. tostring(#parentTable + 1))
            end
        elseif typeof(key) == "string" then
            if not utf8.len(key) then
                error("Unexpected non-utf8 character for string key '"
                    .. key
                    .. " in path "
                    .. SerializeUtil.KeyListToString(keyList))
            end
        else
            error("Unexpected key '"
                .. tostring(key)
                .. "' of type '"
                .. typeof(key)
                .. "; expected string or number!")
        end
    end

    -- Traverse parent tables and validate if our keys are strings or sequential
    -- numbers
    local rootTable = self._data
    for i = 1, #keyList - 1 do
        local key = keyList[i]
        checkKey(rootTable, key)
        local nextTable = rootTable[key]
        if nextTable == nil then
            nextTable = {}
            rootTable[key] = nextTable
        elseif typeof(nextTable) ~= "table" then
            error("Invalid attempt to write over keypath "
                .. SerializeUtil.KeyListToString(keyList)
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
    local listenersHit = self._listenerTree:GetListenersHit(
        keyList,
        oldValue,
        newValue
    )
    rootTable[finalKey] = newValue
    for _, listener in listenersHit do
        listener(newValue)
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

return Save