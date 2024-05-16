--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local AutoSaving = {}

function AutoSaving.Start(
    registry: Types.Registry,
    saveScheduler: Types.SaveScheduler
)
    -- Stagger out auto saves requests based on player count
    local playerOrderedByJoinCount: {Player} = {}
    local nextPlayerCursor = 1
    Players.PlayerAdded:Connect(function(player)
        table.insert(playerOrderedByJoinCount, player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        local index = table.find(playerOrderedByJoinCount, player) :: number
        if nextPlayerCursor > index then
            nextPlayerCursor -= 1
        end
        table.remove(
            playerOrderedByJoinCount,
            index
        )
    end)
    local function processNextPlayer()
        local playerToProcess = playerOrderedByJoinCount[nextPlayerCursor]
        if not playerToProcess then
            nextPlayerCursor = 1
            playerToProcess = playerOrderedByJoinCount[nextPlayerCursor]
        end
        if not playerToProcess then
            return
        end
        
        nextPlayerCursor += 1
        local save = registry:Get(playerToProcess)
        if not save or not save:IsLoaded() or not save:IsSafeToSave() then
            return
        end
        saveScheduler:ScheduleSave(save, "AutoSave")
    end
    local lastAutoSaveClockTime = os.clock()
    RunService.Heartbeat:Connect(function()
        if not Config.AutoSaving.Enabled then
            return
        end
        local autoSaveInterval = Config.AutoSaving.Interval
            / math.max(1, #playerOrderedByJoinCount)
        local elapsedSinceLastAutosave = os.clock() - lastAutoSaveClockTime
        if elapsedSinceLastAutosave > autoSaveInterval then
            lastAutoSaveClockTime = os.clock()
            processNextPlayer()
        end
    end)
end

return AutoSaving