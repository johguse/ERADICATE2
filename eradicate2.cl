enum ModeFunction {
	Benchmark, Matching, Leading, Range, Mirror, Doubles, LeadingRange
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

__kernel void eradicate2_iterate(__global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_result_update(const uchar * const hash, __global result * const pResult, const uchar score, const uchar scoreMax, const ulong round);
void eradicate2_score_leading(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_score_benchmark(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_score_matching(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_score_range(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_score_leadingrange(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_score_mirror(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);
void eradicate2_score_doubles(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round);

__kernel void eradicate2_iterate(__global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
	ethhash h = { .q = { ERADICATE2_INITHASH } };

	// Salt have index h.b[21:52] inclusive, which covers QWORDS with index h.q[3:5] inclusive (they represent h.b[24:47] inclusive)
	// We use two of those three QWORD indexes to generate a unique salt value for each round.
	h.q[3] += get_global_id(0);
	h.q[4] += round;

	// Hash
	sha3_keccakf(&h);

	/* enum class ModeFunction {
	 *      Benchmark, Matching, Leading, Range, Mirror, Doubles, LeadingRange
	 * };
	 */
	switch (pMode->function) {
	case Benchmark:
		eradicate2_score_benchmark(h.b + 12, pResult, pMode, scoreMax, round);
		break;

	case Matching:
		eradicate2_score_matching(h.b + 12, pResult, pMode, scoreMax, round);
		break;

	case Leading:
		eradicate2_score_leading(h.b + 12, pResult, pMode, scoreMax, round);
		break;

	case Range:
		eradicate2_score_range(h.b + 12, pResult, pMode, scoreMax, round);
		break;

	case Mirror:
		eradicate2_score_mirror(h.b + 12, pResult, pMode, scoreMax, round);
		break;

	case Doubles:
		eradicate2_score_doubles(h.b + 12, pResult, pMode, scoreMax, round);
		break;

	case LeadingRange:
		eradicate2_score_leadingrange(h.b + 12, pResult, pMode, scoreMax, round);
		break;
	}
}

void eradicate2_result_update(const uchar * const H, __global result * const pResult, const uchar score, const uchar scoreMax, const ulong round) {
	if (score && score > scoreMax) {
		const uchar hasResult = atomic_inc(&pResult[score].found); // NOTE: If "too many" results are found it'll wrap around to 0 again and overwrite last result. Only relevant if global worksize exceeds MAX(uint).

		// Save only one result for each score, the first.
		if (hasResult == 0) {
			// Reconstruct state with hash and extract salt
			ethhash h = { .q = { ERADICATE2_INITHASH } };
			h.q[3] += get_global_id(0);
			h.q[4] += round;

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

void eradicate2_score_leading(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}

void eradicate2_score_benchmark(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
	const size_t id = get_global_id(0);
	int score = 0;

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}

void eradicate2_score_matching(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
	const size_t id = get_global_id(0);
	int score = 0;

	for (int i = 0; i < 20; ++i) {
		if (pMode->data1[i] > 0 && (hash[i] & pMode->data1[i]) == pMode->data2[i]) {
			++score;
		}
	}

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}

void eradicate2_score_range(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}

void eradicate2_score_leadingrange(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}

void eradicate2_score_mirror(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}

void eradicate2_score_doubles(const uchar * const hash, __global result * const pResult, __global const mode * const pMode, const uchar scoreMax, const ulong round) {
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

	eradicate2_result_update(hash, pResult, score, scoreMax, round);
}
