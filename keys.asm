\ keys.asm — Key system: remap handler, KEYON/OFF, KSTATUS, DEFKEYS

\ ============================================================================
\ BYTEV intercept handler — makes the five chosen keys stand in for the
\ game keys Z, X, :, / and RETURN when a program reads the keyboard with
\ OSBYTE &81 (INKEY) or OSBYTE &79 (keyboard scan); every other OSBYTE
\ goes straight to the original BYTEV.
\ This entire block is copied to RAM at &D100 by KEYON, which patches the
\ CPX/LDX pairs with the user's chosen keys first.
\ ============================================================================
.key_remap_handler
    PHP
    CMP #&81
    BEQ key_remap_inkey
    CMP #&79
    BEQ key_remap_test_key
    PLP
.key_remap_jmp1
    JMP &FFFF                   \ Patched: original BYTEV address
\ OSBYTE &81 with Y=&FF (negative INKEY): a test for one of the game keys
\ becomes a test for the key chosen in its place.
.key_remap_inkey
    CPY #&ff
    BNE key_remap_inkey_pass
.kr_inkey_cpx_0
    CPX #&9E
    BNE kr_inkey_1
.kr_inkey_ldx_0
    LDX #&BF
.kr_inkey_1
.kr_inkey_cpx_1
    CPX #&BD
    BNE kr_inkey_2
.kr_inkey_ldx_1
    LDX #&FE
.kr_inkey_2
.kr_inkey_cpx_2
    CPX #&B7
    BNE kr_inkey_3
.kr_inkey_ldx_2
    LDX #&B7
.kr_inkey_3
.kr_inkey_cpx_3
    CPX #&97
    BNE kr_inkey_4
.kr_inkey_ldx_3
    LDX #&97
.kr_inkey_4
.kr_inkey_cpx_4
    CPX #&B6
    BNE key_remap_inkey_pass
.kr_inkey_ldx_4
    LDX #&B6
.key_remap_inkey_pass
    PLP
.key_remap_jmp2
    JMP &FFFF                   \ Patched: original BYTEV address

\ OSBYTE &79 with X>=&80 tests one key (internal key number + &80): a test
\ for a game key becomes a test for its replacement. X<&80 is a scan from
\ key X upward, handled below.
.key_remap_test_key
    CPX #&80
    BCC key_remap_scan_from
.kr_test_cpx_0
    CPX #&E1
    BNE kr_test_1
.kr_test_ldx_0
    LDX #&C0
.kr_test_1
.kr_test_cpx_1
    CPX #&C2
    BNE kr_test_2
.kr_test_ldx_1
    LDX #&81
.kr_test_2
.kr_test_cpx_2
    CPX #&C8
    BNE kr_test_3
.kr_test_ldx_2
    LDX #&C8
.kr_test_3
.kr_test_cpx_3
    CPX #&E8
    BNE kr_test_4
.kr_test_ldx_3
    LDX #&E8
.kr_test_4
.kr_test_cpx_4
    CPX #&C9
    BNE kr_test_pass
.kr_test_ldx_4
    LDX #&C9
.kr_test_pass
    PLP
.key_remap_jmp3
    JMP &FFFF                   \ Patched: original BYTEV address

\ OSBYTE &79 scan: call the original BYTEV, then report a replacement key
\ that the scan found as its game key, also storing the game key (+&80) in &EC,
\ the MOS's record of the key currently pressed.
.key_remap_scan_from
    PLP
.key_remap_jsr
    JSR &FFFF                   \ Patched: call original BYTEV
    PHP
.kr_scan_from_cpx_0
    CPX #&40
    BNE kr_scan_from_1
.kr_scan_from_ldx_0
    LDX #&E1 : STX os_last_key
.kr_scan_from_orig_0
    LDX #&61
.kr_scan_from_1
.kr_scan_from_cpx_1
    CPX #&01
    BNE kr_scan_from_2
.kr_scan_from_ldx_1
    LDX #&C2 : STX os_last_key
.kr_scan_from_orig_1
    LDX #&42
.kr_scan_from_2
.kr_scan_from_cpx_2
    CPX #&48
    BNE kr_scan_from_3
.kr_scan_from_ldx_2
    LDX #&C8 : STX os_last_key
.kr_scan_from_orig_2
    LDX #&48
.kr_scan_from_3
.kr_scan_from_cpx_3
    CPX #&68
    BNE kr_scan_from_4
.kr_scan_from_ldx_3
    LDX #&E8 : STX os_last_key
