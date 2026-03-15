bits 64
default rel

STACK_SIZE  equ 4096

SA_RESTORER equ 0x4000000

AF_INET     equ 2
SOCK_STREAM equ 1

SHUT_RDWR   equ 3
            
CLONE_FLAG  equ 0x00010f00 ; CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD

O_RDONLY    equ 0
            
MMAP_RW     equ 0x3
MMAP_STACK  equ 0x122 ; MAP_PRIVATE | MAP_ANONYMOUS | MAP_GROWSDOWN

SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_OPEN    equ 2
SYS_CLOSE   equ 3
SYS_FSTAT   equ 5
SYS_MMAP    equ 9
SYS_MUNMAP  equ 11
SYS_SIGACT  equ 13
SYS_SIGRET  equ 15
SYS_SENDF   equ 40
SYS_SOCKET  equ 41
SYS_ACCEPT  equ 43
SYS_SHUT    equ 48
SYS_BIND    equ 49
SYS_LISTEN  equ 50
SYS_CLONE   equ 56
SYS_EXIT    equ 60
SYS_DENTS   equ 78

S_IFMT      equ 0xF000
S_IFREG     equ 0x8000
S_IFDIR     equ 0x4000

DT_DIR      equ 4

section .text
global _start

restore_rt:
	mov rax, SYS_SIGRET
	syscall

interrupt:
	mov rax, SYS_SHUT
	mov edi, [sockfd]
	mov rsi, SHUT_RDWR
	syscall

	mov rax, SYS_CLOSE
	mov edi, [sockfd]
	syscall

	mov rax, SYS_EXIT
	mov rdi, 0
	syscall

thread:
	push rbp
	mov rbp, rsp

	mov r12, rdi
	mov r13, rsi

	mov rax, SYS_MMAP
	xor rdi, rdi
	mov rsi, STACK_SIZE
	mov rdx, MMAP_RW
	mov r10, MMAP_STACK
	xor r8, r8
	xor r9, r9
	syscall

	mov r14, rax
	lea rsi, [rax + STACK_SIZE]

	mov rax, SYS_CLONE
	mov rdi, CLONE_FLAG
	xor rdx, rdx
	xor r10, r10
	xor r8, r8
	syscall

	cmp rax, 0
	jne _t0

	push r14
	mov rdi, r13
	call r12

	mov rax, SYS_MUNMAP
	pop rdi
	mov rsi, STACK_SIZE
	syscall

	mov rax, SYS_EXIT
	xor rdi, rdi
	syscall

_t0:
	mov rsp, rbp
	pop rbp
	ret

write_cstr:
	mov rdx, rsi

	jmp .c0

.a0:
	inc rdx

.c0:
	cmp byte [rdx], 0
	jne .a0

	sub rdx, rsi
	mov rax, SYS_WRITE
	syscall
	ret

send_dir:
	push rbp
	mov rbp, rsp
	sub rsp, 2068

	mov [rbp - 4], edi ; sock
	mov [rbp - 8], esi ; dir

	mov edi, [rbp - 4]
	mov rsi, dir_head
	call write_cstr

.a0:
	mov rax, SYS_DENTS
	mov edi, [rbp - 8]
	mov rsi, rsp
	mov rdx, 2048
	syscall

	cmp rax, 0
	jle .b0

	mov [rbp - 12], eax
	mov [rbp - 20], rsp

.a1:
	mov edi, [rbp - 4]
	mov rsi, dir_a
	call write_cstr

	mov edi, [rbp - 4]
	mov rsi, [rbp - 20]
	add rsi, 18
	call write_cstr

	mov rsi, [rbp - 20]
	movzx rax, word [rsi + 16] ; reclen
	add rsi, rax
	mov al, [rsi - 1] ; d_type

	mov rsi, dir_b

	cmp al, DT_DIR
	je .b1

	inc rsi
.b1:
	mov edi, [rbp - 4]
	call write_cstr

	mov edi, [rbp - 4]
	mov rsi, [rbp - 20]
	add rsi, 18
	call write_cstr

	mov edi, [rbp - 4]
	mov rsi, dir_c
	call write_cstr

	mov rsi, [rbp - 20]
	movzx rax, word [rsi + 16]
	add [rbp - 20], rax

	sub dword [rbp - 12], eax
	cmp dword [rbp - 12], 0
	jne .a1
	jmp .a0

