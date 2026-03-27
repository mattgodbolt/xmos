\ lvar.asm — Variable lister: *LVAR, token classify, print_decimal

\ *LVAR — lists all BASIC variables currently defined.
\ BASIC stores variables in 64 hash-chain buckets (A-Z pairs), each a
\ linked list. This walks all 64 buckets, printing each variable's name
\ prefixed with a letter derived from the bucket index (X/2 + &40 = 'A'..).
\ Each variable entry has a forward-link pointer at offset 0-1 and a
\ null-terminated name starting at offset 2.
.cmd_lvar
{
        LDA saved_language_rom
        CMP #&0c
        BEQ start
        JSR copy_inline_to_stack  \ BRK error: "VAR works only in BASIC"
        EQUS &4C, "VAR works only in BASIC", 0
.start
        LDX #&00
.var_loop
        LDA os_fkey_buf,X : STA zp_ptr_lo
        INX
        LDA os_fkey_buf,X
        DEX
        STA zp_ptr_hi
        CMP #&00                \ null hi-byte means empty bucket
        BEQ next_var
.check_type
        TXA
        LSR A                   \ bucket index / 2
        CLC : ADC #'@'          \ convert to ASCII letter ('A' onwards)
        JSR oswrch
        LDY #&01
.skip_name
        INY
        LDA (zp_ptr_lo),Y
        BEQ print_newline       \ null terminator ends the variable name
        JSR oswrch
        BRA skip_name
.print_newline
        JSR osnewl
        LDY #&01                \ follow linked-list pointer to next variable
        LDA (zp_ptr_lo),Y
        BEQ next_var            \ null = end of chain
        STA zp_tmp_lo
        DEY
        LDA (zp_ptr_lo),Y : STA zp_ptr_lo
        LDA zp_tmp_lo : STA zp_ptr_hi
        BRA check_type
.next_var
        INX                     \ advance to next bucket (2 bytes per entry)
        INX
        CPX #&80                \ 64 buckets * 2 = &80
        BNE var_loop
        RTS
}
\ --- MEM/DIS editor workspace (all set at runtime) ---
.mem_workspace  SKIP 2
.mem_edit_lo    SKIP 1          \ MEM current address low byte
.mem_edit_hi    SKIP 1          \ MEM current address high byte
.mem_vdu_1      SKIP 1          \ DIS resume address low byte
.mem_vdu_2      SKIP 1          \ DIS resume address high byte
.mem_mode       SKIP 1          \ Saved WRCH destination during MEM
.mem_page_size  SKIP 1          \ Saved screen pages during MEM
.mem_column     SKIP 1          \ MEM column counter (0-7)
.mem_key_codes
    EQUB &88, &89, &8A, &8B     \ Key codes: left, right, down, up
    EQUB &09                    \ TAB key
.mem_routine_table
    EQUW mem_cursor_up          \ Address of cursor-up routine
    EQUW mem_cursor_down        \ Address of cursor-down routine
    EQUW mem_page_down          \ Address of page-down routine
    EQUW mem_page_up            \ Address of page-up routine
    EQUW mem_toggle_mode        \ Address of hex/ascii toggle
\ --- MEM editor header display (uses VDU control codes) ---
.mem_header
    EQUB &82 : EQUS "ADDR " : EQUB &94
    EQUS ",,,,,,"
    EQUB &82 : EQUS "HEX CODE" : EQUB &94
    EQUS ",,,,,,, "
    EQUB &82 : EQUS "ASCII " : EQUB &85
\ --- Hex digit lookup table ---
    EQUS "A"                    \ Padding byte before hex digit table
.hex_digits
    EQUS "0123456789ABCDEF"
