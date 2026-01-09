local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Client = Players.LocalPlayer.PlayerScripts.Client
local PlotStations = Client.PlotStations

-- Station handlers
local StationHandlers = {
    ClayPatch = require(PlotStations.ClayPatch),
    PottersWheel = require(PlotStations.PottersWheel),
    Kiln = require(PlotStations.Kiln),
    GlazeTable = require(PlotStations.GlazeTable),
    CoolingTable = require(PlotStations.CoolingTable),
}

local player = Players.LocalPlayer

local PlotHandler = {
    currentPlots = game.Workspace:WaitForChild("Plots"):GetChildren(),
    plot = nil :: Model?,
    stations = {},
}

function PlotHandler:GetPlot()
    for _, plot in ipairs(self.currentPlots) do
        if plot:GetAttribute("Owner") == player.UserId then
            self.plot = plot
            return plot
        end
    end
    return nil
end

function PlotHandler:SetupPlotStations()
    local stationsFolder = self.plot:WaitForChild("MainPlot"):WaitForChild("PotteryStations")
    
    for _, stationModel in ipairs(stationsFolder:GetChildren()) do
        local handler = self:GetHandlerForStation(stationModel.Name)
        
        if handler then
            local station = handler.new(player, stationModel)
            table.insert(self.stations, station)
        else
            warn("[PlotHandler] No handler for station: " .. stationModel.Name)
        end
    end
end

function PlotHandler:GetHandlerForStation(stationName: string)
    -- Check if station name contains any of our handler keys
    for handlerName, handler in pairs(StationHandlers) do
        if stationName:find(handlerName) then
            return handler
        end
    end
    return nil
end

function PlotHandler:GetStation(stationModel: Model)
    for _, station in ipairs(self.stations) do
        if station.model == stationModel then
            return station
        end
    end
    return nil
end

function PlotHandler:Cleanup()
    for _, station in ipairs(self.stations) do
        if station.Destroy then
            station:Destroy()
        end
    end
    self.stations = {}
end

-- Initialize
task.spawn(function()
    repeat task.wait() until PlotHandler:GetPlot() ~= nil
    
    print("[PlotHandler] Found plot, setting up stations...")
    PlotHandler:SetupPlotStations()
end)

return PlotHandler