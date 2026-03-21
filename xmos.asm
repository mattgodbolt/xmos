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
    JSR alias_init                   \ Initialise alias system
    LDA keyon_active
    BEQ reset_skip_keyon
    LDA #&00
    STA keyon_active
    JSR keyon_setup                   \ Re-enable KEYON if it was active
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
    BEQ xi_entry
    PLP
    JMP &EF39
.xi_entry
    PLA
    STX &00AE
    STY &00AF
    LDA #&db
    STA &00AB
    LDA #&e0
    STA &00AA
    LDY #&0f
.xi_save_regs_loop
    LDA (&ae),Y
    STA (&aa),Y
    DEY
    BPL xi_save_regs_loop
    LDA &00F4
    STA &0230
    LDA #&07
    STA sheila_romsel
    STA &00F4
    JSR xi_check_xon
    PHP
    LDA &0230
    STA sheila_romsel
    STA &00F4
    LDA #&00
    PLP
    RTS
.xi_check_xon
    LDA xon_flag
    BNE xi_init_state
    LDX &00AE
    LDY &00AF
    JMP &EF39
.xi_init_state
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
.xi_read_loop
    JSR osrdch
    STA xi_char
    LDA &026A
    BPL xi_dispatch
    LDA xi_char
    JSR oswrch
    JMP xi_read_loop
.xi_dispatch
    LDA xi_char
    CMP #&88
    BNE xi_check_right
    JMP xi_handle_left
.xi_check_right
    CMP #&89
    BNE xi_check_delete
    JMP xi_handle_right
.xi_check_delete
    CMP #&7f
    BNE xi_check_cr
    JMP xi_handle_delete
.xi_check_cr
    CMP #&0d
    BNE xi_check_escape
    JMP xi_handle_cr
.xi_check_escape
    CMP #&1b
    BNE xi_check_clear
    JMP xi_cr_restore_keys
.xi_check_clear
    CMP #&15
    BNE xi_check_copy
    JMP xi_handle_clear
.xi_check_copy
    CMP #&8b
    BNE xi_check_down
    JMP xi_handle_copy_up
.xi_check_down
    CMP #&8a
    BNE xi_check_tab
    JMP xi_handle_copy_down
.xi_check_tab
    CMP #&87
    BNE xi_check_ctrl_n
    JMP xi_handle_tab
.xi_check_ctrl_n
    CMP #&0e
    BNE xi_check_ctrl_o
    JSR oswrch
.xi_check_ctrl_o
    CMP #&0f
    BNE xi_check_htab
    JSR oswrch
.xi_check_htab
    CMP #&09
    BNE xi_check_null
    JMP xi_handle_htab
.xi_check_null
    CMP #&00
    BNE xi_handle_printable
    JMP xi_handle_null
.xi_handle_printable
    LDA xi_char
    CMP #&20
    BCS xi_check_lo_range
    JSR oswrch
    JMP xi_read_loop
.xi_check_lo_range
    LDY #&03
    CMP (&aa),Y
    BCS xi_check_hi_range
    JMP xi_read_loop
.xi_check_hi_range
    INY
    CMP (&aa),Y
    BEQ xi_check_buffer_full
    BCC xi_check_buffer_full
    JMP xi_read_loop
.xi_check_buffer_full
    LDA xi_cursor_pos
    LDY #&02
    CMP (&aa),Y
    BNE xi_do_insert_setup
    JMP xi_read_loop
.xi_do_insert_setup
    LDA #&00
    STA xi_insert_mode
    JSR xi_do_insert
    JMP xi_read_loop
.xi_insert_mode
    EQUB &00                   \ &85D8: insert mode flag (0=insert, FF=overwrite)
.xi_do_insert
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ xi_write_char
    TAX
    LDY xi_cursor_pos
    DEY
.xi_shift_right_loop
    LDA (&a8),Y
    INY
    STA (&a8),Y
    DEY
    DEY
    DEX
    BNE xi_shift_right_loop
.xi_write_char
    LDY xi_line_len
    LDA xi_char
    JSR oswrch
    STA (&a8),Y
    INC xi_line_len
    INC xi_cursor_pos
    PLA
    BEQ xi_insert_done
    PHA
    TAX
.xi_redraw_after
    INY
    LDA (&a8),Y
    JSR oswrch
    DEX
    BNE xi_redraw_after
    PLA
    TAX
.xi_backspace_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_backspace_loop
.xi_insert_done
    RTS
.xi_handle_left
    LDA xi_cursor_pos
    BNE xi_left_no_scroll
    LDY #&8c
    JMP xi_reset_cursor_keys
.xi_left_no_scroll
    LDA xi_line_len
    BEQ xi_left_done
    DEC xi_line_len
    LDA #&08
    JSR oswrch
.xi_left_done
    JMP xi_read_loop
.xi_handle_right
    LDA xi_cursor_pos
    BNE xi_right_no_scroll
    LDY #&8d
    JMP xi_reset_cursor_keys
.xi_right_no_scroll
    LDA xi_line_len
    CMP xi_cursor_pos
    BEQ xi_right_done
    INC xi_line_len
    LDA #&09
    JSR oswrch
.xi_right_done
    JMP xi_read_loop
.xi_handle_delete
    LDA xi_line_len
    BEQ xi_del_done
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ xi_del_do_delete
    TAX
    LDY xi_line_len
.xi_del_shift_loop
    LDA (&a8),Y
    DEY
    STA (&a8),Y
    INY
    INY
    DEX
    BNE xi_del_shift_loop
.xi_del_do_delete
    LDA #&7f
    JSR oswrch
    DEC xi_line_len
    DEC xi_cursor_pos
    LDY xi_line_len
    PLA
    BEQ xi_del_done
    PHA
    TAX
.xi_del_redraw_loop
    LDA (&a8),Y
    JSR oswrch
    INY
    DEX
    BNE xi_del_redraw_loop
    LDA #&20
    JSR oswrch
    PLA
    TAX
    INX
.xi_del_backspace_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_del_backspace_loop
.xi_del_done
    JMP xi_read_loop
.xi_handle_cr
    LDA xon_flag
    BEQ xi_cr_check_mode
    LDA #&04
    LDX #&01
    LDY #&00
    JSR osbyte
.xi_cr_check_mode
    LDA &0230
    CMP #&0c
    BNE xi_cr_normal
    LDA xi_cursor_pos
    CMP #&04
    BNE xi_cr_normal
    LDY #&03
.xi_cr_check_save
    LDA (&a8),Y
    CMP save_keyword,Y
    BNE xi_cr_normal
    DEY
    BPL xi_cr_check_save
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
.xi_cr_normal
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_cr_finish
    TAX
.xi_cr_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_cr_fwd_loop
.xi_cr_finish
    JSR xi_support_entry
    LDY xi_cursor_pos
    LDA #&0d
    STA (&a8),Y
    JSR osnewl
    CLC
    LDX #&00
    RTS
.save_keyword
    EQUS "SAVE"                \ &8700: compared against user input
.xi_cr_restore_keys
    LDA #&04                   \ OSBYTE 4: cursor key status
    LDX #&01                   \ Enable cursor editing
    LDY #&00
    JSR osbyte
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_cr_sec_return
    TAX
