.model small
.stack 100h
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

    ; Llamada a la funci?n para dibujar la ventana
    call DrawWindow

    ; Esperar una tecla antes de salir
    mov ah, 0
    int 16h

    ; Restaurar el modo de texto
    mov ax, 3
    int 10h

    ; Salir del programa
    mov ax, 4C00h
    int 21h
main endp

DrawWindow proc
    ; Dibujar el contorno de la ventana
    mov cx, 0
    mov dx, 0
    mov bh, 0
    mov ah, 0Ch ; Funci?n para dibujar p?xeles
    mov al, 15   ; Color blanco
    mov cx, SCREEN_WIDTH
    mov dx, SCREEN_HEIGHT
    int 10h

    ret
DrawWindow endp

end main

