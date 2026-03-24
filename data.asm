\ data.asm — ROM data: features text, opcode table, keyword table, build artifacts, padding

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
.lvar_indent
    EQUB &00                    \ LVAR indentation counter
.xi_alias_count
    EQUB &ff
\ ============================================================================
\ DIS opcode decode table — 256 entries × 4 bytes (1024 bytes)
\ Uses OP macro for valid opcodes, NOOP for undefined.
\ Mode indices: 0=???, 1=#&l, 2=&hl, 3=&l, 4=A, 5=imp,
\   6=(&l,X), 7=(&l),Y, 8=&l,X, 9=&l,Y, 10=&hl,X, 11=&hl,Y,
\   12=&b, 13=(&hl), 14=(&hl,X), 15=(&l)
\ ============================================================================
.dis_opcode_table
    \ --- &00-&0f ---
    OP "BRK", &05               \ &00: BRK imp
    OP "ORA", &06               \ &01: ORA (&l,X)
    NOOP                        \ &02
    NOOP                        \ &03
    OP "TSB", &03               \ &04: TSB &l
    OP "ORA", &03               \ &05: ORA &l
    OP "ASL", &03               \ &06: ASL &l
    NOOP                        \ &07
    OP "PHP", &05               \ &08: PHP imp
    OP "ORA", &01               \ &09: ORA #&l
    OP "ASL", &04               \ &0a: ASL A
    NOOP                        \ &0b
    OP "TSB", &02               \ &0c: TSB &hl
    OP "ORA", &02               \ &0d: ORA &hl
    OP "ASL", &02               \ &0e: ASL &hl
    NOOP                        \ &0f
    \ --- &10-&1f ---
    OP "BPL", &0c               \ &10: BPL &b
    OP "ORA", &07               \ &11: ORA (&l),Y
    OP "ORA", &0f               \ &12: ORA (&l)
    NOOP                        \ &13
    OP "TRB", &03               \ &14: TRB &l
    OP "ORA", &08               \ &15: ORA &l,X
    OP "ASL", &08               \ &16: ASL &l,X
    NOOP                        \ &17
    OP "CLC", &05               \ &18: CLC imp
    OP "ORA", &0b               \ &19: ORA &hl,Y
    OP "INC", &04               \ &1a: INC A
    NOOP                        \ &1b
    OP "TRB", &02               \ &1c: TRB &hl
    OP "ORA", &0a               \ &1d: ORA &hl,X
    OP "ASL", &0a               \ &1e: ASL &hl,X
    NOOP                        \ &1f
    \ --- &20-&2f ---
    OP "JSR", &02               \ &20: JSR &hl
    OP "AND", &06               \ &21: AND (&l,X)
    NOOP                        \ &22
    NOOP                        \ &23
    OP "BIT", &03               \ &24: BIT &l
    OP "AND", &03               \ &25: AND &l
    OP "ROL", &03               \ &26: ROL &l
    NOOP                        \ &27
    OP "PLP", &05               \ &28: PLP imp
    OP "AND", &01               \ &29: AND #&l
    OP "ROL", &04               \ &2a: ROL A
    NOOP                        \ &2b
    OP "BIT", &02               \ &2c: BIT &hl
    OP "AND", &02               \ &2d: AND &hl
    OP "ROL", &02               \ &2e: ROL &hl
    NOOP                        \ &2f
    \ --- &30-&3f ---
    OP "BMI", &0c               \ &30: BMI &b
    OP "AND", &07               \ &31: AND (&l),Y
    OP "AND", &0f               \ &32: AND (&l)
    NOOP                        \ &33
    OP "BIT", &08               \ &34: BIT &l,X
    OP "AND", &08               \ &35: AND &l,X
    OP "ROL", &08               \ &36: ROL &l,X
    NOOP                        \ &37
    OP "SEC", &05               \ &38: SEC imp
    OP "AND", &0b               \ &39: AND &hl,Y
    OP "DEC", &04               \ &3a: DEC A
    NOOP                        \ &3b
    OP "BIT", &09               \ &3c: BIT &l,Y
    OP "AND", &0a               \ &3d: AND &hl,X
    OP "ROL", &0a               \ &3e: ROL &hl,X
    NOOP                        \ &3f
    \ --- &40-&4f ---
    OP "RTI", &05               \ &40: RTI imp
    OP "EOR", &06               \ &41: EOR (&l,X)
    NOOP                        \ &42
    NOOP                        \ &43
    NOOP                        \ &44
    OP "EOR", &03               \ &45: EOR &l
    OP "LSR", &03               \ &46: LSR &l
    NOOP                        \ &47
    OP "PHA", &05               \ &48: PHA imp
    OP "EOR", &01               \ &49: EOR #&l
    OP "LSR", &04               \ &4a: LSR A
    NOOP                        \ &4b
    OP "JMP", &02               \ &4c: JMP &hl
    OP "EOR", &02               \ &4d: EOR &hl
    OP "LSR", &02               \ &4e: LSR &hl
    NOOP                        \ &4f
    \ --- &50-&5f ---
    OP "BVC", &0c               \ &50: BVC &b
    OP "EOR", &07               \ &51: EOR (&l),Y
    OP "EOR", &0f               \ &52: EOR (&l)
    NOOP                        \ &53
    NOOP                        \ &54
    OP "EOR", &08               \ &55: EOR &l,X
    OP "LSR", &08               \ &56: LSR &l,X
    NOOP                        \ &57
    OP "CLI", &05               \ &58: CLI imp
    OP "EOR", &0b               \ &59: EOR &hl,Y
    OP "PHY", &05               \ &5a: PHY imp
    NOOP                        \ &5b
    NOOP                        \ &5c
    OP "EOR", &0a               \ &5d: EOR &hl,X
    OP "LSR", &0a               \ &5e: LSR &hl,X
    NOOP                        \ &5f
    \ --- &60-&6f ---
    OP "RTS", &05               \ &60: RTS imp
    OP "ADC", &06               \ &61: ADC (&l,X)
    NOOP                        \ &62
    NOOP                        \ &63
    OP "STZ", &03               \ &64: STZ &l
    OP "ADC", &03               \ &65: ADC &l
    OP "ROR", &03               \ &66: ROR &l
    NOOP                        \ &67
    OP "PLA", &05               \ &68: PLA imp
    OP "ADC", &01               \ &69: ADC #&l
    OP "ROR", &04               \ &6a: ROR A
    NOOP                        \ &6b
    OP "JMP", &0d               \ &6c: JMP (&hl)
    OP "ADC", &02               \ &6d: ADC &hl
    OP "ROR", &02               \ &6e: ROR &hl
    NOOP                        \ &6f
    \ --- &70-&7f ---
    OP "BVS", &0c               \ &70: BVS &b
    OP "ADC", &07               \ &71: ADC (&l),Y
    OP "ADC", &0f               \ &72: ADC (&l)
    NOOP                        \ &73
    OP "STZ", &08               \ &74: STZ &l,X
    OP "ADC", &08               \ &75: ADC &l,X
    OP "ROR", &08               \ &76: ROR &l,X
    NOOP                        \ &77
    OP "SEI", &05               \ &78: SEI imp
    OP "ADC", &0b               \ &79: ADC &hl,Y
    OP "PLY", &05               \ &7a: PLY imp
    NOOP                        \ &7b
    OP "JMP", &0e               \ &7c: JMP (&hl,X)
    OP "ADC", &0a               \ &7d: ADC &hl,X
    OP "ROR", &0a               \ &7e: ROR &hl,X
    NOOP                        \ &7f
    \ --- &80-&8f ---
    OP "BRA", &0c               \ &80: BRA &b
    OP "STA", &06               \ &81: STA (&l,X)
    NOOP                        \ &82
    NOOP                        \ &83
    OP "STY", &03               \ &84: STY &l
    OP "STA", &03               \ &85: STA &l
    OP "STX", &03               \ &86: STX &l
    NOOP                        \ &87
    OP "DEY", &05               \ &88: DEY imp
    OP "BIT", &01               \ &89: BIT #&l
    OP "TXA", &05               \ &8a: TXA imp
    NOOP                        \ &8b
    OP "STY", &02               \ &8c: STY &hl
    OP "STA", &02               \ &8d: STA &hl
    OP "STX", &02               \ &8e: STX &hl
    NOOP                        \ &8f
    \ --- &90-&9f ---
    OP "BCC", &0c               \ &90: BCC &b
    OP "STA", &07               \ &91: STA (&l),Y
    OP "STA", &0f               \ &92: STA (&l)
    NOOP                        \ &93
    OP "STY", &08               \ &94: STY &l,X
    OP "STA", &08               \ &95: STA &l,X
    OP "STX", &09               \ &96: STX &l,Y
    NOOP                        \ &97
    OP "TYA", &05               \ &98: TYA imp
    OP "STA", &0b               \ &99: STA &hl,Y
    OP "TXS", &05               \ &9a: TXS imp
    NOOP                        \ &9b
    OP "STZ", &02               \ &9c: STZ &hl
    OP "STA", &0a               \ &9d: STA &hl,X
    OP "STZ", &0a               \ &9e: STZ &hl,X
    NOOP                        \ &9f
    \ --- &a0-&af ---
    OP "LDY", &01               \ &a0: LDY #&l
    OP "LDA", &06               \ &a1: LDA (&l,X)
    OP "LDX", &01               \ &a2: LDX #&l
    NOOP                        \ &a3
    OP "LDY", &03               \ &a4: LDY &l
    OP "LDA", &03               \ &a5: LDA &l
    OP "LDX", &03               \ &a6: LDX &l
    NOOP                        \ &a7
    OP "TAY", &05               \ &a8: TAY imp
    OP "LDA", &01               \ &a9: LDA #&l
    OP "TAX", &05               \ &aa: TAX imp
    NOOP                        \ &ab
    OP "LDY", &02               \ &ac: LDY &hl
    OP "LDA", &02               \ &ad: LDA &hl
    OP "LDX", &02               \ &ae: LDX &hl
    NOOP                        \ &af
    \ --- &b0-&bf ---
    OP "BCS", &0c               \ &b0: BCS &b
    OP "LDA", &07               \ &b1: LDA (&l),Y
    OP "LDA", &0f               \ &b2: LDA (&l)
    NOOP                        \ &b3
    OP "LDY", &08               \ &b4: LDY &l,X
    OP "LDA", &08               \ &b5: LDA &l,X
    OP "LDX", &09               \ &b6: LDX &l,Y
    NOOP                        \ &b7
    OP "CLV", &05               \ &b8: CLV imp
    OP "LDA", &0b               \ &b9: LDA &hl,Y
    OP "TSX", &05               \ &ba: TSX imp
    NOOP                        \ &bb
    OP "LDY", &0a               \ &bc: LDY &hl,X
    OP "LDA", &0a               \ &bd: LDA &hl,X
    OP "LDX", &0b               \ &be: LDX &hl,Y
    NOOP                        \ &bf
    \ --- &c0-&cf ---
    OP "CPY", &01               \ &c0: CPY #&l
    OP "CMP", &06               \ &c1: CMP (&l,X)
    NOOP                        \ &c2
    NOOP                        \ &c3
    OP "CPY", &03               \ &c4: CPY &l
    OP "CMP", &03               \ &c5: CMP &l
    OP "DEC", &03               \ &c6: DEC &l
    NOOP                        \ &c7
    OP "INY", &05               \ &c8: INY imp
    OP "CMP", &01               \ &c9: CMP #&l
    OP "DEX", &05               \ &ca: DEX imp
    NOOP                        \ &cb
    OP "CPY", &02               \ &cc: CPY &hl
    OP "CMP", &02               \ &cd: CMP &hl
    OP "DEC", &02               \ &ce: DEC &hl
    NOOP                        \ &cf
    \ --- &d0-&df ---
    OP "BNE", &0c               \ &d0: BNE &b
    OP "CMP", &07               \ &d1: CMP (&l),Y
    OP "CMP", &0f               \ &d2: CMP (&l)
    NOOP                        \ &d3
    NOOP                        \ &d4
    OP "CMP", &08               \ &d5: CMP &l,X
    OP "DEC", &08               \ &d6: DEC &l,X
    NOOP                        \ &d7
    OP "CLD", &05               \ &d8: CLD imp
    OP "CMP", &0b               \ &d9: CMP &hl,Y
    OP "PHX", &05               \ &da: PHX imp
    NOOP                        \ &db
    NOOP                        \ &dc
    OP "CMP", &0a               \ &dd: CMP &hl,X
    OP "DEC", &0a               \ &de: DEC &hl,X
    NOOP                        \ &df
    \ --- &e0-&ef ---
    OP "CPX", &01               \ &e0: CPX #&l
    OP "SBC", &06               \ &e1: SBC (&l,X)
    NOOP                        \ &e2
    NOOP                        \ &e3
    OP "CPX", &03               \ &e4: CPX &l
    OP "SBC", &03               \ &e5: SBC &l
    OP "INC", &03               \ &e6: INC &l
    NOOP                        \ &e7
    OP "INX", &05               \ &e8: INX imp
    OP "SBC", &01               \ &e9: SBC #&l
    OP "NOP", &05               \ &ea: NOP imp
    NOOP                        \ &eb
    OP "CPX", &02               \ &ec: CPX &hl
    OP "SBC", &02               \ &ed: SBC &hl
    OP "INC", &02               \ &ee: INC &hl
    NOOP                        \ &ef
    \ --- &f0-&ff ---
    OP "BEQ", &0c               \ &f0: BEQ &b
    OP "SBC", &07               \ &f1: SBC (&l),Y
    OP "SBC", &0f               \ &f2: SBC (&l)
    NOOP                        \ &f3
    NOOP                        \ &f4
    OP "SBC", &08               \ &f5: SBC &l,X
    OP "INC", &08               \ &f6: INC &l,X
    NOOP                        \ &f7
    OP "SED", &05               \ &f8: SED imp
    OP "SBC", &0b               \ &f9: SBC &hl,Y
    OP "PLX", &05               \ &fa: PLX imp
    NOOP                        \ &fb
    NOOP                        \ &fc
    OP "SBC", &0a               \ &fd: SBC &hl,X
    OP "INC", &0a               \ &fe: INC &hl,X
    NOOP                        \ &ff
