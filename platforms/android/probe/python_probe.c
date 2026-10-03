// SPDX-License-Identifier: GPL-2.0-or-later
// Standalone Android feasibility probe; does not initialize or modify GemRB.
#include <Python.h>
#include <stdio.h>

#if PY_MAJOR_VERSION != 3 || PY_MINOR_VERSION != 10 || PY_MICRO_VERSION != 5
	#error "This probe must use the desktop-matching Python 3.10.5 headers"
#endif

int main(int argc, char** argv)
{
	if (argc != 2) {
		fprintf(stderr, "Usage: gemrb_python_probe <extracted-python-home>\n");
		return 2;
	}
	printf("Python library: %s\n", Py_GetVersion());
	PyConfig config;
	PyConfig_InitIsolatedConfig(&config);
	config.site_import = 0;
	config.write_bytecode = 0;
	PyStatus status = PyConfig_SetBytesString(&config, &config.home, argv[1]);
	if (!PyStatus_Exception(status)) {
		status = Py_InitializeFromConfig(&config);
	}
	if (PyStatus_Exception(status)) {
		fprintf(stderr, "Python initialization failed: %s\n",
			status.err_msg ? status.err_msg : "unknown error");
		PyConfig_Clear(&config);
		return 1;
	}
	PyConfig_Clear(&config);
	int result = PyRun_SimpleString(
		"import sys, encodings, json, math, struct, zlib, ctypes, ssl, sqlite3\n"
		"assert sys.version_info[:3] == (3, 10, 5), sys.version\n"
		"assert json.loads('{\"ok\":true}')['ok']\n"
		"assert struct.unpack('<I', struct.pack('<I', 42))[0] == 42\n"
		"assert zlib.decompress(zlib.compress(b'GemRB')) == b'GemRB'\n"
		"print('ANDROID_PYTHON_PROBE_OK', sys.version, flush=True)\n");
	int finalized = Py_FinalizeEx();
	return result != 0 || finalized < 0 ? 1 : 0;
}
