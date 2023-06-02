package parser

import    "core:fmt"
import    "core:log"
import    "core:slice"
import    "core:math/rand"
import rl "vendor:raylib"

import    "../tokenizer"
import    "../program"
import    "../../ctx"
import    "../../handles"

token_as_readval :: proc(tk: tokenizer.Token) -> (program.ReadVal, bool) {
    using program
    if rv, ok := tk.(tokenizer.RegA); ok do return RegA{}, true
    if rv, ok := tk.(tokenizer.RegB); ok do return RegB{}, true
    if rv, ok := tk.(tokenizer.RegC); ok do return RegC{}, true
    if rv, ok := tk.(tokenizer.RegD); ok do return RegD{}, true
    if rv, ok := tk.(tokenizer.RegT); ok do return RegT{}, true
    if rv, ok := tk.(tokenizer.RegX); ok do return RegX{}, true
    if rv, ok := tk.(tokenizer.RegY); ok do return RegY{}, true
    if rv, ok := tk.(tokenizer.Num ); ok do return Num{rv.val}, true
    if rv, ok := tk.(tokenizer.Ref ); ok {
        to, ok := token_as_readval(rv.val^)
        if !ok do return nil, false
        else do return Ref{new_clone(to)}, true
    }
    if rv, ok := tk.(tokenizer.Hdl ); ok {
        hdl, ok := handles.READ_HANDLES[rv.val]
        if !ok do return nil, false
        else do return RHdl{hdl}, true
    }


    return nil, false
}

token_as_writeval :: proc(tk: tokenizer.Token) -> (program.WriteVal, bool) {
    using program
    if rv, ok := tk.(tokenizer.RegA); ok do return RegA{}, true
    if rv, ok := tk.(tokenizer.RegB); ok do return RegB{}, true
    if rv, ok := tk.(tokenizer.RegC); ok do return RegC{}, true
    if rv, ok := tk.(tokenizer.RegD); ok do return RegD{}, true
    if rv, ok := tk.(tokenizer.RegT); ok do return RegT{}, true
    if rv, ok := tk.(tokenizer.RegX); ok do return RegX{}, true
    if rv, ok := tk.(tokenizer.RegY); ok do return RegY{}, true
    if rv, ok := tk.(tokenizer.Ref ); ok {
        to, ok := token_as_readval(rv.val^)
        if !ok do return nil, false
        else do return Ref{new_clone(to)}, true
    }
    if rv, ok := tk.(tokenizer.Hdl ); ok {
        hdl, ok := handles.WRITE_HANDLES[rv.val]
        if !ok do return nil, false
        else do return WHdl{hdl}, true
    }

    return nil, false
}

token_as_printable :: proc(tk: tokenizer.Token) -> (program.Printable, bool) {
    using program
    if rv, ok := token_as_readval(tk); ok do return rv, true
    if rv, ok := tk.(tokenizer.Str); ok do return Str{rv.val}, true

    return nil, false
}


extract_nonoperators :: proc(instructions: []tokenizer.Instruction_Tokenized) -> (unmarked: []tokenizer.Instruction_Tokenized, marks: map[string]int, defs: map[string]tokenizer.Token, ok: bool) {
    unmarkedDyn := make([dynamic]tokenizer.Instruction_Tokenized, 0, len(instructions))
    marks = make(map[string]int)
    defs = make(map[string]tokenizer.Token)
    ok = true

    instrIdx := 0

    for instr in instructions {
        #partial switch _ in instr.tokens[0] {
            case tokenizer.Mrk:
                tkC := len(instr.tokens)
                // would be a switch but you can't initialize variables in a case

                if tkC != 2 { 
                    log.errorf("Mark on line %d has wrong number of args", instr.lineNum)
                    delete(unmarkedDyn)
                    delete(marks)
                    delete(defs)
                    return nil, nil, nil, false
                }
                identifier, argIsId := instr.tokens[1].(tokenizer.Idn)
                if !argIsId {
                    log.errorf("Mark on line %d has wrong argument type", instr.lineNum)
                    delete(unmarkedDyn)
                    delete(marks)
                    delete(defs)
                    return nil, nil, nil, false
                }

                marks[identifier.val] = instrIdx
                continue

            case tokenizer.Def:
                tkC := len(instr.tokens)

                if tkC != 3 {
                    log.errorf("Def on line %d has wrong number of arguments", instr.lineNum)
                    delete(unmarkedDyn)
                    delete(marks)
                    delete(defs)
                    return nil, nil, nil, false
                }
                identifier, argIsId := instr.tokens[1].(tokenizer.Idn)
                if !argIsId {
                    log.errorf("Def on line %d has wrong argument type (not an identifier)", instr.lineNum)
                    delete(unmarkedDyn)
                    delete(marks)
                    delete(defs)
                    return nil, nil, nil, false
                }

                defs[identifier.val] = instr.tokens[2]

                continue
        }
        append(&unmarkedDyn, instr)
        instrIdx += 1
    }

    unmarked = unmarkedDyn[:]
    return
}

