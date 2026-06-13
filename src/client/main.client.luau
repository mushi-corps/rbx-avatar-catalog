-- Credits to: "bryan250420" (same username for both discord & roblox)
-- Coded on Visual Studio Code using Rojo

-- === Imports ===
local AvatarEditorService = game:GetService("AvatarEditorService");
local ContentProvider = game:GetService("ContentProvider");
local ReplicatedStorage = game:GetService("ReplicatedStorage");

local Players = game:GetService("Players");
local UserInputService = game:GetService("UserInputService");
local TweenService = game:GetService("TweenService");

local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes);
local HumanoidUtils = require(ReplicatedStorage.Shared.util.HumanoidUtils);
local NetworkUtils = require(ReplicatedStorage.Shared.util.NetworkUtils);

-- === Variables ===
local isCatalogOpen: boolean = false;
local isPreviewing: boolean = false;
local searchToken: number = 0;

local baseHumanoidDescription: HumanoidDescription? = nil;

-- === Constants ===
local OPEN_CATALOG_KEY: Enum.KeyCode = Enum.KeyCode.E;

local FADE_TWEEN_SETTINGS: TweenInfo = TweenInfo.new(0.375, Enum.EasingStyle.Quart, Enum.EasingDirection.Out);
local BACKDROP_FADE_TWEEN_SETTINGS: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

