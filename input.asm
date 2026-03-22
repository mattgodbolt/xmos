\ input.asm — Extended input system: handle_reset, XON handler, keyboard intercept

\ Initialise the extended input system on ROM reset.
\ Patches workspace addresses into the handler code, re-enables KEYON/XON
\ if they were active, and copies the input handler into private workspace RAM.
.handle_reset
    PHA : PHX : PHY
    LDA rom_workspace_table,X   \ Get our ROM's workspace page
    STA extended_input_code + &0F  \ Patch workspace high byte into handler
    STX extended_input_code + &25  \ Patch ROM slot number into handler
    STA zp_work_hi              \ Set up workspace pointer high
    STA os_himem_hi             \ Set OSHWM high byte
    LDA #&00
    STA zp_work_lo              \ Workspace pointer low = 0
    STA os_himem_lo             \ OSHWM low byte = 0
    JSR alias_init              \ Initialise alias system
    LDA keyon_active
    BEQ reset_skip_keyon
    LDA #&00
    STA keyon_active
    JSR keyon_setup             \ Re-enable KEYON if it was active
.reset_skip_keyon
    LDA xon_flag
    BEQ reset_skip_xon
    LDA #&04                    \ OSBYTE 4: cursor key status
    LDX #&01                    \ Enable cursor editing
    LDY #&00
    JSR osbyte
    LDA #&16                    \ OSBYTE &16: reset function keys?
    LDX #&01
    JSR osbyte
.reset_skip_xon
{
        LDY #&00                \ Copy extended input handler code to workspace
.copy_loop
        LDA extended_input_code,Y
        STA (zp_work_lo),Y
        INY
        CPY #&D0                \ Copy &D0 (208) bytes
        BNE copy_loop
}
    PLY : PLX : PLA
    RTS
\ ============================================================================
\ Extended input handler code — copied to workspace RAM on reset
\ This block runs from the ROM's private workspace page, intercepting
\ keyboard input to provide cursor editing, insert/delete, etc.
\ ============================================================================
\ KEYV intercept entry point. If A=0 (keyboard read), handle it ourselves;
\ otherwise fall through to the default keyboard vector handler.
.extended_input_code
    PHP
    CMP #&00
    BEQ xi_entry
    PLP
    JMP default_keyv
\ Save caller's register block, page in XMOS ROM, and call the main handler.
.xi_entry
    PLA
    STX zp_src_lo
    STY zp_src_hi
    LDA #&db
    STA zp_work_hi
    LDA #&e0
    STA zp_work_lo
    LDY #&0f
.xi_save_regs_loop
    LDA (zp_src_lo),Y
    STA (zp_work_lo),Y
    DEY
    BPL xi_save_regs_loop
    LDA rom_number
    STA os_mode
    LDA #&07
    STA sheila_romsel
    STA rom_number
    JSR xi_check_xon
    PHP
    LDA os_mode
    STA sheila_romsel
    STA rom_number
    LDA #&00
    PLP
    RTS
\ If XON mode is not active, pass through to the default KEYV handler.
\ Otherwise, enter the extended line editor.
.xi_check_xon
    LDA xon_flag
    BNE xi_init_state
    LDX zp_src_lo
    LDY zp_src_hi
    JMP default_keyv
\ Reset editor state and begin reading a new input line.
\ Fetches the caller's buffer address from the register block.
.xi_init_state
    LDA #&00
    STA xi_scroll_count
    LDA #&00
    STA xi_cursor_pos
    STA xi_line_len
    TAY
    LDA (zp_work_lo),Y
    STA zp_ptr_lo
    INY
    LDA (zp_work_lo),Y
    STA zp_ptr_hi
\ Main input loop: read a character and dispatch it.
\ Escape is echoed and re-read; all other keys are dispatched by type.
.xi_read_loop
    JSR osrdch
    STA xi_char
    LDA os_escape_flag
    BPL xi_dispatch
    LDA xi_char
    JSR oswrch
    JMP xi_read_loop
