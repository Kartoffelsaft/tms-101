package handles

import    "core:log"
import    "core:math/rand"
import    "core:slice"
import rl "vendor:raylib"

import "../ctx"

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
    "resx" = proc() -> i16 { return cast(i16)(cast(^ctx.TmxCtx)context.user_ptr).vDisplay.texture.width },
    "resy" = proc() -> i16 { return cast(i16)(cast(^ctx.TmxCtx)context.user_ptr).vDisplay.texture.height },
    "fps"  = proc() -> i16 { return cast(i16)rl.GetFPS() },
}
WRITE_HANDLES := map[string]proc(i16) {
    "rng"  = proc(x: i16) { rand.set_global_seed(cast(u64)x) },
    "void" = proc(x: i16) {},
    "bg"   = proc(x: i16) { rl.ClearBackground(writehandle_to_color(x)) },
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
        log.debugf("draw texture %d to %d, %d", x, ctx.prg.regx, ctx.prg.regy)
    },
    "txt"  = proc(x: i16) {
        ctx := cast(^ctx.TmxCtx)context.user_ptr
        char := cast(u8)(x & 0xff)
        rl.DrawTextCodepoint(ctx.font, cast(rune)char, {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy}, 6, rl.WHITE)
        charwidth := cast(i16)rl.GetGlyphAtlasRec(ctx.font, cast(rune)char).width + 1 // +1 for padding
        log.debugf("character %c has width %d", char, charwidth)
        ctx.prg.regx += charwidth
    },
    "fps"  = proc(x: i16) { rl.SetTargetFPS(cast(i32)x) },
}
