\ util.asm — Utility routines: print_inline, copy_inline_to_stack, compare_string

\ ============================================================================
\ print_inline — Print a null-terminated string embedded immediately after
\ the JSR. Returns to the instruction following the null terminator.
\ ============================================================================
.print_inline
{
        PLA                     \ Pull return address (points to string - 1)
        STA zp_ptr_lo
        PLA
        STA zp_ptr_hi
        LDY #&00
.loop
        INY
        LDA (zp_ptr_lo),Y
        JSR osasci
        BNE loop
        CLC                     \ Adjust return address past the string
        TYA
        ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi
        ADC #&00
        PHA                     \ Push adjusted return address
        LDA zp_ptr_lo
        PHA
        RTS                     \ "Return" to instruction after the string
}

\ ============================================================================
\ copy_inline_to_stack — Copy inline code/data after the JSR to the stack
\ page (&0100) and jump to it. Used to generate BRK-based error messages,
\ since BRK requires the error block to sit at the current PC.
\ ============================================================================
.copy_inline_to_stack
{
        PLA                     \ Pull return address (points to code - 1)
        STA zp_ptr_lo
        PLA
        STA zp_ptr_hi
        LDA #&00
        TAY
        STA &0100,Y             \ Store null at start of stack page
.loop
        INY
        LDA (zp_ptr_lo),Y : STA &0100,Y  \ Copy bytes to stack page
        BNE loop
        JMP &0100               \ Execute the copied code
}
\ ============================================================================
\ compare_string — Case-insensitive match of the command line against a
\ null-terminated keyword. Supports BBC-style dot abbreviation (e.g. "D."
\ matches "DUMP"). Entry: (&F2),Y points into the command line; (&A8)
\ points to the keyword. Exit: C=1 and Y past the match on success, C=0
\ on failure. compare_string_y holds Y on the most recent successful match.
\ ============================================================================
.compare_string
{
        LDX #&00
        LDA zp_ptr_lo : STA cmp_str_addr + 1 : STA lda_str_addr + 1  \ Self-modify the CMP and LDA absolute,X below
        LDA zp_ptr_hi : STA cmp_str_addr + 2 : STA lda_str_addr + 2
.loop
        LDA (cmd_line_lo),Y     \ Get next character from command line
        CMP #'.'
        BEQ matched
        CMP #'a'                \ Convert lowercase to uppercase
        BCC no_convert
        CMP #'{'
        BCS no_convert
        AND #&df                \ Clear bit 5 = uppercase
.no_convert
.*cmp_str_addr
        CMP &831F,X             \ Compare against string (self-modified address)
        BEQ next_char
.*lda_str_addr
        LDA &831F,X             \ Check if we reached end of keyword (null)
        BNE no_match
        LDA (cmd_line_lo),Y     \ At end of keyword: check command line terminator
        CMP #&0d
        BEQ matched
        CMP #' '
        BNE no_match
.matched
        STY compare_string_y    \ Save Y position after match
        SEC                     \ C=1: match found
        RTS
.next_char
        INX
        INY
        BNE loop
.no_match
        CLC                     \ C=0: no match
        RTS
}
.compare_string_y
    EQUB &07                    \ Saved Y position after last match
\ ============================================================================
\ *S — Save BASIC program using its incore (embedded) filename
\ Looks for a line like: 10 REM > Filename
\ ============================================================================
