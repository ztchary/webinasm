server: server.asm
	nasm -felf64 server.asm -o server.o
	ld server.o -o server
	rm server.o
