local RingMenuReborn_AddonName, RingMenuReborn = ...

-- Shallow-copy a table
function RingMenuReborn.shallow_copy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

-- Deep-copy a table
function RingMenuReborn.deep_copy(t)
    local copy = {}
    if type(t) == 'table' then
        for k, v in pairs(t) do
            copy[RingMenuReborn.deep_copy(k)] = RingMenuReborn.deep_copy(v)
        end
    else
        copy = t
    end
    return copy
end

-- Copies fields from defaults to t but only if they are currently nil in t
function RingMenuReborn.update_with_defaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = RingMenuReborn.deep_copy(v)
        end
    end
end
