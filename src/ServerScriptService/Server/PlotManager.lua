local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local StationManager = require(Server.StationManager)

local Assets = ReplicatedStorage.Assets

local PlotManager = {
    currentPlots = game.Workspace.Plots:GetChildren(),
}

function PlotManager:LoadPlot(player, freePlot)
    local playerData = DataObject.new(player, true)
    local plotTheme = Assets.PlotThemes[playerData.Replica.Data.plot]:Clone()
    plotTheme.Parent = freePlot
    plotTheme.Name = "MainPlot"
    plotTheme:PivotTo(freePlot.PrimaryPart.CFrame)

    player.RespawnLocation = plotTheme.SpawnLocation

    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        character:PivotTo(plotTheme.SpawnLocation.CFrame + Vector3.new(0, 5, 0))
    end)

    freePlot.DefaultGround.Transparency = 1
    freePlot.DefaultGround.CanCollide = false

    local stationData = playerData.Replica.Data.potteryStations
    for _, stationLocation in ipairs (plotTheme.StationLocations:GetChildren()) do
        local potteryStation = Assets.PotteryStations[`{stationData[stationLocation.Name].level}_{stationLocation.Name}`]:Clone()
        potteryStation.Parent = plotTheme.StationLocations
		potteryStation:PivotTo(stationLocation.CFrame)
		stationLocation:Destroy()

		potteryStation:SetAttribute("Level", stationData[stationLocation.Name].level)
        potteryStation:SetAttribute("StationType", stationLocation.Name)
        potteryStation:SetAttribute("Owner", player.UserId)

        StationManager:SetupStation(player, potteryStation)
    end

    plotTheme.StationLocations.Name = "PotteryStations"
end

function PlotManager:GetPlot() : Model?
    for _, plot in ipairs (PlotManager.currentPlots) do
        if plot:GetAttribute("Owner") == "" then
            return plot
        end
    end
    return
end

function PlotManager:AssignPlot(player): {After: (callback: (freePlot: Model) -> ()) -> ()}
	local freePlot = PlotManager:GetPlot()
	if freePlot then
		freePlot:SetAttribute("Owner", player.UserId)
	else
		player:Kick("No free plots available.")
	end

    return {
        After = function(callback)
            if freePlot then
                callback(freePlot)
            end
        end
    }
end

function PlotManager:SetupPlayer(player)
    PlotManager:AssignPlot(player).After(function(freePlot)
		PlotManager:LoadPlot(player, freePlot)
    end)
end

for _, player in ipairs (Players:GetPlayers()) do
	PlotManager:SetupPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
	PlotManager:SetupPlayer(player)
end)

return PlotManager