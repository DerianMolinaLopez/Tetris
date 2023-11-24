; tetrisv.asm - Don Yang (uguu.org)
;
; This version uses vertical synchronization pulses instead of clock ticks.
; Runs slightly faster and block rotates/moves smoother.
;
; Keys:
;     Esc = quit
;     Left = move left
;     Right = move right
;     Pause = pause
;     Down = drop to floor if not already there, or stop moving if it has
;     Most other keys rotate the block
;
; To make tetris.com:
;     tasm tetrisv
;     tlink /t tetrisv
;
; 09/19/99: blit: vsync
;           newblock: longer delay
;           getinput: longer delay
;           main: longer delay
;           showscore: longer delay


;..................................................................... Header
.386
.model tiny

; Constants
BACKGROUND_BASE   equ   0818h
BLOCK_STATIC      equ   0b0h
BLOCK_DYNAMIC     equ   0dbh

KEY_ESCAPE        equ   01h
KEY_DROP          equ   50h
KEY_LEFT          equ   4bh
KEY_RIGHT         equ   4dh

FIELD_WIDTH       equ   10
FIELD_HEIGHT      equ   23
FIELD_MARGIN      equ   3     ; Real width = 16
FIELD_SIZE        equ   ((FIELD_WIDTH + 2 * FIELD_MARGIN) * (FIELD_HEIGHT + 2 * FIELD_MARGIN))
FIELD_OFFSET      equ   25

FIRST_CELL        equ   (offset Field + (FIELD_WIDTH + 2 * FIELD_MARGIN) * FIELD_MARGIN + FIELD_MARGIN)

SCORE_POS         equ   ((3 * 80 + 58) * 2)
LINE_POS          equ   ((5 * 80 + 58) * 2)
LEVEL_POS         equ   ((7 * 80 + 58) * 2)
TEXT_LENGTH       equ   8
NUMBER_LENGTH     equ   10

END_TEXT_RPOS     equ   ((10 * 80 + (FIELD_OFFSET - 2)) * 2)
END_TEXT_WIDTH    equ   FIELD_WIDTH * 2 + 6
END_TEXT_HEIGHT   equ   5
END_TEXT_POS      equ   ((12 * 80 + FIELD_OFFSET + 6) * 2)
END_TEXT_LENGTH   equ   10

INIT_BLOCK        equ   (FIELD_WIDTH / 2)
ROTATE_DELTA      equ   (7 * 4 * 2)
ROTATE_LIMIT      equ   (ROTATE_DELTA * 4)
MAX_LEVEL         equ   10
LINES_PER_LEVEL   equ   25
LINE_SCORE_POS    equ   ((11 * 80 + FIELD_OFFSET + 1) * 2)

IMAGE_SIZE        equ   72

;....................................................................... Code

sCode       segment para public use16
            assume cs:sCode, ds:sCode, es:sCode, ss:sCode
   org      100h

tetris:

;----------------------------------------------------------------------- main
main        proc near

   ; Set color text mode
   mov      ax, 3
   int      10h

   ; Set segments
   xor      ax, ax
   mov      fs, ax      ; FS:046c = clock

   ; Seed random number generator
   mov      eax, fs:[046ch]
   mov      RandSeed, eax

   ; Initialize game
   cld
   call     reset
   call     rotateall

   ; Initialize screen
   call     drawbg

main_MainLoop:

      ; Redraw screen
      call     render

      ; Create block
      call     newblock

main_BlockLoop:

         ; Draw block
         mov      dh, BlockColor
         call     drawblock
         call     blit

         ; Erase block
         xor      dh, dh
         call     drawblock

         ; Read input
         call     getinput
         jc       short main_Cleanup

         ; Animate block
         mov      ax, BlockTime
         or       ax, ax
         jz       short main_DropBlock

         dec      BlockTime
         jmp      main_BlockLoop

main_DropBlock:

         ; Check for collision with floor
         mov      dx, word ptr [BlockX]
         mov      bx, BlockR
         inc      dh
         call     testblock
         jc       short main_StopBlock

         ; Shift block down
         inc      BlockY
         mov      ax, MAX_LEVEL
         sub      ax, Level
         shl      ax, 3
         inc      ax
         mov      BlockTime, ax
         jmp      main_BlockLoop

main_StopBlock:

      ; Block has come to rest
      call     stopblock
      call     clearlines

      ; Check for filled field
      test     byte ptr ds:[FIRST_CELL + FIELD_WIDTH / 2], 0ffh
      jz       main_MainLoop