\ Runtime workspace — everything from here to alias_clear_flag is
\ overwritten at runtime. Initial values are development artifacts.
\ See the workspace overlay after SAVE in xmos.asm for the layout.
.workspace_start
    EQUS "KEY9 *SRSAVE XMos 8000+4000 7Q|M", 13, "M", 13

\ Overwritten workspace
    FOR n, 1, 220 : EQUB '*' : NEXT
    FOR n, 1, 17 : EQUB '"' : NEXT
    FOR n, 1, 17 : EQUB &80 : NEXT

\ BASIC build scripts and fragments from the development environment
    EQUS "i", &8a, &90, "~z", &a9, &19, "it", '"', 13, "&", &8a, &90, "~z", &a9, &19, "oader", '"', 13, "CH.", '"', "Medit", '"', 13, "&", &8a, &90, "~z", &a9, &19, "ader", '"', 13, "CH.", '"', "Medit", '"', 13
    EQUS "&", &8a, &90, "~z", &a9, &19, "PAGE=&2800", 13, "LO.", '"', "SrcCode", '"', 13, "CH.", '"', "MakeMap", '"', 13, "CH.", '"', "Loader", '"', 13, "CH.", '"'
    EQUS "Medit", '"', 13, "&", &8a, &90, "~z", &a9, &19, "akeMap", '"', 13, "CH.", '"', "Loader", '"', 13, "CH.", '"', "Medit", '"', 13, "&", &a9, &82, &85, &a9, &a0, 0, &b2, &a8, &c9, &ff, &f0, "C", &a9, " "
    EQUS " ", &e3, &ff, " ", &e3, &ff, &b1, &a8, &f0, &06, " ", &e3, &ff, &c8, &d0, &f6, &98, "8", &e9, &09, "I", &ff, &1a, &aa, &a9, "  ", &e3, &ff, &ca, &d0, &f8, &c8, &c8, &c8, &88, &c8, &b1, &a8, &f0, &05, " ", 0, 0, 0, 0, 0, 0, 0, &c8, &18, &98, "e", &a8, &85, &a8, &a5, &a9, "i", 0
    EQUS &85, &a9, "L", &cc, &80, "z", &fa, "h`", &a9, &86, &85, &a8, &a9, &80, &85, &a9

