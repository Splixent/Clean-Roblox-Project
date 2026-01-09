local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Replication = require(Client.Replication)


local StationHandler = {
    clientStations = {}
}

local PlotStations = Client.PlotStations
local StationHandlers = {
	ClayPatch = require(PlotStations.ClayPatch),
	PottersWheel = require(PlotStations.PottersWheel),
	Kiln = require(PlotStations.Kiln),
	GlazeTable = require(PlotStations.GlazeTable),
	CoolingTable = require(PlotStations.CoolingTable),
}


function StationHandler:SetupStation(ownerPlayer: Player, stationData: any)
    local stationInstance = StationHandlers[stationData.stationType].new(ownerPlayer, stationData.model)
    stationInstance:SetupVisuals()
end

function StationHandler:RemoveStation(ownerPlayer: Player, stationData: any)
    local stationInstance = self.clientStations[ownerPlayer][stationData.stationType]
    if stationInstance then
        stationInstance:Destroy()
        self.clientStations[ownerPlayer][stationData.stationType] = nil
    end
end

task.spawn(function()
    repeat task.wait() until Replication.PotteryStations

    Replication.PotteryStations:OnSet({"activeStations"}, function(newActiveStations, oldActiveStations)
        for plrInstance, stationData in pairs (newActiveStations) do
            if not oldActiveStations or not oldActiveStations[plrInstance] then
                StationHandler:SetupStation(plrInstance, stationData)
            end
        end

        if oldActiveStations then
            for plrInstance, stationData in pairs (oldActiveStations) do
                if not newActiveStations[plrInstance] then
                    StationHandler:RemoveStation(plrInstance, stationData)
                end
            end
        end
    end)

    for plrInstance, stationData in pairs (Replication.PotteryStations.Data.activeStations) do
        StationHandler:SetupStation(plrInstance, stationData)        
    end

end)

return StationHandler