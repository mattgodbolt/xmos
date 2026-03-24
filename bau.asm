\ bau.asm — BASIC utilities: *BAU (split lines), *SPACE (insert spaces)

\ *BAU — splits multi-statement BASIC lines at colons into separate lines.
\ Walks the BASIC program in memory, finds colons outside strings/REM/DATA,
\ and inserts new line headers at each split point. Skips lines whose first
\ token is "." (assembler directive). After splitting, falls through to *SPACE.
.cmd_bau
{
        LDA saved_language_rom
        CMP #&0c
        BEQ splitting
        JSR copy_inline_to_stack  \ BRK error: "BAU must be called from BASIC"
        EQUS &5C, "BAU must be called from BASIC", 0
.splitting
        STROUT msg_now_splitting
        LDA basic_page_hi : STA zp_ptr_hi
        LDA #&00 : STA zp_ptr_lo
.line_loop
        JSR print_backspace
.check_line
        LDY #&01
        LDA (zp_ptr_lo),Y
        CMP #&ff                \ end-of-program marker
        BNE get_length
        JMP start_space
.get_length
        LDY #&04
        LDA (zp_ptr_lo),Y : STA os_rs423_buf
        DEY
        CMP #'.'                \ "." — assembler directive, skip entire line
        BNE skip_token
\ Assembler-directive line: scan for colon (split point) or space runs
.scan_loop
        INY
        LDA (zp_ptr_lo),Y
        CMP #&0d
        BNE check_colon
        JMP next_line
.check_colon
        CMP #':'
        BEQ split_here
        CMP #' '
        BNE scan_loop
.scan_char
        INY                     \ skip consecutive spaces
        LDA (zp_ptr_lo),Y
        CMP #' '
        BEQ scan_char
        DEY
.split_here
        JMP check_end
\ Non-assembler line: scan for colon to split at, but never split after
\ THEN, DATA, ELSE, or REM (the rest of those lines belongs together).
\ Also skips over quoted strings so colons inside strings are ignored.
.skip_token
        INY
        LDA (zp_ptr_lo),Y
        CMP #':'
        BEQ check_end
        CMP #&0d
        BNE check_then
        JMP next_line
.check_then
        CMP #&e7                \ THEN — don't split
        BNE check_data
        JMP next_line
.check_data
        CMP #&dc                \ DATA — don't split
        BNE check_else
        JMP next_line
.check_else
        CMP #&ee                \ ELSE — don't split
        BNE check_rem
        JMP next_line
.check_rem
        CMP #&f4                \ REM — don't split
        BNE check_quote
        JMP next_line
.check_quote
        CMP #'"'                \ opening quote — skip string contents
        BNE skip_token
.skip_string
        INY
        LDA (zp_ptr_lo),Y
        CMP #'"'                \ closing quote
        BEQ skip_token
        CMP #&0d
        BNE skip_string
        JMP next_line
\ Perform the split: terminate the current line at offset Y, then shift
\ the remainder of the program up in memory to make room for a new 4-byte
\ BASIC line header (hi-byte, lo-byte of line number 0, and length).
.check_end
        CPY #&04                \ nothing to split if colon is first char
        BEQ skip_token
        LDA #&0d : STA (zp_ptr_lo),Y  \ terminate current line at split point
        TYA
        PHA
        SEC
        LDY #&03
        SBC (&a8),Y
        EOR #&ff
        CLC
        ADC #&04
        STA zp_src_lo           \ new line length for the split-off portion
        PLA
        STA (zp_ptr_lo),Y
        CLC
        ADC zp_ptr_lo : STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
\ Shift the program body upward by 3 bytes (room for new line header).
\ Copies from TOP downward to avoid overwriting data.
        LDA basic_lomem_lo : CLC : ADC #&02 : STA zp_tmp_lo
        LDA basic_lomem_hi : ADC #&00 : STA zp_tmp_hi
        SEC
        LDA basic_lomem_lo : SBC #&01 : STA zp_work_lo
        LDA basic_lomem_hi : SBC #&00 : STA zp_work_hi
.copy_byte
        LDA (zp_work_lo) : STA (zp_tmp_lo)
        SEC
        LDA zp_tmp_lo : SBC #&01 : STA zp_tmp_lo
        LDA zp_tmp_hi : SBC #&00 : STA zp_tmp_hi
        SEC
        LDA zp_work_lo : SBC #&01 : STA zp_work_lo
        LDA zp_work_hi : SBC #&00 : STA zp_work_hi
        CMP zp_ptr_hi
        BNE copy_byte
        LDA zp_work_lo
        CMP zp_ptr_lo
        BNE copy_byte
\ Write the new line header: line number 0, then stored length
        LDA #&00
        LDY #&01
        STA (zp_ptr_lo),Y       \ line number hi = 0
        INY
        STA (zp_ptr_lo),Y       \ line number lo = 0
        LDA zp_src_lo
        INY
        STA (zp_ptr_lo),Y       \ line length
        CLC
        LDA basic_lomem_lo : ADC #&03 : STA basic_lomem_lo
        LDA basic_lomem_hi : ADC #&00 : STA basic_lomem_hi
        JMP check_line          \ re-scan from this new line
\ Advance pointer to next BASIC line (add line length to pointer)
.next_line
        LDY #&03
        LDA (zp_ptr_lo),Y
        CLC
        ADC zp_ptr_lo : STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        JMP line_loop

\ After BAU finishes, reset BASIC state: issue RENUMBER via *KEY9
.start_space
        JSR osnewl
        LDA #&15                \ VDU 21 — disable display output
        JSR oswrch
        LDX #' '
        LDY #&9a
        JSR oscli               \ execute *KEY9 (RENUMBER) to fix line numbers
        LDA #&8a
        LDX #&00
        LDY #&89
        JMP osbyte              \ insert key press to trigger the function key
.key9_def
        EQUS "KEY9REN.|F|K|M"   \ *KEY9 definition for renumber
        EQUB &0D
}

