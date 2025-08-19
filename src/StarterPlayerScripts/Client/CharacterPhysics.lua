local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Maid = require(Shared.Maid)
local Gizmo = require(Shared.CeiveImGizmo)

local CharacterPhysics = {
    antiFriction = 200,
    antiModifier = 14,
    currentForces = {},
    gravityStrength = -196.2 * 1.5, -- Default gravity strength
    raycastDistance = 3.5, -- How far to check for ground beneath
    stepDistance = 2.5,
    debugVisualization = true, -- Toggle for debug visualization
    gizmos = {}, -- Store gizmo references
}

function CharacterPhysics:ContinuousImpulse(character, settings)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local rootAttachment = humanoidRootPart and humanoidRootPart:FindFirstChild("RootAttachment")

    if not humanoidRootPart or not rootAttachment then
        warn("ContinuousImpulse: Missing HumanoidRootPart or RootAttachment")
        return nil
    end

    if not settings.velocityFunction or typeof(settings.velocityFunction) ~= "function" then
        warn("ContinuousImpulse: velocityFunction must be provided as a function")
        return nil
    end

    local running = false
    local maids = {}
    
    local linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Parent = humanoidRootPart
    linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVelocity.Attachment0 = rootAttachment
    linearVelocity.MaxForce = 250000
    linearVelocity.VectorVelocity = Vector3.zero
    linearVelocity.Enabled = false

    for settingName, settingValue in pairs(settings) do
        if settingName == "maxForce" then
            linearVelocity.MaxForce = settingValue
            continue
        end

        if pcall(function()
            return linearVelocity[settingName] ~= nil
        end) then
            linearVelocity[settingName] = settingValue
        end
    end

    settings.linearVelocity = linearVelocity

    if CharacterPhysics.debugVisualization then
        local gizmoMaid = Maid.new()
        maids.gizmo = gizmoMaid
        
        gizmoMaid:GiveTask(RunService.RenderStepped:Connect(function()
            Gizmo.PushProperty("Color3", Color3.fromRGB(255, 0, 0))
            local hrpPosition = humanoidRootPart.Position
            local velocityVec = linearVelocity.VectorVelocity
            if velocityVec.Magnitude > 0.001 then
                local targetPosition = hrpPosition + velocityVec.Unit * 5
                Gizmo.Arrow:Draw(hrpPosition, targetPosition, 0.1, 0.5, 5)
            end

            Gizmo.PushProperty("Color3", Color3.fromRGB(0, 0, 255))
            if velocityVec.Magnitude > 0.001 then
                local lineDisplayVector = velocityVec / 20
                local lineLength = lineDisplayVector.Magnitude
                local lineTransform = CFrame.new(hrpPosition, hrpPosition - lineDisplayVector)
                Gizmo.Line:Draw(lineTransform, lineLength, 0.05)
            end
        end))

        CharacterPhysics.gizmos[linearVelocity] = gizmoMaid
    end

    if settings.applyGravity then
        local gravityMaid = CharacterPhysics:ApplyGravity(humanoidRootPart, linearVelocity, -3e3)
        maids.gravity = gravityMaid
    end

    local impulseController = {
        Play = function()
            if running then
                return
            end
            running = true
            linearVelocity.Enabled = true

            local forceDecayMaid = CharacterPhysics:SetupDecay(settings)
            maids.decay = forceDecayMaid
            
            local stepUpMaid = CharacterPhysics:StepUp(humanoidRootPart, settings, 25)
            maids.stepUp = stepUpMaid

            local updateMaid = Maid.new()
            maids.update = updateMaid
            
            updateMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime)
                if not running or not humanoidRootPart or not humanoidRootPart.Parent then
				    CharacterPhysics:CleanupMaids(maids)
                    return
                end

                local newVelocity = settings.velocityFunction(deltaTime, humanoidRootPart)
                if typeof(newVelocity) == "Vector3" then
                    linearVelocity.VectorVelocity = newVelocity
                end
            end))
        end,

        Stop = function()
            running = false
		    CharacterPhysics:CleanupMaids(maids)
            
            if settings.linearVelocity then
                settings.linearVelocity:Destroy()
            end
            if CharacterPhysics.gizmos[linearVelocity] then
                CharacterPhysics.gizmos[linearVelocity] = nil
            end
        end,
    }

    return impulseController