\ Assembler block formatter: called from *SPACE when "[" is encountered.
\ Parses assembler directives inside [...] blocks, inserting spaces where
\ needed. Handles "." labels (skip to next space/colon), quoted strings,
\ backslash comments, and tokenised opcodes via token_classify.
.lvar_display_value
{
        INY
.parse_token
        LDA #&00 : STA lvar_indent
        LDA (zp_ptr_lo),Y
        CMP #&0d
        BNE check_dot
        JMP end_of_line
.check_dot
        CMP #'.'                \ "." — assembler label definition
        BNE check_string
.scan_name
        INY                     \ skip label name until space or colon
        LDA (zp_ptr_lo),Y
        CMP #&0d
        BNE check_space
        JMP end_of_line
.check_space
        CMP #' '
        BEQ next_token
        CMP #':'
        BNE scan_name
.next_token
        INY
        BRA parse_token
.check_string
        CMP #'"'                \ skip over quoted string literals
        BNE lookup_token
.string_loop
        INY
        LDA (zp_ptr_lo),Y
        CMP #&0d
        BEQ end_of_line
        CMP #'"'
        BNE string_loop
        INY
        BRA parse_token
\ Classify the current byte via token_classify. If recognised, skip past
\ a number of characters determined by the indent value (operand width).
.lookup_token
        JSR token_classify
        BCS skip_operand        \ carry set = known token, skip its operand
        CMP #':'                \ ":" statement separator
        BNE check_close
        INY
        BRA parse_token
.check_close
        CMP #']'                \ "]" — end of assembler block
        BNE check_backslash
        JMP done
.check_backslash
        CMP #'\'                \ "\" — assembler comment, skip to end of stmt
        BNE set_indent
.skip_comment
        INY
        LDA (zp_ptr_lo),Y
        CMP #':'
        BEQ skip_and_continue
        CMP #&0d
        BNE skip_comment
        JMP end_of_line
.skip_and_continue
        INY
        BRA parse_token
.set_indent
        LDA #&03 : STA lvar_indent  \ default: skip 3 chars (opcode + operand)
\ Skip past the operand bytes (counted by lvar_indent), then insert a
\ space before the next item if one isn't already there.
.skip_operand
        INY
        LDA (zp_ptr_lo),Y
        CMP #']'
        BEQ done
        CMP #&0d
        BEQ end_of_line
        DEC lvar_indent
        BNE skip_operand        \ keep skipping until indent reaches 0
        CMP #':'
        BEQ parse_token
        CMP #' '
        BEQ scan_char           \ already has a space, just continue
        DEY
        JSR space_shift_up      \ insert a space byte before this position
        PHY
        LDY #&03
        LDA (zp_ptr_lo),Y
        INC A
        STA (zp_ptr_lo),Y
        PLY
        CLC
        LDA basic_lomem_lo : ADC #&01 : STA basic_lomem_lo
        LDA basic_lomem_hi : ADC #&00 : STA basic_lomem_hi
        LDA #' '
        INY
        STA (zp_ptr_lo),Y
.scan_char
        INY
        LDA (zp_ptr_lo),Y
        CMP #&0d
        BEQ end_of_line
        CMP #':'
        BNE scan_char
        INY
        JMP parse_token
\ Advance to the next BASIC line and continue formatting
.end_of_line
        LDY #&03
        CLC
        LDA (zp_ptr_lo),Y
        ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi
        ADC #&00
        STA zp_ptr_hi
        JSR print_backspace
        LDY #&01
        LDA (zp_ptr_lo),Y
        CMP #&ff                \ end-of-program marker
        BNE continuation
        JMP space_save_top
.continuation
        LDY #&04
        JMP parse_token
.done
        JMP space_scan_loop     \ return to *SPACE main scan loop
}
\ XI alias history support: copies the current command line into the alias
\ buffer and shifts the existing alias history down to make room.
.xi_history_save
{
        LDA #LO(xi_hist_flag) : STA zp_tmp_lo
        LDA #HI(xi_hist_flag) : STA zp_tmp_hi
        INC xi_alias_count
        LDA xi_alias_count
        BNE inc_cursor
        LDA #&ff : STA xi_alias_count
.inc_cursor
        INC xi_line_len
        SEC
        LDA zp_tmp_lo
        SBC xi_line_len
        STA zp_src_lo
        LDA zp_tmp_hi
        SBC #&00
        STA zp_src_hi
        DEC xi_line_len
        LDA #&0d : STA xi_hist_term
        LDA #&ff : STA xi_hist_flag
.copy_loop
        LDA (zp_src_lo) : STA (zp_tmp_lo)
        SEC
        LDA zp_tmp_lo
        SBC #&01
        STA zp_tmp_lo
        LDA zp_tmp_hi
        SBC #&00
        STA zp_tmp_hi
        SEC
        LDA zp_src_lo
        SBC #&01
        STA zp_src_lo
        LDA zp_src_hi
        SBC #&00
        STA zp_src_hi
        LDA zp_src_lo
        CMP #&54
        BNE copy_loop
        LDA zp_src_hi
        CMP #zp_work_lo
        BNE copy_loop
        LDY xi_line_len
        BEQ save_cr
        LDY #&00
.save_loop
        LDA (zp_ptr_lo),Y : STA alias_buffer,Y
        INY
        CPY xi_line_len
        BNE save_loop
.save_cr
        LDA #&0d : STA alias_buffer,Y
        RTS
}
.xi_scroll_count
    EQUB &A6
