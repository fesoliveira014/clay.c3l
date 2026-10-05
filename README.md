# clay.c3l

C3 bindings for [Clay](https://github.com/nicbarker/clay), a single-header C UI layout library by
Nic Barker. Module `clay`, package `clay`, C3 0.8.3, Clay `main` at
`e6cc36941ab2af5d81107617039d6f527a1c660b`.

The binding is thin. `src/clay.c3i` declares Clay's types layout-exact and the bound functions
with `@cname`. `src/clay.c3` adds element ids, string views, sizing helpers and the element
macros. `src/layout_posix.c3` and `src/layout_windows.c3` pin the size, alignment and key field
offsets of every struct against the real header; `scripts/probe-layout.sh --check` regenerates and
compares them.

## Using it

Add the repository as a git submodule (with `--recursive`, for `vendor/clay`) into the directory
your project searches for libraries, then name `clay` as a dependency:

```json
{
  "dependency-search-paths": [ "lib" ],
  "dependencies": [ "clay" ]
}
```

The implementation translation unit `csrc/clay.c` compiles through the package's `c-sources` on
`linux-x64` and `windows-x64`. The Windows target sets `"wincrt": "static"`.

```c3
import clay;

fn clay::Dimensions measure(clay::CharsSlice text, clay::TextElementConfig* config, void* user) {
    return { (float)text.length * 8, (float)config.font_size };
}

fn void layout() {
    clay::set_max_element_count(1024);
    uint bytes = clay::min_memory_size();
    char[] memory = mem::new_array(char, bytes);
    clay::initialize(clay::create_arena(bytes, memory.ptr), { 800, 600 }, {});
    clay::set_measure_text_function(&measure, null);

    clay::begin_layout();
    clay::ElementDeclaration panel = {
        .layout = { .sizing = { clay::grow(), clay::fit() }, .padding = { 8, 8, 8, 8 } },
        .custom = { .custom_data = &panel },
    };
    clay::@element(clay::id(1), &panel) {
        clay::text("Hello", { .font_size = 16 });
    };
    foreach (command : clay::end_layout(0).commands()) {
        // draw command.bounding_box by command.command_type
    }
}
```

## Surface

| Clay | C3 |
| --- | --- |
| `Clay_MinMemorySize`, `Clay_CreateArenaWithCapacityAndMemory`, `Clay_Initialize` | `min_memory_size`, `create_arena`, `initialize` |
| `Clay_GetCurrentContext`, `Clay_SetCurrentContext` | `get_current_context`, `set_current_context` |
| `Clay_SetLayoutDimensions`, `Clay_BeginLayout`, `Clay_EndLayout` | `set_layout_dimensions`, `begin_layout`, `end_layout` |
| `Clay_SetPointerState`, `Clay_GetPointerOverIds`, `Clay_GetElementData` | `set_pointer_state`, `get_pointer_over_ids`, `get_element_data` |
| `Clay_UpdateScrollContainers`, `Clay_GetScrollOffset` | `update_scroll_containers`, `get_scroll_offset` |
| `Clay_SetMeasureTextFunction`, `Clay_ResetMeasureTextCache` | `set_measure_text_function`, `reset_measure_text_cache` |
| `Clay_SetMaxElementCount`, `Clay_SetMaxMeasureTextCacheWordCount`, `Clay_SetCullingEnabled` | `set_max_element_count`, `set_max_measure_text_cache_word_count`, `set_culling_enabled` |
| `CLAY(id, decl) { ... }` | `clay::@element(id, &decl) { ... };` |
| `Clay__OpenElementWithId`, `Clay__ConfigureOpenElementPtr`, `Clay__CloseElement` | `open_element(id)`, `configure_element(&decl)`, `close_element()` |
| `CLAY_TEXT(text, config)` | `text(String, TextElementConfig)` |

Open and configure are separate calls because a scroll container reads `get_scroll_offset()`
between them:

```c3
clay::open_element(clay::id(7));
clay::ElementDeclaration scroller = { .clip = { .vertical = true, .child_offset = clay::get_scroll_offset() } };
clay::configure_element(&scroller);
// children
clay::close_element();
```

`Clay_String` is `Chars` and `Clay_StringSlice` is `CharsSlice`, so C3's `String` keeps its name in
every importer. Text passed to `text` must outlive the layout and its render commands.

Clay keeps one current context and one process-wide measure function; the measure function's user
pointer belongs to the context. Errors arrive through the `ErrorHandler` passed to `initialize`.

## Platform layouts

Clay's packed enums are one byte under gcc and clang but int-sized under MSVC's C compiler, which
c3c uses for `c-sources` on Windows. The binding declares them over `PackedEnum` (`int` under
`@feat(WIN32)`, `char` elsewhere) and pins each platform's layout separately; for example,
`ElementDeclaration` is 248 bytes on Linux and 272 on Windows.

## Verification

```sh
scripts/probe-layout.sh --check
c3c compile-only --no-obj src/*.c3i src/*.c3 && rm -rf obj
cd test && c3c test
```

CI runs all three on Linux (`cc`) and Windows (`cl`).

## License

The binding is MIT (`LICENSE`). Clay is zlib/libpng; see `NOTICE` and `vendor/clay/LICENSE.md`.