.xi_cr_fwd_loop2
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_cr_fwd_loop2
.xi_cr_sec_return
    LDY xi_cursor_pos
    SEC
    RTS
.xi_handle_clear
    JSR xi_do_clear
    JMP xi_read_loop
.xi_do_clear
    LDA xi_cursor_pos
    BEQ xi_clear_done
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_clear_del_loop
    TAX
.xi_clear_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_clear_fwd_loop
.xi_clear_del_loop
    LDX xi_cursor_pos
.xi_clear_del_char
    LDA #&7f
    JSR oswrch
    DEX
    BNE xi_clear_del_char
    LDA #&00
    STA xi_line_len
    STA xi_cursor_pos
.xi_clear_done
    RTS
.xi_handle_null
    LDA xi_cursor_pos
    BEQ xi_null_not_empty
    JMP xi_read_loop
.xi_null_not_empty
    JSR cmd_xoff
    JSR osnewl
    LDY #&00
    LDA #&0d
    STA (&a8),Y
    CLC
    RTS
.xi_handle_copy_up
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE xi_copy_up_has_key
    LDA xi_scroll_count
    BNE xi_copy_up_inc
    LDA xi_insert_mode
    BNE xi_copy_up_inc
    LDA #&ff
    STA xi_insert_mode
    LDA xi_cursor_pos
    BEQ xi_copy_up_jmp
    JSR xi_support_entry
.xi_copy_up_inc
    INC xi_scroll_count
.xi_copy_up_jmp
    JMP xi_supp_restore
.xi_copy_up_has_key
    LDA xi_cursor_pos
    BNE xi_copy_up_calc
    LDY #&8f
    JMP xi_reset_cursor_keys
.xi_copy_up_calc
    SEC
    LDA &030A
    SBC &0308
    CLC
    ADC #&01
    STA xi_char
    SEC
    LDA xi_line_len
    SBC xi_char
    BCC xi_copy_up_clear
    STA xi_line_len
    LDA #&0b
    JSR oswrch
.xi_copy_up_done
    JMP xi_read_loop
.xi_copy_up_clear
    LDX xi_line_len
    BEQ xi_copy_up_done
.xi_copy_up_bs_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_copy_up_bs_loop
    LDA #&00
    STA xi_line_len
    JMP xi_read_loop
.xi_handle_copy_down
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE xi_copy_down_has_key
    LDA xi_scroll_count
    BNE xi_copy_down_dec
    LDA xi_insert_mode
    BNE xi_copy_down_dec
    LDA #&ff
    STA xi_insert_mode
    JSR xi_support_entry
.xi_copy_down_dec
    DEC xi_scroll_count
    JMP xi_supp_restore
.xi_copy_down_has_key
    LDA xi_cursor_pos
    BNE xi_copy_down_calc
    LDY #&8e
    JMP xi_reset_cursor_keys
.xi_copy_down_calc
    SEC
    LDA &030A
    SBC &0308
    CLC
    ADC #&01
    CLC
    ADC xi_line_len
    BCS xi_copy_down_truncate
    CMP xi_cursor_pos
    BCS xi_copy_down_truncate
    STA xi_line_len
    LDA #&0a
    JSR oswrch
    JMP xi_read_loop
.xi_copy_down_truncate
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_copy_down_set_pos
    TAX
.xi_copy_down_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_copy_down_fwd_loop
.xi_copy_down_set_pos
    LDA xi_cursor_pos
    STA xi_line_len
    JMP xi_read_loop
.xi_reset_cursor_keys
    PHY
    LDA #&04
    LDX #&00
    LDY #&00
    JSR osbyte
    PLY
    LDA #&8a
    LDX #&00
    JSR osbyte
    JMP xi_read_loop
.xi_handle_tab
    LDA xi_cursor_pos
    CMP xi_line_len
    BEQ xi_tab_done
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    PHA
    BEQ xi_tab_update_pos
    TAX
    LDY xi_line_len
    INY
.xi_tab_shift_loop
    LDA (&a8),Y
    DEY
    STA (&a8),Y
    INY
    INY
    DEX
    BNE xi_tab_shift_loop
.xi_tab_update_pos
    DEC xi_cursor_pos
    LDY xi_line_len
    PLA
    BEQ xi_tab_done
    TAX
    DEX
    BEQ xi_tab_single
    PHA
.xi_tab_redraw_loop
    LDA (&a8),Y
    JSR oswrch
    INY
    DEX
    BNE xi_tab_redraw_loop
    LDA #&20
    JSR oswrch
    PLA
    TAX
.xi_tab_bs_loop
    LDA #&08
    JSR oswrch
    DEX
    BNE xi_tab_bs_loop
.xi_tab_done
    JMP xi_read_loop
.xi_tab_single
    LDA #&09
    JSR oswrch
    LDA #&7f
    JSR oswrch
.xi_tab_finished
    JMP xi_read_loop
.xi_handle_htab
    LDA xi_cursor_pos
    BEQ xi_tab_finished
    LDA &0230
    CMP #&0c
    BNE xi_tab_finished
    SEC
    LDA xi_cursor_pos
    SBC xi_line_len
    BEQ xi_htab_set_pos
    TAX
.xi_htab_fwd_loop
    LDA #&09
    JSR oswrch
    DEX
    BNE xi_htab_fwd_loop
.xi_htab_set_pos
    LDA xi_cursor_pos
    STA xi_line_len
    LDY #&00
    STY xi_char
    STY xi_temp
.xi_htab_parse_loop
    LDA (&a8),Y
    CMP #&30
    BCC xi_htab_skip_nondigit
    CMP #&3a
    BCS xi_htab_skip_nondigit
    JMP xi_htab_mul10
.xi_htab_skip_nondigit
    INY
    CPY xi_cursor_pos
    BEQ xi_tab_finished
    BNE xi_htab_parse_loop
.xi_htab_mul10
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
    BCC xi_htab_lookup
    CMP #&3a
    BCS xi_htab_lookup
    CPY xi_cursor_pos
    BNE xi_htab_mul10
.xi_htab_lookup
    LDY xi_cursor_pos
    LDA #&00
    STA &00AC
    LDA &0018
    STA &00AD
.xi_htab_search_loop
    LDY #&01
    LDA (&ac),Y
    CMP #&ff
    BEQ xi_htab_not_found
    CMP xi_temp
    BNE xi_htab_advance_ptr
    INY
    LDA (&ac),Y
    CMP xi_char
    BNE xi_htab_advance_ptr
    INY
    LDA (&ac),Y
    SEC
    SBC #&04
    TAX
    LDA #&00
    STA xi_quote_toggle
    LDA &001F
    AND #&01
    BEQ xi_htab_found_space
    PHY
    LDA #&20
    STA xi_char
    JSR xi_do_insert
    PLY
.xi_htab_found_space
    INY
    LDA (&ac),Y
    PHY
    STA xi_char
    CMP #&80
    BCS xi_htab_check_quote
    CMP #&22
    BNE xi_htab_output_char
    LDA xi_quote_toggle
    EOR #&ff
    STA xi_quote_toggle
.xi_htab_output_char
    JSR xi_do_insert
.xi_htab_next_char
    PLY
    DEX
    BNE xi_htab_found_space
    JMP xi_read_loop
