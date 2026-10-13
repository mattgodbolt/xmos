\ lvar.asm — Variable lister: *LVAR, token classify, print_decimal

\ *LVAR — lists everything on BASIC's heap: variables, arrays, and PROC and
\ FN names. BASIC keeps one linked list per initial character, &40-&7F; PROC
\ and FN names sit in the lists for '{' and '|', so they print that way.
\ Each name is printed as the list's character (X/2 + '@') followed by the
\ entry's own null-terminated name, which starts at offset 2 after the
\ forward link.
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
        LDA basic_var_lists,X : STA zp_ptr_lo
        INX
        LDA basic_var_lists,X
        DEX
        STA zp_ptr_hi
        CMP #&00                \ null hi-byte means empty list
        BEQ next_var
.check_type
        TXA
        LSR A                   \ list number
        CLC : ADC #'@'          \ the name's initial character
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
        INX                     \ advance to next list head (2 bytes each)
        INX
        CPX #&80                \ 64 lists * 2 = &80
        BNE var_loop
        RTS
}
\ --- MEM/DIS editor workspace (all set at runtime) ---
.mem_workspace  SKIP 2
.mem_edit_lo    SKIP 1          \ MEM current address low byte
.mem_edit_hi    SKIP 1          \ MEM current address high byte
.dis_resume_lo  SKIP 1          \ DIS resume address low byte
.dis_resume_hi  SKIP 1          \ DIS resume address high byte
.mem_saved_cursor_edit SKIP 1   \ Cursor editing type to restore when MEM exits
.mem_saved_repeat_rate SKIP 1   \ Auto-repeat rate to restore when MEM exits
.mem_column     SKIP 1          \ MEM column counter (0-7)
.mem_key_codes
    EQUB &88, &89, &8A, &8B     \ Key codes: left, right, down, up
    EQUB &09                    \ TAB key
.mem_routine_table
    EQUW mem_cursor_left
    EQUW mem_cursor_right
    EQUW mem_row_down
    EQUW mem_row_up
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
\ backslash comments, and mnemonics that BASIC tokenised via token_classify.
.space_asm_block
{
        INY
.parse_token
        LDA #&00 : STA space_mnemonic_len
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
\ Classify the current byte via token_classify, which gives the length in
\ program bytes of a mnemonic that BASIC tokenised; anything else is taken
\ to be a 3-letter mnemonic. Skip the mnemonic, then make sure a space follows.
.lookup_token
        JSR token_classify
        BCS skip_mnemonic       \ carry set = known token
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
        LDA #&03 : STA space_mnemonic_len  \ default: a 3-letter mnemonic
.skip_mnemonic
        INY
        LDA (zp_ptr_lo),Y
        CMP #']'
        BEQ done
        CMP #&0d
        BEQ end_of_line
        DEC space_mnemonic_len
        BNE skip_mnemonic
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
\ Save the current input line at the front of the history buffer, shifting
\ the older entries along to make room.
.xi_history_save
{
        LDA #LO(xi_hist_flag) : STA zp_tmp_lo
        LDA #HI(xi_hist_flag) : STA zp_tmp_hi
        INC xi_hist_count
        LDA xi_hist_count
        BNE inc_cursor
        LDA #&ff : STA xi_hist_count
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
        LDA zp_src_lo : CMP #LO(xi_hist_buffer - 1)
        BNE copy_loop
        LDA zp_src_hi : CMP #HI(xi_hist_buffer - 1)
        BNE copy_loop
        LDY xi_line_len
        BEQ save_cr
        LDY #&00
.save_loop
        LDA (zp_ptr_lo),Y : STA xi_hist_buffer,Y
        INY
        CPY xi_line_len
        BNE save_loop
.save_cr
        LDA #&0d : STA xi_hist_buffer,Y
        RTS
}
.xi_hist_index
    EQUB &A6
\ Replace the input line with history entry xi_hist_index.
.xi_history_recall
{
        LDA #&0D : STA xi_hist_flag
        LDA xi_hist_index
        CMP #&FF
        BNE check_count
        LDA #&00 : STA xi_hist_index
.check_count
        CMP xi_hist_count
        BCC set_ptr
        LDA xi_hist_count
        DEC A
        STA xi_hist_index
.set_ptr
        LDA #LO(xi_hist_buffer) : STA zp_src_lo
        LDA #HI(xi_hist_buffer) : STA zp_src_hi
        LDX xi_hist_index
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
        LDA #&00 : STA xi_hist_index
        JMP xi_history_recall
.advance
        INY
        TYA
        CLC : ADC zp_src_lo
        STA zp_src_lo
        LDA zp_src_hi
        ADC #&00
        STA zp_src_hi
        CMP #HI(xi_hist_flag + 1)
        BCC in_buffer
        LDA zp_src_lo : CMP #LO(xi_hist_flag + 1)
        BCC in_buffer
        LDA #&00 : STA xi_hist_index
        JMP xi_history_recall
.in_buffer
        DEX
        BEQ clear_and_load
        BRA check_end
}
\ token_classify — sets space_mnemonic_len to the length in program bytes
\ of a mnemonic BASIC stores specially.
\ Returns: carry set if recognised, carry clear if not.
\   &45 ("E" — EQUB/EQUW/EQUD/EQUS) -> 4 bytes
\   &80 (AND token)                 -> 1 byte
\   &82 (EOR token)                 -> 1 byte
\   &84 (OR token, then "A" of ORA) -> 2 bytes
.token_classify
{
        CMP #&45
        BNE check_80
        LDA #&04 : STA space_mnemonic_len
        BRA found
.check_80
        CMP #&80
        BNE check_82
        LDA #&01 : STA space_mnemonic_len
        BRA found
.check_82
        CMP #&82
        BNE check_84
        LDA #&01 : STA space_mnemonic_len
        BRA found
.check_84
        CMP #&84
        BNE not_found
        LDA #&02 : STA space_mnemonic_len
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
