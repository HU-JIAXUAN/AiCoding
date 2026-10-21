add_executable(controller_legacy test_legacy.c)
target_link_libraries(controller_legacy PRIVATE foc_controller)
add_test(NAME pid_legacy COMMAND controller_legacy pid "${CMAKE_CURRENT_SOURCE_DIR}/fixtures/legacy_pid.txt")
add_test(NAME foc_legacy COMMAND controller_legacy foc "${CMAKE_CURRENT_SOURCE_DIR}/fixtures/legacy_foc.txt")

add_executable(controller_numeric test_primitives.c)
target_link_libraries(controller_numeric PRIVATE controller_primitives)
add_test(NAME controller_numeric COMMAND controller_numeric)

set(example_files
    current_loop_example.c
    flat_vf_if_example.c
    minimal_example.c
    motion_loop_example.c
    open_loop_current_example.c
    with_pid_controller_example.c)
set(example_index 0)
foreach(example IN LISTS example_files)
    get_filename_component(example_name "${example}" NAME_WE)
    set(example_target "foc_baseline_${example_name}")
    add_executable("${example_target}" test_example.c)
    target_compile_definitions("${example_target}" PRIVATE
        FOC_EXAMPLE_KIND=${example_index}
        FOC_EXAMPLE_SOURCE="${CMAKE_CURRENT_SOURCE_DIR}/../foc/examples/${example}")
    target_link_libraries("${example_target}" PRIVATE foc_controller)
    add_test(NAME "${example_target}" COMMAND "${example_target}")
    math(EXPR example_index "${example_index} + 1")
endforeach()

foreach(target controller_legacy controller_numeric)
    set_target_properties("${target}" PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED YES)
endforeach()
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    foreach(target controller_legacy controller_numeric)
        target_compile_options("${target}" PRIVATE -Wall -Wextra -Werror -pedantic)
    endforeach()
endif()