.xi_htab_advance_ptr
    LDY #&03
    LDA (&ac),Y
    CLC
    ADC &00AC
    STA &00AC
    LDA &00AD
    ADC #&00
    STA &00AD
    JMP xi_htab_search_loop
.xi_htab_not_found
    LDA #&07
    JSR oswrch
    JMP xi_read_loop
.xi_quote_toggle
    EQUB &00                   \ &89AE: quote toggle flag
.xi_htab_check_quote
    EQUB &AD, &AE, &89         \ LDA xi_quote_toggle (absolute ZP workaround)
    BNE xi_htab_output_char
    LDA #&55
    STA &AE
    LDA #&AE
    STA &AF
.xi_htab_keyword_loop
    LDY #&00
    LDA (&ae),Y
.xi_htab_kw_scan
    INY
    LDA (&ae),Y
    BPL xi_htab_kw_scan
    CMP xi_char
    BNE xi_htab_kw_advance
    LDY #&ff
.xi_htab_kw_match
    INY
    LDA (&ae),Y
    BMI xi_htab_kw_done
    STA xi_char
    PHY
    JSR xi_do_insert
    PLY
    JMP xi_htab_kw_match
.xi_htab_kw_done
    JMP xi_htab_next_char
.xi_htab_kw_advance
    INY
    INY
    TYA
    CLC
    ADC &00AE
    STA &00AE
    LDA &00AF
    ADC #&00
    STA &00AF
    JMP xi_htab_keyword_loop
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
\ Scan handler: remap key codes for OSBYTE &81
\ Each CPX/LDX pair is patched by KEYON with the configured key codes
.key_remap_scan
    CPY #&FF
    BNE key_remap_pass2
.kr_scan_cpx_0
    CPX #&9E
    BNE kr_scan_1
.kr_scan_ldx_0
    LDX #&BF
.kr_scan_1
.kr_scan_cpx_1
    CPX #&BD
    BNE kr_scan_2
.kr_scan_ldx_1
    LDX #&FE
.kr_scan_2
.kr_scan_cpx_2
    CPX #&B7
    BNE kr_scan_3
.kr_scan_ldx_2
    LDX #&B7
.kr_scan_3
.kr_scan_cpx_3
    CPX #&97
    BNE kr_scan_4
.kr_scan_ldx_3
    LDX #&97
.kr_scan_4
.kr_scan_cpx_4
    CPX #&B6
    BNE key_remap_pass2
.kr_scan_ldx_4
    LDX #&B6
.key_remap_pass2
    PLP
.key_remap_jmp2
    JMP &FFFF                  \ Patched: original KEYV address

\ Keyboard handler: remap key codes for OSBYTE &79
.key_remap_keyboard
    CPX #&80
    BCC key_remap_shifted
.kr_kbd_cpx_0
    CPX #&E1
    BNE kr_kbd_1
.kr_kbd_ldx_0
    LDX #&C0
.kr_kbd_1
.kr_kbd_cpx_1
    CPX #&C2
    BNE kr_kbd_2
.kr_kbd_ldx_1
    LDX #&81
.kr_kbd_2
.kr_kbd_cpx_2
    CPX #&C8
    BNE kr_kbd_3
.kr_kbd_ldx_2
    LDX #&C8
.kr_kbd_3
.kr_kbd_cpx_3
    CPX #&E8
    BNE kr_kbd_4
.kr_kbd_ldx_3
    LDX #&E8
.kr_kbd_4
.kr_kbd_cpx_4
    CPX #&C9
    BNE kr_kbd_pass
.kr_kbd_ldx_4
    LDX #&C9
.kr_kbd_pass
    PLP
.key_remap_jmp3
    JMP &FFFF                  \ Patched: original KEYV address

\ Shifted handler: call original KEYV then remap results
.key_remap_shifted
    PLP
.key_remap_jsr
    JSR &FFFF                  \ Patched: call original KEYV
    PHP
.kr_shift_cpx_0
    CPX #&40
    BNE kr_shift_1
.kr_shift_ldx_0
    LDX #&E1
    STX &EC
.kr_shift_orig_0
    LDX #&61
.kr_shift_1
.kr_shift_cpx_1
    CPX #&01
    BNE kr_shift_2
.kr_shift_ldx_1
    LDX #&C2
    STX &EC
.kr_shift_orig_1
    LDX #&42
.kr_shift_2
.kr_shift_cpx_2
    CPX #&48
    BNE kr_shift_3
.kr_shift_ldx_2
    LDX #&C8
    STX &EC
.kr_shift_orig_2
    LDX #&48
.kr_shift_3
.kr_shift_cpx_3
    CPX #&68
    BNE kr_shift_4
.kr_shift_ldx_3
    LDX #&E8
    STX &EC
.kr_shift_orig_3
    LDX #&68
.kr_shift_4
.kr_shift_cpx_4
    CPX #&49
    BNE kr_shift_done
.kr_shift_ldx_4
    LDX #&C9
    STX &EC
.kr_shift_orig_4
    LDX #&49
.kr_shift_done
    PLP
    RTS

.saved_keyv_lo
    EQUB &00                   \ &8C71: saved KEYV low byte
.saved_keyv_hi
    EQUB &00                   \ &8C72: saved KEYV high byte
.keyon_active
    EQUB &00                   \ &8C73: non-zero = KEYON active
.key_codes                     \ 5-byte table of key scan codes to remap
    EQUB &41, &02, &49, &69, &4A
.keyon_already_msg
    STROUT msg_keyon_already
    JMP keyon_rts
.keyon_setup
    LDA keyon_active
    BNE keyon_already_msg
    LDA #&01
    STA keyon_active
    LDA keyv_lo
    STA key_remap_jmp1 + 1
    STA key_remap_jmp2 + 1
    STA key_remap_jmp3 + 1
    STA key_remap_jsr + 1
    STA saved_keyv_lo
    LDA keyv_hi
    STA key_remap_jmp1 + 2
    STA key_remap_jmp2 + 2
    STA key_remap_jmp3 + 2
    STA key_remap_jsr + 2
    STA saved_keyv_hi
    SEC
    LDA #&00
    SBC key_codes
    STA kr_scan_ldx_0 + 1
    SEC
    LDA #&00
    SBC key_codes + 1
    STA kr_scan_ldx_1 + 1
    SEC
    LDA #&00
    SBC key_codes + 2
    STA kr_scan_ldx_2 + 1
    SEC
    LDA #&00
    SBC key_codes + 3
    STA kr_scan_ldx_3 + 1
    SEC
    LDA #&00
    SBC key_codes + 4
    STA kr_scan_ldx_4 + 1
    CLC
    LDA key_codes
    ADC #&7f
    STA kr_kbd_ldx_0 + 1
    CLC
    LDA key_codes + 1
    ADC #&7f
    STA kr_kbd_ldx_1 + 1
    CLC
    LDA key_codes + 2
    ADC #&7f
    STA kr_kbd_ldx_2 + 1
    CLC
    LDA key_codes + 3
    ADC #&7f
    STA kr_kbd_ldx_3 + 1
    CLC
    LDA key_codes + 4
    ADC #&7f
    STA kr_kbd_ldx_4 + 1
    SEC
    LDA key_codes
    SBC #&01
    STA kr_shift_cpx_0 + 1
    SEC
    LDA key_codes + 1
    SBC #&01
    STA kr_shift_cpx_1 + 1
    SEC
    LDA key_codes + 2
    SBC #&01
    STA kr_shift_cpx_2 + 1
    SEC
    LDA key_codes + 3
    SBC #&01
    STA kr_shift_cpx_3 + 1
    SEC
    LDA key_codes + 4
    SBC #&01
    STA kr_shift_cpx_4 + 1
    LDX #&00
