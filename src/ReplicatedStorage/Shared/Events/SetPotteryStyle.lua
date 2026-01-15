local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)

-- Used to set or clear the pottery style selection on a PottersWheel
-- styleKey: the selected pottery style key, or nil to clear
return Red.Function("SetPotteryStyle", function(stationId: string, styleKey: string?, requiredClay: number?)
    return stationId, styleKey, requiredClay
end, function(result)
    return result
end)
