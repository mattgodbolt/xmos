\ basic.asm — BASIC commands: *S, *L (save and mode setup)

\ ============================================================================
\ cmd_s — *S command: save the current BASIC program to disc using the
\ filename embedded in the first line (e.g. 10 REM > Filename). Copies a
\ template into the OSFILE parameter block, fills in PAGE/TOP addresses,
\ calls OSFILE &00 (save), then prints a confirmation with the filename.
\ ============================================================================
.cmd_s
{
        LDY #&00
.copy_template                  \ Copy OSFILE parameter block template
        LDA osfile_template,Y : STA osfile_block,Y
        INY
        CPY #&12
        BNE copy_template
        JSR find_incore_name    \ Find and validate the incore filename
        LDA basic_str_lo        \ Save BASIC string pointer
        PHA
        LDA basic_str_hi
        PHA
        LDA basic_page_hi : STA osfile_block + 3 : STA osfile_block + 11  \ Start address high byte
        LDA basic_top_lo : STA osfile_block + 14  \ End address low byte
        LDA basic_top_hi : STA osfile_block + 15  \ End address high byte
        LDA #&00                \ OSFILE A=0: save file
        LDX #LO(osfile_block)
        LDY #HI(osfile_block)
        JSR osfile
        STROUT saved_msg
        PLA                     \ Restore BASIC string pointer
        STA basic_str_hi
        PLA
        STA basic_str_lo
        LDY #&FF                \ Skip leading spaces in filename
.skip_spaces
        INY
        LDA (basic_str_lo),Y
        CMP #' '
        BEQ skip_spaces
.print_name                     \ Print the filename
        LDA (basic_str_lo),Y
        CMP #' '
        BEQ name_done
        CMP #&0D
        BEQ name_done
        JSR osasci
        INY
        BNE print_name
.name_done
        STROUT saved_msg_end    \ Print closing quote + newline
        RTS
}

\ --- OSFILE parameter block (18 bytes). Layout per the MOS specification:
\ +0,1: filename pointer  +2-5: load address  +6-9: exec address
\ +10-13: start address   +14-17: end address
\ High words &FFFF select the I/O processor (host) address space.
\ Copied from osfile_template at the start of cmd_s, then patched with
\ the incore filename pointer, PAGE (load/start), and TOP (end).
\ ---
.osfile_block
    EQUB &07, &30               \ +0: Filename pointer (overwritten)
    EQUB &00, &30               \ +2: Load address low/high (high overwritten with PAGE)
    EQUB &ff, &ff               \ +4: Load address top word (&FFFF = host)
    EQUB &2B, &80               \ +6: Exec address low/high
    EQUB &ff, &ff               \ +8: Exec address top word (&FFFF = host)
    EQUB &AC, &05               \ +10: Start address (overwritten)
    EQUB &00, &00               \ +12: Start address top
    EQUB &00, &00               \ +14: End address (overwritten with TOP)
    EQUB &00, &00               \ +16: End address top
.osfile_template                \ Template copied into osfile_block on each call
    EQUB &00, &00, &00, &00     \ Filename/load addr (zeroed)
    EQUB &ff, &ff, &2B, &80     \ Load addr top + exec addr
    EQUB &ff, &ff, &00, &00     \ Exec addr top + start addr
    EQUB &ff, &ff, &00, &00     \ Start addr top + end addr
    EQUB &ff, &ff               \ End addr top

\ ============================================================================
\ find_incore_name — Locate the embedded filename in the BASIC program.
\ Validates that a program exists (byte at PAGE+1 != &FF), checks the first
\ line is well-formed (terminated by &0D), then scans for a REM token (&F4)
\ followed by '>'. On success, sets the OSFILE filename pointer and
\ basic_str_lo/hi to the character after '>'. Raises an error if no program
\ is loaded, the first line is corrupt, or no "> name" marker is found.
\ ============================================================================
.find_incore_name
{
        LDA basic_page_hi : STA basic_str_hi
        LDA #&01 : STA basic_str_lo  \ Check byte at PAGE+1 (program present?)
        LDY #&00
        LDA (basic_str_lo),Y
        CMP #&ff
        BEQ error_no_basic
        LDA basic_page_hi : STA basic_str_hi
        LDA #&00 : STA basic_str_lo  \ Point to PAGE+0
        LDY #&03                \ Offset 3 = line length in first line
        LDA (basic_str_lo),Y
        TAY                     \ Y = end of first line
        LDA (basic_str_lo),Y
        CMP #&0d
        BNE error_bad_program
        LDY #&03                \ Search first line for '>' marker
.skip_spaces
        INY
        LDA (basic_str_lo),Y
        CMP #' '
        BEQ skip_spaces
        LDA (basic_str_lo),Y
        CMP #&f4                \ REM token
        BNE error_no_incore_name
.find_marker                    \ Find '>' character
        INY
        LDA (basic_str_lo),Y
        CMP #'>'
        BEQ set_filename_and_return
        CMP #&0d
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
    STY basic_str_lo
    LDA basic_str_hi : STA osfile_block + 1  \ Set filename pointer high byte
    RTS

.saved_msg
    EQUS 13, "Program saved as '", 0
.saved_msg_end
    EQUS "'", 13, 0

\ ============================================================================
\ cmd_l — *L command: configure the editing environment by programming
\ function key 0 with a sequence of commands (shadow MODE 128, colours,
\ etc.) via *KEY, then calls OSBYTE &8A to select the language ROM.
\ ============================================================================
.cmd_l
    LDX #LO(cmd_l_oscli)
    LDY #HI(cmd_l_oscli)
    JSR oscli                   \ Execute the *KEY command string
    LDA #&8A                    \ OSBYTE &8A: read/write ROM pointer table
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
