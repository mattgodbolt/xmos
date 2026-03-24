\ dis.asm — Disassembler: *DIS command, addressing mode tables
\
\ The disassembler works by looking up each opcode in a 256×4-byte table
\ (stored elsewhere in the ROM). Each entry contains a 3-char mnemonic and
\ an addressing mode index. The mode index selects a printf-style format
\ string from the table below, where placeholder letters are substituted
\ with actual operand bytes:
\   &l  = low byte operand (1-byte)
\   &h  = high byte operand (2nd byte of a 16-bit operand)
\   &b  = branch offset, resolved to an absolute target address
\ All other characters in the format string are printed literally.

.dis_addr_modes
    EQUB &81                    \ Mode 0: ??? (invalid opcode)
    EQUS "???", 0
    EQUS "#&l", 0               \ Mode 1: immediate
    EQUS "&hl", 0               \ Mode 2: absolute
    EQUS "&l", 0                \ Mode 3: zero page
    EQUS "A", 0                 \ Mode 4: accumulator
    EQUS " ", 0                 \ Mode 5: implied
    EQUS "(&l,X)", 0            \ Mode 6: (indirect,X)
    EQUS "(&l),Y", 0            \ Mode 7: (indirect),Y
    EQUS "&l,X", 0              \ Mode 8: zero page,X
    EQUS "&l,Y", 0              \ Mode 9: zero page,Y
    EQUS "&hl,X", 0             \ Mode 10: absolute,X
    EQUS "&hl,Y", 0             \ Mode 11: absolute,Y
    EQUS "&b", 0                \ Mode 12: relative (branch)
    EQUS "(&hl)", 0             \ Mode 13: (indirect)
    EQUS "(&hl,X)", 0           \ Mode 14: (indirect,X) 65C02
    EQUS "(&l)", 0              \ Mode 15: (indirect) 65C02 ZP
\ --- Addressing mode pointer table (16 entries, low/high pairs) ---
.dis_addr_mode_ptrs
    EQUW dis_addr_modes + &00   \ Mode 0: ???
    EQUW dis_addr_modes + &05   \ Mode 1: #&l
    EQUW dis_addr_modes + &09   \ Mode 2: &hl
    EQUW dis_addr_modes + &0D   \ Mode 3: &l
    EQUW dis_addr_modes + &10   \ Mode 4: A
    EQUW dis_addr_modes + &12   \ Mode 5: implied
    EQUW dis_addr_modes + &14   \ Mode 6: (&l,X)
    EQUW dis_addr_modes + &1B   \ Mode 7: (&l),Y
    EQUW dis_addr_modes + &22   \ Mode 8: &l,X
    EQUW dis_addr_modes + &27   \ Mode 9: &l,Y
    EQUW dis_addr_modes + &2C   \ Mode 10: &hl,X
    EQUW dis_addr_modes + &32   \ Mode 11: &hl,Y
    EQUW dis_addr_modes + &38   \ Mode 12: &b
    EQUW dis_addr_modes + &3B   \ Mode 13: (&hl)
    EQUW dis_addr_modes + &41   \ Mode 14: (&hl,X)
    EQUW dis_addr_modes + &49   \ Mode 15: (&l)
\ --- Operand byte counts per addressing mode ---
.dis_operand_sizes
    EQUB 1, 2, 3, 2, 1, 1, 2, 2, 2, 2, 3, 3, 2, 3, 3, 2
\ Entry point for *DIS [address]. If no address given, continues from
\ the last position (saved across invocations in mem_vdu_1/2).
.cmd_dis
{
        JSR parse_cmdline
        CMP #&0d
        BEQ dis_display_line
        JSR parse_hex_word
        BRA dis_print_header
}
.dis_display_line
{
        LDA mem_vdu_1 : STA zp_src_lo
        LDA mem_vdu_2 : STA zp_src_hi
}
\ Print one disassembled line: address, mnemonic, operand, raw bytes, ASCII.
\ The opcode is multiplied by 4 to index into a 1024-byte lookup table that
\ holds {3-char mnemonic, addressing mode index} for each of the 256 opcodes.
.dis_print_header
    LDA #&82
    JSR oswrch
    JSR oswrch
    LDA zp_src_hi
    JSR dis_print_hex_word
    LDA zp_src_lo
    JSR dis_print_hex_word
    LDA #' '
    JSR oswrch
    LDY #&00 : STY zp_tmp_hi
    LDA (zp_src_lo),Y           \ opcode × 4 to get table offset
    ASL A : ROL zp_tmp_hi
    ASL A : ROL zp_tmp_hi
    CLC : ADC #LO(dis_opcode_table) : STA zp_tmp_lo
    LDA zp_tmp_hi
    ADC #HI(dis_opcode_table)
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
    LDA #' '
    JSR oswrch
