.model tiny
.486

esc_code = 1Bh

fsize = 10h
mines = 25

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
   fields_left dw 100h
   game_over db 0
   game_over_text db 47h, 61h, 6Dh, 65h, 20h, 4Fh, 76h, 65h, 72h
   win_text db 59h, 6Fh, 75h, 20h, 57h, 69h, 6Eh
   old_vector dw 2 dup(?)
   timer dw 1620
   seed dw 0

.code
   ORG 100h

mouse proc far
   push ds
   push es
   push di

   mov bx, @DATA 
   mov ds, bx
   
   ; if game over, do nothing
   cmp game_over, 1
   jge mouse_end

   ; convert coordinates to index for array
   cmp cx, 16   ; less than 16, out of bounds
   jl mouse_end
   cmp cx, 16 + 16 * 16  ; horizontally, one cell is 16px across
   jg mouse_end
   cmp dx, 8
   jl mouse_end
   cmp dx, 8 + 16 * 8
   jg mouse_end
   
   sub cx, 16
   shr cx, 4
   sub dx, 8
   shr dx, 3
   shl dx, 4
   mov di, dx
   add di, cx

   test ax, 04h   ; left button released
   jz test_flag
   ; only reveal if there is no flag
   test field[di], 40h
   jnz mouse_end 
   call reveal
   cmp fields_left, mines
   ja repaint
   mov game_over, 2
   jmp repaint
test_flag:
   test ax, 10h
   jz repaint
   xor field[di], 40h
repaint: 
   call draw_field

mouse_end:
   pop di
   pop es
   pop ds
   ret
mouse endp

reveal proc
   push di
   push si
   push dx
   push ax
   push bx

   ; dont reveal if flagged or already revealed
   test field[di], 0C0h
   jnz reveal_end
   or field[di], 80h
   dec fields_left
   ; if number > 0, dont recurse 
   test field[di], 0Fh
   jnz reveal_end
   ; if mine, game over, dont recurse
   test field[di], 20h
   jz reveal_start
   mov game_over, 1
   jmp reveal_end

reveal_start:
   mov dx, di

   ; loop over neighbours
   call get_neighbour_mask
   mov si, 0
reveal_loop:
   rcl ah, 1
   jnc reveal_loop_end
   mov bx, dx
   add bl, byte ptr offsets[si]
   mov di, bx
   call reveal
reveal_loop_end:
   inc si
   cmp si, 8
   jne reveal_loop

reveal_end:
   pop bx
   pop ax
   pop dx
   pop si
   pop di
   ret
reveal endp

timer_int:
   push ax
   mov ax, @DATA
   mov ds, ax
   cmp game_over, 0
   ja timer_end
   dec timer
   call draw_timer
   cmp timer, 0
   jne timer_end
   mov game_over, 1
   call draw_field
timer_end:
   pop ax
   iret

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
   mov byte ptr field[di], 020h
   dec bl
   jnz mine_loop

   ; set mouse procedure
   push cs
   pop es   
   mov cx, 00010100b    ; react on left/right button released
   mov dx, offset mouse
   mov ax, 0Ch
   int 33h

   ; enable cursor
   mov ax, 1
   int 33h
   
   ; register timer interrupt
   mov al, 1Ch
   mov ah, 35h
   int 21h
   push es
   pop ax
   mov old_vector, ax 
   mov old_vector+2, bx

   push ds
   push cs
   pop ds
   mov dx, offset timer_int
   mov al, 1Ch
   mov ah, 25h
   int 21h
   pop ds

   call calc_cells
   call draw_field
   
endless:
   xor ah, ah
   int 16h
   
   cmp al, esc_code
   je final

   jmp endless

final:
   mov ax, @DATA
   mov ds, ax
   xor ax, ax
   int 33h
   mov ax, 3
   int 10h
   mov ah, 4Ch
   int 21h
   mov ax, [old_vector]
   mov ds, ax
   mov dx, [old_vector+2]
   mov al, 1Ch
   mov ah, 25h
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
   ; or field[di], 80h    ; DEBUG: reveal all fields

hints_loop_end:
   cmp di, 0
   je calc_cell_ret
   dec di
   jmp hints_loop

calc_cell_ret:
   ret
calc_cells endp

get_neighbour_mask proc
   mov ah, 0FFh;  ; bitmask for storing which surrounding fields need to be checked
                  ; bits 7-5 = row above, bits 4+3 = before/after, bits 2-0: below 
above:
   cmp di, 10h
   jae below
   and ah, 1Fh    ; mask with 00011111 to eliminate row above
below:
   cmp di, 0EFh
   jbe before
   and ah, 0F8h   ; 11111000
before:
   mov bx, di
   shl bl, 4
   jnz after
   and ah, 6Bh    ; 01101011
after:
   cmp bl, 0F0h
   jnz neighbour_end
   and ah, 0D6h    ; 11010110

neighbour_end: 
   ret
get_neighbour_mask endp

num_surrounding_mines proc
   call get_neighbour_mask

   xor al, al
   ; go through each neighbour, if the bits are set
   xor si, si
num_loop:
   rcl ah, 1
   jnc nend
   mov bx, di
   add bl, byte ptr offsets[si] 
   test byte ptr field[bx], 20h
   jz nend
   inc al
nend:
   inc si
   cmp si, 9
   jne num_loop

   ret
num_surrounding_mines endp

; include TEXT.ASM
include VIDEO.ASM
   
   end start