.b0:
	mov rsp, rbp
	pop rbp
	ret

handler:
	push rbp
	mov rbp, rsp
	sub rsp, 2200

	mov [rbp - 4], edi

	mov rax, SYS_READ
	mov edi, [rbp - 4]
	mov rsi, rsp
	mov rdx, 2048
	syscall

	add rax, rsp
	mov rdi, rsp

	jmp .c0

.a0:
	inc rdi

.c0:
	cmp rdi, rax
	jge .b0
	cmp byte [rdi], 32
	jne .a0

	add rdi, 2

	mov rsi, rdi

	jmp .c1

.a1:
	inc rsi

.c1:
	cmp rsi, rax
	jge .b0
	cmp byte [rsi], 32
	jne .a1

	mov byte [rsi], 0

	cmp rdi, rsi

	jne .b1
	mov rdi, index
.b1:

	mov rax, SYS_OPEN
	mov rsi, O_RDONLY
	xor rdx, rdx
	syscall

	cmp eax, 0
	jle .b2

	mov [rbp - 8], eax

	mov rax, SYS_FSTAT
	mov edi, [rbp - 8]
	lea rsi, [rbp - 152]
	syscall

	cmp rax, 0
	jne .b3

	mov eax, [rbp - 128] ; +24 (st_mode)
	and eax, S_IFMT
	cmp eax, S_IFREG

	je .b4

	cmp eax, S_IFDIR
	jne .b3

	mov edi, [rbp - 4]
	mov esi, [rbp - 8]
	call send_dir
	jmp .b5

.b4:
	mov edi, [rbp - 4]
	mov rsi, http_resp
	call write_cstr

	mov rax, SYS_SENDF
	mov edi, [rbp - 4]
	mov esi, [rbp - 8]
	xor rdx, rdx
	mov r10, [rbp - 104]
	syscall

.b5:
	mov rax, SYS_CLOSE
	mov edi, [rbp - 8]
	syscall

	jmp .b0

.b3:
	mov rax, SYS_CLOSE
	mov edi, [rbp - 8]
	syscall
.b2:
	mov edi, [rbp - 4]
	mov rsi, http_404
	call write_cstr

.b0:
	mov rax, SYS_CLOSE
	mov edi, [rbp - 4]
	syscall

	mov rsp, rbp
	pop rbp
	ret

_start:
	mov rax, SYS_SIGACT
	mov rdi, 2 ; interrupt
	mov rsi, sigaction
	xor rdx, rdx
	mov r10, 8
	syscall

	mov rax, SYS_SOCKET
	mov rdi, AF_INET
	mov rsi, SOCK_STREAM
	xor rdx, rdx
	syscall

	cmp rax, 0
	jl exit_err

	mov [sockfd], eax

	mov rax, SYS_BIND
	mov edi, [sockfd]
	mov rsi, sockaddr
	mov rdx, sockaddr_size
	syscall

	cmp rax, 0
	jl exit_err

	mov rax, SYS_LISTEN
	mov edi, [sockfd]
	mov rsi, 10
	syscall

	cmp rax, 0
	jl exit_err

.s0:
	mov rax, SYS_ACCEPT
	mov edi, [sockfd]
	xor rsi, rsi
	xor rdx, rdx
	syscall

	cmp rax, 0
	jl exit

	mov rdi, handler
	mov rsi, rax
	call thread

	jmp .s0

exit_err:
	mov rdi, 1
	mov rsi, err
	call write_cstr

	mov rdi, 1
exit:
	mov rax, SYS_EXIT
	syscall

section .data
	err db `Failed to create server.\n`, 0
	http_resp db `HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n`, 0
	http_404 db `HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n<h1>404 Not Found</h1>\r\n\r\n`, 0
	index db ".", 0
	dir_head db `HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/html\r\n\r\n<h1>directory listing</h1>\n`, 0
	dir_a db '<a href="', 0
	dir_b db '/">', 0
	dir_c db `</a></br>\n`, 0

sigaction:
	sa_handler dq interrupt
	sa_flags   dq SA_RESTORER
	sa_restore dq restore_rt
	sa_mask    dq 0

sockaddr:
	sin_family dw 2
	sin_port   dw 0x901f ; 8080
	sin_addr   dd 0      ; all
	sin_pad    dq 0
	sockaddr_size equ $ - sockaddr

section .bss
	sockfd resd 1

