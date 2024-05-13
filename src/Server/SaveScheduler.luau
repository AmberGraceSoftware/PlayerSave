--!strict
--[[
    Handles save retries, DataStore request budget, and save queueing on the
    server
]]
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Config)
local DataStoreWrapper = require(script.Parent.DataStoreWrapper)
local Save = require(script.Parent.Parent.Save)
local SaveFormat = require(script.Parent.SaveFormat)
export type Save = Save.Save
export type DataStoreWrapper = DataStoreWrapper.DataStoreWrapper

export type SaveType = "ExitSave" | "AutoSave" | "ForceSave"
    | "SessionBeginSave" | "TradeSave"

local SaveScheduler = {}
SaveScheduler.__index = {}

function SaveScheduler.new(
    dataStoreWrapper: DataStoreWrapper,
    libraryVersion: string
)
    local self = {}
    self._dataStoreWrapper = dataStoreWrapper
    self._libraryVersion = libraryVersion
    self._queuedSaves = {} :: {[Save]: {
        saveType: SaveType,
        retryCount: number,
        scheduledClockTime: number?,
    }}
    self._heartbeatConnection = nil :: RBXScriptConnection?
    setmetatable(self, SaveScheduler)
    return self
end

export type SaveScheduler = typeof(SaveScheduler.new(nil :: any, ""))

function SaveScheduler.__index.ProcessQueue(self: SaveScheduler)
    -- Prioritize exit saves over all other save types
    local savesToProcessInReverseOrder: {Save} = {}
    local now = os.clock()
    for save, info in self._queuedSaves do
        if info.scheduledClockTime > now then
            continue
        end
        if info.saveType == "ExitSave" then
            continue
        end
        table.insert(savesToProcessInReverseOrder, save)
    end
    for save, info in self._queuedSaves do
        if info.scheduledClockTime > now then
            continue
        end
        if info.saveType ~= "ExitSave" then
            table.insert(savesToProcessInReverseOrder, save)
        end
    end

    while #savesToProcessInReverseOrder > 0
    and DataStoreService:GetRequestBudgetForRequestType(
        Enum.DataStoreRequestType.SetIncrementAsync
    ) > 0 do
        local top = table.remove(savesToProcessInReverseOrder) :: Save
        local lastQueueInfo = self._queuedSaves[top]
        self._queuedSaves[top] = nil
        local serialized
        local serializeSuccess, serializeErr = pcall(function()
            serialized = SaveFormat.SerializeSaveData({
                data = top._data,
                libraryVersion = self._libraryVersion
            })
        end)
        if serializeSuccess then
            warn("Data could not be saved! Serialization error: "
                .. serializeErr)
            -- Don't call API or schedule a save retry if serializeation fails.
            continue
        end
        local saveSuccess, versionOrErr = self._dataStoreWrapper:SetAsync(
            top._player,
            serialized
        )
        if not saveSuccess then
            warn("Data saving error: ", versionOrErr)

            -- Queue up a retry on failure
            if Config.SaveRetries.Enabled
            and lastQueueInfo.retryCount <= Config.SaveRetries.Max then
                self._queuedSaves[top] = {
                    saveType = lastQueueInfo.saveType,
                    retryCount = lastQueueInfo.retryCount + 1,
                    scheduledClockTime = os.clock() + math.clamp(
                        Config.SaveRetries.Interval,
                        1, 60
                    )
                }
            end
        end
    end
end

function SaveScheduler.__index.Start(self: SaveScheduler)
    self._heartbeatConnection = RunService.Heartbeat:Connect(function()
        self:ProcessQueue()
    end)
end

function SaveScheduler.__index.Stop(self: SaveScheduler)
    if self._heartbeatConnection then
        self._heartbeatConnection:Disconnect()
        self._heartbeatConnection = nil
    end
end

function SaveScheduler.__index.ScheduleSave(
    self: SaveScheduler,
    save: Save,
    saveType: SaveType
)
    -- Don't schedule any additional saves over an exit save
    local queuedSaveInfo = self._queuedSaves[save]
    if queuedSaveInfo and queuedSaveInfo.saveType == "ExitSave" then
        return
    end

    -- Inherit scheduled clocked time if a save retry is already being attempted
    -- and this is NOT an exit save.
    local scheduledClockTime: number?
    if queuedSaveInfo
    and queuedSaveInfo.scheduledClockTime
    and saveType ~= "ExitSave" then
        scheduledClockTime = queuedSaveInfo.scheduledClockTime
    end
    self._queuedSaves[save] = {
        saveType = saveType,
        retryCount = 0,
        scheduledClockTime = scheduledClockTime,
    }
    self:ProcessQueue()
end

return SaveScheduler