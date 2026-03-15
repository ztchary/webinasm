; ignore this one, just to test out socket syscalls
bits 64

section .text
global _start
_start:
	mov rbp, rsp
	sub rsp, 8

	mov rax, 41
	mov rdi, 2
	mov rsi, 1
	mov rdx, 0
	syscall

	mov [rbp - 8], rax

	mov rax, 42
	mov rdi, [rbp - 8]
	mov rsi, sockaddr
	mov rdx, 16
	syscall

	mov rax, 1
	mov rdi, [rbp - 8]
	mov rsi, request
	mov rdx, request_len
	syscall

	mov rax, 12
	xor rdi, rdi
	syscall

	mov [rbp - 16], rax

	mov rax, 12
	mov rdi, [rbp - 16]
	add rdi, 4096
	syscall

	mov rax, 0
	mov rdi, [rbp - 8]
	mov rsi, [rbp - 16]
	mov rdx, 4096
	syscall

	mov rax, 1
	mov rdi, 1
	mov rsi, [rbp - 16]
	mov rdx, 4096
	syscall

	mov rax, 3
	mov rdi, [rbp - 8]
	syscall

	mov rax, 60
	mov rdi, 0
	syscall

section .data
	request db "GET / HTTP/1.1", 13, 10
	        db "Host: ifconfig.me", 13, 10
			db "User-Agent: curl/0.0.0", 13, 10, 13, 10
	request_len equ $ - request

sockaddr:
	sin_family dw 2
	sin_port   dw 0x5000 
	sin_addr   dd 0x916fa022 ; 34.160.111.145
	sin_pad    dq 0

