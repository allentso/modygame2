local Json = {}

local function escapeString(value)
    local replacements = {
        ['"'] = '\\"',
        ["\\"] = "\\\\",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    return '"' .. string.gsub(value, '[%z\1-\31\\"]', function(char)
        return replacements[char] or string.format("\\u%04x", string.byte(char))
    end) .. '"'
end

local function isArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end
    return count == #value
end

local function encodeValue(value, indent, depth)
    local valueType = type(value)
    if valueType == "nil" then
        return "null"
    elseif valueType == "boolean" or valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return escapeString(value)
    elseif valueType ~= "table" then
        error("Cannot JSON encode " .. valueType)
    end

    local padding = indent and string.rep(indent, depth) or ""
    local childPadding = indent and string.rep(indent, depth + 1) or ""
    local separator = indent and ",\n" or ","
    local afterColon = indent and " " or ""

    if isArray(value) then
        local items = {}
        for i = 1, #value do
            items[i] = encodeValue(value[i], indent, depth + 1)
        end
        if not indent then
            return "[" .. table.concat(items, ",") .. "]"
        end
        if #items == 0 then
            return "[]"
        end
        return "[\n" .. childPadding .. table.concat(items, separator .. childPadding) .. "\n" .. padding .. "]"
    end

    local keys = {}
    for key in pairs(value) do
        if type(key) ~= "string" then
            error("JSON object keys must be strings")
        end
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local items = {}
    for _, key in ipairs(keys) do
        items[#items + 1] = escapeString(key) .. ":" .. afterColon .. encodeValue(value[key], indent, depth + 1)
    end

    if not indent then
        return "{" .. table.concat(items, ",") .. "}"
    end
    if #items == 0 then
        return "{}"
    end
    return "{\n" .. childPadding .. table.concat(items, separator .. childPadding) .. "\n" .. padding .. "}"
end

function Json.encode(value, options)
    options = options or {}
    return encodeValue(value, options.pretty and "  " or nil, 0)
end

local Parser = {}
Parser.__index = Parser

function Parser:new(text)
    return setmetatable({ text = text, index = 1, length = #text }, self)
end

function Parser:peek()
    return string.sub(self.text, self.index, self.index)
end

function Parser:advance()
    local char = self:peek()
    self.index = self.index + 1
    return char
end

function Parser:error(message)
    error(message .. " at byte " .. tostring(self.index))
end

function Parser:skipWhitespace()
    while self.index <= self.length do
        local char = self:peek()
        if char ~= " " and char ~= "\n" and char ~= "\r" and char ~= "\t" then
            return
        end
        self.index = self.index + 1
    end
end

function Parser:expect(text)
    if string.sub(self.text, self.index, self.index + #text - 1) ~= text then
        self:error("Expected " .. text)
    end
    self.index = self.index + #text
end

function Parser:parseString()
    self:expect('"')
    local result = {}
    while self.index <= self.length do
        local char = self:advance()
        if char == '"' then
            return table.concat(result)
        elseif char == "\\" then
            local escaped = self:advance()
            if escaped == '"' or escaped == "\\" or escaped == "/" then
                result[#result + 1] = escaped
            elseif escaped == "b" then
                result[#result + 1] = "\b"
            elseif escaped == "f" then
                result[#result + 1] = "\f"
            elseif escaped == "n" then
                result[#result + 1] = "\n"
            elseif escaped == "r" then
                result[#result + 1] = "\r"
            elseif escaped == "t" then
                result[#result + 1] = "\t"
            elseif escaped == "u" then
                local hex = string.sub(self.text, self.index, self.index + 3)
                self.index = self.index + 4
                local code = tonumber(hex, 16)
                if not code or code > 127 then
                    self:error("Only ASCII unicode escapes are supported")
                end
                result[#result + 1] = string.char(code)
            else
                self:error("Invalid escape sequence")
            end
        else
            result[#result + 1] = char
        end
    end
    self:error("Unterminated string")
end

function Parser:parseNumber()
    local start = self.index
    local char = self:peek()
    if char == "-" then
        self.index = self.index + 1
    end
    while string.match(self:peek(), "%d") do
        self.index = self.index + 1
    end
    if self:peek() == "." then
        self.index = self.index + 1
        while string.match(self:peek(), "%d") do
            self.index = self.index + 1
        end
    end
    char = self:peek()
    if char == "e" or char == "E" then
        self.index = self.index + 1
        char = self:peek()
        if char == "+" or char == "-" then
            self.index = self.index + 1
        end
        while string.match(self:peek(), "%d") do
            self.index = self.index + 1
        end
    end
    local value = tonumber(string.sub(self.text, start, self.index - 1))
    if value == nil then
        self:error("Invalid number")
    end
    return value
end

function Parser:parseArray()
    self:expect("[")
    local result = {}
    self:skipWhitespace()
    if self:peek() == "]" then
        self.index = self.index + 1
        return result
    end
    while true do
        result[#result + 1] = self:parseValue()
        self:skipWhitespace()
        local char = self:advance()
        if char == "]" then
            return result
        elseif char ~= "," then
            self:error("Expected ',' or ']'")
        end
    end
end

function Parser:parseObject()
    self:expect("{")
    local result = {}
    self:skipWhitespace()
    if self:peek() == "}" then
        self.index = self.index + 1
        return result
    end
    while true do
        self:skipWhitespace()
        if self:peek() ~= '"' then
            self:error("Expected object key")
        end
        local key = self:parseString()
        self:skipWhitespace()
        self:expect(":")
        result[key] = self:parseValue()
        self:skipWhitespace()
        local char = self:advance()
        if char == "}" then
            return result
        elseif char ~= "," then
            self:error("Expected ',' or '}'")
        end
    end
end

function Parser:parseValue()
    self:skipWhitespace()
    local char = self:peek()
    if char == '"' then
        return self:parseString()
    elseif char == "{" then
        return self:parseObject()
    elseif char == "[" then
        return self:parseArray()
    elseif char == "t" then
        self:expect("true")
        return true
    elseif char == "f" then
        self:expect("false")
        return false
    elseif char == "n" then
        self:expect("null")
        return nil
    elseif char == "-" or string.match(char, "%d") then
        return self:parseNumber()
    end
    self:error("Unexpected value")
end

function Json.decode(text)
    local parser = Parser:new(text)
    local value = parser:parseValue()
    parser:skipWhitespace()
    if parser.index <= parser.length then
        parser:error("Trailing content")
    end
    return value
end

return Json
