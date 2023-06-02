package ctx

import    "core:math"
import rl "vendor:raylib"

import "../asmcomp/program"
import "../input"
import "../rom"

TmxCtx :: struct {
    prg: ^program.Program,
    vDisplay: rl.RenderTexture,
    rom: rom.Rom,
    spritemap: rl.Texture,
    font: rl.Font,
    inputlist: input.InputList,
    frame: uint,
}

get_virtual_display_pos_scale :: proc(vdisp := (cast(^TmxCtx)context.user_ptr).vDisplay) -> (pos: rl.Vector2, scale: i32) {
    scale = math.max(1, math.min(rl.GetScreenWidth() / vdisp.texture.width, rl.GetScreenHeight() / vdisp.texture.height))
    
    pos = rl.Vector2{
        cast(f32)(rl.GetScreenWidth () - scale * vdisp.texture.width ),
        cast(f32)(rl.GetScreenHeight() - scale * vdisp.texture.height),
    } * 0.5

    return
}

delete_tmxctx :: proc(ctx: TmxCtx) {
    program.delete_program(ctx.prg^)
    free(ctx.prg)

    rl.UnloadRenderTexture(ctx.vDisplay)
    rl.UnloadTexture(ctx.spritemap)
    rl.UnloadFont(ctx.font)
}
