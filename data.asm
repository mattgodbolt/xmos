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
    EQUB &00                   \ LVAR indentation counter
.xi_alias_count
    EQUB &FF
\ ============================================================================
\ DIS opcode decode table — 256 entries × 4 bytes (1024 bytes)
\ Uses OP macro for valid opcodes, NOOP for undefined.
\ Mode indices: 0=???, 1=#&l, 2=&hl, 3=&l, 4=A, 5=imp,
\   6=(&l,X), 7=(&l),Y, 8=&l,X, 9=&l,Y, 10=&hl,X, 11=&hl,Y,
\   12=&b, 13=(&hl), 14=(&hl,X), 15=(&l)
\ ============================================================================
.dis_opcode_table
    \ --- &00-&0F ---
    OP "BRK", &05                       \ &00: BRK imp
    OP "ORA", &06                       \ &01: ORA (&l,X)
    NOOP                                \ &02
    NOOP                                \ &03
    OP "TSB", &03                       \ &04: TSB &l
    OP "ORA", &03                       \ &05: ORA &l
    OP "ASL", &03                       \ &06: ASL &l
    NOOP                                \ &07
    OP "PHP", &05                       \ &08: PHP imp
    OP "ORA", &01                       \ &09: ORA #&l
    OP "ASL", &04                       \ &0A: ASL A
    NOOP                                \ &0B
    OP "TSB", &02                       \ &0C: TSB &hl
    OP "ORA", &02                       \ &0D: ORA &hl
    OP "ASL", &02                       \ &0E: ASL &hl
    NOOP                                \ &0F
    \ --- &10-&1F ---
    OP "BPL", &0C                       \ &10: BPL &b
    OP "ORA", &07                       \ &11: ORA (&l),Y
    OP "ORA", &0F                       \ &12: ORA (&l)
    NOOP                                \ &13
    OP "TRB", &03                       \ &14: TRB &l
    OP "ORA", &08                       \ &15: ORA &l,X
    OP "ASL", &08                       \ &16: ASL &l,X
    NOOP                                \ &17
    OP "CLC", &05                       \ &18: CLC imp
    OP "ORA", &0B                       \ &19: ORA &hl,Y
    OP "INC", &04                       \ &1A: INC A
    NOOP                                \ &1B
    OP "TRB", &02                       \ &1C: TRB &hl
    OP "ORA", &0A                       \ &1D: ORA &hl,X
    OP "ASL", &0A                       \ &1E: ASL &hl,X
    NOOP                                \ &1F
    \ --- &20-&2F ---
    OP "JSR", &02                       \ &20: JSR &hl
    OP "AND", &06                       \ &21: AND (&l,X)
    NOOP                                \ &22
    NOOP                                \ &23
    OP "BIT", &03                       \ &24: BIT &l
    OP "AND", &03                       \ &25: AND &l
    OP "ROL", &03                       \ &26: ROL &l
    NOOP                                \ &27
    OP "PLP", &05                       \ &28: PLP imp
    OP "AND", &01                       \ &29: AND #&l
    OP "ROL", &04                       \ &2A: ROL A
    NOOP                                \ &2B
    OP "BIT", &02                       \ &2C: BIT &hl
    OP "AND", &02                       \ &2D: AND &hl
    OP "ROL", &02                       \ &2E: ROL &hl
    NOOP                                \ &2F
    \ --- &30-&3F ---
    OP "BMI", &0C                       \ &30: BMI &b
    OP "AND", &07                       \ &31: AND (&l),Y
    OP "AND", &0F                       \ &32: AND (&l)
    NOOP                                \ &33
    OP "BIT", &08                       \ &34: BIT &l,X
    OP "AND", &08                       \ &35: AND &l,X
    OP "ROL", &08                       \ &36: ROL &l,X
    NOOP                                \ &37
    OP "SEC", &05                       \ &38: SEC imp
    OP "AND", &0B                       \ &39: AND &hl,Y
    OP "DEC", &04                       \ &3A: DEC A
    NOOP                                \ &3B
    OP "BIT", &09                       \ &3C: BIT &l,Y
    OP "AND", &0A                       \ &3D: AND &hl,X
    OP "ROL", &0A                       \ &3E: ROL &hl,X
    NOOP                                \ &3F
    \ --- &40-&4F ---
    OP "RTI", &05                       \ &40: RTI imp
    OP "EOR", &06                       \ &41: EOR (&l,X)
    NOOP                                \ &42
    NOOP                                \ &43
    NOOP                                \ &44
    OP "EOR", &03                       \ &45: EOR &l
    OP "LSR", &03                       \ &46: LSR &l
    NOOP                                \ &47
    OP "PHA", &05                       \ &48: PHA imp
    OP "EOR", &01                       \ &49: EOR #&l
    OP "LSR", &04                       \ &4A: LSR A
    NOOP                                \ &4B
    OP "JMP", &02                       \ &4C: JMP &hl
    OP "EOR", &02                       \ &4D: EOR &hl
    OP "LSR", &02                       \ &4E: LSR &hl
    NOOP                                \ &4F
    \ --- &50-&5F ---
    OP "BVC", &0C                       \ &50: BVC &b
    OP "EOR", &07                       \ &51: EOR (&l),Y
    OP "EOR", &0F                       \ &52: EOR (&l)
    NOOP                                \ &53
    NOOP                                \ &54
    OP "EOR", &08                       \ &55: EOR &l,X
    OP "LSR", &08                       \ &56: LSR &l,X
    NOOP                                \ &57
    OP "CLI", &05                       \ &58: CLI imp
    OP "EOR", &0B                       \ &59: EOR &hl,Y
    OP "PHY", &05                       \ &5A: PHY imp
    NOOP                                \ &5B
    NOOP                                \ &5C
    OP "EOR", &0A                       \ &5D: EOR &hl,X
    OP "LSR", &0A                       \ &5E: LSR &hl,X
    NOOP                                \ &5F
    \ --- &60-&6F ---
    OP "RTS", &05                       \ &60: RTS imp
    OP "ADC", &06                       \ &61: ADC (&l,X)
    NOOP                                \ &62
    NOOP                                \ &63
    OP "STZ", &03                       \ &64: STZ &l
    OP "ADC", &03                       \ &65: ADC &l
    OP "ROR", &03                       \ &66: ROR &l
    NOOP                                \ &67
    OP "PLA", &05                       \ &68: PLA imp
    OP "ADC", &01                       \ &69: ADC #&l
    OP "ROR", &04                       \ &6A: ROR A
    NOOP                                \ &6B
    OP "JMP", &0D                       \ &6C: JMP (&hl)
    OP "ADC", &02                       \ &6D: ADC &hl
    OP "ROR", &02                       \ &6E: ROR &hl
    NOOP                                \ &6F
    \ --- &70-&7F ---
    OP "BVS", &0C                       \ &70: BVS &b
    OP "ADC", &07                       \ &71: ADC (&l),Y
    OP "ADC", &0F                       \ &72: ADC (&l)
    NOOP                                \ &73
    OP "STZ", &08                       \ &74: STZ &l,X
    OP "ADC", &08                       \ &75: ADC &l,X
    OP "ROR", &08                       \ &76: ROR &l,X
    NOOP                                \ &77
    OP "SEI", &05                       \ &78: SEI imp
    OP "ADC", &0B                       \ &79: ADC &hl,Y
    OP "PLY", &05                       \ &7A: PLY imp
    NOOP                                \ &7B
    OP "JMP", &0E                       \ &7C: JMP (&hl,X)
    OP "ADC", &0A                       \ &7D: ADC &hl,X
    OP "ROR", &0A                       \ &7E: ROR &hl,X
    NOOP                                \ &7F
    \ --- &80-&8F ---
    OP "BRA", &0C                       \ &80: BRA &b
    OP "STA", &06                       \ &81: STA (&l,X)
    NOOP                                \ &82
    NOOP                                \ &83
    OP "STY", &03                       \ &84: STY &l
    OP "STA", &03                       \ &85: STA &l
    OP "STX", &03                       \ &86: STX &l
    NOOP                                \ &87
    OP "DEY", &05                       \ &88: DEY imp
    OP "BIT", &01                       \ &89: BIT #&l
    OP "TXA", &05                       \ &8A: TXA imp
    NOOP                                \ &8B
    OP "STY", &02                       \ &8C: STY &hl
    OP "STA", &02                       \ &8D: STA &hl
    OP "STX", &02                       \ &8E: STX &hl
    NOOP                                \ &8F
    \ --- &90-&9F ---
    OP "BCC", &0C                       \ &90: BCC &b
    OP "STA", &07                       \ &91: STA (&l),Y
    OP "STA", &0F                       \ &92: STA (&l)
    NOOP                                \ &93
    OP "STY", &08                       \ &94: STY &l,X
    OP "STA", &08                       \ &95: STA &l,X
    OP "STX", &09                       \ &96: STX &l,Y
    NOOP                                \ &97
    OP "TYA", &05                       \ &98: TYA imp
    OP "STA", &0B                       \ &99: STA &hl,Y
    OP "TXS", &05                       \ &9A: TXS imp
    NOOP                                \ &9B
    OP "STZ", &02                       \ &9C: STZ &hl
    OP "STA", &0A                       \ &9D: STA &hl,X
    OP "STZ", &0A                       \ &9E: STZ &hl,X
    NOOP                                \ &9F
    \ --- &A0-&AF ---
    OP "LDY", &01                       \ &A0: LDY #&l
    OP "LDA", &06                       \ &A1: LDA (&l,X)
    OP "LDX", &01                       \ &A2: LDX #&l
    NOOP                                \ &A3
    OP "LDY", &03                       \ &A4: LDY &l
    OP "LDA", &03                       \ &A5: LDA &l
    OP "LDX", &03                       \ &A6: LDX &l
    NOOP                                \ &A7
    OP "TAY", &05                       \ &A8: TAY imp
    OP "LDA", &01                       \ &A9: LDA #&l
    OP "TAX", &05                       \ &AA: TAX imp
    NOOP                                \ &AB
    OP "LDY", &02                       \ &AC: LDY &hl
    OP "LDA", &02                       \ &AD: LDA &hl
    OP "LDX", &02                       \ &AE: LDX &hl
    NOOP                                \ &AF
    \ --- &B0-&BF ---
    OP "BCS", &0C                       \ &B0: BCS &b
    OP "LDA", &07                       \ &B1: LDA (&l),Y
    OP "LDA", &0F                       \ &B2: LDA (&l)
    NOOP                                \ &B3
    OP "LDY", &08                       \ &B4: LDY &l,X
    OP "LDA", &08                       \ &B5: LDA &l,X
    OP "LDX", &09                       \ &B6: LDX &l,Y
    NOOP                                \ &B7
    OP "CLV", &05                       \ &B8: CLV imp
    OP "LDA", &0B                       \ &B9: LDA &hl,Y
    OP "TSX", &05                       \ &BA: TSX imp
    NOOP                                \ &BB
    OP "LDY", &0A                       \ &BC: LDY &hl,X
    OP "LDA", &0A                       \ &BD: LDA &hl,X
    OP "LDX", &0B                       \ &BE: LDX &hl,Y
    NOOP                                \ &BF
    \ --- &C0-&CF ---
    OP "CPY", &01                       \ &C0: CPY #&l
    OP "CMP", &06                       \ &C1: CMP (&l,X)
    NOOP                                \ &C2
    NOOP                                \ &C3
    OP "CPY", &03                       \ &C4: CPY &l
    OP "CMP", &03                       \ &C5: CMP &l
    OP "DEC", &03                       \ &C6: DEC &l
    NOOP                                \ &C7
    OP "INY", &05                       \ &C8: INY imp
    OP "CMP", &01                       \ &C9: CMP #&l
    OP "DEX", &05                       \ &CA: DEX imp
    NOOP                                \ &CB
    OP "CPY", &02                       \ &CC: CPY &hl
    OP "CMP", &02                       \ &CD: CMP &hl
    OP "DEC", &02                       \ &CE: DEC &hl
    NOOP                                \ &CF
    \ --- &D0-&DF ---
    OP "BNE", &0C                       \ &D0: BNE &b
    OP "CMP", &07                       \ &D1: CMP (&l),Y
    OP "CMP", &0F                       \ &D2: CMP (&l)
    NOOP                                \ &D3
    NOOP                                \ &D4
    OP "CMP", &08                       \ &D5: CMP &l,X
    OP "DEC", &08                       \ &D6: DEC &l,X
    NOOP                                \ &D7
    OP "CLD", &05                       \ &D8: CLD imp
    OP "CMP", &0B                       \ &D9: CMP &hl,Y
    OP "PHX", &05                       \ &DA: PHX imp
    NOOP                                \ &DB
    NOOP                                \ &DC
    OP "CMP", &0A                       \ &DD: CMP &hl,X
    OP "DEC", &0A                       \ &DE: DEC &hl,X
    NOOP                                \ &DF
    \ --- &E0-&EF ---
    OP "CPX", &01                       \ &E0: CPX #&l
    OP "SBC", &06                       \ &E1: SBC (&l,X)
    NOOP                                \ &E2
    NOOP                                \ &E3
    OP "CPX", &03                       \ &E4: CPX &l
    OP "SBC", &03                       \ &E5: SBC &l
    OP "INC", &03                       \ &E6: INC &l
    NOOP                                \ &E7
    OP "INX", &05                       \ &E8: INX imp
    OP "SBC", &01                       \ &E9: SBC #&l
    OP "NOP", &05                       \ &EA: NOP imp
    NOOP                                \ &EB
    OP "CPX", &02                       \ &EC: CPX &hl
    OP "SBC", &02                       \ &ED: SBC &hl
    OP "INC", &02                       \ &EE: INC &hl
    NOOP                                \ &EF
    \ --- &F0-&FF ---
    OP "BEQ", &0C                       \ &F0: BEQ &b
    OP "SBC", &07                       \ &F1: SBC (&l),Y
    OP "SBC", &0F                       \ &F2: SBC (&l)
    NOOP                                \ &F3
    NOOP                                \ &F4
    OP "SBC", &08                       \ &F5: SBC &l,X
    OP "INC", &08                       \ &F6: INC &l,X
    NOOP                                \ &F7
    OP "SED", &05                       \ &F8: SED imp
    OP "SBC", &0B                       \ &F9: SBC &hl,Y
    OP "PLX", &05                       \ &FA: PLX imp
    NOOP                                \ &FB
    NOOP                                \ &FC
    OP "SBC", &0A                       \ &FD: SBC &hl,X
    OP "INC", &0A                       \ &FE: INC &hl,X
    NOOP                                \ &FF
    EQUB &4B, &45, &59, &39
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
    EQUB &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D, &0D
