\ lvar.asm — Variable lister: *LVAR, token classify, print_decimal

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
    STA &a8
    INX
    LDA os_fkey_buf,X
    DEX
    STA &a9
    CMP #&00
    BEQ lvar_next_var
.lvar_check_type
    TXA
    LSR A
    CLC
    ADC #&40
    JSR oswrch
    LDY #&01
.lvar_skip_name
    INY
    LDA (&a8),Y
    BEQ lvar_print_newline
    JSR oswrch
    BRA lvar_skip_name
.lvar_print_newline
    JSR osnewl
    LDY #&01
    LDA (&a8),Y
    BEQ lvar_next_var
    STA &ac
    DEY
    LDA (&a8),Y
    STA &a8
    LDA &ac
    STA &a9
    BRA lvar_check_type
.lvar_next_var
    INX
    INX
    CPX #&80
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
    EQUB &02                   \ MEM column counter (0-7)
.mem_key_codes
    EQUB &88, &89, &8A, &8B   \ Key codes: left, right, down, up
    EQUB &09                   \ TAB key
.mem_routine_table
    EQUW mem_cursor_up                 \ Address of cursor-up routine
    EQUW mem_cursor_down                 \ Address of cursor-down routine
    EQUW mem_page_down                 \ Address of page-down routine
    EQUW mem_page_up                 \ Address of page-up routine
    EQUW mem_toggle_mode                 \ Address of hex/ascii toggle
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
.lvar_display_value
    INY
.lvar_parse_token
    LDA #&00
    STA lvar_indent
    LDA (&a8),Y
    CMP #&0d
    BNE lvar_check_dot
    JMP lvar_end_of_line
.lvar_check_dot
    CMP #&2e
    BNE lvar_check_string
.lvar_scan_name
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE lvar_check_space
    JMP lvar_end_of_line
.lvar_check_space
    CMP #&20
    BEQ lvar_next_token
    CMP #&3a
    BNE lvar_scan_name
.lvar_next_token
    INY
    BRA lvar_parse_token
.lvar_check_string
    CMP #&22
    BNE lvar_lookup_token
.lvar_string_loop
    INY
    LDA (&a8),Y
    CMP #&0d
    BEQ lvar_end_of_line
    CMP #&22
    BNE lvar_string_loop
    INY
    BRA lvar_parse_token
.lvar_lookup_token
    JSR token_classify
    BCS lvar_print_token
    CMP #&3a
    BNE lvar_check_close
    INY
    BRA lvar_parse_token
.lvar_check_close
    CMP #&5d
    BNE lvar_check_backslash
    JMP lvar_done
.lvar_check_backslash
    CMP #&5c
    BNE lvar_set_indent
.lvar_skip_backslash
    INY
    LDA (&a8),Y
    CMP #&3a
    BEQ lvar_skip_and_continue
    CMP #&0d
    BNE lvar_skip_backslash
    JMP lvar_end_of_line
.lvar_skip_and_continue
    INY
    BRA lvar_parse_token
.lvar_set_indent
    LDA #&03
    STA lvar_indent
.lvar_print_token
    INY
    LDA (&a8),Y
    CMP #&5d
    BEQ lvar_done
    CMP #&0d
    BEQ lvar_end_of_line
    DEC lvar_indent
    BNE lvar_print_token
    CMP #&3a
    BEQ lvar_parse_token
    CMP #&20
    BEQ lvar_print_char
    DEY
    JSR space_shift_up
    PHY
    LDY #&03
    LDA (&a8),Y
    INC A
    STA (&a8),Y
    PLY
    CLC
    LDA &00
    ADC #&01
    STA &00
    LDA &01
    ADC #&00
    STA &01
    LDA #&20
    INY
    STA (&a8),Y
.lvar_print_char
    INY
    LDA (&a8),Y
    CMP #&0d
    BEQ lvar_end_of_line
    CMP #&3a
    BNE lvar_print_char
    INY
    JMP lvar_parse_token
.lvar_end_of_line
    LDY #&03
    CLC
    LDA (&a8),Y
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JSR print_backspace
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE lvar_continuation
    JMP space_save_top
.lvar_continuation
    LDY #&04
    JMP lvar_parse_token
.lvar_done
    JMP space_scan_loop
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
    EQUB &B2, &AE  \ LDA (&ae)
    EQUB &92, &AC  \ STA (&ac)
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
    LDA (&a8),Y
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
    EQUB &B2, &AE  \ LDA (&ae)
    CMP #&0d
    BNE xi_supp_find_cr
    JMP xi_read_loop
.xi_supp_find_cr
    LDY #&ff
.xi_supp_find_loop
    INY
    LDA (&ae),Y
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
    LDA (&ae),Y
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
    CLC
    RTS
.token_found
    SEC
    RTS
.print_decimal
    LDY #&00
.print_dec_loop
    LDX #&10
    LDA #&00
.print_dec_shift
    ASL dec_value_lo
    ROL dec_value_hi
    ROL A
    CMP #&0a
    BCC print_dec_next_bit
    SBC #&0a
    INC dec_value_lo
.print_dec_next_bit
    DEX
    BNE print_dec_shift
    CLC
    ADC #&30
    PHA
    INY
    LDA dec_value_lo
    ORA dec_value_hi
    BNE print_dec_loop
.print_dec_done
    CPY #&05
    BEQ print_dec_output
    LDA #&20
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
    EQUB &00                   \ padding
