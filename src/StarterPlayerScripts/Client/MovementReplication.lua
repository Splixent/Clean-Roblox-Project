local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Events = require(Shared.Events)
local MovementHandler = require(Client.MovementHandler)

local PlayerCameraData = Events.PlayerCameraData:Client()
local CameraPosition = Events.CameraPosition:Client()

local player = Players.LocalPlayer

local MovementReplication = {
    updateRate = 0.2,
    origins = {},

    lookAtDist = 60,
    headStrength = 0.05,
    torsoStrength = 0.05,
    counterStrength = 0.5,
}

function MovementReplication:MovementSolver(otherPlayer, cameraData)
    local character = otherPlayer.character
    if character == nil then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    
    if humanoidRootPart == nil or torso == nil or head == nil then return end
    
    local neck = torso:FindFirstChild("Neck") or torso:FindFirstChild("Neck")
    local waist = humanoidRootPart:FindFirstChild("RootJoint")
    
    if neck == nil or waist == nil then return end
    
    local rHip, lHip

    rHip = torso:FindFirstChild("Right Hip")
    lHip = torso:FindFirstChild("Left Hip")
    
    if rHip == nil or lHip == nil then return end

    if not MovementReplication.origins[character] then
        MovementReplication.origins[character] = {
            neck = neck.C0,
            waist = waist.C0,
            rHip = rHip.C0,
            lHip = lHip.C0,
            lastCameraData = cameraData,
            currentCameraData = cameraData,
            lastUpdateTime = tick()
        }
        
        -- Clean up when character is removed
        character.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                if MovementReplication.origins[character] and MovementReplication.origins[character].renderSteppedConnection then
                    MovementReplication.origins[character].renderSteppedConnection:Disconnect()
                end
                MovementReplication.origins[character] = nil
            end
        end)
    end

    local characterData = MovementReplication.origins[character]
    
    -- Update camera data and timestamps
    characterData.lastCameraData = characterData.currentCameraData
    characterData.currentCameraData = cameraData
    characterData.lastUpdateTime = tick()
    
    -- Connect a renderstepped function if not already connected
    if not characterData.renderSteppedConnection then
        characterData.renderSteppedConnection = game:GetService("RunService").RenderStepped:Connect(function()
            -- Calculate interpolation factor based on time since last update
            local timeSinceUpdate = tick() - characterData.lastUpdateTime
            local alpha = math.min(timeSinceUpdate / MovementReplication.updateRate, 1)
            
            -- Interpolate between last and current camera positions
            local lerpedCameraData = characterData.lastCameraData:Lerp(characterData.currentCameraData, alpha)
            
            -- Use the interpolated camera position for calculations
            local neckOriginC0 = characterData.neck
            local waistOriginC0 = characterData.waist
            local rHipOriginC0 = characterData.rHip
            local lHipOriginC0 = characterData.lHip
            
            local torsoLookVector = torso.CFrame.LookVector
            local headPosition = head.CFrame.Position
            
            -- Check if player should look at the local player instead of camera position
            local lookTarget = lerpedCameraData
            local localChar = player.Character
            
            if localChar and localChar:FindFirstChild("Head") then
                local localHead = localChar.Head
                local distanceToPlayer = (headPosition - localHead.Position).Magnitude
                local directionToPlayer = (localHead.Position - headPosition).Unit
                local facingPlayer = torsoLookVector:Dot(directionToPlayer) > 0.3 -- Looking in general direction
                
                if distanceToPlayer <= MovementReplication.lookAtDist and facingPlayer then
                    lookTarget = localHead.Position
                end
            end

            local cameraLookPoint = lookTarget
            local distance = (headPosition - cameraLookPoint).Magnitude
            local difference = head.CFrame.Y - cameraLookPoint.Y

            local goalNeckCFrame = CFrame.Angles(-(math.atan(difference / distance) * MovementReplication.headStrength), (((headPosition - cameraLookPoint).Unit):Cross(torsoLookVector)).Y * 1, 0)
            neck.C0 = neck.C0:lerp(goalNeckCFrame * neckOriginC0, 0.25).Rotation + neckOriginC0.Position

            local xAxisWaistRotation = -(math.atan(difference / distance) * 0.5)
            local yAxisWaistRotation = (((headPosition - cameraLookPoint).Unit):Cross(torsoLookVector)).Y * 0.5
            local rotationWaistCFrame = CFrame.Angles(xAxisWaistRotation, yAxisWaistRotation, 0)
            local goalWaistCFrame = rotationWaistCFrame * waistOriginC0
            waist.C0 = waist.C0:lerp(goalWaistCFrame, MovementReplication.torsoStrength).Rotation + waistOriginC0.Position

            local currentLegCounterCFrame = waist.C0 * waistOriginC0:Inverse()
            local legsCounterCFrame = currentLegCounterCFrame:Inverse()

            rHip.C0 = rHip.C0:Lerp(legsCounterCFrame * rHipOriginC0, MovementReplication.counterStrength)
            lHip.C0 = lHip.C0:Lerp(legsCounterCFrame * lHipOriginC0, MovementReplication.counterStrength)
        end)
    end
end

PlayerCameraData:On(function(cameraDatas)
    for otherPlayerName, cameraData in pairs(cameraDatas) do
        local otherPlayer = Players:FindFirstChild(otherPlayerName)
        if otherPlayer and otherPlayer ~= player then
            MovementReplication:MovementSolver(otherPlayer, cameraData)
        end
    end
end)

task.spawn(function()
    task.spawn(function()
        while true do
            CameraPosition:Fire(MovementHandler.cameraLookPoint)
            task.wait(MovementReplication.updateRate)
        end
    end)
end)

return MovementReplication