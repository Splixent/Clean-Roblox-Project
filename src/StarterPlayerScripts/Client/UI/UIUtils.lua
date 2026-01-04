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
    
    local newState = not currentlyVisible
    
    if newState then
        for name, state in pairs(UIUtils.UIVisibility) do

            if name == targetUIName then
                state:set(true)
            else
                state:set(false)
            end
        end
    else
        UIUtils.UIVisibility[targetUIName]:set(false)
    end
end

return UIUtils
