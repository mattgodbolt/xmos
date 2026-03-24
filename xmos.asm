\ ============================================================================
\ XMOS — MOS Extension ROM
\ By Richard Talbot-Watkins and Matt Godbolt, 1992
\ Reverse engineered disassembly
\ ============================================================================

CPU 1                           \ 65C02

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
    EQUB LO(copyright_ptr - &8000)  \ Copyright offset from ROM start
.rom_start
    EQUB &01                    \ Version number
    EQUS "MOS Extension"        \ ROM title
.copyright_ptr
    EQUS 0, "(C) RTW and MG 1992", 0

\ ============================================================================
\ Service entry — dispatches on service call number in A
\ Handles four service calls:
\   svc_command      — intercept unrecognised * commands
\   svc_help         — respond to *HELP requests
\   svc_post_reset   — reinitialise state after a break/reset
\   svc_claim_static — reserve one byte of static workspace
\ ============================================================================
.service_entry
    CMP #svc_command
    BNE not_command
    JMP handle_command
.not_command
    CMP #svc_help
    BEQ handle_help
    CMP #svc_post_reset
    BNE not_reset
    JMP handle_reset
.not_reset
    CMP #svc_claim_static
    BEQ handle_claim_static
    RTS

\ Claim one byte of static workspace (Y is decremented to allocate)
\ and record its address in the ROM workspace table for later use.
.handle_claim_static
    DEY
    TYA
    STA rom_workspace_table,X
    LDA #svc_claim_static
    RTS
\ ============================================================================
\ *HELP handler (service call &09)
\ Bare *HELP — prints the ROM title and sub-topic keywords (XMOS, FEATURES).
\ *HELP XMOS — lists every command with its one-line help text.
\ *HELP FEATURES — prints the extended feature documentation block.
\ *HELP <cmd> — prints the help entry for a single command if found.
\ ============================================================================
{
.*handle_help
        PHA : PHX : PHY
        LDX #&00
.print_loop
        LDA (cmd_line_lo),Y     \ Check if bare *HELP (CR = end of line)
        CMP #&0D
        BNE help_has_argument
        LDA help_title_text,X   \ Print help title string
        BEQ done
        JSR osasci
        INX
        BNE print_loop
.done
        PLY : PLX : PLA
        RTS
.help_title_text
        EQUS 13, "MOS Extension", 13, "  XMOS", 13, "  FEATURES", 13, 0
.features_keyword
        EQUS "FEATURES", 0
\ *HELP with an argument — check for "XMOS", "FEATURES", or a command name
.help_has_argument
        PHY
        LDA #LO(xmos_keyword) : STA zp_ptr_lo
        LDA #HI(xmos_keyword) : STA zp_ptr_hi
        JSR compare_string      \ Compare argument against "XMOS"
        BCC help_try_features
        PLY
    \ Matched "XMOS" — print all commands from the command table
        LDA #LO(command_table) : STA zp_ptr_lo
        LDA #HI(command_table) : STA zp_ptr_hi
        JSR print_inline
        EQUS 13, "MOS Extension commands:", &0E, 13, 0
        LDA #LO(command_table) : STA zp_ptr_lo
        LDA #HI(command_table) : STA zp_ptr_hi
.help_print_loop
        LDY #&00
        LDA (zp_ptr_lo)
        CMP #&FF                \ End of table marker?
        BEQ help_done
        LDA #' ' : JSR osasci : JSR osasci  \ two space indent
.print_name                     \ Print command name
        LDA (zp_ptr_lo),Y
        BEQ name_done
        JSR osasci
        INY
        BNE print_name
.name_done
        TYA                     \ Pad with spaces to column 11
        SEC                     \ (9 - name_length spaces)
        SBC #&09
        EOR #&FF : INC A        \ negate
        TAX
.pad_loop
        LDA #' ' : JSR osasci
        DEX
        BNE pad_loop
        INY : INY : INY         \ skip null + handler address
        DEY                     \ back up (print_help starts with INY)
.print_help                     \ Print help text
        INY
        LDA (zp_ptr_lo),Y
        BEQ help_text_done
        JSR osasci
        BRA print_help
.help_text_done
        JSR osnewl
        INY                     \ Advance pointer past this entry
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
.print_loop_2
        LDA (zp_ptr_lo),Y
        BEQ done_2
        JSR osasci
        INY
        BNE print_loop_2
        INC zp_ptr_hi
        BRA print_loop_2
.done_2
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
        LDY #&00
.skip_name                      \ Skip past command name
        INY
        LDA (zp_ptr_lo),Y
        BNE skip_name
        INY : INY : INY         \ skip null + handler address
.skip_help                      \ Skip past help text
        INY
        LDA (zp_ptr_lo),Y
        BNE skip_help
        INY                     \ Advance pointer to next entry
        CLC
        TYA
        ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi
        ADC #&00
        STA zp_ptr_hi
        PLY
        LDA (zp_ptr_lo)
        CMP #&FF                \ End of table?
        BNE help_try_next_cmd
        LDA #&0F                \ Print mode 0 (reset double height)
        JSR osasci
        PLY : PLX : PLA
        RTS

\ Matched a specific command — print its help entry
.help_print_single_cmd
        PLY
        LDA #' ' : JSR osasci : JSR osasci
        LDY #&FF
.print_name_2                   \ Print command name
        INY
        LDA (zp_ptr_lo),Y
        JSR osasci
        CMP #&00
        BNE print_name_2
        TYA                     \ Pad with spaces to column 11
        SEC
        SBC #&09
        EOR #&FF : INC A        \ negate
        TAX
.pad_loop_2
        LDA #' ' : JSR osasci
        DEX
        BNE pad_loop_2
        INY : INY : INY         \ skip handler address + offset
.print_help_text                \ Print the help description
        LDA (zp_ptr_lo),Y
        BEQ done_3
        JSR osasci
        INY
        BNE print_help_text
.done_3
        JSR osnewl
        PLY : PLX : PLA
        RTS

\ ============================================================================
\ * command handler (service call &04) — dispatch unrecognised commands
\ Walks the command table comparing each entry's name against the input.
\ On a match, copies the handler address into a self-modifying JMP instruction
\ and calls it via JSR so the handler can simply RTS to return here.
\ If no built-in command matches, falls through to the alias checker.
}

