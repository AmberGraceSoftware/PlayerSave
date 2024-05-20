--!strict
local Registry = require(script.Parent.Parent.Parent.Registry)
local Save = require(script.Parent.Parent.Parent.Save)
export type Registry = Registry.Registry
export type Save = Registry.Save
export type DeepSelectionQuery = Save.DeepSelectionQuery

return nil