main_Cleanup:

   ; Display end message
   call     gameover

   ; Clear screen
   mov      ax, 3
   int      10h

   ; Display text
   mov      ah, 9
   mov      dx, offset TitleStr  ; DS:DX points at string
   int      21h

   ; Exit
   mov      ax, 4c00h
   int      21h                                                            ;*

main        endp

;----------------------------------------------------------------------- blit
; Copy screen buffer to video memory.
;
; IN: Screen = screen buffer.
;     DF cleared.
; OUT: EAX/CX/DX/SI/DI destroyed.
blit        proc near

   ; Set blit parameters
   mov      cx, (80 * 25) / 2    ; CX = count
   mov      ax, 0b800h
   mov      si, offset Screen    ; DS:SI = source
   mov      es, ax
   xor      di, di               ; ES:DI = target

   ; Wait for synchronization
   mov      dx, 3dah

blit_WaitForSync1:

      in       al, dx
      test     al, 8
      jnz      blit_WaitForSync1

blit_WaitForSync2:

      in       al, dx
      test     al, 8
      jz       blit_WaitForSync2

   ; Copy screen
   rep      movsd

   ; Reload segment
   mov      ax, ds
   mov      es, ax

   ret                                                                     ;*

blit        endp

;----------------------------------------------------------------- buildblock
; Calculate block offsets in game field.
;
; IN: (DL, DH) = block coordinate.
;     BX = block rotation offset.
;     BlockType = shape table offset.
;     BlockShapeX, BlockShapeY = shape table.
; OUT: CellX, CellY = translated block coordinates.
;      AX/CX/SI/DI destroyed.
buildblock  proc near

   mov      di, offset CellX

   ; Translate X values
   mov      si, offset BlockShapeX
   add      si, BlockType
   add      si, bx
   mov      cx, 4

buildblock_TranslateX:

      lodsb             ; AL = shape x
      add      al, dl
      cbw               ; AX = translated x
      stosw

      loop     buildblock_TranslateX

   ; Translate Y values
   add      si, 6 * 4
   mov      cx, 4

buildblock_TranslateY:

      lodsb             ; AL = shape y
      add      al, dh
      cbw               ; AX = translated y
      stosw

      loop     buildblock_TranslateY

   ret                                                                     ;*

buildblock  endp

;----------------------------------------------------------------- clearlines
; Check for completed lines and remove them.
;
; IN: Field = game field.
;     Level = current level.
; OUT: Field updated.
;      Score updated.
;      Lines updated.
;      Screen updated.
;      Calls shiftdown, showscore, levelup and blit.
;      AX/CX/DX destroyed.
clearlines  proc near

   ; Increase score for dropped block
   inc      dword ptr [Score]

   ; Count rows
   xor      bx, bx               ; BX = row index
   xor      bp, bp               ; BP = cleared row count

clearlines_CountRowLoop:

      mov      si, bx
      shl      si, 4
      add      si, FIRST_CELL    ; DS:SI points at first cell in row AH
      mov      cx, FIELD_WIDTH
      xor      ax, ax
      xor      dx, dx

clearlines_CountCellLoop:

         lodsb
         or       al, al
         setnz    ah             ; AH == 1 if cell is occupied
         add      dl, ah
         loop     clearlines_CountCellLoop

      cmp      dl, 10
      jl       short clearlines_NextRow

      ;; A row has been filled

      ; Remove row
      mov      di, bx
      call     shiftdown

      ; Increase row count
      inc      bp

      ; Mark removed row
      mov      di, bx
      mov      ax, bx
      shl      di, 7
      shl      ax, 5
      add      di, ax            ; DI = BX * 160
      add      di, (FIELD_OFFSET + 1) * 2 + 160 + offset Screen
      mov      ax, 7f40h
      mov      cx, FIELD_WIDTH * 2
      rep      stosw
      call     blit

clearlines_NextRow:

      inc      bx
      cmp      bx, FIELD_HEIGHT
      jl       clearlines_CountRowLoop

   ; Increase score
   or       bp, bp
   jz       short clearlines_end
   movzx    ebx, bp
   add      Lines, ebx
   dec      bx
   shl      bx, 1
   add      bx, offset ScoreTable
   movzx    eax, word ptr [bx]
   add      Score, eax

   ; Show increase in score
   call     showscore
   shl      bp, 3

