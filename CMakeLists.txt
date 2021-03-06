cmake_minimum_required(VERSION 2.8.6)

if (NOT DEFINED CMAKE_BUILD_TYPE)
   set (CMAKE_BUILD_TYPE Release CACHE STRING "Build type")
endif ()

# hunter initialize 
include("cmake/HunterGate.cmake") 
HunterGate(
    URL "https://github.com/CHChang810716/hunter/archive/170bdfbbe468a8cf7d58e6f83079f23298de1380.zip"
    SHA1 "7a0445a0d209c65490abce324ad53f55b8082828"
    FILEPATH "${CMAKE_CURRENT_LIST_DIR}/config.cmake"
)
# hunter initialize done
    

project(arpack C Fortran)

# Adopted from https://github.com/feymark/arpack.git

if (POLICY CMP0042)
  # enable MACOSX_RPATH by default
  cmake_policy (SET CMP0042 NEW)
endif ()

option(MPI "Enable parallel support" OFF)
option(ICB "Enable support for *[ae]upd_c with ISO_C_BINDING" ON)
#option(SYSTEM_BLAS "Use system BLAS" ON)
#option(SYSTEM_LAPACK "Use system LAPACK" ON)
option(EXAMPLES "Compile ARPACK examples" OFF)
set(LIBSUFFIX ""
    CACHE STRING "suffix to add to ARPACK libraries names")
set(SYMBOLSUFFIX ""
    CACHE STRING "suffix to add to ARPACK, BLAS and LAPACK function names")
option(INTERFACE64 "use the 64-bit integer interface (ILP64) for ARPACK, BLAS and LAPACK" ON)
option(USE_MKL "Use MKL as the blas library" OFF)
option(USE_OPENBLAS "use openblas as blas library" OFF)

if(USE_MKL)
  message(STATUS "MKL not yet supported, use LAPACK")
  set(BLAS_LIB_USE "LAPACK")
elseif(USE_OPENBLAS)
  message(STATUS "USE OpenBLAS as BLAS library")
  set(BLAS_LIB_USE "OpenBLAS")
else()
  message(STATUS "USE LAPACK as BLAS library")
  set(BLAS_LIB_USE "LAPACK")
endif()

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

function(prefixlist list_name prefix)
    set(${list_name}_TMP)
    foreach(l ${${list_name}})
      list(APPEND ${list_name}_TMP ${prefix}${l} )
    endforeach()
    set(${list_name} "${${list_name}_TMP}" PARENT_SCOPE)
endfunction(prefixlist)

function(examples list_name)
    foreach(l ${${list_name}})
        get_filename_component(lwe ${l} NAME_WE)
        add_executable(${lwe} ${arpackexample_DIR}/${l} ${examples_EXTRA_SRCS})
        target_link_libraries(${lwe} arpack)
        add_test(NAME "${lwe}_ex" COMMAND ${lwe} WORKING_DIRECTORY ${arpackexample_DIR})
    endforeach()
endfunction(examples)

function(pexamples list_name)
    foreach(l ${${list_name}})
        get_filename_component(lwe ${l} NAME_WE)
        add_executable(${lwe} ${parpackexample_DIR}/${l} )
        target_link_libraries(${lwe} parpack arpack  ${MPI_Fortran_LIBRARIES})
    endforeach()
endfunction(pexamples)

if(BLAS_LIB_USE STREQUAL "MKL")
  message(STATUS "MKL currently not support, use LAPACK")
  find_package(LAPACK CONFIG REQUIRED)
  list(APPEND BLAS_LIBS lapack blas)
elseif(BLAS_LIB_USE STREQUAL "OpenBLAS")
  find_package(OpenBLAS CONFIG REQUIRED)
  list(APPEND BLAS_LIBS OpenBLAS::OpenBLAS)
else()
  find_package(LAPACK CONFIG REQUIRED)
  list(APPEND BLAS_LIBS lapack blas)
endif()

if (MPI)
    include(FindMPI)
    find_package(MPI REQUIRED)
    include_directories(${MPI_Fortran_INCLUDE_PATH})
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} ${MPI_Fortran_COMPILE_FLAG}")
endif()

#if (SYSTEM_LAPACK)
#    find_package(LAPACK REQUIRED)
#endif()
#if (BLAS_LIBRARIES)
#    set(SYSTEM_LAPACK ON)
#endif()

