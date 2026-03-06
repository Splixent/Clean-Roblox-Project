local Shared = game:GetService("ReplicatedStorage").Shared
local SoundService = game:GetService("SoundService")

local Janitor = require(Shared.Packages.Janitor)

local SoundManager = {}

function SoundManager.new(properties: any): Sound
    local Sound = Instance.new("Sound")
    for propertyName, propertyValue in pairs (properties) do
        if propertyName == "SoundGroup" then
            Sound[propertyName] = SoundService[propertyValue]
        elseif propertyName == "Parent" then
            if typeof(propertyValue) == "string" then
                Sound[propertyName] = SoundService[propertyValue]
            else
                Sound[propertyName] = propertyValue
            end
        else
            Sound[propertyName] = propertyValue
        end
    end

    return Sound
end

function SoundManager.createPlayDestroy(properties: any)
    local sound = SoundManager.new(properties)
    local janitor = Janitor.new()

    sound:Play()

    janitor:Add(sound.Ended:Connect(function()
        sound:Destroy()
        janitor:Destroy()
    end))
end

return SoundManager