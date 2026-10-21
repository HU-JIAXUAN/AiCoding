# Shared sources stay in their existing modules; consumers link the same targets.
if(TARGET controller_primitives)
    return()
endif()

get_filename_component(CONTROLLER_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

if(NOT TARGET pid_controller)
    add_subdirectory("${CONTROLLER_ROOT}/pid" "${CMAKE_CURRENT_BINARY_DIR}/shared-pid")
endif()

add_library(controller_math "${CONTROLLER_ROOT}/foc/src/foc_math.c")
target_include_directories(controller_math PUBLIC "${CONTROLLER_ROOT}/foc/src")
set_target_properties(controller_math PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED YES)
if(UNIX)
    target_link_libraries(controller_math PUBLIC m)
endif()

add_library(controller_svpwm "${CONTROLLER_ROOT}/foc/src/foc_svpwm.c")
target_link_libraries(controller_svpwm PUBLIC controller_math)
set_target_properties(controller_svpwm PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED YES)

add_library(controller_primitives INTERFACE)
target_link_libraries(controller_primitives INTERFACE
    pid_controller controller_svpwm controller_math)