\ ============================================================================
{
.*handle_command
        PHA : PHX : PHY
        LDA #LO(command_table)
        STA zp_ptr_lo
        LDA #HI(command_table)
        STA zp_ptr_hi
.cmd_try_next
        PHY
        LDA (zp_ptr_lo)
        CMP #&FF                \ End of command table?
        BEQ cmd_not_found
        JSR compare_string
        BCS cmd_found
        LDY #&00
.skip_name_2                    \ Skip command name
        INY
        LDA (zp_ptr_lo),Y
        BNE skip_name_2
        INY : INY : INY         \ skip null + handler address
.skip_help                      \ Skip help text
        INY
        LDA (zp_ptr_lo),Y
        BNE skip_help
        INY                     \ Advance past help text null terminator
        TYA
        CLC
        ADC zp_ptr_lo
        STA zp_ptr_lo
        LDA zp_ptr_hi
        ADC #&00
        STA zp_ptr_hi
        PLY
        JMP cmd_try_next

.cmd_not_found
        PLY
        JMP check_alias         \ Not a built-in command, try aliases

.cmd_found
        PLY
        LDY #&00
.skip_cmd_name                  \ Skip past command name to handler address
        INY
        LDA (zp_ptr_lo),Y
        BNE skip_cmd_name
        INY
        LDA (zp_ptr_lo),Y       \ Load handler address low byte
        STA cmd_dispatch_addr + 1
        INY
        LDA (zp_ptr_lo),Y       \ Load handler address high byte
        STA cmd_dispatch_addr + 2
        JSR cmd_dispatch
        PLY : PLX : PLA
        LDA #&00                \ Claim the service call
        RTS

}
\ Trampoline: the JMP target is patched at runtime by handle_command.
\ The default target is arbitrary — it is always overwritten before use.
.cmd_dispatch
.cmd_dispatch_addr
    JMP cmd_keyoff              \ Self-modified: handler address written here
