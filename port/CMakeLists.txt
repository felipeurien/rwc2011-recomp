# rugby2011 - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(rugby2011 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(RUGBY2011_SOURCES
    src/main.cpp
    src/lua_diagnostics.cpp
    src/task_diagnostics.cpp
    src/input_diagnostics.cpp
    src/profile_storage.cpp
)

if(WIN32)
    add_executable(rugby2011 WIN32 ${RUGBY2011_SOURCES})
else()
    add_executable(rugby2011 ${RUGBY2011_SOURCES})
endif()

rexglue_setup_target(rugby2011 GPU_PLUGINS xenos)
if(MINGW)
    target_link_options(rugby2011 PRIVATE -municode)
endif()

option(RUGBY_BUILD_CAPTURE_TOOL "Build an optional manual GPU capture host" OFF)
if(RUGBY_BUILD_CAPTURE_TOOL)
    add_executable(rugby2011_capture WIN32 ${RUGBY2011_SOURCES})
    target_compile_definitions(rugby2011_capture PRIVATE RUGBY_FRAME_CAPTURE=1)
    target_include_directories(rugby2011_capture PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${REXGLUE_ENTRYPOINT_INCLUDE_DIR})
    target_link_libraries(rugby2011_capture PRIVATE rugby2011_recomp rex::runtime)
    rexglue_apply_target_settings(rugby2011_capture)
    rexglue_configure_target(rugby2011_capture GPU_PLUGINS xenos)
    set_target_properties(rugby2011_capture PROPERTIES OUTPUT_NAME rugby2011
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/capture")
endif()
