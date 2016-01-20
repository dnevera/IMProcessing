//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//


#ifndef IMProcessing_Bridging_Metal_h
#define IMProcessing_Bridging_Metal_h

#include "IMPTypes-Bridging-Metal.h"
#include "IMPConstants-Bridging-Metal.h"
#include "IMPOperations-Bridgin-Metal.h"
#include "IMPHistogramTypes-Bridging-Metal.h"

#ifndef __METAL_VERSION__

#include "IMPJpegturbo.h"

#endif

#define IMPSTD_PASS_KERNEL "kernel_passthrough"
#define IMPSTD_VIEW_KERNEL "kernel_view"

#endif //IMProcessing_Bridging_Metal_h