// SPDX-License-Identifier: GPL-2.0-or-later
// Android port: centered controllers must not reset the direct-touch cursor.

#include "../../plugins/SDLVideo/GamepadControl.h"

#include <gtest/gtest.h>

TEST(GamepadControlTest, CenterAndDeadZoneDoNotMoveCursor)
{
	for (int value : { -5000, -1, 0, 1, 5000 }) {
		EXPECT_EQ(GamepadControl::AxisDirection(value, 5000), 0);
	}
	EXPECT_EQ(GamepadControl::AxisDirection(0, 0), 0);
}

TEST(GamepadControlTest, BothDirectionsOutsideDeadZone)
{
	EXPECT_EQ(GamepadControl::AxisDirection(-5001, 5000), -1);
	EXPECT_EQ(GamepadControl::AxisDirection(-32768, 5000), -1);
	EXPECT_EQ(GamepadControl::AxisDirection(5001, 5000), 1);
	EXPECT_EQ(GamepadControl::AxisDirection(32767, 5000), 1);
}

TEST(GamepadControlTest, CenteredAxisPreservesLastTouchPosition)
{
	GamepadControl control;
	control.SetGamepadPosition(640, 360);
	control.HandleAxisEvent(SDL_CONTROLLER_AXIS_LEFTX, 0);
	control.HandleAxisEvent(SDL_CONTROLLER_AXIS_LEFTY, 0);
	EXPECT_EQ(GamepadControl::AxisDirection(control.xAxisLValue, control.deadZoneL), 0);
	EXPECT_EQ(GamepadControl::AxisDirection(control.yAxisLValue, control.deadZoneL), 0);
	EXPECT_FLOAT_EQ(control.xAxisFloatPos, 640);
	EXPECT_FLOAT_EQ(control.yAxisFloatPos, 360);
}
