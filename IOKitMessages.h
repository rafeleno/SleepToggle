#pragma once
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPM.h>

// Swift cannot import IOKit's function-like message macro directly.
// Export its SDK-defined value instead of duplicating a numeric constant.
enum { SleepToggleClamshellStateChange = kIOPMMessageClamshellStateChange };
