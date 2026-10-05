module clay;

<*
 Element id from a caller-computed hash.
*>
macro ElementId id(uint hash) => { .id = hash, .base_id = hash };

<*
 Borrowed bytes as Clay text.
 @param text : "Must outlive the layout and its render commands."
*>
macro Chars chars(String text) => { .length = (int)text.len, .chars = text.ptr };

<*
 Bytes of a render command or measured slice.
*>
macro String CharsSlice.str(self) => (String)self.chars[:self.length];

<*
 Axis sized to fit its children.
*>
macro SizingAxis fit(float min = 0, float max = float::max) => { .min_max = { min, max }, .type = FIT };

<*
 Axis that grows into free space.
*>
macro SizingAxis grow(float min = 0, float max = float::max) => { .min_max = { min, max }, .type = GROW };

<*
 Axis of a fixed size.
*>
macro SizingAxis fixed(float size) => { .min_max = { size, size }, .type = FIXED };

<*
 Axis sized as a fraction of the parent.
 @require fraction >= 0 && fraction <= 1
*>
macro SizingAxis percent(float fraction) => { .percent = fraction, .type = PERCENT };

<*
 Declare one element and its children.
 @param [&in] declaration : "Copied by Clay."
*>
macro void @element(ElementId element_id, ElementDeclaration* declaration; @body()) {
    __open_element_with_id(element_id);
    __configure_open_element(declaration);
    @body();
    __close_element();
}

<*
 Open an element; configure it, then close it with close_element.
*>
fn void open_element(ElementId element_id) => __open_element_with_id(element_id);

<*
 Configure the element opened last.
 @param [&in] declaration : "Copied by Clay."
*>
fn void configure_element(ElementDeclaration* declaration) => __configure_open_element(declaration);

<*
 Close the innermost open element.
*>
fn void close_element() => __close_element();

<*
 Declare a text element.
 @param text : "Must outlive the layout and its render commands."
*>
fn void text(String text, TextElementConfig config) => __open_text_element(chars(text), config);

<*
 Render commands of the finished layout.
*>
macro RenderCommand[] RenderCommandArray.commands(self) => self.internal_array[:self.length];

<*
 Ids under the pointer, outermost first.
*>
macro ElementId[] ElementIdArray.ids(self) => self.internal_array[:self.length];
