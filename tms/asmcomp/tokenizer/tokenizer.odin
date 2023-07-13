package tokenizer

import "core:strings"
import "core:strconv"
import "core:slice"
import "core:log"

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
Shf     :: struct{}

Prn     :: struct{}

Mrk     :: struct{}
Def     :: struct{}
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

Num     :: struct{ val : i16    }
Idn     :: struct{ name: string }
Str     :: struct{ val : string }
Ref     :: struct{ val : ^Token }
Hdl     :: struct{ name: string }
Mkb     :: struct{ name: string }
Mki     :: struct{ name: string }
Mke     :: struct{}

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
    Shf,

    Prn,

    Mrk,
    Def,
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
    Mkb,
    Mki,
    Mke,
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

tokenize :: proc(s: string) -> (Token, bool) {
    sl := strings.to_lower(s)
    defer delete(sl)

    switch sl {
        case "mov", "move": return Mov{}, true

        case "add"        : return Add{}, true
        case "sub"        : return Sub{}, true
        case "mul"        : return Mul{}, true
        case "div"        : return Div{}, true 
        case "mod"        : return Mod{}, true 
        case "bnd"        : return BNd{}, true 
        case "bor"        : return BOr{}, true 
        case "bxr"        : return BXr{}, true 
        case "shf"        : return Shf{}, true 

        case "prn"        : return Prn{}, true

        case "mrk"        : return Mrk{}, true 
        case "def"        : return Def{}, true
        case "jmp"        : return Jmp{}, true
        case "fjp"        : return Fjp{}, true
        case "tjp"        : return Tjp{}, true
        case "nxt"        : return Nxt{}, true
        case "nop"        : return Nop{}, true

        case "rega", "a"  : return RegA{}, true
        case "regb", "b"  : return RegB{}, true
        case "regc", "c"  : return RegC{}, true
        case "regd", "d"  : return RegD{}, true

        case "regt", "t"  : return RegT{}, true
        case "regx", "x"  : return RegX{}, true
        case "regy", "y"  : return RegY{}, true

        case: {
            i, parsed := parse_num(s)

            switch {
                case parsed: return Num{i}, true
                case s[0] == '"': 
                    r, a, ok := strconv.unquote_string(s)
                    if !ok {
                    }
                    else if !a do r = strings.clone_from(r)
                    return Str{r}, true
                case s[0] == '\'': 
                    c, m, t, ok := strconv.unquote_char(s[1:len(s)-1], '\'')
                    if !ok {
                        log.errorf("could not parse character: %s", s)
                        return nil, false
                    } else if len(t) > 0 {
                        log.errorf("single quotes used for more than one char: %s", s)
                        return nil, false
                    } else if m {
                        log.warn("characters beyond ascii likely won't work")
                    }
                    return Num{cast(i16)c}, true
                case s[0] == '&': 
                    to, ok := tokenize(s[1:])
                    if !ok {
                        log.errorf("reference to invalid: %s", s)
                        return nil, false
                    }
                    return Ref{new_clone(to)}, true
                case s[0] == '@': return Hdl{s[1:]}, true
                case s[0] == '?': return Mkb{s[1:]}, true
                case s[0] == '!': return Mki{s[1:]}, true
                case s == "/?" : return Mke{}, true
                case: return Idn{s}, true
            }
        }
    }
    
    return nil, false
}

Instruction_Tokenized :: struct {
    lineNum: int,
    tokens: []Token,
}

tokenize_instuction_str :: proc(instr: lexer.Instruction_Str) -> (Instruction_Tokenized, bool) {
    tks := make([]Token, len(instr.contents))
    for c, i in instr.contents {
        ok := false
        tks[i], ok = tokenize(c)
        if !ok do return {}, false
    }

    return Instruction_Tokenized {
        lineNum = instr.lineNum,
        tokens = tks,
    }, true
}

tokenize_instuctions_str :: proc(instrs: []lexer.Instruction_Str) -> (ret: []Instruction_Tokenized, ok: bool) {
    ret = make([]Instruction_Tokenized, len(instrs))
    for s, i in instrs {
        ret[i] = tokenize_instuction_str(s) or_return
    }

    return ret, true
}

delete_instructions_tok :: proc(instrs: []Instruction_Tokenized) {
    for instr in instrs {
        for token in instr.tokens do delete_token(token)
        delete(instr.tokens)
    }
    delete(instrs)
}

delete_token :: proc(tok: Token) {
    #partial switch i in tok {
        case Ref: 
            delete_token(i.val^)
            free(i.val)
    }
}

clone_token :: proc(tok: Token) -> (ret: Token) {
    ret = tok
    #partial switch i in tok {
        case Ref: 
            ret = Ref{new_clone(i.val^)}
    }
    return
}
