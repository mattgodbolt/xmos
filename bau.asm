\ bau.asm — BASIC utilities: *BAU (split lines), *SPACE (insert spaces)

.cmd_bau
    LDA os_mode
    CMP #&0c
    BEQ bau_splitting
    JSR copy_inline_to_stack    \ BRK error: "BAU must be called from BASIC"
    EQUS &5C, "BAU must be called from BASIC", 0
.bau_splitting
    STROUT msg_now_splitting
    LDA &18
    STA &a9
    LDA #&00
    STA &a8
.bau_line_loop
    JSR print_backspace
.bau_check_line
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE bau_get_length
    JMP space_start
.bau_get_length
    LDY #&04
    LDA (&a8),Y
    STA os_rs423_buf
    DEY
    CMP #&2e
    BNE bau_skip_token
.bau_scan_loop
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE bau_check_colon
    JMP bau_next_line
.bau_check_colon
    CMP #&3a
    BEQ bau_split_here
    CMP #&20
    BNE bau_scan_loop
.bau_scan_char
    INY
    LDA (&a8),Y
    CMP #&20
    BEQ bau_scan_char
    DEY
.bau_split_here
    JMP bau_check_end
.bau_skip_token
    INY
    LDA (&a8),Y
    CMP #&3a
    BEQ bau_check_end
    CMP #&0d
    BNE bau_check_then
    JMP bau_next_line
.bau_check_then
    CMP #&e7
    BNE bau_check_data
    JMP bau_next_line
.bau_check_data
    CMP #&dc
    BNE bau_check_else
    JMP bau_next_line
.bau_check_else
    CMP #&ee
    BNE bau_check_rem
    JMP bau_next_line
.bau_check_rem
    CMP #&f4
    BNE bau_check_quote
    JMP bau_next_line
.bau_check_quote
    CMP #&22
    BNE bau_skip_token
.bau_skip_string
    INY
    LDA (&a8),Y
    CMP #&22
    BEQ bau_skip_token
    CMP #&0d
    BNE bau_skip_string
    JMP bau_next_line
.bau_check_end
    CPY #&04
    BEQ bau_skip_token
    LDA #&0d
    STA (&a8),Y
    TYA
    PHA
    SEC
    LDY #&03
    SBC (&a8),Y
    EOR #&ff
    CLC
    ADC #&04
    STA &ae
    PLA
    STA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    LDA &00
    CLC
    ADC #&02
    STA &ac
    LDA &01
    ADC #&00
    STA &ad
    SEC
    LDA &00
    SBC #&01
    STA &aa
    LDA &01
    SBC #&00
    STA &ab
.bau_copy_byte
    EQUB &B2, &AA  \ LDA (0xaa)
    EQUB &92, &AC  \ STA (0xac)
    SEC
    LDA &ac
    SBC #&01
    STA &ac
    LDA &ad
    SBC #&00
    STA &ad
    SEC
    LDA &aa
    SBC #&01
    STA &aa
    LDA &ab
    SBC #&00
    STA &ab
    CMP &a9
    BNE bau_copy_byte
    LDA &aa
    CMP &a8
    BNE bau_copy_byte
    LDA #&00
    LDY #&01
    STA (&a8),Y
    INY
    STA (&a8),Y
    LDA &ae
    INY
    STA (&a8),Y
    CLC
    LDA &00
    ADC #&03
    STA &00
    LDA &01
    ADC #&00
    STA &01
    JMP bau_check_line
.bau_next_line
    LDY #&03
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP bau_line_loop
.space_start
    JSR osnewl
    LDA #&15
    JSR oswrch
    LDX #&20
    LDY #&9a
    JSR oscli
    LDA #&8a
    LDX #&00
    LDY #&89
    JMP osbyte
.cmd_space_key9
    EQUS "KEY9REN.|F|K|M"     \ *KEY9 definition for renumber
    EQUB &0D
.cmd_space
    LDA os_mode
    CMP #&0c
    BEQ space_setup
    JSR copy_inline_to_stack    \ BRK error: "Must be called from BASIC!"
    EQUS &5C, "Must be called from BASIC!", 0
.space_setup
    LDA &18
    STA &a9
    STZ &a8
    STROUT msg_now_spacing
