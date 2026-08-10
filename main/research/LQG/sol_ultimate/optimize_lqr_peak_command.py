"""Optimize the nominal 7k continuous-time LQR for a unit-step command peak."""

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
    def forward(ctx, A: torch.Tensor, B: torch.Tensor, Q: torch.Tensor, R: torch.Tensor) -> torch.Tensor:
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
    def backward(ctx, grad_P: torch.Tensor):
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


def lower_cholesky(raw: torch.Tensor) -> torch.Tensor:
    lower = torch.tril(raw, diagonal=-1)
    diagonal = torch.nn.functional.softplus(torch.diagonal(raw)) + 1e-8
    return lower + torch.diag(diagonal)


def inverse_softplus(value: np.ndarray) -> np.ndarray:
    return np.log(np.expm1(value))


def raw_from_q(Q: np.ndarray) -> torch.Tensor:
    L = np.linalg.cholesky(Q)
    raw = np.tril(L, k=-1)
    raw += np.diag(inverse_softplus(np.diag(L) - 1e-8))
    return torch.tensor(raw, requires_grad=True)


def load_7k_model(study_folder: Path) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, dict]:
    lqg_folder = study_folder.parent
    model_data = loadmat(lqg_folder / "results" / "lqr_state_space_models.mat", simplify_cells=True)["result"]
    baseline = loadmat(study_folder / "ncf_matched_lqr.mat", simplify_cells=True)["result"]
    model = model_data["system_7k"]
    scale = float(model_data["frequency_scale_rad_per_second"])
    A = scale * np.asarray(model["A"], dtype=float)
    B = (scale * np.asarray(model["B"], dtype=float)).reshape(-1, 1)
    C = np.asarray(model["C"], dtype=float).reshape(1, -1)
    return torch.tensor(A), torch.tensor(B), torch.tensor(C), baseline


def lqr_step(
    A: torch.Tensor,
    B: torch.Tensor,
    C: torch.Tensor,
    Q: torch.Tensor,
    time: torch.Tensor,
) -> dict[str, torch.Tensor]:
    R = torch.ones((B.shape[1], B.shape[1]), dtype=A.dtype)
    P = ContinuousCARE.apply(A, B, Q, R)
    K = torch.linalg.solve(R, B.T @ P)
    A_closed = A - B @ K
    nbar = -torch.linalg.inv(C @ torch.linalg.solve(A_closed, B))
    x_steady = -torch.linalg.solve(A_closed, B @ nbar)
    transition = torch.matrix_exp(time[:, None, None] * A_closed[None, :, :])
    state = x_steady.T - torch.matmul(transition, x_steady).squeeze(-1)
    output = state @ C.T
    command = nbar - state @ K.T
    error = 1.0 - output
    tracking = torch.trapezoid(error[:, 0].square(), time) / time[-1]
    command_peak = command[:, 0].abs().max()
    return {
        "P": P,
        "K": K,
        "nbar": nbar.squeeze(),
        "state": state,
        "output": output[:, 0],
        "command": command[:, 0],
        "tracking": tracking,
        "command_peak": command_peak,
        "closed_loop_eigenvalues": torch.linalg.eigvals(A_closed),
    }


def losses(response: dict[str, torch.Tensor], target_peak: float, peak_weight: float) -> dict[str, torch.Tensor]:
    peak_error = response["command_peak"] / target_peak - 1.0
    peak_penalty = peak_error.square()
    return {
        "tracking": response["tracking"],
        "peak_penalty": peak_penalty,
        "total": response["tracking"] + peak_weight * peak_penalty,
    }


def evaluate(A, B, C, Q, time, target_peak, peak_weight):
    response = lqr_step(A, B, C, Q, time)
    return response, losses(response, target_peak, peak_weight)


def gradient_check(A, B, C, Q, time, target_peak, peak_weight) -> float:
    Q_check = Q.detach().clone().requires_grad_(True)
    _, loss = evaluate(A, B, C, Q_check, time, target_peak, peak_weight)
    analytical = torch.autograd.grad(loss["total"], Q_check)[0][0, 0].item()
    step = 1e-5 * max(1.0, abs(Q_check[0, 0].item()))
    direction = torch.zeros_like(Q_check)
    direction[0, 0] = step
    plus = evaluate(A, B, C, Q_check.detach() + direction, time, target_peak, peak_weight)[1]["total"]
    minus = evaluate(A, B, C, Q_check.detach() - direction, time, target_peak, peak_weight)[1]["total"]
    finite_difference = ((plus - minus) / (2 * step)).item()
    return abs(analytical - finite_difference) / max(1e-12, abs(analytical), abs(finite_difference))


def tensor_list(value: torch.Tensor):
    return value.detach().cpu().numpy().tolist()