clearlines_WaitScore:

      call     blit

      dec      bp
      jnz      clearlines_WaitScore

   ; Level up
   mov      eax, Lines
   cmp      eax, LineLimit
   jb       short clearlines_end
   call     levelup

clearlines_end:

   ret                                                                     ;*

clearlines  endp

;-------------------------------------------------------------------- dcimage
; Draw background image for final level.
;
; IN: BgLayer1, BgLayer2 = RLE encoded image.
;     DF cleared.
; OUT: Screen updated.
;      AX/BX/CX/DX/SI/DI destroyed.
dcimage     proc near

   mov      ax, 0c04h
   mov      bx, 2

   mov      si, offset BgLayer1

dcimage_DecodeLayers:

      mov      dx, IMAGE_SIZE

dcimage_LoadBlock:

         mov      di, [si]
         mov      cx, [si+2]
         add      di, offset Screen
         add      si, 4

dcimage_PaintBlock:

            mov      [di], al
            add      di, 2
            loop     dcimage_PaintBlock

         dec      dx
         jnz      dcimage_LoadBlock

      xchg     ah, al
      dec      bx
      jnz      dcimage_DecodeLayers

   ret                                                                     ;*

dcimage     endp

;--------------------------------------------------------------------- drawbg
; Draw field background.
;
; IN: BgTexts = background text strings.
;     DF cleared.
; OUT: Screen updated.
;      Calls rand.
;      AX/CX/SI/DI destroyed.
drawbg      proc near

   ; Fill background
   mov      di, offset Screen
   mov      cx, 80 * 25

drawbg_FillBackgroundLoop:

      call     rand
      and      ax, 3
      add      ax, BACKGROUND_BASE

      stosw
      loop     drawbg_FillBackgroundLoop

   ; Draw middle borders
   mov      eax, 0fdbh
   mov      cx, FIELD_HEIGHT + 2
   mov      di, FIELD_OFFSET * 2 + offset Screen

drawbg_DrawBorderLoop:

      mov      [di], ax
      mov      byte ptr [di-2], 0
      mov      [di + (FIELD_WIDTH * 2 + 1) * 2], eax

      add      di, 160
      loop     drawbg_DrawBorderLoop

   ; Draw top border
   mov      ax, 0fdch
   mov      cx, FIELD_WIDTH * 2 + 2
   mov      di, FIELD_OFFSET * 2 + offset Screen
   rep      stosw

   ; Draw bottom border
   mov      al, 0dfh
   mov      cx, FIELD_WIDTH * 2 + 2
   mov      di, FIELD_OFFSET * 2 + offset Screen + (FIELD_HEIGHT + 1) * 160
   rep      stosw

   ; Draw score text
   mov      ah, 0fh
   mov      si, offset BgTexts
   mov      di, offset Screen + SCORE_POS - TEXT_LENGTH * 2
   mov      cx, TEXT_LENGTH

drawbg_DrawScoreLoop:

      lodsb                ; AL = character
      stosw
      loop     drawbg_DrawScoreLoop

   ; Draw blank area (reserved for number text)
   mov      ax, 0700h
   mov      cx, NUMBER_LENGTH + 2
   rep      stosw

   ; Draw line text
   mov      ah, 0fh
   mov      di, offset Screen + LINE_POS - TEXT_LENGTH * 2
   mov      cx, TEXT_LENGTH

drawbg_DrawLineLoop:

      lodsb
      stosw
      loop     drawbg_DrawLineLoop

   ; Draw blank area
   mov      ax, 0700h
   mov      cx, NUMBER_LENGTH + 2
   rep      stosw

   ; Draw level text
   mov      ah, 0fh
   mov      di, offset Screen + LEVEL_POS - TEXT_LENGTH * 2
   mov      cx, TEXT_LENGTH

drawbg_DrawLevelLoop:

      lodsb
      stosw
      loop     drawbg_DrawLevelLoop

   ; Reserve area for level indicator
   mov      ax, 0700h
   stosw
   inc      ax
   mov      cx, 10
   rep      stosw
   dec      ax
   stosw

   ret                                                                     ;*

drawbg      endp

