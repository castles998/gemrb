// SPDX-FileCopyrightText: 2011 Contributors to the GemRB project <https://gemrb.org>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "AndroidLogger.h"
#include "Interface.h"
#include "PluginMgr.h"

#include "Logging/Logging.h"

#include <SDL.h>
#include <clocale>

using namespace GemRB;

// SDL.h exposes SDL_main for SDLActivity's nativeRunMain.
int main(int argc, char* argv[])
{
	setlocale(LC_ALL, "");
	AddLogWriter(createAndroidLogger());
	ToggleLogging(true);
	try {
		auto cfg = LoadFromArgs(argc, argv);
		SanityCheck();
		Interface gemrb(std::move(cfg));
		gemrb.Main();
	} catch (CoreInitializationException& cie) {
		Log(FATAL, "Main", "Aborting due to fatal error... {}", cie);
		FlushLogs();
		return GEM_ERROR;
	}
	VideoDriver.reset();
	PluginMgr::Get()->RunCleanup();
	FlushLogs();
	return GEM_OK;
}
