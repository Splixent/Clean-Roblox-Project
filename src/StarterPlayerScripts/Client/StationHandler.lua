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


function StationHandler:SetupStation(stationKey: string, stationData: any)
    local ownerUserId = stationKey:match("^(%-?%d+)_(.+)$")
    
    local ownerPlayer = Players:GetPlayerByUserId(tonumber(ownerUserId))
    if not ownerPlayer then
        warn("StationHandler: Could not find player with UserId", stationKey)
        return
    end
    
    print(stationData.stationType)
    local stationInstance = StationHandlers[stationData.stationType].new(ownerPlayer, stationData.model)
    stationInstance:SetupVisuals()
    if not self.clientStations[ownerUserId] then
        self.clientStations[ownerUserId] = {}
    end
    self.clientStations[ownerUserId][stationData.stationType] = stationInstance
end

function StationHandler:RemoveStation(stationKey: string, stationData: any)
    local ownerUserId = stationKey:match("^(%-?%d+)_(.+)$")
    local stationInstance = self.clientStations[ownerUserId] and self.clientStations[ownerUserId][stationData.stationType]
    if stationInstance then
        stationInstance:Destroy()
        self.clientStations[ownerUserId][stationData.stationType] = nil
    end
end

task.spawn(function()
    repeat task.wait() until Replication.PotteryStations

    -- Set up initial stations first, BEFORE setting up the OnSet listener
    for ownerUserId, stationData in pairs(Replication.PotteryStations.Data.activeStations) do
        StationHandler:SetupStation(ownerUserId, stationData)        
    end

    -- Now listen for changes (new stations added or removed after initial load)
    Replication.PotteryStations:OnSet({"activeStations"}, function(newActiveStations, oldActiveStations)
        -- Only process if we have old data to compare (skip initial fire)
        if not oldActiveStations then return end
        
        for stationKey, stationData in pairs(newActiveStations) do
            if not oldActiveStations[stationKey] then
                StationHandler:SetupStation(stationKey, stationData)
            end
        end

        for stationKey, stationData in pairs(oldActiveStations) do
            if not newActiveStations[stationKey] then
                StationHandler:RemoveStation(stationKey, stationData)
            end
        end
    end)

end)

return StationHandler