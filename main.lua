require "strict"

local parsec = require "parser_combinators"
local utility = require "utility"
local inspect = require "inspect"

local function astype(type)
    return function(result)
        return {
            ["type"] = type,
            ["result"] = result
        }
    end
end

local letter_or_digit = parsec.choice(
    parsec.letter,
    parsec.digit
)

local identifier = parsec.sequence_of(
    parsec.letters,
    parsec.many(letter_or_digit):map(utility.string_concat)
):map(utility.string_concat)

local hex_digit = parsec.choice(
    parsec.digit,
    parsec.char('a'), parsec.char('A'),
    parsec.char('b'), parsec.char('B'),
    parsec.char('c'), parsec.char('C'),
    parsec.char('d'), parsec.char('D'),
    parsec.char('e'), parsec.char('E'),
    parsec.char('f'), parsec.char('F')
)

local hex_literal = parsec.sequence_of(
    parsec.choice(
        parsec.str('0x'),
        parsec.str('0x')
    ),
    parsec.many1(hex_digit)
):map(function(result) return result[2] end
):map(utility.string_concat):chain(
    function(result)
        local hex_number = tonumber(result, 16)
        if hex_number ~= nil then
            return parsec.succeed(hex_number)
        end

        return parsec.fail("Not a valid hex literal.")
    end
):map(astype('hex_literal'))

local operator = parsec.choice(
    parsec.char('+'):map(astype('operator_add')),
    parsec.char('-'):map(astype('operator_subtract')),
    parsec.char('*'):map(astype('operator_multiply'))
)

local paren_expression = parsec.contextual(coroutine.create(
    function()
        local states = {
            ["open_paren"] = 0,
            ["operator_or_closing_paren"] = 1,
            ["element_or_opening_paren"] = 2,
            ["close_paren"] = 3,
        }

        local current_state = states.element_or_opening_paren
        local expression = { }
        local stack = { expression }

        while true do
            local next_char = coroutine.yield(parsec.peek)
            if current_state == states.open_paren then
                coroutine.yield(parsec.char('('))
                expression[#expression + 1] = { }
                stack[#stack + 1] = expression[#expression]
                coroutine.yield(parsec.optional_blank_space)
                current_state = states.element_or_opening_paren
            elseif current_state == states.close_paren then
                coroutine.yield(parsec.char(')'))
                table.remove(stack, 1)
                if #stack == 1 then
                    break
                end

                coroutine.yield(parsec.optional_blank_space)
                current_state = states.operator_or_closing_paren
            elseif current_state == states.element_or_opening_paren then
                if next_char == ')' then
                    coroutine.yield(parsec.fail('unexpected end of expression.'))
                elseif next_char == '(' then
                    current_state = states.open_paren
                else
                    stack[#stack][#stack[#stack] + 1] = coroutine.yield(
                        parsec.choice(
                            hex_literal,
                            identifier
                        )
                    )
                    coroutine.yield(parsec.optional_blank_space)
                    current_state = states.operator_or_closing_paren
                end
            elseif current_state == states.operator_or_closing_paren then
                if next_char == ')' then
                    current_state = states.close_paren
                    goto continue
                end

                stack[#stack][#stack[#stack] + 1] = coroutine.yield(operator)
                coroutine.yield(parsec.optional_blank_space)
                current_state = states.element_or_opening_paren
            else
                error('Unknown state reached in paren_expression.')
            end
            ::continue::
        end

        return astype('paren_expression')(expression)
    end
))

local square_bracket_expression = parsec.contextual(coroutine.create(
    function()
        local states = {
            ["expect_element"] = 0,
            ["expect_operator"] = 1,
        }

        coroutine.yield(parsec.char('['))
        coroutine.yield(parsec.optional_blank_space)

        local expression = { }
        local current_state = states.expect_element

        while true do
            if current_state == states.expect_element then
                local result = coroutine.yield(
                    parsec.choice(
                        hex_literal,
                        identifier,
                        paren_expression
                    )
                )

                expression[#expression + 1] = result
                current_state = states.expect_operator
                coroutine.yield(parsec.optional_blank_space)
            elseif current_state == states.expect_operator then
                local next_char = coroutine.yield(parsec.peek)
                if next_char == ']' then
                    coroutine.yield(parsec.char(']'))
                    coroutine.yield(parsec.optional_blank_space)
                    break
                end

                local result = coroutine.yield(operator)
                expression[#expression + 1] = result
                current_state = states.expect_element
                coroutine.yield(parsec.optional_blank_space)
            end
        end

        return astype('square_bracket_expression')(expression)
    end
))

local mov_literal_to_register = parsec.contextual(coroutine.create(
    function ()
        coroutine.yield(parsec.str('mov'))

        local next_char = coroutine.yield(parsec.peek)
        if next_char ~= '[' then
            coroutine.yield(
                parsec.many1(parsec.blank_space_char):error_map(
                    function(s, i)
                        return "expected blank space after 'mov' at index " .. i .. "."
                    end
                )
            )
        end

        local arg1 = coroutine.yield(
            parsec.choice(
                hex_literal,
                square_bracket_expression
            )
        )

        coroutine.yield(parsec.optional_blank_space)
        coroutine.yield(parsec.char(','))
        coroutine.yield(parsec.optional_blank_space)
        local arg2 = coroutine.yield(parsec.letters)
        coroutine.yield(parsec.optional_blank_space)

        return astype('instruction')({
            ["instruction"] = "mov",
            ["arguments"] = {arg1, arg2}
        })
    end
))

print(
    inspect.inspect(
        mov_literal_to_register:run('mov0x0,rax')
    )
)
