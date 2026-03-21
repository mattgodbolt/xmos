\ basic.asm — BASIC commands: *S, *L (save and mode setup)

.cmd_s
{
    LDY #&00
.copy_template                  \ Copy OSFILE parameter block template
    LDA osfile_template,Y
    STA osfile_block,Y
    INY
    CPY #&12
    BNE copy_template
}
    JSR find_incore_name        \ Find and validate the incore filename
    LDA &b2                     \ Save BASIC string pointer
    PHA
    LDA &b3
    PHA
    LDA &18                     \ PAGE = start of BASIC program
    STA osfile_block + 3        \ Load address high byte
    STA osfile_block + 11       \ Start address high byte
    LDA &12                     \ TOP low byte
    STA osfile_block + 14       \ End address low byte
    LDA &13                     \ TOP high byte
    STA osfile_block + 15       \ End address high byte
    LDA #&00                    \ OSFILE A=0: save file
    LDX #LO(osfile_block)
    LDY #HI(osfile_block)
    JSR osfile
    STROUT saved_msg
    PLA                         \ Restore BASIC string pointer
    STA &b3
    PLA
    STA &b2
{
    LDY #&FF                    \ Skip leading spaces in filename
.skip_spaces
    INY
    LDA (&b2),Y
    CMP #&20
    BEQ skip_spaces
.print_name                     \ Print the filename
    LDA (&b2),Y
    CMP #&20
    BEQ name_done
    CMP #&0D
    BEQ name_done
    JSR osasci
    INY
    BNE print_name
.name_done
}
    STROUT saved_msg_end         \ Print closing quote + newline
    RTS

\ --- OSFILE parameter block (18 bytes, copied from template then modified) ---
.osfile_block
    EQUB &07, &30              \ +0: Filename pointer (overwritten)
    EQUB &00, &30              \ +2: Load address low/high (high overwritten with PAGE)
    EQUB &FF, &FF              \ +4: Load address top word (&FFFF = host)
    EQUB &2B, &80              \ +6: Exec address low/high
    EQUB &FF, &FF              \ +8: Exec address top word (&FFFF = host)
    EQUB &AC, &05              \ +10: Start address (overwritten)
    EQUB &00, &00              \ +12: Start address top
    EQUB &00, &00              \ +14: End address (overwritten with TOP)
    EQUB &00, &00              \ +16: End address top
.osfile_template                \ Template copied into osfile_block on each call
    EQUB &00, &00, &00, &00   \ Filename/load addr (zeroed)
    EQUB &FF, &FF, &2B, &80   \ Load addr top + exec addr
    EQUB &FF, &FF, &00, &00   \ Exec addr top + start addr
    EQUB &FF, &FF, &00, &00   \ Start addr top + end addr
    EQUB &FF, &FF              \ End addr top

\ ============================================================================
\ find_incore_name — Validate BASIC program and find "> filename" in first line
\ Sets &B2/&B3 to point at the filename
\ ============================================================================
.find_incore_name
    LDA &18                     \ PAGE high byte
    STA &b3
    LDA #&01                   \ Check byte at PAGE+1 (program present?)
    STA &b2
    LDY #&00
    LDA (&b2),Y
    CMP #&FF                   \ &FF = no program
    BEQ error_no_basic
    LDA &18                     \ Point to PAGE+0
    STA &b3
    LDA #&00
    STA &b2
    LDY #&03                   \ Offset 3 = line length in first line
    LDA (&b2),Y
    TAY                         \ Y = end of first line
    LDA (&b2),Y
    CMP #&0D                   \ Should end with CR
    BNE error_bad_program
    LDY #&03                   \ Search first line for '>' marker
{
.skip_spaces
    INY
    LDA (&b2),Y
    CMP #&20
    BEQ skip_spaces
}
    LDA (&b2),Y
    CMP #&F4                   \ &F4 = REM token (look for REM > filename)
    BNE error_no_incore_name
{
.find_marker                    \ Find '>' character
    INY
    LDA (&b2),Y
    CMP #&3E                   \ '>'
    BEQ set_filename_and_return
    CMP #&0D                   \ End of line without finding '>'
    BEQ error_no_incore_name
    BNE find_marker
}
.error_no_incore_name
    JSR copy_inline_to_stack    \ BRK error: "No incore filename"
    EQUS &43, "No incore filename", 0
.error_no_basic
    JSR copy_inline_to_stack    \ BRK error: "No BASIC program"
    EQUS &44, "No BASIC program", 0
.error_bad_program
    JSR copy_inline_to_stack    \ BRK error: "Bad program"
    EQUS &01, "Bad program", 0
.set_filename_and_return
    INY                         \ Skip past '>'
    STY osfile_block            \ Set filename offset in parameter block
    STY &b2
    LDA &b3
    STA osfile_block + 1        \ Set filename pointer high byte
    RTS

.saved_msg
    EQUB &0D
    EQUS "Program saved as '"
    EQUB 0
.saved_msg_end
    EQUS "'"
    EQUB &0D, 0

\ ============================================================================
\ *L — Select MODE 128 and set up key definitions
\ ============================================================================
.cmd_l
    LDX #LO(cmd_l_oscli)
    LDY #HI(cmd_l_oscli)
    JSR oscli                   \ Execute the *KEY command string
    LDA #&8A                   \ OSBYTE &8A: read/write ROM pointer table
    LDY #&80
    LDX #&00
    JMP osbyte
.cmd_l_oscli
    EQUS "KEY0|UL.O1|MO.|MMO.128|M|S07000|S70000|W|@|J@|@|@|@|@|@|@", 13

\ ============================================================================
\ Key remapping interceptor — hooked into KEYV
\ Called when a key event occurs. Remaps certain key codes.
\ Self-modifying: JMP &FFFF targets are patched to the original KEYV address.
\ ============================================================================
