\ ============================================================================
\ XMOS — MOS Extension ROM
\ By Richard Talbot-Watkins and Matt Godbolt, 1992
\ Reverse engineered disassembly
\ ============================================================================

CPU 1  \ 65C02

INCLUDE "constants.asm"

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
\ --- Workspace variables (within ROM, self-modified) ---
.xon_flag
    EQUB &FF                   \ non-zero = XON active
.cursor_col
    EQUB &1A                   \ cursor column (extended input state)
.cursor_max_col
    EQUB &1A                   \ max column
.cursor_cr
    EQUB &0D                   \ CR character
.cursor_bs
    EQUB &08                   \ backspace character

\ ============================================================================
\ Post-reset handler (service call &27)
\ ============================================================================
.handle_reset
    PHA
    PHX
    PHY
    LDA &0df0,X
    STA &84e0
    STX &84f6
    STA &ab
    STA &020d
    LDA #&00
    STA &aa
    STA &020c
    JSR L9379
    LDA keyon_active
    BEQ L84AC
    LDA #&00
    STA keyon_active
    JSR L8C89
.L84AC
    LDA xon_flag
    BEQ L84C1
    LDA #&04
    LDX #&01
    LDY #&00
    JSR osbyte
    LDA #&16
    LDX #&01
    JSR osbyte
.L84C1
    LDY #&00
