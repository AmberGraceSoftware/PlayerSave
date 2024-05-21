---
sidebar_position: 3
---
# Incorrect API Usage

PlayerSave's API has a few key limitations to look out for!

## Table Mutations

One core feature of PlayerSave is that all changes to player save data are [Observable](../api/Save#Subscribe). This is achieved by only allowing data to be changed in a player's save via [Setter methods](../api/Save#Set).

*However*, **there are still ways to accidentally modify save data** that the PlayerSave library is not able to observe to at runtime!

:::warning
You should never directly edit a table returned by [`save:Get()`](../api/Save#Get)! For example:

```lua
local inventory = save:Get("Inventory", {})
table.insert(inventory, "Sword") -- Incorrect! `inventory` should not be mutated
save:Set("Inventory", inventory) -- Will throw an error.
```

Mutating a value directly like this will result in ***desynchronization*** between server data and client data. It may also prevent listeners connected via [`save:Subscribe()`](../api/Save#Subscribe) from firing when they are supposed to.
:::

PlayerSave provides a number of useful ways to modify tables in a player's save.
For example, to insert a value into a list, you can simply call:
```lua
save:ListInsert("Inventory", "Sword)
```

If your use case is not covered by methods like [`save:ListInsert()`](../api/Save#ListInsert), [`save:ListRemove()`](../api/Save#ListRemove), or [`save:ListSwapRemove()`](../api/Save#ListSwapRemove), you can use the method [`save:GetDeepCopy()`](../api/Save#GetDeepCopy) to get a copy of a saved value which is safe to mutate:
```lua
local inventory = save:GetDeepCopy("Inventory", {})
table.insert(inventory, "Sword") -- OK, since this is a deep copy of save data!
save:Set("Inventory", inventory) -- OK!
```

## Setting Mutable Tables in a Save

:::info
PlayerSave will automatically make deep copies of tables passed into [`save:Set()`](../api/Save#Set), or as a second argument (`defaultValue`) to [`save:Get()`](../api/Save#Get).

This means you do not have to worry about mutating values that are later stored in a save.

```lua
local myTable = {}
save:Set("Value1", myTable) -- OK
table.insert(myTable, "Foo") -- OK; this will not affect Value1!
save:Get("Value2", myTable) -- OK
table.insert(myTable, "Fighters") -- OK; this will not affect Value1 or Value2!

print(#save:Get("Value1")) -- 0
print(#save:Get("Value2")) -- 1
print(#myTable) -- 2
```
:::

## Unsecured Remotes

One limitation of all player saving systems, which PlayerSave is by no means immune to, is the possibility of exploited data ending up in a player's save.

Whenever you write code that listens to a RemoteEvent / RemoteFunction, you should ***never trust values sent from the client to the server!*** Failing to perform sanity checks on values sent by the client could result in exploits that remain in a player's save forever.

:::caution
Never trust values sent from the client to the server!

**Unsecured Remote Example (using [Knit](https://sleitnick.github.io/Knit/)):**
```lua
function LevelUpService.Client:SpendExperienceShards(
    player: Player,
    amount: number
)
    local save = PlayerSave.Get(player)
    save:Increment("ExperienceShards", -amount)
    save:Increment("ExperienceLevel", amount)
end
```

Exploiters are able to call any remote function with arbitrary arguments. Take a moment to consider what the net effect would be after making any of the following requests:
```lua
LevelUpService:SpendExperienceShards(-100000)
LevelUpService:SpendExperienceShards(math.huge)
LevelUpService:SpendExperienceShards(1/0)
LevelUpService:SpendExperienceShards(0/0)
LevelUpService:SpendExperienceShards(0.000001)
LevelUpService:SpendExperienceShards(0)
LevelUpService:SpendExperienceShards(Vector3.new(0.5, -1, 1 / 0))
LevelUpService:SpendExperienceShards("Oops, I corrupted the save!")
```
:::

:::info
It's a good idea to perform sanity checks on values provided by the client that will end up in a player's save.

**Example of a secured remote:**
```lua
function LevelUpService.Client:SpendExperienceShards(
    player: Player,
    amount: unknown -- Never assume the type of a value sent by a player!
)
    -- Loaded save check
    local save = PlayerSave.GetLoaded(player)
    if not save then
        return
    end
    -- Type check
    if typeof(amount) ~= "number" then
        return
    end
    -- NaN check
    if amount ~= amount then
        return
    end
    -- Range check
    local currentShards = save:Get("ExperienceShards", 0)
    if amount < 1 or amount > currentShards then
        return
    end
    -- Integer check
    if amount ~= math.floor(amount) then
        return
    end

    -- All sanity checks have passed! Now we are safe to edit the player's data.

    save:Increment("ExperienceShards", -amount)
    save:Increment("ExperienceLevel", amount)
end
```
:::