\ ============================================================================
\ BASIC keyword table for *LVAR
\ Format: KW "keyword", token, flags
\ Tokens &80-&FF are standard BASIC tokens
\ ============================================================================
.basic_keyword_table
    KW "AND", &80, &00
    KW "ABS", &94, &00
    KW "ACS", &95, &00
    KW "ADVAL", &96, &00
    KW "ASC", &97, &00
    KW "ASN", &98, &00
    KW "ATN", &99, &00
    KW "AUTO", &C6, &10
    KW "BGET", &9A, &01
    KW "BPUT", &D5, &03
    KW "COLOUR", &FB, &02
    KW "CALL", &D6, &02
    KW "CHAIN", &D7, &02
    KW "CHR$", &BD, &00
    KW "CLEAR", &D8, &01
    KW "CLOSE", &D9, &03
    KW "CLG", &DA, &01
    KW "CLS", &DB, &01
    KW "COS", &9B, &00
    KW "COUNT", &9C, &01
    KW "COLOR", &FB, &02
    KW "DATA", &DC, &20
    KW "DEG", &9D, &00
    KW "DEF", &DD, &00
    KW "DELETE", &C7, &10
    KW "DIV", &81, &00
    KW "DIM", &DE, &02
    KW "DRAW", &DF, &02
    KW "ENDPROC", &E1, &01
    KW "END", &E0, &01
    KW "ENVELOPE", &E2, &02
    KW "ELSE", &8B, &14
    KW "EVAL", &A0, &00
    KW "ERL", &9E, &01
    KW "ERROR", &85, &04
    KW "EOF", &C5, &01
    KW "EOR", &82, &00
    KW "ERR", &9F, &01
    KW "EXP", &A1, &00
    KW "EXT", &A2, &01
    KW "EDIT", &CE, &10
    KW "FOR", &E3, &02
    KW "FALSE", &A3, &01
    KW "FN", &A4, &08
    KW "GOTO", &E5, &12
    KW "GET$", &BE, &00
    KW "GET", &A5, &00
    KW "GOSUB", &E4, &12
    KW "GCOL", &E6, &02
    KW "HIMEM", &93, &43
    KW "INPUT", &E8, &02
    KW "IF", &E7, &02
    KW "INKEY$", &BF, &00
    KW "INKEY", &A6, &00
    KW "INT", &A8, &00
    KW "INSTR(", &A7, &00
    KW "LIST", &C9, &10
    KW "LINE", &86, &00
    KW "LOAD", &C8, &02
    KW "LOMEM", &92, &43
    KW "LOCAL", &EA, &02
    KW "LEFT$(", &C0, &00
    KW "LEN", &A9, &00
    KW "LET", &E9, &04
    KW "LOG", &AB, &00
    KW "LN", &AA, &00
    KW "MID$(", &C1, &00
    KW "MODE", &EB, &02
    KW "MOD", &83, &00
    KW "MOVE", &EC, &02
    KW "NEXT", &ED, &02
    KW "NEW", &CA, &01
    KW "NOT", &AC, &00
    KW "OLD", &CB, &01
    KW "ON", &EE, &02
    KW "OFF", &87, &00
    KW "OR", &84, &00
    KW "OPENIN", &8E, &00
    KW "OPENOUT", &AE, &00
    KW "OPENUP", &AD, &00
    KW "OSCLI", &FF, &02
    KW "PRINT", &F1, &02
    KW "PAGE", &90, &43
    KW "PTR", &8F, &43
    KW "PI", &AF, &01
    KW "PLOT", &F0, &02
    KW "POINT(", &B0, &00
    KW "PROC", &F2, &0A
    KW "POS", &B1, &01
    KW "RETURN", &F8, &01
    KW "REPEAT", &F5, &00
    KW "REPORT", &F6, &01
    KW "READ", &F3, &02
    KW "REM", &F4, &20
    KW "RUN", &F9, &01
    KW "RAD", &B2, &00
    KW "RESTORE", &F7, &12
    KW "RIGHT$(", &C2, &00
    KW "RND", &B3, &01
    KW "RENUMBER", &CC, &10
    KW "STEP", &88, &00
    KW "SAVE", &CD, &02
    KW "SGN", &B4, &00
    KW "SIN", &B5, &00
    KW "SQR", &B6, &00
    KW "SPC", &89, &00
    KW "STR$", &C3, &00
    KW "STRING$(", &C4, &00
    KW "SOUND", &D4, &02
    KW "STOP", &FA, &01
    KW "TAN", &B7, &00
    KW "THEN", &8C, &14
    KW "TO", &B8, &00
    KW "TAB(", &8A, &00
    KW "TRACE", &FC, &12
    KW "TIME", &91, &43
    KW "TRUE", &B9, &01
    KW "UNTIL", &FD, &02
    KW "USR", &BA, &00
    KW "VDU", &EF, &02
    KW "VAL", &BB, &00
    KW "VPOS", &BC, &01
    KW "WIDTH", &FE, &02
    KW "PAGE", &D0, &00
    KW "PTR", &CF, &00
    KW "TIME", &D1, &00
    KW "LOMEM", &D2, &00
    KW "HIMEM", &D3, &00
    KW "Missing", &FF, &4F
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
\ ============================================================================
\ Uninitialised sideways RAM — alternating &FF/&00 blocks
\ This is the unused portion of the 16KB ROM slot. The alternating
\ pattern is characteristic of uninitialised BBC Master sideways RAM.
\ ============================================================================
.uninitialised_ram
    EQUB &0D
    FOR n, 1, 27 : EQUB &FF : NEXT
    FOR n, 1, 54
        FOR m, 1, 32 : EQUB &00 : NEXT
        FOR m, 1, 32 : EQUB &FF : NEXT
    NEXT
    FOR n, 1, 32 : EQUB &00 : NEXT
    FOR n, 1, 16 : EQUB &FF : NEXT

