\ alias.asm — Alias system: ALIAS, ALIASES, ALICLR, ALILD, ALISV, STORE, alias init, hex parsing
\
\ Alias table format (stored in private workspace starting at &B165):
\   Each entry: <name>\0 <length-byte> <expansion>\0D
\   Table terminated by &FF sentinel byte.
\   The length byte after the name gives the total entry size from that point,
\   used to walk to the next entry.

\ *ALIAS <name> <expansion> — Define, redefine, or delete an alias.
\ If only a name is given (no expansion), the existing alias is deleted.
\ Walks the alias table looking for an existing entry with the same name;
\ if found, removes it by compacting the table, then appends the new entry.
.cmd_alias
    LDA #&00
    STA alias_semicolon_flag
    JSR parse_cmdline
    CMP #&0d
    BNE alias_table_start
    JMP alias_syntax_error
\ Set pointer to start of alias table and begin scanning
.alias_table_start
    LDA #&65
    STA zp_ptr_lo
    LDA #&b1
    STA zp_ptr_hi
.alias_check_end
    LDA (zp_ptr_lo)
    CMP #&ff
    BEQ alias_exec_setup
    LDY compare_string_y
    PHY
    JSR compare_string
    PLY
    STY compare_string_y
    BCC alias_find_end
\ Match found — delete existing entry by compacting the table over it
    LDA #&ff
    STA alias_semicolon_flag
    LDY #&ff
.alias_skip_name
    INY
    LDA (zp_ptr_lo),Y
    BNE alias_skip_name
    INY
    LDA (zp_ptr_lo),Y
    CLC
    ADC zp_ptr_lo
    STA &aa
    LDA zp_ptr_hi
    ADC #&00
    STA &ab
    LDY #&00
.alias_copy_loop
    LDA (&aa),Y
    STA (zp_ptr_lo),Y
    CMP #&ff
    BNE alias_copy_next
    STA (zp_ptr_lo),Y
    LDA (zp_ptr_lo)
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
\ No match — skip past this entry's name and length to the next entry
.alias_find_end
    LDY #&ff
.alias_find_loop
    INY
    LDA (zp_ptr_lo),Y
    BNE alias_find_loop
    INY
    LDA (zp_ptr_lo),Y
    CLC
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP alias_check_end
\ Reached end of table (or deleted entry) — now append the new alias.
\ First check there's enough room in the table for the new entry.
.alias_exec_setup
    LDA compare_string_y
    STA &70
    LDY compare_string_y
    DEY
.alias_exec_copy
    INY
    LDA (cmd_line_lo),Y
    CMP #&0d
    BNE alias_exec_copy
    TYA
    SEC
    SBC compare_string_y
    CLC
    ADC zp_ptr_lo
    BCC alias_exec_run
    LDA zp_ptr_hi
    CMP #&be
    BCC alias_exec_run
    JSR copy_inline_to_stack    \ BRK error: "No room for alias"
    EQUS &48, "No room for alias", 0
\ Write the new alias entry: uppercase name, null separator, expansion, CR, &FF sentinel
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
    LDA (cmd_line_lo),Y
    CMP #' '
    BEQ alias_terminate
    CMP #&0d
    BNE alias_upper_case
    JMP alias_clear_entry
\ Convert alias name to uppercase (a-z -> A-Z)
.alias_upper_case
    CMP #'a'
    BCC alias_store_char
    CMP #'{'
    BCS alias_store_char
    AND #&df
.alias_store_char
    STA (zp_ptr_lo),Y
    INY
    BNE alias_skip_ws
\ Null-terminate the alias name, then store the expansion text and length
.alias_terminate
    LDA #&00
    STA (zp_ptr_lo),Y
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
    LDA (cmd_line_lo),Y
    CMP #&0d
    BEQ alias_store_arg
    STA (zp_ptr_lo),Y
    INY
    BNE alias_parse_arg
.alias_store_arg
    STA (zp_ptr_lo),Y
    INY
    LDA #&ff
    STA (zp_ptr_lo),Y
    TYA
    LDY compare_string_y
    STA (zp_ptr_lo),Y
    RTS
\ *ALIASES — List all defined aliases in "NAME = expansion" format.
\ Walks the alias table printing each entry until the &FF sentinel.
.cmd_aliases
    LDA #&65
    STA zp_ptr_lo
    LDA #&b1
    STA zp_ptr_hi
