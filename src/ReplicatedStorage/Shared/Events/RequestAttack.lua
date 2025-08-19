local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)
local Guard = require(Shared.Red.Guard)

return Red.Event("RequestAttack", function(timeStamp, attackData)
    return Guard.Number(timeStamp), Guard.Any(attackData)
end)