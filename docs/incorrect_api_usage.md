---
sidebar_position: 3
---
# Incorrect API Usage

PlayerSave's API has a few key limitations to look out for!

# Table Mutations

One core feature of PlayerSave is that all changes to player save data are [Observable](../api/Save#Subscribe). This is achieved by only allowing data to be changed in a player's save via [Setter methods](../api/Save#Set).

*However*, **there are still ways to accidentally modify save data** that the PlayerSave library is not able to observe to at runtime!

:::warning
You should never directly edit a table returned by [`save:Get()`](../api/Save#Get)! For example:

```lua
local inventory = save:Get("Inventory")
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
local inventory = save:GetDeepCopy("Inventory")
table.insert(inventory, "Sword") -- OK, since this is a deep copy of save data!
save:Set("Inventory", inventory) -- OK!
```