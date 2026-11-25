cmake_minimum_required(VERSION 3.18.1)

project(tahrir_ocr_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(
    tahrir_ocr_native
    SHARED
    ../../../../../native/tahrir_ocr_native/tahrir_ocr_native.cpp
)

target_compile_options(tahrir_ocr_native PRIVATE -O3 -Wall -Wextra)

if(NOT WIN32)
    target_link_libraries(tahrir_ocr_native PRIVATE dl)
endif()
