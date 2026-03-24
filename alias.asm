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
{
        LDA #&00 : STA alias_semicolon_flag
        JSR parse_cmdline
        CMP #&0d
        BNE table_start
        JMP alias_syntax_error
\ Set pointer to start of alias table and begin scanning
.table_start
        LDA #LO(alias_clear_flag) : STA zp_ptr_lo
        LDA #HI(alias_clear_flag) : STA zp_ptr_hi
.check_end
        LDA (zp_ptr_lo)
        CMP #&ff
        BEQ exec_setup
        LDY compare_string_y
        PHY
        JSR compare_string
        PLY
        STY compare_string_y
        BCC find_end
\ Match found — delete existing entry by compacting the table over it
        LDA #&ff : STA alias_semicolon_flag
        LDY #&ff
.skip_name
        INY
        LDA (zp_ptr_lo),Y
        BNE skip_name
        INY
        LDA (zp_ptr_lo),Y
        CLC : ADC zp_ptr_lo
        STA zp_work_lo
        LDA zp_ptr_hi
        ADC #&00
        STA zp_work_hi
        LDY #&00
.copy_loop
        LDA (zp_work_lo),Y : STA (zp_ptr_lo),Y
        CMP #&ff
        BNE copy_next
        STA (zp_ptr_lo),Y
        LDA (zp_ptr_lo)
        CMP #&ff
        BNE find_end
        BEQ exec_setup
.copy_next
        INY
        BNE copy_loop
        INC zp_tmp_lo
        INC zp_work_lo
        LDA zp_work_lo
        CMP #&bf
        BCC copy_loop
\ No match — skip past this entry's name and length to the next entry
.find_end
        LDY #&ff
.find_loop
        INY
        LDA (zp_ptr_lo),Y
        BNE find_loop
        INY
        LDA (zp_ptr_lo),Y
        CLC : ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        JMP check_end
\ Reached end of table (or deleted entry) — now append the new alias.
\ First check there's enough room in the table for the new entry.
.exec_setup
        LDA compare_string_y : STA zp_scratch
        LDY compare_string_y
        DEY
.exec_copy
        INY
        LDA (cmd_line_lo),Y
        CMP #&0d
        BNE exec_copy
        TYA
        SEC : SBC compare_string_y
        CLC : ADC zp_ptr_lo
        BCC exec_run
        LDA zp_ptr_hi
        CMP #&be
        BCC exec_run
        JSR copy_inline_to_stack  \ BRK error: "No room for alias"
        EQUS &48, "No room for alias", 0
\ Write the new alias entry: uppercase name, null separator, expansion, CR, &FF sentinel
.exec_run
        CLC
        LDA cmd_line_lo
        ADC compare_string_y
        STA cmd_line_lo
        LDA cmd_line_hi
        ADC #&00
        STA cmd_line_hi
        LDY #&00
.skip_ws
        LDA (cmd_line_lo),Y
        CMP #' '
        BEQ terminate
        CMP #&0d
        BNE upper_case
        JMP alias_clear_entry
\ Convert alias name to uppercase (a-z -> A-Z)
.upper_case
        CMP #'a'
        BCC store_char
        CMP #'{'
        BCS store_char
        AND #&df
.store_char
        STA (zp_ptr_lo),Y
        INY
        BNE skip_ws
\ Null-terminate the alias name, then store the expansion text and length
.terminate
        LDA #&00 : STA (zp_ptr_lo),Y
        INY
        SEC
        LDA cmd_line_lo
        SBC #&01
        STA cmd_line_lo
        LDA cmd_line_hi
        SBC #&00
        STA cmd_line_hi
        STY compare_string_y
        INY
.parse_arg
        LDA (cmd_line_lo),Y
        CMP #&0d
        BEQ store_arg
        STA (zp_ptr_lo),Y
        INY
        BNE parse_arg
.store_arg
        STA (zp_ptr_lo),Y
        INY
        LDA #&ff : STA (zp_ptr_lo),Y
        TYA
        LDY compare_string_y
        STA (zp_ptr_lo),Y
        RTS
}
\ *ALIASES — List all defined aliases in "NAME = expansion" format.
\ Walks the alias table printing each entry until the &FF sentinel.
.cmd_aliases
{
        LDA #LO(alias_clear_flag) : STA zp_ptr_lo
        LDA #HI(alias_clear_flag) : STA zp_ptr_hi
.check
        LDA (zp_ptr_lo)
        CMP #&ff
        BEQ done
        LDY #&ff
.name
        INY
        LDA (zp_ptr_lo),Y
        JSR osasci
        CMP #&00
        BNE name
        INY
        LDA #' '
        JSR osasci
        LDA #'='
        JSR osasci
        LDA #' '
        JSR osasci
.value
        INY
        LDA (zp_ptr_lo),Y
        JSR osasci
        CMP #&0d
        BNE value
        INY
        TYA
        CLC : ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        JMP check
.done
        RTS
}
\ Delete alias — write &FF sentinel at current position to remove the entry.
\ Only valid if an existing alias was found (alias_semicolon_flag set).
.alias_clear_entry
    LDA #&ff : STA (zp_ptr_lo)
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
{
        LDA #LO(alias_clear_flag) : STA zp_ptr_lo
        LDA #HI(alias_clear_flag) : STA zp_ptr_hi
.walk_check
        LDA (zp_ptr_lo)
        CMP #&ff
        BEQ cmd_done
        PHY
        JSR compare_string
        BCS exec_entry
        LDY #&ff
.walk_name
        INY
        LDA (zp_ptr_lo),Y
        CMP #&0d
        BNE walk_name
        INY
        CLC
        TYA
        ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        PLY
        JMP walk_check
\ No alias matched — clean up stack and return to normal command dispatch
.cmd_done
        PLY : PLX : PLA
        RTS
\ Alias matched — expand it with parameter substitution into the execution buffer
.exec_entry
        PLY
        JSR parse_cmdline
        LDY #&ff
.exec_name
        INY
        LDA (zp_ptr_lo),Y
        CMP #&00
        BNE exec_name
        INY
        INY
        STY alias_file_handle
        LDX #&00
.exec_expand
        LDY alias_file_handle
        LDA (zp_ptr_lo),Y
        INY
        STY alias_file_handle
        STA store_buf_3,X
        INX
        CMP #&0d
        BNE check_percent
        JMP open
\ Check for % substitution markers in the expansion text
.check_percent
        CMP #'%'
        BEQ copy_literal
        JMP exec_expand
\ Handle % escape: %% = literal %, %U = VDU codes, %0-%9 = positional parameter
.copy_literal
        LDA (zp_ptr_lo),Y
        INY
        STY alias_file_handle
        CMP #'%'
        BEQ exec_expand
        DEX
        CMP #'U'
        BNE get_param_num
        JMP write_header
\ %0-%9: Find the Nth space-delimited parameter from the original command line
.get_param_num
        SEC : SBC #'0'
        PHX
        TAX
        LDY compare_string_y
        CMP #&00
        BEQ copy_param
        DEY
.find_param
        INY
        LDA (cmd_line_lo),Y
        CMP #&0d
        BEQ skip_rest
        CMP #' '
        BNE find_param
        DEX
        BNE find_param
        INY
.copy_param
        PLX
.copy_param_loop
        LDA (cmd_line_lo),Y
        CMP #' '
        BEQ next_expand
        CMP #&0d
        BEQ next_expand
        BEQ next_expand
        STA store_buf_3,X
        INX
        INY
        BNE copy_param_loop
.next_expand
        JMP exec_expand
.skip_rest
        PLX
        JMP exec_expand
\ Expansion complete — execute the expanded alias command via OSCLI,
\ then use OSBYTE &8A to restore the language ROM paging
.open
        LDX #LO(alias_oscli_buf)
        LDY #HI(alias_oscli_buf)
        JSR oscli
        LDA #&8a
        LDX #&00
        LDY #&89
        JSR osbyte
        PLY : PLX : PLA
        LDA #&00
        RTS
\ %U substitution — emit VDU 11 (cursor up) and VDU 21 (disable display)
.write_header
        LDA #&0b
        JSR osasci
        LDA #&15
        JSR osasci
        JMP exec_expand
}
\ *ALILD <filename> — Load alias definitions from a file into the alias table.
\ Opens the file for reading and copies its entire contents byte-by-byte
\ into the alias table workspace.
.cmd_alild
{
        JSR parse_cmdline
        CLC
        TYA
        ADC cmd_line_lo
        TAX
        LDA cmd_line_hi
        ADC #&00
        TAY
        LDA #'@'
        JSR osfind
        CMP #&00
        BEQ not_found
        STA alias_file_handle
        LDA #LO(alias_clear_flag) : STA zp_ptr_lo
        LDA #HI(alias_clear_flag) : STA zp_ptr_hi
.read_loop
        LDY alias_file_handle
        JSR osbget
        BCS close
        STA (zp_ptr_lo)
        CLC
        LDA zp_ptr_lo
        ADC #&01
        STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        JMP read_loop
.close
        LDA #&00
        LDY alias_file_handle
        JMP osfind
.not_found
        JSR copy_inline_to_stack  \ BRK error: "Alias file not found"
        EQUS &D6, "Alias file not found", 0
}
\ *ALISV <filename> — Save the current alias table to a file.
\ Opens the file for writing and writes alias table bytes until the
\ &FF sentinel is reached, then closes the file.
.cmd_alisv
{
        JSR parse_cmdline
        CLC
        TYA
        ADC cmd_line_lo
        TAX
        LDA cmd_line_hi
        ADC #&00
        TAY
        LDA #&80
        JSR osfind
        CMP #&00
        BEQ cant_open
        STA alias_file_handle
        LDA #LO(alias_clear_flag) : STA zp_ptr_lo
        LDA #HI(alias_clear_flag) : STA zp_ptr_hi
.check_end
        LDY alias_file_handle
        LDA (zp_ptr_lo)
        JSR osbput
        CMP #&ff
        BEQ close
        CLC
        LDA zp_ptr_lo
        ADC #&01
        STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        JMP check_end
.close
        LDA #&00
        LDY alias_file_handle
        JMP osfind
.cant_open
        JSR copy_inline_to_stack  \ BRK error: "Can't open alias file"
        EQUS &63, "Can't open alias file", 0
}
\ *ALICLR — Clear all aliases by writing &FF sentinel at the start of the table.
.cmd_aliclr
{
        LDA #&ff : STA alias_clear_flag
        RTS
}
\ *STORE — Save the first 1K of the current sideways ROM slot to a buffer.
\ Selects the shadow copy of the ROM bank (bit 7 of ROMSEL) and copies
\ pages &80-&83 into the store buffers. Sets store_flag to indicate
\ that a ROM image has been saved, so alias_init can restore it later.
.cmd_store
{
        LDA sheila_romsel
        ORA #&80
        STA sheila_romsel
        LDX #&00
.copy_loop
        LDA &8000,X : STA store_buf_0,X
        LDA &8100,X : STA store_buf_1,X
        LDA &8200,X : STA store_buf_2,X
        LDA &8300,X : STA alias_exec_buf,X
        INX
        BNE copy_loop
        LDA sheila_romsel : AND #&7f : STA sheila_romsel
        LDA #&ff : STA store_flag
        RTS
}
\ alias_init — Called on ROM service reset. If a ROM was previously saved
\ with *STORE (store_flag != 0), restore the first 768 bytes of the
\ sideways ROM slot from the store buffers. This preserves ROM state
\ across soft resets.
.alias_init
{
        LDA store_flag
        BEQ done
        LDA sheila_romsel
        ORA #&80
        STA sheila_romsel
        LDX #&00
.restore_loop
        LDA store_buf_0,X : STA &8000,X
        LDA store_buf_1,X : STA &8100,X
        LDA store_buf_2,X : STA &8200,X
        INX
        BNE restore_loop
        LDA sheila_romsel : AND #&7f : STA sheila_romsel
.done
        RTS
}
.store_flag
    EQUB &FF
