# PGU_Exercises

Solutions to the exercises from the book Programming from ground up by Jonathan Bartlett.
Book: https://savannah.nongnu.org/projects/pgubook/

## Assembling and Linking

Assuming x86_64 machine:
    as -W --32 -g toupper.libcf.s -o toupper.libcf.o
    ld -m elf_i386 -dynamic-linker /usr/lib32/ld-linux.so.2 -o toupper.libcf toupper.libcf.o --library=c -L=/usr/lib32    

