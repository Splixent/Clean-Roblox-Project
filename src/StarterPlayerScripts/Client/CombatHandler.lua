local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Replication = require(Client.Replication)
local Fusion = require(Shared.Fusion)
local Maid = require(Shared.Maid)
local Events = require(Shared.Events)
local Hitbox = require(Shared.Hitbox)
local WeaponData = require(Shared.WeaponData)

local Value = Fusion.Value

local player = Players.LocalPlayer

local RequestAttack = Events.RequestAttack:Client()
local RequestHit = Events.RequestHit:Client()
local RequestBlock = Events.RequestBlock:Client()

local MovementHandler

local CombatHandler = {
    currentWeapon = Value(),
    weaponEquipped = Value(false),

    attackMaid = Maid.new(),

    attackTrackPlaying = false,
    tempStopped = false,
    m1Down = false,

    attackTrack = nil,
    attackQueued = false,

    cooldownStart = 0,

    attackTweens = {},

    queueWindowOpen = false,

    blockTrack = nil,

    parryCooldown = 1,
    lastParry = 0,
}

function CombatHandler:m1(userInputState)
    if userInputState == Enum.UserInputState.Begin then
        CombatHandler.m1Down = true

        if MovementHandler.isFlashsteping then
            return Enum.ContextActionResult.Sink               
        end

        if CombatHandler.blockTrack then
            return Enum.ContextActionResult.Sink
        end

        if tick() - CombatHandler.cooldownStart < WeaponData[CombatHandler.currentWeapon:get()].basicAttackCooldown then
            print("ATTACK_COOLDOWN")
            return Enum.ContextActionResult.Sink
        end

		if CombatHandler.tempStopped == false then
            if CombatHandler.queueWindowOpen then
                print("ATTACK_QUEUED")
                CombatHandler.attackQueued = true
            end
		end

        if CombatHandler.attackTrack == nil then
            CombatHandler:BasicAttack()
        elseif CombatHandler.tempStopped then
            print('ATTACK_RESUMED')
			CombatHandler.tempStopped = false
			CombatHandler:ClearTweens()

			CombatHandler.attackTrack:AdjustSpeed(1)
			CombatHandler.attackTrack:AdjustWeight(1)
        end

        return Enum.ContextActionResult.Sink
    end

    if userInputState == Enum.UserInputState.End then
		CombatHandler.m1Down = false
        return Enum.ContextActionResult.Sink
    end
end

function CombatHandler:block(userInputState)
    CombatHandler.blockHeld = true

    if userInputState == Enum.UserInputState.Begin then
        if CombatHandler.attackTrackPlaying or MovementHandler.isFlashsteping then
            local heldMaid = Maid.new()
            heldMaid:GiveTask(RunService.Stepped:Connect(function()
                if CombatHandler.attackTrackPlaying == false and MovementHandler.isFlashsteping == false then
                    if CombatHandler.blockHeld then
                        CombatHandler:Block()
                    end
                    heldMaid:Destroy()
                end
            end))
            return Enum.ContextActionResult.Sink
        end

        if CombatHandler.blockTrack then
			RequestBlock:Fire(0)

			CombatHandler.blockTrack:Stop(0.25)
			CombatHandler.blockTrack = nil
        end

        CombatHandler:Block()
    end

	if userInputState == Enum.UserInputState.End then
        CombatHandler.blockHeld = false

        if CombatHandler.blockTrack then
            RequestBlock:Fire(0)

            CombatHandler.blockTrack:Stop(0.25)
            CombatHandler.blockTrack = nil

			local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")

            if character and humanoid then
                humanoid.WalkSpeed = 16
            end
        end
    end
end