end

function CharacterPhysics:Impulse(character, settings)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local rootAttachment = humanoidRootPart:FindFirstChild("RootAttachment")
    local linearVelocity
    local gravityMaid
    local gizmoMaid

    if humanoidRootPart and rootAttachment then
        linearVelocity = Instance.new("LinearVelocity")
        linearVelocity.Parent = humanoidRootPart
        linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
        linearVelocity.Attachment0 = rootAttachment
        linearVelocity.Enabled = false
        linearVelocity.MaxForce = 250000 -- Ensure maximum effect
        linearVelocity.VectorVelocity = Vector3.zero
        linearVelocity.Enabled = false

        for settingName, settingValue in pairs(settings) do
            if settingName == "maxForce" then
                linearVelocity.MaxForce = settingValue
                continue
            end

            if settingName == "vectorVelocity" then
                linearVelocity.VectorVelocity = settingValue
                continue
            end

            if pcall(function() return linearVelocity[settingName] ~= nil end) then
                linearVelocity[settingName] = settingValue
            end
        end

        settings.linearVelocity = linearVelocity

        if CharacterPhysics.debugVisualization then
            gizmoMaid = Maid.new()
            gizmoMaid:GiveTask(RunService.RenderStepped:Connect(function()
                Gizmo.PushProperty("Color3", Color3.fromRGB(255, 0, 0))
                local hrpPosition = humanoidRootPart.Position
                local targetPosition = hrpPosition + linearVelocity.VectorVelocity.Unit * 5
                Gizmo.Arrow:Draw(hrpPosition, targetPosition, 0.1, 0.5, 5) -- Example values for radius, length, subdivisions

                Gizmo.PushProperty("Color3", Color3.fromRGB(0, 0, 255)) -- Blue for velocity magnitude
                local velocityVec = linearVelocity.VectorVelocity
                local velocityMagnitude = velocityVec.Magnitude
                if velocityMagnitude > 0.001 then -- Draw only if there's some velocity (reduced threshold slightly)
                    local startPosition = hrpPosition
                    
                    local lineDisplayVector = velocityVec / 20 
                    local lineLength = lineDisplayVector.Magnitude

                    local lineTransform
                    if lineLength < 0.0001 then -- If the line is too short, treat as a point
                        lineTransform = CFrame.new(startPosition)
                    else
                        local lookAtTarget = startPosition - lineDisplayVector.Unit
                        lineTransform = CFrame.lookAt(startPosition, lookAtTarget)
                    end
                    Gizmo.Line:Draw(lineTransform, lineLength, 0.05) -- Thickness
                end
            end))
            CharacterPhysics.gizmos[linearVelocity] = gizmoMaid
        end

        if settings.applyGravity then
            gravityMaid = CharacterPhysics:ApplyGravity(humanoidRootPart, linearVelocity)
        end
    end

    return {
        Play = function()
            if character then
                task.spawn(function()
                    linearVelocity.Enabled = true

                    local forceDecayMaid = CharacterPhysics:SetupDecay(settings)

                    settings.linearVelocity.Enabled = true
                    task.wait(settings.duration or 0)
                    settings.linearVelocity.Enabled = false
                    settings.linearVelocity:Destroy()

                    if forceDecayMaid then
                        forceDecayMaid:Destroy()
                    end
                    if gravityMaid then
                        gravityMaid:Destroy()
                    end
                    if gizmoMaid then
                        gizmoMaid:Destroy()
                    end
                    if CharacterPhysics.gizmos[settings.linearVelocity] then
                        CharacterPhysics.gizmos[settings.linearVelocity]:Destroy()
                        CharacterPhysics.gizmos[settings.linearVelocity] = nil
                    end
                end)
            end
        end,
    }
