local Shared = game:GetService("ReplicatedStorage").Shared

local Red = require(Shared.Red)
local Guard = require(Shared.Red.Guard)

return Red.Event("RecieveEffect", function(...)
    return ...
end)