function CombatHandler:BasicAttack()
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    local animator = humanoid:FindFirstChild("Animator")

    if humanoid and animator and CombatHandler.weaponEquipped:get() then
		CombatHandler.tempStopped = false
        CombatHandler.attackMaid:DoCleaning()

        local weaponType = CombatHandler.currentWeapon:get()
        CombatHandler.attackTrack = animator:LoadAnimation(ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[weaponType].LightAttack)

        CombatHandler.attackMaid:GiveTask(CombatHandler.attackTrack:GetMarkerReachedSignal("End"):Connect(function(attackNumber)
			CombatHandler.queueWindowOpen = false

            if CombatHandler.attackQueued and tonumber(attackNumber) ~= #WeaponData[weaponType].basicAttack then
                CombatHandler.attackQueued = false
				CombatHandler:ClearTweens()

                CombatHandler.attackTrack:AdjustSpeed(1)
                CombatHandler.attackTrack:AdjustWeight(1)
            else
                if CombatHandler.attackTrack and CombatHandler.m1Down == false then
				    CombatHandler:ClearTweens()

                    table.insert(CombatHandler.attackTweens, CombatHandler:TweenAnimationProperty(CombatHandler.attackTrack, "Speed", 0.25, 1, 0, Enum.EasingStyle.Circular, Enum.EasingDirection.Out))
                    table.insert(CombatHandler.attackTweens, CombatHandler:TweenAnimationProperty(CombatHandler.attackTrack, "Weight", 0.25, 1, 0.01, Enum.EasingStyle.Circular, Enum.EasingDirection.Out))

                    if tonumber(attackNumber) ~= #WeaponData[weaponType].basicAttack then
					    CombatHandler.tempStopped = true
                    else
                        CombatHandler.tempStopped = false
                    end

					task.delay(WeaponData[weaponType].maxDelay, function()
						if CombatHandler.tempStopped == true then
							CombatHandler.attackTrackPlaying = false
							CombatHandler.attackTrack:Stop(0.25)
							CombatHandler.attackTrack = nil
							CombatHandler.attackMaid:DoCleaning()
						end
					end)
                end
            end

            if tonumber(attackNumber) == #WeaponData[weaponType].basicAttack then
                CombatHandler.cooldownStart = tick()
				CombatHandler.attackTrackPlaying = false
				CombatHandler.attackTrack:Stop(0.25)
				CombatHandler.attackTrack = nil
                CombatHandler.attackMaid:DoCleaning()

                task.delay(WeaponData[CombatHandler.currentWeapon:get()].basicAttackCooldown, function()
                    if CombatHandler.m1Down then
                        CombatHandler:BasicAttack()
                    end
                end)
            end
        end))

        CombatHandler.attackMaid:GiveTask(CombatHandler.attackTrack:GetMarkerReachedSignal("Stop"):Connect(function()
            CombatHandler.attackTrackPlaying = false
            CombatHandler.attackTrack:Stop(0.25)
            CombatHandler.attackTrack:AdjustSpeed(0)

            CombatHandler.attackMaid:DoCleaning()

            if CombatHandler.m1Down then
                CombatHandler:BasicAttack()
            end
        end))

        CombatHandler.attackMaid:GiveTask(CombatHandler.attackTrack:GetMarkerReachedSignal("RequestAttack"):Connect(function(attackNumber)
            if CombatHandler.tempStopped == false then
                RequestAttack:Fire(DateTime.now().UnixTimestampMillis / 1000, {attackType = "BasicAttack", attackNumber = tonumber(attackNumber)})
            end
        end))

        CombatHandler.attackMaid:GiveTask(CombatHandler.attackTrack:GetMarkerReachedSignal("Attack"):Connect(function(attackNumber)
            CombatHandler.queueWindowOpen = true
            CombatHandler.currentHitbox = Hitbox.new(table.clone(WeaponData[weaponType].basicAttack[tonumber(attackNumber)]), {
                attackNumber = tonumber(attackNumber),
                onHit = CombatHandler.BasicAttackOnHit,
                attachTarget = character,
                ignoreList = {character},
                startTime = tick(),
            })
            CombatHandler.currentHitbox:Play()
        end))

        CombatHandler.attackMaid:GiveTask(CombatHandler.attackTrack:GetMarkerReachedSignal("AttackEnd"):Connect(function()
            if CombatHandler.currentHitbox then
                CombatHandler.currentHitbox:Destroy()
                CombatHandler.currentHitbox = nil
            end
        end))

        CombatHandler.attackTrack:Play(0.33)
        CombatHandler.attackTrackPlaying = true
    end
end

function CombatHandler:Block()
	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	local animator = humanoid:FindFirstChild("Animator")

    if humanoid and animator and CombatHandler.weaponEquipped:get() then
        local weaponType = CombatHandler.currentWeapon:get()
        local isParry = false

        CombatHandler.blockTrack = animator:LoadAnimation(ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[weaponType].Block)

        if tick() - CombatHandler.lastParry > CombatHandler.parryCooldown then
            isParry = true
			CombatHandler.lastParry = tick()
            CombatHandler.parryTrack = animator:LoadAnimation(ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations[weaponType].ParryBlock)
        end

        if isParry then
            print("Parry Block")
            CombatHandler.parryTrack:Play(0.1)
        end

		humanoid.WalkSpeed = 5
		RequestBlock:Fire(DateTime.now().UnixTimestampMillis / 1000)
		CombatHandler.blockTrack:Play(0.1)
    end
end

function CombatHandler.BasicAttackOnHit(hitData)
    RequestHit:Fire(hitData.hitCharacter, hitData.timeStamp)
end

function CombatHandler:CriticalAttack()
    
end

function CombatHandler:TweenAnimationProperty(animationTrack, property, duration, startValue, targetValue, easingStyle, easingDirection)
    if not animationTrack then return end
    
    local TweenService = game:GetService("TweenService")
    startValue = startValue or 1
    targetValue = targetValue or 0
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    easingDirection = easingDirection or Enum.EasingDirection.Out
    
    -- Create a dummy object to tween
    local dummy = Instance.new("NumberValue")
    dummy.Name = "AnimationTweener"
    dummy.Value = startValue
    
    -- Create tween info
    local tweenInfo = TweenInfo.new(
        duration,
        easingStyle,
        easingDirection
    )
    
    -- Create the tween
    local tween = TweenService:Create(
        dummy,
        tweenInfo,
        {Value = targetValue}
    )
    
    -- Connect to the change event
    local connection
    connection = dummy:GetPropertyChangedSignal("Value"):Connect(function()
        if property == "Weight" then
            animationTrack:AdjustWeight(dummy.Value)
        elseif property == "Speed" then
            animationTrack:AdjustSpeed(dummy.Value)
        end
    end)
    
    -- Clean up when tween completes
    tween.Completed:Connect(function()
        connection:Disconnect()
        dummy:Destroy()
    end)
    
    tween:Play()
    
    return tween
end

function CombatHandler:ClearTweens()
    for _, tween in ipairs(CombatHandler.attackTweens) do
        if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
            tween:Cancel()
        end
    end
end

function CombatHandler:PassMovement(movementModule)
    MovementHandler = movementModule
end

task.spawn(function()
    CombatHandler.currentWeapon:set(Replication:GetInfo("Data").equipment.weapon)
    CombatHandler.weaponEquipped:set(Replication:GetInfo("States").weapon.isEquipped)

    Replication:GetInfo("States", true):ListenToChange({ "weapon", "isEquipped" }, function(newValue)
        CombatHandler.weaponEquipped:set(newValue)
    end)

	Replication:GetInfo("Data", true):ListenToChange({ "equipment", "weapon" }, function(newValue)
		CombatHandler.currentWeapon:set(newValue)
	end)
end)

return CombatHandler