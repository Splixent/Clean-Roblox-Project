--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local ProfileStore = require(Server.ProfileStore)
local Constants = require(Server.Constants)
local DataObject = require(script.DataObject)
local PlayerEntityManager = require(Server.PlayerEntityManager)
local ScriptUtils = require(Shared.ScriptUtils)

local Datastore = {
    Globalize = {}
}
local Profiles = {}

Datastore.profileStore = ProfileStore.New(
    "alpha_0",
    ScriptUtils:DeepCopy(Constants.profileSettings.profileTemplate)
).Mock

function Datastore:PlayerAdded(player: Player)
    local profile = Datastore.profileStore:StartSessionAsync("dataKey"..player.UserId)
    if profile ~= nil then
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        profile.OnSessionEnd:Connect(function()
            Profiles[player] = nil
            player:Kick()
        end)

        if player:IsDescendantOf(Players) == true then
            Profiles[player] = profile

            Datastore:LoadData(player)
            Datastore:SaveData(player)

            local playerEntity = PlayerEntityManager.new(player)

            if playerEntity ~= nil then

            end
        else
            profile:EndSession()
        end
    else
        player:Kick()
    end
end

function Datastore:LoadData(player: Player)
    if Profiles[player].Data.loginInfo.totalLogins < 1 then

    end

    Profiles[player].Data.loginInfo.totalLogins += 1
    Profiles[player].Data.loginInfo.lastLogin = os.time()


    Datastore[player].DataObject = DataObject.new(player, true, Profiles[player].Data)
    Datastore[player].PlayerEntity = PlayerEntityManager.new(player, true).Replica

    PlayerEntityManager.SetupCharacter(player)

    Datastore[player].PlayerEntity:Set({"loaded"}, true)
end

function Datastore:SaveData(player: Player)
    Datastore[player].DataObject.Replica:OnChange(function()
        Profiles[player].Data = Datastore[player].DataObject.Replica.Data
    end)
end

for _, player in ipairs (Players:GetPlayers()) do
    task.spawn(function()
        Datastore[player] = {}
        Datastore:PlayerAdded(player)
    end)
end

Players.PlayerAdded:Connect(function(player: Player)
    Datastore[player] = {}
    Datastore:PlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player: Player?)
    assert(player, "player is nil")

    local profile = Profiles[player]
    DataObject[player] = nil

    if profile then
        profile.Data.loginInfo.totalPlaytime += (os.time() -  profile.Data.loginInfo.lastLogin)
    end

    if profile ~= nil then
        profile:EndSession()
    end
end)

return Datastore
