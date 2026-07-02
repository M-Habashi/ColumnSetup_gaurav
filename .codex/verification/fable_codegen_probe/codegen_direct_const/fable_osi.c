/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * fable_osi.c
 *
 * Code generation for function 'fable_osi'
 *
 */

/* Include files */
#include "fable_osi.h"
#include "SortedBuffer.h"
#include "abs.h"
#include "allOrAny.h"
#include "angle.h"
#include "any.h"
#include "assertCompatibleDims.h"
#include "div.h"
#include "eml_int_forloop_overflow_check.h"
#include "exp.h"
#include "fable_osi_data.h"
#include "fable_osi_emxutil.h"
#include "fable_osi_internal_types.h"
#include "fable_osi_types.h"
#include "log.h"
#include "mean.h"
#include "median.h"
#include "mldivide.h"
#include "mod.h"
#include "movmax.h"
#include "mtimes.h"
#include "nnz.h"
#include "rt_nonfinite.h"
#include "sqrt.h"
#include "sumMatrixIncludeNaN.h"
#include "vmedian.h"
#include "mwmathutil.h"
#include "omp.h"
#include <emmintrin.h>
#include <string.h>

/* Variable Definitions */
static emlrtRSInfo emlrtRSI = { 70,    /* lineNo */
  "fable_osi",                         /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo b_emlrtRSI = { 339, /* lineNo */
  "stepHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo c_emlrtRSI = { 340, /* lineNo */
  "stepHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo d_emlrtRSI = { 352, /* lineNo */
  "stepHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo e_emlrtRSI = { 356, /* lineNo */
  "stepHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo f_emlrtRSI = { 926, /* lineNo */
  "detrendLinear",                     /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo v_emlrtRSI = { 94,  /* lineNo */
  "eml_mtimes_helper",                 /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\ops\\eml_mtimes_helper.m"/* pathName */
};

static emlrtRSInfo y_emlrtRSI = { 63,  /* lineNo */
  "fft",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\fft.m"/* pathName */
};

static emlrtRSInfo ab_emlrtRSI = { 42, /* lineNo */
  "fft",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\+fft\\fft.m"/* pathName */
};

static emlrtRSInfo gb_emlrtRSI = { 389,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo hb_emlrtRSI = { 390,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ib_emlrtRSI = { 403,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo jb_emlrtRSI = { 404,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo kb_emlrtRSI = { 405,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo lb_emlrtRSI = { 406,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo mb_emlrtRSI = { 410,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo nb_emlrtRSI = { 419,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ob_emlrtRSI = { 421,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo pb_emlrtRSI = { 479,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo qb_emlrtRSI = { 482,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo rb_emlrtRSI = { 493,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo sb_emlrtRSI = { 509,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo tb_emlrtRSI = { 514,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ub_emlrtRSI = { 516,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo vb_emlrtRSI = { 531,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo wb_emlrtRSI = { 544,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo xb_emlrtRSI = { 545,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo yb_emlrtRSI = { 548,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ac_emlrtRSI = { 549,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo bc_emlrtRSI = { 572,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo cc_emlrtRSI = { 592,/* lineNo */
  "slowHop",                           /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo nc_emlrtRSI = { 44, /* lineNo */
  "mpower",                            /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\matfun\\mpower.m"/* pathName */
};

static emlrtRSInfo oc_emlrtRSI = { 71, /* lineNo */
  "power",                             /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\ops\\power.m"/* pathName */
};

static emlrtRSInfo ld_emlrtRSI = { 783,/* lineNo */
  "fastQuietPower",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo md_emlrtRSI = { 791,/* lineNo */
  "fastQuietPower",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo nd_emlrtRSI = { 13, /* lineNo */
  "all",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\ops\\all.m"/* pathName */
};

static emlrtRSInfo od_emlrtRSI = { 143,/* lineNo */
  "allOrAny",                          /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\allOrAny.m"/* pathName */
};

static emlrtRSInfo pd_emlrtRSI = { 20, /* lineNo */
  "sum",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\sum.m"/* pathName */
};

static emlrtRSInfo qd_emlrtRSI = { 99, /* lineNo */
  "sumprod",                           /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\private\\sumprod.m"/* pathName */
};

static emlrtRSInfo xd_emlrtRSI = { 910,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo yd_emlrtRSI = { 908,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ae_emlrtRSI = { 895,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo be_emlrtRSI = { 893,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ce_emlrtRSI = { 892,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo de_emlrtRSI = { 885,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ee_emlrtRSI = { 883,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo fe_emlrtRSI = { 882,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ge_emlrtRSI = { 880,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo he_emlrtRSI = { 879,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ie_emlrtRSI = { 867,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo je_emlrtRSI = { 866,/* lineNo */
  "finalizeCalibration",               /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo oe_emlrtRSI = { 19, /* lineNo */
  "abs",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\elfun\\abs.m"/* pathName */
};

static emlrtRSInfo pe_emlrtRSI = { 82, /* lineNo */
  "applyScalarFunction",               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\applyScalarFunction.m"/* pathName */
};

static emlrtRSInfo qe_emlrtRSI = { 77, /* lineNo */
  "median",                            /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\median.m"/* pathName */
};

static emlrtRSInfo re_emlrtRSI = { 106,/* lineNo */
  "applyToMultipleDims",               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\applyToMultipleDims.m"/* pathName */
};

static emlrtRSInfo se_emlrtRSI = { 76, /* lineNo */
  "@(x)median(x,coder.internal.indexInt(1),\'i\')",/* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\median.m"/* pathName */
};

static emlrtRSInfo te_emlrtRSI = { 17, /* lineNo */
  "log",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\elfun\\log.m"/* pathName */
};

static emlrtRSInfo ue_emlrtRSI = { 44, /* lineNo */
  "applyScalarFunctionInPlace",        /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\applyScalarFunctionInPlace.m"/* pathName */
};

static emlrtRSInfo ve_emlrtRSI = { 932,/* lineNo */
  "maskedMovMedian",                   /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo we_emlrtRSI = { 10, /* lineNo */
  "movmedian",                         /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\movmedian.m"/* pathName */
};

static emlrtRSInfo xe_emlrtRSI = { 159,/* lineNo */
  "dispatch",                          /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\private\\movfunDispatch.m"/* pathName */
};

static emlrtRSInfo ye_emlrtRSI = { 808,/* lineNo */
  "residualBranch",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo af_emlrtRSI = { 810,/* lineNo */
  "residualBranch",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo bf_emlrtRSI = { 811,/* lineNo */
  "residualBranch",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo cf_emlrtRSI = { 822,/* lineNo */
  "residualBranch",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo df_emlrtRSI = { 850,/* lineNo */
  "residualBranch",                    /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo gf_emlrtRSI = { 34, /* lineNo */
  "rdivide_helper",                    /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\rdivide_helper.m"/* pathName */
};

static emlrtRSInfo hf_emlrtRSI = { 53, /* lineNo */
  "div",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\div.m"/* pathName */
};

static emlrtRSInfo jf_emlrtRSI = { 15, /* lineNo */
  "min",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\min.m"/* pathName */
};

static emlrtRSInfo kf_emlrtRSI = { 75, /* lineNo */
  "minOrMax",                          /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\minOrMax.m"/* pathName */
};

static emlrtRSInfo lf_emlrtRSI = { 121,/* lineNo */
  "minimum",                           /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\minOrMax.m"/* pathName */
};

static emlrtRSInfo nf_emlrtRSI = { 620,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo of_emlrtRSI = { 641,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo pf_emlrtRSI = { 642,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo qf_emlrtRSI = { 647,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo rf_emlrtRSI = { 648,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo sf_emlrtRSI = { 673,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo tf_emlrtRSI = { 674,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo uf_emlrtRSI = { 679,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo vf_emlrtRSI = { 680,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo wf_emlrtRSI = { 681,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo xf_emlrtRSI = { 691,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo yf_emlrtRSI = { 711,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo ag_emlrtRSI = { 718,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo bg_emlrtRSI = { 739,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo cg_emlrtRSI = { 742,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo dg_emlrtRSI = { 744,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo eg_emlrtRSI = { 746,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo fg_emlrtRSI = { 755,/* lineNo */
  "fastPath",                          /* fcnName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pathName */
};

static emlrtRSInfo hg_emlrtRSI = { 15, /* lineNo */
  "max",                               /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\max.m"/* pathName */
};

static emlrtRSInfo ig_emlrtRSI = { 73, /* lineNo */
  "minOrMax",                          /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\minOrMax.m"/* pathName */
};

static emlrtRSInfo jg_emlrtRSI = { 108,/* lineNo */
  "maximum",                           /* fcnName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\minOrMax.m"/* pathName */
};

static emlrtDCInfo emlrtDCI = { 344,   /* lineNo */
  15,                                  /* colNo */
  "stepHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo emlrtBCI = { 1,     /* iFirst */
  3,                                   /* iLast */
  344,                                 /* lineNo */
  15,                                  /* colNo */
  "state.fSuu",                        /* aName */
  "stepHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo b_emlrtDCI = { 345, /* lineNo */
  15,                                  /* colNo */
  "stepHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo b_emlrtBCI = { 1,   /* iFirst */
  3,                                   /* iLast */
  345,                                 /* lineNo */
  15,                                  /* colNo */
  "state.fSyy",                        /* aName */
  "stepHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo c_emlrtDCI = { 346, /* lineNo */
  15,                                  /* colNo */
  "stepHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo c_emlrtBCI = { 1,   /* iFirst */
  3,                                   /* iLast */
  346,                                 /* lineNo */
  15,                                  /* colNo */
  "state.fSuy",                        /* aName */
  "stepHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo d_emlrtDCI = { 791, /* lineNo */
  40,                                  /* colNo */
  "fastQuietPower",                    /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo d_emlrtBCI = { 1,   /* iFirst */
  3,                                   /* iLast */
  791,                                 /* lineNo */
  40,                                  /* colNo */
  "state.fSyy",                        /* aName */
  "fastQuietPower",                    /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtRTEInfo i_emlrtRTEI = { 198,/* lineNo */
  27,                                  /* colNo */
  "unaryMinOrMax",                     /* fName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\unaryMinOrMax.m"/* pName */
};

static emlrtECInfo emlrtECI = { -1,    /* nDims */
  544,                                 /* lineNo */
  5,                                   /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtBCInfo e_emlrtBCI = { 1,   /* iFirst */
  80,                                  /* iLast */
  489,                                 /* lineNo */
  23,                                  /* colNo */
  "state.cal_med",                     /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo e_emlrtDCI = { 489, /* lineNo */
  23,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo f_emlrtBCI = { 1,   /* iFirst */
  80,                                  /* iLast */
  488,                                 /* lineNo */
  26,                                  /* colNo */
  "state.cal_res",                     /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo f_emlrtDCI = { 488, /* lineNo */
  26,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo g_emlrtBCI = { 1,   /* iFirst */
  80,                                  /* iLast */
  482,                                 /* lineNo */
  42,                                  /* colNo */
  "state.cal_med",                     /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtDCInfo g_emlrtDCI = { 482, /* lineNo */
  42,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo h_emlrtBCI = { 1,   /* iFirst */
  17,                                  /* iLast */
  396,                                 /* lineNo */
  18,                                  /* colNo */
  "state.Suy_seg",                     /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo h_emlrtDCI = { 396, /* lineNo */
  18,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo i_emlrtBCI = { 1,   /* iFirst */
  17,                                  /* iLast */
  395,                                 /* lineNo */
  18,                                  /* colNo */
  "state.Syy_seg",                     /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo i_emlrtDCI = { 395, /* lineNo */
  18,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo j_emlrtBCI = { 1,   /* iFirst */
  17,                                  /* iLast */
  394,                                 /* lineNo */
  18,                                  /* colNo */
  "state.Suu_seg",                     /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo j_emlrtDCI = { 394, /* lineNo */
  18,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo k_emlrtBCI = { 1,   /* iFirst */
  80,                                  /* iLast */
  492,                                 /* lineNo */
  25,                                  /* colNo */
  "state.cal_pf",                      /* aName */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo k_emlrtDCI = { 492, /* lineNo */
  25,                                  /* colNo */
  "slowHop",                           /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo l_emlrtBCI = { 1,   /* iFirst */
  320,                                 /* iLast */
  907,                                 /* lineNo */
  24,                                  /* colNo */
  "state.cal_d",                       /* aName */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtDCInfo l_emlrtDCI = { 907, /* lineNo */
  24,                                  /* colNo */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo m_emlrtBCI = { 1,   /* iFirst */
  80,                                  /* iLast */
  889,                                 /* lineNo */
  28,                                  /* colNo */
  "state.cal_pf",                      /* aName */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtBCInfo n_emlrtBCI = { -1,  /* iFirst */
  -1,                                  /* iLast */
  880,                                 /* lineNo */
  13,                                  /* colNo */
  "logq",                              /* aName */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtBCInfo o_emlrtBCI = { -1,  /* iFirst */
  -1,                                  /* iLast */
  874,                                 /* lineNo */
  20,                                  /* colNo */
  "cal",                               /* aName */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtRTEInfo k_emlrtRTEI = { 873,/* lineNo */
  9,                                   /* colNo */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtBCInfo p_emlrtBCI = { 1,   /* iFirst */
  80,                                  /* iLast */
  865,                                 /* lineNo */
  26,                                  /* colNo */
  "state.cal_res",                     /* aName */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtDCInfo m_emlrtDCI = { 865, /* lineNo */
  26,                                  /* colNo */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtDCInfo n_emlrtDCI = { 872, /* lineNo */
  22,                                  /* colNo */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtDCInfo o_emlrtDCI = { 872, /* lineNo */
  22,                                  /* colNo */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  4                                    /* checkKind */
};

static emlrtBCInfo q_emlrtBCI = { -1,  /* iFirst */
  -1,                                  /* iLast */
  890,                                 /* lineNo */
  13,                                  /* colNo */
  "pf",                                /* aName */
  "finalizeCalibration",               /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtBCInfo r_emlrtBCI = { 1,   /* iFirst */
  3,                                   /* iLast */
  671,                                 /* lineNo */
  30,                                  /* colNo */
  "state.fSuy",                        /* aName */
  "fastPath",                          /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtDCInfo p_emlrtDCI = { 671, /* lineNo */
  30,                                  /* colNo */
  "fastPath",                          /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo s_emlrtBCI = { 1,   /* iFirst */
  3,                                   /* iLast */
  657,                                 /* lineNo */
  26,                                  /* colNo */
  "state.fSuu",                        /* aName */
  "fastPath",                          /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  0                                    /* checkKind */
};

static emlrtDCInfo q_emlrtDCI = { 657, /* lineNo */
  26,                                  /* colNo */
  "fastPath",                          /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtBCInfo t_emlrtBCI = { 1,   /* iFirst */
  320,                                 /* iLast */
  691,                                 /* lineNo */
  21,                                  /* colNo */
  "state.cal_d",                       /* aName */
  "fastPath",                          /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  3                                    /* checkKind */
};

static emlrtDCInfo r_emlrtDCI = { 691, /* lineNo */
  21,                                  /* colNo */
  "fastPath",                          /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m",                         /* pName */
  1                                    /* checkKind */
};

static emlrtRTEInfo r_emlrtRTEI = { 30,/* lineNo */
  21,                                  /* colNo */
  "applyScalarFunction",               /* fName */
  "C:\\Program Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\applyScalarFunction.m"/* pName */
};

static emlrtRTEInfo u_emlrtRTEI = { 872,/* lineNo */
  8,                                   /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtRTEInfo v_emlrtRTEI = { 883,/* lineNo */
  11,                                  /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtRTEInfo w_emlrtRTEI = { 885,/* lineNo */
  19,                                  /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtRTEInfo x_emlrtRTEI = { 872,/* lineNo */
  1,                                   /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtRTEInfo y_emlrtRTEI = { 883,/* lineNo */
  1,                                   /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtRTEInfo ab_emlrtRTEI = { 863,/* lineNo */
  18,                                  /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static emlrtRTEInfo bb_emlrtRTEI = { 798,/* lineNo */
  41,                                  /* colNo */
  "fable_osi",                         /* fName */
  "C:\\Users\\Victus\\Desktop\\folder_working\\a purdue\\aa reasearch\\Gaurav Setup\\ColumnSetup_gaurav\\main\\OSI_tests\\fable\\fa"
  "ble_osi.m"                          /* pName */
};

static const real_T dv[25] = { 0.049999999999999989, 0.0641784421056258,
  0.082377448622103278, 0.10573712634405641, 0.13572088082974532,
  0.17420709385712702, 0.22360679774997896, 0.28701471847642812,
  0.36840314986403866, 0.47287080450158792, 0.60696223100291724,
  0.779077808054444, 1.0, 1.2835688421125162, 1.6475489724420658,
  2.1147425268811282, 2.7144176165949068, 3.4841418771425405, 4.47213595499958,
  5.7402943695285629, 7.3680629972807736, 9.4574160900317583, 12.139244620058346,
  15.581556161088884, 20.000000000000004 };

static const int8_T iv[25] = { 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52,
  56, 60, 64, 68, 72, 76, 80, 84, 88, 92, 96, 99 };

static const boolean_T bv[25] = { true, true, true, true, true, true, true, true,
  true, true, true, true, true, true, false, true, true, true, true, true, true,
  true, true, true, true };

static const boolean_T bv1[99] = { false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, true, true,
  true, true, true, true, true, true, true, true, true, true, true, true, true,
  true, true, true, true, true, true, true, true, true, true, true, true, true,
  true, true, false, false, false, false, false, true, true, true, true, true,
  true, true, true, true, true, true, true, true, true, true, true, true, true,
  true, true, true, true, true, true, true, true, true, true, true, true, true,
  true, true, true, true, true, true, true };

static const int8_T iv1[94] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
  15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34,
  35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
  55, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
  80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98 };

/* Function Declarations */
static void b_maskedMovMedian(const emlrtStack *sp, const real_T x[25], const
  boolean_T mask[25], real_T y[25]);
static real_T binary_expand_op_1(const emlrtStack *sp, const emlrtRSInfo in1,
  const real_T in2_data[], const int32_T *in2_size, const real_T in3_data[],
  const int32_T *in3_size);
static real_T fastPath(const emlrtStack *sp, struct1_T *state, boolean_T
  *fast_trip, real_T *trip_reason, real_T *z_pf);
static void fastQuietPower(const emlrtStack *sp, const real_T state_fSyy[75],
  real_T state_fseg_count, real_T state_fring_pos, const boolean_T qpmask[99],
  real_T p[5]);
static void finalizeCalibration(const emlrtStack *sp, struct1_T *state, const
  boolean_T quiet[99]);
static void maskedMovMedian(const emlrtStack *sp, const real_T x[99], const
  boolean_T mask[99], real_T y[99]);
static real_T residualBranch(const emlrtStack *sp, struct1_T *state, const
  real_T res[99], const boolean_T quiet[99], real_T *f_res, real_T *z_max);
static void slowHop(const emlrtStack *sp, struct1_T *state);

/* Function Definitions */
static void b_maskedMovMedian(const emlrtStack *sp, const real_T x[25], const
  boolean_T mask[25], real_T y[25])
{
  b_coder_internal_SortedBuffer s;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack h_st;
  emlrtStack i_st;
  emlrtStack j_st;
  emlrtStack st;
  real_T xm[25];
  real_T d;
  int32_T i;
  int32_T mid;
  int32_T trueCount;
  int8_T b_tmp_data[25];
  int8_T tmp_data[25];
  int8_T b_i;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  f_st.prev = &e_st;
  f_st.tls = e_st.tls;
  g_st.prev = &f_st;
  g_st.tls = f_st.tls;
  h_st.prev = &g_st;
  h_st.tls = g_st.tls;
  i_st.prev = &h_st;
  i_st.tls = h_st.tls;
  j_st.prev = &i_st;
  j_st.tls = i_st.tls;
  trueCount = 0;
  mid = 0;
  for (i = 0; i < 25; i++) {
    xm[i] = x[i];
    if (!mask[i]) {
      trueCount++;
      tmp_data[mid] = (int8_T)i;
      mid++;
    }
  }

  for (i = 0; i < trueCount; i++) {
    xm[tmp_data[i]] = rtNaN;
  }

  st.site = &ve_emlrtRSI;
  b_st.site = &we_emlrtRSI;
  c_st.site = &qc_emlrtRSI;
  d_st.site = &xe_emlrtRSI;
  e_st.site = &sc_emlrtRSI;
  f_st.site = &tc_emlrtRSI;
  memset(&y[0], 0, 25U * sizeof(real_T));
  g_st.site = &uc_emlrtRSI;
  h_st.site = &gc_emlrtRSI;
  i_st.site = &vc_emlrtRSI;
  s.buf[0] = 0.0;
  s.buf[1] = 0.0;
  s.buf[2] = 0.0;
  s.nbuf = 0;
  j_st.site = &wc_emlrtRSI;
  b_SortedBuffer_insert(&j_st, &s, xm[0]);
  j_st.site = &wc_emlrtRSI;
  b_SortedBuffer_insert(&j_st, &s, xm[1]);
  if (s.nbuf == 0) {
    y[0] = rtNaN;
  } else {
    mid = s.nbuf >> 1;
    if (((uint32_T)s.nbuf & 1U) == 1U) {
      y[0] = s.buf[mid];
    } else {
      d = s.buf[mid - 1];
      if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
        y[0] = (d + s.buf[mid]) / 2.0;
      } else {
        y[0] = d + (s.buf[mid] - d) / 2.0;
      }
    }
  }

  j_st.site = &xc_emlrtRSI;
  b_SortedBuffer_insert(&j_st, &s, xm[2]);
  if (s.nbuf == 0) {
    y[1] = rtNaN;
  } else {
    mid = s.nbuf >> 1;
    if (((uint32_T)s.nbuf & 1U) == 1U) {
      y[1] = s.buf[mid];
    } else {
      d = s.buf[mid - 1];
      if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
        y[1] = (d + s.buf[mid]) / 2.0;
      } else {
        y[1] = d + (s.buf[mid] - d) / 2.0;
      }
    }
  }

  for (i = 0; i < 22; i++) {
    j_st.site = &yc_emlrtRSI;
    SortedBuffer_replace(&j_st, &s, xm[i], xm[i + 3]);
    if (s.nbuf == 0) {
      y[i + 2] = rtNaN;
    } else {
      mid = s.nbuf >> 1;
      if (((uint32_T)s.nbuf & 1U) == 1U) {
        y[i + 2] = s.buf[mid];
      } else {
        d = s.buf[mid - 1];
        if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
          y[i + 2] = (d + s.buf[mid]) / 2.0;
        } else {
          y[i + 2] = d + (s.buf[mid] - d) / 2.0;
        }
      }
    }
  }

  j_st.site = &ad_emlrtRSI;
  b_SortedBuffer_remove(&j_st, &s, xm[22]);
  if (s.nbuf == 0) {
    y[24] = rtNaN;
  } else {
    mid = s.nbuf >> 1;
    if (((uint32_T)s.nbuf & 1U) == 1U) {
      y[24] = s.buf[mid];
    } else {
      d = s.buf[mid - 1];
      if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
        y[24] = (d + s.buf[mid]) / 2.0;
      } else {
        y[24] = d + (s.buf[mid] - d) / 2.0;
      }
    }
  }

  for (i = 0; i < trueCount; i++) {
    b_i = tmp_data[i];
    y[b_i] = x[b_i];
  }

  trueCount = 0;
  mid = 0;
  for (i = 0; i < 25; i++) {
    if (muDoubleScalarIsNaN(y[i]) && mask[i]) {
      trueCount++;
      b_tmp_data[mid] = (int8_T)i;
      mid++;
    }
  }

  for (i = 0; i < trueCount; i++) {
    b_i = b_tmp_data[i];
    y[b_i] = x[b_i];
  }
}

static real_T binary_expand_op_1(const emlrtStack *sp, const emlrtRSInfo in1,
  const real_T in2_data[], const int32_T *in2_size, const real_T in3_data[],
  const int32_T *in3_size)
{
  emlrtStack st;
  real_T b_in2_data[99];
  int32_T i;
  int32_T loop_ub;
  int32_T stride_0_0;
  int32_T stride_1_0;
  st.prev = sp;
  st.tls = sp->tls;
  if (*in3_size == 1) {
    loop_ub = *in2_size;
  } else {
    loop_ub = *in3_size;
  }

  stride_0_0 = (*in2_size != 1);
  stride_1_0 = (*in3_size != 1);
  for (i = 0; i < loop_ub; i++) {
    b_in2_data[i] = in2_data[i * stride_0_0] / in3_data[i * stride_1_0];
  }

  st.site = (emlrtRSInfo *)&in1;
  return c_median(&st, b_in2_data, loop_ub);
}

static real_T fastPath(const emlrtStack *sp, struct1_T *state, boolean_T
  *fast_trip, real_T *trip_reason, real_T *z_pf)
{
  static const int8_T b_iv[24] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24 };

  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack st;
  real_T a_data[99];
  real_T Suu[25];
  real_T maxval[25];
  real_T y[25];
  real_T b_dv[2];
  real_T b_dv1[2];
  real_T b_fast;
  int32_T a_size;
  int32_T b_i;
  int32_T i;
  int32_T maxval_size;
  int8_T b_tmp_data[25];
  int8_T tmp_data[5];
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;

  /*  -------------------------------------------------------------- fast path */
  b_fast = rtNaN;
  *fast_trip = false;
  *trip_reason = 0.0;
  *z_pf = rtNaN;
  if ((state->update_count <= 4.0) || (state->fseg_count < 3.0)) {
    state->cus_st = 0.0;
    for (i = 0; i < 5; i++) {
      state->cus_burst[i] = 0.0;
    }
  } else {
    __m128d r;
    __m128d r1;
    real_T d_raw;
    real_T p_in_new;
    real_T tiny1;
    int32_T b_state;
    int32_T idx;
    int8_T c_i;
    boolean_T state_data[99];
    boolean_T exc_f[25];
    boolean_T burst_trip;
    boolean_T exitg1;
    boolean_T st_trip;

    /*  masks projected from the slow path onto the fast grid */
    for (b_i = 0; b_i < 25; b_i++) {
      b_state = b_i << 2;
      c_i = iv[b_i];
      if (b_state + 1 > c_i) {
        b_state = 0;
        idx = 0;
      } else {
        idx = c_i;
      }

      idx -= b_state;
      for (i = 0; i < idx; i++) {
        state_data[i] = state->sb_excited[b_state + i];
      }

      st.site = &nf_emlrtRSI;
      exc_f[b_i] = any(state_data, idx);
      if (*emlrtBreakCheckR2012bFlagVar != 0) {
        emlrtBreakCheckR2012b((emlrtConstCTX)sp);
      }
    }

    for (i = 0; i < 25; i++) {
      exc_f[i] = (exc_f[i] && bv[i]);
    }

    /*  ---- fast ST margin + pooled FRF-change statistic ------------------------ */
    /*  The chordal margin from ~0.5 s of data is too noisy to separate a real */
    /*  deficit from its own floor - but the FRF DISPLACEMENT pooled across all */
    /*  observed bins concentrates: d = median_bins |T_new - T_slow|^2/|T_slow|^2 */
    /*  jumps by an order of magnitude on a plant change. It is computed on the */
    /*  NEWEST segment alone (one segment of latency, the pooling supplies the */
    /*  averaging), z-scored against its own calibrated healthy spread, and */
    /*  guarded by direction (fast margin below the slow one), so a */
    /*  margin-improving change does not trip. */
    d_raw = rtNaN;
    if (state->sb_stvalid) {
      real_T local_max[25];
      real_T d_state[24];
      real_T br;
      real_T tiny;
      boolean_T mask[25];

      /*  ring-median fast margin (for reporting, direction and trip sizing) */
      f_median(state->fSuu, Suu);
      st_trip = !muDoubleScalarIsNaN(Suu[0]);
      if (st_trip) {
        idx = 1;
      } else {
        idx = 0;
        b_state = 2;
        exitg1 = false;
        while ((!exitg1) && (b_state < 26)) {
          if (!muDoubleScalarIsNaN(Suu[b_state - 1])) {
            idx = b_state;
            exitg1 = true;
          } else {
            b_state++;
          }
        }
      }

      if (idx == 0) {
        p_in_new = Suu[0];
      } else {
        p_in_new = Suu[idx - 1];
        idx++;
        for (i = idx; i < 26; i++) {
          tiny1 = Suu[i - 1];
          if (p_in_new < tiny1) {
            p_in_new = tiny1;
          }
        }
      }

      tiny = muDoubleScalarMax(p_in_new, 1.0) * 1.0E-14;
      st.site = &of_emlrtRSI;
      b_st.site = &nc_emlrtRSI;
      c_st.site = &oc_emlrtRSI;
      if (st_trip) {
        idx = 1;
      } else {
        idx = 0;
        b_state = 2;
        exitg1 = false;
        while ((!exitg1) && (b_state < 25)) {
          if (!muDoubleScalarIsNaN(Suu[b_iv[b_state - 1]])) {
            idx = b_state;
            exitg1 = true;
          } else {
            b_state++;
          }
        }
      }

      if (idx == 0) {
        p_in_new = Suu[0];
      } else {
        p_in_new = Suu[b_iv[idx - 1]];
        idx++;
        for (i = idx; i < 25; i++) {
          br = Suu[b_iv[i - 1]];
          if (p_in_new < br) {
            p_in_new = br;
          }
        }
      }

      st.site = &pf_emlrtRSI;
      b_movmax(&st, Suu, local_max);
      p_in_new = muDoubleScalarMax(p_in_new * 0.00031622776601683794, tiny);
      for (i = 0; i < 25; i++) {
        tiny1 = Suu[i];
        mask[i] = (exc_f[i] && (tiny1 > p_in_new) && (tiny1 > local_max[i] *
                    0.0031622776601683794));
      }

      if (b_intnnz(mask) >= 3) {
        real_T c_state[75];
        for (i = 0; i < 25; i++) {
          maxval[i] = muDoubleScalarMax(Suu[i], tiny);
        }

        for (i = 0; i < 75; i++) {
          c_state[i] = state->fSuy[i].re;
        }

        f_median(c_state, local_max);
        for (i = 0; i < 75; i++) {
          c_state[i] = state->fSuy[i].im;
        }

        f_median(c_state, Suu);
        for (i = 0; i < 25; i++) {
          p_in_new = local_max[i];
          tiny1 = Suu[i];
          br = maxval[i];
          if (tiny1 == 0.0) {
            tiny = p_in_new / br;
            p_in_new = 0.0;
          } else if (p_in_new == 0.0) {
            tiny = 0.0;
            p_in_new = tiny1 / br;
          } else {
            tiny = p_in_new / br;
            p_in_new = tiny1 / br;
          }

          tiny1 = muDoubleScalarHypot(1.0 - tiny, 0.0 - p_in_new);
          y[i] = tiny1 * tiny1;
          tiny1 = muDoubleScalarHypot(tiny, p_in_new);
          local_max[i] = tiny1;
          Suu[i] = tiny1 * tiny1;
        }

        st.site = &qf_emlrtRSI;
        for (i = 0; i <= 22; i += 2) {
          r = _mm_loadu_pd(&y[i]);
          r1 = _mm_loadu_pd(&Suu[i]);
          _mm_storeu_pd(&y[i], _mm_add_pd(r, r1));
        }

        y[24] += Suu[24];
        for (i = 0; i <= 22; i += 2) {
          r = _mm_loadu_pd(&y[i]);
          _mm_storeu_pd(&y[i], _mm_sqrt_pd(r));
        }

        y[24] = muDoubleScalarSqrt(y[24]);
        for (i = 0; i <= 22; i += 2) {
          b_dv[0] = muDoubleScalarMax(y[i], 2.2204460492503131E-16);
          b_dv[1] = muDoubleScalarMax(y[i + 1], 2.2204460492503131E-16);
          r = _mm_loadu_pd(&b_dv[0]);
          _mm_storeu_pd(&maxval[i], _mm_div_pd(_mm_set1_pd(1.0), _mm_mul_pd
            (_mm_set1_pd(1.4142135623730951), r)));
        }

        maxval[24] = 1.0 / (1.4142135623730951 * muDoubleScalarMax(y[24],
          2.2204460492503131E-16));
        st.site = &rf_emlrtRSI;
        b_maskedMovMedian(&st, maxval, mask, local_max);
        for (i = 0; i < 25; i++) {
          if (!mask[i]) {
            local_max[i] = rtNaN;
          }
        }

        if (!muDoubleScalarIsNaN(local_max[0])) {
          idx = 1;
        } else {
          idx = 0;
          b_state = 2;
          exitg1 = false;
          while ((!exitg1) && (b_state < 26)) {
            if (!muDoubleScalarIsNaN(local_max[b_state - 1])) {
              idx = b_state;
              exitg1 = true;
            } else {
              b_state++;
            }
          }
        }

        if (idx == 0) {
          p_in_new = local_max[0];
        } else {
          p_in_new = local_max[idx - 1];
          idx++;
          for (i = idx; i < 26; i++) {
            tiny1 = local_max[i - 1];
            if (p_in_new > tiny1) {
              p_in_new = tiny1;
            }
          }
        }

        b_fast = muDoubleScalarMin(0.70710678118654746, p_in_new);
      }

      /*  newest-segment FRF deviation - but only while the COMMAND itself is */
      /*  steady: a fading or bursting input (test phase ending, EQ lull) */
      /*  makes the single-segment FRF garbage, which is not evidence of a */
      /*  plant change. The reference is a ~3 s EMA of the newest-segment */
      /*  in-band input power. */
      if (state->fring_pos != (int32_T)muDoubleScalarFloor(state->fring_pos)) {
        emlrtIntegerCheckR2012b(state->fring_pos, &q_emlrtDCI, (emlrtConstCTX)sp);
      }

      idx = (int32_T)state->fring_pos;
      if ((idx < 1) || (idx > 3)) {
        emlrtDynamicBoundsCheckR2012b(idx, 1, 3, &s_emlrtBCI, (emlrtConstCTX)sp);
      }

      idx = (int32_T)state->fring_pos;
      for (i = 0; i < 24; i++) {
        d_state[i] = state->fSuu[b_iv[i] + 25 * (idx - 1)];
      }

      p_in_new = c_sumColumnB(d_state);
      st_trip = ((!muDoubleScalarIsInf(state->p_in_ema)) &&
                 (!muDoubleScalarIsNaN(state->p_in_ema)));
      if (st_trip && (state->p_in_ema > 0.0) && (p_in_new >= 0.25 *
           state->p_in_ema) && (p_in_new <= 4.0 * state->p_in_ema)) {
        burst_trip = true;
      } else {
        burst_trip = false;
      }

      if (p_in_new > 0.0) {
        if (!st_trip) {
          state->p_in_ema = p_in_new;
        } else {
          state->p_in_ema = 0.96 * state->p_in_ema + 0.04 * p_in_new;
        }
      }

      if (burst_trip) {
        if (state->fring_pos != (int32_T)muDoubleScalarFloor(state->fring_pos))
        {
          emlrtIntegerCheckR2012b(state->fring_pos, &p_emlrtDCI, (emlrtConstCTX)
            sp);
        }

        idx = (int32_T)state->fring_pos;
        if ((idx < 1) || (idx > 3)) {
          emlrtDynamicBoundsCheckR2012b(idx, 1, 3, &r_emlrtBCI, (emlrtConstCTX)
            sp);
        }

        if (!muDoubleScalarIsNaN(state->fSuu[25 * ((int32_T)state->fring_pos - 1)]))
        {
          idx = 1;
        } else {
          idx = 0;
          b_state = 2;
          exitg1 = false;
          while ((!exitg1) && (b_state < 26)) {
            if (!muDoubleScalarIsNaN(state->fSuu[(b_state + 25 * ((int32_T)
                   state->fring_pos - 1)) - 1])) {
              idx = b_state;
              exitg1 = true;
            } else {
              b_state++;
            }
          }
        }

        if (idx == 0) {
          p_in_new = state->fSuu[25 * ((int32_T)state->fring_pos - 1)];
        } else {
          p_in_new = state->fSuu[(idx + 25 * ((int32_T)state->fring_pos - 1)) -
            1];
          idx++;
          for (i = idx; i < 26; i++) {
            if (p_in_new < state->fSuu[(i + 25 * ((int32_T)state->fring_pos - 1))
                - 1]) {
              p_in_new = state->fSuu[(i + 25 * ((int32_T)state->fring_pos - 1))
                - 1];
            }
          }
        }

        tiny1 = muDoubleScalarMax(p_in_new, 1.0) * 1.0E-14;
        st.site = &sf_emlrtRSI;
        b_st.site = &nc_emlrtRSI;
        c_st.site = &oc_emlrtRSI;
        if (!muDoubleScalarIsNaN(state->fSuu[25 * ((int32_T)state->fring_pos - 1)]))
        {
          idx = 1;
        } else {
          idx = 0;
          b_state = 2;
          exitg1 = false;
          while ((!exitg1) && (b_state < 25)) {
            if (!muDoubleScalarIsNaN(state->fSuu[b_iv[b_state - 1] + 25 *
                 ((int32_T)state->fring_pos - 1)])) {
              idx = b_state;
              exitg1 = true;
            } else {
              b_state++;
            }
          }
        }

        if (idx == 0) {
          p_in_new = state->fSuu[25 * ((int32_T)state->fring_pos - 1)];
        } else {
          p_in_new = state->fSuu[b_iv[idx - 1] + 25 * ((int32_T)state->fring_pos
            - 1)];
          idx++;
          for (i = idx; i < 25; i++) {
            b_state = b_iv[i - 1];
            if (p_in_new < state->fSuu[b_state + 25 * ((int32_T)state->fring_pos
                 - 1)]) {
              p_in_new = state->fSuu[b_state + 25 * ((int32_T)state->fring_pos -
                1)];
            }
          }
        }

        st.site = &tf_emlrtRSI;
        b_movmax(&st, &state->fSuu[25 * ((int32_T)state->fring_pos - 1)],
                 local_max);
        p_in_new = muDoubleScalarMax(p_in_new * 0.00031622776601683794, tiny1);
        idx = (int32_T)state->fring_pos;
        b_state = (int32_T)state->fring_pos;
        for (i = 0; i < 25; i++) {
          exc_f[i] = (exc_f[i] && (state->fSuu[i + 25 * (idx - 1)] > p_in_new) &&
                      (state->fSuu[i + 25 * (b_state - 1)] > local_max[i] *
                       0.0031622776601683794) && state->sb_Tsf_valid[i]);
        }

        if (b_intnnz(exc_f) >= 3) {
          creal_T c_state_data[25];
          int32_T trueCount;
          idx = (int32_T)state->fring_pos;
          trueCount = 0;
          b_state = 0;
          for (i = 0; i < 25; i++) {
            maxval[i] = muDoubleScalarMax(state->fSuu[i + 25 * (idx - 1)], tiny1);
            if (exc_f[i]) {
              trueCount++;
              b_tmp_data[b_state] = (int8_T)i;
              b_state++;
            }
          }

          st.site = &vf_emlrtRSI;
          for (i = 0; i < trueCount; i++) {
            c_state_data[i] = state->sb_Tsf[b_tmp_data[i]];
          }

          b_st.site = &vf_emlrtRSI;
          a_size = b_abs(c_state_data, trueCount, a_data);
          b_st.site = &oc_emlrtRSI;
          maxval_size = a_size;
          idx = a_size / 2 * 2;
          b_state = idx - 2;
          for (i = 0; i <= b_state; i += 2) {
            r = _mm_loadu_pd(&a_data[i]);
            r = _mm_mul_pd(r, r);
            _mm_storeu_pd(&b_dv1[0], r);
            b_dv[0] = muDoubleScalarMax(b_dv1[0], 1.0E-12);
            b_dv[1] = muDoubleScalarMax(b_dv1[1], 1.0E-12);
            r = _mm_loadu_pd(&b_dv[0]);
            _mm_storeu_pd(&Suu[i], r);
          }

          for (i = idx; i < a_size; i++) {
            p_in_new = a_data[i];
            Suu[i] = muDoubleScalarMax(p_in_new * p_in_new, 1.0E-12);
          }

          st.site = &uf_emlrtRSI;
          b_st.site = &uf_emlrtRSI;
          idx = (int32_T)state->fring_pos;
          for (i = 0; i < trueCount; i++) {
            c_i = b_tmp_data[i];
            b_state = c_i + 25 * (idx - 1);
            p_in_new = state->fSuy[b_state].re;
            tiny1 = state->fSuy[b_state].im;
            tiny = maxval[c_i];
            if (tiny1 == 0.0) {
              br = p_in_new / tiny;
              p_in_new = 0.0;
            } else if (p_in_new == 0.0) {
              br = 0.0;
              p_in_new = tiny1 / tiny;
            } else {
              br = p_in_new / tiny;
              p_in_new = tiny1 / tiny;
            }

            c_state_data[i].re = br - state->sb_Tsf[c_i].re;
            c_state_data[i].im = p_in_new - state->sb_Tsf[c_i].im;
          }

          c_st.site = &uf_emlrtRSI;
          a_size = b_abs(c_state_data, trueCount, a_data);
          c_st.site = &oc_emlrtRSI;
          idx = a_size / 2 * 2;
          b_state = idx - 2;
          for (i = 0; i <= b_state; i += 2) {
            r = _mm_loadu_pd(&a_data[i]);
            r = _mm_mul_pd(r, r);
            _mm_storeu_pd(&a_data[i], r);
          }

          for (i = idx; i < a_size; i++) {
            p_in_new = a_data[i];
            a_data[i] = p_in_new * p_in_new;
          }

          b_st.site = &gf_emlrtRSI;
          c_st.site = &hf_emlrtRSI;
          assertCompatibleDims(&c_st, a_size, maxval_size);
          if (a_size == maxval_size) {
            idx = (a_size / 2) << 1;
            b_state = idx - 2;
            for (i = 0; i <= b_state; i += 2) {
              r = _mm_loadu_pd(&a_data[i]);
              r1 = _mm_loadu_pd(&Suu[i]);
              _mm_storeu_pd(&a_data[i], _mm_div_pd(r, r1));
            }

            for (i = idx; i < a_size; i++) {
              a_data[i] /= Suu[i];
            }

            st.site = &wf_emlrtRSI;
            d_raw = c_median(&st, a_data, a_size);
          } else {
            st.site = &wf_emlrtRSI;
            d_raw = binary_expand_op_1(&st, wf_emlrtRSI, a_data, &a_size, Suu,
              &maxval_size);
          }
        }
      }
    }

    /*  collect the healthy spread of the statistic during calibration */
    if (!state->ready) {
      if ((!muDoubleScalarIsInf(d_raw)) && (!muDoubleScalarIsNaN(d_raw)) &&
          (d_raw > 0.0) && (state->cal_d_count < 320.0)) {
        state->cal_d_count++;
        st.site = &xf_emlrtRSI;
        if (state->cal_d_count != (int32_T)muDoubleScalarFloor
            (state->cal_d_count)) {
          emlrtIntegerCheckR2012b(state->cal_d_count, &r_emlrtDCI, &st);
        }

        idx = (int32_T)state->cal_d_count;
        if ((idx < 1) || (idx > 320)) {
          emlrtDynamicBoundsCheckR2012b(idx, 1, 320, &t_emlrtBCI, &st);
        }

        state->cal_d[idx - 1] = muDoubleScalarLog(d_raw);
      }

      state->cus_st = 0.0;
      for (i = 0; i < 5; i++) {
        state->cus_burst[i] = 0.0;
      }

      /*  suspected or NASCENT excitation-regime transition (the input-support */
      /*  mask is moving): the spectra are mixing two regimes, which mimics */
      /*  change evidence - stand down until it resolves */
    } else if ((state->regime_count > 0.0) || (state->sb_ndiff >= 4.0)) {
      state->cus_st *= 0.9;
      r = _mm_loadu_pd(&state->cus_burst[0]);
      r1 = _mm_set1_pd(0.9);
      _mm_storeu_pd(&state->cus_burst[0], _mm_mul_pd(r1, r));
      r = _mm_loadu_pd(&state->cus_burst[2]);
      _mm_storeu_pd(&state->cus_burst[2], _mm_mul_pd(r1, r));
      state->cus_burst[4] *= 0.9;
    } else {
      /*  CUSUM on the FRF-change z: sustained moderate shifts accumulate and */
      /*  cross within a few 0.125 s steps; isolated healthy spikes decay */
      p_in_new = rtNaN;
      if ((!muDoubleScalarIsInf(d_raw)) && (!muDoubleScalarIsNaN(d_raw)) &&
          (d_raw > 0.0)) {
        st.site = &yf_emlrtRSI;
        p_in_new = (muDoubleScalarLog(d_raw) - state->mu_d) / state->sig_d;
      }

      if ((!muDoubleScalarIsInf(p_in_new)) && (!muDoubleScalarIsNaN(p_in_new)))
      {
        state->cus_st = muDoubleScalarMax(0.0, (state->cus_st + p_in_new) - 1.25);

        /*  gated drift tracking of the healthy FRF-change level */
        if (muDoubleScalarAbs(p_in_new) < 1.5) {
          st.site = &ag_emlrtRSI;
          state->mu_d = muDoubleScalarMin(muDoubleScalarMax(0.99875 *
            state->mu_d + 0.00125 * muDoubleScalarLog(muDoubleScalarMax(d_raw,
            2.2204460492503131E-16)), state->mu_d0 - 0.7), state->mu_d0 + 0.7);
        }
      } else {
        state->cus_st *= 0.9;
      }

      /*  trip needs the accumulated change evidence AND a margin-degrading */
      /*  direction AND an absolutely-concerning fast margin (a change BACK to */
      /*  healthy after an event, or a benign FRF shift at safe margins, is not */
      /*  grounds to shed) */
      if ((state->cus_st > 4.5) && ((!muDoubleScalarIsInf(b_fast)) &&
           (!muDoubleScalarIsNaN(b_fast))) && ((!muDoubleScalarIsInf
            (state->b_slow_filt)) && (!muDoubleScalarIsNaN(state->b_slow_filt)))
          && (b_fast < state->b_slow_filt) && (b_fast < 0.4)) {
        st_trip = true;
        state->cus_st = 0.0;

        /*  edge semantics: re-accumulate for a new trip */
      } else {
        st_trip = false;
      }

      /*  ---- fast quiet-band burst (calibrated sub-band levels, newest segment) -- */
      burst_trip = false;
      if (vectorAny(state->sb_qpmask, 99)) {
        real_T z_data[99];
        real_T b_state_data[5];
        real_T p_new[5];
        real_T zj[5];
        boolean_T live[5];
        st.site = &bg_emlrtRSI;
        fastQuietPower(&st, state->fSyy, state->fseg_count, state->fring_pos,
                       state->sb_qpmask, p_new);
        a_size = 0;
        idx = 0;
        for (i = 0; i < 5; i++) {
          boolean_T b;
          zj[i] = rtNaN;
          b = ((p_new[i] > 0.0) && (state->sig_pf[i] < 100000.0));
          live[i] = b;
          if (b) {
            a_size++;
            tmp_data[idx] = (int8_T)i;
            idx++;
          }
        }

        for (i = 0; i < a_size; i++) {
          b_state_data[i] = p_new[tmp_data[i]];
        }

        st.site = &cg_emlrtRSI;
        b_log(&st, b_state_data, &a_size);
        st.site = &cg_emlrtRSI;
        for (i = 0; i < a_size; i++) {
          a_data[i] = b_state_data[i] - state->mu_pf[tmp_data[i]];
        }

        b_st.site = &gf_emlrtRSI;
        c_st.site = &hf_emlrtRSI;
        assertCompatibleDims(&c_st, a_size, a_size);
        for (i = 0; i < a_size; i++) {
          z_data[i] = a_data[i] / state->sig_pf[tmp_data[i]];
        }

        for (i = 0; i < a_size; i++) {
          zj[tmp_data[i]] = z_data[i];
        }

        if (vectorAny(live, 5)) {
          st.site = &dg_emlrtRSI;
          b_st.site = &hg_emlrtRSI;
          c_st.site = &ig_emlrtRSI;
          d_st.site = &jg_emlrtRSI;
          if (a_size < 1) {
            emlrtErrorWithMessageIdR2018a(&d_st, &i_emlrtRTEI,
              "Coder:toolbox:eml_min_or_max_varDimZero",
              "Coder:toolbox:eml_min_or_max_varDimZero", 0);
          }

          if (a_size <= 2) {
            if (a_size - 1 == 0) {
              *z_pf = zj[tmp_data[0]];
            } else {
              p_in_new = zj[tmp_data[0]];
              tiny1 = zj[tmp_data[a_size - 1]];
              if ((p_in_new < tiny1) || (muDoubleScalarIsNaN(p_in_new) &&
                   (!muDoubleScalarIsNaN(tiny1)))) {
                *z_pf = tiny1;
              } else {
                *z_pf = p_in_new;
              }
            }
          } else {
            p_in_new = zj[tmp_data[0]];
            if (!muDoubleScalarIsNaN(p_in_new)) {
              idx = 1;
            } else {
              idx = 0;
              b_state = 2;
              exitg1 = false;
              while ((!exitg1) && (b_state <= a_size)) {
                if (!muDoubleScalarIsNaN(zj[tmp_data[b_state - 1]])) {
                  idx = b_state;
                  exitg1 = true;
                } else {
                  b_state++;
                }
              }
            }

            if (idx == 0) {
              *z_pf = p_in_new;
            } else {
              p_in_new = zj[tmp_data[idx - 1]];
              idx++;
              for (i = idx; i <= a_size; i++) {
                tiny1 = zj[tmp_data[i - 1]];
                if (p_in_new < tiny1) {
                  p_in_new = tiny1;
                }
              }

              *z_pf = p_in_new;
            }
          }
        }

        st.site = &eg_emlrtRSI;
        for (i = 0; i < 5; i++) {
          if (live[i]) {
            /*  per-band CUSUM */
            p_in_new = zj[i];
            state->cus_burst[i] = muDoubleScalarMax(0.0, (state->cus_burst[i] +
              p_in_new) - 1.0);

            /*  gated ultra-slow drift tracking, bounded +-3 dB */
            if (muDoubleScalarAbs(p_in_new) < 1.5) {
              st.site = &fg_emlrtRSI;
              p_in_new = p_new[i];
              if (p_in_new < 0.0) {
                emlrtErrorWithMessageIdR2018a(&st, &l_emlrtRTEI,
                  "Coder:toolbox:ElFunDomainError",
                  "Coder:toolbox:ElFunDomainError", 3, 4, 3, "log");
              }

              tiny1 = state->mu_pf0[i];
              state->mu_pf[i] = muDoubleScalarMin(muDoubleScalarMax(0.99875 *
                state->mu_pf[i] + 0.00125 * muDoubleScalarLog(p_in_new), tiny1 -
                0.69077552789821373), tiny1 + 0.69077552789821373);
            }
          } else {
            state->cus_burst[i] *= 0.9;
          }

          if (*emlrtBreakCheckR2012bFlagVar != 0) {
            emlrtBreakCheckR2012b((emlrtConstCTX)sp);
          }
        }

        for (i = 0; i < 5; i++) {
          state_data[i] = (state->cus_burst[i] > 6.0);
        }

        if (vectorAny(state_data, 5)) {
          burst_trip = true;
          for (i = 0; i < 5; i++) {
            state->cus_burst[i] = 0.0;
          }
        }
      }

      if (st_trip || burst_trip) {
        *fast_trip = true;
      }

      if (st_trip) {
        *trip_reason = 2.0;
      } else if (burst_trip) {
        *trip_reason = 1.0;
      }
    }
  }

  return b_fast;
}

static void fastQuietPower(const emlrtStack *sp, const real_T state_fSyy[75],
  real_T state_fseg_count, real_T state_fring_pos, const boolean_T qpmask[99],
  real_T p[5])
{
  static const int8_T b_iv[25] = { 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 0,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5 };

  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack st;
  int32_T i;
  int32_T ix;
  int32_T j;
  int32_T n;
  int8_T tmp_data[25];
  boolean_T q_f[25];
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  f_st.prev = &e_st;
  f_st.tls = e_st.tls;
  g_st.prev = &f_st;
  g_st.tls = f_st.tls;

  /*  undriven-band power of the NEWEST fast segment, per burst sub-band, */
  /*  using the (stable) input-support mask from the slow path */
  for (i = 0; i < 25; i++) {
    int32_T b_i;
    int8_T i1;
    b_i = i << 2;
    i1 = iv[i];
    if (b_i + 1 > i1) {
      b_i = 0;
      n = 0;
    } else {
      n = i1;
    }

    n -= b_i;
    if (n != 0) {
      boolean_T exitg1;
      boolean_T y;
      st.site = &ld_emlrtRSI;
      b_st.site = &nd_emlrtRSI;
      y = true;
      c_st.site = &od_emlrtRSI;
      ix = 1;
      exitg1 = false;
      while ((!exitg1) && (ix <= n)) {
        if (!qpmask[(b_i + ix) - 1]) {
          y = false;
          exitg1 = true;
        } else {
          ix++;
        }
      }

      if (y) {
        q_f[i] = true;
      } else {
        q_f[i] = false;
      }
    } else {
      q_f[i] = false;
    }

    if (*emlrtBreakCheckR2012bFlagVar != 0) {
      emlrtBreakCheckR2012b((emlrtConstCTX)sp);
    }
  }

  for (i = 0; i < 25; i++) {
    q_f[i] = (q_f[i] && bv[i]);
  }

  for (i = 0; i < 5; i++) {
    p[i] = 0.0;
  }

  if (state_fseg_count > 0.0) {
    for (j = 0; j < 5; j++) {
      n = 0;
      for (i = 0; i < 25; i++) {
        if (q_f[i] && (j + 1 == b_iv[i])) {
          n++;
        }
      }

      if (n >= 2) {
        ix = 0;
        n = 0;
        for (i = 0; i < 25; i++) {
          if (q_f[i] && (j + 1 == b_iv[i])) {
            ix++;
            tmp_data[n] = (int8_T)i;
            n++;
          }
        }

        st.site = &md_emlrtRSI;
        if (state_fring_pos != (int32_T)muDoubleScalarFloor(state_fring_pos)) {
          emlrtIntegerCheckR2012b(state_fring_pos, &d_emlrtDCI, &st);
        }

        if (((int32_T)state_fring_pos < 1) || ((int32_T)state_fring_pos > 3)) {
          emlrtDynamicBoundsCheckR2012b((int32_T)state_fring_pos, 1, 3,
            &d_emlrtBCI, &st);
        }

        b_st.site = &pd_emlrtRSI;
        c_st.site = &qd_emlrtRSI;
        d_st.site = &rd_emlrtRSI;
        if (ix == 0) {
          p[j] = 0.0;
        } else {
          real_T state_fSyy_data[25];
          e_st.site = &sd_emlrtRSI;
          f_st.site = &td_emlrtRSI;
          for (i = 0; i < ix; i++) {
            state_fSyy_data[i] = state_fSyy[tmp_data[i] + 25 * ((int32_T)
              state_fring_pos - 1)];
          }

          g_st.site = &ud_emlrtRSI;
          p[j] = sumColumnB(&g_st, state_fSyy_data, ix);
        }
      }

      if (*emlrtBreakCheckR2012bFlagVar != 0) {
        emlrtBreakCheckR2012b((emlrtConstCTX)sp);
      }
    }
  }
}

static void finalizeCalibration(const emlrtStack *sp, struct1_T *state, const
  boolean_T quiet[99])
{
  static const int8_T b_iv[68] = { 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
    37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55,
    61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98 };

  __m128d r;
  __m128d r1;
  __m128d r2;
  jmp_buf * volatile emlrtJBStack;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack st;
  emxArray_real_T b_state_data;
  emxArray_real_T *b_dev;
  emxArray_real_T *dev;
  emxArray_real_T *logq;
  emxArray_real_T *xPacked;
  real_T state_data[7920];
  real_T x_data[320];
  real_T maxval[99];
  real_T ratio[99];
  real_T b_state[94];
  real_T pf_data[80];
  real_T b_dv[2];
  real_T b_dv1[2];
  real_T nc;
  real_T y;
  real_T *dev_data;
  real_T *logq_data;
  int32_T pf_size[2];
  int32_T state_size[2];
  int32_T b_k;
  int32_T b_loop_ub;
  int32_T c_k;
  int32_T d_k;
  int32_T finalizeCalibration_numThreads;
  int32_T i;
  int32_T i1;
  int32_T i2;
  int32_T k;
  int32_T loop_ub;
  int32_T nx;
  int8_T tmp_data[99];
  int8_T b_tmp_data[80];
  boolean_T qbins[99];
  boolean_T b_y;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtConstCTX)sp);

  /*  -------------------------------------------------- calibration finalize */
  nc = state->cal_count;
  if (state->cal_count < 1.0) {
    loop_ub = 0;
  } else {
    if (state->cal_count != (int32_T)muDoubleScalarFloor(state->cal_count)) {
      emlrtIntegerCheckR2012b(state->cal_count, &m_emlrtDCI, (emlrtConstCTX)sp);
    }

    loop_ub = (int32_T)state->cal_count;
    if ((loop_ub < 1) || (loop_ub > 80)) {
      emlrtDynamicBoundsCheckR2012b(loop_ub, 1, 80, &p_emlrtBCI, (emlrtConstCTX)
        sp);
    }
  }

  state_size[0] = 99;
  state_size[1] = loop_ub;
  for (k = 0; k < loop_ub; k++) {
    memcpy(&state_data[k * 99], &state->cal_res[k * 99], 99U * sizeof(real_T));
  }

  b_state_data.data = &state_data[0];
  b_state_data.size = &state_size[0];
  b_state_data.allocatedSize = 7920;
  b_state_data.numDimensions = 2;
  b_state_data.canFreeData = false;
  st.site = &je_emlrtRSI;
  d_median(&st, &b_state_data, state->baseline);
  for (k = 0; k < 94; k++) {
    b_state[k] = state->baseline[iv1[k]];
  }

  st.site = &ie_emlrtRSI;
  y = b_median(&st, b_state) * 1.0E-6;
  for (k = 0; k < 99; k++) {
    real_T d;
    d = muDoubleScalarMax(state->baseline[k], y);
    state->baseline[k] = d;
    state->baseline0[k] = d;
  }

  /*  per-bin location and pooled spread of the self-normalized ln ratios */
  emxInit_real_T(sp, &logq, 2, &x_emlrtRTEI);
  b_k = logq->size[0] * logq->size[1];
  logq->size[0] = 99;
  emxEnsureCapacity_real_T(sp, logq, b_k, &u_emlrtRTEI);
  if (!(state->cal_count >= 0.0)) {
    emlrtNonNegativeCheckR2012b(state->cal_count, &o_emlrtDCI, (emlrtConstCTX)sp);
  }

  y = state->cal_count;
  if (y != (int32_T)muDoubleScalarFloor(y)) {
    emlrtIntegerCheckR2012b(y, &n_emlrtDCI, (emlrtConstCTX)sp);
  }

  b_k = logq->size[0] * logq->size[1];
  logq->size[1] = (int32_T)y;
  emxEnsureCapacity_real_T(sp, logq, b_k, &u_emlrtRTEI);
  logq_data = logq->data;
  b_loop_ub = (int32_T)state->cal_count;
  emlrtForLoopVectorCheckR2021a(1.0, 1.0, state->cal_count, mxDOUBLE_CLASS,
    (int32_T)state->cal_count, &k_emlrtRTEI, (emlrtConstCTX)sp);
  emxInit_real_T(sp, &xPacked, 1, &ab_emlrtRTEI);
  for (c_k = 0; c_k < b_loop_ub; c_k++) {
    boolean_T exitg1;
    if (((int32_T)((uint32_T)c_k + 1U) < 1) || ((int32_T)((uint32_T)c_k + 1U) >
         loop_ub)) {
      emlrtDynamicBoundsCheckR2012b((int32_T)((uint32_T)c_k + 1U), 1, loop_ub,
        &o_emlrtBCI, (emlrtConstCTX)sp);
    }

    for (k = 0; k < 99; k++) {
      ratio[k] = state->cal_res[k + 99 * c_k] / state->baseline[k];
      qbins[k] = quiet[k];
    }

    b_y = false;
    b_k = 0;
    exitg1 = false;
    while ((!exitg1) && (b_k <= 98)) {
      if (quiet[b_k]) {
        b_y = true;
        exitg1 = true;
      } else {
        b_k++;
      }
    }

    if (!b_y) {
      memcpy(&qbins[0], &bv1[0], 99U * sizeof(boolean_T));
    }

    nx = 0;
    b_k = 0;
    for (k = 0; k < 99; k++) {
      if (qbins[k]) {
        nx++;
        tmp_data[b_k] = (int8_T)k;
        b_k++;
      }
    }

    st.site = &he_emlrtRSI;
    if (nx == 0) {
      y = rtNaN;
    } else {
      b_k = xPacked->size[0];
      xPacked->size[0] = nx;
      emxEnsureCapacity_real_T(&st, xPacked, b_k, &n_emlrtRTEI);
      dev_data = xPacked->data;
      for (k = 0; k < nx; k++) {
        dev_data[k] = ratio[tmp_data[k]];
      }

      b_st.site = &hd_emlrtRSI;
      y = vmedian(&b_st, xPacked, nx);
    }

    y = muDoubleScalarMax(y, 2.2204460492503131E-16);
    for (k = 0; k <= 96; k += 2) {
      r2 = _mm_loadu_pd(&ratio[k]);
      r2 = _mm_div_pd(r2, _mm_set1_pd(y));
      _mm_storeu_pd(&ratio[k], r2);
      _mm_storeu_pd(&b_dv[0], r2);
      b_dv1[0] = muDoubleScalarMax(b_dv[0], 2.2204460492503131E-16);
      b_dv1[1] = muDoubleScalarMax(b_dv[1], 2.2204460492503131E-16);
      r2 = _mm_loadu_pd(&b_dv1[0]);
      _mm_storeu_pd(&maxval[k], r2);
    }

    maxval[98] = muDoubleScalarMax(ratio[98] / y, 2.2204460492503131E-16);
    st.site = &ge_emlrtRSI;
    for (k = 0; k < 99; k++) {
      maxval[k] = muDoubleScalarLog(maxval[k]);
    }

    if (((int32_T)((uint32_T)c_k + 1U) < 1) || ((int32_T)((uint32_T)c_k + 1U) >
         logq->size[1])) {
      emlrtDynamicBoundsCheckR2012b((int32_T)((uint32_T)c_k + 1U), 1, logq->
        size[1], &n_emlrtBCI, (emlrtConstCTX)sp);
    }

    for (k = 0; k < 99; k++) {
      logq_data[k + 99 * c_k] = maxval[k];
    }

    if (*emlrtBreakCheckR2012bFlagVar != 0) {
      emlrtBreakCheckR2012b((emlrtConstCTX)sp);
    }
  }

  st.site = &fe_emlrtRSI;
  d_median(&st, logq, state->mu0);
  st.site = &ee_emlrtRSI;
  emxInit_real_T(&st, &dev, 2, &y_emlrtRTEI);
  b_k = dev->size[0] * dev->size[1];
  dev->size[0] = 99;
  nx = logq->size[1];
  dev->size[1] = logq->size[1];
  emxEnsureCapacity_real_T(&st, dev, b_k, &v_emlrtRTEI);
  dev_data = dev->data;
  b_k = logq->size[1];
  if (logq->size[1] * 48 < 1600) {
    for (i = 0; i < nx; i++) {
      for (i1 = 0; i1 <= 96; i1 += 2) {
        b_k = i1 + 99 * i;
        r = _mm_loadu_pd(&logq_data[b_k]);
        r1 = _mm_loadu_pd(&state->mu0[i1]);
        _mm_storeu_pd(&dev_data[b_k], _mm_sub_pd(r, r1));
      }

      b_k = 99 * i + 98;
      dev_data[b_k] = logq_data[b_k] - state->mu0[98];
    }
  } else {
    emlrtEnterParallelRegion(&st, omp_in_parallel());
    emlrtPushJmpBuf(&st, &emlrtJBStack);
    finalizeCalibration_numThreads = emlrtAllocRegionTLSs(st.tls,
      omp_in_parallel(), omp_get_max_threads(), omp_get_num_procs());

#pragma omp parallel for \
 num_threads(finalizeCalibration_numThreads) \
 private(r,r1,i1,i2)

    for (i = 0; i < b_k; i++) {
      for (i1 = 0; i1 <= 96; i1 += 2) {
        i2 = i1 + 99 * i;
        r = _mm_loadu_pd(&logq_data[i2]);
        r1 = _mm_loadu_pd(&state->mu0[i1]);
        r = _mm_sub_pd(r, r1);
        _mm_storeu_pd(&dev_data[i2], r);
      }

      i2 = 99 * i + 98;
      dev_data[i2] = logq_data[i2] - state->mu0[98];
    }

    emlrtPopJmpBuf(&st, &emlrtJBStack);
    emlrtExitParallelRegion(&st, omp_in_parallel());
  }

  b_k = logq->size[0] * logq->size[1];
  logq->size[0] = 99;
  loop_ub = dev->size[1];
  logq->size[1] = dev->size[1];
  emxEnsureCapacity_real_T(&st, logq, b_k, &v_emlrtRTEI);
  logq_data = logq->data;
  nx = 99 * dev->size[1];
  for (k = 0; k < nx; k++) {
    logq_data[k] = dev_data[k];
  }

  b_st.site = &oe_emlrtRSI;
  b_k = dev->size[0] * dev->size[1];
  dev->size[0] = 99;
  dev->size[1] = loop_ub;
  emxEnsureCapacity_real_T(&b_st, dev, b_k, &r_emlrtRTEI);
  dev_data = dev->data;
  c_st.site = &pe_emlrtRSI;
  if (nx > 2147483646) {
    d_st.site = &n_emlrtRSI;
    check_forloop_overflow_error(&d_st);
  }

  if (nx < 1600) {
    for (d_k = 0; d_k < nx; d_k++) {
      dev_data[d_k] = muDoubleScalarAbs(logq_data[d_k]);
    }
  } else {
    emlrtEnterParallelRegion(&b_st, omp_in_parallel());
    emlrtPushJmpBuf(&b_st, &emlrtJBStack);
    finalizeCalibration_numThreads = emlrtAllocRegionTLSs(b_st.tls,
      omp_in_parallel(), omp_get_max_threads(), omp_get_num_procs());

#pragma omp parallel for \
 num_threads(finalizeCalibration_numThreads)

    for (d_k = 0; d_k < nx; d_k++) {
      dev_data[d_k] = muDoubleScalarAbs(logq_data[d_k]);
    }

    emlrtPopJmpBuf(&b_st, &emlrtJBStack);
    emlrtExitParallelRegion(&b_st, omp_in_parallel());
  }

  emxFree_real_T(&b_st, &logq);
  st.site = &de_emlrtRSI;
  b_st.site = &qe_emlrtRSI;
  c_st.site = &re_emlrtRSI;
  d_st.site = &se_emlrtRSI;
  nx = 68 * dev->size[1];
  if (nx == 0) {
    y = rtNaN;
  } else {
    emxInit_real_T(&d_st, &b_dev, 2, &w_emlrtRTEI);
    b_k = b_dev->size[0] * b_dev->size[1];
    b_dev->size[0] = 68;
    b_dev->size[1] = loop_ub;
    emxEnsureCapacity_real_T(&d_st, b_dev, b_k, &w_emlrtRTEI);
    logq_data = b_dev->data;
    for (k = 0; k < loop_ub; k++) {
      for (c_k = 0; c_k < 68; c_k++) {
        logq_data[c_k + 68 * k] = dev_data[b_iv[c_k] + 99 * k];
      }
    }

    b_k = xPacked->size[0];
    xPacked->size[0] = nx;
    emxEnsureCapacity_real_T(&d_st, xPacked, b_k, &n_emlrtRTEI);
    dev_data = xPacked->data;
    for (k = 0; k < nx; k++) {
      dev_data[k] = logq_data[k];
    }

    emxFree_real_T(&d_st, &b_dev);
    e_st.site = &hd_emlrtRSI;
    y = vmedian(&e_st, xPacked, nx);
  }

  emxFree_real_T(&d_st, &dev);
  state->sigma0 = muDoubleScalarMax(0.15, 1.4826 * y);

  /*  fast burst statistics from the collected newest-segment sub-band powers */
  if (nc < 1.0) {
    b_loop_ub = 0;
  } else {
    if (((int32_T)nc < 1) || ((int32_T)nc > 80)) {
      emlrtDynamicBoundsCheckR2012b((int32_T)nc, 1, 80, &m_emlrtBCI,
        (emlrtConstCTX)sp);
    }

    b_loop_ub = (int32_T)nc;
  }

  pf_size[0] = 1;
  for (c_k = 0; c_k < 5; c_k++) {
    int32_T trueCount;
    trueCount = 0;
    b_k = 0;
    for (k = 0; k < b_loop_ub; k++) {
      if (state->cal_pf[c_k + 5 * k] > 0.0) {
        trueCount++;
        b_tmp_data[b_k] = (int8_T)k;
        b_k++;
      }
    }

    pf_size[1] = trueCount;
    for (k = 0; k < trueCount; k++) {
      int8_T i3;
      i3 = b_tmp_data[k];
      if ((i3 < 0) || (i3 > b_loop_ub - 1)) {
        emlrtDynamicBoundsCheckR2012b(i3, 0, b_loop_ub - 1, &q_emlrtBCI,
          (emlrtConstCTX)sp);
      }

      pf_data[k] = state->cal_pf[c_k + 5 * i3];
    }

    if (trueCount >= 8) {
      real_T y_data[80];
      st.site = &ce_emlrtRSI;
      b_y = false;
      for (k = 0; k < trueCount; k++) {
        if (b_y || (state->cal_pf[c_k + 5 * b_tmp_data[k]] < 0.0)) {
          b_y = true;
        }
      }

      if (b_y) {
        emlrtErrorWithMessageIdR2018a(&st, &l_emlrtRTEI,
          "Coder:toolbox:ElFunDomainError", "Coder:toolbox:ElFunDomainError", 3,
          4, 3, "log");
      }

      b_st.site = &te_emlrtRSI;
      c_st.site = &ue_emlrtRSI;
      for (k = 0; k < trueCount; k++) {
        pf_data[k] = muDoubleScalarLog(pf_data[k]);
      }

      st.site = &be_emlrtRSI;
      y = e_median(pf_data, pf_size);
      state->mu_pf[c_k] = y;
      st.site = &ae_emlrtRSI;
      b_k = trueCount - 1;
      nx = (trueCount / 2) << 1;
      loop_ub = nx - 2;
      for (k = 0; k <= loop_ub; k += 2) {
        r2 = _mm_loadu_pd(&pf_data[k]);
        _mm_storeu_pd(&pf_data[k], _mm_sub_pd(r2, _mm_set1_pd(y)));
      }

      for (k = nx; k <= b_k; k++) {
        pf_data[k] -= y;
      }

      b_st.site = &oe_emlrtRSI;
      pf_size[0] = 1;
      c_st.site = &pe_emlrtRSI;
      for (k = 0; k < trueCount; k++) {
        y_data[k] = muDoubleScalarAbs(pf_data[k]);
      }

      st.site = &ae_emlrtRSI;
      y = 1.4826 * e_median(y_data, pf_size);
      state->sig_pf[c_k] = muDoubleScalarMax(0.2, y);
    } else {
      state->mu_pf[c_k] = 0.0;
      state->sig_pf[c_k] = 1.0E+6;

      /*  band unusable: disarmed */
    }

    if (*emlrtBreakCheckR2012bFlagVar != 0) {
      emlrtBreakCheckR2012b((emlrtConstCTX)sp);
    }
  }

  for (k = 0; k < 5; k++) {
    state->mu_pf0[k] = state->mu_pf[k];
    state->cus_burst[k] = 0.0;
  }

  /*  fast FRF-change statistics from the collected healthy samples */
  if (state->cal_d_count >= 16.0) {
    if (state->cal_d_count != (int32_T)muDoubleScalarFloor(state->cal_d_count))
    {
      emlrtIntegerCheckR2012b(state->cal_d_count, &l_emlrtDCI, (emlrtConstCTX)sp);
    }

    b_k = (int32_T)state->cal_d_count;
    if ((b_k < 1) || (b_k > 320)) {
      emlrtDynamicBoundsCheckR2012b(b_k, 1, 320, &l_emlrtBCI, (emlrtConstCTX)sp);
    }

    st.site = &yd_emlrtRSI;
    b_k = xPacked->size[0];
    xPacked->size[0] = (int32_T)state->cal_d_count;
    emxEnsureCapacity_real_T(&st, xPacked, b_k, &n_emlrtRTEI);
    dev_data = xPacked->data;
    b_k = (int32_T)state->cal_d_count;
    for (k = 0; k < b_k; k++) {
      dev_data[k] = state->cal_d[k];
    }

    b_st.site = &hd_emlrtRSI;
    state->mu_d = vmedian(&b_st, xPacked, (int32_T)state->cal_d_count);
    st.site = &xd_emlrtRSI;
    b_loop_ub = (int32_T)state->cal_d_count;
    b_k = (int32_T)state->cal_d_count;
    nx = (b_k / 2) << 1;
    loop_ub = nx - 2;
    for (k = 0; k <= loop_ub; k += 2) {
      r2 = _mm_loadu_pd(&state->cal_d[k]);
      _mm_storeu_pd(&x_data[k], _mm_sub_pd(r2, _mm_set1_pd(state->mu_d)));
    }

    for (k = nx; k < b_k; k++) {
      x_data[k] = state->cal_d[k] - state->mu_d;
    }

    b_st.site = &oe_emlrtRSI;
    b_k = xPacked->size[0];
    xPacked->size[0] = b_loop_ub;
    emxEnsureCapacity_real_T(&b_st, xPacked, b_k, &r_emlrtRTEI);
    dev_data = xPacked->data;
    c_st.site = &pe_emlrtRSI;
    for (k = 0; k < b_loop_ub; k++) {
      dev_data[k] = muDoubleScalarAbs(x_data[k]);
    }

    st.site = &xd_emlrtRSI;
    b_st.site = &hd_emlrtRSI;
    y = vmedian(&b_st, xPacked, xPacked->size[0]);
    state->sig_d = muDoubleScalarMax(0.3, 1.4826 * y);
  } else {
    state->mu_d = 0.0;
    state->sig_d = 1.0E+6;

    /*  no usable calibration: fast-ST path disarmed */
  }

  emxFree_real_T(sp, &xPacked);
  state->mu_d0 = state->mu_d;
  state->cal_d_count = 0.0;
  state->cus_st = 0.0;
  state->ready = true;
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtConstCTX)sp);
}

static void maskedMovMedian(const emlrtStack *sp, const real_T x[99], const
  boolean_T mask[99], real_T y[99])
{
  b_coder_internal_SortedBuffer s;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack h_st;
  emlrtStack i_st;
  emlrtStack j_st;
  emlrtStack st;
  real_T xm[99];
  real_T d;
  int32_T i;
  int32_T mid;
  int32_T trueCount;
  int8_T b_tmp_data[99];
  int8_T tmp_data[99];
  int8_T b_i;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  f_st.prev = &e_st;
  f_st.tls = e_st.tls;
  g_st.prev = &f_st;
  g_st.tls = f_st.tls;
  h_st.prev = &g_st;
  h_st.tls = g_st.tls;
  i_st.prev = &h_st;
  i_st.tls = h_st.tls;
  j_st.prev = &i_st;
  j_st.tls = i_st.tls;
  trueCount = 0;
  mid = 0;
  for (i = 0; i < 99; i++) {
    xm[i] = x[i];
    if (!mask[i]) {
      trueCount++;
      tmp_data[mid] = (int8_T)i;
      mid++;
    }
  }

  for (i = 0; i < trueCount; i++) {
    xm[tmp_data[i]] = rtNaN;
  }

  st.site = &ve_emlrtRSI;
  b_st.site = &we_emlrtRSI;
  c_st.site = &qc_emlrtRSI;
  d_st.site = &xe_emlrtRSI;
  e_st.site = &sc_emlrtRSI;
  f_st.site = &tc_emlrtRSI;
  memset(&y[0], 0, 99U * sizeof(real_T));
  g_st.site = &uc_emlrtRSI;
  h_st.site = &gc_emlrtRSI;
  i_st.site = &vc_emlrtRSI;
  s.buf[0] = 0.0;
  s.buf[1] = 0.0;
  s.buf[2] = 0.0;
  s.nbuf = 0;
  j_st.site = &wc_emlrtRSI;
  b_SortedBuffer_insert(&j_st, &s, xm[0]);
  j_st.site = &wc_emlrtRSI;
  b_SortedBuffer_insert(&j_st, &s, xm[1]);
  if (s.nbuf == 0) {
    y[0] = rtNaN;
  } else {
    mid = s.nbuf >> 1;
    if (((uint32_T)s.nbuf & 1U) == 1U) {
      y[0] = s.buf[mid];
    } else {
      d = s.buf[mid - 1];
      if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
        y[0] = (d + s.buf[mid]) / 2.0;
      } else {
        y[0] = d + (s.buf[mid] - d) / 2.0;
      }
    }
  }

  j_st.site = &xc_emlrtRSI;
  b_SortedBuffer_insert(&j_st, &s, xm[2]);
  if (s.nbuf == 0) {
    y[1] = rtNaN;
  } else {
    mid = s.nbuf >> 1;
    if (((uint32_T)s.nbuf & 1U) == 1U) {
      y[1] = s.buf[mid];
    } else {
      d = s.buf[mid - 1];
      if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
        y[1] = (d + s.buf[mid]) / 2.0;
      } else {
        y[1] = d + (s.buf[mid] - d) / 2.0;
      }
    }
  }

  for (i = 0; i < 96; i++) {
    j_st.site = &yc_emlrtRSI;
    SortedBuffer_replace(&j_st, &s, xm[i], xm[i + 3]);
    if (s.nbuf == 0) {
      y[i + 2] = rtNaN;
    } else {
      mid = s.nbuf >> 1;
      if (((uint32_T)s.nbuf & 1U) == 1U) {
        y[i + 2] = s.buf[mid];
      } else {
        d = s.buf[mid - 1];
        if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
          y[i + 2] = (d + s.buf[mid]) / 2.0;
        } else {
          y[i + 2] = d + (s.buf[mid] - d) / 2.0;
        }
      }
    }
  }

  j_st.site = &ad_emlrtRSI;
  b_SortedBuffer_remove(&j_st, &s, xm[96]);
  if (s.nbuf == 0) {
    y[98] = rtNaN;
  } else {
    mid = s.nbuf >> 1;
    if (((uint32_T)s.nbuf & 1U) == 1U) {
      y[98] = s.buf[mid];
    } else {
      d = s.buf[mid - 1];
      if (((d < 0.0) != (s.buf[mid] < 0.0)) || muDoubleScalarIsInf(d)) {
        y[98] = (d + s.buf[mid]) / 2.0;
      } else {
        y[98] = d + (s.buf[mid] - d) / 2.0;
      }
    }
  }

  for (i = 0; i < trueCount; i++) {
    b_i = tmp_data[i];
    y[b_i] = x[b_i];
  }

  trueCount = 0;
  mid = 0;
  for (i = 0; i < 99; i++) {
    if (muDoubleScalarIsNaN(y[i]) && mask[i]) {
      trueCount++;
      b_tmp_data[mid] = (int8_T)i;
      mid++;
    }
  }

  for (i = 0; i < trueCount; i++) {
    b_i = b_tmp_data[i];
    y[b_i] = x[b_i];
  }
}

static real_T residualBranch(const emlrtStack *sp, struct1_T *state, const
  real_T res[99], const boolean_T quiet[99], real_T *f_res, real_T *z_max)
{
  static const real_T b_dv2[99] = { 0.69551898699856718, 0.68825734782248837,
    0.68365496074833476, 0.68173423965376889, 0.6819717821297997,
    0.68386279265098993, 0.68702440578349866, 0.69117505234638221,
    0.69609824824750077, 0.701613789163366, 0.7075575611280368,
    0.71376727744738755, 0.72007166794386512, 0.72628152682334512,
    0.73218158476284378, 0.73752272375752215, 0.74201451217557168,
    0.745318374518418, 0.74704241044445718, 0.74673943787889308,
    0.74391076721472271, 0.73801904057252588, 0.72851404623233984,
    0.71487529565808217, 0.69667338903319642, 0.673648485647523,
    0.64579830844422, 0.61346163030206258, 0.57737885478525275,
    0.53871236885525786, 0.4990165065382422, 0.46015632443214427,
    0.42417836043752971, 0.39313025907791688, 0.36881864105394574,
    0.35251499292414734, 0.34468854883952776, 0.3449115204699022,
    0.352029088272022, 0.36451496946837353, 0.38082541040136147,
    0.39962231510813651, 0.41985431871316, 0.44074726226136318,
    0.46175644326374587, 0.48251215056047375, 0.50277199602236977,
    0.52238362507814562, 0.54125714218371823, 0.55934535375598182,
    0.57662985724516491, 0.59311134838259993, 0.60880292056088692,
    0.62372545430001525, 0.63790446595484462, 0.65136797118255729,
    0.66414504672046093, 0.67626487843739436, 0.687756143090279,
    0.69864661714062026, 0.70896294227934231, 0.71873049253628485,
    0.72797330925584136, 0.73671407832232672, 0.74497413040967608,
    0.7527734525452382, 0.760130701463575, 0.76706321100397323,
    0.77358698801601089, 0.77971669343198546, 0.785465601208716,
    0.7908455330135129, 0.7958667617088665, 0.80053787797441089,
    0.80486561229219744, 0.80885460251821872, 0.81250709506743557,
    0.81582256461074509, 0.81879723197788545, 0.82142345687671847,
    0.8236889734733801, 0.82557593032029153, 0.82705968606015345,
    0.82810730228904317, 0.82867566199004816, 0.828709131865625,
    0.82813667976421668, 0.8268683612096186, 0.82479111558525986,
    0.82176388271584833, 0.81761220203385743, 0.81212275090447028,
    0.80503880778571046, 0.79605851712473952, 0.78483922994423994,
    0.77101316907986783, 0.75422201579597492, 0.73417983493737637,
    0.710772827932893 };

  emlrtStack b_st;
  emlrtStack st;
  emxArray_real_T *xPacked;
  real_T maxval[99];
  real_T ratio[99];
  real_T b_dv[2];
  real_T b_dv1[2];
  real_T dv3[2];
  real_T dv4[2];
  real_T dv5[2];
  real_T b_res;
  real_T *xPacked_data;
  int32_T i;
  int32_T k;
  int8_T tmp_data[99];
  boolean_T exitg1;
  boolean_T y;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtConstCTX)sp);

  /*  ------------------------------------------------------- residual branch */
  b_res = 0.70710678118654746;
  *f_res = rtNaN;
  *z_max = rtNaN;
  y = false;
  k = 0;
  exitg1 = false;
  while ((!exitg1) && (k <= 98)) {
    if (quiet[k]) {
      y = true;
      exitg1 = true;
    } else {
      k++;
    }
  }

  if (!y) {
    state->res_count = 0.0;
  } else {
    __m128d r;
    __m128d r1;
    real_T x;
    int32_T idx;
    int32_T trueCount;
    boolean_T guard1;
    for (i = 0; i <= 96; i += 2) {
      r = _mm_loadu_pd(&state->baseline[i]);
      _mm_storeu_pd(&ratio[i], _mm_div_pd(_mm_loadu_pd(&res[i]), r));
    }

    ratio[98] = res[98] / state->baseline[98];
    trueCount = 0;
    k = 0;
    for (i = 0; i < 99; i++) {
      if (quiet[i]) {
        trueCount++;
        tmp_data[k] = (int8_T)i;
        k++;
      }
    }

    st.site = &ye_emlrtRSI;
    if (trueCount == 0) {
      x = rtNaN;
    } else {
      emxInit_real_T(&st, &xPacked, 1, &bb_emlrtRTEI);
      k = xPacked->size[0];
      xPacked->size[0] = trueCount;
      emxEnsureCapacity_real_T(&st, xPacked, k, &n_emlrtRTEI);
      xPacked_data = xPacked->data;
      for (i = 0; i < trueCount; i++) {
        xPacked_data[i] = ratio[tmp_data[i]];
      }

      b_st.site = &hd_emlrtRSI;
      x = vmedian(&b_st, xPacked, trueCount);
      emxFree_real_T(&st, &xPacked);
    }

    x = muDoubleScalarMax(x, 2.2204460492503131E-16);
    for (i = 0; i <= 96; i += 2) {
      r = _mm_loadu_pd(&ratio[i]);
      r = _mm_div_pd(r, _mm_set1_pd(x));
      _mm_storeu_pd(&ratio[i], r);
      _mm_storeu_pd(&b_dv[0], r);
      b_dv1[0] = muDoubleScalarMax(b_dv[0], 2.2204460492503131E-16);
      b_dv1[1] = muDoubleScalarMax(b_dv[1], 2.2204460492503131E-16);
      r = _mm_loadu_pd(&b_dv1[0]);
      _mm_storeu_pd(&maxval[i], r);
    }

    maxval[98] = muDoubleScalarMax(ratio[98] / x, 2.2204460492503131E-16);
    st.site = &af_emlrtRSI;
    for (i = 0; i < 99; i++) {
      maxval[i] = muDoubleScalarLog(maxval[i]);
    }

    for (i = 0; i <= 96; i += 2) {
      r = _mm_loadu_pd(&maxval[i]);
      r1 = _mm_loadu_pd(&state->mu0[i]);
      _mm_storeu_pd(&maxval[i], _mm_div_pd(_mm_sub_pd(r, r1), _mm_set1_pd
        (state->sigma0)));
    }

    maxval[98] = (maxval[98] - state->mu0[98]) / state->sigma0;
    st.site = &bf_emlrtRSI;
    maskedMovMedian(&st, maxval, quiet, ratio);
    for (i = 0; i < 99; i++) {
      if (!quiet[i]) {
        ratio[i] = rtMinusInf;
      }
    }

    if (!muDoubleScalarIsNaN(ratio[0])) {
      idx = 1;
    } else {
      idx = 0;
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k < 100)) {
        if (!muDoubleScalarIsNaN(ratio[k - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }

    if (idx == 0) {
      x = ratio[0];
      idx = 1;
    } else {
      x = ratio[idx - 1];
      k = idx + 1;
      for (i = k; i < 100; i++) {
        real_T d;
        d = ratio[i - 1];
        if (x < d) {
          x = d;
          idx = i;
        }
      }
    }

    *z_max = x;
    *f_res = ((real_T)idx - 1.0) + 2.0;

    /*  engage / disengage with same-frequency persistence. Engagement must be */
    /*  RE-CONFIRMED: z hovering in the hysteresis zone [z_off, z_on] holds it */
    /*  only for res_hold_s, so a one-off transient cannot depress the margin */
    /*  for the rest of the test. */
    guard1 = false;
    if (x > 4.0) {
      st.site = &cf_emlrtRSI;
      if ((x * state->sigma0 >= 0.69077552789821373) && (muDoubleScalarIsInf
           (state->res_freq) || muDoubleScalarIsNaN(state->res_freq) ||
           (muDoubleScalarAbs((((real_T)idx - 1.0) + 2.0) - state->res_freq) <=
            3.0))) {
        state->res_count = muDoubleScalarMin(state->res_count + 1.0, 4.0);
        state->res_age = 0.0;
      } else {
        guard1 = true;
      }
    } else {
      guard1 = true;
    }

    if (guard1) {
      if (x < 2.0) {
        state->res_count = muDoubleScalarMax(state->res_count - 1.0, 0.0);
      } else {
        state->res_age++;
        if (state->res_age > 20.0) {
          state->res_count = muDoubleScalarMax(state->res_count - 1.0, 0.0);
        }
      }
    }

    state->res_freq = ((real_T)idx - 1.0) + 2.0;
    if ((!state->res_on) && (state->res_count >= 4.0)) {
      state->res_on = true;
    } else if (state->res_on && (state->res_count <= 0.0)) {
      state->res_on = false;
    }

    if (state->res_on) {
      /*  engaged: map the FULL residual power growth to margin. Near the */
      /*  critical point output PSD ~ |S|^2 * noise and b ~ 1/|S|, so */
      /*  b ~ b0/sqrt(growth). The z-gate only decides WHEN this is evidence, */
      /*  never discounts the growth itself. */
      st.site = &df_emlrtRSI;
      b_res = muDoubleScalarMax(0.05, muDoubleScalarMin(0.70710678118654746,
        b_dv2[idx - 1]) / muDoubleScalarSqrt(muDoubleScalarMax(muDoubleScalarExp
        (muDoubleScalarMax(x, 0.0) * state->sigma0), 1.0)));

      /*  healthy: gated ultra-slow baseline adaptation (bounded to +-max_db) */
    } else if (x < 1.5) {
      __m128d r2;
      r2 = _mm_set1_pd(1.9952623149688795);
      for (i = 0; i <= 96; i += 2) {
        r = _mm_loadu_pd(&state->baseline[i]);
        r1 = _mm_loadu_pd(&state->baseline0[i]);
        _mm_storeu_pd(&dv3[0], _mm_add_pd(_mm_mul_pd(_mm_set1_pd(0.9975), r),
          _mm_mul_pd(_mm_set1_pd(0.0025), _mm_loadu_pd(&res[i]))));
        _mm_storeu_pd(&dv4[0], _mm_div_pd(r1, r2));
        _mm_storeu_pd(&dv5[0], _mm_mul_pd(r1, r2));
        b_dv[0] = muDoubleScalarMin(muDoubleScalarMax(dv3[0], dv4[0]), dv5[0]);
        b_dv[1] = muDoubleScalarMin(muDoubleScalarMax(dv3[1], dv4[1]), dv5[1]);
        r = _mm_loadu_pd(&b_dv[0]);
        _mm_storeu_pd(&ratio[i], r);
      }

      x = state->baseline0[98];
      ratio[98] = muDoubleScalarMin(muDoubleScalarMax(0.9975 * state->baseline
        [98] + 0.0025 * res[98], x / 1.9952623149688795), x * 1.9952623149688795);
      for (i = 0; i < trueCount; i++) {
        int8_T b_i;
        b_i = tmp_data[i];
        state->baseline[b_i] = ratio[b_i];
      }
    }
  }

  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtConstCTX)sp);
  return b_res;
}

static void slowHop(const emlrtStack *sp, struct1_T *state)
{
  static const real_T b_dv[2048] = { 0.0, 2.3553948388377322E-6,
    9.421557163713512E-6, 2.11984204002702E-5, 3.768587359187503E-5,
    5.8883761400674306E-5, 8.4791884109036708E-5, 0.0001154099976216072,
    0.00015073781346730541, 0.0001907749988023788, 0.00023552117641323367,
    0.00028497592472032096, 0.0003391387777817445, 0.00039800922529786842,
    0.00046158671261609108, 0.00052987064073617418, 0.00060286036631551632,
    0.00068055520167575878, 0.00076295441480872528, 0.0008500572293838049,
    0.000941862824754891, 0.0010383703359682084, 0.0011395788537706397,
    0.001245487424618108, 0.0013560950506845693, 0.0014714006898715604,
    0.0015914032558177471, 0.0017161016179095823, 0.0018454946012914086,
    0.0019795809868770609, 0.0021183595113609677, 0.0022618288672302533,
    0.0024099877027770056, 0.0025628346221109877, 0.00272036818517285,
    0.0028825869077476196, 0.0030494892614786884, 0.003221073673882302,
    0.0033973385283623259, 0.0035782821642254548, 0.0037639028766968119,
    0.0039541989169362135, 0.0041491684920543226, 0.0043488097651298019,
    0.0045531208552266889, 0.0047620998374117152, 0.0049757447427728474,
    0.0051940535584376613, 0.0054170242275922709, 0.00564465464950098,
    0.0058769426795255431, 0.0061138861291458735, 0.00635548276598058,
    0.0066017303138076189, 0.0068526264525862746, 0.007108168818478644,
    0.0073683550038720624, 0.0076331825574016965, 0.0079026489839738034,
    0.00817675174478899, 0.0084554882573663614, 0.0087388558955677209,
    0.009026851989622442, 0.0093194738261524468, 0.0096167186481979083,
    0.0099185836552430628, 0.010225066003242855, 0.010536162804649529,
    0.010851871128439827, 0.011172188000142802, 0.011497110401867572,
    0.011826635272331965, 0.012160759506891272, 0.01249947995756745,
    0.012842793433078981, 0.01319069669887063, 0.013543186477144198,
    0.013900259446889329, 0.014261912243914598, 0.01462814146087954,
    0.014998943647326513, 0.015374315309713282, 0.015754252911446,
    0.016138752872912332, 0.016527811571515394, 0.016921425341707763,
    0.017319590475026125, 0.017722303220126079, 0.018129559782817495,
    0.018541356326100322, 0.018957688970200837, 0.019378553792608,
    0.019803946828110375, 0.020233864068833818, 0.020668301464278893,
    0.021107254921359175, 0.021550720304439885, 0.021998693435376748,
    0.022451170093555295, 0.022908146015930775, 0.023369616897068346,
    0.023835578389183487, 0.024306026102182909, 0.0247809556037063,
    0.025260362419167515, 0.025744242031797371, 0.026232589882685509,
    0.026725401370824076, 0.027222671853150415, 0.027724396644591254,
    0.028230571018106665, 0.028741190204734646, 0.029256249393635914,
    0.029775743732139537, 0.030299668325788343, 0.030828018238385213,
    0.031360788492039549, 0.031897974067214063, 0.032439569902772247,
    0.03298557089602594, 0.033535971902783512, 0.034090767737398164,
    0.034649953172816939, 0.035213522940629849, 0.035781471731119618,
    0.036353794193311695, 0.036930484935024488, 0.037511538522920496,
    0.038096949482557152, 0.03868671229843873, 0.039280821414068023,
    0.039879271231998858, 0.04048205611388872, 0.041089170380552154,
    0.041700608312013776, 0.042316364147562624, 0.042936432085806331,
    0.043560806284725473, 0.04418948086172908, 0.044822449893709704,
    0.045459707417099371, 0.046101247427925762, 0.046747063881868778,
    0.047397150694317436, 0.048051501740427216, 0.048710110855177846,
    0.049372971833431256, 0.0500400784299902, 0.05071142435965692,
    0.0513870032972924, 0.05206680887787607, 0.052750834696565829,
    0.053439074308757994, 0.054131521230148583, 0.054828168936793875,
    0.055529010865172257, 0.056234040412245834, 0.056943250935522882,
    0.057656635753120133, 0.058374188143825889, 0.05909590134716336,
    0.059821768563454336, 0.060551782953883249, 0.061285937640561561,
    0.062024225706592717, 0.062766640196137036, 0.063513174114477544,
    0.0642638204280856, 0.065018572064687419, 0.065777421913330636,
    0.066540362824451138, 0.0673073876099406, 0.068078489043214119,
    0.068853659859278327, 0.069632892754799947, 0.070416180388174321,
    0.0712035153795949, 0.071994890311122661, 0.072790297726755715,
    0.073589730132500142, 0.074393179996439962, 0.075200639748808584,
    0.076012101782059915, 0.076827558450939915, 0.077647002072558979,
    0.078470424926463889, 0.079297819254711022, 0.080129177261938911,
    0.080964491115442183, 0.081803752945245112, 0.082646954844175724,
    0.083494088867940464, 0.0843451470351988, 0.085200121327638711,
    0.086059003690052149, 0.086921786030410675, 0.087788460219942133,
    0.088659018093206643, 0.089533451448174373, 0.090411752046301919,
    0.091293911612610523, 0.092179921835763845, 0.093069774368146285,
    0.093963460825941481, 0.094860972789211739, 0.0957623018019767,
    0.096667439372293662, 0.09757637697233712, 0.098489106038479379,
    0.0994056179713711, 0.10032590413602233, 0.10124995586188401,
    0.10217776444292942, 0.10310932113773646, 0.10404461716956975,
    0.10498364372646346, 0.10592639196130449, 0.1068728529919154,
    0.10782301790113857, 0.10877687773691996, 0.10973442351239332,
    0.11069564620596517, 0.11166053676139964, 0.11262908608790373,
    0.11360128506021328, 0.1145771245186783, 0.11555659526935003,
    0.116539688084067, 0.1175263937005423, 0.11851670282245069,
    0.11951060611951614, 0.12050809422759984, 0.1215091577487884,
    0.12251378725148249, 0.12352197327048553, 0.12453370630709287,
    0.12554897682918154, 0.12656777527129959, 0.12759009203475674,
    0.1286159174877145, 0.12964524196527688, 0.1306780557695818,
    0.13171434916989178, 0.13275411240268647, 0.13379733567175411,
    0.13484400914828376, 0.13589412297095838, 0.136947667246047,
    0.13800463204749885, 0.13906500741703609, 0.14012878336424806,
    0.14119594986668521, 0.14226649686995368, 0.14334041428780986,
    0.14441769200225574, 0.14549831986363371, 0.14658228769072262,
    0.14766958527083363, 0.14876020235990622, 0.14985412868260511,
    0.15095135393241643, 0.15205186777174562, 0.15315565983201407,
    0.15426271971375727, 0.15537303698672283, 0.15648660118996832,
    0.15760340183196037, 0.15872342839067294, 0.1598466703136871,
    0.16097311701828976, 0.16210275789157402, 0.16323558229053881,
    0.164371579542189, 0.16551073894363644, 0.16665304976220036,
    0.16779850123550882, 0.16894708257159979, 0.17009878294902309,
    0.17125359151694231, 0.1724114973952367, 0.17357248967460431,
    0.17473655741666416, 0.17590368965405967, 0.17707387539056196,
    0.17824710360117302, 0.17942336323223029, 0.18060264320151037,
    0.18178493239833332, 0.18297021968366778, 0.18415849389023542,
    0.18534974382261654, 0.18654395825735542, 0.18774112594306591,
    0.18894123560053777, 0.19014427592284261, 0.1913502355754404,
    0.19255910319628677, 0.19377086739593941, 0.19498551675766579,
    0.1962030398375505, 0.19742342516460326, 0.19864666124086694,
    0.1998727365415256, 0.2011016395150137, 0.20233335858312423,
    0.20356788214111832, 0.20480519855783424, 0.20604529617579714,
    0.2072881633113291, 0.20853378825465851, 0.2097821592700313,
    0.21103326459582089, 0.21228709244463906, 0.21354363100344731,
    0.21480286843366786, 0.21606479287129537, 0.21732939242700866,
    0.21859665518628246, 0.21986656920950037, 0.22113912253206647,
    0.22241430316451871, 0.22369209909264159, 0.22497249827757931,
    0.22625548865594947, 0.22754105813995623, 0.22882919461750478,
    0.23011988595231508, 0.23141311998403646, 0.23270888452836147,
    0.23400716737714194, 0.23530795629850276, 0.23661123903695819,
    0.23791700331352633, 0.23922523682584529, 0.24053592724828943,
    0.24184906223208469, 0.24316462940542594, 0.24448261637359242,
    0.24580301071906541, 0.24712580000164464, 0.24845097175856617,
    0.24977851350461894, 0.25110841273226325, 0.25244065691174783,
    0.25377523349122832, 0.25511212989688581, 0.2564513335330445,
    0.2577928317822914, 0.25913661200559385, 0.26048266154242017,
    0.26183096771085762, 0.26318151780773286, 0.26453429910873083,
    0.2658892988685152, 0.26724650432084823, 0.26860590267871087,
    0.26996748113442393, 0.27133122685976774, 0.27269712700610371,
    0.27406516870449515, 0.27543533906582895, 0.27680762518093593,
    0.27818201412071408, 0.2795584929362484, 0.28093704865893465,
    0.2823176683006009, 0.28370033885362933, 0.28508504729108, 0.286471780566812,
    0.2878605256156081, 0.28925126935329637, 0.29064399867687463,
    0.29203870046463276, 0.29343536157627736, 0.2948339688530548,
    0.29623450911787563, 0.29763696917543875, 0.29904133581235537,
    0.30044759579727376, 0.30185573588100373, 0.303265742796642,
    0.30467760325969634, 0.3060913039682116, 0.30750683160289405,
    0.30892417282723794, 0.31034331428765038, 0.31176424261357749,
    0.31318694441763045, 0.31461140629571105, 0.31603761482713882,
    0.31746555657477682, 0.31889521808515869, 0.320326585888615,
    0.32175964649940036, 0.32319438641582049, 0.3246307921203595,
    0.32606885007980707, 0.327508546745386, 0.32894986855287978,
    0.33039280192276066, 0.3318373332603175, 0.33328344895578355,
    0.33473113538446531, 0.3361803789068698, 0.3376311658688344,
    0.33908348260165455, 0.340537315422213, 0.34199265063310857,
    0.34344947452278463, 0.34490777336565975, 0.34636753342225535,
    0.34782874093932648, 0.34929138214999045, 0.350755443273857,
    0.35222091051715793, 0.35368777007287761, 0.35515600812088222,
    0.35662561082805039, 0.3580965643484037, 0.35956885482323664,
    0.361042468381248, 0.36251739113867032, 0.36399360919940227,
    0.36547110865513771, 0.36694987558549863, 0.3684298960581649,
    0.36991115612900627, 0.37139364184221357, 0.37287733923042965,
    0.374362234314882, 0.37584831310551381, 0.37733556160111581,
    0.37882396578945826, 0.380313511647423, 0.3818041851411354,
    0.38329597222609707, 0.38478885884731734, 0.38628283093944682,
    0.38777787442690859, 0.38927397522403168, 0.39077111923518404,
    0.39226929235490432, 0.39376848046803586, 0.3952686694498585,
    0.396769845166223, 0.39827199347368303, 0.39977510021962925,
    0.40127915124242219, 0.40278413237152566, 0.40429002942764064,
    0.40579682822283836, 0.40730451456069455, 0.40881307423642266,
    0.41032249303700807, 0.41183275674134157, 0.4133438511203541,
    0.41485576193714979, 0.41636847494714124, 0.41788197589818238,
    0.41939625053070423, 0.420911284577848, 0.42242706376560013,
    0.42394357381292697, 0.42546080043190848, 0.42697872932787384,
    0.42849734619953539, 0.43001663673912394, 0.43153658663252292,
    0.433057181559404, 0.43457840719336105, 0.43610024920204649,
    0.43762269324730479, 0.43914572498530868, 0.44066933006669368,
    0.44219349413669357, 0.4437182028352758, 0.44524344179727615,
    0.44676919665253506, 0.44829545302603163, 0.44982219653802069,
    0.45134941280416674, 0.45287708743568095, 0.45440520603945539,
    0.45593375421819909, 0.45746271757057444, 0.45899208169133165,
    0.46052183217144549, 0.46205195459825033, 0.46358243455557629,
    0.46511325762388495, 0.46664440938040541, 0.46817587539926986,
    0.4697076412516496, 0.47123969250589121, 0.472772014727652,
    0.47430459348003684, 0.47583741432373317, 0.47737046281714812,
    0.47890372451654317, 0.48043718497617188, 0.48197082974841465,
    0.48350464438391577, 0.48503861443171892, 0.48657272543940328,
    0.48810696295322054, 0.48964131251822995, 0.49117575967843563,
    0.49271028997692179, 0.49424488895598934, 0.4957795421572922,
    0.49731423512197365, 0.49884895339080193, 0.50038368250430743,
    0.50191840800291765, 0.50345311542709448, 0.50498779031747043,
    0.50652241821498389, 0.5080569846610169, 0.50959147519752934,
    0.51112587536719711, 0.51266017071354719, 0.51419434678109421,
    0.5157283891154768, 0.51726228326359314, 0.51879601477373782,
    0.52032956919573758, 0.52186293208108814, 0.52339608898308909,
    0.52492902545698117, 0.52646172706008143, 0.5279941793519205,
    0.52952636789437724, 0.531058278251816, 0.53258989599122131,
    0.53412120668233543, 0.53565219589779312, 0.537182849213258,
    0.53871315220755833, 0.540243090462823, 0.54177264956461746,
    0.54330181510207909, 0.54483057266805368, 0.54635890785923014,
    0.54788680627627739, 0.54941425352397932, 0.55094123521137028,
    0.55246773695187146, 0.55399374436342519, 0.55551924306863176,
    0.557044218694884, 0.558568656874503, 0.56009254324487356,
    0.56161586344857939, 0.563138603133538, 0.56466074795313692,
    0.56618228356636791, 0.56770319563796223, 0.56922346983852634,
    0.570743091844676, 0.57226204733917208, 0.57378032201105478,
    0.57529790155577887, 0.576814771675348, 0.57833091807845027,
    0.57984632648059176, 0.5813609826042323, 0.58287487217891876,
    0.5843879809414203, 0.58590029463586291, 0.58741179901386276,
    0.58892247983466184, 0.59043232286526059, 0.59194131388055327,
    0.593449438663461, 0.59495668300506688, 0.59646303270474832,
    0.59796847357031246, 0.59947299141812849, 0.60097657207326216,
    0.602479201369609, 0.6039808651500278, 0.60548154926647435,
    0.60698123958013384, 0.60847992196155509, 0.60997758229078314,
    0.6114742064574924, 0.61296978036111949, 0.61446428991099611,
    0.61595772102648194, 0.6174500596370972, 0.61894129168265555,
    0.62043140311339551, 0.62192037989011428, 0.62340820798429875,
    0.62489487337825866, 0.62638036206525793, 0.62786466004964736,
    0.629347753346995, 0.63082962798422026, 0.63231026999972351,
    0.63378966544351822, 0.6352678003773633, 0.63674466087489268,
    0.63822023302174835, 0.63969450291571006, 0.64116745666682706,
    0.6426390803975488, 0.64410936024285537, 0.64557828235038839,
    0.647045832880582, 0.64851199800679227, 0.64997676391542814,
    0.65144011680608127, 0.65290204289165632, 0.65436252839850084,
    0.65582155956653432, 0.65727912264937938, 0.65873520391448925,
    0.66018978964327912, 0.66164286613125389, 0.66309441968813809,
    0.664544436638005, 0.66599290331940453, 0.66743980608549314,
    0.66888513130416127, 0.670328865358163, 0.67177099464524337,
    0.6732115055782667, 0.67465038458534488, 0.67608761810996543,
    0.67752319261111849, 0.6789570945634249, 0.6803893104572637,
    0.68181982679889908, 0.683248630110608, 0.68467570693080648,
    0.68610104381417747, 0.68752462733179565, 0.6889464440712566,
    0.69036648063680073, 0.691784723649441, 0.69320115974708851,
    0.69461577558467757, 0.6960285578342934, 0.69743949318529563,
    0.698848568344445, 0.7002557700360279, 0.70166108500198221,
    0.70306450000202114, 0.70446600181375918, 0.70586557723283561,
    0.70726321307303985, 0.7086588961664344, 0.7100526133634808,
    0.71144435153316155, 0.712834097563105, 0.71422183835970876,
    0.71560756084826294, 0.71699125197307279, 0.71837289869758281,
    0.71975248800449876, 0.72113000689591056, 0.72250544239341452,
    0.72387878153823582, 0.72525001139135137, 0.72661911903360943,
    0.727986091565854, 0.72935091610904523, 0.73071357980438012,
    0.7320740698134145, 0.73343237331818367, 0.7347884775213237,
    0.73614236964619117, 0.73749403693698368, 0.738843466658861,
    0.74019064609806373, 0.74153556256203368, 0.74287820337953381,
    0.74421855590076713, 0.74555660749749619, 0.74689234556316131,
    0.74822575751300047, 0.74955683078416735, 0.75088555283584935,
    0.75221191114938635, 0.753535893228388, 0.75485748659885221,
    0.75617667880928208, 0.75749345743080343, 0.75880781005728237,
    0.76011972430544106, 0.76142918781497526, 0.76273618824867073,
    0.764040713292519, 0.76534275065583435, 0.76664228807136781,
    0.76793931329542464, 0.76923381410797909, 0.77052577831278857,
    0.77181519373751006, 0.77310204823381379, 0.77438632967749821,
    0.7756680259686034, 0.77694712503152619, 0.77822361481513347,
    0.77949748329287527, 0.78076871846289841, 0.78203730834816021,
    0.78330324099654036, 0.78456650448095366, 0.78582708689946323,
    0.78708497637539154, 0.78834016105743354, 0.78959262911976658,
    0.790842368762164, 0.792089368210104, 0.79333361571488259,
    0.79457509955372307, 0.7958138080298871, 0.79704972947278452,
    0.79828285223808315, 0.79951316470781908, 0.80074065529050575,
    0.80196531242124358, 0.80318712456182761, 0.804406080200858,
    0.80562216785384777, 0.80683537606333022, 0.80804569339896815,
    0.80925310845766063, 0.81045760986365112, 0.81165918626863354,
    0.81285782635186088, 0.81405351882025045, 0.81524625240849069,
    0.81643601587914716, 0.81762279802276927, 0.81880658765799486,
    0.81998737363165575, 0.82116514481888325, 0.82233989012321262,
    0.82351159847668809, 0.8246802588399661, 0.82584586020242035,
    0.827008391582245, 0.8281678420265588, 0.82932420061150691,
    0.83047745644236526, 0.83162759865364277, 0.83277461640918315,
    0.83391849890226755, 0.83505923535571636, 0.83619681502199072,
    0.83733122718329334, 0.83846246115166989, 0.83959050626910992,
    0.840715351907647, 0.84183698746945845, 0.84295540238696576,
    0.8440705861229344, 0.84518252817057193, 0.84629121805362817,
    0.84739664532649361, 0.84849879957429764, 0.84959767041300593,
    0.85069324748952013, 0.85178552048177358, 0.85287447909883007,
    0.85396011308097908, 0.855042412199834, 0.85612136625842816,
    0.85719696509130983, 0.85826919856463957, 0.85933805657628448,
    0.860403529055914, 0.86146560596509458, 0.86252427729738423,
    0.86357953307842727, 0.8646313633660474, 0.86567975825034216,
    0.866724707853776, 0.86776620233127333, 0.86880423187031108,
    0.86983878669101178, 0.870869857046235, 0.87189743322166979,
    0.87292150553592518, 0.87394206434062283, 0.87495910002048727,
    0.87597260299343582, 0.87698256371066985, 0.87798897265676423,
    0.87899182034975754, 0.87999109734124037, 0.8809867942164451,
    0.881978901594335, 0.88296741012769153, 0.883952310503203,
    0.88493359344155231, 0.88591124969750457, 0.88688527005999385,
    0.88785564535220984, 0.88882236643168466, 0.88978542419037931,
    0.89074480955476831, 0.89170051348592627, 0.892652526979613,
    0.89360084106635784, 0.89454544681154413, 0.895486335315494,
    0.8964234977135519, 0.89735692517616794, 0.89828660890898093,
    0.89921254015290208, 0.90013471018419644, 0.901053110314566,
    0.901967731891231, 0.9028785662970118, 0.90378560495040983,
    0.90468883930568811, 0.90558826085295263, 0.9064838611182322,
    0.9073756316635575, 0.90826356408704179, 0.90914765002295916,
    0.91002788114182376, 0.9109042491504683, 0.911776745792122,
    0.91264536284648856, 0.9135100921298237, 0.91437092549501142,
    0.91522785483164215, 0.91608087206608824, 0.91692996916157987,
    0.91777513811828138, 0.91861637097336635, 0.91945365980109306,
    0.920286996712878, 0.92111637385737133, 0.92194178342053057,
    0.92276321762569413, 0.9235806687336543, 0.92439412904273055,
    0.92520359088884241, 0.92600904664558037, 0.92681048872427918,
    0.927607909574089, 0.92840130168204582, 0.92919065757314279,
    0.92997596981040109, 0.93075723099493879, 0.93153443376604206,
    0.93230757080123294, 0.93307663481633973, 0.93384161856556469,
    0.93460251484155255, 0.93535931647545889, 0.93611201633701713,
    0.93686060733460552, 0.93760508241531482, 0.93834543456501385,
    0.93908165680841615, 0.93981374220914538, 0.94054168386980086,
    0.94126547493202251, 0.94198510857655537, 0.94270057802331375,
    0.94341187653144587, 0.944118997399396, 0.94482193396496916,
    0.94552067960539232, 0.94621522773737832, 0.9469055718171866,
    0.94759170534068582, 0.94827362184341424, 0.94895131490064166,
    0.94962477812742918, 0.95029400517868945, 0.95095898974924664,
    0.951619725573896, 0.95227620642746247, 0.95292842612485962,
    0.95357637852114774, 0.954220057511592, 0.95485945703171971,
    0.95549457105737745, 0.956125393604788, 0.95675191873060683,
    0.95737414053197778, 0.95799205314658842, 0.95860565075272641,
    0.95921492756933313, 0.9598198778560586, 0.9604204959133158,
    0.96101677608233382, 0.961608712745212, 0.96219630032497183,
    0.9627795332856105, 0.9633584061321524, 0.963932913410701,
    0.96450304970849032, 0.965068809653936, 0.965630187916686,
    0.96618717920767039, 0.96673977827915136, 0.967287979924773,
    0.96783177897961015, 0.96837117032021669, 0.96890614886467419,
    0.96943670957264017, 0.96996284744539452, 0.9704845575258878,
    0.97100183489878678, 0.97151467469052188, 0.97202307206933225,
    0.97252702224531151, 0.97302652047045324, 0.97352156203869522,
    0.974012142285964, 0.97449825659021894, 0.9749799003714954,
    0.9754570690919484, 0.9759297582558949, 0.97639796340985652,
    0.97686168014260133, 0.9773209040851849, 0.97777563091099284,
    0.97822585633578019, 0.97867157611771227, 0.97911278605740493,
    0.97954948199796354, 0.97998165982502283, 0.980409315466785,
    0.98083244489405863, 0.98125104412029585, 0.9816651092016313,
    0.9820746362369176, 0.98247962136776346, 0.98288006077856926,
    0.98327595069656359, 0.98366728739183773, 0.98405406717738231,
    0.98443628640912073, 0.984813941485944, 0.98518702884974529,
    0.985555544985452, 0.98591948642106031, 0.98627884972766688,
    0.98663363151950212, 0.98698382845396093, 0.98732943723163535,
    0.98767045459634473, 0.9880068773351669, 0.98833870227846843,
    0.988665926299934, 0.98898854631659683, 0.98930655928886679,
    0.98961996222055937, 0.989928752158924, 0.99023292619467163,
    0.99053248146200246, 0.99082741513863315, 0.99111772444582213,
    0.99140340664839766, 0.991684459054782, 0.99196087901701746,
    0.99223266393079168, 0.99249981123546138, 0.99276231841407714,
    0.99302018299340666, 0.99327340254395835, 0.99352197468000414,
    0.99376589705960194, 0.99400516738461775, 0.994239783400747,
    0.99446974289753642, 0.99469504370840445, 0.99491568371066152,
    0.99513166082553028, 0.99534297301816532, 0.99554961829767208,
    0.99575159471712549, 0.99594890037358885, 0.99614153340813116,
    0.996329492005845, 0.9965127743958635, 0.99669137885137726, 0.99686530368965,
    0.99703454727203522, 0.997199108003991, 0.9973589843350954,
    0.99751417475906079, 0.99766467781374835, 0.99781049208118144,
    0.99795161618755968, 0.99808804880327084, 0.99821978864290439,
    0.99834683446526284, 0.998469185073374, 0.99858683931450165,
    0.99869979608015735, 0.99880805430610986, 0.99891161297239561,
    0.99901047110332852, 0.99910462776750886, 0.99919408207783222,
    0.99927883319149746, 0.9993588803100153, 0.99943422267921567,
    0.99950485958925439, 0.99957079037462, 0.99963201441414062,
    0.9996885311309891, 0.99974033999268852, 0.99978744051111779,
    0.99982983224251543, 0.99986751478748448, 0.99990048779099583,
    0.99992875094239175, 0.99995230397538859, 0.99997114666807985,
    0.99998527884293731, 0.99999470036681382, 0.9999994111509436,
    0.9999994111509436, 0.99999470036681382, 0.99998527884293731,
    0.99997114666807985, 0.99995230397538859, 0.99992875094239175,
    0.99990048779099583, 0.99986751478748448, 0.99982983224251543,
    0.99978744051111779, 0.99974033999268852, 0.9996885311309891,
    0.99963201441414073, 0.99957079037462, 0.99950485958925439,
    0.99943422267921567, 0.9993588803100153, 0.99927883319149746,
    0.99919408207783222, 0.99910462776750886, 0.99901047110332863,
    0.99891161297239561, 0.99880805430611, 0.99869979608015735,
    0.99858683931450165, 0.998469185073374, 0.99834683446526284,
    0.9982197886429045, 0.99808804880327084, 0.99795161618755968,
    0.99781049208118144, 0.99766467781374835, 0.99751417475906079,
    0.9973589843350954, 0.997199108003991, 0.99703454727203522, 0.99686530368965,
    0.99669137885137726, 0.9965127743958635, 0.996329492005845,
    0.99614153340813116, 0.99594890037358885, 0.9957515947171256,
    0.99554961829767208, 0.99534297301816532, 0.99513166082553028,
    0.99491568371066152, 0.99469504370840456, 0.99446974289753642,
    0.994239783400747, 0.99400516738461775, 0.99376589705960194,
    0.99352197468000414, 0.99327340254395846, 0.99302018299340666,
    0.99276231841407714, 0.99249981123546149, 0.99223266393079168,
    0.99196087901701746, 0.991684459054782, 0.99140340664839766,
    0.99111772444582225, 0.99082741513863315, 0.99053248146200257,
    0.99023292619467163, 0.989928752158924, 0.98961996222055937,
    0.98930655928886679, 0.98898854631659683, 0.988665926299934,
    0.98833870227846843, 0.9880068773351669, 0.98767045459634473,
    0.98732943723163547, 0.986983828453961, 0.98663363151950212,
    0.98627884972766688, 0.98591948642106031, 0.98555554498545206,
    0.98518702884974529, 0.984813941485944, 0.98443628640912073,
    0.98405406717738231, 0.98366728739183773, 0.98327595069656359,
    0.98288006077856949, 0.98247962136776357, 0.9820746362369176,
    0.9816651092016313, 0.981251044120296, 0.98083244489405852,
    0.980409315466785, 0.97998165982502294, 0.97954948199796377,
    0.97911278605740493, 0.97867157611771238, 0.9782258563357803,
    0.97777563091099284, 0.9773209040851849, 0.97686168014260122,
    0.97639796340985652, 0.975929758255895, 0.9754570690919484,
    0.9749799003714954, 0.97449825659021894, 0.974012142285964,
    0.97352156203869522, 0.97302652047045335, 0.97252702224531151,
    0.97202307206933214, 0.97151467469052188, 0.97100183489878689,
    0.9704845575258878, 0.96996284744539463, 0.96943670957264017,
    0.9689061488646743, 0.96837117032021669, 0.96783177897961026,
    0.96728797992477311, 0.96673977827915136, 0.96618717920767039,
    0.96563018791668609, 0.96506880965393615, 0.96450304970849032,
    0.96393291341070109, 0.96335840613215251, 0.96277953328561061,
    0.96219630032497183, 0.961608712745212, 0.96101677608233382,
    0.96042049591331569, 0.9598198778560586, 0.95921492756933313,
    0.95860565075272652, 0.95799205314658853, 0.95737414053197778,
    0.95675191873060694, 0.95612539360478821, 0.95549457105737734,
    0.95485945703171971, 0.954220057511592, 0.95357637852114774,
    0.95292842612485962, 0.95227620642746258, 0.95161972557389607,
    0.95095898974924664, 0.95029400517868945, 0.94962477812742918,
    0.94895131490064166, 0.94827362184341424, 0.94759170534068571,
    0.94690557181718671, 0.94621522773737832, 0.94552067960539243,
    0.94482193396496927, 0.9441189973993962, 0.94341187653144587,
    0.94270057802331386, 0.94198510857655537, 0.94126547493202262,
    0.94054168386980086, 0.93981374220914549, 0.93908165680841627,
    0.938345434565014, 0.93760508241531482, 0.93686060733460563,
    0.93611201633701724, 0.935359316475459, 0.93460251484155243,
    0.93384161856556458, 0.93307663481633973, 0.93230757080123294,
    0.93153443376604206, 0.930757230994939, 0.92997596981040109,
    0.9291906575731429, 0.92840130168204582, 0.92760790957408912,
    0.92681048872427918, 0.92600904664558026, 0.9252035908888423,
    0.92439412904273066, 0.9235806687336543, 0.92276321762569413,
    0.92194178342053079, 0.92111637385737133, 0.920286996712878,
    0.91945365980109317, 0.91861637097336657, 0.91777513811828126,
    0.91692996916157976, 0.91608087206608824, 0.91522785483164237,
    0.91437092549501153, 0.91351009212982381, 0.91264536284648878,
    0.91177674579212209, 0.91090424915046841, 0.91002788114182365,
    0.90914765002295916, 0.90826356408704179, 0.90737563166355761,
    0.90648386111823231, 0.90558826085295274, 0.90468883930568822,
    0.90378560495040983, 0.902878566297012, 0.90196773189123114,
    0.90105311031456592, 0.90013471018419633, 0.89921254015290208,
    0.89828660890898093, 0.89735692517616794, 0.89642349771355212,
    0.89548633531549415, 0.89454544681154424, 0.89360084106635784,
    0.89265252697961317, 0.89170051348592616, 0.8907448095547682,
    0.88978542419037931, 0.88882236643168488, 0.88785564535221,
    0.886885270059994, 0.88591124969750479, 0.88493359344155242,
    0.883952310503203, 0.88296741012769164, 0.88197890159433512,
    0.8809867942164451, 0.87999109734124037, 0.87899182034975754,
    0.87798897265676445, 0.87698256371066985, 0.87597260299343593,
    0.87495910002048738, 0.873942064340623, 0.87292150553592518,
    0.87189743322166968, 0.8708698570462351, 0.86983878669101178,
    0.86880423187031108, 0.86776620233127333, 0.8667247078537762,
    0.86567975825034227, 0.86463136336604762, 0.8635795330784275,
    0.86252427729738435, 0.86146560596509447, 0.860403529055914,
    0.85933805657628459, 0.85826919856463957, 0.85719696509130994,
    0.85612136625842827, 0.85504241219983435, 0.85396011308097908,
    0.85287447909883007, 0.85178552048177381, 0.85069324748952,
    0.84959767041300593, 0.84849879957429764, 0.84739664532649384,
    0.84629121805362839, 0.845182528170572, 0.84407058612293451,
    0.84295540238696609, 0.84183698746945845, 0.84071535190764712,
    0.83959050626911, 0.83846246115166978, 0.83733122718329323,
    0.83619681502199072, 0.83505923535571658, 0.83391849890226766,
    0.83277461640918327, 0.831627598653643, 0.83047745644236559,
    0.82932420061150691, 0.8281678420265588, 0.82700839158224526,
    0.82584586020242068, 0.82468025883996632, 0.82351159847668831,
    0.82233989012321285, 0.82116514481888314, 0.81998737363165586,
    0.81880658765799486, 0.81762279802276916, 0.81643601587914727,
    0.81524625240849058, 0.81405351882025034, 0.8128578263518611,
    0.81165918626863376, 0.810457609863651, 0.80925310845766085,
    0.80804569339896826, 0.80683537606333056, 0.805622167853848,
    0.80440608020085813, 0.80318712456182784, 0.80196531242124369,
    0.80074065529050609, 0.79951316470781952, 0.798282852238083,
    0.7970497294727843, 0.79581380802988722, 0.79457509955372307,
    0.7933336157148827, 0.792089368210104, 0.79084236876216374,
    0.7895926291197668, 0.78834016105743365, 0.78708497637539165,
    0.78582708689946346, 0.78456650448095377, 0.78330324099654025,
    0.78203730834816043, 0.78076871846289864, 0.7794974832928756,
    0.7782236148151338, 0.77694712503152652, 0.77566802596860385,
    0.77438632967749843, 0.77310204823381379, 0.77181519373751017,
    0.77052577831278857, 0.76923381410797886, 0.76793931329542475,
    0.76664228807136769, 0.76534275065583457, 0.76404071329251932,
    0.76273618824867073, 0.76142918781497548, 0.76011972430544117,
    0.75880781005728237, 0.75749345743080376, 0.75617667880928208,
    0.75485748659885221, 0.75353589322838821, 0.75221191114938657,
    0.7508855528358499, 0.74955683078416779, 0.7482257575130008,
    0.74689234556316142, 0.74555660749749608, 0.744218555900767,
    0.74287820337953392, 0.74153556256203357, 0.7401906460980634,
    0.73884346665886114, 0.73749403693698379, 0.73614236964619151,
    0.734788477521324, 0.73343237331818378, 0.73207406981341472,
    0.73071357980438023, 0.72935091610904523, 0.72798609156585437,
    0.72661911903360954, 0.72525001139135126, 0.72387878153823637,
    0.72250544239341474, 0.72113000689591111, 0.71975248800449887,
    0.71837289869758281, 0.7169912519730729, 0.71560756084826282,
    0.71422183835970865, 0.71283409756310512, 0.71144435153316143,
    0.71005261336348069, 0.70865889616643463, 0.70726321307303985,
    0.705865577232836, 0.7044660018137594, 0.70306450000202125,
    0.70166108500198254, 0.70025577003602812, 0.698848568344445,
    0.697439493185296, 0.69602855783429363, 0.6946157755846778,
    0.69320115974708885, 0.691784723649441, 0.690366480636801,
    0.6889464440712566, 0.68752462733179565, 0.68610104381417747,
    0.68467570693080659, 0.68324863011060788, 0.6818198267988993,
    0.6803893104572637, 0.67895709456342479, 0.67752319261111871,
    0.67608761810996554, 0.67465038458534488, 0.67321150557826692,
    0.67177099464524348, 0.67032886535816349, 0.66888513130416161,
    0.66743980608549314, 0.665992903319405, 0.66454443663800522,
    0.66309441968813787, 0.66164286613125389, 0.660189789643279,
    0.658735203914489, 0.65727912264937938, 0.65582155956653432,
    0.65436252839850106, 0.65290204289165643, 0.65144011680608127,
    0.64997676391542836, 0.64851199800679238, 0.647045832880582,
    0.64557828235038872, 0.64410936024285537, 0.6426390803975488,
    0.6411674566668274, 0.63969450291571028, 0.6382202330217488,
    0.636744660874893, 0.635267800377363, 0.63378966544351834,
    0.6323102699997234, 0.63082962798422, 0.62934775334699511,
    0.62786466004964714, 0.62638036206525793, 0.62489487337825877,
    0.62340820798429875, 0.62192037989011451, 0.62043140311339562,
    0.61894129168265555, 0.61745005963709754, 0.615957721026482,
    0.61446428991099611, 0.61296978036111982, 0.61147420645749262,
    0.60997758229078325, 0.60847992196155554, 0.60698123958013406,
    0.60548154926647435, 0.6039808651500278, 0.60247920136960875,
    0.60097657207326227, 0.59947299141812849, 0.59796847357031235,
    0.59646303270474854, 0.59495668300506688, 0.59344943866346089,
    0.59194131388055338, 0.59043232286526059, 0.58892247983466217,
    0.587411799013863, 0.58590029463586291, 0.58438798094142064,
    0.58287487217891887, 0.58136098260423241, 0.5798463264805922,
    0.5783309180784505, 0.57681477167534811, 0.57529790155577876,
    0.57378032201105467, 0.57226204733917219, 0.570743091844676,
    0.56922346983852612, 0.56770319563796234, 0.56618228356636791,
    0.56466074795313681, 0.56313860313353825, 0.56161586344857939,
    0.56009254324487356, 0.55856865687450319, 0.55704421869488407,
    0.5555192430686321, 0.55399374436342541, 0.55246773695187157,
    0.55094123521137073, 0.54941425352397955, 0.5478868062762775,
    0.54635890785923058, 0.54483057266805346, 0.54330181510207887,
    0.54177264956461746, 0.54024309046282293, 0.53871315220755855,
    0.5371828492132581, 0.53565219589779312, 0.53412120668233565,
    0.53258989599122142, 0.53105827825181584, 0.52952636789437757,
    0.52799417935192061, 0.52646172706008143, 0.52492902545698139,
    0.5233960889830892, 0.52186293208108858, 0.520329569195738,
    0.51879601477373793, 0.51726228326359358, 0.51572838911547714,
    0.514194346781094, 0.5126601707135473, 0.511125875367197,
    0.50959147519752912, 0.5080569846610169, 0.506522418214984,
    0.50498779031747065, 0.50345311542709459, 0.50191840800291754,
    0.50038368250430765, 0.49884895339080221, 0.4973142351219737,
    0.49577954215729259, 0.49424488895598945, 0.49271028997692179,
    0.491175759678436, 0.48964131251823018, 0.488106962953221,
    0.48657272543940361, 0.48503861443171908, 0.48350464438391588,
    0.48197082974841465, 0.48043718497617166, 0.47890372451654328,
    0.477370462817148, 0.47583741432373311, 0.47430459348003695,
    0.472772014727652, 0.47123969250589143, 0.46970764125164977,
    0.46817587539926986, 0.46664440938040574, 0.46511325762388517,
    0.46358243455557629, 0.46205195459825066, 0.46052183217144571,
    0.45899208169133177, 0.45746271757057477, 0.45593375421819932,
    0.45440520603945583, 0.45287708743568095, 0.45134941280416668,
    0.4498221965380208, 0.44829545302603163, 0.44676919665253484,
    0.44524344179727637, 0.4437182028352758, 0.44219349413669345,
    0.44066933006669379, 0.43914572498530868, 0.43762269324730513,
    0.43610024920204671, 0.43457840719336122, 0.43305718155940431,
    0.4315365866325232, 0.43001663673912405, 0.42849734619953583,
    0.42697872932787406, 0.42546080043190859, 0.42394357381292735,
    0.4224270637656, 0.4209112845778481, 0.41939625053070423,
    0.41788197589818232, 0.41636847494714135, 0.4148557619371499,
    0.413343851120354, 0.41183275674134179, 0.41032249303700807,
    0.40881307423642255, 0.40730451456069477, 0.40579682822283847,
    0.404290029427641, 0.40278413237152594, 0.40127915124242231,
    0.3997751002196297, 0.39827199347368336, 0.3967698451662231,
    0.39526866944985894, 0.39376848046803609, 0.3922692923549041,
    0.39077111923518404, 0.38927397522403162, 0.3877778744269087,
    0.38628283093944682, 0.38478885884731734, 0.38329597222609729,
    0.38180418514113551, 0.38031351164742289, 0.37882396578945854,
    0.37733556160111592, 0.37584831310551381, 0.37436223431488225,
    0.37287733923042976, 0.37139364184221391, 0.3699111561290066,
    0.36842989605816512, 0.36694987558549907, 0.36547110865513804,
    0.36399360919940238, 0.36251739113867043, 0.36104246838124787,
    0.35956885482323647, 0.3580965643484037, 0.35662561082805033,
    0.35515600812088244, 0.35368777007287772, 0.35222091051715793,
    0.35075544327385721, 0.34929138214999056, 0.34782874093932648,
    0.34636753342225568, 0.34490777336565986, 0.34344947452278468,
    0.3419926506331088, 0.34053731542221322, 0.33908348260165511,
    0.33763116586883474, 0.33618037890687, 0.33473113538446575,
    0.33328344895578355, 0.33183733326031728, 0.33039280192276077,
    0.32894986855287967, 0.32750854674538576, 0.32606885007980718,
    0.3246307921203595, 0.32319438641582082, 0.32175964649940048,
    0.320326585888615, 0.31889521808515897, 0.31746555657477704,
    0.31603761482713882, 0.31461140629571133, 0.31318694441763062,
    0.3117642426135776, 0.31034331428765072, 0.30892417282723816,
    0.30750683160289416, 0.30609130396821194, 0.30467760325969623,
    0.30326574279664209, 0.30185573588100373, 0.30044759579727354,
    0.29904133581235548, 0.29763696917543875, 0.29623450911787552,
    0.29483396885305491, 0.29343536157627736, 0.29203870046463265,
    0.29064399867687485, 0.28925126935329648, 0.28786052561560838,
    0.28647178056681222, 0.28508504729108, 0.28370033885362972,
    0.28231766830060107, 0.28093704865893476, 0.27955849293624868,
    0.27818201412071425, 0.27680762518093577, 0.27543533906582895,
    0.2740651687044951, 0.27269712700610382, 0.27133122685976774,
    0.26996748113442381, 0.26860590267871109, 0.26724650432084823,
    0.26588929886851514, 0.26453429910873105, 0.26318151780773297,
    0.26183096771085762, 0.26048266154242039, 0.25913661200559396,
    0.25779283178229168, 0.25645133353304483, 0.25511212989688592,
    0.25377523349122871, 0.252440656911748, 0.25110841273226336,
    0.24977851350461905, 0.24845097175856612, 0.24712580000164447,
    0.24580301071906541, 0.24448261637359231, 0.2431646294054261,
    0.2418490622320848, 0.24053592724828932, 0.23922523682584551,
    0.23791700331352639, 0.23661123903695819, 0.2353079562985031,
    0.234007167377142, 0.23270888452836147, 0.23141311998403663,
    0.23011988595231531, 0.22882919461750523, 0.22754105813995651,
    0.22625548865594963, 0.22497249827757976, 0.22369209909264148,
    0.22241430316451849, 0.22113912253206652, 0.21986656920950026,
    0.2185966551862823, 0.21732939242700872, 0.21606479287129537,
    0.21480286843366808, 0.21354363100344742, 0.21228709244463906,
    0.21103326459582111, 0.20978215927003147, 0.20853378825465851,
    0.20728816331132932, 0.20604529617579731, 0.20480519855783424,
    0.20356788214111859, 0.2023333585831244, 0.20110163951501414,
    0.19987273654152593, 0.19864666124086677, 0.19742342516460337,
    0.19620303983755044, 0.19498551675766562, 0.19377086739593952,
    0.19255910319628677, 0.19135023557544029, 0.19014427592284266,
    0.18894123560053777, 0.18774112594306619, 0.18654395825735554,
    0.1853497438226166, 0.18415849389023564, 0.18297021968366789,
    0.18178493239833338, 0.18060264320151065, 0.17942336323223046,
    0.17824710360117307, 0.17707387539056224, 0.17590368965405989,
    0.17473655741666427, 0.17357248967460431, 0.17241149739523659,
    0.17125359151694242, 0.17009878294902314, 0.16894708257159968,
    0.16779850123550893, 0.16665304976220041, 0.16551073894363633,
    0.16437157954218912, 0.16323558229053881, 0.1621027578915743,
    0.16097311701828992, 0.15984667031368716, 0.15872342839067322,
    0.15760340183196053, 0.15648660118996843, 0.15537303698672311,
    0.15426271971375749, 0.15315565983201385, 0.15205186777174562,
    0.15095135393241638, 0.14985412868260523, 0.14876020235990628,
    0.14766958527083357, 0.14658228769072273, 0.14549831986363371,
    0.14441769200225568, 0.14334041428781003, 0.14226649686995374,
    0.14119594986668516, 0.14012878336424822, 0.1390650074170362,
    0.13800463204749913, 0.13694766724604723, 0.13589412297095843,
    0.13484400914828409, 0.13379733567175434, 0.13275411240268659,
    0.13171434916989178, 0.13067805576958169, 0.12964524196527671,
    0.1286159174877145, 0.12759009203475669, 0.12656777527129975,
    0.12554897682918154, 0.12453370630709287, 0.1235219732704857,
    0.1225137872514826, 0.1215091577487884, 0.1205080942276, 0.11951060611951619,
    0.11851670282245069, 0.11752639370054252, 0.11653968808406712,
    0.11555659526935036, 0.11457712451867852, 0.11360128506021339,
    0.11262908608790406, 0.11166053676139959, 0.110695646205965,
    0.10973442351239338, 0.10877687773691991, 0.10782301790113852,
    0.10687285299191551, 0.10592639196130449, 0.10498364372646363,
    0.10404461716956981, 0.10310932113773646, 0.10217776444292959,
    0.10124995586188412, 0.10032590413602233, 0.099405617971371263,
    0.09848910603847949, 0.097576376972337175, 0.096667439372293884,
    0.095762301801976868, 0.094860972789212017, 0.093963460825941758,
    0.093069774368146119, 0.0921799218357639, 0.091293911612610468,
    0.090411752046301808, 0.089533451448174428, 0.0886590180932067,
    0.087788460219942022, 0.086921786030410786, 0.086059003690052149,
    0.085200121327638934, 0.084345147035198853, 0.083494088867940464,
    0.082646954844175891, 0.081803752945245223, 0.080964491115442239,
    0.080129177261939133, 0.079297819254711133, 0.078470424926464,
    0.0776470020725592, 0.076827558450940081, 0.076012101782059971,
    0.075200639748808584, 0.074393179996439851, 0.0735897301325002,
    0.072790297726755715, 0.07199489031112255, 0.071203515379595017,
    0.070416180388174321, 0.069632892754799891, 0.068853659859278438,
    0.068078489043214119, 0.067307387609940761, 0.066540362824451249,
    0.065777421913330691, 0.065018572064687641, 0.0642638204280857,
    0.063513174114477544, 0.062766640196137258, 0.062024225706592884,
    0.061285937640561672, 0.060551782953883249, 0.059821768563454281,
    0.059095901347163415, 0.058374188143825889, 0.057656635753120078,
    0.056943250935522993, 0.056234040412245889, 0.0555290108651722,
    0.054828168936793986, 0.054131521230148638, 0.053439074308757994,
    0.05275083469656594, 0.052066808877876125, 0.051387003297292566,
    0.050711424359657031, 0.050040078429990253, 0.049372971833431478,
    0.048710110855177957, 0.048051501740427272, 0.0473971506943176,
    0.046747063881868722, 0.046101247427925651, 0.045459707417099371,
    0.044822449893709648, 0.044189480861729136, 0.043560806284725473,
    0.042936432085806275, 0.042316364147562735, 0.041700608312013776,
    0.0410891703805521, 0.040482056113888831, 0.039879271231998914,
    0.039280821414068023, 0.038686712298438841, 0.038096949482557207,
    0.037511538522920662, 0.0369304849350246, 0.03635379419331175,
    0.03578147173111984, 0.03521352294062996, 0.034649953172816828,
    0.03409076773739822, 0.033535971902783512, 0.032985570896025884,
    0.032439569902772247, 0.031897974067214008, 0.031360788492039493,
    0.030828018238385269, 0.030299668325788343, 0.029775743732139648,
    0.029256249393635969, 0.028741190204734646, 0.028230571018106776,
    0.027724396644591365, 0.027222671853150415, 0.026725401370824187,
    0.02623258988268562, 0.025744242031797371, 0.025260362419167626,
    0.024780955603706356, 0.024306026102182965, 0.023835578389183487,
    0.02336961689706829, 0.02290814601593083, 0.022451170093555295,
    0.021998693435376693, 0.021550720304439941, 0.021107254921359175,
    0.020668301464278838, 0.020233864068833873, 0.019803946828110375,
    0.019378553792608055, 0.018957688970200892, 0.018541356326100378,
    0.018129559782817606, 0.017722303220126134, 0.017319590475026181,
    0.016921425341707874, 0.016527811571515449, 0.016138752872912332,
    0.015754252911446, 0.015374315309713282, 0.014998943647326568,
    0.01462814146087954, 0.014261912243914543, 0.013900259446889329,
    0.013543186477144198, 0.013190696698870574, 0.012842793433078981,
    0.01249947995756745, 0.012160759506891217, 0.01182663527233202,
    0.011497110401867572, 0.011172188000142858, 0.010851871128439883,
    0.010536162804649529, 0.010225066003242966, 0.0099185836552431184,
    0.0096167186481979083, 0.0093194738261525578, 0.009026851989622442,
    0.0087388558955676654, 0.0084554882573663614, 0.0081767517447889349,
    0.0079026489839738034, 0.007633182557401752, 0.0073683550038720624,
    0.0071081688184786995, 0.00685262645258633, 0.0066017303138076189,
    0.00635548276598058, 0.006113886129145929, 0.0058769426795255431,
    0.00564465464950098, 0.0054170242275923264, 0.0051940535584377168,
    0.0049757447427728474, 0.0047620998374117152, 0.0045531208552267444,
    0.0043488097651298574, 0.0041491684920542671, 0.0039541989169362135,
    0.0037639028766968119, 0.0035782821642254548, 0.0033973385283623814,
    0.003221073673882302, 0.0030494892614786884, 0.0028825869077476196,
    0.00272036818517285, 0.0025628346221110432, 0.0024099877027770056,
    0.0022618288672302533, 0.0021183595113609677, 0.0019795809868770609,
    0.0018454946012914086, 0.0017161016179095823, 0.0015914032558178026,
    0.0014714006898715604, 0.0013560950506845693, 0.001245487424618108,
    0.0011395788537706397, 0.0010383703359682084, 0.00094186282475483551,
    0.0008500572293838049, 0.00076295441480872528, 0.00068055520167575878,
    0.00060286036631551632, 0.00052987064073617418, 0.00046158671261614659,
    0.00039800922529786842, 0.0003391387777817445, 0.00028497592472032096,
    0.00023552117641323367, 0.0001907749988023788, 0.00015073781346730541,
    0.0001154099976216072, 8.4791884109036708E-5, 5.8883761400674306E-5,
    3.768587359187503E-5, 2.11984204002702E-5, 9.421557163713512E-6,
    2.3553948388377322E-6, 0.0 };

  static const boolean_T b_bv[99] = { true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, false, false,
    false, false, false, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true };

  __m128d r;
  __m128d r1;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack g_st;
  creal_T U[2048];
  creal_T Y[2048];
  real_T y[2048];
  real_T Suu[99];
  real_T Syy[99];
  real_T b_y[99];
  real_T st[99];
  real_T state_data[80];
  real_T b[2];
  real_T b_dv1[2];
  real_T f_res;
  real_T med_new;
  real_T med_ref;
  real_T re_tmp;
  real_T tiny;
  real_T z_max;
  int32_T b_idx;
  int32_T b_size;
  int32_T ck_size;
  int32_T i;
  int32_T idx;
  int32_T k;
  int8_T c_tmp_data[99];
  int8_T tmp_data[99];
  int8_T b_tmp_data[3];
  boolean_T has_input[99];
  c_st.prev = sp;
  c_st.tls = sp->tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  g_st.prev = &e_st;
  g_st.tls = e_st.tls;

  /*  ---------------------------------------------------------- slow pipeline */
  state->hop_count++;
  c_st.site = &gb_emlrtRSI;

  /*  ------------------------------------------------------------- utilities */
  d_st.site = &f_emlrtRSI;
  e_st.site = &f_emlrtRSI;
  b_mldivide(&e_st, state->xdd, b);
  e_st.site = &v_emlrtRSI;
  b_mtimes(dv2, b, y);
  c_st.site = &gb_emlrtRSI;
  for (i = 0; i <= 2046; i += 2) {
    r = _mm_loadu_pd(&state->xdd[i]);
    r1 = _mm_loadu_pd(&y[i]);
    _mm_storeu_pd(&y[i], _mm_mul_pd(_mm_loadu_pd(&b_dv[i]), _mm_sub_pd(r, r1)));
  }

  d_st.site = &y_emlrtRSI;
  e_st.site = &ab_emlrtRSI;
  emlrtFFTWSetNumThreads(8);
  emlrtFFTW_1D_R2C(&y[0], (real_T *)&U[0], 1, 2048, 2048, 1, -1);
  c_st.site = &hb_emlrtRSI;

  /*  ------------------------------------------------------------- utilities */
  d_st.site = &f_emlrtRSI;
  e_st.site = &f_emlrtRSI;
  b_mldivide(&e_st, state->xdm, b);
  e_st.site = &v_emlrtRSI;
  b_mtimes(dv2, b, y);
  c_st.site = &hb_emlrtRSI;
  for (i = 0; i <= 2046; i += 2) {
    r = _mm_loadu_pd(&state->xdm[i]);
    r1 = _mm_loadu_pd(&y[i]);
    _mm_storeu_pd(&y[i], _mm_mul_pd(_mm_loadu_pd(&b_dv[i]), _mm_sub_pd(r, r1)));
  }

  d_st.site = &y_emlrtRSI;
  e_st.site = &ab_emlrtRSI;
  emlrtFFTWSetNumThreads(8);
  emlrtFFTW_1D_R2C(&y[0], (real_T *)&Y[0], 1, 2048, 2048, 1, -1);
  state->ring_pos = b_mod(state->ring_pos) + 1.0;
  for (i = 0; i < 99; i++) {
    med_new = muDoubleScalarHypot(U[i + 2].re, U[i + 2].im);
    b_y[i] = med_new * med_new;
  }

  if (state->ring_pos != (int32_T)muDoubleScalarFloor(state->ring_pos)) {
    emlrtIntegerCheckR2012b(state->ring_pos, &j_emlrtDCI, (emlrtConstCTX)sp);
  }

  idx = (int32_T)state->ring_pos;
  if ((idx < 1) || (idx > 17)) {
    emlrtDynamicBoundsCheckR2012b(idx, 1, 17, &j_emlrtBCI, (emlrtConstCTX)sp);
  }

  for (i = 0; i < 99; i++) {
    state->Suu_seg[i + 99 * (idx - 1)] = b_y[i];
    med_new = muDoubleScalarHypot(Y[i + 2].re, Y[i + 2].im);
    b_y[i] = med_new * med_new;
  }

  if (state->ring_pos != (int32_T)muDoubleScalarFloor(state->ring_pos)) {
    emlrtIntegerCheckR2012b(state->ring_pos, &i_emlrtDCI, (emlrtConstCTX)sp);
  }

  idx = (int32_T)state->ring_pos;
  if ((idx < 1) || (idx > 17)) {
    emlrtDynamicBoundsCheckR2012b(idx, 1, 17, &i_emlrtBCI, (emlrtConstCTX)sp);
  }

  memcpy(&state->Syy_seg[idx * 99 + -99], &b_y[0], 99U * sizeof(real_T));
  if (state->ring_pos != (int32_T)muDoubleScalarFloor(state->ring_pos)) {
    emlrtIntegerCheckR2012b(state->ring_pos, &h_emlrtDCI, (emlrtConstCTX)sp);
  }

  idx = (int32_T)state->ring_pos;
  if ((idx < 1) || (idx > 17)) {
    emlrtDynamicBoundsCheckR2012b(idx, 1, 17, &h_emlrtBCI, (emlrtConstCTX)sp);
  }

  for (i = 0; i < 99; i++) {
    med_new = U[i + 2].re;
    med_ref = -U[i + 2].im;
    re_tmp = Y[i + 2].re;
    tiny = Y[i + 2].im;
    b_idx = i + 99 * (idx - 1);
    state->Suy_seg[b_idx].re = re_tmp * med_new - tiny * med_ref;
    state->Suy_seg[b_idx].im = re_tmp * med_ref + tiny * med_new;
  }

  state->seg_count = muDoubleScalarMin(state->seg_count + 1.0, 17.0);
  if (!(state->seg_count < 17.0)) {
    creal_T Lb_data[99];
    creal_T M[99];
    creal_T Suy[99];
    real_T b_state[1683];
    real_T g2[99];
    real_T g2raw[99];
    real_T b_res;
    real_T b_st;
    real_T f_st;
    int32_T b_i;
    boolean_T exitg1;
    boolean_T st_valid;

    /*  robust aggregation over the ring (median across segments) */
    c_st.site = &ib_emlrtRSI;
    median(state->Suu_seg, Suu);
    c_st.site = &jb_emlrtRSI;
    median(state->Syy_seg, Syy);
    for (i = 0; i < 1683; i++) {
      b_state[i] = state->Suy_seg[i].re;
    }

    c_st.site = &kb_emlrtRSI;
    median(b_state, g2);
    for (i = 0; i < 1683; i++) {
      b_state[i] = state->Suy_seg[i].im;
    }

    c_st.site = &lb_emlrtRSI;
    median(b_state, st);
    for (i = 0; i < 99; i++) {
      Suy[i].re = g2[i];
      Suy[i].im = st[i];
    }

    st_valid = !muDoubleScalarIsNaN(Suu[0]);
    if (st_valid) {
      idx = 1;
    } else {
      idx = 0;
      b_idx = 2;
      exitg1 = false;
      while ((!exitg1) && (b_idx < 100)) {
        if (!muDoubleScalarIsNaN(Suu[b_idx - 1])) {
          idx = b_idx;
          exitg1 = true;
        } else {
          b_idx++;
        }
      }
    }

    if (idx == 0) {
      med_new = Suu[0];
    } else {
      med_new = Suu[idx - 1];
      idx++;
      for (i = idx; i < 100; i++) {
        med_ref = Suu[i - 1];
        if (med_new < med_ref) {
          med_new = med_ref;
        }
      }
    }

    tiny = muDoubleScalarMax(med_new, 1.0) * 1.0E-14;
    for (i = 0; i < 99; i++) {
      med_new = Suy[i].re;
      med_ref = Suy[i].im;
      re_tmp = muDoubleScalarMax(Suu[i], tiny);
      if (med_ref == 0.0) {
        M[i].re = med_new / re_tmp;
        M[i].im = 0.0;
      } else if (med_new == 0.0) {
        M[i].re = 0.0;
        M[i].im = med_ref / re_tmp;
      } else {
        M[i].re = med_new / re_tmp;
        M[i].im = med_ref / re_tmp;
      }
    }

    c_st.site = &mb_emlrtRSI;
    d_st.site = &nc_emlrtRSI;
    e_st.site = &oc_emlrtRSI;
    med_ref = tiny * tiny;
    for (i = 0; i < 99; i++) {
      med_new = muDoubleScalarHypot(Suy[i].re, Suy[i].im);
      re_tmp = Syy[i];
      med_new = muDoubleScalarMin(med_new * med_new / muDoubleScalarMax(Suu[i] *
        re_tmp, med_ref), 1.0);
      g2raw[i] = med_new;
      re_tmp *= muDoubleScalarMax(1.0 - muDoubleScalarMax(0.0, (9.10992522361791
        * med_new - 1.0) / 8.10992522361791), 0.03);
      Syy[i] = re_tmp;
    }

    /*  a bin is excited only with significant coherence, real input power, AND */
    /*  no leakage taint: an isolated false-coherence bin at a quiet frequency */
    /*  would read |M| = huge and nuke the margin to zero, and a bin sitting */
    /*  >sidelobe_db below a +-3 Hz neighbor is the segment window's own */
    /*  (coherent!) leakage of a strong band edge, not excitation. */
    c_st.site = &nb_emlrtRSI;
    d_st.site = &nc_emlrtRSI;
    e_st.site = &oc_emlrtRSI;
    if (st_valid) {
      idx = 1;
    } else {
      idx = 0;
      b_idx = 2;
      exitg1 = false;
      while ((!exitg1) && (b_idx < 95)) {
        if (!muDoubleScalarIsNaN(Suu[iv1[b_idx - 1]])) {
          idx = b_idx;
          exitg1 = true;
        } else {
          b_idx++;
        }
      }
    }

    if (idx == 0) {
      med_new = Suu[0];
    } else {
      med_new = Suu[iv1[idx - 1]];
      idx++;
      for (i = idx; i < 95; i++) {
        med_ref = Suu[iv1[i - 1]];
        if (med_new < med_ref) {
          med_new = med_ref;
        }
      }
    }

    med_new = muDoubleScalarMax(med_new * 0.00031622776601683794, tiny);
    for (i = 0; i < 99; i++) {
      has_input[i] = (Suu[i] > med_new);
    }

    c_st.site = &ob_emlrtRSI;
    movmax(&c_st, Suu, g2);

    /*  the residual branch watches only frequencies the COMMAND DOES NOT DRIVE: */
    /*  where the input has power, closed-loop health is the ST branch's job, and */
    /*  partially-coherent leakage there is not evidence of instability. */
    state->update_count++;

    /*  burst-power mask: only the STABLE conditions (input support), so the */
    /*  band membership does not wobble with per-window coherence and inflate */
    /*  the calibrated spread of the burst statistic */
    /*  ---- excitation-regime change detector ----------------------------------- */
    /*  The support of the COMMAND's input power changing (test phase */
    /*  started/stopped/moved band) is an exogenous, observable event that */
    /*  legitimately moves the quiet-bin output floor: instability grows */
    /*  quiet-bin power but cannot change which bins the command drives. The */
    /*  detector keys on the input-power mask (has_input), which is coherence- */
    /*  independent and therefore stable, unlike the excited set. On a sustained */
    /*  change, recollect the residual baseline; the ST branch keeps running. */
    for (i = 0; i < 99; i++) {
      boolean_T b1;
      boolean_T b_b;
      st_valid = b_bv[i];
      med_new = g2raw[i];
      b_b = has_input[i];
      state->sb_excited[i] = (st_valid && (med_new > 0.43325381990144252) && b_b
        && (Suu[i] > g2[i] * 0.0031622776601683794));
      b1 = (bv1[i] && (!b_b));
      state->sb_qpmask[i] = b1;
      state->sb_quiet[i] = (b1 && (med_new < 0.15));
      b_b = (b_b && st_valid);
      has_input[i] = b_b;
    }

    state->sb_ndiff = 0.0;
    if (state->ready) {
      boolean_T b_bv1[99];
      for (i = 0; i < 99; i++) {
        b_bv1[i] = has_input[i] ^ state->regime_mask[i];
      }

      idx = intnnz(b_bv1);
      state->sb_ndiff = idx;
      if (idx > muDoubleScalarMax(6.0, 0.5 * (real_T)intnnz(state->regime_mask)))
      {
        state->regime_count++;
      } else {
        state->regime_count = 0.0;
      }

      if (state->regime_count >= 8.0) {
        state->ready = false;
        state->cal_count = 0.0;
        state->cal_tries = 0.0;
        state->cal_rejects = 0.0;
        state->cal_d_count = 0.0;
        state->res_on = false;
        state->res_count = 0.0;
        state->regime_count = 0.0;
        memcpy(&state->regime_mask[0], &has_input[0], 99U * sizeof(boolean_T));
        state->cus_st = 0.0;
        for (i = 0; i < 5; i++) {
          state->cus_burst[i] = 0.0;
        }

        state->p_in_ema = rtNaN;
        state->recal_pending = true;
      }
    } else {
      memcpy(&state->regime_mask[0], &has_input[0], 99U * sizeof(boolean_T));
    }

    /*  ---- residual calibration (initial and after a regime change) ----------- */
    if ((!state->ready) && (state->hop_count * 0.25 >= 10.0)) {
      real_T b_Syy[94];
      boolean_T guard1;
      state->cal_tries++;
      for (i = 0; i < 94; i++) {
        b_Syy[i] = Syy[iv1[i]];
      }

      c_st.site = &pb_emlrtRSI;
      med_new = b_median(&c_st, b_Syy);
      guard1 = false;
      if (!(state->cal_count == 0.0)) {
        if (state->cal_count < 1.0) {
          idx = 0;
        } else {
          if (state->cal_count != (int32_T)muDoubleScalarFloor(state->cal_count))
          {
            emlrtIntegerCheckR2012b(state->cal_count, &g_emlrtDCI,
              (emlrtConstCTX)sp);
          }

          idx = (int32_T)state->cal_count;
          if ((idx < 1) || (idx > 80)) {
            emlrtDynamicBoundsCheckR2012b(idx, 1, 80, &g_emlrtBCI,
              (emlrtConstCTX)sp);
          }
        }

        if (idx - 1 >= 0) {
          memcpy(&state_data[0], &state->cal_med[0], (uint32_T)idx * sizeof
                 (real_T));
        }

        c_st.site = &qb_emlrtRSI;
        med_ref = c_median(&c_st, state_data, idx);
        if ((med_new < 4.0 * med_ref) && (med_new > med_ref / 4.0)) {
          guard1 = true;
        } else {
          /*  a startup transient (e.g. actuator homing) can poison the */
          /*  first reference; if everything since then is rejected, the */
          /*  reference was the outlier - start over */
          state->cal_rejects++;
          if (state->cal_rejects >= 12.0) {
            state->cal_count = 0.0;
            state->cal_rejects = 0.0;
          }
        }
      } else {
        guard1 = true;
      }

      if (guard1) {
        state->cal_count++;
        if (state->cal_count != (int32_T)muDoubleScalarFloor(state->cal_count))
        {
          emlrtIntegerCheckR2012b(state->cal_count, &f_emlrtDCI, (emlrtConstCTX)
            sp);
        }

        idx = (int32_T)state->cal_count;
        if ((idx < 1) || (idx > 80)) {
          emlrtDynamicBoundsCheckR2012b(idx, 1, 80, &f_emlrtBCI, (emlrtConstCTX)
            sp);
        }

        memcpy(&state->cal_res[idx * 99 + -99], &Syy[0], 99U * sizeof(real_T));
        if (state->cal_count != (int32_T)muDoubleScalarFloor(state->cal_count))
        {
          emlrtIntegerCheckR2012b(state->cal_count, &e_emlrtDCI, (emlrtConstCTX)
            sp);
        }

        idx = (int32_T)state->cal_count;
        if ((idx < 1) || (idx > 80)) {
          emlrtDynamicBoundsCheckR2012b(idx, 1, 80, &e_emlrtBCI, (emlrtConstCTX)
            sp);
        }

        state->cal_med[idx - 1] = med_new;

        /*  fast-path burst calibration sample: newest fast segment's */
        /*  undriven sub-band powers (what the burst detector watches) */
        if (state->cal_count != (int32_T)muDoubleScalarFloor(state->cal_count))
        {
          emlrtIntegerCheckR2012b(state->cal_count, &k_emlrtDCI, (emlrtConstCTX)
            sp);
        }

        idx = (int32_T)state->cal_count;
        if ((idx < 1) || (idx > 80)) {
          emlrtDynamicBoundsCheckR2012b(idx, 1, 80, &k_emlrtBCI, (emlrtConstCTX)
            sp);
        }

        c_st.site = &rb_emlrtRSI;
        fastQuietPower(&c_st, state->fSyy, state->fseg_count, state->fring_pos,
                       state->sb_qpmask, &state->cal_pf[5 * (idx - 1)]);
        state->cal_rejects = 0.0;
      }

      if ((state->cal_count >= 80.0) || ((state->cal_tries >= 600.0) &&
           (state->cal_count >= 24.0))) {
        c_st.site = &sb_emlrtRSI;
        finalizeCalibration(&c_st, state, state->sb_quiet);
      }
    }

    /*  ---- ST branch ---------------------------------------------------------- */
    for (i = 0; i < 99; i++) {
      med_new = M[i].re;
      med_ref = M[i].im;
      Suy[i].re = 1.0 - med_new;
      Suy[i].im = 0.0 - med_ref;
      re_tmp = muDoubleScalarHypot(1.0 - med_new, 0.0 - med_ref);
      g2raw[i] = re_tmp;
      st[i] = re_tmp * re_tmp;
      med_new = muDoubleScalarHypot(med_new, med_ref);
      b_y[i] = med_new * med_new;
    }

    c_st.site = &tb_emlrtRSI;
    for (i = 0; i <= 96; i += 2) {
      r = _mm_loadu_pd(&st[i]);
      r1 = _mm_loadu_pd(&b_y[i]);
      _mm_storeu_pd(&st[i], _mm_add_pd(r, r1));
    }

    st[98] += b_y[98];
    for (i = 0; i <= 96; i += 2) {
      r = _mm_loadu_pd(&st[i]);
      _mm_storeu_pd(&st[i], _mm_sqrt_pd(r));
    }

    st[98] = muDoubleScalarSqrt(st[98]);
    for (i = 0; i <= 96; i += 2) {
      b_dv1[0] = muDoubleScalarMax(st[i], 2.2204460492503131E-16);
      b_dv1[1] = muDoubleScalarMax(st[i + 1], 2.2204460492503131E-16);
      r = _mm_loadu_pd(&b_dv1[0]);
      _mm_storeu_pd(&b_y[i], _mm_div_pd(_mm_set1_pd(1.0), _mm_mul_pd(_mm_set1_pd
        (1.4142135623730951), r)));
    }

    b_y[98] = 1.0 / (1.4142135623730951 * muDoubleScalarMax(st[98],
      2.2204460492503131E-16));
    c_st.site = &ub_emlrtRSI;
    maskedMovMedian(&c_st, b_y, state->sb_excited, g2);
    b_i = intnnz(state->sb_excited);
    if (b_i >= 5) {
      for (i = 0; i < 99; i++) {
        if (!state->sb_excited[i]) {
          g2[i] = rtNaN;
        }
      }

      if (!muDoubleScalarIsNaN(g2[0])) {
        b_idx = 1;
      } else {
        b_idx = 0;
        idx = 2;
        exitg1 = false;
        while ((!exitg1) && (idx < 100)) {
          if (!muDoubleScalarIsNaN(g2[idx - 1])) {
            b_idx = idx;
            exitg1 = true;
          } else {
            idx++;
          }
        }
      }

      if (b_idx == 0) {
        b_st = g2[0];
        b_idx = 1;
      } else {
        b_st = g2[b_idx - 1];
        idx = b_idx + 1;
        for (i = idx; i < 100; i++) {
          med_new = g2[i - 1];
          if (b_st > med_new) {
            b_st = med_new;
            b_idx = i;
          }
        }
      }

      /*  min skips NaN */
      f_st = ((real_T)b_idx - 1.0) + 2.0;
      st_valid = true;
    } else {
      b_st = rtNaN;
      f_st = rtNaN;
      st_valid = false;
    }

    /*  ---- residual branch (only with a baseline for the current regime) ------ */
    if (state->ready) {
      c_st.site = &vb_emlrtRSI;
      b_res = residualBranch(&c_st, state, Syy, state->sb_quiet, &f_res, &z_max);
    } else {
      b_res = rtNaN;
      f_res = rtNaN;
      z_max = rtNaN;
    }

    /*  ---- authority-planning curve: margin vs relative loop-gain multiplier --- */
    for (i = 0; i < 25; i++) {
      state->sb_pred[i] = rtNaN;
    }

    state->sb_predvalid = false;
    if (st_valid) {
      int32_T trueCount;
      b_idx = 0;
      idx = 0;
      for (i = 0; i < 99; i++) {
        if (g2raw[i] < 0.001) {
          b_idx++;
          tmp_data[idx] = (int8_T)i;
          idx++;
        }
      }

      for (i = 0; i < b_idx; i++) {
        Lb_data[i] = Suy[tmp_data[i]];
      }

      c_st.site = &wb_emlrtRSI;
      b_size = angle(Lb_data, b_idx, b_y);
      for (i = 0; i < b_size; i++) {
        med_new = b_y[i];
        Lb_data[i].re = med_new * 0.0;
        Lb_data[i].im = med_new;
      }

      c_st.site = &wb_emlrtRSI;
      b_exp(Lb_data, &b_size);
      for (i = 0; i < b_size; i++) {
        Lb_data[i].re *= 0.001;
        Lb_data[i].im *= 0.001;
      }

      if (b_idx != b_size) {
        emlrtSubAssignSizeCheck1dR2017a(b_idx, b_size, &emlrtECI, (emlrtConstCTX)
          sp);
      }

      for (i = 0; i < b_size; i++) {
        Suy[tmp_data[i]] = Lb_data[i];
      }

      c_st.site = &xb_emlrtRSI;
      d_st.site = &gf_emlrtRSI;
      e_st.site = &hf_emlrtRSI;
      trueCount = 0;
      idx = 0;
      for (i = 0; i < 99; i++) {
        if (state->sb_excited[i]) {
          real_T ai;
          real_T ar;
          trueCount++;
          ar = M[i].re;
          ai = M[i].im;
          re_tmp = Suy[i].re;
          tiny = Suy[i].im;
          if (tiny == 0.0) {
            if (ai == 0.0) {
              Lb_data[idx].re = ar / re_tmp;
              Lb_data[idx].im = 0.0;
            } else if (ar == 0.0) {
              Lb_data[idx].re = 0.0;
              Lb_data[idx].im = ai / re_tmp;
            } else {
              Lb_data[idx].re = ar / re_tmp;
              Lb_data[idx].im = ai / re_tmp;
            }
          } else if (re_tmp == 0.0) {
            if (ar == 0.0) {
              Lb_data[idx].re = ai / tiny;
              Lb_data[idx].im = 0.0;
            } else if (ai == 0.0) {
              Lb_data[idx].re = 0.0;
              Lb_data[idx].im = -(ar / tiny);
            } else {
              Lb_data[idx].re = ai / tiny;
              Lb_data[idx].im = -(ar / tiny);
            }
          } else {
            real_T brm;
            brm = muDoubleScalarAbs(re_tmp);
            med_new = muDoubleScalarAbs(tiny);
            if (brm > med_new) {
              med_ref = tiny / re_tmp;
              med_new = re_tmp + med_ref * tiny;
              Lb_data[idx].re = (ar + med_ref * ai) / med_new;
              Lb_data[idx].im = (ai - med_ref * ar) / med_new;
            } else if (med_new == brm) {
              if (re_tmp > 0.0) {
                med_ref = 0.5;
              } else {
                med_ref = -0.5;
              }

              if (tiny > 0.0) {
                med_new = 0.5;
              } else {
                med_new = -0.5;
              }

              Lb_data[idx].re = (ar * med_ref + ai * med_new) / brm;
              Lb_data[idx].im = (ai * med_ref - ar * med_new) / brm;
            } else {
              med_ref = re_tmp / tiny;
              med_new = tiny + med_ref * re_tmp;
              Lb_data[idx].re = (med_ref * ar + ai) / med_new;
              Lb_data[idx].im = (med_ref * ai - ar) / med_new;
            }
          }

          idx++;
        }
      }

      for (k = 0; k < 25; k++) {
        for (i = 0; i < trueCount; i++) {
          med_new = dv[k];
          Suy[i].re = med_new * Lb_data[i].re;
          Suy[i].im = med_new * Lb_data[i].im;
        }

        c_st.site = &yb_emlrtRSI;
        d_st.site = &yb_emlrtRSI;
        b_size = b_abs(Suy, trueCount, b_y);
        d_st.site = &oc_emlrtRSI;
        c_st.site = &yb_emlrtRSI;
        for (i = 0; i < trueCount; i++) {
          Suy[i].re++;
        }

        d_st.site = &yb_emlrtRSI;
        ck_size = b_abs(Suy, trueCount, Suu);
        idx = b_size / 2 * 2;
        b_idx = idx - 2;
        for (i = 0; i <= b_idx; i += 2) {
          r = _mm_loadu_pd(&b_y[i]);
          r = _mm_mul_pd(r, r);
          r = _mm_add_pd(r, _mm_set1_pd(1.0));
          r = _mm_mul_pd(_mm_set1_pd(2.0), r);
          _mm_storeu_pd(&b_y[i], r);
        }

        for (i = idx; i < b_size; i++) {
          med_new = b_y[i];
          b_y[i] = 2.0 * (med_new * med_new + 1.0);
        }

        d_st.site = &yb_emlrtRSI;
        b_sqrt(&d_st, b_y, &b_size);
        d_st.site = &gf_emlrtRSI;
        e_st.site = &hf_emlrtRSI;
        assertCompatibleDims(&e_st, ck_size, b_size);
        if (ck_size == b_size) {
          idx = (ck_size / 2) << 1;
          b_idx = idx - 2;
          for (i = 0; i <= b_idx; i += 2) {
            r = _mm_loadu_pd(&Suu[i]);
            r1 = _mm_loadu_pd(&b_y[i]);
            _mm_storeu_pd(&Suu[i], _mm_div_pd(r, r1));
          }

          for (i = idx; i < ck_size; i++) {
            Suu[i] /= b_y[i];
          }
        } else {
          rdivide(Suu, &ck_size, b_y, &b_size);
        }

        c_st.site = &ac_emlrtRSI;
        d_st.site = &jf_emlrtRSI;
        e_st.site = &kf_emlrtRSI;
        g_st.site = &lf_emlrtRSI;
        if (ck_size < 1) {
          emlrtErrorWithMessageIdR2018a(&g_st, &i_emlrtRTEI,
            "Coder:toolbox:eml_min_or_max_varDimZero",
            "Coder:toolbox:eml_min_or_max_varDimZero", 0);
        }

        if (ck_size <= 2) {
          if (ck_size - 1 == 0) {
            med_new = Suu[0];
          } else {
            med_new = Suu[ck_size - 1];
            if ((!(Suu[0] > med_new)) && ((!muDoubleScalarIsNaN(Suu[0])) ||
                 muDoubleScalarIsNaN(med_new))) {
              med_new = Suu[0];
            }
          }
        } else {
          if (!muDoubleScalarIsNaN(Suu[0])) {
            idx = 1;
          } else {
            idx = 0;
            b_idx = 2;
            exitg1 = false;
            while ((!exitg1) && (b_idx <= ck_size)) {
              if (!muDoubleScalarIsNaN(Suu[b_idx - 1])) {
                idx = b_idx;
                exitg1 = true;
              } else {
                b_idx++;
              }
            }
          }

          if (idx == 0) {
            med_new = Suu[0];
          } else {
            med_new = Suu[idx - 1];
            idx++;
            for (i = idx; i <= ck_size; i++) {
              med_ref = Suu[i - 1];
              if (med_new > med_ref) {
                med_new = med_ref;
              }
            }
          }
        }

        state->sb_pred[k] = muDoubleScalarMin(0.70710678118654746, med_new);
        if (*emlrtBreakCheckR2012bFlagVar != 0) {
          emlrtBreakCheckR2012b((emlrtConstCTX)sp);
        }
      }

      state->sb_predvalid = true;
    }

    /*  cache for the fast path / info */
    state->sb_st = b_st;
    state->sb_res = b_res;
    state->sb_fst = f_st;
    state->sb_fres = f_res;
    state->sb_zmax = z_max;
    state->sb_stvalid = st_valid;
    state->sb_nexc = b_i;

    /*  slow FRF projected onto the fast grid (reference for the fast */
    /*  FRF-change statistic): per fast cell, mean of M over its excited bins */
    for (k = 0; k < 25; k++) {
      int8_T i1;
      memset(&has_input[0], 0, 99U * sizeof(boolean_T));
      b_idx = k << 2;
      i1 = iv[k];
      if (b_idx + 1 > i1) {
        b_idx = 0;
        idx = 0;
      } else {
        idx = i1;
      }

      idx -= b_idx;
      for (i = 0; i < idx; i++) {
        has_input[b_idx + i] = true;
      }

      for (i = 0; i < 99; i++) {
        has_input[i] = (has_input[i] && state->sb_excited[i]);
      }

      if (vectorAny(has_input, 99)) {
        b_idx = 0;
        idx = 0;
        for (i = 0; i < 99; i++) {
          if (has_input[i]) {
            b_idx++;
            c_tmp_data[idx] = (int8_T)i;
            idx++;
          }
        }

        for (i = 0; i < b_idx; i++) {
          Lb_data[i] = M[c_tmp_data[i]];
        }

        emlrtStack *b_sp;
        c_st.site = &bc_emlrtRSI;
        b_sp = &c_st;
        state->sb_Tsf[k] = mean(b_sp, Lb_data, b_idx);
        state->sb_Tsf_valid[k] = true;
      } else {
        state->sb_Tsf[k].re = 0.0;
        state->sb_Tsf[k].im = 0.0;
        state->sb_Tsf_valid[k] = false;
      }

      if (*emlrtBreakCheckR2012bFlagVar != 0) {
        emlrtBreakCheckR2012b((emlrtConstCTX)sp);
      }
    }

    /*  temporal median over DISTINCT slow updates (kills one-window artifacts) */
    if (muDoubleScalarIsNaN(b_st) && muDoubleScalarIsNaN(b_res)) {
      med_new = rtNaN;
    } else {
      med_new = muDoubleScalarMin(muDoubleScalarMin(b_st, b_res),
        0.70710678118654746);
    }

    state->slow_hist[0] = state->slow_hist[1];
    state->slow_hist[1] = state->slow_hist[2];
    state->slow_hist[2] = med_new;
    b_idx = 0;
    if (!muDoubleScalarIsNaN(state->slow_hist[0])) {
      b_idx = 1;
    }

    if (!muDoubleScalarIsNaN(state->slow_hist[1])) {
      b_idx++;
    }

    if (!muDoubleScalarIsNaN(state->slow_hist[2])) {
      b_idx++;
    }

    idx = 0;
    if (!muDoubleScalarIsNaN(state->slow_hist[0])) {
      b_tmp_data[0] = 0;
      idx = 1;
    }

    if (!muDoubleScalarIsNaN(state->slow_hist[1])) {
      b_tmp_data[idx] = 1;
      idx++;
    }

    if (!muDoubleScalarIsNaN(state->slow_hist[2])) {
      b_tmp_data[idx] = 2;
    }

    if (b_idx == 0) {
      state->sb_b = rtNaN;
    } else {
      real_T b_state_data[3];
      for (i = 0; i < b_idx; i++) {
        b_state_data[i] = state->slow_hist[b_tmp_data[i]];
      }

      c_st.site = &cc_emlrtRSI;
      state->sb_b = c_median(&c_st, b_state_data, b_idx);
    }

    if (!muDoubleScalarIsNaN(med_new)) {
      if (muDoubleScalarIsNaN(state->b_slow_filt)) {
        state->b_slow_filt = med_new;
      } else {
        state->b_slow_filt = 0.8 * state->b_slow_filt + 0.2 * med_new;
      }
    }
  }
}

emlrtCTX emlrtGetRootTLSGlobal(void)
{
  return emlrtRootTLSGlobal;
}

void emlrtLockerFunction(EmlrtLockeeFunction aLockee, emlrtConstCTX aTLS, void
  *aData)
{
  omp_set_lock(&emlrtLockGlobal);
  emlrtCallLockeeFunction(aLockee, aTLS, aData);
  omp_unset_lock(&emlrtLockGlobal);
}

void fable_osi(const emlrtStack *sp, const real_T varargin_1[256], const real_T
               varargin_2[256], const struct1_T *varargin_4, real_T *out,
               struct1_T *state, struct2_T *info)
{
  static const real_T b_dv[512] = { 0.0, 3.7796577274096244E-5,
    0.00015118059477142731, 0.00034013491038087373, 0.00060463095679685885,
    0.00094462874583833845, 0.0013600768744944647, 0.0018509125326960918,
    0.00241706151281168, 0.0030584382208665439, 0.0037749456894833888,
    0.00456647559254264, 0.0054329082615597324, 0.0063741127037773015,
    0.0073899466219696786, 0.0084802564359560684, 0.0096448773058199766,
    0.010883633156830497, 0.012196336706062738, 0.013582789490712122,
    0.015042781898099433, 0.016576093197361252, 0.018182491572821535,
    0.019861734159038968, 0.021613567077524876, 0.023437725475126125,
    0.025333933564067435, 0.02730190466364657, 0.029341341243576458,
    0.031451934968968087, 0.033633366746946, 0.035885306774891212,
    0.038207414590302524, 0.040599339122270095, 0.043060718744552196,
    0.045591181330248531, 0.048190344308060407, 0.050857814720130512,
    0.053593189281452569, 0.056396054440842724, 0.059265986443462593,
    0.062202551394885286, 0.0652053053266945, 0.06827379426360608,
    0.071407554292103159, 0.074606111630573457, 0.077868982700938449,
    0.0811956742017641, 0.084585683182840765, 0.088038497121222858,
    0.091553593998715044, 0.095130442380794267, 0.098768501496955485,
    0.10246722132246855, 0.10622604266153479, 0.11004439723182935,
    0.11392170775041788, 0.1178573880210339, 0.12185084302270349,
    0.12590146899970439, 0.13000865355284569, 0.13417177573205397,
    0.13839020613025255, 0.14266330697851953, 0.14699043224250907,
    0.15137092772012367, 0.15580413114041997, 0.16028937226373541,
    0.16482597298301915, 0.16941324742635255, 0.17405050206064371,
    0.17873703579648026, 0.18347214009412405, 0.1882550990706332,
    0.19308518960809357, 0.19796168146294407, 0.20288383737637988,
    0.20785091318581578, 0.21286215793739288, 0.21791681399951346,
    0.22301411717738356, 0.22815329682854946, 0.23333357597940785,
    0.23855417144267393, 0.24381429393578824, 0.24911314820024566,
    0.25444993312182745, 0.25982384185171903, 0.26523406192849397,
    0.27067977540094756, 0.27616015895175938, 0.28167438402196809,
    0.28722161693623766, 0.29280101902889821, 0.29841174677074034,
    0.30405295189654535, 0.30972378153333141, 0.31542337832929634,
    0.32115088058343716, 0.32690542237582787, 0.332686133698534,
    0.33849214058714694, 0.3443225652529146, 0.35017652621545126,
    0.3560531384360055, 0.36195151345126558, 0.36787075950768328,
    0.37380998169629476, 0.37976828208801833, 0.38574475986940937,
    0.39173851147885075, 0.39774863074315892, 0.403774209014585,
    0.40981433530819011, 0.41586809643957334, 0.42193457716293326,
    0.42801286030943986, 0.43410202692589872, 0.44020115641368357,
    0.44630932666791845, 0.45242561421688732, 0.45854909436165042,
    0.46467884131584553, 0.470813928345655, 0.476953427909915,
    0.48309641180034668, 0.48924195128188885, 0.49538911723310969,
    0.5015369802866777, 0.507684610969869, 0.513831079845091,
    0.51997545765040043, 0.52611681543999511, 0.53225422472465811,
    0.53838675761213217, 0.54451348694740465, 0.55063348645288068,
    0.55674583086842311, 0.56284959609124, 0.56894385931559555,
    0.57502769917232632, 0.58110019586813921, 0.58716043132467188,
    0.59320748931729328, 0.59924045561362471, 0.60525841811175873,
    0.61126046697815717, 0.617245694785205, 0.62321319664840058,
    0.629162070363163, 0.6350914165412318, 0.64100033874664319,
    0.64688794363125812, 0.65275334106982486, 0.658595644294553,
    0.66441397002918134, 0.67020743862251719, 0.67597517418142694,
    0.68171630470325972, 0.6874299622076816, 0.69311528286790314,
    0.69877140714127783, 0.70439747989925294, 0.70999265055665339,
    0.715556073200279, 0.72108690671679387, 0.72658431491989317,
    0.73204746667672, 0.73747553603352523, 0.74286770234053645,
    0.74822315037603238, 0.7535410704695904, 0.7588206586245,
    0.76406111663931409, 0.7692616522285276, 0.77442147914235948,
    0.77953981728562316, 0.78461589283566591, 0.78964893835936056,
    0.79463819292913085, 0.79958290223799355, 0.80448231871359832,
    0.80933570163125168, 0.81414231722590369, 0.8189014388030833,
    0.82361234684876461, 0.828274329138148, 0.83288668084333783,
    0.83744870463990351, 0.84195971081230536, 0.84641901735816982,
    0.85082595009139883, 0.85517984274409842, 0.85948003706730813,
    0.86372588293051966, 0.8679167384199683, 0.87205196993568013,
    0.87613095228726556, 0.8801530687884378, 0.88411771135024808,
    0.88802428057302063, 0.8918721858369737, 0.89566084539151236,
    0.89938968644318251, 0.90305814524226791, 0.906665667168023,
    0.91021170681252261, 0.913695728063121, 0.91711720418350484,
    0.92047561789332744, 0.9237704614464155, 0.92700123670753354,
    0.93016745522769417, 0.93326863831800544, 0.9363043171220421,
    0.93927403268673038, 0.9421773360317347, 0.94501378821733839,
    0.94778296041080434, 0.95048443395120952, 0.9531178004127403,
    0.95568266166644067, 0.95817862994040448, 0.96060532787840081,
    0.962962388596925, 0.96524945574066656, 0.9674661835363858,
    0.96961223684518849, 0.9716872912131963, 0.97369103292059767,
    0.97562315902907992, 0.97748337742762759, 0.97927140687668712,
    0.98098697705068549, 0.98262982857890013, 0.984199713084672,
    0.985696393222957, 0.98711964271620922, 0.98846924638859091,
    0.98974500019850375, 0.99094671126943834, 0.992074197919133,
    0.99312728968704256, 0.99410582736010955, 0.99500966299683513,
    0.99583865994964493, 0.99659269288554975, 0.99727164780509292,
    0.997875422059586, 0.99840392436662828, 0.99885707482390618,
    0.99923480492127492, 0.999537057551115, 0.99976378701696711,
    0.99991495904043992, 0.99999055076639354, 0.99999055076639354,
    0.99991495904043992, 0.99976378701696711, 0.999537057551115,
    0.99923480492127492, 0.99885707482390618, 0.99840392436662828,
    0.997875422059586, 0.99727164780509292, 0.99659269288554975,
    0.99583865994964493, 0.995009662996835, 0.99410582736010966,
    0.99312728968704256, 0.992074197919133, 0.99094671126943834,
    0.98974500019850375, 0.98846924638859091, 0.98711964271620922,
    0.9856963932229571, 0.984199713084672, 0.98262982857890013,
    0.98098697705068549, 0.97927140687668723, 0.9774833774276277,
    0.97562315902908, 0.97369103292059789, 0.9716872912131963,
    0.9696122368451886, 0.9674661835363858, 0.96524945574066656,
    0.962962388596925, 0.96060532787840081, 0.95817862994040459,
    0.95568266166644067, 0.9531178004127403, 0.95048443395120952,
    0.94778296041080445, 0.94501378821733828, 0.9421773360317347,
    0.93927403268673038, 0.93630431712204221, 0.93326863831800533,
    0.93016745522769417, 0.92700123670753376, 0.92377046144641561,
    0.92047561789332755, 0.917117204183505, 0.91369572806312127,
    0.91021170681252261, 0.9066656671680231, 0.90305814524226791,
    0.89938968644318251, 0.89566084539151247, 0.89187218583697381,
    0.88802428057302074, 0.88411771135024808, 0.8801530687884378,
    0.87613095228726579, 0.87205196993568024, 0.86791673841996841,
    0.86372588293051988, 0.85948003706730824, 0.85517984274409853,
    0.850825950091399, 0.84641901735816971, 0.84195971081230536,
    0.83744870463990351, 0.832886680843338, 0.828274329138148, 0.823612346848765,
    0.8189014388030833, 0.81414231722590391, 0.80933570163125168,
    0.80448231871359877, 0.79958290223799366, 0.79463819292913085,
    0.78964893835936056, 0.78461589283566591, 0.77953981728562338,
    0.77442147914235959, 0.76926165222852783, 0.76406111663931431,
    0.75882065862450032, 0.75354107046959051, 0.74822315037603249,
    0.74286770234053678, 0.73747553603352511, 0.73204746667672016,
    0.72658431491989284, 0.72108690671679443, 0.715556073200279,
    0.70999265055665373, 0.70439747989925294, 0.69877140714127828,
    0.69311528286790325, 0.68742996220768182, 0.6817163047032595,
    0.675975174181427, 0.67020743862251742, 0.66441397002918134,
    0.65859564429455342, 0.652753341069825, 0.64688794363125846,
    0.64100033874664319, 0.63509141654123225, 0.62916207036316307,
    0.62321319664840036, 0.61724569478520486, 0.61126046697815728,
    0.605258418111759, 0.5992404556136246, 0.59320748931729328,
    0.58716043132467211, 0.58110019586813955, 0.57502769917232632,
    0.56894385931559566, 0.56284959609124019, 0.556745830868423,
    0.55063348645288068, 0.54451348694740442, 0.5383867576121325,
    0.53225422472465811, 0.52611681543999533, 0.51997545765040032,
    0.51383107984509147, 0.50768461096986917, 0.50153698028667792,
    0.49538911723311, 0.48924195128188891, 0.48309641180034696,
    0.47695342790991496, 0.47081392834565544, 0.46467884131584553,
    0.45854909436165053, 0.45242561421688721, 0.44630932666791889,
    0.44020115641368368, 0.43410202692589894, 0.4280128603094398,
    0.42193457716293331, 0.41586809643957356, 0.40981433530819,
    0.40377420901458505, 0.397748630743159, 0.391738511478851,
    0.38574475986940937, 0.37976828208801844, 0.373809981696295,
    0.36787075950768361, 0.36195151345126558, 0.35605313843600522,
    0.35017652621545159, 0.3443225652529146, 0.33849214058714705,
    0.33268613369853423, 0.32690542237582815, 0.32115088058343727,
    0.31542337832929657, 0.30972378153333174, 0.3040529518965453,
    0.29841174677074039, 0.292801019028898, 0.287221616936238,
    0.28167438402196809, 0.27616015895175949, 0.2706797754009474,
    0.2652340619284943, 0.25982384185171914, 0.25444993312182768,
    0.24911314820024555, 0.24381429393578824, 0.23855417144267405,
    0.23333357597940774, 0.22815329682854946, 0.22301411717738368,
    0.21791681399951368, 0.21286215793739288, 0.20785091318581583,
    0.20288383737638011, 0.19796168146294435, 0.19308518960809357,
    0.18825509907063331, 0.18347214009412421, 0.17873703579648015,
    0.17405050206064376, 0.16941324742635266, 0.16482597298301932,
    0.16028937226373541, 0.15580413114042008, 0.15137092772012384,
    0.14699043224250935, 0.14266330697851959, 0.13839020613025244,
    0.13417177573205419, 0.13000865355284569, 0.1259014689997045,
    0.12185084302270338, 0.11785738802103413, 0.11392170775041793,
    0.11004439723182946, 0.10622604266153474, 0.10246722132246883,
    0.098768501496955541, 0.095130442380794156, 0.091553593998715044,
    0.088038497121222914, 0.084585683182840876, 0.081195674201764045,
    0.077868982700938727, 0.074606111630573513, 0.07140755429210327,
    0.06827379426360608, 0.065205305326694774, 0.0622025513948854,
    0.059265986443462537, 0.056396054440842724, 0.05359318928145268,
    0.050857814720130623, 0.048190344308060407, 0.045591181330248587,
    0.043060718744552307, 0.040599339122270206, 0.038207414590302524,
    0.035885306774891268, 0.033633366746946114, 0.031451934968968032,
    0.029341341243576513, 0.027301904663646459, 0.025333933564067546,
    0.023437725475126125, 0.021613567077524931, 0.019861734159038913,
    0.018182491572821646, 0.016576093197361252, 0.015042781898099378,
    0.013582789490712233, 0.012196336706062794, 0.010883633156830552,
    0.0096448773058199211, 0.00848025643595618, 0.0073899466219696786,
    0.0063741127037773571, 0.0054329082615597324, 0.0045664755925427514,
    0.0037749456894834443, 0.0030584382208665439, 0.00241706151281168,
    0.0018509125326961473, 0.0013600768744944647, 0.00094462874583833845,
    0.00060463095679685885, 0.00034013491038087373, 0.00015118059477142731,
    3.7796577274096244E-5, 0.0 };

  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack st;
  real_T y[512];
  real_T Uf_im;
  real_T b_out;
  int32_T k;
  boolean_T t4_fast_trip;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;

  /* FABLE_OSI Online NCF-margin stability indicator (Fable redesign). */
  /*  */
  /*  Commands: */
  /*    cfg    = fable_osi('config', dt, initial_loop_tf, override) */
  /*    state  = fable_osi('state', cfg) */
  /*    result = fable_osi('run', dd, dm, dt, initial_loop_tf, override) */
  /*    [b, state, info] = fable_osi(dd_step, dm_step, cfg, state)   % step */
  /*  */
  /*  The step call consumes exactly cfg.step_n samples (cfg.step_s = 0.125 s) */
  /*  of dd (loop command) and dm (measured displacement) per call. */
  /*  */
  /*  TWO-SCALE architecture (fast detection, slow accuracy): */
  /*  */
  /*    SLOW path (level, recovery authority) - every 2nd step (0.25 s): */
  /*      1 s Hann segments in a 5 s ring (17 segments, ONE new segment FFT per */
  /*      slow hop), median-aggregated spectra, null-calibrated coherence gate, */
  /*      debiased chordal ST margin, evidence-based residual branch with */
  /*      regime-aware baseline, authority-planning prediction curve. */
  /*  */
  /*    FAST path (<= 0.5 s deficit detection) - every step (0.125 s): */
  /*      0.25 s Hann segments in a short ring (span ~0.6 s). */
  /*      * fast ST margin b_f over the slow path's excited bins: trips when */
  /*        b_f falls below BOTH the threshold and fast_st_frac x the slow */
  /*        margin for fast_st_n consecutive steps; */
  /*      * quiet-band burst detector: newest fast segment's undriven-band */
  /*        power as a calibrated log z-score, trips on fast_burst_n */
  /*        consecutive exceedances. */
  /*      Fast trips can only ever REDUCE authority (fable_auth trip path); */
  /*      authority increases always require the slow, accurate margin. */
  /*  */
  /*  Margin definition (unchanged project quantity): */
  /*    b(w) = |1 + L(w)|/sqrt(2*(1 + |L(w)|^2)) = 1/(sqrt(2)*sqrt(|S|^2+|T|^2)) */
  /*  minimum over the band, capped at the mathematical ceiling 1/sqrt(2). */
  /*  Reported margin = min(slow ST, slow residual, fast ST while tripped), */
  /*  NaN when nothing is measurable (never a fabricated "nominal"). */
  /*  */
  /*  All step-mode state is fixed-size numeric, so the step path can be moved */
  /*  to a MATLAB Function block / codegen with the usual flattening. */
  st.site = &emlrtRSI;
  *state = *varargin_4;

  /*  ------------------------------------------------------------------ step */
  /*  shift new samples into the raw ring (long enough for a slow segment) */
  for (k = 0; k < 1792; k++) {
    state->xdd[k] = state->xdd[k + 256];
  }

  memcpy(&state->xdd[1792], &varargin_1[0], 256U * sizeof(real_T));
  for (k = 0; k < 1792; k++) {
    state->xdm[k] = state->xdm[k + 256];
  }

  memcpy(&state->xdm[1792], &varargin_2[0], 256U * sizeof(real_T));
  state->samples_in += 256.0;
  state->step_count++;
  b_out = rtNaN;
  if (state->samples_in < 512.0) {
    boolean_T info_st_binding;

    /*  is the binding constraint inside the coherently observed band? (then the */
    /*  authority-planning curve covers it; otherwise the deficit is residual- */
    /*  driven and the prediction is blind to it) */
    if (state->sb_stvalid && (muDoubleScalarIsNaN(state->sb_res) ||
         (state->sb_st <= state->sb_res))) {
      info_st_binding = true;
    } else {
      info_st_binding = false;
    }

    info->margin = rtNaN;
    info->valid = false;
    info->ncf_st = state->sb_st;
    info->st_valid = state->sb_stvalid;
    info->f_st_hz = state->sb_fst;
    info->n_excited = state->sb_nexc;
    info->ncf_res = state->sb_res;
    info->f_res_hz = state->sb_fres;
    info->z_max = state->sb_zmax;
    info->res_on = state->res_on;
    info->b_fast = rtNaN;
    info->fast_trip = false;
    info->trip_reason = 0.0;
    info->baseline_ready = state->ready;
    info->pred_valid = state->sb_predvalid;
    memcpy(&info->pred_margin[0], &state->sb_pred[0], 25U * sizeof(real_T));
    memcpy(&info->alpha_grid[0], &dv[0], 25U * sizeof(real_T));
    info->nominal = 0.34468854883952776;
    info->nominal_hz = 38.0;
    info->detected = state->detected;
    info->detect_step = state->detect_step;
    info->st_binding = info_st_binding;
    info->z_fast = rtNaN;
    info->regime_recal = false;
  } else {
    __m128d r;
    __m128d r1;
    creal_T Uf[512];
    creal_T Yf[512];
    real_T b_y[25];
    real_T b[2];
    real_T b_fast;
    real_T b_r;
    int32_T i;
    boolean_T info_st_binding;
    boolean_T valid;

    /*  ---- fast segment FFT (every step) -------------------------------------- */
    b_st.site = &b_emlrtRSI;

    /*  ------------------------------------------------------------- utilities */
    c_st.site = &f_emlrtRSI;
    d_st.site = &f_emlrtRSI;
    mldivide(&d_st, &state->xdd[1536], b);
    mtimes(dv1, b, y);
    b_st.site = &b_emlrtRSI;
    for (k = 0; k <= 510; k += 2) {
      r = _mm_loadu_pd(&state->xdd[k + 1536]);
      r1 = _mm_loadu_pd(&y[k]);
      _mm_storeu_pd(&y[k], _mm_mul_pd(_mm_loadu_pd(&b_dv[k]), _mm_sub_pd(r, r1)));
    }

    c_st.site = &y_emlrtRSI;
    emlrtFFTWSetNumThreads(8);
    emlrtFFTW_1D_R2C(&y[0], (real_T *)&Uf[0], 1, 512, 512, 1, -1);
    b_st.site = &c_emlrtRSI;

    /*  ------------------------------------------------------------- utilities */
    c_st.site = &f_emlrtRSI;
    d_st.site = &f_emlrtRSI;
    mldivide(&d_st, &state->xdm[1536], b);
    mtimes(dv1, b, y);
    b_st.site = &c_emlrtRSI;
    for (k = 0; k <= 510; k += 2) {
      r = _mm_loadu_pd(&state->xdm[k + 1536]);
      r1 = _mm_loadu_pd(&y[k]);
      _mm_storeu_pd(&y[k], _mm_mul_pd(_mm_loadu_pd(&b_dv[k]), _mm_sub_pd(r, r1)));
    }

    c_st.site = &y_emlrtRSI;
    emlrtFFTWSetNumThreads(8);
    emlrtFFTW_1D_R2C(&y[0], (real_T *)&Yf[0], 1, 512, 512, 1, -1);
    if (muDoubleScalarIsNaN(state->fring_pos) || muDoubleScalarIsInf
        (state->fring_pos)) {
      b_r = rtNaN;
    } else {
      b_r = muDoubleScalarRem(state->fring_pos, 3.0);
      if (b_r == 0.0) {
        b_r = 0.0;
      } else if (b_r < 0.0) {
        b_r += 3.0;
      }
    }

    state->fring_pos = b_r + 1.0;
    for (k = 0; k < 25; k++) {
      b_out = muDoubleScalarHypot(Uf[k + 1].re, Uf[k + 1].im);
      b_y[k] = b_out * b_out;
    }

    i = (int32_T)muDoubleScalarFloor(b_r + 1.0);
    if (b_r + 1.0 != i) {
      emlrtIntegerCheckR2012b(b_r + 1.0, &emlrtDCI, &st);
    }

    if ((int32_T)(b_r + 1.0) > 3) {
      emlrtDynamicBoundsCheckR2012b((int32_T)(b_r + 1.0), 1, 3, &emlrtBCI, &st);
    }

    for (k = 0; k < 25; k++) {
      state->fSuu[k + 25 * ((int32_T)(b_r + 1.0) - 1)] = b_y[k];
      b_out = muDoubleScalarHypot(Yf[k + 1].re, Yf[k + 1].im);
      b_y[k] = b_out * b_out;
    }

    if (b_r + 1.0 != i) {
      emlrtIntegerCheckR2012b(b_r + 1.0, &b_emlrtDCI, &st);
    }

    if ((int32_T)(b_r + 1.0) > 3) {
      emlrtDynamicBoundsCheckR2012b((int32_T)(b_r + 1.0), 1, 3, &b_emlrtBCI, &st);
    }

    for (k = 0; k < 25; k++) {
      state->fSyy[k + 25 * ((int32_T)(b_r + 1.0) - 1)] = b_y[k];
    }

    if (b_r + 1.0 != i) {
      emlrtIntegerCheckR2012b(b_r + 1.0, &c_emlrtDCI, &st);
    }

    if ((int32_T)(b_r + 1.0) > 3) {
      emlrtDynamicBoundsCheckR2012b((int32_T)(b_r + 1.0), 1, 3, &c_emlrtBCI, &st);
    }

    for (k = 0; k < 25; k++) {
      real_T d;
      b_out = Uf[k + 1].re;
      Uf_im = -Uf[k + 1].im;
      b_fast = Yf[k + 1].re;
      d = Yf[k + 1].im;
      i = k + 25 * ((int32_T)(b_r + 1.0) - 1);
      state->fSuy[i].re = b_fast * b_out - d * Uf_im;
      state->fSuy[i].im = b_fast * Uf_im + d * b_out;
    }

    state->fseg_count = muDoubleScalarMin(state->fseg_count + 1.0, 3.0);

    /*  ---- slow spectral hop (every steps_per_hop-th step) --------------------- */
    if (muDoubleScalarIsNaN(state->step_count) || muDoubleScalarIsInf
        (state->step_count)) {
      b_out = rtNaN;
    } else {
      b_out = muDoubleScalarRem(state->step_count, 2.0);
      if (b_out == 0.0) {
        b_out = 0.0;
      } else if (b_out < 0.0) {
        b_out += 2.0;
      }
    }

    if ((b_out == 0.0) && (state->samples_in >= 2048.0)) {
      b_st.site = &d_emlrtRSI;
      slowHop(&b_st, state);
    }

    /*  ---- fast statistics (every step, once the slow path is running) -------- */
    b_st.site = &e_emlrtRSI;
    b_fast = fastPath(&b_st, state, &t4_fast_trip, &Uf_im, &info->z_fast);

    /*  ---- combine ------------------------------------------------------------- */
    /*  slow component: median over the last margin_filter_n DISTINCT slow */
    /*  updates (computed in slowHop); fast dips bypass that median only when a */
    /*  persistence-gated trip is active */
    b_out = state->sb_b;
    if (state->update_count <= 4.0) {
      b_out = rtNaN;
    }

    if ((Uf_im == 2.0) && (!muDoubleScalarIsNaN(b_out))) {
      /*  fast ST trip: show the dive */
      b_out = muDoubleScalarMin(b_out, b_fast);
    }

    valid = !muDoubleScalarIsNaN(b_out);
    if (valid && (!state->detected) && (b_out < 0.3)) {
      state->detected = true;
      state->detect_step = state->step_count;
    }

    /*  is the binding constraint inside the coherently observed band? (then the */
    /*  authority-planning curve covers it; otherwise the deficit is residual- */
    /*  driven and the prediction is blind to it) */
    if (state->sb_stvalid && (muDoubleScalarIsNaN(state->sb_res) ||
         (state->sb_st <= state->sb_res))) {
      info_st_binding = true;
    } else {
      info_st_binding = false;
    }

    info->margin = b_out;
    info->valid = valid;
    info->ncf_st = state->sb_st;
    info->st_valid = state->sb_stvalid;
    info->f_st_hz = state->sb_fst;
    info->n_excited = state->sb_nexc;
    info->ncf_res = state->sb_res;
    info->f_res_hz = state->sb_fres;
    info->z_max = state->sb_zmax;
    info->res_on = state->res_on;
    info->b_fast = b_fast;
    info->fast_trip = t4_fast_trip;
    info->trip_reason = Uf_im;
    info->baseline_ready = state->ready;
    info->pred_valid = state->sb_predvalid;
    memcpy(&info->pred_margin[0], &state->sb_pred[0], 25U * sizeof(real_T));
    memcpy(&info->alpha_grid[0], &dv[0], 25U * sizeof(real_T));
    info->nominal = 0.34468854883952776;
    info->nominal_hz = 38.0;
    info->detected = state->detected;
    info->detect_step = state->detect_step;
    info->st_binding = info_st_binding;

    /*  one-shot flag: a regime recalibration was just confirmed. The authority */
    /*  law uses it to UNDO a fast trip that fired during the transition onset */
    /*  (the trip was the regime change, not the plant). */
    info->regime_recal = state->recal_pending;
    state->recal_pending = false;
  }

  *out = b_out;
}

/* End of code generation (fable_osi.c) */
