cmake_minimum_required(VERSION 3.26)
project(rvcore_core_test)

# GoogleTest settings
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/03597a01ee50ed33e9dfd640b249b4be3799d395.zip
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)
enable_testing()

# verilator setting
find_package(verilator HINTS $ENV{VERILATOR_ROOT})

# rvcore/core setting
set(CORE_RTL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)
set(CORE_TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/test)
set(CORE_OBJ_DIR ${CMAKE_CURRENT_SOURCE_DIR}/obj_dir)

# memory_test
add_executable(memory_test ${CORE_TEST_DIR}/memory_test.cpp)
target_compile_options(memory_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(memory_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(memory_test)
verilate(memory_test
    SOURCES
        ${CORE_RTL_DIR}/memory.sv
    PREFIX Vmemory
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${CORE_OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
)

# core_test
add_executable(core_test ${CORE_TEST_DIR}/core_test.cpp)
target_compile_options(core_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(core_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(core_test)
verilate(core_test
    SOURCES
        ${CORE_RTL_DIR}/core.sv
        ${CORE_RTL_DIR}/csr_reg.sv
        ${CORE_RTL_DIR}/regfile.sv
        ${CORE_RTL_DIR}/decoder.sv
        ${CORE_RTL_DIR}/execute.sv
        ${CORE_RTL_DIR}/memory_access.sv
        ${CORE_RTL_DIR}/write_back.sv
    PREFIX Vcore
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${CORE_OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
)

# top_test
add_executable(top_test ${CORE_TEST_DIR}/top_test.cpp)
target_compile_options(top_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(top_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(top_test)
verilate(top_test
    SOURCES
        ${CORE_RTL_DIR}/top.sv
        ${CORE_RTL_DIR}/core.sv
        ${CORE_RTL_DIR}/csr_reg.sv
        ${CORE_RTL_DIR}/regfile.sv
        ${CORE_RTL_DIR}/decoder.sv
        ${CORE_RTL_DIR}/execute.sv
        ${CORE_RTL_DIR}/memory_access.sv
        ${CORE_RTL_DIR}/write_back.sv
        ${CORE_RTL_DIR}/memory.sv
    PREFIX Vtop
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${CORE_OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
)