\ Ghost code — old help/command handler from a previous build (not executed)
    EQUB &7a, &5a, &20, &26, &8a, &90, &20, &7a, &a9, &f0, &85, &a8, &a9, &9e, &85, &a9
    EQUB &a0, &00, &b1, &a8, &f0, &0a, &20, &e3, &ff, &c8, &d0, &f6, &e6, &a9, &80, &f2
    EQUB &20, &e7, &ff, &7a, &fa, &68, &60, &7a, &a9, &19, &85, &a8, &a9, &82, &85, &a9
    EQUB &5a, &20, &26, &8a, &b0, &2c, &a0, &00, &c8, &b1, &a8, &d0, &fb, &c8, &c8, &c8
    EQUB &c8, &b1, &a8, &d0, &fb, &c8, &18, &98, &65, &a8, &85, &a8, &a5, &a9, &69, &00
    EQUB &85, &a9, &7a, &b2, &a8, &c9, &ff, &d0, &d7, &a9, &0f, &20, &e3, &ff, &7a, &fa
    EQUB &68, &60, &7a, &a9, &20, &20, &e3, &ff, &20, &e3, &ff, &a0, &ff, &c8, &b1, &a8
    EQUB &20, &e3, &ff, &c9, &00, &d0, &f6, &98, &38, &e9, &09, &49, &ff, &1a, &aa, &a9
    EQUB &20, &20, &e3, &ff, &ca, &d0, &f8, &c8, &c8, &c8, &b1, &a8, &f0, &06, &20, &e3
    EQUB &ff, &c8, &d0, &f6, &20, &e7, &ff, &7a, &fa, &68, &60, &48, &da, &5a, &a9, &19
    EQUB &85, &a8, &a9, &82, &85, &a9, &5a, &b2, &a8, &c9, &ff, &f0, &25, &20, &26, &8a
    EQUB &b0, &24, &a0, &00, &c8, &b1, &a8, &d0, &fb, &c8, &c8, &c8, &c8, &b1, &a8, &d0
    EQUB &fb, &c8, &98, &18, &65, &a8, &85, &a8, &a5, &a9, &69, &00, &85, &a9, &7a, &4c
    EQUB &c9, &81, &7a, &4c, &b8, &91, &7a, &a0, &00, &c8, &b1, &a8, &d0, &00, &00, &00
    EQUB &00, &00, &00, &82, &c8, &b1, &a8, &8d, &18, &82, &20, &16, &82, &7a, &fa, &68