.L84C3
    LDA &84d1,Y
    STA (&aa),Y
    INY
    CPY #&d0
    BNE L84C3
    PLY
    PLX
    PLA
    RTS
    EQUB &08, &C9, &00, &F0, &04, &28, &4C, &39, &EF, &68, &86, &AE, &84, &AF, &A9, &DB  \ &84D1: .....(L9.h......
    EQUB &85, &AB, &A9, &E0, &85, &AA, &A0, &0F, &B1, &AE, &91, &AA, &88, &10, &F9, &A5  \ &84E1: ................
    EQUB &F4, &8D, &30, &02, &A9, &07, &8D, &30, &FE, &85, &F4, &20, &0C, &85, &08, &AD  \ &84F1: ..0....0... ....
    EQUB &30, &02, &8D, &30, &FE, &85, &F4, &A9, &00, &28, &60, &AD, &7F, &84, &D0, &07  \ &8501: 0..0.....(`.....
    EQUB &A6, &AE, &A4, &AF, &4C, &39, &EF, &A9, &00, &8D, &FD, &9D, &A9, &00, &8D, &80  \ &8511: ....L9..........
    EQUB &84, &8D, &81, &84, &A8, &B1, &AA, &85, &A8, &C8, &B1, &AA, &85, &A9, &20, &E0  \ &8521: .............. .
    EQUB &FF, &8D, &82, &84, &AD, &6A, &02, &10, &09, &AD, &82, &84, &20, &EE, &FF, &4C  \ &8531: .....j...... ..L
    EQUB &2F, &85, &AD, &82, &84, &C9, &88, &D0, &03, &4C, &1C, &86, &C9, &89, &D0, &03  \ &8541: /........L......
    EQUB &4C, &36, &86, &C9, &7F, &D0, &03, &4C, &53, &86, &C9, &0D, &D0, &03, &4C, &9F  \ &8551: L6.....LS.....L.
    EQUB &86, &C9, &1B, &D0, &03, &4C, &04, &87, &C9, &15, &D0, &03, &4C, &24, &87, &C9  \ &8561: .....L......L$..
    EQUB &8B, &D0, &03, &4C, &6B, &87, &C9, &8A, &D0, &03, &4C, &D5, &87, &C9, &87, &D0  \ &8571: ...Lk.....L.....
    EQUB &03, &4C, &54, &88, &C9, &0E, &D0, &03, &20, &EE, &FF, &C9, &0F, &D0, &03, &20  \ &8581: .LT..... ...... 
    EQUB &EE, &FF, &C9, &09, &D0, &03, &4C, &AB, &88, &C9, &00, &D0, &03, &4C, &55, &87  \ &8591: ......L......LU.
    EQUB &AD, &82, &84, &C9, &20, &B0, &06, &20, &EE, &FF, &4C, &2F, &85, &A0, &03, &D1  \ &85A1: .... .. ..L/....
    EQUB &AA, &B0, &03, &4C, &2F, &85, &C8, &D1, &AA, &F0, &05, &90, &03, &4C, &2F, &85  \ &85B1: ...L/........L/.
    EQUB &AD, &80, &84, &A0, &02, &D1, &AA, &D0, &03, &4C, &2F, &85, &A9, &00, &8D, &D8  \ &85C1: .........L/.....
    EQUB &85, &20, &D9, &85, &4C, &2F, &85, &00, &38, &AD, &80, &84, &ED, &81, &84, &48  \ &85D1: . ..L/..8......H
    EQUB &F0, &0F, &AA, &AC, &80, &84, &88, &B1, &A8, &C8, &91, &A8, &88, &88, &CA, &D0  \ &85E1: ................
    EQUB &F6, &AC, &81, &84, &AD, &82, &84, &20, &EE, &FF, &91, &A8, &EE, &81, &84, &EE  \ &85F1: ....... ........
    EQUB &80, &84, &68, &F0, &15, &48, &AA, &C8, &B1, &A8, &20, &EE, &FF, &CA, &D0, &F7  \ &8601: ..h..H.... .....
    EQUB &68, &AA, &A9, &08, &20, &EE, &FF, &CA, &D0, &F8, &60, &AD, &80, &84, &D0, &05  \ &8611: h... .....`.....
    EQUB &A0, &8C, &4C, &3F, &88, &AD, &81, &84, &F0, &08, &CE, &81, &84, &A9, &08, &20  \ &8621: ..L?........... 
    EQUB &EE, &FF, &4C, &2F, &85, &AD, &80, &84, &D0, &05, &A0, &8D, &4C, &3F, &88, &AD  \ &8631: ..L/........L?..
    EQUB &81, &84, &CD, &80, &84, &F0, &08, &EE, &81, &84, &A9, &09, &20, &EE, &FF, &4C  \ &8641: ............ ..L
    EQUB &2F, &85, &AD, &81, &84, &F0, &44, &38, &AD, &80, &84, &ED, &81, &84, &48, &F0  \ &8651: /.....D8......H.
    EQUB &0E, &AA, &AC, &81, &84, &B1, &A8, &88, &91, &A8, &C8, &C8, &CA, &D0, &F6, &A9  \ &8661: ................
    EQUB &7F, &20, &EE, &FF, &CE, &81, &84, &CE, &80, &84, &AC, &81, &84, &68, &F0, &1B  \ &8671: . ...........h..
    EQUB &48, &AA, &B1, &A8, &20, &EE, &FF, &C8, &CA, &D0, &F7, &A9, &20, &20, &EE, &FF  \ &8681: H... .......  ..
    EQUB &68, &AA, &E8, &A9, &08, &20, &EE, &FF, &CA, &D0, &F8, &4C, &2F, &85, &AD, &7F  \ &8691: h.... .....L/...
    EQUB &84, &F0, &09, &A9, &04, &A2, &01, &A0, &00, &20, &F4, &FF, &AD, &30, &02, &C9  \ &86A1: ......... ...0..
    EQUB &0C, &D0, &29, &AD, &80, &84, &C9, &04, &D0, &22, &A0, &03, &B1, &A8, &D9, &00  \ &86B1: ..)......"......
    EQUB &87, &D0, &19, &88, &10, &F6, &20, &E7, &FF, &AD, &30, &02, &48, &20, &68, &8A  \ &86C1: ...... ...0.H h.
    EQUB &A9, &0D, &92, &A8, &A0, &00, &68, &8D, &30, &02, &18, &60, &38, &AD, &80, &84  \ &86D1: ......h.0..`8...
    EQUB &ED, &81, &84, &F0, &09, &AA, &A9, &09, &20, &EE, &FF, &CA, &D0, &F8, &20, &88  \ &86E1: ........ ..... .
    EQUB &9D, &AC, &80, &84, &A9, &0D, &91, &A8, &20, &E7, &FF, &18, &A2, &00, &60, &53  \ &86F1: ........ .....`S
    EQUB &41, &56, &45, &A9, &04, &A2, &01, &A0, &00, &20, &F4, &FF, &38, &AD, &80, &84  \ &8701: AVE...... ..8...
    EQUB &ED, &81, &84, &F0, &09, &AA, &A9, &09, &20, &EE, &FF, &CA, &D0, &F8, &AC, &80  \ &8711: ........ .......
    EQUB &84, &38, &60, &20, &2A, &87, &4C, &2F, &85, &AD, &80, &84, &F0, &25, &38, &AD  \ &8721: .8` *.L/.....%8.
    EQUB &80, &84, &ED, &81, &84, &F0, &09, &AA, &A9, &09, &20, &EE, &FF, &CA, &D0, &F8  \ &8731: .......... .....
    EQUB &AE, &80, &84, &A9, &7F, &20, &EE, &FF, &CA, &D0, &F8, &A9, &00, &8D, &81, &84  \ &8741: ..... ..........
    EQUB &8D, &80, &84, &60, &AD, &80, &84, &F0, &03, &4C, &2F, &85, &20, &6C, &84, &20  \ &8751: ...`.....L/. l. 
    EQUB &E7, &FF, &A0, &00, &A9, &0D, &91, &A8, &18, &60, &A9, &81, &A2, &FF, &A0, &FF  \ &8761: .........`......
    EQUB &20, &F4, &FF, &E0, &FF, &D0, &1D, &AD, &FD, &9D, &D0, &12, &AD, &D8, &85, &D0  \ &8771:  ...............
    EQUB &0D, &A9, &FF, &8D, &D8, &85, &AD, &80, &84, &F0, &06, &20, &88, &9D, &EE, &FD  \ &8781: ........... ....
    EQUB &9D, &4C, &FE, &9D, &AD, &80, &84, &D0, &05, &A0, &8F, &4C, &3F, &88, &38, &AD  \ &8791: .L.........L?.8.
    EQUB &0A, &03, &ED, &08, &03, &18, &69, &01, &8D, &82, &84, &38, &AD, &81, &84, &ED  \ &87A1: ......i....8....
    EQUB &82, &84, &90, &0B, &8D, &81, &84, &A9, &0B, &20, &EE, &FF, &4C, &2F, &85, &AE  \ &87B1: ......... ..L/..
    EQUB &81, &84, &F0, &F8, &A9, &08, &20, &EE, &FF, &CA, &D0, &F8, &A9, &00, &8D, &81  \ &87C1: ...... .........
    EQUB &84, &4C, &2F, &85, &A9, &81, &A2, &FF, &A0, &FF, &20, &F4, &FF, &E0, &FF, &D0  \ &87D1: .L/....... .....
    EQUB &18, &AD, &FD, &9D, &D0, &0D, &AD, &D8, &85, &D0, &08, &A9, &FF, &8D, &D8, &85  \ &87E1: ................
    EQUB &20, &88, &9D, &CE, &FD, &9D, &4C, &FE, &9D, &AD, &80, &84, &D0, &05, &A0, &8E  \ &87F1:  .....L.........
    EQUB &4C, &3F, &88, &38, &AD, &0A, &03, &ED, &08, &03, &18, &69, &01, &18, &6D, &81  \ &8801: L?.8.......i..m.
    EQUB &84, &B0, &10, &CD, &80, &84, &B0, &0B, &8D, &81, &84, &A9, &0A, &20, &EE, &FF  \ &8811: ............. ..
    EQUB &4C, &2F, &85, &38, &AD, &80, &84, &ED, &81, &84, &F0, &09, &AA, &A9, &09, &20  \ &8821: L/.8........... 
    EQUB &EE, &FF, &CA, &D0, &F8, &AD, &80, &84, &8D, &81, &84, &4C, &2F, &85, &5A, &A9  \ &8831: ...........L/.Z.
    EQUB &04, &A2, &00, &A0, &00, &20, &F4, &FF, &7A, &A9, &8A, &A2, &00, &20, &F4, &FF  \ &8841: ..... ..z.... ..
    EQUB &4C, &2F, &85, &AD, &80, &84, &CD, &81, &84, &F0, &3F, &38, &AD, &80, &84, &ED  \ &8851: L/........?8....
    EQUB &81, &84, &48, &F0, &0F, &AA, &AC, &81, &84, &C8, &B1, &A8, &88, &91, &A8, &C8  \ &8861: ..H.............
    EQUB &C8, &CA, &D0, &F6, &CE, &80, &84, &AC, &81, &84, &68, &F0, &1D, &AA, &CA, &F0  \ &8871: ..........h.....
    EQUB &1C, &48, &B1, &A8, &20, &EE, &FF, &C8, &CA, &D0, &F7, &A9, &20, &20, &EE, &FF  \ &8881: .H.. .......  ..
    EQUB &68, &AA, &A9, &08, &20, &EE, &FF, &CA, &D0, &F8, &4C, &2F, &85, &A9, &09, &20  \ &8891: h... .....L/... 
    EQUB &EE, &FF, &A9, &7F, &20, &EE, &FF, &4C, &2F, &85, &AD, &80, &84, &F0, &F8, &AD  \ &88A1: .... ..L/.......
    EQUB &30, &02, &C9, &0C, &D0, &F1, &38, &AD, &80, &84, &ED, &81, &84, &F0, &09, &AA  \ &88B1: 0.....8.........
    EQUB &A9, &09, &20, &EE, &FF, &CA, &D0, &F8, &AD, &80, &84, &8D, &81, &84, &A0, &00  \ &88C1: .. .............
    EQUB &8C, &82, &84, &8C, &83, &84, &B1, &A8, &C9, &30, &90, &07, &C9, &3A, &B0, &03  \ &88D1: .........0...:..
    EQUB &4C, &EC, &88, &C8, &CC, &80, &84, &F0, &BE, &D0, &EB, &0E, &82, &84, &2E, &83  \ &88E1: L...............
    EQUB &84, &AD, &82, &84, &0A, &85, &AC, &AD, &83, &84, &2A, &85, &AD, &06, &AC, &26  \ &88F1: ..........*....&
    EQUB &AD, &18, &AD, &82, &84, &65, &AC, &8D, &82, &84, &A5, &AD, &6D, &83, &84, &8D  \ &8901: .....e......m...
    EQUB &83, &84, &B1, &A8, &38, &E9, &30, &18, &6D, &82, &84, &8D, &82, &84, &AD, &83  \ &8911: ....8.0.m.......
    EQUB &84, &69, &00, &8D, &83, &84, &C8, &B1, &A8, &C9, &30, &90, &09, &C9, &3A, &B0  \ &8921: .i........0...:.
    EQUB &05, &CC, &80, &84, &D0, &B5, &AC, &80, &84, &A9, &00, &85, &AC, &A5, &18, &85  \ &8931: ................
    EQUB &AD, &A0, &01, &B1, &AC, &C9, &FF, &F0, &5C, &CD, &83, &84, &D0, &45, &C8, &B1  \ &8941: ........\....E..
    EQUB &AC, &CD, &82, &84, &D0, &3D, &C8, &B1, &AC, &38, &E9, &04, &AA, &A9, &00, &8D  \ &8951: .....=...8......
    EQUB &AE, &89, &A5, &1F, &29, &01, &F0, &0A, &5A, &A9, &20, &8D, &82, &84, &20, &D9  \ &8961: ....)...Z. ... .
    EQUB &85, &7A, &C8, &B1, &AC, &5A, &8D, &82, &84, &C9, &80, &B0, &31, &C9, &22, &D0  \ &8971: .z...Z......1.".
    EQUB &08, &AD, &AE, &89, &49, &FF, &8D, &AE, &89, &20, &D9, &85, &7A, &CA, &D0, &E2  \ &8981: ....I.... ..z...
    EQUB &4C, &2F, &85, &A0, &03, &B1, &AC, &18, &65, &AC, &85, &AC, &A5, &AD, &69, &00  \ &8991: L/......e.....i.
    EQUB &85, &AD, &4C, &42, &89, &A9, &07, &20, &EE, &FF, &4C, &2F, &85, &00, &AD, &AE  \ &89A1: ..LB... ..L/....
    EQUB &89, &D0, &D6, &A9, &55, &85, &AE, &A9, &AE, &85, &AF, &A0, &00, &B1, &AE, &C8  \ &89B1: ....U...........
    EQUB &B1, &AE, &10, &FB, &CD, &82, &84, &D0, &15, &A0, &FF, &C8, &B1, &AE, &30, &0B  \ &89C1: ..............0.
    EQUB &8D, &82, &84, &5A, &20, &D9, &85, &7A, &4C, &CC, &89, &4C, &8D, &89, &C8, &C8  \ &89D1: ...Z ..zL..L....
    EQUB &98, &18, &65, &AE, &85, &AE, &A5, &AF, &69, &00, &85, &AF, &4C, &BC, &89  \ &89E1: ..e.....i...L..
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
{
    LDX #&00                    \ Print "Program saved as '"
.print_loop
    LDA saved_msg,X
    BEQ done
    JSR osasci
    INX
    BNE print_loop
.done
}
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
{
    LDX #&00                    \ Print closing quote + newline
.print_loop
    LDA saved_msg_end,X
    BEQ done
    JSR osasci
    INX
    BNE print_loop
.done
}
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
    EQUS "KEY0|UL.O1|MO.|MMO.128|M|S07000|S70000|W|@|J@|@|@|@|@|@|@"
    EQUB &0D, &08, &C9, &81, &F0, &08, &C9  \ &8BD5: @|@|@|@|@.......
    EQUB &79, &F0, &2A, &28, &4C, &FF, &FF, &C0, &FF, &D0, &1E, &E0, &9E, &D0, &02, &A2  \ &8BE5: y.*(L...........
    EQUB &BF, &E0, &BD, &D0, &02, &A2, &FE, &E0, &B7, &D0, &02, &A2, &B7, &E0, &97, &D0  \ &8BF5: ................
    EQUB &02, &A2, &97, &E0, &B6, &D0, &02, &A2, &B6, &28, &4C, &FF, &FF, &E0, &80, &90  \ &8C05: .........(L.....
    EQUB &22, &E0, &E1, &D0, &02, &A2, &C0, &E0, &C2, &D0, &02, &A2, &81, &E0, &C8, &D0  \ &8C15: "...............
    EQUB &02, &A2, &C8, &E0, &E8, &D0, &02, &A2, &E8, &E0, &C9, &D0, &02, &A2, &C9, &28  \ &8C25: ...............(
    EQUB &4C, &FF, &FF, &28, &20, &FF, &FF, &08, &E0, &40, &D0, &06, &A2, &E1, &86, &EC  \ &8C35: L..( ....@......
    EQUB &A2, &61, &E0, &01, &D0, &06, &A2, &C2, &86, &EC, &A2, &42, &E0, &48, &D0, &06  \ &8C45: .a.........B.H..
    EQUB &A2, &C8, &86, &EC, &A2, &48, &E0, &68, &D0, &06, &A2, &E8, &86, &EC, &A2, &68  \ &8C55: .....H.h.......h
    EQUB &E0, &49, &D0, &06, &A2, &C9, &86, &EC, &A2, &49, &28, &60  \ &8C65: key remap code
.saved_keyv_lo
    EQUB &00                   \ &8C71: saved KEYV low byte
.saved_keyv_hi
    EQUB &00                   \ &8C72: saved KEYV high byte
.keyon_active
    EQUB &00                   \ &8C73: non-zero = KEYON active
    EQUB &41, &02, &49, &69, &4A  \ &8C74: workspace
.L8C79
    LDX #&00
.L8C7B
    LDA msg_keyon_already,X
    BEQ L8C86
    JSR osasci
    INX
    BNE L8C7B
.L8C86
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
    LDX #&00
.L8D59
    LDA msg_keys_redefined,X
    BEQ L8D64
    JSR osasci
    INX
    BNE L8D59
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
{
    LDX #&00
.loop
    LDA msg_keys_off,X
    BEQ done
    JSR osasci
    INX
    BNE loop
.done
}
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
    LDX #&00
.L8F16
    LDA msg_keys_on,X
    BEQ L8F21
    JSR osasci
    INX
    BNE L8F16
.L8F21
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
    LDX #&00
.L8FA0
    LDA &8f5b,X
    BEQ L8FAB
    JSR osasci
    INX
    BNE L8FA0
.L8FAB
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
    EQUB &FF  \ &9032: .
.cmd_alias
    LDA #&00
    STA &9032
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
    STA &9032
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
    LDA &9032
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
    STA &8217
    LDA &9c75,X
    STA &8218
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
    EQUB &CE, &6E, &9C, &10, &12, &A9, &07, &8D, &6E, &9C, &38, &A5, &A8, &E9, &08, &85  \ &952B: .n......n.8.....
    EQUB &A8, &A5, &A9, &E9, &00, &85, &A9  \ &953B: .......
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
    EQUB &A9, &81, &A2, &FF, &A0, &FF, &20, &F4, &FF, &E0, &FF, &D0, &0E, &38, &A5, &A8  \ &9561: ...... ......8..
    EQUB &E9, &B0, &85, &A8, &A5, &A9, &E9, &00, &85, &A9, &60, &38, &A5, &A8, &E9, &08  \ &9571: ..........`8....
    EQUB &85, &A8, &A5, &A9, &E9, &00, &85, &A9, &60, &A9, &81, &A2, &FF, &A0, &FF, &20  \ &9581: ........`...... 
    EQUB &F4, &FF, &E0, &FF, &D0, &0E, &18, &A5, &A8, &69, &B0, &85, &A8, &A5, &A9, &69  \ &9591: .........i.....i
    EQUB &00, &85, &A9, &60, &18, &A5, &A8, &69, &08, &85, &A8, &A5, &A9, &69, &00, &85  \ &95A1: ...`...i.....i..
    EQUB &A9, &60, &AD, &27, &7C, &49, &09, &8D, &27, &7C, &60  \ &95B1: .`.'|I..'|`
.L95BC
    LDA #&16
    STA &9649
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
    DEC &9649
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
    EQUB &81, &3F, &3F, &3F, &00, &23, &26, &6C, &00, &26, &68, &6C, &00, &26, &6C, &00  \ &9687: .???.#&l.&hl.&l.
    EQUB &41, &00, &20, &00, &28, &26, &6C, &2C, &58, &29, &00, &28, &26, &6C, &29, &2C  \ &9697: A. .(&l,X).(&l),
    EQUB &59, &00, &26, &6C, &2C, &58, &00, &26, &6C, &2C, &59, &00, &26, &68, &6C, &2C  \ &96A7: Y.&l,X.&l,Y.&hl,
    EQUB &58, &00, &26, &68, &6C, &2C, &59, &00, &26, &62, &00, &28, &26, &68, &6C, &29  \ &96B7: X.&hl,Y.&b.(&hl)
    EQUB &00, &28, &26, &68, &6C, &2C, &58, &29, &00, &28, &26, &6C, &29, &00, &87, &96  \ &96C7: .(&hl,X).(&l)...
    EQUB &8C, &96, &90, &96, &94, &96, &97, &96, &99, &96, &9B, &96, &A2, &96, &A9, &96  \ &96D7: ................
    EQUB &AE, &96, &B3, &96, &B9, &96, &BF, &96, &C2, &96, &C8, &96, &D0, &96, &01, &02  \ &96E7: ................
    EQUB &03, &02, &01, &01, &02, &02, &02, &02, &03, &03, &02, &03, &03, &02  \ &96F7: ..............
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
    LDX #&00
.L98EC
    LDA &9889,X
    BEQ L98F7
    JSR osasci
    INX
    BNE L98EC
.L98F7
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
    LDX #&00
.L9A5D
    LDA &98a4,X
    BEQ L9A68
    JSR osasci
    INX
    BNE L9A5D
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
    EQUB &00, &00, &00, &12, &E3, &16, &01, &03, &02, &88, &89, &8A, &8B, &09, &2B, &95  \ &9C66: ..............+.
    EQUB &43, &95, &8A, &95, &61, &95, &B3, &95, &82, &41, &44, &44, &52, &20, &94, &2C  \ &9C76: C...a....ADDR .,
    EQUB &2C, &2C, &2C, &2C, &2C, &82, &48, &45, &58, &20, &43, &4F, &44, &45, &94, &2C  \ &9C86: ,,,,,.HEX CODE.,
    EQUB &2C, &2C, &2C, &2C, &2C, &2C, &20, &82, &41, &53, &43, &49, &49, &20, &85, &41  \ &9C96: ,,,,,, .ASCII .A
    EQUB &30, &31, &32, &33, &34, &35, &36, &37, &38, &39, &41, &42, &43, &44, &45, &46  \ &9CA6: 0123456789ABCDEF
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
    EQUB &A9, &54, &85, &AC, &A9, &AE, &85, &AD, &EE, &55, &A1, &AD, &55, &A1, &D0, &05  \ &9D88: .T.......U..U...
    EQUB &A9, &FF, &8D, &55, &A1, &EE, &80, &84, &38, &A5, &AC, &ED, &80, &84, &85, &AE  \ &9D98: ...U....8.......
    EQUB &A5, &AD, &E9, &00, &85, &AF, &CE, &80, &84, &A9, &0D, &8D, &53, &AE, &A9, &FF  \ &9DA8: ............S...
    EQUB &8D, &54, &AE, &B2, &AE, &92, &AC, &38, &A5, &AC, &E9, &01, &85, &AC, &A5, &AD  \ &9DB8: .T.....8........
    EQUB &E9, &00, &85, &AD, &38, &A5, &AE, &E9, &01, &85, &AE, &A5, &AF, &E9, &00, &85  \ &9DC8: ....8...........
    EQUB &AF, &A5, &AE, &C9, &54, &D0, &DC, &A5, &AF, &C9, &AA, &D0, &D6, &AC, &80, &84  \ &9DD8: ....T...........
    EQUB &F0, &0D, &A0, &00, &B1, &A8, &99, &55, &AA, &C8, &CC, &80, &84, &D0, &F5, &A9  \ &9DE8: .......U........
    EQUB &0D, &99, &55, &AA, &60, &A6, &A9, &0D, &8D, &54, &AE, &AD, &FD, &9D, &C9, &FF  \ &9DF8: ..U.`....T......
    EQUB &D0, &05, &A9, &00, &8D, &FD, &9D, &CD, &55, &A1, &90, &07, &AD, &55, &A1, &3A  \ &9E08: ........U....U.:
    EQUB &8D, &FD, &9D, &A9, &55, &85, &AE, &A9, &AA, &85, &AF, &AE, &FD, &9D, &D0, &22  \ &9E18: ....U.........."
    EQUB &20, &2A, &87, &B2, &AE, &C9, &0D, &D0, &03, &4C, &2F, &85, &A0, &FF, &C8, &B1  \ &9E28:  *.......L/.....
    EQUB &AE, &8D, &82, &84, &C9, &0D, &D0, &03, &4C, &2F, &85, &5A, &20, &D9, &85, &7A  \ &9E38: ........L/.Z ..z
    EQUB &80, &EC, &A0, &00, &B1, &AE, &C9, &0D, &F0, &0B, &C8, &D0, &F7, &A9, &00, &8D  \ &9E48: ................
    EQUB &FD, &9D, &4C, &FE, &9D, &C8, &98, &18, &65, &AE, &85, &AE, &A5, &AF, &69, &00  \ &9E58: ..L.....e.....i.
    EQUB &85, &AF, &CA, &F0, &BB, &C9, &AE, &90, &D9, &A5, &AE, &C9, &55, &90, &D3, &A9  \ &9E68: ............U...
    EQUB &00, &8D, &FD, &9D, &4C, &FE, &9D  \ &9E78: ....L..
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
    EQUB &49, &6E, &20, &61, &64, &64, &69, &74, &69, &6F, &6E, &20  \ In addition
    EQUB &74, &6F, &20, &74, &68, &65, &20, &63, &6F, &6D, &6D, &61, &6E, &64, &73, &20  \ &9EFC: to the commands 
    EQUB &73, &68, &6F, &77, &6E, &20, &75, &6E, &64, &65, &72, &20, &2A, &48, &45, &4C  \ &9F0C: shown under *HEL
    EQUB &50, &20, &58, &4D, &4F, &53, &2C, &20, &20, &73, &65, &76, &65, &72, &61, &6C  \ &9F1C: P XMOS,  several
    EQUB &20, &20, &65, &78, &74, &65, &6E, &64, &65, &64, &20, &6B, &65, &79, &62, &6F  \ &9F2C:   extended keybo
    EQUB &61, &72, &64, &20, &66, &61, &63, &69, &6C, &69, &74, &69, &65, &73, &20, &61  \ &9F3C: ard facilities a
    EQUB &72, &65, &20, &61, &76, &61, &69, &6C, &61, &62, &6C, &65, &20, &77, &68, &69  \ &9F4C: re available whi
    EQUB &6C, &73, &74, &20, &69, &6E, &20, &2A, &58, &4F, &4E, &20, &6D, &6F, &64, &65  \ &9F5C: lst in *XON mode
    EQUB &2E, &0D, &0D, &49, &6E, &70, &75, &74, &20, &63, &61, &6E, &20, &6E, &6F, &77  \ &9F6C: ...Input can now
    EQUB &20, &62, &65, &20, &65, &64, &69, &74, &65, &64, &20, &75, &73, &69, &6E, &67  \ &9F7C:  be edited using
    EQUB &20, &74, &68, &65, &20, &61, &72, &72, &6F, &77, &20, &6B, &65, &79, &73, &2C  \ &9F8C:  the arrow keys,
    EQUB &20, &6F, &66, &66, &65, &72, &69, &6E, &67, &20, &69, &6E, &73, &65, &72, &74  \ &9F9C:  offering insert
    EQUB &2F, &64, &65, &6C, &65, &74, &65, &20, &66, &61, &63, &69, &6C, &69, &74, &69  \ &9FAC: /delete faciliti
    EQUB &65, &73, &20, &61, &6E, &64, &20, &72, &65, &70, &6C, &61, &63, &69, &6E, &67  \ &9FBC: es and replacing
    EQUB &20, &6E, &6F, &72, &6D, &61, &6C, &20, &63, &75, &72, &73, &6F, &72, &20, &65  \ &9FCC:  normal cursor e
    EQUB &64, &69, &74, &69, &6E, &67, &2E, &20, &49, &6E, &20, &74, &68, &69, &73, &20  \ &9FDC: diting. In this 
    EQUB &6D, &6F, &64, &65, &2C, &20, &20, &43, &4F, &50, &59, &20, &20, &64, &65, &6C  \ &9FEC: mode,  COPY  del
    EQUB &65, &74, &65, &73, &20, &74, &68, &65, &20, &63, &68, &61, &72, &61, &63, &74  \ &9FFC: etes the charact
    EQUB &65, &72, &20, &75, &6E, &64, &65, &72, &20, &74, &68, &65, &20, &63, &75, &72  \ &A00C: er under the cur
    EQUB &73, &6F, &72, &2E, &0D, &4E, &6F, &72, &6D, &61, &6C, &20, &63, &75, &72, &73  \ &A01C: sor..Normal curs
    EQUB &6F, &72, &20, &65, &64, &69, &74, &69, &6E, &67, &2C, &20, &69, &66, &20, &72  \ &A02C: or editing, if r
    EQUB &65, &71, &75, &69, &72, &65, &64, &2C, &20, &63, &61, &6E, &20, &62, &65, &20  \ &A03C: equired, can be 
    EQUB &20, &61, &63, &74, &69, &76, &61, &74, &65, &64, &20, &62, &79, &20, &70, &72  \ &A04C:  activated by pr
    EQUB &65, &73, &73, &69, &6E, &67, &20, &61, &20, &20, &63, &75, &72, &73, &6F, &72  \ &A05C: essing a  cursor
    EQUB &20, &6B, &65, &79, &20, &6F, &6E, &20, &61, &20, &62, &6C, &61, &6E, &6B, &20  \ &A06C:  key on a blank 
    EQUB &6C, &69, &6E, &65, &2E, &0D, &0D, &54, &79, &70, &69, &6E, &67, &20, &61, &20  \ &A07C: line...Typing a 
    EQUB &6C, &69, &6E, &65, &20, &6E, &75, &6D, &62, &65, &72, &20, &20, &61, &6E, &64  \ &A08C: line number  and
    EQUB &20, &74, &68, &65, &6E, &20, &70, &72, &65, &73, &73, &69, &6E, &67, &20, &54  \ &A09C:  then pressing T
    EQUB &41, &42, &20, &63, &61, &6C, &6C, &73, &20, &75, &70, &20, &74, &68, &61, &74  \ &A0AC: AB calls up that
    EQUB &20, &6C, &69, &6E, &65, &20, &66, &6F, &72, &20, &65, &64, &69, &74, &69, &6E  \ &A0BC:  line for editin
    EQUB &67, &2E, &0D, &41, &20, &72, &65, &63, &6F, &72, &64, &20, &20, &6F, &66, &20  \ &A0CC: g..A record  of 
    EQUB &70, &61, &73, &74, &20, &69, &6E, &70, &75, &74, &20, &63, &61, &6E, &20, &62  \ &A0DC: past input can b
    EQUB &65, &20, &72, &65, &63, &61, &6C, &6C, &65, &64, &20, &75, &73, &69, &6E, &67  \ &A0EC: e recalled using
    EQUB &20, &53, &48, &49, &46, &54, &2D, &75, &70, &20, &61, &6E, &64, &20, &53, &48  \ &A0FC:  SHIFT-up and SH
    EQUB &49, &46, &54, &2D, &64, &6F, &77, &6E, &2E, &0D, &54, &79, &70, &69, &6E, &67  \ &A10C: IFT-down..Typing
    EQUB &20, &53, &41, &56, &45, &20, &77, &68, &69, &6C, &65, &20, &69, &6E, &20, &42  \ &A11C:  SAVE while in B
    EQUB &41, &53, &49, &43, &20, &77, &69, &6C, &6C, &20, &65, &78, &65, &63, &75, &74  \ &A12C: ASIC will execut
    EQUB &65, &20, &74, &68, &65, &20, &65, &71, &75, &69, &76, &61, &6C, &65, &6E, &74  \ &A13C: e the equivalent
    EQUB &20, &6F, &66, &20, &2A, &53, &2E, &00, &00, &FF, &42, &52, &4B, &05, &4F, &52  \ &A14C:  of *S....BRK.OR
    EQUB &41, &06, &00, &00, &00, &00, &00, &00, &00, &00, &54, &53, &42, &03, &4F, &52  \ &A15C: A.........TSB.OR
    EQUB &41, &03, &41, &53, &4C, &03, &00, &00, &00, &00, &50, &48, &50, &05, &4F, &52  \ &A16C: A.ASL.....PHP.OR
    EQUB &41, &01, &41, &53, &4C, &04, &00, &00, &00, &00, &54, &53, &42, &02, &4F, &52  \ &A17C: A.ASL.....TSB.OR
    EQUB &41, &02, &41, &53, &4C, &02, &00, &00, &00, &00, &42, &50, &4C, &0C, &4F, &52  \ &A18C: A.ASL.....BPL.OR
    EQUB &41, &07, &4F, &52, &41, &0F, &00, &00, &00, &00, &54, &52, &42, &03, &4F, &52  \ &A19C: A.ORA.....TRB.OR
    EQUB &41, &08, &41, &53, &4C, &08, &00, &00, &00, &00, &43, &4C, &43, &05, &4F, &52  \ &A1AC: A.ASL.....CLC.OR
    EQUB &41, &0B, &49, &4E, &43, &04, &00, &00, &00, &00, &54, &52, &42, &02, &4F, &52  \ &A1BC: A.INC.....TRB.OR
    EQUB &41, &0A, &41, &53, &4C, &0A, &00, &00, &00, &00, &4A, &53, &52, &02, &41, &4E  \ &A1CC: A.ASL.....JSR.AN
    EQUB &44, &06, &00, &00, &00, &00, &00, &00, &00, &00, &42, &49, &54, &03, &41, &4E  \ &A1DC: D.........BIT.AN
    EQUB &44, &03, &52, &4F, &4C, &03, &00, &00, &00, &00, &50, &4C, &50, &05, &41, &4E  \ &A1EC: D.ROL.....PLP.AN
    EQUB &44, &01, &52, &4F, &4C, &04, &00, &00, &00, &00, &42, &49, &54, &02, &41, &4E  \ &A1FC: D.ROL.....BIT.AN
    EQUB &44, &02, &52, &4F, &4C, &02, &00, &00, &00, &00, &42, &4D, &49, &0C, &41, &4E  \ &A20C: D.ROL.....BMI.AN
    EQUB &44, &07, &41, &4E, &44, &0F, &00, &00, &00, &00, &42, &49, &54, &08, &41, &4E  \ &A21C: D.AND.....BIT.AN
    EQUB &44, &08, &52, &4F, &4C, &08, &00, &00, &00, &00, &53, &45, &43, &05, &41, &4E  \ &A22C: D.ROL.....SEC.AN
    EQUB &44, &0B, &44, &45, &43, &04, &00, &00, &00, &00, &42, &49, &54, &09, &41, &4E  \ &A23C: D.DEC.....BIT.AN
    EQUB &44, &0A, &52, &4F, &4C, &0A, &00, &00, &00, &00, &52, &54, &49, &05, &45, &4F  \ &A24C: D.ROL.....RTI.EO
    EQUB &52, &06, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &45, &4F  \ &A25C: R.............EO
    EQUB &52, &03, &4C, &53, &52, &03, &00, &00, &00, &00, &50, &48, &41, &05, &45, &4F  \ &A26C: R.LSR.....PHA.EO
    EQUB &52, &01, &4C, &53, &52, &04, &00, &00, &00, &00, &4A, &4D, &50, &02, &45, &4F  \ &A27C: R.LSR.....JMP.EO
    EQUB &52, &02, &4C, &53, &52, &02, &00, &00, &00, &00, &42, &56, &43, &0C, &45, &4F  \ &A28C: R.LSR.....BVC.EO
    EQUB &52, &07, &45, &4F, &52, &0F, &00, &00, &00, &00, &00, &00, &00, &00, &45, &4F  \ &A29C: R.EOR.........EO
    EQUB &52, &08, &4C, &53, &52, &08, &00, &00, &00, &00, &43, &4C, &49, &05, &45, &4F  \ &A2AC: R.LSR.....CLI.EO
    EQUB &52, &0B, &50, &48, &59, &05, &00, &00, &00, &00, &00, &00, &00, &00, &45, &4F  \ &A2BC: R.PHY.........EO
    EQUB &52, &0A, &4C, &53, &52, &0A, &00, &00, &00, &00, &52, &54, &53, &05, &41, &44  \ &A2CC: R.LSR.....RTS.AD
    EQUB &43, &06, &00, &00, &00, &00, &00, &00, &00, &00, &53, &54, &5A, &03, &41, &44  \ &A2DC: C.........STZ.AD
    EQUB &43, &03, &52, &4F, &52, &03, &00, &00, &00, &00, &50, &4C, &41, &05, &41, &44  \ &A2EC: C.ROR.....PLA.AD
    EQUB &43, &01, &52, &4F, &52, &04, &00, &00, &00, &00, &4A, &4D, &50, &0D, &41, &44  \ &A2FC: C.ROR.....JMP.AD
    EQUB &43, &02, &52, &4F, &52, &02, &00, &00, &00, &00, &42, &56, &53, &0C, &41, &44  \ &A30C: C.ROR.....BVS.AD
    EQUB &43, &07, &41, &44, &43, &0F, &00, &00, &00, &00, &53, &54, &5A, &08, &41, &44  \ &A31C: C.ADC.....STZ.AD
    EQUB &43, &08, &52, &4F, &52, &08, &00, &00, &00, &00, &53, &45, &49, &05, &41, &44  \ &A32C: C.ROR.....SEI.AD
    EQUB &43, &0B, &50, &4C, &59, &05, &00, &00, &00, &00, &4A, &4D, &50, &0E, &41, &44  \ &A33C: C.PLY.....JMP.AD
    EQUB &43, &0A, &52, &4F, &52, &0A, &00, &00, &00, &00, &42, &52, &41, &0C, &53, &54  \ &A34C: C.ROR.....BRA.ST
    EQUB &41, &06, &00, &00, &00, &00, &00, &00, &00, &00, &53, &54, &59, &03, &53, &54  \ &A35C: A.........STY.ST
    EQUB &41, &03, &53, &54, &58, &03, &00, &00, &00, &00, &44, &45, &59, &05, &42, &49  \ &A36C: A.STX.....DEY.BI
    EQUB &54, &01, &54, &58, &41, &05, &00, &00, &00, &00, &53, &54, &59, &02, &53, &54  \ &A37C: T.TXA.....STY.ST
    EQUB &41, &02, &53, &54, &58, &02, &00, &00, &00, &00, &42, &43, &43, &0C, &53, &54  \ &A38C: A.STX.....BCC.ST
    EQUB &41, &07, &53, &54, &41, &0F, &00, &00, &00, &00, &53, &54, &59, &08, &53, &54  \ &A39C: A.STA.....STY.ST
    EQUB &41, &08, &53, &54, &58, &09, &00, &00, &00, &00, &54, &59, &41, &05, &53, &54  \ &A3AC: A.STX.....TYA.ST
    EQUB &41, &0B, &54, &58, &53, &05, &00, &00, &00, &00, &53, &54, &5A, &02, &53, &54  \ &A3BC: A.TXS.....STZ.ST
    EQUB &41, &0A, &53, &54, &5A, &0A, &00, &00, &00, &00, &4C, &44, &59, &01, &4C, &44  \ &A3CC: A.STZ.....LDY.LD
    EQUB &41, &06, &4C, &44, &58, &01, &00, &00, &00, &00, &4C, &44, &59, &03, &4C, &44  \ &A3DC: A.LDX.....LDY.LD
    EQUB &41, &03, &4C, &44, &58, &03, &00, &00, &00, &00, &54, &41, &59, &05, &4C, &44  \ &A3EC: A.LDX.....TAY.LD
    EQUB &41, &01, &54, &41, &58, &05, &00, &00, &00, &00, &4C, &44, &59, &02, &4C, &44  \ &A3FC: A.TAX.....LDY.LD
    EQUB &41, &02, &4C, &44, &58, &02, &00, &00, &00, &00, &42, &43, &53, &0C, &4C, &44  \ &A40C: A.LDX.....BCS.LD
    EQUB &41, &07, &4C, &44, &41, &0F, &00, &00, &00, &00, &4C, &44, &59, &08, &4C, &44  \ &A41C: A.LDA.....LDY.LD
    EQUB &41, &08, &4C, &44, &58, &09, &00, &00, &00, &00, &43, &4C, &56, &05, &4C, &44  \ &A42C: A.LDX.....CLV.LD
    EQUB &41, &0B, &54, &53, &58, &05, &00, &00, &00, &00, &4C, &44, &59, &0A, &4C, &44  \ &A43C: A.TSX.....LDY.LD
    EQUB &41, &0A, &4C, &44, &58, &0B, &00, &00, &00, &00, &43, &50, &59, &01, &43, &4D  \ &A44C: A.LDX.....CPY.CM
    EQUB &50, &06, &00, &00, &00, &00, &00, &00, &00, &00, &43, &50, &59, &03, &43, &4D  \ &A45C: P.........CPY.CM
    EQUB &50, &03, &44, &45, &43, &03, &00, &00, &00, &00, &49, &4E, &59, &05, &43, &4D  \ &A46C: P.DEC.....INY.CM
    EQUB &50, &01, &44, &45, &58, &05, &00, &00, &00, &00, &43, &50, &59, &02, &43, &4D  \ &A47C: P.DEX.....CPY.CM
    EQUB &50, &02, &44, &45, &43, &02, &00, &00, &00, &00, &42, &4E, &45, &0C, &43, &4D  \ &A48C: P.DEC.....BNE.CM
    EQUB &50, &07, &43, &4D, &50, &0F, &00, &00, &00, &00, &00, &00, &00, &00, &43, &4D  \ &A49C: P.CMP.........CM
    EQUB &50, &08, &44, &45, &43, &08, &00, &00, &00, &00, &43, &4C, &44, &05, &43, &4D  \ &A4AC: P.DEC.....CLD.CM
    EQUB &50, &0B, &50, &48, &58, &05, &00, &00, &00, &00, &00, &00, &00, &00, &43, &4D  \ &A4BC: P.PHX.........CM
    EQUB &50, &0A, &44, &45, &43, &0A, &00, &00, &00, &00, &43, &50, &58, &01, &53, &42  \ &A4CC: P.DEC.....CPX.SB
    EQUB &43, &06, &00, &00, &00, &00, &00, &00, &00, &00, &43, &50, &58, &03, &53, &42  \ &A4DC: C.........CPX.SB
    EQUB &43, &03, &49, &4E, &43, &03, &00, &00, &00, &00, &49, &4E, &58, &05, &53, &42  \ &A4EC: C.INC.....INX.SB
    EQUB &43, &01, &4E, &4F, &50, &05, &00, &00, &00, &00, &43, &50, &58, &02, &53, &42  \ &A4FC: C.NOP.....CPX.SB
    EQUB &43, &02, &49, &4E, &43, &02, &00, &00, &00, &00, &42, &45, &51, &0C, &53, &42  \ &A50C: C.INC.....BEQ.SB
    EQUB &43, &07, &53, &42, &43, &0F, &00, &00, &00, &00, &00, &00, &00, &00, &53, &42  \ &A51C: C.SBC.........SB
    EQUB &43, &08, &49, &4E, &43, &08, &00, &00, &00, &00, &53, &45, &44, &05, &53, &42  \ &A52C: C.INC.....SED.SB
    EQUB &43, &0B, &50, &4C, &58, &05, &00, &00, &00, &00, &00, &00, &00, &00, &53, &42  \ &A53C: C.PLX.........SB
    EQUB &43, &0A, &49, &4E, &43, &0A, &00, &00, &00, &00, &4B, &45, &59, &39, &20, &2A  \ &A54C: C.INC.....KEY9 *
    EQUB &53, &52, &53, &41, &56, &45, &20, &58, &4D, &6F, &73, &20, &38, &30, &30, &30  \ &A55C: SRSAVE XMos 8000
    EQUB &2B, &34, &30, &30, &30, &20, &37, &51, &7C, &4D, &0D, &4D, &0D, &2A, &2A, &2A  \ &A56C: +4000 7Q|M.M.***
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A57C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A58C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A59C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A5AC: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A5BC: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A5CC: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A5DC: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A5EC: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A5FC: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A60C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A61C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A62C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A  \ &A63C: ****************
    EQUB &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &2A, &22, &22, &22, &22, &22, &22, &22  \ &A64C: *********"""""""
    EQUB &22, &22, &22, &22, &22, &22, &22, &22, &22, &22, &80, &80, &80, &80, &80, &80  \ &A65C: """"""""""......
    EQUB &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &80, &69, &8A, &90, &7E, &7A  \ &A66C: ...........i..~z
    EQUB &A9, &19, &69, &74, &22, &0D, &26, &8A, &90, &7E, &7A, &A9, &19, &6F, &61, &64  \ &A67C: ..it".&..~z..oad
    EQUB &65, &72, &22, &0D, &43, &48, &2E, &22, &4D, &65, &64, &69, &74, &22, &0D, &26  \ &A68C: er".CH."Medit".&
    EQUB &8A, &90, &7E, &7A, &A9, &19, &61, &64, &65, &72, &22, &0D, &43, &48, &2E, &22  \ &A69C: ..~z..ader".CH."
    EQUB &4D, &65, &64, &69, &74, &22, &0D, &26, &8A, &90, &7E, &7A, &A9, &19, &50, &41  \ &A6AC: Medit".&..~z..PA
    EQUB &47, &45, &3D, &26, &32, &38, &30, &30, &0D, &4C, &4F, &2E, &22, &53, &72, &63  \ &A6BC: GE=&2800.LO."Src
    EQUB &43, &6F, &64, &65, &22, &0D, &43, &48, &2E, &22, &4D, &61, &6B, &65, &4D, &61  \ &A6CC: Code".CH."MakeMa
    EQUB &70, &22, &0D, &43, &48, &2E, &22, &4C, &6F, &61, &64, &65, &72, &22, &0D, &43  \ &A6DC: p".CH."Loader".C
    EQUB &48, &2E, &22, &4D, &65, &64, &69, &74, &22, &0D, &26, &8A, &90, &7E, &7A, &A9  \ &A6EC: H."Medit".&..~z.
    EQUB &19, &61, &6B, &65, &4D, &61, &70, &22, &0D, &43, &48, &2E, &22, &4C, &6F, &61  \ &A6FC: .akeMap".CH."Loa
    EQUB &64, &65, &72, &22, &0D, &43, &48, &2E, &22, &4D, &65, &64, &69, &74, &22, &0D  \ &A70C: der".CH."Medit".
    EQUB &26, &A9, &82, &85, &A9, &A0, &00, &B2, &A8, &C9, &FF, &F0, &43, &A9, &20, &20  \ &A71C: &...........C.  
    EQUB &E3, &FF, &20, &E3, &FF, &B1, &A8, &F0, &06, &20, &E3, &FF, &C8, &D0, &F6, &98  \ &A72C: .. ...... ......
    EQUB &38, &E9, &09, &49, &FF, &1A, &AA, &A9, &20, &20, &E3, &FF, &CA, &D0, &F8, &C8  \ &A73C: 8..I....  ......
    EQUB &C8, &C8, &88, &C8, &B1, &A8, &F0, &05, &20, &00, &00, &00, &00, &00, &00, &00  \ &A74C: ........ .......
    EQUB &C8, &18, &98, &65, &A8, &85, &A8, &A5, &A9, &69, &00, &85, &A9, &4C, &CC, &80  \ &A75C: ...e.....i...L..
    EQUB &7A, &FA, &68, &60, &A9, &86, &85, &A8, &A9, &80, &85, &A9, &7A, &5A, &20, &26  \ &A76C: z.h`........zZ &
    EQUB &8A, &90, &20, &7A, &A9, &F0, &85, &A8, &A9, &9E, &85, &A9, &A0, &00, &B1, &A8  \ &A77C: .. z............
    EQUB &F0, &0A, &20, &E3, &FF, &C8, &D0, &F6, &E6, &A9, &80, &F2, &20, &E7, &FF, &7A  \ &A78C: .. ......... ..z
    EQUB &FA, &68, &60, &7A, &A9, &19, &85, &A8, &A9, &82, &85, &A9, &5A, &20, &26, &8A  \ &A79C: .h`z........Z &.
    EQUB &B0, &2C, &A0, &00, &C8, &B1, &A8, &D0, &FB, &C8, &C8, &C8, &C8, &B1, &A8, &D0  \ &A7AC: .,..............
    EQUB &FB, &C8, &18, &98, &65, &A8, &85, &A8, &A5, &A9, &69, &00, &85, &A9, &7A, &B2  \ &A7BC: ....e.....i...z.
    EQUB &A8, &C9, &FF, &D0, &D7, &A9, &0F, &20, &E3, &FF, &7A, &FA, &68, &60, &7A, &A9  \ &A7CC: ....... ..z.h`z.
    EQUB &20, &20, &E3, &FF, &20, &E3, &FF, &A0, &FF, &C8, &B1, &A8, &20, &E3, &FF, &C9  \ &A7DC:   .. ....... ...
    EQUB &00, &D0, &F6, &98, &38, &E9, &09, &49, &FF, &1A, &AA, &A9, &20, &20, &E3, &FF  \ &A7EC: ....8..I....  ..
    EQUB &CA, &D0, &F8, &C8, &C8, &C8, &B1, &A8, &F0, &06, &20, &E3, &FF, &C8, &D0, &F6  \ &A7FC: .......... .....
    EQUB &20, &E7, &FF, &7A, &FA, &68, &60, &48, &DA, &5A, &A9, &19, &85, &A8, &A9, &82  \ &A80C:  ..z.h`H.Z......
    EQUB &85, &A9, &5A, &B2, &A8, &C9, &FF, &F0, &25, &20, &26, &8A, &B0, &24, &A0, &00  \ &A81C: ..Z.....% &..$..
    EQUB &C8, &B1, &A8, &D0, &FB, &C8, &C8, &C8, &C8, &B1, &A8, &D0, &FB, &C8, &98, &18  \ &A82C: ................
    EQUB &65, &A8, &85, &A8, &A5, &A9, &69, &00, &85, &A9, &7A, &4C, &C9, &81, &7A, &4C  \ &A83C: e.....i...zL..zL
    EQUB &B8, &91, &7A, &A0, &00, &C8, &B1, &A8, &D0, &00, &00, &00, &00, &00, &00, &82  \ &A84C: ..z.............
    EQUB &C8, &B1, &A8, &8D, &18, &82, &20, &16, &82, &7A, &FA, &68, &A9, &00, &60, &4C  \ &A85C: ...... ..z.h..`L
    EQUB &46, &93, &41, &4C, &49, &41, &53, &00, &33, &90, &3C, &61, &6C, &69, &61, &73  \ &A86C: F.ALIAS.3.<alias
    EQUB &20, &6E, &61, &6D, &65, &3E, &20, &3C, &61, &6C, &69, &61, &73, &3E, &00, &41  \ &A87C:  name> <alias>.A
    EQUB &4C, &49, &41, &53, &45, &53, &00, &41, &91, &53, &68, &6F, &77, &73, &20, &61  \ &A88C: LIASES.A.Shows a
    EQUB &63, &74, &69, &76, &65, &20, &61, &6C, &69, &61, &73, &65, &73, &00, &41, &4C  \ &A89C: ctive aliases.AL
    EQUB &49, &43, &4C, &52, &00, &40, &93, &43, &6C, &65, &61, &72, &73, &20, &61, &6C  \ &A8AC: ICLR.@.Clears al
    EQUB &6C, &20, &61, &6C, &69, &61, &73, &65, &73, &00, &41, &4C, &49, &4C, &44, &00  \ &A8BC: l aliases.ALILD.
    EQUB &85, &92, &4C, &6F, &61, &64, &73, &20, &61, &6C, &69, &61, &73, &20, &66, &69  \ &A8CC: ..Loads alias fi
    EQUB &6C, &65, &00, &41, &4C, &49, &53, &56, &00, &E1, &92, &53, &61, &76, &65, &73  \ &A8DC: le.ALISV...Saves
    EQUB &20, &61, &6C, &69, &61, &73, &20, &66, &69, &6C, &65, &00, &42, &41, &55, &00  \ &A8EC:  alias file.BAU.
    EQUB &C1, &98, &53, &70, &6C, &69, &74, &73, &20, &74, &6F, &20, &73, &69, &6E, &67  \ &A8FC: ..Splits to sing
    EQUB &6C, &65, &20, &63, &6F, &6D, &6D, &61, &6E, &64, &73, &00, &44, &45, &46, &4B  \ &A90C: le commands.DEFK
    EQUB &45, &59, &53, &00, &78, &8F, &44, &65, &66, &69, &6E, &65, &73, &20, &6E, &65  \ &A91C: EYS.x.Defines ne
    EQUB &77, &20, &6B, &65, &79, &73, &00, &44, &49, &53, &00, &05, &97, &3C, &61, &64  \ &A92C: w keys.DIS...<ad
    EQUB &64, &72, &3E, &20, &2D, &20, &64, &69, &73, &61, &73, &73, &65, &6D, &62, &6C  \ &A93C: dr> - disassembl
    EQUB &65, &20, &6D, &65, &6D, &6F, &72, &79, &00, &00, &00, &00, &00, &00, &00, &00  \ &A94C: e memory........
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A95C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A96C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A97C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A98C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A99C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A9AC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A9BC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A9CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A9DC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A9EC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &A9FC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &AA0C: ................
    EQUB &00, &63, &6F, &72, &65, &20, &6E, &61, &6D, &65, &00, &53, &50, &41, &43, &45  \ &AA1C: .core name.SPACE
    EQUB &00, &2F, &9A, &49, &6E, &73, &65, &72, &74, &73, &20, &73, &70, &61, &63, &65  \ &AA2C: ./.Inserts space
    EQUB &73, &20, &69, &6E, &74, &6F, &20, &70, &72, &6F, &67, &72, &61, &6D, &73, &00  \ &AA3C: s into programs.
    EQUB &53, &54, &4F, &52, &45, &00, &46, &93, &4B, &2A, &53, &52, &53, &41, &56, &45  \ &AA4C: STORE.F.K*SRSAVE
    EQUB &20, &58, &4D, &4F, &53, &20, &38, &30, &30, &30, &2B, &34, &30, &30, &30, &20  \ &AA5C:  XMOS 8000+4000 
    EQUB &37, &20, &51, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AA6C: 7 Q.............
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AA7C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AA8C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AA9C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AAAC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AABC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AACC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AADC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AAEC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AAFC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB0C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB1C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB2C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB3C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB4C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB5C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB6C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB7C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB8C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AB9C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ABAC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ABBC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ABCC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ABDC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ABEC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ABFC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC0C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC1C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC2C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC3C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC4C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC5C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC6C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC7C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC8C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AC9C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ACAC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ACBC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ACCC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ACDC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ACEC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &ACFC: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AD0C: ................
    EQUB &0D, &2A, &4B, &45, &59, &4F, &46, &46, &0D, &2A, &4B, &45, &59, &4F, &46, &0D  \ &AD1C: .*KEYOFF.*KEYOF.
    EQUB &2A, &53, &54, &4F, &52, &45, &0D, &2A, &48, &2E, &58, &4D, &4F, &53, &0D, &0D  \ &AD2C: *STORE.*H.XMOS..
    EQUB &2A, &4B, &45, &59, &20, &31, &35, &0D, &2A, &4B, &45, &59, &20, &31, &0D, &2A  \ &AD3C: *KEY 15.*KEY 1.*
    EQUB &4B, &45, &59, &20, &31, &36, &0D, &2A, &4B, &45, &59, &20, &31, &34, &0D, &2A  \ &AD4C: KEY 16.*KEY 14.*
    EQUB &4B, &45, &59, &20, &31, &33, &0D, &2A, &4B, &45, &59, &20, &31, &32, &0D, &2A  \ &AD5C: KEY 13.*KEY 12.*
    EQUB &4B, &45, &59, &20, &31, &31, &0D, &2A, &4B, &45, &59, &20, &31, &30, &0D, &2A  \ &AD6C: KEY 11.*KEY 10.*
    EQUB &4B, &45, &59, &20, &39, &0D, &2A, &4B, &45, &59, &20, &38, &0D, &2A, &4B, &45  \ &AD7C: KEY 9.*KEY 8.*KE
    EQUB &59, &20, &37, &0D, &2A, &4B, &45, &59, &20, &36, &0D, &2A, &4B, &45, &59, &20  \ &AD8C: Y 7.*KEY 6.*KEY 
    EQUB &35, &0D, &2A, &4B, &45, &59, &20, &34, &0D, &2A, &4B, &45, &59, &20, &33, &0D  \ &AD9C: 5.*KEY 4.*KEY 3.
    EQUB &2A, &4B, &45, &59, &20, &32, &0D, &2A, &4B, &45, &59, &20, &31, &0D, &2A, &4B  \ &ADAC: *KEY 2.*KEY 1.*K
    EQUB &45, &59, &20, &30, &0D, &4F, &53, &43, &4C, &49, &22, &53, &61, &76, &65, &20  \ &ADBC: EY 0.OSCLI"Save 
    EQUB &47, &61, &6D, &65, &20, &31, &31, &30, &30, &20, &22, &2B, &53, &54, &52, &24  \ &ADCC: Game 1100 "+STR$
    EQUB &7E, &50, &25, &2B, &22, &20, &22, &2B, &53, &54, &52, &24, &7E, &73, &74, &61  \ &ADDC: ~P%+" "+STR$~sta
    EQUB &72, &74, &0D, &2A, &53, &48, &4F, &57, &20, &31, &30, &0D, &2A, &53, &48, &4F  \ &ADEC: rt.*SHOW 10.*SHO
    EQUB &57, &0D, &2A, &48, &2E, &4D, &4F, &53, &0D, &2A, &4B, &45, &59, &53, &0D, &2A  \ &ADFC: W.*H.MOS.*KEYS.*
    EQUB &4B, &45, &59, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AE0C: KEY.............
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AE1C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AE2C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D  \ &AE3C: ................
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &41, &4E, &44, &80, &00, &41, &42  \ &AE4C: .........AND..AB
    EQUB &53, &94, &00, &41, &43, &53, &95, &00, &41, &44, &56, &41, &4C, &96, &00, &41  \ &AE5C: S..ACS..ADVAL..A
    EQUB &53, &43, &97, &00, &41, &53, &4E, &98, &00, &41, &54, &4E, &99, &00, &41, &55  \ &AE6C: SC..ASN..ATN..AU
    EQUB &54, &4F, &C6, &10, &42, &47, &45, &54, &9A, &01, &42, &50, &55, &54, &D5, &03  \ &AE7C: TO..BGET..BPUT..
    EQUB &43, &4F, &4C, &4F, &55, &52, &FB, &02, &43, &41, &4C, &4C, &D6, &02, &43, &48  \ &AE8C: COLOUR..CALL..CH
    EQUB &41, &49, &4E, &D7, &02, &43, &48, &52, &24, &BD, &00, &43, &4C, &45, &41, &52  \ &AE9C: AIN..CHR$..CLEAR
    EQUB &D8, &01, &43, &4C, &4F, &53, &45, &D9, &03, &43, &4C, &47, &DA, &01, &43, &4C  \ &AEAC: ..CLOSE..CLG..CL
    EQUB &53, &DB, &01, &43, &4F, &53, &9B, &00, &43, &4F, &55, &4E, &54, &9C, &01, &43  \ &AEBC: S..COS..COUNT..C
    EQUB &4F, &4C, &4F, &52, &FB, &02, &44, &41, &54, &41, &DC, &20, &44, &45, &47, &9D  \ &AECC: OLOR..DATA. DEG.
    EQUB &00, &44, &45, &46, &DD, &00, &44, &45, &4C, &45, &54, &45, &C7, &10, &44, &49  \ &AEDC: .DEF..DELETE..DI
    EQUB &56, &81, &00, &44, &49, &4D, &DE, &02, &44, &52, &41, &57, &DF, &02, &45, &4E  \ &AEEC: V..DIM..DRAW..EN
    EQUB &44, &50, &52, &4F, &43, &E1, &01, &45, &4E, &44, &E0, &01, &45, &4E, &56, &45  \ &AEFC: DPROC..END..ENVE
    EQUB &4C, &4F, &50, &45, &E2, &02, &45, &4C, &53, &45, &8B, &14, &45, &56, &41, &4C  \ &AF0C: LOPE..ELSE..EVAL
    EQUB &A0, &00, &45, &52, &4C, &9E, &01, &45, &52, &52, &4F, &52, &85, &04, &45, &4F  \ &AF1C: ..ERL..ERROR..EO
    EQUB &46, &C5, &01, &45, &4F, &52, &82, &00, &45, &52, &52, &9F, &01, &45, &58, &50  \ &AF2C: F..EOR..ERR..EXP
    EQUB &A1, &00, &45, &58, &54, &A2, &01, &45, &44, &49, &54, &CE, &10, &46, &4F, &52  \ &AF3C: ..EXT..EDIT..FOR
    EQUB &E3, &02, &46, &41, &4C, &53, &45, &A3, &01, &46, &4E, &A4, &08, &47, &4F, &54  \ &AF4C: ..FALSE..FN..GOT
    EQUB &4F, &E5, &12, &47, &45, &54, &24, &BE, &00, &47, &45, &54, &A5, &00, &47, &4F  \ &AF5C: O..GET$..GET..GO
    EQUB &53, &55, &42, &E4, &12, &47, &43, &4F, &4C, &E6, &02, &48, &49, &4D, &45, &4D  \ &AF6C: SUB..GCOL..HIMEM
    EQUB &93, &43, &49, &4E, &50, &55, &54, &E8, &02, &49, &46, &E7, &02, &49, &4E, &4B  \ &AF7C: .CINPUT..IF..INK
    EQUB &45, &59, &24, &BF, &00, &49, &4E, &4B, &45, &59, &A6, &00, &49, &4E, &54, &A8  \ &AF8C: EY$..INKEY..INT.
    EQUB &00, &49, &4E, &53, &54, &52, &28, &A7, &00, &4C, &49, &53, &54, &C9, &10, &4C  \ &AF9C: .INSTR(..LIST..L
    EQUB &49, &4E, &45, &86, &00, &4C, &4F, &41, &44, &C8, &02, &4C, &4F, &4D, &45, &4D  \ &AFAC: INE..LOAD..LOMEM
    EQUB &92, &43, &4C, &4F, &43, &41, &4C, &EA, &02, &4C, &45, &46, &54, &24, &28, &C0  \ &AFBC: .CLOCAL..LEFT$(.
    EQUB &00, &4C, &45, &4E, &A9, &00, &4C, &45, &54, &E9, &04, &4C, &4F, &47, &AB, &00  \ &AFCC: .LEN..LET..LOG..
    EQUB &4C, &4E, &AA, &00, &4D, &49, &44, &24, &28, &C1, &00, &4D, &4F, &44, &45, &EB  \ &AFDC: LN..MID$(..MODE.
    EQUB &02, &4D, &4F, &44, &83, &00, &4D, &4F, &56, &45, &EC, &02, &4E, &45, &58, &54  \ &AFEC: .MOD..MOVE..NEXT
    EQUB &ED, &02, &4E, &45, &57, &CA, &01, &4E, &4F, &54, &AC, &00, &4F, &4C, &44, &CB  \ &AFFC: ..NEW..NOT..OLD.
    EQUB &01, &4F, &4E, &EE, &02, &4F, &46, &46, &87, &00, &4F, &52, &84, &00, &4F, &50  \ &B00C: .ON..OFF..OR..OP
    EQUB &45, &4E, &49, &4E, &8E, &00, &4F, &50, &45, &4E, &4F, &55, &54, &AE, &00, &4F  \ &B01C: ENIN..OPENOUT..O
    EQUB &50, &45, &4E, &55, &50, &AD, &00, &4F, &53, &43, &4C, &49, &FF, &02, &50, &52  \ &B02C: PENUP..OSCLI..PR
    EQUB &49, &4E, &54, &F1, &02, &50, &41, &47, &45, &90, &43, &50, &54, &52, &8F, &43  \ &B03C: INT..PAGE.CPTR.C
    EQUB &50, &49, &AF, &01, &50, &4C, &4F, &54, &F0, &02, &50, &4F, &49, &4E, &54, &28  \ &B04C: PI..PLOT..POINT(
    EQUB &B0, &00, &50, &52, &4F, &43, &F2, &0A, &50, &4F, &53, &B1, &01, &52, &45, &54  \ &B05C: ..PROC..POS..RET
    EQUB &55, &52, &4E, &F8, &01, &52, &45, &50, &45, &41, &54, &F5, &00, &52, &45, &50  \ &B06C: URN..REPEAT..REP
    EQUB &4F, &52, &54, &F6, &01, &52, &45, &41, &44, &F3, &02, &52, &45, &4D, &F4, &20  \ &B07C: ORT..READ..REM. 
    EQUB &52, &55, &4E, &F9, &01, &52, &41, &44, &B2, &00, &52, &45, &53, &54, &4F, &52  \ &B08C: RUN..RAD..RESTOR
    EQUB &45, &F7, &12, &52, &49, &47, &48, &54, &24, &28, &C2, &00, &52, &4E, &44, &B3  \ &B09C: E..RIGHT$(..RND.
    EQUB &01, &52, &45, &4E, &55, &4D, &42, &45, &52, &CC, &10, &53, &54, &45, &50, &88  \ &B0AC: .RENUMBER..STEP.
    EQUB &00, &53, &41, &56, &45, &CD, &02, &53, &47, &4E, &B4, &00, &53, &49, &4E, &B5  \ &B0BC: .SAVE..SGN..SIN.
    EQUB &00, &53, &51, &52, &B6, &00, &53, &50, &43, &89, &00, &53, &54, &52, &24, &C3  \ &B0CC: .SQR..SPC..STR$.
    EQUB &00, &53, &54, &52, &49, &4E, &47, &24, &28, &C4, &00, &53, &4F, &55, &4E, &44  \ &B0DC: .STRING$(..SOUND
    EQUB &D4, &02, &53, &54, &4F, &50, &FA, &01, &54, &41, &4E, &B7, &00, &54, &48, &45  \ &B0EC: ..STOP..TAN..THE
    EQUB &4E, &8C, &14, &54, &4F, &B8, &00, &54, &41, &42, &28, &8A, &00, &54, &52, &41  \ &B0FC: N..TO..TAB(..TRA
    EQUB &43, &45, &FC, &12, &54, &49, &4D, &45, &91, &43, &54, &52, &55, &45, &B9, &01  \ &B10C: CE..TIME.CTRUE..
    EQUB &55, &4E, &54, &49, &4C, &FD, &02, &55, &53, &52, &BA, &00, &56, &44, &55, &EF  \ &B11C: UNTIL..USR..VDU.
    EQUB &02, &56, &41, &4C, &BB, &00, &56, &50, &4F, &53, &BC, &01, &57, &49, &44, &54  \ &B12C: .VAL..VPOS..WIDT
    EQUB &48, &FE, &02, &50, &41, &47, &45, &D0, &00, &50, &54, &52, &CF, &00, &54, &49  \ &B13C: H..PAGE..PTR..TI
    EQUB &4D, &45, &D1, &00, &4C, &4F, &4D, &45, &4D, &D2, &00, &48, &49, &4D, &45, &4D  \ &B14C: ME..LOMEM..HIMEM
    EQUB &D3, &00, &4D, &69, &73, &73, &69, &6E, &67, &FF, &4F, &00, &16, &53, &41, &56  \ &B15C: ..Missing.O..SAV
    EQUB &45, &7C, &4D, &43, &48, &2E, &22, &43, &6F, &72, &65, &22, &7C, &4D, &0D, &42  \ &B16C: E|MCH."Core"|M.B
    EQUB &52, &45, &41, &4B, &00, &1E, &2A, &4B, &45, &59, &31, &30, &20, &25, &30, &7C  \ &B17C: REAK..*KEY10 %0|
    EQUB &7C, &4D, &7C, &4D, &2A, &53, &54, &4F, &52, &45, &7C, &4D, &0D, &4D, &41, &4B  \ &B18C: |M|M*STORE|M.MAK
    EQUB &45, &00, &1F, &2A, &53, &53, &41, &56, &45, &20, &25, &30, &7C, &4D, &43, &48  \ &B19C: E..*SSAVE %0|MCH
    EQUB &2E, &22, &43, &52, &45, &41, &54, &45, &22, &7C, &4D, &0D, &53, &50, &52, &00  \ &B1AC: ."CREATE"|M.SPR.
    EQUB &34, &4D, &4F, &44, &45, &31, &3A, &56, &44, &55, &31, &39, &2C, &31, &2C, &31  \ &B1BC: 4MODE1:VDU19,1,1
    EQUB &3B, &30, &3B, &31, &39, &2C, &32, &2C, &32, &3B, &30, &3B, &31, &39, &2C, &33  \ &B1CC: ;0;19,2,2;0;19,3
    EQUB &2C, &33, &3B, &30, &3B, &3A, &2A, &53, &45, &44, &2E, &25, &30, &7C, &4D, &0D  \ &B1DC: ,3;0;:*SED.%0|M.
    EQUB &55, &50, &44, &41, &54, &45, &00, &24, &2A, &53, &52, &53, &41, &56, &45, &20  \ &B1EC: UPDATE.$*SRSAVE 
    EQUB &58, &4D, &6F, &73, &20, &38, &30, &30, &30, &2B, &34, &30, &30, &30, &20, &37  \ &B1FC: XMos 8000+4000 7
    EQUB &51, &7C, &4D, &0D, &FF, &45, &54, &55, &50, &54, &45, &00, &24, &2A, &53, &52  \ &B20C: Q|M..ETUPTE.$*SR
    EQUB &53, &41, &56, &45, &20, &58, &4D, &6F, &73, &20, &38, &30, &30, &30, &2B, &34  \ &B21C: SAVE XMos 8000+4
    EQUB &30, &30, &30, &20, &37, &51, &7C, &4D, &0D, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B22C: 000 7Q|M........
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B23C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B24C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B25C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B26C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B27C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B28C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B29C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B2AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B2BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B2CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B2DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B2EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B2FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B30C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B31C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B32C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B33C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B34C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B35C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B36C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B37C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B38C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B39C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B3AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B3BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B3CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B3DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B3EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B3FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B40C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B41C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B42C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B43C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B44C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B45C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B46C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B47C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B48C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B49C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B4AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B4BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B4CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B4DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B4EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B4FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B50C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B51C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B52C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B53C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B54C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B55C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B56C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B57C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B58C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B59C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B5AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B5BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B5CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B5DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B5EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B5FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B60C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B61C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B62C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B63C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B64C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B65C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B66C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B67C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B68C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B69C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B6AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B6BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B6CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B6DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B6EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B6FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B70C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B71C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B72C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B73C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B74C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B75C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B76C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B77C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B78C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B79C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B7AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B7BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B7CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B7DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B7EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B7FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B80C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B81C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B82C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B83C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B84C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B85C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B86C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B87C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B88C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B89C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B8AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B8BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B8CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B8DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B8EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B8FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B90C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B91C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B92C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B93C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B94C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B95C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B96C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B97C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B98C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B99C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B9AC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B9BC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B9CC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &B9DC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B9EC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &B9FC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BA0C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BA1C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BA2C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BA3C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BA4C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BA5C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BA6C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BA7C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BA8C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BA9C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BAAC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BABC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BACC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BADC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BAEC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BAFC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BB0C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BB1C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BB2C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BB3C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BB4C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BB5C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BB6C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BB7C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BB8C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BB9C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BBAC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BBBC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BBCC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BBDC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BBEC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BBFC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BC0C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BC1C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BC2C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BC3C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BC4C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BC5C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BC6C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BC7C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BC8C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BC9C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BCAC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BCBC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BCCC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BCDC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BCEC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BCFC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BD0C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BD1C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BD2C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BD3C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BD4C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BD5C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BD6C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BD7C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BD8C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BD9C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BDAC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BDBC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BDCC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BDDC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BDEC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BDFC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BE0C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BE1C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BE2C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BE3C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BE4C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BE5C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BE6C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BE7C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BE8C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BE9C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BEAC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BEBC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BECC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BEDC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BEEC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BEFC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BF0C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BF1C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BF2C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BF3C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BF4C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BF5C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BF6C: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BF7C: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BF8C: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BF9C: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BFAC: ................
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BFBC: ................
    EQUB &FF, &FF, &FF, &FF, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BFCC: ................
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  \ &BFDC: ................
    EQUB &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF  \ &BFEC: ................
    EQUB &FF, &FF, &FF, &FF  \ &BFFC: ....

SAVE "build.rom", &8000, &C000