if (MPI)
    set(parpackutil_DIR ${arpack_SOURCE_DIR}/PARPACK/UTIL/)
    set(parpacksrc_DIR ${arpack_SOURCE_DIR}/PARPACK/SRC/)
endif()

#if (NOT SYSTEM_BLAS)
#    file(GLOB arpackblas_STAT_SRCS blas/*.f)
#endif()
#if (NOT SYSTEM_LAPACK)
#    file(GLOB arpacklapack_STAT_SRCS lapack/*.f)
#endif()
#file(GLOB arpackutil_STAT_SRCS util/*.f)
file(GLOB arpacksrc_STAT_SRCS SRC/*.f)

set(arpacksrc_ICB "")
if(ICB)
  file(GLOB arpacksrc_ICB SRC/icba*.f90)
endif()

set(arpackutil_STAT_SRCS
    UTIL/icnteq.f
    UTIL/icopy.f
    UTIL/iset.f
    UTIL/iswap.f
    UTIL/ivout.f
    UTIL/second_NONE.f
    UTIL/svout.f
    UTIL/smout.f
    UTIL/dvout.f
    UTIL/dmout.f
    UTIL/cvout.f
    UTIL/cmout.f
    UTIL/zvout.f
    UTIL/zmout.f )


if (MPI)
    file(GLOB parpackutil_STAT_SRCS PARPACK/UTIL/MPI/*.f)
    file(GLOB parpacksrc_STAT_SRCS PARPACK/SRC/MPI/*.f)
endif()

option(ENABLE_STATIC "Static linking (shared otherwise)" ON)
if (ENABLE_STATIC)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  add_library(arpack STATIC ${arpackutil_STAT_SRCS} ${arpacksrc_STAT_SRCS} ${arpacksrc_ICB})
else ()
  add_library(arpack SHARED ${arpackutil_STAT_SRCS} ${arpacksrc_STAT_SRCS} ${arpacksrc_ICB})
endif()

if(ICB)
  install(FILES arpack.h DESTINATION include)
  install(FILES arpack.hpp DESTINATION include)
  target_include_directories(arpack PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)
endif()

target_link_libraries(arpack PUBLIC ${BLAS_LIBS})
set_target_properties(arpack PROPERTIES OUTPUT_NAME arpack${LIBSUFFIX})
set_target_properties(arpack PROPERTIES VERSION 2.0.0)
set_target_properties(arpack PROPERTIES SOVERSION 2)

if (MPI)
  if (ENABLE_STATIC)
    add_library(parpack STATIC ${parpacksrc_STAT_SRCS} ${parpackutil_STAT_SRCS})
  else ()
    add_library(parpack SHARED ${parpacksrc_STAT_SRCS} ${parpackutil_STAT_SRCS})
  endif ()

    target_link_libraries(parpack PUBLIC ${MPI_Fortran_LIBRARIES})
    target_link_libraries(parpack PUBLIC arpack)
    set_target_properties(parpack PROPERTIES OUTPUT_NAME parpack${LIBSUFFIX})
    set_target_properties(parpack PROPERTIES VERSION 2.0.0)
    set_target_properties(parpack PROPERTIES SOVERSION 2)
endif ()

if (INTERFACE64)
    if ("${CMAKE_Fortran_COMPILER_ID}" MATCHES "GNU")
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fdefault-integer-8")
    elseif ("${CMAKE_Fortran_COMPILER_ID}" MATCHES "Intel")
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -i8")
    else ()
      message(WARNING "build script does not know how to make your Fortran compiler use 64-bit integers: set it manually via FFLAGS.")
    endif ()

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DBLASINT=int64_t")
endif ()

if (SYMBOLSUFFIX)
    if ("${CMAKE_Fortran_COMPILER_ID}" MATCHES "GNU")
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -cpp -ffixed-line-length-none")
    elseif ("${CMAKE_Fortran_COMPILER_ID}" MATCHES "Intel")
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fpp -extend-source")
    else ()
      message(WARNING "build script does not know how to enable your Fortran compiler's preprocessor and support for lines longer than 72 characters: set them manually via FFLAGS.")
    endif ()

    set(SCALARFUNS naitr napps naup2 naupd nconv neigh neupd ngets statn saitr sapps saup2 saupd sconv seigt seupd sgets stats getv0 sortc sortr sesrt stqrb)
    set(COMPLEXFUNS, naitr napps naup2 naupd neigh neupd ngets statn getv0 sortc)

    set(BLASFUNS1 axpy copy gemv geqr2 lacpy lae2 lahqr lanhs larnv lartg lascl laset lasrt scal trevc trmm trsen gbmv gbtrf gbtrs gttrf gttrs pttrf pttrs)
    set(BLASFUNS2 dot ger labad laev2 lamch lanst lanv2 lapy2 larf larfg lasr nrm2 orm2r rot steqr swap)
    set(BLASFUNS3 dotc geru unm2r)
    set(BLASFUNS4 COPY LABAD LAMCH LANHS LANV2 LARFG ROT GEMV)
    set(BLASFUNS5 scnrm2 dznrm2 csscal zdscal)

    foreach (f IN LISTS SCALARFUNS BLASFUNS1 BLASFUNS2)
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -Ds${f}=s${f}${SYMBOLSUFFIX} -Dd${f}=d${f}${SYMBOLSUFFIX}")
    endforeach ()

    foreach (f IN LISTS COMPLEXFUNS BLASFUNS1 BLASFUNS3)
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -Dc${f}=c${f}${SYMBOLSUFFIX} -Dz${f}=z${f}${SYMBOLSUFFIX}")
    endforeach ()

    foreach (f IN LISTS BLASFUNS4)
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -DS${f}=S${f}${SYMBOLSUFFIX} -DD${f}=D${f}${SYMBOLSUFFIX}")
    endforeach ()

    foreach (f IN LISTS BLASFUNS5)
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -D${f}=${f}${SYMBOLSUFFIX}")
    endforeach ()
endif ()

set(CFUNS sgemm snaupd sneupd dnaupd dneupd cheev)
foreach (f IN LISTS CFUNS)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D${f}=${f}${SYMBOLSUFFIX}")
  list(APPEND CFUNS_SUFFIXED ${f}${SYMBOLSUFFIX})
endforeach ()

if(NOT ICB) # With ICB no more need to tweak mangling.
    include(FortranCInterface)
    FortranCInterface_HEADER(FCMangle.h SYMBOLS ${CFUNS_SUFFIXED})
endif()

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DINCLUDE_FCMANGLE")
set(CMAKE_INCLUDE_CURRENT_DIR ON)

############################
# EXAMPLES
############################
if (EXAMPLES)
    ############################
    # EXAMPLES/BAND
    ############################
    set(arpackexample_DIR ${arpack_SOURCE_DIR}/EXAMPLES/BAND/)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/band/)

    set(examples_EXTRA_SRCS ${arpackexample_DIR}/cnband.f)
    set(examples_STAT_SRCS
        cnbdr1.f
        cnbdr2.f
        cnbdr3.f
        cnbdr4.f)
    examples(examples_STAT_SRCS)

    set(examples_EXTRA_SRCS ${arpackexample_DIR}/dnband.f)
    set(examples_STAT_SRCS
        dnbdr1.f
        dnbdr2.f
        dnbdr3.f
        dnbdr4.f
        dnbdr5.f
        dnbdr6.f)
    examples(examples_STAT_SRCS)

    set(examples_EXTRA_SRCS ${arpackexample_DIR}/dsband.f)
    set(examples_STAT_SRCS
        dsbdr1.f
        dsbdr2.f
        dsbdr3.f
        dsbdr4.f
        dsbdr5.f
        dsbdr6.f)
    examples(examples_STAT_SRCS)

    set(examples_EXTRA_SRCS ${arpackexample_DIR}/snband.f)
    set(examples_STAT_SRCS
        snbdr1.f
        snbdr2.f
        snbdr3.f
        snbdr4.f
        snbdr5.f
        snbdr6.f)
    examples(examples_STAT_SRCS)

    set(examples_EXTRA_SRCS ${arpackexample_DIR}/ssband.f)
    set(examples_STAT_SRCS
        ssbdr1.f
        ssbdr2.f
        ssbdr3.f
        ssbdr4.f
        ssbdr5.f
        ssbdr6.f)
    examples(examples_STAT_SRCS)

    set(examples_EXTRA_SRCS ${arpackexample_DIR}/znband.f)
    set(examples_STAT_SRCS
        znbdr1.f
        znbdr2.f
        znbdr3.f
        znbdr4.f)
    examples(examples_STAT_SRCS)
    set(examples_EXTRA_SRCS)

    ############################
    # EXAMPLES/COMPLEX
    ############################
    set(arpackexample_DIR ${arpack_SOURCE_DIR}/EXAMPLES/COMPLEX/)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/complex/)

    set(examples_STAT_SRCS
        cndrv1.f
        cndrv2.f
        cndrv3.f
        cndrv4.f
        zndrv1.f
        zndrv2.f
        zndrv3.f
        zndrv4.f)
    examples(examples_STAT_SRCS)

    ############################
    # examples/nonsym
    ############################
    set(arpackexample_DIR ${arpack_SOURCE_DIR}/EXAMPLES/NONSYM/)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/nonsym/)

    set(examples_STAT_SRCS
        dndrv1.f
        dndrv2.f
        dndrv3.f
        dndrv4.f
        dndrv5.f
        dndrv6.f
        sndrv1.f
        sndrv2.f
        sndrv3.f
        sndrv4.f
        sndrv5.f
        sndrv6.f)
    examples(examples_STAT_SRCS)

    ############################
    # examples/SIMPLE
    ############################
    set(arpackexample_DIR ${arpack_SOURCE_DIR}/EXAMPLES/SIMPLE/)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/simple/)

    set(examples_STAT_SRCS
        cnsimp.f
        dnsimp.f
        dssimp.f
        snsimp.f
        sssimp.f
        znsimp.f)

    examples(examples_STAT_SRCS)

    ############################
    # examples/svd
    ############################
    set(arpackexample_DIR ${arpack_SOURCE_DIR}/EXAMPLES/SVD/)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/svd/)

    set(examples_STAT_SRCS
        ssvd.f)

    examples(examples_STAT_SRCS)

    ############################
    # examples/sym
    ############################
    set(arpackexample_DIR ${arpack_SOURCE_DIR}/EXAMPLES/SYM/)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/sym/)

    set(examples_STAT_SRCS
        dsdrv1.f
        dsdrv2.f
        dsdrv3.f
        dsdrv4.f
        dsdrv5.f
        dsdrv6.f
        ssdrv1.f
        ssdrv2.f
        ssdrv3.f
        ssdrv4.f
        ssdrv5.f
        ssdrv6.f)

    examples(examples_STAT_SRCS)

    ############################
    # parpack/examples
    ############################
    if (MPI)
        set(parpackexample_DIR ${arpack_SOURCE_DIR}/PARPACK/EXAMPLES/MPI/)
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Examples/parpack)

        set(pexamples_STAT_SRCS
            pcndrv1.f
            pdndrv1.f
            pdndrv3.f
            pdsdrv1.f
            psndrv1.f
            psndrv3.f
            pssdrv1.f
            pzndrv1.f)

        pexamples(pexamples_STAT_SRCS)
    endif()
endif()


############################
# CHECK
############################

enable_testing()

set(CMAKE_CTEST_COMMAND ctest -V)

add_custom_target(check COMMAND ${CMAKE_CTEST_COMMAND})

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Tests)

add_executable(dnsimp_test EXCLUDE_FROM_ALL TESTS/dnsimp.f TESTS/mmio.f TESTS/debug.h)
set_target_properties( dnsimp_test PROPERTIES OUTPUT_NAME  dnsimp )
target_link_libraries(dnsimp_test arpack)
add_custom_command(TARGET dnsimp_test POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/TESTS/testA.mtx testA.mtx
)
add_test(dnsimp_test Tests/dnsimp)

add_executable(bug_1315_single EXCLUDE_FROM_ALL TESTS/bug_1315_single.c)
target_link_libraries(bug_1315_single arpack)
add_test(bug_1315_single Tests/bug_1315_single)

add_executable(bug_1315_double EXCLUDE_FROM_ALL TESTS/bug_1315_double.c)
target_link_libraries(bug_1315_double arpack)
add_test(bug_1315_double Tests/bug_1315_double)

add_executable(bug_1323 EXCLUDE_FROM_ALL TESTS/bug_1323.f)
target_link_libraries(bug_1323 arpack)
add_test(bug_1323 Tests/bug_1323)

add_executable(bug_58_double EXCLUDE_FROM_ALL TESTS/bug_58_double.f)
target_link_libraries(bug_58_double arpack)
add_test(bug_58_double Tests/bug_58_double)

add_dependencies(check dnsimp_test bug_1315_single bug_1315_double bug_1323 bug_58_double)

if(MPI)
  add_executable(issue46 PARPACK/TESTS/MPI/issue46.f)
  target_link_libraries(issue46 parpack arpack)
  add_test(issue46 Tests/issue46)
endif()

if(ICB)
  add_executable(icb_arpack_c TESTS/icb_arpack_c.c)
  target_include_directories(icb_arpack_c PUBLIC ..)
  target_link_libraries(icb_arpack_c arpack)
  add_test(icb_arpack_c Tests/icb_arpack_c)

  enable_language(CXX) # For testing binding with c++.
  add_executable(icb_arpack_cpp TESTS/icb_arpack_cpp.cpp)
  target_include_directories(icb_arpack_cpp PUBLIC ..)
  target_link_libraries(icb_arpack_cpp arpack)
  add_test(icb_arpack_cpp Tests/icb_arpack_cpp)
endif()

############################
# install
############################
# 'make install' to the correct location
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Convert variable names to those expected by the .pc file.
set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix \${prefix})
set(libdir \${exec_prefix}/${CMAKE_INSTALL_LIBDIR})
set(PACKAGE_NAME ${PROJECT_NAME})
set(targets_export_name "${PROJECT_NAME}-targets")
set(namespace           "${PROJECT_NAME}::")
set(config_install_dir  "lib/cmake/arpack-ng")
# TODO: Fill these in with something appropriate.
#set(PACKAGE_VERSION)
#set(PACKAGE_URL)
#set(LAPACK_LIBS)
#set(BLAS_LIBS)
configure_file(arpack.pc.in arpack${LIBSUFFIX}.pc @ONLY)

#install(FILES ${CMAKE_CURRENT_BINARY_DIR}/arpack${LIBSUFFIX}.pc
#    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

install(TARGETS arpack
    EXPORT "${targets_export_name}"
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

if (MPI)
  install(TARGETS parpack
      EXPORT "${targets_export_name}"
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif ()

install(
    EXPORT      "${targets_export_name}"
    NAMESPACE   "${namespace}"
    DESTINATION "${config_install_dir}"
)

# Provide find_package for arpack-ng to users.
configure_package_config_file(
    arpack-ng-config.cmake.in 
    "${PROJECT_BINARY_DIR}/arpack-ng-config.cmake" 
    INSTALL_DESTINATION "${config_install_dir}"
)
install(FILES "${PROJECT_BINARY_DIR}/arpack-ng-config.cmake" DESTINATION "${config_install_dir}") # find_package(arpack-ng)
set(arpack_ng_MAJOR_VERSION 3)
set(arpack_ng_MINOR_VERSION 6)
set(arpack_ng_PATCH_VERSION 0)
set(arpack_ng_VERSION ${arpack_ng_MAJOR_VERSION}.${arpack_ng_MINOR_VERSION}.${arpack_ng_PATCH_VERSION})
configure_file(arpack-ng-config-version.cmake.in "${PROJECT_BINARY_DIR}/arpack-ng-config-version.cmake" @ONLY)
install(FILES "${PROJECT_BINARY_DIR}/arpack-ng-config-version.cmake" DESTINATION "${config_install_dir}")

# Packaging: ease arpack-ng distribution (precompiled binaries and sources tarballs).
set(CPACK_VERSION_MAJOR "${arpack_ng_MAJOR_VERSION}")
set(CPACK_VERSION_MINOR "${arpack_ng_MINOR_VERSION}")
set(CPACK_VERSION_PATCH "${arpack_ng_PATCH_VERSION}")
set(CPACK_SOURCE_IGNORE_FILES "/BUILD/" "/Build/" "/build/" "/local/") # Do not ship (eventual) build or install directories in tarballs.
set(CPACK_SOURCE_PACKAGE_FILE_NAME "arpack-ng-${CPACK_VERSION_MAJOR}.${CPACK_VERSION_MINOR}.${CPACK_VERSION_PATCH}")
include(CPack)
