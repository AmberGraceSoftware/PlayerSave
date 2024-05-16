--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local Config = require(script.Parent.Parent.Parent.Config)

local BindToClose = {}

function BindToClose.Start(
    registry: Types.Registry,
    saveScheduler: Types.SaveScheduler
)
    local function stillProcessingSaves()
        if #registry:GetOpenSaves() > 0 then
            return true
        end
        if not saveScheduler:ProcessQueueIsEmpty() then
            return true
        end
        if saveScheduler:IsStillProcessingSave() then
            if not RunService:IsStudio()
            or Config.BindToClose.WaitForSetAsyncResponsesWhileInStudio then
                return true
            end
        end
        return false
    end
    game:BindToClose(function()
        local bindToCloseStart = os.clock()
        local function didTimeOut()
            return RunService:IsStudio() and (
                (os.clock() - bindToCloseStart)
                > Config.BindToClose.TimeoutWhileInStudio
            )
        end
        
        -- Manually process saves until the queue is empty
        saveScheduler:StopProcessLoop()
        saveScheduler:ProcessQueue()
        while stillProcessingSaves() do
            RunService.Heartbeat:Wait()
            saveScheduler:ProcessQueue()
            if didTimeOut() then
                break
            end
        end
    end)
end

return BindToClose