package ctx

import    "core:math"
import rl "vendor:raylib"

import "../asmcomp/program"

TmxCtx :: struct {
    prg: ^program.Program,
    vDisplay: rl.RenderTexture,
    spritemap: rl.Texture,
}

get_virtual_display_pos_scale :: proc(vdisp := (cast(^TmxCtx)context.user_ptr).vDisplay) -> (pos: rl.Vector2, scale: i32) {
    scale = math.max(1, math.min(rl.GetScreenWidth() / vdisp.texture.width, rl.GetScreenHeight() / vdisp.texture.height))
    
    pos = rl.Vector2{
        cast(f32)(rl.GetScreenWidth () - scale * vdisp.texture.width ),
        cast(f32)(rl.GetScreenHeight() - scale * vdisp.texture.height),
    } * 0.5

    return
}
