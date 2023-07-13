package asmcomp

import "core:os"
import "core:fmt"
import "core:log"
import "core:slice"

import "lexer"
import "tokenizer"
import "parser"
import "program"


compile :: proc(filename: string) -> (^program.Program, bool) {
    content, success := os.read_entire_file_from_filename(filename)
    defer delete(content)

    if success {
        contentStr := string(content)
        instrsStr, okis := lexer.file_contents_to_intructions_str(contentStr)
        if !okis do return nil, false
        defer {
            for inst in instrsStr do lexer.delete_instruction_str(inst)
            delete(instrsStr)
        }

        if context.logger.lowest_level <= log.Level.Info do fmt.println()
        for i in instrsStr {
            log.infof("%d: \t%v", i.lineNum, i.contents)
        }


        instrsTok, oktok := tokenizer.tokenize_instuctions_str(instrsStr)
        if !oktok do return nil, false
        defer tokenizer.delete_instructions_tok(instrsTok)

        if context.logger.lowest_level <= log.Level.Info do fmt.println()
        for i in instrsTok {
            log.infof("%d: \t%v", i.lineNum, i.tokens)
        }

        
        finalInstructions, parseSuccess := parser.parse_instructions_tok(instrsTok)
        if !parseSuccess do return nil, false

        return program.generate_program(finalInstructions), true
    } else {
        log.error("could not open asm file")
    }

    return nil, false
}
