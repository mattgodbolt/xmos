\ bau.asm — BASIC utilities: *BAU (split lines), *SPACE (insert spaces)

\ *BAU — splits multi-statement BASIC lines at colons into separate lines.
\ Walks the BASIC program in memory, finds colons outside strings/REM/DATA,
\ and inserts new line headers at each split point. Skips lines whose first
\ token is "." (assembler directive). After splitting, falls through to *SPACE.
.cmd_bau
    LDA os_mode
    CMP #&0c
    BEQ bau_splitting
    JSR copy_inline_to_stack    \ BRK error: "BAU must be called from BASIC"
    EQUS &5C, "BAU must be called from BASIC", 0
.bau_splitting
    STROUT msg_now_splitting
    LDA &18
    STA zp_ptr_hi
    LDA #&00
    STA zp_ptr_lo
.bau_line_loop
    JSR print_backspace
.bau_check_line
    LDY #&01
    LDA (zp_ptr_lo),Y
    CMP #&ff                    \ end-of-program marker
    BNE bau_get_length
    JMP space_start
.bau_get_length
    LDY #&04
    LDA (zp_ptr_lo),Y
    STA os_rs423_buf
    DEY
    CMP #'.'                    \ "." — assembler directive, skip entire line
    BNE bau_skip_token
\ Assembler-directive line: scan for colon (split point) or space runs
.bau_scan_loop
    INY
    LDA (zp_ptr_lo),Y
    CMP #&0d
    BNE bau_check_colon
    JMP bau_next_line
.bau_check_colon
    CMP #':'
    BEQ bau_split_here
    CMP #' '
    BNE bau_scan_loop
.bau_scan_char
    INY                         \ skip consecutive spaces
    LDA (zp_ptr_lo),Y
    CMP #' '
    BEQ bau_scan_char
    DEY
.bau_split_here
    JMP bau_check_end
\ Non-assembler line: scan for colon to split at, but never split after
\ THEN, DATA, ELSE, or REM (the rest of those lines belongs together).
\ Also skips over quoted strings so colons inside strings are ignored.
.bau_skip_token
    INY
    LDA (zp_ptr_lo),Y
    CMP #':'
    BEQ bau_check_end
    CMP #&0d
    BNE bau_check_then
    JMP bau_next_line
.bau_check_then
    CMP #&e7                    \ THEN — don't split
    BNE bau_check_data
    JMP bau_next_line
.bau_check_data
    CMP #&dc                    \ DATA — don't split
    BNE bau_check_else
    JMP bau_next_line
.bau_check_else
    CMP #&ee                    \ ELSE — don't split
    BNE bau_check_rem
    JMP bau_next_line
.bau_check_rem
    CMP #&f4                    \ REM — don't split
    BNE bau_check_quote
    JMP bau_next_line
.bau_check_quote
    CMP #&22                    \ opening quote — skip string contents
    BNE bau_skip_token
.bau_skip_string
    INY
    LDA (zp_ptr_lo),Y
    CMP #&22                    \ closing quote
    BEQ bau_skip_token
    CMP #&0d
    BNE bau_skip_string
    JMP bau_next_line
\ Perform the split: terminate the current line at offset Y, then shift
\ the remainder of the program up in memory to make room for a new 4-byte
\ BASIC line header (hi-byte, lo-byte of line number 0, and length).
.bau_check_end
    CPY #&04                    \ nothing to split if colon is first char
    BEQ bau_skip_token
    LDA #&0d
    STA (zp_ptr_lo),Y          \ terminate current line at split point
    TYA
    PHA
    SEC
    LDY #&03
    SBC (&a8),Y
    EOR #&ff
    CLC
    ADC #&04
    STA &ae                     \ new line length for the split-off portion
    PLA
    STA (zp_ptr_lo),Y
    CLC
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
\ Shift the program body upward by 3 bytes (room for new line header).
\ Copies from TOP downward to avoid overwriting data.
    LDA &00
    CLC
    ADC #&02
    STA zp_tmp_lo
    LDA &01
    ADC #&00
    STA zp_tmp_hi
    SEC
    LDA &00
    SBC #&01
    STA zp_work_lo
    LDA &01
    SBC #&00
    STA zp_work_hi