\ Fetch the addressing mode index from the 4th byte of the opcode table entry,
\ then look up the corresponding format string pointer from dis_addr_mode_ptrs.
.dis_get_mode
    LDY #&03
    LDA (zp_tmp_lo),Y
    PHA
    ASL A
    TAX
    LDA dis_addr_mode_ptrs,X : STA zp_tmp_lo
    LDA dis_addr_mode_ptrs + 1,X : STA zp_tmp_hi
    LDY #&ff
\ Walk the format string character by character. Literal chars are printed
\ directly; 'h' (high byte), 'l' (low byte), and 'b' (branch target)
\ are intercepted and replaced with the actual operand values.
.dis_format_loop
    INY
    LDA (zp_tmp_lo),Y
    BEQ dis_print_addr
    CMP #'h'                    \ 'h' — print high byte of operand
    BNE dis_check_lo
    JMP dis_check_up
.dis_check_lo
    CMP #'l'                    \ 'l' — print low byte of operand
    BNE dis_check_branch
    JMP dis_check_down
.dis_check_branch
    CMP #'b'                    \ 'b' — resolve and print branch target
    BNE dis_print_char
    JMP dis_check_right
.dis_print_char
    JSR oswrch
    BRA dis_format_loop
\ Tab to a fixed column, then print the raw instruction bytes in hex.
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
    LDA #' '
    JSR oswrch
    INY
    DEX
    BNE dis_print_byte
\ Tab further right, then print the raw bytes as printable ASCII
\ (non-printable chars shown as '.')
.dis_print_ascii
    LDA #&85
    JSR oswrch
    LDA os_vdu_x
    CMP #'!'
    BNE dis_print_ascii
    PLX
    PHX
    LDY #&00
.dis_ascii_char
    LDA (zp_src_lo),Y
    AND #&7f
    CMP #' '
    BCS dis_check_del
    LDA #'.'
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
\ Wait for a keypress: any key continues to the next instruction,
\ Escape saves the current position and exits.
.dis_wait_key
{
        JSR osrdch
        BCS save_state
        JMP dis_print_header
\ Save current address so *DIS with no argument can resume here.
.save_state
        LDA zp_src_lo : STA mem_vdu_1
        LDA zp_src_hi : STA mem_vdu_2
        LDA #&00 : STA os_escape_effect
        RTS
}
\ Print the high byte of a two-byte operand (byte at PC+2).
.dis_check_up
    PHY
    LDY #&02
    LDA (zp_src_lo),Y
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
\ Print the low byte of the operand (byte at PC+1).
.dis_check_down
    PHY
    LDY #&01
    LDA (zp_src_lo),Y
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
\ Resolve a relative branch offset to an absolute target address.
\ Computes target = (PC + 2) + signed_offset, handling both forward
\ (positive) and backward (negative) branches.
.dis_check_right
    PHY
    LDY #&01
    CLC
    LDA zp_src_lo
    ADC #&02
    STA zp_ptr_lo
    LDA zp_src_hi
    ADC #&00
    STA zp_ptr_hi
    LDA (zp_src_lo),Y
    BMI dis_advance
    CLC
    ADC &a8
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JSR dis_print_hex_word
    LDA zp_ptr_lo
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
\ Backward branch: offset is negative, so add &FF to the high byte
\ (sign-extend the 8-bit negative offset to 16 bits).
.dis_advance
    CLC
    ADC &a8
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&ff
    STA zp_ptr_hi
    JSR dis_print_hex_word
    LDA zp_ptr_lo
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
\ Print 5 backspaces then overwrite with the current BASIC line number
\ (read from the line header). Used by the line-spacing progress display.
.print_backspace
{
        LDA #&08
        FOR n, 1, 5 : JSR oswrch : NEXT
        LDY #&01
        LDA (&a8),Y
        BMI rts
        STA dec_value_hi
        LDY #&02
        LDA (&a8),Y : STA dec_value_lo
        PHX
        PHY
        JSR print_decimal
        PLY
        PLX
.rts
        RTS
}
.msg_now_splitting
    EQUS 13, "Now splitting line:      " : EQUB 0
.msg_now_spacing
    EQUS 13, "Now spacing out line:      " : EQUB 0