.space_line_loop
    JSR print_backspace
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE space_scan_start
    JMP space_save_top
.space_scan_start
    LDY #&03
.space_scan_loop
    INY
    LDA (&a8),Y
    BMI space_check_token
    CMP #&0d
    BNE space_check_bracket
    JMP space_next_line
.space_check_bracket
    CMP #&5b
    BNE space_check_quote
    JMP lvar_display_value
.space_check_quote
    CMP #&22
    BNE space_scan_loop
.space_skip_string
    INY
    LDA (&a8),Y
    CMP #&22
    BEQ space_scan_loop
    CMP #&0d
    BNE space_skip_string
    JMP space_next_line
.space_check_token
    CMP #&8d
    BNE space_check_else
    INY : INY : INY             \ skip 3-byte token
    BNE space_scan_loop
.space_check_else
    CMP #&a7
    BEQ space_scan_loop
    CMP #&c0
    BEQ space_scan_loop
    CMP #&c1
    BEQ space_scan_loop
    CMP #&b0
    BEQ space_scan_loop
    CMP #&c2
    BEQ space_scan_loop
    CMP #&c4
    BEQ space_scan_loop
    CMP #&8a
    BEQ space_scan_loop
    CMP #&f2
    BEQ space_scan_loop
    CMP #&a4
    BEQ space_scan_loop
    CMP #&cf
    BCC space_check_range
    CMP #&d4
    BCS space_check_range
    JMP space_scan_loop
.space_check_range
    CMP #&8f
    BCC space_check_next
    CMP #&94
    BCS space_check_next
    JMP space_scan_loop
.space_check_next
    CMP #&b8
    BNE space_check_lomem
    INY
    LDA (&a8),Y
    CMP #&50
    BEQ space_scan_loop
    DEY
    LDA #&b8
.space_check_lomem
    CMP #&b3
    BNE space_check_rem
    INY
    LDA (&a8),Y
    CMP #&28
    BNE space_insert_lomem
    JMP space_scan_loop
.space_insert_lomem
    DEY
    LDA #&b3
.space_check_rem
    CMP #&f4
    BNE space_insert_space
    JMP space_next_line
.space_insert_space
    INY
    LDA (&a8),Y
    DEY
    CMP #&20
    BNE space_check_cr
    JMP space_scan_loop
.space_check_cr
    CMP #&0d
    BNE space_check_colon
    JMP space_scan_loop
.space_check_colon
    CMP #&3a
    BNE space_do_insert
    JMP space_scan_loop
.space_do_insert
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
    DEY
    LDA (&a8),Y
    CMP #&b8
    BEQ space_insert_byte
    CMP #&80
    BEQ space_insert_byte
    CMP #&81
    BEQ space_insert_byte
    CMP #&8b
    BEQ space_insert_byte
    CMP #&82
    BEQ space_insert_byte
    CMP #&83
    BEQ space_insert_byte
    CMP #&84
    BEQ space_insert_byte
    CMP #&8c
    BEQ space_insert_byte
    CMP #&88
    BEQ space_insert_byte
    INY
    JMP space_scan_loop
.space_next_line
    LDY #&03
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP space_line_loop
.space_save_top
    LDA &00
    STA &12
    LDA &01
    STA &13
    JSR osnewl
    RTS
.space_insert_byte
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
    INY
    INY
    JMP space_scan_loop
.space_shift_up
    LDA &a8
    PHA
    LDA &a9
    PHA
    TYA
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    LDA &00
    STA &ac
    LDA &01
    STA &ad
    SEC
    LDA &00
    SBC #&01
    STA &aa
    LDA &01
    SBC #&00
    STA &ab
.space_copy_loop
    EQUB &B2, &AA  \ LDA (0xaa)
    EQUB &92, &AC  \ STA (0xac)
    SEC
    LDA &ac
    SBC #&01
    STA &ac
    LDA &ad
    SBC #&00
    STA &ad
    SEC
    LDA &aa
    SBC #&01
    STA &aa
    LDA &ab
    SBC #&00
    STA &ab
    CMP &a9
    BNE space_copy_loop
    LDA &aa
    CMP &a8
    BNE space_copy_loop
    PLA
    STA &a9
    PLA
    STA &a8
    RTS