.bau_copy_byte
    EQUB &B2, &AA               \ LDA (0xaa)
    EQUB &92, &AC               \ STA (0xac)
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
    CMP &a9
    BNE bau_copy_byte
    LDA zp_work_lo
    CMP &a8
    BNE bau_copy_byte
\ Write the new line header: line number 0, then stored length
    LDA #&00
    LDY #&01
    STA (zp_ptr_lo),Y          \ line number hi = 0
    INY
    STA (zp_ptr_lo),Y          \ line number lo = 0
    LDA &ae
    INY
    STA (zp_ptr_lo),Y          \ line length
    CLC
    LDA &00
    ADC #&03
    STA &00                     \ adjust TOP pointer
    LDA &01
    ADC #&00
    STA &01
    JMP bau_check_line          \ re-scan from this new line
\ Advance pointer to next BASIC line (add line length to pointer)
.bau_next_line
    LDY #&03
    LDA (zp_ptr_lo),Y
    CLC
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP bau_line_loop

\ After BAU finishes, reset BASIC state: issue RENUMBER via *KEY9
.space_start
    JSR osnewl
    LDA #&15                    \ VDU 21 — disable display output
    JSR oswrch
    LDX #' '
    LDY #&9a
    JSR oscli                   \ execute *KEY9 (RENUMBER) to fix line numbers
    LDA #&8a
    LDX #&00
    LDY #&89
    JMP osbyte                  \ insert key press to trigger the function key
.cmd_space_key9
    EQUS "KEY9REN.|F|K|M"       \ *KEY9 definition for renumber
    EQUB &0D

\ *SPACE — inserts spaces after BASIC keyword tokens so they are readable.
\ Walks each line, identifies tokenised keywords, and inserts a space after
\ each one unless already followed by space, CR, or colon. Some keywords
\ (e.g. AND, OR, DIV, EOR, MOD, THEN, ELSE, LINE) get a space before AND
\ after, since they are infix operators or statement separators. Skips over
\ strings, line-number tokens, and REM (which consumes the rest of the line).
\ Also handles "[" brackets by dispatching to the assembler-block formatter.
.cmd_space
    LDA os_mode
    CMP #&0c
    BEQ space_setup
    JSR copy_inline_to_stack    \ BRK error: "Must be called from BASIC!"
    EQUS &5C, "Must be called from BASIC!", 0
.space_setup
    LDA &18
    STA zp_ptr_hi
    STZ &a8
    STROUT msg_now_spacing
.space_line_loop
    JSR print_backspace
    LDY #&01
    LDA (zp_ptr_lo),Y
    CMP #&ff
    BNE space_scan_start
    JMP space_save_top
.space_scan_start
    LDY #&03
.space_scan_loop
    INY
    LDA (zp_ptr_lo),Y
    BMI space_check_token
    CMP #&0d
    BNE space_check_bracket
    JMP space_next_line
.space_check_bracket
    CMP #'['
    BNE space_check_quote
    JMP lvar_display_value
.space_check_quote
    CMP #&22
    BNE space_scan_loop
.space_skip_string
    INY
    LDA (zp_ptr_lo),Y
    CMP #&22
    BEQ space_scan_loop
    CMP #&0d
    BNE space_skip_string
    JMP space_next_line
\ Token classifier: decides which tokens need a space inserted after them.
\ Tokens that are part of expressions or take arguments directly (ELSE as
\ function, AND/OR/EOR/MOD bitwise, LINE, PROC, FN, and various groups)
\ are skipped — they don't need extra spacing.
.space_check_token
    CMP #&8d                    \ pseudo line-number token (3-byte encoding)
    BNE space_check_else
    INY : INY : INY             \ skip 3-byte token
    BNE space_scan_loop
.space_check_else
    CMP #&a7                    \ ELSE (function form) — skip
    BEQ space_scan_loop
    CMP #&c0                    \ AND — skip
    BEQ space_scan_loop
    CMP #&c1                    \ OR — skip
    BEQ space_scan_loop
    CMP #&b0                    \ AND (bitwise) — skip
    BEQ space_scan_loop
    CMP #&c2                    \ EOR — skip
    BEQ space_scan_loop
    CMP #&c4                    \ MOD — skip
    BEQ space_scan_loop
    CMP #&8a                    \ LINE — skip
    BEQ space_scan_loop
    CMP #&f2                    \ PROC — skip
    BEQ space_scan_loop
    CMP #&a4                    \ FN — skip
    BEQ space_scan_loop
    CMP #&cf                    \ tokens &CF-&D3 (SGN..TAN range) — skip
    BCC space_check_range
    CMP #&d4
    BCS space_check_range
    JMP space_scan_loop