.kr_scan_from_orig_3
    LDX #&68
.kr_scan_from_4
.kr_scan_from_cpx_4
    CPX #&49
    BNE kr_scan_from_done
.kr_scan_from_ldx_4
    LDX #&C9 : STX os_last_key
.kr_scan_from_orig_4
    LDX #&49
.kr_scan_from_done
    PLP
    RTS

\ --- State variables ---
.saved_bytev_lo
    EQUB &00
.saved_bytev_hi
    EQUB &00
.keyon_active                   \ Non-zero when key remapping is active
    EQUB &00
.key_codes                      \ 5 keys, as negated INKEY numbers (internal key number + 1): left, right, up, down, fire
    EQUB &41, &02, &49, &69, &4A
.keyon_already_msg
    STROUT msg_keyon_already
    JMP keyon_rts
\ Install the key remap handler: save the current BYTEV, compute the forms
\ of each key in key_codes that the handler compares against (INKEY number,
\ internal number + &80, internal number), patch them in, copy the handler
\ to RAM, and point BYTEV at the copy.
.keyon_setup
{
        LDA keyon_active
        BNE keyon_already_msg
        LDA #&01 : STA keyon_active
        LDA bytev_lo : STA key_remap_jmp1 + 1 : STA key_remap_jmp2 + 1
        STA key_remap_jmp3 + 1 : STA key_remap_jsr + 1 : STA saved_bytev_lo
        LDA bytev_hi : STA key_remap_jmp1 + 2 : STA key_remap_jmp2 + 2
        STA key_remap_jmp3 + 2 : STA key_remap_jsr + 2 : STA saved_bytev_hi
        SEC : LDA #&00 : SBC key_codes
        STA kr_inkey_ldx_0 + 1
        SEC : LDA #&00 : SBC key_codes + 1
        STA kr_inkey_ldx_1 + 1
        SEC : LDA #&00 : SBC key_codes + 2
        STA kr_inkey_ldx_2 + 1
        SEC : LDA #&00 : SBC key_codes + 3
        STA kr_inkey_ldx_3 + 1
        SEC : LDA #&00 : SBC key_codes + 4
        STA kr_inkey_ldx_4 + 1
        CLC : LDA key_codes : ADC #&7f
        STA kr_test_ldx_0 + 1
        CLC : LDA key_codes + 1 : ADC #&7f
        STA kr_test_ldx_1 + 1
        CLC : LDA key_codes + 2 : ADC #&7f
        STA kr_test_ldx_2 + 1
        CLC : LDA key_codes + 3 : ADC #&7f
        STA kr_test_ldx_3 + 1
        CLC : LDA key_codes + 4 : ADC #&7f
        STA kr_test_ldx_4 + 1
        SEC : LDA key_codes : SBC #&01
        STA kr_scan_from_cpx_0 + 1
        SEC : LDA key_codes + 1 : SBC #&01
        STA kr_scan_from_cpx_1 + 1
        SEC : LDA key_codes + 2 : SBC #&01
        STA kr_scan_from_cpx_2 + 1
        SEC : LDA key_codes + 3 : SBC #&01
        STA kr_scan_from_cpx_3 + 1
        SEC : LDA key_codes + 4 : SBC #&01
        STA kr_scan_from_cpx_4 + 1
        LDX #&00
.loop
        LDA key_remap_handler,X : STA keyon_handler_dest,X
        INX
        BNE loop
        LDA #LO(keyon_handler_dest) : STA bytev_lo
        LDA #HI(keyon_handler_dest) : STA bytev_hi
        RTS
}
\ *KEYON — Activate key remapping with the current key_codes definitions
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
    LDA saved_bytev_lo : STA bytev_lo  \ Restore original BYTEV
    LDA saved_bytev_hi : STA bytev_hi
.keyoff_print_msg
    STROUT msg_keys_off
    JMP keyon_rts