;------------------------------------------------------------------ drawblock
; Draw block.
;
; IN: BlockX, BlockY = block coordinate.
;     BlockR = block rotation offset.
;     DH = block color.
;     DF cleared.
; OUT: Screen updated.
;      CellX updated.
;      CellY updated.
;      Calls buildblock.
;      AX/BX/CX/DX/SI/DI destroyed.
drawblock   proc near

   push     dx                                                       ;      2

   ; Set block offsets
   mov      dx, word ptr [BlockX]
   mov      bx, BlockR
   call     buildblock

   ; Set block character
   pop      dx                                                       ;      0
   mov      dl, BLOCK_DYNAMIC

   ; Draw cells
   mov      cx, 4
   mov      si, offset CellY
   mov      di, offset Screen + FIELD_OFFSET * 2 + 162

drawblock_CellLoop:

      lodsw                   ; AX = y value
      mov      bx, ax
      shl      bx, 6
      shl      ax, 4
      add      bx, ax         ; BX = y * (64 + 16) = y * 80
      mov      ax, [si-10]    ; AX = x value
      shl      ax, 1
      add      bx, ax
      shl      bx, 1          ; BX = screen offset

      mov      [di+bx], dx
      mov      [di+bx+2], dx
      loop     drawblock_CellLoop

   ret                                                                     ;*

drawblock   endp

;------------------------------------------------------------------- gameover
; Display end message.
;
; IN: EndText = end text string.
;     DF cleared.
; OUT: Screen updated.
;      AX/CX/DX/SI/DI destroyed.
gameover    proc near

   ; Draw rectangle
   mov      di, END_TEXT_RPOS + offset Screen
   mov      ax, 0fc9h
   stosw
   mov      al, 0cdh
   mov      cx, END_TEXT_WIDTH - 2
   rep      stosw
   mov      al, 0bbh
   stosw
   add      di, (80 - END_TEXT_WIDTH) * 2
   dec      ax
   mov      dx, END_TEXT_HEIGHT - 2

gameover_DrawBoxLoop:

      stosw
      xor      al, al
      mov      cx, END_TEXT_WIDTH - 2
      rep      stosw
      mov      al, 0bah
      stosw

      add      di, (80 - END_TEXT_WIDTH) * 2
      dec      dx
      jnz      gameover_DrawBoxLoop

   mov      al, 0c8h
   stosw
   mov      al, 0cdh
   mov      cx, END_TEXT_WIDTH - 2
   rep      stosw
   mov      al, 0bch
   stosw

gameover_FlashTextLoop:

      ; Draw text
      mov      si, offset EndText
      mov      di, END_TEXT_POS + offset Screen
      mov      cx, END_TEXT_LENGTH

gameover_DrawTextLoop:

         lodsb
         stosw
         loop     gameover_DrawTextLoop

      push     ax                                                    ;      2
      call     blit
      pop      ax                                                    ;      0
      dec      ah
      jnz      gameover_FlashTextLoop

   ; Display text and wait for keypress
   mov      ah, 7fh
   mov      si, offset EndText
   mov      di, END_TEXT_POS + offset Screen
   mov      cx, END_TEXT_LENGTH

gameover_DrawTextLoop2:

      lodsb
      stosw
      loop        gameover_DrawTextLoop2

   call     blit

   xor      ah, ah
   int      16h

   ret                                                                     ;*

gameover    endp

;------------------------------------------------------------------- getinput
; Process keyboard input.
;
; IN: BlockX, BlockY = block coordinate.
;     BlockR = block rotation.
; OUT: CF set = end program.
;      CF cleared = continue.
;      BlockX updated.
;      BlockY updated.
;      BlockR updated.
;      BlockTime updated.
;      Calls buildblock and testblock.
;      AX/BX/DX destroyed.
getinput    proc near

   ; Check for keystroke
   mov      ah, 1
   int      16h
   jz       short getinput_end

   ; Get keystroke
   xor      ah, ah
   int      16h
   cmp      ah, KEY_LEFT
   je       short getinput_left
   cmp      ah, KEY_RIGHT
   je       short getinput_right
   cmp      ah, KEY_DROP
   je       short getinput_drop
   cmp      ah, KEY_ESCAPE
   je       getinput_exit

   ; Set offset
   mov      bx, BlockR
   mov      dx, word ptr [BlockX]
   add      bx, ROTATE_DELTA
   cmp      bx, ROTATE_LIMIT
   jb       short getinput_rotatetest

   xor      bx, bx

