cmake_minimum_required(VERSION 3.19)

project(mgard_x_example CXX C)
find_package(mgard)

add_executable(SimpleExample SimpleExample.cpp)
target_link_libraries(SimpleExample mgard::mgard)
