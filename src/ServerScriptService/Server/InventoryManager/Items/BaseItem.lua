--[[
    BaseItem - Server-side base item class
    Handles basic equip, unequip, and activate functionality on the server
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseItem = {}
BaseItem.__index = BaseItem

function BaseItem.new(player: Player, itemName: string)
    local self = setmetatable({}, BaseItem)
    
    self.Player = player
    self.ItemName = itemName
    self.IsEquipped = false
    self.Tool = nil
    
    return self
end

function BaseItem:GetToolModel()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if assets then
        local heldItems = assets:FindFirstChild("HeldItems")
        if heldItems then
            return heldItems:FindFirstChild(self.ItemName)
        end
    end
    return nil
end

function BaseItem:Equip()
    if self.IsEquipped then return end
    
    self.IsEquipped = true
    
    local toolModel = self:GetToolModel()
    if toolModel then
        local character = self.Player.Character
        if character then
            self.Tool = toolModel:Clone()
            self.Tool.Name = "HeldItem"
            
            -- Weld to right arm/hand
            local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
            if rightArm and self.Tool:IsA("Model") then
                local handle = self.Tool:FindFirstChild("Handle") or self.Tool.PrimaryPart
                if handle then
                    local weld = Instance.new("Weld")
                    weld.Name = "HeldItemWeld"
                    weld.Part0 = rightArm
                    weld.Part1 = handle
                    weld.C0 = CFrame.new(0, -1, 0)
                    weld.Parent = handle
                end
            elseif self.Tool:IsA("BasePart") then
                local weld = Instance.new("Weld")
                weld.Name = "HeldItemWeld"
                weld.Part0 = rightArm
                weld.Part1 = self.Tool
                weld.C0 = CFrame.new(0, -1, 0)
                weld.Parent = self.Tool
            end
            
            self.Tool.Parent = character
        end
    end
    
    self:OnEquip()
end

function BaseItem:Unequip()
    if not self.IsEquipped then return end
    
    self.IsEquipped = false
    
    if self.Tool then
        self.Tool:Destroy()
        self.Tool = nil
    end
    
    self:OnUnequip()
end

function BaseItem:Activate()
    if not self.IsEquipped then return end
    
    self:OnActivate()
end

-- Override these in subclasses
function BaseItem:OnEquip()
    print(`[BaseItem] {self.Player.Name} equipped {self.ItemName}`)
end

function BaseItem:OnUnequip()
    print(`[BaseItem] {self.Player.Name} unequipped {self.ItemName}`)
end

function BaseItem:OnActivate()
    print(`[BaseItem] {self.Player.Name} activated {self.ItemName}`)
end

function BaseItem:Destroy()
    self:Unequip()
end

return BaseItem
