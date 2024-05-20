--!strict
local Players = game:GetService("Players")
local Types = require(script.Parent.Types)
type Registry = Types.Registry

local RegistryClient = {}

function RegistryClient.Start(registry: Registry)
    local function onPlayer(player: Player)
        registry:OpenSave(player)
    end
    for _, player in Players:GetPlayers() do
        onPlayer(player)
    end
    game.Players.PlayerAdded:Connect(onPlayer)
    game.Players.PlayerRemoving:Connect(function(player)
        task.defer(function()
            registry:CloseSave(player)
        end)
    end)
end

return RegistryClient