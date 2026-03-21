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
    PHA
    PHX
    PHY
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
    PLY
    PLX
    PLA
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
    LDA #LO(xmos_keyword)
    STA zp_ptr_lo
    LDA #HI(xmos_keyword)
    STA zp_ptr_hi
    JSR compare_string          \ Compare argument against "XMOS"
    BCC help_try_features
    PLY
    \ Matched "XMOS" — print all commands from the command table
    LDA #LO(command_table)
    STA zp_ptr_lo
    LDA #HI(command_table)
    STA zp_ptr_hi
    JSR print_inline
    EQUB &0D
    EQUS "MOS Extension commands:"
    EQUB &0E, &0D, 0           \ &0E = mode 1 (double height?)
    LDA #LO(command_table)
    STA zp_ptr_lo
    LDA #HI(command_table)
    STA zp_ptr_hi
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
    EOR #&FF
    INC A
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
    PLY
    PLX
    PLA
    RTS
\ Check if *HELP FEATURES
.help_try_features
    LDA #LO(features_keyword)
    STA zp_ptr_lo
    LDA #HI(features_keyword)
    STA zp_ptr_hi
    PLY
    PHY
    JSR compare_string
    BCC help_try_command
    PLY
    \ Matched "FEATURES" — print features text from &9EF0
    LDA #LO(features_text)
    STA zp_ptr_lo
    LDA #HI(features_text)
    STA zp_ptr_hi
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
    PLY
    PLX
    PLA
    RTS

\ Check if *HELP <command name> — try each command in table
.help_try_command
    PLY
    LDA #LO(command_table)
    STA zp_ptr_lo
    LDA #HI(command_table)
    STA zp_ptr_hi
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
    PLY
    PLX
    PLA
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
    EOR #&FF
    INC A
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
    PLY
    PLX
    PLA
    RTS

\ ============================================================================
\ * command handler (service call &04) — dispatch unrecognised commands
\ ============================================================================
.handle_command
    PHA
    PHX
    PHY
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
    PLY
    PLX
    PLA
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
.handle_reset
    PHA
    PHX
    PHY
    LDA rom_workspace_table,X   \ Get our ROM's workspace page
    STA extended_input_code + &0F \ Patch workspace high byte into handler
    STX extended_input_code + &25 \ Patch ROM slot number into handler
    STA &AB                     \ Set up workspace pointer high
    STA &020D                   \ Set OSHWM high byte
    LDA #&00
    STA &AA                     \ Workspace pointer low = 0
    STA &020C                   \ OSHWM low byte = 0
    JSR L9379                   \ Initialise alias system
    LDA keyon_active
    BEQ reset_skip_keyon
    LDA #&00
    STA keyon_active
    JSR L8C89                   \ Re-enable KEYON if it was active
.reset_skip_keyon
    LDA xon_flag
    BEQ reset_skip_xon
    LDA #&04                   \ OSBYTE 4: cursor key status
    LDX #&01                   \ Enable cursor editing
    LDY #&00
    JSR osbyte
    LDA #&16                   \ OSBYTE &16: reset function keys?
    LDX #&01
    JSR osbyte
.reset_skip_xon
{
    LDY #&00                   \ Copy extended input handler code to workspace
.copy_loop
    LDA extended_input_code,Y
    STA (&AA),Y
    INY
    CPY #&D0                   \ Copy &D0 (208) bytes
    BNE copy_loop
}
    PLY
    PLX
    PLA
    RTS
\ ============================================================================
\ Extended input handler code — copied to workspace RAM on reset
\ This block runs from the ROM's private workspace page, intercepting
\ keyboard input to provide cursor editing, insert/delete, etc.
\ ============================================================================
.extended_input_code
    PHP
    CMP #&00
    BEQ L84DA
    PLP
    JMP &EF39
.L84DA
    PLA
    STX &00AE
    STY &00AF
    LDA #&db
    STA &00AB
    LDA #&e0
    STA &00AA
    LDY #&0f
.L84E9
    LDA (&ae),Y
    STA (&aa),Y
    DEY
    BPL L84E9
    LDA &00F4
    STA &0230
    LDA #&07
    STA sheila_romsel
    STA &00F4
    JSR L850C
    PHP
    LDA &0230
    STA sheila_romsel
    STA &00F4
    LDA #&00
    PLP
    RTS
.L850C
    LDA xon_flag
    BNE L8518
    LDX &00AE
    LDY &00AF
    JMP &EF39
.L8518
    LDA #&00
    STA xi_scroll_count
    LDA #&00
    STA xi_cursor_pos
    STA xi_line_len
    TAY
    LDA (&aa),Y
    STA &00A8
    INY
    LDA (&aa),Y
    STA &00A9
.L852F
    JSR osrdch
    STA xi_char
    LDA &026A
    BPL L8543
    LDA xi_char
    JSR oswrch
    JMP L852F
.L8543
    LDA xi_char
    CMP #&88
    BNE L854D
    JMP L861C
.L854D
    CMP #&89
    BNE L8554
    JMP L8636
.L8554
    CMP #&7f
    BNE L855B
    JMP L8653
.L855B
    CMP #&0d
    BNE L8562
    JMP L869F
.L8562
    CMP #&1b
    BNE L8569
    JMP L8704
.L8569
    CMP #&15
    BNE L8570
    JMP L8724
.L8570
    CMP #&8b
    BNE L8577
    JMP L876B
.L8577
    CMP #&8a
    BNE L857E
    JMP L87D5
.L857E
    CMP #&87
    BNE L8585
    JMP L8854
.L8585
    CMP #&0e
    BNE L858C
    JSR oswrch
.L858C
    CMP #&0f
    BNE L8593
    JSR oswrch
.L8593
    CMP #&09
    BNE L859A
    JMP L88AB
.L859A
    CMP #&00
    BNE L85A1
    JMP L8755
.L85A1
    LDA xi_char
    CMP #&20
    BCS L85AE
    JSR oswrch
    JMP L852F
.L85AE
    LDY #&03
    CMP (&aa),Y
    BCS L85B7
    JMP L852F
.L85B7
    INY
    CMP (&aa),Y
    BEQ L85C1
    BCC L85C1
    JMP L852F
.L85C1
    LDA xi_cursor_pos
    LDY #&02
    CMP (&aa),Y
    BNE L85CD
    JMP L852F
.L85CD
    LDA #&00
    STA xi_insert_mode
    JSR L85D9
    JMP L852F
.xi_insert_mode
    EQUB &00                   \ &85D8: insert mode flag (0=insert, FF=overwrite)
.L85D9
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ L85F2
    TAX
    LDY xi_cursor_pos
    DEY
.L85E8
    LDA (&a8),Y
    INY
    STA (&a8),Y
    DEY
    DEY
    DEX
    BNE L85E8
.L85F2
    LDY xi_line_len
    LDA xi_char
    JSR oswrch
    STA (&a8),Y
    INC xi_line_len
    INC xi_cursor_pos
    PLA
    BEQ L861B
    PHA
    TAX
.L8608
    INY
    LDA (&a8),Y
    JSR oswrch
    DEX
    BNE L8608
    PLA
    TAX
.L8613
    LDA #&08
    JSR oswrch
    DEX
    BNE L8613
.L861B
    RTS
.L861C
    LDA xi_cursor_pos
    BNE L8626
    LDY #&8c
    JMP L883F
.L8626
    LDA xi_line_len
    BEQ L8633
    DEC xi_line_len
    LDA #&08
    JSR oswrch
.L8633
    JMP L852F
.L8636
    LDA xi_cursor_pos
    BNE L8640
    LDY #&8d
    JMP L883F
.L8640
    LDA xi_line_len
    CMP xi_cursor_pos
    BEQ L8650
    INC xi_line_len
    LDA #&09
    JSR oswrch
.L8650
    JMP L852F
.L8653
    LDA xi_line_len
    BEQ L869C
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ L8670
    TAX
    LDY xi_line_len
.L8666
    LDA (&a8),Y
    DEY
    STA (&a8),Y
    INY
    INY
    DEX
    BNE L8666
.L8670
    LDA #&7f
    JSR oswrch
    DEC xi_line_len
    DEC xi_cursor_pos
    LDY xi_line_len
    PLA
    BEQ L869C
    PHA
    TAX
.L8683
    LDA (&a8),Y
    JSR oswrch
    INY
    DEX
    BNE L8683
    LDA #&20
    JSR oswrch
    PLA
    TAX
    INX
.L8694
    LDA #&08
    JSR oswrch
    DEX
    BNE L8694
.L869C
    JMP L852F
.L869F
    LDA xon_flag
    BEQ L86AD
    LDA #&04
    LDX #&01
    LDY #&00
    JSR osbyte
.L86AD
    LDA &0230
    CMP #&0c
    BNE L86DD
    LDA xi_cursor_pos
    CMP #&04
    BNE L86DD
    LDY #&03
.L86BD
    LDA (&a8),Y
    CMP save_keyword,Y
    BNE L86DD
    DEY
    BPL L86BD
    JSR osnewl
    LDA &0230
    PHA
    JSR cmd_s
    LDA #&0d
    EQUB &92, &A8  \ STA (&a8)
    LDY #&00
    PLA
    STA &0230
    CLC
    RTS
.L86DD
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ L86EF
    TAX
.L86E7
    LDA #&09
    JSR oswrch
    DEX
    BNE L86E7
.L86EF
    JSR L9D88
    LDY xi_cursor_pos
    LDA #&0d
    STA (&a8),Y
    JSR osnewl
    CLC
    LDX #&00
    RTS
.save_keyword
    EQUS "SAVE"                \ &8700: compared against user input
.L8704
    LDA #&04                   \ OSBYTE 4: cursor key status
    LDX #&01                   \ Enable cursor editing
    LDY #&00
    JSR osbyte
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ L871F
    TAX
.L8717
    LDA #&09
    JSR oswrch
    DEX
    BNE L8717
.L871F
    LDY xi_cursor_pos
    SEC
    RTS
.L8724
    JSR L872A
    JMP L852F
.L872A
    LDA xi_cursor_pos
    BEQ L8754
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ L8741
    TAX
.L8739
    LDA #&09
    JSR oswrch
    DEX
    BNE L8739
.L8741
    LDX xi_cursor_pos
.L8744
    LDA #&7f
    JSR oswrch
    DEX
    BNE L8744
    LDA #&00
    STA xi_line_len
    STA xi_cursor_pos
.L8754
    RTS
.L8755
    LDA xi_cursor_pos
    BEQ L875D
    JMP L852F
.L875D
    JSR cmd_xoff
    JSR osnewl
    LDY #&00
    LDA #&0d
    STA (&a8),Y
    CLC
    RTS
.L876B
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE L8795
    LDA xi_scroll_count
    BNE L878F
    LDA xi_insert_mode
    BNE L878F
    LDA #&ff
    STA xi_insert_mode
    LDA xi_cursor_pos
    BEQ L8792
    JSR L9D88
.L878F
    INC xi_scroll_count
.L8792
    JMP L9DFE
.L8795
    LDA xi_cursor_pos
    BNE L879F
    LDY #&8f
    JMP L883F
.L879F
    SEC
    LDA &030A
    SBC &0308
    CLC
    ADC #&01
    STA xi_char
    SEC
    LDA xi_line_len
    SBC xi_char
    BCC L87C0
    STA xi_line_len
    LDA #&0b
    JSR oswrch
.L87BD
    JMP L852F
.L87C0
    LDX xi_line_len
    BEQ L87BD
.L87C5
    LDA #&08
    JSR oswrch
    DEX
    BNE L87C5
    LDA #&00
    STA xi_line_len
    JMP L852F
