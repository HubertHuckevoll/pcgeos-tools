# Html4Par form buttons

`<button>...</button>` is collected as text by the parser's `TAG_FLUSH_TEXT`
path and converted to an existing submit, reset, or plain button form record
when `PopStyle()` closes `SPEC_BUTTON`. `HFD_prompt` holds its caption while
`HFD_value` remains the submitted value; `HTML_BUTTON_CONTENT` marks this
layout in `HFD_var.submit.flags`. The style also ignores nested tags, so this
implementation supports text and character entities rather than nested HTML.
See `htmlsty.goh`, `htmlpars/parstags.goc`, and `htmlclas/htmlfdrw.goc`.

`<input type="button">` is separate: `Open_FORM_INPUT_SELECT()` in
`htmlpars/opentags.goc` creates `HTML_FORM_BUTTON`. It is drawn by
`FormElementDraw()` in `htmlclas/htmlfdrw.goc`. Activating it has no built-in
form action (`MSG_HTML_TEXT_FORM_ELEMENT_START` in `htmlclas/htmlfedi.goc`).
In JavaScript builds, `ParseEvents()` collects `ONCLICK`, and the form element
click path in `htmlclas/htmlclrt.goc` fires that event.

`KeepFormControl()` in `htmlpars/parstags.goc` retains controls when the
`HTML_JAVASCRIPT` option is set or the tag stack contains `SPEC_FORM`.
`Open_FORM_INPUT_SELECT()` applies it before creating INPUT/SELECT records;
`PopStyle()` applies it when closing TEXTAREA/BUTTON. Rejected collected text
and unconnected OPTION text release their NamePool tokens. Closing SELECT
clears `currentMenu`, preventing later OPTIONs from joining a closed menu.
Form membership for TEXTAREA/BUTTON is checked at closing time, so malformed
markup that closes FORM first can suppress them.