getinput_rotatetest:

   ; Check rotation
   push     bx                                                       ;     2
   call     testblock
   pop      bx                                                       ;     0
   jc       short getinput_end

   ; Set rotation
   mov      BlockR, bx

getinput_end:

   clc
   ret                                                                     ;*

getinput_left:

   ; Check position
   mov      dx, word ptr [BlockX]
   mov      bx, BlockR
   dec      dl
   call     testblock
   jc       getinput_end

   ; Set position
   dec      BlockX
   jmp      getinput_end

getinput_right:

   ; Check position
   mov      dx, word ptr [BlockX]
   mov      bx, BlockR
   inc      dl
   call     testblock
   jc       getinput_end

   ; Set position
   inc      BlockX
   jmp      getinput_end

getinput_drop:

   ; Check for floored block
   mov      dx, word ptr [BlockX]
   mov      bx, BlockR
   inc      dh
   call     testblock
   jnc      short getinput_dropping

   xor      ax, ax
   mov      BlockTime, ax
   jmp      getinput_end

getinput_dropping:

      ; Move block down until floor reached
      mov      dx, word ptr [BlockX]
      mov      bx, BlockR
      inc      dh
      call     testblock
      jc       short getinput_dropped

      inc      byte ptr [BlockY]
      jmp      getinput_dropping

getinput_dropped:

   ; Reset block time (for last minute shifts)
   mov      ax, MAX_LEVEL
   sub      ax, Level
   shl      ax, 3
   inc      ax
   mov      BlockTime, ax
   jmp      getinput_end

getinput_exit:

   stc
   ret                                                                     ;*


getinput    endp

;----------------------------------------------------------------------- itoa
; Convert integer to ASCII.
;
; IN: EAX = unsigned integer.
;     DI = output offset.
; OUT: DI points at leading space.
;      EAX/EBX/EDX destroyed.
itoa        proc near

   mov      ebx, 10

itoa_ModLoop:

      xor      edx, edx
      div      ebx         ; DL = remainder = unit digit

      add      dl, '0'
      mov      [di], dl
      sub      di, 2

      or       eax, eax
      jnz      itoa_ModLoop

   ret                                                                     ;*

itoa        endp

;-------------------------------------------------------------------- levelup
; Increase level.
;
; IN: Level = current level.
;     InitScore = initial score table.
; OUT: Level updated.
;      ScoreTable updated.
;      LineLimit updated.
;      Calls dcimage.
;      EAX/EBX destroyed.
levelup     proc near

   ; Check level
   cmp      Level, MAX_LEVEL
   jge      short levelup_end

   ; Increase level
   mov      ax, Level
   inc      ax
   mov      Level, ax

   ; Update display
   mov      bx, NUMBER_LENGTH
   sub      bx, ax
   shl      bx, 1
   add      bx, LEVEL_POS + offset Screen + 2
   inc      byte ptr [bx]

   ; Update score table
   mov      eax, dword ptr [InitScore]
   mov      ebx, dword ptr [InitScore+4]
   add      dword ptr [ScoreTable], eax
   add      dword ptr [ScoreTable+4], ebx

   ; Draw background
   cmp      byte ptr [Level], MAX_LEVEL
   jb       short levelup_end
   call     dcimage

levelup_end:

   ; Set next level limit
   add      dword ptr [LineLimit], LINES_PER_LEVEL
   ret                                                                     ;*

levelup     endp

;------------------------------------------------------------------- newblock
; Generate new block.
;
; IN: Level = current level.
; OUT: BlockColor updated.
;      BlockType updated.
;      BlockX updated.
;      BlockY updated.
;      BlockR updated.
;      BlockTime updated.
;      Calls rand.
;      AX/BX/CX/DX destroyed.
newblock    proc near

   ; Get block type
   call     rand
   xor      dx, dx
   mov      bx, 7
   div      bx                ; DX = block type (0 to 6)

   ; Set block foreground color
   mov      cl, 9
   add      cx, dx            ; CL = block foreground color

   ; Store block type
   shl      dx, 2
   mov      BlockType, dx     ; DX = offset to block shape tables

   ; Set block color
   call     rand
   xor      dx, dx
   mov      bx, 6
   div      bx
   inc      dx
   shl      dx, 4             ; DL = block background color
   or       cl, dl
   mov      BlockColor, cl

   ; Set initial block position/rotation
   mov      dword ptr [BlockX], INIT_BLOCK

   ; Set drop delay
   mov      ax, MAX_LEVEL
   sub      ax, Level      ; Level = 0 (slowest) to 10 (fastest)
   shl      ax, 3
   inc      ax             ; Delay = 21 (slowest) to 1 (fastest)
   mov      BlockTime, ax

   ret                                                                     ;*

