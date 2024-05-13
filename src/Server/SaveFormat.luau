--!strict
--[[
    Defines the top-level save format.
]]
local SerializeUtil = require(script.Parent.Parent.SerializeUtil)

local SaveFormat = {}

function SaveFormat.IsSavedValueInPlayerSaveFormat(saveData: any)
    return typeof(saveData) == "table"
        and saveData.PlayerSaveLibraryVersion
        and saveData.SaveData
end

function SaveFormat.DeserializeStoredValue(storedValue: any)
    if SaveFormat.IsSavedValueInPlayerSaveFormat(storedValue) then
        return SerializeUtil.DeserializeStoreable(storedValue)
    else
        return storedValue
    end
end

function SaveFormat.SerializeSaveData(params: {
    data: {[string]: any},
    libraryVersion: string
})
    return {
        PlayerSaveLibraryVersion = params.libraryVersion,
        SaveData = SerializeUtil.SerializeToStoreable(params.data),
    }
end

return SaveFormat