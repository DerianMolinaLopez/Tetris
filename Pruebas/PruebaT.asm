.model small
.stack 100h
PINTAR MACRO COLOR
   push AX
   push BX
   push CX
   push DX
   MOV AL,COLOR
   MOV AH,0CH
   INT 10H
   POP DX
   POP CS
   POP BX
   POP DX
   endm
   
CUADRADO MACRO L,X,Y,COLOR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    MOV AX,X
    MOV BX,Y
    
    ADD AX,L;LIMITE HORIZONTAL
    ADD BX,L;LIMITE VERTICAL
    
    MOV CX,X
    MOV DX Y
    
S1:    PINTAR COLOR
    INC DX
    CMP DX,BX
    JE S
    JMP S1
S: MOV DX,Y 
   INC CX
   PINTAR COLOR
   CMP CX,AX
   JE FIN
   JMP S1
FIN:
   POP DX
   POP CX
   POP
   BX
   POz

 
    
    POP DX
    POP CX
    POP BX
    POP AX
ENDM
    
    
.data
    ; Constantes para el modo gr?fico VGA
    SCREEN_WIDTH equ 320
    SCREEN_HEIGHT equ 200
    SCREEN_SEGMENT equ 0A000h

.code
main proc
    mov ax, @data
    mov ds, ax

    ; Configuraci?n del modo gr?fico VGA
    mov ax, 13h
    int 10h

    ; Calcular las coordenadas del cuadrado
    mov cx, SCREEN_WIDTH / 2 - 500 ; 200 es la mitad del ancho del cuadrado
    mov dx, SCREEN_HEIGHT - 1000 ; 400 es la altura del cuadrado

    ; Dibujar el cuadrado rojo
    mov ax, SCREEN_SEGMENT
    mov es, ax
    mov di, cx ; Coordenada x
    shl di, 1 ; Multiplicar por 2 para obtener el desplazamiento en bytes
    add di, dx ; Sumar la coordenada y
    shl di, 8 ; Desplazar 8 bits para obtener el desplazamiento final
    mov cx, 400 ; Ancho del cuadrado
    mov dx, 400 ; Altura del cuadrado
    mov bh, 0 ; P?gina de la pantalla
    mov ah, 0Ch ; Funci?n para dibujar p?xeles
    mov al, 4 ; Color rojo
    int 10h

    ; Esperar una tecla antes de salir
    mov ah, 0
    int 16h

    ; Restaurar el modo de texto
    mov ax, 3
    int 10h

    ; Salir del programa
    mov ah, 4Ch
    int 21h
main endp
end main

