--!strict
--[[
    Utility for parsing key paths
]]

export type KeyList = {string | number}
export type KeyPath = string | {string | number}

local SerializeUtil = {}

function SerializeUtil.DeepCopy(value: any)
    if typeof(value) == "table" then
        local newTable = table.clone(value)
        for k,v in newTable do
            if typeof(v) == "table" then
                
            end
        end
    else

    end
end

function SerializeUtil.KeyListToString(keyList: KeyList): string
    local output: {string} = {}
    for _, key in keyList do
        if typeof(key) == "string" then

        else
            table.insert(output, "[")
            table.insert(output, tostring(key))
            table.insert(output, "]")
        end
    end
    return table.concat(output)
end

function SerializeUtil.ValidateKeyList(keyList: KeyList, minSize: number)
    local expectedI = 1
    for i, entry in keyList do
        local entryType = typeof(entry)
        if entryType ~= "string"
        and entryType ~= "number" then
            error("Invalid KeyPath: expected type string | number for "
                .. "element " .. tostring(i) .. " of keyPath, got "
                .. entryType)
        end
        if i ~= expectedI then
            error("Invalid KeyPath: expected all keys to be numbers; got "
                .. "key '" .. tostring(i) .. "'")
        end
    end
    if #keyList < minSize then
        error("Invalid KeyPath: must contain at least "
            .. tostring(minSize) .. " key, got 0")
    end
    if typeof(keyList[1] ~= "string") then
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

local INVALID_TYPES: {[string]: true} = {
    Instance = true,
}
function SerializeUtil.ValueIsStorable(value: unknown): (boolean, string?)
    if INVALID_TYPES[typeof(value)] then
        return false, ""
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

return SerializeUtil