\ --- Key name lookup table ---
\ Each entry: the key's code in the MOS key translation table (&03 and &04
\ stand in for SHIFT and CTRL, which have none), then a 9-char padded name.
\ Used by KSTATUS and DEFKEYS to display key names
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
\ Print the name of the key whose internal key number is in A.
\ SHIFT (&00) and CTRL (&01) map to &03 and &04; other keys are translated
\ via the MOS key table before searching the name table. A key not in the
\ table is printed as its character.
.keyname_lookup
{
        CMP #&00
        BNE check_caps
        LDA #&03
        BNE search
.check_caps
        CMP #&01
        BNE from_table
        LDA #&04
        BNE search
.from_table
        LDX os_key_trans : STX zp_ptr_lo
        LDX os_key_trans_hi : STX zp_ptr_hi
        TAY
        LDA (zp_ptr_lo),Y
.search
        LDX #LO(key_name_table) : STX zp_ptr_lo
        LDX #HI(key_name_table) : STX zp_ptr_hi
        LDY #&00
.scan_loop
        CMP (zp_ptr_lo),Y
        BEQ found
        FOR n, 1, 10 : INY : NEXT  \ skip 10-byte entry (keycode + 9-char name)
        CPY #&96
        BCC scan_loop
        JMP oswrch
.found
        LDX #&09
        INY
.print_loop
        LDA (zp_ptr_lo),Y
        JSR oswrch
        INY
        DEX
        BNE print_loop
        RTS
}
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
\ Print the current remapping state: if active, show each direction label
\ followed by the name of the key assigned to it from key_codes.
.cmd_kstatus
{
        LDA keyon_active
        BEQ kstatus_not_active
        STROUT msg_keys_on
        LDA #LO(defkeys_direction_labels) : STA zp_work_lo
        LDA #HI(defkeys_direction_labels) : STA zp_work_hi
        LDX #&00
.loop
        LDY #&00
.print_dir
        LDA (zp_work_lo),Y
        JSR oswrch
        INY
        CPY #&0c
        BNE print_dir
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
        BNE loop
        JSR osnewl
        JMP keyon_rts
}
.msg_key_redefiner
    EQUS "KEY REDEFINER", 13, "-------------", 13, 0
\ ============================================================================
\ *DEFKEYS — Interactive key redefiner
\ Disables any active remapping first, then prompts for each of the 5
\ joystick directions (left/right/up/down/fire) by printing the direction
\ label and waiting for the user to press a key. Stores the chosen internal
\ key numbers into key_codes, then calls keyon_setup to activate them.
\ ============================================================================
.cmd_defkeys
{
        LDA keyon_active
        BEQ start
        LDA #&00 : STA keyon_active
        LDA saved_bytev_lo : STA bytev_lo
        LDA saved_bytev_hi : STA bytev_hi
.start
        LDA #&81
        LDX #&b6
        LDY #&ff
        JSR osbyte
        CPX #&ff
        BEQ start
        JSR osnewl
        STROUT msg_key_redefiner
        JSR osnewl
        LDA #LO(defkeys_direction_labels) : STA zp_work_lo
        LDA #HI(defkeys_direction_labels) : STA zp_work_hi
        LDX #&00
.header_y
        LDY #&00
.header_loop
        LDA (zp_work_lo),Y
        JSR oswrch
        INY
        CPY #&0c
        BNE header_loop
        CLC : LDA zp_work_lo : ADC #&0c
        STA zp_work_lo
        LDA zp_work_hi
        ADC #&00
        STA zp_work_hi
        JSR defkeys_wait_key
        INX
        CPX #&05
        BNE header_y
        JSR osnewl
        LDA #&0f
        JSR osbyte
        JMP keyon_setup
}
\ Wait for a keypress using negative INKEY scanning: tries INKEY numbers
\ &81..&FF until one is pressed, stores it negated in key_codes, prints
\ the key name, then waits for key release.
.defkeys_wait_key
{
        PHX
.read_key
        LDX #&81
.store_key
        PHX
        LDA #&81
        LDY #&ff
        JSR osbyte
        CPX #&ff
        BEQ check_match
        PLX
        INX
        BNE store_key
        BEQ read_key
.check_match
        PLA
        EOR #&ff
        INC A
        PLX
        STA key_codes,X
        DEC A
        PHX : PHA
        JSR keyname_lookup
        JSR osnewl
        PLA
        EOR #&ff
        TAX
        PHX
.next_entry
        PLX
        PHX
        LDA #&81
        LDY #&ff
        JSR osbyte
        CPX #&ff
        BEQ next_entry
        PLX : PLX
        RTS
}
\ Skip spaces and dots in the command line, leaving Y pointing at the
\ next non-whitespace character.
.parse_cmdline
{
        LDY compare_string_y
        DEY
.skip
        INY
        LDA (cmd_line_lo),Y
        CMP #' '
        BEQ skip
        CMP #'.'
        BEQ skip
        STY compare_string_y
        RTS
}
.alias_found_flag
    EQUB &ff
