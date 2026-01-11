local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)

return Red.Function("InsertClay", function(stationId: string, styleKey: string)
    return stationId, styleKey
end, function(result)
    return result
end)