newblock    endp

;----------------------------------------------------------------------- rand
; Generate random number (power residue function).
;
; IN: RandSeed = random number seed.
; OUT: AX = random number.
;      RandSeed updated.
;      EAX/EDX destroyed.
rand        proc near

   mov      eax, RandSeed
   mov      edx, 343fdh
   mul      edx
   add      eax, 269ec3h
   mov      RandSeed, eax
   shr      eax, 16

   ret                                                                     ;*

rand        endp

;--------------------------------------------------------------------- render
; Draw game field.
;
; IN: Field = game field.
;     Level = current level.
;     DF cleared.
; OUT: Screen updated.
;      Calls itoa.
;      EAX/BX/CX/DX/SI/DI destroyed.
render      proc near

   mov      si, FIRST_CELL          ; DS:SI = top-left cell
   mov      di, offset Screen + FIELD_OFFSET * 2 + 162   ; ES:DI = Screen
   mov      dx, FIELD_HEIGHT

   mov      ax, Level
   inc      ax
   shr      ax, 2
   mov      ah, BLOCK_STATIC
   add      ah, al

render_DrawRowLoop:

      mov      cx, FIELD_WIDTH

render_DrawColumnLoop:

         lodsb             ; AL = color
         xchg     ah, al
         stosw
         stosw
         xchg     al, ah

         loop     render_DrawColumnLoop

      add      si, FIELD_MARGIN * 2
      add      di, (80 - FIELD_WIDTH * 2) * 2
      dec      dx
      jnz      render_DrawRowLoop

   ; Display score
   mov      eax, Score
   mov      di, SCORE_POS + NUMBER_LENGTH * 2 + offset Screen
   call     itoa

   ; Display lines
   mov      eax, Lines
   mov      di, LINE_POS + NUMBER_LENGTH * 2 + offset Screen
   call     itoa

   ret                                                                     ;*

render      endp

;---------------------------------------------------------------------- reset
; Reset game field.
;
; IN: InitScore = initial score table.
;     DF cleared.
; OUT: Field updated.
;      ScoreTable updated.
;      EAX/ECX/EDX/DI destroyed.
reset       proc near

   ; Fill boundaries
   mov      al, 0ffh
   mov      di, offset Field
   mov      cx, FIELD_SIZE
   rep      stosb

   ; Empty field / set offsets
   inc      al
   mov      dx, FIELD_HEIGHT
   mov      di, FIRST_CELL

reset_EmptyLoop:

      mov      cx, FIELD_WIDTH
      rep      stosb

      add      di, 2 * FIELD_MARGIN
      dec      dx
      jnz      reset_EmptyLoop

   ; Reset score table
   mov      eax, dword ptr [InitScore]
   mov      edx, dword ptr [InitScore+4]
   mov      dword ptr [ScoreTable], eax
   mov      dword ptr [ScoreTable+4], edx

   ret                                                                     ;*

reset       endp

;------------------------------------------------------------------ rotateall
; Build rotation table.
;
; IN: BlockShapeX, BlockShapeY = block shape table.
;     DF cleared.
; OUT: BlockRTable updated.
;      AX/CX/SI/DI destroyed.
rotateall   proc near

   ;; Rotation 1: (x, y) -> (y, -x)

   ; Copy Y values
   mov      si, offset BlockShapeY
   mov      di, offset BlockRTable
   mov      cx, 7
   rep      movsd

   ; Negate X values
   mov      si, offset BlockShapeX
   mov      cx, 7 * 4

rotateall_r1:

      lodsb
      neg      al
      stosb
      loop     rotateall_r1

   ;; Rotation 2: (x, y) -> (-x, -y)

   ; Negate coordinates
   mov      si, offset BlockShapeX
   mov      cx, 7 * 4 * 2

rotateall_r2:

      lodsb
      neg      al
      stosb
      loop     rotateall_r2

   ;; Rotation 3: (x, y) -> (-y, x)

   ; Negate Y values
   mov      si, offset BlockShapeY
   mov      cx, 7 * 4

rotateall_r3:

      lodsb
      neg      al
      stosb
      loop     rotateall_r3

   ; Copy X values
   mov      si, offset BlockShapeX
   mov      cx, 7
   rep      movsd

   ret                                                                     ;*

