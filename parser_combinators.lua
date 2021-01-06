require "strict"

local utility = require "utility"

local ParserState = { }
ParserState.__index = ParserState

function ParserState:new(target, index, result, error)
    local parser_state = {}
    setmetatable(parser_state, ParserState)

    parser_state.target = target
    parser_state.index = index
    parser_state.result = result
    parser_state.error = error or nil
    return parser_state
end

local Parser = { }
Parser.__index = Parser

function Parser:new(parser_fn)
    local parser = {}
    setmetatable(parser, Parser)

    parser.parser_fn = parser_fn
    return parser
end

function Parser:parse(state)
    return self.parser_fn(state)
end

function Parser:run(input)
    local initial_state = ParserState:new(input, 1, nil)
    return self(initial_state)
end

function Parser:__call(state)
    return self.parser_fn(state)
end

function Parser:parse(input)
    return self.parser_fn(input)
end

function Parser:map(fn)
    local parser_fn = function(initial_state)
        local next_state = self(initial_state)
        
        if next_state.error then
            return next_state
        end

        local new_state = ParserState:new(
            next_state.target,
            next_state.index,
            fn(next_state.result),
            next_state.error
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

function Parser:chain(fn)
    local parser_fn = function(initial_state)
        local next_state = self(initial_state)
        
        if next_state.error then
            return next_state
        end

        local next_parser = fn(next_state.result)

        return next_parser(next_state)
    end

    return Parser:new(parser_fn)
end

function Parser:error_map(fn)
    local parser_fn = function(initial_state)
        local next_state = self(initial_state)
        
        if not next_state.error then
            return next_state
        end

        local new_state = ParserState:new(
            next_state.target,
            next_state.index,
            next_state.result,
            fn(next_state.error, next_state.index)
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

local function char(match)
    local parser_fn = function(initial_state)
        if initial_state.error then
            return initial_state
        end

        if #initial_state.target < initial_state.index then
            local new_state = ParserState:new(
                initial_state.target,
                initial_state.index,
                initial_state.result,
                "char: unexpected end of input."
            )

            return new_state
        end

        local c = initial_state.target:sub(initial_state.index, initial_state.index)

        if match == c then
            local new_state = ParserState:new(initial_state.target, initial_state.index + 1, c)
            return new_state
        end

        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            initial_state.result,
            "char: unable to match '" .. c .. "' with required '" .. 
                match .. "' at index " ..  initial_state.index .. "."
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

local letter = Parser:new(function(initial_state)
    if initial_state.error then
        return initial_state
    end

    if #initial_state.target < initial_state.index then
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            initial_state.result,
            "letter: unexpected end of input."
        )

        return new_state
    end

    local c = initial_state.target:sub(initial_state.index, initial_state.index)
    local b = string.byte(c)

    if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
        local new_state = ParserState:new(initial_state.target, initial_state.index + 1, c)
        return new_state
    end

    local new_state = ParserState:new(
        initial_state.target,
        initial_state.index,
        initial_state.result,
        "letter: unable to match letter at index " ..  initial_state.index .. "."
    )

    return new_state
end)

local peek = Parser:new(function(initial_state)
    if initial_state.error then
        return initial_state
    end

    if #initial_state.target < initial_state.index then
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            initial_state.result,
            "letter: unexpected end of input."
        )

        return new_state
    end

    local c = initial_state.target:sub(initial_state.index, initial_state.index)
    local new_state = ParserState:new(initial_state.target, initial_state.index, c)

    return new_state
end)

local blank_space_char = Parser:new(function(initial_state)
    if initial_state.error then
        return initial_state
    end

    if #initial_state.target < initial_state.index then
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            initial_state.result,
            "blank_space: unexpected end of input."
        )

        return new_state
    end

    local c = initial_state.target:sub(initial_state.index, initial_state.index)
    local b = string.byte(c)

    if c == '\n' or c == '\t' or c == '\r' or c == ' ' or b == 0xb or b == 0xc then
        local new_state = ParserState:new(initial_state.target, initial_state.index + 1, c)
        return new_state
    end

    local new_state = ParserState:new(
        initial_state.target,
        initial_state.index,
        initial_state.result,
        "blank_space: unable to match blank space at index " .. initial_state.index .. "."
    )

    return new_state
end)

local eof = Parser:new(function(initial_state)
    if initial_state.error then
        return initial_state
    end

    if #initial_state.target < initial_state.index then
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            initial_state.result
        )

        return new_state
    end

    local error_state = ParserState:new(
        initial_state.target,
        initial_state.index,
        initial_state.result,
        "eof: Not end of file."
    )

    return error_state
end)

local digit = Parser:new(function(initial_state)
    if initial_state.error then
        return initial_state
    end

    if #initial_state.target < initial_state.index then
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            initial_state.result,
            "digit: unexpected end of input."
        )

        return new_state
    end

    local c = initial_state.target:sub(initial_state.index, initial_state.index)
    local b = string.byte(c)

    if b >= 48 and b <= 57 then
        local new_state = ParserState:new(initial_state.target, initial_state.index + 1, c)
        return new_state
    end

    local new_state = ParserState:new(
        initial_state.target,
        initial_state.index,
        initial_state.result,
        "digit: unable to match digit at index " ..  initial_state.index .. "."
    )

    return new_state
end)