.keyon_copy_handler
    LDA key_remap_handler,X
    STA &d100,X
    INX
    BNE keyon_copy_handler
    LDA #&00
    STA keyv_lo
    LDA #&d1
    STA keyv_hi
    RTS
.cmd_keyon
    JSR keyon_setup
    STROUT msg_keys_redefined
.keyon_rts
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
    JMP keyon_rts

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
.keyname_lookup
    CMP #&00
    BNE keyname_check_caps
    LDA #&03
    BNE keyname_search
.keyname_check_caps
    CMP #&01
    BNE keyname_from_table
    LDA #&04
    BNE keyname_search
.keyname_from_table
    LDX &023c
    STX &a8
    LDX &023d
    STX &a9
    TAY
    LDA (&a8),Y
.keyname_search
    LDX #&f1
    STX &a8
    LDX #&8d
    STX &a9
    LDY #&00
.keyname_scan_loop
    CMP (&a8),Y
    BEQ keyname_found
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
    BCC keyname_scan_loop
    JMP oswrch
.keyname_found
    LDX #&09
    INY
.keyname_print_loop
    LDA (&a8),Y
    JSR oswrch
    INY
    DEX
    BNE keyname_print_loop
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
.kstatus_entry_loop
    LDY #&00
.kstatus_print_dir
    LDA (&aa),Y
    JSR oswrch
    INY
    CPY #&0c
    BNE kstatus_print_dir
    CLC
    LDA &aa
    ADC #&0c
    STA &aa
    LDA &ab
    ADC #&00
    STA &ab
    LDA key_codes,X
    PHX
    DEC A
    JSR keyname_lookup
    JSR osnewl
    PLX
    INX
    CPX #&05
    BNE kstatus_entry_loop
    JSR osnewl
    JMP keyon_rts
.msg_key_redefiner
    EQUS "KEY REDEFINER"
    EQUB &0D
    EQUS "-------------"
    EQUB &0D, 0
.cmd_defkeys
    LDA keyon_active
    BEQ defkeys_start
    LDA #&00
    STA keyon_active
    LDA saved_keyv_lo
    STA keyv_lo
    LDA saved_keyv_hi
    STA keyv_hi
.defkeys_start
    LDA #&81
    LDX #&b6
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BEQ defkeys_start
    JSR osnewl
    STROUT msg_key_redefiner
    JSR osnewl
    LDA #&d0
    STA &aa
    LDA #&8e
    STA &ab
    LDX #&00
.defkeys_header_y
    LDY #&00
.defkeys_header_loop
    LDA (&aa),Y
    JSR oswrch
    INY
    CPY #&0c
    BNE defkeys_header_loop
    CLC
    LDA &aa
    ADC #&0c
    STA &aa
    LDA &ab
    ADC #&00
    STA &ab
    JSR defkeys_wait_key
    INX
    CPX #&05
    BNE defkeys_header_y
    JSR osnewl
    LDA #&0f
    JSR osbyte
    JMP keyon_setup
.defkeys_wait_key
    PHX
.defkeys_read_key
    LDX #&81
.defkeys_store_key
    PHX
    LDA #&81
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BEQ defkeys_check_match
    PLX
    INX
    BNE defkeys_store_key
    BEQ defkeys_read_key
.defkeys_check_match
    PLA
    EOR #&ff
    INC A
    PLX
    STA key_codes,X
    DEC A
    PHX
    PHA
    JSR keyname_lookup
    JSR osnewl
    PLA
    EOR #&ff
    TAX
    PHX
.defkeys_next_entry
    PLX
    PHX
    LDA #&81
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BEQ defkeys_next_entry
    PLX
    PLX
    RTS
.parse_cmdline
    LDY &8a67
    DEY
.parse_skip_spaces
    INY
    LDA (&f2),Y
    CMP #&20
    BEQ parse_skip_spaces
    CMP #&2e
    BEQ parse_skip_spaces
    STY &8a67
    RTS
.alias_semicolon_flag
    EQUB &FF  \ &9032: .
.cmd_alias
    LDA #&00
    STA alias_semicolon_flag
    JSR parse_cmdline
    CMP #&0d
    BNE alias_table_start
    JMP alias_syntax_error
.alias_table_start
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alias_check_end
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ alias_exec_setup
    LDY &8a67
    PHY
    JSR compare_string
    PLY
    STY &8a67
    BCC alias_find_end
    LDA #&ff
    STA alias_semicolon_flag
    LDY #&ff
.alias_skip_name
    INY
    LDA (&a8),Y
    BNE alias_skip_name
    INY
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &aa
    LDA &a9
    ADC #&00
    STA &ab
    LDY #&00
.alias_copy_loop
    LDA (&aa),Y
    STA (&a8),Y
    CMP #&ff
    BNE alias_copy_next
    STA (&a8),Y
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BNE alias_find_end
    BEQ alias_exec_setup
.alias_copy_next
    INY
    BNE alias_copy_loop
    INC &ac
    INC &aa
    LDA &aa
    CMP #&bf
    BCC alias_copy_loop
.alias_find_end
    LDY #&ff
.alias_find_loop
    INY
    LDA (&a8),Y
    BNE alias_find_loop
    INY
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alias_check_end
.alias_exec_setup
    LDA &8a67
    STA &70
    LDY &8a67
    DEY
.alias_exec_copy
    INY
    LDA (&f2),Y
    CMP #&0d
    BNE alias_exec_copy
    TYA
    SEC
    SBC &8a67
    CLC
    ADC &a8
    BCC alias_exec_run
    LDA &a9
    CMP #&be
    BCC alias_exec_run
    JSR copy_inline_to_stack    \ BRK error: "No room for alias"
    EQUS &48, "No room for alias", 0
.alias_exec_run
    CLC
    LDA &f2
    ADC &8a67
    STA &f2
    LDA &f3
    ADC #&00
    STA &f3
    LDY #&00
.alias_skip_ws
    LDA (&f2),Y
    CMP #&20
    BEQ alias_terminate
    CMP #&0d
    BNE alias_upper_case
    JMP alias_clear_entry
.alias_upper_case
    CMP #&61
    BCC alias_store_char
    CMP #&7b
    BCS alias_store_char
    AND #&df
.alias_store_char
    STA (&a8),Y
    INY
    BNE alias_skip_ws
.alias_terminate
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
.alias_parse_arg
    LDA (&f2),Y
    CMP #&0d
    BEQ alias_store_arg
    STA (&a8),Y
    INY
    BNE alias_parse_arg
.alias_store_arg
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
.alias_list_check
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ alias_list_done
    LDY #&ff
