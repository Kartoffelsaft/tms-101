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
    for instr in prg.instructions {
        #partial switch i in instr {
            case Prn:
                if s, isS := i.val.(Str); isS do delete(s.val)
        }
    }
    delete(prg.instructions)
}
