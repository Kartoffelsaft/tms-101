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

    QuoteMode :: enum {
        none,
        single,
        double,
    }
    qm := QuoteMode.none

    for i := 0; i < len(remainingStr); i += 1 {
        this := remainingStr[i]
        if this == '\\' {
            // escaped char
            i += 1
            continue
        }

        if this == '"' {
            switch qm {
                case .none:
                    qm = .double
                    nextTokens := strings.split_multi(remainingStr[:i], {" ", "\t"})
                    defer delete(nextTokens)
                    append(&ret, ..nextTokens)
                    remainingStr = remainingStr[i:]
                    i = 1
                case .single:
                    continue
                case .double:
                    qm = .none
                    append(&ret, remainingStr[:i+1])
                    remainingStr = remainingStr[i+1:]
                    i = 0
            }
        }
        if this == '\'' {
            switch qm {
                case .none:
                    qm = .single
                    nextTokens := strings.split_multi(remainingStr[:i], {" ", "\t"})
                    defer delete(nextTokens)
                    append(&ret, ..nextTokens)
                    remainingStr = remainingStr[i:]
                    i = 1
                case .single:
                    qm = .none
                    append(&ret, remainingStr[:i+1])
                    remainingStr = remainingStr[i+1:]
                    i = 0
                case .double:
                    continue
            }
        }
    }

    if qm != QuoteMode.none {
        log.errorf("unmatched quotes: %s", line)
        delete(ret)
        return nil, false
    }

    if len(remainingStr) != 0 {
        nextTokens := strings.split_multi(remainingStr, {" ", "\t"})
        defer delete(nextTokens)
        append(&ret, ..nextTokens)
    }

    return ret[:], true
}