\ XI alias restore: retrieves a previously stored command line from the
\ alias history buffer, scrolling through entries by index.
.xi_history_recall
{
        LDA #&0D : STA xi_hist_flag
        LDA xi_scroll_count
        CMP #&FF
        BNE check_count
        LDA #&00 : STA xi_scroll_count
.check_count
        CMP xi_alias_count
        BCC set_ptr
        LDA xi_alias_count
        DEC A
        STA xi_scroll_count
.set_ptr
        LDA #LO(xi_hist_buffer) : STA zp_src_lo
        LDA #HI(xi_hist_buffer) : STA zp_src_hi
        LDX xi_scroll_count
        BNE check_end
.clear_and_load
        JSR xi_do_clear
        LDA (zp_src_lo)
        CMP #&0d
        BNE find_cr
        JMP xi_read_loop
.find_cr
        LDY #&ff
.find_loop
        INY
        LDA (zp_src_lo),Y : STA xi_char
        CMP #&0d
        BNE insert_char
        JMP xi_read_loop
.insert_char
        PHY
        JSR xi_do_insert
        PLY
        BRA find_loop
.check_end
        LDY #&00
.check_loop
        LDA (zp_src_lo),Y
        CMP #&0d
        BEQ advance
        INY
        BNE check_loop
        LDA #&00 : STA xi_scroll_count
        JMP xi_history_recall
.advance
        INY
        TYA
        CLC : ADC zp_src_lo
        STA zp_src_lo
        LDA zp_src_hi
        ADC #&00
        STA zp_src_hi
        DEX
        BEQ clear_and_load
        CMP #zp_src_lo
        BCC check_end
        LDA zp_src_lo
        CMP #&55
        BCC check_end
        LDA #&00 : STA xi_scroll_count
        JMP xi_history_recall
}
\ token_classify — identifies assembler-context tokens and sets lvar_indent
\ to indicate how many operand bytes to skip past.
\ Returns: carry set if recognised (indent set), carry clear if not.
\   &45 ("E" — EQUB/EQUW/EQUS) -> skip 4 bytes
\   &80 (AND) -> skip 1 byte
\   &82 (EOR) -> skip 1 byte
\   &84 (OR)  -> skip 2 bytes
.token_classify
{
        CMP #&45
        BNE check_80
        LDA #&04 : STA lvar_indent
        BRA found
.check_80
        CMP #&80
        BNE check_82
        LDA #&01 : STA lvar_indent
        BRA found
.check_82
        CMP #&82
        BNE check_84
        LDA #&01 : STA lvar_indent
        BRA found
.check_84
        CMP #&84
        BNE not_found
        LDA #&02 : STA lvar_indent
        BRA found
.not_found
        CLC                     \ not recognised
        RTS
.found
        SEC                     \ recognised
        RTS
}
\ print_decimal — prints the 16-bit value in dec_value_lo/hi as a
\ right-justified 5-character decimal number (space-padded on the left).
\ Uses repeated shift-and-subtract (double-dabble style): shifts the 16-bit
\ value left one bit at a time, accumulating each decimal digit in A.
\ Digits are pushed onto the stack in reverse order, then padded with spaces
\ to fill 5 columns, and finally popped and printed left-to-right.
.print_decimal
{
        LDY #&00                \ Y = digit count
.digit_loop
        LDX #&10                \ 16 bits to shift
        LDA #&00
.shift
        ASL dec_value_lo : ROL dec_value_hi
        ROL A                   \ shift next bit into accumulator
        CMP #&0a
        BCC next_bit
        SBC #&0a                \ digit overflow: subtract 10, carry 1 back
        INC dec_value_lo
.next_bit
        DEX
        BNE shift
        CLC : ADC #'0'          \ convert digit to ASCII
        PHA                     \ push digit (most significant first)
        INY
        LDA dec_value_lo
        ORA dec_value_hi
        BNE digit_loop          \ more digits if value is non-zero
.pad
        CPY #&05                \ pad to 5 characters with leading spaces
        BEQ output
        LDA #' '
        PHA
        INY
        BNE pad
.output
        STY dec_digit_count
.print_digit
        PLA
        JSR oswrch
        DEC dec_digit_count
        BNE print_digit
        RTS
}
.dec_value_lo
    EQUB &00
.dec_value_hi
    EQUB &00
.dec_digit_count
    EQUB &00
    EQUB &00                    \ padding
