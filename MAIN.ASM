.model tiny
.486

esc_code = 1Bh

fsize = 10h
mines = 10h

.stack 100h
.data
   ; Each entry represents one field. The byte for each field is structured as follows
   ; 7 - Hidden/Revealed
   ; 6 - Not Flagged/Flagged
   ; 5 - Safe/Mine
   ; 4 - Unused
   ; 3-0: Number of field
   field db 10h*10h dup (0h)
   colors db 00h, 09h, 0Ah, 0Ch, 01h, 04h, 03h, 05h, 08h
   offsets db -11h, -10h, -0Fh, -01h, 01h, 0Fh, 10h, 11h
   seed dw 0

.code
   ORG 100h

start:
   call init_screen
   ; setup playing field
   mov ax, @DATA
   mov ds, ax
   mov ah, 0   ; setup rng
   int 01ah
   mov seed, dx

setup:   
   mov bl, mines
mine_loop:  ; generated mine positions
   call rng
   ; use di as index into field array
   xor ah, ah
   mov di, ax
   test byte ptr field[di], 20h
   jnz mine_loop
   mov byte ptr field[di], 0A0h
   dec bl
   jnz mine_loop

   call calc_cells

   mov bx, offset field
   call draw_field
   
endless:
   xor ah, ah
   int 16h
   
   cmp al, esc_code
   je final

   jmp endless

final:
   mov ax, 3
   int 10h
   mov ah, 4Ch
   int 21h

; Taken from https://stackoverflow.com/a/40709661/13551386
rng proc
   mov ax, 25173
   mul word ptr seed
   add ax, 13849
   mov seed, ax
   ret
rng endp

calc_cells proc
   mov di, 0FFh
hints_loop: ; calculates necessary info for remaining board (i.e. numbers)
   cmp field[di], 0
   jne hints_loop_end

   call num_surrounding_mines
   or field[di], al
   or field[di], 80h    ; DEBUG: reveal all fields

hints_loop_end:
   cmp di, 0
   je calc_cell_ret
   dec di
   jmp hints_loop

calc_cell_ret:
   ret
calc_cells endp

num_surrounding_mines proc
   mov ah, 0FFh;  ; bitmask for storing which surrounding fields need to be checked
                  ; bits 7-5 = row above, bits 4+3 = before/after, bits 2-0: below 
above:
   cmp di, 10h
   jge below
   and ah, 1Fh    ; mask with 00011111 to eliminate row above
below:
   cmp di, 0EFh
   jle before
   and ah, 0F8h   ; 11111000
before:
   mov bx, di
   shl bl, 4
   jnz after
   and ah, 6Bh    ; 01101011
after:
   cmp bl, 0F0h
   jnz num_calc
   and ah, 0D6h    ; 11010110

num_calc:
   xor al, al
   ; go through each neighbour, if the bits are set
   mov si, 0
n0:
   cmp si, 8
   jz nend
   inc si
   rcl ah, 1
   jnc n0
   mov bx, di
   add bl, byte ptr offsets[si-1] 
   test byte ptr field[bx], 20h
   jz n0
   inc al
   jmp n0
nend:
   ret
num_surrounding_mines endp

include TEXT.ASM
; include VIDEO.ASM
   
   end start