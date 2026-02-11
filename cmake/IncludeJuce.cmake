# IncludeJuce.cmake
#
# Purpose:
#   Centralize how JUCE is brought into the build:
#   - If USE_LOCAL_JUCE_IF_AVAILABLE is true AND a local JUCE tree exists
#     (platform default or user-specified JUCE_LOCAL_DIR), use that.
#   - Otherwise, fetch JUCE via CPM with GIT_TAG set from JUCE_REF.
#
# Inputs (expected to be set by the parent project, but sensible defaults are used):
#   - USE_LOCAL_JUCE_IF_AVAILABLE : BOOL (default: OFF)
#   - JUCE_LOCAL_DIR              : PATH (optional override for the local JUCE tree)
#   - JUCE_REF                    : STRING tag/branch/commit (optional; auto-read if GetJuceRef.cmake is present)
#   - CPM_PATH                    : PATH to CPM.cmake (default: ${CMAKE_SOURCE_DIR}/cmake/CPM.cmake)
#
# Outputs:
#   - juce (CPM package)
#   - juce_SOURCE_DIR (from CPM)
#   - JUCE_SOURCE_IS_LOCAL : BOOL
#   - JUCE_USED_SOURCE     : PATH actually used
#
# Usage:
#   include("${CMAKE_SOURCE_DIR}/cmake/IncludeJuce.cmake")
#
# Notes:
#   - This file does not declare targets; it just ensures the 'juce' package is available.
#   - You can still use CPMFindPackage(juce CONFIG) later if you prefer, but CPMAddPackage sets juce_SOURCE_DIR.

if(DEFINED _INCLUDE_JUCE_CMAKE_INCLUDED)
  return()
endif()
set(_INCLUDE_JUCE_CMAKE_INCLUDED TRUE)

# --- Resolve CPM.cmake ---------------------------------------------------------
if(NOT DEFINED CPM_PATH)
  set(CPM_PATH "${CMAKE_SOURCE_DIR}/cmake/CPM.cmake")
endif()
if(NOT EXISTS "${CPM_PATH}")
  message(FATAL_ERROR "IncludeJuce.cmake: CPM.cmake not found at '${CPM_PATH}'. "
                      "Set CPM_PATH before including this file.")
endif()
include("${CPM_PATH}")

# --- Resolve JUCE_REF (optional auto-read) -------------------------------------
if(NOT DEFINED JUCE_REF)
  # If the helper exists, use it to read from VERSION; otherwise default to 'master'
  set(_get_juce_ref_cmake "${CMAKE_SOURCE_DIR}/cmake/GetJuceRef.cmake")
  if(EXISTS "${_get_juce_ref_cmake}")
    include("${_get_juce_ref_cmake}")
    if(COMMAND read_juce_ref)
      read_juce_ref(JUCE_REF)
    endif()
  endif()
  if(NOT DEFINED JUCE_REF OR JUCE_REF STREQUAL "")
    set(JUCE_REF "master")
    message(STATUS "IncludeJuce.cmake: JUCE_REF not set; defaulting to '${JUCE_REF}'")
  endif()
endif()

# --- Compute candidate local path ---------------------------------------------
if(NOT DEFINED USE_LOCAL_JUCE_IF_AVAILABLE)
  set(USE_LOCAL_JUCE_IF_AVAILABLE ON)
endif()

set(_candidate_local "")
if(USE_LOCAL_JUCE_IF_AVAILABLE)
  if(DEFINED JUCE_LOCAL_DIR AND NOT JUCE_LOCAL_DIR STREQUAL "")
    set(_candidate_local "${JUCE_LOCAL_DIR}")
  else()
    if(APPLE)
      set(_candidate_local "/Applications/JUCE")
    elseif(WIN32)
      # Common Windows system-wide path (note: ProgramData has no space).
      set(_candidate_local "C:/ProgramData/JUCE")
    endif()
  endif()
endif()

# --- Validate local JUCE tree --------------------------------------------------
set(_use_local FALSE)
if(_candidate_local)
  # A minimal sanity check for a JUCE tree
  if(EXISTS "${_candidate_local}/modules/juce_core/juce_core.h" OR
     EXISTS "${_candidate_local}/CMakeLists.txt")
    set(_use_local TRUE)
  endif()
endif()

# --- Bring JUCE in via CPM -----------------------------------------------------
if(_use_local)
  message(STATUS "IncludeJuce.cmake: Using local JUCE at: ${_candidate_local}")
  CPMAddPackage(
    NAME juce
    SOURCE_DIR "${_candidate_local}"
    OPTIONS
      "JUCE_ENABLE_MODULE_SOURCE_GROUPS ON"
  )
  set(JUCE_SOURCE_IS_LOCAL TRUE)
  set(JUCE_USED_SOURCE "${_candidate_local}")
else()
  message(STATUS "IncludeJuce.cmake: Using JUCE from Git tag '${JUCE_REF}' (Audioloom-Inc/JUCE)")
  CPMAddPackage(
    NAME juce
    GITHUB_REPOSITORY Audioloom-Inc/JUCE
    GIT_TAG ${JUCE_REF}
    OPTIONS
      "JUCE_ENABLE_MODULE_SOURCE_GROUPS ON"
  )
  set(JUCE_SOURCE_IS_LOCAL FALSE)
  # juce_SOURCE_DIR is set by CPM; mirror it for convenience after resolution.
  if(DEFINED juce_SOURCE_DIR)
    set(JUCE_USED_SOURCE "${juce_SOURCE_DIR}")
  endif()
endif()

# --- On Local JUCE, verify version matches JUCE_REF -------------------------------
if(JUCE_SOURCE_IS_LOCAL)
  # Attempt to read the local JUCE ref from .git/HEAD file
    set(_git_head_file "${JUCE_USED_SOURCE}/.git/HEAD")
    if(EXISTS "${_git_head_file}")
      file(READ "${_git_head_file}" _git_head_content)
      string(STRIP "${_git_head_content}" _git_head_content_stripped)
      if(_git_head_content_stripped MATCHES "^ref: refs/heads/(.+)$")
        set(_local_juce_ref "${CMAKE_MATCH_1}")
      else()
        set(_local_juce_ref "${_git_head_content_stripped}")
      endif()
      if(NOT _local_juce_ref STREQUAL JUCE_REF)
        message(FATAL_ERROR "Local JUCE ref '${_local_juce_ref}' does not match expected JUCE_REF '${JUCE_REF}' defined in ./VERSION. Either update the local JUCE tree to match the provided JUCE_REF or change the JUCE_REF to your local JUCE_VERSION. You can use branch names, tags, or commit hashes.")

      endif()
    else()
      message(FATAL_ERROR "IncludeJuce.cmake: Could not read .git/HEAD to verify local JUCE ref against JUCE_REF '${JUCE_REF}'. Ensure the local JUCE tree is a git repository.")
    endif()
endif()

# --- Export helpful cache variables (READ-ONLY by default) ---------------------
set(JUCE_SOURCE_IS_LOCAL "${JUCE_SOURCE_IS_LOCAL}" CACHE BOOL "True if JUCE is sourced from a local tree")
set(JUCE_USED_SOURCE     "${JUCE_USED_SOURCE}"     CACHE PATH "Path used for JUCE (local or fetched)")

# Optional: mark as advanced to avoid cluttering GUIs
mark_as_advanced(JUCE_SOURCE_IS_LOCAL JUCE_USED_SOURCE)