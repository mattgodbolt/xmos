\ alias.asm — Alias system: ALIAS, ALIASES, ALICLR, ALILD, ALISV, STORE, alias init, hex parsing

.cmd_alias
    LDA #&00
    STA alias_semicolon_flag
    JSR parse_cmdline
    CMP #&0d
    BNE alias_table_start
    JMP alias_syntax_error
.alias_table_start
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alias_check_end
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ alias_exec_setup
    LDY compare_string_y
    PHY
    JSR compare_string
    PLY
    STY compare_string_y
    BCC alias_find_end
    LDA #&ff
    STA alias_semicolon_flag
    LDY #&ff
.alias_skip_name
    INY
    LDA (&a8),Y
    BNE alias_skip_name
    INY
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &aa
    LDA &a9
    ADC #&00
    STA &ab
    LDY #&00
.alias_copy_loop
    LDA (&aa),Y
    STA (&a8),Y
    CMP #&ff
    BNE alias_copy_next
    STA (&a8),Y
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BNE alias_find_end
    BEQ alias_exec_setup
.alias_copy_next
    INY
    BNE alias_copy_loop
    INC &ac
    INC &aa
    LDA &aa
    CMP #&bf
    BCC alias_copy_loop
.alias_find_end
    LDY #&ff
.alias_find_loop
    INY
    LDA (&a8),Y
    BNE alias_find_loop
    INY
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alias_check_end
.alias_exec_setup
    LDA compare_string_y
    STA &70
    LDY compare_string_y
    DEY
.alias_exec_copy
    INY
    LDA (&f2),Y
    CMP #&0d
    BNE alias_exec_copy
    TYA
    SEC
    SBC compare_string_y
    CLC
    ADC &a8
    BCC alias_exec_run
    LDA &a9
    CMP #&be
    BCC alias_exec_run
    JSR copy_inline_to_stack    \ BRK error: "No room for alias"
    EQUS &48, "No room for alias", 0
.alias_exec_run
    CLC
    LDA &f2
    ADC compare_string_y
    STA &f2
    LDA &f3
    ADC #&00
    STA &f3
    LDY #&00
.alias_skip_ws
    LDA (&f2),Y
    CMP #&20
    BEQ alias_terminate
    CMP #&0d
    BNE alias_upper_case
    JMP alias_clear_entry
.alias_upper_case
    CMP #&61
    BCC alias_store_char
    CMP #&7b
    BCS alias_store_char
    AND #&df
.alias_store_char
    STA (&a8),Y
    INY
    BNE alias_skip_ws
.alias_terminate
    LDA #&00
    STA (&a8),Y
    INY
    SEC
    LDA &f2
    SBC #&01
    STA &f2
    LDA &f3
    SBC #&00
    STA &f3
    STY compare_string_y
    INY
.alias_parse_arg
    LDA (&f2),Y
    CMP #&0d
    BEQ alias_store_arg
    STA (&a8),Y
    INY
    BNE alias_parse_arg
.alias_store_arg
    STA (&a8),Y
    INY
    LDA #&ff
    STA (&a8),Y
    TYA
    LDY compare_string_y
    STA (&a8),Y
    RTS
.cmd_aliases
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alias_list_check
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ alias_list_done
    LDY #&ff
.alias_list_name
    INY
    LDA (&a8),Y
    JSR osasci
    CMP #&00
    BNE alias_list_name
    INY
    LDA #&20
    JSR osasci
    LDA #&3d
    JSR osasci
    LDA #&20
    JSR osasci
.alias_list_value
    INY
    LDA (&a8),Y
    JSR osasci
    CMP #&0d
    BNE alias_list_value
    INY
    TYA
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alias_list_check
.alias_list_done
    RTS
.alias_clear_entry
    LDA #&ff
    EQUB &92, &A8  \ STA (0xa8)
    LDA alias_semicolon_flag
    BEQ alias_syntax_error
    RTS
.alias_syntax_error
    JSR copy_inline_to_stack    \ BRK error: "Syntax : ALIAS <alias name> <alias>"
    EQUS &48, "Syntax : ALIAS <alias name> <alias>", 0
.check_alias
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alias_walk_check
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ alias_cmd_done
    PHY
    JSR compare_string
    BCS alias_exec_entry
    LDY #&ff
.alias_walk_name
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE alias_walk_name
    INY
    CLC
    TYA
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    PLY
    JMP alias_walk_check
.alias_cmd_done
    PLY : PLX : PLA
    RTS
.alias_exec_entry
    PLY
    JSR parse_cmdline
    LDY #&ff
.alias_exec_name
    INY
    LDA (&a8),Y
    CMP #&00
    BNE alias_exec_name
    INY
    INY
    STY alias_file_handle
    LDX #&00
.alias_exec_expand
    LDY alias_file_handle
    LDA (&a8),Y
    INY
    STY alias_file_handle
    STA store_buf_3,X
    INX
    CMP #&0d
    BNE alias_check_percent
    JMP alisv_open
.alias_check_percent
    CMP #&25
    BEQ alias_copy_literal
    JMP alias_exec_expand
