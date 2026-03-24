\ mem.asm — Memory editor: *MEM command
\
\ Full-screen hex/ASCII memory editor displayed in Mode 7. Shows 22 rows
\ of 8 bytes each, with address, hex dump, and ASCII columns. Cursor keys
\ navigate byte-by-byte; SHIFT+cursor scrolls by page. TAB toggles between
\ hex-entry and direct-ASCII editing modes. In hex mode, typing two hex
\ digits modifies one byte (high nibble shifted in first, then OR with low).

\ Entry point for *MEM [address]. Parses optional start address,
\ or resumes from last position if none given.
.cmd_mem
{
        JSR parse_cmdline
        CMP #&0d
        BEQ mem_setup_display
        JSR parse_hex_word
        LDA zp_src_lo : STA mem_edit_lo
        LDA zp_src_hi : STA mem_edit_hi
}
\ Set up the Mode 7 display: switch video mode, align the start address
\ to an 8-byte boundary, and initialise the column cursor position.
.mem_setup_display
{
        LDA mem_edit_lo : STA zp_ptr_lo
        LDA mem_edit_hi : STA zp_ptr_hi
        LDA zp_ptr_lo
        AND #&07
        STA mem_column
        EOR &a8
        STA zp_ptr_lo
        LDA #&16
        JSR oswrch
        LDA #&07
        JSR oswrch
        LDA #&0a : STA crtc_addr
        LDA #' ' : STA crtc_data
        LDX #&27
.loop
        LDA mem_header,X : STA mode7_screen,X
        DEX
        BPL loop
        LDA os_wrch_dest : STA mem_mode
        LDA #&01 : STA os_wrch_dest
        LDA os_screen_pages : STA mem_page_size
        LDA #&02 : STA os_screen_pages
        LDA #&50 : STA zp_tmp_lo
        LDA #&7c : STA zp_tmp_hi
        LDX #&16
}
\ Write Mode 7 colour control codes at the start, middle, and end of
\ each row to produce coloured address / hex / ASCII columns.
.mem_draw_row
{
        LDA #&83
        LDY #&00
        STA (zp_tmp_lo),Y
        LDA #&87
        LDY #&05
        STA (zp_tmp_lo),Y
        LDA #&86
        LDY #&1f
        STA (zp_tmp_lo),Y
        CLC
        LDA zp_tmp_lo
        ADC #&28
        STA zp_tmp_lo
        BCC skip
        INC zp_tmp_hi
.skip
        DEX
        BNE mem_draw_row
}
\ Main event loop: redraw the screen from a position one row above the
\ cursor, poll for a keypress, then dispatch to the appropriate handler.
\ Escape exits; cursor/page keys are dispatched via a lookup table;
\ other keys are treated as data entry (hex digit or raw ASCII byte).
.mem_adjust_ptr
{
        SEC
        LDA zp_ptr_lo
        SBC #&50
        STA zp_src_lo
        LDA zp_ptr_hi
        SBC #&00
        STA zp_src_hi
        JSR dis_setup
        LDA #&81
        LDX #&02
        LDY #&00
        JSR osbyte
        CPY #&1b
        BEQ mem_set_mode
        BCS mem_adjust_ptr
        TXA
        LDX #&04
.check_key
        CMP mem_key_codes,X
        BEQ mem_dispatch
        DEX
        BPL check_key
        PHA
        LDA mode7_screen + &27
        CMP #&48
        BEQ mem_handle_hex
        PLA
        LDY mem_column
        STA (zp_ptr_lo),Y
        JSR mem_cursor_down
        JMP mem_adjust_ptr
}
\ Hex editing mode: parse the keypress as a hex digit (0-F), then rotate
\ it into the current byte. Each keypress shifts the existing value left
\ by 4 bits (losing the old high nibble) and ORs in the new digit as the
\ low nibble — so two successive keystrokes fully replace one byte.
.mem_handle_hex
{
        PLA
        JSR parse_hex_digit
        BCS mem_adjust_ptr
        STA alias_file_handle
        LDY mem_column
        LDA (zp_ptr_lo),Y
        ASL A : ASL A : ASL A : ASL A  \ shift to high nibble
        ORA alias_file_handle
        STA (zp_ptr_lo),Y
        JMP mem_adjust_ptr
}
\ Jump to the handler for a recognised special key (cursor/page/tab)
\ via the mem_routine_table dispatch table.
.mem_dispatch
{
        TXA
        ASL A
        TAX
        LDA mem_routine_table,X : STA cmd_dispatch_addr + 1
        LDA mem_routine_table + 1,X : STA cmd_dispatch_addr + 2
        JSR cmd_dispatch
        JMP mem_adjust_ptr
}
\ Exit the memory editor: restore the original VDU state and cursor position.
.mem_set_mode
{
        LDA mem_mode : STA os_wrch_dest
        LDA mem_page_size : STA os_screen_pages
        LDA #&0a : STA crtc_addr
        LDA #&72 : STA crtc_data
        LDA #&1f
        JSR oswrch
        LDA #&00
        JSR oswrch
        LDA #&18
        JSR oswrch
        LDA #&00 : STA os_escape_effect
        RTS
}
\ Move cursor one byte backward. If already at column 0, wrap to column 7
\ of the previous row (subtract 8 from the base pointer).
.mem_cursor_up
{
        DEC mem_column
        BPL mem_cursor_rts
        LDA #&07 : STA mem_column
        SEC
        LDA &A8
        SBC #&08
        STA &A8
        LDA &A9
        SBC #&00
        STA &A9
}
.mem_cursor_rts
    RTS