local function sequence_of(...)
    local parsers = { ... }
    local parser_fn = function(initial_state)
        if initial_state.error then
            return initial_state
        end

        local results = { }
        local next_state = initial_state
        for _, parser in ipairs(parsers) do
            next_state = parser(next_state)
            if next_state.error then
                break
            end
            results[#results + 1] = next_state.result
        end

        local new_state = ParserState:new(
            next_state.target,
            next_state.index,
            results,
            next_state.error
        )
        
        return new_state
    end

    return Parser:new(parser_fn)
end

local function choice(...)
    local parsers = { ... }
    local parser_fn = function(initial_state)
        if initial_state.error then
            return initial_state
        end

        for _, parser in ipairs(parsers) do
            local next_state = parser(initial_state)
            if not next_state.error then
                return next_state
            end
        end

        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            nil,
            "choice: unable to match with any parser."
        )
        
        return new_state
    end

    return Parser:new(parser_fn)
end

local function many(parser)
    local parser_fn = function(initial_state)
        local results = { }
        local next_state = initial_state

        while true do
            next_state = parser(next_state)
            if next_state.error then
                break
            end

            results[#results + 1] = next_state.result
        end

        local new_state = ParserState:new(
            next_state.target,
            next_state.index,
            results
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

local function many1(parser)
    local parser_fn = function(initial_state)
        local results = { }
        local next_state = parser(initial_state)

        if next_state.error then
            return next_state
        end

        results[#results + 1] = next_state.result

        while true do
            next_state = parser(next_state)
            if next_state.error then
                break
            end

            results[#results + 1] = next_state.result
        end

        local new_state = ParserState:new(
            next_state.target,
            next_state.index,
            results
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

local function separated_by(separator_parser)
    return function(value_parser)
        local parser_fn = function(initial_state)
            local results = { }
            local next_state = initial_state

            while true do
                local capture_state = value_parser(next_state)
                if capture_state.error then
                    break
                end

                results[#results + 1] = capture_state.result
                next_state = capture_state

                local separator_state = separator_parser(next_state)
                if separator_state.error then
                    break
                end

                next_state = separator_state
            end

            local new_state = ParserState:new(
                next_state.target,
                next_state.index,
                results
            )

            return new_state
        end

        return Parser:new(parser_fn)
    end
end

local function separated_by1(separator_parser)
    return function(value_parser)
        local parser_fn = function(initial_state)
            local results = { }
            local next_state = initial_state

            while true do
                local capture_state = value_parser(next_state)
                if capture_state.error then
                    break
                end

                results[#results + 1] = capture_state.result
                next_state = capture_state

                local separator_state = separator_parser(next_state)
                if separator_state.error then
                    break
                end

                next_state = separator_state
            end

            if #results == 0 then
                local error_state = ParserState:new(
                    initial_state.target,
                    initial_state.index,
                    initial_state.result,
                    "separated_by1: unable to capture any results at index " .. initial_state.index
                )

                return error_state
            end

            local new_state = ParserState:new(
                next_state.target,
                next_state.index,
                results
            )

            return new_state
        end

        return Parser:new(parser_fn)
    end
end

local letters = many1(letter):map(utility.string_concat)
local digits = many1(digit):map(utility.string_concat)
local optional_blank_space = many(blank_space_char):map(utility.string_concat)

local function str(match)
    local parsers = { }
    for i = 1, #match do
        parsers[#parsers + 1] = char(match:sub(i, i))
    end

    return sequence_of(
        unpack(parsers)
    ):map(utility.string_concat)
end

local function between(left_parser, right_parser)
    return function(content_parser)
        return sequence_of(
            left_parser,
            content_parser,
            right_parser
        ):map(function(results) return results[2] end)
    end
end

local function succeed(value)
    local parser_fn = function(initial_state)
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            value
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

local function fail(value)
    local parser_fn = function(initial_state)
        local new_state = ParserState:new(
            initial_state.target,
            initial_state.index,
            nil,
            value
        )

        return new_state
    end

    return Parser:new(parser_fn)
end

local function lazy(parser_thunk)
    local parser_fn = function(initial_state)
        local parser = parser_thunk()
        return parser(initial_state)
    end

    return Parser:new(parser_fn)
end

local function contextual(generator_fn)
    return succeed(nil):chain(
        function()
            local function run_step(next_value)
                local status, result = coroutine.resume(generator_fn, next_value)
                if status == "dead" or getmetatable(result) ~= Parser then
                    return succeed(result)
                end

                local next_parser = result
                return next_parser:chain(run_step)
            end

            return run_step(nil)
        end
    )
end

local parser_combinators = { }

parser_combinators.Parser = Parser
parser_combinators.ParserState = ParserState

parser_combinators.letter = letter
parser_combinators.peek = peek
parser_combinators.letters = letters
parser_combinators.digit = digit
parser_combinators.digits = digits
parser_combinators.char = char
parser_combinators.str = str
parser_combinators.between = between
parser_combinators.many1 = many1
parser_combinators.many = many
parser_combinators.separated_by1 = separated_by1
parser_combinators.separated_by = separated_by
parser_combinators.sequence_of = sequence_of
parser_combinators.choice = choice
parser_combinators.succeed = succeed
parser_combinators.fail = fail
parser_combinators.eof = eof
parser_combinators.blank_space_char = blank_space_char
parser_combinators.optional_blank_space = optional_blank_space

parser_combinators.lazy = lazy
parser_combinators.contextual = contextual

return parser_combinators
