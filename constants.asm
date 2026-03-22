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
basic_str_lo  = &B2            \ BASIC string pointer low
basic_str_hi  = &B3            \ BASIC string pointer high
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
zp_ptr_lo  = &A8               \ General pointer low
zp_ptr_hi  = &A9               \ General pointer high
zp_work_lo = &AA               \ Workspace pointer low
zp_work_hi = &AB               \ Workspace pointer high
zp_tmp_lo  = &AC               \ Temporary pointer low
zp_tmp_hi  = &AD               \ Temporary pointer high
zp_src_lo  = &AE               \ Source pointer low
zp_src_hi  = &AF               \ Source pointer high



\ Temporary: will become labels when data is split
alias_end_lo   = &AE53
alias_end_hi   = &AE54

\ --- OS workspace addresses ---
keyv_lo        = &020A         \ Keyboard vector low byte
keyv_hi        = &020B         \ Keyboard vector high byte
os_mode        = &0230         \ Current screen mode
os_escape_flag = &026A         \ Escape flag (bit 7 set = escape pressed)
os_wrch_dest   = &027D         \ VDU driver destination
os_width_lo    = &0308         \ Text window left column
os_width_hi    = &030A         \ Text window right column
os_disp_addr   = &0255         \ Display start address?

\ --- Hardware registers ---
crtc_addr      = &FE00         \ 6845 CRTC address register
crtc_data      = &FE01         \ 6845 CRTC data register

\ --- Default vectors ---
default_keyv   = &EF39         \ Default KEYV handler address

\ --- STORE buffer pages (in sideways RAM) ---
store_buf_0 = &A655            \ *STORE buffer for ROM page 0 (&8000-&80FF)
store_buf_1 = &A755            \ *STORE buffer for ROM page 1 (&8100-&81FF)
store_buf_2 = &A855            \ *STORE buffer for ROM page 2 (&8200-&82FF)
store_buf_3 = &A55B            \ *STORE buffer for ROM page 3 (&8300-&83FF)

\ --- More OS page 2 workspace ---
os_himem_lo    = &020C         \ OS high water mark low byte
os_himem_hi    = &020D         \ OS high water mark high byte
os_key_trans   = &023C         \ Key translation table address low
os_key_trans_hi = &023D        \ Key translation table address high
os_vdu_x       = &0318         \ VDU text cursor X position
os_autorepeat  = &0255         \ Keyboard auto-repeat period
os_fkey_buf    = &0480         \ Function key buffer start
os_rs423_buf   = &0900         \ RS423 output buffer

\ --- BASIC zero page ---
basic_flags    = &1F           \ BASIC internal flags byte

\ --- Display memory ---
mode7_screen   = &7C00         \ Start of MODE 7 screen memory

\ --- Workspace outside ROM ---
keyon_handler_dest = &D100     \ Destination for key remap handler copy
alias_clear_flag = &B165       \ Alias clear marker
alias_exec_buf   = &A955       \ Alias execution buffer
