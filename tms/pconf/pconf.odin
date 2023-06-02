package pconf

import "core:encoding/json"
import "core:os"
import "core:log"
import "core:strings"

ProgramConfig :: struct {
    asmfile: string,
    spritemapfile: string,
    romfile: string,
    resx: i32,
    resy: i32,
}

load_program_config :: proc() -> (ProgramConfig, bool) {
    if len(os.args) < 2 {
        log.error("You must specify a program to load")
        return ---, false
    }
    conffile := strings.clone(os.args[1]) if os.is_file(os.args[1]) else strings.concatenate({os.args[1], "/conf.json"})
    defer delete(conffile)
    confdir := strings.trim_right_proc(conffile, proc(r: rune) -> bool {return r != '/' && r !='\\'})

    conffiledata, ok := os.read_entire_file_from_filename(conffile)
    if !ok {
        log.errorf("could not open file %s", conffile)
        return ---, false
    }
    defer delete(conffiledata)
    
    confjson, err := json.parse(conffiledata)
    if err != .None {
        log.errorf("json error: %v", err)
        return ---, false
    }
    defer json.destroy_value(confjson)

    confroot := confjson.(json.Object)

    log.infof("config: %v", confroot)

    return ProgramConfig{
        asmfile = strings.concatenate({confdir, confroot["asmfile"].(json.String) or_else "src.tmsasm"}),
        spritemapfile = strings.concatenate({confdir, confroot["spritemapfile"].(json.String) or_else "spritemap.png"}),
        romfile = strings.concatenate({confdir, confroot["romfile"].(json.String) or_else "data.csvrom"}),
        resx = cast(i32)(confroot["resx"].(json.Integer) or_else cast(i64)(confroot["resx"].(json.Float) or_else 120)),
        resy = cast(i32)(confroot["resx"].(json.Integer) or_else cast(i64)(confroot["resy"].(json.Float) or_else 120)),
    }, true
}

delete_program_config :: proc(cfg: ProgramConfig) {
    delete(cfg.asmfile)
    delete(cfg.spritemapfile)
}
