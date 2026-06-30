/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * main.c
 *
 * Code generation for function 'main'
 *
 */

/*************************************************************************/
/* This automatically generated example C main file shows how to call    */
/* entry-point functions that MATLAB Coder generated. You must customize */
/* this file for your application. Do not modify this file directly.     */
/* Instead, make a copy of this file, modify it, and integrate it into   */
/* your development environment.                                         */
/*                                                                       */
/* This file initializes entry-point function arguments to a default     */
/* size and value before calling the entry-point functions. It does      */
/* not store or use any values returned from the entry-point functions.  */
/* If necessary, it does pre-allocate memory for returned values.        */
/* You can use this file as a starting point for a main function that    */
/* you can deploy in your application.                                   */
/*                                                                       */
/* After you copy the file, and before you deploy it, you must make the  */
/* following changes:                                                    */
/* * For variable-size function arguments, change the example sizes to   */
/* the sizes that your application requires.                             */
/* * Change the example values of function arguments to the values that  */
/* your application requires.                                            */
/* * If the entry-point functions return values, store these values or   */
/* otherwise use them as required by your application.                   */
/*                                                                       */
/*************************************************************************/

/* Include files */
#include "main.h"
#include "auth_stability_gain.h"
#include "auth_stability_gain_initialize.h"
#include "auth_stability_gain_terminate.h"
#include "rt_nonfinite.h"

/* Function Declarations */
static double argInit_real_T(void);

/* Function Definitions */
static double argInit_real_T(void)
{
  return 0.0;
}

int main(int argc, char **argv)
{
  (void)argc;
  (void)argv;
  /* Initialize the application.
You do not need to do this more than one time. */
  auth_stability_gain_initialize();
  /* Invoke the entry-point functions.
You can call entry-point functions multiple times. */
  main_auth_stability_gain();
  /* Terminate the application.
You do not need to do this more than one time. */
  auth_stability_gain_terminate();
  return 0;
}

void main_auth_stability_gain(void)
{
  double above_count_next;
  double authority_next;
  double below_count_next;
  double down_confirmed;
  double m91_margin_tmp;
  double margin_filtered_next;
  double margin_guarded_next;
  /* Initialize function 'auth_stability_gain' input arguments. */
  m91_margin_tmp = argInit_real_T();
  /* Call the entry-point 'auth_stability_gain'. */
  auth_stability_gain(
      m91_margin_tmp, m91_margin_tmp, m91_margin_tmp, m91_margin_tmp,
      m91_margin_tmp, m91_margin_tmp, m91_margin_tmp, m91_margin_tmp,
      m91_margin_tmp, m91_margin_tmp, m91_margin_tmp, m91_margin_tmp,
      m91_margin_tmp, m91_margin_tmp, m91_margin_tmp, m91_margin_tmp,
      m91_margin_tmp, m91_margin_tmp, m91_margin_tmp, m91_margin_tmp,
      m91_margin_tmp, m91_margin_tmp, &authority_next, &margin_filtered_next,
      &margin_guarded_next, &above_count_next, &below_count_next,
      &down_confirmed);
}

/* End of code generation (main.c) */
