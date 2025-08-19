local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local CombatManager = require(Server.CombatManager)
local BufferUtils = require(Shared.BetterReplication.Lib.BufferUtils)

local writeFromClient = BufferUtils.writeFromClientSimplified

local AITest = {
    AICharacters = game.Workspace:WaitForChild("AICharacters")
}

function AITest:InitializeAICharacter(character)
    RunService.Stepped:Connect(function()
        if character and character:FindFirstChild("HumanoidRootPart") then
            CombatManager.fromAI:Fire(character, writeFromClient(os.clock(), character.HumanoidRootPart.CFrame))
        end
    end)
end

task.spawn(function()

    for _, character in ipairs(AITest.AICharacters:GetChildren()) do
        print(character)
        AITest:InitializeAICharacter(character)
    end
end)

return AITest