rotateall   endp

;------------------------------------------------------------------ shiftdown
; Shift rows down (after clearing a line).
;
; IN: Field = game field.
;     DI = row index (top row = 0).
; OUT: AL/CX/DX/SI/DI destroyed.
shiftdown   proc near

   ; Shift rows down
   std
   mov      dx, di
   shl      di, 4
   add      di, FIRST_CELL - FIELD_MARGIN
   mov      si, di
   add      di, 16

shiftdown_RowLoop:

      mov      cx, 16
      rep      movsb
      dec      dx
      jnz      shiftdown_RowLoop

   ; Empty top row
   cld
   mov      di, FIRST_CELL
   xor      al, al
   mov      cx, FIELD_WIDTH
   rep      stosb

   ret                                                                     ;*

shiftdown   endp

;------------------------------------------------------------------ showscore
; Display score of newly cleared lines.
;
; IN: EAX = score.
;     DF cleared.
; OUT: Calls itoa.
;      EAX/DI destroyed.
showscore   proc near

   push     ax                                                       ;      2

   ; Clear area for score
   mov      ax, 0f20h
   mov      di, LINE_SCORE_POS + offset Screen
   mov      cx, FIELD_WIDTH * 2
   rep      stosw

   ; Display score
   pop      ax                                                       ;      0
   sub      di, 16
   call     itoa

   ret                                                                     ;*

showscore   endp

;------------------------------------------------------------------ stopblock
; Stop block motion.
;
; IN: CellX, CellY = translated block data (using buildblock).
;     BlockColor = block color.
;     DF cleared.
; OUT: Field updated.
;      Calls buildblock.
;      AX/BX/CX/DX/SI destroyed.
stopblock   proc near

   ; Get cell offsets
   mov      dx, word ptr [BlockX]
   mov      bx, BlockR
   call     buildblock

   ; Write block
   mov      si, offset CellY
   mov      dl, BlockColor
   mov      cx, 4

stopblock_WriteBlock:

      lodsw                   ; AX = y value
      mov      bx, [si-10]    ; BX = x value
      shl      ax, 4
      add      bx, ax

      mov      [bx+FIRST_CELL], dl
      loop     stopblock_WriteBlock

   ret                                                                     ;*

stopblock   endp

;------------------------------------------------------------------ testblock
; Test block for collision.
;
; IN: Field = game field.
;     (DL, DH) = block coordinate.
;     BX = block rotation.
;     DF cleared.
; OUT: CF set = collision.
;      CF cleared = no collision.
;      Calls buildblock.
;      AX/BX/CX/DX/SI destroyed.
testblock   proc near

   ; Generate coordinates
   call     buildblock

   ; Test coordinates
   mov      si, offset CellY
   mov      cx, 4

testblock_loop:

      lodsw                         ; AX = y value
      movsx    bx, [si-10]          ; BX = x value
      shl      ax, 4
      add      bx, ax               ; BX = cell offset

      test     byte ptr ds:[bx+FIRST_CELL], 0ffh
      jnz      short testblock_end

      loop     testblock_loop

   clc
   ret                                                                     ;*

testblock_end:
   stc
   ret                                                                     ;*

testblock   endp


