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
        return SerializeUtil.DeserializeStorable(storedValue.SaveData)
    else
        return storedValue
    end
end

function SaveFormat.SerializeSaveData(params: {
    data: {[string]: any},
    saveType: string,
    libraryVersion: string
})
    return {
        PlayerSaveLibraryVersion = params.libraryVersion,
        SaveType = params.saveType,
        SaveData = SerializeUtil.SerializeToStorable(params.data),
        TimestampUTC = os.time(),
        PlaceVersion = game.PlaceVersion,
        PlaceId = game.PlaceId,
        GameId = game.GameId,
    }
end

return SaveFormat