\ Move cursor one byte forward. If past column 7, wrap to column 0
\ of the next row (add 8 to the base pointer).
.mem_cursor_down
{
        LDA mem_column
        INC A
        STA mem_column
        CMP #&08
        BNE mem_cursor_rts
        LDA #&00 : STA mem_column
        CLC
        LDA zp_ptr_lo
        ADC #&08
        STA zp_ptr_lo
        LDA zp_ptr_hi
        ADC #&00
        STA zp_ptr_hi
        RTS
}
\ Page up: if SHIFT is held, jump back by a full page (&B0 bytes = 22 rows);
\ otherwise move back one row (8 bytes).
.mem_page_up
{
        LDA #&81
        LDX #&ff
        LDY #&ff
        JSR osbyte
        CPX #&ff
        BNE row_up
        SEC
        LDA &A8
        SBC #&b0
        STA &A8
        LDA &A9
        SBC #&00
        STA &A9
        RTS
.row_up
        SEC
        LDA &A8
        SBC #&08
        STA &A8
        LDA &A9
        SBC #&00
        STA &A9
        RTS
}
\ Page down: if SHIFT is held, jump forward by a full page (&B0 bytes);
\ otherwise move forward one row (8 bytes).
.mem_page_down
{
        LDA #&81
        LDX #&ff
        LDY #&ff
        JSR osbyte
        CPX #&ff
        BNE row_down
        CLC
        LDA &A8
        ADC #&b0
        STA &A8
        LDA &A9
        ADC #&00
        STA &A9
        RTS
.row_down
        CLC
        LDA &A8
        ADC #&08
        STA &A8
        LDA &A9
        ADC #&00
        STA &A9
        RTS
}
\ Toggle between hex-entry ('H') and ASCII-entry ('A') mode by flipping
\ the mode indicator character in the header row of the screen display.
.mem_toggle_mode
{
        LDA mode7_screen + &27
        EOR #&09
        STA mode7_screen + &27
        RTS
}
\ Render the entire memory display into the Mode 7 screen RAM.
\ Writes 22 rows, each showing: 4-digit address, 8 hex bytes, 8 ASCII chars.
\ Also draws bracket markers around the currently selected column.
.dis_setup
{
        LDA #&16 : STA counter
        LDA #&51 : STA zp_tmp_lo
        LDA #&7c : STA zp_tmp_hi
.line_loop
        LDA zp_src_hi
        JSR dis_print_hex_byte
        LDA zp_src_lo
        JSR dis_print_hex_byte
        CLC
        LDA zp_tmp_lo
        ADC #&02
        STA zp_tmp_lo
        BCC hex_dump
        INC zp_tmp_hi
.hex_dump
        LDY #&00
.hex_byte_loop
        LDA (zp_src_lo),Y
        JSR dis_print_hex_byte
        INC zp_tmp_lo
        BNE hex_next
        INC zp_tmp_hi
.hex_next
        INY
        CPY #&08
        BNE hex_byte_loop
        CLC
        LDA zp_tmp_lo
        ADC #&01
        STA zp_tmp_lo
        BCC ascii_dump
        INC zp_tmp_hi
\ Write the ASCII representation of the 8 bytes (non-printable shown as '.').
.ascii_dump
        LDY #&00
.ascii_loop
        LDA (zp_src_lo),Y
        AND #&7f
        CMP #' '
        BCS store_byte
        LDA #'.'
.store_byte
        STA (zp_tmp_lo),Y
        INY
        CPY #&08
        BNE ascii_loop
        CLC
        LDA zp_tmp_lo
        ADC #&09
        STA zp_tmp_lo
        BCC advance_ptr
        INC zp_tmp_hi
.advance_ptr
        CLC
        LDA zp_src_lo
        ADC #&08
        STA zp_src_lo
        BCC next_line
        INC zp_src_hi
.next_line
        DEC counter
        BNE line_loop
        LDY #&00
        TYA
.bracket_loop
        STA mode7_screen + &1E6,Y
        INY : INY : INY
        CPY #&1b
        BNE bracket_loop
        LDA mem_column
        ASL A
        ADC mem_column
        TAY
        LDA #']' : STA mode7_screen + &1E6,Y
        LDA #'[' : STA mode7_screen + &1E9,Y
        RTS
.counter
        EQUB &00
}
\ Write a byte as two hex digits directly into screen memory (via indirect
\ store). Uses self-modifying code to save the value for the low nibble.
.dis_print_hex_byte
{
        STA dis_print_lo_nibble + 1
        LSR A : LSR A : LSR A : LSR A  \ high nibble
        TAX : LDA hex_digits,X
        STA (zp_tmp_lo)
        INC zp_tmp_lo
        BNE dis_print_lo_nibble
        INC zp_tmp_hi
.*dis_print_lo_nibble
        LDA #&88
        AND #&0f
        TAX
        LDA hex_digits,X : STA (zp_tmp_lo)
        INC zp_tmp_lo
        BNE rts
        INC zp_tmp_hi
.rts
        RTS
}
\ Print a byte as two hex digits via OSWRCH (used by the disassembler).
\ Uses self-modifying code to stash the value for the low nibble pass.
.dis_print_hex_word
{
        STA dis_hex_word_lda + 1
        LSR A : LSR A : LSR A : LSR A  \ high nibble
        TAX : LDA hex_digits,X
        JSR oswrch
.*dis_hex_word_lda
        LDA #'b'
        AND #&0f
        TAX
        LDA hex_digits,X
        JMP oswrch
}
\ --- Disassembler addressing mode format strings ---
\ &l = low byte, &hl = high+low bytes, &b = branch offset