.alias_copy_literal
    LDA (&a8),Y
    INY
    STY alias_file_handle
    CMP #&25
    BEQ alias_exec_expand
    DEX
    CMP #&55
    BNE alias_get_param_num
    JMP alisv_write_header
.alias_get_param_num
    SEC
    SBC #&30
    PHX
    TAX
    LDY compare_string_y
    CMP #&00
    BEQ alias_copy_param
    DEY
.alias_find_param
    INY
    LDA (&f2),Y
    CMP #&0d
    BEQ alias_skip_rest
    CMP #&20
    BNE alias_find_param
    DEX
    BNE alias_find_param
    INY
.alias_copy_param
    PLX
.alias_copy_param_loop
    LDA (&f2),Y
    CMP #&20
    BEQ alias_next_expand
    CMP #&0d
    BEQ alias_next_expand
    BEQ alias_next_expand
    STA store_buf_3,X
    INX
    INY
    BNE alias_copy_param_loop
.alias_next_expand
    JMP alias_exec_expand
.alias_skip_rest
    PLX
    JMP alias_exec_expand
.alisv_open
    LDX #&56
    LDY #&a5
    JSR oscli
    LDA #&8a
    LDX #&00
    LDY #&89
    JSR osbyte
    PLY : PLX : PLA
    LDA #&00
    RTS
.alisv_write_header
    LDA #&0b
    JSR osasci
    LDA #&15
    JSR osasci
    JMP alias_exec_expand
.cmd_alild
    JSR parse_cmdline
    CLC
    TYA
    ADC &f2
    TAX
    LDA &f3
    ADC #&00
    TAY
    LDA #&40
    JSR osfind
    CMP #&00
    BEQ alild_not_found
    STA alias_file_handle
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alild_read_loop
    LDY alias_file_handle
    JSR osbget
    BCS alild_close
    EQUB &92, &A8  \ STA (0xa8)
    CLC
    LDA &a8
    ADC #&01
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alild_read_loop
.alild_close
    LDA #&00
    LDY alias_file_handle
    JMP osfind
.alild_not_found
    JSR copy_inline_to_stack    \ BRK error: "Alias file not found"
    EQUS &D6, "Alias file not found", 0
.cmd_alisv
    JSR parse_cmdline
    CLC
    TYA
    ADC &f2
    TAX
    LDA &f3
    ADC #&00
    TAY
    LDA #&80
    JSR osfind
    CMP #&00
    BEQ alild_cant_open
    STA alias_file_handle
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alild_check_end
    LDY alias_file_handle
    EQUB &B2, &A8  \ LDA (0xa8)
    JSR osbput
    CMP #&ff
    BEQ alild_open_error
    CLC
    LDA &a8
    ADC #&01
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alild_check_end
.alild_open_error
    LDA #&00
    LDY alias_file_handle
    JMP osfind
.alild_cant_open
    JSR copy_inline_to_stack    \ BRK error: "Can't open alias file"
    EQUS &63, "Can't open alias file", 0
.cmd_aliclr
    LDA #&ff
    STA alias_clear_flag
    RTS
.cmd_store
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    ORA #&80
    STA sheila_romsel
    LDX #&00
.store_copy_rom
    LDA &8000,X
    STA store_buf_0,X
    LDA &8100,X
    STA store_buf_1,X
    LDA &8200,X
    STA store_buf_2,X
    LDA &8300,X
    STA alias_exec_buf,X
    INX
    BNE store_copy_rom
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    AND #&7f
    STA sheila_romsel
    LDA #&ff
    STA store_flag
    RTS
.alias_init
    LDA store_flag
    BEQ alias_init_rts
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    ORA #&80
    STA sheila_romsel
    LDX #&00
.store_restore_rom
    LDA store_buf_0,X
    STA &8000,X
    LDA store_buf_1,X
    STA &8100,X
    LDA store_buf_2,X
    STA &8200,X
    INX
    BNE store_restore_rom
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    AND #&7f
    STA sheila_romsel
.alias_init_rts
    RTS
.store_flag
    EQUB &FF
.alias_file_handle
    EQUB &24
.parse_hex_digit
    CMP #&30
    BCC parse_hex_bad
    CMP #&47
    BCS parse_hex_bad
    SEC
    SBC #&30
    CMP #&0a
    BCC parse_hex_ok
    CMP #&11
    BCC parse_hex_bad
    SEC
    SBC #&07
.parse_hex_ok
    CLC
    RTS
.parse_hex_bad
    SEC
    RTS
.parse_hex_word
    LDA #&00
    STA &ae
    STA &af
.parse_hex_loop
    LDA (&f2),Y
    CMP #&0d
    BEQ mem_rts
    CMP #&20
    BEQ mem_rts
    JSR parse_hex_digit
    BCC parse_hex_shift
    JSR copy_inline_to_stack    \ BRK error: "Invalid hex digit"
    EQUS &EB, "Invalid hex digit", 0
.parse_hex_shift
    ASL &ae
    ROL &af
    ASL &ae
    ROL &af
    ASL &ae
    ROL &af
    ASL &ae
    ROL &af
    CLC
    ADC &ae
    STA &ae
    LDA &af
    ADC #&00
    STA &af
    INY
    BNE parse_hex_loop
.mem_rts
    RTS
