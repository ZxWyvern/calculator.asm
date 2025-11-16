section .data
    prompt db "Enter expression (e.g., 2 + 3) or 'q' to quit: ", 0
    prompt_len equ $ - prompt
    result_msg db "Result: ", 0
    result_msg_len equ $ - result_msg
    error_msg db "Error: Invalid input or division by zero", 10, 0
    error_len equ $ - error_msg
    newline db 10, 0

section .bss
    input_buffer resb 256
    num1 resb 256
    num2 resb 256
    result resb 512
    temp_result resb 512

section .text
global _start

_start:
main_loop:
    ; Print prompt
    mov rdi, 1
    mov rsi, prompt
    mov rdx, prompt_len
    mov rax, 1
    syscall

    ; Read input
    mov rdi, 0
    mov rsi, input_buffer
    mov rdx, 256
    mov rax, 0
    syscall
    
    ; Null terminate
    cmp rax, 0
    jle exit_program
    mov byte [input_buffer + rax - 1], 0

    ; Check if 'q' to quit
    cmp byte [input_buffer], 'q'
    je exit_program

    ; Parse input
    call parse_input
    test rax, rax
    jz invalid_input

    ; Perform calculation
    call calculate
    test rax, rax
    jz invalid_input

    ; Print result message
    mov rdi, 1
    mov rsi, result_msg
    mov rdx, result_msg_len
    mov rax, 1
    syscall

    ; Print result
    mov rsi, result
    call print_result
    
    ; Print newline
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    mov rax, 1
    syscall

    jmp main_loop

invalid_input:
    mov rdi, 1
    mov rsi, error_msg
    mov rdx, error_len
    mov rax, 1
    syscall
    jmp main_loop

exit_program:
    mov rax, 60
    xor rdi, rdi
    syscall

; Print null-terminated string
print_result:
    push rsi
    mov rdi, rsi
    call strlen
    mov rdx, rax
    pop rsi
    mov rdi, 1
    mov rax, 1
    syscall
    ret

; Parse input: num1 op num2
parse_input:
    mov rsi, input_buffer
    call skip_spaces
    mov rdi, num1
    call parse_number_string
    test rax, rax
    jz .error
    
    call skip_spaces
    mov al, byte [rsi]
    cmp al, '+'
    je .valid_op
    cmp al, '-'
    je .valid_op
    cmp al, '*'
    je .valid_op
    cmp al, '/'
    je .valid_op
    xor rax, rax
    ret
    
.valid_op:
    mov byte [temp_result], al  ; Store operator temporarily
    inc rsi
    call skip_spaces
    mov rdi, num2
    call parse_number_string
    test rax, rax
    jz .error
    mov rax, 1
    ret
    
.error:
    xor rax, rax
    ret

skip_spaces:
    cmp byte [rsi], ' '
    jne .done
    inc rsi
    jmp skip_spaces
.done:
    ret

parse_number_string:
    xor rax, rax
.loop:
    mov cl, byte [rsi]
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    mov byte [rdi], cl
    inc rdi
    inc rsi
    inc rax
    jmp .loop
.done:
    mov byte [rdi], 0
    ret

; Perform calculation
calculate:
    mov al, byte [temp_result]  ; Get operator
    cmp al, '+'
    je add_op
    cmp al, '-'
    je sub_op
    cmp al, '*'
    je mul_op
    cmp al, '/'
    je div_op
    xor rax, rax
    ret

add_op:
    mov rsi, num1
    mov rdi, num2
    mov rdx, result
    call add_strings
    mov rax, 1
    ret

sub_op:
    mov rsi, num1
    mov rdi, num2
    mov rdx, result
    call sub_strings
    mov rax, 1
    ret

mul_op:
    mov rsi, num1
    mov rdi, num2
    mov rdx, result
    call mul_strings
    mov rax, 1
    ret

div_op:
    xor rax, rax
    ret

; String length
strlen:
    push rdi
    xor rax, rax
