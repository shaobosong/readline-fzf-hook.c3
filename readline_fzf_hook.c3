module readline_fzf_hook;

import std::collections;
import std::io;
import std::os;
import std::sort;

import libc;

alias ListStr = List {String};

const bool READLINE_LONGEST_COMMON_PREFIX_COMPLETION = true;
const bool FZF_ONLY_LIST_COMPLETION_FIELD = true;
const String[] FZF_ARGS = {
    "fzf",
    "--bind=tab:down,btab:up",
    "--bind=change:first",
    "--cycle",
    "--height=40%",
    "--layout=reverse",
    "--no-multi",
    "--print-query",
    "--print0",
    "--read0",
    "--tiebreak=index",
};

const void* GNUC_RTLD_NEXT = (void*)((usz) -1);
const int GNUC_RTLD_LAZY = 0x1;
const int GNUC_RTLD_GLOBAL = 0x100;

extern fn void* libc_dlopen(CChar*, CInt) @extern("dlopen");
extern fn CInt libc_dlclose(void*) @extern("dlclose");
extern fn void* libc_dlsym(void*, CChar*) @extern("dlsym");

alias Rl_command_func_t = fn int(int, int);
alias Rl_redraw_func_t = fn void();
alias Rl_completion_func_t = fn char**(char*, int, int);
alias Rl_compentry_func_t = fn char*(char*, int);

Rl_command_func_t original_rl_complete = null;
Rl_redraw_func_t original_rl_redraw_prompt_last_line = null;

Rl_completion_func_t* rl_attempted_completion_function_ptr = null;
Rl_completion_func_t rl_attempted_completion_function_val = null;
Rl_compentry_func_t* rl_completion_entry_function_ptr = null;
Rl_compentry_func_t rl_completion_entry_function_val = null;
char* rl_line_buffer_val = null;
int* rl_attempted_completion_over_ptr = null;
int rl_attempted_completion_over_val = 0;

macro usz cstring_strlen(ptr) @private
{
    usz len = 0;
    while (ptr[len]) len++;
    return len;
}

macro String[] cstrings_to_strings(int count, char** cstrs) @private
{
    String[] list = mem::alloc_array(String, count);
    for (int i = 0; i < count; i++)
    {
        char* cstr = cstrs[i];
        usz len = 0;
        list[i] = (String)cstr[:cstring_strlen(cstr)];
    }
    return list;
}

fn String? get_fzf_result(String[] extra_fzf_args, String[] choices, String query)
{
    ListStr fzf_args;

    fzf_args.tinit_with_array(FZF_ARGS);
    fzf_args.add_array(extra_fzf_args);
    fzf_args.push(string::tformat("--query=%s", query));

    SubProcess proc = process::create(fzf_args.to_tarray(), {
        .inherit_environment = true,
        .search_user_path = true,
    })!;
    defer proc.destroy();

    File proc_stdin = file::from_handle(proc.stdin_file);
    foreach (choice : choices) {
        proc_stdin.write(choice)!;
        proc_stdin.write_byte(0)!;
    }

    CInt exit_code = proc.join()!;
    if (exit_code > 1) {
        return "";
    }

    char[] buf = mem::talloc_array(char, 1024);
    usz len = proc.read_stdout(buf.ptr, buf.len)!;

    String sbuf = (String)buf[:len];
    String[] output = sbuf.trim("\0").tsplit("\0");

    return output[^1];
}

fn void c_free_match_list(char **cmatches)
{
    int i;

    if (!cmatches) {
        return;
    }

    for (i = 0; cmatches[i]; i++) {
        free(cmatches[i]);
    }

    free(cmatches);
}

fn char** c_new_single_match_list(String match)
{
    char* cmatch = libc::malloc(match.len + 1);
    if (!cmatch) {
        return null;
    }

    libc::memset(cmatch, 0, match.len + 1);
    libc::memcpy(cmatch, match.zstr_tcopy(), match.len + 1);

    char** cmatches = libc::malloc(2 * char*.sizeof);

    if (!cmatches) {
        libc::free(cmatch);
        return null;
    }
    libc::memset(cmatches, 0, 2 * char *.sizeof);
    libc::memcpy(cmatches, &cmatch, char *.sizeof);

    return cmatches;
}

fn int cmp_string(String a, String b)
{
    usz an = a.len;
    usz bn = b.len;
    if (an > bn) @swap(a, b);
    foreach (i, ac : a) {
        char bc = b[i];
        if (ac != bc) return an > bn ? bc - ac : ac - bc;
    }
    return (int)(an - bn);
}

