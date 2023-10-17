cmake_minimum_required(VERSION 3.26)
project(rvcore_test)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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
set(CORE_RTL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl/core/)
set(CORE_TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/test/core/)
set(COMMON_RTL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl/common/)
set(COMMON_TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/test/common/)
set(OBJ_DIR ${CMAKE_CURRENT_SOURCE_DIR}/obj_dir)

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
    DIRECTORY ${OBJ_DIR}
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
    DIRECTORY ${OBJ_DIR}
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
    DIRECTORY ${OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
)

# fifo_test
add_executable(fifo_test ${COMMON_TEST_DIR}/fifo_test.cpp)
target_compile_options(fifo_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(fifo_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(fifo_test)
verilate(fifo_test
    SOURCES
        ${COMMON_RTL_DIR}/fifoWrapper.sv
        ${COMMON_RTL_DIR}/fifo.sv
        ${COMMON_RTL_DIR}/fifoIf.sv
    PREFIX Vfifo
    DIRECTORY ${OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
        -Wall
        -Wwarn-lint
        -Wwarn-style
)

# issue_queue_test
add_executable(issue_queue_test ${CORE_TEST_DIR}/issue_queue_test.cpp)
target_compile_options(issue_queue_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(issue_queue_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(issue_queue_test)
verilate(issue_queue_test
    SOURCES
        ${CORE_RTL_DIR}/issueQueue.sv
        ${CORE_RTL_DIR}/issueQueueIf.sv
        ${CORE_RTL_DIR}/issueQueueWrapper.sv
    PREFIX Vissue_queue
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
        -Wall
        -Wwarn-lint
        -Wwarn-style
)

# rob_test
add_executable(rob_test ${CORE_TEST_DIR}/rob_test.cpp)
target_compile_options(rob_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(rob_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(rob_test)
verilate(rob_test
    SOURCES
        ${CORE_RTL_DIR}/rob.sv
        ${CORE_RTL_DIR}/robIf.sv
        ${CORE_RTL_DIR}/robWrapper.sv
    PREFIX Vrob
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
        -Wall
        -Wwarn-lint
        -Wwarn-style
)

# freelist_test
add_executable(freelist_test ${CORE_TEST_DIR}/freelist_test.cpp)
target_compile_options(freelist_test PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(freelist_test PUBLIC GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(freelist_test)
verilate(freelist_test
    SOURCES
        ${CORE_RTL_DIR}/freelist.sv
        ${CORE_RTL_DIR}/freelistIf.sv
        ${CORE_RTL_DIR}/freelistWrapper.sv
        ${COMMON_RTL_DIR}/fifo.sv
        ${COMMON_RTL_DIR}/fifoIf.sv
        ${COMMON_RTL_DIR}/fifoWrapper.sv
    PREFIX Vfreelist
    INCLUDE_DIRS
        ${CORE_RTL_DIR}/include
    DIRECTORY ${OBJ_DIR}
    VERILATOR_ARGS
        --trace
        --trace-params
        --trace-structs
        --trace-underscore
        -Wall
        -Wwarn-lint
        -Wwarn-style
)
