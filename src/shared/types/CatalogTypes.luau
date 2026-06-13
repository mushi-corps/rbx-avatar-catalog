local CatalogTypes = {};

export type CatalogItem = {
    Id: number,
    ItemType: "Asset" | "Bundle", -- Corresponds to Enum.AvatarItemType
    AssetType: string?,           -- e.g., "Hat", "Shirt" (Only present if ItemType is "Asset")
    BundleType: string?,          -- e.g., "BodyParts" (Only present if ItemType is "Bundle")
    Name: string,
    Description: string,
    ProductId: number,
    Price: number,
    CreatorName: string,
    IsOwned: boolean,
    ItemStatus: { string },       -- e.g., {"New", "Sale"}
    ItemRestrictions: { string }, -- e.g., {"Limited", "LimitedUnique"}
}

export type CatalogItemUI = TextButton & {
    MainContainer: Frame & {
        Content: Frame & {
            Icon: ImageLabel,
            Price: TextLabel
        },
        Creator: TextLabel,
        ItemName: TextLabel
    },
    Image: ImageLabel & {
        Spinner: ImageLabel & {
            Script: LocalScript
        }
    },
}

return CatalogTypes;