.alias_file_handle
    EQUB &24
\ parse_hex_digit — Parse a single hex digit (0-9, A-F) from A.
\ Returns the 4-bit value in A with carry clear, or carry set on error.
.parse_hex_digit
{
        CMP #'0'
        BCC bad
        CMP #'G'
        BCS bad
        SEC : SBC #'0'
        CMP #&0a
        BCC ok
        CMP #&11
        BCC bad
        SEC : SBC #&07
.ok
        CLC
        RTS
.bad
        SEC
        RTS
}
\ parse_hex_word — Parse a multi-digit hex string from the command line
\ into a 16-bit value stored at &AE/&AF. Stops at CR or space.
.parse_hex_word
{
        LDA #&00 : STA zp_src_lo : STA zp_src_hi
.loop
        LDA (cmd_line_lo),Y
        CMP #&0d
        BEQ done
        CMP #' '
        BEQ done
        JSR parse_hex_digit
        BCC shift
        JSR copy_inline_to_stack  \ BRK error: "Invalid hex digit"
        EQUS &EB, "Invalid hex digit", 0
\ Shift existing value left by 4 bits and OR in the new digit
.shift
        ASL zp_src_lo : ROL zp_src_hi
        ASL zp_src_lo : ROL zp_src_hi
        ASL zp_src_lo : ROL zp_src_hi
        ASL zp_src_lo : ROL zp_src_hi
        CLC : ADC zp_src_lo
        STA zp_src_lo
        LDA zp_src_hi
        ADC #&00
        STA zp_src_hi
        INY
        BNE loop
.done
        RTS
}
