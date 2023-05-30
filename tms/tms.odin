package tms

import    "core:os"
import    "core:fmt"
import    "core:mem"
import    "core:log"
import    "core:time"
import    "core:math"
import    "core:strings"
import rl "vendor:raylib"

import    "asmcomp"
import    "asmcomp/program"
import    "asmcomp/program/prgrunner"
import    "ctx"

_main :: proc() {
    if (len(os.args) < 3) {
        fmt.eprintln("Not enough files given to read (needs 2)")
        return
    }

    uctx := new(ctx.TmxCtx)
    context.user_ptr = uctx
    defer free(uctx)

    compStopwatch := time.Stopwatch{}
    time.stopwatch_start(&compStopwatch)
    prg, ok := asmcomp.compile(os.args[1])
    if !ok do log.error("compile failed with errors")
    defer program.delete_program(prg^)
    defer free(prg)
    time.stopwatch_stop(&compStopwatch)
    log.info("compile took", time.stopwatch_duration(compStopwatch))

    uctx.prg = prg

    rl.InitWindow(800, 600, "tms-101")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    uctx.vDisplay = rl.LoadRenderTexture(80, 80)
    uctx.spritemap = rl.LoadTexture(strings.clone_to_cstring(os.args[2]))
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)

        {
            rl.BeginTextureMode(uctx.vDisplay)
            defer rl.EndTextureMode()
            prgrunner.run_program()
        }

        pos, scale := ctx.get_virtual_display_pos_scale()
        rl.DrawTexturePro(
            uctx.vDisplay.texture,
            rl.Rectangle{0, 0, cast(f32)uctx.vDisplay.texture.width, cast(f32)-uctx.vDisplay.texture.height},
            rl.Rectangle{pos.x, pos.y, cast(f32)(uctx.vDisplay.texture.width * scale), cast(f32)(uctx.vDisplay.texture.height * scale)},
            {0, 0},
            0,
            rl.WHITE,
        )
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
