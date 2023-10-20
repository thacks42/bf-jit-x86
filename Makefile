ASM=nasm
LD=ld
AFLAGS=-f elf64 -F dwarf -g
ALDFLAGS=
SOURCES=bf.asm
OBJECTS=$(SOURCES:.asm=.o)
EXECUTABLE=bf.run

all: $(SOURCES) $(EXECUTABLE)
    
$(EXECUTABLE): $(OBJECTS) 
	$(LD) $(ALDFLAGS) $(OBJECTS) -o $@

%.o : %.asm
	$(ASM) $(AFLAGS) $< -o $@

.PHONY: clean
clean:
	rm -f $(OBJECTS)
	rm -f $(EXECUTABLE)
