local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Replication = require(Client.Replication)
local Fusion = require(Shared.Fusion)

local Value = Fusion.Value
local Hydrate = Fusion.Hydrate
local New = Fusion.New
local Children = Fusion.Children

local player = Players.LocalPlayer

local KeybindHandler = {
    keybinds = Value({}),
    modulesWithKeybinds = {
        MovementHandler = require(Client.MovementHandler),
        CameraHandler = require(Client.CameraHandler),
        EquipmentHandler = require(Client.EquipmentHandler),
        CombatHandler = require(Client.CombatHandler),
    }
}

function KeybindHandler:UpdateBinds(keybinds)

    for keybindName, keybindInfo in pairs (keybinds) do
        ContextActionService:UnbindAction(keybindName)

        if keybindInfo.mouse then
            ContextActionService:BindAction(
                keybindName,
                KeybindHandler.modulesWithKeybinds[keybindInfo.moduleName][keybindName],
                true,
                Enum.UserInputType[keybindInfo.keyCode]
            )
        else
			ContextActionService:BindAction(
				keybindName,
				KeybindHandler.modulesWithKeybinds[keybindInfo.moduleName][keybindName],
				true,
				Enum.KeyCode[keybindInfo.keyCode]
			)
        end
    end
end

function KeybindHandler:UpdateMobileButtons(mobileKeybindInfos)
    for keybindName, mobileKeybindInfo in pairs (mobileKeybindInfos) do
        local button = ContextActionService:GetButton(keybindName)
        if button then
            Hydrate(button) {
                Name = keybindName,
                BackgroundColor3 = Color3.new(),
                BackgroundTransparency = 0.5,
                ImageTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(mobileKeybindInfo.location[1], mobileKeybindInfo.location[2]),
                Size = UDim2.fromScale(mobileKeybindInfo.size[1], mobileKeybindInfo.size[2]),
              
                [Children] = {
                  New "ImageLabel" {
                    Name = "ActionIcon",
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                  },
              
                  New "UICorner" {
                    Name = "UICorner",
                    CornerRadius = UDim.new(1, 0),
                  },
              
                  New "UIStroke" {
                    Name = "UIStroke",
                    Thickness = 2,
                    Transparency = 0.3,
                  },
              
                  New "UIGradient" {
                    Name = "UIGradient",
                    Rotation = 90,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                  },
              
                  New "TextLabel" {
                    Name = "ButtonName",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                      "rbxasset://fonts/families/SourceSansPro.json",
                      Enum.FontWeight.Heavy,
                      Enum.FontStyle.Normal
                    ),
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 0.3),
                    Text = keybindName,
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                  
                    [Children] = {
                      New "UIStroke" {
                        Name = "UIStroke",
                      },
                  
                      New "UIGradient" {
                        Name = "UIGradient",
                        Color = ColorSequence.new({
                          ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                          ColorSequenceKeypoint.new(0.585, Color3.fromRGB(252, 252, 252)),
                          ColorSequenceKeypoint.new(1, Color3.fromRGB(127, 127, 127)),
                        }),
                        Rotation = 90,
                      },
                    }
                  },

                  New "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                  },
                }
            }
        end
    end
end

function KeybindHandler:SetupMobileUI()
    local ContextButtonFrame = player.PlayerGui:WaitForChild("ContextActionGui"):WaitForChild("ContextButtonFrame")

    Hydrate(ContextButtonFrame) {
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
    }
end

task.spawn(function()

    if UserInputService.TouchEnabled then
        task.spawn(function()
			KeybindHandler:SetupMobileUI()
        end)
    end

    KeybindHandler:UpdateBinds(Replication:GetInfo("Data").keybinds)
	KeybindHandler:UpdateMobileButtons(Replication:GetInfo("Data").mobileKeybindInfos)

    Replication:GetInfo("Data", true):ListenToChange({"keybinds"}, function(newKeybinds)
        KeybindHandler:UpdateBinds(newKeybinds)
    end)
    
    Replication:GetInfo("Data", true):ListenToChange({"mobileKeybindInfos"}, function(newMobileKeybindInfos)
        KeybindHandler:UpdateMobileButtons(newMobileKeybindInfos)
    end)
end)

return KeybindHandler