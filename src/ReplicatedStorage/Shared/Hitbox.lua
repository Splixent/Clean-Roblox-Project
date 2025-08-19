local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Maid = require(Shared.Maid)
local Gizmo = require(Shared.CeiveImGizmo)

local PlayerCharacters = game.Workspace:WaitForChild("PlayerCharacters")
local AICharacters = game.Workspace:WaitForChild("AICharacters")

local Hitbox = {
    overlapParams = (function()
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
        overlapParams.FilterDescendantsInstances = {workspace.Terrain}
        return overlapParams
    end)()
}

function Hitbox.new(attackData, ...)
    local self = setmetatable({}, {__index = Hitbox})
    self.hitboxes = attackData.hitboxes
    self.durationMaid = Maid.new()
    self.cleaning = false
    self.extraData = {}

	for i, v in ipairs({ ... }) do
		if type(v) == "table" then
			for k, v2 in pairs(v) do
				self.extraData[k] = v2
			end
		else
			self.extraData[i] = v
		end
	end
    
    return self
end

function Hitbox:Play(once)
	local hitList = {}
    local scanned = false

    for _, hitboxData in ipairs (self.hitboxes) do
        local objectHitList = {}

        self.durationMaid:GiveTask(RunService[RunService:IsServer() and "Stepped" or "RenderStepped"]:Connect(function()
            if once then
                if scanned == false then
					scanned = true
                else
					self.durationMaid:DoCleaning()
                end
            end

            local transform = CFrame.new()
            local attachObject

            if hitboxData.attachPath and self.extraData.attachTarget then
                attachObject = self.extraData.attachTarget

                if typeof(attachObject) == "Instance" then
                    for _, childName in ipairs(hitboxData.attachPath) do
						if attachObject then
							attachObject = attachObject:FindFirstChild(childName)
						else
							break
						end
                    end

					transform = attachObject.CFrame

					if hitboxData.offset then
						transform = transform * hitboxData.offset
					end
                end
                
                if attachObject and typeof(attachObject) == "CFrame" then
                    transform = attachObject
                    
                    if hitboxData.offset then
                        transform = transform * hitboxData.offset
                    end
                end
            end

            if self.extraData.ignoreList then
				Hitbox.overlapParams.FilterDescendantsInstances = self.extraData.ignoreList
				Hitbox.overlapParams.FilterType = Enum.RaycastFilterType.Exclude
            end

            if self.extraData.whiteList then
                Hitbox.overlapParams.FilterDescendantsInstances = self.extraData.whiteList
                Hitbox.overlapParams.FilterType = Enum.RaycastFilterType.Include
            end

            local parts

            if hitboxData.shape == "cube" then
				local size = hitboxData.size or Vector3.new(4, 4, 4)

                if self.extraData.scan == nil then
                    if tick() - self.extraData.startTime <= (hitboxData.startUpDelay or 0) then
						Gizmo.PushProperty("Color3", Color3.new(1, 0.835294, 0))
						Gizmo.PushProperty("Transparency", 0.8)
						Gizmo.VolumeBox:Draw(transform, size, false)

						Gizmo.PushProperty("Color3", Color3.new(1, 0.835294, 0))
						Gizmo.PushProperty("Transparency", 0)
						Gizmo.Box:Draw(transform, size, false)
						return
                    else
						if #objectHitList > 0 then
							Gizmo.PushProperty("Color3", Color3.new(0, 1, 0.584313))
							Gizmo.PushProperty("Transparency", 0.8)
							Gizmo.VolumeBox:Draw(transform, size, false)

							Gizmo.PushProperty("Color3", Color3.new(0, 1, 0.584313))
							Gizmo.PushProperty("Transparency", 0)
							Gizmo.Box:Draw(transform, size, false)
						else
							Gizmo.PushProperty("Color3", Color3.new(1, 0, 0.282352))
							Gizmo.PushProperty("Transparency", 0.8)
							Gizmo.VolumeBox:Draw(transform, size, false)

							Gizmo.PushProperty("Color3", Color3.new(1, 0, 0.282352))
							Gizmo.PushProperty("Transparency", 0)
							Gizmo.Box:Draw(transform, size, false)
						end
                    end
                end
                
				parts = workspace:GetPartBoundsInBox(transform, size, Hitbox.overlapParams)
			elseif hitboxData.shape == "sphere" then
				local radius = hitboxData.size.X or 4

                if self.extraData.scan == nil then
                    if #hitList > 0 then
						Gizmo.PushProperty("Color3", Color3.new(0, 1, 0.584313))
						Gizmo.PushProperty("Transparency", 0.8)
						Gizmo.VolumeSphere:Draw(transform, radius, 30, 360)

						Gizmo.PushProperty("Color3", Color3.new(0, 1, 0.584313))
						Gizmo.PushProperty("Transparency", 0)
						Gizmo.Sphere:Draw(transform, radius, 30, 360)
                    else
						Gizmo.PushProperty("Color3", Color3.new(1, 0, 0.282352))
						Gizmo.PushProperty("Transparency", 0.8)
						Gizmo.VolumeSphere:Draw(transform, radius, 30, 360)

						Gizmo.PushProperty("Color3", Color3.new(1, 0, 0.282352))
						Gizmo.PushProperty("Transparency", 0)
						Gizmo.Sphere:Draw(transform, radius, 30, 360)
                    end
                end

				parts = workspace:GetPartBoundsInRadius(transform.Position, radius, Hitbox.overlapParams)
			end

            if self.extraData.scan then
                if #parts > 0 then
                    self.extraData.onScan(true, {
                        Destroy = function()
                            self:Stop()
                        end,
                    })
                end
            else
                for _, part in ipairs(parts) do
					local targetCharacter = part.Parent:IsDescendantOf(PlayerCharacters)
						or part.Parent:IsDescendantOf(AICharacters)

					if targetCharacter then
						local targetCharacter = part.Parent
						local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

						if humanoid and table.find(objectHitList, targetCharacter) == nil then
							table.insert(objectHitList, targetCharacter)
						end

						if humanoid and table.find(hitList, targetCharacter) == nil then
							table.insert(hitList, targetCharacter)

							self.extraData.onHit({
								hitCharacter = targetCharacter,
								attackNumber = self.extraData.attackNumber,
								timeStamp = DateTime.now().UnixTimestampMillis / 1000,
							}, {
								Destroy = function()
									self:Stop()
								end,
							})
						end
					end
                end
            end
        end))

        task.delay(hitboxData.duration or 0.5, function()
            if self.durationMaid then
				self.durationMaid:DoCleaning()
            end
        end)
    end

    return {
        Wait = function()
            repeat task.wait() until self.cleaning
        end
    }
end

function Hitbox:Stop()
	self.durationMaid:Destroy()
	self.cleaning = true
	self = nil
end

Hitbox.Destroy = Hitbox.Stop

return Hitbox