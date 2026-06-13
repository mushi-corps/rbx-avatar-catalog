-- === Imports ===
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkUtils = require(ReplicatedStorage.Shared.util.NetworkUtils)

-- === References ===
local EquipAssetEvent = ReplicatedStorage:WaitForChild("Catalog").Events.EquipAssetEvent;

local function handleEquipRequest(player, assetId)
    local character = player.Character;
    if not character then return end;

    local humanoid = character:FindFirstChildOfClass("Humanoid");
    if not humanoid then return end;

    local success, descriptionResponse = NetworkUtils.retryingPcall(function(...)
        return humanoid:GetAppliedDescription();
    end)

    if success and descriptionResponse then
        descriptionResponse.Shirt = tonumber(assetId);
        
        NetworkUtils.retryingPcall(function(...)
            humanoid:ApplyDescription(descriptionResponse);
        end)
    else
        warn("There was an error applying description to player");
    end
end

EquipAssetEvent.OnServerEvent:Connect(handleEquipRequest);