\ ============================================================================
\ Command table
\ Each entry: null-terminated name, 2-byte handler address (little-endian),
\ null-terminated help text. The table ends with a single &FF byte.
\ ============================================================================
.command_table
    EQUS "ALIAS", 0 : EQUW cmd_alias : EQUS "<alias name> <alias>", 0
    EQUS "ALIASES", 0 : EQUW cmd_aliases : EQUS "Shows active aliases", 0
    EQUS "ALICLR", 0 : EQUW cmd_aliclr : EQUS "Clears all aliases", 0
    EQUS "ALILD", 0 : EQUW cmd_alild : EQUS "Loads alias file", 0
    EQUS "ALISV", 0 : EQUW cmd_alisv : EQUS "Saves alias file", 0
    EQUS "BAU", 0 : EQUW cmd_bau : EQUS "Splits to single commands", 0
    EQUS "DEFKEYS", 0 : EQUW cmd_defkeys : EQUS "Defines new keys", 0
    EQUS "DIS", 0 : EQUW cmd_dis : EQUS "<addr> - disassemble memory", 0
    EQUS "KEYON", 0 : EQUW cmd_keyon : EQUS "Enables redefined keys", 0
    EQUS "KEYOFF", 0 : EQUW cmd_keyoff : EQUS "Disables redefined keys", 0
    EQUS "KSTATUS", 0 : EQUW cmd_kstatus : EQUS "Displays KEYON status", 0
    EQUS "L", 0 : EQUW cmd_l : EQUS "Selects mode 128", 0
    EQUS "LVAR", 0 : EQUW cmd_lvar : EQUS "Shows current variables", 0
    EQUS "MEM", 0 : EQUW cmd_mem : EQUS "<addr> - memory editor", 0
    EQUS "S", 0 : EQUW cmd_s : EQUS "Saves BASIC with incore name", 0
    EQUS "SPACE", 0 : EQUW cmd_space : EQUS "Inserts spaces into programs", 0
    EQUS "STORE", 0 : EQUW cmd_store : EQUS "Keeps function keys on break", 0
    EQUS "XON", 0 : EQUW cmd_xon : EQUS "Enables extended input", 0
    EQUS "XOFF", 0 : EQUW cmd_xoff : EQUS "Disables extended input", 0
    EQUB &FF                    \ End of command table
.xmos_keyword
    EQUS "XMOS", 0
\ ============================================================================
\ *XON — Enable extended input (line-editing enhancements).
\ Sets the XON flag and switches cursor keys to editing mode via OSBYTE 4.
\ ============================================================================
.cmd_xon
    LDA #&FF
    STA xon_flag
    LDA #&04                    \ OSBYTE 4: set cursor key status
    LDX #&01                    \ X=1: cursor editing mode
    LDY #&00
    JMP osbyte

\ ============================================================================
\ *XOFF — Disable extended input, restoring normal cursor key behaviour.
\ Clears the XON flag and resets cursor keys to normal mode via OSBYTE 4.
\ ============================================================================
.cmd_xoff
    LDA #&00
    STA xon_flag
    LDA #&04                    \ OSBYTE 4: set cursor key status
    LDX #&00                    \ X=0: normal cursor keys
    LDY #&00
    JMP osbyte

\ Ring the bell (used to signal errors or invalid key presses).
.beep
    LDA #&07                    \ BEL character
    JMP oswrch
\ --- Workspace variables (in sideways RAM, overwritten at runtime) ---
\ These live in the ROM image but are mutated in sideways RAM at runtime.
\ Initial values here are the defaults set after the ROM is first loaded.
.xon_flag
    EQUB &FF                    \ non-zero = extended input (XON) is active
.xi_line_len
    EQUB &1A                    \ total length of the current input line
.xi_cursor_pos
    EQUB &1A                    \ insertion point within the current input line
.xi_char
    EQUB &0D                    \ last character read during input processing
.xi_temp
    EQUB &08                    \ scratch byte used during number parsing

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

\ ============================================================================
\ Workspace layout overlay
\ The workspace_start region contains runtime workspace: store buffers,
\ alias expansion buffer, command history, keyword table, and the alias
\ table. The ROM image has development-era junk here which is preserved
\ for byte-identical output but overwritten at runtime.
\
\ This overlay defines labels at the correct addresses without
\ changing the binary output (SAVE has already captured the bytes).
\ ============================================================================
CLEAR workspace_start, &C000
ORG workspace_start
.alias_oscli_buf SKIP 5         \ OSCLI command buffer for alias expansion
.store_buf_3    SKIP 250        \ *STORE buffer: ANDY page 3 (&8300-&83FF)
.store_buf_0    SKIP 256        \ *STORE buffer: ANDY page 0 (&8000-&80FF)
                                \ (overlaps last 6 bytes of store_buf_3)
.store_buf_1    SKIP 256        \ *STORE buffer: ANDY page 1 (&8100-&81FF)
.store_buf_2    SKIP 256        \ *STORE buffer: ANDY page 2 (&8200-&82FF)
.alias_exec_buf SKIP 256        \ Alias execution buffer
.xi_hist_buffer SKIP 1022       \ Command history buffer
.xi_hist_term   SKIP 1          \ History entry terminator (set to &0D)
.xi_hist_flag   SKIP 1          \ History state flag
                                \ basic_keyword_table follows (label in data.asm)
    SKIP 784                    \ Keyword table, stored key defs, alias preamble
.alias_clear_flag               \ Alias table start (first byte = &FF sentinel)