\ Ghost command table — previous version of command_table left in RAM
    EQUS &a9, 0, "`LF", &93, "ALIAS", 0, "3", &90, "<alias name> <alias>", 0, "ALIASES", 0, "A", &91, "Shows active al"
    EQUS "iases", 0, "ALICLR", 0, "@", &93, "Clears all aliases", 0, "ALILD", 0, &85, &92, "Loads alias file", 0, "A"
    EQUS "LISV", 0, &e1, &92, "Saves alias file", 0, "BAU", 0, &c1, &98, "Splits to single commands", 0, "DEFK"
    EQUS "EYS", 0, "x", &8f, "Defines new keys", 0, "DIS", 0, &05, &97, "<addr> - disassemble memory", 0, 0, 0, 0
    FOR n, 1, 180 : EQUB 0 : NEXT
    EQUS 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "core name", 0, "SPACE", 0, "/", &9a, "Inserts spaces into progr"
    EQUS "ams", 0, "STORE", 0, "F", &93, "K"

\ Key/alias buffer workspace
.alias_buffer
    EQUS "*SRSAVE XMOS 8000+4000 7 Q", 13
    FOR n, 1, 685 : EQUB &0d : NEXT

\ Stored function key definitions
    EQUS "*KEYOFF", 13, "*KEYOF", 13, "*STORE", 13, "*H.XMOS", 13, 13, "*KEY 15", 13, "*KEY 1", 13, "*KEY 16", 13, "*KEY 1"
    EQUS "4", 13, "*KEY 13", 13, "*KEY 12", 13, "*KEY 11", 13, "*KEY 10", 13, "*KEY 9", 13, "*KEY 8", 13, "*KEY 7", 13, "*KEY "
    EQUS "6", 13, "*KEY 5", 13, "*KEY 4", 13, "*KEY 3", 13, "*KEY 2", 13, "*KEY 1", 13, "*KEY 0", 13, "OSCLI", '"', "Save Game "
    EQUS "1100 ", '"', "+STR$~P%+", '"', " ", '"', "+STR$~start", 13, "*SHOW 10", 13, "*SHOW", 13, "*H.MOS", 13, "*KEYS", 13, "*K"
    EQUS "EY"
    FOR n, 1, 70 : EQUB &0d : NEXT

