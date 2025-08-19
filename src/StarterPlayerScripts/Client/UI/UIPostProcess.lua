local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Maid = require(Shared.Maid)
local Fusion = require(Shared.Fusion)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Value = Fusion.Value --test branch update

local UIPostProcess = {
    scrollingFrameConnections = {},
    scrollFrameMaid = Maid.new(),
    masterUI = nil,
    viewportSize = Value(Vector2.new(0, 0)),

    handlers = {
        {
            condition = function(object)
                return object:IsA("ImageLabel") and object.ScaleType == Enum.ScaleType.Slice
            end,
            action = function(object, context)
                if not object:GetAttribute("original") then
                    object:SetAttribute("original", object.SliceScale)
                end
                object.SliceScale = object:GetAttribute("original") * context.uniformScale
            end
        },
        {
            condition = function(object)
                return object:IsA("UIGridLayout")
            end,
            action = function(object, context)
                if not object:GetAttribute("originalPadding") then
                    object:SetAttribute("originalPadding", object.CellPadding)
                end
                if not object:GetAttribute("originalCellSize") then
                    object:SetAttribute("originalCellSize", object.CellSize)
                end
                local originalPadding = object:GetAttribute("originalPadding")
                local originalCellSize = object:GetAttribute("originalCellSize")
                object.CellPadding = UDim2.new(
                    originalPadding.X.Scale, originalPadding.X.Offset * context.uniformScale,
                    originalPadding.Y.Scale, originalPadding.Y.Offset * context.uniformScale)
                object.CellSize = UDim2.new(
                    originalCellSize.X.Scale, originalCellSize.X.Offset * context.uniformScale,
                    originalCellSize.Y.Scale, originalCellSize.Y.Offset * context.uniformScale)
            end
        },
        {
            condition = function(object)
                return object:IsA("UIStroke")
            end,
            action = function(object, context)
                if object.Name == "UIStroke_Ignore" then return end
                if not object:GetAttribute("original") then
                    object:SetAttribute("original", object.Thickness)
                end
                object.Thickness = object:GetAttribute("original") * context.viewportSize.Y / 1080
            end
        },
        {
            condition = function(object)
                return object:IsA("UIListLayout")
            end,
            action = function(object, context)
                -- Initialize original padding scales and offsets if not already set
                if not object:GetAttribute("originalPaddingScale") then
                    object:SetAttribute("originalPaddingScale", object.Padding.Scale)
                end
                if not object:GetAttribute("originalPaddingOffset") then
                    object:SetAttribute("originalPaddingOffset", object.Padding.Offset)
                end
        
                -- Retrieve original padding scales and offsets
                local originalPaddingScale = object:GetAttribute("originalPaddingScale")
                local originalPaddingOffset = object:GetAttribute("originalPaddingOffset")
        
                -- Get FillDirection to determine which axis to scale
                local fillDirection = object.FillDirection
        
                -- Calculate new Scale
                local newScale = originalPaddingScale * context.uniformScale
        
                -- Calculate new Offset based on FillDirection
                local newOffset
                if fillDirection == Enum.FillDirection.Horizontal then
                    -- Scale Offset based on X-axis relative to 1920
                    newOffset = originalPaddingOffset * (context.viewportSize.X / 1920) * 1.1
                else
                    -- Scale Offset based on Y-axis relative to 1080
                    newOffset = originalPaddingOffset * (context.viewportSize.Y / 1080) * 1.1
                end
        
                -- Apply the new Padding
                object.Padding = UDim.new(newScale, newOffset)
            end
        },
        {
            condition = function(object)
                return object:IsA("UICorner") and object.CornerRadius.Scale == 0
            end,
            action = function(object, context)
                if not object:GetAttribute("originalCornerRadius") then
                    object:SetAttribute("originalCornerRadius", object.CornerRadius)
                end
                local originalCornerRadius = object:GetAttribute("originalCornerRadius")
                object.CornerRadius = UDim.new(0, originalCornerRadius.Offset * context.uniformScale)
            end
        },
        {
            condition = function(object)
                return object:IsA("ScrollingFrame")
            end,
            action = function(scrollingFrame, context)
                if scrollingFrame.name == "ScrollingFrame_Ignore" then return end
                -- Find UIListLayout or UIGridLayout within the ScrollingFrame
                local UIConstraint = scrollingFrame:FindFirstChildOfClass("UIListLayout") or scrollingFrame:FindFirstChildOfClass("UIGridLayout")
                task.delay(1, function()
                    if UIConstraint then
                        task.wait(1)
                        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, UIConstraint.AbsoluteContentSize.Y * 1.1)
                    end
                end)
            end
        }
    }
}

