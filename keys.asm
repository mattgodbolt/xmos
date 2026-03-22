\ keys.asm — Key system: remap handler, KEYON/OFF, KSTATUS, DEFKEYS

.key_remap_handler
    PHP
    CMP #&81
    BEQ key_remap_scan
    CMP #&79
    BEQ key_remap_keyboard
    PLP
.key_remap_jmp1
    JMP &FFFF                   \ Patched: original KEYV address
\ Scan handler: remap key codes for OSBYTE &81
\ Each CPX/LDX pair is patched by KEYON with the configured key codes
.key_remap_scan
    CPY #&ff
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
    JMP &FFFF                   \ Patched: original KEYV address

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
    JMP &FFFF                   \ Patched: original KEYV address

\ Shifted handler: call original KEYV then remap results
.key_remap_shifted
    PLP
.key_remap_jsr
    JSR &FFFF                   \ Patched: call original KEYV
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
    EQUB &00
.saved_keyv_hi
    EQUB &00
.keyon_active
    EQUB &00
.key_codes                      \ 5-byte table of key scan codes to remap
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
    SEC : LDA #&00 : SBC key_codes
    STA kr_scan_ldx_0 + 1
    SEC : LDA #&00 : SBC key_codes + 1
    STA kr_scan_ldx_1 + 1
    SEC : LDA #&00 : SBC key_codes + 2
    STA kr_scan_ldx_2 + 1
    SEC : LDA #&00 : SBC key_codes + 3
    STA kr_scan_ldx_3 + 1
    SEC : LDA #&00 : SBC key_codes + 4
    STA kr_scan_ldx_4 + 1
    CLC : LDA key_codes : ADC #&7f
    STA kr_kbd_ldx_0 + 1
    CLC : LDA key_codes + 1 : ADC #&7f
    STA kr_kbd_ldx_1 + 1
    CLC : LDA key_codes + 2 : ADC #&7f
    STA kr_kbd_ldx_2 + 1
    CLC : LDA key_codes + 3 : ADC #&7f
    STA kr_kbd_ldx_3 + 1
    CLC : LDA key_codes + 4 : ADC #&7f
    STA kr_kbd_ldx_4 + 1
    SEC : LDA key_codes : SBC #&01
    STA kr_shift_cpx_0 + 1
    SEC : LDA key_codes + 1 : SBC #&01
    STA kr_shift_cpx_1 + 1
    SEC : LDA key_codes + 2 : SBC #&01
    STA kr_shift_cpx_2 + 1
    SEC : LDA key_codes + 3 : SBC #&01
    STA kr_shift_cpx_3 + 1
    SEC : LDA key_codes + 4 : SBC #&01
    STA kr_shift_cpx_4 + 1
    LDX #&00
.keyon_copy_handler
    LDA key_remap_handler,X
    STA keyon_handler_dest,X
    INX
    BNE keyon_copy_handler
    LDA #&00 : STA keyv_lo
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
    EQUS 13, "Redefined keys on, and are:", 13, 13, 0
\ ============================================================================
\ *KEYOFF — Disable redefined keys
\ ============================================================================
.cmd_keyoff
    LDA keyon_active            \ Already disabled?
    BEQ keyoff_print_msg
    LDA #&00 : STA keyon_active
    LDA saved_keyv_lo           \ Restore original KEYV
    STA keyv_lo
    LDA saved_keyv_hi
    STA keyv_hi
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
    LDX os_key_trans
    STX zp_ptr_lo
    LDX os_key_trans_hi
    STX zp_ptr_hi
    TAY
    LDA (zp_ptr_lo),Y
.keyname_search
    LDX #&f1
    STX zp_ptr_lo
    LDX #&8d
    STX zp_ptr_hi
    LDY #&00
.keyname_scan_loop
    CMP (&a8),Y
    BEQ keyname_found
    FOR n, 1, 10 : INY : NEXT   \ skip 10-byte entry (keycode + 9-char name)
    CPY #&96
    BCC keyname_scan_loop
    JMP oswrch
.keyname_found
    LDX #&09
    INY
.keyname_print_loop
    LDA (zp_ptr_lo),Y
    JSR oswrch
    INY
    DEX
    BNE keyname_print_loop
    RTS
\ --- DEFKEYS joystick direction labels (12 chars each) ---
.defkeys_direction_labels
    EQUS "     Left : "         \ 12 bytes each
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
    STA zp_work_lo
    LDA #&8e
    STA zp_work_hi
    LDX #&00
.kstatus_entry_loop
    LDY #&00
.kstatus_print_dir
    LDA (zp_work_lo),Y
    JSR oswrch
    INY
    CPY #&0c
    BNE kstatus_print_dir
    CLC : LDA zp_work_lo : ADC #&0c
    STA zp_work_lo
    LDA zp_work_hi
    ADC #&00
    STA zp_work_hi
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
    EQUS "KEY REDEFINER", 13, "-------------", 13, 0
.cmd_defkeys
    LDA keyon_active
    BEQ defkeys_start
    LDA #&00 : STA keyon_active
    LDA saved_keyv_lo : STA keyv_lo
    LDA saved_keyv_hi : STA keyv_hi
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
    STA zp_work_lo
    LDA #&8e
    STA zp_work_hi
    LDX #&00
.defkeys_header_y
    LDY #&00
.defkeys_header_loop
    LDA (zp_work_lo),Y
    JSR oswrch
    INY
    CPY #&0c
    BNE defkeys_header_loop
    CLC : LDA zp_work_lo : ADC #&0c
    STA zp_work_lo
    LDA zp_work_hi
    ADC #&00
    STA zp_work_hi
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
    LDY compare_string_y
    DEY
.parse_skip_spaces
    INY
    LDA (cmd_line_lo),Y
    CMP #' '
    BEQ parse_skip_spaces
    CMP #'.'
    BEQ parse_skip_spaces
    STY compare_string_y
    RTS
.alias_semicolon_flag
    EQUB &ff
