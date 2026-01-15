local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)

-- Used to update pottery shaping state for visual replication
-- isShaping: true when minigame is active (spinning), false when stopped
-- isComplete: true when minigame finished successfully
return Red.Function("UpdatePotteryShaping", function(stationId: string, isShaping: boolean, isComplete: boolean?)
    return stationId, isShaping, isComplete
end, function(result)
    return result
end)
