/*
	Placeholder for /usr/lib/swift/libswiftQuickLookUI.dylib.

	Apps link this overlay and reference exactly one symbol from it,
	__swift_FORCE_LOAD_$_swiftQuickLookUI, which the Swift linker emits so the overlay is
	loaded at startup. It is a marker rather than a call, so satisfying it is the whole
	of what the clients ask of this library and nothing here is ever entered.

	Demand analysis (llvm-nm -u, both slices) over every imported app that links it found
	no other reference. If a future binary binds real overlay symbols, they belong in this
	file with the ladder rung that supports each one.

	Built rather than committed because *.dylib is LFS-tracked in this repository, and an
	unfetchable LFS object installs as a 130-byte pointer file that dyld reports as
	"file too short".
*/

int _swift_FORCE_LOAD_$_swiftQuickLookUI;
