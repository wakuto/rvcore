cmake_minimum_required(VERSION 3.26)
project(rvcore_core_test)

set(CORE_RTL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)
set(CORE_TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/test)
set(CORE_OBJ_DIR ${CMAKE_CURRENT_SOURCE_DIR}/obj_dir)

find_package(verilator HINTS $ENV{VERILATOR_ROOT})
add_executable(Vmemory ${CORE_TEST_DIR}/memory_test.cpp)


verilate(Vmemory
    SOURCES
        ${CORE_RTL_DIR}/memory.sv
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${CORE_OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
)