.loop:
    cmp byte [rdi], 0
    je .done
    inc rax
    inc rdi
    jmp .loop
.done:
    pop rdi
    ret

; Add two strings representing numbers
add_strings:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Get length of num1
    push rsi
    push rdi
    push rdx
    mov rdi, rsi
    call strlen
    mov r12, rax  ; len1
    pop rdx
    pop rdi
    pop rsi
    
    ; Get length of num2
    push rsi
    push rdi
    push rdx
    mov rdi, num2
    call strlen
    mov r13, rax  ; len2
    pop rdx
    pop rdi
    pop rsi
    
    ; Point to last characters
    mov r14, rsi
    add r14, r12
    dec r14  ; r14 points to last char of num1
    
    mov r15, num2
    add r15, r13
    dec r15  ; r15 points to last char of num2
    
    ; temp_result will hold reversed result
    mov rbx, temp_result + 256
    xor r8, r8  ; carry
    
.loop:
    ; Check if both numbers exhausted
    test r12, r12
    jnz .continue
    test r13, r13
    jnz .continue
    test r8, r8
    jz .done_adding
    
.continue:
    xor rax, rax
    xor rcx, rcx
    
    ; Add digit from num1 if available
    test r12, r12
    jz .no_num1
    mov al, byte [r14]
    sub al, '0'
    dec r14
    dec r12
    
.no_num1:
    ; Add digit from num2 if available
    test r13, r13
    jz .no_num2
    mov cl, byte [r15]
    sub cl, '0'
    dec r15
    dec r13
    
.no_num2:
    ; Sum = digit1 + digit2 + carry
    add rax, rcx
    add rax, r8
    
    ; Divide by 10 to get new carry and digit
    xor rdx, rdx
    mov rcx, 10
    div rcx
    
    ; rdx = digit, rax = carry
    add dl, '0'
    mov byte [rbx], dl
    inc rbx
    mov r8, rax
    
    jmp .loop
    
.done_adding:
    ; Null terminate
    mov byte [rbx], 0
    
    ; Reverse from temp_result+256 to result
    mov rsi, temp_result + 256
    dec rbx
    mov rdi, result
    
.reverse_loop:
    cmp rbx, temp_result + 256
    jl .reverse_done
    mov al, byte [rbx]
    mov byte [rdi], al
    inc rdi
    dec rbx
    jmp .reverse_loop
    
.reverse_done:
    mov byte [rdi], 0
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Subtract strings (num1 - num2, assumes num1 >= num2)
sub_strings:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Get lengths
    push rsi
    push rdi
    push rdx
    mov rdi, rsi
    call strlen
    mov r12, rax
    pop rdx
    pop rdi
    pop rsi
    
    push rsi
    push rdi
    push rdx
    mov rdi, num2
    call strlen
    mov r13, rax
    pop rdx
    pop rdi
    pop rsi
    
    ; Point to last chars
    mov r14, rsi
    add r14, r12
    dec r14
    
    mov r15, num2
    add r15, r13
    dec r15
    
    mov rbx, temp_result + 256
    xor r8, r8  ; borrow
    
.loop:
    test r12, r12
    jz .done_sub
    
    xor rax, rax
    xor rcx, rcx
    
    mov al, byte [r14]
    sub al, '0'
    dec r14
    dec r12
    
    test r13, r13
    jz .no_num2
    mov cl, byte [r15]
    sub cl, '0'
    dec r15
    dec r13
    
.no_num2:
    sub rax, rcx
    sub rax, r8
    xor r8, r8
    
    cmp rax, 0
    jge .positive
    add rax, 10
    mov r8, 1
    
.positive:
    add al, '0'
    mov byte [rbx], al
    inc rbx
    jmp .loop
    
.done_sub:
    mov byte [rbx], 0
    
    ; Reverse
    mov rsi, temp_result + 256
    dec rbx
    mov rdi, result
    
.reverse_loop:
    cmp rbx, temp_result + 256
    jl .reverse_done
    mov al, byte [rbx]
    mov byte [rdi], al
    inc rdi
    dec rbx
    jmp .reverse_loop
    
