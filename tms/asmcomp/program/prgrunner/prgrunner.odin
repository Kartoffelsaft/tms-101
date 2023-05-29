package prgrunner

import   "core:fmt"
import p ".."
import   "../../../ctx"

run_program :: proc(ctx := cast(^ctx.TmxCtx)context.user_ptr) {
    context.user_ptr = &ctx.prg // 1,000x perf improvement for some reason
    for step_program() {}
}

@(private)
step_program :: proc(prg := cast(^p.Program)context.user_ptr) -> bool #no_bounds_check {
    using p

    if prg.instructionIdx > len(prg.instructions) do prg.instructionIdx = 0

    switch instr in prg.instructions[prg.instructionIdx] {
        case Add: write(read(instr.lhs) + read(instr.rhs), instr.target)
        case Sub: write(read(instr.lhs) - read(instr.rhs), instr.target)
        case Mul: write(read(instr.lhs) * read(instr.rhs), instr.target)
        case Div: write(read(instr.lhs) / read(instr.rhs), instr.target)
        case Mod: write(read(instr.lhs) % read(instr.rhs), instr.target)
        case BNd: write(read(instr.lhs) & read(instr.rhs), instr.target)
        case BOr: write(read(instr.lhs) | read(instr.rhs), instr.target)
        case BXr: write(read(instr.lhs) ~ read(instr.rhs), instr.target)
        case Mov: write(read(instr.source), instr.target)
        case Prn: print(instr.val)
        case Jmp: prg.instructionIdx = instr.target.instrIdx - 1 // -1 because of below ++
        case Fjp: if prg.regt == 0 do prg.instructionIdx = instr.target.instrIdx - 1 
        case Tjp: if prg.regt != 0 do prg.instructionIdx = instr.target.instrIdx - 1 
        case Nxt: return false
        case Nop:
    }

    prg.instructionIdx += 1

    return true
}

@(private)
read :: proc(val: p.ReadVal, prg := cast(^p.Program)context.user_ptr) -> i16 {
    using p

    switch v in val {
        case RegA: return prg.rega
        case RegB: return prg.regb
        case RegC: return prg.regc
        case RegD: return prg.regd
        case RegT: return prg.regt
        case RegX: return prg.regx
        case RegY: return prg.regy
        case Num : return v.val
        case Ref : return prg.memory[transmute(u16)read(v.val^)]
        case RHdl: return v.val()
    }

    return 0 // unreachable
}

@(private)
write :: proc(val: i16, trg: p.WriteVal, prg := cast(^p.Program)context.user_ptr) {
    using p

    switch t in trg {
        case RegA: prg.rega = val
        case RegB: prg.regb = val
        case RegC: prg.regc = val
        case RegD: prg.regd = val
        case RegT: prg.regt = val
        case RegX: prg.regx = val
        case RegY: prg.regy = val
        case Ref : prg.memory[transmute(u16)read(t.val^)] = val
        case WHdl: t.val(val)
    }
}

@(private)
print :: proc(val: p.Printable, prg := cast(^p.Program)context.user_ptr) {
    using p

    switch v in val {
        case ReadVal: fmt.println(read(v))
        case Str: fmt.println(v.val)
    }
}
