\ dis.asm — Disassembler: *DIS command, addressing mode tables

.dis_addr_modes
    EQUB &81                   \ Mode 0: ??? (invalid opcode)
    EQUS "???", 0
    EQUS "#&l", 0             \ Mode 1: immediate
    EQUS "&hl", 0             \ Mode 2: absolute
    EQUS "&l", 0              \ Mode 3: zero page
    EQUS "A", 0               \ Mode 4: accumulator
    EQUS " ", 0               \ Mode 5: implied
    EQUS "(&l,X)", 0          \ Mode 6: (indirect,X)
    EQUS "(&l),Y", 0          \ Mode 7: (indirect),Y
    EQUS "&l,X", 0            \ Mode 8: zero page,X
    EQUS "&l,Y", 0            \ Mode 9: zero page,Y
    EQUS "&hl,X", 0           \ Mode 10: absolute,X
    EQUS "&hl,Y", 0           \ Mode 11: absolute,Y
    EQUS "&b", 0              \ Mode 12: relative (branch)
    EQUS "(&hl)", 0           \ Mode 13: (indirect)
    EQUS "(&hl,X)", 0         \ Mode 14: (indirect,X) 65C02
    EQUS "(&l)", 0            \ Mode 15: (indirect) 65C02 ZP
\ --- Addressing mode pointer table (16 entries, low/high pairs) ---
.dis_addr_mode_ptrs
    EQUW dis_addr_modes + &00  \ Mode 0: ???
    EQUW dis_addr_modes + &05  \ Mode 1: #&l
    EQUW dis_addr_modes + &09  \ Mode 2: &hl
    EQUW dis_addr_modes + &0D  \ Mode 3: &l
    EQUW dis_addr_modes + &10  \ Mode 4: A
    EQUW dis_addr_modes + &12  \ Mode 5: implied
    EQUW dis_addr_modes + &14  \ Mode 6: (&l,X)
    EQUW dis_addr_modes + &1B  \ Mode 7: (&l),Y
    EQUW dis_addr_modes + &22  \ Mode 8: &l,X
    EQUW dis_addr_modes + &27  \ Mode 9: &l,Y
    EQUW dis_addr_modes + &2C  \ Mode 10: &hl,X
    EQUW dis_addr_modes + &32  \ Mode 11: &hl,Y
    EQUW dis_addr_modes + &38  \ Mode 12: &b
    EQUW dis_addr_modes + &3B  \ Mode 13: (&hl)
    EQUW dis_addr_modes + &41  \ Mode 14: (&hl,X)
    EQUW dis_addr_modes + &49  \ Mode 15: (&l)
\ --- Operand byte counts per addressing mode ---
.dis_operand_sizes
    EQUB 1, 2, 3, 2, 1, 1, 2, 2, 2, 2, 3, 3, 2, 3, 3, 2
.cmd_dis
    JSR parse_cmdline
    CMP #&0d
    BEQ dis_display_line
    JSR parse_hex_word
    BRA dis_print_header
.dis_display_line
    LDA mem_vdu_1
    STA zp_src_lo
    LDA mem_vdu_2
    STA zp_src_hi
.dis_print_header
    LDA #&82
    JSR oswrch
    JSR oswrch
    LDA zp_src_hi
    JSR dis_print_hex_word
    LDA zp_src_lo
    JSR dis_print_hex_word
    LDA #&20
    JSR oswrch
    LDY #&00
    STY &ad
    LDA (zp_src_lo),Y                 \ opcode × 4 to get table offset
    ASL A : ROL &ad
    ASL A : ROL &ad
    CLC : ADC #&56 : STA &ac   \ add table base low byte
    LDA zp_tmp_hi
    ADC #&a1
    STA zp_tmp_hi
    LDY #&03
    LDA (zp_tmp_lo),Y
    BEQ dis_get_mode
    LDA #&83
    JSR oswrch
    LDY #&00
.dis_print_opcode
    LDA (zp_tmp_lo),Y
    JSR oswrch
    INY
    CPY #&03
    BNE dis_print_opcode
    LDA #&20
    JSR oswrch
.dis_get_mode
    LDY #&03
    LDA (zp_tmp_lo),Y
    PHA
    ASL A
    TAX
    LDA dis_addr_mode_ptrs,X
    STA zp_tmp_lo
    LDA dis_addr_mode_ptrs + 1,X
    STA zp_tmp_hi
    LDY #&ff
.dis_format_loop
    INY
    LDA (zp_tmp_lo),Y
    BEQ dis_print_addr
    CMP #&68
    BNE dis_check_lo
    JMP dis_check_up
.dis_check_lo
    CMP #&6c
    BNE dis_check_branch
    JMP dis_check_down
.dis_check_branch
    CMP #&62
    BNE dis_print_char
    JMP dis_check_right
.dis_print_char
    JSR oswrch
    BRA dis_format_loop
.dis_print_addr
    LDA #&86
    JSR oswrch
    LDA os_vdu_x
    CMP #&16
    BNE dis_print_addr
    PLX
    LDA dis_operand_sizes,X
    PHA
    TAX
    LDY #&00
.dis_print_byte
    LDA (zp_src_lo),Y
    PHX
    JSR dis_print_hex_word
    PLX
    LDA #&20
    JSR oswrch
    INY
    DEX
    BNE dis_print_byte
.dis_print_ascii
    LDA #&85
    JSR oswrch
    LDA os_vdu_x
    CMP #&21
    BNE dis_print_ascii
    PLX
    PHX
    LDY #&00
.dis_ascii_char
    LDA (zp_src_lo),Y
    AND #&7f
    CMP #' '
    BCS dis_check_del
    LDA #&2e
.dis_check_del
    CMP #&7f
    BNE dis_output_char
    LDA #&ff
.dis_output_char
    JSR oswrch
    INY
    DEX
    BNE dis_ascii_char
    JSR osnewl
    PLA
    CLC
    ADC zp_src_lo
    STA zp_src_lo
    BCC dis_wait_key
    INC zp_src_hi
.dis_wait_key
    JSR osrdch
    BCS dis_save_state
    JMP dis_print_header
.dis_save_state
    LDA zp_src_lo
    STA mem_vdu_1
    LDA zp_src_hi
    STA mem_vdu_2
    LDA #&00
    STA &ff
    RTS
.dis_check_up
    PHY
    LDY #&02
    LDA (zp_src_lo),Y
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.dis_check_down
    PHY
    LDY #&01
    LDA (zp_src_lo),Y
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.dis_check_right
    PHY
    LDY #&01
    CLC
    LDA zp_src_lo
    ADC #&02
    STA &a8
    LDA zp_src_hi
    ADC #&00
    STA &a9
    LDA (zp_src_lo),Y
    BMI dis_advance
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JSR dis_print_hex_word
    LDA &a8
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.dis_advance
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&ff
    STA &a9
    JSR dis_print_hex_word
    LDA &a8
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.print_backspace
    LDA #&08
    FOR n, 1, 5 : JSR oswrch : NEXT
    LDY #&01
    LDA (&a8),Y
    BMI bau_space_rts
    STA dec_value_hi
    LDY #&02
    LDA (&a8),Y
    STA dec_value_lo
    PHX
    PHY
    JSR print_decimal
    PLY
    PLX
.bau_space_rts
    RTS
.msg_now_splitting
    EQUS 13, "Now splitting line:      " : EQUB 0
.msg_now_spacing
    EQUS 13, "Now spacing out line:      " : EQUB 0
