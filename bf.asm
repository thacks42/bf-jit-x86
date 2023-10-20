global _start

section .bss
align 4096
bf_mem: resb 32768
bf_parse_buffer: resb 1024
print_mem: resb 128
read_mem: resb 1


section .rodata

usage_msg: db "usage: ./bf file.b", 0xa
usage_msg_len: equ $ - usage_msg

no_input_msg: db "no input!", 0xa
no_input_msg_len: equ $ - no_input_msg

bad_input_msg: db "bad input!", 0xa
bad_input_msg_len: equ $ - bad_input_msg

brace_mismatch_msg: db "brace mismatch!", 0xa
brace_mismatch_msg_len: equ $ - brace_mismatch_msg

section .text

_start:
    jmp init_bf_machine
    
init_bf_machine:
    pop rax ;argc
    cmp rax, 2
    jne bad_number_of_args
    
    ;make bf_code memory executable
    mov rax, 10 ;mprotect
    mov rdi, bf_code ;buffer
    mov rsi, 32768 ;size
    mov rdx, 7 ;read | write | exec
    syscall
    
    pop rax ;argv[0] (program name, can be ignored)
    pop rdi ;argv[1] (filename)
    mov eax, 2
    mov esi, 0
    mov edx, 0
    syscall
    
    push rax ;file descriptor
    mov rdi, rax
    
    ;parse bf code 
    xor eax, eax
    mov rsi, bf_parse_buffer
    mov edx, 1024 ;todo: handle more than 1024 bytes, also make no input valid input
    syscall
    
    
    test rax, rax ;check for empty input buffer
    jz no_input
    
    mov rdi, bf_code
    lea rsi, [bf_parse_buffer - 1] ;start at -1 because we pre-increment in the parse loop
    lea rax, [bf_parse_buffer + rax] ;end of input pointer
    
    push rbp
    mov rbp, rsp
    
    parse_loop:
        xor edx, edx
        
        inc rsi
        cmp rsi, rax
        je parse_done
        
        mov dl, byte [rsi]
        cmp dl, '>'
            je parse_inc_ptr
        cmp dl, '<'
            je parse_dec_ptr
        cmp dl, '+'
            je parse_inc_mem
        cmp dl, '-'
            je parse_dec_mem
        cmp dl, '.'
            je parse_print
        cmp dl, ','
            je parse_read
        cmp dl, '['
            je parse_open_brace
        cmp dl, ']'
            je parse_close_brace
        ;cmp dl, 0xa
        ;    je parse_loop
        ;jmp bad_input
        jmp parse_loop
    
    parse_inc_ptr:
        mov word [rdi], 0xff48 ;inc rsi
        mov byte [rdi+2], 0xc6
        add rdi, 3
        jmp parse_loop
    
    parse_dec_ptr:
        mov word [rdi], 0xff48 ;dec rsi
        mov byte [rdi+2], 0xce
        add rdi, 3
        jmp parse_loop
    
    parse_inc_mem:
        mov word [rdi], 0x06fe ;inc byte [rsi]
        add rdi, 2
        jmp parse_loop
    
    parse_dec_mem:
        mov word [rdi], 0x0efe ;dec byte [rsi]
        add rdi, 2
        jmp parse_loop
    
    parse_print:
        mov rcx, print
        sub rcx, rdi ; offset = addr(print) - addr(current) - sizeof(instruction)
        sub rcx, 5   ; sizeof(instruction) == 5
        mov byte [rdi], 0xe8
        mov dword [rdi + 1], ecx
        add rdi, 5
        jmp parse_loop
    
    parse_read:
        mov rcx, read
        sub rcx, rdi ; offset = addr(print) - addr(current) - sizeof(instruction)
        sub rcx, 5   ; sizeof(instruction) == 5
        mov byte [rdi], 0xe8
        mov dword [rdi + 1], ecx
        add rdi, 5
        jmp parse_loop
        
    
    parse_open_brace:
        mov byte [rdi], 0x80
        mov dword [rdi+1], 0x840f003e
        mov dword [rdi+5], 0xffffffff
        add rdi, 5
        push rdi
        add rdi, 4
        jmp parse_loop
    
    
    parse_close_brace:
        test rbp, rsp
            je brace_mismatch
        
        mov byte [rdi], 0x80
        mov dword [rdi+1], 0x850f003e
        pop rcx ; matching brace address
        mov rdx, rcx
        sub rcx, rdi
        sub rcx, 5
        mov [rdi+5], ecx
        neg rcx
        mov dword[rdx], ecx
        add rdi, 9
        jmp parse_loop
    
    
    parse_done:
    cmp rbp, rsp
        jne brace_mismatch
    pop rbp
    
    
    mov rcx, wrapup
    sub rcx, rdi
    sub rcx, 5
    mov byte [rdi], 0xe9 ; jmp
    mov dword [rdi + 1], ecx
    
    mov rsi, bf_mem
    mov rdi, 0
    jmp bf_code
    
    
    no_input:
        mov eax, 1
        mov edi, 1
        mov rsi, no_input_msg
        mov rdx, no_input_msg_len
        syscall
        jmp exit
        
        
    bad_input:
        mov eax, 1
        mov edi, 1
        mov rsi, bad_input_msg
        mov rdx, bad_input_msg_len
        syscall
        jmp exit
    
    brace_mismatch:
        mov eax, 1
        mov edi, 1
        mov rsi, brace_mismatch_msg
        mov rdx, brace_mismatch_msg_len
        syscall
        jmp exit
    
    bad_number_of_args:
        mov eax, 1
        mov edi, 1
        mov rsi, usage_msg
        mov rdx, usage_msg_len
        syscall
        jmp exit
    
    wrapup:
        test edi, edi
        jz exit
        mov eax, 1
        mov edx, edi
        mov edi, 1
        mov rsi, print_mem
        syscall
        jmp exit
        
    exit:
        mov eax, 60
        mov edi, 0
        syscall
    
    
align 8
print:
    
    mov al, [rsi]
    ;add al, 48
    mov [print_mem + rdi], al
    inc rdi
    cmp rdi, 128
    jb dont_print ;todo: print remaining buffer at end (should be done)
    mov rdi, 0
    
    push rsi
    push rdi
    mov eax, 1
    mov edi, 1
    mov rsi, print_mem
    mov edx, 128
    syscall
    pop rdi
    pop rsi
    
    dont_print:
    ret

read:

    push rsi
    push rdi
    xor eax, eax
    mov edi, 0
    mov rsi, read_mem
    mov edx, 1
    syscall
    
    test eax, eax
    jnz input_good
    mov byte [read_mem], 0
    
    input_good:
    mov al, [read_mem]
    ;sub al, 48
    pop rdi
    pop rsi
    mov [rsi], al
    ret

;bf_code: db 0
align 4096
bf_code: times 32768 db 0

