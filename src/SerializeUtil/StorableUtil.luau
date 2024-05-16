--!strict
--[[
Utility for serializing all luau/userdata types to a representational format
that can be converted to JSON or stored in a data store.
]]

type Serializer<T, U> = {
    types: {string},
    deserialize: (symbolicValue: U) -> T,
    serialize: (object: T) -> U,
}

-- Header for recursive serialize/deserialize
local serializersById: {[string]: Serializer<any, any>} = {}
local rbxTypeToSerializerId: {[string]: string} = {}

-- Serialize/deserialize recursive root functions
-- Stored in format "{typeId: string, symbolicValue: any}"
local function serializeObject(object: any): any
    local serializerId = rbxTypeToSerializerId[typeof(object)]
    if serializerId then
        local serializer = serializersById[serializerId]
        
        if serializerId == "@@Raw" then
            return object
        end

        return {serializerId, serializer.serialize(object)}
    else
        warn(
            "Type '"
            .. typeof(object)
            .. "' is not supported (encountered when calling Serialize); "
            .. "skipping this value."
        )
        return nil
    end
end

local function deserializeObject(serialValue: any): any
    if typeof(serialValue) == "table"
    and #serialValue == 2
    and typeof(serialValue[1]) == "string" then
        local serializerId = serialValue[1]
        local symbolicValue = serialValue[2]
        local serializer = serializersById[serializerId]
        if serializer then
            return serializer.deserialize(symbolicValue)
        end
    end
    return serialValue
end