local OPEN_CATALOG_TWEEN_SETTINGS =  {UDim2.new(0.5, 0, 0.5, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.35, true}
local PREVIEW_CATALOG_TWEEN_SETTINGS =  {UDim2.new(0.5, 0, 1.3, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.35, true}
local CLOSE_CATALOG_TWEEN_SETTINGS =  {UDim2.new(0.5, 0, 1.5, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.35, true}

-- === References ===
local EquipAssetEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Catalog").Events.EquipAssetEvent;

local player: Player = Players.LocalPlayer;
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui;
local mainGui = playerGui:WaitForChild("MainGui") :: ScreenGui; 

local openCatalogButton: TextButton = mainGui:WaitForChild("OpenCatalogButton") :: TextButton;
local avatarCatalog: Frame = mainGui:WaitForChild("AvatarCatalogContainer") :: Frame;

-- Little workaround to assign types without having to cast every single item, only used once
local ui = avatarCatalog :: any;
local actions = ui.Actions;

local quickSearchButtons: { TextButton } = actions.Bottom:GetChildren();
local searchCatalogBar: TextBox = actions.Top.SearchBar;
local searchCatalogButton: TextButton = actions.Top.SearchButton;
local closeCatalogButton: TextButton = actions.Top.CloseButton;

local catalogItemList: ScrollingFrame = ui.ItemList;
local catalogSkeletonList: ScrollingFrame = ui.SkeletonList;

local templateItem: CatalogTypes.CatalogItemUI = ReplicatedStorage:WaitForChild("Catalog").UI.CatalogItem;
-- Hehe dumb luau interpretator doesn't know the skeleton version has skeleton-specific elements
local skeletonCatalogItem: CatalogTypes.CatalogItemUI = ReplicatedStorage:WaitForChild("Catalog").UI.SkeletonCatalogItem;

local backdrop: Frame = mainGui:WaitForChild("Backdrop") :: Frame;

-- === Instances ===
local backdropFadeIn: Tween = TweenService:Create(backdrop, BACKDROP_FADE_TWEEN_SETTINGS, { BackgroundTransparency = 0.5 })
local backdropFadeOut: Tween = TweenService:Create(backdrop, BACKDROP_FADE_TWEEN_SETTINGS, { BackgroundTransparency = 1 })

-- === Functions ===
local function getCharacter() : Model
    return player.Character or player.CharacterAdded:Wait()
end

local function setBackdrop(visible: boolean)
    if (visible) then 
        backdropFadeIn:Play();
    else
        backdropFadeOut:Play();
    end        
end

local function setCatalogVisibility(open: boolean)
    isCatalogOpen = open;

    -- I wish I had regular people ternariesuhhh
    local settings = if isCatalogOpen then OPEN_CATALOG_TWEEN_SETTINGS else CLOSE_CATALOG_TWEEN_SETTINGS;

    -- Have to use table.unpack for the table objects to be used as params correctly
    avatarCatalog:TweenPosition(table.unpack(settings));
    setBackdrop(isCatalogOpen);
end

local function setCatalogPreviewing(preview: boolean)
    isPreviewing = preview;

    if (isPreviewing) then
        avatarCatalog:TweenPosition(table.unpack(PREVIEW_CATALOG_TWEEN_SETTINGS))

        setBackdrop(false);
    else
        setCatalogVisibility(true);
    end
end

local function showSkeleton(show: boolean)
    catalogSkeletonList.Visible = show;
    catalogItemList.Visible = not show;
end

local function createPreviewHumanoid(catalogItem: CatalogTypes.CatalogItemUI, previewCharacter: Model)
    local viewportFrame = Instance.new("ViewportFrame")
    viewportFrame.Name = "item_preview";
    -- Start the viewport frame off screen
    viewportFrame.Position = UDim2.fromScale(0, 1);
    viewportFrame.Size = UDim2.fromScale(1, 1);
    viewportFrame.BackgroundColor3 = Color3.fromRGB(25, 26, 31);
    viewportFrame.ImageTransparency = 1;
    viewportFrame.ZIndex = 5;
    viewportFrame.Parent = catalogItem.Image;

    local viewportCamera = Instance.new("Camera");
    viewportCamera.CFrame = CFrame.new(Vector3.new(0, -0.6, 5.25))
    viewportCamera.Parent = viewportFrame;
    viewportFrame.CurrentCamera = viewportCamera;

    local worldModel = Instance.new("WorldModel");
    worldModel.Parent = viewportFrame;

    previewCharacter:PivotTo(CFrame.new(0,0,0) * CFrame.Angles(0, math.rad(160), 0));
    previewCharacter.Parent = worldModel;

    -- Tween the viewport frame in
    local targetProperties = {
        Position = UDim2.fromScale(0, 0),
        ImageTransparency = 0
    }
    local fadeInTween = TweenService:Create(viewportFrame, FADE_TWEEN_SETTINGS, targetProperties);
    fadeInTween:Play();
end

local function generatePreviewHumanoid(catalogItem: CatalogTypes.CatalogItemUI, assetId: number, currentSearchToken: number)
    -- TODO: Just cancel the task directly and cleanup if the user makes another search.
     
    if (not baseHumanoidDescription) then
        baseHumanoidDescription = HumanoidUtils.loadBaseHumanoidDescription(player);
    end

    -- Since we brute force the above call, we can cast without worries
    local description = (baseHumanoidDescription :: HumanoidDescription):Clone();
    -- Too busy at the moment to code asset type selection, hardcoded shirts will do for now.
    description.Shirt = assetId;
    
    -- If the results of this search are from an outdated search then destroy and bury them 1000 feet underground 
    if (searchToken ~= currentSearchToken) then description:Destroy(); return end;

    local humanoid = getCharacter():WaitForChild("Humanoid") :: Humanoid
    
    local success, previewCharacterResponse: Model = NetworkUtils.brutePcall(function(...)
        return Players:CreateHumanoidModelFromDescriptionAsync(description, humanoid.RigType);
    end)
    
    -- Same story as above but this time for both the description and the preview character 
    if (searchToken ~= currentSearchToken) then
        description:Destroy(); 
        if (previewCharacterResponse) then previewCharacterResponse:Destroy(); end

        return 
    end;

    if success and previewCharacterResponse then
        -- Setting the parent to workspace for asset loading to work properly, it is not proper to do it like this
        -- But it will do for the moment.
        -- Also, it's funny how the "preview" humanoids pop in and out of the root of the workspace...
        -- Sadly, clients will probably not like it, I wonder why :(
        previewCharacterResponse.Parent = workspace;
        previewCharacterResponse:PivotTo(CFrame.new(0, 250, 0));
        -- For the application I hide them from view by sending them high up in case the same person who tries in-game
        -- Doesn't read these... or maybe they're not whimsy and rejecte the application due to it :(

        -- Clean way to do this? No. Does it work? Kinda... Not really... -_-
        local instancesToLoad = {}
        for _, item in ipairs(previewCharacterResponse:GetDescendants()) do
            if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Decal") or item:IsA("SpecialMesh") then
                table.insert(instancesToLoad, item);
            end
        end
        
        -- Yield the task until the client has fully downloaded and applied the textures
        pcall(function()
            ContentProvider:PreloadAsync(instancesToLoad);
        end)

        if (searchToken ~= currentSearchToken) then previewCharacterResponse:Destroy() end;

        createPreviewHumanoid(catalogItem, previewCharacterResponse);
    end
end

local function cleanCatalogItems()
    catalogSkeletonList.CanvasPosition = Vector2.new(0,0);
    catalogItemList.CanvasPosition = Vector2.new(0,0);

    for _, child in ipairs(catalogItemList:GetChildren()) do
        if (child:IsA("GuiObject")) then
            child:Destroy()
        end
    end
end

local function searchCatalog(query: string)
    local searchParams = CatalogSearchParams.new()
    searchParams.SearchKeyword = query;
    searchParams.AssetTypes = { Enum.AvatarAssetType.Shirt }
    searchParams.SortType = Enum.CatalogSortType.Relevance;
    searchParams.SortAggregation = Enum.CatalogSortAggregation.PastMonth;
    searchParams.SalesTypeFilter = Enum.SalesTypeFilter.All

    searchToken += 1;
    cleanCatalogItems();
    showSkeleton(true);
    
    local success, catalogResponse: CatalogPages = NetworkUtils.retryingPcall(function(...)
        return AvatarEditorService:SearchCatalogAsync(searchParams);
    end)

    if success then
        if (catalogResponse) then
            local results: { CatalogTypes.CatalogItem } = catalogResponse:GetCurrentPage();
            showSkeleton(false);

            for _, item in ipairs(results) do
                local newItem: CatalogTypes.CatalogItemUI = templateItem:Clone();
                newItem.Image.Image = "rbxthumb://type=Asset&id=" .. item.Id .. "&w=150&h=150"
                newItem.MainContainer.ItemName.Text = item.Name;
                newItem.MainContainer.Creator.Text = item.CreatorName;
                newItem.MainContainer.Content.Price.Text = tostring(item.Price);
                newItem.Parent = catalogItemList;

                newItem.MouseButton1Click:Connect(function()
                    EquipAssetEvent:FireServer(item.Id);
                    setCatalogPreviewing(true);
                end);

                task.spawn(function()
                    generatePreviewHumanoid(newItem, item.Id, searchToken);

                    -- Disable spinner after a small delay to decrease the popping look 
                    task.wait(0.1);
                    newItem.Image.Spinner.Visible = false;
                end);
            end
        else
            warn("No results");
        end
    end
end

-- === Events ===
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
    if gameProcessedEvent then return end;

    if input.KeyCode == OPEN_CATALOG_KEY then
        if (isPreviewing) then
            setCatalogPreviewing(false);
        else
            setCatalogVisibility(not isCatalogOpen);
        end
    end
end)

openCatalogButton.MouseButton1Click:Connect(function()
    setCatalogVisibility(true);
end)

closeCatalogButton.MouseButton1Click:Connect(function()
    setCatalogVisibility(false)
end)

searchCatalogBar.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        searchCatalog(searchCatalogBar.Text);
    end
end)

searchCatalogButton.MouseButton1Click:Connect(function()
    searchCatalog(searchCatalogBar.Text);
end)

for _, item in ipairs(quickSearchButtons) do
    if (item:IsA("TextButton")) then
        item.MouseButton1Click:Connect(function()
            searchCatalogBar.Text = item.Text;
            searchCatalog(item.Text);
        end)
    end
end

-- === Execution ===
local function init()
    -- TODO: Probably improve the skeleton initiation
    for i = 1, 8, 1 do
        local newSkeleton = skeletonCatalogItem:Clone();
        newSkeleton.Parent = catalogSkeletonList;
    end

    -- Initial empty query for (I think) general results
    searchCatalog("")
end

init();