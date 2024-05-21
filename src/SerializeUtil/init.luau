--!strict
--[[
    Utility for parsing key paths
]]
local StorableUtil = require(script.StorableUtil)

export type KeyList = {string | number}
export type KeyPath = string | {string | number}

local SerializeUtil = {}

local function deepCopyTable(table: {[any]: any})
    local newTable = table.clone(table)
    for key, value in newTable do
        if typeof(value) == "table" then
            newTable[key] = deepCopyTable(value)
        end
    end
    return newTable
end
function SerializeUtil.DeepCopyValue<T>(value: T): T
    if typeof(value) == "table" then
        return deepCopyTable(value) :: any
    end
    return value
end

function SerializeUtil.KeyListToString(keyList: KeyList, lastI: number?): string
    local output: {string} = {}
    for i, key in keyList do
        if i == 1 then
            table.insert(output, tostring(key))
        elseif typeof(key) == "string" then
            if key:match("[^a-zA-Z0-9_]")
            or key:sub(1, 1):match("[^a-zA-Z]") then
                local open, close
                if not key:find('"') then
                    open = '"'
                    close = '"'
                elseif not key:find("'") then
                    open = "'"
                    close = "'"
                else
                    local repCount = 0
                    repeat 
                        local rep = string.rep("=", repCount)
                        if not key:find("]" .. rep .. "]", nil, true) then
                            open = "]" .. rep .. "]"
                            close = "[" .. rep .. "["
                            break
                        end
                        repCount += 1
                    until repCount == 5
                    open = '"'
                    close = '"'
                end
                table.insert(output, "[")
                table.insert(output, open)
                table.insert(output, tostring(key))
                table.insert(output, close)
                table.insert(output, "]")
            else
                table.insert(output, ".")
                table.insert(output, key)
            end
        else
            table.insert(output, "[")
            table.insert(output, tostring(key))
            table.insert(output, "]")
        end
        if i == lastI then
            break
        end
    end
    return table.concat(output)
end

function SerializeUtil.ValidateKeyList(keyList: KeyList, minSize: number)
    for i, entry in keyList do
        local entryType = typeof(entry)
        if entryType ~= "string"
        and entryType ~= "number" then
            error("Invalid KeyPath: expected type string | number for "
                .. "element " .. tostring(i) .. " of keyPath, got "
                .. entryType)
        end
    end
    if #keyList < minSize then
        error("Invalid KeyPath: must contain at least "
            .. tostring(minSize) .. " key, got 0")
    end
    if typeof(keyList[1]) ~= "string" then
        error("Invalid KeyPath: first key must be of type string, got "
            .. typeof(keyList[1]))
    end
end

function SerializeUtil.ParseKeypath(keyPath: KeyPath, minSize: number): KeyList
    local keyPathType = typeof(keyPath)
    if keyPathType == "string" then
        local keyStrs: {string | number} = (keyPath :: string):split(".")
        for i, key in keyStrs do
            keyStrs[i] = tonumber(key) or key
        end
        SerializeUtil.ValidateKeyList(keyStrs, minSize)
        return keyStrs
    elseif keyPathType == "table" then
        SerializeUtil.ValidateKeyList(keyPath :: KeyList, minSize)
        return keyPath :: KeyList
    else
        error("Invalid KeyPath: expected type string | {string | number}, got "
            .. keyPathType)
    end
end

function SerializeUtil.ValueIsStorable(value: unknown): (boolean, string?)
    if not StorableUtil.ValueIsStorableShallow(value) then
        return false, "'" .. typeof(value) .. " is not a type that can be "
            .. "stored in a DataStore!"
    end
    if typeof(value) == "table" then
        local expectedNextSequentialIndex: number? = nil
        local encounteredStringKey = false
        for k, v in value :: {[any]: any} do
            if typeof(k) == "string" then
                encounteredStringKey = true
                if expectedNextSequentialIndex then
                    return false, "Cannot have both string and number keys. "
                        .. "Encountered key "
                        .. tostring(k)
                        .. "; expected "
                        .. tostring(expectedNextSequentialIndex)
                end
            elseif encounteredStringKey then
                return false, "Cannot have both string and number keys. "
                    .. "Encountered key "
                    .. tostring(k)
                    .. "; expected a string"
            elseif expectedNextSequentialIndex then
                if k ~= expectedNextSequentialIndex then
                    return false, "Lists must have sequential indices. "
                        .. "Encountered key "
                        .. tostring(k)
                        .. "; expected "
                        .. tostring(expectedNextSequentialIndex)
                end
                expectedNextSequentialIndex += 1
            elseif typeof(k) ~= "number" then
                return false, "Keys must be strings or sequential numbers"
            elseif k ~= 1 then
                return false, "Lists must have sequential indices. "
                    .. "Encountered key "
                    .. tostring(k)
                    .. "; expected 1"
            else
                expectedNextSequentialIndex = 2
            end
            local valueValid, reason = SerializeUtil.ValueIsStorable(v)
            if not valueValid then
                return false, reason
            end
        end
    end
    return true
end

function SerializeUtil.DeserializeStorable(storable: any)
    return StorableUtil.Deserialize(storable)
end

function SerializeUtil.SerializeToStorable(data: any)
    return StorableUtil.Serialize(data)
end

return SerializeUtil