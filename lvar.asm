\ lvar.asm — Variable lister: *LVAR, token classify, print_decimal

\ *LVAR — lists all BASIC variables currently defined.
\ BASIC stores variables in 64 hash-chain buckets (A-Z pairs), each a
\ linked list. This walks all 64 buckets, printing each variable's name
\ prefixed with a letter derived from the bucket index (X/2 + &40 = 'A'..).
\ Each variable entry has a forward-link pointer at offset 0-1 and a
\ null-terminated name starting at offset 2.
.cmd_lvar
    LDA os_mode
    CMP #&0c
    BEQ lvar_start
    JSR copy_inline_to_stack    \ BRK error: "VAR works only in BASIC"
    EQUS &4C, "VAR works only in BASIC", 0
.lvar_start
    LDX #&00
.lvar_var_loop
    LDA os_fkey_buf,X
    STA zp_ptr_lo
    INX
    LDA os_fkey_buf,X
    DEX
    STA zp_ptr_hi
    CMP #&00                    \ null hi-byte means empty bucket
    BEQ lvar_next_var
.lvar_check_type
    TXA
    LSR A                       \ bucket index / 2
    CLC
    ADC #'@'                    \ convert to ASCII letter ('A' onwards)
    JSR oswrch
    LDY #&01
.lvar_skip_name
    INY
    LDA (zp_ptr_lo),Y
    BEQ lvar_print_newline      \ null terminator ends the variable name
    JSR oswrch
    BRA lvar_skip_name
.lvar_print_newline
    JSR osnewl
    LDY #&01                    \ follow linked-list pointer to next variable
    LDA (zp_ptr_lo),Y
    BEQ lvar_next_var           \ null = end of chain
    STA zp_tmp_lo
    DEY
    LDA (zp_ptr_lo),Y
    STA zp_ptr_lo
    LDA zp_tmp_lo
    STA zp_ptr_hi
    BRA lvar_check_type
.lvar_next_var
    INX                         \ advance to next bucket (2 bytes per entry)
    INX
    CPX #&80                    \ 64 buckets * 2 = &80
    BNE lvar_var_loop
    RTS
\ --- MEM editor configuration data ---
.mem_workspace
    EQUB &00, &00
.mem_edit_lo
    EQUB &00
.mem_edit_hi
    EQUB &12
.mem_vdu_1
    EQUB &E3
.mem_vdu_2
    EQUB &16
.mem_mode
    EQUB &01
.mem_page_size
    EQUB &03
.mem_column
    EQUB &02                    \ MEM column counter (0-7)
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
    INY
.lvar_parse_token
    LDA #&00
    STA lvar_indent
    LDA (zp_ptr_lo),Y
    CMP #&0d
    BNE lvar_check_dot
    JMP lvar_end_of_line
.lvar_check_dot
    CMP #'.'                    \ "." — assembler label definition
    BNE lvar_check_string
.lvar_scan_name
    INY                         \ skip label name until space or colon
    LDA (zp_ptr_lo),Y
    CMP #&0d
    BNE lvar_check_space
    JMP lvar_end_of_line
.lvar_check_space
    CMP #' '
    BEQ lvar_next_token
    CMP #':'
    BNE lvar_scan_name
.lvar_next_token
    INY
    BRA lvar_parse_token
.lvar_check_string
    CMP #&22                    \ skip over quoted string literals
    BNE lvar_lookup_token
.lvar_string_loop
    INY
    LDA (zp_ptr_lo),Y
    CMP #&0d
    BEQ lvar_end_of_line
    CMP #&22
    BNE lvar_string_loop
    INY
    BRA lvar_parse_token
\ Classify the current byte via token_classify. If recognised, skip past
\ a number of characters determined by the indent value (operand width).
.lvar_lookup_token
    JSR token_classify
    BCS lvar_print_token        \ carry set = known token, skip its operand
    CMP #':'                    \ ":" statement separator
    BNE lvar_check_close
    INY
    BRA lvar_parse_token
.lvar_check_close
    CMP #']'                    \ "]" — end of assembler block
    BNE lvar_check_backslash
    JMP lvar_done
.lvar_check_backslash
    CMP #'\'                    \ "\" — assembler comment, skip to end of stmt
    BNE lvar_set_indent
