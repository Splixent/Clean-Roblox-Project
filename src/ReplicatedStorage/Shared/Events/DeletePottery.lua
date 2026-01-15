local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage.Shared.Red)

return Red.Function("DeletePottery", function(Player, stationId: string, slotIndex: number)
    -- Server validates and handles deleting pottery from cooling table (without collecting)
end)