;....................................................................... Data

   TitleStr    db    'Tetris 1.@ (9/9/99) - '
               db    'Don Yang (uguu.org)', 13, 10, 36

   BgTexts     db    ' Score :'
               db    ' Lines :'
               db    ' Level :'
   EndText     db    'Game Over!'

   BgLayer1    dw    97, 4
               dw    203, 4
               dw    273, 4
               dw    355, 8
               dw    417, 17
               dw    507, 12
               dw    661, 10
               dw    761, 11
               dw    815, 10
               dw    897, 2
               dw    945, 1
               dw    973, 8
               dw    1007, 2
               dw    1069, 2
               dw    1091, 9
               dw    1129, 8
               dw    1161, 5
               dw    1217, 2
               dw    1271, 1
               dw    1287, 7
               dw    1317, 7
               dw    1383, 10
               dw    1419, 8
               dw    1445, 7
               dw    1473, 7
               dw    1549, 9
               dw    1603, 7
               dw    1643, 1
               dw    1697, 1
               dw    1713, 8
               dw    1743, 8
               dw    1789, 6
               dw    1861, 1
               dw    1875, 7
               dw    1905, 7
               dw    1921, 7
               dw    1959, 1
               dw    2023, 1
               dw    2049, 1
               dw    2067, 14
               dw    2119, 1
               dw    2185, 1
               dw    2231, 4
               dw    2269, 6
               dw    2345, 1
               dw    2359, 7
               dw    2403, 7
               dw    2441, 1
               dw    2505, 1
               dw    2519, 7
               dw    2577, 1
               dw    2605, 1
               dw    2679, 7
               dw    2739, 1
               dw    2755, 8
               dw    2839, 7
               dw    2901, 1
               dw    2919, 6
               dw    2977, 1
               dw    3009, 1
               dw    3051, 8
               dw    3085, 3
               dw    3153, 8
               dw    3215, 9
               dw    3307, 9
               dw    3379, 12
               dw    3457, 12
               dw    3545, 13
               dw    3631, 2
               dw    3713, 9
               dw    3781, 3
               dw    3887, 2
   BgLayer2    dw    209, 1
               dw    257, 8
               dw    359, 6
               dw    423, 12
               dw    511, 7
               dw    663, 7
               dw    765, 8
               dw    819, 6
               dw    943, 1
               dw    975, 5
               dw    1057, 6
               dw    1093, 7
               dw    1131, 6
               dw    1163, 4
               dw    1219, 1
               dw    1263, 4
               dw    1289, 5
               dw    1319, 5
               dw    1387, 7
               dw    1421, 6
               dw    1447, 5
               dw    1475, 5
               dw    1551, 7
               dw    1583, 7
               dw    1605, 5
               dw    1631, 6
               dw    1715, 6
               dw    1745, 6
               dw    1763, 6
               dw    1791, 5
               dw    1857, 2
               dw    1877, 6
               dw    1907, 6
               dw    1923, 6
               dw    1949, 5
               dw    2017, 3
               dw    2037, 6
               dw    2069, 5
               dw    2083, 6
               dw    2109, 5
               dw    2177, 4
               dw    2199, 6
               dw    2243, 6
               dw    2271, 5
               dw    2337, 4
               dw    2361, 5
               dw    2405, 5
               dw    2431, 5
               dw    2497, 4
               dw    2521, 5
               dw    2565, 6
               dw    2593, 6
               dw    2657, 4
               dw    2681, 5
               dw    2727, 6
               dw    2757, 6
               dw    2817, 3
               dw    2841, 5
               dw    2889, 6
               dw    2921, 5
               dw    2997, 6
               dw    3053, 6
               dw    3089, 1
               dw    3155, 6
               dw    3217, 6
               dw    3309, 7
               dw    3383, 7
               dw    3461, 9
               dw    3549, 10
               dw    3617, 7
               dw    3719, 6
               dw    3777, 2

   Level       dw    0
   Score       dd    0
   Lines       dd    0
   LineLimit   dd    LINES_PER_LEVEL

   InitScore   dw    100, 300, 500, 800

   BlockShapeX db    -1,  0,  1,  1    ; 0 = #0#
               db     0,  0,  1,  1    ;       #   1 = 0#
               db    -1, -1,  0,  1    ;               ##   2 = #0#
               db    -1,  0,  0,  1    ; 3 = #0#                #
               db    -1,  0,  0,  1    ;      #    4 =  0#
               db    -1,  0,  0,  1    ;               ##   5 = #0
               db    -2, -1,  0,  1    ; 6 = ##0#                ##
   BlockShapeY db     0,  0,  0,  1
               db     0,  1,  1,  0
               db     1,  0,  0,  0
               db     0,  0,  1,  0
               db     1,  1,  0,  0
               db     0,  0,  1,  1
               db     0,  0,  0,  0
   BlockRTable db    (7 * 4 * 2 * 3) dup (?)

   BlockColor  db    ?
   BlockType   dw    ?
   BlockX      db    ?           ; DL (EDX = dword ptr [BlockX])
   BlockY      db    ?           ; DH
   BlockR      dw    ?           ; EDX >> 16
   BlockTime   dw    ?

   ScoreTable  dw    4 dup (?)

   CellX       dw    4 dup (?)
   CellY       dw    4 dup (?)

   RandSeed    dd    ?

   Field       db    FIELD_SIZE dup (?)
   Screen      dw    (80 * 25) dup (?)

sCode       ends


end         tetris