.lvar_skip_backslash
    INY
    LDA (zp_ptr_lo),Y
    CMP #':'
    BEQ lvar_skip_and_continue
    CMP #&0d
    BNE lvar_skip_backslash
    JMP lvar_end_of_line
.lvar_skip_and_continue
    INY
    BRA lvar_parse_token
.lvar_set_indent
    LDA #&03                    \ default: skip 3 chars (opcode + operand)
    STA lvar_indent
\ Skip past the operand bytes (counted by lvar_indent), then insert a
\ space before the next item if one isn't already there.
.lvar_print_token
    INY
    LDA (zp_ptr_lo),Y
    CMP #']'
    BEQ lvar_done
    CMP #&0d
    BEQ lvar_end_of_line
    DEC lvar_indent
    BNE lvar_print_token        \ keep skipping until indent reaches 0
    CMP #':'
    BEQ lvar_parse_token
    CMP #' '
    BEQ lvar_print_char         \ already has a space, just continue
    DEY
    JSR space_shift_up           \ insert a space byte before this position
    PHY
    LDY #&03
    LDA (zp_ptr_lo),Y
    INC A
    STA (zp_ptr_lo),Y
    PLY
    CLC
    LDA &00
    ADC #&01
    STA &00
    LDA &01
    ADC #&00
    STA &01
    LDA #' '
    INY
    STA (zp_ptr_lo),Y
.lvar_print_char
    INY
    LDA (zp_ptr_lo),Y
    CMP #&0d
    BEQ lvar_end_of_line
    CMP #':'
    BNE lvar_print_char
    INY
    JMP lvar_parse_token
\ Advance to the next BASIC line and continue formatting
.lvar_end_of_line
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
    CMP #&ff                    \ end-of-program marker
    BNE lvar_continuation
    JMP space_save_top
.lvar_continuation
    LDY #&04
    JMP lvar_parse_token
.lvar_done
    JMP space_scan_loop         \ return to *SPACE main scan loop
\ XI alias history support: copies the current command line into the alias
\ buffer and shifts the existing alias history down to make room.
.xi_support_entry
    LDA #&54
    STA &AC
    LDA #&ae
    STA &AD
    INC xi_alias_count
    LDA xi_alias_count
    BNE xi_supp_inc_cursor
    LDA #&ff
    STA xi_alias_count
.xi_supp_inc_cursor
    INC xi_cursor_pos
    SEC
    LDA &AC
    SBC xi_cursor_pos
    STA &AE
    LDA &AD
    SBC #&00
    STA &AF
    DEC xi_cursor_pos
    LDA #&0d
    STA alias_end_lo
    LDA #&ff
    STA alias_end_hi
.xi_supp_copy_loop
    LDA (zp_src_lo)
    EQUB &92, &AC               \ STA (&ac)
    SEC
    LDA &AC
    SBC #&01
    STA &AC
    LDA &AD
    SBC #&00
    STA &AD
    SEC
    LDA &AE
    SBC #&01
    STA &AE
    LDA &AF
    SBC #&00
    STA &AF
    LDA &AE
    CMP #&54
    BNE xi_supp_copy_loop
    LDA &AF
    CMP #&aa
    BNE xi_supp_copy_loop
    LDY xi_cursor_pos
    BEQ xi_supp_save_cr
    LDY #&00
.xi_supp_save_loop
    LDA (zp_ptr_lo),Y
    STA alias_buffer,Y
    INY
    CPY xi_cursor_pos
    BNE xi_supp_save_loop
.xi_supp_save_cr
    LDA #&0d
    STA alias_buffer,Y
    RTS
.xi_scroll_count
    EQUB &A6
\ XI alias restore: retrieves a previously stored command line from the
\ alias history buffer, scrolling through entries by index.
.xi_supp_restore
    LDA #&0D
    STA alias_end_hi
    LDA xi_scroll_count
    CMP #&FF
    BNE xi_supp_check_count
    LDA #&00
    STA xi_scroll_count
.xi_supp_check_count
    CMP xi_alias_count
    BCC xi_supp_set_ptr
    LDA xi_alias_count
    DEC A
    STA xi_scroll_count
