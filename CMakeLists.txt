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

file(GLOB DYLIBS "*.dylib")
if(DYLIBS)
	install(FILES ${DYLIBS} DESTINATION libexec/darling/usr/lib/swift)
endif()

# These Swift frameworks install into the framework layout rather than through the glob above. Built
# by overlays/build.sh. The binaries are arm64 only, unlike the fat dylibs above, so they are skipped
# on roots without an arm64 slice.
if (TARGET_ARM64)
	include(InstallSymlink)
	foreach(framework Combine CryptoKit GroupActivities SwiftUI)
		set(framework_dir "libexec/darling/System/Library/Frameworks/${framework}.framework")
		install(PROGRAMS ${framework}.framework/Versions/A/${framework}
			DESTINATION "${framework_dir}/Versions/A")
		InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${framework_dir}/Versions/Current")
		InstallSymlink(Versions/Current/${framework} "${CMAKE_INSTALL_PREFIX}/${framework_dir}/${framework}")
	endforeach()
endif()