.basic_keyword_table
    KW "AND", &80, &00
    KW "ABS", &94, &00
    KW "ACS", &95, &00
    KW "ADVAL", &96, &00
    KW "ASC", &97, &00
    KW "ASN", &98, &00
    KW "ATN", &99, &00
    KW "AUTO", &c6, &10
    KW "BGET", &9a, &01
    KW "BPUT", &d5, &03
    KW "COLOUR", &fb, &02
    KW "CALL", &d6, &02
    KW "CHAIN", &d7, &02
    KW "CHR$", &bd, &00
    KW "CLEAR", &d8, &01
    KW "CLOSE", &d9, &03
    KW "CLG", &da, &01
    KW "CLS", &db, &01
    KW "COS", &9b, &00
    KW "COUNT", &9c, &01
    KW "COLOR", &fb, &02
    KW "DATA", &dc, &20
    KW "DEG", &9d, &00
    KW "DEF", &dd, &00
    KW "DELETE", &c7, &10
    KW "DIV", &81, &00
    KW "DIM", &de, &02
    KW "DRAW", &df, &02
    KW "ENDPROC", &e1, &01
    KW "END", &e0, &01
    KW "ENVELOPE", &e2, &02
    KW "ELSE", &8b, &14
    KW "EVAL", &a0, &00
    KW "ERL", &9e, &01
    KW "ERROR", &85, &04
    KW "EOF", &c5, &01
    KW "EOR", &82, &00
    KW "ERR", &9f, &01
    KW "EXP", &a1, &00
    KW "EXT", &a2, &01
    KW "EDIT", &ce, &10
    KW "FOR", &e3, &02
    KW "FALSE", &a3, &01
    KW "FN", &a4, &08
    KW "GOTO", &e5, &12
    KW "GET$", &be, &00
    KW "GET", &a5, &00
    KW "GOSUB", &e4, &12
    KW "GCOL", &e6, &02
    KW "HIMEM", &93, &43
    KW "INPUT", &e8, &02
    KW "IF", &e7, &02
    KW "INKEY$", &bf, &00
    KW "INKEY", &a6, &00
    KW "INT", &a8, &00
    KW "INSTR(", &a7, &00
    KW "LIST", &c9, &10
    KW "LINE", &86, &00
    KW "LOAD", &c8, &02
    KW "LOMEM", &92, &43
    KW "LOCAL", &ea, &02
    KW "LEFT$(", &c0, &00
    KW "LEN", &a9, &00
    KW "LET", &e9, &04
    KW "LOG", &ab, &00
    KW "LN", &aa, &00
    KW "MID$(", &c1, &00
    KW "MODE", &eb, &02
    KW "MOD", &83, &00
    KW "MOVE", &ec, &02
    KW "NEXT", &ed, &02
    KW "NEW", &ca, &01
    KW "NOT", &ac, &00
    KW "OLD", &cb, &01
    KW "ON", &ee, &02
    KW "OFF", &87, &00
    KW "OR", &84, &00
    KW "OPENIN", &8e, &00
    KW "OPENOUT", &ae, &00
    KW "OPENUP", &ad, &00
    KW "OSCLI", &ff, &02
    KW "PRINT", &f1, &02
    KW "PAGE", &90, &43
    KW "PTR", &8f, &43
    KW "PI", &af, &01
    KW "PLOT", &f0, &02
    KW "POINT(", &b0, &00
    KW "PROC", &f2, &0a
    KW "POS", &b1, &01
    KW "RETURN", &f8, &01
    KW "REPEAT", &f5, &00
    KW "REPORT", &f6, &01
    KW "READ", &f3, &02
    KW "REM", &f4, &20
    KW "RUN", &f9, &01
    KW "RAD", &b2, &00
    KW "RESTORE", &f7, &12
    KW "RIGHT$(", &c2, &00
    KW "RND", &b3, &01
    KW "RENUMBER", &cc, &10
    KW "STEP", &88, &00
    KW "SAVE", &cd, &02
    KW "SGN", &b4, &00
    KW "SIN", &b5, &00
    KW "SQR", &b6, &00
    KW "SPC", &89, &00
    KW "STR$", &c3, &00
    KW "STRING$(", &c4, &00
    KW "SOUND", &d4, &02
    KW "STOP", &fa, &01
    KW "TAN", &b7, &00
    KW "THEN", &8c, &14
    KW "TO", &b8, &00
    KW "TAB(", &8a, &00
    KW "TRACE", &fc, &12
    KW "TIME", &91, &43
    KW "TRUE", &b9, &01
    KW "UNTIL", &fd, &02
    KW "USR", &ba, &00
    KW "VDU", &ef, &02
    KW "VAL", &bb, &00
    KW "VPOS", &bc, &01
    KW "WIDTH", &fe, &02
    KW "PAGE", &d0, &00
    KW "PTR", &cf, &00
    KW "TIME", &d1, &00
    KW "LOMEM", &d2, &00
    KW "HIMEM", &d3, &00
    KW "Missing", &ff, &4f