-- Define serializers
serializersById["@@Raw"] = {
    types = { "number", "string", "boolean", "nil", "buffer" },
    deserialize = function(symbolicValue: any)
        return symbolicValue
    end,
    serialize = function(object: any)
        return object
    end,
}
serializersById["@@EnumItem"] = {
    types = { "EnumItem" },
    deserialize = function(symbolicValue: {string})
        return (Enum :: any)[symbolicValue[1]][symbolicValue[2]]
    end,
    serialize = function(object: EnumItem)
        return {
            tostring(object.EnumType),
            object.Name,
        }
    end,
}
serializersById["@@Table"] = {
    types = { "table" },
    deserialize = function(symbolicValue: {[any]: any})
        if #symbolicValue > 0 then
            local tab = table.create(#symbolicValue)
            for _, v in symbolicValue do
                table.insert(tab, deserializeObject(v))
            end
            return tab
        else
            local tab = {}
            for key, serialValue in symbolicValue do
                tab[key] = deserializeObject(serialValue)
            end
            return tab
        end
    end,
    serialize = function(tab: any)
        local symbolicValue = {}
        if #tab == 0 then
            for k, v in tab do
                if type(k) ~= "string" then
                    k = tostring(k)
                    local shouldSkip = tab[k] ~= nil
                    warn(
                        "Serialized nonsequential tables must have string keys "
                        .. "(encountered non-string key '"
                        .. k
                        .. "[" .. typeof(k) .. "]' "
                        .. "when calling Serialize); "
                        .. if shouldSkip
                            then "skipping this key."
                            else "converting key to string."
                    )
                    if shouldSkip then
                        continue
                    end
                end
                symbolicValue[k] = serializeObject(v)
            end
        else
            local expectedi = 1
            for i, v in tab do
                if i ~= expectedi then
                    warn(
                        "Serialized array tables must have sequential keys"
                        .. " (encountered non-sequential key '"
                        .. tostring(i)
                        .. " when calling Serialize); skipping this key.")
                    continue
                end
                expectedi = expectedi + 1
                
                symbolicValue[i] = serializeObject(v)
            end
        end
        return symbolicValue
    end,
}
do
    local validAxes = {
        Enum.Axis.X,
        Enum.Axis.Y,
        Enum.Axis.Z,
        -- Enum.Axis.Top,
        -- Enum.Axis.Bottom,
        -- Enum.Axis.Left,
        -- Enum.Axis.Right,
        -- Enum.Axis.Back,
        -- Enum.Axis.Front
    }
    serializersById["@@Axes"] = {
        types = {"Axes"},
        deserialize = function(symbolicValue: {any})
            local axisList: {Enum.Axis | Enum.NormalId} = {}
            for i = 1, #symbolicValue do
                table.insert(
                    axisList,
                    (Enum.Axis :: any)[symbolicValue[i]]
                )
            end
            
            return (Axes :: any).new(unpack(axisList))
        end,
        serialize = function(axes: Axes)
            local axesSerialized = {}
            for i = 1, #validAxes do
                if (axes :: any)[validAxes[i].Name] then
                    table.insert(
                        axesSerialized,
                        validAxes[i].Name
                    )
                end
            end
            return axesSerialized
        end,
    }
end
serializersById["@@BrickColor"] = {
    types = {"BrickColor"},
    deserialize = function(number: number)
        return BrickColor.new(number)
    end,
    serialize = function(brickColor: BrickColor)
        return brickColor.Number
    end,
}
serializersById["@@CFrame"] = {
    types = {"CFrame"},
    deserialize = function(components: {number})
        return CFrame.new(unpack(components))
    end,
    serialize = function(cf: CFrame)
        return {cf:GetComponents()}
    end,
}
serializersById["@@Color3"] = {
    types = {"Color3"},
    deserialize = function(rgb: {number})
        return Color3.new(unpack(rgb) :: number)
    end,
    serialize = function(color: Color3)
        return {color.R, color.G, color.B}
    end,
}
serializersById["@@ColorSequence"] = {
    types = {"ColorSequence"},
    deserialize = function(symbolicValue: {any})
        local keypoints = table.create(#symbolicValue)
        for _, serialKP in symbolicValue do
            table.insert(
                keypoints,
                serializersById["@@ColorSequenceKeypoint"].deserialize(serialKP)
            )
        end
        
        return ColorSequence.new(keypoints)
    end,
    serialize = function(seq: ColorSequence)
        local kps = seq.Keypoints
        local symbolicValue = table.create(#kps)
        for _, keypoint in kps do
            table.insert(
                symbolicValue,
                serializersById["@@ColorSequenceKeypoint"].serialize(keypoint)
            )
        end
        return symbolicValue
    end,
}
serializersById["@@ColorSequenceKeypoint"] = {
    types = {"ColorSequenceKeypoint"},
    deserialize = function(symbolicValue: {any})
        return ColorSequenceKeypoint.new(
            symbolicValue[1],
            serializersById["@@Color3"].deserialize(symbolicValue[2])
        )
    end,
    serialize = function(kp)
        return {
            kp.Time,
            serializersById["@@Color3"].serialize(kp.Value),
        }
    end,
}
do
    local validFaces = {
        Enum.NormalId.Top,
        Enum.NormalId.Bottom,
        Enum.NormalId.Left,
        Enum.NormalId.Right,
        Enum.NormalId.Back,
        Enum.NormalId.Front
    }
    serializersById["@@Faces"] = {
        types = {"Faces"},
        deserialize = function(symbolicValue: {any})
            local faceList: {Enum.NormalId} = {}
            for i = 1, #symbolicValue do
                table.insert(
                    faceList,
                    (Enum.NormalId :: any)[symbolicValue[i]]
                )
            end
            
            return Faces.new(unpack(faceList))
        end,
        serialize = function(faces: Faces)
            local facesSerialized = {}
            for i = 1, #validFaces do
                if (faces :: any)[validFaces[i].Name] then
                    table.insert(
                        facesSerialized,
                        validFaces[i].Name
                    )
                end
            end
            return facesSerialized
        end,
    }
end
serializersById["@@NumberRange"] = {
    types = {"NumberRange"},
    deserialize = function(symbolicValue: {number})
        return NumberRange.new(unpack(symbolicValue))
    end,
    serialize = function(range: NumberRange)
        return {range.Min, range.Max}
    end,
}
serializersById["@@NumberSequence"] = {
    types = {"NumberSequence"},
    deserialize = function(symbolicValue: {any})
        local keypoints = table.create(#symbolicValue)
        for _, serialKP in symbolicValue do
            table.insert(
                keypoints,
                serializersById["@@NumberSequenceKeypoint"].deserialize(serialKP)
            )
        end
        
        return NumberSequence.new(keypoints)
    end,
    serialize = function(seq: NumberSequence)
        local kps = seq.Keypoints
        local symbolicValue = table.create(#kps)
        for _, keypoint in kps do
            table.insert(
                symbolicValue,
                serializersById["@@NumberSequenceKeypoint"].serialize(keypoint)
            )
        end
        return symbolicValue
    end,
}
serializersById["@@NumberSequenceKeypoint"] = {
    types = {"NumberSequenceKeypoint"},
    deserialize = function(symbolicValue: {any})
        return NumberSequenceKeypoint.new(unpack(symbolicValue))
    end,
    serialize = function(kp: NumberSequenceKeypoint)
        return {
            kp.Time,
            kp.Value,
            kp.Envelope,
        }
    end,
}
serializersById["@@PathWaypoint"] = {
    types = {"PathWaypoint"},
    deserialize = function(symbolicValue: {any})
        return PathWaypoint.new(
            serializersById["@@Vector3"].deserialize(symbolicValue[1]),
            serializersById["@@EnumItem"].deserialize(symbolicValue[2])
        )
    end,
    serialize = function(object: PathWaypoint)
        return {
            serializersById["@@Vector3"].serialize(object.Position),
            serializersById["@@EnumItem"].serialize(object.Action),
        }
    end,
}
serializersById["@@PhysicalProperties"] = {
    types = {"PhysicalProperties"},
    deserialize = function(symbolicValue: {any})
        return PhysicalProperties.new(unpack(symbolicValue))
    end,
    serialize = function(object: PhysicalProperties)
        return {
            object.Density,
            object.Friction,
            object.Elasticity,
            object.FrictionWeight,
            object.ElasticityWeight,
        }
    end,
}
serializersById["@@Ray"] = {
    types = {"Ray"},
    deserialize = function(symbolicValue: {any})
        return Ray.new(
            serializersById["@@Vector3"].deserialize(symbolicValue[1]),
            serializersById["@@Vector3"].deserialize(symbolicValue[2])
        )
    end,
    serialize = function(object: Ray)
        return {
            serializersById["@@Vector3"].serialize(object.Origin),
            serializersById["@@Vector3"].serialize(object.Direction),
        }
    end,
}
serializersById["@@Rect"] = {
    types = {"Rect"},
    deserialize = function(symbolicType: {any})
        return Rect.new(unpack(symbolicType))
    end,
    serialize = function(object: Rect)
        return {
            object.Min.X,
            object.Min.Y,
            object.Max.X,
            object.Max.Y,
        }
    end,
}
serializersById["@@Region3"] = {
    types = {"Region3"},
    deserialize = function(symbolicType: {any})
        return Region3.new(
            serializersById["@@Vector3"].deserialize(symbolicType[1]),
            serializersById["@@Vector3"].deserialize(symbolicType[2])
        )
    end,
    serialize = function(object: Region3)
        local pos = object.CFrame.Position
        local hSize = object.Size / 2
        return {
            serializersById["@@Vector3"].serialize(pos - hSize),
            serializersById["@@Vector3"].serialize(pos + hSize),
        }
    end,
}
serializersById["@@TweenInfo"] = {
    types = {"TweenInfo"},
    deserialize = function(symbolicValue: {any})
        return TweenInfo.new(
            symbolicValue[1],
            serializersById["@@EnumItem"].deserialize(symbolicValue[2]),
            serializersById["@@EnumItem"].deserialize(symbolicValue[3]),
            symbolicValue[4],
            symbolicValue[5],
            symbolicValue[6]
        )
    end,
    serialize = function(tween: TweenInfo)
        return {
            tween.Time :: any,
            serializersById["@@EnumItem"].serialize(tween.EasingStyle),
            serializersById["@@EnumItem"].serialize(tween.EasingDirection),
            tween.RepeatCount,
            tween.Reverses,
            tween.DelayTime
        }
    end,
}
serializersById["@@UDim"] = {
    types = {"UDim"},
    deserialize = function(symbolicValue: {any})
        return UDim.new(unpack(symbolicValue))
    end,
    serialize = function(object: UDim)
        return {
            object.Scale,
            object.Offset,
        }
    end,
}
serializersById["@@UDim2"] = {
    types = {"UDim2"},
    deserialize = function(symbolicValue: {any})
        return (UDim2 :: any).new(unpack(symbolicValue))
    end,
    serialize = function(object: UDim2)
        return {
            object.X.Scale,
            object.X.Offset,
            object.Y.Scale,
            object.Y.Offset,
        }
    end,
}
serializersById["@@Vector2"] = {
    types = {"Vector2"},
    deserialize = function(symbolicValue: any)
        return Vector2.new(unpack(symbolicValue))
    end,
    serialize = function(object: Vector2)
        return {
            object.X,
            object.Y
        }
    end,
}
serializersById["@@Vector2int16"] = {
    types = {"Vector2int16"},
    deserialize = function(symbolicValue: any)
        return Vector2int16.new(unpack(symbolicValue))
    end,
    serialize = function(object: Vector2int16)
        return {
            object.X,
            object.Y
        }
    end,
}
serializersById["@@Vector3"] = {
    types = {"Vector3"},
    deserialize = function(symbolicValue: any)
        return Vector3.new(unpack(symbolicValue))
    end,
    serialize = function(object: Vector3)
        return {
            object.X,
            object.Y,
            object.Z
        }
    end,
}
serializersById["@@Vector3int16"] = {
    types = {"Vector3int16"},
    deserialize = function(symbolicValue: any)
        return Vector3int16.new(unpack(symbolicValue))
    end,
    serialize = function(object: Vector3int16)
        return {
            object.X,
            object.Y,
            object.Z
        }
    end,
}

-- Map typeof() to serializer ID
for id, serializer in serializersById do
    for _, rbxType in serializer.types do
        rbxTypeToSerializerId[rbxType] = id
    end
end

local StorableUtil = {}

StorableUtil.Serialize = serializeObject
StorableUtil.Deserialize = deserializeObject
function StorableUtil.ValueIsStorable(value: any)
    return rbxTypeToSerializerId[typeof(value)] ~= nil
end

return StorableUtil