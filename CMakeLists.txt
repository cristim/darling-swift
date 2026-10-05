project(swift)

include(darling_lib)

set(DARLING_LIB_64BIT_ONLY TRUE)

set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswiftCoreCompat.dylib")
add_darling_library(swiftCoreCompat SHARED
	swift_compat.S
)
target_link_libraries(swiftCoreCompat system)
set_target_properties(swiftCoreCompat PROPERTIES
	LINKER_LANGUAGE C
	OUTPUT_NAME "swiftCoreCompat"
)
set_property(TARGET swiftCoreCompat APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-U,_swift_getTypeByMangledNameInContext -Wl,-U,'_\$ss12_ArrayBufferV19_getElementSlowPathyyXlSiF'"
)
install(TARGETS swiftCoreCompat DESTINATION libexec/darling/usr/lib/swift)

set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswiftWebKit.dylib")
add_darling_library(swiftWebKit SHARED
	libswiftWebKit.S
)
target_link_libraries(swiftWebKit system)
set_target_properties(swiftWebKit PROPERTIES
	LINKER_LANGUAGE C
	OUTPUT_NAME "swiftWebKit"
)
install(TARGETS swiftWebKit DESTINATION libexec/darling/usr/lib/swift)

set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswift_errno.dylib")
add_darling_library(swift_errno SHARED
	swift_errno.S
)
target_link_libraries(swift_errno system)
set_target_properties(swift_errno PROPERTIES
	LINKER_LANGUAGE C
	OUTPUT_NAME "swift_errno"
)
set_property(TARGET swift_errno APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-reexport_library,${CMAKE_CURRENT_SOURCE_DIR}/libswiftDarwin.dylib")
install(TARGETS swift_errno DESTINATION libexec/darling/usr/lib/swift)

# Overlays that Darwin ships and this repository does not carry a binary for. Apps link each
# one and bind exactly one symbol from it, __swift_FORCE_LOAD_$_swift<Name>, which the Swift
# linker emits so the overlay is loaded at startup; it is a marker, not a call, so nothing in
# these libraries is ever entered and satisfying it is the whole of the load. dyld aborts on a
# dependency named in LC_LOAD_DYLIB that is absent, so without these files the apps that link
# them cannot start at all. Measured with llvm-nm -u over both slices of every imported app:
# no other symbol is referenced from any of these five.
#
# Built from source rather than shipped as a binary because *.dylib is LFS-tracked here, and an
# LFS object that cannot be fetched installs as a 130-byte pointer file, which is the
# "libswiftCore.dylib: file too short" failure this repository has already hit once.
foreach(SWIFT_OVERLAY OSLog Spatial CoreMIDI QuickLookUI MLCompute)
	set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswift${SWIFT_OVERLAY}.dylib")
	add_darling_library(swift_${SWIFT_OVERLAY}_overlay SHARED
		swift_${SWIFT_OVERLAY}_overlay.c
	)
	target_link_libraries(swift_${SWIFT_OVERLAY}_overlay system)
	set_target_properties(swift_${SWIFT_OVERLAY}_overlay PROPERTIES
		LINKER_LANGUAGE C
		OUTPUT_NAME "swift${SWIFT_OVERLAY}"
	)
	install(TARGETS swift_${SWIFT_OVERLAY}_overlay DESTINATION libexec/darling/usr/lib/swift)
endforeach()

file(GLOB DYLIBS "*.dylib")
if(DYLIBS)
	install(FILES ${DYLIBS} DESTINATION libexec/darling/usr/lib/swift)
endif()

# Combine is a Swift framework, not a /usr/lib/swift overlay dylib, so it installs into the
# framework layout rather than through the glob above. Built by overlays/build.sh. The binary is
# arm64 only, unlike the fat dylibs above, so it is skipped on roots without an arm64 slice.
if (TARGET_ARM64)
	include(InstallSymlink)
	set(COMBINE_FRAMEWORK_DIR "libexec/darling/System/Library/Frameworks/Combine.framework")
	install(PROGRAMS Combine.framework/Versions/A/Combine
		DESTINATION "${COMBINE_FRAMEWORK_DIR}/Versions/A")
	InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${COMBINE_FRAMEWORK_DIR}/Versions/Current")
	InstallSymlink(Versions/Current/Combine "${CMAKE_INSTALL_PREFIX}/${COMBINE_FRAMEWORK_DIR}/Combine")

	set(CRYPTOKIT_FRAMEWORK_DIR "libexec/darling/System/Library/Frameworks/CryptoKit.framework")
	install(PROGRAMS CryptoKit.framework/Versions/A/CryptoKit
		DESTINATION "${CRYPTOKIT_FRAMEWORK_DIR}/Versions/A")
	InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${CRYPTOKIT_FRAMEWORK_DIR}/Versions/Current")
	InstallSymlink(Versions/Current/CryptoKit "${CMAKE_INSTALL_PREFIX}/${CRYPTOKIT_FRAMEWORK_DIR}/CryptoKit")

	set(GROUPACTIVITIES_FRAMEWORK_DIR "libexec/darling/System/Library/Frameworks/GroupActivities.framework")
	install(PROGRAMS GroupActivities.framework/Versions/A/GroupActivities
		DESTINATION "${GROUPACTIVITIES_FRAMEWORK_DIR}/Versions/A")
	InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${GROUPACTIVITIES_FRAMEWORK_DIR}/Versions/Current")
	InstallSymlink(Versions/Current/GroupActivities "${CMAKE_INSTALL_PREFIX}/${GROUPACTIVITIES_FRAMEWORK_DIR}/GroupActivities")
endif()