.L87D5
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE L87FA
    LDA xi_scroll_count
    BNE L87F4
    LDA xi_insert_mode
    BNE L87F4
    LDA #&ff
    STA xi_insert_mode
    JSR L9D88
.L87F4
    DEC xi_scroll_count
    JMP L9DFE
.L87FA
    LDA xi_cursor_pos
    BNE L8804
    LDY #&8e
    JMP L883F
.L8804
    SEC
    LDA &030A
    SBC &0308
    CLC
    ADC #&01
    CLC
    ADC xi_line_len
    BCS L8824
    CMP xi_cursor_pos
    BCS L8824
    STA xi_line_len
    LDA #&0a
    JSR oswrch
    JMP L852F
.L8824
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ L8836
    TAX
.L882E
    LDA #&09
    JSR oswrch
    DEX
    BNE L882E
.L8836
    LDA xi_cursor_pos
    STA xi_line_len
    JMP L852F
.L883F
    PHY
    LDA #&04
    LDX #&00
    LDY #&00
    JSR osbyte
    PLY
    LDA #&8a
    LDX #&00
    JSR osbyte
    JMP L852F
.L8854
    LDA xi_cursor_pos
    CMP xi_line_len
    BEQ L889B
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ L8875
    TAX
    LDY xi_line_len
    INY
.L886B
    LDA (&a8),Y
    DEY
    STA (&a8),Y
    INY
    INY
    DEX
    BNE L886B
.L8875
    DEC xi_cursor_pos
    LDY xi_line_len
    PLA
    BEQ L889B
    TAX
    DEX
    BEQ L889E
    PHA
.L8883
    LDA (&a8),Y
    JSR oswrch
    INY
    DEX
    BNE L8883
    LDA #&20
    JSR oswrch
    PLA
    TAX
.L8893
    LDA #&08
    JSR oswrch
    DEX
    BNE L8893
.L889B
    JMP L852F
.L889E
    LDA #&09
    JSR oswrch
    LDA #&7f
    JSR oswrch
.L88A8
    JMP L852F
.L88AB
    LDA xi_cursor_pos
    BEQ L88A8
    LDA &0230
    CMP #&0c
    BNE L88A8
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ L88C9
    TAX
.L88C1
    LDA #&09
    JSR oswrch
    DEX
    BNE L88C1
.L88C9
    LDA xi_cursor_pos
    STA xi_line_len
    LDY #&00
    STY xi_char
    STY xi_temp
.L88D7
    LDA (&a8),Y
    CMP #&30
    BCC L88E4
    CMP #&3a
    BCS L88E4
    JMP L88EC
.L88E4
    INY
    CPY xi_cursor_pos
    BEQ L88A8
    BNE L88D7
.L88EC
    ASL xi_char
    ROL xi_temp
    LDA xi_char
    ASL A
    STA &00AC
    LDA xi_temp
    ROL A
    STA &00AD
    ASL &00AC
    ROL &00AD
    CLC
    LDA xi_char
    ADC &00AC
    STA xi_char
    LDA &00AD
    ADC xi_temp
    STA xi_temp
    LDA (&a8),Y
    SEC
    SBC #&30
    CLC
    ADC xi_char
    STA xi_char
    LDA xi_temp
    ADC #&00
    STA xi_temp
    INY
    LDA (&a8),Y
    CMP #&30
    BCC L8937
    CMP #&3a
    BCS L8937
    CPY xi_cursor_pos
    BNE L88EC
.L8937
    LDY xi_cursor_pos
    LDA #&00
    STA &00AC
    LDA &0018
    STA &00AD
.L8942
    LDY #&01
    LDA (&ac),Y
    CMP #&ff
    BEQ L89A6
    CMP xi_temp
    BNE L8994
    INY
    LDA (&ac),Y
    CMP xi_char
    BNE L8994
    INY
    LDA (&ac),Y
    SEC
    SBC #&04
    TAX
    LDA #&00
    STA xi_quote_toggle
    LDA &001F
    AND #&01
    BEQ L8973
    PHY
    LDA #&20
    STA xi_char
    JSR L85D9
    PLY
.L8973
    INY
    LDA (&ac),Y
    PHY
    STA xi_char
    CMP #&80
    BCS L89AF
    CMP #&22
    BNE L898A
    LDA xi_quote_toggle
    EOR #&ff
    STA xi_quote_toggle
.L898A
    JSR L85D9
.L898D
    PLY
    DEX
    BNE L8973
    JMP L852F
.L8994
    LDY #&03
    LDA (&ac),Y
    CLC
    ADC &00AC
    STA &00AC
    LDA &00AD
    ADC #&00
    STA &00AD
    JMP L8942
.L89A6
    LDA #&07
    JSR oswrch
    JMP L852F
.xi_quote_toggle
    EQUB &00                   \ &89AE: quote toggle flag
.L89AF
    EQUB &AD, &AE, &89         \ LDA xi_quote_toggle (absolute ZP workaround)
    BNE L898A
    LDA #&55
    STA &AE
    LDA #&AE
    STA &AF
.L89BC
    LDY #&00
    LDA (&ae),Y
.L89C0
    INY
    LDA (&ae),Y
    BPL L89C0
    CMP xi_char
    BNE L89DF
    LDY #&ff
.L89CC
    INY
    LDA (&ae),Y
    BMI L89DC
    STA xi_char
    PHY
    JSR L85D9
    PLY
    JMP L89CC
.L89DC
    JMP L898D
.L89DF
    INY
    INY
    TYA
    CLC
    ADC &00AE
    STA &00AE
    LDA &00AF
    ADC #&00
    STA &00AF
    JMP L89BC
\ ============================================================================
\ print_inline — Print null-terminated string that follows the JSR
\ The return address on the stack points to the string data.
\ After printing, returns to the instruction after the null terminator.
\ ============================================================================
.print_inline
    PLA                         \ Pull return address (points to string - 1)
    STA &a8
    PLA
    STA &a9
    LDY #&00
{
.loop
    INY
    LDA (&a8),Y
    JSR osasci
    BNE loop
}
    CLC                         \ Adjust return address past the string
    TYA
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    PHA                         \ Push adjusted return address
    LDA &a8
    PHA
    RTS                         \ "Return" to instruction after the string

