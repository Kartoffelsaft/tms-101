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
        hdl, ok := handles.READ_HANDLES[rv.name]
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
        hdl, ok := handles.WRITE_HANDLES[rv.name]
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

Macro :: struct {
    instrs: []tokenizer.Instruction_Tokenized,
    args: map[tokenizer.Idn]int,
    locals: map[tokenizer.Idn]struct{},
}

extract_macros :: proc(instructions: []tokenizer.Instruction_Tokenized) -> (
    nonmacros: []tokenizer.Instruction_Tokenized,
    macros: map[string]Macro,
    ok: bool,
) {
    nonmacrosDyn := make([dynamic]tokenizer.Instruction_Tokenized, 0, len(instructions))
    macros = make(map[string]Macro)

    Mode :: enum {
        NoMacro,
        InMacro,
    }
    mode := Mode.NoMacro
    thisMacroName  : string
    thisMacroInstrs: [dynamic]tokenizer.Instruction_Tokenized
    thisMacroArgs  : map[tokenizer.Idn]int
    thisMacroLocals: map[tokenizer.Idn]struct{}

    for instr in instructions {
        switch mode {
            case .NoMacro:
                mcb, ismcb := instr.tokens[0].(tokenizer.Mkb)
                if !ismcb {
                    append(&nonmacrosDyn, instr) 
                    continue
                }

                mode = Mode.InMacro
                thisMacroName   = mcb.name
                thisMacroInstrs = make([dynamic]tokenizer.Instruction_Tokenized)
                thisMacroArgs   = make(map[tokenizer.Idn]int, len(instr.tokens) - 1)
                thisMacroLocals = make(map[tokenizer.Idn]struct{})

                for i in 1..<len(instr.tokens) {
                    idn, isIdn := instr.tokens[i].(tokenizer.Idn)
                    if !isIdn {
                        log.errorf("Argument %v on line %i for macro %s is not an identifier", instr.tokens[i], instr.lineNum, mcb.name)
                        delete(nonmacrosDyn)
                        delete(macros)
                        return ---, ---, false
                    }
                    thisMacroArgs[idn] = i-1
                }
            case .InMacro:
                mce, ismce := instr.tokens[0].(tokenizer.Mke)
                if !ismce {
                    append(&thisMacroInstrs, instr) 

                    localDef, _, isDef := parse_def(instr)
                    if isDef do thisMacroLocals[localDef] = ---

                    localMrk, isMrk := parse_mark(instr)
                    if isMrk do thisMacroLocals[localMrk] = ---
                    
                    continue
                }

                macros[thisMacroName] = {
                    thisMacroInstrs[:],
                    thisMacroArgs,
                    thisMacroLocals,
                }
                mode = Mode.NoMacro
                thisMacroName = ---
                thisMacroInstrs = ---
                thisMacroArgs = ---
                thisMacroLocals = ---
        }
    }

    if mode == Mode.InMacro {
        log.errorf("Macro %s not terminated", thisMacroName)
        delete(nonmacrosDyn)
        delete(macros)
        delete(thisMacroInstrs)
        return ---, ---, false
    }

    return nonmacrosDyn[:], macros, true
}

expand_macro :: proc(macro: Macro, args: []tokenizer.Token, line: int) -> []tokenizer.Instruction_Tokenized {
    retinstrs := make([dynamic]tokenizer.Instruction_Tokenized)

    for instr in macro.instrs {
        virtualInstr := tokenizer.Instruction_Tokenized{
            line,
            slice.clone(instr.tokens),
        }
        for token, i in virtualInstr.tokens {
            idn, isIdn := token.(tokenizer.Idn)
            if !isIdn do continue

            if idn in macro.args do virtualInstr.tokens[i] = args[macro.args[idn]]
            else if idn in macro.locals {
                virtualIdnName := fmt.tprintf("%d%s", line, idn.name)
                virtualInstr.tokens[i] = tokenizer.Idn{virtualIdnName}
            }
        }

        append(&retinstrs, virtualInstr)
    }

    return retinstrs[:]
}

