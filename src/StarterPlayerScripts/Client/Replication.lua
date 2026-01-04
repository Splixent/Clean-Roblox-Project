local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = Players.LocalPlayer.PlayerScripts.Client
local Shared = ReplicatedStorage.Shared

local ReplicaClient = require(Client.ReplicaClient)

local Player = Players.LocalPlayer

local Replication = {}

function Replication:GetInfo(info : string, details: boolean?)
	if details then
		return self[info] 
	elseif self[info] ~= nil then
		return self[info].Data 
	else
		return nil
	end
end

ReplicaClient.OnAny(function(Replica)
	if Replica.Token == "states" .. Player.UserId then
		Replication["States"] = Replica
	elseif Replica.Token == "dataKey" .. Player.UserId then
		Replication["Data"] = Replica
	else
		Replication[Replica.Token] = Replica
	end
end)

function Replication.LoadedChanged(Handler)
	Replication.States:OnSet({"loaded"}, Handler)
end

while game:IsLoaded() == false do
	task.wait()
end

ReplicaClient.RequestData()

return Replication