local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage.Shared.Red)

return Red.Function("DeleteKilnPottery", function(Player, stationId: string, slotIndex: number)
    -- Server validates and handles deleting pottery from kiln (without collecting)
end)
