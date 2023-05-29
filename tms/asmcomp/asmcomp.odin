package asmcomp

import "core:os"
import "core:fmt"
import "core:log"
import "core:slice"

import "lexer"
import "tokenizer"
import "parser"
import "program"


compile :: proc(filename: string) -> (program.Program, bool) {
    content, success := os.read_entire_file_from_filename(filename)
    defer delete(content)

    if success {
        contentStr := string(content)
        instrsStr, okis := lexer.file_contents_to_intructions_str(contentStr)
        if !okis do return ---, false
        defer {
            for inst in instrsStr do lexer.delete_instruction_str(inst)
            delete(instrsStr)
        }

        if context.logger.lowest_level <= log.Level.Info do fmt.println()
        for i in instrsStr {
            log.infof("%d: \t%v", i.lineNum, i.contents)
        }


        instrsTok := slice.mapper(instrsStr, tokenizer.tokenize_instuction_str)
        defer {
            for inst in instrsTok do delete(inst.tokens)
            delete(instrsTok)
        }

        if context.logger.lowest_level <= log.Level.Info do fmt.println()
        for i in instrsTok {
            log.infof("%d: \t%v", i.lineNum, i.tokens)
        }

        
        finalInstructions, parseSuccess := parser.parse_instructions_tok(instrsTok)
        if !parseSuccess do return ---, false

        return program.generate_program(finalInstructions), true
    } else {
        log.error("could not open asm file")
    }

    return ---, false
}
