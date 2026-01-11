local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Commands = script.Parent.Commands
local Types = script.Parent.Types
local Hooks = script.Parent.Hooks

if RunService:IsServer() then
    local Cmdr = require(script.Parent)
	Cmdr:RegisterDefaultCommands()
    Cmdr:RegisterTypesIn(Types)
    Cmdr:RegisterCommandsIn(Commands)
    Cmdr:RegisterHooksIn(Hooks)
elseif RunService:IsClient() then
    print("?")
	require(ReplicatedStorage:WaitForChild("CmdrClient")):SetActivationKeys({ Enum.KeyCode.Semicolon })
end

return {}