.space_check_range
    CMP #&8f                    \ tokens &8F-&93 (COLOUR..SOUND range) — skip
    BCC space_check_next
    CMP #&94
    BCS space_check_next
    JMP space_scan_loop
.space_check_next
    CMP #&b8                    \ TAB — skip if followed by "(" (TAB function)
    BNE space_check_lomem
    INY
    LDA (zp_ptr_lo),Y
    CMP #&50
    BEQ space_scan_loop
    DEY
    LDA #&b8
.space_check_lomem
    CMP #&b3                    \ LEFT$ — skip if followed by "(" (function call)
    BNE space_check_rem
    INY
    LDA (zp_ptr_lo),Y
    CMP #'('
    BNE space_insert_lomem
    JMP space_scan_loop
.space_insert_lomem
    DEY
    LDA #&b3
.space_check_rem
    CMP #&f4                    \ REM — rest of line is comment, skip entirely
    BNE space_insert_space
    JMP space_next_line
\ Insert a space after the current token, unless already followed by
\ space, CR, or colon (in which case no insertion is needed).
.space_insert_space
    INY
    LDA (zp_ptr_lo),Y
    DEY
    CMP #' '
    BNE space_check_cr
    JMP space_scan_loop
.space_check_cr
    CMP #&0d
    BNE space_check_colon
    JMP space_scan_loop
.space_check_colon
    CMP #':'
    BNE space_do_insert
    JMP space_scan_loop
\ Shift program up 1 byte and insert a space after the token
.space_do_insert
    JSR space_shift_up
    PHY
    LDY #&03
    LDA (zp_ptr_lo),Y
    INC A                       \ update line length (+1 for inserted space)
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
    STA (zp_ptr_lo),Y          \ write space byte
    DEY
\ Check if this token is an infix keyword that also needs a space BEFORE it.
\ These are: TAB, AND, DIV, ELSE, EOR, MOD, OR, THEN, LINE
    LDA (zp_ptr_lo),Y
    CMP #&b8                    \ TAB
    BEQ space_insert_byte
    CMP #&80                    \ AND
    BEQ space_insert_byte
    CMP #&81                    \ DIV
    BEQ space_insert_byte
    CMP #&8b                    \ ELSE
    BEQ space_insert_byte
    CMP #&82                    \ EOR
    BEQ space_insert_byte
    CMP #&83                    \ MOD
    BEQ space_insert_byte
    CMP #&84                    \ OR
    BEQ space_insert_byte
    CMP #&8c                    \ THEN
    BEQ space_insert_byte
    CMP #&88                    \ LINE
    BEQ space_insert_byte
    INY
    JMP space_scan_loop
.space_next_line
    LDY #&03
    LDA (zp_ptr_lo),Y
    CLC
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP space_line_loop
\ Save the new TOP pointer (program may have grown) and finish
.space_save_top
    LDA &00
    STA &12
    LDA &01
    STA &13
    JSR osnewl
    RTS

\ Insert a space BEFORE the current infix keyword token (e.g. " AND ")
.space_insert_byte
    DEY
    JSR space_shift_up
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
    INY
    INY
    JMP space_scan_loop
\ Shift all program bytes from the current position to TOP up by one byte.
\ Preserves and restores zp_ptr. Used to make room for an inserted space.
.space_shift_up
    LDA zp_ptr_lo
    PHA
    LDA zp_ptr_hi
    PHA
    TYA
    CLC
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    LDA &00
    STA zp_tmp_lo
    LDA &01
    STA zp_tmp_hi
    SEC
    LDA &00
    SBC #&01
    STA zp_work_lo
    LDA &01
    SBC #&00
    STA zp_work_hi
.space_copy_loop
    EQUB &B2, &AA               \ LDA (0xaa)
    EQUB &92, &AC               \ STA (0xac)
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
    CMP &a9
    BNE space_copy_loop
    LDA zp_work_lo
    CMP &a8
    BNE space_copy_loop
    PLA
    STA zp_ptr_hi
    PLA
    STA zp_ptr_lo
    RTS
