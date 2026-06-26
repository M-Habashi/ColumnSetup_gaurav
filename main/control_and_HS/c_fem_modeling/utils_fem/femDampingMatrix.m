function [C, info] = femDampingMatrix(fem_ref, damping_source)
%FEMDAMPINGMATRIX Build the FEM damping matrix from saved damping metadata.
% Units: K [N/m], M [kg], C [N*s/m], omega [rad/s], frequency [Hz].

if nargin < 2
    damping_source = struct();
end

damping = resolveDampingDefinition(fem_ref, damping_source);
K = fem_ref.K;
M = fem_ref.M;

[modes, omega2] = eig(K, M, 'vector');
[omega, order] = sort(sqrt(real(omega2)));
modes = real(modes(:, order));
for mode_id = 1:size(modes, 2)
    modes(:, mode_id) = modes(:, mode_id) ...
        /sqrt(modes(:, mode_id)'*M*modes(:, mode_id));
end

info = damping;
info.omega_rad_s = omega(:);
info.frequency_hz = omega(:)/(2*pi);

switch lower(char(damping.type))
    case 'rayleigh'
        fit_modes = damping.fit_modes(:);
        target_ratio = damping.target_ratio(:);
        if isscalar(target_ratio)
            target_ratio = repmat(target_ratio, size(fit_modes));
        end
        coefficients = [1./(2*omega(fit_modes)), omega(fit_modes)/2] ...
            \target_ratio;
        info.alpha = coefficients(1);
        info.beta = coefficients(2);
        info.modal_damping_ratio = info.alpha./(2*omega(:)) ...
            + info.beta*omega(:)/2;
        C = info.alpha*M + info.beta*K;

    case 'modal'
        ratio = damping.ratio(:);
        if isscalar(ratio)
            ratio = repmat(ratio, size(omega(:)));
        end
        info.modal_damping_ratio = ratio;
        C = M*modes*diag(2*ratio(:).*omega(:))*modes'*M;

    otherwise
        error('femDampingMatrix:UnknownDampingType', ...
            'Unknown FEM damping type: %s.', char(damping.type));
end
end

function damping = resolveDampingDefinition(fem_ref, source)
target_ratio = 0.03;
if isstruct(fem_ref) && isfield(fem_ref, 'damping_ratio')
    target_ratio = fem_ref.damping_ratio;
end
if isstruct(source) && isfield(source, 'damping_ratio')
    target_ratio = source.damping_ratio;
end

if isstruct(source) && isfield(source, 'damping')
    damping = source.damping;
elseif isstruct(source) && isfield(source, 'type')
    damping = source;
elseif isstruct(fem_ref) && isfield(fem_ref, 'damping')
    damping = fem_ref.damping;
else
    damping = struct('type', 'rayleigh', ...
        'target_ratio', target_ratio, 'fit_modes', [1 2]);
end

if ~isfield(damping, 'type') || isempty(damping.type)
    damping.type = 'rayleigh';
end
if strcmpi(char(damping.type), 'rayleigh')
    if ~isfield(damping, 'target_ratio') || isempty(damping.target_ratio)
        damping.target_ratio = target_ratio;
    end
    if ~isfield(damping, 'fit_modes') || isempty(damping.fit_modes)
        damping.fit_modes = [1 2];
    end
elseif strcmpi(char(damping.type), 'modal')
    if ~isfield(damping, 'ratio') || isempty(damping.ratio)
        damping.ratio = target_ratio;
    end
end
end
