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
#include "adaptive_pid_authority_step.h"
#include "adaptive_pid_authority_step_initialize.h"
#include "adaptive_pid_authority_step_terminate.h"
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
  adaptive_pid_authority_step_initialize();
  /* Invoke the entry-point functions.
You can call entry-point functions multiple times. */
  main_adaptive_pid_authority_step();
  /* Terminate the application.
You do not need to do this more than one time. */
  adaptive_pid_authority_step_terminate();
  return 0;
}

void main_adaptive_pid_authority_step(void)
{
  double above_count_next;
  double authority_next;
  double below_count_next;
  double down_confirmed;
  double m91_margin_tmp;
  double margin_filtered_next;
  double margin_guarded_next;
  /* Initialize function 'adaptive_pid_authority_step' input arguments. */
  m91_margin_tmp = argInit_real_T();
  /* Call the entry-point 'adaptive_pid_authority_step'. */
  adaptive_pid_authority_step(
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