.alias_list_name
    INY
    LDA (&a8),Y
    JSR osasci
    CMP #&00
    BNE alias_list_name
    INY
    LDA #&20
    JSR osasci
    LDA #&3d
    JSR osasci
    LDA #&20
    JSR osasci
.alias_list_value
    INY
    LDA (&a8),Y
    JSR osasci
    CMP #&0d
    BNE alias_list_value
    INY
    TYA
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alias_list_check
.alias_list_done
    RTS
.alias_clear_entry
    LDA #&ff
    EQUB &92, &A8  \ STA (0xa8)
    LDA alias_semicolon_flag
    BEQ alias_syntax_error
    RTS
.alias_syntax_error
    JSR copy_inline_to_stack    \ BRK error: "Syntax : ALIAS <alias name> <alias>"
    EQUS &48, "Syntax : ALIAS <alias name> <alias>", 0
.check_alias
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alias_walk_check
    EQUB &B2, &A8  \ LDA (0xa8)
    CMP #&ff
    BEQ alias_cmd_done
    PHY
    JSR compare_string
    BCS alias_exec_entry
    LDY #&ff
.alias_walk_name
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE alias_walk_name
    INY
    CLC
    TYA
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    PLY
    JMP alias_walk_check
.alias_cmd_done
    PLY
    PLX
    PLA
    RTS
.alias_exec_entry
    PLY
    JSR parse_cmdline
    LDY #&ff
.alias_exec_name
    INY
    LDA (&a8),Y
    CMP #&00
    BNE alias_exec_name
    INY
    INY
    STY &93a7
    LDX #&00
.alias_exec_expand
    LDY &93a7
    LDA (&a8),Y
    INY
    STY &93a7
    STA &a55b,X
    INX
    CMP #&0d
    BNE alias_check_percent
    JMP alisv_open
.alias_check_percent
    CMP #&25
    BEQ alias_copy_literal
    JMP alias_exec_expand
.alias_copy_literal
    LDA (&a8),Y
    INY
    STY &93a7
    CMP #&25
    BEQ alias_exec_expand
    DEX
    CMP #&55
    BNE alias_get_param_num
    JMP alisv_write_header
.alias_get_param_num
    SEC
    SBC #&30
    PHX
    TAX
    LDY &8a67
    CMP #&00
    BEQ alias_copy_param
    DEY
.alias_find_param
    INY
    LDA (&f2),Y
    CMP #&0d
    BEQ alias_skip_rest
    CMP #&20
    BNE alias_find_param
    DEX
    BNE alias_find_param
    INY
.alias_copy_param
    PLX
.alias_copy_param_loop
    LDA (&f2),Y
    CMP #&20
    BEQ alias_next_expand
    CMP #&0d
    BEQ alias_next_expand
    BEQ alias_next_expand
    STA &a55b,X
    INX
    INY
    BNE alias_copy_param_loop
.alias_next_expand
    JMP alias_exec_expand
.alias_skip_rest
    PLX
    JMP alias_exec_expand
.alisv_open
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
.alisv_write_header
    LDA #&0b
    JSR osasci
    LDA #&15
    JSR osasci
    JMP alias_exec_expand
.cmd_alild
    JSR parse_cmdline
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
    BEQ alild_not_found
    STA &93a7
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alild_read_loop
    LDY &93a7
    JSR osbget
    BCS alild_close
    EQUB &92, &A8  \ STA (0xa8)
    CLC
    LDA &a8
    ADC #&01
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alild_read_loop
.alild_close
    LDA #&00
    LDY &93a7
    JMP osfind
.alild_not_found
    JSR copy_inline_to_stack    \ BRK error: "Alias file not found"
    EQUS &D6, "Alias file not found", 0
.cmd_alisv
    JSR parse_cmdline
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
    BEQ alild_cant_open
    STA &93a7
    LDA #&65
    STA &a8
    LDA #&b1
    STA &a9
.alild_check_end
    LDY &93a7
    EQUB &B2, &A8  \ LDA (0xa8)
    JSR osbput
    CMP #&ff
    BEQ alild_open_error
    CLC
    LDA &a8
    ADC #&01
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP alild_check_end
.alild_open_error
    LDA #&00
    LDY &93a7
    JMP osfind
.alild_cant_open
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
.store_copy_rom
    LDA &8000,X
    STA &a655,X
    LDA &8100,X
    STA &a755,X
    LDA &8200,X
    STA &a855,X
    LDA &8300,X
    STA &a955,X
    INX
    BNE store_copy_rom
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    AND #&7f
    STA &fe30
    LDA #&ff
    STA &93a6
    RTS
.alias_init
    LDA &93a6
    BEQ alias_init_rts
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    ORA #&80
    STA &fe30
    LDX #&00
.store_restore_rom
    LDA &a655,X
    STA &8000,X
    LDA &a755,X
    STA &8100,X
    LDA &a855,X
    STA &8200,X
    INX
    BNE store_restore_rom
    EQUB &AD, &F4, &00  \ LDA 0x00f4
    AND #&7f
    STA &fe30
.alias_init_rts
    RTS
    EQUB &FF, &24  \ &93A6: .$
.parse_hex_digit
    CMP #&30
    BCC parse_hex_bad
    CMP #&47
    BCS parse_hex_bad
    SEC
    SBC #&30
    CMP #&0a
    BCC parse_hex_ok
    CMP #&11
    BCC parse_hex_bad
    SEC
    SBC #&07
.parse_hex_ok
    CLC
    RTS
.parse_hex_bad
    SEC
    RTS
.parse_hex_word
    LDA #&00
    STA &ae
    STA &af
.parse_hex_loop
    LDA (&f2),Y
    CMP #&0d
    BEQ mem_rts
    CMP #&20
    BEQ mem_rts
    JSR parse_hex_digit
    BCC parse_hex_shift
    JSR copy_inline_to_stack    \ BRK error: "Invalid hex digit"
    EQUS &EB, "Invalid hex digit", 0
.parse_hex_shift
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
    BNE parse_hex_loop
.mem_rts
    RTS
.cmd_mem
    JSR parse_cmdline
    CMP #&0d
    BEQ mem_setup_display
    JSR parse_hex_word
    LDA &ae
    STA &9c68
    LDA &af
    STA &9c69
.mem_setup_display
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
.mem_copy_header
    LDA &9c7e,X
    STA &7c00,X
    DEX
    BPL mem_copy_header
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
.mem_draw_row
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
    BCC mem_next_row
    INC &ad
.mem_next_row
    DEX
    BNE mem_draw_row
.mem_adjust_ptr
    SEC
    LDA &a8
    SBC #&50
    STA &ae
    LDA &a9
    SBC #&00
    STA &af
    JSR dis_setup
    LDA #&81
    LDX #&02
    LDY #&00
    JSR osbyte
    CPY #&1b
    BEQ mem_set_mode
    BCS mem_adjust_ptr
    TXA
    LDX #&04
.mem_check_key
    CMP &9c6f,X
    BEQ mem_dispatch
    DEX
    BPL mem_check_key
    PHA
    LDA &7c27
    CMP #&48
    BEQ mem_handle_hex
    PLA
    LDY &9c6e
    STA (&a8),Y
    JSR mem_cursor_down
    JMP mem_adjust_ptr
