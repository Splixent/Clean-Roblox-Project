local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared

local WeaponData = {
    StarterKatana = {
        basicAttack = {
            {
                cooldown = 1.6,
                attackDelay = 0.367,
                hitDuration = 0.5,
                hitboxes = {
                    {
                        shape = "cube",
                        size = Vector3.one * 6.5,
                        position = CFrame.new(0, 0, 0),
                        offset = CFrame.new(0, 0, -3),
                        
                        duration = 0.5,
                        attachPath = {"HumanoidRootPart"}
                    },
                },
            },
            {
                cooldown = 0.6,
                attackDelay = 0.25,
                hitDuration = 0.5,
                hitboxes = {
                    {
                        shape = "cube",
                        size = Vector3.one * 6.5,
                        position = CFrame.new(0, 0, 0),
                        offset = CFrame.new(0, 0, -3),
                        
                        duration = 0.5,
                        attachPath = {"HumanoidRootPart"}
                    }
                },
            },
            {
                cooldown = 0.6,
                attackDelay = 0.316,
                hitDuration = 0.5,
                hitboxes = {
                    {
                        shape = "cube",
                        size = Vector3.one * 6.5,
                        position = CFrame.new(0, 0, 0),
                        offset = CFrame.new(0, 0, -3),
                        
                        duration = 0.5,
                        attachPath = {"HumanoidRootPart"}
                    }
                },
            },
            {
                cooldown = 0.6,
                attackDelay = 0.267,
                hitDuration = 0.5,
                hitboxes = {
                    {
                        shape = "cube",
                        size = Vector3.one * 6.5,
                        position = CFrame.new(0, 0, 0),
                        offset = CFrame.new(0, 0, -3),
                        
                        duration = 0.5,
                        attachPath = {"HumanoidRootPart"}
                    }
                },
            },
        },
        maxDelay = 0.332,
        basicAttackCooldown = 1,
    },
}



return WeaponData