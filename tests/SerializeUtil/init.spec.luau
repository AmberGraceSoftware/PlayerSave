--!strict
local HttpService = game:GetService("HttpService")

local function deepCompare(valA: any, valB: any)
	local valAType = typeof(valA)
	if valAType == typeof(valB) then
		if valAType == "table" then
			for k, v in pairs(valA) do
				if not deepCompare(v, valB[k]) then
					return false
				end
			end
			for k in pairs(valB) do
				if valA[k] == nil then
					return false
				end
			end
			return true
		end
		return valA == valB
	end
	return false
end

local function VerifyJSONSerializeSafety(value: any)
	return deepCompare(value, HttpService:JSONDecode(HttpService:JSONEncode(value)))
end

local function expectDeepEqual(
    expect: any,
    expectation: any,
    actualValue: any
)
    if typeof(expectation) ~= "table"
    or typeof(actualValue) ~= "table" then
        expect(actualValue).to.equal(expectation)
    end
    for k, v in expectation do
        if typeof(v) == "table" then
            expectDeepEqual(expect, v, actualValue[k])
        else
            expect(actualValue[k]).to.equal(v)
        end
    end
    for k, v in actualValue do
        if not expectation[k] then
            expect(v).to.equal(nil)
        end
    end
end

return function()
    local StorableUtil = require(game.ReplicatedStorage.Packages.PlayerSave.SerializeUtil.StorableUtil)
	it("should serialize primitive types in a component", function()
		local comp = {
			values = {
				4.20 :: any,
				"",
				true,
			},
		}
		local serialized = StorableUtil.Serialize(comp)
		assert(VerifyJSONSerializeSafety(serialized))
		expectDeepEqual(expect, comp, StorableUtil.Deserialize(serialized))
	end)
	it("should serialize enum types in a component", function()
		local comp = {
			values = {
				Enum.ActionType.Win,
			},
		}
		local serialized = StorableUtil.Serialize(comp)
		assert(VerifyJSONSerializeSafety(serialized))
		expectDeepEqual(expect, comp, StorableUtil.Deserialize(serialized))
	end)
	it("should serialize userdata types in a component", function()
		local comp = {
			values = {
				Color3.new() :: any,
				BrickColor.new("Camo"),
				ColorSequence.new {
					ColorSequenceKeypoint.new(0, Color3.new()),
					ColorSequenceKeypoint.new(1, Color3.new()),
				},
				NumberSequence.new {
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 0),
				},
				NumberRange.new(0, 1),
				CFrame.new(),
				Vector2.new(),
				Vector3.new(),
				UDim.new(),
				UDim2.new(),
				Vector2int16.new(),
				Vector3int16.new(),
				Axes.new({Enum.Axis.X, Enum.Axis.Z}),
				Faces.new({Enum.NormalId.Top, Enum.NormalId.Back}),
				PathWaypoint.new(Vector3.new(), Enum.PathWaypointAction.Jump),
				PhysicalProperties.new(0.5, 1, 1),
				Ray.new(Vector3.new(), Vector3.new(1, 0, 0)),
				Rect.new(0, 0, 1, 1),
				Region3.new(Vector3.zero, Vector3.one),
				TweenInfo.new(),
			},
		}
		local serialized = StorableUtil.Serialize(comp)
		assert(VerifyJSONSerializeSafety(serialized))
		expectDeepEqual(expect, comp, StorableUtil.Deserialize(serialized))
	end)
end