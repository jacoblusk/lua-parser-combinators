require "strict"

local utility = { }

local function string_concat(s, sep)
    local t = { }
    for _, v in ipairs(s) do
        t[#t+1] = tostring(v)
    end
    return table.concat(t, sep or '')
end

utility.string_concat = string_concat

return utility