function margin = sim_helper(current_factor, beta)
    m_e = evalin('base','m_e');
    k_e = evalin('base','k_e');
    zeta = evalin('base','z_e');
    analog_cntrlr = evalin('base','analog_cntrlr');
    digital_cntrlr = evalin('base','digital_cntrlr');
    digital_cntrlr2 = evalin('base','digital_cntrlr2');

    ci = 2*zeta*sqrt(current_factor*k_e*m_e);
    analog_cl_r = feedback(analog_cntrlr * inner_open_loop2_with_params(m_e, ci, current_factor * k_e), 1);
    dg_cntrlr = digital_cntrlr*beta + digital_cntrlr2*(1-beta);
    sys = dg_cntrlr*analog_cl_r;

    ncfmargin_value = compute_ncfmargin(analog_cl_r, dg_cntrlr);


    margin = ncfmargin_value;
end