fn char **fzf_attempted_completion_callback(char *ctext, int start, int end)
{
    int c;
    char **cmatches;
    String? selected;
    String line_text;
    usz nth;
    String text;
    String[] matches;
    String common_prefix;
    ListStr extra_fzf_args;
    ListStr choices;
    usz new_end;

    // We first invoke the original callback function
    cmatches = rl_attempted_completion_function_val(ctext, start, end);
    if (!cmatches) {
        return null;
    }

    for (c = 0; cmatches[c]; c++);

    // Nice! Just a single match and let the original completer handle it directly
    if (c == 1) {
        return cmatches;
    }

    matches = cstrings_to_strings(c, cmatches);
    defer free(matches.ptr);

    text = (String)ctext[:cstring_strlen(ctext)];

    // Return early to let the original completer finish completing the
    // rest of the common prefix that hasn't been fully completed yet
    if (READLINE_LONGEST_COMMON_PREFIX_COMPLETION) {
        common_prefix = matches[0];
        if (text != common_prefix) {
            return cmatches;
        }
    }

    // Now FZF takes over and handles the matches
    // Get the line text in line editor
    line_text = (String)rl_line_buffer_val[:cstring_strlen(rl_line_buffer_val)];

    // Get index of the field under completion in the space-separated string
    nth = line_text[0:start].count(" ") + 1;

    // Run FZF
    extra_fzf_args.tinit_with_array({
        "--delimiter= ",
        string::tformat("--accept-nth={%d}", nth)
    });
    if (FZF_ONLY_LIST_COMPLETION_FIELD) {
        extra_fzf_args.push(string::tformat("--with-nth={%d}", nth));
    }

    // Ignore first match, and concat a new choice
    new_end = line_text.index_of_char_from(' ', end) ?? line_text.len;
    foreach (String m : matches[1..]) {
        String choice = line_text[0:start].tcopy().tconcat(m).tconcat(line_text[new_end..].tcopy());
        if (!choices.contains(choice)) {
            choices.push(choice);
        }
    }

    quicksort(choices, &cmp_string);

    selected = get_fzf_result(extra_fzf_args.to_tarray(), choices.to_tarray(), text);
    if (catch excuse = selected) {
        io::printfn("Error: %s", excuse);
        return cmatches;
    }

    c_free_match_list(cmatches);

    original_rl_redraw_prompt_last_line();

    // Avoid to trigger original behaviour if we do nothing
    if (selected.len == 0) {
        // To suppress normal filename completion
        if (rl_attempted_completion_over_ptr) {
            *rl_attempted_completion_over_ptr = 1;
        }
        return null;
    }

    return c_new_single_match_list(selected);
}

fn char *fzf_completion_entry_callback(char *text, int state)
{
    return null;
}

macro @resolve_text_sym(#orig, #sym)
{
    if (!#orig) {
        #orig = libc_dlsym(GNUC_RTLD_NEXT, $stringify(#sym));
    }
}

macro @resolve_data_sym_ptr(#handle, #sym)
{
    return libc_dlsym(#handle, $stringify(#sym));
}

macro @resolve_data_sym_val(#handle, #sym, $Type, #failval)
{
    $Type* ptr = libc_dlsym(#handle, $stringify(#sym));
    return ptr ? *ptr : #failval;
}

fn void resolve_function_symbols()
{
    @resolve_text_sym(original_rl_complete, rl_complete);
    @resolve_text_sym(original_rl_redraw_prompt_last_line, rl_redraw_prompt_last_line);
}

fn void resolve_variable_symbols()
{
    void* handle = libc_dlopen(null, GNUC_RTLD_LAZY | GNUC_RTLD_GLOBAL);

    rl_attempted_completion_function_ptr = @resolve_data_sym_ptr(handle, rl_attempted_completion_function);
    if (rl_attempted_completion_function_ptr) {
        rl_attempted_completion_function_val = *rl_attempted_completion_function_ptr;
        *rl_attempted_completion_function_ptr = &fzf_attempted_completion_callback;
    }

    rl_attempted_completion_over_ptr = @resolve_data_sym_ptr(handle, rl_attempted_completion_over);
    if (rl_attempted_completion_over_ptr) {
        rl_attempted_completion_over_val = *rl_attempted_completion_over_ptr;
    }

    // rl_completion_entry_function_ptr = @resolve_data_sym_ptr(handle, rl_completion_entry_function);
    // if (rl_completion_entry_function_ptr) {
    //     rl_completion_entry_function_val = *rl_completion_entry_function_ptr;
    //     *rl_completion_entry_function_ptr = &fzf_completion_entry_callback;
    // }

    rl_line_buffer_val = @resolve_data_sym_val(handle, rl_line_buffer, char*, null);

    libc_dlclose(handle);
}

fn void restore_variable_symbols()
{
    *rl_attempted_completion_function_ptr = rl_attempted_completion_function_val;
    // *rl_attempted_completion_over_ptr = rl_attempted_completion_over_val;
    // *rl_completion_entry_function_ptr = rl_completion_entry_function_val;
}

fn int rl_complete(int ignore, int invoking_key) @export("rl_complete")
{
    resolve_function_symbols();
    resolve_variable_symbols();
    defer restore_variable_symbols();

    /* Complete the word at or before point.
       WHAT_TO_DO says what to do with the completion.
       `?' means list the possible completions.
       TAB means do standard completion.
       `*' means insert all of the possible completions.
       `!' means to do standard completion, and list all possible completions if
       there is more than one.
       `@' means to do standard completion, and list all possible completions if
       there is more than one and partial completion is not possible.
       `$' implements a protocol for exporting completions and information about
       what is being completed to another process via rl_outstream. */
    return original_rl_complete ? original_rl_complete(ignore, invoking_key) : 0;
}
