package tokenizer

import "core:strings"
import "core:strconv"
import "core:slice"

import "../lexer"

Mov     :: struct{}
Add     :: struct{}
Sub     :: struct{}
Mul     :: struct{}
Div     :: struct{}
Mod     :: struct{}
BNd     :: struct{}
BOr     :: struct{}
BXr     :: struct{}

Prn     :: struct{}

Mrk     :: struct{}
Jmp     :: struct{}
Fjp     :: struct{}
Tjp     :: struct{}
Nxt     :: struct{}
Nop     :: struct{}

RegA    :: struct{}
RegB    :: struct{}
RegC    :: struct{}
RegD    :: struct{}
RegT    :: struct{}
RegX    :: struct{}
RegY    :: struct{}

Num     :: struct{ val: i16    }
Idn     :: struct{ val: string }
Str     :: struct{ val: string }
Ref     :: struct{ val: ^Token }
Hdl     :: struct{ val: string }

Token :: union {
    Mov,
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    BNd,
    BOr,
    BXr,

    Prn,

    Mrk,
    Jmp,
    Fjp,
    Tjp,
    Nxt,
    Nop,

    RegA,
    RegB,
    RegC,
    RegD,
    RegT,
    RegX,
    RegY,

    Num,
    Idn,
    Str,
    Ref,
    Hdl,
}

parse_num :: proc(s: string) -> (value: i16, ok: bool) {
    v: int = ---

    switch s[0] {
        case 'b'     : v, ok = strconv.parse_int(s[1:], 2 )
        case 'o'     : v, ok = strconv.parse_int(s[1:], 8 )
        case 'd'     : v, ok = strconv.parse_int(s[1:], 10)
        case 'h', '#': v, ok = strconv.parse_int(s[1:], 16)

        case: v, ok = strconv.parse_int(s)
    }

    value = i16(v)

    return
}

tokenize :: proc(s: string) -> Token {
    sl := strings.to_lower(s)
    defer delete(sl)

    switch sl {
        case "mov", "move": return Mov{}

        case "add"        : return Add{}
        case "sub"        : return Sub{}
        case "mul"        : return Mul{}
        case "div"        : return Div{} 
        case "mod"        : return Mod{} 
        case "bnd"        : return BNd{} 
        case "bor"        : return BOr{} 
        case "bxr"        : return BXr{} 

        case "prn"        : return Prn{}

        case "mrk"        : return Mrk{} 
        case "jmp"        : return Jmp{}
        case "fjp"        : return Fjp{}
        case "tjp"        : return Tjp{}
        case "nxt"        : return Nxt{}
        case "nop"        : return Nop{}

        case "rega", "a"  : return RegA{}
        case "regb", "b"  : return RegB{}
        case "regc", "c"  : return RegC{}
        case "regd", "d"  : return RegD{}

        case "regt", "t"  : return RegT{}
        case "regx", "x"  : return RegX{}
        case "regy", "y"  : return RegY{}

        case: {
            i, parsed := parse_num(s)

            switch {
                case parsed: return Num{i}
                case s[0] == '"': 
                    r, a, ok := strconv.unquote_string(s)
                    if !ok do r = strings.clone_from(s[1:len(s)-1])
                    else if !a do r = strings.clone_from(r)
                    return Str{r}
                case s[0] == '&': return Ref{new_clone(tokenize(s[1:]))}
                case s[0] == '@': return Hdl{s[1:]}
                case: return Idn{s}
            }
        }
    }
    
    return nil
}

Instruction_Tokenized :: struct {
    lineNum: int,
    tokens: []Token,
}

tokenize_instuction_str :: proc(instr: lexer.Instruction_Str) -> Instruction_Tokenized {
    return Instruction_Tokenized {
        lineNum = instr.lineNum,
        tokens = slice.mapper(instr.contents, tokenize),
    }
}

