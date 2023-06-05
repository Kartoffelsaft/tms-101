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

i16_to_deg :: proc(x: i16) -> f32 {
    return cast(f32)x * (360.0 / 0xffff)
}
i16_to_rad :: proc(x: i16) -> f32 {
    return cast(f32)x * (2 * math.PI / 0xffff)
}

READ_HANDLES := map[string]ReadHandle {
    "rng"    = read_rng,
    "msx"    = read_msx,
    "msy"    = read_msy,
    "resx"   = read_resx,
    "resy"   = read_resy,
    "fps"    = read_fps,
    "frame"  = read_frame,
    "input"  = read_input,
    "minput" = read_minput,
    "rom"    = read_rom,
}
WRITE_HANDLES := map[string]proc(i16) {
    "rng"  = write_rng,
    "void" = write_void,
    "bg"   = write_bg,
    "tcol" = write_tcol,
    "draw" = write_draw,
    "blit" = write_blit,
    "dbox" = write_dbox,
    "dtxt" = write_dtxt,
    "dnum" = write_dnum,
    "scale"= write_scale,
    "rot"  = write_rot,
    "fps"  = write_fps,
    "rom"  = write_rom,
}

read_rng :: proc() -> i16 { 
    return transmute(i16)cast(u16)(rand.int31() & 0xffff) 
}
write_rng :: proc(x: i16) { 
    rand.set_global_seed(cast(u64)x) 
}

read_msx :: proc() -> i16 {
    pos, scale := ctx.get_virtual_display_pos_scale()
    return cast(i16)((rl.GetMouseX() - cast(i32)pos.x)/scale)
}

read_msy :: proc() -> i16 { 
    pos, scale := ctx.get_virtual_display_pos_scale()
    return cast(i16)((rl.GetMouseY() - cast(i32)pos.y)/scale)
}

read_resx :: proc() -> i16 { 
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    return cast(i16)ctx.vDisplay.texture.width 
}

read_resy :: proc() -> i16 { 
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    return cast(i16)ctx.vDisplay.texture.height 
}

read_fps :: proc() -> i16 { 
    return cast(i16)rl.GetFPS() 
}
write_fps :: proc(x: i16) { 
    rl.SetTargetFPS(cast(i32)x) 
}

read_frame :: proc() -> i16 { 
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    return transmute(i16)cast(u16)ctx.frame 
}

read_input :: proc() -> i16 { 
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    return cast(i16)input.next_input(&ctx.inputlist) 
}

read_minput :: proc() -> i16 { 
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    return transmute(i16)ctx.inputlist.mouseInputs 
}

read_rom :: proc() -> i16 {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    return rom.read_rom(&ctx.rom)
}
write_rom :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    switch transmute(u16)x {
        case 0x8000: ctx.rom.readIndex = 0
        case 0x7fff: ctx.rom.readIndex = len(ctx.rom.data)
        case: ctx.rom.readIndex += math.clamp(cast(int)x, 0, len(ctx.rom.data))
    }
}


write_void :: proc(x: i16) {}


// Drawing

write_bg :: proc(x: i16) {
    rl.ClearBackground(writehandle_to_color(x)) 
}

write_tcol :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    ctx.textColor = writehandle_to_color(x) 
}

write_draw :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    rl.DrawTexturePro(
        ctx.spritemap,
        {cast(f32)((x & 0xf) << 3), cast(f32)((x & 0xf0) >> 1), 8, 8},
        {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy, cast(f32)ctx.drawScale, cast(f32)ctx.drawScale},
        {0, 0},
        ctx.drawRotation,
        rl.WHITE,
    )
    if ctx.drawRotation == 0 do ctx.prg.regx += cast(i16)ctx.drawScale
    else {
        r := ctx.drawRotationI * complex(cast(f32)ctx.drawScale, 0)
        ctx.prg.regx += real(r)
        ctx.prg.regy += imag(r)
    }
}

write_blit :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    rl.DrawPixel(cast(i32)ctx.prg.regx, cast(i32)ctx.prg.regy, writehandle_to_color(x))
    ctx.prg.regx += 1
}

write_dbox :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    log.debugf("rotation is %f", ctx.drawRotation)
    rl.DrawRectanglePro({
        cast(f32)ctx.prg.regx, 
        cast(f32)ctx.prg.regy, 
        cast(f32)ctx.drawScale, 
        cast(f32)ctx.drawScale,
    }, {0, 0}, ctx.drawRotation, writehandle_to_color(x))

    if ctx.drawRotation == 0 do ctx.prg.regx += cast(i16)ctx.drawScale
    else {
        r := ctx.drawRotationI * complex(cast(f32)ctx.drawScale, 0)
        ctx.prg.regx += real(r)
        ctx.prg.regy += imag(r)
    }
}

write_dtxt :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    char := cast(u8)(x & 0xff)
    rl.DrawTextCodepoint(ctx.font, cast(rune)char, {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy}, 6, ctx.textColor)
    charwidth := cast(i16)rl.GetGlyphAtlasRec(ctx.font, cast(rune)char).width + 1 // +1 for padding
    log.debugf("character %c has width %d", char, charwidth)
    ctx.prg.regx += charwidth
}

write_dnum :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    buf := [7]byte{} // -32768 + null terminator
    str := strconv.itoa(buf[:], cast(int)x)
    width := cast(i16)rl.MeasureTextEx(ctx.font, strings.unsafe_string_to_cstring(str), 6, 1).x + 1
    rl.DrawTextEx(ctx.font, strings.unsafe_string_to_cstring(str), {cast(f32)ctx.prg.regx, cast(f32)ctx.prg.regy}, 6, 1, ctx.textColor)
    ctx.prg.regx += width
}

write_scale :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    ctx.drawScale = cast(i32)x
}

write_rot :: proc(x: i16) {
    ctx := cast(^ctx.TmxCtx)context.user_ptr

    ctx.drawRotation = i16_to_deg(x)
    rad := i16_to_rad(x)
    ctx.drawRotationI = complex(math.cos(rad), math.sin(rad))
}
