enum ModeFunction {
	Benchmark, ZeroBytes, Matching, Leading, Range, Mirror, Doubles, LeadingRange
};

typedef struct {
	enum ModeFunction function;
	uchar data1[20];
	uchar data2[20];
} mode;

typedef struct __attribute__((packed)) {
	uchar salt[32];
	uchar hash[20];
	uint found;
} result;

__kernel void eradicate2_iterate(__global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_result_update(const uchar * const hash, __global result * const pResult, const uchar score, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_leading(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_benchmark(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_zerobytes(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_matching(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_range(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_leadingrange(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_mirror(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);
void eradicate2_score_doubles(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round);

__kernel void eradicate2_iterate(__global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
	ethhash h = { .q = { ERADICATE2_INITHASH } };

	// Salt have index h.b[21:52] inclusive, which covers WORDS with index h.d[6:12] inclusive (they represent h.b[24:51] inclusive)
	// We use three out of those six words to generate a unique salt value for each device, thread and round. We ignore any overflows
	// and assume that there'll never be more than 2**32 devices, threads or rounds. Worst case scenario with default settings
	// of 16777216 = 2**24 threads means the assumption fails after a device has tried 2**32 * 2**24 = 2**56 salts, enough to match
	// 14 characters in the address! A GTX 1070 with speed of ~700*10**6 combinations per second would hit this target after ~3 years.
	h.d[6] += deviceIndex; 
	h.d[7] += get_global_id(0);
	h.d[8] += round;

	// Hash
	sha3_keccakf(&h);

	/* enum class ModeFunction {
	 *      Benchmark, ZeroBytes, Matching, Leading, Range, Mirror, Doubles, LeadingRange
	 * };
	 */
	switch (pMode->function) {
	case Benchmark:
		eradicate2_score_benchmark(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case ZeroBytes:
		eradicate2_score_zerobytes(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case Matching:
		eradicate2_score_matching(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case Leading:
		eradicate2_score_leading(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case Range:
		eradicate2_score_range(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case Mirror:
		eradicate2_score_mirror(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case Doubles:
		eradicate2_score_doubles(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;

	case LeadingRange:
		eradicate2_score_leadingrange(h.b + 12, pResult, pMode, scoreMax, deviceIndex, round);
		break;
	}
}

void eradicate2_result_update(const uchar * const H, __global result * const pResult, const uchar score, const uchar scoreMax, const uint deviceIndex, const uint round) {
	if (score && score > scoreMax) {
		const uchar hasResult = atomic_inc(&pResult[score].found); // NOTE: If "too many" results are found it'll wrap around to 0 again and overwrite last result. Only relevant if global worksize exceeds MAX(uint).

		// Save only one result for each score, the first.
		if (hasResult == 0) {
			// Reconstruct state with hash and extract salt
			ethhash h = { .q = { ERADICATE2_INITHASH } };
			h.d[6] += deviceIndex;
			h.d[7] += get_global_id(0);
			h.d[8] += round;

			ethhash be;

			for (int i = 0; i < 32; ++i) {
				pResult[score].salt[i] = h.b[i + 21];
			}

			for (int i = 0; i < 20; ++i) {
				pResult[score].hash[i] = H[i];
			}
		}
	}
}

void eradicate2_score_leading(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_benchmark(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
	const size_t id = get_global_id(0);
	int score = 0;

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_zerobytes(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		score += !hash[i];
	}

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_matching(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		if (pMode->data1[i] > 0 && (hash[i] & pMode->data1[i]) == pMode->data2[i]) {
			++score;
		}
	}

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_range(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_leadingrange(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_mirror(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}

void eradicate2_score_doubles(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const uint deviceIndex, const uint round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, deviceIndex, round);
}
