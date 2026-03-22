\ ============================================================================
\ XMOS — MOS Extension ROM
\ By Richard Talbot-Watkins and Matt Godbolt, 1992
\ Reverse engineered disassembly
\ ============================================================================

CPU 1  \ 65C02

INCLUDE "constants.asm"
INCLUDE "macros.asm"

ORG &8000
GUARD &C000

\ ============================================================================
\ ROM Header
\ ============================================================================
    BRK : BRK : BRK             \ No language entry
    JMP service_entry           \ Service entry point
    EQUB romtype_service OR romtype_6502
    EQUB LO(copyright_ptr - &8000) \ Copyright offset from ROM start
.rom_start
    EQUB &01                    \ Version number
    EQUS "MOS Extension"       \ ROM title
.copyright_ptr
    EQUB 0                     \ Title terminator / copyright pointer target
    EQUS "(C) RTW and MG 1992" \ Copyright string
    EQUB 0                     \ Copyright terminator

\ ============================================================================
\ Service entry — dispatches on service call number in A
\ ============================================================================
.service_entry
    CMP #svc_command
{
    BNE not_command
    JMP handle_command
.not_command
}
    CMP #svc_help
    BEQ handle_help
    CMP #svc_post_reset
{
    BNE not_reset
    JMP handle_reset
.not_reset
}
    CMP #svc_claim_static
    BEQ handle_claim_static
    RTS

\ Handle service call &22: claim static workspace for extended input
.handle_claim_static
    DEY
    TYA
    STA rom_workspace_table,X
    LDA #svc_claim_static
    RTS
\ ============================================================================
\ *HELP handler (service call &09)
\ ============================================================================
.handle_help
    PHA : PHX : PHY
    LDX #&00
{
.print_loop
    LDA (&f2),Y                 \ Check if bare *HELP (CR = end of line)
    CMP #&0D
    BNE help_has_argument
    LDA help_title_text,X       \ Print help title string
    BEQ done
    JSR osasci
    INX
    BNE print_loop
.done
    PLY : PLX : PLA
    RTS
}
.help_title_text
    EQUB &0D
    EQUS "MOS Extension"
    EQUB &0D
    EQUS "  XMOS"
    EQUB &0D
    EQUS "  FEATURES"
    EQUB &0D, 0
.features_keyword
    EQUS "FEATURES"
    EQUB 0
\ *HELP with an argument — check for "XMOS", "FEATURES", or a command name
.help_has_argument
    PHY
    LDA #LO(xmos_keyword) : STA zp_ptr_lo
    LDA #HI(xmos_keyword) : STA zp_ptr_hi
    JSR compare_string          \ Compare argument against "XMOS"
    BCC help_try_features
    PLY
    \ Matched "XMOS" — print all commands from the command table
    LDA #LO(command_table) : STA zp_ptr_lo
    LDA #HI(command_table) : STA zp_ptr_hi
    JSR print_inline
    EQUB &0D
    EQUS "MOS Extension commands:"
    EQUB &0E, &0D, 0           \ &0E = mode 1 (double height?)
    LDA #LO(command_table) : STA zp_ptr_lo
    LDA #HI(command_table) : STA zp_ptr_hi
.help_print_loop
    LDY #&00
    EQUB &B2, &A8              \ LDA (zp_ptr_lo) — 65C02 (zp) indirect
    CMP #&FF                   \ End of table marker?
    BEQ help_done
    LDA #&20                   \ Print two spaces indent
    JSR osasci
    JSR osasci
{
.print_name                     \ Print command name
    LDA (zp_ptr_lo),Y
    BEQ name_done
    JSR osasci
    INY
    BNE print_name
.name_done
}
    TYA                         \ Pad with spaces to column 11
    SEC                         \ (9 - name_length spaces)
    SBC #&09
    EOR #&FF : INC A             \ negate
    TAX
{
.pad_loop
    LDA #&20
    JSR osasci
    DEX
    BNE pad_loop
}
    INY                         \ Skip null terminator
    INY                         \ Skip 2-byte handler address
    INY
    DEY                         \ Back up one (INY at start of loop)
{
.print_help                     \ Print help text
    INY
    LDA (zp_ptr_lo),Y
    BEQ help_text_done
    JSR osasci
    BRA print_help
.help_text_done
}
    JSR osnewl
    INY                         \ Advance pointer past this entry
    CLC
    TYA
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    JMP help_print_loop
.help_done
    PLY : PLX : PLA
    RTS
