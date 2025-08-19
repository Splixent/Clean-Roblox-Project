local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)
local Guard = require(Shared.Red.Guard)

return Red.Event("RequestHit", function(targetCharacter, timeStamp)
    return Guard.Character(targetCharacter), Guard.Number(timeStamp)
end)