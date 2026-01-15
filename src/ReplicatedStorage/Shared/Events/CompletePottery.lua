local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)

-- Used to complete pottery after minigame and receive the finished item
-- stationId: the station ID where pottery was completed
-- styleKey: the pottery style that was created
return Red.Function("CompletePottery", function(stationId: string, styleKey: string)
    return stationId, styleKey
end, function(result)
    return result
end)
