\ mem.asm — Memory editor: *MEM command

.cmd_mem
    JSR parse_cmdline
    CMP #&0d
    BEQ mem_setup_display
    JSR parse_hex_word
    LDA zp_src_lo
    STA mem_edit_lo
    LDA zp_src_hi
    STA mem_edit_hi
.mem_setup_display
    LDA mem_edit_lo
    STA zp_ptr_lo
    LDA mem_edit_hi
    STA zp_ptr_hi
    LDA zp_ptr_lo
    AND #&07
    STA mem_column
    EOR &a8
    STA zp_ptr_lo
    LDA #&16
    JSR oswrch
    LDA #&07
    JSR oswrch
    LDA #&0a
    STA crtc_addr
    LDA #&20
    STA crtc_data
    LDX #&27
.mem_copy_header
    LDA mem_header,X
    STA mode7_screen,X
    DEX
    BPL mem_copy_header
    LDA os_wrch_dest : STA mem_mode
    LDA #&01
    STA os_wrch_dest
    LDA os_disp_addr : STA mem_page_size
    LDA #&02
    STA os_disp_addr
    LDA #&50
    STA zp_tmp_lo
    LDA #&7c
    STA zp_tmp_hi
    LDX #&16
.mem_draw_row
    LDA #&83
    LDY #&00
    STA (&ac),Y
    LDA #&87
    LDY #&05
    STA (&ac),Y
    LDA #&86
    LDY #&1f
    STA (&ac),Y
    CLC
    LDA zp_tmp_lo
    ADC #&28
    STA zp_tmp_lo
    BCC mem_next_row
    INC &ad
.mem_next_row
    DEX
    BNE mem_draw_row
.mem_adjust_ptr
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
.mem_check_key
    CMP mem_key_codes,X
    BEQ mem_dispatch
    DEX
    BPL mem_check_key
    PHA
    LDA mode7_screen + &27
    CMP #&48
    BEQ mem_handle_hex
    PLA
    LDY mem_column
    STA (zp_ptr_lo),Y
    JSR mem_cursor_down
    JMP mem_adjust_ptr
.mem_handle_hex
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
.mem_dispatch
    TXA
    ASL A
    TAX
    LDA mem_routine_table,X
    STA cmd_dispatch_addr + 1
    LDA mem_routine_table + 1,X
    STA cmd_dispatch_addr + 2
    JSR cmd_dispatch
    JMP mem_adjust_ptr
.mem_set_mode
    LDA mem_mode : STA os_wrch_dest
    LDA mem_page_size : STA os_disp_addr
    LDA #&0a
    STA crtc_addr
    LDA #&72
    STA crtc_data
    LDA #&1f
    JSR oswrch
    LDA #&00
    JSR oswrch
    LDA #&18
    JSR oswrch
    LDA #&00
    STA &ff
    RTS
.mem_cursor_up
    DEC mem_column
    EQUB &10, &12  \ BPL &9542
    LDA #&07
    STA mem_column
    SEC
    LDA &A8
    SBC #&08
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
.mem_cursor_rts
    RTS
.mem_cursor_down
    LDA mem_column
    INC A
    STA mem_column
    CMP #&08
    BNE mem_cursor_rts
    LDA #&00
    STA mem_column
    CLC
    LDA zp_ptr_lo
    ADC #&08
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    RTS
.mem_page_up
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE mem_row_up
    SEC
    LDA &A8
    SBC #&b0
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
    RTS
.mem_row_up
    SEC
    LDA &A8
    SBC #&08
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
    RTS
.mem_page_down
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE mem_row_down
    CLC
    LDA &A8
    ADC #&b0
    STA &A8
    LDA &A9
    ADC #&00
    STA &A9
    RTS
.mem_row_down
    CLC
    LDA &A8
    ADC #&08
    STA &A8
    LDA &A9
    ADC #&00
    STA &A9
    RTS
.mem_toggle_mode
    LDA mode7_screen + &27
    EOR #&09
    STA mode7_screen + &27
    RTS
.dis_setup
    LDA #&16
    STA dis_temp
    LDA #&51
    STA zp_tmp_lo
    LDA #&7c
    STA zp_tmp_hi
.dis_line_loop
    LDA zp_src_hi
    JSR dis_print_hex_byte
    LDA zp_src_lo
    JSR dis_print_hex_byte
    CLC
    LDA zp_tmp_lo
    ADC #&02
    STA zp_tmp_lo
    BCC dis_hex_dump
    INC &ad
.dis_hex_dump
    LDY #&00
.dis_hex_byte_loop
    LDA (&ae),Y
    JSR dis_print_hex_byte
    INC &ac
    BNE dis_hex_next
    INC &ad
.dis_hex_next
    INY
    CPY #&08
    BNE dis_hex_byte_loop
    CLC
    LDA zp_tmp_lo
    ADC #&01
    STA zp_tmp_lo
    BCC dis_ascii_dump
    INC &ad
.dis_ascii_dump
    LDY #&00
.dis_ascii_loop
    LDA (&ae),Y
    AND #&7f
    CMP #' '
    BCS dis_store_byte
    LDA #&2e
.dis_store_byte
    STA (&ac),Y
    INY
    CPY #&08
    BNE dis_ascii_loop
    CLC
    LDA zp_tmp_lo
    ADC #&09
    STA zp_tmp_lo
    BCC dis_advance_ptr
    INC &ad
.dis_advance_ptr
    CLC
    LDA zp_src_lo
    ADC #&08
    STA zp_src_lo
    BCC dis_next_line
    INC &af
.dis_next_line
    DEC dis_temp
    BNE dis_line_loop
    LDY #&00
    TYA
.dis_bracket_loop
    STA mode7_screen + &1E6,Y
    INY : INY : INY
    CPY #&1b
    BNE dis_bracket_loop
    LDA mem_column
    ASL A
    ADC mem_column
    TAY
    LDA #&5d
    STA mode7_screen + &1E6,Y
    LDA #&5b
    STA mode7_screen + &1E9,Y
    RTS
.dis_temp
    EQUB &00
.dis_print_hex_byte
    STA dis_print_lo_nibble + 1
    LSR A : LSR A : LSR A : LSR A  \ high nibble
    TAX : LDA hex_digits,X
    EQUB &92, &AC  \ STA (0xac)
    INC &ac
    BNE dis_print_lo_nibble
    INC &ad
.dis_print_lo_nibble
    LDA #&88
    AND #&0f
    TAX
    LDA hex_digits,X
    EQUB &92, &AC  \ STA (0xac)
    INC &ac
    BNE dis_hex_byte_rts
    INC &ad
.dis_hex_byte_rts
    RTS
.dis_print_hex_word
    STA dis_hex_word_lda + 1
    LSR A : LSR A : LSR A : LSR A  \ high nibble
    TAX : LDA hex_digits,X
    JSR oswrch
.dis_hex_word_lda
    LDA #&62
    AND #&0f
    TAX
    LDA hex_digits,X
    JMP oswrch
\ --- Disassembler addressing mode format strings ---
\ &l = low byte, &hl = high+low bytes, &b = branch offset