\ Check if *HELP FEATURES
.help_try_features
    LDA #LO(features_keyword) : STA zp_ptr_lo
    LDA #HI(features_keyword) : STA zp_ptr_hi
    PLY
    PHY
    JSR compare_string
    BCC help_try_command
    PLY
    \ Matched "FEATURES" — print features text
    LDA #LO(features_text) : STA zp_ptr_lo
    LDA #HI(features_text) : STA zp_ptr_hi
    LDY #&00
{
.print_loop
    LDA (zp_ptr_lo),Y
    BEQ done
    JSR osasci
    INY
    BNE print_loop
    INC zp_ptr_hi
    BRA print_loop
.done
}
    JSR osnewl
    PLY : PLX : PLA
    RTS

\ Check if *HELP <command name> — try each command in table
.help_try_command
    PLY
    LDA #LO(command_table) : STA zp_ptr_lo
    LDA #HI(command_table) : STA zp_ptr_hi
.help_try_next_cmd
    PHY
    JSR compare_string
    BCS help_print_single_cmd
{
    LDY #&00
.skip_name                      \ Skip past command name
    INY
    LDA (zp_ptr_lo),Y
    BNE skip_name
    INY                         \ Skip null
    INY                         \ Skip 2-byte handler address
    INY
.skip_help                      \ Skip past help text
    INY
    LDA (zp_ptr_lo),Y
    BNE skip_help
}
    INY                         \ Advance pointer to next entry
    CLC
    TYA
    ADC zp_ptr_lo
    STA zp_ptr_lo
    LDA zp_ptr_hi
    ADC #&00
    STA zp_ptr_hi
    PLY
    EQUB &B2, &A8              \ LDA (zp_ptr_lo) — 65C02 (zp) indirect
    CMP #&FF                   \ End of table?
    BNE help_try_next_cmd
    LDA #&0F                   \ Print mode 0 (reset double height)
    JSR osasci
    PLY : PLX : PLA
    RTS

\ Matched a specific command — print its help entry
.help_print_single_cmd
    PLY
    LDA #&20                   \ Two space indent
    JSR osasci
    JSR osasci
    LDY #&FF
{
.print_name                     \ Print command name
    INY
    LDA (zp_ptr_lo),Y
    JSR osasci
    CMP #&00
    BNE print_name
}
    TYA                         \ Pad with spaces to column 11
    SEC
    SBC #&09
    EOR #&FF : INC A             \ negate
    TAX
{
.pad_loop
    LDA #&20
    JSR osasci
    DEX
    BNE pad_loop
}
    INY                         \ Skip handler address (2 bytes)
    INY
    INY
{
.print_help_text                \ Print the help description
    LDA (&a8),Y
    BEQ done
    JSR osasci
    INY
    BNE print_help_text
.done
}
    JSR osnewl
    PLY : PLX : PLA
    RTS

\ ============================================================================
\ * command handler (service call &04) — dispatch unrecognised commands
\ ============================================================================
.handle_command
    PHA : PHX : PHY
    LDA #LO(command_table)
    STA &a8
    LDA #HI(command_table)
    STA &a9
.cmd_try_next
    PHY
    EQUB &B2, &A8              \ LDA (&A8) — 65C02 (zp) indirect
    CMP #&FF                   \ End of command table?
    BEQ cmd_not_found
    JSR compare_string
    BCS cmd_found
{
    LDY #&00
.skip_name                      \ Skip command name
    INY
    LDA (&a8),Y
    BNE skip_name
    INY                         \ Skip null terminator
    INY                         \ Skip handler address low byte
    INY                         \ Skip handler address high byte
.skip_help                      \ Skip help text
    INY
    LDA (&a8),Y
    BNE skip_help
}
    INY                         \ Advance past help text null terminator
    TYA
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    PLY
    JMP cmd_try_next

.cmd_not_found
    PLY
    JMP check_alias             \ Not a built-in command, try aliases

.cmd_found
    PLY
    LDY #&00
{
.skip_name                      \ Skip past command name to handler address
    INY
    LDA (&a8),Y
    BNE skip_name
}
    INY
    LDA (&a8),Y                \ Load handler address low byte
    STA cmd_dispatch_addr + 1
    INY
    LDA (&a8),Y                \ Load handler address high byte
    STA cmd_dispatch_addr + 2
    JSR cmd_dispatch
    PLY : PLX : PLA
    LDA #&00                   \ Claim the service call
    RTS

