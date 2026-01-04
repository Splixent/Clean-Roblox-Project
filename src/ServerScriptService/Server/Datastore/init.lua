--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local ProfileService = require(Server.ProfileService)
local Constants = require(Server.Constants)
local DataObject = require(script.DataObject)
local PlayerEntityManager = require(Server.PlayerEntityManager)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)

local Datastore = {
    Globalize = {}
}
local Profiles = {}

Datastore.profileStore = ProfileService.GetProfileStore(
    "alpha_0",
    ScriptUtils:DeepCopy(Constants.profileSettings.profileTemplate)
).Mock

function Datastore:PlayerAdded(player: Player)
    local profile = Datastore.profileStore:LoadProfileAsync("dataKey"..player.UserId)
    if profile ~= nil then
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        profile:ListenToRelease(function()
            Profiles[player] = nil
            player:Kick()
        end)

        if player:IsDescendantOf(Players) == true then
            Profiles[player] = profile

            Datastore:LoadData(player)
            Datastore:GlobalizeData(player)
            Datastore:SaveData(player)

            local playerEntity = PlayerEntityManager.new(player)

            if playerEntity ~= nil then

            end
        else
            profile:Release()
        end
    else
        player:Kick()
    end
end

function Datastore:GlobalizeData(player: Player)
    for updateIndex, update in ipairs (Profiles[player].GlobalUpdates:GetActiveUpdates()) do
        local updateId = update[1]
        local updateData = update[2]

        Datastore.Globalize[updateData.updateType](updateData, player, updateIndex)
        Profiles[player].GlobalUpdates:LockActiveUpdate(updateId)
    end

    for _, lockedUpdate in ipairs (Profiles[player].GlobalUpdates:GetLockedUpdates()) do
        Profiles[player].GlobalUpdates:ClearLockedUpdate(lockedUpdate[1])
    end

    Profiles[player].GlobalUpdates:ListenToNewActiveUpdate(function(updateId, updateData)
        Datastore.Globalize[updateData.updateType](updateData, player)
        Profiles[player].GlobalUpdates:LockActiveUpdate(updateId)
    end)

    Profiles[player].GlobalUpdates:ListenToNewLockedUpdate(function(updateId, updateData)
        Profiles[player].GlobalUpdates:ClearLockedUpdate(updateId)
    end)
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
        Profiles[player]:Save()
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
        profile:Release()
    end
end)

task.spawn(function()

end)

return Datastore