def optimize(args) -> dict:
    study_folder = Path(__file__).resolve().parent
    A, B, C, baseline = load_7k_model(study_folder)
    time = torch.linspace(0.0, args.horizon, round(args.horizon * args.sample_rate) + 1)
    Q_baseline = float(baseline["qy"]) * C.T.numpy() @ C.numpy()
    Q_initial = args.initial_qy * C.T.numpy() @ C.numpy() + args.q_floor * np.eye(A.shape[0])
    raw = raw_from_q(Q_initial)
    optimizer = torch.optim.Adam([raw], lr=args.learning_rate)
    history = []
    best = None

    for iteration in range(args.iterations + 1):
        L = lower_cholesky(raw)
        Q = L @ L.T
        response, loss = evaluate(A, B, C, Q, time, args.target_peak, args.peak_weight)

        if best is None or loss["total"].item() < best["loss"]:
            best = {"loss": loss["total"].item(), "raw": raw.detach().clone()}

        if iteration % args.report_every == 0 or iteration == args.iterations:
            history.append({
                "iteration": iteration,
                "total": loss["total"].item(),
                "tracking": loss["tracking"].item(),
                "peak_penalty": loss["peak_penalty"].item(),
                "command_peak": response["command_peak"].item(),
                "nbar": response["nbar"].item(),
            })
            print(
                f"iter={iteration:4d} total={loss['total'].item():.9g} "
                f"track={loss['tracking'].item():.9g} peak={response['command_peak'].item():.9g}"
            )

        if iteration == args.iterations:
            break
        optimizer.zero_grad()
        loss["total"].backward()
        torch.nn.utils.clip_grad_norm_([raw], args.gradient_clip)
        optimizer.step()

    raw.data.copy_(best["raw"])
    L = lower_cholesky(raw)
    Q = L @ L.T
    verification_time = torch.linspace(
        0.0, args.horizon, round(args.horizon * args.verification_sample_rate) + 1
    )
    response, loss = evaluate(A, B, C, Q, verification_time, args.target_peak, args.peak_weight)
    grad_tracking = torch.autograd.grad(loss["tracking"], Q, retain_graph=True)[0]
    grad_peak = torch.autograd.grad(loss["peak_penalty"], Q, retain_graph=True)[0]
    grad_total = torch.autograd.grad(loss["total"], Q)[0]
    relative_gradient_error = gradient_check(A, B, C, Q, time, args.target_peak, args.peak_weight)

    baseline_response, baseline_loss = evaluate(
        A, B, C, torch.tensor(Q_baseline), verification_time, args.target_peak, args.peak_weight
    )
    result = {
        "configuration": vars(args),
        "loss_definition": (
            "L = (1/T) integral_0^T (1-y(t))^2 dt "
            "+ peak_weight * (max_t|u_raw(t)|/target_peak - 1)^2"
        ),
        "Q": tensor_list(Q),
        "R": [[1.0]],
        "K": tensor_list(response["K"]),
        "nbar_7k": response["nbar"].item(),
        "command_peak": response["command_peak"].item(),
        "tracking_loss": loss["tracking"].item(),
        "peak_penalty": loss["peak_penalty"].item(),
        "total_loss": loss["total"].item(),
        "closed_loop_eigenvalues": [
            {"real": value.real.item(), "imag": value.imag.item()}
            for value in response["closed_loop_eigenvalues"]
        ],
        "gradient_norms": {
            "tracking_Q_fro": torch.linalg.norm(grad_tracking).item(),
            "peak_Q_fro": torch.linalg.norm(grad_peak).item(),
            "total_Q_fro": torch.linalg.norm(grad_total).item(),
        },
        "gradient_check_relative_error_Q00": relative_gradient_error,
        "baseline": {
            "Q": Q_baseline.tolist(),
            "K": np.asarray(baseline["K"], dtype=float).reshape(1, -1).tolist(),
            "nbar_7k": float(baseline["nbar"]),
            "command_peak": baseline_response["command_peak"].item(),
            "tracking_loss": baseline_loss["tracking"].item(),
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
    parser.add_argument("--peak-weight", type=float, default=100.0)
    parser.add_argument("--initial-qy", type=float, default=0.7)
    parser.add_argument("--q-floor", type=float, default=1e-12)
    parser.add_argument("--horizon", type=float, default=1.5)
    parser.add_argument("--sample-rate", type=float, default=512.0)
    parser.add_argument("--verification-sample-rate", type=float, default=2048.0)
    parser.add_argument("--iterations", type=int, default=300)
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--gradient-clip", type=float, default=10.0)
    parser.add_argument("--report-every", type=int, default=25)
    parser.add_argument("--output", default="lqr_peak_command_optimization.json")
    return parser.parse_args()


if __name__ == "__main__":
    optimize(parse_args())
