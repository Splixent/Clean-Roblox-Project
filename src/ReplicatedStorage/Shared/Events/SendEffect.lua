local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)
local Guard = require(Shared.Red.Guard)

return Red.Event("SendEffect", function(effectName)
    return Guard.String(effectName)
end)