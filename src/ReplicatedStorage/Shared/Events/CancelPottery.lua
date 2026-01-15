local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)

-- Used to cancel pottery creation and return inserted clay to the player's inventory
-- stationId: the station ID being canceled
return Red.Function("CancelPottery", function(stationId: string)
    return stationId
end, function(result)
    return result
end)