.cmd_dispatch
.cmd_dispatch_addr
    JMP cmd_keyoff                  \ Self-modified: handler address written here
\ ============================================================================
\ Command table
\ Format: name (null-terminated), handler address (2 bytes LE), help text (null-terminated)
\ Terminated by &FF
\ ============================================================================
.command_table
    EQUS "ALIAS", 0    : EQUW cmd_alias    : EQUS "<alias name> <alias>", 0
    EQUS "ALIASES", 0  : EQUW cmd_aliases  : EQUS "Shows active aliases", 0
    EQUS "ALICLR", 0   : EQUW cmd_aliclr   : EQUS "Clears all aliases", 0
    EQUS "ALILD", 0    : EQUW cmd_alild    : EQUS "Loads alias file", 0
    EQUS "ALISV", 0    : EQUW cmd_alisv    : EQUS "Saves alias file", 0
    EQUS "BAU", 0      : EQUW cmd_bau      : EQUS "Splits to single commands", 0
    EQUS "DEFKEYS", 0  : EQUW cmd_defkeys  : EQUS "Defines new keys", 0
    EQUS "DIS", 0      : EQUW cmd_dis      : EQUS "<addr> - disassemble memory", 0
    EQUS "KEYON", 0    : EQUW cmd_keyon    : EQUS "Enables redefined keys", 0
    EQUS "KEYOFF", 0   : EQUW cmd_keyoff   : EQUS "Disables redefined keys", 0
    EQUS "KSTATUS", 0  : EQUW cmd_kstatus  : EQUS "Displays KEYON status", 0
    EQUS "L", 0        : EQUW cmd_l        : EQUS "Selects mode 128", 0
    EQUS "LVAR", 0     : EQUW cmd_lvar     : EQUS "Shows current variables", 0
    EQUS "MEM", 0      : EQUW cmd_mem      : EQUS "<addr> - memory editor", 0
    EQUS "S", 0        : EQUW cmd_s        : EQUS "Saves BASIC with incore name", 0
    EQUS "SPACE", 0    : EQUW cmd_space    : EQUS "Inserts spaces into programs", 0
    EQUS "STORE", 0    : EQUW cmd_store    : EQUS "Keeps function keys on break", 0
    EQUS "XON", 0      : EQUW cmd_xon      : EQUS "Enables extended input", 0
    EQUS "XOFF", 0     : EQUW cmd_xoff     : EQUS "Disables extended input", 0
    EQUB &FF                  \ End of command table
.xmos_keyword
    EQUS "XMOS"
    EQUB 0
\ ============================================================================
\ *XON — Enable extended input
\ ============================================================================
.cmd_xon
    LDA #&FF
    STA xon_flag
    LDA #&04                   \ OSBYTE 4: set cursor key status
    LDX #&01                   \ X=1: cursor editing mode
    LDY #&00
    JMP osbyte

\ ============================================================================
\ *XOFF — Disable extended input
\ ============================================================================
.cmd_xoff
    LDA #&00
    STA xon_flag
    LDA #&04                   \ OSBYTE 4: set cursor key status
    LDX #&00                   \ X=0: normal cursor keys
    LDY #&00
    JMP osbyte

\ --- Small utility: ring the bell ---
.beep
    LDA #&07                   \ BEL character
    JMP oswrch
\ --- Workspace variables (in sideways RAM, overwritten at runtime) ---
.xon_flag
    EQUB &FF                   \ non-zero = XON active
.xi_cursor_pos
    EQUB &1A                   \ current cursor position in input line
.xi_line_len
    EQUB &1A                   \ current line length
.xi_char
    EQUB &0D                   \ last character read / temp
.xi_temp
    EQUB &08                   \ temp for number parsing

\ ============================================================================
\ Post-reset handler (service call &27)
\ ============================================================================
\ ============================================================================
\ Post-reset handler (service call &27) — restore XMOS state after BREAK
\ ============================================================================

INCLUDE "input.asm"
INCLUDE "util.asm"
INCLUDE "basic.asm"
INCLUDE "keys.asm"
INCLUDE "alias.asm"
INCLUDE "mem.asm"
INCLUDE "dis.asm"
INCLUDE "bau.asm"
INCLUDE "lvar.asm"
INCLUDE "data.asm"

SAVE "build.rom", &8000, &C000
