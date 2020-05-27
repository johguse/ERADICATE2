#ifndef HPP_HELP
#define HPP_HELP

#include <string>

const std::string g_strHelp = R"(
usage: ./ERADICATE2 [OPTIONS]

  Input:
    -A, --address           Target address
    -I, --init-code         Init code
    -i, --init-code-file    Read init code from this file

    The init code should be expressed as a hexadecimal string having the
    prefix 0x both when expressed on the command line with -I and in the
    file pointed to by -i if used. Any whitespace will be trimmed. If no
    init code is specified it defaults to an empty string.

  Basic modes:
    --benchmark             Run without any scoring, a benchmark.
    --zeros                 Score on zeros anywhere in hash.
    --zero-bytes            Score on zero bytes anywhere in hash.
    --letters               Score on letters anywhere in hash.
    --numbers               Score on numbers anywhere in hash.
    --mirror                Score on mirroring from center.
    --leading-doubles       Score on hashes leading with hexadecimal pairs

  Modes with arguments:
    --leading <single hex>  Score on hashes leading with given hex character.
    --matching <hex string> Score on hashes matching given hex string.

  Advanced modes:
    --leading-range         Scores on hashes leading with characters within
                            given range.
    --range                 Scores on hashes having characters within given
                            range anywhere.

  Range:
    -m, --min <0-15>        Set range minimum (inclusive), 0 is '0' 15 is 'f'.
    -M, --max <0-15>        Set range maximum (inclusive), 0 is '0' 15 is 'f'.

  Device control:
    -s, --skip <index>      Skip device given by index.

  Tweaking:
    -w, --work <size>       Set OpenCL local work size. [default = 64]
    -W, --work-max <size>   Set OpenCL maximum work size. [default = -i * -I]
    -S, --size <size>       Set number of salts tried per loop.
                            [default = 16777216]

  Examples:
    ./ERADICATE2 -A 0x00000000000000000000000000000000deadbeef -I 0x00 --leading 0
    ./ERADICATE2 -A 0x00000000000000000000000000000000deadbeef -I 0x00 --zeros

  About:
    ERADICATE2 is a vanity address generator for CREATE2 addresses that
	utilizes computing power from GPUs using OpenCL.

    Author: Johan Gustafsson <johan@johgu.se>
    Beer donations: 0x000dead000ae1c8e8ac27103e4ff65f42a4e9203
)";

#endif /* HPP_HELP */