.alias_list_check
    LDA (zp_ptr_lo)
    CMP #&ff
    BEQ alias_list_done
    LDY #&ff
.alias_list_name
    INY
    LDA (zp_ptr_lo),Y
    JSR osasci
    CMP #&00
    BNE alias_list_name
    INY
    LDA #' '
    JSR osasci
    LDA #'='
    JSR osasci
    LDA #' '
    JSR osasci
.alias_list_value
    INY
    LDA (zp_ptr_lo),Y
    JSR osasci
    CMP #&0d
    BNE alias_list_value
    INY
    TYA
    CLC
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP alias_list_check
.alias_list_done
    RTS
\ Delete alias — write &FF sentinel at current position to remove the entry.
\ Only valid if an existing alias was found (alias_semicolon_flag set).
.alias_clear_entry
    LDA #&ff
    STA (zp_ptr_lo)
    LDA alias_semicolon_flag
    BEQ alias_syntax_error
    RTS
.alias_syntax_error
    JSR copy_inline_to_stack    \ BRK error: "Syntax : ALIAS <alias name> <alias>"
    EQUS &48, "Syntax : ALIAS <alias name> <alias>", 0
\ check_alias — Called during command dispatch to intercept * commands.
\ Scans the alias table for a match against the current command line.
\ If a match is found, expands the alias (with %0-%9 parameter substitution
\ and %% for literal %) into a buffer, then executes it via OSCLI.
\ If no match, returns to let normal command processing continue.
.check_alias
    LDA #&65
    STA zp_ptr_lo
    LDA #&b1
    STA zp_ptr_hi
.alias_walk_check
    LDA (zp_ptr_lo)
    CMP #&ff
    BEQ alias_cmd_done
    PHY
    JSR compare_string
    BCS alias_exec_entry
    LDY #&ff
.alias_walk_name
    INY
    LDA (zp_ptr_lo),Y
    CMP #&0d
    BNE alias_walk_name
    INY
    CLC
    TYA
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    PLY
    JMP alias_walk_check
\ No alias matched — clean up stack and return to normal command dispatch
.alias_cmd_done
    PLY : PLX : PLA
    RTS
\ Alias matched — expand it with parameter substitution into the execution buffer
.alias_exec_entry
    PLY
    JSR parse_cmdline
    LDY #&ff
.alias_exec_name
    INY
    LDA (zp_ptr_lo),Y
    CMP #&00
    BNE alias_exec_name
    INY
    INY
    STY alias_file_handle
    LDX #&00
.alias_exec_expand
    LDY alias_file_handle
    LDA (zp_ptr_lo),Y
    INY
    STY alias_file_handle
    STA store_buf_3,X
    INX
    CMP #&0d
    BNE alias_check_percent
    JMP alisv_open
\ Check for % substitution markers in the expansion text
.alias_check_percent
    CMP #'%'
    BEQ alias_copy_literal
    JMP alias_exec_expand
\ Handle % escape: %% = literal %, %U = VDU codes, %0-%9 = positional parameter
.alias_copy_literal
    LDA (zp_ptr_lo),Y
    INY
    STY alias_file_handle
    CMP #'%'
    BEQ alias_exec_expand
    DEX
    CMP #&55
    BNE alias_get_param_num
    JMP alisv_write_header
\ %0-%9: Find the Nth space-delimited parameter from the original command line
.alias_get_param_num
    SEC
    SBC #'0'
    PHX
    TAX
    LDY compare_string_y
    CMP #&00
    BEQ alias_copy_param
    DEY
.alias_find_param
    INY
    LDA (cmd_line_lo),Y
    CMP #&0d
    BEQ alias_skip_rest
    CMP #' '
    BNE alias_find_param
    DEX
    BNE alias_find_param
    INY
.alias_copy_param
    PLX
.alias_copy_param_loop
    LDA (cmd_line_lo),Y
    CMP #' '
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
\ Expansion complete — execute the expanded alias command via OSCLI,
\ then use OSBYTE &8A to restore the language ROM paging
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
\ %U substitution — emit VDU 11 (cursor up) and VDU 21 (disable display)
.alisv_write_header
    LDA #&0b
    JSR osasci
    LDA #&15
    JSR osasci
    JMP alias_exec_expand
