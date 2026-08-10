"""Gradient-tune one continuous-time LQI for the 7k and 5k plants."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from scipy.io import loadmat
from scipy.linalg import solve_continuous_are, solve_continuous_lyapunov


torch.set_default_dtype(torch.float64)


class ContinuousCARE(torch.autograd.Function):
    """SciPy CARE forward solve with an implicit Lyapunov backward pass."""

    @staticmethod
    def forward(ctx, A, B, Q, R):
        P_np = solve_continuous_are(
            A.detach().cpu().numpy(),
            B.detach().cpu().numpy(),
            Q.detach().cpu().numpy(),
            R.detach().cpu().numpy(),
        )
        P = torch.as_tensor(P_np, dtype=Q.dtype, device=Q.device)
        ctx.save_for_backward(A, B, P, R)
        return P

    @staticmethod
    def backward(ctx, grad_P):
        A, B, P, R = ctx.saved_tensors
        K = torch.linalg.solve(R, B.T @ P)
        A_closed = A - B @ K
        forcing = 0.5 * (grad_P + grad_P.T)
        adjoint_np = solve_continuous_lyapunov(
            A_closed.detach().cpu().numpy(),
            -forcing.detach().cpu().numpy(),
        )
        adjoint = torch.as_tensor(adjoint_np, dtype=P.dtype, device=P.device)
        grad_Q = 0.5 * (adjoint + adjoint.T)
        grad_R = K @ grad_Q @ K.T
        return None, None, grad_Q, 0.5 * (grad_R + grad_R.T)


def lower_cholesky(raw):
    lower = torch.tril(raw, diagonal=-1)
    diagonal = torch.exp(torch.diagonal(raw))
    return lower + torch.diag(diagonal)


def raw_from_positive_matrix(matrix):
    factor = np.linalg.cholesky(matrix)
    raw = np.tril(factor, k=-1)
    raw += np.diag(np.log(np.diag(factor)))
    return torch.tensor(raw, requires_grad=True)


def raw_from_positive_scalar(value):
    return torch.tensor(np.log(np.sqrt(value)), requires_grad=True)


def load_models(study_folder):
    model_data = loadmat(
        study_folder.parent / "results" / "lqr_state_space_models.mat",
        simplify_cells=True,
    )["result"]
    baseline = loadmat(study_folder / "ncf_matched_lqri.mat", simplify_cells=True)["result"]
    scale = float(model_data["frequency_scale_rad_per_second"])
    models = {}
    for label, key in (("7k", "system_7k"), ("5k", "system_5k")):
        model = model_data[key]
        models[label] = (
            torch.tensor(scale * np.asarray(model["A"], dtype=float)),
            torch.tensor((scale * np.asarray(model["B"], dtype=float)).reshape(-1, 1)),
            torch.tensor(np.asarray(model["C"], dtype=float).reshape(1, -1)),
        )
    return models, baseline


def augmented_plant(A, B, C):
    state_count = A.shape[0]
    zeros_column = torch.zeros((state_count, 1), dtype=A.dtype)
    A_augmented = torch.cat(
        [
            torch.cat([A, zeros_column], dim=1),
            torch.cat([-C, torch.zeros((1, 1), dtype=A.dtype)], dim=1),
        ],
        dim=0,
    )
    B_augmented = torch.cat([B, torch.zeros((1, B.shape[1]), dtype=A.dtype)], dim=0)
    reference_input = torch.cat(
        [torch.zeros((state_count, 1), dtype=A.dtype), torch.ones((1, 1), dtype=A.dtype)],
        dim=0,
    )
    C_augmented = torch.cat([C, torch.zeros((C.shape[0], 1), dtype=A.dtype)], dim=1)
    return A_augmented, B_augmented, C_augmented, reference_input


def modal_step_response(A_closed, reference_input, time):
    steady_state = -torch.linalg.solve(A_closed, reference_input)
    eigenvalues, eigenvectors = torch.linalg.eig(A_closed)
    coefficients = torch.linalg.solve(eigenvectors, steady_state.to(torch.complex128))
    exponents = time[:, None] * eigenvalues[None, :]
    bounded_exponents = torch.complex(
        torch.clamp(exponents.real, max=80.0), exponents.imag
    )
    exponentials = torch.exp(bounded_exponents)
    transient = (exponentials * coefficients.T) @ eigenvectors.T
    return steady_state.T - transient.real


def simulate_lqi_gain(A, B, C, K, time):
    A_augmented, B_augmented, C_augmented, reference_input = augmented_plant(A, B, C)
    A_closed = A_augmented - B_augmented @ K
    state = modal_step_response(A_closed, reference_input, time)
    output = (state @ C_augmented.T)[:, 0]
    command = -(state @ K.T)[:, 0]
    return {
        "state": state,
        "output": output,
        "command": command,
        "tracking": torch.trapezoid((1.0 - output).square(), time) / time[-1],
        "command_peak": command.abs().max(),
        "closed_loop_eigenvalues": torch.linalg.eigvals(A_closed),
    }


def nominal_lqi_gain(A, B, C, Q, QI):
    A_augmented, B_augmented, _, _ = augmented_plant(A, B, C)
    state_count = A.shape[0]
    Q_augmented = torch.zeros_like(A_augmented)
    Q_augmented[:state_count, :state_count] = Q
    Q_augmented[state_count, state_count] = QI
    R = torch.ones((B.shape[1], B.shape[1]), dtype=A.dtype)
    P = ContinuousCARE.apply(A_augmented, B_augmented, Q_augmented, R)
    K = torch.linalg.solve(R, B_augmented.T @ P)
    return P, K


def losses(responses, args):
    tracking = torch.stack([response["tracking"] for response in responses.values()])
    command_peaks = torch.stack(
        [response["command_peak"] for response in responses.values()]
    )
    spectral_abscissae = torch.stack(
        [response["closed_loop_eigenvalues"].real.max() for response in responses.values()]
    )
    command_peak = command_peaks.max()
    normalized_violation = torch.relu(
        (command_peak - args.target_peak) / args.command_tolerance
    )
    command_penalty = normalized_violation.square()
    stability_violation = torch.relu(
        (spectral_abscissae + args.stability_margin) / args.stability_tolerance
    )
    stability_penalty = stability_violation.square().mean()
    return {
        "tracking": tracking.mean(),
        "tracking_by_plant": dict(zip(responses, tracking)),
        "command_peak": command_peak,
        "command_peak_by_plant": dict(zip(responses, command_peaks)),
        "spectral_abscissa_by_plant": dict(zip(responses, spectral_abscissae)),
        "command_penalty": command_penalty,
        "stability_penalty": stability_penalty,
        "total": tracking.mean()
        + args.command_weight * command_penalty
        + args.stability_weight * stability_penalty,
    }


def evaluate(models, Q, QI, time, args):
    A, B, C = models["7k"]
    P, K = nominal_lqi_gain(A, B, C, Q, QI)
    responses = {
        label: simulate_lqi_gain(*model, K, time)
        for label, model in models.items()
    }
    return {"P": P, "K": K, "responses": responses}, losses(responses, args)


def tensor_list(value):
    return value.detach().cpu().numpy().tolist()


def direct_gradient_check(models, Q, QI, time, args):
    Q_check = Q.detach().clone().requires_grad_(True)
    QI_check = QI.detach().clone().requires_grad_(True)
    _, loss = evaluate(models, Q_check, QI_check, time, args)
    grad_Q, grad_QI = torch.autograd.grad(loss["total"], (Q_check, QI_check))

    q_index = int(torch.argmax(torch.diagonal(Q_check)).item())
    q_step = args.gradient_check_step * max(1.0, abs(Q_check[q_index, q_index].item()))
    direction = torch.zeros_like(Q_check)
    direction[q_index, q_index] = q_step
    plus = evaluate(models, Q_check.detach() + direction, QI_check.detach(), time, args)[1]["total"]
    minus = evaluate(models, Q_check.detach() - direction, QI_check.detach(), time, args)[1]["total"]
    fd_q = ((plus - minus) / (2.0 * q_step)).item()
    analytic_q = grad_Q[q_index, q_index].item()

    qi_step = args.gradient_check_step * max(1.0, abs(QI_check.item()))
    plus = evaluate(models, Q_check.detach(), QI_check.detach() + qi_step, time, args)[1]["total"]
    minus = evaluate(models, Q_check.detach(), QI_check.detach() - qi_step, time, args)[1]["total"]
    fd_qi = ((plus - minus) / (2.0 * qi_step)).item()
    analytic_qi = grad_QI.item()

    relative = lambda a, b: abs(a - b) / max(1e-12, abs(a), abs(b))
    return {
        "Q_diagonal_index": q_index,
        "Q_analytical": analytic_q,
        "Q_finite_difference": fd_q,
        "Q_relative_error": relative(analytic_q, fd_q),
        "QI_analytical": analytic_qi,
        "QI_finite_difference": fd_qi,
        "QI_relative_error": relative(analytic_qi, fd_qi),
    }


def optimize(args):
    study_folder = Path(__file__).resolve().parent
    models, baseline = load_models(study_folder)
    A, _, C = models["7k"]
    time = torch.linspace(0.0, args.horizon, round(args.horizon * args.sample_rate) + 1)
    Q_initial = float(baseline["qy"]) * C.T.numpy() @ C.numpy()
    Q_initial += args.q_floor * np.eye(A.shape[0])
    raw_Q = raw_from_positive_matrix(Q_initial)
    raw_QI = raw_from_positive_scalar(float(baseline["qi"]))
    optimizer = torch.optim.Adam([raw_Q, raw_QI], lr=args.learning_rate)
    history = []
    best_feasible = None
    best_infeasible = None
    for iteration in range(args.iterations + 1):
        LQ = lower_cholesky(raw_Q)
        LI = torch.exp(raw_QI)
        Q = LQ @ LQ.T
        QI = LI.square()
        result, loss = evaluate(models, Q, QI, time, args)
        peak = loss["command_peak"].item()
        spectral_abscissae = {
            label: value.item()
            for label, value in loss["spectral_abscissa_by_plant"].items()
        }
        stability_violation = max(
            0.0,
            max(spectral_abscissae.values()) + args.stability_margin,
        )
        candidate = {
            "tracking": loss["tracking"].item(),
            "violation": max(0.0, peak - args.target_peak - args.command_tolerance)
            + stability_violation,
            "raw_Q": raw_Q.detach().clone(),
            "raw_QI": raw_QI.detach().clone(),
        }
        constraints_satisfied = (
            peak <= args.target_peak + args.command_tolerance
            and stability_violation == 0.0
        )
        if constraints_satisfied and (
            best_feasible is None or candidate["tracking"] < best_feasible["tracking"]
        ):
            best_feasible = candidate
        if best_infeasible is None or (
            candidate["violation"], candidate["tracking"]
        ) < (best_infeasible["violation"], best_infeasible["tracking"]):
            best_infeasible = candidate

        if iteration % args.report_every == 0 or iteration == args.iterations:
            history.append(
                {
                    "iteration": iteration,
                    "total": loss["total"].item(),
                    "tracking": loss["tracking"].item(),
                    "command_penalty": loss["command_penalty"].item(),
                    "stability_penalty": loss["stability_penalty"].item(),
                    "command_peak": peak,
                    "tracking_7k": loss["tracking_by_plant"]["7k"].item(),
                    "tracking_5k": loss["tracking_by_plant"]["5k"].item(),
                    "spectral_abscissa_7k": spectral_abscissae["7k"],
                    "spectral_abscissa_5k": spectral_abscissae["5k"],
                }
            )
            print(
                f"iter={iteration:4d} total={loss['total'].item():.9g} "
                f"track={loss['tracking'].item():.9g} peak={peak:.9g} "
                f"alpha7={spectral_abscissae['7k']:.5g} "
                f"alpha5={spectral_abscissae['5k']:.5g}"
            )

        if iteration == args.iterations:
            break
        optimizer.zero_grad()
        loss["total"].backward()
        torch.nn.utils.clip_grad_norm_([raw_Q, raw_QI], args.gradient_clip)
        optimizer.step()

    best = best_feasible if best_feasible is not None else best_infeasible
    raw_Q.data.copy_(best["raw_Q"])
    raw_QI.data.copy_(best["raw_QI"])
    LQ = lower_cholesky(raw_Q)
    LI = torch.exp(raw_QI)
    Q = LQ @ LQ.T
    QI = LI.square()
    verification_time = torch.linspace(
        0.0,
        args.horizon,
        round(args.horizon * args.verification_sample_rate) + 1,
    )
    result, loss = evaluate(models, Q, QI, verification_time, args)
    grad_tracking = torch.autograd.grad(loss["tracking"], (Q, QI), retain_graph=True)
    grad_command = torch.autograd.grad(
        loss["command_penalty"], (Q, QI), retain_graph=True, allow_unused=True
    )
    grad_stability = torch.autograd.grad(
        loss["stability_penalty"], (Q, QI), retain_graph=True, allow_unused=True
    )
    grad_total = torch.autograd.grad(loss["total"], (Q, QI))
    gradient_check = direct_gradient_check(models, Q, QI, time, args)

    baseline_Q = float(baseline["qy"]) * C.T @ C
    baseline_result, baseline_loss = evaluate(
        models, baseline_Q, torch.tensor(float(baseline["qi"])),
        verification_time, args
    )
    gain = result["K"]
    responses = result["responses"]
    spectral_abscissae = {
        label: loss["spectral_abscissa_by_plant"][label].item()
        for label in models
    }
    command_peaks = {
        label: loss["command_peak_by_plant"][label].item()
        for label in models
    }
    tracking_losses = {
        label: loss["tracking_by_plant"][label].item()
        for label in models
    }
    constraints_satisfied = (
        loss["command_peak"].item() <= args.target_peak + args.command_tolerance
        and max(spectral_abscissae.values()) <= -args.stability_margin
    )
    result = {
        "configuration": vars(args),
        "loss_definition": (
            "J = mean_{p in {7k,5k}} [(1/T) integral_0^T (1-y_p(t))^2 dt] "
            "+ command_weight * max(0, (max_{p,t}|u_p(t)|-target_peak) / "
            "command_tolerance)^2 + stability_weight * mean_p max(0, "
            "(max Re eig(Aa_p-Ba_p*K)+stability_margin) / "
            "stability_tolerance)^2. K is generated once by the nominal-7k CARE; "
            "the same K is simulated and differentiated on both endpoint plants."
        ),
        "constraint_definition": (
            "The reported fixed gain is accepted only when max_{p,t}|u_p(t)| <= "
            "target_peak + command_tolerance and max Re eig(Aa_p-Ba_p*K) <= "
            "-stability_margin for both p in {7k,5k}."
        ),
        "optimization_scope": "shared fixed gain evaluated at both 7k and 5k",
        "Q": tensor_list(Q),
        "QI": [[QI.item()]],
        "R": [[1.0]],
        "K": tensor_list(gain),
        "state_gain": tensor_list(gain[:, :-1]),
        "integral_gain": gain[0, -1].item(),
        "command_peak": loss["command_peak"].item(),
        "command_peak_by_plant": command_peaks,
        "constraint_satisfied": constraints_satisfied,
        "tracking_loss": loss["tracking"].item(),
        "tracking_loss_by_plant": tracking_losses,
        "command_penalty": loss["command_penalty"].item(),
        "stability_penalty": loss["stability_penalty"].item(),
        "total_loss": loss["total"].item(),
        "spectral_abscissa_by_plant": spectral_abscissae,
        "closed_loop_eigenvalues_by_plant": {
            label: [
                {"real": value.real.item(), "imag": value.imag.item()}
                for value in response["closed_loop_eigenvalues"]
            ]
            for label, response in responses.items()
        },
        "gradient_norms": {
            "tracking_Q_fro": torch.linalg.norm(grad_tracking[0]).item(),
            "tracking_QI_fro": abs(grad_tracking[1].item()),
            "command_Q_fro": 0.0 if grad_command[0] is None else torch.linalg.norm(grad_command[0]).item(),
            "command_QI_fro": 0.0 if grad_command[1] is None else abs(grad_command[1].item()),
            "stability_Q_fro": 0.0 if grad_stability[0] is None else torch.linalg.norm(grad_stability[0]).item(),
            "stability_QI_fro": 0.0 if grad_stability[1] is None else abs(grad_stability[1].item()),
            "total_Q_fro": torch.linalg.norm(grad_total[0]).item(),
            "total_QI_fro": abs(grad_total[1].item()),
        },
        "gradient_check": gradient_check,
        "baseline": {
            "qy": float(baseline["qy"]),
            "QI": [[float(baseline["qi"])]],
            "K": np.asarray(baseline["augmented_gain"], dtype=float).reshape(1, -1).tolist(),
            "command_peak": baseline_loss["command_peak"].item(),
            "tracking_loss": baseline_loss["tracking"].item(),
            "spectral_abscissa_by_plant": {
                label: baseline_loss["spectral_abscissa_by_plant"][label].item()
                for label in models
            },
        },
        "history": history,
    }
    output_path = study_folder / args.output
    output_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"Saved {output_path}")
    return result


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-peak", type=float, default=2.5)
    parser.add_argument("--command-tolerance", type=float, default=1e-2)
    parser.add_argument("--command-weight", type=float, default=1.0)
    parser.add_argument("--stability-margin", type=float, default=1.0)
    parser.add_argument("--stability-tolerance", type=float, default=1.0)
    parser.add_argument("--stability-weight", type=float, default=1.0)
    parser.add_argument("--q-floor", type=float, default=1e-6)
    parser.add_argument("--horizon", type=float, default=8.0)
    parser.add_argument("--sample-rate", type=float, default=2048.0)
    parser.add_argument("--verification-sample-rate", type=float, default=2048.0)
    parser.add_argument("--iterations", type=int, default=1600)
    parser.add_argument("--learning-rate", type=float, default=2e-2)
    parser.add_argument("--gradient-clip", type=float, default=10.0)
    parser.add_argument("--gradient-check-step", type=float, default=1e-5)
    parser.add_argument("--report-every", type=int, default=50)
    parser.add_argument("--output", default="lqi_peak_command_optimization.json")
    return parser.parse_args()


if __name__ == "__main__":
    optimize(parse_args())