extract_nonoperators :: proc(instructions: []tokenizer.Instruction_Tokenized) -> (
    operators: []tokenizer.Instruction_Tokenized, 
    marks: map[string]int, 
    defs: map[string]tokenizer.Token, 
    ok: bool,
) {
    instructions, macros, mcok := extract_macros(instructions)
    if !mcok do return ---, ---, ---, false
    defer delete(instructions)
    defer delete(macros)
    defer for _, mc in macros {
        delete(mc.instrs)
        delete(mc.args)
        delete(mc.locals)
    }

    operatorsDyn := make([dynamic]tokenizer.Instruction_Tokenized, 0, len(instructions))
    marks = make(map[string]int)
    defs = make(map[string]tokenizer.Token)
    ok = true

    instrIdx := 0

    for instr in instructions {
        #partial switch tk in instr.tokens[0] {
            case tokenizer.Mrk:
                markName, mrkok := parse_mark(instr)
                if !mrkok {
                    delete(operatorsDyn)
                    delete(marks)
                    delete(defs)
                    return nil, nil, nil, false
                }

                marks[markName.name] = instrIdx
                continue

            case tokenizer.Def:
                defName, defTo, defOk := parse_def(instr)

                if !defOk {
                    delete(operatorsDyn)
                    delete(marks)
                    delete(defs)
                    return nil, nil, nil, false
                }

                defs[defName.name] = defTo
                continue

            case tokenizer.Mki:
                log.debug(instr)
                log.debug(macros)
                expanded := expand_macro(macros[tk.name], instr.tokens[1:], instr.lineNum)
                defer delete(expanded)

                ops, mrks, dfs, exok := extract_nonoperators(expanded)
                if !exok {
                    delete(operatorsDyn)
                    delete(marks)
                    delete(defs)
                }
                defer delete(ops)
                defer delete(mrks)
                defer delete(dfs)

                append(&operatorsDyn, ..ops)

                for mcMarkName, mcMarkTo in mrks {
                    marks[mcMarkName] = mcMarkTo + instrIdx
                }
                for mcDefName, mcDefTo in dfs {
                    defs[mcDefName] = mcDefTo
                }

                instrIdx += len(ops)

                continue
        }
        append(&operatorsDyn, instr)
        instrIdx += 1
    }

    operators = operatorsDyn[:]
    return
}

parse_mark :: proc(instr: tokenizer.Instruction_Tokenized) -> (tokenizer.Idn, bool) {
    mrk, isMrk := instr.tokens[0].(tokenizer.Mrk)
    if !isMrk {
        return ---, false
    }

    tkC := len(instr.tokens)
    if tkC != 2 { 
        log.errorf("Mark on line %d has wrong number of args", instr.lineNum)
        return ---, false
    }

    identifier, argIsId := instr.tokens[1].(tokenizer.Idn)
    if !argIsId {
        log.errorf("Mark on line %d has wrong argument type", instr.lineNum)
        return ---, false
    }

    return identifier, true
}

parse_def :: proc(instr: tokenizer.Instruction_Tokenized) -> (tokenizer.Idn, tokenizer.Token, bool) {
    def, isDef := instr.tokens[0].(tokenizer.Def)
    if !isDef do return ---, ---, false

    tkC := len(instr.tokens)
    if tkC != 3 {
        log.errorf("Def on line %d has wrong number of arguments", instr.lineNum)
        return ---, ---, false
    }

    identifier, argIsId := instr.tokens[1].(tokenizer.Idn)
    if !argIsId {
        log.errorf("Def on line %d has wrong argument type (not an identifier)", instr.lineNum)
        return ---, ---, false
    }

    return identifier, instr.tokens[2], true
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
            if !(ntar.name in marks) {
                log.errorf("Jmp on line %d cannot find matching mark %s", instr.lineNum, ntar.name)
                return nil, false
            }

            return Jmp{MarkTarget{marks[ntar.name]}}, true
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
            if !(ntar.name in marks) {
                log.errorf("Fjp on line %d cannot find matching mark %s", instr.lineNum, ntar.name)
                return nil, false
            }

            return Fjp{MarkTarget{marks[ntar.name]}}, true
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
            if !(ntar.name in marks) {
                log.errorf("Tjp on line %d cannot find matching mark %s", instr.lineNum, ntar.name)
                return nil, false
            }

            return Tjp{MarkTarget{marks[ntar.name]}}, true
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
        case tokenizer.Mkb : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Mki : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
        case tokenizer.Mke : log.errorf("invalid instruction on line %d", instr.lineNum); return nil, false
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
                if idn.name in defmap {
                    instr.tokens[j] = tokenizer.clone_token(defmap[idn.name])
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