\ ============================================================================
\ copy_inline_to_stack — Copy inline string to &0100 (stack page) and execute
\ Used for self-modifying command strings that run from the stack.
\ ============================================================================
.copy_inline_to_stack
    PLA                         \ Pull return address (points to code - 1)
    STA &a8
    PLA
    STA &a9
    LDA #&00
    TAY
    STA &0100,Y                \ Store null at start of stack page
{
.loop
    INY
    LDA (&a8),Y                \ Copy bytes to stack page
    STA &0100,Y
    BNE loop
}
    JMP &0100                  \ Execute the copied code
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
    LDA &a9
    STA cmp_str_addr + 2
    STA lda_str_addr + 2
{
.loop
    LDA (&f2),Y                 \ Get next character from command line
    CMP #&2E                   \ '.' = abbreviation marker
    BEQ matched
    CMP #&61                   \ Convert lowercase to uppercase
    BCC no_convert
    CMP #&7B
    BCS no_convert
    AND #&DF                   \ Clear bit 5 = uppercase
.no_convert
.*cmp_str_addr
    CMP &831F,X                \ Compare against string (self-modified address)
    BEQ next_char
.*lda_str_addr
    LDA &831F,X                \ Check if we reached end of keyword (null)
    BNE no_match
    LDA (&f2),Y                \ At end of keyword: check command line terminator
    CMP #&0D                   \ CR = end of line
    BEQ matched
    CMP #&20                   \ Space = argument separator
    BNE no_match
.matched
    STY compare_string_y       \ Save Y position after match
    SEC                         \ C=1: match found
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
    EQUB &07                   \ Saved Y position after last match
\ ============================================================================
\ *S — Save BASIC program using its incore (embedded) filename
\ Looks for a line like: 10 REM > Filename
\ ============================================================================
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
.key_remap_handler
    PHP
    CMP #&81
    BEQ key_remap_scan
    CMP #&79
    BEQ key_remap_keyboard
    PLP
.key_remap_jmp1
    JMP &FFFF                  \ Patched: original KEYV address
.key_remap_scan
    CPY #&FF
    BNE key_remap_pass2
    CPX #&9E : BNE L8BF6 : LDX #&BF
.L8BF6
    CPX #&BD : BNE L8BFC : LDX #&FE
.L8BFC
    CPX #&B7 : BNE L8C02 : LDX #&B7
.L8C02
    CPX #&97 : BNE L8C08 : LDX #&97
.L8C08
    CPX #&B6 : BNE key_remap_pass2 : LDX #&B6
.key_remap_pass2
    PLP
.key_remap_jmp2
    JMP &FFFF                  \ Patched: original KEYV address
.key_remap_keyboard
    CPX #&80
    BCC key_remap_shifted
    CPX #&E1 : BNE L8C1C : LDX #&C0
.L8C1C
    CPX #&C2 : BNE L8C22 : LDX #&81
.L8C22
    CPX #&C8 : BNE L8C28 : LDX #&C8
.L8C28
    CPX #&E8 : BNE L8C2E : LDX #&E8
.L8C2E
    CPX #&C9 : BNE L8C34 : LDX #&C9
.L8C34
    PLP
.key_remap_jmp3
    JMP &FFFF                  \ Patched: original KEYV address
.key_remap_shifted
    PLP
.key_remap_jsr
    JSR &FFFF                  \ Patched: call original KEYV
    PHP
    CPX #&40 : BNE L8C45 : LDX #&E1 : STX &EC : LDX #&61
.L8C45
    CPX #&01 : BNE L8C4F : LDX #&C2 : STX &EC : LDX #&42
.L8C4F
    CPX #&48 : BNE L8C59 : LDX #&C8 : STX &EC : LDX #&48
.L8C59
    CPX #&68 : BNE L8C63 : LDX #&E8 : STX &EC : LDX #&68
.L8C63
    CPX #&49 : BNE L8C6D : LDX #&C9 : STX &EC : LDX #&49
.L8C6D
    PLP
    RTS

.saved_keyv_lo
    EQUB &00                   \ &8C71: saved KEYV low byte
.saved_keyv_hi
    EQUB &00                   \ &8C72: saved KEYV high byte
.keyon_active
    EQUB &00                   \ &8C73: non-zero = KEYON active
    EQUB &41, &02, &49, &69, &4A  \ &8C74: workspace
.L8C79
    STROUT msg_keyon_already
    JMP L8D64
.L8C89
    LDA keyon_active
    BNE L8C79
    LDA #&01
    STA keyon_active
    LDA &020a
    STA &8bea
    STA &8c10
    STA &8c36
    STA &8c3a
    STA saved_keyv_lo
    LDA &020b
    STA &8beb
    STA &8c11
    STA &8c37
    STA &8c3b
    STA saved_keyv_hi
    SEC
    LDA #&00
    SBC &8c74
    STA &8bf5
    SEC
    LDA #&00
    SBC &8c75
    STA &8bfb
    SEC
    LDA #&00
    SBC &8c76
    STA &8c01
    SEC
    LDA #&00
    SBC &8c77
    STA &8c07
    SEC
    LDA #&00
    SBC &8c78
    STA &8c0d
    CLC
    LDA &8c74
    ADC #&7f
    STA &8c1b
    CLC
    LDA &8c75
    ADC #&7f
    STA &8c21
    CLC
    LDA &8c76
    ADC #&7f
    STA &8c27
    CLC
    LDA &8c77
    ADC #&7f
    STA &8c2d
    CLC
    LDA &8c78
    ADC #&7f
    STA &8c33
    SEC
    LDA &8c74
    SBC #&01
    STA &8c3e
    SEC
    LDA &8c75
    SBC #&01
    STA &8c48
    SEC
    LDA &8c76
    SBC #&01
    STA &8c52
    SEC
    LDA &8c77
    SBC #&01
    STA &8c5c
    SEC
    LDA &8c78
    SBC #&01
    STA &8c66
    LDX #&00
.L8D40
    LDA &8bdf,X
    STA &d100,X
    INX
    BNE L8D40
    LDA #&00
    STA &020a
    LDA #&d1
    STA &020b
    RTS
.cmd_keyon
    JSR L8C89
    STROUT msg_keys_redefined
.L8D64
    RTS
.msg_keys_redefined
    EQUS 13, "Keys now redefined", 13, 0
.msg_keyon_already
    EQUS 13, "'KEYON' already executed!", 13, 7, 0
.msg_keys_off
    EQUS 13, "Redefined keys off", 13, 0
.msg_keys_on
    EQUS 13, "Redefined keys on, and are:", 13, 13, 0  \ &8DC5: re:...
\ ============================================================================
\ *KEYOFF — Disable redefined keys
\ ============================================================================
.cmd_keyoff
    LDA keyon_active            \ Already disabled?
    BEQ keyoff_print_msg
    LDA #&00
    STA keyon_active
    LDA saved_keyv_lo           \ Restore original KEYV
    STA &020A
    LDA saved_keyv_hi
    STA &020B
.keyoff_print_msg
    STROUT msg_keys_off
    JMP L8D64

\ --- Key name lookup table ---
\ Each entry: key code byte, then 9-char padded name
\ Used by KSTATUS to display key names
.key_name_table
    EQUB &00 : EQUS "TAB      "
    EQUB &01 : EQUS "CAPS LOCK"
    EQUB &02 : EQUS "SHFT LOCK"
    EQUB &03 : EQUS "SHIFT    "
    EQUB &04 : EQUS "CTRL     "
    EQUB &1B : EQUS "ESCAPE   "
    EQUS 13, "RETURN   "
    EQUB &20 : EQUS "SPACE    "
    EQUB &7F : EQUS "DELETE   "
    EQUB &8B : EQUS "COPY     "
    EQUB &8C : EQUS "LEFT     "
    EQUB &8D : EQUS "RIGHT    "
    EQUB &8E : EQUS "DOWN     "
    EQUB &8F : EQUS "UP       "
    EQUB &E0 : EQUS "BREAK!!! "
.L8E87
    CMP #&00
    BNE L8E8F
    LDA #&03
    BNE L8EA4
.L8E8F
    CMP #&01
    BNE L8E97
    LDA #&04
    BNE L8EA4
.L8E97
    LDX &023c
    STX &a8
    LDX &023d
    STX &a9
    TAY
    LDA (&a8),Y
.L8EA4
    LDX #&f1
    STX &a8
    LDX #&8d
    STX &a9
    LDY #&00
.L8EAE
    CMP (&a8),Y
    BEQ L8EC3
    INY
    INY
    INY
    INY
    INY
    INY
    INY
    INY
    INY
    INY
    CPY #&96
    BCC L8EAE
    JMP oswrch
.L8EC3
    LDX #&09
    INY
.L8EC6
    LDA (&a8),Y
    JSR oswrch
    INY
    DEX
    BNE L8EC6
    RTS
\ --- DEFKEYS joystick direction labels (12 chars each) ---
.defkeys_direction_labels
    EQUS "     Left : "  \ 12 bytes each
    EQUS "    Right : "
    EQUS "       Up : "
    EQUS "     Down : "
    EQUS "Jump/fire : "

\ ============================================================================
\ *KSTATUS — Display current key redefinition status
\ ============================================================================
.kstatus_not_active
    JMP keyoff_print_msg        \ Print "Redefined keys off" message
.cmd_kstatus
    LDA keyon_active
    BEQ kstatus_not_active
    STROUT msg_keys_on
    LDA #&d0
    STA &aa
    LDA #&8e
    STA &ab
    LDX #&00
.L8F2B
    LDY #&00
.L8F2D
    LDA (&aa),Y
    JSR oswrch
    INY
    CPY #&0c
    BNE L8F2D
    CLC
    LDA &aa
    ADC #&0c
    STA &aa
    LDA &ab
    ADC #&00
    STA &ab
    LDA &8c74,X
    PHX
    DEC A
    JSR L8E87
    JSR osnewl
    PLX
    INX
    CPX #&05
    BNE L8F2B
    JSR osnewl
    JMP L8D64
.msg_key_redefiner
    EQUS "KEY REDEFINER"
    EQUB &0D
    EQUS "-------------"
    EQUB &0D, 0
.cmd_defkeys
    LDA keyon_active
    BEQ L8F8E
    LDA #&00
    STA keyon_active
    LDA saved_keyv_lo
    STA &020a
    LDA saved_keyv_hi
    STA &020b
.L8F8E
    LDA #&81
    LDX #&b6
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BEQ L8F8E
    JSR osnewl
    STROUT msg_key_redefiner
    JSR osnewl
    LDA #&d0
    STA &aa
    LDA #&8e
    STA &ab
    LDX #&00
.L8FB8
    LDY #&00
.L8FBA
    LDA (&aa),Y
    JSR oswrch
    INY
    CPY #&0c
    BNE L8FBA
    CLC
    LDA &aa
    ADC #&0c
    STA &aa
    LDA &ab
    ADC #&00
    STA &ab
    JSR L8FE4
    INX
    CPX #&05
    BNE L8FB8
    JSR osnewl
    LDA #&0f
    JSR osbyte
    JMP L8C89
.L8FE4
    PHX
.L8FE5
    LDX #&81
.L8FE7
    PHX
    LDA #&81
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BEQ L8FF9
    PLX
    INX
    BNE L8FE7
    BEQ L8FE5
.L8FF9
    PLA
    EOR #&ff
    INC A
    PLX
    STA &8c74,X
    DEC A
    PHX
    PHA
    JSR L8E87
    JSR osnewl
    PLA
    EOR #&ff
    TAX
    PHX
.L900F
    PLX
    PHX
    LDA #&81
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BEQ L900F
    PLX
    PLX
    RTS
.L901F
    LDY &8a67
    DEY
.L9023
    INY
    LDA (&f2),Y
    CMP #&20
    BEQ L9023
    CMP #&2e
    BEQ L9023
    STY &8a67
    RTS
.alias_semicolon_flag
    EQUB &FF  \ &9032: .
.cmd_alias
    LDA #&00
    STA alias_semicolon_flag
    JSR L901F
    CMP #&0d
    BNE L9042
    JMP L9190
.L9042
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.L904A
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ L90B0
    LDY &8a67
    PHY
    JSR compare_string
    PLY
    STY &8a67
    BCC L9098
    LDA #&ff
    STA alias_semicolon_flag
    LDY #&ff
.L9064
    INY
    LDA (&a8),Y
    BNE L9064
    INY
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &aa
    LDA &a9
    ADC #&00
    STA &ab
    LDY #&00
.L9079
    LDA (&aa),Y
    STA (&a8),Y
    CMP #&ff
    BNE L908B
    STA (&a8),Y
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BNE L9098
    BEQ L90B0
.L908B
    INY
    BNE L9079
    INC &ac
    INC &aa
    LDA &aa
    CMP #&bf
    BCC L9079
.L9098
    LDY #&ff
.L909A
    INY
    LDA (&a8),Y
    BNE L909A
    INY
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP L904A
.L90B0
    LDA &8a67
    STA &70
    LDY &8a67
    DEY
.L90B9
    INY
    LDA (&f2),Y
    CMP #&0d
    BNE L90B9
    TYA
    SEC
    SBC &8a67
    CLC
    ADC &a8
    BCC L90E6
    LDA &a9
    CMP #&be
    BCC L90E6
    JSR copy_inline_to_stack    \ BRK error: "No room for alias"
    EQUS &48, "No room for alias", 0
.L90E6
    CLC
    LDA &f2
    ADC &8a67
    STA &f2
    LDA &f3
    ADC #&00
    STA &f3
    LDY #&00
.L90F6
    LDA (&f2),Y
    CMP #&20
    BEQ L9112
    CMP #&0d
    BNE L9103
    JMP L9186
.L9103
    CMP #&61
    BCC L910D
    CMP #&7b
    BCS L910D
    AND #&df
.L910D
    STA (&a8),Y
    INY
    BNE L90F6
.L9112
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
    STY &8a67
    INY
.L9128
    LDA (&f2),Y
    CMP #&0d
    BEQ L9133
    STA (&a8),Y
    INY
    BNE L9128
.L9133
    STA (&a8),Y
    INY
    LDA #&ff
    STA (&a8),Y
    TYA
    LDY &8a67
    STA (&a8),Y
    RTS
.cmd_aliases
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.L9149
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ L9185
    LDY #&ff
.L9151
    INY
    LDA (&a8),Y
    JSR osasci
    CMP #&00
    BNE L9151
    INY
    LDA #&20
    JSR osasci
    LDA #&3d
    JSR osasci
    LDA #&20
    JSR osasci
.L916B
    INY
    LDA (&a8),Y
    JSR osasci
    CMP #&0d
    BNE L916B
    INY
    TYA
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP L9149
.L9185
    RTS
.L9186
    LDA #&ff
    EQUB &92, &A8  \ STA (0xa8)
    LDA alias_semicolon_flag
    BEQ L9190
    RTS
.L9190
    JSR copy_inline_to_stack    \ BRK error: "Syntax : ALIAS <alias name> <alias>"
    EQUS &48, "Syntax : ALIAS <alias name> <alias>", 0
.check_alias
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.L91C0
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ L91E6
    PHY
    JSR compare_string
    BCS L91EA
    LDY #&ff
.L91CE
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE L91CE
    INY
    CLC
    TYA
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    PLY
    JMP L91C0
.L91E6
    PLY
    PLX
    PLA
    RTS
.L91EA
    PLY
    JSR L901F
    LDY #&ff
.L91F0
    INY
    LDA (&a8),Y
    CMP #&00
    BNE L91F0
    INY
    INY
    STY &93a7
    LDX #&00
.L91FE
    LDY &93a7
    LDA (&a8),Y
    INY
    STY &93a7
    STA &a55b,X
    INX
    CMP #&0d
    BNE L9212
    JMP L9262
.L9212
    CMP #&25
    BEQ L9219
    JMP L91FE
.L9219
    LDA (&a8),Y
    INY
    STY &93a7
    CMP #&25
    BEQ L91FE
    DEX
    CMP #&55
    BNE L922B
    JMP L9278
.L922B
    SEC
    SBC #&30
    PHX
    TAX
    LDY &8a67
    CMP #&00
    BEQ L9247
    DEY
.L9238
    INY
    LDA (&f2),Y
    CMP #&0d
    BEQ L925E
    CMP #&20
    BNE L9238
    DEX
    BNE L9238
    INY
.L9247
    PLX
.L9248
    LDA (&f2),Y
    CMP #&20
    BEQ L925B
    CMP #&0d
    BEQ L925B
    BEQ L925B
    STA &a55b,X
    INX
    INY
    BNE L9248
.L925B
    JMP L91FE
.L925E
    PLX
    JMP L91FE
.L9262
    LDX #&56
    LDY #&a5
    JSR oscli
    LDA #&8a
    LDX #&00
    LDY #&89
    JSR osbyte
    PLY
    PLX
    PLA
    LDA #&00
    RTS
.L9278
    LDA #&0b
    JSR osasci
    LDA #&15
    JSR osasci
    JMP L91FE
.cmd_alild
    JSR L901F
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
    BEQ L92C8
    STA &93a7
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.L92A6
    LDY &93a7
    JSR osbget
    BCS L92C0
    EQUB &92, &A8  \ STA (0xa8)
    CLC
    LDA &a8
    ADC #&01
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP L92A6
.L92C0
    LDA #&00
    LDY &93a7
    JMP osfind
.L92C8
    JSR copy_inline_to_stack    \ BRK error: "Alias file not found"
    EQUS &D6, "Alias file not found", 0
.cmd_alisv
    JSR L901F
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
    BEQ L9326
    STA &93a7
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.L9302
    LDY &93a7
    EQUB &B2, &A8  \ LDA (0xa8)
    JSR osbput
    CMP #&ff
    BEQ L931E
    CLC
    LDA &a8
    ADC #&01
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP L9302
.L931E
    LDA #&00
    LDY &93a7
    JMP osfind
.L9326
    JSR copy_inline_to_stack    \ BRK error: "Can't open alias file"
    EQUS &63, "Can't open alias file", 0
.cmd_aliclr
    LDA #&ff
    STA &b165
    RTS
.cmd_store
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    ORA #&80
    STA &fe30
    LDX #&00
.L9350
    LDA &8000,X
    STA &a655,X
    LDA &8100,X
    STA &a755,X
    LDA &8200,X
    STA &a855,X
    LDA &8300,X
    STA &a955,X
    INX
    BNE L9350
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    AND #&7f
    STA &fe30
    LDA #&ff
    STA &93a6
    RTS
.L9379
    LDA &93a6
    BEQ L93A5
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    ORA #&80
    STA &fe30
    LDX #&00
.L9388
    LDA &a655,X
    STA &8000,X
    LDA &a755,X
    STA &8100,X
    LDA &a855,X
    STA &8200,X
    INX
    BNE L9388
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    AND #&7f
    STA &fe30
.L93A5
    RTS
    EQUB &FF, &24  \ &93A6: .$
.L93A8
    CMP #&30
    BCC L93C0
    CMP #&47
    BCS L93C0
    SEC
    SBC #&30
    CMP #&0a
    BCC L93BE
    CMP #&11
    BCC L93C0
    SEC
    SBC #&07
.L93BE
    CLC
    RTS
.L93C0
    SEC
    RTS
.L93C2
    LDA #&00
    STA &ae
    STA &af
.L93C8
    LDA (&f2),Y
    CMP #&0d
    BEQ L940B
    CMP #&20
    BEQ L940B
    JSR L93A8
    BCC L93ED
    JSR copy_inline_to_stack    \ BRK error: "Invalid hex digit"
    EQUS &EB, "Invalid hex digit", 0
.L93ED
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
    BNE L93C8
.L940B
    RTS
.cmd_mem
    JSR L901F
    CMP #&0d
    BEQ L9420
    JSR L93C2
    LDA &ae
    STA &9c68
    LDA &af
    STA &9c69
.L9420
    LDA &9c68
    STA &a8
    LDA &9c69
    STA &a9
    LDA &a8
    AND #&07
    STA &9c6e
    EOR &a8
    STA &a8
    LDA #&16
    JSR oswrch
    LDA #&07
    JSR oswrch
    LDA #&0a
    STA &fe00
    LDA #&20
    STA &fe01
    LDX #&27
.L944B
    LDA &9c7e,X
    STA &7c00,X
    DEX
    BPL L944B
    LDA &027d
    STA &9c6c
    LDA #&01
    STA &027d
    LDA &0255
    STA &9c6d
    LDA #&02
    STA &0255
    LDA #&50
    STA &ac
    LDA #&7c
    STA &ad
    LDX #&16
.L9474
    LDA #&83
    LDY #&00
    STA (&ac),Y
    LDA #&87
    LDY #&05
    STA (&ac),Y
    LDA #&86
    LDY #&1f
    STA (&ac),Y
    CLC
    LDA &ac
    ADC #&28
    STA &ac
    BCC L9491
    INC &ad
.L9491
    DEX
    BNE L9474
.L9494
    SEC
    LDA &a8
    SBC #&50
    STA &ae
    LDA &a9
    SBC #&00
    STA &af
    JSR L95BC
    LDA #&81
    LDX #&02
    LDY #&00
    JSR osbyte
    CPY #&1b
    BEQ L9501
    BCS L9494
    TXA
    LDX #&04
.L94B6
    CMP &9c6f,X
    BEQ L94EC
    DEX
    BPL L94B6
    PHA
    LDA &7c27
    CMP #&48
    BEQ L94D2
    PLA
    LDY &9c6e
    STA (&a8),Y
    JSR L9543
    JMP L9494
.L94D2
    PLA
    JSR L93A8
    BCS L9494
    STA &93a7
    LDY &9c6e
    LDA (&a8),Y
    ASL A
    ASL A
    ASL A
    ASL A
    ORA &93a7
    STA (&a8),Y
    JMP L9494
.L94EC
    TXA
    ASL A
    TAX
    LDA &9c74,X
    STA cmd_dispatch_addr + 1
    LDA &9c75,X
    STA cmd_dispatch_addr + 2
    JSR cmd_dispatch
    JMP L9494
.L9501
    LDA &9c6c
    STA &027d
    LDA &9c6d
    STA &0255
    LDA #&0a
    STA &fe00
    LDA #&72
    STA &fe01
    LDA #&1f
    JSR oswrch
    LDA #&00
    JSR oswrch
    LDA #&18
    JSR oswrch
    LDA #&00
    STA &ff
    RTS
.L952B
    DEC mem_column
    EQUB &10, &12  \ BPL &9542
    LDA #&07
    STA mem_column
    SEC
    LDA &A8
    SBC #&08
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
.L9542
    RTS
.L9543
    LDA &9c6e
    INC A
    STA &9c6e
    CMP #&08
    BNE L9542
    LDA #&00
    STA &9c6e
    CLC
    LDA &a8
    ADC #&08
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    RTS
.L9561
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE L957C
    SEC
    LDA &A8
    SBC #&b0
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
    RTS
.L957C
    SEC
    LDA &A8
    SBC #&08
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
    RTS
.L958A
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE L95A5
    CLC
    LDA &A8
    ADC #&b0
    STA &A8
    LDA &A9
    ADC #&00
    STA &A9
    RTS
.L95A5
    CLC
    LDA &A8
    ADC #&08
    STA &A8
    LDA &A9
    ADC #&00
    STA &A9
    RTS
.L95B3
    LDA &7C27
    EOR #&09
    STA &7C27
    RTS
.L95BC
    LDA #&16
    STA dis_temp
    LDA #&51
    STA &ac
    LDA #&7c
    STA &ad
.L95C9
    LDA &af
    JSR L964A
    LDA &ae
    JSR L964A
    CLC
    LDA &ac
    ADC #&02
    STA &ac
    BCC L95DE
    INC &ad
.L95DE
    LDY #&00
.L95E0
    LDA (&ae),Y
    JSR L964A
    INC &ac
    BNE L95EB
    INC &ad
.L95EB
    INY
    CPY #&08
    BNE L95E0
    CLC
    LDA &ac
    ADC #&01
    STA &ac
    BCC L95FB
    INC &ad
.L95FB
    LDY #&00
.L95FD
    LDA (&ae),Y
    AND #&7f
    CMP #&20
    BCS L9607
    LDA #&2e
.L9607
    STA (&ac),Y
    INY
    CPY #&08
    BNE L95FD
    CLC
    LDA &ac
    ADC #&09
    STA &ac
    BCC L9619
    INC &ad
.L9619
    CLC
    LDA &ae
    ADC #&08
    STA &ae
    BCC L9624
    INC &af
.L9624
    DEC dis_temp
    BNE L95C9
    LDY #&00
    TYA
.L962C
    STA &7de6,Y
    INY
    INY
    INY
    CPY #&1b
    BNE L962C
    LDA &9c6e
    ASL A
    ADC &9c6e
    TAY
    LDA #&5d
    STA &7de6,Y
    LDA #&5b
    STA &7de9,Y
    RTS
.dis_temp
    EQUB &00  \ &9649: .
.L964A
    STA &965e
    LSR A
    LSR A
    LSR A
    LSR A
    TAX
    LDA &9ca6,X
    EQUB &92, &AC  \ STA (0xac)
    INC &ac
    BNE L965D
    INC &ad
.L965D
    LDA #&88
    AND #&0f
    TAX
    LDA &9ca6,X
    EQUB &92, &AC  \ STA (0xac)
    INC &ac
    BNE L966D
    INC &ad
.L966D
    RTS
.L966E
    STA &967d
    LSR A
    LSR A
    LSR A
    LSR A
    TAX
    LDA &9ca6,X
    JSR oswrch
    LDA #&62
    AND #&0f
    TAX
    LDA &9ca6,X
    JMP oswrch
\ --- Disassembler addressing mode format strings ---
\ &l = low byte, &hl = high+low bytes, &b = branch offset
.dis_addr_modes
    EQUB &81                   \ Mode 0: ??? (invalid opcode)
    EQUS "???", 0
    EQUS "#&l", 0             \ Mode 1: immediate
    EQUS "&hl", 0             \ Mode 2: absolute
    EQUS "&l", 0              \ Mode 3: zero page
    EQUS "A", 0               \ Mode 4: accumulator
    EQUS " ", 0               \ Mode 5: implied
    EQUS "(&l,X)", 0          \ Mode 6: (indirect,X)
    EQUS "(&l),Y", 0          \ Mode 7: (indirect),Y
    EQUS "&l,X", 0            \ Mode 8: zero page,X
    EQUS "&l,Y", 0            \ Mode 9: zero page,Y
    EQUS "&hl,X", 0           \ Mode 10: absolute,X
    EQUS "&hl,Y", 0           \ Mode 11: absolute,Y
    EQUS "&b", 0              \ Mode 12: relative (branch)
    EQUS "(&hl)", 0           \ Mode 13: (indirect)
    EQUS "(&hl,X)", 0         \ Mode 14: (indirect,X) 65C02
    EQUS "(&l)", 0            \ Mode 15: (indirect) 65C02 ZP
\ --- Addressing mode pointer table (16 entries, low/high pairs) ---
.dis_addr_mode_ptrs
    EQUW dis_addr_modes + &00  \ Mode 0: ???
    EQUW dis_addr_modes + &05  \ Mode 1: #&l
    EQUW dis_addr_modes + &09  \ Mode 2: &hl
    EQUW dis_addr_modes + &0D  \ Mode 3: &l
    EQUW dis_addr_modes + &10  \ Mode 4: A
    EQUW dis_addr_modes + &12  \ Mode 5: implied
    EQUW dis_addr_modes + &14  \ Mode 6: (&l,X)
    EQUW dis_addr_modes + &1B  \ Mode 7: (&l),Y
    EQUW dis_addr_modes + &22  \ Mode 8: &l,X
    EQUW dis_addr_modes + &27  \ Mode 9: &l,Y
    EQUW dis_addr_modes + &2C  \ Mode 10: &hl,X
    EQUW dis_addr_modes + &32  \ Mode 11: &hl,Y
    EQUW dis_addr_modes + &38  \ Mode 12: &b
    EQUW dis_addr_modes + &3B  \ Mode 13: (&hl)
    EQUW dis_addr_modes + &41  \ Mode 14: (&hl,X)
    EQUW dis_addr_modes + &49  \ Mode 15: (&l)
\ --- Operand byte counts per addressing mode ---
.dis_operand_sizes
    EQUB 1, 2, 3, 2, 1, 1, 2, 2, 2, 2, 3, 3, 2, 3, 3, 2
.cmd_dis
    JSR L901F
    CMP #&0d
    BEQ L9711
    JSR L93C2
    BRA L971B
.L9711
    LDA &9c6a
    STA &ae
    LDA &9c6b
    STA &af
.L971B
    LDA #&82
    JSR oswrch
    JSR oswrch
    LDA &af
    JSR L966E
    LDA &ae
    JSR L966E
    LDA #&20
    JSR oswrch
    LDY #&00
    STY &ad
    LDA (&ae),Y
    ASL A
    ROL &ad
    ASL A
    ROL &ad
    CLC
    ADC #&56
    STA &ac
    LDA &ad
    ADC #&a1
    STA &ad
    LDY #&03
    LDA (&ac),Y
    BEQ L9765
    LDA #&83
    JSR oswrch
    LDY #&00
.L9756
    LDA (&ac),Y
    JSR oswrch
    INY
    CPY #&03
    BNE L9756
    LDA #&20
    JSR oswrch
.L9765
    LDY #&03
    LDA (&ac),Y
    PHA
    ASL A
    TAX
    LDA &96d5,X
    STA &ac
    LDA &96d6,X
    STA &ad
    LDY #&ff
.L9778
    INY
    LDA (&ac),Y
    BEQ L9797
    CMP #&68
    BNE L9784
    JMP L9806
.L9784
    CMP #&6c
    BNE L978B
    JMP L9812
.L978B
    CMP #&62
    BNE L9792
    JMP L981E
.L9792
    JSR oswrch
    BRA L9778
.L9797
    LDA #&86
    JSR oswrch
    LDA &0318
    CMP #&16
    BNE L9797
    PLX
    LDA &96f5,X
    PHA
    TAX
    LDY #&00
.L97AB
    LDA (&ae),Y
    PHX
    JSR L966E
    PLX
    LDA #&20
    JSR oswrch
    INY
    DEX
    BNE L97AB
.L97BB
    LDA #&85
    JSR oswrch
    LDA &0318
    CMP #&21
    BNE L97BB
    PLX
    PHX
    LDY #&00
.L97CB
    LDA (&ae),Y
    AND #&7f
    CMP #&20
    BCS L97D5
    LDA #&2e
.L97D5
    CMP #&7f
    BNE L97DB
    LDA #&ff
.L97DB
    JSR oswrch
    INY
    DEX
    BNE L97CB
    JSR osnewl
    PLA
    CLC
    ADC &ae
    STA &ae
    BCC L97EF
    INC &af
.L97EF
    JSR osrdch
    BCS L97F7
    JMP L971B
.L97F7
    LDA &ae
    STA &9c6a
    LDA &af
    STA &9c6b
    LDA #&00
    STA &ff
    RTS
.L9806
    PHY
    LDY #&02
    LDA (&ae),Y
    JSR L966E
    PLY
    JMP L9778
.L9812
    PHY
    LDY #&01
    LDA (&ae),Y
    JSR L966E
    PLY
    JMP L9778
.L981E
    PHY
    LDY #&01
    CLC
    LDA &ae
    ADC #&02
    STA &a8
    LDA &af
    ADC #&00
    STA &a9
    LDA (&ae),Y
    BMI L9849
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JSR L966E
    LDA &a8
    JSR L966E
    PLY
    JMP L9778
.L9849
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&ff
    STA &a9
    JSR L966E
    LDA &a8
    JSR L966E
    PLY
    JMP L9778
.L9860
    LDA #&08
    JSR oswrch
    JSR oswrch
    JSR oswrch
    JSR oswrch
    JSR oswrch
    LDY #&01
    LDA (&a8),Y
    BMI L9888
    STA &9eed
    LDY #&02
    LDA (&a8),Y
    STA &9eec
    PHX
    PHY
    JSR L9EAF
    PLY
    PLX
.L9888
    RTS
.msg_now_splitting
    EQUS 13, "Now splitting line:      " : EQUB 0
.msg_now_spacing
    EQUS 13, "Now spacing out line:      " : EQUB 0
.cmd_bau
    LDA &0230
    CMP #&0c
    BEQ L98EA
    JSR copy_inline_to_stack    \ BRK error: "BAU must be called from BASIC"
    EQUS &5C, "BAU must be called from BASIC", 0
.L98EA
    STROUT msg_now_splitting
    LDA &18
    STA &a9
    LDA #&00
    STA &a8
.L98FF
    JSR L9860
.L9902
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE L990D
    JMP L9A08
.L990D
    LDY #&04
    LDA (&a8),Y
    STA &0900
    DEY
    CMP #&2e
    BNE L9936
.L9919
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE L9923
    JMP L99F6
.L9923
    CMP #&3a
    BEQ L9933
    CMP #&20
    BNE L9919
.L992B
    INY
    LDA (&a8),Y
    CMP #&20
    BEQ L992B
    DEY
.L9933
    JMP L9972
.L9936
    INY
    LDA (&a8),Y
    CMP #&3a
    BEQ L9972
    CMP #&0d
    BNE L9944
    JMP L99F6
.L9944
    CMP #&e7
    BNE L994B
    JMP L99F6
.L994B
    CMP #&dc
    BNE L9952
    JMP L99F6
.L9952
    CMP #&ee
    BNE L9959
    JMP L99F6
.L9959
    CMP #&f4
    BNE L9960
    JMP L99F6
.L9960
    CMP #&22
    BNE L9936
.L9964
    INY
    LDA (&a8),Y
    CMP #&22
    BEQ L9936
    CMP #&0d
    BNE L9964
    JMP L99F6
.L9972
    CPY #&04
    BEQ L9936
    LDA #&0d
    STA (&a8),Y
    TYA
    PHA
    SEC
    LDY #&03
    SBC (&a8),Y
    EOR #&ff
    CLC
    ADC #&04
    STA &ae
    PLA
    STA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    LDA &00
    CLC
    ADC #&02
    STA &ac
    LDA &01
    ADC #&00
    STA &ad
    SEC
    LDA &00
    SBC #&01
    STA &aa
    LDA &01
    SBC #&00
    STA &ab
.L99B0
    EQUB &B2, &AA  \ LDA (0xaa)
    EQUB &92, &AC  \ STA (0xac)
    SEC
    LDA &ac
    SBC #&01
    STA &ac
    LDA &ad
    SBC #&00
    STA &ad
    SEC
    LDA &aa
    SBC #&01
    STA &aa
    LDA &ab
    SBC #&00
    STA &ab
    CMP &a9
    BNE L99B0
    LDA &aa
    CMP &a8
    BNE L99B0
    LDA #&00
    LDY #&01
    STA (&a8),Y
    INY
    STA (&a8),Y
    LDA &ae
    INY
    STA (&a8),Y
    CLC
    LDA &00
    ADC #&03
    STA &00
    LDA &01
    ADC #&00
    STA &01
    JMP L9902
.L99F6
    LDY #&03
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP L98FF
.L9A08
    JSR osnewl
    LDA #&15
    JSR oswrch
    LDX #&20
    LDY #&9a
    JSR oscli
    LDA #&8a
    LDX #&00
    LDY #&89
    JMP osbyte
.cmd_space_key9
    EQUS "KEY9REN.|F|K|M"     \ *KEY9 definition for renumber
    EQUB &0D
.cmd_space
    LDA &0230
    CMP #&0c
    BEQ L9A55
    JSR copy_inline_to_stack    \ BRK error: "Must be called from BASIC!"
    EQUS &5C, "Must be called from BASIC!", 0
.L9A55
    LDA &18
    STA &a9
    STZ &a8
    STROUT msg_now_spacing
.L9A68
    JSR L9860
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE L9A76
    JMP L9B7A
.L9A76
    LDY #&03
.L9A78
    INY
    LDA (&a8),Y
    BMI L9A9D
    CMP #&0d
    BNE L9A84
    JMP L9B68
.L9A84
    CMP #&5b
    BNE L9A8B
    JMP L9CB6
.L9A8B
    CMP #&22
    BNE L9A78
.L9A8F
    INY
    LDA (&a8),Y
    CMP #&22
    BEQ L9A78
    CMP #&0d
    BNE L9A8F
    JMP L9B68
.L9A9D
    CMP #&8d
    BNE L9AA6
    INY
    INY
    INY
    BNE L9A78
.L9AA6
    CMP #&a7
    BEQ L9A78
    CMP #&c0
    BEQ L9A78
    CMP #&c1
    BEQ L9A78
    CMP #&b0
    BEQ L9A78
    CMP #&c2
    BEQ L9A78
    CMP #&c4
    BEQ L9A78
    CMP #&8a
    BEQ L9A78
    CMP #&f2
    BEQ L9A78
    CMP #&a4
    BEQ L9A78
    CMP #&cf
    BCC L9AD5
    CMP #&d4
    BCS L9AD5
    JMP L9A78
.L9AD5
    CMP #&8f
    BCC L9AE0
    CMP #&94
    BCS L9AE0
    JMP L9A78
.L9AE0
    CMP #&b8
    BNE L9AEE
    INY
    LDA (&a8),Y
    CMP #&50
    BEQ L9A78
    DEY
    LDA #&b8
.L9AEE
    CMP #&b3
    BNE L9AFF
    INY
    LDA (&a8),Y
    CMP #&28
    BNE L9AFC
    JMP L9A78
.L9AFC
    DEY
    LDA #&b3
.L9AFF
    CMP #&f4
    BNE L9B06
    JMP L9B68
.L9B06
    INY
    LDA (&a8),Y
    DEY
    CMP #&20
    BNE L9B11
    JMP L9A78
.L9B11
    CMP #&0d
    BNE L9B18
    JMP L9A78
.L9B18
    CMP #&3a
    BNE L9B1F
    JMP L9A78
.L9B1F
    JSR L9BAA
    PHY
    LDY #&03
    LDA (&a8),Y
    INC A
    STA (&a8),Y
    PLY
    CLC
    LDA &00
    ADC #&01
    STA &00
    LDA &01
    ADC #&00
    STA &01
    LDA #&20
    INY
    STA (&a8),Y
    DEY
    LDA (&a8),Y
    CMP #&b8
    BEQ L9B86
    CMP #&80
    BEQ L9B86
    CMP #&81
    BEQ L9B86
    CMP #&8b
    BEQ L9B86
    CMP #&82
    BEQ L9B86
    CMP #&83
    BEQ L9B86
    CMP #&84
    BEQ L9B86
    CMP #&8c
    BEQ L9B86
    CMP #&88
    BEQ L9B86
    INY
    JMP L9A78
.L9B68
    LDY #&03
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP L9A68
.L9B7A
    LDA &00
    STA &12
    LDA &01
    STA &13
    JSR osnewl
    RTS
.L9B86
    DEY
    JSR L9BAA
    PHY
    LDY #&03
    LDA (&a8),Y
    INC A
    STA (&a8),Y
    PLY
    CLC
    LDA &00
    ADC #&01
    STA &00
    LDA &01
    ADC #&00
    STA &01
    LDA #&20
    INY
    STA (&a8),Y
    INY
    INY
    JMP L9A78
.L9BAA
    LDA &a8
    PHA
    LDA &a9
    PHA
    TYA
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    LDA &00
    STA &ac
    LDA &01
    STA &ad
    SEC
    LDA &00
    SBC #&01
    STA &aa
    LDA &01
    SBC #&00
    STA &ab
.L9BD1
    EQUB &B2, &AA  \ LDA (0xaa)
    EQUB &92, &AC  \ STA (0xac)
    SEC
    LDA &ac
    SBC #&01
    STA &ac
    LDA &ad
    SBC #&00
    STA &ad
    SEC
    LDA &aa
    SBC #&01
    STA &aa
    LDA &ab
    SBC #&00
    STA &ab
    CMP &a9
    BNE L9BD1
    LDA &aa
    CMP &a8
    BNE L9BD1
    PLA
    STA &a9
    PLA
    STA &a8
    RTS
.cmd_lvar
    LDA &0230
    CMP #&0c
    BEQ L9C23
    JSR copy_inline_to_stack    \ BRK error: "VAR works only in BASIC"
    EQUS &4C, "VAR works only in BASIC", 0
.L9C23
    LDX #&00
.L9C25
    LDA &0480,X
    STA &a8
    INX
    LDA &0480,X
    DEX
    STA &a9
    CMP #&00
    BEQ L9C5F
.L9C35
    TXA
    LSR A
    CLC
    ADC #&40
    JSR oswrch
    LDY #&01
.L9C3F
    INY
    LDA (&a8),Y
    BEQ L9C49
    JSR oswrch
    BRA L9C3F
.L9C49
    JSR osnewl
    LDY #&01
    LDA (&a8),Y
    BEQ L9C5F
    STA &ac
    DEY
    LDA (&a8),Y
    STA &a8
    LDA &ac
    STA &a9
    BRA L9C35
.L9C5F
    INX
    INX
    CPX #&80
    BNE L9C25
    RTS
\ --- MEM editor configuration data ---
.mem_workspace
    EQUB &00, &00, &00         \ Workspace variables
    EQUB &12, &E3, &16         \ VDU codes: text window? mode?
    EQUB &01, &03              \ Colour settings
.mem_column
    EQUB &02                   \ MEM column counter (0-7)
    EQUB &88, &89, &8A, &8B   \ Key codes: left, right, down, up
    EQUB &09                   \ TAB key
    EQUW L952B                 \ Address of cursor-up routine
    EQUW L9543                 \ Address of cursor-down routine
    EQUW L958A                 \ Address of page-down routine
    EQUW L9561                 \ Address of page-up routine
    EQUW L95B3                 \ Address of hex/ascii toggle
\ --- MEM editor header display (uses VDU control codes) ---
.mem_header
    EQUB &82 : EQUS "ADDR " : EQUB &94
    EQUS ",,,,,,"
    EQUB &82 : EQUS "HEX CODE" : EQUB &94
    EQUS ",,,,,,, "
    EQUB &82 : EQUS "ASCII " : EQUB &85
\ --- Hex digit lookup table ---
.hex_digits
    EQUS "A0123456789ABCDEF"
.L9CB6
    INY
.L9CB7
    LDA #&00
    STA &a154
    LDA (&a8),Y
    CMP #&0d
    BNE L9CC5
    JMP L9D63
.L9CC5
    CMP #&2e
    BNE L9CDE
.L9CC9
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE L9CD3
    JMP L9D63
.L9CD3
    CMP #&20
    BEQ L9CDB
    CMP #&3a
    BNE L9CC9
.L9CDB
    INY
    BRA L9CB7
.L9CDE
    CMP #&22
    BNE L9CF0
.L9CE2
    INY
    LDA (&a8),Y
    CMP #&0d
    BEQ L9D63
    CMP #&22
    BNE L9CE2
    INY
    BRA L9CB7
.L9CF0
    JSR L9E7F
    BCS L9D1D
    CMP #&3a
    BNE L9CFC
    INY
    BRA L9CB7
.L9CFC
    CMP #&5d
    BNE L9D03
    JMP L9D85
.L9D03
    CMP #&5c
    BNE L9D18
.L9D07
    INY
    LDA (&a8),Y
    CMP #&3a
    BEQ L9D15
    CMP #&0d
    BNE L9D07
    JMP L9D63
.L9D15
    INY
    BRA L9CB7
.L9D18
    LDA #&03
    STA &a154
.L9D1D
    INY
    LDA (&a8),Y
    CMP #&5d
    BEQ L9D85
    CMP #&0d
    BEQ L9D63
    DEC &a154
    BNE L9D1D
    CMP #&3a
    BEQ L9CB7
    CMP #&20
    BEQ L9D54
    DEY
    JSR L9BAA
    PHY
    LDY #&03
    LDA (&a8),Y
    INC A
    STA (&a8),Y
    PLY
    CLC
    LDA &00
    ADC #&01
    STA &00
    LDA &01
    ADC #&00
    STA &01
    LDA #&20
    INY
    STA (&a8),Y
.L9D54
    INY
    LDA (&a8),Y
    CMP #&0d
    BEQ L9D63
    CMP #&3a
    BNE L9D54
    INY
    JMP L9CB7
.L9D63
    LDY #&03
    CLC
    LDA (&a8),Y
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JSR L9860
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE L9D80
    JMP L9B7A
.L9D80
    LDY #&04
    JMP L9CB7
.L9D85
    JMP L9A78
.L9D88
    LDA #&54
    STA &AC
    LDA #&ae
    STA &AD
    INC xi_alias_count
    LDA xi_alias_count
    BNE L9D9D
    LDA #&ff
    STA xi_alias_count
.L9D9D
    INC xi_cursor_pos
    SEC
    LDA &AC
    SBC xi_cursor_pos
    STA &AE
    LDA &AD
    SBC #&00
    STA &AF
    DEC xi_cursor_pos
    LDA #&0d
    STA alias_end_lo
    LDA #&ff
    STA alias_end_hi
.L9DBB
    EQUB &B2, &AE  \ LDA (&ae)
    EQUB &92, &AC  \ STA (&ac)
    SEC
    LDA &AC
    SBC #&01
    STA &AC
    LDA &AD
    SBC #&00
    STA &AD
    SEC
    LDA &AE
    SBC #&01
    STA &AE
    LDA &AF
    SBC #&00
    STA &AF
    LDA &AE
    CMP #&54
    BNE L9DBB
    LDA &AF
    CMP #&aa
    BNE L9DBB
    LDY xi_cursor_pos
    BEQ L9DF7
    LDY #&00
.L9DEC
    LDA (&a8),Y
    STA &aa55,Y
    INY
    CPY xi_cursor_pos
    BNE L9DEC
.L9DF7
    LDA #&0d
    STA alias_buffer,Y
    RTS
.xi_scroll_count
    EQUB &A6                   \ &9DFD: scroll counter variable
.L9DFE
    LDA #&0D
    STA alias_end_hi
    LDA xi_scroll_count
    CMP #&FF
    BNE L9E0F
    LDA #&00
    STA xi_scroll_count
.L9E0F
    CMP xi_alias_count
    BCC L9E1B
    LDA xi_alias_count
    DEC A
    STA xi_scroll_count
.L9E1B
    LDA #&55
    STA &AE
    LDA #&aa
    STA &AF
    LDX xi_scroll_count
    BNE L9E4A
.L9E28
    JSR L872A
    EQUB &B2, &AE  \ LDA (&ae)
    CMP #&0d
    BNE L9E34
    JMP L852F
.L9E34
    LDY #&ff
.L9E36
    INY
    LDA (&ae),Y
    STA xi_char
    CMP #&0d
    BNE L9E43
    JMP L852F
.L9E43
    PHY
    JSR L85D9
    PLY
    BRA L9E36
.L9E4A
    LDY #&00
.L9E4C
    LDA (&ae),Y
    CMP #&0d
    BEQ L9E5D
    INY
    BNE L9E4C
    LDA #&00
    STA xi_scroll_count
    JMP L9DFE
.L9E5D
    INY
    TYA
    CLC
    ADC &AE
    STA &AE
    LDA &AF
    ADC #&00
    STA &AF
    DEX
    BEQ L9E28
    CMP #&ae
    BCC L9E4A
    LDA &AE
    CMP #&55
    BCC L9E4A
    LDA #&00
    STA xi_scroll_count
    JMP L9DFE
.L9E7F
    CMP #&45
    BNE L9E8A
    LDA #&04
    STA &a154
    BRA L9EAD
.L9E8A
    CMP #&80
    BNE L9E95
    LDA #&01
    STA &a154
    BRA L9EAD
.L9E95
    CMP #&82
    BNE L9EA0
    LDA #&01
    STA &a154
    BRA L9EAD
.L9EA0
    CMP #&84
    BNE L9EAB
    LDA #&02
    STA &a154
    BRA L9EAD
.L9EAB
    CLC
    RTS
.L9EAD
    SEC
    RTS
.L9EAF
    LDY #&00
.L9EB1
    LDX #&10
    LDA #&00
.L9EB5
    ASL &9eec
    ROL &9eed
    ROL A
    CMP #&0a
    BCC L9EC5
    SBC #&0a
    INC &9eec
.L9EC5
    DEX
    BNE L9EB5
    CLC
    ADC #&30
    PHA
    INY
    LDA &9eec
    ORA &9eed
    BNE L9EB1
.L9ED5
    CPY #&05
    BEQ L9EDF
    LDA #&20
    PHA
    INY
    BNE L9ED5
.L9EDF
    STY &9eee
.L9EE2
    PLA
    JSR oswrch
    DEC &9eee
    BNE L9EE2
    RTS
    EQUB &00, &00, &00, &00
.features_text
    EQUS "In addition to the commands shown under *HELP XMOS,  several  extended keyboard facilities are available whilst in *XON mode.", 13
    EQUB 13
    EQUS "Input can now be edited using the arrow keys, offering insert/delete facilities and replacing normal cursor editing. In this mode,  COPY  deletes the character under the cursor.", 13
    EQUS "Normal cursor editing, if required, can be  activated by pressing a  cursor key on a blank line.", 13
    EQUB 13
    EQUS "Typing a line number  and then pressing TAB calls up that line for editing.", 13
    EQUS "A record  of past input can be recalled using SHIFT-up and SHIFT-down.", 13
    EQUS "Typing SAVE while in BASIC will execute the equivalent of *S."
    EQUB 0

\ Remaining ROM data
    EQUB &00
.xi_alias_count
    EQUB &FF, &42, &52, &4B, &05, &4F, &52, &41, &06, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &54, &53, &42, &03, &4F, &52, &41, &03, &41, &53, &4C, &03, &00, &00
    EQUB &00, &00, &50, &48, &50, &05, &4F, &52, &41, &01, &41, &53, &4C, &04, &00, &00
    EQUB &00, &00, &54, &53, &42, &02, &4F, &52, &41, &02, &41, &53, &4C, &02, &00, &00
    EQUB &00, &00, &42, &50, &4C, &0C, &4F, &52, &41, &07, &4F, &52, &41, &0F, &00, &00
    EQUB &00, &00, &54, &52, &42, &03, &4F, &52, &41, &08, &41, &53, &4C, &08, &00, &00
    EQUB &00, &00, &43, &4C, &43, &05, &4F, &52, &41, &0B, &49, &4E, &43, &04, &00, &00
    EQUB &00, &00, &54, &52, &42, &02, &4F, &52, &41, &0A, &41, &53, &4C, &0A, &00, &00
    EQUB &00, &00, &4A, &53, &52, &02, &41, &4E, &44, &06, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &42, &49, &54, &03, &41, &4E, &44, &03, &52, &4F, &4C, &03, &00, &00
    EQUB &00, &00, &50, &4C, &50, &05, &41, &4E, &44, &01, &52, &4F, &4C, &04, &00, &00
    EQUB &00, &00, &42, &49, &54, &02, &41, &4E, &44, &02, &52, &4F, &4C, &02, &00, &00
    EQUB &00, &00, &42, &4D, &49, &0C, &41, &4E, &44, &07, &41, &4E, &44, &0F, &00, &00
    EQUB &00, &00, &42, &49, &54, &08, &41, &4E, &44, &08, &52, &4F, &4C, &08, &00, &00
    EQUB &00, &00, &53, &45, &43, &05, &41, &4E, &44, &0B, &44, &45, &43, &04, &00, &00
    EQUB &00, &00, &42, &49, &54, &09, &41, &4E, &44, &0A, &52, &4F, &4C, &0A, &00, &00
    EQUB &00, &00, &52, &54, &49, &05, &45, &4F, &52, &06, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00
    EQUB &45, &4F, &52, &03, &4C, &53, &52, &03, &00, &00, &00, &00, &50, &48, &41, &05
    EQUB &45, &4F, &52, &01, &4C, &53, &52, &04, &00, &00, &00, &00, &4A, &4D, &50, &02
    EQUB &45, &4F, &52, &02, &4C, &53, &52, &02, &00, &00, &00, &00, &42, &56, &43, &0C
    EQUB &45, &4F, &52, &07, &45, &4F, &52, &0F, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &45, &4F, &52, &08, &4C, &53, &52, &08, &00, &00, &00, &00, &43, &4C, &49, &05
    EQUB &45, &4F, &52, &0B, &50, &48, &59, &05, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &45, &4F, &52, &0A, &4C, &53, &52, &0A, &00, &00, &00, &00, &52, &54, &53, &05
    EQUB &41, &44, &43, &06, &00, &00, &00, &00, &00, &00, &00, &00, &53, &54, &5A, &03
    EQUB &41, &44, &43, &03, &52, &4F, &52, &03, &00, &00, &00, &00, &50, &4C, &41, &05
    EQUB &41, &44, &43, &01, &52, &4F, &52, &04, &00, &00, &00, &00, &4A, &4D, &50, &0D
    EQUB &41, &44, &43, &02, &52, &4F, &52, &02, &00, &00, &00, &00, &42, &56, &53, &0C
    EQUB &41, &44, &43, &07, &41, &44, &43, &0F, &00, &00, &00, &00, &53, &54, &5A, &08
    EQUB &41, &44, &43, &08, &52, &4F, &52, &08, &00, &00, &00, &00, &53, &45, &49, &05
    EQUB &41, &44, &43, &0B, &50, &4C, &59, &05, &00, &00, &00, &00, &4A, &4D, &50, &0E
    EQUB &41, &44, &43, &0A, &52, &4F, &52, &0A, &00, &00, &00, &00, &42, &52, &41, &0C
    EQUB &53, &54, &41, &06, &00, &00, &00, &00, &00, &00, &00, &00, &53, &54, &59, &03
    EQUB &53, &54, &41, &03, &53, &54, &58, &03, &00, &00, &00, &00, &44, &45, &59, &05
    EQUB &42, &49, &54, &01, &54, &58, &41, &05, &00, &00, &00, &00, &53, &54, &59, &02
    EQUB &53, &54, &41, &02, &53, &54, &58, &02, &00, &00, &00, &00, &42, &43, &43, &0C
    EQUB &53, &54, &41, &07, &53, &54, &41, &0F, &00, &00, &00, &00, &53, &54, &59, &08
    EQUB &53, &54, &41, &08, &53, &54, &58, &09, &00, &00, &00, &00, &54, &59, &41, &05
    EQUB &53, &54, &41, &0B, &54, &58, &53, &05, &00, &00, &00, &00, &53, &54, &5A, &02
    EQUB &53, &54, &41, &0A, &53, &54, &5A, &0A, &00, &00, &00, &00, &4C, &44, &59, &01
    EQUB &4C, &44, &41, &06, &4C, &44, &58, &01, &00, &00, &00, &00, &4C, &44, &59, &03
    EQUB &4C, &44, &41, &03, &4C, &44, &58, &03, &00, &00, &00, &00, &54, &41, &59, &05
    EQUB &4C, &44, &41, &01, &54, &41, &58, &05, &00, &00, &00, &00, &4C, &44, &59, &02
    EQUB &4C, &44, &41, &02, &4C, &44, &58, &02, &00, &00, &00, &00, &42, &43, &53, &0C
    EQUB &4C, &44, &41, &07, &4C, &44, &41, &0F, &00, &00, &00, &00, &4C, &44, &59, &08
    EQUB &4C, &44, &41, &08, &4C, &44, &58, &09, &00, &00, &00, &00, &43, &4C, &56, &05
    EQUB &4C, &44, &41, &0B, &54, &53, &58, &05, &00, &00, &00, &00, &4C, &44, &59, &0A
    EQUB &4C, &44, &41, &0A, &4C, &44, &58, &0B, &00, &00, &00, &00, &43, &50, &59, &01
    EQUB &43, &4D, &50, &06, &00, &00, &00, &00, &00, &00, &00, &00, &43, &50, &59, &03
    EQUB &43, &4D, &50, &03, &44, &45, &43, &03, &00, &00, &00, &00, &49, &4E, &59, &05
    EQUB &43, &4D, &50, &01, &44, &45, &58, &05, &00, &00, &00, &00, &43, &50, &59, &02
    EQUB &43, &4D, &50, &02, &44, &45, &43, &02, &00, &00, &00, &00, &42, &4E, &45, &0C
    EQUB &43, &4D, &50, &07, &43, &4D, &50, &0F, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &43, &4D, &50, &08, &44, &45, &43, &08, &00, &00, &00, &00, &43, &4C, &44, &05
    EQUB &43, &4D, &50, &0B, &50, &48, &58, &05, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &43, &4D, &50, &0A, &44, &45, &43, &0A, &00, &00, &00, &00, &43, &50, &58, &01
    EQUB &53, &42, &43, &06, &00, &00, &00, &00, &00, &00, &00, &00, &43, &50, &58, &03
    EQUB &53, &42, &43, &03, &49, &4E, &43, &03, &00, &00, &00, &00, &49, &4E, &58, &05
    EQUB &53, &42, &43, &01, &4E, &4F, &50, &05, &00, &00, &00, &00, &43, &50, &58, &02
    EQUB &53, &42, &43, &02, &49, &4E, &43, &02, &00, &00, &00, &00, &42, &45, &51, &0C
    EQUB &53, &42, &43, &07, &53, &42, &43, &0F, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &53, &42, &43, &08, &49, &4E, &43, &08, &00, &00, &00, &00, &53, &45, &44, &05
    EQUB &53, &42, &43, &0B, &50, &4C, &58, &05, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &53, &42, &43, &0A, &49, &4E, &43, &0A, &00, &00, &00, &00, &4B, &45, &59, &39
    EQUS " *SRSAVE XMos 8000+4000 7Q|M"
    EQUB &0D, &4D, &0D, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A
    EQUS "************************************************************"
    EQUS "************************************************************"
    EQUS "************************************************************"
    EQUS "***************************"
    EQUB &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &22
    EQUB &22, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80
    EQUB &80, &80, &69, &8A, &90, &7E, &7A, &A9, &19, &69, &74, &22, &0D, &26, &8A, &90
    EQUB &7E, &7A, &A9, &19, &6F, &61, &64, &65, &72, &22, &0D, &43, &48, &2E, &22, &4D
    EQUB &65, &64, &69, &74, &22, &0D, &26, &8A, &90, &7E, &7A, &A9, &19, &61, &64, &65
    EQUB &72, &22, &0D, &43, &48, &2E, &22, &4D, &65, &64, &69, &74, &22, &0D, &26, &8A
    EQUB &90, &7E, &7A, &A9, &19, &50, &41, &47, &45, &3D, &26, &32, &38, &30, &30, &0D
    EQUB &4C, &4F, &2E, &22, &53, &72, &63, &43, &6F, &64, &65, &22, &0D, &43, &48, &2E
    EQUB &22, &4D, &61, &6B, &65, &4D, &61, &70, &22, &0D, &43, &48, &2E, &22, &4C, &6F
    EQUB &61, &64, &65, &72, &22, &0D, &43, &48, &2E, &22, &4D, &65, &64, &69, &74, &22
    EQUB &0D, &26, &8A, &90, &7E, &7A, &A9, &19, &61, &6B, &65, &4D, &61, &70, &22, &0D
    EQUB &43, &48, &2E, &22, &4C, &6F, &61, &64, &65, &72, &22, &0D, &43, &48, &2E, &22
    EQUB &4D, &65, &64, &69, &74, &22, &0D, &26, &A9, &82, &85, &A9, &A0, &00, &B2, &A8
    EQUB &C9, &FF, &F0, &43, &A9, &20, &20, &E3, &FF, &20, &E3, &FF, &B1, &A8, &F0, &06
    EQUB &20, &E3, &FF, &C8, &D0, &F6, &98, &38, &E9, &09, &49, &FF, &1A, &AA, &A9, &20
    EQUB &20, &E3, &FF, &CA, &D0, &F8, &C8, &C8, &C8, &88, &C8, &B1, &A8, &F0, &05, &20
    EQUB &00, &00, &00, &00, &00, &00, &00
    EQUB &C8, &18, &98, &65, &A8, &85, &A8, &A5, &A9, &69, &00, &85, &A9, &4C, &CC, &80
    EQUB &7A, &FA, &68, &60, &A9, &86, &85, &A8, &A9, &80, &85, &A9, &7A, &5A, &20, &26
    EQUB &8A, &90, &20, &7A, &A9, &F0, &85, &A8, &A9, &9E, &85, &A9, &A0, &00, &B1, &A8
    EQUB &F0, &0A, &20, &E3, &FF, &C8, &D0, &F6, &E6, &A9, &80, &F2, &20, &E7, &FF, &7A
    EQUB &FA, &68, &60, &7A, &A9, &19, &85, &A8, &A9, &82, &85, &A9, &5A, &20, &26, &8A
    EQUB &B0, &2C, &A0, &00, &C8, &B1, &A8, &D0, &FB, &C8, &C8, &C8, &C8, &B1, &A8, &D0
    EQUB &FB, &C8, &18, &98, &65, &A8, &85, &A8, &A5, &A9, &69, &00, &85, &A9, &7A, &B2
    EQUB &A8, &C9, &FF, &D0, &D7, &A9, &0F, &20, &E3, &FF, &7A, &FA, &68, &60, &7A, &A9
    EQUB &20, &20, &E3, &FF, &20, &E3, &FF, &A0, &FF, &C8, &B1, &A8, &20, &E3, &FF, &C9
    EQUB &00, &D0, &F6, &98, &38, &E9, &09, &49, &FF, &1A, &AA, &A9, &20, &20, &E3, &FF
    EQUB &CA, &D0, &F8, &C8, &C8, &C8, &B1, &A8, &F0, &06, &20, &E3, &FF, &C8, &D0, &F6
    EQUB &20, &E7, &FF, &7A, &FA, &68, &60, &48, &DA, &5A, &A9, &19, &85, &A8, &A9, &82
    EQUB &85, &A9, &5A, &B2, &A8, &C9, &FF, &F0, &25, &20, &26, &8A, &B0, &24, &A0, &00
    EQUB &C8, &B1, &A8, &D0, &FB, &C8, &C8, &C8, &C8, &B1, &A8, &D0, &FB, &C8, &98, &18
    EQUB &65, &A8, &85, &A8, &A5, &A9, &69, &00, &85, &A9, &7A, &4C, &C9, &81, &7A, &4C
    EQUB &B8, &91, &7A, &A0, &00, &C8, &B1, &A8, &D0, &00, &00, &00, &00, &00, &00, &82
    EQUB &C8, &B1, &A8, &8D, &18, &82, &20, &16, &82, &7A, &FA, &68, &A9, &00, &60, &4C
    EQUB &46, &93, &41, &4C, &49, &41, &53, &00, &33, &90, &3C, &61, &6C, &69, &61, &73
    EQUS " name> <alias>"
    EQUB &00, &41, &4C, &49, &41, &53, &45, &53, &00, &41, &91, &53, &68, &6F, &77, &73
    EQUS " active aliases"
    EQUB &00, &41, &4C, &49, &43, &4C, &52, &00, &40, &93, &43, &6C, &65, &61, &72, &73
    EQUS " all aliases"
    EQUB &00, &41, &4C, &49, &4C, &44, &00, &85, &92, &4C, &6F, &61, &64, &73, &20, &61
    EQUS "lias file"
    EQUB &00, &41, &4C, &49, &53, &56, &00, &E1, &92, &53, &61, &76, &65, &73, &20, &61
    EQUS "lias file"
    EQUB &00, &42, &41, &55, &00, &C1, &98, &53, &70, &6C, &69, &74, &73, &20, &74, &6F
    EQUS " single commands"
    EQUB &00, &44, &45, &46, &4B, &45, &59, &53, &00, &78, &8F, &44, &65, &66, &69, &6E
    EQUS "es new keys"
    EQUB &00, &44, &49, &53, &00, &05, &97, &3C, &61, &64, &64, &72, &3E, &20, &2D, &20
    EQUS "disassemble memory"
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUS "core name"
    EQUB &00, &53, &50, &41, &43, &45, &00, &2F, &9A, &49, &6E, &73, &65, &72, &74, &73
    EQUS " spaces into programs"
    EQUB &00, &53, &54, &4F, &52, &45, &00, &46, &93, &4B
.alias_buffer
    EQUB &2A, &53, &52, &53, &41, &56
    EQUS "E XMOS 8000+4000 7 Q"
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &2A, &4B
    EQUB &45, &59, &4F, &46, &46, &0D, &2A, &4B, &45, &59, &4F, &46, &0D, &2A, &53, &54
    EQUB &4F, &52, &45, &0D, &2A, &48, &2E, &58, &4D, &4F, &53, &0D, &0D, &2A, &4B, &45
    EQUB &59, &20, &31, &35, &0D, &2A, &4B, &45, &59, &20, &31, &0D, &2A, &4B, &45, &59
    EQUB &20, &31, &36, &0D, &2A, &4B, &45, &59, &20, &31, &34, &0D, &2A, &4B, &45, &59
    EQUB &20, &31, &33, &0D, &2A, &4B, &45, &59, &20, &31, &32, &0D, &2A, &4B, &45, &59
    EQUB &20, &31, &31, &0D, &2A, &4B, &45, &59, &20, &31, &30, &0D, &2A, &4B, &45, &59
    EQUB &20, &39, &0D, &2A, &4B, &45, &59, &20, &38, &0D, &2A, &4B, &45, &59, &20, &37
    EQUB &0D, &2A, &4B, &45, &59, &20, &36, &0D, &2A, &4B, &45, &59, &20, &35, &0D, &2A
    EQUB &4B, &45, &59, &20, &34, &0D, &2A, &4B, &45, &59, &20, &33, &0D, &2A, &4B, &45
    EQUB &59, &20, &32, &0D, &2A, &4B, &45, &59, &20, &31, &0D, &2A, &4B, &45, &59, &20
    EQUB &30, &0D, &4F, &53, &43, &4C, &49, &22, &53, &61, &76, &65, &20, &47, &61, &6D
    EQUB &65, &20, &31, &31, &30, &30, &20, &22, &2B, &53, &54, &52, &24, &7E, &50, &25
    EQUB &2B, &22, &20, &22, &2B, &53, &54, &52, &24, &7E, &73, &74, &61, &72, &74, &0D
    EQUS "*SHOW 10"
    EQUB &0D, &2A, &53, &48, &4F, &57, &0D, &2A, &48, &2E, &4D, &4F, &53, &0D, &2A, &4B
    EQUB &45, &59, &53, &0D, &2A, &4B, &45, &59, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &41, &4E
    EQUB &44, &80, &00, &41, &42, &53, &94, &00, &41, &43, &53, &95, &00, &41, &44, &56
    EQUB &41, &4C, &96, &00, &41, &53, &43, &97, &00, &41, &53, &4E, &98, &00, &41, &54
    EQUB &4E, &99, &00, &41, &55, &54, &4F, &C6, &10, &42, &47, &45, &54, &9A, &01, &42
    EQUB &50, &55, &54, &D5, &03, &43, &4F, &4C, &4F, &55, &52, &FB, &02, &43, &41, &4C
    EQUB &4C, &D6, &02, &43, &48, &41, &49, &4E, &D7, &02, &43, &48, &52, &24, &BD, &00
    EQUB &43, &4C, &45, &41, &52, &D8, &01, &43, &4C, &4F, &53, &45, &D9, &03, &43, &4C
    EQUB &47, &DA, &01, &43, &4C, &53, &DB, &01, &43, &4F, &53, &9B, &00, &43, &4F, &55
    EQUB &4E, &54, &9C, &01, &43, &4F, &4C, &4F, &52, &FB, &02, &44, &41, &54, &41, &DC
    EQUB &20, &44, &45, &47, &9D, &00, &44, &45, &46, &DD, &00, &44, &45, &4C, &45, &54
    EQUB &45, &C7, &10, &44, &49, &56, &81, &00, &44, &49, &4D, &DE, &02, &44, &52, &41
    EQUB &57, &DF, &02, &45, &4E, &44, &50, &52, &4F, &43, &E1, &01, &45, &4E, &44, &E0
    EQUB &01, &45, &4E, &56, &45, &4C, &4F, &50, &45, &E2, &02, &45, &4C, &53, &45, &8B
    EQUB &14, &45, &56, &41, &4C, &A0, &00, &45, &52, &4C, &9E, &01, &45, &52, &52, &4F
    EQUB &52, &85, &04, &45, &4F, &46, &C5, &01, &45, &4F, &52, &82, &00, &45, &52, &52
    EQUB &9F, &01, &45, &58, &50, &A1, &00, &45, &58, &54, &A2, &01, &45, &44, &49, &54
    EQUB &CE, &10, &46, &4F, &52, &E3, &02, &46, &41, &4C, &53, &45, &A3, &01, &46, &4E
    EQUB &A4, &08, &47, &4F, &54, &4F, &E5, &12, &47, &45, &54, &24, &BE, &00, &47, &45
    EQUB &54, &A5, &00, &47, &4F, &53, &55, &42, &E4, &12, &47, &43, &4F, &4C, &E6, &02
    EQUB &48, &49, &4D, &45, &4D, &93, &43, &49, &4E, &50, &55, &54, &E8, &02, &49, &46
    EQUB &E7, &02, &49, &4E, &4B, &45, &59, &24, &BF, &00, &49, &4E, &4B, &45, &59, &A6
    EQUB &00, &49, &4E, &54, &A8, &00, &49, &4E, &53, &54, &52, &28, &A7, &00, &4C, &49
    EQUB &53, &54, &C9, &10, &4C, &49, &4E, &45, &86, &00, &4C, &4F, &41, &44, &C8, &02
    EQUB &4C, &4F, &4D, &45, &4D, &92, &43, &4C, &4F, &43, &41, &4C, &EA, &02, &4C, &45
    EQUB &46, &54, &24, &28, &C0, &00, &4C, &45, &4E, &A9, &00, &4C, &45, &54, &E9, &04
    EQUB &4C, &4F, &47, &AB, &00, &4C, &4E, &AA, &00, &4D, &49, &44, &24, &28, &C1, &00
    EQUB &4D, &4F, &44, &45, &EB, &02, &4D, &4F, &44, &83, &00, &4D, &4F, &56, &45, &EC
    EQUB &02, &4E, &45, &58, &54, &ED, &02, &4E, &45, &57, &CA, &01, &4E, &4F, &54, &AC
    EQUB &00, &4F, &4C, &44, &CB, &01, &4F, &4E, &EE, &02, &4F, &46, &46, &87, &00, &4F
    EQUB &52, &84, &00, &4F, &50, &45, &4E, &49, &4E, &8E, &00, &4F, &50, &45, &4E, &4F
    EQUB &55, &54, &AE, &00, &4F, &50, &45, &4E, &55, &50, &AD, &00, &4F, &53, &43, &4C
    EQUB &49, &FF, &02, &50, &52, &49, &4E, &54, &F1, &02, &50, &41, &47, &45, &90, &43
    EQUB &50, &54, &52, &8F, &43, &50, &49, &AF, &01, &50, &4C, &4F, &54, &F0, &02, &50
    EQUB &4F, &49, &4E, &54, &28, &B0, &00, &50, &52, &4F, &43, &F2, &0A, &50, &4F, &53
    EQUB &B1, &01, &52, &45, &54, &55, &52, &4E, &F8, &01, &52, &45, &50, &45, &41, &54
    EQUB &F5, &00, &52, &45, &50, &4F, &52, &54, &F6, &01, &52, &45, &41, &44, &F3, &02
    EQUB &52, &45, &4D, &F4, &20, &52, &55, &4E, &F9, &01, &52, &41, &44, &B2, &00, &52
    EQUB &45, &53, &54, &4F, &52, &45, &F7, &12, &52, &49, &47, &48, &54, &24, &28, &C2
    EQUB &00, &52, &4E, &44, &B3, &01, &52, &45, &4E, &55, &4D, &42, &45, &52, &CC, &10
    EQUB &53, &54, &45, &50, &88, &00, &53, &41, &56, &45, &CD, &02, &53, &47, &4E, &B4
    EQUB &00, &53, &49, &4E, &B5, &00, &53, &51, &52, &B6, &00, &53, &50, &43, &89, &00
    EQUB &53, &54, &52, &24, &C3, &00, &53, &54, &52, &49, &4E, &47, &24, &28, &C4, &00
    EQUB &53, &4F, &55, &4E, &44, &D4, &02, &53, &54, &4F, &50, &FA, &01, &54, &41, &4E
    EQUB &B7, &00, &54, &48, &45, &4E, &8C, &14, &54, &4F, &B8, &00, &54, &41, &42, &28
    EQUB &8A, &00, &54, &52, &41, &43, &45, &FC, &12, &54, &49, &4D, &45, &91, &43, &54
    EQUB &52, &55, &45, &B9, &01, &55, &4E, &54, &49, &4C, &FD, &02, &55, &53, &52, &BA
    EQUB &00, &56, &44, &55, &EF, &02, &56, &41, &4C, &BB, &00, &56, &50, &4F, &53, &BC
    EQUB &01, &57, &49, &44, &54, &48, &FE, &02, &50, &41, &47, &45, &D0, &00, &50, &54
    EQUB &52, &CF, &00, &54, &49, &4D, &45, &D1, &00, &4C, &4F, &4D, &45, &4D, &D2, &00
    EQUB &48, &49, &4D, &45, &4D, &D3, &00, &4D, &69, &73, &73, &69, &6E, &67, &FF, &4F
    EQUB &00, &16, &53, &41, &56, &45, &7C, &4D, &43, &48, &2E, &22, &43, &6F, &72, &65
    EQUB &22, &7C, &4D, &0D, &42, &52, &45, &41, &4B, &00, &1E, &2A, &4B, &45, &59, &31
    EQUS "0 %0||M|M*STORE|M"
    EQUB &0D, &4D, &41, &4B, &45, &00, &1F, &2A, &53, &53, &41, &56, &45, &20, &25, &30
    EQUB &7C, &4D, &43, &48, &2E, &22, &43, &52, &45, &41, &54, &45, &22, &7C, &4D, &0D
    EQUB &53, &50, &52, &00, &34, &4D, &4F, &44, &45, &31, &3A, &56, &44, &55, &31, &39
    EQUS ",1,1;0;19,2,2;0;19,3,3;0;:*SED.%0|M"
    EQUB &0D, &55, &50, &44, &41, &54, &45, &00, &24, &2A, &53, &52, &53, &41, &56, &45
    EQUS " XMos 8000+4000 7Q|M"
    EQUB &0D, &FF, &45, &54, &55, &50, &54, &45, &00, &24, &2A, &53, &52, &53, &41, &56
    EQUS "E XMos 8000+4000 7Q|M"
    EQUB &0D, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
SAVE "build.rom", &8000, &C000