\ Dispatch table for special keys: cursor left/right, delete, CR, escape,
\ Ctrl-U (clear), copy up/down, Tab, Ctrl-N/O, horizontal tab, and null.
.xi_dispatch
{
        LDA xi_char
        CMP #&88
        BNE check_right
        JMP xi_handle_left
.check_right
        CMP #&89
        BNE check_delete
        JMP xi_handle_right
.check_delete
        CMP #&7f
        BNE check_cr
        JMP xi_handle_delete
.check_cr
        CMP #&0d
        BNE check_escape
        JMP xi_handle_cr
.check_escape
        CMP #&1b
        BNE check_clear
        JMP xi_cr_restore_keys
.check_clear
        CMP #&15
        BNE check_copy
        JMP xi_handle_clear
.check_copy
        CMP #&8b
        BNE check_down
        JMP xi_handle_copy_up
.check_down
        CMP #&8a
        BNE check_tab
        JMP xi_handle_copy_down
.check_tab
        CMP #&87
        BNE check_ctrl_n
        JMP xi_handle_tab
.check_ctrl_n
        CMP #&0e
        BNE check_ctrl_o
        JSR oswrch
.check_ctrl_o
        CMP #&0f
        BNE check_htab
        JSR oswrch
.check_htab
        CMP #&09
        BNE check_null
        JMP xi_handle_htab
.check_null
        CMP #&00
        BNE xi_handle_printable
        JMP xi_handle_null
}
\ Handle a printable character: validate it's within the allowed range
\ and the buffer isn't full, then insert it at the cursor position.
.xi_handle_printable
    LDA xi_char
    CMP #&20
    BCS xi_check_lo_range
    JSR oswrch
    JMP xi_read_loop
.xi_check_lo_range
    LDY #&03
    CMP (zp_work_lo),Y
    BCS xi_check_hi_range
    JMP xi_read_loop
.xi_check_hi_range
    INY
    CMP (zp_work_lo),Y
    BEQ xi_check_buffer_full
    BCC xi_check_buffer_full
    JMP xi_read_loop
.xi_check_buffer_full
    LDA xi_cursor_pos
    LDY #&02
    CMP (zp_work_lo),Y
    BNE xi_do_insert_setup
    JMP xi_read_loop
.xi_do_insert_setup
    LDA #&00
    STA xi_insert_mode
    JSR xi_do_insert
    JMP xi_read_loop
.xi_insert_mode
    EQUB &00
\ Insert xi_char into the line buffer at the current cursor position.
\ Shifts characters after the cursor rightward, then redraws the tail.
.xi_do_insert
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ xi_write_char
    TAX
    LDY xi_cursor_pos
    DEY
.xi_shift_right_loop
    LDA (zp_ptr_lo),Y
    INY
    STA (zp_ptr_lo),Y
    DEY
    DEY
    DEX
    BNE xi_shift_right_loop
.xi_write_char
    LDY xi_line_len
    LDA xi_char
    JSR oswrch
    STA (zp_ptr_lo),Y
    INC xi_line_len
    INC xi_cursor_pos
    PLA
    BEQ xi_insert_done
    PHA
    TAX
.xi_redraw_after
    INY
    LDA (zp_ptr_lo),Y
    JSR oswrch
    DEX
    BNE xi_redraw_after
    PLA
    TAX
.xi_backspace_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_backspace_loop
.xi_insert_done
    RTS
\ Cursor left: move insertion point one character left within the line.
\ If already at position 0, switch to scroll mode via cursor key reset.
.xi_handle_left
{
        LDA xi_cursor_pos
        BNE no_scroll
        LDY #&8c
        JMP xi_reset_cursor_keys
.no_scroll
        LDA xi_line_len
        BEQ done
        DEC xi_line_len
        LDA #&08
        JSR oswrch
.done
        JMP xi_read_loop
}
\ Cursor right: move insertion point one character right within the line.
\ If already at position 0, switch to scroll mode via cursor key reset.
.xi_handle_right
{
        LDA xi_cursor_pos
        BNE no_scroll
        LDY #&8d
        JMP xi_reset_cursor_keys
.no_scroll
        LDA xi_line_len
        CMP xi_cursor_pos
        BEQ done
        INC xi_line_len
        LDA #&09
        JSR oswrch
.done
        JMP xi_read_loop
}
\ Delete: remove the character before the cursor, shift remaining chars
\ left, and redraw the line tail with trailing space to erase the last char.
.xi_handle_delete
{
        LDA xi_line_len
        BEQ done
        SEC
        LDA xi_cursor_pos
        SBC xi_line_len
        PHA
        BEQ do_delete
        TAX
        LDY xi_line_len
.shift_loop
        LDA (zp_ptr_lo),Y
        DEY
        STA (zp_ptr_lo),Y
        INY
        INY
        DEX
        BNE shift_loop
.do_delete
        LDA #&7f
        JSR oswrch
        DEC xi_line_len
        DEC xi_cursor_pos
        LDY xi_line_len
        PLA
        BEQ done
        PHA
        TAX
.redraw_loop
        LDA (zp_ptr_lo),Y
        JSR oswrch
        INY
        DEX
        BNE redraw_loop
        LDA #' '
        JSR oswrch
        PLA
        TAX
        INX
.bs_loop
        LDA #&08
        JSR oswrch
        DEX
        BNE bs_loop
.done
        JMP xi_read_loop
}
\ Carriage return: finalise the input line and return it to the caller.
\ In BASIC edit mode, intercepts "SAVE" to auto-save before returning.
\ Moves the cursor to end-of-line, stores CR terminator, and exits.
.xi_handle_cr
    LDA xon_flag
    BEQ xi_cr_check_mode
    LDA #&04
    LDX #&01
    LDY #&00
    JSR osbyte
