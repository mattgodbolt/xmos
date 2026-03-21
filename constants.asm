\ ============================================================================
\ XMOS — System Constants
\ ============================================================================

\ --- MOS entry points ---
oscli  = &FFF7
osbyte = &FFF4
osword = &FFF1
oswrch = &FFEE
osnewl = &FFE7
osasci = &FFE3
osrdch = &FFE0
osfile = &FFDD
osargs = &FFDA
osbget = &FFD7
osbput = &FFD4
osgbpb = &FFD1
osfind = &FFCE
gsread = &FFC5
gsinit = &FFC2
oseven = &FFBF
osrdrm = &FFB9

\ --- Hardware registers ---
sheila_romsel = &FE30           \ ROM select latch

\ --- Service call numbers ---
svc_command      = &04          \ Unrecognised * command
svc_help         = &09          \ *HELP request
svc_claim_static = &22          \ Claim static workspace
svc_post_reset   = &27          \ Post-reset (soft break)

\ --- OS workspace ---
rom_workspace_table = &0DF0     \ Per-ROM private workspace (&0DF0+rom_number)

\ --- ROM header flags ---
romtype_service = &80           \ Has service entry
romtype_6502    = &02           \ 6502 CPU type

\ --- BASIC zero page locations ---
\ These are valid when BASIC is the current language
basic_page_hi = &18            \ PAGE high byte (start of BASIC program)
basic_top_lo  = &12            \ TOP low byte (end of BASIC program)
basic_top_hi  = &13            \ TOP high byte
basic_lomem   = &00            \ LOMEM (varies)

\ --- OS zero page ---
cmd_line_lo = &F2              \ Command line pointer low (set by MOS)
cmd_line_hi = &F3              \ Command line pointer high
rom_number  = &F4              \ Current paged ROM number

\ --- XMOS workspace (zero page, temporary for * commands) ---
\ &A8-&AF are reserved by MOS for sideways ROM use during commands
zp_ptr_lo = &A8                \ General pointer low byte
zp_ptr_hi = &A9                \ General pointer high byte



\ Temporary: will become labels when data is split
alias_end_lo   = &AE53
alias_end_hi   = &AE54
