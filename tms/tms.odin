package tms

import    "core:os"
import    "core:fmt"
import    "core:mem"
import    "core:log"
import    "core:time"
import rl "vendor:raylib"

import    "asmcomp"
import    "asmcomp/program/prgrunner"
import    "ctx"

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

    rl.InitWindow(800, 600, "tms-101")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        prgrunner.run_program()
    }
}

main :: proc() {

    trackalloc: mem.Tracking_Allocator
    mem.tracking_allocator_init(&trackalloc, context.allocator)
    context.allocator = mem.tracking_allocator(&trackalloc)

    context.logger = log.create_console_logger(log.Level.Info)

    _main()

    log.destroy_console_logger(context.logger)

    for _, leak in trackalloc.allocation_map {
        log.warnf("%v leaked at %v", leak.size, leak.location)
    }
    for badFree in trackalloc.bad_free_array {
        log.warnf("bad free at %v", badFree.location)
    }
}