.xi_supp_set_ptr
    LDA #&55
    STA &AE
    LDA #&aa
    STA &AF
    LDX xi_scroll_count
    BNE xi_supp_check_end
.xi_supp_clear_and_load
    JSR xi_do_clear
    LDA (zp_src_lo)
    CMP #&0d
    BNE xi_supp_find_cr
    JMP xi_read_loop
.xi_supp_find_cr
    LDY #&ff
.xi_supp_find_loop
    INY
    LDA (zp_src_lo),Y
    STA xi_char
    CMP #&0d
    BNE xi_supp_insert_char
    JMP xi_read_loop
.xi_supp_insert_char
    PHY
    JSR xi_do_insert
    PLY
    BRA xi_supp_find_loop
.xi_supp_check_end
    LDY #&00
.xi_supp_check_loop
    LDA (zp_src_lo),Y
    CMP #&0d
    BEQ xi_supp_advance
    INY
    BNE xi_supp_check_loop
    LDA #&00
    STA xi_scroll_count
    JMP xi_supp_restore
.xi_supp_advance
    INY
    TYA
    CLC
    ADC &AE
    STA &AE
    LDA &AF
    ADC #&00
    STA &AF
    DEX
    BEQ xi_supp_clear_and_load
    CMP #&ae
    BCC xi_supp_check_end
    LDA &AE
    CMP #&55
    BCC xi_supp_check_end
    LDA #&00
    STA xi_scroll_count
    JMP xi_supp_restore
\ token_classify — identifies assembler-context tokens and sets lvar_indent
\ to indicate how many operand bytes to skip past.
\ Returns: carry set if recognised (indent set), carry clear if not.
\   &45 ("E" — EQUB/EQUW/EQUS) -> skip 4 bytes
\   &80 (AND) -> skip 1 byte
\   &82 (EOR) -> skip 1 byte
\   &84 (OR)  -> skip 2 bytes
.token_classify
    CMP #&45
    BNE token_check_80
    LDA #&04
    STA lvar_indent
    BRA token_found
.token_check_80
    CMP #&80
    BNE token_check_82
    LDA #&01
    STA lvar_indent
    BRA token_found
.token_check_82
    CMP #&82
    BNE token_check_84
    LDA #&01
    STA lvar_indent
    BRA token_found
.token_check_84
    CMP #&84
    BNE token_not_found
    LDA #&02
    STA lvar_indent
    BRA token_found
.token_not_found
    CLC                         \ not recognised
    RTS
.token_found
    SEC                         \ recognised
    RTS
\ print_decimal — prints the 16-bit value in dec_value_lo/hi as a
\ right-justified 5-character decimal number (space-padded on the left).
\ Uses repeated shift-and-subtract (double-dabble style): shifts the 16-bit
\ value left one bit at a time, accumulating each decimal digit in A.
\ Digits are pushed onto the stack in reverse order, then padded with spaces
\ to fill 5 columns, and finally popped and printed left-to-right.
.print_decimal
    LDY #&00                    \ Y = digit count
.print_dec_loop
    LDX #&10                    \ 16 bits to shift
    LDA #&00
.print_dec_shift
    ASL dec_value_lo
    ROL dec_value_hi
    ROL A                       \ shift next bit into accumulator
    CMP #&0a
    BCC print_dec_next_bit
    SBC #&0a                    \ digit overflow: subtract 10, carry 1 back
    INC dec_value_lo
.print_dec_next_bit
    DEX
    BNE print_dec_shift
    CLC
    ADC #'0'                    \ convert digit to ASCII
    PHA                         \ push digit (most significant first)
    INY
    LDA dec_value_lo
    ORA dec_value_hi
    BNE print_dec_loop          \ more digits if value is non-zero
.print_dec_done
    CPY #&05                    \ pad to 5 characters with leading spaces
    BEQ print_dec_output
    LDA #' '
    PHA
    INY
    BNE print_dec_done
.print_dec_output
    STY dec_digit_count
.print_dec_digit
    PLA
    JSR oswrch
    DEC dec_digit_count
    BNE print_dec_digit
    RTS
.dec_value_lo
    EQUB &00
.dec_value_hi
    EQUB &00
.dec_digit_count
    EQUB &00
    EQUB &00                    \ padding
