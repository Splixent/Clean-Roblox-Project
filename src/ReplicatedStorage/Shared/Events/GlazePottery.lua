local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)

-- Used to apply glaze to a pottery item
-- potteryItemKey: the unique key of the pottery item (e.g., "bowl_1")
-- glazeData: table containing color, pattern, and finish selections
return Red.Function("GlazePottery", function(potteryItemKey: string, glazeData: {color: string?, pattern: string?, finish: string?})
    return potteryItemKey, glazeData
end, function(result)
    return result
end)