.mem_handle_hex
    PLA
    JSR parse_hex_digit
    BCS mem_adjust_ptr
    STA &93a7
    LDY &9c6e
    LDA (&a8),Y
    ASL A
    ASL A
    ASL A
    ASL A
    ORA &93a7
    STA (&a8),Y
    JMP mem_adjust_ptr
.mem_dispatch
    TXA
    ASL A
    TAX
    LDA &9c74,X
    STA cmd_dispatch_addr + 1
    LDA &9c75,X
    STA cmd_dispatch_addr + 2
    JSR cmd_dispatch
    JMP mem_adjust_ptr
.mem_set_mode
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
.mem_cursor_up
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
.mem_cursor_rts
    RTS
.mem_cursor_down
    LDA &9c6e
    INC A
    STA &9c6e
    CMP #&08
    BNE mem_cursor_rts
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
.mem_page_up
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE mem_row_up
    SEC
    LDA &A8
    SBC #&b0
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
    RTS
.mem_row_up
    SEC
    LDA &A8
    SBC #&08
    STA &A8
    LDA &A9
    SBC #&00
    STA &A9
    RTS
.mem_page_down
    LDA #&81
    LDX #&ff
    LDY #&ff
    JSR osbyte
    CPX #&ff
    BNE mem_row_down
    CLC
    LDA &A8
    ADC #&b0
    STA &A8
    LDA &A9
    ADC #&00
    STA &A9
    RTS
.mem_row_down
    CLC
    LDA &A8
    ADC #&08
    STA &A8
    LDA &A9
    ADC #&00
    STA &A9
    RTS
.mem_toggle_mode
    LDA &7C27
    EOR #&09
    STA &7C27
    RTS
.dis_setup
    LDA #&16
    STA dis_temp
    LDA #&51
    STA &ac
    LDA #&7c
    STA &ad
.dis_line_loop
    LDA &af
    JSR dis_print_hex_byte
    LDA &ae
    JSR dis_print_hex_byte
    CLC
    LDA &ac
    ADC #&02
    STA &ac
    BCC dis_hex_dump
    INC &ad
.dis_hex_dump
    LDY #&00
.dis_hex_byte_loop
    LDA (&ae),Y
    JSR dis_print_hex_byte
    INC &ac
    BNE dis_hex_next
    INC &ad
.dis_hex_next
    INY
    CPY #&08
    BNE dis_hex_byte_loop
    CLC
    LDA &ac
    ADC #&01
    STA &ac
    BCC dis_ascii_dump
    INC &ad
.dis_ascii_dump
    LDY #&00
.dis_ascii_loop
    LDA (&ae),Y
    AND #&7f
    CMP #&20
    BCS dis_store_byte
    LDA #&2e
.dis_store_byte
    STA (&ac),Y
    INY
    CPY #&08
    BNE dis_ascii_loop
    CLC
    LDA &ac
    ADC #&09
    STA &ac
    BCC dis_advance_ptr
    INC &ad
.dis_advance_ptr
    CLC
    LDA &ae
    ADC #&08
    STA &ae
    BCC dis_next_line
    INC &af
.dis_next_line
    DEC dis_temp
    BNE dis_line_loop
    LDY #&00
    TYA
.dis_bracket_loop
    STA &7de6,Y
    INY
    INY
    INY
    CPY #&1b
    BNE dis_bracket_loop
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
.dis_print_hex_byte
    STA &965e
    LSR A
    LSR A
    LSR A
    LSR A
    TAX
    LDA &9ca6,X
    EQUB &92, &AC  \ STA (0xac)
    INC &ac
    BNE dis_print_lo_nibble
    INC &ad
.dis_print_lo_nibble
    LDA #&88
    AND #&0f
    TAX
    LDA &9ca6,X
    EQUB &92, &AC  \ STA (0xac)
    INC &ac
    BNE dis_hex_byte_rts
    INC &ad
.dis_hex_byte_rts
    RTS
.dis_print_hex_word
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
    JSR parse_cmdline
    CMP #&0d
    BEQ dis_display_line
    JSR parse_hex_word
    BRA dis_print_header
.dis_display_line
    LDA &9c6a
    STA &ae
    LDA &9c6b
    STA &af
.dis_print_header
    LDA #&82
    JSR oswrch
    JSR oswrch
    LDA &af
    JSR dis_print_hex_word
    LDA &ae
    JSR dis_print_hex_word
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
    BEQ dis_get_mode
    LDA #&83
    JSR oswrch
    LDY #&00
.dis_print_opcode
    LDA (&ac),Y
    JSR oswrch
    INY
    CPY #&03
    BNE dis_print_opcode
    LDA #&20
    JSR oswrch
.dis_get_mode
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
.dis_format_loop
    INY
    LDA (&ac),Y
    BEQ dis_print_addr
    CMP #&68
    BNE dis_check_lo
    JMP dis_check_up
.dis_check_lo
    CMP #&6c
    BNE dis_check_branch
    JMP dis_check_down
.dis_check_branch
    CMP #&62
    BNE dis_print_char
    JMP dis_check_right
.dis_print_char
    JSR oswrch
    BRA dis_format_loop
.dis_print_addr
    LDA #&86
    JSR oswrch
    LDA &0318
    CMP #&16
    BNE dis_print_addr
    PLX
    LDA &96f5,X
    PHA
    TAX
    LDY #&00
.dis_print_byte
    LDA (&ae),Y
    PHX
    JSR dis_print_hex_word
    PLX
    LDA #&20
    JSR oswrch
    INY
    DEX
    BNE dis_print_byte
.dis_print_ascii
    LDA #&85
    JSR oswrch
    LDA &0318
    CMP #&21
    BNE dis_print_ascii
    PLX
    PHX
    LDY #&00
.dis_ascii_char
    LDA (&ae),Y
    AND #&7f
    CMP #&20
    BCS dis_check_del
    LDA #&2e
.dis_check_del
    CMP #&7f
    BNE dis_output_char
    LDA #&ff
.dis_output_char
    JSR oswrch
    INY
    DEX
    BNE dis_ascii_char
    JSR osnewl
    PLA
    CLC
    ADC &ae
    STA &ae
    BCC dis_wait_key
    INC &af
.dis_wait_key
    JSR osrdch
    BCS dis_save_state
    JMP dis_print_header
.dis_save_state
    LDA &ae
    STA &9c6a
    LDA &af
    STA &9c6b
    LDA #&00
    STA &ff
    RTS
.dis_check_up
    PHY
    LDY #&02
    LDA (&ae),Y
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.dis_check_down
    PHY
    LDY #&01
    LDA (&ae),Y
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.dis_check_right
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
    BMI dis_advance
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JSR dis_print_hex_word
    LDA &a8
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.dis_advance
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&ff
    STA &a9
    JSR dis_print_hex_word
    LDA &a8
    JSR dis_print_hex_word
    PLY
    JMP dis_format_loop
.print_backspace
    LDA #&08
    JSR oswrch
    JSR oswrch
    JSR oswrch
    JSR oswrch
    JSR oswrch
    LDY #&01
    LDA (&a8),Y
    BMI bau_space_rts
    STA &9eed
    LDY #&02
    LDA (&a8),Y
    STA &9eec
    PHX
    PHY
    JSR print_decimal
    PLY
    PLX
.bau_space_rts
    RTS
