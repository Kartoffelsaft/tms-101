package rom

import "core:os"
import "core:log"
import "core:strings"
import "core:strconv"
import "core:slice"


Rom :: struct {
    data: []i16,
    readIndex: int,
}

read_rom :: proc(rom: ^Rom) -> (ret: i16) {
    ret = rom.data[rom.readIndex] if rom.readIndex < len(rom.data) else 0
    rom.readIndex += 1

    return
}

load_rom_from_filename :: proc(filename: string) -> Rom {
    if !os.exists(filename) {
        log.warnf("%s does not exist. If a rom file is not intended this can be safely ignored", filename)
        return Rom{{}, 0}
    }

    switch filename[strings.last_index(filename, "."):] {
        case ".csvrom": return load_csvrom_from_filename(filename)
        case ".binrom": return load_binrom_from_filename(filename)

        case: 
            log.warn("rom file extension not recognized. Interpreting as binrom")
            return load_binrom_from_filename(filename)
    }
}

load_csvrom_from_filename :: proc(file: string) -> Rom {
    csvdata, csvfok := os.read_entire_file_from_filename(file)
    defer delete(csvdata)
    csvstrings := strings.split(string(csvdata), ",")
    defer delete(csvstrings)
    data := slice.mapper(csvstrings, proc(s: string) -> i16 {
        datum, ok := strconv.parse_i64(s)
        if !ok do log.errorf("%s is a non-number", s)
        return cast(i16)datum
    })

    log.infof("Rom data: %v", data)

    return Rom{data, 0}
}

load_binrom_from_filename :: proc(file: string) -> Rom {
    data, dataok := os.read_entire_file_from_filename(file)
    log.infof("Rom data: %v", slice.reinterpret([]i16, data))
    return Rom{
        slice.reinterpret([]i16, data),
        0,
    }
}
