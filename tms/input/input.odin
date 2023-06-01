package input

import rl "vendor:raylib"
import    "core:slice"

InputList :: struct {
    currentInputs: []rl.KeyboardKey,
    nextInputIdx: int,
    mouseInputs: bit_set[rl.MouseButton; u16],
}

refresh_inputs :: proc(inpl: ^InputList) {
    oldInputs := inpl.currentInputs
    newInputs := make([dynamic]rl.KeyboardKey, 0, len(inpl.currentInputs))

    stillHeld := slice.filter(oldInputs, proc(k: rl.KeyboardKey) -> bool { return rl.IsKeyDown(k) })
    defer delete(stillHeld)
    append(&newInputs, ..stillHeld)

    for {
        nInp := rl.GetKeyPressed() 
        if cast(i32)nInp == 0 do break

        append(&newInputs, nInp)
    }

    delete(inpl.currentInputs)
    inpl.currentInputs = newInputs[:]
    inpl.nextInputIdx = 0

    inpl.mouseInputs = {}
    for i in rl.MouseButton {
        if rl.IsMouseButtonDown(i) do incl(&inpl.mouseInputs, i)
    }
}

next_input :: proc(inpl: ^InputList) -> (ret: rl.KeyboardKey) {
    ret = cast(rl.KeyboardKey)0

    if inpl.nextInputIdx >= len(inpl.currentInputs) do return 

    ret = inpl.currentInputs[inpl.nextInputIdx]
    inpl.nextInputIdx += 1

    return
}
