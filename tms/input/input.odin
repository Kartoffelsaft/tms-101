package input

import rl "vendor:raylib"
import    "core:slice"

InputList :: struct {
    currentInputs: []rl.KeyboardKey,
    nextInputIdx: int,
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
}

next_input :: proc(inpl: ^InputList) -> (ret: rl.KeyboardKey) {
    ret = cast(rl.KeyboardKey)0

    if inpl.nextInputIdx >= len(inpl.currentInputs) do return 

    ret = inpl.currentInputs[inpl.nextInputIdx]
    inpl.nextInputIdx += 1

    return
}
