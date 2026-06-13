local Players = game:GetService("Players")
local NetworkUtils = require(script.Parent.NetworkUtils)
local HumanoidUtils = {}

function HumanoidUtils.loadBaseHumanoidDescription(player: Player): HumanoidDescription
    -- Dangerous to run a brute force call but this is an internal API call. AFAIK if the internal call fails 
    -- it would mean that roblox went down. If roblox was to be down we'd have bigger fish to fry than a simple call no?
    local _, humanoidDescription = NetworkUtils.brutePcall(function(...)
        return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId);
    end)

    return humanoidDescription;
end


return HumanoidUtils;