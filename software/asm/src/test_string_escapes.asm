; Test program demonstrating string escape sequences
; This program showcases the new string literal escape sequence features

        ORG $F000

MAIN:
        ; Basic strings with escape sequences
        WELCOME_MSG:  DB "CPU Boot v1.0\n", 0
        PROMPT_MSG:   DB "Press \"ENTER\" to continue...\n", 0
        
        ; Demonstration of various escape sequences
        TAB_DEMO:     DB "Col1\tCol2\tCol3\n", 0
        CR_LF_DEMO:   DB "Line1\r\nLine2\r\n", 0
        NULL_DEMO:    DB "String\0with\0nulls", 0
        BACKSLASH:    DB "Path\\to\\file.txt\n", 0
        
        ; Hex escape sequences
        BELL_MSG:     DB "Alert: \x07\n", 0          ; Bell character
        ASCII_DEMO:   DB "\x41\x42\x43\n", 0        ; "ABC\n"
        CONTROL_CHARS:DB "\x1B[32mGreen Text\x1B[0m\n", 0  ; ANSI escape codes
        
        ; Mixed escape sequences in one string
        COMPLEX_MSG:  DB "Boot complete!\nPress \"ESC\" to exit\x0D\x0A", 0
        
        ; Show that regular strings still work
        NORMAL_MSG:   DB "This is a normal string", 0
        
        HLT