.reverse_done:
    mov byte [rdi], 0
    
    ; Remove leading zeros
    mov rsi, result
.skip_zeros:
    cmp byte [rsi], '0'
    jne .copy_result
    cmp byte [rsi + 1], 0
    je .copy_result
    inc rsi
    jmp .skip_zeros
    
.copy_result:
    cmp rsi, result
    je .done_remove
    mov rdi, result
.copy_loop:
    mov al, byte [rsi]
    mov byte [rdi], al
    test al, al
    jz .done_remove
    inc rsi
    inc rdi
    jmp .copy_loop
    
.done_remove:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Multiply strings
mul_strings:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Initialize result to "0"
    mov byte [result], '0'
    mov byte [result + 1], 0
    
    ; Get length of num2
    push rdx
    mov rdi, num2
    call strlen
    mov r12, rax
    pop rdx
    
    test r12, r12
    jz .done
    
    ; For each digit in num2 (right to left)
    mov r13, num2
    add r13, r12
    dec r13
    xor r14, r14  ; position (power of 10)
    
.outer_loop:
    test r12, r12
    jz .done
    
    mov al, byte [r13]
    sub al, '0'
    movzx rbx, al
    
    ; Multiply num1 by this digit with shift
    push rdx
    push r12
    push r13
    push r14
    
    mov rdi, num1
    mov rsi, rbx
    mov rcx, r14
    mov rdx, temp_result
    call mul_digit_with_shift
    
    ; Add to result
    mov rsi, result
    mov rdi, temp_result
    mov rdx, temp_result + 256
    call add_strings
    
    ; Copy back to result
    mov rsi, temp_result + 256
    mov rdi, result
    call strcpy
    
    pop r14
    pop r13
    pop r12
    pop rdx
    
    inc r14
    dec r13
    dec r12
    jmp .outer_loop
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Multiply num1 by single digit with shift (zeros at end)
mul_digit_with_shift:
    push rbx
    push r12
    push r13
    push r14
    
    ; Get length of num1
    push rdi
    call strlen
    mov r12, rax
    pop rdi
    
    add rdi, r12
    dec rdi
    
    mov r13, rdx  ; result pointer (temp_result)
    mov r14, rdx  ; save start
    xor rbx, rbx  ; carry
    
    ; Add shift zeros
    mov rax, rcx
.shift_loop:
    test rax, rax
    jz .mul_loop
    mov byte [r13], '0'
    inc r13
    dec rax
    jmp .shift_loop
    
.mul_loop:
    test r12, r12
    jz .final_carry
    
    mov al, byte [rdi]
    sub al, '0'
    movzx rax, al
    mul rsi
    add rax, rbx
    
    xor rdx, rdx
    push rcx
    mov rcx, 10
    div rcx
    pop rcx
    
    add dl, '0'
    mov byte [r13], dl
    inc r13
    mov rbx, rax
    
    dec rdi
    dec r12
    jmp .mul_loop
    
.final_carry:
    test rbx, rbx
    jz .end_mul
.carry_loop:
    mov rax, rbx
    xor rdx, rdx
    push rcx
    mov rcx, 10
    div rcx
    pop rcx
    add dl, '0'
    mov byte [r13], dl
    inc r13
    mov rbx, rax
    test rbx, rbx
    jnz .carry_loop
    
.end_mul:
    mov byte [r13], 0
    
    ; Reverse result
    mov rsi, r14
    dec r13
    mov rdi, r14
    
.reverse_loop:
    cmp rsi, r13
    jge .reverse_done
    mov al, byte [rsi]
    mov bl, byte [r13]
    mov byte [rsi], bl
    mov byte [r13], al
    inc rsi
    dec r13
    jmp .reverse_loop
    
.reverse_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Copy string
strcpy:
    mov al, byte [rsi]
    mov byte [rdi], al
    test al, al
    jz .done
    inc rsi
    inc rdi
    jmp strcpy
.done:
    ret