function UIPostProcess:UpdateAutoScaleScrollingFrames(masterUI)
    UIPostProcess.scrollFrameMaid:Destroy()
    UIPostProcess.scrollFrameMaid = Maid.new()
    UIPostProcess.scrollingFrameConnections = {}

    if UIPostProcess.masterUI == nil then UIPostProcess.masterUI = masterUI end

    for index, scrollingFrame in ipairs(UIPostProcess.masterUI:GetDescendants()) do
        if scrollingFrame:IsA("ScrollingFrame") then
            if scrollingFrame.name == "ScrollingFrame_Ignore" then return end
            local UIConstraint = scrollingFrame:FindFirstChildOfClass("UIListLayout") or scrollingFrame:FindFirstChildOfClass("UIGridLayout")
            if UIConstraint then
                table.insert(UIPostProcess.scrollingFrameConnections, UIPostProcess.scrollFrameMaid:GiveTask(UIConstraint:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, UIConstraint.AbsoluteContentSize.Y)
                end)))

                scrollingFrame.CanvasSize = UDim2.new(0, 0, 0.01, UIConstraint.AbsoluteContentSize.Y * 1.1)
            end
        end

        if index % 100 == 0 then
            task.wait()
        end
    end
end

function UIPostProcess:ViewportChanged(masterUI)
    if UIPostProcess.masterUI == nil then UIPostProcess.masterUI = masterUI end

    local scaleX = game.Workspace.CurrentCamera.ViewportSize.Y / 1080
    local scaleY = game.Workspace.CurrentCamera.ViewportSize.X / 1920
    local uniformScale = math.min(scaleX, scaleY)

    local context = {
        uniformScale = uniformScale,
        viewportSize = game.Workspace.CurrentCamera.ViewportSize
    }

    if UIPostProcess.masterUI then
        for index, object in ipairs(UIPostProcess.masterUI:GetDescendants()) do
            for _, handler in ipairs(UIPostProcess.handlers) do
                if handler.condition(object) then
                    handler.action(object, context)
                    break
                end
            end

            if index % 100 == 0 then
                task.wait()
            end
        end
    end

    UIPostProcess.viewportSize:set(Vector2.new(game.Workspace.CurrentCamera.ViewportSize.X, game.Workspace.CurrentCamera.ViewportSize.Y))
end

task.spawn(function()
    repeat task.wait(1) until UIPostProcess.masterUI

    UIPostProcess:ViewportChanged(UIPostProcess.masterUI)

    local uniformScale = game.Workspace.CurrentCamera.ViewportSize.Y / 1080
    local context = {
        uniformScale = uniformScale,
        viewportSize = game.Workspace.CurrentCamera.ViewportSize
    }

    task.spawn(function()
        while true do
            UIPostProcess:ViewportChanged(UIPostProcess.masterUI)
            task.wait(5)
        end
    end)

    if UIPostProcess.masterUI ~= nil then
        for index, object in ipairs(UIPostProcess.masterUI:GetDescendants()) do
            for _, handler in ipairs(UIPostProcess.handlers) do
                if handler.condition(object) then
                    handler.action(object, context)
                    break
                end
            end

            if index % 100 == 0 then
                task.wait()
            end
        end
    end

    UIPostProcess.masterUI.DescendantAdded:Connect(function(descendant)
        for _, handler in ipairs(UIPostProcess.handlers) do
            if handler.condition(descendant) then
                handler.action(descendant, context)
                break
            end
        end
    end)
end)

return UIPostProcess
