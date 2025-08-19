local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local ScriptUtils = require(Shared.ScriptUtils)
local UIPostProcess = require(Client.UI.UIPostProcess)
local Replication = require(Client.Replication)

local Value = Fusion.Value
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween

local UIUtils = {
	UIVisibility = {},
}

function UIUtils:ToggleUI(targetUIName: string)
    local currentlyVisible = UIUtils.UIVisibility[targetUIName]:get()
    
    -- Determine next state (flip it)
    local newState = not currentlyVisible
    
    -- If we want to SHOW the UI (newState == true):
    if newState then
        -- Hide everything except optional extras
        for name, state in pairs(UIUtils.UIVisibility) do

            if name == targetUIName then
                state:set(true)
            else
                state:set(false)
            end
        end
    else
        -- If we are HIDING the target UI
        UIUtils.UIVisibility[targetUIName]:set(false)
    end
end

task.spawn(function()
	
end)

return UIUtils
