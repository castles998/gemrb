// SPDX-FileCopyrightText: 2011 Contributors to the GemRB project <https://gemrb.org>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "AndroidLogger.h"
#include "Interface.h"
#include "PluginMgr.h"

#include "Logging/Logging.h"

#include <Python.h>
#include <SDL.h>
#include <android/log.h>
#include <clocale>
#include <cstdlib>
#include <cstring>
#include <fstream>

using namespace GemRB;

extern "C" PyObject* PyInit_GemRB();
extern "C" PyObject* PyInit__GemRB();

// A packaging diagnostic, deliberately separate from game/GUI initialization.
// GUIClasses and Main need a live Interface and are tested with game data later.
static int RuntimeCheck()
{
	bool passed = false;
	std::string report;
	SDL_Window* window = nullptr;
	SDL_Renderer* renderer = nullptr;
	if (SDL_Init(SDL_INIT_VIDEO) == 0) {
		window = SDL_CreateWindow("GemRB runtime diagnostic", SDL_WINDOWPOS_CENTERED,
					  SDL_WINDOWPOS_CENTERED, 640, 360, 0);
		if (window) renderer = SDL_CreateRenderer(window, -1, 0);
	}
	auto mgr = PluginMgr::Get();
	bool plugins = mgr->IsAvailable(IE_GUI_SCRIPT_CLASS_ID) && mgr->IsAvailable(IE_BIF_CLASS_ID);
	if (renderer && plugins &&
	    PyImport_AppendInittab("GemRB", PyInit_GemRB) == 0 &&
	    PyImport_AppendInittab("_GemRB", PyInit__GemRB) == 0) {
		Py_Initialize();
		passed = PyRun_SimpleString(
				 "import sys, encodings, json, math, struct, zlib, ctypes, ssl, sqlite3\n"
				 "import GemRB, _GemRB, GUIDefines, MetaClasses, ie_restype\n"
				 "assert sys.version_info[:3] == (3, 10, 5)\n"
				 "assert callable(GemRB.GetView) and callable(_GemRB.Table_GetValue)\n"
				 "assert zlib.decompress(zlib.compress(b'GemRB Android')) == b'GemRB Android'\n") == 0;
		if (passed) {
			report = fmt::format("ANDROID_APK_RUNTIME_OK\nPython: {}\nRegistered class plugins: {}\n"
					     "SDL video/rendering and GemRB/_GemRB, GUIDefines, MetaClasses imports passed.\n"
					     "Game initialization, GUIClasses, audio playback and gameplay are not tested.\n",
					     Py_GetVersion(), mgr->GetPluginCount());
		} else {
			report = "ANDROID_APK_RUNTIME_FAILED: Python imports failed; inspect logcat traceback.\n";
		}
		Py_FinalizeEx();
	} else {
		report = fmt::format("ANDROID_APK_RUNTIME_FAILED: SDL={}, registered plugins={}\n",
				     SDL_GetError(), mgr->GetPluginCount());
	}
	if (renderer) {
		SDL_SetRenderDrawColor(renderer, passed ? 20 : 160, passed ? 120 : 20, 50, 255);
		SDL_RenderClear(renderer);
		SDL_RenderPresent(renderer);
		SDL_Delay(1500);
		SDL_DestroyRenderer(renderer);
	}
	if (window) SDL_DestroyWindow(window);
	SDL_Quit();
	if (const char* path = std::getenv("GEMRB_ANDROID_REPORT")) std::ofstream(path) << report;
	Log(passed ? MESSAGE : ERROR, "Android", "{}", report);
	__android_log_write(passed ? ANDROID_LOG_INFO : ANDROID_LOG_ERROR, "GemRB", report.c_str());
	FlushLogs();
	return passed ? GEM_OK : GEM_ERROR;
}

// SDL.h exposes SDL_main for SDLActivity's nativeRunMain.
int main(int argc, char* argv[])
{
	setlocale(LC_ALL, "");
	AddLogWriter(createAndroidLogger());
	ToggleLogging(true);
	if (argc == 2 && std::strcmp(argv[1], "--android-runtime-check") == 0) return RuntimeCheck();
	try {
		auto cfg = LoadFromArgs(argc, argv);
		if (const char* runtime = std::getenv("GEMRB_ANDROID_RUNTIME")) {
			// App-owned resources move with their content version; user config/saves don't.
			cfg.GemRBPath = runtime;
			cfg.GUIScriptsPath = runtime;
			cfg.GemRBOverridePath = runtime;
			cfg.GemRBUnhardcodedPath = runtime;
			cfg.CachePath = PathJoin(SDL_AndroidGetInternalStoragePath(), "cache");
		}
		if (!FileExists(PathJoin(cfg.GamePath, "chitin.key"))) {
			__android_log_write(ANDROID_LOG_WARN, "GemRB", "ANDROID_GAME_DATA_MISSING: showing setup instructions");
			SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Game data missing",
						 "Copy a complete supported game into the game directory shown in the launcher, "
						 "or edit GamePath in GemRB.cfg. No game data is included in this APK.",
						 nullptr);
			Log(ERROR, "Android", "Missing game data: {}", cfg.GamePath);
			FlushLogs();
			return GEM_ERROR;
		}
		SanityCheck();
		Interface gemrb(std::move(cfg));
		gemrb.Main();
	} catch (CoreInitializationException& cie) {
		Log(FATAL, "Main", "Aborting due to fatal error... {}", cie);
		FlushLogs();
		SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "GemRB startup failed", cie.what(), nullptr);
		return GEM_ERROR;
	}
	VideoDriver.reset();
	PluginMgr::Get()->RunCleanup();
	FlushLogs();
	return GEM_OK;
}