.msg_now_splitting
    EQUS 13, "Now splitting line:      " : EQUB 0
.msg_now_spacing
    EQUS 13, "Now spacing out line:      " : EQUB 0
.cmd_bau
    LDA &0230
    CMP #&0c
    BEQ bau_splitting
    JSR copy_inline_to_stack    \ BRK error: "BAU must be called from BASIC"
    EQUS &5C, "BAU must be called from BASIC", 0
.bau_splitting
    STROUT msg_now_splitting
    LDA &18
    STA &a9
    LDA #&00
    STA &a8
.bau_line_loop
    JSR print_backspace
.bau_check_line
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE bau_get_length
    JMP space_start
.bau_get_length
    LDY #&04
    LDA (&a8),Y
    STA &0900
    DEY
    CMP #&2e
    BNE bau_skip_token
.bau_scan_loop
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE bau_check_colon
    JMP bau_next_line
.bau_check_colon
    CMP #&3a
    BEQ bau_split_here
    CMP #&20
    BNE bau_scan_loop
.bau_scan_char
    INY
    LDA (&a8),Y
    CMP #&20
    BEQ bau_scan_char
    DEY
.bau_split_here
    JMP bau_check_end
.bau_skip_token
    INY
    LDA (&a8),Y
    CMP #&3a
    BEQ bau_check_end
    CMP #&0d
    BNE bau_check_then
    JMP bau_next_line
.bau_check_then
    CMP #&e7
    BNE bau_check_data
    JMP bau_next_line
.bau_check_data
    CMP #&dc
    BNE bau_check_else
    JMP bau_next_line
.bau_check_else
    CMP #&ee
    BNE bau_check_rem
    JMP bau_next_line
.bau_check_rem
    CMP #&f4
    BNE bau_check_quote
    JMP bau_next_line
.bau_check_quote
    CMP #&22
    BNE bau_skip_token
.bau_skip_string
    INY
    LDA (&a8),Y
    CMP #&22
    BEQ bau_skip_token
    CMP #&0d
    BNE bau_skip_string
    JMP bau_next_line
.bau_check_end
    CPY #&04
    BEQ bau_skip_token
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
.bau_copy_byte
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
    BNE bau_copy_byte
    LDA &aa
    CMP &a8
    BNE bau_copy_byte
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
    JMP bau_check_line
.bau_next_line
    LDY #&03
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP bau_line_loop
.space_start
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
    BEQ space_setup
    JSR copy_inline_to_stack    \ BRK error: "Must be called from BASIC!"
    EQUS &5C, "Must be called from BASIC!", 0
.space_setup
    LDA &18
    STA &a9
    STZ &a8
    STROUT msg_now_spacing
.space_line_loop
    JSR print_backspace
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE space_scan_start
    JMP space_save_top
.space_scan_start
    LDY #&03
.space_scan_loop
    INY
    LDA (&a8),Y
    BMI space_check_token
    CMP #&0d
    BNE space_check_bracket
    JMP space_next_line
.space_check_bracket
    CMP #&5b
    BNE space_check_quote
    JMP lvar_display_value
.space_check_quote
    CMP #&22
    BNE space_scan_loop
.space_skip_string
    INY
    LDA (&a8),Y
    CMP #&22
    BEQ space_scan_loop
    CMP #&0d
    BNE space_skip_string
    JMP space_next_line
.space_check_token
    CMP #&8d
    BNE space_check_else
    INY
    INY
    INY
    BNE space_scan_loop
.space_check_else
    CMP #&a7
    BEQ space_scan_loop
    CMP #&c0
    BEQ space_scan_loop
    CMP #&c1
    BEQ space_scan_loop
    CMP #&b0
    BEQ space_scan_loop
    CMP #&c2
    BEQ space_scan_loop
    CMP #&c4
    BEQ space_scan_loop
    CMP #&8a
    BEQ space_scan_loop
    CMP #&f2
    BEQ space_scan_loop
    CMP #&a4
    BEQ space_scan_loop
    CMP #&cf
    BCC space_check_range
    CMP #&d4
    BCS space_check_range
    JMP space_scan_loop
.space_check_range
    CMP #&8f
    BCC space_check_next
    CMP #&94
    BCS space_check_next
    JMP space_scan_loop
.space_check_next
    CMP #&b8
    BNE space_check_lomem
    INY
    LDA (&a8),Y
    CMP #&50
    BEQ space_scan_loop
    DEY
    LDA #&b8
.space_check_lomem
    CMP #&b3
    BNE space_check_rem
    INY
    LDA (&a8),Y
    CMP #&28
    BNE space_insert_lomem
    JMP space_scan_loop
.space_insert_lomem
    DEY
    LDA #&b3
.space_check_rem
    CMP #&f4
    BNE space_insert_space
    JMP space_next_line
.space_insert_space
    INY
    LDA (&a8),Y
    DEY
    CMP #&20
    BNE space_check_cr
    JMP space_scan_loop
.space_check_cr
    CMP #&0d
    BNE space_check_colon
    JMP space_scan_loop
.space_check_colon
    CMP #&3a
    BNE space_do_insert
    JMP space_scan_loop
.space_do_insert
    JSR space_shift_up
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
    BEQ space_insert_byte
    CMP #&80
    BEQ space_insert_byte
    CMP #&81
    BEQ space_insert_byte
    CMP #&8b
    BEQ space_insert_byte
    CMP #&82
    BEQ space_insert_byte
    CMP #&83
    BEQ space_insert_byte
    CMP #&84
    BEQ space_insert_byte
    CMP #&8c
    BEQ space_insert_byte
    CMP #&88
    BEQ space_insert_byte
    INY
    JMP space_scan_loop
.space_next_line
    LDY #&03
    LDA (&a8),Y
    CLC
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JMP space_line_loop
.space_save_top
    LDA &00
    STA &12
    LDA &01
    STA &13
    JSR osnewl
    RTS
.space_insert_byte
    DEY
    JSR space_shift_up
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
    JMP space_scan_loop
.space_shift_up
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
.space_copy_loop
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
    BNE space_copy_loop
    LDA &aa
    CMP &a8
    BNE space_copy_loop
    PLA
    STA &a9
    PLA
    STA &a8
    RTS
.cmd_lvar
    LDA &0230
    CMP #&0c
    BEQ lvar_start
    JSR copy_inline_to_stack    \ BRK error: "VAR works only in BASIC"
    EQUS &4C, "VAR works only in BASIC", 0
.lvar_start
    LDX #&00
.lvar_var_loop
    LDA &0480,X
    STA &a8
    INX
    LDA &0480,X
    DEX
    STA &a9
    CMP #&00
    BEQ lvar_next_var
.lvar_check_type
    TXA
    LSR A
    CLC
    ADC #&40
    JSR oswrch
    LDY #&01
.lvar_skip_name
    INY
    LDA (&a8),Y
    BEQ lvar_print_newline
    JSR oswrch
    BRA lvar_skip_name
.lvar_print_newline
    JSR osnewl
    LDY #&01
    LDA (&a8),Y
    BEQ lvar_next_var
    STA &ac
    DEY
    LDA (&a8),Y
    STA &a8
    LDA &ac
    STA &a9
    BRA lvar_check_type