\ *ALILD <filename> — Load alias definitions from a file into the alias table.
\ Opens the file for reading and copies its entire contents byte-by-byte
\ into the alias table workspace.
.cmd_alild
    JSR parse_cmdline
    CLC
    TYA
    ADC &f2
    TAX
    LDA &f3
    ADC #&00
    TAY
    LDA #'@'
    JSR osfind
    CMP #&00
    BEQ alild_not_found
    STA alias_file_handle
    LDA #&65
    STA zp_ptr_lo
    LDA #&b1
    STA zp_ptr_hi
.alild_read_loop
    LDY alias_file_handle
    JSR osbget
    BCS alild_close
    STA (zp_ptr_lo)
    CLC
    LDA zp_ptr_lo
    ADC #&01
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP alild_read_loop
.alild_close
    LDA #&00
    LDY alias_file_handle
    JMP osfind
.alild_not_found
    JSR copy_inline_to_stack    \ BRK error: "Alias file not found"
    EQUS &D6, "Alias file not found", 0
\ *ALISV <filename> — Save the current alias table to a file.
\ Opens the file for writing and writes alias table bytes until the
\ &FF sentinel is reached, then closes the file.
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
    STA zp_ptr_lo
    LDA #&b1
    STA zp_ptr_hi
.alild_check_end
    LDY alias_file_handle
    LDA (zp_ptr_lo)
    JSR osbput
    CMP #&ff
    BEQ alild_open_error
    CLC
    LDA zp_ptr_lo
    ADC #&01
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP alild_check_end
.alild_open_error
    LDA #&00
    LDY alias_file_handle
    JMP osfind
.alild_cant_open
    JSR copy_inline_to_stack    \ BRK error: "Can't open alias file"
    EQUS &63, "Can't open alias file", 0
\ *ALICLR — Clear all aliases by writing &FF sentinel at the start of the table.
.cmd_aliclr
    LDA #&ff
    STA alias_clear_flag
    RTS
\ *STORE — Save the first 1K of the current sideways ROM slot to a buffer.
\ Selects the shadow copy of the ROM bank (bit 7 of ROMSEL) and copies
\ pages &80-&83 into the store buffers. Sets store_flag to indicate
\ that a ROM image has been saved, so alias_init can restore it later.
.cmd_store
    EQUB &AD, &F4, &00          \ LDA 0x00f4
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
    EQUB &AD, &F4, &00          \ LDA 0x00f4
    AND #&7f
    STA sheila_romsel
    LDA #&ff
    STA store_flag
    RTS
\ alias_init — Called on ROM service reset. If a ROM was previously saved
\ with *STORE (store_flag != 0), restore the first 768 bytes of the
\ sideways ROM slot from the store buffers. This preserves ROM state
\ across soft resets.
.alias_init
    LDA store_flag
    BEQ alias_init_rts
    EQUB &AD, &F4, &00          \ LDA 0x00f4
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
    EQUB &AD, &F4, &00          \ LDA 0x00f4
    AND #&7f
    STA sheila_romsel
.alias_init_rts
    RTS
.store_flag
    EQUB &FF
.alias_file_handle
    EQUB &24
\ parse_hex_digit — Parse a single hex digit (0-9, A-F) from A.
\ Returns the 4-bit value in A with carry clear, or carry set on error.
.parse_hex_digit
    CMP #'0'
    BCC parse_hex_bad
    CMP #'G'
    BCS parse_hex_bad
    SEC
    SBC #'0'
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
\ parse_hex_word — Parse a multi-digit hex string from the command line
\ into a 16-bit value stored at &AE/&AF. Stops at CR or space.
.parse_hex_word
    LDA #&00
    STA &ae
    STA &af
.parse_hex_loop
    LDA (cmd_line_lo),Y
    CMP #&0d
    BEQ mem_rts
    CMP #' '
    BEQ mem_rts
    JSR parse_hex_digit
    BCC parse_hex_shift
    JSR copy_inline_to_stack    \ BRK error: "Invalid hex digit"
    EQUS &EB, "Invalid hex digit", 0
\ Shift existing value left by 4 bits and OR in the new digit
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
