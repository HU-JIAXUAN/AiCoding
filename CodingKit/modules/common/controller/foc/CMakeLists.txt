cmake_minimum_required(VERSION 3.16)
project(foc_controller C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    include(CTest)
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/ControllerPrimitives.cmake")

add_library(foc_controller src/foc.c)
target_include_directories(foc_controller PUBLIC src)
target_link_libraries(foc_controller PUBLIC controller_primitives)

if(BUILD_TESTING)
    add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../tests" "${CMAKE_CURRENT_BINARY_DIR}/controller-tests")
endif()
