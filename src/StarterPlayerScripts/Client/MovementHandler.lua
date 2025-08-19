local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local Replication = require(Client.Replication)
local Maid = require(Shared.Maid)
local Gizmo = require(Shared.CeiveImGizmo)
local ScriptUtils = require(Shared.ScriptUtils)
local CharacterPhysics = require(Client.CharacterPhysics)
local Events = require(Shared.Events)
local ClientEffects = require(Client.ClientEffects)
local ControlModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule.ControlModule)
local CombatHandler = require(Client.CombatHandler)

local Value = Fusion.Value
local Children = Fusion.Children
local New = Fusion.New
local Computed = Fusion.Computed

local player = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera

local SendEffect = Events.SendEffect:Client()

local MovementHandler = {
    sprintKey = Value("LeftShift"),
    toggleSprint = Value(false),
    sprintToggle = Value(false),
    isSprinting = false,
    shiftHeld = false,
    isFlashsteping = false,

    tiltSpeed = 0.3,
    maxTilt = 0.1,

    tiltX = 0.1,
    tiltZ = 0.1,

    headStrength = 0.2,
    torsoStrength = 0.01,

    characterAnimations = ReplicatedStorage.Assets.CharacterAnimations,

    runAnimation = ReplicatedStorage.Assets.CharacterAnimations.Run,
    walkAnimation = ReplicatedStorage.Assets.CharacterAnimations.Walk,

    movementInfo = {
        hrpLookVector = Vector3.new(),
        hrpLinearVelocity = Vector3.new(),
        hrpMoveVelocity = Vector3.new(),
        hrpMoveYaw = 0,
    },

    currentCharacter = {},

    idleAnimations = {
        ReplicatedStorage.Assets.CharacterAnimations.Idle1,
        ReplicatedStorage.Assets.CharacterAnimations.Idle2,
    },

    jumpAnimation = ReplicatedStorage.Assets.CharacterAnimations.Jump,
    fallAnimation = ReplicatedStorage.Assets.CharacterAnimations.Fall,
    landAnimation = ReplicatedStorage.Assets.CharacterAnimations.Land,

    movementMaid = Maid.new(),
    dashDebounce = false,
    dashCD = 2,
    cameraLookPoint = Vector3.new(),

    currentWeapon = Value("None"),
}

