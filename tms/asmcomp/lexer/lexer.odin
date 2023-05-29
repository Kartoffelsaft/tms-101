package lexer

import "core:strings"
import "core:slice"
import "core:log"

Instruction_Str :: struct {
    lineNum: int,
    contents: []string,
}

delete_instruction_str :: proc(is: Instruction_Str) {
    delete(is.contents)
}

file_contents_to_intructions_str :: proc(content: string) -> ([]Instruction_Str, bool) {
    contentLines := strings.split_lines(content)
    defer delete(contentLines)

    instructions := make([]Instruction_Str, len(contentLines))
    defer delete(instructions)

    for line, lineNum in contentLines {

        contentTrimmed := trim_comment(line)

        contentTokens, okct := split_tokens(contentTrimmed)
        if !okct do return nil, false
        defer delete(contentTokens)

        contentCode := slice.filter(contentTokens, proc(s: string) -> bool { return s != "" })

        instructions[lineNum].lineNum  = lineNum
        instructions[lineNum].contents = contentCode

    }

    return slice.filter(instructions, proc(i: Instruction_Str) -> bool { return len(i.contents) > 0 }), true
}

trim_comment :: proc(line: string) -> string {
    commentIdx := strings.index(line, ";")
    nocomment := line[:commentIdx >= 0? commentIdx : len(line)]

    trimmed := strings.trim_space(nocomment)

    return trimmed
}

split_tokens :: proc(line: string) -> ([]string, bool) {
    ret := make([dynamic]string)
    quotSection := 0
    remainingStr := line[:]

    for do if n := strings.index(remainingStr[quotSection%2:], "\""); n >= 0 {
        switch quotSection % 2 {
            case 0: // this is outside of " "
                nextTokens := strings.split_multi(remainingStr[:n], {" ", "\t"})
                defer delete(nextTokens)
                append(&ret, ..nextTokens)
                remainingStr = remainingStr[n:]
            case 1: // this is inside of " "
                // +1 to n to include the close quote
                // another +1 because n does not account for the open quote
                append(&ret, remainingStr[:n+2])
                remainingStr = remainingStr[n+2:]
        }
        quotSection += 1
    } else do break

    remTokens := strings.split_multi(remainingStr, {" ", "\t"})
    defer delete(remTokens)
    append(&ret, ..remTokens)

    if quotSection % 2 == 0 do return ret[:], true
    else {
        log.errorf("line \"%s\" is missing matching quotations", line)
        delete(ret)
        return nil, false
    }
}

