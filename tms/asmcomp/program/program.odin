package program

import "core:fmt"

Program :: struct {
    rega: i16,
    regb: i16,
    regc: i16,
    regd: i16,
    regt: i16,
    regx: i16,
    regy: i16,

    instructions: []Instruction,
    instructionIdx: int,

    memory: [0x1_0000]i16,
}

RegA        :: struct{}
RegB        :: struct{}
RegC        :: struct{}
RegD        :: struct{}
RegT        :: struct{}
RegX        :: struct{}
RegY        :: struct{}

Num         :: struct{ val: i16 }
Str         :: struct{ val: string }
Ref         :: struct{ val: ^ReadVal }
RHdl        :: struct{ val: proc() -> i16 }
WHdl        :: struct{ val: proc(i16) }

MarkTarget  :: struct{ instrIdx: int }

ReadVal :: union {
    RegA,
    RegB,
    RegC,
    RegD,
    RegT,
    RegX,
    RegY,
    Num ,
    Ref ,
    RHdl,
}

WriteVal :: union {
    RegA,
    RegB,
    RegC,
    RegD,
    RegT,
    RegX,
    RegY,
    Ref ,
    WHdl,
}

Printable :: union {
    ReadVal,
    Str,
}

Add         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
Sub         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
Mul         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
Div         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
Mod         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
BNd         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
BOr         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
BXr         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }
Shf         :: struct{ lhs: ReadVal, rhs: ReadVal, target: WriteVal }

Mov         :: struct{ source: ReadVal, target: WriteVal }

Prn         :: struct{ val: Printable }

Jmp         :: struct{ target: MarkTarget }
Fjp         :: struct{ target: MarkTarget }
Tjp         :: struct{ target: MarkTarget }
Nxt         :: struct{}
Nop         :: struct{}

Instruction :: union {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    BNd,
    BOr,
    BXr,
    Shf,
    Mov,
    Prn,
    Jmp,
    Fjp,
    Tjp,
    Nxt,
    Nop,
}

generate_program :: proc(instrs: []Instruction) -> (prg: ^Program) {
    prg = new(Program)
    prg.instructions = instrs
    return
}

delete_program :: proc(prg: Program) {
    delete_ref_rv :: proc(v: ReadVal) { if ref, ok := v.(Ref); ok {
        delete_ref_rv(ref.val^) 
        free(ref.val)
    }}
    delete_ref_wv :: proc(v: WriteVal) { if ref, ok := v.(Ref); ok {
        delete_ref_rv(ref.val^) 
        free(ref.val)
    }}
    delete_ref :: proc {delete_ref_rv, delete_ref_wv}

    for instr in prg.instructions {
        #partial switch i in instr {
            case Prn:
                if s, isS := i.val.(Str); isS do delete(s.val)

            // again with the whole DRY principle; I can think of ways to not repeat
            // myself but I'm not doing it because you wouldn't understand what you're
            // looking at like you would here
            case Add: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case Sub: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case Mul: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case Div: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case Mod: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case BNd: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case BOr: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case BXr: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case Shf: delete_ref(i.lhs); delete_ref(i.rhs); delete_ref(i.target)
            case Mov: delete_ref(i.source); delete_ref(i.target)
        }
    }
    delete(prg.instructions)
}