function MovementHandler.sprint(inputName, userInputState)
    local character = player.Character
    local humanoid = character.Humanoid

	if character == nil or humanoid == nil then
		return Enum.ContextActionResult.Pass
	end

	if CombatHandler.blockTrack then
		return Enum.ContextActionResult.Sink
	end

    if MovementHandler.toggleSprint:get() == true then
		if MovementHandler.sprintToggle:get() == false then
			if userInputState == Enum.UserInputState.Begin then
				humanoid.WalkSpeed = 26
				MovementHandler.isSprinting = true
				MovementHandler.shiftHeld = true
				MovementHandler.sprintToggle:set(true)
				return Enum.ContextActionResult.Sink
			end
		else
			if userInputState == Enum.UserInputState.Begin then
				humanoid.WalkSpeed = 16
				MovementHandler.isSprinting = false

				MovementHandler.shiftHeld = false
				MovementHandler.sprintToggle:set(false)
				return Enum.ContextActionResult.Sink
			end
		end
    end

	if userInputState == Enum.UserInputState.Begin then
		local sprintMaid = Maid.new()
		local heldMaid = Maid.new()
		sprintMaid:GiveTask(UserInputService.InputEnded:Connect(function(InputObject, isTyping)
			if
				InputObject.UserInputType == Enum.UserInputType.Touch
				or (
					InputObject.UserInputType == Enum.UserInputType.Keyboard
					and InputObject.KeyCode == Enum.KeyCode[MovementHandler.sprintKey:get()]
				)
			then
				if MovementHandler.isFlashsteping == false then
					humanoid.WalkSpeed = 16
				end
				MovementHandler.isSprinting = false
				sprintMaid:Destroy()
			end
		end))

		heldMaid:GiveTask(UserInputService.InputEnded:Connect(function(InputObject, isTyping)
			if
				InputObject.UserInputType == Enum.UserInputType.Touch
				or (
					InputObject.UserInputType == Enum.UserInputType.Keyboard
					and InputObject.KeyCode == Enum.KeyCode[MovementHandler.sprintKey:get()]
				)
			then
				MovementHandler.shiftHeld = false
				heldMaid:Destroy()
			end
		end))

		sprintMaid:GiveTask(RunService.RenderStepped:Connect(function()
			if character:FindFirstChild("HumanoidRootPart") == nil then
				sprintMaid:Destroy()
				return Enum.ContextActionResult.Sink
			end

            local notMoving = character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude < 0.1
            local runningBackwards = 2.2 <= math.abs(MovementHandler.hrpMoveYaw or 0)

            if notMoving or runningBackwards then
				if MovementHandler.isFlashsteping == false then
					humanoid.WalkSpeed = 16
					MovementHandler.isSprinting = false
    
                    sprintMaid:Destroy()
				end
				return Enum.ContextActionResult.Sink
			end
            
            if CombatHandler.attackTrack == nil and MovementHandler.isSprinting and MovementHandler.shiftHeld == true then
                humanoid.WalkSpeed = 36
            end

            if CombatHandler.attackTrack ~= nil then
                humanoid.WalkSpeed = 16
            end

            if CombatHandler.blockTrack ~= nil then
                humanoid.WalkSpeed = 5
				MovementHandler.isSprinting = false

				sprintMaid:Destroy()
            end
		end))

		MovementHandler.isSprinting = true
		MovementHandler.shiftHeld = true

        if CombatHandler.attackTrack == nil then
			humanoid.WalkSpeed = 36
        end
	end
	return Enum.ContextActionResult.Sink
end

function MovementHandler.dash(inputName, userInputState)
	local character = player.Character
    local humanoid = character.Humanoid

	if character == nil or humanoid == nil then
		return Enum.ContextActionResult.Pass
	end

	if CombatHandler.blockTrack then
		return Enum.ContextActionResult.Sink
	end

	if userInputState == Enum.UserInputState.Begin then
		local moveDirection = MovementHandler.movementInfo.hrpMoveVelocity.Unit
		local dashForce = Vector3.new(
			math.abs(math.round(moveDirection.X)) == math.abs(math.round(moveDirection.Z))
					and math.round(moveDirection.X) * 0.65
				or math.round(moveDirection.X),
			0,
			math.abs(math.round(moveDirection.Z)) == math.abs(math.round(moveDirection.X))
					and math.round(moveDirection.Z) * 0.65
				or math.round(moveDirection.Z)
		)

        local nanOrInf = (dashForce.Magnitude ~= dashForce.Magnitude == true) or (dashForce.Magnitude == math.huge)

        if MovementHandler.dashDebounce == true or nanOrInf == true then return Enum.ContextActionResult.Sink end

        MovementHandler.dashDebounce = true
        task.delay(MovementHandler.dashCD, function()
            MovementHandler.dashDebounce = false
        end)

		if MovementHandler.shiftHeld == true then
            local impulseController = CharacterPhysics:ContinuousImpulse(character, {
                applyGravity = true,
                maxForce = 100000,
                velocityFunction = function()
				    return ControlModule.inputMoveVector * 60
                end
            })

			impulseController:Play()
			humanoid.JumpPower = 0

            MovementHandler.isFlashsteping = true
			SendEffect:Fire("flashstep")
			task.delay(0.5, function()
                impulseController:Stop()

                if character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude < 0.1 or 1.8 <= math.abs(MovementHandler.hrpMoveYaw) then
                    humanoid.WalkSpeed = 16
                end

                if MovementHandler.isSprinting == false then
					humanoid.WalkSpeed = 16
                end

			    humanoid.JumpPower = 70
                MovementHandler.isFlashsteping = false
			end)
			ClientEffects:flashstep(character, {
				duration = 0.5,
			})
		else
			local dashImpulse = CharacterPhysics:Impulse(character, {
				vectorVelocity = dashForce * game.Workspace.vectorVelocity.Value,
				maxForce = game.Workspace.maxForce.Value,
				duration = game.Workspace.duration.Value,
				velocityDecayRate = game.Workspace.velocityDecayRate.Value,
				maxForceDecayRate = game.Workspace.maxForceDecayRate.Value,
				applyGravity = true,
			})
            dashImpulse:Play()

            MovementHandler.dashTrack = humanoid.Animator:LoadAnimation(MovementHandler.characterAnimations[`{ScriptUtils:Snap90(moveDirection)}Dash`])
            MovementHandler.dashTrack:Play(0.1)
        end
	end
	return Enum.ContextActionResult.Sink
