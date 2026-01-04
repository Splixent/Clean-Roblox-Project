local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion, s = require(Shared.Fusion)
local UIPostProcess = require(script.UIPostProcess)

local Children = Fusion.Children

local s = Fusion.scoped(Fusion)

local Player = Players.LocalPlayer

local UI = {}

task.spawn(function()
    local TestUI = Player.PlayerGui:WaitForChild("TestUI")

    if TestUI then
        TestUI.Enabled = false
    end
end)


for i, component in ipairs (script.Components:GetChildren()) do
    table.insert(UI, require(component))
    task.wait(0.33/2)
end 


local masterUI = s:New "ScreenGui" {
    Name = "UI",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = Player.PlayerGui,
    IgnoreGuiInset = true,

    [Children] = {
        UI
    }
}
UIPostProcess:ViewportChanged(masterUI)
UIPostProcess:UpdateAutoScaleScrollingFrames(masterUI)

return nil