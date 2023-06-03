package handles

import    "core:log"
import    "core:math/rand"
import    "core:math"
import    "core:slice"
import    "core:strconv"
import    "core:strings"
import rl "vendor:raylib"

import "../ctx"
import "../input"
import "../rom"

ReadHandle :: #type proc() -> i16
WriteHandle :: #type proc(i16)

writehandle_to_color :: proc(x: i16) -> rl.Color {
    return rl.Color{
        cast(u8)(transmute(u16)x & 0b11111_000000_00000 >> 8),
        cast(u8)(transmute(u16)x & 0b00000_111111_00000 >> 3),
        cast(u8)(transmute(u16)x & 0b00000_000000_11111 << 3),
        255,
    }
}

READ_HANDLES := map[string]ReadHandle {
    "rng"  = proc() -> i16 { return transmute(i16)cast(u16)(rand.int31() & 0xffff) },
    "msx"  = proc() -> i16 {
        pos, scale := ctx.get_virtual_display_pos_scale()
        return cast(i16)((rl.GetMouseX() - cast(i32)pos.x)/scale)
    },
    "msy"  = proc() -> i16 { 
        pos, scale := ctx.get_virtual_display_pos_scale()
        return cast(i16)((rl.GetMouseY() - cast(i32)pos.y)/scale)
    },
    "resx"   = proc() -> i16 { return cast(i16)(cast(^ctx.TmxCtx)context.user_ptr).vDisplay.texture.width },
    "resy"   = proc() -> i16 { return cast(i16)(cast(^ctx.TmxCtx)context.user_ptr).vDisplay.texture.height },
    "fps"    = proc() -> i16 { return cast(i16)rl.GetFPS() },
    "frame"  = proc() -> i16 { return transmute(i16)cast(u16)(cast(^ctx.TmxCtx)context.user_ptr).frame },
    "input"  = proc() -> i16 { return cast(i16)input.next_input(&(cast(^ctx.TmxCtx)context.user_ptr).inputlist) },
    "minput" = proc() -> i16 { return transmute(i16)(cast(^ctx.TmxCtx)context.user_ptr).inputlist.mouseInputs },
    "rom"    = proc() -> i16 {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        return rom.read_rom(&ctx.rom)
    },
}
WRITE_HANDLES := map[string]proc(i16) {
    "rng"  = proc(x: i16) { rand.set_global_seed(cast(u64)x) },
    "void" = proc(x: i16) {},
    "bg"   = proc(x: i16) { rl.ClearBackground(writehandle_to_color(x)) },
    "tcol" = proc(x: i16) { (cast(^ctx.TmxCtx)context.user_ptr).textColor = writehandle_to_color(x) },
    "draw" = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        rl.DrawTexturePro(
            ctx.spritemap,
            {cast(f32)((x & 0xf) << 3), cast(f32)((x & 0xf0) >> 1), 8, 8},
            {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy  , 8, 8},
            {0, 0},
            0,
            rl.WHITE,
        )
        ctx.prg.regx += 8
        log.debugf("draw texture %d to %d, %d", x, ctx.prg.regx, ctx.prg.regy)
    },
    "blit" = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        rl.DrawPixel(cast(i32)ctx.prg.regx, cast(i32)ctx.prg.regy, writehandle_to_color(x))
        ctx.prg.regx += 1
    },
    "fbox" = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        rl.DrawRectangle(cast(i32)ctx.prg.regx, cast(i32)ctx.prg.regy, 8, 8, writehandle_to_color(x))
        ctx.prg.regx += 8
    },
    "dtxt"  = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        char := cast(u8)(x & 0xff)
        rl.DrawTextCodepoint(ctx.font, cast(rune)char, {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy}, 6, ctx.textColor)
        charwidth := cast(i16)rl.GetGlyphAtlasRec(ctx.font, cast(rune)char).width + 1 // +1 for padding
        log.debugf("character %c has width %d", char, charwidth)
        ctx.prg.regx += charwidth
    },
    "dnum"  = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        buf := [7]byte{} // -32768 + null terminator
        str := strconv.itoa(buf[:], cast(int)x)
        width := cast(i16)rl.MeasureTextEx(ctx.font, strings.unsafe_string_to_cstring(str), 6, 1).x + 1
        rl.DrawTextEx(ctx.font, strings.unsafe_string_to_cstring(str), {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy}, 6, 1, ctx.textColor)
        ctx.prg.regx += width
    },
    "fps"  = proc(x: i16) { rl.SetTargetFPS(cast(i32)x) },
    "rom"    = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        switch transmute(u16)x {
            case 0x8000: ctx.rom.readIndex = 0
            case 0x7fff: ctx.rom.readIndex = len(ctx.rom.data)
            case: ctx.rom.readIndex += math.clamp(cast(int)x, 0, len(ctx.rom.data))
        }
    },
}
