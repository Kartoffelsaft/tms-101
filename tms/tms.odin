package tms

import "core:os"
import "core:fmt"
import "core:mem"
import "core:log"
import "core:time"

import "asmcomp"
import "asmcomp/program/prgrunner"
import "ctx"

_main :: proc() {
    if (len(os.args) < 2) {
        fmt.eprintln("No file given to read")
        return
    }

    context.user_ptr = new(ctx.TmxCtx)
    defer free(context.user_ptr)

    compStopwatch := time.Stopwatch{}
    time.stopwatch_start(&compStopwatch)
    prg, ok := asmcomp.compile(os.args[1])
    if !ok do log.error("compile failed with errors")
    defer free(prg)
    time.stopwatch_stop(&compStopwatch)
    log.info("compile took", time.stopwatch_duration(compStopwatch))

    (cast(^ctx.TmxCtx)context.user_ptr).prg = prg
    
    runStopwatch := time.Stopwatch{}
    time.stopwatch_start(&runStopwatch)
    prgrunner.run_program()
    time.stopwatch_stop(&runStopwatch)
    log.info("run took", time.stopwatch_duration(runStopwatch))
}

main :: proc() {

    trackalloc: mem.Tracking_Allocator
    mem.tracking_allocator_init(&trackalloc, context.allocator)
    context.allocator = mem.tracking_allocator(&trackalloc)

    context.logger = log.create_console_logger()

    _main()

    log.destroy_console_logger(context.logger)

    for _, leak in trackalloc.allocation_map {
        log.warnf("%v leaked at %v", leak.size, leak.location)
    }
    for badFree in trackalloc.bad_free_array {
        log.warnf("bad free at %v", badFree.location)
    }
}