end

function MovementHandler:SetupMobile()
    local actionButton = ContextActionService:GetButton("sprint")
end

function MovementHandler:SetupAnimations(character, setup)
    if setup then
		task.delay(1, function()
			local humanoid = character:WaitForChild("Humanoid")
			local animator = humanoid:WaitForChild("Animator")

			MovementHandler.walkTrack = animator:LoadAnimation(MovementHandler.walkAnimation)
			MovementHandler.runTrack = animator:LoadAnimation(MovementHandler.runAnimation)

			MovementHandler.walkTrack:Play(0)
			MovementHandler.runTrack:Play(0)

			MovementHandler.walkTrack:AdjustSpeed(0)
			MovementHandler.runTrack:AdjustSpeed(0)

			MovementHandler:SetupMovementAnimations(character)
		end)
    else
		local humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")

        if MovementHandler.walkTrack ~= nil then
            MovementHandler.walkTrack:Stop(0.33)
            MovementHandler.runTrack:Stop(0.33)
        end

		MovementHandler.walkTrack = animator:LoadAnimation(MovementHandler.walkAnimation)
		MovementHandler.runTrack = animator:LoadAnimation(MovementHandler.runAnimation)

		MovementHandler.walkTrack:Play(0.33)
		MovementHandler.runTrack:Play(0.33)

        MovementHandler:SetupMovementAnimations(character)
    end
end