end

function CharacterPhysics:CleanupMaids(maidsToCleanup)
	for _, maid in pairs(maidsToCleanup) do
		if maid then
			maid:Destroy()
		end
	end
end

function CharacterPhysics:StepUp(humanoidRootPart, settings, stepUpForce)
    local stepUpMaid = Maid.new()

    stepUpMaid:GiveTask(RunService.Heartbeat:Connect(function()
        local rayOrigin = humanoidRootPart.Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {humanoidRootPart.Parent}

        local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0, -CharacterPhysics.stepDistance, 0), raycastParams)

        if raycastResult and raycastResult.Instance then
            settings.linearVelocity.VectorVelocity = Vector3.new(
                settings.linearVelocity.VectorVelocity.X,
                settings.linearVelocity.VectorVelocity.Y + stepUpForce, -- Adjust the step up force as needed
                settings.linearVelocity.VectorVelocity.Z
            )
        end
    end))

    return stepUpMaid
end

function CharacterPhysics:ApplyGravity(humanoidRootPart, linearVelocity, gravityStrength)
    local gravityMaid = Maid.new()

    if CharacterPhysics.debugVisualization then
        gravityMaid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime)
            local rayOrigin = humanoidRootPart.Position
            local rayEnd = rayOrigin + Vector3.new(0, -CharacterPhysics.raycastDistance, 0)
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {humanoidRootPart.Parent}

            local raycastResult = workspace:Raycast(
                rayOrigin,
                Vector3.new(0, -CharacterPhysics.raycastDistance, 0),
                raycastParams
            )

            if raycastResult then
                Gizmo.PushProperty("Color3", Color3.fromRGB(255, 0, 0)) -- Red when hitting ground
            else
                Gizmo.PushProperty("Color3", Color3.fromRGB(0, 255, 0)) -- Green when not hitting ground
            end
            Gizmo.Ray:Draw(rayOrigin, rayEnd)
        end))
    end

    gravityMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {humanoidRootPart.Parent}

        local raycastResult = workspace:Raycast(
            humanoidRootPart.Position,
            Vector3.new(0, -CharacterPhysics.raycastDistance, 0),
            raycastParams
        )

        if not raycastResult then
            local currentVelocity = linearVelocity.VectorVelocity
            linearVelocity.VectorVelocity = Vector3.new(
                currentVelocity.X,
                currentVelocity.Y + (gravityStrength or CharacterPhysics.gravityStrength) * deltaTime,
                currentVelocity.Z
            )
        end
    end))

    CharacterPhysics.currentForces[linearVelocity] = gravityMaid
    return gravityMaid
end

function CharacterPhysics:SetupDecay(settings)
    local decayMaid = Maid.new()

    if settings.velocityDecayRate then
        decayMaid:GiveTask(CharacterPhysics:Decay(settings.linearVelocity, "Force", settings.velocityDecayRate))
    end

    if settings.maxForceDecayRate then
        decayMaid:GiveTask(CharacterPhysics:Decay(settings.linearVelocity, "MaxForce", settings.maxForceDecayRate))
    end

    return decayMaid
end

function CharacterPhysics:Decay(linearVelocity, propertyName, rate)
    local decayMaid = Maid.new()

    decayMaid:GiveTask(RunService.Stepped:Connect(function()
        if propertyName == "Force" then
            local velocity = linearVelocity.VectorVelocity
            local newVelocity = velocity * rate
            linearVelocity.VectorVelocity = newVelocity
        elseif propertyName == "MaxForce" then
            linearVelocity.MaxForce = linearVelocity.MaxForce * rate
        end
    end))

    return decayMaid
end

return CharacterPhysics