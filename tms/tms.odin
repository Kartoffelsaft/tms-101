package tms

import    "core:os"
import    "core:fmt"
import    "core:mem"
import    "core:log"
import    "core:time"
import    "core:math"
import    "core:strings"
import    "core:slice"
import rl "vendor:raylib"

import    "asmcomp"
import    "asmcomp/program"
import    "asmcomp/program/prgrunner"
import    "ctx"
import    "pconf"
import    "rom"
import    "input"

DEFAULT_FONT := #load("../bswf.png")

init :: proc() -> (uctx: ^ctx.TmxCtx) {
    conf, confok := pconf.load_program_config()
    if !confok do return nil
    defer pconf.delete_program_config(conf)

    uctx = new(ctx.TmxCtx)

    compStopwatch := time.Stopwatch{}
    time.stopwatch_start(&compStopwatch)
    prg, prgok := asmcomp.compile(conf.asmfile)
    if !prgok {
        log.error("compile failed with errors")
        return
    }
    time.stopwatch_stop(&compStopwatch)
    log.info("compile took", time.stopwatch_duration(compStopwatch))

    uctx.prg = prg
    uctx.rom = rom.load_rom_from_filename(conf.romfile)

    rl.InitWindow(800, 600, "tms-101")

    rl.SetTargetFPS(60)

    uctx.vDisplay = rl.LoadRenderTexture(cast(i32)conf.resx, cast(i32)conf.resy)
    uctx.spritemap = rl.LoadTexture(strings.clone_to_cstring(conf.spritemapfile))
    uctx.font = rl.LoadFontFromImage(rl.LoadImageFromMemory(".png", slice.as_ptr(DEFAULT_FONT), cast(i32)len(DEFAULT_FONT)), rl.MAGENTA, ' ')

    return uctx
}

_main :: proc() {
    uctx := init()
    if uctx == nil do return
    context.user_ptr = uctx
    defer free(uctx)
    defer rl.CloseWindow()
    defer ctx.delete_tmxctx(uctx^)
    
    for !rl.WindowShouldClose() {
        input.refresh_inputs(&uctx.inputlist)

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

        uctx.frame += 1
    }
}

main :: proc() {

    trackalloc: mem.Tracking_Allocator
    mem.tracking_allocator_init(&trackalloc, context.allocator)
    context.allocator = mem.tracking_allocator(&trackalloc)

    context.logger = log.create_console_logger(log.Level.Info)

    _main()

    prgrunner.print_program_benchmark()

    log.destroy_console_logger(context.logger)

    for _, leak in trackalloc.allocation_map {
        log.warnf("%v leaked at %v", leak.size, leak.location)
    }
    for badFree in trackalloc.bad_free_array {
        log.warnf("bad free at %v", badFree.location)
    }
}
