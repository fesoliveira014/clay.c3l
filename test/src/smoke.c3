module clay_smoke;

import clay;

int errors;

fn clay::Dimensions measure(clay::CharsSlice text, clay::TextElementConfig* config, void* user) {
    return { (float)text.length * 10, (float)config.font_size };
}

fn void on_error(clay::ErrorData error) {
    errors++;
}

fn clay::RenderCommandArray layout(int* marker) {
    clay::begin_layout();
    clay::ElementDeclaration root = {
        .layout = {
            .sizing           = { clay::fixed(400), clay::fixed(300) },
            .padding          = { 10, 10, 10, 10 },
            .child_gap        = 5,
            .layout_direction = TOP_TO_BOTTOM,
        },
    };
    clay::@element(clay::id(1), &root) {
        clay::ElementDeclaration box = {
            .layout = { .sizing = { clay::fixed(100), clay::fixed(50) } },
            .custom = { .custom_data = marker },
        };
        clay::@element(clay::id(2), &box) {};
        clay::text("hello world", { .font_size = 20 });
        clay::ElementDeclaration tip = {
            .layout   = { .sizing = { clay::fixed(30), clay::fixed(10) } },
            .custom   = { .custom_data = marker },
            .floating = {
                .attach_to            = PARENT,
                .z_index              = 5,
                .pointer_capture_mode = PASSTHROUGH,
                .attach_points        = { .element = LEFT_TOP, .parent = RIGHT_BOTTOM },
            },
        };
        clay::@element(clay::id(3), &tip) {};
        clay::open_element(clay::id(4));
        clay::ElementDeclaration scroller = {
            .layout = { .sizing = { clay::fixed(50), clay::fixed(20) } },
            .clip   = { .vertical = true, .child_offset = clay::get_scroll_offset() },
        };
        clay::configure_element(&scroller);
        clay::text("one two", { .font_size = 20 });
        clay::close_element();
    };
    return clay::end_layout(0);
}

fn void test_layout_text_floating_clip_and_pointer() @test {
    clay::set_max_element_count(64);
    uint bytes = clay::min_memory_size();
    char[] memory = mem::new_array(char, bytes);
    defer free(memory);
    clay::Context* context = clay::initialize(
        clay::create_arena(bytes, memory.ptr),
        { 400, 300 },
        { .error_handler_function = &on_error },
    );
    defer clay::set_current_context(null);
    assert(context == clay::get_current_context());
    clay::set_measure_text_function(&measure, null);

    int marker;
    layout(&marker);
    clay::RenderCommand[] commands = layout(&marker).commands();
    assert(errors == 0);

    assert(commands[0].command_type == CUSTOM && commands[0].id == 2);
    assert(commands[0].render_data.custom.custom_data == &marker);
    assert(commands[0].bounding_box.x == 10 && commands[0].bounding_box.y == 10);
    assert(commands[0].bounding_box.width == 100 && commands[0].bounding_box.height == 50);
    assert(commands[1].command_type == TEXT && commands[1].render_data.text.string_contents.str() == "hello world");
    assert(commands[1].bounding_box.y == 65 && commands[1].bounding_box.width == 110);
    assert(commands[2].command_type == SCISSOR_START && commands[2].id == 4);
    assert(commands[3].command_type == TEXT && commands[3].render_data.text.string_contents.str() == "one");
    assert(commands[4].command_type == TEXT && commands[4].render_data.text.string_contents.str() == "two");
    assert(commands[5].command_type == SCISSOR_END);
    assert(commands[6].command_type == CUSTOM && commands[6].id == 3 && commands[6].z_index == 5);
    assert(commands[6].bounding_box.x == 400 && commands[6].bounding_box.y == 300);

    clay::set_pointer_state({ 20, 20 }, false);
    clay::ElementId[] over = clay::get_pointer_over_ids().ids();
    assert(over.len == 3 && over[1].id == 1 && over[2].id == 2);
    clay::ElementData data = clay::get_element_data(clay::id(2));
    assert(data.found && data.bounding_box.x == 10 && data.bounding_box.width == 100);
}