.xi_cr_check_mode
    LDA os_mode
    CMP #&0c
    BNE xi_cr_normal
    LDA xi_cursor_pos
    CMP #&04
    BNE xi_cr_normal
    LDY #&03
.xi_cr_check_save
    LDA (zp_ptr_lo),Y
    CMP save_keyword,Y
    BNE xi_cr_normal
    DEY
    BPL xi_cr_check_save
    JSR osnewl
    LDA os_mode
    PHA
    JSR cmd_s
    LDA #&0d
    STA (zp_ptr_lo)
    LDY #&00
    PLA
    STA os_mode
    CLC
    RTS
.xi_cr_normal
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_cr_finish
    TAX
.xi_cr_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_cr_fwd_loop
.xi_cr_finish
    JSR xi_support_entry
    LDY xi_cursor_pos
    LDA #&0d
    STA (zp_ptr_lo),Y
    JSR osnewl
    CLC
    LDX #&00
    RTS
.save_keyword
    EQUS "SAVE"
\ Escape key handler: restore cursor keys to editing mode, move cursor
\ to end of line, and return with carry set to indicate escape.
.xi_cr_restore_keys
    LDA #&04                    \ OSBYTE 4: cursor key status
    LDX #&01                    \ Enable cursor editing
    LDY #&00
    JSR osbyte
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_cr_sec_return
    TAX
.xi_cr_fwd_loop2
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_cr_fwd_loop2
.xi_cr_sec_return
    LDY xi_cursor_pos
    SEC
    RTS
\ Ctrl-U: clear the entire input line by deleting all characters.
.xi_handle_clear
    JSR xi_do_clear
    JMP xi_read_loop
\ Erase all characters on the current line by moving cursor to end,
\ then issuing delete for each character. Resets line_len and cursor_pos.
.xi_do_clear
{
        LDA xi_cursor_pos
        BEQ done
        SEC
        LDA xi_cursor_pos
        SBC xi_line_len
        BEQ del_loop
        TAX
.fwd_loop
        LDA #&09
        JSR oswrch
        DEX
        BNE fwd_loop
.del_loop
        LDX xi_cursor_pos
.del_char
        LDA #&7f
        JSR oswrch
        DEX
        BNE del_char
        LDA #&00
        STA xi_line_len
        STA xi_cursor_pos
.done
        RTS
}
\ Null character (Ctrl-@): if the line is empty, turn off XON mode
\ and return an empty line terminated with CR.
.xi_handle_null
    LDA xi_cursor_pos
    BEQ xi_null_not_empty
    JMP xi_read_loop
.xi_null_not_empty
    JSR cmd_xoff
    JSR osnewl
    LDY #&00
    LDA #&0d
    STA (zp_ptr_lo),Y
    CLC
    RTS
\ Copy-up (cursor up in copy mode): if no key is pending in the buffer,
\ enter insert/scroll mode and scroll the screen up. If a key is pending,
\ move the cursor up one screen line (by subtracting the window width).
.xi_handle_copy_up
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE xi_copy_up_has_key
    LDA xi_scroll_count
    BNE xi_copy_up_inc
    LDA xi_insert_mode
    BNE xi_copy_up_inc
    LDA #&ff
    STA xi_insert_mode
    LDA xi_cursor_pos
    BEQ xi_copy_up_jmp
    JSR xi_support_entry
.xi_copy_up_inc
    INC xi_scroll_count
.xi_copy_up_jmp
    JMP xi_supp_restore
.xi_copy_up_has_key
    LDA xi_cursor_pos
    BNE xi_copy_up_calc
    LDY #&8f
    JMP xi_reset_cursor_keys
