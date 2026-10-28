cmake_minimum_required(VERSION 3.16)
project(if_controller C)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    include(CTest)
endif()

add_library(if_controller src/if_controller.c)
target_include_directories(if_controller PUBLIC src)
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(if_controller PRIVATE -Wall -Wextra -Werror -pedantic)
endif()
set_target_properties(if_controller PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED YES)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
