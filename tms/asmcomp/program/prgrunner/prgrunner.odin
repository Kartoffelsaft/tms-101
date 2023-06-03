package prgrunner

import   "core:fmt"
import p ".."
import   "../../../ctx"

when #config(BENCHMARK, false) {
    import "core:time"
    import "core:log"

    Benchmarker :: struct {
        timer: time.Stopwatch,
        instructions: u128,
    }

    bm := Benchmarker{{}, 0}
}


run_program :: proc() {
    when #defined(bm) do time.stopwatch_start(&bm.timer)
    for step_program() {}
    when #defined(bm) do time.stopwatch_stop(&bm.timer)
}

print_program_benchmark :: proc() {
    when #defined(bm) {
        log.infof("%d instructions in %v seconds", bm.instructions, time.duration_seconds(time.stopwatch_duration(bm.timer)))
    }
}

@(private)
step_program :: proc(prg := (cast(^ctx.TmxCtx)context.user_ptr).prg) -> bool #no_bounds_check {
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
            // why does odin require the right side of shifts to be unsigned?
        case Shf: amt := read(instr.rhs); write(read(instr.lhs) >> transmute(u16)amt if amt > 0 else read(instr.lhs) << transmute(u16)(-amt), instr.target)
        case Mov: write(read(instr.source), instr.target)
        case Prn: print(instr.val)
        case Jmp: prg.instructionIdx = instr.target.instrIdx - 1 // -1 because of below ++
        case Fjp: if prg.regt == 0 do prg.instructionIdx = instr.target.instrIdx - 1 
        case Tjp: if prg.regt != 0 do prg.instructionIdx = instr.target.instrIdx - 1 
        case Nxt: prg.instructionIdx += 1; return false
        case Nop:
    }

    prg.instructionIdx += 1
    when #defined(bm) do bm.instructions += 1

    return true
}

@(private)
read :: proc(val: p.ReadVal, prg := (cast(^ctx.TmxCtx)context.user_ptr).prg) -> i16 {
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
write :: proc(val: i16, trg: p.WriteVal, prg := (cast(^ctx.TmxCtx)context.user_ptr).prg) {
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
print :: proc(val: p.Printable, prg := (cast(^ctx.TmxCtx)context.user_ptr).prg) {
    using p

    switch v in val {
        case ReadVal: fmt.println(read(v))
        case Str: fmt.println(v.val)
    }
}