.xi_copy_up_calc
    SEC
    LDA os_width_hi
    SBC os_width_lo
    CLC
    ADC #&01
    STA xi_char
    SEC
    LDA xi_line_len
    SBC xi_char
    BCC xi_copy_up_clear
    STA xi_line_len
    LDA #&0b
    JSR oswrch
.xi_copy_up_done
    JMP xi_read_loop
.xi_copy_up_clear
    LDX xi_line_len
    BEQ xi_copy_up_done
.xi_copy_up_bs_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_copy_up_bs_loop
    LDA #&00
    STA xi_line_len
    JMP xi_read_loop
\ Copy-down (cursor down in copy mode): if no key is pending, enter
\ insert/scroll mode and scroll down. If a key is pending, move the
\ cursor down one screen line (by adding the window width).
.xi_handle_copy_down
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE xi_copy_down_has_key
    LDA xi_scroll_count
    BNE xi_copy_down_dec
    LDA xi_insert_mode
    BNE xi_copy_down_dec
    LDA #&ff
    STA xi_insert_mode
    JSR xi_support_entry
.xi_copy_down_dec
    DEC xi_scroll_count
    JMP xi_supp_restore
.xi_copy_down_has_key
    LDA xi_cursor_pos
    BNE xi_copy_down_calc
    LDY #&8e
    JMP xi_reset_cursor_keys
.xi_copy_down_calc
    SEC
    LDA os_width_hi
    SBC os_width_lo
    CLC
    ADC #&01
    CLC
    ADC xi_line_len
    BCS xi_copy_down_truncate
    CMP xi_cursor_pos
    BCS xi_copy_down_truncate
    STA xi_line_len
    LDA #&0a
    JSR oswrch
    JMP xi_read_loop
.xi_copy_down_truncate
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_copy_down_set_pos
    TAX
.xi_copy_down_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_copy_down_fwd_loop
.xi_copy_down_set_pos
    LDA xi_cursor_pos
    STA xi_line_len
    JMP xi_read_loop
\ Temporarily disable cursor editing mode and re-inject a cursor key,
\ allowing normal screen-level cursor movement for one keypress.
.xi_reset_cursor_keys
    PHY
    LDA #&04
    LDX #&00
    LDY #&00
    JSR osbyte
    PLY
    LDA #&8a
    LDX #&00
    JSR osbyte
    JMP xi_read_loop
\ Tab (copy key): delete the character at the current cursor position
\ by shifting remaining characters left and redrawing. Used for
\ character-at-a-time deletion during copy editing.
.xi_handle_tab
    LDA xi_cursor_pos
    CMP xi_line_len
    BEQ xi_tab_done
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ xi_tab_update_pos
    TAX
    LDY xi_line_len
    INY
.xi_tab_shift_loop
    LDA (zp_ptr_lo),Y
    DEY
    STA (zp_ptr_lo),Y
    INY
    INY
    DEX
    BNE xi_tab_shift_loop
.xi_tab_update_pos
    DEC xi_cursor_pos
    LDY xi_line_len
    PLA
    BEQ xi_tab_done
    TAX
    DEX
    BEQ xi_tab_single
    PHA
.xi_tab_redraw_loop
    LDA (zp_ptr_lo),Y
    JSR oswrch
    INY
    DEX
    BNE xi_tab_redraw_loop
    LDA #' '
    JSR oswrch
    PLA
    TAX
.xi_tab_bs_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_tab_bs_loop
.xi_tab_done
    JMP xi_read_loop
.xi_tab_single
    LDA #&09
    JSR oswrch
    LDA #&7f
    JSR oswrch
.xi_tab_finished
    JMP xi_read_loop
\ Horizontal tab (Ctrl-I): in BASIC edit mode, parse a line number from
\ the current input, look up the corresponding BASIC program line, and
\ expand its tokenised content into the input buffer for editing.
.xi_handle_htab
    LDA xi_cursor_pos
    BEQ xi_tab_finished
    LDA os_mode
    CMP #&0c
    BNE xi_tab_finished
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_htab_set_pos
    TAX
.xi_htab_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_htab_fwd_loop
.xi_htab_set_pos
    LDA xi_cursor_pos
    STA xi_line_len
    LDY #&00
    STY xi_char
    STY xi_temp
.xi_htab_parse_loop
    LDA (zp_ptr_lo),Y
    CMP #&30
    BCC xi_htab_skip_nondigit
    CMP #&3a
    BCS xi_htab_skip_nondigit
    JMP xi_htab_mul10
