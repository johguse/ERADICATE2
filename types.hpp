#ifndef HPP_TYPES
#define HPP_TYPES

/* The structs declared in this file should have size/alignment hints
 * to ensure that their representation is identical to that in OpenCL.
 */
#if defined(__APPLE__) || defined(__MACOSX)
#include <OpenCL/cl.h>
#else
#include <CL/cl.h>
#endif

enum class ModeFunction {
	Benchmark, ZeroBytes, Matching, Leading, Range, Mirror, Doubles, LeadingRange
};

typedef struct {
	ModeFunction function;
	cl_uchar data1[20];
	cl_uchar data2[20];
} mode;

#pragma pack(push, 1)
typedef struct {
	cl_uchar salt[32];
	cl_uchar hash[20];
	cl_uint found;
} result;
#pragma pack(pop)

typedef union {
	cl_uchar b[200];
	cl_ulong q[25];
	cl_uint d[50];
} ethhash;

#endif /* HPP_TYPES */