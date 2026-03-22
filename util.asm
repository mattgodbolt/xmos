\ util.asm — Utility routines: print_inline, copy_inline_to_stack, compare_string

.print_inline
    PLA                         \ Pull return address (points to string - 1)
    STA zp_ptr_lo
    PLA
    STA zp_ptr_hi
    LDY #&00
{
.loop
        INY
        LDA (zp_ptr_lo),Y
        JSR osasci
        BNE loop
}
    CLC                         \ Adjust return address past the string
    TYA
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    PHA                         \ Push adjusted return address
    LDA zp_ptr_lo
    PHA
    RTS                         \ "Return" to instruction after the string

\ ============================================================================
\ copy_inline_to_stack — Copy inline string to stack page and execute
\ Used for self-modifying command strings that run from the stack.
\ ============================================================================
.copy_inline_to_stack
    PLA                         \ Pull return address (points to code - 1)
    STA zp_ptr_lo
    PLA
    STA zp_ptr_hi
    LDA #&00
    TAY
    STA &0100,Y                 \ Store null at start of stack page
{
.loop
        INY
        LDA (zp_ptr_lo),Y       \ Copy bytes to stack page
        STA &0100,Y
        BNE loop
}
    JMP &0100                   \ Execute the copied code
\ ============================================================================
\ compare_string — Compare command line against string at (&A8)
\ Entry: (&F2),Y = command line position, (&A8) = string to compare
\ Exit:  C=1 if match, C=0 if no match. Y advanced past the match.
\ Supports abbreviated commands (e.g. "D." matches "DIS")
\ Converts lowercase to uppercase for case-insensitive comparison
\ ============================================================================
.compare_string
    LDX #&00
    LDA &a8                     \ Self-modify the CMP and LDA absolute,X below
    STA cmp_str_addr + 1
    STA lda_str_addr + 1
    LDA zp_ptr_hi
    STA cmp_str_addr + 2
    STA lda_str_addr + 2
{
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
}
    CLC                         \ C=0: no match
    RTS
.compare_string_y
    EQUB &07                    \ Saved Y position after last match
\ ============================================================================
\ *S — Save BASIC program using its incore (embedded) filename
\ Looks for a line like: 10 REM > Filename
\ ============================================================================
