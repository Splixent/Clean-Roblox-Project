local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local ScriptUtils = require(Shared.ScriptUtils)
local EffectUtils = require(script.EffectUtils)
local Events = require(Shared.Events)

local vfx = ReplicatedStorage.Assets.VFX

local RecieveEffect = Events.RecieveEffect:Client()

local ClientEffects = {}

function ClientEffects:flashstep(character, settings)
    settings = settings or {
        duration = 0.5,
    }

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart == nil then return end
    local rootAttachment = humanoidRootPart:FindFirstChild("RootAttachment")
    if rootAttachment == nil then return end

    local flashstepVFX = vfx.Flashstep:Clone()
    flashstepVFX.Parent = humanoidRootPart.Parent

    flashstepVFX.Winds.AttachWeld.RigidConstraint.Attachment0 = rootAttachment

    local invisibleObjects = EffectUtils:HideCharacter(character, {flashstepVFX})

    task.spawn(function()
        for _ = 1, 3 do
            for _, particleEmitter in flashstepVFX.FlashstepEffect:GetChildren() do
                particleEmitter:Emit(particleEmitter:GetAttribute("EmitCount") or 1)
            end
            task.wait(settings.duration / 3)
        end
		Debris:AddItem(flashstepVFX, 1)
    end)

    task.spawn(function()
        for count = 1, 12 do
            for _, particleEmitter in ipairs (flashstepVFX[`Step{count % 2 == 0 and "1" or "2"}`].Container:GetChildren()) do
                particleEmitter:Emit(particleEmitter:GetAttribute("EmitCount") or 1)
            end
            for _, particleEmitter in ipairs (flashstepVFX[`Stones{count % 2 == 0 and "1" or "2"}`]:GetChildren()) do
                particleEmitter:Emit(particleEmitter:GetAttribute("EmitCount") or 1)
            end
            task.wait(settings.duration / 12)
        end
    end)

    task.spawn(function()
        for _ = 1, 9 do
			local afterImage = EffectUtils:CreateAfterImage(character)
			local offset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
                        
			for _, part in ipairs(afterImage:GetChildren()) do
				TweenService:Create(
					part,
					TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
					{ Transparency = 1 }
				):Play()
				TweenService:Create(
					part,
					TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
					{ Color = Color3.fromRGB(122, 122, 122) }
				):Play()

				TweenService:Create(
					part,
					TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
					{ CFrame = part.CFrame + offset }
				):Play()
			end

			task.delay(0.5, function()
				afterImage:Destroy()
			end)

            task.wait(settings.duration / 9)
        end
    end)

    task.delay(settings.duration or 0.5, function()
        EffectUtils:ShowCharacter(invisibleObjects)
    end)

    local wind = function()
        for _, windParticle in flashstepVFX.Winds.Winds:GetChildren() do
			windParticle:Emit(windParticle:GetAttribute("EmitCount") or 1)
        end
    end

    wind()

    task.delay(settings.duration, function()
        wind()
    end)
end

RecieveEffect:On(function(effectName, ...)
    print("Recieved effect:", effectName, ...)
    ClientEffects[effectName](effectName, ...)
end)


return ClientEffects