.xi_htab_skip_nondigit
    INY
    CPY xi_cursor_pos
    BEQ xi_tab_finished
    BNE xi_htab_parse_loop
\ Multiply the accumulated number by 10 and add the current digit.
.xi_htab_mul10
    ASL xi_char
    ROL xi_temp
    LDA xi_char
    ASL A
    STA zp_tmp_lo
    LDA xi_temp
    ROL A
    STA zp_tmp_hi
    ASL zp_tmp_lo
    ROL zp_tmp_hi
    CLC
    LDA xi_char
    ADC zp_tmp_lo
    STA xi_char
    LDA zp_tmp_hi
    ADC xi_temp
    STA xi_temp
    LDA (zp_ptr_lo),Y
    SEC
    SBC #&30
    CLC
    ADC xi_char
    STA xi_char
    LDA xi_temp
    ADC #&00
    STA xi_temp
    INY
    LDA (zp_ptr_lo),Y
    CMP #&30
    BCC xi_htab_lookup
    CMP #&3a
    BCS xi_htab_lookup
    CPY xi_cursor_pos
    BNE xi_htab_mul10
\ Walk the BASIC program's linked list to find the line matching
\ the parsed number, then expand its tokens into the input buffer.
.xi_htab_lookup
    LDY xi_cursor_pos
    LDA #&00
    STA zp_tmp_lo
    LDA basic_page_hi
    STA zp_tmp_hi
.xi_htab_search_loop
    LDY #&01
    LDA (zp_tmp_lo),Y
    CMP #&ff
    BEQ xi_htab_not_found
    CMP xi_temp
    BNE xi_htab_advance_ptr
    INY
    LDA (zp_tmp_lo),Y
    CMP xi_char
    BNE xi_htab_advance_ptr
    INY
    LDA (zp_tmp_lo),Y
    SEC
    SBC #&04
    TAX
    LDA #&00
    STA xi_quote_toggle
    LDA basic_flags
    AND #&01
    BEQ xi_htab_found_space
    PHY
    LDA #' '
    STA xi_char
    JSR xi_do_insert
    PLY
.xi_htab_found_space
    INY
    LDA (zp_tmp_lo),Y
    PHY
    STA xi_char
    CMP #&80
    BCS xi_htab_check_quote
    CMP #&22
    BNE xi_htab_output_char
    LDA xi_quote_toggle
    EOR #&ff
    STA xi_quote_toggle
.xi_htab_output_char
    JSR xi_do_insert
.xi_htab_next_char
    PLY
    DEX
    BNE xi_htab_found_space
    JMP xi_read_loop
.xi_htab_advance_ptr
    LDY #&03
    LDA (zp_tmp_lo),Y
    CLC
    ADC zp_tmp_lo
    STA zp_tmp_lo
    LDA zp_tmp_hi
    ADC #&00
    STA zp_tmp_hi
    JMP xi_htab_search_loop
.xi_htab_not_found
    LDA #&07
    JSR oswrch
    JMP xi_read_loop
.xi_quote_toggle
    EQUB &00
\ When expanding a BASIC token outside of a quoted string, look up the
\ full keyword text and insert each character into the input buffer.
.xi_htab_check_quote
    EQUB &AD, &AE, &89          \ LDA xi_quote_toggle (absolute ZP workaround)
    BNE xi_htab_output_char
    LDA #&55
    STA zp_src_lo
    LDA #&AE
    STA zp_src_hi
.xi_htab_keyword_loop
    LDY #&00
    LDA (zp_src_lo),Y
.xi_htab_kw_scan
    INY
    LDA (zp_src_lo),Y
    BPL xi_htab_kw_scan
    CMP xi_char
    BNE xi_htab_kw_advance
    LDY #&ff
.xi_htab_kw_match
    INY
    LDA (zp_src_lo),Y
    BMI xi_htab_kw_done
    STA xi_char
    PHY
    JSR xi_do_insert
    PLY
    JMP xi_htab_kw_match
.xi_htab_kw_done
    JMP xi_htab_next_char
.xi_htab_kw_advance
    INY
    INY
    TYA
    CLC
    ADC zp_src_lo
    STA zp_src_lo
    LDA zp_src_hi
    ADC #&00
    STA zp_src_hi
    JMP xi_htab_keyword_loop
\ ============================================================================
\ print_inline — Print null-terminated string that follows the JSR
\ The return address on the stack points to the string data.
\ After printing, returns to the instruction after the null terminator.
\ ============================================================================
