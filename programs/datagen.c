/*
    datagen.c - compressible data generator test tool
    Copyright (C) Yann Collet 2012-2016

    GPL v2 License

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

    You can contact the author at :
    - zstd homepage : http://www.zstd.net/
    - source repository : https://github.com/Cyan4973/zstd
*/

/*-************************************
*  Includes
**************************************/
#include <stdlib.h>    /* malloc */
#include <stdio.h>     /* FILE, fwrite */
#include <string.h>    /* memcpy */
#include "mem.h"


/*-************************************
*  OS-specific Includes
**************************************/
#if defined(MSDOS) || defined(OS2) || defined(WIN32) || defined(_WIN32) || defined(__CYGWIN__)
#  include <fcntl.h>   /* _O_BINARY */
#  include <io.h>      /* _setmode, _isatty */
#  define SET_BINARY_MODE(file) {int unused = _setmode(_fileno(file), _O_BINARY); (void)unused; }
#else
#  define SET_BINARY_MODE(file)
#endif


/*-************************************
*  Macros
**************************************/
#define KB *(1 <<10)


/*-************************************
*  Local types
**************************************/
#define LTLOG 13
#define LTSIZE (1<<LTLOG)
#define LTMASK (LTSIZE-1)
typedef BYTE litDistribTable[LTSIZE];


/*-*******************************************************
*  Local Functions
*********************************************************/
#define RDG_rotl32(x,r) ((x << r) | (x >> (32 - r)))
static unsigned int RDG_rand(U32* src)
{
    static const U32 prime1 = 2654435761U;
    static const U32 prime2 = 2246822519U;
    U32 rand32 = *src;
    rand32 *= prime1;
    rand32 ^= prime2;
    rand32  = RDG_rotl32(rand32, 13);
    *src = rand32;
    return rand32;
}


static void RDG_fillLiteralDistrib(litDistribTable lt, double ld)
{
    U32 i = 0;
    BYTE character = (ld<=0.0) ? 0 : '0';
    BYTE const firstChar = (ld<=0.0) ? 0 : '(';
    BYTE const lastChar  = (ld<=0.0) ?255: '}';

    while (i<LTSIZE) {
        U32 weight = (U32)((double)(LTSIZE - i) * ld) + 1;
        U32 end;
        if (weight + i > LTSIZE) weight = LTSIZE-i;
        end = i + weight;
        while (i < end) lt[i++] = character;
        character++;
        if (character > lastChar) character = firstChar;
    }
}


static BYTE RDG_genChar(U32* seed, const litDistribTable lt)
{
    U32 const id = RDG_rand(seed) & LTMASK;
    return (lt[id]);
}


#define RDG_RAND15BITS  ((RDG_rand(seed) >> 3) & 0x7FFF)
#define RDG_RANDLENGTH  ( ((RDG_rand(seed) >> 7) & 7) ? (RDG_rand(seed) & 15) : (RDG_rand(seed) & 511) + 15)
void RDG_genBlock(void* buffer, size_t buffSize, size_t prefixSize, double matchProba, litDistribTable lt, unsigned* seedPtr)
{
    BYTE* buffPtr = (BYTE*)buffer;
    const U32 matchProba32 = (U32)(32768 * matchProba);
    size_t pos = prefixSize;
    U32* seed = seedPtr;
    U32 prevOffset = 1;

    /* special case : sparse content */
    while (matchProba >= 1.0) {
        size_t size0 = RDG_rand(seed) & 3;
        size0  = (size_t)1 << (16 + size0 * 2);
        size0 += RDG_rand(seed) & (size0-1);   /* because size0 is power of 2*/
        if (buffSize < pos + size0) {
            memset(buffPtr+pos, 0, buffSize-pos);
            return;
        }
        memset(buffPtr+pos, 0, size0);
        pos += size0;
        buffPtr[pos-1] = RDG_genChar(seed, lt);
        continue;
    }

    /* init */
    if (pos==0) buffPtr[0] = RDG_genChar(seed, lt), pos=1;

    /* Generate compressible data */
    while (pos < buffSize) {
        /* Select : Literal (char) or Match (within 32K) */
        if (RDG_RAND15BITS < matchProba32) {
            /* Copy (within 32K) */
            size_t match;
            size_t d;
            size_t const length = RDG_RANDLENGTH + 4;
            U32 offset = RDG_RAND15BITS + 1;
            U32 repeatOffset = (RDG_rand(seed) & 15) == 2;
            if (repeatOffset) offset = prevOffset;
            if (offset > pos) offset = (U32)pos;
            prevOffset = offset;
            match = pos - offset;
            d = pos + length;
            if (d > buffSize) d = buffSize;
            while (pos < d) buffPtr[pos++] = buffPtr[match++];   /* correctly manages overlaps */
        } else {
            /* Literal (noise) */
            size_t const length = RDG_RANDLENGTH;
            size_t d = pos + length;
            if (d > buffSize) d = buffSize;
            while (pos < d) buffPtr[pos++] = RDG_genChar(seed, lt);
    }   }
}


void RDG_genBuffer(void* buffer, size_t size, double matchProba, double litProba, unsigned seed)
{
    litDistribTable lt;
    if (litProba==0.0) litProba = matchProba / 4.5;
    RDG_fillLiteralDistrib(lt, litProba);
    RDG_genBlock(buffer, size, 0, matchProba, lt, &seed);
}


#define RDG_DICTSIZE  (32 KB)
#define RDG_BLOCKSIZE (128 KB)
#define MIN(a,b)  ( (a) < (b) ? (a) : (b) )
void RDG_genStdout(unsigned long long size, double matchProba, double litProba, unsigned seed)
{
    BYTE* buff = (BYTE*)malloc(RDG_DICTSIZE + RDG_BLOCKSIZE);
    U64 total = 0;
    litDistribTable ldt;

    /* init */
    if (buff==NULL) { fprintf(stdout, "not enough memory\n"); exit(1); }
    if (litProba<=0.0) litProba = matchProba / 4.5;
    RDG_fillLiteralDistrib(ldt, litProba);
    SET_BINARY_MODE(stdout);

    /* Generate initial dict */
    RDG_genBlock(buff, RDG_DICTSIZE, 0, matchProba, ldt, &seed);

    /* Generate compressible data */
    while (total < size) {
        size_t const genBlockSize = (size_t) (MIN (RDG_BLOCKSIZE, size-total));
        RDG_genBlock(buff, RDG_DICTSIZE+RDG_BLOCKSIZE, RDG_DICTSIZE, matchProba, ldt, &seed);
        total += genBlockSize;
        { size_t const unused = fwrite(buff, 1, genBlockSize, stdout); (void)unused; }
        /* update dict */
        memcpy(buff, buff + RDG_BLOCKSIZE, RDG_DICTSIZE);
    }

    /* cleanup */
    free(buff);
}
