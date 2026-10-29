section .data
    msg1 db "Ingrese el primer digito (0-9): ", 0
    len1 equ $ - msg1
    msg2 db "Ingrese el segundo digito (0-9): ", 0
    len2 equ $ - msg2
    msg_res db "El resultado es: ", 0
    len_res equ $ - msg_res
    
    msg_error db "Error: Debe ingresar un solo digito entero del 0 al 9.", 10, 0
    len_error equ $ - msg_error

section .bss
    num1 resb 2      ; Guardar carácter + Enter
    num2 resb 2      ; Guardar carácter + Enter
    res resb 3       ; Guardar hasta 2 dígitos + Enter
    trash resb 1     ; Búfer auxiliar para descartar caracteres sobrantes

section .text
    global _start

_start:
; --- 1. Pedir y leer el primer dato ---
pedir_num1:
    mov eax, 4       ; sys_write
    mov ebx, 1       ; stdout
    mov ecx, msg1
    mov edx, len1
    int 0x80

    mov eax, 3       ; sys_read
    mov ebx, 0       ; stdin
    mov ecx, num1
    mov edx, 2       ; Pedir 2 bytes
    int 0x80

    ; --- CONTROL DE ERRORES / EOF DE SYS_READ ---
    cmp eax, 0
    jle salir_error  ; Si EAX <= 0 (EOF o error de lectura), salir limpiamente

    ; Si leyó solo 1 byte, comprobar si fue un Enter o un dígito suelto
    cmp eax, 1
    je comprobar_un_byte_num1

    ; Si leyó 2 bytes, verificar que el segundo byte sea Enter (\n = 10 o \r = 13)
    mov al, [num1 + 1]
    cmp al, 10
    je validar_primer_caracter_num1
    cmp al, 13
    je validar_primer_caracter_num1

    ; Si el segundo byte no fue Enter, la persona ingresó caracteres de más
    jmp limpiar_num1

comprobar_un_byte_num1:
    mov al, [num1]
    cmp al, 10
    je pedir_num1    ; Si solo presionó Enter, pedir de nuevo
    cmp al, 13
    je pedir_num1
    jmp validar_primer_caracter_num1

validar_primer_caracter_num1:
    mov al, [num1]
    call validar_digito
    cmp edx, 1       ; Si EDX = 1, es un carácter no numérico
    je pedir_num1
    jmp pedir_num2

limpiar_num1:
    call limpiar_bufer
    call mostrar_error
    jmp pedir_num1

; --- 2. Pedir y leer el segundo dato ---
pedir_num2:
    mov eax, 4       ; sys_write
    mov ebx, 1       ; stdout
    mov ecx, msg2
    mov edx, len2
    int 0x80

    mov eax, 3       ; sys_read
    mov ebx, 0       ; stdin
    mov ecx, num2
    mov edx, 2       ; Pedir 2 bytes
    int 0x80

    ; --- CONTROL DE ERRORES / EOF DE SYS_READ ---
    cmp eax, 0
    jle salir_error

    cmp eax, 1
    je comprobar_un_byte_num2

    mov al, [num2 + 1]
    cmp al, 10
    je validar_primer_caracter_num2
    cmp al, 13
    je validar_primer_caracter_num2

    jmp limpiar_num2

comprobar_un_byte_num2:
    mov al, [num2]
    cmp al, 10
    je pedir_num2
    cmp al, 13
    je pedir_num2
    jmp validar_primer_caracter_num2

validar_primer_caracter_num2:
    mov al, [num2]
    call validar_digito
    cmp edx, 1
    je pedir_num2
    jmp calcular

limpiar_num2:
    call limpiar_bufer
    call mostrar_error
    jmp pedir_num2

; --- 3. Operación Aritmética ---
calcular:
    mov eax, 4       ; sys_write
    mov ebx, 1       ; stdout
    mov ecx, msg_res
    mov edx, len_res
    int 0x80

    mov al, [num1]
    sub al, '0'

    mov bl, [num2]
    sub bl, '0'

    add al, bl       ; Suma

; --- 4. Formatear y mostrar resultado ---
    cmp al, 9
    jle un_digito

dos_digitos:
    mov ah, 0        ; Limpiar AH para dividir AX / CL de forma segura
    mov cl, 10
    div cl           ; AL = decenas, AH = unidades

    add al, '0'
    add ah, '0'

    mov [res], al
    mov [res+1], ah
    mov byte [res+2], 10

    mov eax, 4       ; sys_write
    mov ebx, 1       ; stdout
    mov ecx, res
    mov edx, 3
    int 0x80
    jmp salir

un_digito:
    add al, '0'
    mov [res], al
    mov byte [res+1], 10

    mov eax, 4       ; sys_write
    mov ebx, 1       ; stdout
    mov ecx, res
    mov edx, 2
    int 0x80

salir:
    mov eax, 1       ; sys_exit
    mov ebx, 0       ; Éxito (0)
    int 0x80

salir_error:
    mov eax, 1       ; sys_exit
    mov ebx, 1       ; Código de salida con error (1)
    int 0x80


; =======================================================
; --- SUBRUTINAS ---
; =======================================================

validar_digito:
    cmp al, '0'
    jl digito_invalido
    cmp al, '9'
    jg digito_invalido

    mov edx, 0       ; Válido
    ret

digito_invalido:
    call mostrar_error
    mov edx, 1       ; Inválido
    ret

mostrar_error:
    push eax
    push ebx
    push ecx
    push edx

    mov eax, 4       ; sys_write
    mov ebx, 1       ; stdout
    mov ecx, msg_error
    mov edx, len_error
    int 0x80

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Subrutina con control anti-bloqueo para EOF / Error
limpiar_bufer:
    push eax
    push ebx
    push ecx
    push edx

bucles_limpieza:
    mov eax, 3       ; sys_read
    mov ebx, 0       ; stdin
    mov ecx, trash
    mov edx, 1
    int 0x80

    ; Si sys_read devuelve <= 0 (EOF o Error), salir inmediatamente del bucle
    cmp eax, 0
    jle fin_limpieza

    ; Si lee Enter (\n=10) o retorno de carro (\r=13), terminó la línea
    cmp byte [trash], 10
    je fin_limpieza
    cmp byte [trash], 13
    je fin_limpieza

    jmp bucles_limpieza

fin_limpieza:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
    