\ *SPACE — inserts spaces after BASIC keyword tokens so they are readable.
\ Walks each line, identifies tokenised keywords, and inserts a space after
\ each one unless already followed by space, CR, or colon. Some keywords
\ (e.g. AND, OR, DIV, EOR, MOD, THEN, ELSE, LINE) get a space before AND
\ after, since they are infix operators or statement separators. Skips over
\ strings, line-number tokens, and REM (which consumes the rest of the line).
\ Also handles "[" brackets by dispatching to the assembler-block formatter.
.cmd_space
{
        LDA saved_language_rom
        CMP #&0c
        BEQ setup
        JSR copy_inline_to_stack  \ BRK error: "Must be called from BASIC!"
        EQUS &5C, "Must be called from BASIC!", 0
.setup
        LDA basic_page_hi : STA zp_ptr_hi
        STZ zp_ptr_lo
        STROUT msg_now_spacing
}
.space_line_loop
{
        JSR print_backspace
        LDY #&01
        LDA (zp_ptr_lo),Y
        CMP #&ff
        BNE scan_start
        JMP space_save_top
.scan_start
        LDY #&03
}
.space_scan_loop
{
        INY
        LDA (zp_ptr_lo),Y
        BMI check_token
        CMP #&0d
        BNE check_bracket
        JMP next_line
.check_bracket
        CMP #'['
        BNE check_quote
        JMP lvar_display_value
.check_quote
        CMP #'"'
        BNE space_scan_loop
.skip_string
        INY
        LDA (zp_ptr_lo),Y
        CMP #'"'
        BEQ space_scan_loop
        CMP #&0d
        BNE skip_string
        JMP next_line
\ Token classifier: decides which tokens need a space inserted after them.
\ Tokens that are part of expressions or take arguments directly (ELSE as
\ function, AND/OR/EOR/MOD bitwise, LINE, PROC, FN, and various groups)
\ are skipped — they don't need extra spacing.
.check_token
        CMP #&8d                \ pseudo line-number token (3-byte encoding)
        BNE check_else
        INY : INY : INY         \ skip 3-byte token
        BNE space_scan_loop
.check_else
        CMP #&a7                \ ELSE (function form) — skip
        BEQ space_scan_loop
        CMP #&c0                \ AND — skip
        BEQ space_scan_loop
        CMP #&c1                \ OR — skip
        BEQ space_scan_loop
        CMP #&b0                \ AND (bitwise) — skip
        BEQ space_scan_loop
        CMP #&c2                \ EOR — skip
        BEQ space_scan_loop
        CMP #&c4                \ MOD — skip
        BEQ space_scan_loop
        CMP #&8a                \ LINE — skip
        BEQ space_scan_loop
        CMP #cmd_line_lo        \ PROC — skip
        BEQ space_scan_loop
        CMP #&a4                \ FN — skip
        BEQ space_scan_loop
        CMP #&cf                \ tokens &CF-&D3 (SGN..TAN range) — skip
        BCC check_range
        CMP #&d4
        BCS check_range
        JMP space_scan_loop
.check_range
        CMP #&8f                \ tokens &8F-&93 (COLOUR..SOUND range) — skip
        BCC check_next
        CMP #&94
        BCS check_next
        JMP space_scan_loop
.check_next
        CMP #&b8                \ TAB — skip if followed by "(" (TAB function)
        BNE check_lomem
        INY
        LDA (zp_ptr_lo),Y
        CMP #&50
        BEQ space_scan_loop
        DEY
        LDA #&b8
.check_lomem
        CMP #&b3                \ LEFT$ — skip if followed by "(" (function call)
        BNE check_rem
        INY
        LDA (zp_ptr_lo),Y
        CMP #'('
        BNE insert_lomem
        JMP space_scan_loop
.insert_lomem
        DEY
        LDA #&b3
.check_rem
        CMP #&f4                \ REM — rest of line is comment, skip entirely
        BNE insert_space
        JMP next_line
\ Insert a space after the current token, unless already followed by
\ space, CR, or colon (in which case no insertion is needed).
.insert_space
        INY
        LDA (zp_ptr_lo),Y
        DEY
        CMP #' '
        BNE check_cr
        JMP space_scan_loop
.check_cr
        CMP #&0d
        BNE check_colon
        JMP space_scan_loop
.check_colon
        CMP #':'
        BNE do_insert
        JMP space_scan_loop
\ Shift program up 1 byte and insert a space after the token
.do_insert
        JSR space_shift_up
        PHY
        LDY #&03
        LDA (zp_ptr_lo),Y
        INC A                   \ update line length (+1 for inserted space)
        STA (zp_ptr_lo),Y
        PLY
        CLC
        LDA basic_lomem_lo : ADC #&01 : STA basic_lomem_lo
        LDA basic_lomem_hi : ADC #&00 : STA basic_lomem_hi
        LDA #' '
        INY
        STA (zp_ptr_lo),Y       \ write space byte
        DEY
\ Check if this token is an infix keyword that also needs a space BEFORE it.
\ These are: TAB, AND, DIV, ELSE, EOR, MOD, OR, THEN, LINE
        LDA (zp_ptr_lo),Y
        CMP #&b8                \ TAB
        BEQ space_insert_byte
        CMP #&80                \ AND
        BEQ space_insert_byte
        CMP #&81                \ DIV
        BEQ space_insert_byte
        CMP #&8b                \ ELSE
        BEQ space_insert_byte
        CMP #&82                \ EOR
        BEQ space_insert_byte
        CMP #&83                \ MOD
        BEQ space_insert_byte
        CMP #&84                \ OR
        BEQ space_insert_byte
        CMP #&8c                \ THEN
        BEQ space_insert_byte
        CMP #&88                \ LINE
        BEQ space_insert_byte
        INY
        JMP space_scan_loop
.next_line
        LDY #&03
        LDA (zp_ptr_lo),Y
        CLC
        ADC zp_ptr_lo : STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        JMP space_line_loop
}
\ Save the new TOP pointer (program may have grown) and finish
.space_save_top
    LDA basic_lomem_lo : STA basic_top_lo
    LDA basic_lomem_hi : STA basic_top_hi
    JSR osnewl
    RTS