parse_instruction :: proc(instr: tokenizer.Instruction_Tokenized, marks: map[string]int) -> (program.Instruction, bool) {
    using program

    // I'm sure there's a way to apply DRY here, but I highly doubt that'd be more readable
    switch _ in instr.tokens[0] {
        case tokenizer.Add:
            if len(instr.tokens) != 4 {
                log.errorf("Add on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return Add{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Sub:
            if len(instr.tokens) != 4 {
                log.errorf("Sub on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return Sub{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Mul:
            if len(instr.tokens) != 4 {
                log.errorf("Mul on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return Mul{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Div:
            if len(instr.tokens) != 4 {
                log.errorf("Div on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return Div{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Mod:
            if len(instr.tokens) != 4 {
                log.errorf("Mod on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return Mod{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.BNd:
            if len(instr.tokens) != 4 {
                log.errorf("BNd on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return BNd{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.BOr:
            if len(instr.tokens) != 4 {
                log.errorf("BOr on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return BOr{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.BXr:
            if len(instr.tokens) != 4 {
                log.errorf("BXr on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return BXr{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Shf:
            if len(instr.tokens) != 4 {
                log.errorf("Shf on line %d has %d arguments, should take 3", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nlhs, oklhs := token_as_readval(instr.tokens[1])
            nrhs, okrhs := token_as_readval(instr.tokens[2])
            ntar, oktar := token_as_writeval(instr.tokens[3])

            if oklhs && okrhs && oktar {
                return Shf{nlhs, nrhs, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Mov:
            if len(instr.tokens) != 3 {
                log.errorf("Mov on line %d has %d arguments, should take 2", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nsrc, oksrc := token_as_readval(instr.tokens[1])
            ntar, oktar := token_as_writeval(instr.tokens[2])

            if oksrc && oktar {
                return Mov{nsrc, ntar}, true
            } else {
                log.errorf("Invalid argument on line %d", instr.lineNum)
                return nil, false
            }
        case tokenizer.Jmp:
            if len(instr.tokens) != 2 {
                log.errorf("Jmp on line %d has %d arguments, should take 1", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            ntar, oktar := instr.tokens[1].(tokenizer.Idn)
            if !oktar {
                log.errorf("Jmp argument on line %d is not an identifier", instr.lineNum)
                return nil, false
            }
            if !(ntar.val in marks) {
                log.errorf("Jmp on line %d cannot find matching mark %s", instr.lineNum, ntar.val)
                return nil, false
            }

            return Jmp{MarkTarget{marks[ntar.val]}}, true
        case tokenizer.Fjp:
            if len(instr.tokens) != 2 {
                log.errorf("Fjp on line %d has %d arguments, should take 1", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            ntar, oktar := instr.tokens[1].(tokenizer.Idn)
            if !oktar {
                log.errorf("Fjp argument on line %d is not an identifier", instr.lineNum)
                return nil, false
            }
            if !(ntar.val in marks) {
                log.errorf("Fjp on line %d cannot find matching mark %s", instr.lineNum, ntar.val)
                return nil, false
            }

            return Fjp{MarkTarget{marks[ntar.val]}}, true
        case tokenizer.Tjp:
            if len(instr.tokens) != 2 {
                log.errorf("Tjp on line %d has %d arguments, should take 1", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            ntar, oktar := instr.tokens[1].(tokenizer.Idn)
            if !oktar {
                log.errorf("Tjp argument on line %d is not an identifier", instr.lineNum)
                return nil, false
            }
            if !(ntar.val in marks) {
                log.errorf("Tjp on line %d cannot find matching mark %s", instr.lineNum, ntar.val)
                return nil, false
            }

            return Tjp{MarkTarget{marks[ntar.val]}}, true
        case tokenizer.Nxt:
            if len(instr.tokens) != 1 {
                log.errorf("Nxt on line %d has %d arguments, should take 0", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            
            return Nxt{}, true
        case tokenizer.Nop:
            if len(instr.tokens) != 1 {
                log.errorf("Nop on line %d has %d arguments, should take 0", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            
            return Nop{}, true
            
        case tokenizer.Prn:
            if len(instr.tokens) != 2 {
                log.errorf("Prn on line %d has %d arguments, should take 1", instr.lineNum, len(instr.tokens))
                return nil, false
            }
            nval, okval := token_as_printable(instr.tokens[1])
            return Prn{nval}, true


        case tokenizer.RegA: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.RegB: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.RegC: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.RegD: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.RegT: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.RegX: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.RegY: log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Ref : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Num : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Idn : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Str : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Hdl : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Mrk : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Def : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
    }

    return nil, false
}

parse_instructions_tok :: proc(instructions: []tokenizer.Instruction_Tokenized) -> ([]program.Instruction, bool) {
    unmarked, markmap, defmap, okExtract := extract_nonoperators(instructions)
    if !okExtract do return nil, false
    defer delete(unmarked)
    defer delete(markmap)
    defer delete(defmap)
    
    if context.logger.lowest_level <= log.Level.Info do fmt.println()
    for instr, i in unmarked {
        log.infof("%d->%d: \t%v", i, instr.lineNum, instr.tokens)
    }

    if context.logger.lowest_level <= log.Level.Info do fmt.println()
    for mark, target in markmap {
        log.infof("%s -> %d", mark, target)
    }

    parsed := make([]program.Instruction, len(unmarked))
    for instr, i in unmarked {
        for tk, j in instr.tokens { 
            if idn, isIdn := tk.(tokenizer.Idn); isIdn {
                if idn.val in defmap {
                    instr.tokens[j] = tokenizer.clone_token(defmap[idn.val])
                }
            }
        }

        ok := false
        parsed[i], ok = parse_instruction(instr, markmap)
        if !ok {
            delete(parsed)
            return nil, false
        }
    }

    if context.logger.lowest_level <= log.Level.Info do fmt.println()
    for instr, i in parsed {
        log.infof("%d: \t%v", i, instr)
    }

    return parsed, true
}