\ Build-time *KEY definitions stored after the keyword table
    EQUS 0, &16, "SAVE|MCH.", '"', "Core", '"', "|M", 13
    EQUS "BREAK", 0, &1e, "*KEY10 %0||M|M*STORE|M", 13
    EQUS "MAKE", 0, &1f, "*SSAVE %0|MCH.", '"', "CREATE", '"', "|M", 13
    EQUS "SPR", 0, &34, "MODE1:VDU19,1,1;0;19,2,2;0;19,3,3;0;:*SED.%0|M", 13
    EQUS "UPDATE", 0, &24, "*SRSAVE XMos 8000+4000 7Q|M", 13
    EQUS &ff, "ETUPTE", 0, &24, "*SRSAVE XMos 8000+4000 7Q|M"
\ ============================================================================
\ Uninitialised sideways RAM — alternating &ff/&00 blocks
\ This is the unused portion of the 16KB ROM slot. The alternating
\ pattern is characteristic of uninitialised BBC Master sideways RAM.
\ ============================================================================
.uninitialised_ram
    EQUB &0d
    FOR n, 1, 27 : EQUB &ff : NEXT
FOR n, 1, 54
        FOR m, 1, 32 : EQUB &00 : NEXT
        FOR m, 1, 32 : EQUB &ff : NEXT
NEXT
    FOR n, 1, 32 : EQUB &00 : NEXT
    FOR n, 1, 16 : EQUB &ff : NEXT