\ Insert a space BEFORE the current infix keyword token (e.g. " AND ")
.space_insert_byte
{
        DEY
        JSR space_shift_up
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
        INY
        INY
        JMP space_scan_loop
}
\ Shift all program bytes from the current position to TOP up by one byte.
\ Preserves and restores zp_ptr. Used to make room for an inserted space.
.space_shift_up
{
        LDA zp_ptr_lo
        PHA
        LDA zp_ptr_hi
        PHA
        TYA
        CLC
        ADC zp_ptr_lo : STA zp_ptr_lo
        LDA zp_ptr_hi : ADC #&00 : STA zp_ptr_hi
        LDA basic_lomem_lo : STA zp_tmp_lo
        LDA basic_lomem_hi : STA zp_tmp_hi
        SEC
        LDA basic_lomem_lo
        SBC #&01
        STA zp_work_lo
        LDA basic_lomem_hi
        SBC #&00
        STA zp_work_hi
.copy_loop
        LDA (zp_work_lo) : STA (zp_tmp_lo)
        SEC
        LDA zp_tmp_lo
        SBC #&01
        STA zp_tmp_lo
        LDA zp_tmp_hi
        SBC #&00
        STA zp_tmp_hi
        SEC
        LDA zp_work_lo
        SBC #&01
        STA zp_work_lo
        LDA zp_work_hi
        SBC #&00
        STA zp_work_hi
        CMP zp_ptr_hi
        BNE copy_loop
        LDA zp_work_lo
        CMP zp_ptr_lo
        BNE copy_loop
        PLA
        STA zp_ptr_hi
        PLA
        STA zp_ptr_lo
        RTS
}
