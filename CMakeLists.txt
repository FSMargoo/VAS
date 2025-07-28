cmake_minimum_required(VERSION 3.31)
project(VAS)

set(CMAKE_CXX_STANDARD 20)

add_subdirectory(./thirdparty/glfw)

set(IMGUICode thirdparty/imgui/imgui.cpp thirdparty/imgui/imgui_draw.cpp thirdparty/imgui/imgui_widgets.cpp
        thirdparty/imgui/backends/imgui_impl_opengl3.cpp thirdparty/imgui/backends/imgui_impl_glfw.cpp
        thirdparty/imgui/imgui_demo.cpp thirdparty/imgui/imgui_draw.cpp thirdparty/imgui/imgui_tables.cpp)

add_library(IMGUI ${IMGUICode})
target_link_libraries(IMGUI glfw opengl32)

add_executable(VAS main.cpp thirdparty/glad/src/glad.c)

target_include_directories(VAS PUBLIC lumen/inc)
target_include_directories(VAS PUBLIC ./thirdparty/glad/include)
target_include_directories(VAS PUBLIC ./thirdparty/imgui)

target_include_directories(IMGUI PUBLIC ./thirdparty/imgui)

target_link_libraries(VAS glfw opengl32 IMGUI)