.lvar_next_var
    INX
    INX
    CPX #&80
    BNE lvar_var_loop
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
    EQUW mem_cursor_up                 \ Address of cursor-up routine
    EQUW mem_cursor_down                 \ Address of cursor-down routine
    EQUW mem_page_down                 \ Address of page-down routine
    EQUW mem_page_up                 \ Address of page-up routine
    EQUW mem_toggle_mode                 \ Address of hex/ascii toggle
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
.lvar_display_value
    INY
.lvar_parse_token
    LDA #&00
    STA &a154
    LDA (&a8),Y
    CMP #&0d
    BNE lvar_check_dot
    JMP lvar_end_of_line
.lvar_check_dot
    CMP #&2e
    BNE lvar_check_string
.lvar_scan_name
    INY
    LDA (&a8),Y
    CMP #&0d
    BNE lvar_check_space
    JMP lvar_end_of_line
.lvar_check_space
    CMP #&20
    BEQ lvar_next_token
    CMP #&3a
    BNE lvar_scan_name
.lvar_next_token
    INY
    BRA lvar_parse_token
.lvar_check_string
    CMP #&22
    BNE lvar_lookup_token
.lvar_string_loop
    INY
    LDA (&a8),Y
    CMP #&0d
    BEQ lvar_end_of_line
    CMP #&22
    BNE lvar_string_loop
    INY
    BRA lvar_parse_token
.lvar_lookup_token
    JSR token_classify
    BCS lvar_print_token
    CMP #&3a
    BNE lvar_check_close
    INY
    BRA lvar_parse_token
.lvar_check_close
    CMP #&5d
    BNE lvar_check_backslash
    JMP lvar_done
.lvar_check_backslash
    CMP #&5c
    BNE lvar_set_indent
.lvar_skip_backslash
    INY
    LDA (&a8),Y
    CMP #&3a
    BEQ lvar_skip_and_continue
    CMP #&0d
    BNE lvar_skip_backslash
    JMP lvar_end_of_line
.lvar_skip_and_continue
    INY
    BRA lvar_parse_token
.lvar_set_indent
    LDA #&03
    STA &a154
.lvar_print_token
    INY
    LDA (&a8),Y
    CMP #&5d
    BEQ lvar_done
    CMP #&0d
    BEQ lvar_end_of_line
    DEC &a154
    BNE lvar_print_token
    CMP #&3a
    BEQ lvar_parse_token
    CMP #&20
    BEQ lvar_print_char
    DEY
    JSR space_shift_up
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
.lvar_print_char
    INY
    LDA (&a8),Y
    CMP #&0d
    BEQ lvar_end_of_line
    CMP #&3a
    BNE lvar_print_char
    INY
    JMP lvar_parse_token
.lvar_end_of_line
    LDY #&03
    CLC
    LDA (&a8),Y
    ADC &a8
    STA &a8
    LDA &a9
    ADC #&00
    STA &a9
    JSR print_backspace
    LDY #&01
    LDA (&a8),Y
    CMP #&ff
    BNE lvar_continuation
    JMP space_save_top
.lvar_continuation
    LDY #&04
    JMP lvar_parse_token
.lvar_done
    JMP space_scan_loop
.xi_support_entry
    LDA #&54
    STA &AC
    LDA #&ae
    STA &AD
    INC xi_alias_count
    LDA xi_alias_count
    BNE xi_supp_inc_cursor
    LDA #&ff
    STA xi_alias_count
.xi_supp_inc_cursor
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
.xi_supp_copy_loop
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
    BNE xi_supp_copy_loop
    LDA &AF
    CMP #&aa
    BNE xi_supp_copy_loop
    LDY xi_cursor_pos
    BEQ xi_supp_save_cr
    LDY #&00
.xi_supp_save_loop
    LDA (&a8),Y
    STA &aa55,Y
    INY
    CPY xi_cursor_pos
    BNE xi_supp_save_loop
.xi_supp_save_cr
    LDA #&0d
    STA alias_buffer,Y
    RTS
.xi_scroll_count
    EQUB &A6                   \ &9DFD: scroll counter variable
.xi_supp_restore
    LDA #&0D
    STA alias_end_hi
    LDA xi_scroll_count
    CMP #&FF
    BNE xi_supp_check_count
    LDA #&00
    STA xi_scroll_count
.xi_supp_check_count
    CMP xi_alias_count
    BCC xi_supp_set_ptr
    LDA xi_alias_count
    DEC A
    STA xi_scroll_count
.xi_supp_set_ptr
    LDA #&55
    STA &AE
    LDA #&aa
    STA &AF
    LDX xi_scroll_count
    BNE xi_supp_check_end
.xi_supp_clear_and_load
    JSR xi_do_clear
    EQUB &B2, &AE  \ LDA (&ae)
    CMP #&0d
    BNE xi_supp_find_cr
    JMP xi_read_loop
.xi_supp_find_cr
    LDY #&ff
.xi_supp_find_loop
    INY
    LDA (&ae),Y
    STA xi_char
    CMP #&0d
    BNE xi_supp_insert_char
    JMP xi_read_loop
.xi_supp_insert_char
    PHY
    JSR xi_do_insert
    PLY
    BRA xi_supp_find_loop
.xi_supp_check_end
    LDY #&00
.xi_supp_check_loop
    LDA (&ae),Y
    CMP #&0d
    BEQ xi_supp_advance
    INY
    BNE xi_supp_check_loop
    LDA #&00
    STA xi_scroll_count
    JMP xi_supp_restore
.xi_supp_advance
    INY
    TYA
    CLC
    ADC &AE
    STA &AE
    LDA &AF
    ADC #&00
    STA &AF
    DEX
    BEQ xi_supp_clear_and_load
    CMP #&ae
    BCC xi_supp_check_end
    LDA &AE
    CMP #&55
    BCC xi_supp_check_end
    LDA #&00
    STA xi_scroll_count
    JMP xi_supp_restore
.token_classify
    CMP #&45
    BNE token_check_80
    LDA #&04
    STA &a154
    BRA token_found
.token_check_80
    CMP #&80
    BNE token_check_82
    LDA #&01
    STA &a154
    BRA token_found
.token_check_82
    CMP #&82
    BNE token_check_84
    LDA #&01
    STA &a154
    BRA token_found
.token_check_84
    CMP #&84
    BNE token_not_found
    LDA #&02
    STA &a154
    BRA token_found
.token_not_found
    CLC
    RTS
.token_found
    SEC
    RTS
.print_decimal
    LDY #&00
.print_dec_loop
    LDX #&10
    LDA #&00
.print_dec_shift
    ASL &9eec
    ROL &9eed
    ROL A
    CMP #&0a
    BCC print_dec_next_bit
    SBC #&0a
    INC &9eec
.print_dec_next_bit
    DEX
    BNE print_dec_shift
    CLC
    ADC #&30
    PHA
    INY
    LDA &9eec
    ORA &9eed
    BNE print_dec_loop
.print_dec_done
    CPY #&05
    BEQ print_dec_output
    LDA #&20
    PHA
    INY
    BNE print_dec_done
.print_dec_output
    STY &9eee
.print_dec_digit
    PLA
    JSR oswrch
    DEC &9eee
    BNE print_dec_digit
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
