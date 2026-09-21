// Narrow view of Darling's libicucore (ICU 66.1) for the Foundation overlay's date formatting.
//
// swift-foundation reaches ICU through its own `_FoundationICU` module, which vendors ICU 72+.
// Darling has ICU already: `usr/include/unicode` ships 190 headers and libicucore.A.dylib exports
// the public entry points unsuffixed. This header admits only the ones the overlay calls, so that
// the dependency surface stays reviewable; add a header here only with a caller to name.
//
// ICU 66 is a hard boundary. swift-foundation also calls udatpg_getDefaultHourCycle (ICU 67),
// UDAT_HOUR_CYCLE_* (67), ucal_getTimeZoneOffsetFromLocal (69) and UDAT_*NARROW_QUARTERS (70),
// none of which exist here. Those paths stay compile errors naming the ICU version they need;
// substituting a near-equivalent call would reintroduce exactly the silent divergence this
// module exists to remove.

#include <unicode/utypes.h>   // UErrorCode, U_ZERO_ERROR, U_FAILURE: every call below
#include <unicode/udatpg.h>   // udatpg_open/close/clone/getBestPatternWithOptions: pattern generation
#include <unicode/udat.h>     // udat_open/close/format/applyPattern/setContext: the formatter itself
#include <unicode/ureldatefmt.h>     // ureldatefmt_open/close/format/formatNumeric: relative dates
#include <unicode/unum.h>            // unum_open: the number format a relative formatter takes over
#include <unicode/udisplaycontext.h> // UDisplayContext: FormatStyleCapitalizationContext.icuContext
