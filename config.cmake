# hunter_config(LAPACK
#   VERSION ${HUNTER_LAPACK_VERSION}
#   CMAKE_ARGS 
#     BUILD_SHARED_LIBS=OFF
#     CMAKE_POSITION_INDEPENDENT_CODE=ON
# )
hunter_config(OpenBLAS
    VERSION ${HUNTER_OpenBLAS_VERSION}
    CMAKE_ARGS
        NOFORTRAN=OFF
)