function MovementHandler:SetupMovementAnimations(character)
	local humanoid = character:WaitForChild("Humanoid")
    local animator = humanoid:WaitForChild("Animator")

    MovementHandler.movementMaid:DoCleaning()

    local function swapIdle()
        if MovementHandler.idleTrack ~= nil then
            MovementHandler.idleTrack:Stop(0.1)
            MovementHandler.idleTrack = nil
        end

        local chosenIdleAnimation = MovementHandler.idleAnimations[math.random(1, #MovementHandler.idleAnimations)]

        MovementHandler.idleTrack = animator:LoadAnimation(chosenIdleAnimation)
        MovementHandler.idleTrack:Play(0.1)
    end

    swapIdle()

    local stopped = true

    MovementHandler.movementMaid:GiveTask(humanoid.Running:Connect(function(speed)
        if speed < 1 then
            stopped = true
        else
            stopped = false
        end

        if stopped == false then
            swapIdle()
        end

        if MovementHandler.fallTrack ~= nil then
            MovementHandler.fallTrack:Stop(0.1)
            MovementHandler.fallTrack = nil

            animator:LoadAnimation(MovementHandler.landAnimation):Play(0.1)
        end
    end))

    MovementHandler.movementMaid:GiveTask(humanoid.Jumping:Connect(function()
        animator:LoadAnimation(MovementHandler.jumpAnimation):Play(0.1)
    end))

	MovementHandler.movementMaid:GiveTask(humanoid.FreeFalling:Connect(function()
        if MovementHandler.fallTrack ~= nil then
            MovementHandler.fallTrack:Stop(0.1)
        end

		MovementHandler.fallTrack = animator:LoadAnimation(MovementHandler.fallAnimation)
        MovementHandler.fallTrack:Play(0.1)
	end))

end

function MovementHandler:UpdateRunWalkMovement()
    if MovementHandler.walkTrack == nil or MovementHandler.runTrack == nil then return end
    ----------------------------------------------------------------
    -- 1.  velocity in HumanoidRootPart-local space
    --     (stored each RenderStepped in your main loop)
    ----------------------------------------------------------------
    local localVel = MovementHandler.movementInfo.hrpMoveVelocity
    local speed    = localVel.Magnitude              -- always positive

    ----------------------------------------------------------------
    -- 2.  stop-motion when almost idle
    ----------------------------------------------------------------

    if speed < 0.05 then
        MovementHandler.walkTrack:AdjustWeight(0.01, 0.1)
        MovementHandler.walkTrack:AdjustSpeed(0)

        MovementHandler.runTrack:AdjustWeight(0.01, 0.1)
        MovementHandler.runTrack:AdjustSpeed(0)
        return
    end

    local runBlend   = math.clamp((speed - 16) / 10, 0, 1)
    local walkScale  = ScriptUtils:Map(speed, 0, 16, 0, 1.1)
    local runScale   = ScriptUtils:Map(speed, 16, 26, 0.01, 1.16)

    MovementHandler.walkTrack:AdjustWeight(math.clamp(1 - runBlend, 0.01, 1), 0.1)
    MovementHandler.runTrack :AdjustWeight(math.clamp(runBlend, 0.01, 1), 0.1)

    local dirSign = (localVel.Z > 1) and -1 or 1      -- tweak 0.05 dead-zone

    MovementHandler.walkTrack:AdjustSpeed(dirSign * math.clamp(walkScale, 0.01, 1.1))
    MovementHandler.runTrack :AdjustSpeed(dirSign * math.clamp(runScale , 0.01, 1.16))
end

function MovementHandler:SetupAdvancedControl(character)
    MovementHandler.currentCharacter.humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
    MovementHandler.currentCharacter.humanoid = character.Humanoid

    MovementHandler.currentCharacter.head = character.Head
    MovementHandler.currentCharacter.torso = character.Torso
    MovementHandler.currentCharacter.neck = character.Torso.Neck
    MovementHandler.currentCharacter.waist = character.HumanoidRootPart.RootJoint

    MovementHandler.currentCharacter.rHip = character.Torso["Right Hip"]
    MovementHandler.currentCharacter.lHip = character.Torso["Left Hip"]

    MovementHandler.rHipOriginC0 = character.Torso["Right Hip"].C0
    MovementHandler.lHipOriginC0 = character.Torso["Left Hip"].C0

    MovementHandler.neckOriginC0 = character.Torso.Neck.C0
    MovementHandler.waistOriginC0 = character.HumanoidRootPart.RootJoint.C0

    MovementHandler.currentCharacter.neck.MaxVelocity = 0.33
end

function MovementHandler:AdvancedControl()
    local humanoidRootPart = MovementHandler.currentCharacter.humanoidRootPart

    local torso = MovementHandler.currentCharacter.torso
    local head = MovementHandler.currentCharacter.head

    local neck = MovementHandler.currentCharacter.neck
    local waist = MovementHandler.currentCharacter.waist

    local rHip = MovementHandler.currentCharacter.rHip
    local lHip = MovementHandler.currentCharacter.lHip

    local neckOriginC0 = MovementHandler.neckOriginC0
    local waistOriginC0 = MovementHandler.waistOriginC0

    local rHipOriginC0 = MovementHandler.rHipOriginC0
    local lHipOriginC0 = MovementHandler.lHipOriginC0

    local torsoLookVector = torso.CFrame.LookVector
    local headPosition = head.CFrame.Position
    MovementHandler.cameraLookPoint = camera.CFrame.Position + (camera.CFrame.LookVector * 30)

    local distance = (head.CFrame.Position - MovementHandler.cameraLookPoint).magnitude
    local difference = head.CFrame.Y - MovementHandler.cameraLookPoint.Y

    local goalNeckCFrame = CFrame.Angles(-(math.atan(difference / distance) * MovementHandler.headStrength), (((headPosition - MovementHandler.cameraLookPoint).Unit):Cross(torsoLookVector)).Y * 1, 0)
	neck.C0 = neck.C0:lerp(goalNeckCFrame * neckOriginC0, 0.25).Rotation + neckOriginC0.Position

    local xAxisWaistRotation = -(math.atan(difference / distance) * 0.5)
	local yAxisWaistRotation = (((headPosition - MovementHandler.cameraLookPoint).Unit):Cross(torsoLookVector)).Y * 0.5
	local rotationWaistCFrame = CFrame.Angles(xAxisWaistRotation, yAxisWaistRotation, 0)
	local goalWaistCFrame = rotationWaistCFrame * waistOriginC0
	waist.C0 = waist.C0:lerp(goalWaistCFrame, MovementHandler.torsoStrength).Rotation + waistOriginC0.Position

    local currentLegCounterCFrame = waist.C0 * waistOriginC0:Inverse()
    local legsCounterCFrame = currentLegCounterCFrame:Inverse()

    local localVel = MovementHandler.movementInfo.hrpMoveVelocity
    local speed = localVel.Magnitude

    if speed < 0.05 then
        rHip.C0 = rHip.C0:Lerp(legsCounterCFrame * rHipOriginC0, 0.35)
        lHip.C0 = lHip.C0:Lerp(legsCounterCFrame * lHipOriginC0, 0.35)
        return
    end
    
    MovementHandler.hrpMoveYaw = math.atan2(-localVel.X , -localVel.Z)
    local clampedYawInverted =  math.clamp(math.atan2(localVel.X , localVel.Z), -0.785, 0.785)
    local clampedYaw = math.clamp(math.atan2(-localVel.X , -localVel.Z), -0.785, 0.785)

    local yawFactor  = 1.6 >= math.abs(MovementHandler.hrpMoveYaw) and math.abs(MovementHandler.hrpMoveYaw) >= 0.79 and 0.5 or 0.3 --How much the legs twist

    local rightTwist = CFrame.Angles(0, (-1.6 <= MovementHandler.hrpMoveYaw and MovementHandler.hrpMoveYaw <= 1.6 and clampedYaw or clampedYawInverted) * yawFactor, 0)
    local leftTwist  = CFrame.Angles(0, (-1.6 <= MovementHandler.hrpMoveYaw and MovementHandler.hrpMoveYaw <= 1.6 and clampedYaw or clampedYawInverted) * yawFactor , 0)

    rHip.C0 = rHip.C0:lerp(legsCounterCFrame * (rHipOriginC0 * rightTwist), 0.05)
    lHip.C0 = lHip.C0:lerp(legsCounterCFrame * (lHipOriginC0 * leftTwist), 0.05)
end

function MovementHandler:Tilt(character)
    if character and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart:FindFirstChild("RootJoint") then
        local movementVector = character.HumanoidRootPart.CFrame:VectorToObjectSpace(character.HumanoidRootPart.Velocity / math.max(character.Humanoid.WalkSpeed, 0.01))

        MovementHandler.tiltZ = math.clamp(ScriptUtils:Lerp(MovementHandler.tiltZ, movementVector.X, 1), -MovementHandler.maxTilt, MovementHandler.maxTilt)
        MovementHandler.tiltX = math.clamp(ScriptUtils:Lerp(MovementHandler.tiltX, math.clamp(-movementVector.Z, -1, 1), 1), -MovementHandler.maxTilt, MovementHandler.maxTilt)
        
        character.HumanoidRootPart.RootJoint.C1 = character.HumanoidRootPart.RootJoint.C1:Lerp(MovementHandler.waistOriginC0 * CFrame.Angles(-MovementHandler.tiltX, MovementHandler.tiltZ, 0), MovementHandler.tiltSpeed)
    end
end

task.spawn(function()
    CombatHandler:PassMovement(MovementHandler)

    MovementHandler.sprintKey:set(Replication:GetInfo("Data").keybinds.sprint.keyCode)
    MovementHandler.toggleSprint:set(Replication:GetInfo("Data").settings.toggleSprint.value or UserInputService.TouchEnabled)
    MovementHandler.currentWeapon:set(Replication:GetInfo("Data").equipment.weapon)

    Replication:GetInfo("Data", true):ListenToChange({"keybinds"}, function(newValue)
        MovementHandler.sprintKey:set(newValue.sprint.keyCode)
    end)

    Replication:GetInfo("Data", true):ListenToChange({"settings"}, function(newValue)
        MovementHandler.toggleSprint:set(newValue.toggleSprint.value or UserInputService.TouchEnabled)
    end)

    Replication:GetInfo("Data", true):ListenToChange({"equipment", "weapon"}, function(newValue)
        MovementHandler.currentWeapon:set(newValue)

        if newValue.weapon == nil then
			MovementHandler.walkAnimation = MovementHandler.characterAnimations.Walk
			MovementHandler.runAnimation = MovementHandler.characterAnimations.Run
            MovementHandler.idleAnimations = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Idles:GetChildren()
            MovementHandler:SetupAnimations(player.Character)
        else
            MovementHandler.walkAnimation = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Walk
            MovementHandler.runAnimation = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Run
            MovementHandler.idleAnimations = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Idles:GetChildren()
			MovementHandler:SetupAnimations(player.Character)
        end
    end)

    Replication:GetInfo("States", true):ListenToChange({"weapon", "isEquipped"}, function(newValue)
        if newValue then
            MovementHandler.walkAnimation = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Walk
            MovementHandler.runAnimation = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Run
            MovementHandler.idleAnimations = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Idles:GetChildren()
            MovementHandler:SetupAnimations(player.Character)
        else
            MovementHandler.walkAnimation = MovementHandler.characterAnimations.Walk
            MovementHandler.runAnimation = MovementHandler.characterAnimations.Run
            MovementHandler.idleAnimations = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[MovementHandler.currentWeapon:get()].Idles:GetChildren()
            MovementHandler:SetupAnimations(player.Character)
        end
    end)

    local character = player.Character or player.CharacterAdded:Wait()

    MovementHandler:SetupAdvancedControl(character)
    MovementHandler:SetupAnimations(character)

    player.CharacterAdded:Connect(function(newCharacter)
        MovementHandler:SetupAdvancedControl(newCharacter)
        MovementHandler:SetupAnimations(newCharacter)
    end)

    RunService.RenderStepped:Connect(function(dt)
        local character, humanoidRootPart = player.Character, player.Character and player.Character:FindFirstChild("HumanoidRootPart")

        if character and humanoidRootPart then
            MovementHandler.movementInfo.hrpLookVector = humanoidRootPart.CFrame.LookVector
            MovementHandler.movementInfo.hrpLinearVelocity = ScriptUtils:FlatVec3(humanoidRootPart.AssemblyLinearVelocity)
            MovementHandler.movementInfo.hrpMoveVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(MovementHandler.movementInfo.hrpLinearVelocity)

            Gizmo.PushProperty("Color3", Color3.fromRGB(0, 255, 0))
            Gizmo.Arrow:Draw(humanoidRootPart.Position, humanoidRootPart.Position + MovementHandler.movementInfo.hrpLookVector * 2, 0.1, 0.5, 5)
            Gizmo.PopProperty("Color3")

            Gizmo.PushProperty("Color3", Color3.fromRGB(255, 0, 0))
            Gizmo.Arrow:Draw(humanoidRootPart.Position, humanoidRootPart.Position + MovementHandler.movementInfo.hrpLinearVelocity * 0.2, 0.1, 0.5, 5)
            Gizmo.PopProperty("Color3")


            MovementHandler:Tilt(character)
            MovementHandler:AdvancedControl()
            MovementHandler:UpdateRunWalkMovement()
        end
    end)
end)

return MovementHandler