local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Client = Players.LocalPlayer.PlayerScripts.Client

local player = Players.LocalPlayer

local PlotHandler = {
    currentPlots = game.Workspace:WaitForChild("Plots"):GetChildren(),
    plot = nil :: Model?,
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

-- Initialize
task.spawn(function()
    repeat task.wait() until PlotHandler:GetPlot() ~= nil
end)

return PlotHandler