# GetJuceRef.cmake
#
# Usage:
#   include("${CMAKE_SOURCE_DIR}/cmake/GetJuceRef.cmake")  # adjust path as needed
#   read_juce_ref(JUCE_REF)                # reads from ${CMAKE_SOURCE_DIR}/VERSION
#   # or
#   read_juce_ref(JUCE_REF "${CMAKE_SOURCE_DIR}/path/to/VERSION")

function(read_juce_ref OUT_VAR)
  if(NOT OUT_VAR)
    message(FATAL_ERROR "read_juce_ref: missing variable name")
  endif()

  # Default VERSION file; allow an override as 2nd arg
  set(_file "${CMAKE_SOURCE_DIR}/VERSION")
  if(ARGC GREATER 1)
    set(_file "${ARGV1}")
  endif()
  if(NOT EXISTS "${_file}")
    message(FATAL_ERROR "read_juce_ref: file not found: ${_file}")
  endif()

  # Reconfigure when VERSION changes
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_file}")

  # Read and scan for JUCE_REF = ...
  file(STRINGS "${_file}" _lines ENCODING UTF-8)
  set(_val "")
  foreach(_line IN LISTS _lines)
    string(STRIP "${_line}" _line)
    if(_line STREQUAL "" OR _line MATCHES "^#")
      continue()
    endif()
    if(_line MATCHES "^JUCE_REF[ \t]*([:=]|[ \t]+)[ \t]*(.+)$")
      set(_val "${CMAKE_MATCH_2}")
      break()
    endif()
  endforeach()

  if(_val STREQUAL "")
    message(FATAL_ERROR "read_juce_ref: key 'JUCE_REF' not found in ${_file}")
  endif()

  # Strip inline comments and surrounding quotes/backticks, then trim
  string(REGEX REPLACE "[ \t]*(#|//).*$" "" _val "${_val}")
  string(REGEX REPLACE "^[\"'`]" "" _val "${_val}")
  string(REGEX REPLACE "[\"'`]$" "" _val "${_val}")
  string(STRIP "${_val}" _val)

  # Return to caller
  set(${OUT_VAR} "${_val}" PARENT_SCOPE)
endfunction()

function(read_juce_ref_here OUT_VAR)
  read_juce_ref(${OUT_VAR} ${ARGN})
  set(${OUT_VAR} "${${OUT_VAR}}" PARENT_SCOPE)
endfunction()