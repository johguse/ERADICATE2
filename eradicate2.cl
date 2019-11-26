enum ModeFunction {
	Benchmark, Matching, Leading, Range, Mirror, Doubles, LeadingRange
};

typedef struct {
	enum ModeFunction function;
	uchar data1[20];
	uchar data2[20];
} mode;

typedef struct __attribute__((packed)) {
	uchar foundHash[20];
	ulong4 salt;
	uint found;
} result;

__kernel void eradicate2_init(__global ethhash * const pHash, __global ulong4 * const pSalt, __global result * const pResult, __global uchar * const pAddress, __global uchar * const pInitCodeDigest, const ulong4 seed, const uint size);
__kernel void eradicate2_iterate(__global const ethhash * const pHash, __global const ulong4 * const pSaltGlobal, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_result_update(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, const uchar score, const uchar scoreMax);
void eradicate2_score_leading(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_score_benchmark(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_score_matching(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_score_range(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_score_leadingrange(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_score_mirror(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);
void eradicate2_score_doubles(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax);

__kernel void eradicate2_init(__global ethhash * const pHash, __global ulong4 * const pSalt, __global result * const pResult, __global uchar * const pAddress, __global uchar * const pInitCodeDigest, const ulong4 seed, const uint size) {
	// Zero data structures
	for (int i = 0; i < 50; ++i) {
		pHash->d[i] = 0;
	}

	for (size_t i = 0; i < ERADICATE2_MAX_SCORE + 1; ++i) {
		pResult[i].found = 0;
		for (size_t j = 0; j < 20; ++j) {
			pResult[i].foundHash[j] = 0xde;
		}
	}

	// Prepare main ethhash structure
	pHash->b[0] = 0xff;
	for (size_t i = 0; i < 20; ++i) {
		pHash->b[1 + i] = pAddress[i];
	}
	for (size_t i = 0; i < 32; ++i) {
		pHash->b[53 + i] = pInitCodeDigest[i];
	}
	pHash->b[85] ^= 0x01;

	// Prepare all salt structures
	for (size_t i = 0; i < size; ++i) {
		pSalt[i].x = seed.x + i;
		pSalt[i].y = seed.y;
		pSalt[i].z = seed.z;
		pSalt[i].w = seed.w;
	}
}

__kernel void eradicate2_iterate(__global const ethhash * const pHash, __global const ulong4 * const pSaltGlobal, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);

	ethhash h = *pHash;
	const ulong4 salt = pSaltGlobal[id];
	const uchar * const pSalt = (uchar * const) &salt;

	// Write salt
	for (size_t i = 0; i < 32; ++i) {
		h.b[21 + i] = pSalt[i];
	}

	// Hash
	sha3_keccakf(&h);

	// Iterate salt
	++pSaltGlobal[id].w;

	/* enum class ModeFunction {
	 *      Benchmark, Matching, Leading, Range, Mirror, Doubles, LeadingRange
	 * };
	 */
	switch (pMode->function) {
	case Benchmark:
		eradicate2_score_benchmark(salt, &h.b[12], pResult, pMode, scoreMax);
		break;

	case Matching:
		eradicate2_score_matching(salt, &h.b[12], pResult, pMode, scoreMax);
		break;

	case Leading:
		eradicate2_score_leading(salt, &h.b[12], pResult, pMode, scoreMax);
		break;

	case Range:
		eradicate2_score_range(salt, &h.b[12], pResult, pMode, scoreMax);
		break;

	case Mirror:
		eradicate2_score_mirror(salt, &h.b[12], pResult, pMode, scoreMax);
		break;

	case Doubles:
		eradicate2_score_doubles(salt, &h.b[12], pResult, pMode, scoreMax);
		break;

	case LeadingRange:
		eradicate2_score_leadingrange(salt, &h.b[12], pResult, pMode, scoreMax);
		break;
	}
}

void eradicate2_result_update(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, const uchar score, const uchar scoreMax) {
	if (score && score > scoreMax) {
		uchar hasResult = atomic_inc(&pResult[score].found); // NOTE: If "too many" results are found it'll wrap around to 0 again and overwrite last result. Only relevant if global worksize exceeds MAX(uint).

		// Save only one result for each score, the first.
		if (hasResult == 0) {
			pResult[score].salt = salt;

			for (int i = 0; i < 20; ++i) {
				pResult[score].foundHash[i] = hash[i];
			}
		}
	}
}

void eradicate2_score_leading(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		if ((hash[i] & 0xF0) >> 4 == pMode->data1[0]) {
			++score;
		} else {
			break;
		}

		if ((hash[i] & 0x0F) == pMode->data1[0]) {
			++score;
		} else {
			break;
		}
	}

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}

void eradicate2_score_benchmark(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);
	int score = 0;

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}

void eradicate2_score_matching(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		if (pMode->data1[i] > 0 && (hash[i] & pMode->data1[i]) == pMode->data2[i]) {
			++score;
		}
	}

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}

void eradicate2_score_range(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		const uchar first = (hash[i] & 0xF0) >> 4;
		const uchar second = (hash[i] & 0x0F);

		if (first >= pMode->data1[0] && first <= pMode->data2[0]) {
			++score;
		}

		if (second >= pMode->data1[0] && second <= pMode->data2[0]) {
			++score;
		}
	}

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}

void eradicate2_score_leadingrange(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		const uchar first = (hash[i] & 0xF0) >> 4;
		const uchar second = (hash[i] & 0x0F);

		if (first >= pMode->data1[0] && first <= pMode->data2[0]) {
			++score;
		}
		else {
			break;
		}

		if (second >= pMode->data1[0] && second <= pMode->data2[0]) {
			++score;
		}
		else {
			break;
		}
	}

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}

void eradicate2_score_mirror(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 10; ++i) {
		const uchar leftLeft = (hash[9 - i] & 0xF0) >> 4;
		const uchar leftRight = (hash[9 - i] & 0x0F);

		const uchar rightLeft = (hash[10 + i] & 0xF0) >> 4;
		const uchar rightRight = (hash[10 + i] & 0x0F);

		if (leftRight != rightLeft) {
			break;
		}

		++score;

		if (leftLeft != rightRight) {
			break;
		}

		++score;
	}

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}

void eradicate2_score_doubles(const ulong4 salt, __private const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		if ((hash[i] == 0x00) || (hash[i] == 0x11) || (hash[i] == 0x22) || (hash[i] == 0x33) || (hash[i] == 0x44) || (hash[i] == 0x55) || (hash[i] == 0x66) || (hash[i] == 0x77) || (hash[i] == 0x88) || (hash[i] == 0x99) || (hash[i] == 0xAA) || (hash[i] == 0xBB) || (hash[i] == 0xCC) || (hash[i] == 0xDD) || (hash[i] == 0xEE) || (hash[i] == 0xFF)) {
			++score;
		}
		else {
			break;
		}
	}

	eradicate2_result_update(salt, hash, pResult, score, scoreMax);
}
