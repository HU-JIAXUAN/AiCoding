cmake_minimum_required(VERSION 3.16)
project(if_controller C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    include(CTest)
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/ControllerPrimitives.cmake")

add_library(if_controller src/if_controller.c)
target_include_directories(if_controller PUBLIC src)
target_link_libraries(if_controller PUBLIC controller_primitives)
set_target_properties(if_controller PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED YES)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
